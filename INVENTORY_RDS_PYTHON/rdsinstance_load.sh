#!/bin/bash
. ~/.bash_profile

CURRDIR=`dirname $0`
TS=`date +%y%m%d`

cd $CURRDIR

JSONFILE="/u01/app/ets/autoinv_sshpass_pbrun/rdsinstance/rds_instance_ec2host.vpc.example.com_$TS.json"

if [ -f $JSONFILE ]; 
then
   python rdsins.py  $JSONFILE 
fi

