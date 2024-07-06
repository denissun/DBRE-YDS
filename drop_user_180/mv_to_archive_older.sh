#!/bin/bash

echo "Usage: $0  or  "
echo "       $0 <mins>"

if [ -z "$1" ]
then
MMIN=60
else
MMIN=$1 
fi

echo "~~~~~  list files modified in last $MMIN mins ~~~~~"

find  logs/ -name "*.spool" -mmin +$MMIN   | xargs mv -t archive
   
