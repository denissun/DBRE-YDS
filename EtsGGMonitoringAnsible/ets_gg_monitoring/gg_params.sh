#/bin/bash
# gg_params.sh 
#   - load gg params as lines into the respository.${host_name}.database
#
# Author: Yu (Denis) Sun
#
# Notes:
#     It requires run ggconf.sh first to set up.${host_name}.sqlplus env and db user account
#
# Modifications:
#    Denis  4-12-2020  created
#


host_name=`hostname`

SCRIPTDIR=`dirname $0`

source $SCRIPTDIR/ggconf.sh 

echo "$0 start `date`"


if [[ -z `ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }'` ]]
then
  echo "no mgr prcocess exiting "
  exit 0
fi


# we should use ET consistently

create_time=`date '+%Y-%m-%d %H:%M:%S' `

{
ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }' |sed 's/dirprm\/mgr.prm/ggsci/' | awk NF | while read command
do

echo  "GGHOME  $command  "
echo "info all " | $command
echo " "
done
}  > $SCRIPTDIR/infoall_params.${host_name}.dat


{
cat $SCRIPTDIR/infoall_params.${host_name}.dat | awk NF | while read program  status  group  lag   chkpt
do

if [ "$program" = "GGHOME" ]
then
   GGHOME=` echo $status | sed 's/ggsci//' `
   GGHOME_GGSCI=` echo $status `
   continue
fi

if [  "$program" = "REPLICAT" ] ||  [  "$program" = "EXTRACT" ]
then
  echo "PARAMS STARTS $GGHOME $program $group"
  echo " view params $group " | $GGHOME_GGSCI  | grep -v GGSCI | awk NF | awk  '{ if (NR>5) { print $0} } END { print "-- END OF PARAMS" } ' | cat -n  
  continue
fi

if [  "$program" = "MANAGER" ] 
then
  echo "PARAMS STARTS $GGHOME $program mgr"
  echo " view params mgr " | $GGHOME_GGSCI  | grep -v GGSCI | awk NF | awk  '{ if (NR>5) { print $0} } END { print "-- END OF PARAMS" } ' | cat -n  
fi

done
}  > $SCRIPTDIR/gg_params.${host_name}.dat


cat $SCRIPTDIR/gg_params.${host_name}.dat | awk -v hostname=$host_name -v ctime="$create_time" ' 
{
   if ( $0 ~ /^PARAMS STARTS / ) {
      gghome=$3;
      program=$4;
      group_name=$5;
   }
   else {
     line_no=substr($0,0,6);
     line=substr($0,7);
     printf("insert into gg_params_lines( CREATE_TIME,HOST_NAME,GG_HOME,PROGRAM, GROUP_NAME,LINE_NO,LINE) values(to_date(\x27%s\x27,\x27YYYY-MM-DD HH24:MI:SS\x27), \x27%s\x27,\x27%s\x27, \x27%s\x27,\x27%s\x27,%s, q\x27[%s]\x27); \n",ctime, hostname,  gghome, program, group_name,line_no, line)
   }
}  ' > $SCRIPTDIR/insert_gg_params.${host_name}.sql

mypass=`cat $SCRIPTDIR/.dbpass`

sqlplus /nolog <<EOF
conn $DBUSER/${mypass}@$EZCONN
spool $SCRIPTDIR/insert_gg_params.${host_name}.spool
WHENEVER SQLERROR EXIT SQL.SQLCODE
select host_name, instance_name from v\$instance;
@$SCRIPTDIR/insert_gg_params.${host_name}.sql
commit;
spool off
exit;
EOF

echo "$0 end `date`"

exit 0
