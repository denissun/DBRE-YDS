
col event format a30
-- last_call_et could be reset by each fetch call
-- so the acutal running time can be much longer than what ela_sec shows 
-- note we may miss long queries that last_call_et=0 at the time of execution this query
--
-- check also longops.sql 
--
col username for a16

select inst_id, username, sid, serial#,sql_id, status, event, last_call_et ela_sec, round(last_call_et/60) ela_min 
from gv$session
where username is not null 
and sql_id is not null
and status='ACTIVE'
and last_call_et > 10
order by status, last_call_et
;
