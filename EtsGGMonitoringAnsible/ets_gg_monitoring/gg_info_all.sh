#/bin/bash
# gg_info_all.sh
#   - insert "GGSIC> info all" .${host_name}.data into the a repository db, 
#     if a process abended or stopped, try to get error messages for the reason.
#
# Author: Yu (Denis) Sun
#
# Notes:
#     It requires run ggconf.sh first to set up sqlplus env and db user account 
#
# Modifications:
#    Denis  4-12-2020  created
#


host_name=`hostname`
SCRIPTDIR=`dirname $0`

create_time=`date '+%Y-%m-%d %H:%M:%S' `

if [[ -z `ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }'` ]]
then
  echo "no mgr prcocess exiting "
  exit 0
fi


{
ps -ef | grep mgr.prm | grep -v grep | awk '{print $10 }' |sed 's/dirprm\/mgr.prm/ggsci/' | awk NF | while read command
do

echo "GGHOME  $command  "
echo "info all " | $command
echo " "
done
}  > $SCRIPTDIR/infoall.${host_name}.dat

# check for abend if abend generate abend reprot

{
cat $SCRIPTDIR/infoall.${host_name}.dat | awk NF | while read program  status  group  lag   chkpt
do

if [ "$program" = "GGHOME" ]
then
   GGHOME=` echo $status | sed 's/ggsci//' `
   GGHOME_GGSCI=` echo $status `
   continue
fi

if [ "$status" = "STOPPED" ] || [ "$status" = "ABENDED" ] ; then

STOPREASON=` echo  "view report $group " |  ${GGHOME_GGSCI} | grep " ERROR " `

echo "insert into apex_gg_abend(create_time, host_name,gg_home, program, group_name, status, reason) values(to_date('$create_time', 'YYYY-MM-DD HH24:MI:SS'), '$host_name', '$GGHOME','$program', '$group',  '$status', q'["
echo  $STOPREASON
echo "]');"

fi
done
}  > $SCRIPTDIR/insert_abend.${host_name}.sql


###############################################################


{
cat $SCRIPTDIR/infoall.${host_name}.dat | awk NF | while read program  status  group  lag   chkpt
do

if [ "$program" = "REPLICAT" ] || [ "$program" = "EXTRACT" ]
then
  if [ "$lag" = "unknown" ]
  then
     lag="00:00:00"
     echo "pro  ORA-00000 lag unknown set to 00:00:00"
  fi 
  echo "insert into apex_gg_info_all values( to_date('$create_time', 'YYYY-MM-DD HH24:MI:SS'), '$host_name', '$GGHOME','$program', '$status', '$group',  INTERVAL '$lag' HOUR TO SECOND, INTERVAL '$chkpt' HOUR TO SECOND);"
  continue
fi

if [ "$program" = "MANAGER" ]
then
  echo "insert into apex_gg_info_all(create_time, host_name,gg_home, program, status) values(to_date('$create_time', 'YYYY-MM-DD HH24:MI:SS'), '$host_name', '$GGHOME','$program', '$status');"
   continue
fi

if [ "$program" = "GGHOME" ]
then
   GGHOME=` echo $status | sed 's/ggsci//' `
   continue
fi

done
} >  $SCRIPTDIR/insert_gginfo.${host_name}.sql



mypass=`cat $SCRIPTDIR/.dbpass`

sqlplus /nolog <<EOF
conn ${DBUSER}/${mypass}@${EZCONN}
set sqlblanklines on
spool $SCRIPTDIR/insert_gginfo.${host_name}.spool
WHENEVER SQLERROR EXIT SQL.SQLCODE
select host_name, instance_name from v\$instance;
@$SCRIPTDIR/insert_gginfo.${host_name}.sql
commit;
spool off
spool $SCRIPTDIR/insert_abend.${host_name}.spool
@$SCRIPTDIR/insert_abend.${host_name}.sql
commit;
spool off
exit;
EOF

exit 0
