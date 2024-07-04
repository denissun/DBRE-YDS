#!/bin/ksh
# $0 <sqlcmdcfg>


CURRDIR=`dirname $0`


cat $1 | grep -v "^#" | grep -v "^$"  | while read SQLCMD
do
  echo " ####  process   $SQLCMD "

$SQLCMD <<EOF
col spoolfile new_val spoolfile
col instance_name new_val instance_name
col host_name new_val host_name
col check_ts new_val check_ts

-- select 'config_inactive_accttime_' ||  instance_name ||'_' || host_name ||'_' ||to_char(sysdate, 'YYYYMMDD-HH24MISS') || '.spool' as spoolfile from v\$instance;
select 'config_inactive_accttime_' || instance_name || '_' ||  substr('&_connect_identifier', 1, instr( '&_connect_identifier', ':') -1 ) || '_' ||to_char(sysdate, 'YYYYMMDD-HH24MISS') || '.spool' as spoolfile
from v\$instance;

spool &spoolfile
select name db_name from v\$database;
select '&_connect_identifier' as connect_identifier from dual;
@config_inactive_accttime.sql
spool off
EOF
done
