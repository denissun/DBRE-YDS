"""
config.example.py
-----------------
Copy this file to config.py and fill in your values.
config.py is excluded from git (see .gitignore).
"""

import os
import ssl
import warnings
import urllib3
from google import genai

# Corporate network SSL fix
ssl._create_default_https_context = ssl._create_unverified_context
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
warnings.filterwarnings("ignore", message="Unverified HTTPS request")

# --- Gemini API ---
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "YOUR_GEMINI_API_KEY_HERE")
GEMINI_MODEL = "gemini-1.5-flash"

# --- Oracle DB connection settings ---
DB_CONFIG = {
    "host": "your_oracle_host",
    "port": 1521,
    "service": "your_service_name",
    "user": "your_db_user",
    "password": "your_db_password",
}

# --- AWS Bedrock Agent settings ---
# No credentials needed — boto3 uses the EC2 IAM role automatically via IMDS.
BEDROCK_REGION         = "us-east-1"
BEDROCK_AGENT_ID       = "YOUR_AGENT_ID"
BEDROCK_AGENT_ALIAS_ID = "YOUR_ALIAS_ID"

# --- LLM Provider: "gemini" | "bedrock" | "mock" ---
LLM_PROVIDER = "mock"

# --- Orchestration ---
MAX_RETRY_ATTEMPTS = 3
USE_MOCK_DB = True


def make_gemini_client():
    return genai.Client(api_key=GEMINI_API_KEY)
