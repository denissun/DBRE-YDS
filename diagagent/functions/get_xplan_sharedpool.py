import os
import json
import time
import logging
import re
from typing import Any, Dict
import requests


# Oracle sql_id is base32 (characters 0-9,a-z excluding some). Allow broad safe set for debug.
SQL_ID_PATTERN = re.compile(r"^[0-9a-zA-Z_\$#]{13}$")


def get_xplan_sharedpool(db_name: str, sql_id: str) -> str:
    """Retrieve execution plan from shared pool using DBMS_XPLAN.DISPLAY_CURSOR.

    Params:
      db_name: Target database identifier.
      sql_id : SQL_ID whose cursor plan to display.

    Returns: JSON string containing rows / metadata or error info.
    """
    logger = logging.getLogger(__name__)

    # Normalize and validate sql_id with detailed debug
    orig_sql_id = sql_id
    sql_id = (sql_id or "").strip()
    match_ok = bool(SQL_ID_PATTERN.match(sql_id))
    if not match_ok:
        logger.debug("sql_id validation failed: provided='%s' length=%d pattern=%s", orig_sql_id, len(sql_id), SQL_ID_PATTERN.pattern)
        return json.dumps({
            "error": "Invalid sql_id format (must be 13 chars: [0-9a-zA-Z_$#])",
            "provided": orig_sql_id,
            "normalized": sql_id,
            "length": len(sql_id),
            "pattern": SQL_ID_PATTERN.pattern,
        })
    else:
        logger.debug("sql_id validation success: '%s' length=%d", sql_id, len(sql_id))

    # Build SQL (bind replacement). If backend supports binds, adapt later.
    # Using quoted literal after validation to avoid injection.
    sql_text = (
        "SELECT PLAN_TABLE_OUTPUT FROM TABLE(DBMS_XPLAN.DISPLAY_CURSOR('" + sql_id + "', NULL, 'ALLSTATS LAST'))"
    )

    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API

    payload = {"sqlText": sql_text, "db_name": db_name, "limit": 9999}
    headers = {"Content-Type": "application/json"}
    start = time.time()
    logger.debug("Calling xplan API: url=%s db=%s sql_id=%s payload_len=%d", url, db_name, sql_id, len(sql_text))
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=90)
    except Exception as e:
        logger.error("XPLAN API request failed: %s", e)
        return json.dumps({"error": f"HTTP request failed: {e}", "sql_id": sql_id})

    elapsed_ms = int((time.time() - start) * 1000)
    ctype = resp.headers.get("Content-Type", "")
    if resp.status_code != 200:
        return json.dumps({
            "error": f"Non-200 status {resp.status_code}",
            "status": resp.status_code,
            "elapsed_ms": elapsed_ms,
            "snippet": resp.text[:500],
            "sql_id": sql_id,
        })
    if "application/json" not in ctype:
        return json.dumps({
            "error": "Unexpected content-type",
            "content_type": ctype,
            "elapsed_ms": elapsed_ms,
            "snippet": resp.text[:300],
            "sql_id": sql_id,
        })
    try:
        data: Dict[str, Any] = resp.json()
    except ValueError as e:
        return json.dumps({
            "error": f"JSON decode error: {e}",
            "elapsed_ms": elapsed_ms,
            "snippet": resp.text[:300],
            "sql_id": sql_id,
        })

    data["elapsed_ms"] = elapsed_ms
    data["db_name"] = db_name
    data["sql_id"] = sql_id.upper()
    return json.dumps(data, indent=2)


__all__ = ["get_xplan_sharedpool"]
