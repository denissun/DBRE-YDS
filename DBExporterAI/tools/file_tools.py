"""
file_tools.py
-------------
Tools for writing query results to CSV/JSON files and saving error logs.
These tools work the same in both MOCK and REAL mode since they
only deal with the local filesystem.

Key behaviour:
  - Never overwrites an existing file — raises FileExistsError with a
    suggested timestamped alternative path so the Troubleshooter Agent
    can recommend it to the Exporter on the next attempt.
"""

import os
import json
import csv
from datetime import datetime


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _suggest_new_path(output_path: str) -> str:
    """
    Generates a non-colliding file path by appending a timestamp suffix.
    e.g. /tmp/employees.csv  →  /tmp/employees_20260415_143022.csv
    """
    base, ext = os.path.splitext(os.path.abspath(output_path))
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"{base}_{ts}{ext}"


def _parse_data_json(data_json: str) -> list:
    """
    Parses the data_json string into a list of dicts.
    Handles double-escaped backslashes (e.g. \\' → ') that Gemini
    sometimes introduces when passing function call arguments.
    """
    try:
        return json.loads(data_json)
    except json.JSONDecodeError:
        # Try fixing invalid \' escape sequences
        fixed = data_json.replace("\\'", "'")
        try:
            return json.loads(fixed)
        except json.JSONDecodeError:
            # Last resort: use ast.literal_eval on each row
            import ast
            fixed2 = fixed.replace('true', 'True').replace('false', 'False').replace('null', 'None')
            return ast.literal_eval(fixed2)


# ---------------------------------------------------------------------------
# Export functions
# ---------------------------------------------------------------------------

def export_to_csv(data_json: str, output_path: str) -> str:
    """
    Writes query result data to a CSV file.
    Raises FileExistsError if the file already exists — never overwrites.
    The error message includes a suggested timestamped alternative path.
    """
    data = _parse_data_json(data_json)
    if not data:
        raise ValueError("No data to export — query returned zero rows.")

    abs_path = os.path.abspath(output_path)

    if os.path.isfile(abs_path):
        suggested = _suggest_new_path(abs_path)
        raise FileExistsError(
            f"FILE_EXISTS: '{abs_path}' already exists and will not be overwritten. "
            f"Suggested alternative path: '{suggested}'"
        )

    os.makedirs(os.path.dirname(abs_path), exist_ok=True)

    fieldnames = list(data[0].keys())
    with open(abs_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)

    if not os.path.isfile(abs_path):
        raise OSError(f"File was not created at '{abs_path}' — unknown write error.")

    file_size = os.path.getsize(abs_path)
    result = {
        "status":          "success",
        "format":          "csv",
        "rows_written":    len(data),
        "output_path":     abs_path,
        "file_size_bytes": file_size,
    }
    print(f"[FileTool] CSV verified: {abs_path} ({file_size} bytes, {len(data)} rows)")
    return json.dumps(result)


def export_to_json(data_json: str, output_path: str) -> str:
    """
    Writes query result data to a JSON file.
    Raises FileExistsError if the file already exists — never overwrites.
    The error message includes a suggested timestamped alternative path.
    """
    data = _parse_data_json(data_json)
    if not data:
        raise ValueError("No data to export — query returned zero rows.")

    abs_path = os.path.abspath(output_path)

    if os.path.isfile(abs_path):
        suggested = _suggest_new_path(abs_path)
        raise FileExistsError(
            f"FILE_EXISTS: '{abs_path}' already exists and will not be overwritten. "
            f"Suggested alternative path: '{suggested}'"
        )

    os.makedirs(os.path.dirname(abs_path), exist_ok=True)

    with open(abs_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, default=str)

    if not os.path.isfile(abs_path):
        raise OSError(f"File was not created at '{abs_path}' — unknown write error.")

    file_size = os.path.getsize(abs_path)
    result = {
        "status":          "success",
        "format":          "json",
        "rows_written":    len(data),
        "output_path":     abs_path,
        "file_size_bytes": file_size,
    }
    print(f"[FileTool] JSON verified: {abs_path} ({file_size} bytes, {len(data)} rows)")
    return json.dumps(result)


# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

def read_file(file_path: str) -> str:
    """
    Reads and returns the content of a text file.
    Used by the Troubleshooter to inspect output files or logs.
    """
    abs_path = os.path.abspath(file_path)
    if not os.path.isfile(abs_path):
        raise FileNotFoundError(f"File not found: '{abs_path}'")
    with open(abs_path, "r", encoding="utf-8") as f:
        return f.read()


def save_error_log(error_message: str, log_dir: str = "logs") -> str:
    """
    Saves an error message to a timestamped log file in log_dir.
    Creates log_dir if it does not exist.
    Returns the path to the saved log file.
    """
    os.makedirs(log_dir, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = os.path.join(log_dir, f"error_{ts}.log")
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(error_message)
    print(f"[FileTool] Error log saved: {log_path}")
    return json.dumps({"status": "saved", "log_path": os.path.abspath(log_path)})
