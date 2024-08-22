#!/bin/bash
# script: instance_sw_hv.sh
# update SRE CDM inventory instance sw home and version

. ~/.bash_profile

CURRDIR=`dirname $0`
TS=`date +%Y%m%d%H%M`
LOGFILE=ora_sw_hv_${TS}.log

cd $CURRDIR

cat /dev/null > $LOGFILE 

{

cat $1 | grep -v "^#" | grep -v "^$" | while read CURRENTHOST
do

echo "~~~~~~~#### `date`   Run playbook against  a single host: $CURRENTHOST ~~~~~~~~~~~~~~"

/u01/app/venv_python36/bin/ansible-playbook -vvv -i inventory -e "HOSTS=${CURRENTHOST}"  --become-method=pbrun --become-user=oracle -b  ora_home_ver.yml

find ./ -name "ora_swhv_data.csv" | while read datafile
do
    echo "~~~~ processing  $datafile "
    # update swinstances table in the PostgreSql 
    ./pgcdmmgr instance update --sw_attr_by_file  -f $datafile
    rm -f $datafile
done

done

} 2>&1 | tee -a $LOGFILE 
