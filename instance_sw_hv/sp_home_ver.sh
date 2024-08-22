#!/bin/bash
# update SRE CDM inventory Splex instance sw home and version

. ~/.bash_profile

CURRDIR=`dirname $0`

cd $CURRDIR

cat /dev/null > sp_home_ver.log

{

cat $1 | grep -v "^#" | grep -v "^$" | while read CURRENTHOST
do
echo "~~~~~~~#### `date` Run Splex playbook against a single host: $CURRENTHOST ~~~~~~~~~~~~~~"
/u01/app/venv_python36/bin/ansible-playbook -i inventory -e "HOSTS=${CURRENTHOST}"  --become-method=pbrun --become-user=oracle -b  sp_home_ver.yml

find ./ -name "sp_swhv_data.csv" | while read datafile
do
    echo "~~~~ processing  $datafile "
    cat $datafile
    # update instances table in srecdm repository oracle database
    #./srecdmmgr instance update --sw_attr_by_file  -f $datafile
    ./pgcdmmgr instance update --sw_attr_by_file  -f $datafile
    rm -f $datafile
done
done

} 2>&1 | tee -a sp_home_ver.log
