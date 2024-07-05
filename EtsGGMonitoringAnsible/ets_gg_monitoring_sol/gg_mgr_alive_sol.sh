#/bin/bash
# gg_mgr_alive.sh
#   - check if a mgr process exist in the current server
#
# Author: Yu (Denis) Sun
#
# Notes:
#     It requires run ggconf.sh first to set up.${host_name}.sqlplus env and db user account
#
# Modifications:
#    Denis  4-16-2020  soloaris version: print $11 , awk NF -> sed '/^$/d'
#    Denis  4-12-2020  created
#
#


host_name=`hostname`
SCRIPTDIR=`dirname $0`

# create_time=` date '+%Y-%m-%d %H:%M:%S' `

{
ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{ if ($11 ~ /mgr/ ) {print $11} else if ($10 ~ /mgr/) { print $10} }' |sed 's/dirprm\/mgr.prm/ggsci/' | sed  '/^$/d' | while read command
do

GGHOME=`echo $command | sed 's/ggsci//'`

echo "execute gg_instance_upsert('$host_name','$GGHOME'); "

done
} > $SCRIPTDIR/insert_mgr_alive.${host_name}.sql



mypass=`cat $SCRIPTDIR/.dbpass`

sqlplus /nolog <<EOF
conn ${DBUSER}/${mypass}@${EZCONN}
set echo on
spool $SCRIPTDIR/insert_mgr_alive.${host_name}.spool
WHENEVER SQLERROR EXIT SQL.SQLCODE
select host_name, instance_name from v\$instance;
@$SCRIPTDIR/insert_mgr_alive.${host_name}.sql
commit;
spool off
exit;
EOF

exit 0

