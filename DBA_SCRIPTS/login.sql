rem script: login.sql
rem   -- placed at SQLPATH or working directory. 
rem      Display username@sid> as SQL* Plus prompt,
rem      also give better text alignment for AUTOTRACE execution plan output
rem 
rem      Originally from Tom Kyte book "Expert Oracle Database Architecture"
rem  

set autotrace off
set termout off
set echo off

-- define_editor=vim
define_editor=vi
set serveroutput on size 1000000 format wrapped
set trimspool on
set long 5000
set linesize 120 
set pagesize 9999
set head on
set arraysize 100


column object_name format a30
column segment_name format a30
-- WHENEVER SQLERROR EXIT SQL.SQLCODE
-- default width of the explain plan output from Autotrace
column plan_plus_exp format a100  

REM prompt

define gname=SQL
column global_name new_value gname
column promptuser new_value promptuser

select lower(user) || '@'  promptuser from dual;

select instance_name || '_' || host_name   global_name from v$instance;

set sqlprompt '&promptuser&gname> '
set termout on


--- following taken from JL setenv.sql 


clear breaks
ttitle off
btitle off

column owner format a25
column segment_name format a30
column table_name format a20
column index_name format a20
column object_name format a20
column subobject_name format a20
column partition_name format a20
column subpartition_name format a20
column column_name format a20
column column_expression format a40 word wrap
column constraint_name format a20
column referenced_name format a30
column file_name format a60
column low_value format a24
column high_value format a24
column parent_id_plus_exp       format 999
column id_plus_exp              format 990
column plan_plus_exp            format a90
column object_node_plus_exp     format a14
column other_plus_exp           format a90
column other_tag_plus_exp       format a29

column access_predicates        format a80
column filter_predicates        format a80
column projection               format a80
column remarks                  format a80
column partition_start          format a12
column partition_stop           format a12
column partition_id             format 999
column other_tag                format a32
column object_alias             format a24

column object_node              format a13
column  other                   format a150

column os_username              format a30
column terminal                 format a24
column userhost                 format a24
column client_id                format a24

column statistic_name format a35

column namespace format a20
column attribute format a20

column hint format a40

column start_time       format a25
column end_time         format a25

column time_now noprint new_value m_timestamp

set feedback off

select to_char(sysdate,'hh24miss') time_now from dual;
commit;

set feedback on

set timing off
set verify off

alter session set nls_date_format='DD-Mon-YYYY HH24:MI:SS';
