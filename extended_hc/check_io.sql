define label=&1
define IOPS_THRESHOLD=&2
-- average host cpu utilization (%) in past 2 min

SELECT /* realtime_hc */  '~IO-READ~&label' label,  
a.inst_id,  round(avg(a.value)) Single_block_read_ms,
    case when round(avg(a.value)) > 10 
         then 'ALERT'
    else 'NORMAL' end result
    FROM gv$sysmetric_history a
where a.metric_name like 'Average Synchronous Single-Bl%'
and begin_time >= sysdate - 10/1440
group by inst_id
order by 1
/


SET LINESIZE 200
SET PAGESIZE 50
COLUMN dbid NEW_VALUE thisdb NOPRINT
COLUMN snap_time FORMAT A20
COLUMN total_mb_per_sec FORMAT 9999.99 HEADING 'Total MB/s'
COLUMN total_iops_count FORMAT 9999999 HEADING 'Total IOPS'
COLUMN iops_status FORMAT A10 HEADING 'IOPS Status' 
-- NEW: Format for the status flag

SELECT dbid FROM v$database;

-- 2. Main Query: Calculate Max I/O Metrics per Snapshot for the Last 1 Hour
SELECT /* realtime_hc */  '~IO-IOPS~&label' label,  
    TO_CHAR(s.end_interval_time, 'YYYY-MM-DD HH24:MI') AS snap_time,
    -- Calculate Total MB/s (Reads + Writes)
    SUM(CASE WHEN m.metric_name IN ('Physical Read Total Bytes Per Sec', 'Physical Write Total Bytes Per Sec') THEN m.maxval ELSE 0 END) / 1024 / 1024 AS total_mb_per_sec,
    -- Calculate Total IOPS (Reads + Writes + Redo)
    SUM(CASE WHEN m.metric_name = 'Physical Read Total IO Requests Per Sec' THEN m.maxval ELSE 0 END) +
    SUM(CASE WHEN m.metric_name = 'Physical Write Total IO Requests Per Sec' THEN m.maxval ELSE 0 END) +
    SUM(CASE WHEN m.metric_name = 'Redo Writes Per Sec' THEN m.maxval ELSE 0 END) AS total_iops_count,
    -- NEW: IOPS Alerting Flag
    CASE 
        WHEN (
            SUM(CASE WHEN m.metric_name = 'Physical Read Total IO Requests Per Sec' THEN m.maxval ELSE 0 END) +
            SUM(CASE WHEN m.metric_name = 'Physical Write Total IO Requests Per Sec' THEN m.maxval ELSE 0 END) +
            SUM(CASE WHEN m.metric_name = 'Redo Writes Per Sec' THEN m.maxval ELSE 0 END)
        ) > &IOPS_THRESHOLD 
    THEN 'ALERT'
    ELSE 'NORMAL'
    END AS iops_status
FROM
    DBA_HIST_SYSMETRIC_SUMMARY m
JOIN
    DBA_HIST_SNAPSHOT s 
    ON m.snap_id = s.snap_id AND m.dbid = s.dbid
WHERE
    s.dbid = &&thisdb
    -- Filter for the last 60 minutes using the correct TIMESTAMP column
    AND s.begin_interval_time >= SYSDATE - INTERVAL '60' MINUTE
    -- Only include the necessary metrics to avoid unnecessary processing
    AND m.metric_name IN (
        'Physical Read Total Bytes Per Sec',
        'Physical Write Total Bytes Per Sec',
        'Physical Read Total IO Requests Per Sec',
        'Physical Write Total IO Requests Per Sec',
        'Redo Writes Per Sec'
    )
GROUP BY
    s.end_interval_time
ORDER BY
    s.end_interval_time DESC;

-- Optional: To clear the defined substitution variables
UNDEF thisdb
