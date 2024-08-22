#!/bin/bash

OSTYPE=`uname -s`

if [ "$OSTYPE" == "SunOS" ];
then
ORATAB=/var/opt/oracle/oratab
else
ORATAB=/etc/oratab
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



OUTFILE=ora_swhv_data.csv
LSPATCHTMP=__lspatches.log

cat /dev/null > $OUTFILE

ps -ef | grep ora_pmon | grep -v grep | awk -F'_' '{print $NF}' | while read INSTANCE_NAME
do
  SW_HOME=`grep $INSTANCE_NAME $ORATAB | grep -v "^#" | awk -F':' '{print $2}'`

  if [ -z $SW_HOME ];
  then
     # INSTANCE_NAME1=${INSTANCE_NAME::-1}
     # for linux 6
     INSTANCE_NAME1=${INSTANCE_NAME::${#INSTANCE_NAME}-1}
     echo "INSTANCE_NAME1=$INSTANCE_NAME1"
     SW_HOME=`grep $INSTANCE_NAME1 $ORATAB | grep -v "^#" | awk -F':' '{print $2}'`
  fi
  if [ -z $SW_HOME ];
  then
     continue
  fi
  echo $SW_HOME
  export ORACLE_HOME=$SW_HOME
  $ORACLE_HOME/OPatch/opatch lspatches > $LSPATCHTMP
  #
  # 23054246;Database Patch Set Update : 12.1.0.2.160719 (23054246)  ---> this is where version is obtained
  # 23177536;Database PSU 12.1.0.2.160719, Oracle JavaVM Component (JUL2016)
  #

  SW_VERSION=`grep -i "Database" $LSPATCHTMP | sort |  head -1 | awk '{print $(NF-1)}'`
  PORT=`lsnrctl status | grep "PORT=" | grep "(PROTOCOL=tcp)" | awk -F'=' '{print $NF}' |sed s/\)//g | head -1 | sed s/\)//g`
  echo "`hostname`,$INSTANCE_NAME,$SW_HOME,$SW_VERSION,$PORT" | tee -a $OUTFILE
done


