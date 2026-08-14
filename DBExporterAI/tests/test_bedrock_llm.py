"""
test_bedrock_llm.py - Test AWS Bedrock LLM directly via the Converse API.

Uses bedrock-runtime (NOT bedrock-agent-runtime) to talk to the raw
Claude model with no managed agent layer. Mirrors the style of test_hf.py.

Run:
    python -B tests/test_bedrock_llm.py

Requirements:
    - boto3 installed
    - EC2 IAM role with bedrock:InvokeModel permission (on the server)
      OR AWS credentials in ~/.aws/credentials (local)
"""

import boto3
import sys

# ---------------------------------------------------------------------------
# Config — change MODEL_ID to any Claude model available in your region
# ---------------------------------------------------------------------------
REGION   = "us-east-1"
MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"

SYSTEM_PROMPT = (
    "You are a helpful Oracle database export assistant. "
    "Answer questions clearly and concisely."
)


# ---------------------------------------------------------------------------
# Converse helper
# ---------------------------------------------------------------------------

def chat(client, messages: list, user_text: str) -> str:
    """
    Appends user_text to the message history, calls the Converse API,
    appends the assistant reply, and returns the reply text.
    Maintains full conversation history for multi-turn support.
    """
    messages.append({"role": "user", "content": [{"text": user_text}]})

    response = client.converse(
        modelId=MODEL_ID,
        system=[{"text": SYSTEM_PROMPT}],
        messages=messages,
    )

    assistant_msg = response["output"]["message"]
    messages.append(assistant_msg)  # keep history for next turn

    for block in assistant_msg.get("content", []):
        if "text" in block:
            return block["text"]

    return "(no text in response)"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    print("=" * 55)
    print("  Bedrock LLM Test  (Converse API)")
    print(f"  Model  : {MODEL_ID}")
    print(f"  Region : {REGION}")
    print("  Type 'exit' to quit")
    print("=" * 55)

    try:
        client = boto3.client("bedrock-runtime", region_name=REGION)
    except Exception as e:
        print(f"ERROR: could not create boto3 client: {e}")
        sys.exit(1)

    messages = []  # shared conversation history across turns

    while True:
        try:
            user_input = input("\nYou: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nGoodbye.")
            break

        if not user_input:
            continue
        if user_input.lower() in ("exit", "quit", "q"):
            print("Goodbye.")
            break

        try:
            reply = chat(client, messages, user_input)
            print(f"\nBedrock: {reply}")
        except Exception as e:
            err = str(e)
            if "AccessDenied" in err or "UnauthorizedClient" in err:
                print(f"\nERROR: Access denied — check IAM role has 'bedrock:InvokeModel' on {MODEL_ID}")
            elif "ValidationException" in err and "model" in err.lower():
                print(f"\nERROR: Model '{MODEL_ID}' not found or not enabled in {REGION}.")
                print("Go to AWS Console -> Bedrock -> Model access -> enable Claude models.")
            else:
                print(f"\nERROR {type(e).__name__}: {e}")
            break


if __name__ == "__main__":
    main()
