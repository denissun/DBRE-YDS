import sys
import os
from google import genai
from google.genai import types
from dotenv import load_dotenv

from prompts import system_prompt
from call_function import available_functions, call_function

def main():
    load_dotenv()

    verbose = "--verbose" in sys.argv
    args = []
    for arg in sys.argv[1:]:
        if not arg.startswith("--"):
            args.append(arg)

    if not args:
        print("AI Code Assistant")
        print('\nUsage: python main.py "your prompt here" [--verbose]')
        print('Example: python main.py "How do I build a calculator app?"')
        sys.exit(1)

    api_key = os.environ.get("GEMINI_API_KEY")
    client = genai.Client(api_key=api_key)

    user_prompt = " ".join(args)

    if verbose:
        print(f"User prompt: {user_prompt}\n")

    # Display user message
    print(f'User: "{user_prompt}"')

    messages = [
        types.Content(role="user", parts=[types.Part(text=user_prompt)]),
    ]

    generate_content(client, messages, verbose)

def generate_content(client, messages, verbose):
    max_iters = 20
    for i in range(0, max_iters) :

        try: 
           response = client.models.generate_content(
             model="gemini-2.0-flash-001",
             contents=messages,
             config=types.GenerateContentConfig(
             tools=[available_functions], system_instruction=system_prompt),
           )
        except:
           continue

        if verbose:
            print("Prompt tokens:", response.usage_metadata.prompt_token_count)
            print("Response tokens:", response.usage_metadata.candidates_token_count)

        if response.candidates:
            for candidate in response.candidates:
                if candidate is None or candidate.content is None:
                    continue
                messages.append(candidate.content)

        if response.function_calls:
            # Display model's intention to call tools
            function_names = [fc.name for fc in response.function_calls]
            print(f'Model: "I want to call {", ".join(function_names)}..."')
            
            for function_call_part in response.function_calls:
                result = call_function(function_call_part, verbose)
                messages.append (result)
        else:
            # Display model's final response
            print(f'Model: "{response.text}"')
            return

if __name__ == "__main__":
    main()

