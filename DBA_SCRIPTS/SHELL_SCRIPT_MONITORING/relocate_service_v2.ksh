#!/usr/bin/ksh
# Script: relocate_service_v2.ksh
# Purpose: check service preferred and running nodes, if they are not match, gnerate commands for "relocate the service"
#
# 
#
# Modification
#
#   YYYY-MM-DD   who       what
#   2024-09-13   Denis     Created
#

. ~/.profile

-- set correct DATABASE and CRS_HOME
DATABASE=obvtpprd
CRS_HOME=/oragrid/app/19c/grid

TMP_SERVICE_CONFIG=tmp_serviceconfig.log
TMP_SERVICE_STATUS=tmp_servicestatus.log


CURRDIR=`dirname $0`
cd $CURRDIR

echo "database=$DATABASE"
echo "~~~ list the services by crstl status res"

$CRS_HOME/bin/crsctl status res | grep -i "ora.$DATABASE.*\.svc" | cut -d'=' -f2|cut -d'.' -f3 >service.dat

cat service.dat


for service in `cat service.dat`; do
        echo ""
        echo "### Now checking $service  ..."
        echo "database=$DATABASE"
        srvctl config service -d "$DATABASE" -s $service  > ${TMP_SERVICE_CONFIG}
        # cat ${TMP_SERVICE_CONFIG}

        # is the service enabled?

        if [ -n `grep "Service is enabled" ${TMP_SERVICE_CONFIG}` ];
        then
           echo "Service is enabled"

           PREFERRED=`grep -i "Preferred instances:" ${TMP_SERVICE_CONFIG} | awk '{print $3 }'`
           AVAILABLE=`grep -i "Available instances:" ${TMP_SERVICE_CONFIG} | awk '{print $3 }'`

           echo "PREFERRED=^$PREFERRED^"
           echo "AVAILABLE=$AVAILABLE"

           srvctl status service -d $DATABASE -s $service >${TMP_SERVICE_STATUS}

           RUNNING=`cat ${TMP_SERVICE_STATUS} | awk '{print $NF }'`
           echo "RUNNIG=^$RUNNING^"

           if [ "$PREFERRED" == "$RUNNING" ];
           then
              echo "Relocate is NOT needed"
           else
              echo "To relocate ..."
              echo "COMMAND:   srvctl relocate service -d $DATABASE -s $service -oldinst $RUNNING -newinst $PREFERRED "
           fi
      else
        echo "Service is NOT enabled"
      fi
done
exit
