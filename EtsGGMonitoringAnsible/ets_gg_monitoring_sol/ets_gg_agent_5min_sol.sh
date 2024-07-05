#/bin/bash
# ets_gg_agent_5min_sol.sh
#   - Driver script to run jobs to collect gg metrics
#
# Author: Yu (Denis) Sun
#
# Notes:
#     It requires ggconf.sh     
#
# Modifications:
#    Denis  4-16-2020  solaris version: nawk instead of awk 
#    Denis  4-12-2020  created
#

SCRIPTDIR=`dirname $0`

source $SCRIPTDIR/ggconf.sh


cd $SCRIPTDIR

nohup $SCRIPTDIR/gg_error_sol.sh      &
nohup $SCRIPTDIR/gg_info_all_sol.sh   &
nohup $SCRIPTDIR/gg_mgr_alive_sol.sh  &
nohup $SCRIPTDIR/gg_operations_sol.sh  &

exit 0
