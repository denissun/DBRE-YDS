rem script ash_top5_15.sql
rem Top 5 events in the database from Ash data in the last 15 minutes  (10g)
rem


define label=&1

-- break on inst_id skip 1
set verify off feedback off

col event format a42
col wait_class format a14
col snap_start format a20
col snap_end format a14
col INST_ID format 9 
col aas format a5 
col CPU_COUNT for a10
col host_name for a30
col "%activity" for a10
col label format a30
set lines 200
set pages 200

rem col mint format 99,999,999
rem col maxt format 99,999,999

col instance_name new_val instance_name

select /* realtime_hc */ i.instance_name, i.host_name, to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') chk_time, p.value CPU_COUNT
from gv$instance i, gv$parameter p
where i.inst_id=p.inst_id
and p.name='cpu_count'
;


break on inst_id

select inst_id                          as inst_id
       ,'| ' || event                   as event
       ,'| ' || wait_class              as wait_class
       ,'| ' || round(evttot*100/tot,1) as "%activity"
       ,'| ' || round(evttot/5/60)      as aas
       ,'| ' || snap_start              as snap_start
       ,'| ' || snap_end                as snap_end
       ,'| ' || '~data~&label'  as label
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
               to_char( maxt, 'HH24:MI:SS') snap_end,
               row_number() over (partition by inst_id order by evttot desc) rn
        from (
        select distinct inst_id, event,
               wait_class,
               count(*) over (partition by inst_id,event) evttot,
               count(*) over (partition by inst_id) tot,
               min(sample_time) over () mint,
               max(sample_time) over () maxt
          from gv$active_session_history
         where sample_time >= sysdate -5/1440
           and sample_time <= sysdate
        )
)
where rn <=5;

