rem script: tbs.sql 
rem  -- list data files of a tablespace 
rem 

set echo off;
column file_name format a75;
set lines 200
PROMPT Enter a tablespace
ACCEPT tbs PROMPT 'Tablespace:'
select file_name, file_id, bytes/1024/1024
from dba_data_files where tablespace_name = upper('&tbs') 
/
