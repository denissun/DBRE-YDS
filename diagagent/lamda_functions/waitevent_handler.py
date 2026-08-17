"""AWS Lambda handler to invoke check_waitevent tool.

Expected event format (JSON):
{
  "db_name": "g4tpsdb",
  "limit": 50,
  "raw": false
}

Returns JSON structure from underlying REST tool or error payload.

Deployment notes:
- Package this file with the 'requests' dependency (or use Lambda layer).
- Ensure config.DB_RUN_SQL_API is set via environment variable DB_RUN_SQL_API if not using config file.
- Timeout should accommodate underlying API call (default 60s request timeout + overhead).
"""
from __future__ import annotations
import json
import os
import logging
from typing import Any, Dict

# Reuse existing function implementation
try:
    from functions.check_waitevent import check_waitevent  # type: ignore
except Exception as e:  # pragma: no cover
    raise RuntimeError(f"Unable to import check_waitevent: {e}")

logger = logging.getLogger()
if not logger.handlers:
    logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))


def _build_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):  # AWS Lambda entry point
    # Support both direct dict and JSON string event
    if isinstance(event, str):
        try:
            event = json.loads(event)
        except json.JSONDecodeError:
            return _build_response(400, {"error": "Invalid JSON event string"})

    if not isinstance(event, dict):
        return _build_response(400, {"error": "Event must be an object"})

    db_name = event.get("db_name") or event.get("db")
    limit = event.get("limit", 50)
    raw = event.get("raw", False)

    if not db_name:
        return _build_response(400, {"error": "Missing required field 'db_name'"})

    try:
        result_str = check_waitevent(db_name=db_name, limit=limit)
        if raw:
            # Return parsed JSON body from tool result
            try:
                parsed = json.loads(result_str)
            except Exception:
                parsed = {"raw_result": result_str}
            return _build_response(200, parsed)
        else:
            # Wrap as text
            return _build_response(200, {"result": result_str})
    except Exception as e:  # catch all to avoid Lambda cold failure
        logger.exception("handler error")
        return _build_response(500, {"error": str(e), "type": type(e).__name__})


# Local test harness
if __name__ == "__main__":  # pragma: no cover
    sample_event = {"db_name": os.environ.get("TEST_DB_NAME", "g4tpsdb"), "limit": 5, "raw": True}
    print(json.dumps(handler(sample_event, None), indent=2))
