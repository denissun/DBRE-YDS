---- html format -----

set feedback off
set pages 999 

set markup HTML ON HEAD " -
<style type='text/css'> -
  body {font:10pt Arial,Helvetica,sans-serif; color:black; background:White;} -
  p {   font:10pt Arial,Helvetica,sans-serif; color:black; background:White;} -
        table,tr,td {font:10pt Arial,Helvetica,sans-serif; color:Black; background:#f7f7e7; -
        padding:0px 0px 0px 0px; margin:0px 0px 0px 0px; white-space:nowrap;} -
  th {  font:bold 10pt Arial,Helvetica,sans-serif; color:#336699; background:#cccc99; -
        padding:0px 0px 0px 0px;} -
  h1 {  font:16pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; -
        border-bottom:1px solid #cccc99; margin-top:0pt; margin-bottom:0pt; padding:0px 0px 0px 0px;} -
  h2 {  font:bold 10pt Arial,Helvetica,Geneva,sans-serif; color:#336699; background-color:White; -
        margin-top:4pt; margin-bottom:0pt;} a {font:9pt Arial,Helvetica,sans-serif; color:#663300; -
        background:#ffffff; margin-top:0pt; margin-bottom:0pt; vertical-align:top;} -
</style> -
<title>DB User Account CPI810 Compliance Report</title>" -
BODY "" -
TABLE "border='1' align='center' summary='Script output'" -
SPOOL ON ENTMAP ON PREFORMAT OFF


col CON_NAME new_val CON_NAME
col REPORTFILE new_val REPORTFILE

define CON_NAME='xxx'

SELECT SYS_CONTEXT ('USERENV', 'CON_NAME') as CON_NAME FROM DUAL;

col REPORTFILE new_val REPORTFILE

select
case '&CON_NAME'
when 'xxx' then
   instance_name || '_' || host_name  || '_cpi810_' || to_char(sysdate, 'YYYYMMDD') || '.html'
else
  instance_name || '_' || host_name  || '_' ||  replace('&CON_NAME', '$','') ||  '_cpi810_' || to_char(sysdate, 'YYYYMMDD') || '.html'
end  as REPORTFILE
from gv$instance where inst_id=1;


spool &REPORTFILE

SET MARKUP HTML OFF
prompt <h1> List of Report Sections </h1></br>
prompt <a href="#Instance/Database Basic Info"> Instance/Database Basic Info  </a> </br>
prompt <a href="#Database Audit Config"> Database Audit Config  </a> </br>
prompt <a href="#Profile Config"> Profile Config (SOX C-13740  </a> </br>
prompt <a href="#Columns audited by"> Columns audited by FGA </a></br>
prompt <a href="#System Privileges Being"> System Privileges Being Audited </a></br>
prompt <a href="#List users this year">List users created this year </a></br>
prompt <a href="#List users Status"> List users with Status , Profile and Lock/Expire dates </a></br>
prompt <a href="#Users DBA Admin">  Users with DBA and other Admin roles assigned (SOX C-13739) </a></br>
prompt <a href="#Users Any Admin"> Users with 'ANY' and other ADMIN system Privileges </a></br>
prompt <a href="#PUBLIC Access SYS"> PUBLIC Access to SYS Privs and Roles </a></br>
prompt <a href="#Default Password">  Accounts with Default passwords. (SOX C-8481) </a></br>
prompt <a href="#Password Verfiy Function">  Password Verify Function definition </a></br>
prompt <a href="#Database Links"> Database Links  </a> </br>
prompt <a href="#pwd expires"> Users whose pwd expires in less than 10 days or has expired in the past </a></br>
prompt <a href="#open accout profiles">  Review open user account profiles </a></br>
prompt <a href="#locked or expired"> Review follwing locked or expired  user accounts </a></br>
prompt <a href="#180days">  Review user accounts that have not been used to log into db for at least 180 days </a></br>
prompt <a href="#role_granted">  Roles Granted </a></br>
prompt <a href="#tablecount">Table count by application db user account</a></br>
prompt <a href="#vaultparam">Vault and Label Security parameter values</a></br>
prompt <a href="#enctbs">Encrpted Tablespace by TDE</a></br>
prompt <a href="#dbsize">Total DB Size</a></br>

SET MARKUP HTML ON


SET MARKUP HTML OFF
prompt ********************************************
prompt <h3 id="Instance/Database Basic Info"> Instance/Database Basic Info  </h3>
prompt ********************************************
SET MARKUP HTML ON

select to_char(sysdate, 'YYYY-MON-DD HH24:MI:SS') report_time, instance_name, host_name, version, db_unique_name, open_mode from v$instance, v$database;

select name as container_name from v$containers;

SET MARKUP HTML OFF
prompt ********************************************
prompt <h3 id="Database Audit Config">  Database Audit Config (SOX C-13790) (enable audit, sys_ops and ddl logging) </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON


select name
     , decode(type, 1, 'Boolean'
                  , 2, 'String'
                  , 3, 'Integer'
                  , 4, 'Parameter file'
                  , 5, 'Reserved'
                  , 6, 'Big integer'
       ) type
     , value
from v$parameter where name in ('audit_file_dest', 'audit_sys_operations', 'audit_syslog_level', 'audit_trail','enable_ddl_logging')
order by name;

pro # audit_sys_operations should be TRUE
pro # audit_trail is recommeded to be set with 'XML'
pro # DDL logging should be enabled per SOX

SELECT VALUE "Is Unified Auditiong Enabled"  FROM V$OPTION WHERE PARAMETER = 'Unified Auditing';


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Profile Config">  Profile Config (SOX C-13740) </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON
select * from dba_profiles order by 1,4;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Columns audited by"> Columns audited by FGA </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON
select * from dba_audit_policy_columns order by 2,3;

prompt
select object_schema, policy_name,enabled, policy_column, policy_column_options
from DBA_AUDIT_POLICIES order by 1;
prompt
select * from dba_tab_privs where (table_name,owner) in ( select object_name,object_schema from dba_audit_policies) order by 1,3;



SET MARKUP HTML OFF
prompt ********************************************
prompt <h3 id="System Privileges Being"> System Privileges Being Audited </h3>
prompt ********************************************
SET MARKUP HTML ON

select * from DBA_PRIV_AUDIT_OPTS order by user_name, privilege;


SET MARKUP HTML OFF
prompt ********************************************
prompt <h3 id="List users this year">List users created this year </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

--select rpad(username,25) dbuser,rpad(account_status,20) acct_status,profile,created,lock_date,expiry_date
--from dba_users where created > sysdate -90 order by 3,1,2;
select username, profile, created, lock_date, account_status status from dba_users where created > TRUNC(sysdate,'YEAR') order by 3,2;

SET MARKUP HTML OFF
prompt ********************************************
prompt <h3 id="List users Status"> List users with Status , Profile and Lock/Expire dates </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON


select user_id, rpad(username,25) dbuser,rpad(account_status,20) acct_status,profile, created, 
case  when last_login is null then 'never logged in' else to_char(last_login) end as last_login, lock_date,expiry_date,ORACLE_MAINTAINED
from dba_users
order by 3,1,2;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Users DBA Admin">  Users with DBA  other Admin roles assigned (SOX C-13739) </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON


select rpad(a.grantee,30) dbuser, a.granted_role grantee_role,b.account_status,b.profile, b.created,b.lock_date
from  dba_role_privs a, dba_users b
where a.GRANTED_ROLE in ('DBA','RESOURCE','EXP_FULL_DATABASE','IMP_FULL_DATABASE','SCHEDULER_ADMIN')
and   a.grantee not in ('SYS','SYSTEM','DBA')
and   a.grantee = b.username
--and   b.account_status = 'OPEN'
order by 2, 1;



SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Users Any Admin"> Users with 'ANY' and other ADMIN system Privileges </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

select rpad(grantee,30) dbuser, privilege  grantee_privilege
from  dba_sys_privs a,dba_users b
where 1 = 1 and
( a.PRIVILEGE like ('DROP ANY%') or
 a.PRIVILEGE like ('ALTER ANY%') or
 a.PRIVILEGE like ('CREATE ANY%') or
 a.PRIVILEGE like ('GRANT ANY%') or
 a.PRIVILEGE like ('EXECUTE ANY%') or
 a.PRIVILEGE like ('AUDIT %') or
 a.PRIVILEGE like ('ADMINISTER %') or
 a.PRIVILEGE in ('SELECT ANY TABLE','SELECT ANY VIEW','ALTER DATABASE','ALTER SYSTEM','ALTER USER','BECOME USER','CREATE DATABASE LINK','UNLIMITED TABLESPACE','RESTRICTED SESSION','CREATE USER','DROP USER') )
and   ( a.grantee not in ('SYS','SYSTEM','DBA','IMP_FULL_DATABASE')  )
and   a.grantee = b.username
and   b.account_status = 'OPEN'
ORDER by 2,1;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="PUBLIC Access SYS"> PUBLIC Access to SYS Privs and Roles </h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON


prompt ## Role Privs

prompt
Select * from dba_role_privs where grantee='PUBLIC' order by granted_role;
prompt
prompt ## SYS Privs
prompt
Select * from dba_sys_privs where grantee='PUBLIC' order by privilege;

prompt
prompt ## Dev/PS with SYS Privs
prompt
Select * from dba_sys_privs where privilege != 'CREATE SESSION' and grantee in ( select username from dba_users where profile in ('DEVL','APP_USER_PROFILE'))
order by 2,1;

SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Default Password">  Accounts with Default passwords. (SOX C-8481) </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

select a.username,created,account_status,lock_date,profile from dba_users_with_defpwd a, dba_users b where a.username = b.username order by 1;

prompt ## Any accounts with Def pwds should be LOCKED or EXPIRED and LOCKED status


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Password Verfiy Function">  Password Verify Function definition </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON



select profile, LIMIT PASSWD_VERIFY_FUNC from dba_profiles where RESOURCE_NAME ='PASSWORD_VERIFY_FUNCTION' order by 1;


select owner, name, text
from dba_source
where name in
(
select distinct limit
from dba_profiles where RESOURCE_NAME ='PASSWORD_VERIFY_FUNCTION' 
)
order by owner, name, line
;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="Database Links"> Database Links </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

select owner,db_link, username, host, created from dba_db_links
order by 1,3;

select * from DBA_DB_LINK_SOURCES;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="pwd expires"> Users whose pwd expires in less than 10 days or has expired in the past </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

select username, account_status, expiry_date, created, profile
from dba_users where expiry_date < sysdate + 10 and account_status= 'OPEN'
order by username
;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="open accout profiles">  Review open user account profiles </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

select username, account_status, profile, created, lock_date, expiry_date
from dba_users
where account_status ='OPEN'
order by profile, username;


SET MARKUP HTML OFF
prompt
prompt ********************************************
prompt <h3 id="locked or expired"> Review follwing locked or expired  user accounts </h3>
prompt ********************************************
prompt
SET MARKUP HTML ON

select username, account_status, profile, created, lock_date, expiry_date
from dba_users
where account_status !='OPEN'
order by username;


SET MARKUP HTML OFF
prompt
prompt ********************************************
pro <h3 id="180days">  Review user accounts that have not been used to log into db for at least 180 days </h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON

pro ### those accounts may be required to be dropped per CPI-810, schema object owner only should be excluded

select username as inactive_accounts_180days, profile, account_status, expiry_date, lock_date, last_login
from dba_users
where  username not in(
'SYSTEM'
,'SYS'
, 'XDB'
,'APPQOSSYS'
,'AUDSYS'
,'OUTLN'
,'DVSYS'
,'SYSBACKUP'
,'SYSDG'
,'SYSKM'
,'GSMADMIN_INTERNAL'
,'GSMCATUSER'
,'GSMUSER'
,'ORACLE_OCM'
,'XS$NULL'
)
and (  expiry_date < sysdate -180
       or lock_date < sysdate -180
       or last_login < sysdate -180
)
order by 1
;


SET MARKUP HTML OFF
prompt
prompt ********************************************
pro <h3 id="role_granted">  Roles Granted </h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON

pro ### grantee not in ('SYS','DBA','RDSADMIN','SYSDBA')

select granted_role,listagg(grantee, ',') grantees
from dba_role_privs
where grantee not in ('SYS','DBA','RDSADMIN','SYSDBA')
group by granted_role
order by 1
/

SET MARKUP HTML OFF
prompt
prompt ********************************************
pro <h3 id="tablecount">  Table count by application db user account </h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON


select owner, count(*) num_of_tables
from dba_tables
where owner not in (
'SYSTEM'
,'SYS'
, 'XDB'
,'APPQOSSYS'
,'AUDSYS'
,'OUTLN'
,'DVSYS'
,'SYSBACKUP'
,'SYSDG'
,'SYSKM'
,'GSMADMIN_INTERNAL'
,'GSMCATUSER'
,'GSMUSER'
,'ORACLE_OCM'
,'XS$NULL'
)
group by owner
order by owner;

SET MARKUP HTML OFF
prompt
prompt ********************************************
pro <h3 id="vaultparam"> Vault and Label Security Parameter   </h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON

SELECT PARAMETER, VALUE FROM V$OPTION WHERE PARAMETER in ('Oracle Database Vault', 'Oracle Label Security');


SET MARKUP HTML OFF
prompt
prompt ********************************************
pro <h3 id="enctbs">Encrpted Tablespace by TDE</h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON

select tablespace_name, encrypted from dba_tablespaces where encrypted='YES';

select * from gv$encryption_wallet;

SET MARKUP HTML OFF
prompt
prompt ********************************************
pro <h3 id="dbsize">Total Database Size</h3>
prompt ********************************************
prompt </br>
SET MARKUP HTML ON

select round((a.data_size+b.temp_size+c.redo_size)/1024/1024/1024) "total_size GB"
from ( select sum(bytes) data_size
         from dba_data_files ) a,
     ( select nvl(sum(bytes),0) temp_size
         from dba_temp_files ) b,
     ( select sum(bytes) redo_size
         from sys.v_$log ) c
/

spool off
