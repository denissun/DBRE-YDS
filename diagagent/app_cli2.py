#!/usr/bin/env python3
"""
Lightweight CLI (v2) that ONLY uses local function tools (no MCP / SQLcl).
Provides natural language interaction via Gemini model plus direct tool invocation.
"""

import os
import sys
import asyncio
import logging
import inspect
import shlex
from logging.handlers import RotatingFileHandler
from dotenv import load_dotenv

from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.prebuilt import create_react_agent
from langchain.tools import StructuredTool
from langchain_core.messages import AIMessage

# Local tools
from functions.check_tablespace_usage import check_tablespace_usage
from functions.check_waitevent import check_waitevent
from functions.check_blockers import check_blockers
from functions.check_long_running_sql import check_long_running_sql
from functions.get_xplan_sharedpool import get_xplan_sharedpool
from functions.get_object_owner import get_object_owner
from functions.check_invalid_objects import check_invalid_objects
from functions.top_sql_by_elapsed_time_15min import top_sql_by_elapsed_time_15min
from functions.run_sql import run_sql
from functions.run_sql_databases import run_sql_databases  # new multi-db SQL tool

# Optional system prompt
try:
    from system_prompt import system_prompt  # may exist at project root
except Exception:
    system_prompt = "You are a helpful Oracle database diagnostic assistant using only local tools."  # fallback

load_dotenv()

# ---------------- Logging ----------------
LOG_LEVEL = os.environ.get("APP_LOG_LEVEL", "INFO").upper()
LOG_FORMAT = "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
LOGGER_NAME = "diagagent.app2"

logger = logging.getLogger(LOGGER_NAME)
if not logger.handlers:
    logger.setLevel(LOG_LEVEL)
    ch = logging.StreamHandler()
    ch.setFormatter(logging.Formatter(LOG_FORMAT))
    ch.setLevel(LOG_LEVEL)
    logger.addHandler(ch)
    # rotating file
    base_dir = os.path.dirname(os.path.abspath(__file__))
    logs_dir = os.path.join(base_dir, "logs")
    os.makedirs(logs_dir, exist_ok=True)
    fh = RotatingFileHandler(os.path.join(logs_dir, "diagagent2.log"), maxBytes=5_000_000, backupCount=3, encoding="utf-8")
    fh.setFormatter(logging.Formatter(LOG_FORMAT))
    fh.setLevel(LOG_LEVEL)
    logger.addHandler(fh)
logger.debug("Logging initialized level=%s", LOG_LEVEL)

# ------------- Model (optional) -------------
_api_key = os.environ.get("GEMINI_API_KEY")
_model = None

_tools = []  # List[Tool]
_agent = None
_conversation_history = []  # list of dict(role, content)
_history_lock = asyncio.Lock()  # protects _conversation_history mutations
_init_lock = asyncio.Lock()
_context_state = {  # carries forward implicit parameters
    "db_name": None,
    "table_name": None,  # or object_name
    "schema_name": None,  # owner/schema for object
}


def _extract_context_from_query(query: str):
    """Extract db_name and table/object name from the raw user query.

    Heuristics:
      - db_name=NAME pattern
      - explicit token matching SUPPORTED_DATABASES if prefixed by 'for', 'on', 'in', 'against'
      - table=NAME or object=NAME or object_name=NAME pattern
    Returns dict of discovered values (None if unchanged).
    """
    from config import SUPPORTED_DATABASES  # type: ignore
    import re
    found = {}
    q_lower = query.lower()

    # db_name= pattern
    m = re.search(r"db_name\s*=\s*([A-Za-z0-9_\-]+)", query)
    if m:
        found["db_name"] = m.group(1)
    else:
        # look for standalone supported db tokens preceded by prepositions
        tokens = set(SUPPORTED_DATABASES)
        # simple split; maintain original tokens
        words = query.split()
        for i, w in enumerate(words):
            raw = w.strip(',.;:')
            if raw in tokens and i > 0 and words[i-1].lower() in {"for", "on", "in", "against", "to"}:
                found["db_name"] = raw
                break

    # table= or object=  (object and object_name treated as same)
    m2 = re.search(r"(table|object|object_name)\s*=\s*([A-Za-z0-9_\$#]+)", query, re.IGNORECASE)
    if m2:
        found["table_name"] = m2.group(2)
    else:
        # a crude heuristic: 'table <name>' or 'object <name>'
        m3 = re.search(r"\btable\s+([A-Za-z0-9_\$#]+)", query, re.IGNORECASE)
        if m3:
            found["table_name"] = m3.group(1)
        else:
            m4 = re.search(r"\bobject\s+([A-Za-z0-9_\$#]+)", query, re.IGNORECASE)
            if m4:
                found["table_name"] = m4.group(1)

    # schema / owner
    m5 = re.search(r"(schema|owner)\s*=\s*([A-Za-z0-9_\$#]+)", query, re.IGNORECASE)
    if m5:
        found["schema_name"] = m5.group(2)

    # simple phrase 'in schema X' or 'from schema X'
    m6 = re.search(r"(in|from)\s+schema\s+([A-Za-z0-9_\$#]+)", query, re.IGNORECASE)
    if m6:
        found["schema_name"] = m6.group(2)

    return found


def _build_context_system_message():
    parts = []
    if _context_state.get("db_name"):
        parts.append(f"db_name={_context_state['db_name']}")
    if _context_state.get("table_name"):
        parts.append(f"table_name={_context_state['table_name']}")
    if _context_state.get("schema_name"):
        parts.append(f"schema_name={_context_state['schema_name']}")
    if not parts:
        return None
    return (
        "Context memory: If the user does not explicitly specify these parameters in the current turn, "
        "assume they refer to previous values: " + ", ".join(parts) + ". If user supplies new values, update the context accordingly."
    )


def _build_tools():
    global _tools
    if _tools:
        return _tools
    # Register check_tablespace_usage
    try:
        tool2 = StructuredTool.from_function(
            func=check_tablespace_usage,
            name="check_tablespace_usage",
            description="Check tablespace usage. Params: db_name (str), limit (int=50)"
        )
        _tools.append(tool2)
    except Exception as e:
        logger.exception("Failed to register check_tablespace_usage: %s", e)
    # Register check_waitevent
    try:
        tool3 = StructuredTool.from_function(
            func=check_waitevent,
            name="check_waitevent",
            description="Check wait event stats. Params: db_name (str), limit (int=50)"
        )
        _tools.append(tool3)
    except Exception as e:
        logger.exception("Failed to register check_waitevent: %s", e)
    # Register check_blockers
    try:
        tool4 = StructuredTool.from_function(
            func=check_blockers,
            name="check_blockers",
            description="Check blocking sessions. Params: db_name (str), limit (int=50)"
        )
        _tools.append(tool4)
    except Exception as e:
        logger.exception("Failed to register check_blockers: %s", e)
    # Register check_long_running_sql
    try:
        tool5 = StructuredTool.from_function(
            func=check_long_running_sql,
            name="check_long_running_sql",
            description="Check long running SQL. Params: db_name (str), limit (int=50)"
        )
        _tools.append(tool5)
    except Exception as e:
        logger.exception("Failed to register check_long_running_sql: %s", e)
    # Register get_xplan_sharedpool
    try:
        tool6 = StructuredTool.from_function(
            func=get_xplan_sharedpool,
            name="get_xplan_sharedpool",
            description="Get execution plan or xplan from shared pool. Params: db_name (str), sql_id "
        )
        _tools.append(tool6)
    except Exception as e:
        logger.exception("Failed to register get_xplan_sharedpool: %s", e)
    # Register get_object_owner
    try:
        tool7 = StructuredTool.from_function(
            func=get_object_owner,
            name="get_object_owner",
            description="Get object owner metadata. Params: db_name (str), object_name (str)"
        )
        _tools.append(tool7)
    except Exception as e:
        logger.exception("Failed to register get_object_owner: %s", e)
    # Register check_invalid_objects
    try:
        tool8 = StructuredTool.from_function(
            func=check_invalid_objects,
            name="check_invalid_objects",
            description="List invalid database objects. Params: db_name (str), limit (int=100)"
        )
        _tools.append(tool8)
    except Exception as e:
        logger.exception("Failed to register check_invalid_objects: %s", e)
    # Register top_sql_by_elapsed_time_15min
    try:
        tool9 = StructuredTool.from_function(
            func=top_sql_by_elapsed_time_15min,
            name="top_sql_by_elapsed_time_15min",
            description="Top SQL (last 15m) avg elapsed >1s. Params: db_name (str), limit (int=50)"
        )
        _tools.append(tool9)
    except Exception as e:
        logger.exception("Failed to register top_sql_by_elapsed_time_15min: %s", e)
    # Register run_sql (generic SQL runner)
    try:
        tool10 = StructuredTool.from_function(
            func=run_sql,
            name="run_sql",
            description="Run arbitrary SQL via DBAETS. Params: db_name (str), sql_text (str), limit (int=500)"
        )
        _tools.append(tool10)
    except Exception as e:
        logger.exception("Failed to register run_sql: %s", e)
    # Register run_sql_databases (multi-database SQL runner)
    try:
        tool_multi = StructuredTool.from_function(
            func=run_sql_databases,
            name="run_sql_databases",
            description="Run arbitrary SQL against multiple databases. Params: databases (List[str]), sql_text (str), limit (int=100)"
        )
        _tools.append(tool_multi)
    except Exception as e:
        logger.exception("Failed to register run_sql_databases: %s", e)
    logger.info("Registered %d local tools", len(_tools))
    return _tools


async def _ensure_agent():
    global _agent, _model
    if _agent:
        return _agent
    async with _init_lock:
        if _agent:
            return _agent
        _build_tools()
        if _api_key:
            _model = ChatGoogleGenerativeAI(
                model="gemini-2.0-flash-001",
                google_api_key=_api_key,
                request_timeout=30,
                max_retries=3,
            )
            _agent = create_react_agent(_model, _tools)
            logger.info("Agent created with %d tools", len(_tools))
        else:
            logger.warning("GEMINI_API_KEY not set. Falling back to tool-only mode (no LLM reasoning).")
            _agent = None
        return _agent


async def run_query(query: str):
    """Run a natural language query through the agent ensuring we don't re-answer old questions.

    We now persist BOTH the user and assistant turns (previous version stored only user turns),
    preventing the model from seeing consecutive user-only messages which caused it to sometimes
    answer an earlier question again. History is trimmed to the most recent 40 messages (20 turns).
    """
    agent = await _ensure_agent()

    if not agent:
        return AIMessage(content="LLM disabled (no API key). You can run tools directly: /tools or /run <tool> ...")

    # Extract / update context BEFORE building the message list
    try:
        extracted = _extract_context_from_query(query)
        # Update global context (only keys present)
        for k, v in extracted.items():
            if v:
                _context_state[k] = v
    except Exception as e:  # non-fatal
        logger.debug("Context extraction failed: %s", e)

    ctx_msg = _build_context_system_message()

    async with _history_lock:
        # Build full message list with system prompt always first (not stored in history list itself)
        messages = [{"role": "system", "content": system_prompt}]
        if ctx_msg:
            messages.append({"role": "system", "content": ctx_msg})
        messages.extend(_conversation_history)
        messages.append({"role": "user", "content": query})

    logger.info("Processing NL query len=%d history_msgs=%d", len(query), len(_conversation_history))
    try:
        result = await agent.ainvoke({"messages": messages})

        # Extract last assistant message (agent returns a dict with messages list)
        if isinstance(result, dict) and result.get("messages"):
            last_msg = None
            for m in reversed(result["messages"]):
                # find the last assistant/ai message
                role = getattr(m, 'type', None) or getattr(m, 'role', None) or (isinstance(m, dict) and m.get('role'))
                if role in ("assistant", "ai"):
                    last_msg = m
                    break
            if last_msg is None:
                last_msg = result["messages"][-1]

            # Persist conversation turn (user + assistant) atomically
            async with _history_lock:
                _conversation_history.append({"role": "user", "content": query})
                # Normalize assistant message content
                content = getattr(last_msg, 'content', None)
                if content is None and isinstance(last_msg, dict):
                    content = last_msg.get('content', str(last_msg))
                _conversation_history.append({"role": "assistant", "content": content})
                # Trim to last 40 messages (~20 turns)
                if len(_conversation_history) > 40:
                    del _conversation_history[:-40]

            return last_msg if hasattr(last_msg, "content") else AIMessage(content=str(last_msg))

        # Fallback: treat the entire result as assistant reply
        async with _history_lock:
            _conversation_history.append({"role": "user", "content": query})
            _conversation_history.append({"role": "assistant", "content": str(result)})
            if len(_conversation_history) > 40:
                del _conversation_history[:-40]
        return AIMessage(content=str(result))
    except Exception as e:
        logger.exception("Agent error: %s", e)
        return AIMessage(content=f"Error: {type(e).__name__}: {e}")


def _list_tools():
    return [f"{t.name}: {getattr(t, 'description', '')}" for t in _tools]


def _direct_tool_call(parts):
    if len(parts) < 2:
        return "Usage: /run <tool_name> [key=value | positional...]"
    name = parts[1]
    tool = next((t for t in _tools if t.name == name), None)
    if not tool:
        return f"Unknown tool '{name}'. Use /tools to list."\

    # Parse simple key=value args; others treated as positional text values
    kwargs = {}
    positional = []
    for p in parts[2:]:
        if '=' in p:
            k, v = p.split('=', 1)
            # cast booleans
            if v.lower() in ('true', 'false'):
                v = v.lower() == 'true'
            kwargs[k] = v
        else:
            positional.append(p)
    # If db_name missing and we have context, inject
    if 'db_name' not in kwargs and _context_state.get('db_name'):
        kwargs['db_name'] = _context_state['db_name']
    # Map potential table/object fallback
    if 'object_name' not in kwargs and 'table_name' not in kwargs:
        if _context_state.get('table_name'):
            # choose object_name param if tool expects object; user might call get_object_owner
            kwargs.setdefault('object_name', _context_state['table_name'])
    # If we have positional args, map them to the tool function signature
    if positional:
        try:
            func = getattr(tool, 'func', None)
            if func is not None:
                sig = inspect.signature(func)
                param_names = [p.name for p in sig.parameters.values() if p.kind in (p.POSITIONAL_ONLY, p.POSITIONAL_OR_KEYWORD)]
                # Fill kwargs in order; if extra positional remain and the last param is likely a free-text, join the rest
                for i, pname in enumerate(param_names):
                    if i >= len(positional):
                        break
                    if i == len(param_names) - 1 and len(positional) - i > 1:
                        # join remaining tokens for final parameter (e.g., sql_text)
                        kwargs.setdefault(pname, " ".join(positional[i:]))
                        break
                    else:
                        kwargs.setdefault(pname, positional[i])
        except Exception as e:
            logger.debug("Positional mapping failed, falling back to string input: %s", e)
            # As a last resort, pass a single string
            if not kwargs:
                kwargs = {"input": " ".join(positional)}

    try:
        # If both exist, pass kwargs; user should map names correctly
        result = tool.run(kwargs if kwargs else "")  # type: ignore
        return result
    except Exception as e:
        logger.exception("Tool execution failed: %s", e)
        return f"Tool error: {e}"


BANNER = """
============================================================
🔮Oracle Database Issue Diagnostic AI Agent CLI v2
============================================================
Type natural language questions OR use control commands:
    /help        Show help
    /quit        Exit
    /reset       Clear conversation
    /tools       List available tools
        /run <tool>  Run a tool directly (e.g., /run check_tablespace_usage db_name=g4tpsdb)
------------------------------------------------------------
"""

HELP_TEXT = """Commands:
    /help              Show this help
    /quit (/exit)      Exit
    /reset             Reset conversation context
    /context           Show current remembered db / table / schema
    /set k=v [...]     Set context values manually (db_name=, table=, schema=)
    /tools             List local tools
    /run <tool> ...    Run a tool directly
Examples:
    /run check_tablespace_usage db_name=g4tpsdb
    /run check_waitevent db_name=g4tpsdb
Natural language example:
    Show current tablespace usage for g4tpsdb.
Context memory: If you omit db_name or table/object name, the last used values are assumed.
"""


def print_banner():
    print(BANNER)
    # Dynamically show supported databases from config
    try:
        from config import SUPPORTED_DATABASES  # type: ignore
        if SUPPORTED_DATABASES:
            print("Supported databases ({} total):".format(len(SUPPORTED_DATABASES)))
            line = []
            for i, db in enumerate(SUPPORTED_DATABASES, 1):
                line.append(db)
                if i % 8 == 0:
                    print("  " + ", ".join(line))
                    line = []
            if line:
                print("  " + ", ".join(line))
        else:
            print("Supported databases list is empty in config.py")
    except Exception:
        print("(Could not load SUPPORTED_DATABASES from config.py)")


def print_help():
    print(HELP_TEXT)
def print_context():
    print("Current context memory:")
    for k in ["db_name", "table_name", "schema_name"]:
        print(f"  {k}: {_context_state.get(k) or '-'}")

    # Show supported databases
    try:
        from config import SUPPORTED_DATABASES  # type: ignore
        if SUPPORTED_DATABASES:
            print("Supported databases ({} total):".format(len(SUPPORTED_DATABASES)))
            line = []
            for i, db in enumerate(SUPPORTED_DATABASES, 1):
                line.append(db)
                if i % 8 == 0:
                    print("  " + ", ".join(line))
                    line = []
            if line:
                print("  " + ", ".join(line))
        else:
            print("(No supported databases defined in config.py)")
    except Exception:
        print("(Could not load SUPPORTED_DATABASES from config.py)")


async def main():
    print_banner()
    _build_tools()
    while True:
        try:
            raw = input("💬 > ").strip()
            if not raw:
                continue
            lower = raw.lower()
            if lower in ("/quit", "/exit", "quit", "exit", "q"):
                print("👋 Bye")
                break
            if lower in ("/help", "help", "h"):
                print_help()
                continue
            if lower in ("/reset", "reset"):
                _conversation_history.clear()
                _context_state["db_name"] = None
                _context_state["table_name"] = None
                _context_state["schema_name"] = None
                print("✅ Conversation & context reset")
                continue
            if lower in ("/context", "context"):
                print_context()
                continue
            if lower.startswith("/set"):
                # /set key=value ...
                parts = raw.split()
                changed = []
                for p in parts[1:]:
                    if '=' in p:
                        k, v = p.split('=', 1)
                        key_map = {
                            'table': 'table_name',
                            'object': 'table_name',
                            'object_name': 'table_name',
                            'schema': 'schema_name',
                            'owner': 'schema_name'
                        }
                        k_norm = key_map.get(k, k)
                        if k_norm in _context_state:
                            _context_state[k_norm] = v
                            changed.append(f"{k_norm}={v}")
                if changed:
                    print("Updated context: " + ", ".join(changed))
                else:
                    print("No valid context keys provided. Use db_name=, table=, schema=")
                continue
            if lower in ("/tools", "tools"):
                for line in _list_tools():
                    print(" •", line)
                continue
            if lower.startswith("/run "):
                try:
                    parts = shlex.split(raw)
                except Exception:
                    parts = raw.split()
                print(_direct_tool_call(parts))
                continue

            # Natural language path
            msg = await run_query(raw)
            if isinstance(msg, AIMessage):
                print(msg.content)
            else:
                print(msg)
        except KeyboardInterrupt:
            print("\n👋 Interrupted")
            break
        except EOFError:
            print("\n👋 EOF")
            break
        except Exception as e:
            logger.exception("Loop error: %s", e)
            print(f"Error: {e}")


def run_single_query(text: str):
    async def _once():
        res = await run_query(text)
        if isinstance(res, AIMessage):
            print(res.content)
        else:
            print(res)
    asyncio.run(_once())


if __name__ == "__main__":
    if len(sys.argv) > 1:
        run_single_query(" ".join(sys.argv[1:]))
    else:
        asyncio.run(main())
