import os
import ssl
import httpx
from google import genai

# ---------------------------------------------------------------------------
# Load API key — from environment variable or bat file fallback
# ---------------------------------------------------------------------------
def _load_api_key() -> str:
    key = os.getenv("GEMINI_API_KEY", "")
    if not key:
        bat_path = os.path.join(os.path.dirname(__file__), "set_gemini_api_key.bat")
        try:
            with open(bat_path) as f:
                for line in f:
                    line = line.strip()
                    if line.upper().startswith("SET GEMINI_API_KEY="):
                        key = line.split("=", 1)[1].strip()
                        break
        except FileNotFoundError:
            pass
    return key

# Corporate SSL fix
ssl._create_default_https_context = ssl._create_unverified_context

api_key = _load_api_key()
if not api_key:
    raise ValueError("GEMINI_API_KEY not found.")

# Build client with SSL-bypass httpx transport for corporate proxy
client = genai.Client(api_key=api_key)
client._api_client._httpx_client = httpx.Client(
    verify=False,
    proxy=os.getenv("HTTPS_PROXY", "http://proxy.mycompany.com:80"),
)

# ---------------------------------------------------------------------------
# List all available models
# ---------------------------------------------------------------------------
print("Available Gemini models:")
print("-" * 50)
for model in client.models.list():
    print(f"  {model.name}")

print()
print("Test generate_content:")
print("-" * 50)
response = client.models.generate_content(
    model="gemini-2.5-flash",
    contents="Write a one-sentence explanation of what an Oracle DBA does."
)
print(response.text)
