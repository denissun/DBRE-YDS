#/bin/bash
# gg_log_chk.sh
#   - find errors in the logs of metrics collection scripts to alert developer to fix bugs
#
# Author: Yu (Denis) Sun
#
# Modifications:
#    Denis  4-12-2020  created
#


NOTIFY=username@example.com

export PATH=~/bin:$PATH

host_name=`hostname`

SCRIPTDIR=`dirname $0`


# create_time=` date '+%Y-%m-%d %H:%M:%S' `

MSG=` egrep "^ORA-|^SP2-" $SCRIPTDIR/*.spool `

echo $MSG 

if [ -z "$MSG" ]; then
   echo "there are NO issues in the monitoring job"
else
   echo "there are issues in the monitoring job"
   echo $MSG |  mailx -s "gg monitoring job exeuction logs have errors  `hostname` " $NOTIFY  
   create_time=` date '+%Y%m%d%H%M%S' `
   mkdir -p  $SCRIPTDIR/spool_${create_time}
   mv $SCRIPTDIR/*.spool $SCRIPTDIR/spool_${create_time}/
   mv $SCRIPTDIR/*.sql $SCRIPTDIR/spool_${create_time}/
fi

