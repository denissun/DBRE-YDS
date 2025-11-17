col machine for a24
col username for a15
col instance_name for a16
set lines 200 
select /* realtime_hc */ i.instance_name, s.machine, s.username, s.event, count(*), '~data~repl' label 
from gv$session s, gv$instance i  
where  s.inst_id = i.inst_id
and ( s.username like 'SPLEX%' or s.username ='GGADMIN' )
group by i.instance_name, s.machine, s.username, s.event
order by s.username
;

