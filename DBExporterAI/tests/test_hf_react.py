"""
test_hf_react.py - Demonstrate a simple ReAct tool-calling loop using
the OpenAI-compatible HuggingFace Inference API.

The LLM does NOT natively receive tool schemas — instead we describe
tools in the system prompt and parse TOOL_CALL: markers from the response.

Run:
    python -B tests/test_hf_react.py

Tools demonstrated:
    get_weather(city)        - returns fake weather
    calculate(expression)    - evaluates a math expression
"""

import os
import json
import re
from openai import OpenAI

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=os.environ.get("HF_TOKEN"),
)
MODEL = "Qwen/Qwen2.5-72B-Instruct"

# ---------------------------------------------------------------------------
# Step 1 — Define real local tool functions
# ---------------------------------------------------------------------------

def get_weather(city: str) -> str:
    """Simulated weather tool — returns fake data."""
    data = {
        "london":   "12C, cloudy",
        "new york": "22C, sunny",
        "tokyo":    "18C, partly cloudy",
    }
    return data.get(city.lower(), f"No weather data for '{city}'")


def calculate(expression: str) -> str:
    """Safely evaluates a simple math expression."""
    try:
        result = eval(expression, {"__builtins__": {}})   # restricted eval
        return str(result)
    except Exception as e:
        return f"ERROR: {e}"


# Tool dispatch map — name -> function
TOOLS = {
    "get_weather": get_weather,
    "calculate":   calculate,
}

# ---------------------------------------------------------------------------
# Step 2 — Describe tools in the system prompt (plain text registration)
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = """You are a helpful assistant. You have access to these tools:

  get_weather(city: str) -> str
      Returns current weather for a city.

  calculate(expression: str) -> str
      Evaluates a math expression and returns the result.

To call a tool, emit EXACTLY this on its own line (valid JSON only):
  TOOL_CALL: {"name": "<tool_name>", "args": {"<param>": "<value>"}}

After receiving a TOOL_RESULT you can call another tool or give your final answer.
When you have enough information, emit:
  FINAL_ANSWER: <your answer to the user>

Rules:
- Never make up tool results. Always call the tool first.
- Only call one tool per response.
- Always end with FINAL_ANSWER once you have the answer.
"""

# ---------------------------------------------------------------------------
# Step 3 — ReAct loop
# ---------------------------------------------------------------------------

def react_loop(user_question: str, max_iterations: int = 6) -> str:
    """
    Sends user_question to the LLM, parses TOOL_CALL markers,
    executes real local functions, feeds results back, repeats
    until FINAL_ANSWER is seen or max_iterations is reached.
    """
    messages = [
        {"role": "system",  "content": SYSTEM_PROMPT},
        {"role": "user",    "content": user_question},
    ]

    for iteration in range(1, max_iterations + 1):
        print(f"\n--- Iteration {iteration} ---")

        # Call LLM
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            max_tokens=300,
            temperature=0,
        )
        reply = response.choices[0].message.content.strip()
        print(f"LLM reply:\n{reply}")

        # Append assistant reply to history
        messages.append({"role": "assistant", "content": reply})

        # Check for FINAL_ANSWER
        if "FINAL_ANSWER:" in reply:
            answer = reply.split("FINAL_ANSWER:", 1)[1].strip()
            return answer

        # Check for TOOL_CALL
        if "TOOL_CALL:" in reply:
            tool_result = _execute_tool_call(reply)
            print(f"Tool result: {tool_result}")
            # Feed result back as a user message
            messages.append({
                "role": "user",
                "content": f"TOOL_RESULT: {tool_result}\nNow continue."
            })
        else:
            # No marker — treat as final answer
            return reply

    return "Max iterations reached without a final answer."


def _execute_tool_call(llm_reply: str) -> str:
    """
    Extracts the JSON after TOOL_CALL:, dispatches the real function,
    returns the result as a string.
    Uses brace-counting to handle nested JSON correctly.
    """
    marker = "TOOL_CALL:"
    start_marker = llm_reply.find(marker)
    if start_marker == -1:
        return "ERROR: No TOOL_CALL marker found."

    text_after = llm_reply[start_marker + len(marker):].strip()

    # Brace-counting to extract full JSON object
    brace_depth = 0
    json_start = text_after.find("{")
    if json_start == -1:
        return "ERROR: No JSON object after TOOL_CALL."

    json_end = json_start
    for i, ch in enumerate(text_after[json_start:], start=json_start):
        if ch == "{":
            brace_depth += 1
        elif ch == "}":
            brace_depth -= 1
            if brace_depth == 0:
                json_end = i + 1
                break

    raw_json = text_after[json_start:json_end]

    try:
        call = json.loads(raw_json)
    except json.JSONDecodeError as e:
        return f"ERROR: Could not parse tool call JSON: {e}\nRaw: {raw_json}"

    tool_name = call.get("name", "")
    tool_args = call.get("args", {})

    if tool_name not in TOOLS:
        return f"ERROR: Unknown tool '{tool_name}'. Available: {list(TOOLS.keys())}"

    try:
        result = TOOLS[tool_name](**tool_args)
        return str(result)
    except Exception as e:
        return f"ERROR executing {tool_name}: {type(e).__name__}: {e}"


# ---------------------------------------------------------------------------
# Run demo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    questions = [
        "What is the weather in London?",
        "What is 123 * 456 + 789?",
        "What is the weather in Tokyo and what is 100 / 4?",
    ]

    for q in questions:
        print("\n" + "=" * 55)
        print(f"Question: {q}")
        print("=" * 55)
        answer = react_loop(q)
        print(f"\n✅ Final Answer: {answer}")
