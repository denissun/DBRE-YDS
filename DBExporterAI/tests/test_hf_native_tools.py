"""
test_hf_native_tools.py - Demonstrate NATIVE OpenAI function calling
using the HuggingFace OpenAI-compatible API.

Unlike test_hf_react.py (which parses TOOL_CALL: text markers),
this approach passes tool schemas directly to the API via the `tools`
parameter. The model returns a structured `tool_calls` object —
no text parsing needed.

Supported by models that implement the OpenAI tool-calling spec,
e.g. Qwen2.5-72B-Instruct on HuggingFace router.

Run:
    python -B tests/test_hf_native_tools.py
"""

import os
import json
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
# Step 1 — Define real local tool functions (same as ReAct demo)
# ---------------------------------------------------------------------------

def get_weather(city: str) -> str:
    """Simulated weather tool."""
    data = {
        "london":   "12C, cloudy",
        "new york": "22C, sunny",
        "tokyo":    "18C, partly cloudy",
    }
    return data.get(city.lower(), f"No weather data for '{city}'")


def calculate(expression: str) -> str:
    """Safely evaluates a simple math expression."""
    try:
        result = eval(expression, {"__builtins__": {}})
        return str(result)
    except Exception as e:
        return f"ERROR: {e}"


# Tool dispatch map — name -> function
TOOL_FUNCTIONS = {
    "get_weather": get_weather,
    "calculate":   calculate,
}

# ---------------------------------------------------------------------------
# Step 2 — Define tool SCHEMAS (passed to the API, NOT in the system prompt)
# The model reads these schemas and decides when/how to call each tool.
# ---------------------------------------------------------------------------
TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get the current weather for a given city.",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "The name of the city, e.g. 'London' or 'Tokyo'."
                    }
                },
                "required": ["city"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "calculate",
            "description": "Evaluate a mathematical expression and return the result.",
            "parameters": {
                "type": "object",
                "properties": {
                    "expression": {
                        "type": "string",
                        "description": "A valid Python math expression, e.g. '123 * 456 + 789'."
                    }
                },
                "required": ["expression"]
            }
        }
    }
]

# ---------------------------------------------------------------------------
# Step 3 — Native tool-calling loop
# ---------------------------------------------------------------------------

def native_tool_loop(user_question: str, max_iterations: int = 6) -> str:
    """
    Sends user_question to the LLM with tool schemas attached.

    Loop:
      1. Call API with tools=TOOL_SCHEMAS
      2. If response has tool_calls  → execute each tool, feed results back
      3. If response has plain text  → return it as final answer
      4. Repeat until plain text or max_iterations
    """
    messages = [
        {"role": "system", "content": "You are a helpful assistant. Use the provided tools when needed."},
        {"role": "user",   "content": user_question},
    ]

    for iteration in range(1, max_iterations + 1):
        print(f"\n--- Iteration {iteration} ---")

        # Call LLM — pass tool schemas here (NOT in prompt)
        response = client.chat.completions.create(
            model=MODEL,
            messages=messages,
            tools=TOOL_SCHEMAS,          # ← native tool registration
            tool_choice="auto",          # ← let model decide when to call tools
            max_tokens=512,
            temperature=0,
        )

        msg = response.choices[0].message
        finish_reason = response.choices[0].finish_reason

        print(f"finish_reason : {finish_reason}")

        # ── Case A: model wants to call one or more tools ──────────────────
        if finish_reason == "tool_calls" and msg.tool_calls:
            print(f"Tool calls requested: {[tc.function.name for tc in msg.tool_calls]}")

            # Append assistant message (with tool_calls) to history
            messages.append(msg)

            # Execute each requested tool and append results
            for tc in msg.tool_calls:
                fn_name  = tc.function.name
                fn_args  = json.loads(tc.function.arguments)  # already valid JSON

                print(f"  Calling: {fn_name}({fn_args})")

                if fn_name in TOOL_FUNCTIONS:
                    result = TOOL_FUNCTIONS[fn_name](**fn_args)
                else:
                    result = f"ERROR: unknown tool '{fn_name}'"

                print(f"  Result : {result}")

                # Feed tool result back — role must be "tool"
                messages.append({
                    "role":         "tool",
                    "tool_call_id": tc.id,       # ← must match the request id
                    "name":         fn_name,
                    "content":      str(result),
                })

        # ── Case B: model returned a plain text final answer ───────────────
        else:
            answer = msg.content or "(no content)"
            print(f"LLM final reply:\n{answer}")
            return answer

    return "Max iterations reached without a final answer."


# ---------------------------------------------------------------------------
# Side-by-side comparison helper
# ---------------------------------------------------------------------------

def compare_approaches(question: str) -> None:
    """Run both ReAct and native approaches on the same question for comparison."""
    from test_hf_react import react_loop   # import the ReAct demo

    print("\n" + "=" * 60)
    print(f"Question: {question}")
    print("=" * 60)

    print("\n>>> NATIVE tool calling:")
    native_answer = native_tool_loop(question)
    print(f"\n✅ Native Answer: {native_answer}")


# ---------------------------------------------------------------------------
# Run demo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    questions = [
        "What is the weather in London?",
        "What is 123 * 456 + 789?",
        "What is the weather in Tokyo and also calculate 100 / 4?",
    ]

    for q in questions:
        print("\n" + "=" * 60)
        print(f"QUESTION: {q}")
        print("=" * 60)
        answer = native_tool_loop(q)
        print(f"\n✅ Final Answer: {answer}")
