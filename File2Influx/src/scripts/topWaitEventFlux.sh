#!/bin/bash
# Script:  topWaitEventInflux.sh
# Purpose genrate top 5 wait events and some selected metrics in last 5 minutes, call a Java program
# to load the data to Influxdb
# Notes:
#  1. sqlplus out is csv format
#
#    12.2
#    select json_object(
#                'event'  value event
#               ,'pct' value round(evttot*100/tot)
#               ,'wait_class' value wait_class
#               ,'beg_timestamp' value snap_start
#               ,'end_timestamp' value snap_end
#               ,'aas' value aas
#               ,'col_timestamp' value to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS')
#            )
#           from

#
# determine oracle home from $1
#
# example:
#    topWaitEventInflux.sh  <oracle_sid> <oratab_file>
#       <oratab_file> optional default /etc/ortab
#       correct oratab entries should be presented for <oracle_sid>

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR

SCRIPTNAME="$0"
export ORACLE_SID=$1

ORACLE_SID_1=${ORACLE_SID::${#ORACLE_SID}-1}

ORATAB=$2

if [ -z $ORATAB ]; then
ORATAB=/etc/oratab
fi

export ORACLE_HOME=`grep "^${ORACLE_SID_1}" $ORATAB | head -1 |  awk -F':' '{print $2}' `
echo $ORACLE_HOME
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH

#
# set up JAVA_HOME and KAFKA_HOME
#

if [ -f ../${ORACLE_SID}.cfg ]; then
  echo "config file for $ORACLE_SID exists"
  export JAVA_HOME=` grep "^JAVA_HOME" ../${ORACLE_SID}.cfg | awk -F'=' '{print $2}' `
else
  exit  0
fi


echo $JAVA_HOME


if [ -z $JAVA_HOME ]; then
   echo "JAVA_HOME is not set"
   exit 0
fi


sqlplus -s / <<EOF
set lines 400 pages 0 trimspool on echo off head off feedback off
spool top_wait_event_$1.csv

--
-- using a table bb to ensure 5 rows returned from the query
-- in case less than 5 wait events from active session view exists
--
select
    '"' || i.host_name ||'_'|| i.instance_name || '",'||
    '"' ||  a.event  || '",' ||
    '"' ||  round(a.evttot*100/tot)  || '",' ||
    '"' || a.wait_class  || '",' ||
    '"' ||a.snap_start || '",' ||
    '"' || a.snap_end  || '",' ||
    '"' || a.aas  || '",' ||
    '"' || a.rn || '",' ||
    '"' || to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS')   || '"'
from
(
        select aa.event, aa.wait_class, aa.evttot,aa.tot,aa.snap_start, aa.snap_end, aa.aas, bb.rn from
        (
          select
            decode(event,null,'CPU time',event) event,
                    decode(wait_class,null,'CPU',wait_class) wait_class,
                    evttot,
                    tot,
                    to_char( mint, 'YYYY-MM-DD HH24:MI:SS') snap_start,
                    to_char( maxt, 'YYYY-MM-DD HH24:MI:SS') snap_end,
                    row_number()  over(order by evttot desc) rn,
                    round(tot/( CAST( maxt AS DATE ) - CAST( mint AS DATE ))/ 86400 ,1) aas
                from (
                select distinct event,
                    wait_class,
                    count(*) over (partition by event) evttot,
                    count(*) over () tot,
                    min(sample_time) over () mint,
                    max(sample_time) over () maxt
                from v\$active_session_history
                where sample_time >= sysdate -5/1440
                )
        ) aa,
        (select level rn from dual connect by level < 6) bb
        where bb.rn = aa.rn(+)
) a, v\$instance i
;

----------------------------------------------------------------

select '"'|| metric_name ||'","'|| round(avg(value),1) ||'"'
from (
        SELECT
              a.metric_name, a.value
        FROM v\$sysmetric_history a
            where a.metric_name  in (
                 'Average Synchronous Single-Block Read Latency'
                ,'GC CR Block Received Per Second'
                ,'GC Current Block Received Per Second'
                ,'Database Time Per Sec'
                ,'DB Block Changes Per Sec'
                ,'Host CPU Utilization (%)'
                ,'Logical Reads Per Sec'
                ,'I/O Requests per Second'
                ,'Redo Generated Per Sec'
                ,'User Transaction Per Sec')
            and begin_time >= sysdate-5/1440
            )
group by metric_name
order by metric_name;

spool off
exit;
EOF


tagname="`hostname`_$1"

echo $tagname

$JAVA_HOME/bin/java -jar File2Influx-0.1.0.jar influx.properties top_wait_event_$1.csv eventSysmetric $tagname
