define label=&1

col inst_id format 99
col resource_name format a30
col current_utilization for 99999999 
col limit_value for a20
col limit for a20
col label for a25

select /* realtime_hc */  '~RSRC_USAGE_LIMIT~&label' as label,  inst_id, resource_name, current_utilization, limit_value, 
round(100* current_utilization/limit_value) pct_util,
case when   round(100* current_utilization/limit_value) > 70 then 'ALERT' else 'NORMAL' end results
from gv$resource_limit
where resource_name in ('sessions', 'processes')
union all
select '~RSRC_USAGE_LIMIT~&label' as label, 1 as inst_id, 'num_db_file' resource_name, a.num_dbfile_current current_utilization, b.num_dbfile_limit limit_value, round(100* a.num_dbfile_current/b.num_dbfile_limit) pct_util,
 case when  round(100* a.num_dbfile_current/b.num_dbfile_limit) > 90 then 'ALERT ' else 'NORMAL' end results 
from 
( select count(*) as num_dbfile_current from v$datafile ) a,
( select value as num_dbfile_limit from v$parameter where name='db_files') b
;


