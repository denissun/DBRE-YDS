#!/bin/bash

CURRDIR=`dirname $0`

cd $CURRDIR

OSWTOPFILEDIR="/opt/oracle/DBSupportBundle/TFA/tfa/repository/suptools/vvoscpd1/oswbb/oracle/archive/oswiostat"

TSSUFFIX=`date +%y.%m.%d.%H00`

DATAFILE=$OSWTOPFILEDIR/vvoscpd1_iostat_${TSSUFFIX}.dat


ls -lh $DATAFILE

cp dat.cur dat.prv
tail -3000 $DATAFILE  > dat.cur
diff dat.cur dat.prv  > dat.dif

cat dat.dif | grep "^<" | sed 's/< //g' > dat.dat

cat dat.dat | grep zzz  >> history.dat

/dbmisc/app/jdk-15.0.1/bin/java -jar InfluxMgr-1.1.0.jar influx.properties dat.dat oswiostat2 vvoscpd1
