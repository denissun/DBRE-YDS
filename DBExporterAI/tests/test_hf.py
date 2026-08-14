import os
from openai import OpenAI

# Initialize the OpenAI client pointing to the Hugging Face Inference API
client = OpenAI(
    base_url="https://router.huggingface.co/v1",
    api_key=os.environ.get("HF_TOKEN"),
)

try:
    # Request a chat completion
    completion = client.chat.completions.create(
        model="Qwen/Qwen2.5-72B-Instruct",
        messages=[
            {
                "role": "user",
                "content": "how to export oracle table to csv file usin python?"
            }
        ],
        max_tokens=100
    )

    print("Output:")
    print(completion.choices[0].message.content)

except Exception as e:
    print(f"An error occurred: {e}")