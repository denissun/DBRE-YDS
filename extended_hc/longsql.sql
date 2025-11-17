col event format a30
-- last_call_et could be reset by each fetch call
-- so the acutal running time can be much longer than what ela_sec shows
-- note we may miss long queries that last_call_et=0 at the time of execution this query
--
-- check also longops.sql
--
col username for a16
col username for a20
col sid for a10
col serial# for a16
col sql_id for a20
col event for a34
col ela_sec for a13
col ela_min for a13
col status for a12
set lines 200

select /* realtime_hc */ *
from (
select inst_id, 
'| ' || username as username, 
'| ' || sid as sid, 
'| ' || serial# as serial#,
'| ' || sql_id as sql_id, 
'| ' || status as status, 
'| ' || event as event,
'| ' ||  last_call_et as ela_sec, 
'| ' || round(last_call_et/60) as ela_min
from gv$session
where username is not null
and sql_id is not null
and status='ACTIVE'
and ( event not like 'Streams AQ: waiting for mess%' 
and event !='PX Deq: Execution Msg'
)
and last_call_et > 10
order by status, last_call_et desc
)
where rownum <=10
;

