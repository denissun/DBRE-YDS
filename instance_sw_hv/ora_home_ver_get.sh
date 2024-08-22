#!/bin/bash

#
# Notes
#

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


mkdir -p /tmp/dbinv_ora



OUTFILE=/tmp/dbinv_ora/ora_swhv_data.csv

cat /dev/null > $OUTFILE

ps -ef | grep ora_pmon | grep -v grep | awk -F'_' '{print $NF}' | while read INSTANCE_NAME
do
  # 1/17/23 added head -1, oratab may have duplicated entries incorrectly
  SW_HOME=`grep -i  $INSTANCE_NAME $ORATAB | grep -v "^#" |head -1 | awk -F':'  '{print $2}'`

  if [ -z $SW_HOME ];
  then
     # INSTANCE_NAME1=${INSTANCE_NAME::-1}
     # for linux 6
     INSTANCE_NAME1=${INSTANCE_NAME::${#INSTANCE_NAME}-1}
     echo "INSTANCE_NAME1=$INSTANCE_NAME1"
     SW_HOME=`grep -i  $INSTANCE_NAME1 $ORATAB | grep -v "^#" | head -1 | awk -F':' '{print $2}'`
  fi
  if [ -z $SW_HOME ];
  then
     echo "get oracle_home from oratab failed, try env variable .."
     env
     SW_HOME=`env | grep ORACLE_HOME | awk -F'=' '{print $2}'`
  fi

  if [ -z $SW_HOME ];
  then
     continue 
  fi

  echo $SW_HOME  

  export ORACLE_HOME=$SW_HOME
  $ORACLE_HOME/OPatch/opatch lspatches > /tmp/dbinv_ora/__lspatches.log

  # -- example lines to extract version
  # 23054246;Database Patch Set Update : 12.1.0.2.160719 (23054246)  ---> this is where version is obtained
  # 28732021;DATABASE PATCH FOR EXADATA (Jan 2019 - 11.2.0.4.190115) : (28732021)
  # 32545013;Database Release Update : 19.11.0.0.210420 (32545013)
  #
  # -- ignore lines
  #
  # 23177536;Database PSU 12.1.0.2.160719, Oracle JavaVM Component (JUL2016)
  # 32579761;OCW RELEASE UPDATE 19.11.0.0.0 (32579761)
  
  SW_VERSION=`grep -i "Database" /tmp/dbinv_ora/__lspatches.log | $GREP -i -e "release" -e "patch" | grep -v "Java" | awk '{ for (i=1;i<=NF;i++)  if ($i ~ /[0-9]+\.[0-9]+\./) { print $i }}' | sed 's/)//g'`

  PORT=`$ORACLE_HOME/bin/srvctl config scan_listener  | grep "TCP:"  | head -1 | awk -F/ '{print $1}' | awk -F: '{print $NF }'`

  if [ -z "$SW_VERSION" ];
  then
    SW_VERSION=`$ORACLE_HOME/OPatch/opatch lsinventory  | grep "Oracle Database"  | awk '{print $NF" No PSU"}'`
  fi
  if [ -z "$PORT" ];
  then
    PORT=`$ORACLE_HOME/bin/lsnrctl status | grep "PORT=" | grep "(PROTOCOL=tcp)" | awk -F'=' '{print $NF}' |sed s/\)//g | head -1 | sed s/\)//g`
  fi
  echo "`hostname`,$INSTANCE_NAME,$SW_HOME,$SW_VERSION,$PORT" | tee -a $OUTFILE
done

chmod 666 $OUTFILE
