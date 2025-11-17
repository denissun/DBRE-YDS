#!/bin/bash
# Script: healthcheck_one.sh 
#  
#  healthcheck_one.sh <DSN> <LABEL> <CONFIG_FILE> <DATESTR>
#
# Description: Run health check for a single database
# Called by healthcheck.sh to enable parallel execution
#
# Arguments:
#   $1 - DSN connection string
#   $2 - Database label
#   $3 - Config file path
#   $4 - Date string for unique file naming
#
# Modifications
#    when           who     what
#    ------------   -----   -----------------------------------------------
#    Nov. 13, 2025  Denis   Initial version for parallel execution
#

export ORACLE_HOME=/u01/app/oracle/product/19.3.0/db_1

PATH=$PATH:$HOME/.local/bin:$HOME/bin:$PG_HOME/bin:.:$ORACLE_HOME/bin:/u01/app/go/bin:/u01/app/oracle/product/19.3.0/db_1/jdk/bin
export PATH

LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/local/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH

cd /u01/app/dbaets/utils/waitevent_all/extended_hc

# =============================================================================
# Parse Arguments
# =============================================================================
DSN="$1"
LABEL="$2"
CONFIG_FILE="$3"
DATESTR="$4"

if [[ -z "$DSN" ]] || [[ -z "$LABEL" ]] || [[ -z "$CONFIG_FILE" ]] || [[ -z "$DATESTR" ]]; then
    echo "Usage: $0 <DSN> <LABEL> <CONFIG_FILE> <DATESTR>" >&2
    exit 1
fi

VSAD=`echo $CONFIG_FILE | awk -F. '{print $1 }' `

# =============================================================================
# Setup output files for this database
# =============================================================================
SPOOLFILE="logs/${LABEL}_${DATESTR}.spool"
DB_START=$(date +%s)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] START: Processing [$LABEL] ($DSN)" >&2

# =============================================================================
# Read configuration parameters
# =============================================================================
REPLICATION_INFO_TAB=`cat $CONFIG_FILE | grep "^REPLICATION_INFO_TAB" | awk '{print $2}'` 
HOST_CPU_UTIL=`cat $CONFIG_FILE | grep "^HOST_CPU_UTIL" | awk '{print $2}'` 
IOPS_THRESHOLD=`cat $CONFIG_FILE | grep "^IOPS_THRESHOLD" | awk '{print $2}'` 

if [[ -z "$REPLICATION_INFO_TAB" ]]; then 
    REPLICATION_INFO_TAB="N/A"
fi

if [[ -z "$HOST_CPU_UTIL" ]]; then 
    HOST_CPU_UTIL="50"
fi

if [[ -z "$IOPS_THRESHOLD" ]]; then 
    IOPS_THRESHOLD="16000"
fi

# =============================================================================
# Execute SQL queries for this database
# =============================================================================
sqlplus -s newrelic_user/"`cat .pass`"@$DSN <<EOF
set trimspool on
spool $SPOOLFILE

pro <h3> ~~~  $DSN  ~~~ </h3>
pro <a href="#tableOfContents-top" style="font-size: 0.8em; margin-left: 10px;">[↑ Back to TOC] </a> 

pro <h4>  *** Wait Event and AAS  </h4>

pro <pre>
@eventashg5_v2 ${LABEL}
pro </pre>

pro
pro <h4> *** Top 10 SQLs by Elapsed Time (>10s) from Current Active Sessions   </h4>
pro

pro <pre>
@longsql.sql 
pro </pre>

pro
pro <h4> *** Replication User Session Count </h4>
pro
pro <pre>
@splex_running_server.sql
pro </pre>

column my_script new_value v_script noprint
select
    case when '${REPLICATION_INFO_TAB}' = 'N/A'  
    then 'na.sql'
    when '${REPLICATION_INFO_TAB}' = 'hc_gginfo_data'
    then 'check_gginfo.sql'
    else 'check_qstatus_v2.sql'
    end as my_script 
from dual;
 
-- pro *** Top 5 Splex Q backlog messages
pro <h4> *** Replication Latency  *** </h4>
pro <pre>
@&v_script  $REPLICATION_INFO_TAB 
pro </pre>

pro
pro <h4> *** Resource Usage Limit (processes and sessions)   </h4>

clear breaks
pro <pre>
@resource_limit.sql ${LABEL}
pro </pre>

pro
pro <h4> *** XPLAN Change in past 24 hours  </h4>
pro Note: the larger of CV_GETS_PER_EXEC  the more variant of the xplan ( only report > 50) 

pro <pre>
@xplan_change_report ${LABEL}
pro </pre>

pro
pro <h4> *** Archive Log Dest Space Check   </h4>

pro <pre>
@arch_dest ${LABEL}
pro </pre>

pro
pro <h4> *** Tablespace Check  </h4> 
pro <p> Data collected hourly </> 
pro <pre>
@check_tbs.sql ${LABEL}  ${DSN}
pro </pre>

pro
pro <h4> *** Parallelism in Tables and Indexes </h4>
pro <pre>
@object_parallel_degree.sql ${LABEL}
pro </pre>

pro
pro <h4> *** RMAN Job Running </h4>
pro <pre>
@rman_operations.sql ${LABEL}
pro </pre>

pro
pro <h4> *** Gather Stats Job Running </h4>
pro <pre>
@stats_job.sql ${LABEL}
pro </pre>

pro
pro <h4> *** Avg Host CPU Utilization (%)</h4>
pro <p> Average in last 2 min, current threshold setting: ${HOST_CPU_UTIL} </p>
pro <pre>
@cpu_util.sql ${LABEL} ${HOST_CPU_UTIL} 
pro </pre>

pro
pro <h4> *** Check I/O - Single Block Read Latency and IOPS </h4>
pro <pre>
@check_io.sql ${LABEL} ${IOPS_THRESHOLD}
pro </pre>

pro
pro <h4> *** Check App User Accounts Being Locked  </h4>
pro <pre>
@app_account_status.sql ${LABEL} 
pro </pre>

pro
pro <h4>  *** Alert Log Message in last 5 min </h4>   

pro <pre>
@check_alertlog.sql  ${LABEL} 
pro </pre>

spool off
exit
EOF

DB_END=$(date +%s)
ELAPSED=$((DB_END - DB_START))

echo "[$(date '+%Y-%m-%d %H:%M:%S')] COMPLETED: [$LABEL] in ${ELAPSED}s" >&2

# Write completion marker
echo "COMPLETED:${LABEL}:${ELAPSED}" > "logs/${LABEL}_${DATESTR}.done"

exit 0
