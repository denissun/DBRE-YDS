#!/bin/bash

echo "Usage: $0  or  "
echo "       $0 <mins>"


CURRDIR=`dirname $0`

cd $CURRDIR


if [ -z "$1" ]
then
MMIN=60
else
MMIN=$1 
fi

echo "~~~~~  list files modified in last $MMIN mins ~~~~~"

cat /dev/null > data.csv

find  logs/ -name "*.spool"   | while read FN
do
  echo $FN
  egrep "DROP_ACCT|REVIEW_ACCT"  $FN >> data.csv
  mv $FN archive
done
   
