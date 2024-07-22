#!/bin/bash

CURRDIR=`dirname $0`

cd $CURRDIR

OSWTOPFILEDIR="/opt/oracle/product/oracle.ahf/data/repository/suptools/host009/oswbb/oracle/archive/oswtop"

TSSUFFIX=`date +%y.%m.%d.%H00`

DATAFILE=$OSWTOPFILEDIR/host009.example.com_top_${TSSUFFIX}.dat


ls -lh $DATAFILE

cp dat.cur dat.prv
tail -240 $DATAFILE  > dat.cur
diff dat.cur dat.prv  > dat.dif

cat dat.dif | grep "^<" | sed 's/< //g' > dat.dat

cat dat.dat | grep zzz  >> history.dat

/opt/oracle/product/19.3.0/db_1/jdk/bin/java -jar File2Influx-0.1.4.jar influx.properties dat.dat oswtop2 host009
