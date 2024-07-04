#!/usr/bin/ksh


. /opt/oracle/.bash_profile

export ORACLE_HOME=/opt/oracle/OMS/Middleware/em13
export PATH=$PATH:$ORACLE_HOME/bin:~/bin
NOTIFY=emailid@example.com

SCRIPTDIR=` dirname $0`

cd $SCRIPTDIR

cat /dev/null > /tmp/verify_alertlog_existence.out

cat $SCRIPTDIR/db_alertlog.cfg | grep -v "^#" |  while read INSTANCE  DBALERTLOG  TSFORMAT HOSTNAME
do 

echo "~~~~~ Now process $INSTANCE $DBALERTLOG $HOSTNAME" 

# only check last up to 1000 lines 
# -n stdin ssh break out of while oop 
LINE=` ssh -n  $HOSTNAME stat -c %y ${DBALERTLOG} ` 

if [[ $? -gt 0 ]]; then
   echo "$INSTANCE $DBALERTLOG $HOSTNAME Error existence"  >> /tmp/verify_alertlog_existence.out
   continue
else
   echo "$INSTANCE $DBALERTLOG $HOSTNAME  Existence verified ok" 
fi

# check timestamp

echo $LINE
DATESTR=` echo $LINE | awk '{print $1}' `
TWODAYSAGO=` date  --date="14 days ago" +%Y-%m-%d `

echo "compare *${DATESTR}* with *${TWODAYSAGO}*"

if [[ $DATESTR > $TWODAYSAGO ]];
then
   echo "More recent than 2 days ago, alert log file is live" 
else
   echo "$INSTANCE $DBALERTLOG $HOSTNAME - Too old, alert log file may be not live"  >> /tmp/verify_alertlog_existence.out
fi

done 

echo " ~~~~ check verify_alertlog_existence.out ~~~ "
cat /tmp/verify_alertlog_existence.out

COUNTREC=`wc -l /tmp/verify_alertlog_existence.out | awk '{print $1}'`

if [[ $COUNTREC -gt 0 ]]; then
 echo "sedning email ..."
 cat /tmp/verify_alertlog_existence.out  | mailx  -s "ILOGMON issue - `hostname` some alert log files have problem" -r $NOTIFY $NOTIFY 
fi

exit 0
