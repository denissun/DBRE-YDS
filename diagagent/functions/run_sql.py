import os
import json
import time
import logging
from typing import Any, Dict
import requests


def run_sql(db_name: str, sql_text: str, limit: int = 500) -> str:
    """Run an arbitrary SQL statement via the DBAETS db_run_sql API.

    Params:
      db_name: Target database identifier passed to backend API.
      sql_text: The SQL statement to execute (SELECT recommended for safety).
      limit: Optional maximum rows to request from backend (default 500).

    Returns: JSON string (LLM-friendly) containing rows / metadata or error info.
    """
    logger = logging.getLogger(__name__)

    if not db_name or not isinstance(db_name, str):
        return json.dumps({"error": "db_name is required"})
    if not sql_text or not isinstance(sql_text, str):
        return json.dumps({"error": "sql_text is required"})

    # Resolve API endpoint from config or env
    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API

    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}

    start = time.time()
    logger.debug("Calling run_sql API: url=%s db=%s limit=%s", url, db_name, limit)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=90)
    except Exception as e:
        logger.error("run_sql API request failed: %s", e)
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
    # For convenience, include a small snippet of the SQL to echo back (avoid huge outputs)
    data["sql_snippet"] = (sql_text[:200] + ("..." if len(sql_text) > 200 else ""))
    return json.dumps(data, indent=2)


__all__ = ["run_sql"]
