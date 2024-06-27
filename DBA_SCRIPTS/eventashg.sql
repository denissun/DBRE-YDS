rem script ash_top5_15.sql
rem Top 5 events in the database from Ash data in the last 15 minutes  (10g)
rem 

break on inst_id skip 1
set verify off feedback off
accept begin_time default 5 prompt 'Enter value for begin_time (# min ago, default: 5 min):'
accept duration default 5 prompt 'Enter value for duration (1-60 min, default: 5 min):'

col event format a30
col wait_class format a15
col snap_start format a20
col snap_end format a14
col INST_ID format 99
col aas format 9999.9
set lines 200 
set pages 200

rem col mint format 99,999,999 
rem col maxt format 99,999,999 

select inst_id
       ,event
       ,wait_class
       ,round(evttot*100/tot,2) "%activity"
      , round(evttot/&duration/60,1) aas
       ,snap_start
       ,snap_end 
from
(
	select 
	       inst_id, 
	       decode(event,null,'CPU+Wait for CPU',event) event,
	       decode(wait_class,null,'CPU',wait_class) wait_class,
	       -- round(evttot*100/tot,2) "%activity",
	       evttot,
               tot,
	       to_char( mint, 'MM/DD/YY HH24:MI:SS') snap_start,
	       to_char( maxt, '--- HH24:MI:SS') snap_end,
	       row_number() over (partition by inst_id order by evttot desc) rn
	from (
	select distinct inst_id, event,
	       wait_class,
	       count(*) over (partition by inst_id,event) evttot,
	       count(*) over (partition by inst_id) tot,
	       min(sample_time) over () mint,
	       max(sample_time) over () maxt
	  from gv$active_session_history
	 where sample_time >= sysdate -&begin_time/1440
	   and sample_time <= sysdate -( &begin_time -&duration )/1440
	)
)
where rn <=5;

undefine begin_time
undefine duration
