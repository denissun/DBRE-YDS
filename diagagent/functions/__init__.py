"""Local tool functions package.

Exports:
	check_tablespace_usage(db_name: str) -> str
	check_waitevent(db_name: str) -> str
	check_blockers(db_name: str) -> str
	check_long_running_sql(db_name: str) -> str
	get_xplan_sharedpool(db_name: str, sql_id: str) -> str
	get_object_owner(db_name: str, object_name: str) -> str
	check_invalid_objects(db_name: str) -> str
	top_sql_by_elapsed_time_15min(db_name: str) -> str
	run_sql(db_name: str, sql_text: str) -> str
	run_sql_databases(databases: list[str], sql_text: str) -> str
"""

try:
	from .check_tablespace_usage import check_tablespace_usage  # noqa: F401
except Exception:  # pragma: no cover - optional dependency cases
	check_tablespace_usage = None  # type: ignore
try:
	from .check_waitevent import check_waitevent  # noqa: F401
except Exception:  # pragma: no cover
	check_waitevent = None  # type: ignore
try:
	from .check_blockers import check_blockers  # noqa: F401
except Exception:  # pragma: no cover
	check_blockers = None  # type: ignore
try:
	from .check_long_running_sql import check_long_running_sql  # noqa: F401
except Exception:  # pragma: no cover
	check_long_running_sql = None  # type: ignore
try:
	from .get_xplan_sharedpool import get_xplan_sharedpool  # noqa: F401
except Exception:  # pragma: no cover
	get_xplan_sharedpool = None  # type: ignore
try:
	from .get_object_owner import get_object_owner  # noqa: F401
except Exception:  # pragma: no cover
	get_object_owner = None  # type: ignore
try:
	from .check_invalid_objects import check_invalid_objects  # noqa: F401
except Exception:  # pragma: no cover
	check_invalid_objects = None  # type: ignore
try:
	from .top_sql_by_elapsed_time_15min import top_sql_by_elapsed_time_15min  # noqa: F401
except Exception:  # pragma: no cover
	top_sql_by_elapsed_time_15min = None  # type: ignore
try:
	from .run_sql import run_sql  # noqa: F401
except Exception:  # pragma: no cover
	run_sql = None  # type: ignore
try:
	from .run_sql_databases import run_sql_databases  # noqa: F401
except Exception:  # pragma: no cover
	run_sql_databases = None  # type: ignore

__all__ = [
	"check_tablespace_usage",
	"check_waitevent",
	"check_blockers",
	"check_long_running_sql",
	"get_xplan_sharedpool",
	"get_object_owner",
	"check_invalid_objects",
	"top_sql_by_elapsed_time_15min",
	"run_sql",
	"run_sql_databases",
]
