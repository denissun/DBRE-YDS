#!/bin/bash

CURRDIR=`dirname $0`

MAILTO="username1@example.com,$1"

cd $CURRDIR

cat  mail.txt | mailx -s "Your account in db will be dropped due to inactive for more than 180 days" -r username1@example.com $MAILTO 
