define label=&1
define CPU_THRESHOLD=&2
-- average host cpu utilization (%) in past 2 min

SELECT /* realtime_hc */  '~CPU~&label' label,  a.inst_id,  round(avg(a.value)) HOST_CPU_PCT,
    case when round(avg(a.value)) > &CPU_THRESHOLD
         then 'ALERT'
    else 'NORMAL' end result
    FROM gv$sysmetric_history a
where a.metric_name ='Host CPU Utilization (%)'
and begin_time >= sysdate - 2/1440
group by inst_id
order by 1
/
