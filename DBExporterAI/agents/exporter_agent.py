"""
exporter_agent.py
-----------------
Agent 1: The Exporter.

Uses my_llm function-calling to autonomously:
  1. Connect to the Oracle DB
  2. Inspect the table schema
  3. Build and execute the correct SQL query
  4. Export results to CSV or JSON
  5. Report success or a detailed failure message
"""

import json
import sys
import os
import time

# Add project root to path so tools can be imported
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from config import GEMINI_MODEL, get_db_config, DB_INVENTORY, DEFAULT_DB, make_gemini_client, make_huggingface_client, make_bedrock_client, LLM_PROVIDER, EXPORT_DIRECTORIES, DEFAULT_EXPORT_DIR, MAX_EXPORT_ROWS
from tools import db_tools, file_tools
from my_llm import my_llm

# Gemini SDK is only required when LLM_PROVIDER == "gemini" — lazy import below
_genai = None
_types = None

def _ensure_gemini():
    """Lazy-imports the Google Gemini SDK. Raises a clear error if not installed."""
    global _genai, _types
    if _genai is None:
        try:
            from google import genai as _g
            from google.genai import types as _t
            _genai = _g
            _types = _t
        except ImportError:
            raise ImportError(
                "google-generativeai is not installed.\n"
                "Run: pip install google-generativeai\n"
                "Or switch LLM_PROVIDER to 'mock' or 'bedrock' in config.py"
            )

# ---------------------------------------------------------------------------
# Tool dispatch map
# Maps the function name (as declared in the schema) to the actual Python fn.
# ---------------------------------------------------------------------------
TOOL_DISPATCH = {
    "connect_to_oracle":    db_tools.connect_to_oracle,
    "get_table_schema":     db_tools.get_table_schema,
    "execute_query":        db_tools.execute_query,
    "export_query_to_file": db_tools.export_query_to_file,   # ← pipeline tool: Oracle→file, no row data in context
    "close_connection":     db_tools.close_connection,
    "export_to_csv":        file_tools.export_to_csv,         # kept for db_query inline use only
    "export_to_json":       file_tools.export_to_json,        # kept for db_query inline use only
    "save_error_log":       file_tools.save_error_log,
}

def _build_exporter_tools():
    """Builds the Gemini tool schema. Only called when LLM_PROVIDER == 'gemini'."""
    _ensure_gemini()
    types = _types
    return types.Tool(function_declarations=[
    types.FunctionDeclaration(
        name="connect_to_oracle",
        description="Establishes a connection to the Oracle database. Call this first before any query.",
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "host":     types.Schema(type=types.Type.STRING, description="Oracle DB hostname or IP"),
                "port":     types.Schema(type=types.Type.INTEGER, description="Oracle DB port, usually 1521"),
                "service":  types.Schema(type=types.Type.STRING, description="Oracle service name"),
                "user":     types.Schema(type=types.Type.STRING, description="Database username"),
                "password": types.Schema(type=types.Type.STRING, description="Database password"),
            },
            required=["host", "port", "service", "user", "password"],
        ),
    ),
    types.FunctionDeclaration(
        name="get_table_schema",
        description="Returns the column names and data types for a given Oracle table. Call this to understand the table structure before writing SQL.",
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "connection_id": types.Schema(type=types.Type.STRING, description="Connection ID returned by connect_to_oracle"),
                "table_name":    types.Schema(type=types.Type.STRING, description="Name of the Oracle table (uppercase)"),
            },
            required=["connection_id", "table_name"],
        ),
    ),
    types.FunctionDeclaration(
        name="execute_query",
        description=(
            "Executes a SQL SELECT statement and returns rows as a JSON list. "
            "USE ONLY for db_query intent (inline answers, max 50 rows). "
            "For exporting data to a file, use export_query_to_file instead — "
            "it writes directly to disk without passing row data through the LLM."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "connection_id": types.Schema(type=types.Type.STRING, description="Connection ID returned by connect_to_oracle"),
                "sql":           types.Schema(type=types.Type.STRING, description="The SQL SELECT query to execute. Always add FETCH FIRST 50 ROWS ONLY for inline queries."),
            },
            required=["connection_id", "sql"],
        ),
    ),
    types.FunctionDeclaration(
        name="export_query_to_file",
        description=(
            "THE CORRECT TOOL FOR ALL EXPORT TASKS. "
            "Executes `sql` and streams ALL rows DIRECTLY to `output_path` on disk — "
            "row data NEVER passes through the LLM context window. "
            "Supports millions of rows efficiently. "
            "Returns only metadata: {status, rows, path, file_size_bytes}. "
            "If the file already exists, returns FILE_EXISTS with a suggested_path — "
            "immediately call this tool again with the suggested_path, do NOT ask the user."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "connection_id": types.Schema(type=types.Type.STRING, description="Connection ID returned by connect_to_oracle"),
                "sql":           types.Schema(type=types.Type.STRING, description="Full SELECT statement. No row limit needed — all rows are streamed to file."),
                "output_path":   types.Schema(type=types.Type.STRING, description="Absolute path for the output file, e.g. C:/tmp/EMPLOYEES.csv"),
                "format":        types.Schema(type=types.Type.STRING, description="Output format: 'csv' (default) or 'json'"),
            },
            required=["connection_id", "sql", "output_path"],
        ),
    ),
    types.FunctionDeclaration(
        name="export_to_csv",
        description=(
            "DEPRECATED FOR EXPORTS — use export_query_to_file instead. "
            "Only use this if you already have a small JSON string of rows from execute_query."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "data_json":    types.Schema(type=types.Type.STRING, description="JSON string of rows"),
                "output_path":  types.Schema(type=types.Type.STRING, description="Absolute file path for the CSV"),
            },
            required=["data_json", "output_path"],
        ),
    ),
    types.FunctionDeclaration(
        name="export_to_json",
        description=(
            "DEPRECATED FOR EXPORTS — use export_query_to_file instead. "
            "Only use this if you already have a small JSON string of rows from execute_query."
        ),
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "data_json":    types.Schema(type=types.Type.STRING, description="JSON string of rows"),
                "output_path":  types.Schema(type=types.Type.STRING, description="Absolute file path for the JSON file"),
            },
            required=["data_json", "output_path"],
        ),
    ),
    types.FunctionDeclaration(
        name="close_connection",
        description="Closes the Oracle database connection. Always call this after the export is complete.",
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "connection_id": types.Schema(type=types.Type.STRING, description="Connection ID to close"),
            },
            required=["connection_id"],
        ),
    ),
    types.FunctionDeclaration(
        name="save_error_log",
        description="Saves an error message to a log file. Call this when an unrecoverable error occurs.",
        parameters=types.Schema(
            type=types.Type.OBJECT,
            properties={
                "error_message": types.Schema(type=types.Type.STRING, description="The error or traceback text to save"),
                "log_dir":       types.Schema(type=types.Type.STRING, description="Directory to write the log file (default: 'logs')"),
            },
            required=["error_message"],
        ),
    ),
])

def _build_exporter_system_prompt(db_name: str = None) -> str:
    """Builds the system prompt injecting resolved DB credentials and export dirs."""
    try:
        db = get_db_config(db_name)
    except KeyError as e:
        db = get_db_config(DEFAULT_DB)

    allowed_dirs = "\n".join(f"  - {d}" for d in EXPORT_DIRECTORIES)

    return f"""You are an Oracle Database Export Agent. You are persistent and resourceful — always try your best to complete the export even when the exact request cannot be met.

DATABASE CONNECTION (already resolved — use these exact values):
  host     : {db['host']}
  port     : {db['port']}
  service  : {db['service']}
  user     : {db['user']}
  password : {db['password']}

ALLOWED EXPORT DIRECTORIES:
{allowed_dirs}

DEFAULT export directory (use when user does not specify a path): {DEFAULT_EXPORT_DIR}

STANDARD INSTRUCTIONS:
1. Call connect_to_oracle with the exact credentials above.
2. Call get_table_schema to inspect the table before writing SQL.
3. Call export_query_to_file — THIS IS THE ONLY CORRECT TOOL FOR EXPORTING DATA.
   - It streams rows DIRECTLY from Oracle to the file — no row data enters this context.
   - It supports millions of rows with no performance issues.
   - NEVER call execute_query + export_to_csv/export_to_json for exports — that path
     passes all row data through this context window and WILL hang for large tables.
   - Use execute_query ONLY for db_query intent (inline answers, max 50 rows).
   - Format: "csv" (default) or "json" — derived from the output_path extension.
   - Example: export_query_to_file(connection_id, "SELECT * FROM EMPLOYEES", "C:/tmp/EMPLOYEES.csv", "csv")
4. Call close_connection when done.
   - If the user did not specify a directory, use: {DEFAULT_EXPORT_DIR}
   - Only write to the allowed directories listed above.
5. Call close_connection when done.
6. Report: rows exported, output file path, file size.

FINAL ANSWER FORMAT — always begin your final message with one of these exact prefixes:

  EXPORT COMPLETED: <details>
     Use when the exact table, columns, and conditions requested were exported successfully.

  PARTIAL EXPORT: <details>
     Use when you exported something but it differs from the original request.
     Examples: table name was corrected, WHERE returned 0 rows so sample exported,
               column name was corrected, file path changed due to FILE_EXISTS.
     Always state: what was requested, what was actually exported, and why.

  EXPORT FAILED: <details>
     Use only when no file could be written at all after all recovery attempts.

RESILIENCE RULES — follow these when the standard path fails:

R1. TABLE NOT FOUND (ORA-00942):
    - Run: SELECT table_name FROM user_tables WHERE table_name LIKE '%<keyword>%' to find similar table names.
    - Pick the closest match and retry with that table name.
    - If still nothing, run: SELECT table_name FROM user_tables FETCH FIRST 10 ROWS ONLY
      and export 10 sample rows from the first available table.
    - Use prefix: PARTIAL EXPORT:

R2. COLUMN NOT FOUND (ORA-00904):
    - Call get_table_schema on the table to see the real column names.
    - Find the closest matching column name (e.g. DEPT_ID → DEPARTMENT_ID).
    - Retry the query with the corrected column name.
    - Use prefix: PARTIAL EXPORT:

R3. WHERE CONDITION RETURNS ZERO ROWS:
    - Remove the WHERE condition entirely.
    - Call export_query_to_file with: SELECT * FROM <table>
    - This exports all rows (no row limit — export_query_to_file streams directly to file).
    - Use prefix: PARTIAL EXPORT:

R4. FILE ALREADY EXISTS (FILE_EXISTS error):
    - Read the suggested_path from the export_query_to_file error response.
    - Immediately call export_query_to_file again with the suggested_path.
    - Do NOT ask the user — retry automatically.
    - Use prefix: EXPORT COMPLETED: (path was auto-adjusted)

R5. ANY OTHER FAILURE:
    - Try: export_query_to_file with SELECT * FROM <table> (no WHERE, no limit).
    - Report what you did and what the original error was.
    - Use prefix: PARTIAL EXPORT:

GENERAL RULES:
- Never give up after one failure — always attempt at least one recovery strategy.
- Do NOT guess column names — always call get_table_schema first.
- Always call close_connection after finishing (success or failure).
"""


def build_exporter_agent():
    """
    Creates and returns the LLM client for the configured provider.

      "gemini"      → google.genai.Client        (used directly for native function calling)
      "huggingface" → openai.OpenAI              (pointed at HuggingFace router)
      "bedrock"     → boto3 bedrock-agent-runtime client
      "mock"        → None                       (my_llm() handles everything, no client needed)
    """
    if LLM_PROVIDER == "gemini":
        _ensure_gemini()
        return make_gemini_client()
    elif LLM_PROVIDER == "huggingface":
        return make_huggingface_client()
    elif LLM_PROVIDER == "bedrock":
        return make_bedrock_client()
    return None  # mock


def dispatch_tool_call(tool_name: str, tool_args: dict) -> str:
    """
    Routes a function_call to the correct Python tool function.
    For FileExistsError, returns an actionable retry instruction so the
    LLM automatically calls the tool again with the suggested path.
    """
    fn = TOOL_DISPATCH.get(tool_name)
    if fn is None:
        return json.dumps({"error": f"Unknown tool: '{tool_name}'"})
    try:
        result = fn(**tool_args)
        return result if isinstance(result, str) else json.dumps(result)
    except FileExistsError as e:
        # Extract the suggested path from the error message and instruct
        # the LLM to retry immediately with that path — no human needed.
        error_str = str(e)
        import re as _re
        match = _re.search(r"Suggested alternative path: '([^']+)'", error_str)
        suggested = match.group(1) if match else None
        print(f"[Exporter] FileExistsError — suggested path: {suggested}")
        if suggested:
            return json.dumps({
                "error": "FILE_EXISTS",
                "message": error_str,
                "action_required": (
                    f"The file already exists. You MUST immediately call "
                    f"{tool_name} again using output_path='{suggested}'. "
                    f"Do NOT ask the user. Retry now with the suggested path."
                ),
                "suggested_path": suggested,
            })
        return json.dumps({"error": error_str})
    except Exception as e:
        error_str = f"{type(e).__name__}: {e}"
        print(f"[Exporter] Tool '{tool_name}' raised an error: {error_str}")
        return json.dumps({"error": error_str})


def _mask_args(tool_name: str, args: dict) -> dict:
    """
    Returns a copy of `args` with sensitive fields masked for terminal output.
    The `password` field in connect_to_oracle calls is always masked.
    """
    if tool_name == "connect_to_oracle" and "password" in args:
        masked = dict(args)
        pw = str(masked["password"])
        if len(pw) > 4:
            masked["password"] = pw[:2] + "*" * (len(pw) - 4) + pw[-2:]
        else:
            masked["password"] = "****"
        return masked
    return args


_FAILURE_KEYWORDS = [
    "could not", "unable", "ora-", "cannot",
    "unrecoverable", "all attempts failed", "export failed:",
]

_SUCCESS_OVERRIDE_KEYWORDS = [
    "export completed:", "partial export:",
    "exported a sample", "exported instead", "used table", "closest match",
    "rows exported", "rows written", "export successful", "successfully exported",
    "file size", "output_path",
]


def _is_failure(text: str) -> bool:
    """
    Returns True only if the text is a genuine unrecoverable failure.
    EXPORT COMPLETED and PARTIAL EXPORT prefixes are always treated as success.
    """
    lower = text.lower()
    if any(w in lower for w in _SUCCESS_OVERRIDE_KEYWORDS):
        return False
    return any(w in lower for w in _FAILURE_KEYWORDS)


def _extract_db_name(task_description: str) -> str:
    """
    Scans the task description for a DB name matching a key in DB_INVENTORY.
    Returns the canonical key, or DEFAULT_DB ("test_db") if none found.
    """
    lower = task_description.lower()
    for key in DB_INVENTORY:
        if key.lower() in lower:
            return key
    return DEFAULT_DB


# ---------------------------------------------------------------------------
# DB Query system prompt (for "db_query" intent — no file export)
# ---------------------------------------------------------------------------

def _build_db_query_system_prompt(db_name: str = None) -> str:
    """Builds a system prompt for answering DB questions inline (no file export)."""
    db = get_db_config(db_name)
    available_dbs = ", ".join(DB_INVENTORY.keys())
    return f"""
You are an Oracle Database Query Agent. Your job is to answer the user's question \
by querying the Oracle database and returning the results as a formatted plain-text table.

Available database connections: {available_dbs}
Active connection for this session: {db_name or DEFAULT_DB}

Follow these steps:
1. Call connect_to_oracle with: host="{db['host']}", port={db['port']}, service="{db['service']}", user="{db['user']}", password="{db['password']}"
2. If you need column names, call get_table_schema first.
3. Call execute_query with the appropriate SELECT statement.
   - ALWAYS limit results to a maximum of 500 rows.
   - For Oracle 12c+: append  FETCH FIRST 500 ROWS ONLY  to your SQL.
   - For older Oracle: wrap with  WHERE ROWNUM <= 500.
4. Call close_connection to release the connection.
5. Emit FINAL_ANSWER with a readable, plain-text formatted answer.

Rules:
- Do NOT export to any file. Return results inline only.
- Always limit to 500 rows maximum.
- If asked "what tables exist": SELECT table_name FROM user_tables ORDER BY table_name FETCH FIRST 500 ROWS ONLY
- If asked for sample rows: use FETCH FIRST <N> ROWS ONLY (up to 500).
- Format the FINAL_ANSWER as a plain-text table with column headers separated by | characters.
"""


def run_db_query_agent(client, question: str) -> dict:
    """
    Answers a DB question by executing a live query (no file export, max 500 rows).
    Used when the Orchestrator classifies intent as "db_query".
    """
    db_name = _extract_db_name(question)
    print(f"\n[QueryAgent] 🔌 Using database: '{db_name}'")

    try:
        system_prompt = _build_db_query_system_prompt(db_name)
    except KeyError:
        return {
            "status": "failure",
            "message": f"Unknown database '{db_name}'. Available: {', '.join(DB_INVENTORY.keys())}",
            "output_path": None,
        }

    if LLM_PROVIDER == "mock":
        return {
            "status": "success",
            "message": "Mock DB: available tables are EMPLOYEES (4 rows) and ORDERS (3 rows).",
            "output_path": None,
        }

    if LLM_PROVIDER in ("bedrock", "huggingface"):
        if client is None:
            return {
                "status": "failure",
                "message": f"Query agent client is None for provider '{LLM_PROVIDER}'. "
                           f"Check that HF_TOKEN / AWS credentials are set.",
                "output_path": None,
            }
        try:
            return _run_react_loop(client, system_prompt, question)
        except Exception as e:
            import traceback
            return {"status": "failure",
                    "message": f"[QueryAgent error] {e}\n{traceback.format_exc()}",
                    "output_path": None}

    # Gemini native function-calling path
    _ensure_gemini()
    types = _types
    EXPORTER_TOOLS = _build_exporter_tools()
    gemini_config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        tools=[EXPORTER_TOOLS],
    )
    contents = [types.Content(role="user", parts=[types.Part(text=question)])]
    for _ in range(15):
        try:
            response = client.models.generate_content(
                model=GEMINI_MODEL, contents=contents, config=gemini_config,
            )
        except Exception as e:
            return {"status": "failure", "message": str(e), "output_path": None}
        candidate = response.candidates[0]
        contents.append(types.Content(role="model", parts=candidate.content.parts))
        function_calls = [p for p in candidate.content.parts if p.function_call is not None]
        text_parts = [p for p in candidate.content.parts if p.text]
        if function_calls:
            tool_response_parts = []
            last_tool_result = None  # track the last tool result for error reporting
            for part in function_calls:
                fc = part.function_call
                print(f"[QueryAgent] Tool call: {fc.name}({_mask_args(fc.name, dict(fc.args))})")
                tool_result_str = dispatch_tool_call(fc.name, dict(fc.args))
                last_tool_result = tool_result_str  # track for error reporting

                # Guard: content=None means Gemini stopped after tool error
                if candidate.content is None:
                    return {
                        "status": "failure",
                        "message": (
                            f"Gemini returned empty content after calling '{fc.name}'. "
                            f"Tool result: {last_tool_result}"
                        ),
                        "output_path": None,
                    }

                contents.append(types.Content(role="model", parts=candidate.content.parts))
        elif text_parts:
            return {"status": "success",
                    "message": "\n".join(p.text for p in text_parts),
                    "output_path": None}
        else:
            return {"status": "failure", "message": "Agent returned empty response.", "output_path": None}
    return {"status": "failure", "message": "Max iterations reached.", "output_path": None}


# ---------------------------------------------------------------------------
# ReAct tool-calling loop (for bedrock / huggingface)
# ---------------------------------------------------------------------------

_REACT_TOOL_DESCRIPTIONS = """
You have access to the following tools to complete the export task.
To call a tool output EXACTLY one line in this format (nothing else on that line):
  TOOL_CALL: {"name": "<tool_name>", "args": {<json arguments>}}

After you receive the tool result, decide on the next step.
When the task is fully complete (or you cannot recover from an error), output EXACTLY:
  FINAL_ANSWER: <your summary message>

Available tools:
  connect_to_oracle(host, port, service, user, password)
      → Connects to Oracle DB. Returns {"status": "connected", "connection_id": "<id>"}
  get_table_schema(connection_id, table_name)
      → Returns column names and types as JSON list
  execute_query(connection_id, sql)
      → Runs a SELECT statement, returns rows as JSON list
  export_to_csv(data_json, output_path)
      → Writes rows JSON to a CSV file. Returns {"status": "ok", "rows": N, "path": "..."}
  export_to_json(data_json, output_path)
      → Writes rows JSON to a JSON file. Returns {"status": "ok", "rows": N, "path": "..."}
  close_connection(connection_id)
      → Closes the DB connection
  save_error_log(error_message)
      → Saves an error message to a timestamped log file

Rules:
  - Always call connect_to_oracle FIRST before any other DB tool.
  - Always call get_table_schema before building your SQL.
  - Use the connection_id returned by connect_to_oracle in all subsequent calls.
  - Always call close_connection after export is done (or on error).
  - Use absolute paths for all output files (e.g. C:/exports/table.json).
  - After each TOOL_CALL wait for the result before proceeding.
"""


def _run_react_loop(client, system_prompt: str, prompt: str) -> dict:
    """
    Text-based ReAct tool-calling loop for bedrock / huggingface providers.

    Uses the pre-built `client` directly (created by build_exporter_agent) —
    no redundant client construction on each iteration.

    Parses TOOL_CALL / FINAL_ANSWER markers from the LLM response, dispatches
    tools locally, and feeds results back until FINAL_ANSWER or iteration cap.
    """
    import re

    def _call_llm(text: str) -> str:
        """Call the correct provider API using the shared client."""
        if LLM_PROVIDER == "huggingface":
            from config import HF_MODEL
            response = client.chat.completions.create(
                model=HF_MODEL,
                messages=[{"role": "user", "content": text}],
            )
            return response.choices[0].message.content or ""
        elif LLM_PROVIDER == "bedrock":
            from config import BEDROCK_AGENT_ID, BEDROCK_AGENT_ALIAS_ID
            import uuid
            response = client.invoke_agent(
                agentId=BEDROCK_AGENT_ID,
                agentAliasId=BEDROCK_AGENT_ALIAS_ID,
                sessionId=str(uuid.uuid4()),
                inputText=text,
            )
            result = ""
            for event in response["completion"]:
                if "chunk" in event:
                    result += event["chunk"]["bytes"].decode("utf-8")
            return result
        else:
            raise ValueError(f"_run_react_loop called with unsupported provider: {LLM_PROVIDER}")

    # Build a full prompt that includes tool descriptions + task
    conversation = (
        system_prompt
        + "\n\n"
        + _REACT_TOOL_DESCRIPTIONS
        + "\n\n--- TASK ---\n"
        + prompt
        + "\n\nBegin. Call the first tool now."
    )

    max_iterations = 15

    for iteration in range(1, max_iterations + 1):
        print(f"[ExporterAgent:react] Iteration {iteration}/{max_iterations}")
        response = _call_llm(conversation)

        # --- Check for FINAL_ANSWER ---
        final_match = re.search(r"FINAL_ANSWER:\s*(.+)", response, re.IGNORECASE | re.DOTALL)
        if final_match:
            final_text = final_match.group(1).strip()
            print(f"[ExporterAgent:react] ✅ Final answer:\n{final_text}\n")
            lower = final_text.lower()
            if any(w in lower for w in ["error", "failed", "failure", "exception", "could not", "unable"]):
                return {"status": "failure", "message": final_text, "output_path": None}
            output_path = None
            for token in final_text.split():
                token = token.strip(".,;\"'()")
                if token.endswith(".csv") or token.endswith(".json"):
                    output_path = token
                    break
            return {"status": "success", "message": final_text, "output_path": output_path}

        # --- Check for TOOL_CALL ---
        # Use brace-counting to extract the full JSON object (handles nested braces)
        tool_call_marker = re.search(r"TOOL_CALL:\s*(\{)", response, re.IGNORECASE)
        if tool_call_marker:
            start = tool_call_marker.start(1)
            depth = 0
            end = start
            for i, ch in enumerate(response[start:], start):
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        end = i + 1
                        break
            raw_json = response[start:end].strip()

            tool_name = "unknown"   # safe default in case JSON parse fails
            tool_args = {}
            try:
                call = json.loads(raw_json)
                tool_name = call["name"]
                tool_args = call.get("args", {})
            except (json.JSONDecodeError, KeyError) as e:
                tool_result = json.dumps({"error": f"Could not parse tool call JSON: {e}"})
                # Mask password before printing
                safe_json = re.sub(r'"password"\s*:\s*"[^"]*"', '"password": "****"', raw_json)
                print(f"[ExporterAgent:react] ⚠️  Bad tool call JSON: {safe_json}")
            else:
                print(f"[ExporterAgent:react] 🔧 Tool call: {tool_name}({_mask_args(tool_name, tool_args)})")
                tool_result = dispatch_tool_call(tool_name, tool_args)
                print(f"[ExporterAgent:react] Tool result: {tool_result[:300]}")

            # Append assistant turn + tool result to conversation
            conversation += (
                f"\n\nAssistant:\n{response}"
                f"\n\nTool result for {tool_name}:\n{tool_result}"
                f"\n\nContinue — call the next tool or emit FINAL_ANSWER."
            )
            continue

        # LLM replied with neither marker — prompt it to continue
        print(f"[ExporterAgent:react] ⚠️  No TOOL_CALL or FINAL_ANSWER found. Reprompting...")
        conversation += (
            f"\n\nAssistant:\n{response}"
            "\n\nYou must either emit a TOOL_CALL or a FINAL_ANSWER. Continue now."
        )

    return {"status": "failure",
            "message": "Max iterations reached without a FINAL_ANSWER.",
            "output_path": None}


def run_exporter_agent(client, task_description: str, fix_hint: str = None) -> dict:
    """
    Runs the Exporter Agent.

    Provider routing:
      "mock"                  → delegates entirely to my_llm() (no tool calls)
      "bedrock","huggingface" → text-based ReAct tool loop via my_llm()
      "gemini"                → native Gemini SDK function-calling loop
    Returns:
       {"status": "success"|"failure", "message": str, "output_path": str|None}
    """
    # Resolve DB name — falls back to "test_db" if none mentioned in task
    db_name = _extract_db_name(task_description)
    print(f"\n[ExporterAgent] 🔌 Connecting to database: '{db_name}'")

    try:
        system_prompt = _build_exporter_system_prompt(db_name)
    except KeyError:
        return {
            "status": "failure",
            "message": f"Unknown database '{db_name}'. Available: {', '.join(DB_INVENTORY.keys())}",
            "output_path": None,
        }

    prompt = task_description
    if fix_hint:
        prompt += f"\n\n[Previous attempt failed. Troubleshooter's recommended fix]: {fix_hint}"

    print(f"[ExporterAgent] Starting with prompt:\n  {prompt}\n")

    # ------------------------------------------------------------------
    # MOCK path: delegate entirely to my_llm() — no real tool calls.
    # Mock returns a canned string; we just parse it for success/failure.
    # ------------------------------------------------------------------
    if LLM_PROVIDER == "mock":
        response_text = my_llm(system_prompt + "\n\n" + prompt)
        lower = response_text.lower()
        output_path = None
        for token in response_text.split():
            token = token.strip(".,;\"'()")
            if token.endswith(".csv") or token.endswith(".json"):
                output_path = token
                break
        if any(w in lower for w in ["error", "failed", "failure", "exception"]):
            return {"status": "failure", "message": response_text, "output_path": None}
        return {"status": "success", "message": response_text, "output_path": output_path}

    # ------------------------------------------------------------------
    # TEXT-BASED ReAct LOOP — for bedrock and huggingface.
    # Both are treated as plain text LLMs via the pre-built client.
    # ------------------------------------------------------------------
    if LLM_PROVIDER in ("bedrock", "huggingface"):
        if client is None:
            return {
                "status": "failure",
                "message": f"Exporter client is None for provider '{LLM_PROVIDER}'. "
                           f"Ensure HF_TOKEN / AWS credentials are set and re-run '. .\\set_env.ps1'.",
                "output_path": None,
            }
        try:
            return _run_react_loop(client, system_prompt, prompt)
        except Exception as e:
            import traceback
            return {"status": "failure", "message": f"[ReAct loop error] {e}\n{traceback.format_exc()}", "output_path": None}

    # ------------------------------------------------------------------
    # Gemini native function-calling path
    # ------------------------------------------------------------------
    _ensure_gemini()
    types = _types
    EXPORTER_TOOLS = _build_exporter_tools()

    config = types.GenerateContentConfig(
        system_instruction=system_prompt,
        tools=[EXPORTER_TOOLS],
    )

    # Start conversation
    contents = [types.Content(role="user", parts=[types.Part(text=prompt)])]
    max_iterations = 20  # safety cap to prevent infinite loops

    for iteration in range(max_iterations):
        # --- Call Gemini with retry on 429 rate-limit ---
        max_api_retries = 5
        for api_attempt in range(max_api_retries):
            try:
                response = client.models.generate_content(
                    model=GEMINI_MODEL,
                    contents=contents,
                    config=config,
                )
                break  # success — exit retry loop
            except Exception as e:
                err_str = str(e)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    # Parse suggested retry delay from error message if available
                    import re
                    match = re.search(r"retry in (\d+)", err_str)
                    wait_sec = int(match.group(1)) + 2 if match else 30
                    print(f"[ExporterAgent] Rate-limited (429). Waiting {wait_sec}s before retry "
                          f"({api_attempt + 1}/{max_api_retries})...")
                    time.sleep(wait_sec)
                    if api_attempt == max_api_retries - 1:
                        return {"status": "failure",
                                "message": f"Quota exhausted after {max_api_retries} retries: {err_str}",
                                "output_path": None}
                else:
                    return {"status": "failure", "message": err_str, "output_path": None}

        candidate = response.candidates[0]

        # Guard: content=None means Gemini stopped unexpectedly
        if candidate.content is None:
            return {
                "status": "failure",
                "message": "Gemini returned empty content (possible safety filter or quota issue).",
                "output_path": None,
            }

        # Separate function calls from text parts
        function_calls = [p for p in candidate.content.parts if p.function_call is not None]
        text_parts      = [p for p in candidate.content.parts if p.text]

        contents.append(types.Content(role="model", parts=candidate.content.parts))

        if function_calls:
            # Execute all requested tool calls and collect responses
            tool_response_parts = []
            for part in function_calls:
                fc = part.function_call
                tool_name = fc.name
                tool_args = dict(fc.args)
                print(f"[ExporterAgent] Tool call [{iteration+1}]: {tool_name}({_mask_args(tool_name, tool_args)})")
                result_str = dispatch_tool_call(tool_name, tool_args)
                print(f"[ExporterAgent] Tool result: {result_str[:200]}")
                tool_response_parts.append(
                    types.Part(
                        function_response=types.FunctionResponse(
                            name=tool_name,
                            response={"result": result_str},
                        )
                    )
                )
            # Feed results back to the model
            contents.append(types.Content(role="user", parts=tool_response_parts))

        elif text_parts:
            # No more tool calls — agent has finished
            final_text = "\n".join(p.text for p in text_parts)
            print(f"\n[ExporterAgent] Final response:\n{final_text}\n")
            if _is_failure(final_text):
                return {"status": "failure", "message": final_text, "output_path": None}
            output_path = None
            for token in final_text.split():
                token = token.strip(".,;\"'()")
                if token.endswith(".csv") or token.endswith(".json"):
                    output_path = token
                    break
            return {"status": "success", "message": final_text, "output_path": output_path}

        else:
            return {"status": "failure", "message": "Agent returned an empty response.", "output_path": None}

    return {"status": "failure", "message": "Max iterations reached without completion.", "output_path": None}
