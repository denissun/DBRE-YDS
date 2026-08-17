import os
import json
import time
import logging
from typing import Any, Dict
import requests


def check_waitevent(db_name: str, limit: int = 50) -> str:
    """Check database wait event statistics via internal REST endpoint.

    Params:
      db_name: Database identifier passed to the backend API.
      limit:   Maximum rows requested from backend (default 50).

    Returns: JSON string (LLM-friendly) containing rows / metadata or error info.
    """
    logger = logging.getLogger(__name__)

    sql_text = (
          "select inst_id ,event ,wait_class ,round(evttot*100/tot,2) pct_activity , "
          "round(evttot/5/60,1) aas ,snap_start ,snap_end from "
          "( select inst_id, decode(event,null,'CPU+Wait for CPU',event) event, " 
          "decode(wait_class,null,'CPU',wait_class) wait_class, evttot, tot, to_char( mint, 'MM/DD/YY HH24:MI:SS') " 
          "snap_start, to_char( maxt, '--- HH24:MI:SS') snap_end, row_number() over (partition by inst_id order by evttot desc) rn  "
          " from ( select distinct inst_id, event, wait_class, count(*) over (partition by inst_id,event) evttot, " 
          " count(*) over (partition by inst_id) tot, min(sample_time) over () mint, max(sample_time) over () maxt from gv$active_session_history "
          "where sample_time >= sysdate -5/1440 and sample_time <= sysdate )) where rn <=5"
    )
    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API
    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}
    start = time.time()
    logger.debug("Calling wait event API: url=%s db=%s", url, db_name)
    print("Calling wait event API: url=%s db=%s", url, db_name)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("Wait event API request failed: %s", e)
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


__all__ = ["check_waitevent"]
