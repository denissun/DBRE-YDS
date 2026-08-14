"""
my_llm.py
---------
A provider-agnostic LLM wrapper.

Exposes one function:
    my_llm(prompt: str, session_id: str = None) -> str

This function routes to the configured backend (set LLM_PROVIDER in config.py):

  "bedrock" → AWS Bedrock Agent Runtime (invoke_agent)
              In this use case, bedrock is treated as just a LLM API provider similar to Gemini.
              An agent need to have their own tool functions, bedrock does not provide its lambda functions and action groups.
             
             
  "gemini"  → Google Gemini API (generate_content, plain text — no function
              calling schema). For the full tool-calling loop, the agents
              use the Gemini client directly. Use this for simple text tasks
              like the Troubleshooter.

  "mock"    → Returns a pre-canned response. Useful for offline unit tests
              or when neither cloud provider is available.

Swap providers by changing LLM_PROVIDER in config.py — no agent code changes needed.
"""

import uuid
import json
from config import (
    LLM_PROVIDER,
    GEMINI_API_KEY, GEMINI_MODEL,
    BEDROCK_AGENT_ID, BEDROCK_AGENT_ALIAS_ID, BEDROCK_REGION,
    HF_TOKEN, HF_MODEL, HF_BASE_URL,
    make_gemini_client, make_huggingface_client, make_bedrock_client,
)

# ---------------------------------------------------------------------------
# Module-level session ID — shared across calls within one run.
# Pass an explicit session_id to override (e.g. for multi-turn conversations).
# ---------------------------------------------------------------------------
_DEFAULT_SESSION_ID = str(uuid.uuid4())


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def my_llm(prompt: str, session_id: str = None, attempt: int = 1) -> str:
    """
    Send a text prompt to the configured LLM backend and return the response text.

    Parameters:
        prompt     - The full text prompt to send.
        session_id - Optional session identifier for multi-turn context.
                     Defaults to a module-level UUID (same session per process run).

    Returns:
        A plain text string containing the model's response.

    Raises:
        RuntimeError if the provider call fails after retries.
    """
    sid = session_id or _DEFAULT_SESSION_ID

    if LLM_PROVIDER == "bedrock":
        return _call_bedrock(prompt, sid)
    elif LLM_PROVIDER == "gemini":
        return _call_gemini(prompt)
    elif LLM_PROVIDER == "huggingface":
        return _call_huggingface(prompt)
    elif LLM_PROVIDER == "mock":
        return _call_mock(prompt)
    else:
        raise ValueError(f"Unknown LLM_PROVIDER: '{LLM_PROVIDER}'. Choose 'bedrock', 'gemini', 'huggingface', or 'mock'.")


# ---------------------------------------------------------------------------
# Bedrock backend
# ---------------------------------------------------------------------------

# System role injected at the top of every Bedrock inputText.
# The Bedrock invoke_agent API has no separate system_prompt parameter,
# so we prepend the role instruction directly to the user prompt.
BEDROCK_SYSTEM_PROMPT = """\
You are an expert Oracle database table export specialist with deep knowledge of:
- Oracle SQL syntax, data types, and query optimisation
- Oracle error codes (ORA-XXXXX) and how to resolve them
- Best practices for exporting table data to CSV and JSON formats
- Database connection management and schema inspection

When asked to export a table:
  1. Always inspect the table schema before writing SQL.
  2. Apply the requested WHERE conditions exactly.
  3. Use absolute file paths for all output files.
  4. Report the number of rows exported and the output file path on success.
  5. On failure, provide a detailed ORA error message so it can be diagnosed.

When asked a general question, answer concisely and accurately.

---
"""


def _call_bedrock(prompt: str, session_id: str) -> str:
    """
    Invokes the AWS Bedrock Agent and streams back the full response.

    The BEDROCK_SYSTEM_PROMPT role instruction is prepended to every inputText
    because invoke_agent has no separate system prompt parameter.

    Authentication:
        When running on an EC2 instance with an attached IAM role, boto3
        automatically retrieves temporary credentials from the EC2 Instance
        Metadata Service (IMDS) at http://169.254.169.254. No environment
        variables (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY) are needed.

        The IAM role must have the following permission:
            Action:   "bedrock:InvokeAgent"
            Resource: "arn:aws:bedrock:<region>:<account>:agent-alias/<AGENT_ID>/<ALIAS_ID>"

    Phase 1 design note:
        The Bedrock Agent is used purely as an LLM text provider — we send
        a text prompt and receive a text response. The Agent's own Lambda
        Action Groups (if any) are not used. All tool execution (DB queries,
        file exports) happens in local Python via tools/db_tools.py and
        tools/file_tools.py, called directly by the Exporter Agent logic.

    Streams the 'completion' EventStream chunks, decodes bytes, joins to string.
    """
    print(f"[my_llm:bedrock] Invoking agent {BEDROCK_AGENT_ID} (alias {BEDROCK_AGENT_ALIAS_ID})")

    client = make_bedrock_client()

    # Prepend system role to the prompt
    full_input = BEDROCK_SYSTEM_PROMPT + prompt

    response = client.invoke_agent(
        agentId=BEDROCK_AGENT_ID,
        agentAliasId=BEDROCK_AGENT_ALIAS_ID,
        sessionId=session_id,
        inputText=full_input,
    )

    # Stream and assemble the response chunks (same pattern as sample code)
    agent_response = ""
    for event in response["completion"]:
        if "chunk" in event:
            agent_response += event["chunk"]["bytes"].decode("utf-8")

    print(f"[my_llm:bedrock] Response length: {len(agent_response)} chars")
    return agent_response


# ---------------------------------------------------------------------------
# Gemini backend (plain text — no function calling)
# ---------------------------------------------------------------------------

def _call_gemini(prompt: str) -> str:
    """
    Sends a plain text prompt to Google Gemini and returns the response.

    This is a simple, single-turn call with NO function calling schema.
    It is used for reasoning-only tasks (e.g. Troubleshooter Agent diagnosis).

    For the Exporter Agent's tool-calling loop, the agents/exporter_agent.py
    uses the Gemini client directly with EXPORTER_TOOLS attached — that loop
    is separate from this function.
    """
    import time

    client = make_gemini_client()
    max_retries = 3

    for attempt in range(1, max_retries + 1):
        try:
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=prompt,
            )
            return response.text
        except Exception as e:
            if "429" in str(e) and attempt < max_retries:
                wait = 15 * attempt
                print(f"[my_llm:gemini] Rate-limited. Waiting {wait}s (attempt {attempt}/{max_retries})...")
                time.sleep(wait)
            else:
                raise RuntimeError(f"Gemini call failed: {e}") from e

    raise RuntimeError("Gemini call failed after all retries.")


# ---------------------------------------------------------------------------
# HuggingFace Inference backend (OpenAI-compatible)
# ---------------------------------------------------------------------------

def _call_huggingface(prompt: str) -> str:
    """
    Sends a plain text prompt to the HuggingFace Inference API using the
    OpenAI-compatible /v1/chat/completions endpoint.

    Client is created via make_huggingface_client() defined in config.py.
    Model is configured via HF_MODEL in config.py.
    """
    client = make_huggingface_client()

    print(f"[my_llm:huggingface] Calling model '{HF_MODEL}'...")

    response = client.chat.completions.create(
        model=HF_MODEL,
        messages=[{"role": "user", "content": prompt}],
    )

    text = response.choices[0].message.content or ""
    print(f"[my_llm:huggingface] Response length: {len(text)} chars")
    return text


# ---------------------------------------------------------------------------
# Mock backend (for offline testing)
# ---------------------------------------------------------------------------

_mock_call_count = 0

def _call_mock(prompt: str) -> str:
    """
    Returns pre-canned responses without making any API call.

    Routing logic (in priority order):
      1. Orchestrator intent classification  → returns JSON intent object
      2. Orchestrator direct answer          → returns helpful plain text
      3. Troubleshooter diagnosis            → returns JSON diagnosis
      4. Exporter attempt 1                  → simulates SQL failure
      5. Exporter attempt 2+                 → simulates successful export
    """
    global _mock_call_count
    _mock_call_count += 1

    prompt_lower = prompt.lower()

    # --- Orchestrator: intent classification ---
    if '"export"' in prompt or '"question"' in prompt or '"unclear"' in prompt \
            or "classify" in prompt_lower or "user input:" in prompt_lower \
            or ("intent" in prompt_lower and "clarification_needed" in prompt_lower):

        # Extract the actual user input — it appears after "User input:\n"
        user_input = ""
        if "user input:" in prompt_lower:
            user_input = prompt_lower.split("user input:")[-1].strip()
        else:
            user_input = prompt_lower

        # Export intent: user mentions exporting data to a file
        export_verbs   = ["export", "dump", "extract", "pull out", "output"]
        export_targets = [".csv", ".json", "csv", "json", "file", "table"]
        has_export_verb   = any(w in user_input for w in export_verbs)
        has_export_target = any(w in user_input for w in export_targets)

        if has_export_verb and has_export_target:
            return '{"intent": "export", "reason": "User wants to export data to a file.", "clarification_needed": ""}'

        # Question intent: asking for explanation or information
        question_words = ["explain", "what", "how", "which", "why", "describe",
                          "list", "show me", "tell me", "available", "help"]
        if any(w in user_input for w in question_words):
            return '{"intent": "question", "reason": "User is asking for information or an explanation.", "clarification_needed": ""}'

        # Export verb present but missing destination details
        if has_export_verb:
            return '{"intent": "unclear", "reason": "Export requested but output format or path not specified.", "clarification_needed": "Please specify the output format (CSV or JSON) and the output file path."}'

        return '{"intent": "unclear", "reason": "Could not determine intent.", "clarification_needed": "Please describe your export task including the table name, any WHERE conditions, output format (CSV/JSON), and the output file path."}'

    # --- Orchestrator: direct answer to a question ---
    if "answer the user" in prompt_lower or "user question:" in prompt_lower \
            or "available tools" in prompt_lower:
        return (
            "The following tools are available in this system for Oracle table export:\n\n"
            "• connect_to_oracle   — establishes a connection to the Oracle DB\n"
            "• get_table_schema    — returns column names and data types for a table\n"
            "• execute_query       — runs a SELECT statement and returns rows as JSON\n"
            "• export_to_csv       — writes query results to a CSV file\n"
            "• export_to_json      — writes query results to a JSON file\n"
            "• close_connection    — closes the DB connection cleanly\n"
            "• save_error_log      — saves error details to a timestamped log file\n\n"
            "To use them, describe an export task such as:\n"
            "  'Export table EMPLOYEES where DEPT_ID=10 to CSV at /tmp/employees.csv'"
        )

    # --- Troubleshooter: diagnosis ---
    if "troubleshoot" in prompt_lower or "root_cause" in prompt_lower \
            or "recommended_fix" in prompt_lower or "error message from exporter" in prompt_lower:
        return json.dumps({
            "error_type": "COLUMN_NOT_FOUND",
            "root_cause": "The WHERE clause referenced DEPARTMENT_ID but the correct column name is DEPT_ID.",
            "recommended_fix": "Use WHERE DEPT_ID=10 instead of WHERE DEPARTMENT_ID=10 in the SQL query.",
        })

    # --- Exporter: fail on first call, succeed on subsequent ---
    if _mock_call_count <= 2:
        return "Export failed: column DEPARTMENT_ID does not exist. Error: ORA-00904 invalid identifier."
    else:
        return (
            "Export complete. Successfully queried EMPLOYEES WHERE DEPT_ID=10 "
            "and exported 3 rows to C:/exports/employees.csv"
        )
