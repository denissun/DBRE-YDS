# DiagAgent

An AI-powered **Oracle Database Performance Diagnostic Agent** powered by Google's Gemini LLM and LangGraph's ReAct framework. DiagAgent provides intelligent, automated analysis of Oracle database health, performance bottlenecks, and actionable remediation recommendations.

## Overview

DiagAgent is a multi-interface diagnostic assistant that combines AI reasoning with domain-specific database tools to help DBAs quickly identify and resolve performance issues. It uses the **ReAct (Reasoning + Acting)** paradigm to iteratively analyze database metrics and provide expert-level diagnostics.

### Key Architecture
- **LLM**: Google Gemini (ChatGoogleGenerativeAI)
- **Agent Framework**: LangGraph ReAct agent
- **Interfaces**: CLI (command-line) and Streamlit web UI
- **Database**: Oracle Database
- **Integration**: Backend REST APIs for database operations

## What It Does

DiagAgent helps DBAs answer questions like:
- "Is my database healthy?"
- "Why is my database slow?"
- "What SQL statements are consuming the most resources?"
- "Are there blocking sessions?"
- "Do I have tablespace issues?"
- "Which tables have missing or invalid indexes?"
- "What are my database wait events?"

## Key Features

### 1. **Intelligent Health Checks**
   - Real-time database health assessment
   - Wait event analysis (AVG Active Sessions)
   - CPU utilization tracking
   - Critical vs. Warning vs. Normal status classification

### 2. **Performance Diagnostics**
   - **Wait Event Analysis**: Identify top wait events and their impact on performance
   - **SQL Performance**: Identify slow queries and get execution plans
   - **Blocker Detection**: Find sessions blocking others
   - **Long-Running Queries**: Detect queries running longer than normal

### 3. **Space Management**
   - Tablespace usage monitoring
   - Storage capacity forecasting
   - Critical threshold alerts

### 4. **Index & Statistics Analysis**
   - Table index inspection and recommendations
   - Column statistics review
   - Identify missing, redundant, or invalid indexes
   - Missing statistics detection

### 5. **SQL Execution Plans**
   - Retrieve execution plans for specific SQL_IDs
   - Identify inefficiencies (full table scans, bad cardinality estimates, plan instability)
   - Shared pool analysis

### 6. **Multi-Database Support**
   - Run queries across multiple Oracle databases
   - Support for database groups
   - Configured database list management

### 7. **Custom SQL Execution**
   - Write and execute custom SQL queries
   - LLM can formulate SQL to investigate issues
   - Direct database access when needed

## Diagnostic Tools (Functions)

Each tool is a specialized diagnostic function that the AI agent can invoke:

| Tool | Purpose | Output |
|------|---------|--------|
| `check_db_health()` | Overall database health status | Health verdict + contributing factors |
| `check_waitevent()` | Top wait events in past 5 minutes | Wait event stats, AAS, % activity |
| `check_blockers()` | Identify blocking and waiting sessions | Blocker/waiter pairs with context |
| `check_long_running_sql()` | Find long-running SQL statements | Query IDs, runtime, resource consumption |
| `check_tablespace_usage()` | Monitor tablespace capacity | Usage %, thresholds, critical alerts |
| `get_xplan_sharedpool()` | Retrieve SQL execution plans | Plan details for specific SQL_ID |
| `get_object_owner()` | Identify object ownership | Owner, object type, creation date |
| `check_invalid_objects()` | Find invalid database objects | Status, type, compilation errors |
| `top_sql_by_elapsed_time_15min()` | Identify expensive SQL in last 15 min | SQL text, elapsed time, exec count |
| `run_sql()` | Execute custom SQL queries | Raw query results (LLM-friendly format) |
| `run_sql_databases()` | Execute SQL across multiple databases | Results from specified database(s) |

## Interfaces

### 1. **CLI Interface v2** (`app_cli2.py`)
Lightweight command-line interface with natural language interaction using local diagnostic tools.

```bash
python app_cli2.py

# Interactive session:
> What is the health status of database g4tpsdb?
> Show me the top wait events
> Find sessions blocking others
> Get the execution plan for SQL ID abc123
```

**Features**:
- Natural language queries
- Direct function invocation
- Logging to file
- Uses local Python tool functions (no external MCP required)
- REST API backend integration

### 1b. **CLI Interface v1** (`app_cli.py`)
Advanced command-line interface with SQLcl MCP (Model Context Protocol) integration - **self-contained and requires no external Python functions**.

```bash
python app_cli.py

# Interactive session:
> Connect to MYDB database
> How many employees earn more than 10000?
> Show me the top 5 customers by revenue
> What tables are available in the database?
```

**Key Characteristics** (app_cli.py):
- **Self-Contained**: No dependency on `/functions/` modules
- **MCP Protocol**: Uses SQLcl's Model Context Protocol for database access
- **Persistent Session**: Maintains single MCP connection across multiple queries
- **SQLcl Powered**: Requires SQLcl executable installed and `SQLCL_PATH` env var configured
- **Conversation Context**: Preserves conversation history for multi-turn interactions
- **Single or Batch Mode**: Can run interactively or accept single query via command-line argument

**Workflow**:
```
User Query
    ↓
[MCP Initialization] Load SQLcl MCP server (if first query)
    ↓
[Session Management] Reuse persistent MCP ClientSession
    ↓
[LLM Reasoning] Gemini analyzes query and decides next action
    ↓
[Tool Invocation] LLM calls MCP tools (SQL execution, table info, etc.)
    ↓
[Response] LLM synthesizes response from tool results
    ↓
[Conversation History] Store messages for context in next query
    ↓
Display to User
```

**Special Commands**:
- `help` / `h` - Show help and example queries
- `test` - Test SQLcl MCP connection
- `reset` / `restart` - Reset session and conversation history
- `clear` / `cls` - Clear terminal screen
- `quit` / `exit` / `q` - Exit program

**Prerequisites for app_cli.py**:
- SQLcl executable installed
- `SQLCL_PATH` environment variable pointing to SQLcl binary
- `GEMINI_API_KEY` set for Gemini LLM
- SQLcl must support MCP mode (`-mcp` flag)

**Session Management** (app_cli.py):
- **Persistent Connection**: Initializes MCP session once, reuses for all queries
- **Thread-Safe**: Uses `asyncio.Lock` to prevent concurrent initialization races
- **Graceful Cleanup**: Properly exits async contexts on shutdown
- **Error Recovery**: Tests MCP connection before interactive session

### Comparison: app_cli.py vs app_cli2.py

| Feature | app_cli.py (MCP-Based) | app_cli2.py (Local Tools) |
|---------|----------------------|--------------------------|
| **Architecture** | SQLcl MCP Server | Local Python Functions |
| **External Dependency** | Requires SQLcl binary | No external dependencies |
| **Session Management** | Persistent MCP connection | Per-query API calls |
| **Database Access** | Via SQLcl MCP protocol | Via REST API backend |
| **Tool Source** | SQLcl MCP tools | Python modules in `/functions/` |
| **Conversation Context** | Built-in history preservation | Manual history management |
| **Configuration** | SQLCL_PATH, GEMINI_API_KEY | DB_RUN_SQL_API, GEMINI_API_KEY |
| **Best For** | Direct SQLcl integration | DBA-specific diagnostics |
| **Flexibility** | Any SQL through MCP | Pre-built diagnostic tools |
| **Performance** | Single persistent connection | Stateless REST calls |

---

### 3. **Streamlit Web UI** (`app_streamlit.py`)
User-friendly web interface with chat-based interaction.

```bash
streamlit run app_streamlit.py
```

**Features**:
- Web-based chat interface
- Message history
- Real-time streaming responses
- File upload support
- Multi-session support
- Responsive design

## Detailed Workflow: app_cli.py

### 1. **Initialization Phase**
When the first query is received:

```python
async def initialize_session():
    # 1. Create stdio_client pointing to SQLcl MCP server
    _stdio_ctx = stdio_client(server_params)
    read, write = await _stdio_ctx.__aenter__()
    
    # 2. Create ClientSession with stdio pipes
    _client_session_ctx = ClientSession(read, write)
    _session = await _client_session_ctx.__aenter__()
    
    # 3. Initialize MCP protocol handshake
    await _session.initialize()
    
    # 4. Load available MCP tools from SQLcl
    _tools = await load_mcp_tools(_session)
    
    # 5. Create ReAct agent with Gemini + tools
    _agent = create_react_agent(model, _tools)
```

**Key Points**:
- Thread-safe initialization with `asyncio.Lock` prevents race conditions
- Session is cached globally for reuse across queries
- MCP handshake enables bidirectional communication with SQLcl

### 2. **Query Processing Phase**
For each user query:

```python
async def run_agent(query: str, conversation_history=None):
    # 1. Ensure session is initialized
    await initialize_session()
    
    # 2. Build message list with conversation history
    messages = conversation_history or []
    messages.append({"role": "user", "content": query})
    
    # 3. Run ReAct agent with 45-second timeout
    result = await asyncio.wait_for(
        _agent.ainvoke({"messages": messages}),
        timeout=45
    )
    
    # 4. Extract AI response from result
    last_message = result["messages"][-1]
    
    # 5. Return updated history + response
    return result["messages"], last_message
```

**Process Flow**:
1. **Thought**: Gemini analyzes query in context of conversation history
2. **Action**: Gemini decides which MCP tools to invoke
3. **Observation**: SQLcl executes requested actions (SQL, metadata queries, etc.)
4. **Loop**: Gemini may invoke multiple tools before responding
5. **Answer**: Final response synthesized from all observations

### 3. **Session Cleanup Phase**
On exit:

```python
async def cleanup_session():
    # Properly exit async contexts in correct order
    await _client_session_ctx.__aexit__(None, None, None)
    await _stdio_ctx.__aexit__(None, None, None)
    # Global references cleared
```

**Important**: Contexts must be exited in the same async task that entered them to avoid AnyIO cancel scope errors.

### 4. **Command Processing**
Main CLI loop handles:

```
Interactive Loop:
  ├─ Get User Input
  ├─ Check for Special Commands
  │  ├─ quit/exit/q → Exit program
  │  ├─ help/h → Show help menu
  │  ├─ clear/cls → Clear screen
  │  ├─ reset/restart → Reset session & history
  │  ├─ test → Test MCP connection
  │  └─ [Any other input] → Process as query
  ├─ Run Agent with History
  ├─ Update Conversation History
  ├─ Display Response
  └─ Repeat (unless quit)
```

---

## ReAct Framework

DiagAgent implements the ReAct (Reasoning + Acting) paradigm:

```
User Query
    ↓
[THOUGHT] LLM reasons about the problem
    ↓
[ACTION] LLM selects appropriate tool(s)
    ↓
[OBSERVATION] Tool executes and returns results
    ↓
[THOUGHT] LLM analyzes results
    ↓
[ACTION/ANSWER] Either call more tools or provide final answer
    ↓
Final Response to User
```

This iterative loop continues until the agent reaches a conclusive diagnosis.

## Expert System Behavior

The AI operates as an **expert Oracle DBA** following these principles:

1. **Data-Driven**: All recommendations backed by metrics from `gv$active_session_history`, `gv$sql`, etc.
2. **Threshold-Aware**: Interprets metrics against configured thresholds (wait events, AAS, replication lag)
3. **Context-Sensitive**: Ignores noise (e.g., AAS < 4, SharePlex backlog < 5000)
4. **Safety-First**: Never fabricates metrics; states when data is insufficient
5. **Actionable**: Provides specific remediation steps with rationale and expected impact

### Health Status Interpretation

- **Healthy**: Low workload or no significant wait events exceeding AAS > 3
- **Degraded**: Multiple wait events or single high-impact event
- **Critical**: Severe contention, blocked sessions, or space exhaustion

## Setup & Configuration

### Prerequisites
- Python 3.8+
- Google Gemini API key
- Access to Oracle database(s) via REST backend
- Backend API for `db_run_sql` endpoint

### Installation

```bash
# Install dependencies (Linux)
pip install -r requirements_linux.txt

# Or Windows
pip install -r requirements_win.txt

# Copy .env.example to .env and configure
cp .env.example .env
```

### Configuration Files

**`.env`** - Environment variables for app_cli2.py (Local Tools):
```bash
GEMINI_API_KEY=your-api-key
DB_RUN_SQL_API=http://dbaets.linuxhost1.com/dbaets/api/db_run_sql
APP_LOG_LEVEL=INFO
```

**`.env`** - Environment variables for app_cli.py (SQLcl MCP):
```bash
GEMINI_API_KEY=your-api-key
SQLCL_PATH=/path/to/sqlcl/bin/sql
# Optional proxy settings (if required)
HTTP_PROXY=http://proxy.mycompany.com:80
HTTPS_PROXY=http://proxy.mycompany.com:80
```

**`config.py`** - Hardcoded settings:
```python
SUPPORTED_DATABASES = [
    "proddb",      # Production OLTP
    "oratst",      # Test environment
    "billdb",      # Billing validation
    "reportdb",    # Reporting
    "anadb"        # Analytics
]

WAIT_EVENT_THRESHOLDS = {
    "critical": 1000,  # milliseconds
    "warning": 500,
    "normal": 100
}
```

**`system_prompt.py`** - AI behavior specification:
```python
system_prompt = """
You are an expert Oracle database problem diagnosis agent.
[Expert instructions, tool guidance, interpretation rules, response format]
"""
```

## Running DiagAgent

### CLI Mode - Version 2 (Local Tools)
```bash
python app_cli2.py
```

Interactive session with diagnostic queries:
```
> What's the overall health of g4tpsdb?
> Show me top 5 wait events
> Find long-running queries
> Check tablespace usage
> Show me invalid objects in the database
```

**Use When**:
- You have REST API backend configured
- You want pre-built DBA diagnostic tools
- No SQLcl executable available

### CLI Mode - Version 1 (MCP-Based)
```bash
# Interactive mode
python app_cli.py

# Single query mode (exit after answer)
python app_cli.py "How many tables are in the database?"

# Single query from script
python app_cli.py "SELECT COUNT(*) FROM user_tables"
```

**Interactive Session Example**:
```
💬 Enter your question: Connect to MYDB database
✅ Agent Response:
Connected to MYDB database successfully.

💬 Enter your question: Show me the top 5 customers by sales
✅ Agent Response:
[Query results from SQLcl MCP]

💬 Enter your question: help
📋 Available Commands:
  help, h          - Show this help message
  quit, exit, q    - Exit the program
  clear, cls       - Clear the screen
  reset, restart   - Reset session and conversation history
  test             - Test SQLcl MCP connection

💡 Example queries:
  • Connect to MYDB database
  • How many employees earn more than 10000?
  • Show me the top 5 customers by revenue

💬 Enter your question: test
🧪 Testing SQLcl MCP connection...
✅ SQLcl MCP test successful!

💬 Enter your question: quit
👋 Goodbye!
```

**Use When**:
- You have SQLcl installed with MCP support
- You want general SQL query capabilities
- You need conversation context preservation

### Web UI Mode
```bash
streamlit run app_streamlit.py
```

Open browser to `http://localhost:8501`

## Example Workflow

**Scenario**: DBA reports database is slow.

1. **Query**: "Why is database g4tpsdb slow?"

2. **Agent Actions**:
   - Calls `check_db_health()` → Gets health verdict
   - Calls `check_waitevent()` → Identifies top wait event
   - Calls `top_sql_by_elapsed_time_15min()` → Finds expensive SQL
   - Calls `get_xplan_sharedpool()` → Gets execution plan

3. **Analysis**: LLM reasons:
   - "Disk I/O is high (db file sequential read)"
   - "Full table scan on ORDERS table"
   - "Missing index on ORDER_DATE column"

4. **Response**:
   ```
   Health Status: Degraded
   
   Issue: High disk I/O due to full table scans on ORDERS table
   
   Root Cause: Missing index on ORDER_DATE column used in WHERE clause
   
   Recommendations:
   1. CREATE INDEX idx_orders_date ON orders(order_date)
   2. Gather statistics on ORDERS table
   3. Monitor wait events after index creation
   
   Expected Impact: 60-80% reduction in disk I/O
   ```

## Logging

Logs are written to `logs/` directory:
- `diagagent.log` - CLI session logs
- `diagagent_streamlit.log` - Streamlit session logs

Log level controlled by `APP_LOG_LEVEL` environment variable (INFO, DEBUG, ERROR, etc.)

## Technical Stack

- **LLM Framework**: LangChain + LangGraph
- **LLM Model**: Google Gemini (generative-ai API)
- **CLI**: Native Python (no framework)
- **Web UI**: Streamlit
- **Database**: Oracle Database (via REST API backend)
- **Async**: Built-in support for concurrent tool calls

## Limitations & Future Enhancements

### Current Limitations
- Requires backend REST API for database queries
- Single LLM call chain per query (no multi-turn learning)
- Read-only (no DDL/DML execution through agent)

### Future Enhancements
- Memory/context persistence across sessions
- Real-time metrics streaming
- Automated remediation actions (with approval)
- Multi-language support
- Integration with monitoring systems (Grafana, Prometheus)

## References

- [ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/abs/2210.03629)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [Oracle Database Documentation](https://docs.oracle.com/)
- [Google Gemini API](https://ai.google.dev/)
