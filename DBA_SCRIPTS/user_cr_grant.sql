rem script: user_cr_grant.sql 
rem  Purpose: generate create user script with privs
rem
rem  Usage: user_cr_grant <username> 
rem 
rem  Note: 
rem   If ORA-31608 encountered, it means the user does not 
rem   have grants in that category. Edit the spooled script 
rem   as ncessary
rem 
rem 

SET LINESIZE 200 
SET PAGESIZE 0 FEEDBACK off VERIFY off 
-- SET TRIMSPOOL on 
SET LONG 1000000 
-- COLUMN ddl_string FORMAT A100 WORD_WRAP

EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',true); 
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true); 
COLUMN ddl FORMAT A4000 

define username=&&1

spool &username._cr_ddl.sql


SELECT DBMS_METADATA.GET_DDL('USER', upper('&username') )  DDL
FROM dual;

prompt -- Role 
SELECT DBMS_METADATA.GET_GRANTED_DDL('ROLE_GRANT', upper('&username'))  DDL
FROM dual;

prompt -- Sys priv 
SELECT DBMS_METADATA.GET_GRANTED_DDL('SYSTEM_GRANT', upper('&username'))  DDL
FROM  dual;

prompt -- Object priv 
SELECT DBMS_METADATA.GET_GRANTED_DDL('OBJECT_GRANT', upper('&username'))  DDL
FROM dual;

prompt -- tablespace quota
SELECT  DBMS_METADATA.GET_GRANTED_DDL('TABLESPACE_QUOTA',upper('&username')) DDL 
from dual;


spool off 
