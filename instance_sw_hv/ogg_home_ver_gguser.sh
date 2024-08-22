#!/bin/bash
# update SRE CDM inventory GI instance sw home and version

. ~/.bash_profile

CURRDIR=`dirname $0`
TS=`date +%Y%m%d%H%M`

cd $CURRDIR

cat /dev/null > ogg_home_ver_${TS}.log

{

cat $1 | grep -v "^#" | grep -v "^$" | while read CURRENTHOST
do

echo "~~~~~~~#### `date`   Run  OGG playbook against  a single host: $CURRENTHOST ~~~~~~~~~~~~~~"

/u01/app/venv_python36/bin/ansible-playbook -i inventory -e "HOSTS=${CURRENTHOST}"  --become-method=pbrun --become-user=gguser -b ogg_home_ver.yml

find ./ -name "ogg_swhv_data.csv" | while read datafile
do
    echo "~~~~ processing  $datafile "
    #./srecdmmgr instance update --sw_attr_by_file  -f $datafile
    ./pgcdmmgr instance update --sw_attr_by_file  -f $datafile
    rm -f $datafile
done

done 
} 2>&1 | tee -a ogg_home_ver_${TS}.log
