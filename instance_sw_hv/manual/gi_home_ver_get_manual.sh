#!/bin/bash


CURRDIR=`dirname $0`

cd $CURRDIR

if [ -n `echo $SHELL | grep bash` ];
then
 . ~/.bash_profile
fi

if [ -n `echo $SHELL | grep ksh` ];
then
 . ~/.profile
fi

OUTFILE=gi_swhv_data.csv
cat /dev/null > $OUTFILE

ps -ef | grep ocssd.bin | grep -v grep  | awk '{print $(NF)}' | sed s%/bin/ocssd.bin%%g | grep -v "%" | while read SW_HOME
do
  echo "processing  $SW_HOME "
  export ORACLE_HOME=$SW_HOME
  $ORACLE_HOME/OPatch/opatch lspatches > __lspatches.log
  SW_VERSION=`grep -i "Database" __lspatches.log | awk '{print $(NF-1)}'`
  PORT=`$ORACLE_HOME/bin/lsnrctl status | grep "PORT=" | grep "(PROTOCOL=tcp)" | awk -F'=' '{print $NF}' |sed s/\)//g | head -1 | sed s/\)//g`
  
  echo "`hostname`,$SW_HOME,$SW_HOME,$SW_VERSION,$PORT" | tee -a $OUTFILE
done
