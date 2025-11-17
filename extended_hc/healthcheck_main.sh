#!/bin/bash
# Script: healthcheck.sh 
#  
#  heathcheck.sh CHHV-RDS 
#  heathcheck.sh <CHHV-RDS> <DBNAME> 
#
# Modifications
#
#    when           who     what
#    ------------   -----   -----------------------------------------------
#    Nov. 13, 2025  Denis   Added execution timing and logging
#    Nov. 13, 2025  Denis   For extended HC 
#    Sep. 12, 2025  Denis   processing GGINFO data 
#    Sep. 1, 2025   Denis   SINGLE_EVENT_AAS_THRESHOLD
#

export ORACLE_HOME=/u01/app/oracle/product/19.3.0/db_1

PATH=$PATH:$HOME/.local/bin:$HOME/bin:$PG_HOME/bin:.:$ORACLE_HOME/bin:/u01/app/go/bin:/u01/app/oracle/product/19.3.0/db_1/jdk/bin
export PATH

LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/local/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH

# =============================================================================
# Timing and Logging Functions
# =============================================================================
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_msg() {
    local msg="$1"
    echo "[$(get_timestamp)] $msg" >> "$EXEC_LOG"
}

log_timing() {
    local task_name="$1"
    local start_time="$2"
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    
    if [ $mins -gt 0 ]; then
        log_msg "COMPLETED: $task_name - ${mins}m ${secs}s (${elapsed}s total)"
        echo "  ✓ $task_name completed in ${mins}m ${secs}s" >&2
    else
        log_msg "COMPLETED: $task_name - ${elapsed}s"
        echo "  ✓ $task_name completed in ${elapsed}s" >&2
    fi
}

# =============================================================================
# Main Script Start
# =============================================================================

cd /u01/app/dbaets/utils/waitevent_all/extended_hc

DATESTR=`date +%y%m%d%H%M%S`
SCRIPT_START=$(date +%s)

VSAD=`echo $1 | awk -F. '{print $1 }' `

# Initialize execution log
EXEC_LOG="logs/exec_timing_${VSAD}_${DATESTR}.log"
echo "==============================================================================" > "$EXEC_LOG"
echo "Health Check Execution Timing Log" >> "$EXEC_LOG"
echo "Config File: $1" >> "$EXEC_LOG"
echo "VSAD: ${VSAD}" >> "$EXEC_LOG"
echo "Started at: $(get_timestamp)" >> "$EXEC_LOG"
echo "==============================================================================" >> "$EXEC_LOG"
echo "" >> "$EXEC_LOG"

if [[ !  -f  "$1" ]];
then
  echo "$1 does not exist" > summary2_${VSAD}.txt
  echo "$1 does not exist, please contact Denis if you think this HC for the application $VSAD should be configured." 
  exit 1  
fi

#
# concurrent user should use different files so append $DATESTR 
# chances for more than two users run the program at exact as same time is small 
#
SPOOLFILE=logs/$1_${VSAD}_${DATESTR}.spool
export SUMMARYFILE=logs/summary2_${VSAD}_${DATESTR}.txt
TMPFILE=logs/temp_$1_${DATESTR}.txt

cat /dev/null > $SUMMARYFILE

echo "<h5> Issue Highlight</h5>" >> $SUMMARYFILE

REPLICATION_INFO_TAB=`cat $1 | grep "^REPLICATION_INFO_TAB" | awk '{print $2}'` 
HOST_CPU_UTIL=`cat $1 | grep "^HOST_CPU_UTIL" | awk '{print $2}'` 

if  [[ -z "$REPLICATION_INFO_TAB" ]];
then 
REPLICATION_INFO_TAB="N/A"
fi

if  [[ -z "$HOST_CPU_UTIL" ]];
then 
HOST_CPU_UTIL="50"
fi


DBNAME=$2

if [[ -z "$DBNAME" ]]; then
DBNAME=DSN
fi

log_msg "Starting parallel database queries phase"
DB_QUERY_PHASE_START=$(date +%s)

# =============================================================================
# Launch parallel jobs for each database
# =============================================================================
DB_NUM=0
PIDS=()
LABELS=()

cat $1 | grep "^DSN" | grep "${DBNAME}" | awk '{print $2" "$3}' |  while read dsn  label
do
    DB_NUM=$((DB_NUM + 1))
    log_msg "LAUNCHING: Database #${DB_NUM} - [$label] ($dsn) [background]"
    
    # Launch healthcheck_one.sh in background
    ./healthcheck_one.sh "$dsn" "$label" "$1" "$DATESTR" &
    
    PID=$!
    echo "$PID:$label" >> "logs/parallel_jobs_${DATESTR}.tmp"
    
    echo "  → Launched background job for [$label] (PID: $PID)" >&2
done

log_msg "All database jobs launched, waiting for completion..."

# =============================================================================
# Wait for all background jobs to complete
# =============================================================================
WAIT_START=$(date +%s)
MAX_WAIT=600  # Maximum 10 minutes wait per database

if [[ -f "logs/parallel_jobs_${DATESTR}.tmp" ]]; then
    while read job_info; do
        PID=$(echo $job_info | cut -d: -f1)
        LABEL=$(echo $job_info | cut -d: -f2)
        
        log_msg "Waiting for [$LABEL] (PID: $PID)..."
        
        # Wait for the process with timeout
        COUNTER=0
        while kill -0 $PID 2>/dev/null; do
            sleep 1
            COUNTER=$((COUNTER + 1))
            
            if [ $COUNTER -ge $MAX_WAIT ]; then
                log_msg "WARNING: [$LABEL] (PID: $PID) exceeded timeout of ${MAX_WAIT}s, killing..."
                kill -9 $PID 2>/dev/null
                echo "TIMEOUT:${LABEL}:${MAX_WAIT}" > "logs/${LABEL}_${DATESTR}.done"
                break
            fi
        done
        
        # Check if completed successfully
        if [[ -f "logs/${LABEL}_${DATESTR}.done" ]]; then
            RESULT=$(cat "logs/${LABEL}_${DATESTR}.done")
            log_msg "FINISHED: $RESULT"
        fi
    done < "logs/parallel_jobs_${DATESTR}.tmp"
    
    rm -f "logs/parallel_jobs_${DATESTR}.tmp"
fi



# =============================================================================
# Combine all individual spool files into one master spool file
# =============================================================================
log_msg "Combining individual database results..."
COMBINE_START=$(date +%s)

SPOOLFILE=logs/$1_${VSAD}_${DATESTR}.spool
cat /dev/null > $SPOOLFILE

cat $1 | grep "^DSN" | grep "${DBNAME}" | awk '{print $3}' |  while read label
do
    if [[ -f "logs/${label}_${DATESTR}.spool" ]]; then
        cat "logs/${label}_${DATESTR}.spool" >> $SPOOLFILE
        echo "" >> $SPOOLFILE
    else
        log_msg "WARNING: Missing spool file for [$label]"
        echo "<h3>~~~ $label ~~~</h3>" >> $SPOOLFILE
        echo "<p style='color:red;'>ERROR: Health check did not complete for this database</p>" >> $SPOOLFILE
    fi
done

log_timing "Combining results" $COMBINE_START

log_timing "Parallel database query phase (all DBs)" $DB_QUERY_PHASE_START

echo ""
echo ""
# COPY combined spool to special FILEC_CONTENT file to represt on web
cp $SPOOLFILE  logs/${VSAD}_FILE_CONTENT.txt
echo "<h4> CURRENT BLACKOUT LIST - Excluding from check </h4> " >> logs/${VSAD}_FILE_CONTENT.txt
echo "<pre>" >> logs/${VSAD}_FILE_CONTENT.txt
cat $1 |  grep "^BLACKOUT" >>  logs/${VSAD}_FILE_CONTENT.txt 
echo "</pre>" >> logs/${VSAD}_FILE_CONTENT.txt


# echo "<p> ~~~~~~~~~~  CHECK IF ANY OBVIOUS ANONMALIES  ~~~~~~~~~~~~~~</p>"

ANALYSIS_START=$(date +%s)
log_msg "Starting anomaly analysis phase"

SINGLE_EVENT_AAS_THRESHOLD=`cat $1 | grep "^SINGLE_EVENT_AAS_THRESHOLD " | awk '{print $2}'`


## echo  "<p> Rule 1 - Is there any AAS > $SINGLE_EVENT_AAS_THRESHOLD for a single Wait Event? </p>"  

## echo "<p> Assessment is based on real time WAIT Event, AAS and replication backlog data  </p> " > ${SUMMARYFILE}

RULE1_START=$(date +%s)
log_msg "START: Rule 1 - High AAS check (threshold: $SINGLE_EVENT_AAS_THRESHOLD)"

## ds
cat $1 | grep "^DSN" | grep "${DBNAME}" |  awk '{print $3}' | while read LABEL
do 
# !! WARNING high AAS : 1 | CPU+Wait for CPU | CPU | 81.2 | 23 | 11/10/25 19:21:32 | 19:26:31 | ~data~MTASWPR1

SINGLE_EVENT_AAS_THRESHOLD=`cat $1 | grep "^SINGLE_EVENT_AAS_THRESHOLD_${LABEL} " | awk '{print $2}'`

if [[ -z ${SINGLE_EVENT_AAS_THRESHOLD} ]];
then
SINGLE_EVENT_AAS_THRESHOLD=10
fi

grep "~data~$LABEL"  $SPOOLFILE | awk -F'|' -v threshold=$SINGLE_EVENT_AAS_THRESHOLD '{if ( $5 > threshold ) print "!! WARNING high AAS : " $1 "|" $2 "|" $3 "|" $4 "|<strong style=\"color:red;\"> " $5 " </strong>|" $6 "|"  $7 "|" $8 "| <br/>"  }' > $TMPFILE

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\">$LABEL :  AAS is higher than ${SINGLE_EVENT_AAS_THRESHOLD}, investigate immediately </p>"   >> ${SUMMARYFILE}
  echo "<p>" >> ${SUMMARYFILE}
  cat $TMPFILE >> ${SUMMARYFILE}
  echo "</p>" >> ${SUMMARYFILE}
fi

done

log_timing "Rule 1 - High AAS check" $RULE1_START

RULE2_START=$(date +%s)
log_msg "START: Rule 2 - Bad wait events check"

## echo "<p> Rule 2 - Are there any ~bad~ wait events at top 5 with significant AAS (> 3)? </p> "  

bad_event_awk_script='
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)); }
{
if (  $5 > 3  )  {
    if ( trim($2) ~ /^enq:/ || trim($2) ~ /^read by other session/ || trim($2) ~ /^cursor:/ || trim($2) ~ /^buffer busy waits/ || trim($2) ~ /^db file scattered read/ || trim($2) ~ /^direct path/ || trim($2) ~ /^gc buffer busy/ || trim($2) ~ /^gc cr/ || trim($2) ~ /^latch/ || trim($2) ~ /^library cache lock/ ||trim($2) ~ /^resmgr:cpu quntum/ ) {
    print "!! WARNING Bad Wait Event: <strong style=\"color:red;\"> "  trim($2)  " </strong>  AAS: " $5  "<br/>"
   }
}
}
'
# ds
cat $1 | grep "^DSN" | grep "${DBNAME}" | awk '{print $3}' | while read LABEL
do 
  grep "~$LABEL"  $SPOOLFILE | awk -F'|' -v label=$LABEL "$bad_event_awk_script"  > $TMPFILE 
if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;\"> $LABEL: Bad wait event </p>"   >> ${SUMMARYFILE}
  echo "<p>" >> ${SUMMARYFILE}
  cat $TMPFILE >> ${SUMMARYFILE}
  echo "</p>" >> ${SUMMARYFILE}
fi

done

log_timing "Rule 2 - Bad wait events check" $RULE2_START

#####  Check replication  problem   ###########

REPL_CHECK_START=$(date +%s)
log_msg "START: Replication checks" 

# OGG 
if [[ "${REPLICATION_INFO_TAB}" = "hc_gginfo_data" ]];
then
## echo "<p>Rule 3 - GoldenGate Lag Checking? </p> "  

gginfo_awk_script='
{
if ( $4 ~ /ABENDED|STOPPED/ ) {
  print  $0
} else if ( $6 ~ /[0-9]{2}:[0-9]{2}:[0-9]{2}/ && $7 ~ /[0-9]{2}:[0-9]{2}:[0-9]{2}/  ) {
  split($6, v, ":")
  split($7, v2, ":")
  if ( v[1]*3600 + v[2]*60 + v[3] > 300 ) {
     print  $0
  } else if ( v2[1]*3600 + v2[2]*60 + v2[3] > 300 ) {
     print  $0
  }
}
}
'
cat $SPOOLFILE | grep  "GG_BKLOG" |  sed 's/\s*$//g' |   awk -F'|' "$gginfo_awk_script"  > $TMPFILE

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> GG Replication LAG execeeds thresholds - 5 min or Abended/Stopped Groups</p>"   >> ${SUMMARYFILE}
  cat $TMPFILE >> ${SUMMARYFILE}
fi
# SPLEX
else
SPLEX_BACKLOG_AGE=5
NUM_BACKLOG_MSG=50000

## echo "Rule 3 - Splex backlog age > $SPLEX_BACKLOG_AGE min or number of messages > ${NUM_BACKLOG_MSG}? "  

q_backlog_awk_script='{
if (  $5 > NUM_BACKLOG_MSG  || $6 > SPLEX_BACKLOG_AGE  )  {
    print "<p style=\"color:red;\"> "  $0 "</p>"
}
}
'
grep "Q_BKLOG"  $SPOOLFILE | awk -F'|' -v NUM_BACKLOG_MSG=$NUM_BACKLOG_MSG -v SPLEX_BACKLOG_AGE=$SPLEX_BACKLOG_AGE  "$q_backlog_awk_script"  > $TMPFILE

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> Splex Replication Queue Backlog execeeds thresholds - num msg: $NUM_BACKLOG_MSG age: $SPLEX_BACKLOG_AGE min</p>"   >> ${SUMMARYFILE}
  cat $TMPFILE >> ${SUMMARYFILE}
fi

fi

log_timing "Replication checks" $REPL_CHECK_START

#####  Check tablespace problem   ########### 

TBS_CHECK_START=$(date +%s)
log_msg "START: Tablespace check"

cat $SPOOLFILE | grep  "~TBS" |  grep "ALERT"  > $TMPFILE
if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> Tablespace has issue please check</p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | awk '{print $0 "<br/>"}' >> ${SUMMARYFILE}
fi

log_timing "Tablespace check" $TBS_CHECK_START

#####  Check XPLAN change problem   ########### 

XPLAN_CHECK_START=$(date +%s)
log_msg "START: XPLAN change check"

cat $SPOOLFILE | grep  "~XPLAN" > $TMPFILE
if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> There are XPLAN change in the following db: </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | awk '{print $0 "<br/>"}' >> ${SUMMARYFILE}
fi

log_timing "XPLAN change check" $XPLAN_CHECK_START

#####  Check if RAMN Job running    ########### 

log_msg "START: RMAN JOB check"

cat $SPOOLFILE | grep  "~RMAN" > $TMPFILE
if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> There are RMAN jobs running at this time, check if they are legitimate. </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | head -5 | awk '{print $0 "<br/>"}' >> ${SUMMARYFILE}
fi

#####  Check if STASTS Gathering Job running    ########### 

log_msg "START: STATS gatehring JOB check"

cat $SPOOLFILE | grep  "~GATHER-STATS" > $TMPFILE
if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> There are STATS gathering jobs running at this time, check if they are legitmate. </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | head -5 | awk '{print $0 "<br/>"}' >> ${SUMMARYFILE}
fi

#####  Check if IO has problem running    ########### 

log_msg "START: STATS gatehring JOB check"

cat $SPOOLFILE | grep  "~IO-"  | grep "ALERT" > $TMPFILE
if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> IO Warnings - IOPS may be higher than normal or IO is slower. </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | head -5 | awk '{print $0 "<br/>"}' >> ${SUMMARYFILE}
fi

#####  Check if App User Account    ########### 

log_msg "START: STATS gatehring JOB check"

EXCL_DB_LIST=`cat $1  | grep  "^BLACKOUT" | grep "APPUSER_ACCOUNT_STATUS" | awk '{print $3 }'`

if [[ -n "${EXCL_DB_LIST}" ]];
then
cat $SPOOLFILE | grep  "~APP_USER" | egrep -v "${EXCL_DB_LIST}"   > $TMPFILE
else
cat $SPOOLFILE | grep  "~APP_USER"   > $TMPFILE
fi

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> Warning - Application user account has been locked recently, please verify! </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | head -5 | awk '{print $1 "| <strong>" $2 "</strong>| " $3 "| " $4 "| " $5 "<br/>"}' >> ${SUMMARYFILE}
fi

#####  Check parallel degree in table/index    ########### 

log_msg "START: Object Parallel degree check"

EXCL_DB_LIST=`cat $1  | grep  "^BLACKOUT" | grep "OBJECT_PARALLEL_DEGREE" | awk '{print $3 }'`

if [[ -n "${EXCL_DB_LIST}" ]];
then
cat $SPOOLFILE | grep "^~parallel-degree" | egrep -v "${EXCL_DB_LIST}"  > $TMPFILE
else
cat $SPOOLFILE | grep "^~parallel-degree"   > $TMPFILE
fi

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> Warning - Parallel degree setting may have problems in tables or indexes! </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | head -5 | awk '{ print $0 "<br/>"}' >> ${SUMMARYFILE}
fi
echo " ------------------------------------------------------------------"

#####  Check Resource Usage   ########### 

log_msg "START: Check Resource Usage"

EXCL_DB_LIST=`cat $1  | grep  "^BLACKOUT" | grep "RESOURCE_USAGE" | awk '{print $3 }'`

if [[ -n "${EXCL_DB_LIST}" ]];
then
cat $SPOOLFILE | grep "^~RSRC_USAGE_LIMIT" | egrep -v "${EXCL_DB_LIST}"  | grep "ALERT" > $TMPFILE
else
cat $SPOOLFILE | grep "^~RSRC_USAGE_LIMIT"  | grep "ALERT" > $TMPFILE
fi

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> Warning - Resource Usage Limit Threshold Exceeded! </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | head -5 | awk '{ print $0 "<br/>"}' >> ${SUMMARYFILE}
fi
echo " ------------------------------------------------------------------"




#####  Check Alert log problem   ########### 

ALERT_CHECK_START=$(date +%s)
log_msg "START: Alert log check"

cat $SPOOLFILE | grep  "~ALERT" | grep "ORA-" | grep -v "ORA-0$" > $TMPFILE

if [[ -s  $TMPFILE ]];
then
  echo "<p style=\"color:red;font-weight:bold;\"> There are ORA errors in alert log in last 5 min : </p>"   >> ${SUMMARYFILE}
  cat $TMPFILE | awk '{print $0 "<br/>"}' >> ${SUMMARYFILE}
fi

log_timing "Alert log check" $ALERT_CHECK_START

### Last HC item Blackout expiration date check #####
# in file $1 there are following lines:
# BLACKOUT OBJECT_PARALLEL_DEGREE  MSCPREP   2026-01-31
cat $1 | grep "^BLACKOUT" | while read line
do
    ITEM=$(echo $line | awk '{print $2}')
    DB_NAME=$(echo $line | awk '{print $3}')
    EXPIRATION_DATE=$(echo $line | awk '{print $4}')
    if [[ -n "$EXPIRATION_DATE" && "$EXPIRATION_DATE" != "N/A" ]];
    then
        CURRENT_DATE=$(date +%Y-%m-%d)
        if [[ "$CURRENT_DATE" > "$EXPIRATION_DATE" ]];
        then
            echo "<p style=\"color:red;font-weight:bold;\"> BLACKOUT item for $DB_NAME on $ITEM has EXPIRED on $EXPIRATION_DATE. Please contact Admin to review! </p>" >> ${SUMMARYFILE}
        fi
    fi 
done

#####  END of check HC item   ########### 

echo ""
echo ""
echo "<br/> Tips: you can always check individual db health in a group by specifying dbname option " 
echo "https://appportal.mycomp.com/dbaets/oem/run_hc/<group_name>?dbname=<dbname> "
echo "For example:  https://appportal.mycomp.com/dbaets/oem/run_hc/GRPNAME?dbname=testdb" 


echo ""
echo "<br/>"
echo "<a href=\"#tableOfContents-top\" style=\"font-size: 0.8em; margin-left: 10px;\">[↑ Back to TOC] </a> "
echo "<br/>"


##########################

SUMMARY_GEN_START=$(date +%s)
log_msg "START: Summary generation"

# echo "~~~~~~~~~~~~~   loop through each label (represent a unique db) ~~~~~~~~~~~~~~~"

echo "<hr><h5> DB Overall Status </h5>"  >> ${SUMMARYFILE}

cat $1 | grep "^DSN" | grep "${DBNAME}" | awk '{print $3}' | while read LABEL
do
if [[ -z "`grep -i \" ${LABEL} \" ${SUMMARYFILE}`" && -z "`grep -i ~${LABEL} ${SUMMARYFILE}`" ]];
then
  echo "<p style=\"color:green;font-weight:bold;\"> $LABEL: healthy no issue</p>" >> ${SUMMARYFILE}
else
  # Changed color to orange (or a bright gold) for a clear warning against white.
  echo "<p style=\"color:orange;font-weight:bold;\"> $LABEL: Warning! </p>" >> ${SUMMARYFILE}
fi
done


# the content of summary.txt is presented on the web 
cat ${SUMMARYFILE} > summary2_${VSAD}.txt
echo "" >> summary2_${VSAD}.txt
echo "<i> Reported on: `date` </i> " >> summary2_${VSAD}.txt

log_timing "Summary generation" $SUMMARY_GEN_START

log_timing "Total anomaly analysis" $ANALYSIS_START

CLEANUP_START=$(date +%s)
log_msg "START: Log cleanup"

# Clean up individual database spool files and completion markers
cat $1 | grep "^DSN" | grep "${DBNAME}" | awk '{print $3}' |  while read label
do
    rm -f "logs/${label}_${DATESTR}.spool"
    rm -f "logs/${label}_${DATESTR}.done"
done

find ./logs -name "*.txt" -mtime +5 -exec rm -rf {} \;
find ./logs -name "*.spool" -mtime +5 -exec rm -rf {} \;
find ./logs -name "*.done" -mtime +5 -exec rm -rf {} \;

log_timing "Log cleanup" $CLEANUP_START

# =============================================================================
# Script Completion Summary
# =============================================================================
SCRIPT_END=$(date +%s)
TOTAL_ELAPSED=$((SCRIPT_END - SCRIPT_START))
MINS=$((TOTAL_ELAPSED / 60))
SECS=$((TOTAL_ELAPSED % 60))

echo "" >> "$EXEC_LOG"
echo "==============================================================================" >> "$EXEC_LOG"
echo "Health Check Completed" >> "$EXEC_LOG"
echo "Ended at: $(get_timestamp)" >> "$EXEC_LOG"
if [ $MINS -gt 0 ]; then
    echo "Total Execution Time: ${MINS}m ${SECS}s (${TOTAL_ELAPSED}s total)" >> "$EXEC_LOG"
else
    echo "Total Execution Time: ${TOTAL_ELAPSED}s" >> "$EXEC_LOG"
fi
echo "==============================================================================" >> "$EXEC_LOG"

# Print summary to console
echo "" >&2
echo "==============================================================================" >&2
echo "Health Check Completed Successfully" >&2
if [ $MINS -gt 0 ]; then
    echo "Total Execution Time: ${MINS}m ${SECS}s" >&2
else
    echo "Total Execution Time: ${TOTAL_ELAPSED}s" >&2
fi
echo "Detailed timing log: $EXEC_LOG" >&2
echo "==============================================================================" >&2

# Keep timing logs for 30 days
find ./logs -name "exec_timing_*.log" -mtime +30 -exec rm -rf {} \;
