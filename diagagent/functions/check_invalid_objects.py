import os
import json
import time
import logging
from typing import Any, Dict
import requests

def check_invalid_objects(db_name: str, limit: int = 100) -> str:
    """Check invalid database objects (views, procedures, packages, synonyms, etc.).

    Params:
      db_name: Target database identifier passed to the backend API.
      limit:   Max rows to return (ordered by object_type then object_name).

    Returns: JSON string with rows / metadata or error info (LLM-friendly).
    """
    logger = logging.getLogger(__name__)

    # SQL tuned to show invalid objects with owner filtering option stub (future enhancement)
    sql_text = (
        " select owner, object_name, object_type, status, last_ddl_time, created "
        " from dba_objects "
        " where status = 'INVALID' "
        " order by owner, object_type, object_name"  # deterministic ordering
    )

    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API

    # Some backends might not support bind; fall back to simple replace if needed
    # We'll send :b_limit inside and also pass limit separately.
    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}

    start = time.time()
    logger.debug("Calling invalid objects API: url=%s db=%s limit=%s", url, db_name, limit)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("Invalid objects API request failed: %s", e)
        return json.dumps({"error": f"HTTP request failed: {e}"})

    elapsed_ms = int((time.time() - start) * 1000)
    ctype = resp.headers.get("Content-Type", "")
    if resp.status_code != 200:
        return json.dumps({
            "error": f"Non-200 status {resp.status_code}",
            "status": resp.status_code,
            "elapsed_ms": elapsed_ms,
            "snippet": resp.text[:300],
        })
    if "application/json" not in ctype:
        return json.dumps({
            "error": "Unexpected content-type",
            "content_type": ctype,
            "elapsed_ms": elapsed_ms,
            "snippet": resp.text[:300],
        })
    try:
        data: Dict[str, Any] = resp.json()
    except ValueError as e:
        return json.dumps({"error": f"JSON decode error: {e}", "elapsed_ms": elapsed_ms, "snippet": resp.text[:300]})

    data["elapsed_ms"] = elapsed_ms
    data["db_name"] = db_name
    data["query"] = "invalid_objects"
    return json.dumps(data, indent=2)

__all__ = ["check_invalid_objects"]
