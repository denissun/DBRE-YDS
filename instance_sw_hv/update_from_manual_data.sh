#!/bin/bash
# script: update_from_manual_data.sh 
# update SRE CDM inventory instance sw home and version

. ~/.bash_profile


CURRDIR=`dirname $0`
TS=`date +%Y%m%d%H%M`
LOGFILE=update_from_manual_data_${TS}.log

cd $CURRDIR


./pgcdmmgr instance update --sw_attr_by_file  -f manual/manual_all.csv   > $LOGFILE


