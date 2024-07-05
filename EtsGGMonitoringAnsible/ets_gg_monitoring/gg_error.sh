#/bin/bash
# gg_error.sh
#   - Load error messages from ggserr.log into the repository database
#
# Author: Yu (Denis) Sun
#
# Notes:
#     It requires the directory: SCRIPTDIR/errlog
#
# Modifications:
#    Denis  4-12-2020  created
#


export PATH=~/bin:$PATH
host_name=`hostname`
SCRIPTDIR=`dirname $0`


if [[ -z `ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }'` ]]
then
  echo "no mgr prcocess exiting "
  exit 0
fi

# create_time=` date '+%Y-%m-%d %H:%M:%S' `


counter=0


ps -ef | grep mgr.prm | grep -v grep | awk '{print $10 }' |sed 's/dirprm\/mgr.prm//' | awk NF | while read gghome
do
ggerrlog="${gghome}ggserr.log"

if [ -f $SCRIPTDIR/errlog/log.$counter.500.${host_name}.new ]; then

cp $SCRIPTDIR/errlog/log.$counter.500.${host_name}.new  $SCRIPTDIR/errlog/log.$counter.500.${host_name}.old
tail -500 $ggerrlog > $SCRIPTDIR/errlog/log.$counter.500.${host_name}.new
diff $SCRIPTDIR/errlog/log.$counter.500.${host_name}.new  $SCRIPTDIR/errlog/log.$counter.500.${host_name}.old  > $SCRIPTDIR/errlog/log.$counter.500.${host_name}.diff


grep "^<" $SCRIPTDIR/errlog/log.$counter.500.${host_name}.diff | awk -v hostname=$host_name -v gghome=$gghome '{ if ( $4 ~/WARNING|ERROR/ ) { printf "insert into apex_gg_error values(\x27%s\x27, \x27%s\x27,to_date(\x27%s %s\x27, \x27YYYY-MM-DD HH24:MI:SS\x27), \x27%s\x27, \x27%s\x27,q\x27[%s]\x27); \n", hostname, gghome,  $2, $3, $4,$5, substr($0,42) }}'

else
tail -500 $ggerrlog > $SCRIPTDIR/errlog/log.$counter.500.${host_name}.new
fi

((counter=counter+1))
done  > $SCRIPTDIR/insert_error_log.${host_name}.sql


mypass=`cat $SCRIPTDIR/.dbpass`

sqlplus /nolog <<EOF
conn ${DBUSER}/${mypass}@${EZCONN}
spool $SCRIPTDIR/insert_error_log.${host_name}.spool
WHENEVER SQLERROR EXIT SQL.SQLCODE
set echo on
select host_name, instance_name from v\$instance;
@$SCRIPTDIR/insert_error_log.${host_name}.sql
commit;
spool off
exit;
EOF

exit 0

