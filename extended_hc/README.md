# Extended Real time Database Health Check

Provide DBAs a quick glimpse into database metrics collected within 5 minutes typically, which can indicate whether a database is healthy or not at the time of checking.

## Workflow

1. On the web portal (Python Flask App), user clicks a link to invoke run_hc_extended function
2. At the application server, shell script healthcheck_main.sh is executed with a database group config file as input argument
3. This script loops through each database defined in the config file to run sql scripts to gather health check data
4. Detailed HC data and a summary of the evaluation of those HC data are presented in the web portal

## Health Check Items

* Wait Event and AAS
* Top 10 SQLs by Elapsed Time (>10s) from Current Active Sessions
* Replication User Session Count
* Replication Latency 
* Resource Usage Limit (processes and sessions)
* XPLAN Change in past 24 hours
* Archive Log Dest Space Check
* Tablespace Check
* Parallelism in Tables and Indexes
* RMAN Job Running
* Gather Stats Job Running
* Avg Host CPU Utilization (%)
* Check I/O - Single Block Read Latency and IOPS
* Check App User Accounts Being Locked
* Alert Log Message in last 5 min


## `healthcheck_main.sh` Script Documentation

### Purpose

The `healthcheck_main.sh` script is the main orchestration script for performing extended real-time health checks on a group of Oracle databases. It is invoked by the Python Flask web application to execute parallel health checks across multiple databases and generate comprehensive HTML reports.

### Usage

```bash
healthcheck_main.sh <CONFIG_FILE> [DBNAME]
```

#### Arguments

- `CONFIG_FILE` - Configuration file (e.g., `VIP-CLUSTER-1.cfg`) containing database connection details
- `DBNAME` (optional) - Specific database name to check. If omitted, all databases in the config file are checked

### Script Workflow

1. **Initialization**
   - Sets up Oracle environment variables (`ORACLE_HOME`, `PATH`, `LD_LIBRARY_PATH`)
   - Creates necessary log directories
   - Parses configuration file to identify target databases

2. **Parallel Execution**
   - Spawns multiple instances of `healthcheck_one.sh` in parallel
   - Each child process handles health checks for a single database
   - Waits for all parallel jobs to complete with timeout handling

3. **Data Collection**
   - Each database is checked against the 15+ health check items listed above
   - SQL queries gather real-time metrics and historical data
   - Results are captured in individual spool files

4. **Analysis & Reporting**
   - Consolidates individual database spool files
   - Analyzes metrics against thresholds
   - Generates HTML-formatted summary report (`summary2_${GROUPNAME}.txt`)
   - Creates detailed report with individual database sections

5. **Cleanup**
   - Removes temporary files and completion markers
   - Archives old log files (older than 5 days)
   - Logs execution timing for performance monitoring

### Output Files

- `summary2_${GROUPNAME}.txt` - High-level summary displayed in web portal
- `logs/${GROUPNAME}_FILE_CONTENT.txt` - Detailed HTML report for all databases
- `logs/${LABEL}_${DATESTR}.spool` - Individual database health check results
- `logs/hc_exec_${DATESTR}.log` - Execution log with timing information

### Performance Features

- **Parallel Processing**: Executes health checks concurrently across multiple databases
- **Timeout Handling**: 60-second timeout per database to prevent hanging
- **Incremental Logging**: Tracks timing for each phase of execution
- **Resource Cleanup**: Automatically removes old log files to manage disk space

### Error Handling

- Generates error messages in HTML format when database checks fail
- Logs all errors to execution log file
- Provides fallback messages in web interface when script times out or fails

### Example

To run the health check for a specific database group configuration:

```bash
./healthcheck_main.sh my_db_group.cfg
```

To run the health check for a specific database within the group:

```bash
./healthcheck_main.sh my_db_group.cfg mydatabase
```

### Integration with Flask Application

The script is called by the `run_hc_extended` route in the Flask application:

```python
hcscript = '''{} {}.cfg '''.format(current_app.config["HCSCRIPT_EXTENDED"], GROUPNAME)
out = subprocess.run(hcscript, shell=True, timeout=60)
```

Results are read from the generated summary files and displayed in the `hc_output_extended.html` template.

### Notes

- Ensure that the script has the necessary permissions to execute and access the required files and directories.
- The script should be executed in an environment where the Oracle client is installed and configured, and the necessary network connectivity to the databases is available.
- Review the generated HTML report for detailed insights into the database health and any recommended actions.
