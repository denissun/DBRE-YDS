# DBA_SCRIPTS

A collection of frequently-used Oracle database administration scripts organized around a systematic troubleshooting methodology rooted in **wait event analysis**.

## Methodology Overview

When troubleshooting Oracle production database performance issues or conducting health checks, I follow a structured approach using four categories of diagnostic scripts. Start with `event.sql`, then select subsequent scripts based on the problem area identified.

![Script Categories Diagram]( https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEg9XaY8QB_6qJ33-M91fUgCezjNITolcf1_tQSOPQP5mp_qEUF7-MKoTbblkMw2un6NcWjwk1v30eKU41bS7ud3x9pSXc4Dtwu6OsZ90Mndq7Gv6NJ96hFQ75AzM11LFvlfP_ro/s1600/myscripts.PNG)

The scripts are organized into four categories:
- **Wait Events** (Green) - Executed first to identify performance bottlenecks
- **Workload** (Indicators) - Shows system-wide load and activity patterns  
- **Sessions** (Blue) - Investigates specific sessions causing the issue
- **SQLs** (Performance) - Deep-dives into SQL execution and plans

These scripts are designed for **pinpointing or narrowing down problem areas in the first 5-10 minutes** of troubleshooting production database issues, which often have a sense of urgency and require solutions to stabilize the system quickly.

---

## Wait Events Category

Scripts for analyzing database wait events to identify performance bottlenecks.

### event.sql
- **Purpose**: First script to execute; gives the count of each wait event
- **Use Case**: Quick way to show if there are any abnormalities
- **Expected**: In typical OLTP databases, 'db file sequential read' is the most counted event after idle events
- **Reference**: See Tanel Poder's thoughts on first-round session troubleshooting

### eventashg.sql
- **Purpose**: Show top 5 wait events for a given interval from `gv$active_session_history`
- **Similar to**: AWR top 5 wait events section
- **RAC-aware**: Probably the first script to use when checking RAC database health

### sw.sql (by Tanel Poder)
- **Purpose**: Given SID, show current wait event of a session

### snapper.sql (by Tanel Poder)
- **Purpose**: Very comprehensive—shows session statistics and wait events simultaneously
- **Note**: Use `snapper_dflt.sql` wrapper (included for convenience) for easier execution

---

## Workload Category

Scripts for understanding system load distribution and workload patterns.

### logsw.sql (by Jeff Hunter)
- **Purpose**: Display the number of log switches every hour in tabular format
- **Use Case**: Very useful to understand workload distribution patterns

### sysmetric.sql
- **Purpose**: Display system metrics from `gv$system_metric_history` including:
  - Redo Generated Per Sec
  - Host CPU Utilization (%)
  - User Transaction Per Sec
- **Timeframe**: Past 60 minutes
- **RAC-aware**: Primary or secondary script when checking RAC database health

### aas_ash.sql & aas_awr.sql
- **Purpose**: Display average active sessions from ASH and AWR respectively
- **Indicator**: AAS shows workload or performance changes over time

---

## Sessions Category

Scripts for investigating specific sessions and identifying blockers.

### sesevt.sql
- **Purpose**: Given wait event name, show sessions with that event

### qlocks.sql
- **Purpose**: Display blockers and waiters based on `v$lock` view

### longsql.sql
- **Purpose**: Display long-running SQLs
- **Use Case**: Quick way to find candidate "bad" SQLs in the database

### longops.sql
- **Purpose**: Display long operations from `v$session_longops`

### pxses.sql
- **Purpose**: Display parallel execution server sessions

### sessid.sql
- **Purpose**: Given session SID, display session-related information

### ses*.sql
- **Purpose**: Query `v$session` with various filters:
  - By machine
  - By server process ID
  - By OS user
  - By database user
  - By module

### sess_kill_batch.sql
- **Purpose**: Generate kill database session commands (database level)

### sess_kill_os.sql
- **Purpose**: Generate 'kill -9' commands for killing server processes at OS level

---

## SQLs Category

Scripts for analyzing SQL execution plans and performance.

### xplan.sql
- **Purpose**: Given sql_id, show the execution plan from cursor via `dbms_xplan.display_cursor()`

### sqlhistory.sql (by Tim Gorman)
- **Purpose**: Query the history of a specified SQL statement across all database instances
- **Uses**: AWR repository
- **Output**: Execution statistics per execution plan

### tabix.sql
- **Purpose**: List indexes of a table with column details and order
- **Use Case**: Very useful when tuning SQL queries

### tabcols.sql (from roughsea.com)
- **Purpose**: Display table column CBO statistics
- **Use Case**: Essential when performing SQL tuning

### bindvar.sql
- **Purpose**: Find representative bind values for a SQL statement
- **Use Case**: When tuning SQLs, helps identify execution patterns

### get_ddl.sql
- **Purpose**: Obtain definitions of database objects using `dbms_metadata` package
- **Use Case**: When tuning SQLs, understand underlying table structure and index definitions

---

## Key Principles

✓ **Wait Event Based**: Root cause analysis starts with wait event analysis  
✓ **Systematic Approach**: Follow logical sequence from symptom to root cause  
✓ **Quick Diagnosis**: Identify problem areas in 5-10 minutes  
✓ **Non-Invasive**: Gather diagnostic information without impacting production  
✓ **Urgency-Focused**: Built for quick stabilization of production issues  

---

## Reference

For the complete methodology and original blog post:  
https://oracle-study-notes.blogspot.com/2013/09/my-oracle-database-troubleshooting.html
