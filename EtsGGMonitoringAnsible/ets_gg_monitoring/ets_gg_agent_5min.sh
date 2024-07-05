#/bin/bash
# ets_gg_agent_5min.sh
#   - Driver script to run jobs to collect gg metrics
#
# Author: Yu (Denis) Sun
#
# Notes:
#     It requires ggconf.sh     
#
# Modifications:
#    Denis  4-12-2020  created
#

SCRIPTDIR=`dirname $0`

if [[ -z `ps -ef | grep mgr.prm | grep -v grep | grep -v gguser2 | awk '{print $10 }'` ]]
then
  echo "no mgr prcocess exiting "
  exit 0
fi

source $SCRIPTDIR/ggconf.sh

cd $SCRIPTDIR

nohup $SCRIPTDIR/gg_error.sh      &
nohup $SCRIPTDIR/gg_info_all.sh   &
nohup $SCRIPTDIR/gg_mgr_alive.sh  &
nohup $SCRIPTDIR/gg_operations.sh  &

exit 0
