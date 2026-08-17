import os
import json
import time
import logging
from typing import Any, Dict, List
import requests


def run_sql_databases(databases: str, sql_text: str, limit: int = 100) -> str:
    """Run a SQL statement against multiple databases via the DBAETS databases_run_sql API.

        Params:
            databases: Comma-separated list or JSON array string of target database identifiers.
      sql_text: The SQL statement to execute (SELECT recommended for safety).
      limit: Optional per-database maximum rows to request (default 100, max 5000).

    Returns: JSON string containing per-database execution status and rows or error info.

    Payload sent:
      {
        "sqlText": "select * from dual",
        "databases": ["db1", "db2"],
        "limit": 200
      }
    Endpoint: http://dbaets.linuxhost1.com/dbaets/api/databases_run_sql
    """
    logger = logging.getLogger(__name__)

    # Normalize databases param: accept JSON string, comma-separated string, or list
    # Normalize databases string: JSON array or comma-separated
    raw = (databases or "").strip()
    databases_list: List[str] = []
    if raw.startswith("[") and raw.endswith("]"):
        try:
            tmp = json.loads(raw)
            if isinstance(tmp, list):
                databases_list = [str(x).strip() for x in tmp if str(x).strip()]
        except Exception:
            pass
    if not databases_list:
        databases_list = [p.strip() for p in raw.split(',') if p.strip()]

    if not databases_list:
        return json.dumps({"error": "databases list is empty"})
    if not sql_text or not isinstance(sql_text, str):
        return json.dumps({"error": "sql_text is required"})
    if limit <= 0:
        limit = 100
    if limit > 5000:
        limit = 5000  # enforce safety cap

    # Remove duplicates / trim whitespace
    clean_dbs = []
    for db in databases_list:
        if isinstance(db, str):
            dbn = db.strip()
            if dbn and dbn not in clean_dbs:
                clean_dbs.append(dbn)
    if not clean_dbs:
        return json.dumps({"error": "No valid database names provided"})

    url = "http://dbaets.linuxhost1.com/dbaets/api/databases_run_sql"
    payload = {"sqlText": sql_text, "databases": clean_dbs, "limit": limit}
    headers = {"Content-Type": "application/json"}

    start = time.time()
    logger.debug("Calling databases_run_sql API: url=%s db_count=%d limit=%s", url, len(clean_dbs), limit)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=180)
    except Exception as e:
        logger.error("databases_run_sql API request failed: %s", e)
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

    # Augment response
    data["elapsed_ms"] = elapsed_ms
    data["db_count"] = len(clean_dbs)
    data["databases"] = clean_dbs
    data["sql_snippet"] = (sql_text[:200] + ("..." if len(sql_text) > 200 else ""))
    return json.dumps(data, indent=2)


__all__ = ["run_sql_databases"]
