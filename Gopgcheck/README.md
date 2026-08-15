# Gopgcheck

A command-line utility program for PostgreSQL database administrators to interact with PostgreSQL databases more effectively. Gopgcheck is designed to complement `psql` with improved features such as **encrypted password management**, **active session sampling (AAS)**, and **comprehensive performance diagnostics**.

## Overview

Gopgcheck is written in Golang and provides a set of powerful commands for PostgreSQL health checks, performance monitoring, session management, workload analysis, and table/index inspection. It focuses on quick diagnosis and operational visibility for production PostgreSQL databases.

## Key Features

- **Encrypted Password Handling**: Securely encrypt and store database passwords in configuration files
- **Session Management**: List, filter, and terminate sessions with detailed diagnostics
- **Active Session Sampling (AAS)**: Real-time sampling of active sessions to understand workload distribution
- **Workload Analysis**: Monitor database metrics, SQL statistics, and transaction throughput
- **Table Analytics**: Analyze table aging, size, DML activity, and column statistics
- **Index Management**: View index definitions and attributes for tables
- **Blocker Detection**: Identify blocked and blocking sessions with full context
- **Configuration-Driven**: Use YAML config files to manage multiple database connections

## Installation

Build the binary:
```bash
go build -o gopgcheck
```

## Configuration

Create a `config.yml` file to define your database connections:

```yaml
database:
  host: your-postgres-host
  port: 5432
  user: your_user
  password: your_encrypted_password  # use 'gopgcheck encrypt' command
  dbname: your_database
```

### Encrypting Passwords

```bash
gopgcheck encrypt "your_plain_text_password"
```

This generates an encrypted password to be used in `config.yml`. The encryption key is read from a `.env` file:

```
APP_KEY=your-16-byte-encryption-key
```

## Commands

### `session` - Session Management and Diagnostics

List, filter, and manage active database sessions.

**List all sessions:**
```bash
gopgcheck session
```

**Filter sessions by username:**
```bash
gopgcheck session --username myuser
```

**Filter sessions by wait event:**
```bash
gopgcheck session --event ClientRead
```

**Filter sessions by state:**
```bash
gopgcheck session --state active
```

**Filter sessions by query text:**
```bash
gopgcheck session --query "SELECT"
```

**Filter sessions by application name:**
```bash
gopgcheck session --app myapp
```

**Expanded view (full query text):**
```bash
gopgcheck session --expand
```

**Show blockers and waiters:**
```bash
gopgcheck session --blocker
```

**Average Active Sessions (AAS) sampling:**
```bash
gopgcheck session --aas --duration 30
```

Samples active sessions every 1 second for 30 seconds and reports:
- Total AAS (Average Active Sessions)
- AAS by wait event type
- AAS by username
- AAS by application
- AAS by backend type
- AAS by client address/hostname
- Top 10 AAS by query

**Kill sessions:**
```bash
gopgcheck session --kill --pid 1234

# Multiple PIDs
gopgcheck session --kill --pid "1234,5678,9012"

# PIDs from query
gopgcheck session --kill --pid "SELECT pid FROM pg_stat_activity WHERE ..."
```

### `workload` - Workload Analysis and Metrics

Monitor database load, transaction throughput, and SQL performance.

**Database statistics since last reset:**
```bash
gopgcheck workload --db-stats-hist
```

Shows:
- Transactions per second
- Tuples returned/fetched/inserted/updated/deleted per second
- Block read/hit rates
- Deadlock count
- Temp file usage

**Real-time database metrics sampling:**
```bash
gopgcheck workload --db-stats --duration 10
```

Samples database metrics over 10 seconds and shows the rate of change.

**Real-time SQL statistics sampling:**
```bash
gopgcheck workload --sql-stats --duration 10 --limit 10
```

Samples top 10 SQLs over 10 seconds showing:
- Call count and rate
- Rows returned
- Logical reads (hit + read)
- Total elapsed time
- Time per call
- Logical reads per call

**Top SQLs since last reset:**
```bash
gopgcheck workload --top-sql --order ela --limit 10
```

Order options:
- `ela` - Total elapsed time (default)
- `ela-ps` - Elapsed time per call
- `get` - Total logical reads
- `get-ps` - Logical reads per call

### `table` - Table and Index Analysis

Inspect table properties, sizes, DML activity, and index definitions.

**Top aging tables:**
```bash
gopgcheck table --aging --limit 20
```

Shows tables with oldest frozen transaction IDs (vacuum candidates).

**Top tables by size:**
```bash
gopgcheck table --size --limit 20
```

**Top tables by DML activity:**
```bash
gopgcheck table --hot --limit 20
```

Shows tables with most INSERT/UPDATE/DELETE operations, including vacuum/analyze history.

**List indexes for a table:**
```bash
gopgcheck table --index --table-name mytable --schema public
```

Shows all indexes with:
- Primary key indicator
- Unique constraint indicator
- Clustered indicator
- Index validity status
- Index DDL statement

**Column statistics for a table:**
```bash
gopgcheck table --colstats --table-name mytable --schema public
```

Shows for each column:
- Data type and width information
- Null fraction
- Distinct value count
- Most common values and frequencies
- Column correlation
- Last ANALYZE/AUTOANALYZE timestamp

### `psql` - Execute SQL Commands

Execute SQL commands or files using psql under the hood (with encrypted credentials).

**Execute inline SQL:**
```bash
gopgcheck psql -c "SELECT version();"
```

**Execute SQL from file:**
```bash
gopgcheck psql -f script.sql
```

### `encrypt` - Password Encryption

Encrypt a plain-text password for use in config files.

```bash
gopgcheck encrypt "mypassword"
```

Returns the base64-encoded encrypted string to use in `config.yml`.

### `version` - Show Version

```bash
gopgcheck version
```

## Global Flags

- `--dbconfig <file>` - Path to database config file (default: `config.yml`)
- `--sql` - Output the SQL query text being executed

## Use Cases

### Quick Health Check
```bash
gopgcheck workload --db-stats-hist
gopgcheck session --blocker
gopgcheck table --hot --limit 5
```

### Find Performance Issues
```bash
gopgcheck session --aas --duration 20
gopgcheck workload --top-sql --order ela --limit 5
gopgcheck workload --sql-stats --duration 10
```

### Manage Long-Running Sessions
```bash
gopgcheck session --state active
gopgcheck session --kill --pid "<pid_list>"
```

### Table Maintenance
```bash
gopgcheck table --aging
gopgcheck table --size
gopgcheck table --colstats --table-name mytable --schema myschema
```

## Comparison with psql

| Feature | psql | gopgcheck |
|---------|------|-----------|
| Plain text password | ✓ | ✗ |
| Encrypted password | ✗ | ✓ |
| Session diagnostics | ✗ | ✓ |
| AAS sampling | ✗ | ✓ |
| Blocker detection | ✗ | ✓ |
| Workload metrics | ✗ | ✓ |
| SQL performance analysis | ✗ | ✓ |
| Table analytics | ✗ | ✓ |

## Technology Stack

- **Language**: Go 1.16+
- **Database Driver**: pgx (jackc/pgx)
- **CLI Framework**: Cobra
- **Encryption**: AES-256 CFB mode
- **Configuration**: YAML

## Author

Yu (Denis) Sun 
