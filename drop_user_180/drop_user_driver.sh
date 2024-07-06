#!/bin/bash
# Script: drop_user_driver.sh
# Puprose: driver script to loop through all  on-prem servers and run drop_user_180day_inactive.sh for each Oracle db instance

# Usage:  drop_user_driver.sh <host_data_file>
# Author: Yu (Denis) Sun
#
# Modifications:
#
#  DD-Mon-YY   who    what 
#  08-May-24    Denis  Created

. ~/.bash_profile

CURRDIR=`dirname $0`
TS=`date +%Y%m%d%H%M`
LOGFILE=drop_user_${TS}.log

cd $CURRDIR

cat /dev/null > $LOGFILE

{

cat $1 | grep -v "^#" | grep -v "^$" | while read CURRENTHOST  junk
do

echo "~~~~~~~#### `date`   Run playbook against  a single host: $CURRENTHOST ~~~~~~~~~~~~~~"

/u01/app/venv_python36/bin/ansible-playbook -i inventory -e "HOSTS=${CURRENTHOST}"  --become-method=pbrun --become-user=oracle -b  drop_user_180day_inactive.yml

done

echo "ansible playbook done"


} 2>&1 | tee -a $LOGFILE


./prepare_data.sh
./run_sqlldr.sh
