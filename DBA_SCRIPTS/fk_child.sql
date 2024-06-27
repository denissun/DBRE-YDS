rem script: fk_child.sql 
rem 
rem find all childern of a table
rem  input owner and table_name
rem 
rem usage: @fk_child <owner> <parent_table_name>
rem 

clear breaks
clear computes

set linesize 250
set pagesize 40
set verify off

define owner=&&1
define table_name=&&2

column owner    format a14      heading "Owner"
column name     format a28      heading "Constraint Name"
column type     format a1       heading "T|y|p|e"
column tn       format a25      heading "Table Name"
column r_owner  format a14      heading "Ref Owner"
column r_name   format a24      heading "Ref Constraint Name"
column status   format a8       heading "Status"

Prompt -----  Children of  &owner &table_name  --------

select a.owner                    owner,
       a.table_name               tn,
       a.constraint_name          name,
--       a.constraint_type          type,
--       a.r_owner                  r_owner,
       a.r_constraint_name        r_name,
       a.status                   status
from dba_constraints a, dba_constraints b
where b.table_name = upper ('&table_name')
  and b.owner = upper ('&owner')
  and b.constraint_type in ('P', 'U')
  and a.constraint_type='R'
  and a.r_owner=b.owner
  and a.r_constraint_name=b.constraint_name
/

undefine 1
undefine 2
