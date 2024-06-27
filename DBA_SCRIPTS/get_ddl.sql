SET LINESIZE 200 
SET PAGESIZE 0 FEEDBACK off VERIFY off 
SET TRIMSPOOL on 
SET LONG 1000000 
-- COLUMN ddl_string FORMAT A100 WORD_WRAP

EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'PRETTY',true); 
EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true); 
COLUMN ddl_string FORMAT A4000 

accept OBJTYPE default table prompt 'Enter value for OBJECT TYPE (default: table):'
accept OWNER prompt 'Enter value for OWNER: '
accept OBJNAME prompt 'Enter value for OBJECT NAME: '


spool obj_ddl.out
SELECT DBMS_METADATA.GET_DDL(upper('&OBJTYPE'), upper('&OBJNAME') , upper('&OWNER'))  ddl_string from dual; 
spool off 
set pagesize 999 feedback on verify on 
