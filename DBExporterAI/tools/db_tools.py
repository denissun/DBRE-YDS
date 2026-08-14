"""
db_tools.py
-----------
Tools for interacting with an Oracle database.
When config.USE_MOCK_DB is True, all functions return realistic fake data
so the full agent loop can be tested without a real Oracle connection.
"""

import json
import csv
import os
import oracledb
from config import USE_MOCK_DB

# Holds live oracledb connections keyed by connection_id
_REAL_CONNECTIONS: dict = {}

# ---------------------------------------------------------------------------
# Mock data store — simulates a small Oracle schema for testing
# ---------------------------------------------------------------------------
_MOCK_SCHEMA = {
    "EMPLOYEES": [
        {"column": "EMPLOYEE_ID", "type": "NUMBER"},
        {"column": "FIRST_NAME",  "type": "VARCHAR2"},
        {"column": "LAST_NAME",   "type": "VARCHAR2"},
        {"column": "DEPT_ID",     "type": "NUMBER"},
        {"column": "SALARY",      "type": "NUMBER"},
        {"column": "STATUS",      "type": "VARCHAR2"},
    ],
    "ORDERS": [
        {"column": "ORDER_ID",    "type": "NUMBER"},
        {"column": "CUSTOMER_ID", "type": "NUMBER"},
        {"column": "STATUS",      "type": "VARCHAR2"},
        {"column": "AMOUNT",      "type": "NUMBER"},
        {"column": "ORDER_DATE",  "type": "DATE"},
    ],
}

_MOCK_DATA = {
    "EMPLOYEES": [
        {"EMPLOYEE_ID": 1, "FIRST_NAME": "Alice",   "LAST_NAME": "Smith",  "DEPT_ID": 10, "SALARY": 75000, "STATUS": "ACTIVE"},
        {"EMPLOYEE_ID": 2, "FIRST_NAME": "Bob",     "LAST_NAME": "Jones",  "DEPT_ID": 10, "SALARY": 82000, "STATUS": "ACTIVE"},
        {"EMPLOYEE_ID": 3, "FIRST_NAME": "Charlie", "LAST_NAME": "Brown",  "DEPT_ID": 20, "SALARY": 91000, "STATUS": "ACTIVE"},
        {"EMPLOYEE_ID": 4, "FIRST_NAME": "Diana",   "LAST_NAME": "Prince", "DEPT_ID": 10, "SALARY": 68000, "STATUS": "INACTIVE"},
    ],
    "ORDERS": [
        {"ORDER_ID": 101, "CUSTOMER_ID": 5, "STATUS": "PENDING", "AMOUNT": 250.00, "ORDER_DATE": "2026-04-01"},
        {"ORDER_ID": 102, "CUSTOMER_ID": 7, "STATUS": "SHIPPED", "AMOUNT": 130.50, "ORDER_DATE": "2026-04-02"},
        {"ORDER_ID": 103, "CUSTOMER_ID": 5, "STATUS": "PENDING", "AMOUNT": 480.00, "ORDER_DATE": "2026-04-03"},
    ],
}


# ---------------------------------------------------------------------------
# Public tool functions
# ---------------------------------------------------------------------------

def connect_to_oracle(host: str, port: int, service: str, user: str, password: str) -> str:
    """
    Establishes a connection to the Oracle database.

    In MOCK mode: always succeeds and returns a fake connection token.
    In REAL mode: uses the `oracledb` library to create a connection using
    the provided host/port/service/user/password parameters.

    Returns a JSON string: {"status": "connected", "connection_id": "<id>"}
    or raises an exception with a descriptive error on failure.
    """
    if USE_MOCK_DB:
        print("[MockDB] connect_to_oracle() called — returning mock connection.")
        return json.dumps({"status": "connected", "connection_id": "mock-conn-001"})

    # Real Oracle connection via oracledb (thin mode — no Oracle Client needed)
    dsn = oracledb.makedsn(host, port, service_name=service)
    conn = oracledb.connect(user=user, password=password, dsn=dsn)
    conn_id = f"real-conn-{id(conn)}"
    _REAL_CONNECTIONS[conn_id] = conn
    print(f"[OracleDB] Connected to {host}:{port}/{service} as {user} (conn_id={conn_id})")
    return json.dumps({"status": "connected", "connection_id": conn_id})


def get_table_schema(connection_id: str, table_name: str) -> str:
    """
    Fetches column names and data types for the specified table.

    In MOCK mode: looks up the table in the in-memory _MOCK_SCHEMA dictionary.
    In REAL mode: queries ALL_TAB_COLUMNS from the Oracle data dictionary.

    Returns a JSON string: [{"column": "COL_NAME", "type": "DATA_TYPE"}, ...]
    Raises an exception if the table does not exist.
    """
    if USE_MOCK_DB:
        table_upper = table_name.upper()
        print(f"[MockDB] get_table_schema() called for table '{table_upper}'")
        if table_upper not in _MOCK_SCHEMA:
            raise ValueError(f"Table '{table_upper}' does not exist in mock schema. Available: {list(_MOCK_SCHEMA.keys())}")
        return json.dumps(_MOCK_SCHEMA[table_upper])

    # Real implementation — queries Oracle data dictionary
    conn = _REAL_CONNECTIONS[connection_id]
    cursor = conn.cursor()
    cursor.execute(
        "SELECT COLUMN_NAME, DATA_TYPE FROM ALL_TAB_COLUMNS WHERE TABLE_NAME = :1 ORDER BY COLUMN_ID",
        [table_name.upper()]
    )
    rows = [{"column": r[0], "type": r[1]} for r in cursor.fetchall()]
    cursor.close()
    if not rows:
        raise ValueError(f"Table '{table_name.upper()}' not found or has no columns.")
    return json.dumps(rows)


def execute_query(connection_id: str, sql: str) -> str:
    """
    Executes a SELECT SQL query against the Oracle database.

    In MOCK mode: parses the table name and an optional simple WHERE condition
    from the SQL string and filters the in-memory _MOCK_DATA accordingly.
    Supports simple equality conditions like: WHERE DEPT_ID=10 or WHERE STATUS='PENDING'

    In REAL mode: runs the SQL via a cursor on the live Oracle connection
    and returns all rows as a list of dicts.

    Returns a JSON string: [{"COL": value, ...}, ...]
    Raises an exception on SQL errors or unknown tables.
    """
    if USE_MOCK_DB:
        print(f"[MockDB] execute_query() called with SQL: {sql}")
        sql_upper = sql.upper().strip()

        # Extract table name
        from_idx = sql_upper.find("FROM ")
        if from_idx == -1:
            raise ValueError("Invalid SQL: missing FROM clause.")
        rest = sql_upper[from_idx + 5:].strip().split()
        table_name = rest[0].strip(";")

        if table_name not in _MOCK_DATA:
            raise ValueError(f"Table '{table_name}' not found. Available: {list(_MOCK_DATA.keys())}")

        rows = list(_MOCK_DATA[table_name])  # start with all rows

        # Apply simple WHERE filter if present
        where_idx = sql_upper.find("WHERE ")
        if where_idx != -1:
            condition = sql_upper[where_idx + 6:].strip().rstrip(";")
            # Parse simple key=value (e.g. DEPT_ID=10 or STATUS='PENDING')
            for op in ["=", "!=", "<>", ">", "<"]:
                if op in condition:
                    parts = condition.split(op, 1)
                    col = parts[0].strip()
                    val = parts[1].strip().strip("'").strip('"')
                    # Try numeric comparison
                    try:
                        val_typed = int(val)
                    except ValueError:
                        try:
                            val_typed = float(val)
                        except ValueError:
                            val_typed = val  # keep as string

                    def _match(row, col=col, op=op, val_typed=val_typed):
                        rv = row.get(col)
                        if rv is None:
                            return False
                        if isinstance(rv, str):
                            rv = rv.upper()
                        if isinstance(val_typed, str):
                            val_typed_cmp = val_typed.upper()
                        else:
                            val_typed_cmp = val_typed
                        if op == "=":  return rv == val_typed_cmp
                        if op in ("!=", "<>"):  return rv != val_typed_cmp
                        if op == ">":  return rv > val_typed_cmp
                        if op == "<":  return rv < val_typed_cmp
                        return True

                    rows = [r for r in rows if _match(r)]
                    break

        print(f"[MockDB] Query returned {len(rows)} row(s).")
        return json.dumps(rows)

    # Real implementation
    conn = _REAL_CONNECTIONS[connection_id]
    cursor = conn.cursor()
    cursor.execute(sql)
    columns = [d[0] for d in cursor.description]
    rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    cursor.close()
    print(f"[OracleDB] Query returned {len(rows)} row(s).")
    return json.dumps(rows, default=str)


def export_query_to_file(connection_id: str, sql: str, output_path: str, format: str = "csv") -> str:
    """
    Executes `sql` and writes ALL rows directly to `output_path` — row data
    NEVER passes through the LLM context window.

    This is the correct tool for exporting large tables (millions of rows).
    Use execute_query only for small inline db_query results (≤ 50 rows).

    Args:
        connection_id : token returned by connect_to_oracle
        sql           : SELECT statement (no row limit needed — streams directly to file)
        output_path   : absolute path for output file
        format        : "csv" (default) or "json"

    Returns JSON metadata only (no row data):
        {"status": "ok", "rows": N, "path": "...", "file_size_bytes": N}
    or on error:
        {"error": "...", "suggested_path": "..."}   # FILE_EXISTS case
        {"error": "..."}
    """
    import datetime

    output_path = output_path.replace("\\", "/")

    # Guard: never overwrite existing file
    if os.path.isfile(output_path):
        base, ext = os.path.splitext(output_path)
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        suggested = f"{base}_{ts}{ext}"
        return json.dumps({
            "error": "FILE_EXISTS",
            "suggested_path": suggested,
            "action_required": f"File already exists. Call export_query_to_file again with output_path='{suggested}'"
        })

    # Ensure directory exists
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    fmt = format.lower().strip()

    if USE_MOCK_DB:
        # Mock: reuse execute_query result and write it
        raw = execute_query(connection_id, sql)
        rows = json.loads(raw)
        if fmt == "json":
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(rows, f, indent=2, default=str)
        else:
            if rows:
                with open(output_path, "w", newline="", encoding="utf-8") as f:
                    writer = csv.DictWriter(f, fieldnames=rows[0].keys())
                    writer.writeheader()
                    writer.writerows(rows)
            else:
                open(output_path, "w").close()
        size = os.path.getsize(output_path)
        print(f"[MockDB] export_query_to_file → {output_path} ({len(rows)} rows, {size} bytes)")
        return json.dumps({"status": "ok", "rows": len(rows), "path": output_path, "file_size_bytes": size})

    # Real implementation — stream directly Oracle → file
    conn   = _REAL_CONNECTIONS[connection_id]
    cursor = conn.cursor()
    cursor.execute(sql)
    columns    = [d[0] for d in cursor.description]
    row_count  = 0

    if fmt == "json":
        with open(output_path, "w", encoding="utf-8") as f:
            f.write("[\n")
            first = True
            while True:
                batch = cursor.fetchmany(500)
                if not batch:
                    break
                for raw_row in batch:
                    row = dict(zip(columns, raw_row))
                    prefix = "" if first else ",\n"
                    f.write(prefix + json.dumps(row, default=str))
                    first = False
                    row_count += 1
            f.write("\n]")
    else:
        with open(output_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(columns)
            while True:
                batch = cursor.fetchmany(500)
                if not batch:
                    break
                writer.writerows(batch)
                row_count += len(batch)

    cursor.close()
    size = os.path.getsize(output_path)
    print(f"[OracleDB] export_query_to_file → {output_path} ({row_count} rows, {size} bytes)")
    return json.dumps({"status": "ok", "rows": row_count, "path": output_path, "file_size_bytes": size})


def close_connection(connection_id: str) -> str:
    """
    Closes the Oracle database connection identified by connection_id.

    In MOCK mode: acknowledges the close without doing anything.
    In REAL mode: calls conn.close() on the stored connection object.

    Returns a JSON string: {"status": "closed", "connection_id": "<id>"}
    """
    if USE_MOCK_DB:
        print(f"[MockDB] close_connection() called for '{connection_id}'")
        return json.dumps({"status": "closed", "connection_id": connection_id})

    # Real implementation
    conn = _REAL_CONNECTIONS.pop(connection_id, None)
    if conn:
        conn.close()
        print(f"[OracleDB] Connection '{connection_id}' closed.")
    return json.dumps({"status": "closed", "connection_id": connection_id})
