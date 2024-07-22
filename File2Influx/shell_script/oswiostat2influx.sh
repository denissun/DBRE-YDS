#!/bin/bash

CURRDIR=`dirname $0`

cd $CURRDIR

OSWTOPFILEDIR="/opt/oracle/product/oracle.ahf/data/repository/suptools/host009/oswbb/oracle/archive/oswiostat"

TSSUFFIX=`date +%y.%m.%d.%H00`

DATAFILE=$OSWTOPFILEDIR/host009.exmaple.com_iostat_${TSSUFFIX}.dat


ls -lh $DATAFILE

cp dat.cur dat.prv
tail -3000 $DATAFILE  > dat.cur
diff dat.cur dat.prv  > dat.dif

cat dat.dif | grep "^<" | sed 's/< //g' > dat.dat

cat dat.dat | grep zzz  >> history.dat

/opt/oracle/product/19.3.0/db_1/jdk/bin/java -jar File2Influx-0.1.3.jar  influx.properties dat.dat oswiostat3 host009
