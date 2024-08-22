#!/bin/bash
#
# fetch remote server oracle home version data file
# /tmp/dbinv_ora/ora_swhv_data.csv -- this file generated at remote server every Saturday 

. ~/.bash_profile

CURRDIR=`dirname $0`
TS=`date +%Y%m%d`
LOGFILE=ora_sw_hv_fetch_${TS}.log

cd $CURRDIR

cat /dev/null > $LOGFILE 

{
cat hosts_fetch.cfg | grep -v "^#" | grep -v "^$" | while read CURRENTHOST
do
    echo "#### `date`  proccessing  $CURRENTHOST   ################################ "
    sshpass -f ~/.mypass  scp  -o StrictHostKeychecking=no  user1$CURRENTHOST:/tmp/dbinv_ora/ora_swhv_data.csv  fetched_csv/${CURRENTHOST}_ora_swhv_data.csv 
    if [ -f fetched_csv/${CURRENTHOST}_ora_swhv_data.csv ];
    then
    ./pgcdmmgr instance update --sw_attr_by_file  -f fetched_csv/${CURRENTHOST}_ora_swhv_data.csv 
    fi 
done

} 2>&1 | tee -a $LOGFILE
