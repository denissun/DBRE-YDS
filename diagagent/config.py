# Database Healthcheck Agent Configuration
MAX_CHARS = 50000  # Increased for database response data
HEALTHCHECK_API_BASE = "http://dbaets.linuxhost1.com/oem/run_hc/api"
XPLAN_API_BASE = "http://dbaets.linuxhost1.com/oem/xplan/api"
TABIX_API_BASE = "http://dbaets.linuxhost1.com/oem/tabix/api"
COLSTATS_API_BASE = "http://dbaets.linuxhost1.com/oem/colstats/api"
TIMEOUT_SECONDS = 30

# Database health thresholds
WAIT_EVENT_THRESHOLDS = {
    "critical": 1000,  # milliseconds
    "warning": 500,
    "normal": 100
}

REPLICATION_LAG_THRESHOLDS = {
    "critical": 300,  # seconds
    "warning": 60,
    "normal": 10
}

# Supported database or database groups (can be expanded)
SUPPORTED_DATABASES = [
    "proddb",      # Production OLTP
    "oratst",      # Test environment
    "billdb",      # Billing validation
    "reportdb",    # Reporting
    "anadb"        # Analytics
]

# DB_RUN_SQL_API = "http://localhost:5000/api/db_run_sql"
DB_RUN_SQL_API = "http://dbaets.linuxhost1.com/dbaets/api/db_run_sql"