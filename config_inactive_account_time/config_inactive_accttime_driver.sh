#!/bin/bash
# Script: config_inactive_accttime_driver.sh 
# Puprose: driver script to loop through all  on-prem servers host  database 
# and run config_inactive_accttimee.sh for each Oracle db instance

# Usage:  config_inactive_accttime_driver.sh <host_data_file>
# Author: Yu (Denis) Sun
#
# Modifications:
#
#  DD-Mon-YY   who    what 
#  05-Jun-24   Denis  Created

. ~/.bash_profile

if [ $# -lt 1 ]; then
  echo "Wrong number of arguments"
  echo "Usage: $0 <host_data_file>"
  exit 1
fi


CURRDIR=`dirname $0`
TS=`date +%Y%m%d%H%M`
LOGFILE=config_inactive_accttime_${TS}.log

cd $CURRDIR

cat /dev/null > $LOGFILE

{

cat $1 | grep -v "^#" | grep -v "^$" | while read CURRENTHOST junk
do

echo "~~~~~~~#### `date`   Run playbook against  a single host: $CURRENTHOST ~~~~~~~~~~~~~~"

/u01/app/venv_python36/bin/ansible-playbook -i inventory -e "HOSTS=${CURRENTHOST}"  --become-method=pbrun --become-user=oracle -b  config_inactive_accttime.yml

done

echo "ansible playbook done"


} 2>&1 | tee -a $LOGFILE



