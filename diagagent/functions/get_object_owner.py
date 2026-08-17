import os
import json
import time
import logging
from typing import Any, Dict
import requests


def get_object_owner(db_name: str, object_name: str) -> str:
    """Get owner(s) and basic metadata for a database object.

    Params:
      db_name: Target database identifier.
      object_name: Object name (table/view/package/etc). Case-insensitive; will be uppercased.

    Returns JSON string with rows / metadata or error details. Replace sql_text with a
    more elaborate query if needed (e.g., joining DBA_SEGMENTS for size info).
    """
    logger = logging.getLogger(__name__)

    if not object_name or not isinstance(object_name, str):
        return json.dumps({"error": "object_name required"})

    obj = object_name.upper().strip()
    # Basic placeholder query; user can enhance. Using bind emulation via safe formatting after uppercase.
    sql_text = (
        "SELECT owner, object_name, object_type, status "
        "FROM dba_objects WHERE object_name='" + obj.replace("'", "''") + "' ORDER BY owner"
    )

    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API

    payload = {"sqlText": sql_text, "db_name": db_name, "limit": 500}
    headers = {"Content-Type": "application/json"}
    start = time.time()
    logger.debug("Calling object owner API: url=%s db=%s object=%s", url, db_name, obj)
    print("Calling object owner API: url=%s db=%s object=%s", url, db_name, obj)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("Object owner API request failed: %s", e)
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
    data["object_name"] = obj
    return json.dumps(data, indent=2)


__all__ = ["get_object_owner"]
