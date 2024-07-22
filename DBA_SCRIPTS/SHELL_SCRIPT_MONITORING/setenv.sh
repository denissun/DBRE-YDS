#!/bin/bash
#
# Name : setenv.sh
# Usage:  . ~/setenv.sh <ORACLE_SID>
#
#        <ORACLE_SID> is optional, if ORACLE_SID provided , set it as the default ORACLE_SID
# Note :  please make sure enteries in ORATABFILE are accurate
# Author:
#     Denis  10/16/17 created
# Modification
#     Denis  11/10/17  take care if $1 is an invalid sid
#     Denis  11/17/17  remove if [-t 0]
#

. ~/.profile

ORATABFILE=/var/opt/oracle/oratab

ANSWER=""

export TERM=vt100

COUNTER=0
ORACLE_SID=""

while [ -z "${ORACLE_SID}" ]
do
        (( COUNTER++ ))
        tput clear; tput  rev
        echo "Valid Oracle SIDs are :"
        tput  rmso
        for SID in `cat $ORATABFILE|grep -v "^#"|cut -f1 -d: -s | sort`
        do
            echo "                  ${SID}"
        done
        # if $1 is provided we set it to DEFAULT directly for only once
        [ $COUNTER -eq 1 ] &&  ORACLE_SID=$1
        if [ "${ORACLE_SID}" = "" ]
        then
                DEFAULT=`cat $ORATABFILE|grep -v "^#"|cut -d: -f1 -s|head -1`
                echo "\nEnter the Oracle SID you require (default: $DEFAULT): \c"
                # -t 30 wait 30 second to proceed with default if not hit enter
                read -t 30  ANSWER
        else
                DEFAULT=$ORACLE_SID
        fi

        [ "${ANSWER}" = "" ] && ANSWER=$DEFAULT


        export ORACLE_SID=`grep "^${ANSWER}:" $ORATABFILE|cut -d: -f1 -s`
        export ORACLE_HOME=`grep "^${ANSWER}:" $ORATABFILE|cut -d: -f2 -s`
        if [ "${ORACLE_SID}" = "" ]
        then
                echo "\n\n              ${ANS}: Invalid Oracle SID  \c"
                ANSWER=""
                #   [ "$1" != "" ] && exit 1
                sleep 2
        fi
done

export ORACLE_SID=$ORACLE_SID
export ORACLE_HOME=$ORACLE_HOME
export PATH=/usr/bin:/usr/sbin
export PATH=$PATH:/usr/sbin:/usr/ccs/bin:/usr/local/bin:/usr/openwin/bin:/bin
export PATH=${PATH}:${ORACLE_HOME}/bin:${CRS_HOME}/bin:/usr/ucb/whoami:~/bin
export LD_LIBRARY_PATH=${ORACLE_HOME}/lib:/usr/lib
export SQLPATH=/dbmisc/common/sql:.
export CLASSPATH=${ORACLE_HOME}/plsql/jlib/plsql.jar
export PS1='${LOGNAME}@`hostname`:$PWD [$ORACLE_SID] $ '


echo
echo Oracle SID is now `tput rev`$ORACLE_SID`tput rmso`, Oracle Home is `tput rev`$ORACLE_HOME`tput rmso`
echo

# instance specific setting

if [ -e /opt/oracle/.${ORACLE_SID} ]
then
. /opt/oracle/.${ORACLE_SID}
fi


