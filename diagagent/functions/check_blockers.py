import os
import json
import time
import logging
from typing import Any, Dict
import requests


def check_blockers(db_name: str, limit: int = 50) -> str:
    """Check for blocking sessions holding DML locks via internal REST endpoint.

    Params:
      db_name: Target database identifier passed to backend API.
      limit:   Maximum rows to request (backend may enforce its own cap).

    Returns: Pretty JSON string with rows / metadata or error details.
    """
    logger = logging.getLogger(__name__)

    sql_text = '''select
        l.INST_ID,
        l.SID,
        s.serial#,
        s.username,
        l.TYPE,
        decode(l.lmode,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share',5,'S/Row-X',6,'Exclusive') lockheld,
        DECODE(REQUEST,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share', 5,'S/ROW',6,'Exclusive')REQUEST,
        CTIME/60 timeheld ,
        decode(l.BLOCK,0,'No',1, 'Yes', 2, 'Yes') block,
        s.blocking_instance,
        s.blocking_session
from gv$lock l,
     gv$session s
where (l.ID1,l.ID2,l.TYPE) in
       (select ID1,ID2,TYPE
        from gv$lock where request>0)
 and l.sid=s.sid
 and l.inst_id=s.inst_id
order by l.id1, l.lmode desc, l.ctime desc '''
    

    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API
    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}
    start = time.time()
    logger.debug("Calling blockers API: url=%s db=%s", url, db_name)
    print("Calling blockers API: url=%s db=%s", url, db_name)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("Blockers API request failed: %s", e)
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


__all__ = ["check_blockers"]
