#!/bin/bash

# This script runs at an EC2 instance and generates AWS RDS info in JSON format.
# The output files are pushed to the on-prem server staging directory


. ~/.bash_profile

TARGETHOST=targethost.example.com
TS=`date +%y%m%d`
HOSTNAME="ec2host.vpc.example.com"
OUTPUTFILE="rds_instance_${HOSTNAME}_$TS.json"
OUTPUTFILE2="rds_instance_${HOSTNAME}_$TS.json_west"


CURRDIR=`dirname $0`
cd $CURRDIR


/usr/local/bin/aws rds describe-db-instances | jq -r tostring  > $OUTPUTFILE

sshpass -f .mypass  scp  -o StrictHostKeychecking=no  $OUTPUTFILE  username1@$TARGETHOST:/u01/app/ets/autoinv_sshpass_pbrun/rdsinstance



export http_proxy=http://proxy.example.com:80
export https_proxy=http://proxy.example.com:80
export NO_PROXY="xxx.xxx.xxx.xxx"
export PERL_LWP_ENV_PROXY=1

/usr/local/bin/aws rds describe-db-instances --region us-west-2 | jq -r tostring  > $OUTPUTFILE2

sshpass -f .mypass  scp  -o StrictHostKeychecking=no  $OUTPUTFILE2  username1@$TARGETHOST:/u01/app/ets/autoinv_sshpass_pbrun/rdsinstance



find ./ -name "*.json*" -mtime +14 -exec rm -rf {} \;


