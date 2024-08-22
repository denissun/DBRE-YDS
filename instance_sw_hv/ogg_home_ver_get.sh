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


CURRDIR=`dirname $0`
cd $CURRDIR


OUTFILE=/tmp/dbinv_gg/ogg_swhv_data.csv

cat /dev/null > $OUTFILE

{

# using temp.txt to avoid extra line from the sed output for unknown reason
#
ps -ef | grep mgr.prm | grep -v grep |  awk '{for(i=1; i<=NF; i++) {if ($i ~ /dirprm/) print $i}}' | grep -v "^$"  > /tmp/dbinv_gg/temp.txt

cat /tmp/dbinv_gg/temp.txt | sed s%/dirprm/mgr.prm%% | while read SW_HOME
do
  echo "processing  $SW_HOME "
  env
  echo " -----------------------------------"
  # ggsci -v not working through pbrun oracle
  #
  SW_VERSION=`cat ${SW_HOME}/dirrpt/MGR.rpt | grep "OGGCORE" | awk '{print $2}'`
  if [ -z $SW_VERSION ];
  then
    # for  12.1 version
    SW_VERSION=`head -10 ${SW_HOME}/dirrpt/MGR.rpt | grep "Version" | awk '{print $2}'`
  fi

  PORT=`cat ${SW_HOME}/dirprm/mgr.prm  |  grep -i "^PORT" | awk '{print $2}'`
  echo "`hostname`,$SW_HOME,$SW_HOME,$SW_VERSION,$PORT" | tee -a $OUTFILE
done
}  > /tmp/dbinv_gg/run.log

