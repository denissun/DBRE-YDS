column column_name format a20
column table_name format a28
column index_name format a40
set lines 160
set echo off
break on index_name skip 1
select i.table_name,
       c.index_name,
       c.column_name,
       c.column_position col_pos,
       i.uniqueness,
       i.partitioned,
       i.VISIBILITY,
       i.status
  from
       dba_indexes i,
       dba_ind_columns c
 where i.table_owner=upper('&tabowner')
   and i.table_name = upper('&tabname')
   and i.index_name = c.index_name
   and i.owner = c.index_owner
 order by 1,2,4
/
undefine tabowner
undefine tabname
set echo on

