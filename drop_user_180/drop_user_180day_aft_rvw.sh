#!/bin/bash
#
# Script: drop_user_180day_aft_rvw.sh
# Usage:  drop_user_180day_aft_rvw.sh <hosts_aft_rvw.cfg> 
#


CURRDIR=`dirname $0`
cd $CURRDIR

HOSTNAME=`hostname`

OSTYPE=`uname -s`

if [ "$OSTYPE" == "SunOS" ];
then
ORATAB=/var/opt/oracle/oratab
GREP=/usr/xpg4/bin/grep
else
ORATAB=/etc/oratab
GREP=grep
fi

COUNT=`echo $SHELL | grep bash | wc -l`

if [ $COUNT -eq 1 ];
then
 echo "bash"
 . ~/.bash_profile
fi

COUNT=`echo $SHELL | grep ksh | wc -l`

if [ $COUNT -eq 1 ];
then
 echo "ksh"
 . ~/.profile
fi


TS=`date +%Y%m%d%H%M`
OUTFILE=drop_user_180day_aft_rvw_${TS}.log

SQLPLUSCOMMAND="sqlplus -s / as sysdba"

{
ps -ef | grep ora_pmon | grep -v grep | awk -F'_' '{print $NF}' | while read INSTANCE_NAME
do
  # 1/17/23 added head -1, oratab may have duplicated entries incorrectly
  SW_HOME=`grep $INSTANCE_NAME $ORATAB | grep -v "^#" |head -1 | awk -F':'  '{print $2}'`

  if [ -z $SW_HOME ];
  then
     # INSTANCE_NAME1=${INSTANCE_NAME::-1}
     # for linux 6
     INSTANCE_NAME1=${INSTANCE_NAME::${#INSTANCE_NAME}-1}
     echo "INSTANCE_NAME1=$INSTANCE_NAME1"
     SW_HOME=`grep $INSTANCE_NAME1 $ORATAB | grep -v "^#" | head -1 | awk -F':' '{print $2}'`
  fi
  if [ -z $SW_HOME ];
  then
     echo "get oracle_home from oratab failed, try env variable .."
     env
     SW_HOME=`env | grep ORACLE_HOME | awk -F'=' '{print $2}'`
  fi

  if [ -z $SW_HOME ];
  then
     echo " Cannot find ORACLE_HOME for instance: $INSTANCE_NAME  skip "
     continue
  fi

  echo "SW_HOME=$SW_HOME"

export ORACLE_HOME=$SW_HOME
export ORACLE_SID=${INSTANCE_NAME}
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH


echo "SQLPLUST COMMAND: $SQLPLUSCOMMAND "

TMPOUTFILE=drop_user_180day_aft_rvw_tmp.out


#
# check if CDB
#

$SQLPLUSCOMMAND <<EOF   > $TMPOUTFILE
set echo off head off trimspool on
set pages
select cdb from v\$database;
EOF

ISCDB=`cat $TMPOUTFILE`
echo "ISCDB=$ISCDB"

if [ "$ISCDB" == "YES" ];  ## begin *1* if ISCDB
then
    echo "is CDB"
    # get pdb names
$SQLPLUSCOMMAND <<EOF  | grep -v "^$" > $TMPOUTFILE
    set echo off head off trimspool on
    set pages
    select name from v\$containers where name not in ('CDB\$ROOT', 'PDB\$SEED');
    exit;
EOF

# loop over pdbs
cat $TMPOUTFILE | while read pdbname  
do

echo "process pdb $pdbname"
$SQLPLUSCOMMAND <<EOF
spool drop_user_180day_aft_rvw_${INSTANCE_NAME}_$pdbname_${HOSTNAME}_$TS.spool
alter session set container=$pdbname;
show con_name;
@drop_user_180day_aft_rvw.sql
spool off
exit;
EOF
done # end of loop pdbs
echo "## end of loop pdbs `date`"

# non-CDB 
else
    echo "not CDB"

$SQLPLUSCOMMAND <<EOS
spool drop_user_180day_aft_rvw_${INSTANCE_NAME}_${HOSTNAME}_$TS.spool

@drop_user_180day_aft_rvw.sql

spool off
exit;
EOS

fi  ## end *1* if ISCDB
done  # end of loop instances

}  > $OUTFILE
