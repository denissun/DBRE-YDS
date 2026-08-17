import os
import json
import time
import logging
from typing import Any, Dict
import requests


def top_sql_by_elapsed_time_15min(db_name: str, limit: int = 50) -> str:
    """Return top SQL statements active in last 15 minutes whose avg execution time > 1 second.


    Params:
      db_name: Target database identifier passed to backend API.
      limit:   Max rows to request from backend (default 50).

    Returns: JSON string (LLM-friendly) containing rows / metadata or error info.
    """
    logger = logging.getLogger(__name__)

    sql_text = '''
select inst_id, sql_id, avg_elapsed_time_seconds, executions, sql_text 
from 
(
    SELECT
    s.inst_id,
    s.sql_id,
    round((s.elapsed_time / s.executions) / 1000000 ) AS avg_elapsed_time_seconds,
    s.executions,
    t.sql_text
FROM
    gv$sqlstats s
JOIN
    gv$sqlarea t ON s.sql_id = t.sql_id AND s.inst_id = t.inst_id
WHERE
    t.last_active_time > SYSDATE - (15 / 1440)
    AND s.executions > 0
)
where avg_elapsed_time_seconds > 1
ORDER BY avg_elapsed_time_seconds DESC ''' 

    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API

    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}

    start = time.time()
    logger.debug("Calling top_sql_by_elapsed_time_15min API: url=%s db=%s limit=%s", url, db_name, limit)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("top_sql_by_elapsed_time_15min API request failed: %s", e)
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
    data["query"] = "top_sql_by_elapsed_time_15min"
    return json.dumps(data, indent=2)

__all__ = ["top_sql_by_elapsed_time_15min"]
