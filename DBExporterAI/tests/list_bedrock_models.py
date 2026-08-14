"""
list_bedrock_models.py - List all Bedrock foundation models available in your region
and check which ones support the Converse API (ON_DEMAND access).

Run:
    python tests/list_bedrock_models.py
"""

import boto3

REGION = "us-east-1"

def main():
    client = boto3.client("bedrock", region_name=REGION)

    print(f"\nFetching available Bedrock models in {REGION}...\n")
    print(f"{'Model ID':<55} {'Provider':<15} {'Access'}")
    print("-" * 90)

    try:
        response = client.list_foundation_models()
        models = response.get("modelSummaries", [])
        count = 0
        for m in models:
            model_id   = m.get("modelId", "")
            provider   = m.get("providerName", "")
            status     = m.get("modelLifecycle", {}).get("status", "")
            input_mod  = m.get("inputModalities", [])
            output_mod = m.get("outputModalities", [])
            if "TEXT" in input_mod and "TEXT" in output_mod:
                print(f"{model_id:<55} {provider:<15} {status}")
                count += 1
        print(f"\n{count} text-in/text-out models listed.")
    except Exception as e:
        print(f"ERROR: {type(e).__name__}: {e}")
        print("\nIf AccessDenied: IAM role needs 'bedrock:ListFoundationModels' permission.")

if __name__ == "__main__":
    main()
