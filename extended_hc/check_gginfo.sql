define REPLICATION_INFO_TAB=&1

col dbname format a14
col program format a26
col status format a20
col group_name format a26
col lag_chkpt for a16
col tim_chkpt for a16
col  MON_TIMESTEMP format a20
col label for a8 
set lines 200 

pro *** Top GoldenGate Lag  
pro


 
select /* realtime_hc */  'GG_BKLOG' label, 
'| ' || dbname as dbname, 
'| ' || program as program, 
'| ' || status as status, 
'| ' || ggroup as group_name, 
'| ' || lag_chkpt as lag_chkpt,
'| ' || tim_chkpt as tim_chkpt, 
'| ' || mon_ts  mon_timestemp
from
(
select
  DBNAME 
 ,program 
 ,status
 ,ggroup  
 ,lag_chkpt  
 ,tim_chkpt  
 ,to_char(mon_ts,'YYYY-MM-DD HH24:MI')  as mon_ts 
from &&REPLICATION_INFO_TAB 
where mon_ts = (select max(mon_ts) from &&REPLICATION_INFO_TAB)
and status='RUNNING'
order by lag_chkpt desc 
)
where rownum<=10
union all
select 'GG_BKLOG' label, 
'| ' || dbname as dbname, 
'| ' || program as program, 
'| ' || status as status, 
'| ' || ggroup as group_name, 
'| ' || lag_chkpt as lag_chkpt,
'| ' || tim_chkpt as tim_chkpt, 
'| ' || mon_ts  mon_timestemp
from
(
select
  DBNAME 
 ,program 
 ,status
 ,ggroup  
 ,lag_chkpt  
 ,tim_chkpt  
 ,to_char(mon_ts,'YYYY-MM-DD HH24:MI')  as mon_ts 
from &&REPLICATION_INFO_TAB 
where mon_ts = (select max(mon_ts) from &&REPLICATION_INFO_TAB)
and status !='RUNNING'
)
where rownum<=10
; 

undefine REPLICATION_INFO_TAB
