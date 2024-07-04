-- 
-- assume connect user is db_admin, before install, we may want to grant
-- necessary privileges to db_admin  using grant.sql 
--
--  
--
-- prerequites:
--    grant.sql               -- grant privs to schema
--    tables_ddl.sql          -- create configs and alerts table
--    table_external.sql      -- create directory and exteranl table for alert log  
--
-- note


show  user
pro checing the user under whitch the packages are to be installed is  correc
pro hit enter to contiue or ctrl-c  to stop 
pause;



select name, to_char(sysdate, 'YYYY-MM-DD HH24:MI') from v$database; 

set echo off

@@notification.pks
@@notification.pkb

@@proactive.pks
@@proactive.pkb

@alert_file.pks
@alert_file.pkb

@@admin.pks
@@admin.pkb

@@history.pks
@@history.pkb


@@debug_ddl.sql
@@debug.pks  
-- @@debug.pkb  
@@debug_disable.pkb  


set echo on

grant execute on  db_admin.admin to dba;
grant execute on  db_admin.admin to IPM_DB_DEPLOY; 
grant execute on  db_admin.admin to TEAM_DBA_OPS_ROLE;


grant execute on  db_admin.notification to dba;
grant execute on  db_admin.notification to IPM_DB_DEPLOY; 
grant execute on  db_admin.notification to TEAM_DBA_OPS_ROLE;

grant execute on  db_admin.proactive to dba;
grant execute on  db_admin.proactive to IPM_DB_DEPLOY; 
grant execute on  db_admin.proactive to TEAM_DBA_OPS_ROLE;

grant execute on  db_admin.alert_file to dba;
grant execute on  db_admin.alert_file to IPM_DB_DEPLOY; 
grant execute on  db_admin.alert_file to TEAM_DBA_OPS_ROLE;

grant execute on  db_admin.history to dba;
grant execute on  db_admin.history to IPM_DB_DEPLOY; 
grant execute on  db_admin.history to TEAM_DBA_OPS_ROLE;

grant execute on  db_admin.debug to PUBLIC;

create public synonym notfication for db_admin.notification;
create public synonym alert_file for db_admin.alert_file;
create public synonym proactive for db_admin.proactive;
create public synonym admin for db_admin.admin;
create public synonym history for db_admin.history;
create public synonym debug for db_admin.debug;


-- exit
