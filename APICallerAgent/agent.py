#!/usr/bin/env python3
"""
APICallerAgent – CLI agent powered by Gemini that translates natural-language
Oracle database questions into executeQuery API calls via a generic api_caller
tool.  Behaviour is driven by oracle_db_query_playbook.md, which is loaded at
startup and injected as the model's system instruction.

Usage:
    python agent.py [--playbook <path>]
"""

import argparse
import json
import os
import sys
from pathlib import Path

import requests
import urllib3
from google import genai
from google.genai import types

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ── Configuration ─────────────────────────────────────────────────────────────

GEMINI_MODEL = "gemini-2.5-flash"


def _load_playbook(path: Path) -> str:
    """Read the playbook markdown file and return its contents as a string."""
    if not path.exists():
        raise FileNotFoundError(f"Playbook not found: {path}")
    return path.read_text(encoding="utf-8")

# ── Tool declaration (google.genai types) ───────────────────────────────────

_API_CALLER_DECL = types.FunctionDeclaration(
    name="api_caller",
    description=(
        "Makes an HTTP POST request to the given API endpoint with the given "
        "JSON payload string and returns the response body as a JSON string."
    ),
    parameters=types.Schema(
        type=types.Type.OBJECT,
        properties={
            "endpoint": types.Schema(
                type=types.Type.STRING,
                description="The full URL of the API endpoint to POST to.",
            ),
            "payload": types.Schema(
                type=types.Type.STRING,
                description=(
                    "The request body serialised as a JSON string. "
                    'Example: {"query":"SELECT 1","dbNames":["mydb"],"dsn":"","rowLimit":10}'
                ),
            ),
        },
        required=["endpoint", "payload"],
    ),
)

_API_CALLER_TOOL = types.Tool(function_declarations=[_API_CALLER_DECL])

# ── Tool implementation ───────────────────────────────────────────────────────

def _call_api(endpoint: str, payload_str: str) -> str:
    """POST to *endpoint* with *payload_str* (a JSON string). Returns the
    response body as a JSON string, or an error envelope on failure."""
    proxies = {
        "http":  os.environ.get("HTTP_PROXY"),
        "https": os.environ.get("HTTPS_PROXY"),
    }
    proxies = {k: v for k, v in proxies.items() if v}

    try:
        payload = json.loads(payload_str)
    except json.JSONDecodeError as exc:
        return json.dumps({"error": f"Bad payload JSON: {exc}"})

    try:
        resp = requests.post(
            endpoint,
            json=payload,
            proxies=proxies or None,
            verify=False,
            timeout=30,
        )
        resp.raise_for_status()
        return json.dumps(resp.json(), indent=2)
    except requests.exceptions.HTTPError as exc:
        # Include response body so the model can read the error message
        body = {}
        try:
            body = exc.response.json()
        except Exception:
            body = {"raw": exc.response.text}
        return json.dumps({"error": str(exc), "details": body})
    except requests.exceptions.RequestException as exc:
        return json.dumps({"error": str(exc)})


# ── Agent loop ────────────────────────────────────────────────────────────────

def run_query(user_question: str, client: genai.Client, config: types.GenerateContentConfig, debug: bool = False) -> str:
    """Send *user_question* to the agent and return its final text answer.
    Handles one or more tool-call rounds automatically."""

    chat     = client.chats.create(model=GEMINI_MODEL, config=config)
    response = chat.send_message(user_question)

    while True:
        fcs = response.function_calls  # list[types.FunctionCall] or None
        if not fcs:
            break  # No tool call → the model produced a final text answer

        fc          = fcs[0]
        args        = dict(fc.args)
        endpoint    = args.get("endpoint", "")
        payload_str = args.get("payload", "{}")

        print(f"  [tool] POST {endpoint}")
        if debug:
            try:
                pretty = json.dumps(json.loads(payload_str), indent=2)
            except json.JSONDecodeError:
                pretty = payload_str
            print(f"  [debug payload]\n{pretty}")
        tool_result = _call_api(endpoint, payload_str)
        print(f"  [resp] {tool_result[:120]}{'...' if len(tool_result) > 120 else ''}")

        # Feed the result back to the model
        response = chat.send_message(
            types.Part.from_function_response(
                name=fc.name,
                response={"result": tool_result},
            )
        )

    return response.text or ""


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Oracle DB Assistant Agent")
    parser.add_argument(
        "--playbook",
        type=Path,
        required=True,
        help="Path to the playbook markdown file (e.g. oracle_db_query_playbook.md)",
    )
    parser.add_argument(
        "--question",
        type=str,
        default=None,
        help='Run a single question and exit (e.g. --question "what are 10 largest tables in eposdb")',
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Print the full JSON payload before each API call",
    )
    args = parser.parse_args()

    api_key = os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print("ERROR: GEMINI_API_KEY is not set.")
        print("Run:  . .\\set_env.ps1")
        sys.exit(1)

    try:
        system_prompt = _load_playbook(args.playbook)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}")
        sys.exit(1)

    client = genai.Client(api_key=api_key)

    config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        tools=[_API_CALLER_TOOL],
    )

    print(f"Oracle DB Assistant Agent  [playbook: {args.playbook.name}]")
    print("─" * 50)

    # ── Single-question mode ──────────────────────────────────────────────────
    if args.question:
        print(f"You: {args.question}")
        try:
            answer = run_query(args.question, client, config, debug=args.debug)
        except Exception as exc:
            print(f"  [error] {exc}")
            sys.exit(1)
        print(f"\nAgent: {answer}")
        return

    # ── Interactive mode ──────────────────────────────────────────────────────
    print("Type 'quit' to exit.")
    while True:
        try:
            user_input = input("\nYou: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            break

        if not user_input:
            continue
        if user_input.lower() in {"quit", "exit", "q"}:
            print("Goodbye.")
            break

        try:
            answer = run_query(user_input, client, config, debug=args.debug)
        except Exception as exc:
            print(f"  [error] {exc}")
            continue

        print(f"\nAgent: {answer}")


if __name__ == "__main__":
    main()
