-- shared_preload_libraries = 'pg_stat_statements'
-- pg_stat_statements.track = all
-- CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

select now() script_start_time;

create temp table tmp_pss_ as select 1 as snap_id, now() as sample_time, d.* from  pg_stat_statements  d where 1=0;

insert into tmp_pss_ select 1, now(),   d.* from  pg_stat_statements  d ;
select pg_sleep(10);
insert into tmp_pss_ select 2, now(),   d.* from  pg_stat_statements  d ;


\pset format wrapped
\pset columns 1500
\x


select datname, usename, queryid, query_text, duration_s, num_calls, num_rows, total_elapsed_time_ms, 
 case num_calls
   when 0 then total_elapsed_time_ms 
   else  total_elapsed_time_ms/num_calls end  as  ms_per_call,
   (num_blk_hits + num_blk_read)/num_calls  as logical_reads_per_call,   
   100*num_blk_hits/nullif(num_blk_hits + num_blk_read,0) hit_percent
from 
(
	select db.datname, u.usename, b.queryid
	       , substr(b.query, 1,200) query_text
	       , extract ( epoch from (e.sample_time - b.sample_time) ) as duration_s
	       , e.calls - b.calls as num_calls
	       , e.rows - b.rows as num_rows
               , e.shared_blks_hit - b.shared_blks_hit as num_blk_hits
               , e.shared_blks_read - b.shared_blks_read as num_blk_read
	       , round(e.total_exec_time - b.total_exec_time) as total_elapsed_time_ms
	from ( select * from tmp_pss_ where snap_id=1 ) b 
         join ( select * from tmp_pss_ where snap_id=2 ) e on e.userid=b.userid and  e.queryid=b.queryid and e.dbid=b.dbid 
         join pg_user u on u.usesysid=b.userid
         join pg_database db on db.oid=b.dbid  and db.datname=current_database()
	where b.queryid !=440101247839410938  -- excluding select pg_sleep(10)
	order by total_elapsed_time_ms desc limit 10
) t;

drop table tmp_pss_;

select now() script_end_time;
\x

