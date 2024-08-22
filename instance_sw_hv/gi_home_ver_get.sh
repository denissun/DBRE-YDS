#!/bin/bash


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


OUTFILE=/tmp/dbinv_gi/gi_swhv_data.csv
cat /dev/null > $OUTFILE


# extract "ocssd" field, which is not always the last field
GI_HOME_STR=`ps -ef | grep "ocssd.bin" | grep -v grep | awk '{for(i=1; i<=NF; i++) {if($i ~ /ocssd/) print $i}}'`
#
# sed gives extra line if used with grep
#
SW_HOME=`echo $GI_HOME_STR | sed 's%/bin/ocssd.bin%%g'`


echo "processing  $SW_HOME "
export ORACLE_HOME=$SW_HOME
$ORACLE_HOME/OPatch/opatch lspatches > /tmp/dbinv_gi/__lspatches.log
SW_VERSION=`grep -i "Database" /tmp/dbinv_gi/__lspatches.log | awk '{print $(NF-1)}'`

if [ -z "$SW_VERSION" ];
then
    SW_VERSION=`$ORACLE_HOME/OPatch/opatch lsinventory  | grep "Oracle Grid"  | awk '{print $NF" No PSU"}'`
fi

PORT=`$ORACLE_HOME/bin/srvctl config scan_listener  | grep "TCP:"  | head -1 | awk -F/ '{print $1}' | awk -F: '{print $NF }'`

if [ -z "$PORT" ];
then
PORT=`$ORACLE_HOME/bin/lsnrctl status | grep "PORT=" | grep "(PROTOCOL=tcp)" | awk -F'=' '{print $NF}' |sed s/\)//g | head -1 | sed s/\)//g`
fi


echo "`hostname`,$SW_HOME,$SW_HOME,$SW_VERSION,$PORT" | tee -a $OUTFILE
