"""
main.py
-------
Entry point for DBExporterAI.

The Orchestrator is itself an intelligent agent — it classifies the user's
intent before deciding how to respond:

  INTENT: "export"      → run the Exporter → Troubleshooter retry loop
  INTENT: "question"    → answer directly via my_llm() (no tools needed)
  INTENT: "unclear"     → ask the user for clarification

Usage:
    python main.py --task "Export table EMPLOYEES where DEPT_ID=10 to CSV at /tmp/emp.csv"
    python main.py --task "What tools are available for exporting an Oracle table?"
    python main.py                          # interactive mode
"""

import argparse
import json
import os
import re
from agents.exporter_agent import build_exporter_agent, run_exporter_agent, run_db_query_agent
from agents.troubleshooter_agent import build_troubleshooter_agent, run_troubleshooter_agent
from my_llm import my_llm
from config import MAX_RETRY_ATTEMPTS, RETRY_BUDGET, DEFAULT_EXPORT_DIR, MAX_EXPORT_ROWS, EXPORT_DIRECTORIES
from tools.file_tools import _suggest_new_path


# ---------------------------------------------------------------------------
# Orchestrator system prompt — used for intent classification
# ---------------------------------------------------------------------------
ORCHESTRATOR_SYSTEM_PROMPT = """
You are an intent classifier for a database export AI system.
Classify the user input into exactly one of these four intents:

  export    - User explicitly wants to SAVE data TO A FILE (csv/json/file).
              Keywords: "export to", "save to", "write to file", "dump to csv", "output to json"
              Example: "export EMPLOYEES to csv"  →  export
              Example: "save ORDERS table to /tmp/out.json"  →  export

  db_query  - User wants to SEE or INSPECT data inline (no file). Includes listing tables,
              showing rows, counting records, describing schema, checking what exists.
              Keywords: "what tables", "show me", "list", "how many rows", "describe", "select"
              Example: "what tables do we have?"  →  db_query
              Example: "show 10 rows from EMPLOYEES"  →  db_query
              Example: "what columns does ORDERS have?"  →  db_query

  question  - General question about how the system works, what tools exist, concepts.
              Does NOT need to touch the database.
              Example: "how does this tool work?"  →  question
              Example: "what export formats are supported?"  →  question

  unclear   - Missing key information, cannot determine intent.
              Example: "do something with the database"  →  unclear

CRITICAL RULE: If the user says "what", "list", "show", "describe", "how many" about
database objects (tables, rows, columns, schema) → always classify as db_query, NOT export.

Respond with ONLY a raw JSON object — no markdown, no explanation, nothing else:
{"intent": "export|db_query|question|unclear", "reason": "<one sentence>"}
"""

ORCHESTRATOR_ANSWER_PROMPT = """
You are a helpful assistant for an Oracle database export system.
Answer the user's question clearly and concisely.
You have knowledge of these tools available in this system:
  - connect_to_oracle:  Establishes Oracle DB connection
  - get_table_schema:   Returns column names and data types for a table
  - execute_query:      Runs a SELECT SQL statement, returns rows as JSON
  - export_to_csv:      Writes query results to a CSV file
  - export_to_json:     Writes query results to a JSON file
  - close_connection:   Closes the DB connection
  - save_error_log:     Saves error messages to a timestamped log file
"""


# ---------------------------------------------------------------------------
# Intent classification
# ---------------------------------------------------------------------------

def classify_intent(user_input: str) -> tuple:
    """
    Classifies user input into: export | db_query | question | unclear.
    First tries JSON parsing, then falls back to keyword matching for
    providers (like Bedrock) that return prose instead of raw JSON.
    """
    prompt = (
        ORCHESTRATOR_SYSTEM_PROMPT.strip()
        + f"\n\nUser input: {user_input}\nOutput:"
    )
    raw = my_llm(prompt)
    intent, reason = _parse_intent_response(raw)

    # If JSON parsing failed, try keyword fallback
    if intent == "unclear" and "Could not parse" in reason:
        intent, reason = _keyword_fallback(user_input)
        print(f"[Orchestrator] Fallback keyword classification: {intent}")

    return intent, reason


def _parse_intent_response(raw: str) -> tuple[str, str]:
    """Extract intent/reason from JSON, stripping markdown fences if present."""
    text = raw.strip()
    # Strip markdown fences
    if text.startswith("```"):
        lines = text.splitlines()
        text = "\n".join(
            lines[1:-1] if lines[-1].strip().startswith("```") else lines[1:]
        )
    start, end = text.find("{"), text.rfind("}") + 1
    if start != -1 and end > start:
        try:
            data = json.loads(text[start:end])
            intent = data.get("intent", "unclear").lower().strip()
            reason = data.get("reason", "")
            if intent in ("export", "db_query", "question", "unclear"):
                return intent, reason
        except json.JSONDecodeError:
            pass
    return "unclear", "Could not parse classification response."


def _keyword_fallback(user_input: str) -> tuple:
    """
    Keyword-based intent classifier used when the LLM returns prose.
    db_query is checked BEFORE export to avoid misclassifying
    "what tables..." as export.
    """
    t = user_input.lower()

    # db_query signals — check FIRST (highest priority after export-to-file)
    db_inspect_words = ["what table", "list table", "show table", "what column",
                        "show me", "list ", "how many", "count ", "describe ",
                        "select ", "which table", "what schema", "what view",
                        "inspect", "schema", "what do we have"]
    if any(w in t for w in db_inspect_words):
        return "db_query", "Keyword match: database inspection request detected."

    # export signals — must have both a verb AND a file target
    export_verbs   = ["export", "dump", "extract", "pull", "output", "write", "save"]
    export_targets = ["csv", "json", "file", ".csv", ".json", "to /", "to c:\\"]
    has_export_verb   = any(v in t for v in export_verbs)
    has_export_target = any(v in t for v in export_targets)
    if has_export_verb and has_export_target:
        return "export", "Keyword match: export verb + file target detected."
    if has_export_verb:
        return "unclear", "Export intent detected but format/path not specified."

    # question signals
    question_words = ["how", "why", "explain", "tell me about", "help",
                      "what is", "what are", "available tool", "how does"]
    if any(w in t for w in question_words):
        return "question", "Keyword match: general question detected."

    return "unclear", "Could not determine intent from keywords."


# ---------------------------------------------------------------------------
# Direct answer (for "question" intent)
# ---------------------------------------------------------------------------

def answer_question(user_input: str) -> str:
    """
    Calls my_llm() to answer a general question directly,
    without invoking the Exporter or Troubleshooter.
    """
    prompt = f"{ORCHESTRATOR_ANSWER_PROMPT}\n\nUser question:\n{user_input}"
    return my_llm(prompt)


# ---------------------------------------------------------------------------
# Pre-flight checks  (Autonomy upgrade #3)
# ---------------------------------------------------------------------------

def _extract_output_path(task: str) -> str:
    """
    Best-effort extraction of an output file path from a task description.
    Looks for patterns like: 'to /tmp/foo.csv', 'at C:/tmp/bar.json',
    'path /tmp/x.csv', or any token containing .csv / .json.
    Returns the path string, or "" if not found.
    """
    patterns = [
        r'(?:to|at|path|into)\s+([\w./:\\-]+\.(?:csv|json))',
        r'((?:[A-Za-z]:[\\/]|/)[^\s]+\.(?:csv|json))',
        r'([\w./:-]+\.(?:csv|json))',
    ]
    for pat in patterns:
        m = re.search(pat, task, re.IGNORECASE)
        if m:
            return m.group(1).strip()
    return ""


def _is_dir_writable(path: str) -> bool:
    """Test whether a directory is writable by creating a temp file in it."""
    try:
        test_file = os.path.join(path, ".write_test")
        with open(test_file, "w") as f:
            f.write("")
        os.remove(test_file)
        return True
    except Exception:
        return False


def preflight_checks(task: str) -> tuple:
    """
    Inspects the task BEFORE calling the Exporter to catch obvious issues.
    Returns (modified_task, warnings, fatal_error).

    Checks performed:
    1. DIRECTORY WRITABLE — if the target directory is read-only, swap it for
       the first writable directory in EXPORT_DIRECTORIES. Fatal if none found.
    2. FILE EXISTS — if the output file already exists, auto-rename with
       _suggest_new_path() so the Exporter never hits a FileExistsError.
    3. ROW CAP NOTE — always remind about MAX_EXPORT_ROWS cap.
    """
    warnings_list = []
    fatal_error   = None
    output_path   = _extract_output_path(task)

    # ── Check 1: target directory writable ───────────────────────────────
    if output_path:
        target_dir = os.path.dirname(os.path.abspath(output_path))
    else:
        target_dir = os.path.abspath(DEFAULT_EXPORT_DIR)

    if not os.path.isdir(target_dir):
        # Directory doesn't exist — try to create it
        try:
            os.makedirs(target_dir, exist_ok=True)
        except Exception:
            pass

    if not os.path.isdir(target_dir) or not _is_dir_writable(target_dir):
        # Find first writable fallback directory
        fallback = None
        for d in EXPORT_DIRECTORIES:
            if os.path.isdir(d) and _is_dir_writable(d):
                fallback = d
                break
        if fallback:
            filename   = os.path.basename(output_path) if output_path else ""
            new_path   = os.path.join(fallback, filename).replace("\\", "/") if filename else fallback
            if output_path:
                task = task.replace(output_path, new_path)
            else:
                task = task + f" output to {new_path}"
            warnings_list.append(
                f"⚡ Pre-flight: '{target_dir}' is not writable → "
                f"switched to '{fallback}'"
            )
            output_path = new_path
            target_dir  = fallback
        else:
            fatal_error = (
                f"❌ Pre-flight FATAL: No writable export directory found.\n"
                f"   Tried: {EXPORT_DIRECTORIES}\n"
                f"   Please create one of these directories or check permissions."
            )
            return task, warnings_list, fatal_error

    # ── Check 2: file already exists → auto-rename ───────────────────────
    if output_path and os.path.isfile(output_path):
        new_path = _suggest_new_path(output_path)
        task = task.replace(output_path, new_path)
        warnings_list.append(
            f"⚡ Pre-flight: '{output_path}' already exists → "
            f"auto-renamed to '{new_path}'"
        )

    # ── Check 3: row cap reminder ─────────────────────────────────────────
    warnings_list.append(
        f"ℹ️  Pre-flight: Export row cap is {MAX_EXPORT_ROWS} rows. "
        f"Use a WHERE clause to narrow large tables."
    )

    return task, warnings_list, fatal_error


# ---------------------------------------------------------------------------
# Dynamic retry budget  (Autonomy upgrade #4)
# ---------------------------------------------------------------------------

def _retry_budget(error_type: str) -> int:
    """
    Returns how many TOTAL attempts are allowed for a given error type.
    1 means only the initial attempt (no retries).
    0 means fail immediately without even trying (shouldn't occur — handled below).
    """
    budget = RETRY_BUDGET.get(error_type.upper(), MAX_RETRY_ATTEMPTS)
    # budget of 0 means "don't retry" → still need the first attempt to show the error
    return max(budget, 1)


# ---------------------------------------------------------------------------
# Export pipeline (for "export" intent)
# ---------------------------------------------------------------------------

def run_export_pipeline(task_description: str) -> None:
    """
    Runs the Exporter → Troubleshooter retry loop.
    This is only called when intent == "export".

    Autonomy upgrades active here:
      #3 Pre-flight checks: file-exists renamed before first attempt.
      #4 Dynamic retry:     retry count adapts to the error type diagnosed.
    """
    # ── Pre-flight ────────────────────────────────────────────────────────
    task_description, pf_warnings, pf_fatal = preflight_checks(task_description)
    for w in pf_warnings:
        print(f"  {w}")
    if pf_fatal:
        print(pf_fatal)
        return

    exporter       = build_exporter_agent()
    troubleshooter = build_troubleshooter_agent()

    fix_hint         = None
    last_diagnosis   = None
    max_attempts     = MAX_RETRY_ATTEMPTS   # may be tightened after first diagnosis

    attempt = 0
    while attempt < max_attempts:
        attempt += 1
        print(f"\n{'='*60}")
        print(f"  [Pipeline] Attempt {attempt} of {max_attempts}")
        print(f"{'='*60}")

        result = run_exporter_agent(exporter, task_description, fix_hint=fix_hint)

        print(f"\n  [Exporter] Status : {result['status'].upper()}")

        if result["status"] == "success":
            msg = result["message"]
            if msg.lower().startswith("partial export:"):
                print(f"\n⚠️  Export PARTIALLY SUCCEEDED on attempt {attempt} (original request not fully met)!")
            else:
                print(f"\n✅ Export SUCCEEDED on attempt {attempt}!")
            print(f"   {msg}")
            if result.get("output_path"):
                print(f"   Output: {result['output_path']}")
            return

        # Failure — truncate long error for display
        print(f"   Error: {result['message'][:300]}")

        if attempt >= max_attempts:
            break

        print(f"\n🔍 [Pipeline] Calling Troubleshooter Agent...")
        diagnosis = run_troubleshooter_agent(
            None,
            original_task=task_description,
            error_message=result["message"],
        )
        last_diagnosis = diagnosis

        error_type = diagnosis.get("error_type", "OTHER")
        print(f"\n  [Troubleshooter] Error Type : {error_type}")
        print(f"  [Troubleshooter] Root Cause : {diagnosis.get('root_cause')}")
        print(f"  [Troubleshooter] Fix        : {diagnosis.get('recommended_fix')}")

        # ── Dynamic retry budget ─────────────────────────────────────────
        budget = _retry_budget(error_type)
        if budget <= 1:
            # No retries possible for this error type — fail fast
            print(f"\n  [Pipeline] ⛔ Error type '{error_type}' cannot be auto-resolved.")
            print(f"             Skipping remaining attempts (budget={budget}).")
            break
        # Cap max_attempts to budget (don't exceed what the error type allows)
        max_attempts = min(max_attempts, budget)

        fix_hint = diagnosis.get("recommended_fix", "")

    print(f"\n{'='*60}")
    print(f"❌ Export FAILED after {attempt} attempt(s).")
    if last_diagnosis:
        print(f"   Last error  : {last_diagnosis.get('error_type')}")
        print(f"   Root cause  : {last_diagnosis.get('root_cause')}")
        print(f"   Suggestion  : {last_diagnosis.get('recommended_fix')}")
    print(f"{'='*60}\n")


# ---------------------------------------------------------------------------
# DB Query pipeline (for "db_query" intent)
# ---------------------------------------------------------------------------

def run_db_query_pipeline(question: str) -> None:
    """
    Executes a DB query to answer the user's question inline.
    Uses the Exporter agent's tools but with a query-only system prompt.
    Results are limited to 500 rows and displayed in the terminal (no file).
    """
    agent = build_exporter_agent()
    print(f"\n[Orchestrator] → Querying database to answer question...\n")
    result = run_db_query_agent(agent, question)

    print(f"\n{'='*60}")
    if result["status"] == "success":
        print(result["message"])
    else:
        print(f"⚠️  Could not retrieve DB data: {result['message'][:300]}")
    print(f"{'='*60}")
    print(f"\n💡 Please describe your export task when you are ready.")
    print(f"   Example: Export table EMPLOYEES where DEPT_ID=10 to CSV at /tmp/employees.csv\n")


# ---------------------------------------------------------------------------
# Orchestrator — the intelligent router
# ---------------------------------------------------------------------------

def orchestrate(user_input: str) -> bool:
    """
    Classifies user intent and routes to the correct pipeline.
    Returns True if an export completed, False otherwise.
    """
    print("\n[Orchestrator] Classifying intent...")
    intent, reason = classify_intent(user_input)

    print(f"[Orchestrator] Intent : {intent.upper()}")
    print(f"[Orchestrator] Reason : {reason}")

    if intent == "export":
        print("[Orchestrator] -> Routing to Export Pipeline\n")
        return run_export_pipeline(user_input)
    elif intent == "db_query":
        print("[Orchestrator] -> Routing to DB Query\n")
        run_db_query_pipeline(user_input)
        return False
    elif intent == "question":
        print("[Orchestrator] -> Answering directly\n")
        answer = my_llm(user_input)
        print(f"\n{answer}\n")
        return False
    else:
        print("\n" + "=" * 60)
        print("[Orchestrator] I need more information to proceed.\n")
        print("  Please describe your export task including table name,")
        print("  conditions, format, and output path.\n")
        print("  Example:")
        print("    Export table EMPLOYEES where DEPT_ID=10 to CSV at /tmp/employees.csv")
        print("=" * 60 + "\n")
        return False


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_arguments() -> None:
    """
    Parses CLI arguments.
    No --task option — the system always starts in interactive session mode
    and prompts the user for input directly.
    """
    parser = argparse.ArgumentParser(
        description="DBExporterAI — Intelligent two-agent Oracle export system",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Start the system and type your request at the prompt.

Examples:
  What tools are available for exporting an Oracle table?
  Export table EMPLOYEES where DEPT_ID=10 to CSV at /tmp/employees.csv
  Export all rows from ORDERS where STATUS='PENDING' to JSON at /tmp/orders.json
        """,
    )
    parser.parse_args()  # parse with no arguments defined — catches -h / --help


# ---------------------------------------------------------------------------
# Entry point — always interactive session
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    parse_arguments()

    print(f"\n{'='*60}")
    print(f"  DBExporterAI — Intelligent Oracle Export System")
    print(f"  Type 'exit' to quit")
    print(f"{'='*60}\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nGoodbye.")
            break

        if not user_input:
            continue

        if user_input.lower() in ("exit", "quit", "q"):
            print("Goodbye.")
            break

        orchestrate(user_input)
