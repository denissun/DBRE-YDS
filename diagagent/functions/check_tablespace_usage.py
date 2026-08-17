import os
import json
import time
import logging
from typing import Any, Dict, List
import requests


def check_tablespace_usage(db_name: str, limit: int = 50) -> str:
    """Check tablespace usage via internal REST endpoint.

    Params:
    db_name: Database identifier.
      limit: Max rows returned by backend (def 50)

    Returns JSON string (LLM-friendly) with fields rows, row_count, elapsed_ms, etc.
    """
    logger = logging.getLogger(__name__)
    sql_text = (
        "SELECT t.tablespace_name, "
        "ROUND(t.total_size_b/1024/1024/1024) AS size_g, "
        "ROUND(100*tu.used_space * s.block_size/t.total_size_b,1) pct_used, "
        "ROUND((t.total_size_b - tu.used_space * s.block_size)/1024/1024/1024) AS free_g, "
        "t.autoextensible, s.bigfile "
        "FROM dba_tablespace_usage_metrics tu "
        "JOIN ( SELECT tablespace_name, SUM(bytes) total_size_b, MAX(autoextensible) autoextensible "
        "       FROM dba_data_files GROUP BY tablespace_name ) t ON t.tablespace_name = tu.tablespace_name "
        "JOIN dba_tablespaces s ON t.tablespace_name = s.tablespace_name "
        "ORDER BY pct_used DESC"
    )

    try:
        from config import DB_RUN_SQL_API  # type: ignore
    except Exception:
        DB_RUN_SQL_API = os.environ.get("DB_RUN_SQL_API", "http://localhost:5000/api/db_run_sql")
    url = DB_RUN_SQL_API
    payload = {"sqlText": sql_text, "db_name": db_name, "limit": limit}
    headers = {"Content-Type": "application/json"}
    start = time.time()
    logger.debug("Calling tablespace usage API: url=%s db=%s", url, db_name)
    print("Calling tablespace usage API: url=%s db=%s", url, db_name)
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=60)
    except Exception as e:
        logger.error("Tablespace usage API request failed: %s", e)
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
        data = resp.json()
    except ValueError as e:
        return json.dumps({"error": f"JSON decode error: {e}", "elapsed_ms": elapsed_ms, "snippet": resp.text[:300]})

    data["elapsed_ms"] = elapsed_ms
    data["db_name"] = db_name
    return json.dumps(data, indent=2)


# Legacy helper kept for potential reuse

def call_db_run_sql(url: str, sql_text: str, db_name: str, limit: int) -> Dict[str, Any]:
    payload = {
        "sqlText": sql_text,
        "db_name": db_name,
        "limit": limit,
    }
    headers = {"Content-Type": "application/json"}
    start = time.time()
    try:
        resp = requests.post(url, headers=headers, data=json.dumps(payload), timeout=120)
    except Exception as e:
        return {"error": f"HTTP error calling API: {e}"}

    elapsed_ms = int((time.time() - start) * 1000)
    print(f"HTTP {resp.status_code} in {elapsed_ms} ms from {url}")
    ctype = resp.headers.get("Content-Type", "")
    if "application/json" not in ctype:
        return {"error": "Unexpected content-type", "content_type": ctype, "snippet": resp.text[:500]}

    try:
        data = resp.json()
    except ValueError as e:
        return {"error": f"JSON decode error: {e}", "snippet": resp.text[:500]}
    return data


def guess_columns(rows: List[Dict[str, Any]]) -> List[str]:
    if not rows:
        return []
    cols: List[str] = []
    seen = set()
    for r in rows:
        for k in r.keys():
            if k not in seen:
                seen.add(k)
                cols.append(k)
    return cols


def print_result(data: Dict[str, Any]):
    if "error" in data:
        print("ERROR returned by API:")
        print(json.dumps(data, indent=2))
        return

    print("Summary:")
    print(f"  Database : {data.get('db_name')}")
    print(f"  SQL      : {data.get('sqlText')[:100]}{'...' if len(str(data.get('sqlText'))) > 100 else ''}")
    print(f"  Row Count: {data.get('row_count')} (limit {data.get('limit')})")
    print(f"  Elapsed  : {data.get('elapsed_ms')} ms")
    print()

    rows = data.get("rows", [])
    if not rows:
        print("(No rows returned)")
        return

    cols = guess_columns(rows)
    header = " | ".join(cols)
    print(header)
    print("-" * len(header))
    for r in rows:
        line = []
        for c in cols:
            v = r.get(c, "")
            line.append(str(v))
        print(" | ".join(line))
