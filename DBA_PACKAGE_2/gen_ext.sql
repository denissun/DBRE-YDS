set echo off feedback off verify off heading off
spool cr_ext.sql 
select 'Create or replace directory alert_dir' || inst_id  || ' as ''' ||  value
|| ''';'  from gv$parameter where name='background_dump_dest';





select ' CREATE TABLE "ALERT_FILE' || inst_id || '_EXT" ' || chr(10) ||
       '(    "MSG_LINE" VARCHAR2(1000)) ' || chr(10) ||
       ' ORGANIZATION EXTERNAL' || chr(10) ||
       '( TYPE ORACLE_LOADER'     || chr(10) ||
               ' DEFAULT DIRECTORY "ALERT_DIR' ||inst_id ||'"' || chr(10) ||
               ' ACCESS PARAMETERS '  || chr(10) ||
               '( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII'  || chr(10) ||
                       ' nobadfile nologfile nodiscardfile ' || chr(10) ||
                       ' skip 0 ' || chr(10) ||
                       ' READSIZE 1048576 ' || chr(10) ||
                       ' FIELDS LDRTRIM ' || chr(10) ||
                       ' REJECT ROWS WITH ALL NULL FIELDS' || chr(10) ||
                       '( MSG_LINE (1:1000) CHAR(1000)) ' || chr(10) ||
                       ') '|| chr(10) ||
               'LOCATION ' || chr(10) ||
               '( ''alert_' || instance_name || '.log'') '|| chr(10) ||
               ') ' || chr(10) ||
       'REJECT LIMIT UNLIMITED' || chr(10) ||
       '/'
from gv$instance;

spool off
