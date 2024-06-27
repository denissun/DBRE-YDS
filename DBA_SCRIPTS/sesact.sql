-- Gets all active sessions
-- You can restrict to users connected thru sqlplus(program like '%sqlplus%)


set linesize 220
col program format a30
col "sid, serial#" format a16
col username format a10
col spid format a7
col osuser format a10
col module format a15
col machine format a15
col program format a15
col logon_time format a20

select s.sid || ', ' || s.serial# "sid, serial#", 
       p.spid "spid", 
--       p.pid, -- remote server process?
       s.username,
       s.osuser,
       s.module, 
       s.machine, 
       s.program,
       TO_CHAR(s.logon_Time,'DD-MON-YYYY HH24:MI:SS') AS logon_time
from v$session s, v$process p
where s.status = 'ACTIVE' 
  and p.addr=s.paddr
  and s.username is not null
order by 1
/
