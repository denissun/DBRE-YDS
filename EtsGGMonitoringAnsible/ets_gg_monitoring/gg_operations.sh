#/bin/bash
# gg_operations.sh
#   - load REPLICAT group operations statistics into the repository.${host_name}.database. 
#
# Author: Yu (Denis) Sun
#
# Notes:
#    - It requires run ggconf.sh first to set up.${host_name}.sqlplus env and db user account
#    - EXTRACT group operations statistics are not collected
#
# Modifications:
#    Denis  4-12-2020  created
#


host_name=`hostname`

SCRIPTDIR=`dirname $0`

if [[ -z `ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }'` ]]
then
  echo "no mgr prcocess exiting "
  exit 0
fi

echo "$0 start `date`"

# memo: we should use ET consistently

create_time=`date '+%Y-%m-%d %H:%M:%S' `

{
ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }' |sed 's/dirprm\/mgr.prm/ggsci/' | awk NF | while read command
do

echo  "GGHOME  $command  "
echo "info all " | $command
echo " "
done
}  > $SCRIPTDIR/infoall_operations.${host_name}.dat



##
## the timestamp to get stats for each group may be different
## check for abend if abend generate abend reprot

{
cat $SCRIPTDIR/infoall_operations.${host_name}.dat | awk NF | while read program  status  group  lag   chkpt
do

if [ "$program" = "GGHOME" ]
then
   GGHOME=` echo $status | sed 's/ggsci//' `
   GGHOME_GGSCI=` echo $status `
   continue
fi

if [  "$program" = "REPLICAT" ]
then
  echo  "Total stats $GGHOME $group on `date +%Y-%m-%d-%H:%M:%S` "
  echo " stats replicat $group TOTAL, TOTALSONLY *.* " | $GGHOME_GGSCI  | grep -i Total
fi

done
}  > $SCRIPTDIR/stats_operations.${host_name}.dat



cat $SCRIPTDIR/stats_operations.${host_name}.dat | awk -v hostname=$host_name -v ctime="$create_time" ' 
BEGIN {
   operations=0;
   inserts=0;
   updates=0;
   deletes=0;
   discards=0;
}
{
   if ( $0 ~ /^Total stats/ ) {
      if ( operations != 0 ) {
         printf("insert into apex_gg_operations(CREATE_TIME,HOST_NAME,GG_HOME,PROGRAM, GROUP_NAME,INSERTS,UPDATES,DELETES,DISCARDS,OPERATIONS,RESET_TS,STATS_TIME) values(to_date(\x27%s\x27,\x27YYYY-MM-DD HH24:MI:SS\x27), \x27%s\x27,\x27%s\x27, \x27Replicat\x27,\x27%s\x27,%s,%s,%s,%s,%s,to_date(\x27%s\x27,\x27YYYY-MM-DD HH24:MI:SS\x27), to_date(\x27%s\x27,\x27YYYY-MM-DD-HH24:MI:SS\x27)); \n",ctime, hostname,  gghome, group_name,inserts,updates,deletes,discards, operations, reset_ts, stats_time)
      }
      gghome=$3;
      group_name=$4
      stats_time=$6
      operations=0
   }   
   else if ($0 ~ /Total operations/) {
      operations=$3
   }
   else if ($0 ~ /Total inserts/) {
      inserts=$3
   }
   else if ($0 ~ /Total updates/) {
      updates=$3
   }
   else if ($0 ~ /Total deletes/) {
      deletes=$3
   }
   else if ($0 ~ /Total discards/) {
      discards=$3
   }
   else if ($0 ~ /Total statistics since/) {
      reset_ts=$5" "$6
   }
}
END {
      if ( operations != 0 ) {
         printf("insert into apex_gg_operations(CREATE_TIME,HOST_NAME,GG_HOME,PROGRAM, GROUP_NAME,INSERTS,UPDATES,DELETES,DISCARDS,OPERATIONS,RESET_TS,STATS_TIME) values(to_date(\x27%s\x27,\x27YYYY-MM-DD HH24:MI:SS\x27), \x27%s\x27,\x27%s\x27, \x27Replicat\x27,\x27%s\x27,%s,%s,%s,%s,%s,to_date(\x27%s\x27,\x27YYYY-MM-DD HH24:MI:SS\x27), to_date(\x27%s\x27,\x27YYYY-MM-DD-HH24:MI:SS\x27)); \n",ctime, hostname,  gghome, group_name,inserts,updates,deletes,discards, operations, reset_ts, stats_time)
      }
} ' > $SCRIPTDIR/insert_gg_operations.${host_name}.sql


mypass=`cat $SCRIPTDIR/.dbpass`

sqlplus /nolog <<EOF
conn $DBUSER/${mypass}@$EZCONN
spool $SCRIPTDIR/insert_gg_operations.${host_name}.spool
WHENEVER SQLERROR EXIT SQL.SQLCODE
select host_name, instance_name from v\$instance;
@$SCRIPTDIR/insert_gg_operations.${host_name}.sql
commit;
spool off
exit;
EOF

echo "$0 end `date`"

exit 0
