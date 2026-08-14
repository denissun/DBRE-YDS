# DBExporterAI — Implementation Guide

A **three-agent AI system** that exports Oracle database tables to CSV/JSON files through an intelligent conversation loop.

---

## Background

This is my learning project to understeand agentic AI workflow.


I set the goal again for my AI Engineer journey.  The goal is to build a simple multi-agent AI system that we can quickly prototype to see the ideas in action. The intention is for this project to be a hands-on learning experience and to lay the groundwork for tackling more complex, multi-agent AI systems down the road. We need the system's goals to be super clear so we can easily tell if it's working right. This learning project is essential for clearly demonstrating the concepts and workflow of a multi-agent system. By providing a strong, foundational example, it will enable the development of more complex multi-agent systems in the future.

I propose the development of a Database Exporter Multi-Agent AI System,  because the task of database export is foundational, relatively well-defined, and universally understood by database administrators (DBAs). Its inherent simplicity makes it an ideal proving ground for testing multi-agent capabilities, particularly the autonomous handling of dynamic, real-world error conditions. The system will demonstrate the agents' ability to interpret natural language commands, execute complex, multi-step technical procedures, and, most critically, exhibit intelligent self-correction and adaptation in the face of unexpected failures.

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Agent 1 — Orchestrator](#agent-1--orchestrator-mainpy)
4. [Agent 2 — Exporter](#agent-2--exporter-agentsexporter_agentpy)
5. [Agent 3 — Troubleshooter](#agent-3--troubleshooter-agentstroubleshooter_agentpy)
6. [LLM Providers](#llm-providers)
7. [Database Layer](#database-layer)
8. [File Tools](#file-tools)
9. [Configuration Reference](#configuration-reference)
10. [How to Run](#how-to-run)
11. [Provider-Specific Notes](#provider-specific-notes)
12. [File Structure](#file-structure)

---

## System Overview

The user types a plain-English request. The system:

1. **Classifies** the intent (export / question / unclear)
2. **Routes** to the correct handler
3. If export: **executes** the full DB to file pipeline using tool calls
4. If any step fails: **diagnoses** the error and **retries** with a fix hint

All three agents share a single LLM provider configured in `config.py` via `LLM_PROVIDER`.

---

## Architecture Diagram

```
User Input
    |
    v
+---------------------------------------------+
|  Agent 1: ORCHESTRATOR  (main.py)           |
|                                             |
|  classify_intent() -> my_llm()              |
|                                             |
|  intent="export"   ──────────────+          |
|  intent="question" -> answer     |          |
|  intent="unclear"  -> ask again  |          |
+──────────────────────────────────+──────────+
                                   |
                    +--------------v------------------+
                    |   run_export_pipeline()         |
                    |   retry loop, up to 3 attempts  |
                    +──────────+──────────────────────+
                               |
              +────────────────v────────────────────────+
              |  Agent 2: EXPORTER                      |
              |  (agents/exporter_agent.py)             |
              |                                         |
              |  Provider routing:                      |
              |    mock         -> my_llm() only        |
              |    gemini       -> SDK function-calling  |
              |    huggingface /                        |
              |    bedrock      -> ReAct text loop      |
              |                                         |
              |  Tool calls (local Python):             |
              |  connect_to_oracle -> get_table_schema  |
              |  -> execute_query -> export_to_csv/json |
              |  -> close_connection                    |
              +──────────────+──────────────────────────+
                             | FAILURE?
                             v
              +──────────────────────────────────────────+
              |  Agent 3: TROUBLESHOOTER                 |
              |  (agents/troubleshooter_agent.py)        |
              |                                          |
              |  my_llm(task + error) ->                 |
              |  { error_type, root_cause,               |
              |    recommended_fix }                     |
              +──────────────+───────────────────────────+
                             | fix_hint
                             +──> Exporter retries (next attempt)
```

---

## Agent 1 — Orchestrator (`main.py`)

The Orchestrator is the entry point. It runs an **interactive session** (`while True` loop) and handles every user message.

### Intent Classification

`classify_intent(user_input)` sends a structured prompt to `my_llm()`:

- `"export"`   — user wants to export data to a file
- `"question"` — user asks a general question
- `"unclear"`  — missing information (no table name, no format, etc.)

Returns:
```python
{
    "intent": "export" | "question" | "unclear",
    "reason": "one-sentence explanation",
    "clarification_needed": "what info is missing (export only)"
}
```

### Routing Logic

| Intent | Action |
|---|---|
| `export` | Calls `run_export_pipeline(user_input)` |
| `question` | Calls `answer_question(user_input)`, prints the answer |
| `unclear` | Prints clarification request, stays in session |

### Export Pipeline (`run_export_pipeline`)

Retry loop up to `MAX_RETRY_ATTEMPTS` (default 3):

```
Attempt 1:
  run_exporter_agent(task)
    SUCCESS -> print result, done
    FAILURE -> call run_troubleshooter_agent(task, error)
               get fix_hint

Attempt 2:
  run_exporter_agent(task, fix_hint=fix_hint)
    SUCCESS or FAILURE -> repeat

After MAX attempts: print final failure summary
```

---

## Agent 2 — Exporter (`agents/exporter_agent.py`)

The Exporter executes the full DB to file export pipeline using **tool calls**. It is designed to be **persistent and resilient** — it always attempts at least one recovery strategy before reporting failure.

### Initialisation: `build_exporter_agent()`

Creates the LLM client once, returned for reuse across all retry attempts:

| `LLM_PROVIDER` | Client returned |
|---|---|
| `"gemini"` | `google.genai.Client` via `make_gemini_client()` |
| `"huggingface"` | `openai.OpenAI` (HF router) via `make_huggingface_client()` |
| `"bedrock"` | `boto3` bedrock-agent-runtime via `make_bedrock_client()` |
| `"mock"` | `None` |

### DB Name Resolution

`_extract_db_name(task_description)` scans the task text for any key in `DB_INVENTORY` (case-insensitive). Falls back to `DEFAULT_DB` (`"test_db"`) if no DB name is mentioned.

`_build_exporter_system_prompt(db_name)` calls `get_db_config(db_name)` to resolve `host/port/service/user/password` and injects them into the agent system prompt.

### Provider Execution Paths

#### `"mock"` path
Delegates the entire prompt to `my_llm()`. No tool calls are made. The canned response is parsed for success/failure keywords.

#### `"gemini"` path — Native Function Calling
Uses the Gemini SDK structured function-calling loop:

```
1. Send system_prompt + task to Gemini with EXPORTER_TOOLS schema attached
2. Gemini returns function_call objects (tool name + args)
3. dispatch_tool_call() executes each tool locally
4. Tool results fed back as FunctionResponse parts
5. Repeat until Gemini returns a text-only response (task complete)
6. Cap: 20 iterations max
7. Auto-retry on 429 rate-limit (up to 5 retries with backoff)
8. Guard: candidate.content=None detected → returns clean failure dict
```

#### `"huggingface"` / `"bedrock"` path — ReAct Text Loop

Uses a structured text protocol since these providers have no native function-calling SDK:

```
1. Build conversation = system_prompt + tool descriptions + task
2. Call _call_llm(conversation) using the pre-built client
3. Parse response for markers:
   TOOL_CALL: {"name": "...", "args": {...}}
     -> brace-counting JSON extract -> dispatch_tool_call() -> append result -> repeat
   FINAL_ANSWER: <message>
     -> _is_failure() check -> return result dict
   (neither marker found) -> reprompt LLM to emit one
4. Cap: 15 iterations max
```

`_call_llm()` calls the provider API directly using the client from `build_exporter_agent()`:
- **HuggingFace**: `client.chat.completions.create(model=HF_MODEL, messages=[...])`
- **Bedrock**: `client.invoke_agent(agentId=..., inputText=..., sessionId=...)`

### Tools Available to the Exporter

| Tool | Purpose | Module |
|---|---|---|
| `connect_to_oracle` | Opens Oracle DB connection | `tools/db_tools.py` |
| `get_table_schema` | Returns column names and types | `tools/db_tools.py` |
| `execute_query` | Runs SELECT, returns rows as JSON | `tools/db_tools.py` |
| `export_to_csv` | Writes rows JSON to CSV file | `tools/file_tools.py` |
| `export_to_json` | Writes rows JSON to JSON file | `tools/file_tools.py` |
| `close_connection` | Closes the DB connection | `tools/db_tools.py` |
| `save_error_log` | Writes error to timestamped log | `tools/file_tools.py` |

### Expected Tool Execution Order

```
connect_to_oracle(host, port, service, user, password)
  -> get_table_schema(connection_id, table_name)
    -> execute_query(connection_id, sql)
      -> export_to_csv(data_json, output_path)
         OR export_to_json(data_json, output_path)
           -> close_connection(connection_id)
```

---

## Failure Handling & Resilience

The Exporter is designed never to give up after a single failure. It follows five built-in recovery rules before escalating to the Troubleshooter.

### `dispatch_tool_call()` — Special Error Handling

`dispatch_tool_call()` catches exceptions from tools and returns structured JSON so the LLM can reason about them:

- **`FileExistsError`** → returns `{"error": "FILE_EXISTS", "suggested_path": "...", "action_required": "retry with suggested_path"}` — the LLM immediately retries with the timestamped path, no human needed
- **Other exceptions** → returns `{"error": "ExceptionType: message"}` — LLM reads this and decides recovery strategy per the resilience rules

### `_is_failure()` — Smart Success Detection

```python
_SUCCESS_OVERRIDE_KEYWORDS = [
    "exported a sample", "exported instead", "used table", "closest match",
    "rows exported", "rows written", "export successful", "successfully exported",
]
_FAILURE_KEYWORDS = [
    "could not", "unable", "file_exists", "ora-", "cannot",
    "unrecoverable", "all attempts failed",
]
```

If the LLM's final response contains a **success override phrase**, it is classified as `SUCCESS` even if it also contains a word like "error" (e.g. "original table not found, exported a sample instead"). This prevents resilience messages from being misclassified as failures.

### Five Built-in Resilience Rules (in system prompt)

| Rule | Trigger | Recovery Action |
|---|---|---|
| **R1 — Table Not Found** | ORA-00942 | `SELECT table_name FROM user_tables WHERE table_name LIKE '%keyword%'` → use closest match → if nothing, export 10 rows from first available table |
| **R2 — Column Not Found** | ORA-00904 | Call `get_table_schema` → find closest column name → retry SQL with corrected column |
| **R3 — Zero Rows** | WHERE returns 0 rows | Remove WHERE clause → `SELECT * FROM <table> FETCH FIRST 10 ROWS ONLY` → export sample |
| **R4 — File Exists** | `FILE_EXISTS` tool error | Use `suggested_path` from error JSON immediately → retry export — no user prompt |
| **R5 — Any Other Error** | Any remaining exception | `SELECT * FROM <table> FETCH FIRST 10 ROWS ONLY` → export sample → report original error |

### Full Failure Flow

```
User: "export EMPLOYE table to csv"
         |
         v
[Exporter Attempt 1]
  connect_to_oracle() ─────────────────────────────── OK
  get_table_schema("EMPLOYE") ──────────── ORA-00942: table not found
         |
         v [R1: search for similar table]
  execute_query("SELECT table_name FROM user_tables
                 WHERE table_name LIKE '%EMPLOYE%'")
         -> returns "EMPLOYEES"
         |
         v [retry with correct table]
  get_table_schema("EMPLOYEES") ──────────────────── OK
  execute_query("SELECT * FROM EMPLOYEES FETCH FIRST 10 ROWS ONLY")
  export_to_csv(data, "C:/tmp/EMPLOYEES_sample.csv")
  close_connection()
         |
         v
  FINAL_ANSWER: "Table EMPLOYE not found. Exported 10 sample rows
                 from EMPLOYEES to C:/tmp/EMPLOYEES_sample.csv"
         |
         v
  _is_failure() → "exported 10 sample rows" → SUCCESS OVERRIDE → ✅ SUCCESS
```

```
User: "export EMPLOYEES to C:/tmp/test.csv"  (file already exists)
         |
         v
[Exporter Attempt 1]
  connect_to_oracle() ────── OK
  get_table_schema()  ────── OK
  execute_query()     ────── OK
  export_to_csv("C:/tmp/test.csv")
         |
         v [dispatch_tool_call catches FileExistsError]
  returns: {"error": "FILE_EXISTS",
            "suggested_path": "C:/tmp/test_20260426_212112.csv",
            "action_required": "retry with suggested_path"}
         |
         v [LLM reads action_required, retries immediately — same attempt]
  export_to_csv("C:/tmp/test_20260426_212112.csv") ──── OK
  close_connection()
         v
  ✅ SUCCESS — no retry loop needed
```

```
User: "export EMPLOYEES where SALARY=999999 to csv"  (no matching rows)
         |
         v
[Exporter Attempt 1]
  connect_to_oracle() → OK
  get_table_schema()  → OK
  execute_query("SELECT * FROM EMPLOYEES WHERE SALARY=999999")
         -> returns []  (zero rows)
         |
         v [R3: drop WHERE, export sample]
  execute_query("SELECT * FROM EMPLOYEES FETCH FIRST 10 ROWS ONLY")
         -> returns 4 rows
  export_to_csv(data, "C:/tmp/EMPLOYEES.csv")
  close_connection()
         v
  FINAL_ANSWER: "No rows matched SALARY=999999.
                 Exported 4 sample rows to C:/tmp/EMPLOYEES.csv"
         v
  ✅ SUCCESS (success override: "sample rows")
```

### When the Troubleshooter Is Called

The Troubleshooter is only called when the Exporter's **final response is still a failure** after all resilience rules have been exhausted. It diagnoses and returns a `recommended_fix` injected into the next attempt's prompt.

| Error Type | Example Fix Returned |
|---|---|
| `FILE_EXISTS` | "Use the suggested path: `/tmp/employees_20260426_143022.csv`" |
| `ORA_COLUMN` | "Replace `DEPT_ID` with `DEPARTMENT_ID` in the WHERE clause" |
| `ORA_TABLE` | "Table `EMPLOYE` does not exist — try `EMPLOYEES`" |
| `ORA_AUTH` | "Invalid credentials — verify USER/PASSWORD in config.py" |
| `CONNECTION` | "Cannot reach host — verify host/port/service in config.py" |
| `ZERO_ROWS` | "Remove WHERE clause or verify data exists in the table" |

## Agent 3 — Troubleshooter (`agents/troubleshooter_agent.py`)

A **reasoning-only** agent — no tool calls, no client needed.

### `build_troubleshooter_agent()`

Returns `None`. Uses `my_llm()` which manages its own client internally.

### `run_troubleshooter_agent(_client, original_task, error_message)`

Builds a prompt combining the original user task and the full error from the Exporter, then calls `my_llm(prompt)`.

Response JSON:
```json
{
  "error_type": "SQL_SYNTAX | COLUMN_NOT_FOUND | FILE_PATH | CONNECTION | EMPTY_RESULT | OTHER",
  "root_cause": "one sentence",
  "recommended_fix": "specific instruction for next attempt"
}
```

The `recommended_fix` is passed back to the Exporter as `fix_hint` on the next retry.

---

## LLM Providers

### `my_llm(prompt, session_id)` — `my_llm.py`

Single function used by the Orchestrator (intent classification, direct answers) and the Troubleshooter (diagnosis). Routes to the correct backend based on `LLM_PROVIDER`.

### Provider Summary

| Provider | `LLM_PROVIDER` | Package | Auth |
|---|---|---|---|
| Google Gemini | `"gemini"` | `google-generativeai` | `GEMINI_API_KEY` env var |
| HuggingFace | `"huggingface"` | `openai` (compat) | `HF_TOKEN` env var |
| AWS Bedrock | `"bedrock"` | `boto3` | IAM role (EC2 IMDS) |
| Mock | `"mock"` | none | none |

### Client Factory Functions (`config.py`)

```python
make_gemini_client()       # -> google.genai.Client(api_key=GEMINI_API_KEY)
make_huggingface_client()  # -> openai.OpenAI(base_url=HF_BASE_URL, api_key=HF_TOKEN)
make_bedrock_client()      # -> boto3.client("bedrock-agent-runtime", region=BEDROCK_REGION)
```

All factories use lazy imports — missing packages do not crash startup when a different provider is selected.

### Corporate SSL Fix

Applied globally in `config.py` at import time:

```python
ssl._create_default_https_context = ssl._create_unverified_context
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
```

Suppresses SSL errors caused by enterprise proxy certificate injection.

---

## Database Layer (`tools/db_tools.py`)

Controlled by `USE_MOCK_DB` in `config.py`.

### Mock Mode (`USE_MOCK_DB = True`)

All functions return in-memory fake data. No Oracle installation needed.

Available mock tables:
- `EMPLOYEES` — 4 rows: EMPLOYEE_ID, FIRST_NAME, LAST_NAME, DEPT_ID, SALARY, STATUS
- `ORDERS` — 3 rows: ORDER_ID, CUSTOMER_ID, STATUS, AMOUNT, ORDER_DATE

Supports simple WHERE filtering (e.g. `WHERE DEPT_ID=10`, `WHERE STATUS='ACTIVE'`).

### Real Oracle Mode (`USE_MOCK_DB = False`)

Uses `oracledb` library in **thin mode** (no Oracle Client installation needed):

```python
oracledb.connect(user=user, password=password, dsn=dsn)
```

Live connections stored in `_REAL_CONNECTIONS` dict, keyed by `connection_id`.  
Schema queries run against `ALL_TAB_COLUMNS`. Results returned as JSON list of dicts.

### DB Inventory (`config.py`)

```python
DB_INVENTORY = {
    "auditfrmwk_db": {
        "DSN":      "host:port/service",
        "USER":     "username",
        "PASSWORD": "password",
    },
    "test_db": { ... },
}
DEFAULT_DB = "auditfrmwk_db"
```

`get_db_config(db_name)` does a case-insensitive lookup, parses the DSN, and returns a flat dict with `host`, `port`, `service`, `user`, `password` keys.

---

## File Tools (`tools/file_tools.py`)

| Function | Description |
|---|---|
| `export_to_csv(data_json, output_path)` | Writes rows to CSV file — raises `FileExistsError` if file already exists |
| `export_to_json(data_json, output_path)` | Writes rows to JSON file — raises `FileExistsError` if file already exists |
| `save_error_log(error_message)` | Writes to `logs/error_<timestamp>.log` |
| `read_file(file_path)` | Reads and returns content of any text file |

### File Existence Policy

**Neither export function ever overwrites an existing file.** If the target path already exists:

1. `_suggest_new_path(path)` generates a timestamped alternative:
   ```
   C:/tmp/employees.csv  →  C:/tmp/employees_20260426_212112.csv
   ```
2. A `FileExistsError` is raised with the message:
   ```
   FILE_EXISTS: 'C:/tmp/employees.csv' already exists.
   Suggested alternative path: 'C:/tmp/employees_20260426_212112.csv'
   ```
3. `dispatch_tool_call()` catches this and returns structured JSON with `suggested_path` and `action_required` keys
4. The LLM reads `action_required` and immediately retries with `suggested_path` — **no human intervention needed**

### Export Verification

After writing, both functions:
- Verify the file exists on disk with `os.path.isfile()`
- Check file size is non-zero with `os.path.getsize()`
- Raise `OSError` if the file wasn't created (unknown write error)
- Print `[FileTool] ✅ CSV/JSON verified: <path> (<size> bytes, <rows> rows)`

### Data JSON Parsing

`_parse_data_json(data_json)` handles malformed input from the LLM:
1. First tries `json.loads(data_json)` directly
2. If that fails with `\'` escape errors (Gemini sometimes double-escapes SQL strings): replaces `\'` → `'` and retries
3. Last resort: `ast.literal_eval()` after substituting Python keywords

## Configuration Reference (`config.py`)

| Setting | Description | Default |
|---|---|---|
| `LLM_PROVIDER` | Active LLM backend | `"gemini"` |
| `GEMINI_MODEL` | Gemini model name | `"gemini-2.5-flash"` |
| `GEMINI_API_KEY` | From env var `GEMINI_API_KEY` | `""` |
| `HF_TOKEN` | From env var `HF_TOKEN` | `""` |
| `HF_MODEL` | HuggingFace model | `"Qwen/Qwen2.5-72B-Instruct"` |
| `HF_BASE_URL` | HF inference router URL | `"https://router.huggingface.co/v1"` |
| `BEDROCK_REGION` | AWS region | `"us-east-1"` |
| `BEDROCK_AGENT_ID` | Bedrock agent ID | `"MNTQEQHMCM"` |
| `BEDROCK_AGENT_ALIAS_ID` | Bedrock alias | `"3XZQV6OPAM"` |
| `USE_MOCK_DB` | Use in-memory mock Oracle | `False` |
| `MAX_RETRY_ATTEMPTS` | Export retry attempts | `3` |
| `DEFAULT_DB` | Fallback DB name | `"auditfrmwk_db"` |

---

## How to Run

### 1. Set environment variables (PowerShell)

```powershell
. .\set_env.ps1
```

Sets `GEMINI_API_KEY`, `HF_TOKEN`, `HTTPS_PROXY`, `HTTP_PROXY`.

### 2. Activate virtual environment

```powershell
..\venv313\Scripts\Activate.ps1
```

### 3. Choose provider in `config.py`

```python
LLM_PROVIDER = "huggingface"   # or "gemini" / "bedrock" / "mock"
USE_MOCK_DB  = True            # True = no real Oracle needed
```

### 4. Run

```powershell
python main.py
```

### 5. Example session

```
You: What tools are available?
[Orchestrator] Intent: QUESTION -> answers directly

You: Export table EMPLOYEES where DEPT_ID=10 to CSV at C:/exports/emp.csv
[Orchestrator] Intent: EXPORT -> routes to pipeline
[ExporterAgent] Connecting to database: 'test_db'
[ExporterAgent:react] Iteration 1/15
  TOOL_CALL: connect_to_oracle(...)   -> {"status": "connected", "connection_id": "..."}
  TOOL_CALL: get_table_schema(...)    -> [{"column": "EMPLOYEE_ID", ...}]
  TOOL_CALL: execute_query(...)       -> [{"EMPLOYEE_ID": 1, ...}, ...]
  TOOL_CALL: export_to_csv(...)       -> {"status": "ok", "rows": 3, "path": "..."}
  TOOL_CALL: close_connection(...)    -> {"status": "closed"}
  FINAL_ANSWER: Exported 3 rows to C:/exports/emp.csv
  Export SUCCEEDED on attempt 1!

You: exit
```

---

## Provider-Specific Notes

### Gemini
- Requires `GEMINI_API_KEY` (free tier has quota limits — system auto-retries on 429 with backoff)
- Uses native SDK function calling — most reliable tool execution
- Best provider for guaranteed correct tool call sequencing
- Smoke test: `python tests/test_googleapi.py`

### HuggingFace
- Requires `HF_TOKEN`
- Uses OpenAI-compatible API via `router.huggingface.co/v1`
- ReAct text loop — LLM must emit `TOOL_CALL:` / `FINAL_ANSWER:` markers in plain text
- Model configurable via `HF_MODEL` in `config.py`
- Smoke test: `python tests/test_hf.py`

### AWS Bedrock
- Requires IAM role with `bedrock:InvokeAgent` permission
- On EC2: auto-credentials from IMDS — no `AWS_ACCESS_KEY_ID` needed
- Same ReAct text loop as HuggingFace

### Mock
- No network calls, no API keys needed
- Exporter always fails on attempt 1, succeeds on attempt 2+ (exercises the retry/troubleshooter loop)
- Uses in-memory `EMPLOYEES` and `ORDERS` tables

---

## File Structure

```
DBExporterAI/
├── main.py                          # Agent 1: Orchestrator + interactive session
├── my_llm.py                        # Provider-agnostic LLM wrapper
├── config.py                        # All settings, DB inventory, client factories
├── config.example.py                # Safe template (committed to git, no secrets)
├── set_env.ps1                      # Sets env vars in current PowerShell session
├── deploy.ps1                       # Deploys files to Linux server via pscp/plink
├── requirements.txt                 # Python dependencies
├── agents/
│   ├── exporter_agent.py            # Agent 2: DB export with tool calling + resilience
│   └── troubleshooter_agent.py      # Agent 3: Error diagnosis
├── tools/
│   ├── db_tools.py                  # Oracle DB operations (real + mock)
│   └── file_tools.py                # CSV/JSON export, FileExistsError handling
├── tests/
│   ├── test_googleapi.py            # Gemini connectivity + model listing smoke test
│   ├── test_hf.py                   # HuggingFace connectivity smoke test
│   ├── test_hf_react.py             # ReAct tool loop demo (text markers)
│   ├── test_hf_native_tools.py      # Native OpenAI function calling demo
│   ├── test_bedrock_llm.py          # Bedrock Converse API smoke test
│   └── list_bedrock_models.py       # Lists available Bedrock foundation models
├── docs/
│   └── IMPLEMENTATION.md            # This document
└── logs/                            # Auto-created error log files
```
