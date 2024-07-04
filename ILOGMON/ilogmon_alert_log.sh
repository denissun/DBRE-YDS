#!/bin/bash

. ~/.bash_profile

sqlplus / <<EOF
spool /tmp/ilogmon.log
set serveroutput on;
execute apex_mon.ilogmon.get_recent_alert(10);
spool off
exit;
EOF
