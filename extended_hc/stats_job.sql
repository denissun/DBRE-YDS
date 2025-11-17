define label=&1

set lines 200

SELECT '~GATHER-STATS~&label' label,
    s.sid,
    s.serial#,
    s.username,
    s.module,
    s.status,
    TO_CHAR(s.logon_time, 'YYYY-MM-DD HH24:MI:SS') AS logon_time,
    s.last_call_et AS elapsed_seconds
FROM
    v$session s
WHERE
    s.module LIKE 'DBMS_STATS%'
    -- OR s.program LIKE '%rman%' -- RMAN also calls DBMS_STATS
    -- OR s.module LIKE 'DBMS_SCHEDULER%'
;

SELECT '~GATHER-STATS~&label' label,
    client_name,
    -- job_name,
    -- status,
    window_start_time,
    window_end_time
FROM
    dba_autotask_client_history
WHERE
    client_name = 'auto optimizer stats collection'
    AND window_start_time >= SYSDATE - 1/24 -- Check the last hour
ORDER BY
    window_start_time DESC;
