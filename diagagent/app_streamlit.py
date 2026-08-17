#!/usr/bin/env python3
"""
Streamlit web interface for Oracle database diagnostic assistant. 
Provides the same functionality as app_cli2.py but with a GUI interface.
"""

import os
import sys
import json
import logging
from typing import List, Dict, Any, Optional, Tuple
import streamlit as st
from logging.handlers import RotatingFileHandler
from dotenv import load_dotenv

# Streamlit quirk - need to add parent directory to path for local imports
import inspect
currentdir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parentdir = os.path.dirname(currentdir)
if parentdir not in sys.path:
    sys.path.insert(0, parentdir)

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
from functions.run_sql_databases import run_sql_databases  # multi-database SQL runner

# Optional system prompt
try:
    from system_prompt import system_prompt  # may exist at project root
except Exception:
    system_prompt = "You are a helpful Oracle database diagnostic assistant using only local tools."  # fallback

# ------------- Configure logging -------------
def setup_logging():
    LOG_LEVEL = os.environ.get("APP_LOG_LEVEL", "INFO").upper()
    LOG_FORMAT = "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
    LOGGER_NAME = "diagagent.streamlit"

    logger = logging.getLogger(LOGGER_NAME)
    if not logger.handlers:
        logger.setLevel(LOG_LEVEL)
        # rotating file
        base_dir = os.path.dirname(os.path.abspath(__file__))
        logs_dir = os.path.join(base_dir, "logs")
        os.makedirs(logs_dir, exist_ok=True)
        fh = RotatingFileHandler(os.path.join(logs_dir, "diagagent_streamlit.log"), maxBytes=5_000_000, backupCount=3, encoding="utf-8")
        fh.setFormatter(logging.Formatter(LOG_FORMAT))
        fh.setLevel(LOG_LEVEL)
        logger.addHandler(fh)
    return logger
    
# ------------- Get system prompts -------------
def get_system_prompts():
    """Get available system prompts from system_prompt.py"""
    prompts = {}
    
    # Try to import the system_prompt module
    try:
        import sys
        import inspect
        from importlib import import_module
        
        # Import the module
        module = import_module('system_prompt')
        
        # Get all attributes that might be system prompts
        for name, value in inspect.getmembers(module):
            if name.startswith('system_prompt') and isinstance(value, str):
                # Clean up the name for display
                display_name = name.replace('system_prompt', 'Default')
                if display_name == 'Default':
                    display_name = 'Default'
                elif display_name == 'Default2':
                    display_name = 'Extended'
                prompts[display_name] = value
    except Exception as e:
        # If import fails, provide a fallback prompt
        prompts['Default'] = "You are a helpful Oracle database diagnostic assistant using only local tools."
        
    # If no prompts found, add the fallback
    if not prompts:
        prompts['Default'] = "You are a helpful Oracle database diagnostic assistant using only local tools."
        
    return prompts

# ------------- Tool management -------------
def build_tools():
    """Register all diagnostic tools and return the list."""
    tools = []
    logger = logging.getLogger("diagagent.streamlit")
    
    # Register check_tablespace_usage
    try:
        tool = StructuredTool.from_function(
            func=check_tablespace_usage,
            name="check_tablespace_usage",
            description="Check tablespace usage. Params: db_name (str), limit (int=50)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register check_tablespace_usage: %s", e)

    # Register check_waitevent
    try:
        tool = StructuredTool.from_function(
            func=check_waitevent,
            name="check_waitevent",
            description="Check wait event stats. Params: db_name (str), limit (int=50)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register check_waitevent: %s", e)

    # Register check_blockers
    try:
        tool = StructuredTool.from_function(
            func=check_blockers,
            name="check_blockers",
            description="Check blocking sessions. Params: db_name (str), limit (int=50)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register check_blockers: %s", e)

    # Register check_long_running_sql
    try:
        tool = StructuredTool.from_function(
            func=check_long_running_sql,
            name="check_long_running_sql",
            description="Check long running SQL. Params: db_name (str), limit (int=50)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register check_long_running_sql: %s", e)

    # Register get_xplan_sharedpool
    try:
        tool = StructuredTool.from_function(
            func=get_xplan_sharedpool,
            name="get_xplan_sharedpool",
            description="Get execution plan or xplan from shared pool. Params: db_name (str), sql_id"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register get_xplan_sharedpool: %s", e)

    # Register get_object_owner
    try:
        tool = StructuredTool.from_function(
            func=get_object_owner,
            name="get_object_owner",
            description="Get object owner metadata. Params: db_name (str), object_name (str)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register get_object_owner: %s", e)

    # Register check_invalid_objects
    try:
        tool = StructuredTool.from_function(
            func=check_invalid_objects,
            name="check_invalid_objects",
            description="List invalid database objects. Params: db_name (str), limit (int=100)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register check_invalid_objects: %s", e)

    # Register top_sql_by_elapsed_time_15min
    try:
        tool = StructuredTool.from_function(
            func=top_sql_by_elapsed_time_15min,
            name="top_sql_by_elapsed_time_15min",
            description="Top SQL (last 15m) avg elapsed >1s. Params: db_name (str), limit (int=50)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register top_sql_by_elapsed_time_15min: %s", e)

    # Register run_sql (generic SQL runner)
    try:
        tool = StructuredTool.from_function(
            func=run_sql,
            name="run_sql",
            description="Run arbitrary SQL via DBAETS. Params: db_name (str), sql_text (str), limit (int=500)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register run_sql: %s", e)

    # Register run_sql_databases (multi-database SQL runner)
    try:
        tool = StructuredTool.from_function(
            func=run_sql_databases,
            name="run_sql_databases",
            description="Run arbitrary SQL against multiple databases. Params: databases (List[str]), sql_text (str), limit (int=100)"
        )
        tools.append(tool)
    except Exception as e:
        logger.exception("Failed to register run_sql_databases: %s", e)

    logger.info("Registered %d local tools", len(tools))
    return tools

# ------------ Context extraction -------------
def extract_context_from_query(query: str):
    """Extract db_name and table/object name from the raw user query.
    
    Returns dict of discovered values.
    """
    from config import SUPPORTED_DATABASES
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
        # a crude heuristic: 'table <n>' or 'object <n>'
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

def build_context_system_message(context_state):
    """Build system message with context info."""
    parts = []
    if context_state.get("db_name"):
        parts.append(f"db_name={context_state['db_name']}")
    if context_state.get("table_name"):
        parts.append(f"table_name={context_state['table_name']}")
    if context_state.get("schema_name"):
        parts.append(f"schema_name={context_state['schema_name']}")
    
    if not parts:
        return None
        
    return (
        "Context memory: If the user does not explicitly specify these parameters in the current turn, "
        "assume they refer to previous values: " + ", ".join(parts) + ". If user supplies new values, update the context accordingly."
    )

# ------------ Agent setup -------------
def ensure_agent(tools):
    """Create and return the agent if API key available."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return None
        
    model = ChatGoogleGenerativeAI(
        model="gemini-2.0-flash-001",
        google_api_key=api_key,
        request_timeout=30,
        max_retries=3,
    )
    agent = create_react_agent(model, tools)
    return agent

# ------------ Run query -------------
def run_query(query: str, conversation_history, context_state, agent, tools, logger):
    """Run a natural language query through the agent."""
    if not agent:
        return AIMessage(content="LLM disabled (no API key). You can run tools directly using the Tools tab."), conversation_history, context_state

    # Extract / update context from query
    try:
        extracted = extract_context_from_query(query)
        # Update context state with extracted values
        for k, v in extracted.items():
            if v:
                context_state[k] = v
    except Exception as e:
        logger.debug("Context extraction failed: %s", e)

    ctx_msg = build_context_system_message(context_state)

    # Build full message list for the agent, using the active custom system prompt
    active_prompt = st.session_state.get("active_system_prompt", system_prompt)
    messages = [{"role": "system", "content": active_prompt}]
    if ctx_msg:
        messages.append({"role": "system", "content": ctx_msg})
    messages.extend(conversation_history)
    messages.append({"role": "user", "content": query})

    logger.info("Processing query len=%d history_msgs=%d", len(query), len(conversation_history))
    try:
        # Using synchronous invoke
        result = agent.invoke({"messages": messages})

        # Extract last assistant message
        if isinstance(result, dict) and result.get("messages"):
            last_msg = None
            for m in reversed(result["messages"]):
                role = getattr(m, 'type', None) or getattr(m, 'role', None) or (isinstance(m, dict) and m.get('role'))
                if role in ("assistant", "ai"):
                    last_msg = m
                    break
            if last_msg is None:
                last_msg = result["messages"][-1]

            # Add to conversation history
            conversation_history.append({"role": "user", "content": query})
            
            # Normalize assistant message content
            content = getattr(last_msg, 'content', None)
            if content is None and isinstance(last_msg, dict):
                content = last_msg.get('content', str(last_msg))
            conversation_history.append({"role": "assistant", "content": content})
            
            # Trim to last 40 messages (~20 turns)
            if len(conversation_history) > 40:
                conversation_history = conversation_history[-40:]

            return last_msg if hasattr(last_msg, "content") else AIMessage(content=str(last_msg)), conversation_history, context_state

        # Fallback for unexpected response format
        conversation_history.append({"role": "user", "content": query})
        conversation_history.append({"role": "assistant", "content": str(result)})
        if len(conversation_history) > 40:
            conversation_history = conversation_history[-40:]
        return AIMessage(content=str(result)), conversation_history, context_state
    except Exception as e:
        logger.exception("Agent error: %s", e)
        return AIMessage(content=f"Error: {type(e).__name__}: {e}"), conversation_history, context_state

# ------------ Run tool directly -------------
def run_tool_directly(tool_name, params, context_state, tools, logger):
    """Run a specific tool with parameters."""
    tool = next((t for t in tools if t.name == tool_name), None)
    if not tool:
        return f"Unknown tool '{tool_name}'. Please select from the dropdown."
    
    # Apply context if needed
    if 'db_name' not in params and context_state.get('db_name'):
        params['db_name'] = context_state['db_name']
    
    # Apply table/object context
    if 'object_name' not in params and 'table_name' not in params:
        if context_state.get('table_name'):
            # choose object_name param if tool expects object
            params.setdefault('object_name', context_state['table_name'])
    
    # Handle positional parameters (if we add direct command input later)
    if isinstance(params, list) and len(params) > 0:
        kwargs = {}
        positional = params
        
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
                
                # Apply context
                if 'db_name' not in kwargs and context_state.get('db_name'):
                    kwargs['db_name'] = context_state['db_name']
                params = kwargs
        except Exception as e:
            logger.debug("Positional mapping failed: %s", e)
            # As a last resort, pass a single string
            if not kwargs:
                params = {"input": " ".join(positional)}
    
    # Normalize list params (especially 'databases')
    if isinstance(params, dict) and 'databases' in params:
        dbs_val = params['databases']
        if isinstance(dbs_val, str):
            txt = dbs_val.strip()
            parsed = []
            if txt.startswith('[') and txt.endswith(']'):
                try:
                    temp = json.loads(txt)
                    if isinstance(temp, list):
                        parsed = [str(x).strip() for x in temp if str(x).strip()]
                except Exception:
                    pass
            if not parsed:
                parsed = [p.strip() for p in txt.split(',') if p.strip()]
            params['databases'] = parsed
    
    try:
        result = tool.run(params)
        return result
    except Exception as e:
        logger.exception("Tool execution failed: %s", e)
        return f"Tool error: {e}"

# ------------ Streamlit interface -------------
def render_chat_message(msg, is_user):
    """Render a chat message with appropriate styling."""
    if is_user:
        st.chat_message("user").write(msg)
    else:
        with st.chat_message("assistant"):
            st.markdown(msg)

def render_conversation_history(conversation_history):
    """Display the conversation history in the chat interface."""
    for msg in conversation_history:
        is_user = msg.get("role") == "user"
        render_chat_message(msg.get("content", ""), is_user)

def get_tool_params(tool_name, tools):
    """Get parameter info for a specific tool."""
    tool = next((t for t in tools if t.name == tool_name), None)
    if not tool or not hasattr(tool, 'func'):
        return []
    
    sig = inspect.signature(tool.func)
    params = []
    for name, param in sig.parameters.items():
        if name == 'return':
            continue
        has_default = param.default != inspect.Parameter.empty
        default = param.default if has_default else None
        param_type = param.annotation.__name__ if (param.annotation != inspect.Parameter.empty and hasattr(param.annotation, '__name__')) else str(param.annotation) if param.annotation != inspect.Parameter.empty else "any"
        is_list = False
        if str(param.annotation).startswith('typing.List') or str(param.annotation).startswith('list') or 'List[' in str(param.annotation):
            is_list = True
            param_type = 'list[str]'
        params.append({
            "name": name,
            "required": not has_default,
            "default": default,
            "type": param_type,
            "is_list": is_list,
        })
    return params

def json_formatter(text):
    """Format JSON strings for better display"""
    try:
        data = json.loads(text)
        return json.dumps(data, indent=2)
    except:
        return text

def display_supported_databases():
    """Display supported databases in a nice format."""
    try:
        from config import SUPPORTED_DATABASES
        if SUPPORTED_DATABASES:
            cols = st.columns(4)
            for i, db in enumerate(SUPPORTED_DATABASES):
                col_idx = i % 4
                cols[col_idx].write(f"- {db}")
        else:
            st.info("No databases defined in config.py")
    except Exception:
        st.warning("Could not load database list from config.py")

def sidebar_display_context(context_state):
    """Display and allow editing context in the sidebar."""
    with st.sidebar.expander("Context Memory", expanded=True):
        st.write("Current context memory values:")
        db_val = context_state.get("db_name") or ""
        table_val = context_state.get("table_name") or ""
        schema_val = context_state.get("schema_name") or ""
        
        new_db = st.text_input("Database (db_name)", value=db_val)
        new_table = st.text_input("Table/Object (table_name)", value=table_val)
        new_schema = st.text_input("Schema/Owner (schema_name)", value=schema_val)
        
        if st.button("Update Context"):
            if new_db != db_val:
                context_state["db_name"] = new_db if new_db else None
            if new_table != table_val:
                context_state["table_name"] = new_table if new_table else None
            if new_schema != schema_val:
                context_state["schema_name"] = new_schema if new_schema else None
            st.success("Context updated!")
        
        if st.button("Reset Context"):
            context_state["db_name"] = None
            context_state["table_name"] = None
            context_state["schema_name"] = None
            st.success("Context reset!")
            
def sidebar_display_system_prompt(session_state):
    """Display and allow customizing system prompt in the sidebar."""
    with st.sidebar.expander("System Prompt", expanded=False):
        st.write("Customize the agent's system prompt:")
        
        # Get available prompts
        system_prompts = get_system_prompts()
        prompt_options = list(system_prompts.keys())
        
        # Select from available prompts or use custom
        selected_option = st.selectbox(
            "Select a prompt template:",
            prompt_options + ["Custom"],
            index=0 if "selected_prompt_option" not in session_state else 
                  prompt_options.index(session_state["selected_prompt_option"]) 
                  if session_state.get("selected_prompt_option") in prompt_options else len(prompt_options)
        )
        
        # Store the selected option
        session_state["selected_prompt_option"] = selected_option
        
        # Show text area for editing prompt
        if selected_option == "Custom":
            custom_prompt = st.text_area(
                "Custom System Prompt",
                value=session_state.get("custom_system_prompt", "You are an Oracle database diagnostic assistant."),
                height=200
            )
            session_state["custom_system_prompt"] = custom_prompt
            session_state["active_system_prompt"] = custom_prompt
        else:
            # Show the selected prompt in a text area that can be edited
            prompt_text = st.text_area(
                f"{selected_option} System Prompt",
                value=system_prompts[selected_option],
                height=200
            )
            # If the user has edited the default text, consider it custom
            if prompt_text != system_prompts[selected_option]:
                session_state["custom_system_prompt"] = prompt_text
                session_state["active_system_prompt"] = prompt_text
                # Switch to custom mode
                session_state["selected_prompt_option"] = "Custom"
                st.info("You've modified the default prompt. Switched to Custom mode.")
                st.rerun()
            else:
                session_state["active_system_prompt"] = system_prompts[selected_option]
        
        # Reset button to restore default
        if st.button("Reset to Default"):
            session_state["selected_prompt_option"] = "Default"
            if "custom_system_prompt" in session_state:
                del session_state["custom_system_prompt"]
            session_state["active_system_prompt"] = system_prompts["Default"]
            st.success("Reset to default system prompt!")
            st.rerun()
            
        # Apply button to reinitialize the agent with the new prompt
        if st.button("Apply System Prompt"):
            # Reset the agent to force reinitialization with new prompt
            if "agent" in session_state:
                session_state.agent = None
            session_state.is_agent_initialized = False
            st.success("System prompt updated! Agent will be reinitialized.")
            st.rerun()

def main():
    # Load environment variables
    load_dotenv()
    
    # Setup logging
    logger = setup_logging()
    logger.info("Starting Streamlit app")
    
    # Set page config
    st.set_page_config(
        page_title="Oracle Database Diagnostic Assistant",
        page_icon="🔮",
        layout="wide",
    )
    
    # Initialize session state
    if "conversation_history" not in st.session_state:
        st.session_state.conversation_history = []
    if "context_state" not in st.session_state:
        st.session_state.context_state = {
            "db_name": None,
            "table_name": None,
            "schema_name": None,
        }
    if "agent" not in st.session_state:
        st.session_state.agent = None
    if "tools" not in st.session_state:
        st.session_state.tools = build_tools()
    if "is_agent_initialized" not in st.session_state:
        st.session_state.is_agent_initialized = False
        
    # Initialize system prompt
    system_prompts = get_system_prompts()
    if "active_system_prompt" not in st.session_state:
        st.session_state.active_system_prompt = system_prompts.get("Default", 
            "You are a helpful Oracle database diagnostic assistant using only local tools.")
    
    # App header
    st.title("🔮 Oracle Database Diagnostic Assistant")
    
    # Initialize agent if not done yet
    if not st.session_state.is_agent_initialized:
        with st.spinner("Initializing agent..."):
            st.session_state.agent = ensure_agent(st.session_state.tools)
            st.session_state.is_agent_initialized = True
            
    # Create tabs for Chat, Tools, and Help
    chat_tab, tools_tab, help_tab = st.tabs(["Chat", "Tools", "Help"])
    
    # -------------- Chat Tab --------------
    with chat_tab:
        # Display conversation history
        render_conversation_history(st.session_state.conversation_history)
        
        # Chat input
        if prompt := st.chat_input("Ask something about the Oracle database..."):
            # Display user message
            render_chat_message(prompt, True)
            
            # Check for special commands
            lower = prompt.lower().strip()
            
            if lower in ("/tools", "/tool", "tools"):
                # List all tools
                tool_list = []
                for tool in st.session_state.tools:
                    desc = getattr(tool, 'description', '')
                    tool_list.append(f"**{tool.name}**: {desc}")
                
                with st.chat_message("assistant"):
                    st.markdown("### Available Tools\n" + "\n".join(tool_list))
                
                # Add to conversation history
                st.session_state.conversation_history.append({"role": "user", "content": prompt})
                st.session_state.conversation_history.append({"role": "assistant", "content": "### Available Tools\n" + "\n".join(tool_list)})
            
            elif lower in ("/context", "context"):
                # Display current context
                context_msg = []
                for k, v in st.session_state.context_state.items():
                    if v:
                        context_msg.append(f"**{k}**: {v}")
                
                if context_msg:
                    with st.chat_message("assistant"):
                        st.markdown("### Current Context\n" + "\n".join(context_msg))
                else:
                    with st.chat_message("assistant"):
                        st.markdown("No context values set.")
                
                # Add to conversation history
                st.session_state.conversation_history.append({"role": "user", "content": prompt})
                msg_content = "### Current Context\n" + "\n".join(context_msg) if context_msg else "No context values set."
                st.session_state.conversation_history.append({"role": "assistant", "content": msg_content})
            
            elif lower.startswith("/set "):
                # Update context values
                parts = prompt[5:].split()
                changed = []
                
                for part in parts:
                    if "=" in part:
                        k, v = part.split("=", 1)
                        if k == "db_name":
                            st.session_state.context_state["db_name"] = v
                            changed.append(f"db_name={v}")
                        elif k in ("table", "table_name", "object", "object_name"):
                            st.session_state.context_state["table_name"] = v
                            changed.append(f"table_name={v}")
                        elif k in ("schema", "schema_name", "owner"):
                            st.session_state.context_state["schema_name"] = v
                            changed.append(f"schema_name={v}")
                
                # Display result
                if changed:
                    with st.chat_message("assistant"):
                        st.markdown("Updated context: " + ", ".join(changed))
                else:
                    with st.chat_message("assistant"):
                        st.markdown("No valid context keys provided. Use db_name=, table=, schema=")
                
                # Add to conversation history
                st.session_state.conversation_history.append({"role": "user", "content": prompt})
                msg_content = "Updated context: " + ", ".join(changed) if changed else "No valid context keys provided. Use db_name=, table=, schema="
                st.session_state.conversation_history.append({"role": "assistant", "content": msg_content})
            
            else:
                # Process with agent
                with st.spinner("Thinking..."):
                    # No need for asyncio.run now
                    response, updated_history, updated_context = run_query(
                        prompt, 
                        st.session_state.conversation_history,
                        st.session_state.context_state,
                        st.session_state.agent,
                        st.session_state.tools,
                        logger
                    )
                    
                    # Update session state
                    st.session_state.conversation_history = updated_history
                    st.session_state.context_state = updated_context
                    
                    # Display assistant response
                    if hasattr(response, 'content'):
                        render_chat_message(response.content, False)
                    else:
                        render_chat_message(str(response), False)
        
        # Reset button
        if st.button("Reset Conversation"):
            st.session_state.conversation_history = []
            st.rerun()
    
    # -------------- Tools Tab --------------
    with tools_tab:
        st.header("Run Tools Directly")
        
        # Create tabs for form-based and command-based tool execution
        tool_form_tab, tool_command_tab = st.tabs(["Tool Form", "Direct Command"])
        
        with tool_form_tab:
            col1, col2 = st.columns([1, 2])
            
            with col1:
                # Tool selector
                tool_names = [t.name for t in st.session_state.tools]
                selected_tool = st.selectbox("Select a tool", tool_names)
                
                # Get parameter info for the selected tool
                tool_params = get_tool_params(selected_tool, st.session_state.tools)
                
                # Parameter inputs
                param_values = {}
                for param in tool_params:
                    if param["name"] == "db_name" and st.session_state.context_state.get("db_name"):
                        default_value = st.session_state.context_state.get("db_name")
                    elif param["name"] == "object_name" and st.session_state.context_state.get("table_name"):
                        default_value = st.session_state.context_state.get("table_name")
                    else:
                        default_value = param["default"] or ""
                    
                    if param["type"] == "int":
                        value = st.number_input(
                            f"{param['name']}" + (" (required)" if param["required"] else ""),
                            value=int(default_value) if default_value else 0
                        )
                    elif param["type"] == "bool":
                        value = st.checkbox(
                            f"{param['name']}" + (" (required)" if param["required"] else ""),
                            value=bool(default_value) if default_value is not None else False
                        )
                    else:  # str or default
                        if param["name"] == "sql_text":
                            value = st.text_area(
                                f"{param['name']}" + (" (required)" if param["required"] else ""),
                                value=default_value or "",
                                height=200
                            )
                        else:
                            value = st.text_input(
                                f"{param['name']}" + (" (required)" if param["required"] else ""),
                                value=default_value or ""
                            )
                    
                    param_values[param["name"]] = value
                
                # Run button
                if st.button("Run Tool"):
                    with st.spinner("Running..."):
                        result = run_tool_directly(
                            selected_tool,
                            param_values,
                            st.session_state.context_state,
                            st.session_state.tools,
                            logger
                        )
                        
                        # Store result in session state
                        st.session_state.tool_result = result
                        
                        # Update context based on parameters
                        if "db_name" in param_values and param_values["db_name"]:
                            st.session_state.context_state["db_name"] = param_values["db_name"]
                        if "object_name" in param_values and param_values["object_name"]:
                            st.session_state.context_state["table_name"] = param_values["object_name"]
        
        with tool_command_tab:
            st.markdown("""
            ### Direct Command Mode
            
            Enter commands in the format:
            ```
            /run tool_name param1=value1 param2=value2 ...
            ```
            or
            ```
            /run tool_name value1 value2 ...
            ```
            
            For example:
            ```
            /run check_tablespace_usage db_name=MYDB
            /run run_sql MYDB "SELECT * FROM dual"
            ```
            """)
            
            # Command input
            command = st.text_area("Enter command:", height=100)
            
            if st.button("Execute Command"):
                if command.strip().startswith("/run "):
                    with st.spinner("Executing..."):
                        try:
                            import shlex
                            parts = shlex.split(command.strip())
                            
                            if len(parts) < 2:
                                st.error("Usage: /run <tool_name> [key=value | positional...]")
                            else:
                                tool_name = parts[1]
                                
                                # Parse params
                                kwargs = {}
                                positional = []
                                for p in parts[2:]:
                                    if '=' in p:
                                        k, v = p.split('=', 1)
                                        # Cast booleans
                                        if v.lower() in ('true', 'false'):
                                            v = v.lower() == 'true'
                                        kwargs[k] = v
                                    else:
                                        positional.append(p)
                                
                                # Run the tool
                                if positional and not kwargs:
                                    # Use positional params
                                    result = run_tool_directly(
                                        tool_name,
                                        positional,
                                        st.session_state.context_state,
                                        st.session_state.tools,
                                        logger
                                    )
                                else:
                                    # Use keyword args
                                    result = run_tool_directly(
                                        tool_name,
                                        kwargs,
                                        st.session_state.context_state,
                                        st.session_state.tools,
                                        logger
                                    )
                                
                                # Store result
                                st.session_state.tool_result = result
                                
                                # Update context if db_name or object_name were used
                                if kwargs.get("db_name"):
                                    st.session_state.context_state["db_name"] = kwargs["db_name"]
                                if kwargs.get("object_name"):
                                    st.session_state.context_state["table_name"] = kwargs["object_name"]
                        except Exception as e:
                            st.error(f"Command execution error: {e}")
                else:
                    st.error("Commands must start with '/run'")
        
        # Results area (shared between tabs)
        st.subheader("Results")
        if "tool_result" in st.session_state:
            try:
                # If it's JSON, format it nicely
                if isinstance(st.session_state.tool_result, str) and (
                    st.session_state.tool_result.startswith("{") or 
                    st.session_state.tool_result.startswith("[")
                ):
                    try:
                        st.json(json.loads(st.session_state.tool_result))
                    except:
                        st.code(st.session_state.tool_result)
                else:
                    st.code(st.session_state.tool_result)
            except:
                st.text(st.session_state.tool_result)
        
        with col2:
            # This block is empty now as the Results section has been moved
            # to be shared between both tabs
            pass
    
    # -------------- Help Tab --------------
    with help_tab:
        st.header("Help & Documentation")
        
        st.subheader("Using the App")
        st.markdown("""
        ### Chat Interface
        Use the Chat tab to interact with the AI assistant in natural language:
        - Ask about database performance issues
        - Investigate specific database objects
        - Run diagnostic queries
        
        Examples:
        - "Check tablespace usage in PRODDB"
        - "What are the top wait events in TESTDB?"
        - "Show me blocking sessions in DEVDB"
        - "Get the execution plan for SQL ID abc123 in PRODDB"
        
        ### Direct Tool Execution
        Use the Tools tab to run specific diagnostic tools directly:
        - Form-based tool execution with parameter inputs
        - Command-based execution using `/run` syntax (similar to CLI)
        
        Command Examples:
        ```
        /run check_tablespace_usage db_name=PRODDB
        /run check_waitevent TESTDB 10
        /run run_sql PRODDB "SELECT username, sid, serial# FROM v$session WHERE status='ACTIVE'"
        ```
        
        ### Context Memory
        The app remembers values for `db_name`, `table_name`, and `schema_name` across interactions.
        If you don't specify these in a new query, the previous values will be used.
        
        You can view and edit the current context values in the sidebar.
        """)
        
        st.subheader("Available Tools")
        for tool in st.session_state.tools:
            with st.expander(f"{tool.name}"):
                st.markdown(f"**Description**: {getattr(tool, 'description', 'No description')}")
                params = get_tool_params(tool.name, st.session_state.tools)
                if params:
                    st.markdown("**Parameters:**")
                    for p in params:
                        required = " (required)" if p["required"] else ""
                        default = f" (default: `{p['default']}`)" if p["default"] is not None else ""
                        st.markdown(f"- `{p['name']}{required}`: {p['type']}{default}")
        
        st.subheader("Supported Databases")
        display_supported_databases()
    
    # -------------- Sidebar --------------
    sidebar_display_context(st.session_state.context_state)
    sidebar_display_system_prompt(st.session_state)
    
    with st.sidebar.expander("About"):
        st.write("""
        ## Oracle Database Diagnostic Assistant
        
        This app provides diagnostic tools for Oracle databases.
        It can analyze wait events, check tablespace usage, identify blockers,
        and run custom SQL queries.
        
        Built with Streamlit and LangGraph.
        """)
    
    with st.sidebar.expander("Commands"):
        st.write("### Available Commands")
        st.markdown("""
        - **Chat Tab**: Ask natural language questions
        - **Tools Tab**: Run diagnostic tools with forms
        - **Direct Command**: Use the `/run` command syntax
        
        **Special Commands:**
        - `/tools` - List all available tools
        - `/context` - Show current context
        - `/set db_name=DB1 table=TABLE1` - Set context values
        """)
        
        # List all tools in compact format
        if st.button("List Tools"):
            tool_names = []
            for tool in st.session_state.tools:
                desc = getattr(tool, 'description', '')
                tool_names.append(f"**{tool.name}**: {desc}")
            
            st.markdown("\n".join(tool_names))

if __name__ == "__main__":
    main()
