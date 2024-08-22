#!/bin/bash
# script: ora_home_ver_first_sat.sh 
# update SRE CDM inventory instance sw home and version

. ~/.bash_profile

DAY=`date +%d`

if [[ $DAY -gt 7 ]];
then
  echo "It's not the first Saturday of this month, exiting  - DAY=$DAY"
  exit 0
fi


CURRDIR=`dirname $0`
TS=`date +%Y%m%d%H%M`
LOGFILE=ora_sw_hv_sat_${TS}.log

cd $CURRDIR

cat /dev/null > $LOGFILE 

{

cat $1 | grep -v "^#" | grep -v "^$" | while read CURRENTHOST
do

echo "~~~~~~~#### `date`   Run playbook against  a single host: $CURRENTHOST ~~~~~~~~~~~~~~"
/u01/app/venv_python36/bin/ansible-playbook -i inventory -e "HOSTS=${CURRENTHOST}"  --become-method=pbrun --become-user=oracle -b  ora_home_ver.yml

find ./ -name "ora_swhv_data.csv" | while read datafile
do
    echo "~~~~ processing  $datafile "
    # update swinstances table in the PostgreSql 
    ./pgcdmmgr instance update --sw_attr_by_file  -f $datafile
    rm -f $datafile
done

done

} 2>&1 | tee -a $LOGFILE 
