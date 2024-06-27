col tablespace_name  format     a24    justify c heading 'Tablespace'
col autoextensible  format      a14
col bigfile  format      a8
col size_g  format 9,999,990
col free_g  format 9,999,990
col pctusd  format   990.9   justify c heading 'Percent|Used'
set pages 200
 
 
-- tu.used_space:  for undo tablespaces, the value of this column includes space consumed by both expired and unexpired undo segments.
 
SELECT t.TABLESPACE_NAME,
       round(t.total_size_b/1024/1024/1024) AS "SIZE_G",
       round(100*tu.USED_space * s.block_size/t.total_size_b,1) pctusd,
       round((t.total_size_b - tu.USED_space * s.block_size)/1024/1024/1024) AS "FREE_G",
       t.AUTOEXTENSIBLE,
       s.bigfile
FROM DBA_TABLESPACE_USAGE_METRICS tu join
( select tablespace_name, sum(bytes) total_size_b, max(AUTOEXTENSIBLE) AUTOEXTENSIBLE
	   from dba_data_files
	  group by tablespace_name
) t
on (t.tablespace_name = tu.tablespace_name)
join dba_tablespaces s
on (t.tablespace_name=s.tablespace_name)
order by 3
/
