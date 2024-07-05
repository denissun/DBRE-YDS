#/bin/bash
# gg_operations_sol.sh
#   - load REPLICAT group operations statistics into the repository database. 
#
# Author: Yu (Denis) Sun
#
# Notes:
#    - It requires run ggconf.sh first to set up sqlplus env and db user account
#    - EXTRACT group operations statistics are not collected
#
# Modifications:
#    Denis  4-16-2020  solaris version 
#    Denis  4-12-2020  created
#



host_name=`hostname`

SCRIPTDIR=`dirname $0`


echo "$0 start `date`"


# memo: we should use ET consistently

create_time=` date '+%Y-%m-%d %H:%M:%S' `


cat $SCRIPTDIR/stats_operations.dat | nawk -v hostname=$host_name -v ctime="$create_time" ' 
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
} ' > $SCRIPTDIR/insert_gg_operations.sql


exit 0
