import os
import json
import time
import logging
from typing import Any, Dict
import requests


def check_long_running_sql(db_name: str, limit: int = 50) -> str:
    """Check for long running SQL statements via internal REST endpoint.

    Params:
      db_name: Target database identifier.
      limit:   Max rows requested (default 50).

    Returns: JSON string (LLM-friendly) with rows/metadata or an error object.
    """
    logger = logging.getLogger(__name__)

    sql_text = ''' select /* LLM long runing sqls */ inst_id, username, sid, serial#,sql_id, status, event, last_call_et ela_sec, round(last_call_et/60) ela_min
 from gv$session
 where username is not null
 and sql_id is not null
 and status='ACTIVE'
 and last_call_et > 10
order by status, last_call_et '''

    # Resolve API base (prefer config, fallback env then default)
    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API

    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}
    start = time.time()
    logger.debug("Calling long running SQL API: url=%s db=%s", url, db_name)
    print("Calling long running SQL API: url=%s db=%s", url, db_name)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("Long running SQL API request failed: %s", e)
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
    return json.dumps(data, indent=2)


__all__ = ["check_long_running_sql"]
