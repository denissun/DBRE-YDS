define REPLICATION_INFO_TAB=&1

col dbname format a14
col queue_name format a56
col queue_type format a20
col backlog_msg for a11
col backlog_age for a11
col port for a6
col  MON_TIMESTEMP format a20
col label for a8 
set lines 200 

pro *** Top 5 Splex Q backlog messages
pro

 
select /* realtime_hc */ 'Q_BKLOG' label, '| ' || dbname as dbname, '| ' || qname as queue_name, '| ' || qtype as queue_type, 
'| ' || backlog_msg as backlog_msg, 
'| ' || backlog_age backlog_age,
'| ' || port as port, 
'| ' || mon_ts  mon_timestemp
from
(
select 
 dbname 
 ,qname  
 ,qtype   
 ,backlog_msg 
 ,backlog_age 
 ,port 
 ,to_char(mon_ts,'YYYY-MM-DD HH24:MI')  as mon_ts 
from &&REPLICATION_INFO_TAB 
where mon_ts >= (
	select min(port_mon_ts)
	from 
	(
	select port, max(mon_ts) port_mon_ts 
	 from &&REPLICATION_INFO_TAB
	group by port
	)
)
order by backlog_msg desc 
)
where rownum<=5
; 

pro
pro *** check max monitor timestamp of each port, should not delay more than 2 min
select port ||'| ' || to_char(max(mon_ts), 'YYYY-MM-DD HH24:MI:SS')  port_max_mon_timestamp 
from &&REPLICATION_INFO_TAB
group by port
;


undefine REPLICATION_INFO_TAB
