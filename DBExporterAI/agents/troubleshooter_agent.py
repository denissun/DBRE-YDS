"""
troubleshooter_agent.py - Agent 2: The Troubleshooter.
Uses my_llm() for provider-agnostic LLM calls.
"""

import json
import re
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from my_llm import my_llm

TROUBLESHOOTER_SYSTEM_PROMPT = """
You are a Database Export Troubleshooter Agent. Diagnose export failures and suggest fixes.

ERROR TYPES AND HOW TO HANDLE THEM:

1. FILE_EXISTS — the output file already exists (never overwrite).
   - The error message contains: "Suggested alternative path: '<path>'"
   - Your fix MUST use that exact suggested path.
   - Example fix: "Use the suggested path: /tmp/employees_20260415_143022.csv"

2. ORA-00904 — invalid column name in SQL.
   - Fix: correct the column name based on the table schema.

3. ORA-00942 — table or view does not exist.
   - Fix: verify the table name and schema prefix (e.g. SCHEMA.TABLE_NAME).

4. ORA-01017 — invalid username/password.
   - Fix: verify DB credentials in config.py.

5. CONNECTION — cannot connect to Oracle host.
   - Fix: verify host, port, service name in config.py.

6. ZERO_ROWS — query returned no rows.
   - Fix: relax the WHERE conditions or verify the data exists.

7. OTHER — any other error.
   - Analyse the error message and suggest a specific actionable fix.

Respond with ONLY a JSON object — no other text:
{
  "error_type": "<FILE_EXISTS|ORA_COLUMN|ORA_TABLE|ORA_AUTH|CONNECTION|ZERO_ROWS|OTHER>",
  "root_cause": "<one sentence>",
  "recommended_fix": "<exact actionable instruction including corrected path/value>"
}
"""


def build_troubleshooter_agent():
    """No client needed when using my_llm(). Returns None for API compatibility."""
    return None


def run_troubleshooter_agent(_client, original_task: str, error_message: str) -> dict:
    """
    Diagnoses an export failure by calling my_llm() with the task + error context.
    1. Builds a prompt combining system instructions, original task, and error message.
    2. Calls my_llm(prompt) -> routes to gemini/bedrock/mock per config.LLM_PROVIDER.
    3. Parses the JSON response and returns:
       {"error_type": str, "root_cause": str, "recommended_fix": str}
    Falls back to a best-effort dict if JSON parsing fails.
    """
    prompt = (
        f"{TROUBLESHOOTER_SYSTEM_PROMPT}\n\n"
        f"Original export task:\n{original_task}\n\n"
        f"Error message from Exporter Agent:\n{error_message}"
    )

    print(f"\n[TroubleshooterAgent] Analysing failure via my_llm()...\n")
    raw_text = my_llm(prompt)
    print(f"[TroubleshooterAgent] Raw response:\n{raw_text}\n")

    raw_text = re.sub(r"^```[a-zA-Z]*\n?", "", raw_text.strip()).rstrip("```").strip()

    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        return {
            "error_type": "UNKNOWN",
            "root_cause": "Could not parse agent response as JSON.",
            "recommended_fix": raw_text,
        }
