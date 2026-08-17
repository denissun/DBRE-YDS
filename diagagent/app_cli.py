#!/usr/bin/env python3
"""
Command-line interface for the Oracle SQLcl MCP Assistant.
This version provides the same functionality as app.py but through a CLI interface.
"""

import asyncio
import os
import sys
from dotenv import load_dotenv
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from langchain_mcp_adapters.tools import load_mcp_tools
from langgraph.prebuilt import create_react_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import AIMessage

# Load environment variables
load_dotenv()

# Path to SQLcl executable
SQLCL_PATH = os.environ.get("SQLCL_PATH")
if not SQLCL_PATH:
    print("Error: SQLCL_PATH environment variable not set.")
    print("Please set SQLCL_PATH to the path of your SQLcl executable.")
    sys.exit(1)

# Create server params with additional options for compatibility
server_params = StdioServerParameters(
    command=SQLCL_PATH, 
    args=["-mcp"],
    env=dict(os.environ)  # Pass current environment variables
)

# Initialize Gemini model
api_key = os.environ.get("GEMINI_API_KEY")
if not api_key:
    print("Error: GEMINI_API_KEY environment variable not set.")
    print("Please set GEMINI_API_KEY to your Google Gemini API key.")
    sys.exit(1)

# Configure Gemini with better error handling and timeout
os.environ["GRPC_VERBOSITY"] = "ERROR"  # Reduce gRPC logging
os.environ["HTTP_PROXY"] = "http://proxy.mycompany.com:80"
os.environ["HTTPS_PROXY"] = "http://proxy.mycompany.com:80"

model = ChatGoogleGenerativeAI(
    model="gemini-2.0-flash-001", 
    google_api_key=api_key,
    request_timeout=30,
    max_retries=3
)

"""Persistent MCP / Agent State

We keep explicit references to the underlying context managers so we can
exit them in the SAME task that entered them. The previous implementation
called __aenter__ on async context managers directly and then relied on
garbage collection / later awaits to close them, which led to AnyIO
"Attempted to exit cancel scope in a different task" errors.

Design:
    _stdio_ctx: the stdio_client async context manager (holds task group)
    _client_session_ctx: the ClientSession async context manager
    _session: active ClientSession
    _agent: langgraph agent instance
    _tools: cached tools (so we only load once)
    _init_lock: prevents races if multiple queries trigger init simultaneously
"""
_stdio_ctx = None
_client_session_ctx = None
_session = None
_agent = None
_tools = None
_init_lock = asyncio.Lock()

async def initialize_session():
    """Initialize and return a persistent MCP session and agent.

    Safe against concurrent calls; only first caller performs real init.
    """
    global _stdio_ctx, _client_session_ctx, _session, _agent, _tools
    if _session and _agent:
        return _session, _agent

    async with _init_lock:
        if _session and _agent:  # Double-checked after acquiring lock
            return _session, _agent

        print("🔄 Initializing persistent MCP session (single-run)...")
        try:
            # Create and enter stdio context (keep reference for later exit)
            _stdio_ctx = stdio_client(server_params)
            read, write = await _stdio_ctx.__aenter__()

            # Create and enter client session context
            _client_session_ctx = ClientSession(read, write)
            _session = await _client_session_ctx.__aenter__()
            print("🔄 Initializing MCP protocol handshake...")
            await _session.initialize()

            # Load tools once
            if _tools is None:
                print("🔄 Loading MCP tools (first time)...")
                try:
                    _tools = await load_mcp_tools(_session)
                    print(f"✅ Loaded {_tools and len(_tools) or 0} tools")
                except Exception as tool_error:
                    print(f"⚠️  Tool loading failed: {tool_error}. Continuing with 0 tools.")
                    _tools = []
            else:
                print("ℹ️  Reusing previously loaded tools")

            _agent = create_react_agent(model, _tools)
            print("✅ Persistent session & agent ready")
            return _session, _agent
        except Exception as e:
            print(f"❌ Initialization error: {type(e).__name__}: {e}")
            import traceback
            traceback.print_exc()
            await cleanup_session()
            raise

async def cleanup_session():
    """Clean up persistent session/agent and underlying contexts."""
    global _stdio_ctx, _client_session_ctx, _session, _agent, _tools
    # Do not clear _tools so we can reuse after reconnect if desired.
    if _client_session_ctx and _session:
        try:
            await _client_session_ctx.__aexit__(None, None, None)
        except Exception:
            pass
    if _stdio_ctx:
        try:
            await _stdio_ctx.__aexit__(None, None, None)
        except Exception:
            pass
    _client_session_ctx = None
    _stdio_ctx = None
    _session = None
    _agent = None
    print("🧹 Session resources released.")

async def run_agent(query: str, conversation_history=None):
    """Process a user query via the persistent agent.

    We avoid wrapping the whole call in a timeout to prevent cancelling
    internal AnyIO task groups (which previously produced cancel scope errors).
    Instead, we optionally time-box ONLY the model + tool reasoning segment.
    """
    await initialize_session()

    # Build conversation messages
    messages = []
    if conversation_history:
        messages.extend(conversation_history)
    messages.append({"role": "user", "content": query})

    print("🔄 Processing query with persistent session...")
    try:
        # Apply a model invocation timeout (soft) using wait_for
        try:
            result = await asyncio.wait_for(
                _agent.ainvoke({"messages": messages}), timeout=45
            )
        except asyncio.TimeoutError:
            from langchain_core.messages import AIMessage
            timeout_msg = AIMessage(content="Model processing timed out after 45s.")
            return messages + [timeout_msg], timeout_msg

        # Extract last AI message
        if isinstance(result, dict) and "messages" in result and result["messages"]:
            last_message = result["messages"][-1]
            if hasattr(last_message, "content"):
                return result["messages"], last_message

        from langchain_core.messages import AIMessage
        fallback = AIMessage(content=str(result))
        return messages + [fallback], fallback
    except asyncio.CancelledError:
        from langchain_core.messages import AIMessage
        cancelled = AIMessage(content="Request was cancelled.")
        return messages + [cancelled], cancelled
    except Exception as e:
        from langchain_core.messages import AIMessage
        err = AIMessage(content=f"Error during processing: {type(e).__name__}: {e}")
        return messages + [err], err

def print_banner():
    """Print the application banner."""
    print("=" * 60)
    print("🔮 Diagnostic AI Agent through SQLcl MCP  - Command Line Interface")
    print("=" * 60)
    print("Ask natural language questions about your Oracle database.")
    print("Type 'quit', 'exit', or 'q' to exit the program.")
    print("=" * 60)

async def test_sqlcl_mcp():
    """Test if SQLcl MCP mode is working properly."""
    print("🧪 Testing SQLcl MCP connection...")
    try:
        async with asyncio.timeout(10):  # Short timeout for test
            async with stdio_client(server_params) as (read, write):
                async with ClientSession(read, write) as session:
                    await session.initialize()
                    print("✅ SQLcl MCP test successful!")
                    return True
    except Exception as e:
        print(f"❌ SQLcl MCP test failed: {e}")
        return False

def print_help():
    """Print help information."""
    print("\n📋 Available Commands:")
    print("  help, h          - Show this help message")
    print("  quit, exit, q    - Exit the program")
    print("  clear, cls       - Clear the screen")
    print("  reset, restart   - Reset session and conversation history")
    print("  test             - Test SQLcl MCP connection")
    print("\n💡 Example queries:")
    print("  • Connect to MYDB database")
    print("  • How many employees earn more than 10000?")
    print("  • Show me the top 5 customers by revenue")
    print("  • What tables are available in the database?")
    print("  • Create a summary report of sales by region")
    print("\n🔗 Database Connection:")
    print("  The agent maintains your database connection and conversation context.")
    print("  Once connected, you don't need to reconnect for subsequent queries.")
    print("  Use 'reset' if you need to start fresh or change connections.")
    print()

def clear_screen():
    """Clear the terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')

async def main():
    """Main CLI loop with persistent session."""
    print_banner()
    print_help()
    
    # Maintain conversation history to preserve context
    conversation_history = []
    
    try:
        while True:
            try:
                # Get user input
                print("\n" + "─" * 60)
                query = input("💬 Enter your question: ").strip()
                
                # Handle special commands
                if query.lower() in ['quit', 'exit', 'q']:
                    print("👋 Goodbye!")
                    break
                elif query.lower() in ['help', 'h']:
                    print_help()
                    continue
                elif query.lower() in ['clear', 'cls']:
                    clear_screen()
                    print_banner()
                    continue
                elif query.lower() in ['reset', 'restart']:
                    print("🔄 Resetting session and conversation history...")
                    await cleanup_session()
                    conversation_history = []
                    print("✅ Session reset complete!")
                    continue
                elif query.lower() == 'test':
                    print("🧪 Testing SQLcl MCP connection...")
                    success = await test_sqlcl_mcp()
                    if success:
                        print("✅ SQLcl MCP is working properly!")
                    else:
                        print("❌ SQLcl MCP test failed. Check your configuration.")
                    continue
                elif not query:
                    print("⚠️  Please enter a question or type 'help' for assistance.")
                    continue
                
                print(f"\n🤔 Processing: {query}")
                print("─" * 60)
                
                # Run the agent with conversation history
                try:
                    updated_history, result = await run_agent(query, conversation_history)
                    conversation_history = updated_history
                    
                    if isinstance(result, AIMessage):
                        print("✅ Agent Response:")
                        print("─" * 60)
                        print(result.content)
                    else:
                        print("ℹ️  Response (raw format):")
                        print("─" * 60)
                        print(result)
                        
                except Exception as e:
                    print(f"❌ Error: {e}")
                    print("\n💡 Troubleshooting tips:")
                    print("  • Try 'reset' to restart the session")
                    print("  • Ensure SQLCL_PATH points to a valid SQLcl executable")
                    print("  • Check that GEMINI_API_KEY is set correctly")
                    print("  • Verify your network connection and proxy settings")
                    
            except KeyboardInterrupt:
                print("\n\n👋 Interrupted by user. Goodbye!")
                break
            except Exception as e:
                print(f"\n❌ Unexpected error: {e}")
                continue
                
    finally:
        # Clean up session when exiting
        await cleanup_session()

def run_single_query(query: str):
    """
    Run a single query and exit (useful for scripting).
    
    Args:
        query (str): The query to run
    """
    async def single_run():
        try:
            print(f"🤔 Processing: {query}")
            _, result = await run_agent(query, [])
            
            if isinstance(result, AIMessage):
                print("✅ Response:")
                print(result.content)
            else:
                print("Response:")
                print(result)
                
        except Exception as e:
            print(f"❌ Error: {e}")
            sys.exit(1)
        finally:
            await cleanup_session()
    
    asyncio.run(single_run())

if __name__ == "__main__":
    # Check if a query was provided as command line argument
    if len(sys.argv) > 1:
        # Run single query mode
        query = " ".join(sys.argv[1:])
        run_single_query(query)
    else:
        # Run interactive mode
        try:
            asyncio.run(main())
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
