define label=&1

col sid for 99999 
col label_inst_id for a18
col Operation for a28
col "Message Details" for a30
col SID for a7
col "% Comp" for a6
col "TR (min)" for a8
col "ET (min)" for a8

SELECT /* realtime_hc */ '~RMAN~&label | ' || inst_id as label_inst_id,
    '| ' || sid as sid,
    '| ' || opname Operation,
    '| ' || round(sofar / totalwork * 100, 1) "% Comp",
    '| ' || to_char(start_time, 'mm/dd/yy hh24:mi') "Start Time",
    '| ' || round(time_remaining / 60, 2) "TR (min)",
    '| ' || round(elapsed_seconds / 60, 2) "ET (min)",
    '| ' || substr(message, instr(message, ':', 1, 2) + 2, 60) "Message Detail"
FROM
    gv$session_longops
WHERE
    opname LIKE 'RMAN%'
    AND opname NOT LIKE '%aggregate%'
    AND sofar <> totalwork
    AND totalwork <> 0
    and opname !='RMAN: archived log backup'
ORDER BY
    inst_id, sid;

