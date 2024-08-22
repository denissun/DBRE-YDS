#!/bin/bash

mkdir -p /tmp/dbinv_sp
OUTPUT=/tmp/dbinv_sp/sp_swhv_data.csv

cat /dev/null > $OUTPUT

ps -ef | grep sp_cop | grep -v grep | awk -F'/.app-mod' '{print $1}' | awk '{print $NF}' |uniq | while read SP_HOME

do

HOSTNAME=`hostname`

VERSION=`$SP_HOME/util/sp-bininfo | head -2 |tail -1`

echo "$HOSTNAME,$SP_HOME,$VERSION" | tee -a $OUTPUT
done

