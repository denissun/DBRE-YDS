SET colsep '  ' LINES 133 PAGES 111 autot off feedback on timing on;
break on snap_begin skip 
--
-- awr.active.sessions.txt   - zfriese 3/22/2013 
-- number of active (user) sessions, by AWR snap, instance   
-- RAC-aware - reports by instance
--
COL active_sessions   FORMAT                999.99 HEAD "AAS"
COL i                 FORMAT                     9 HEAD "Inst_ID"
COL snap_begin        FORMAT                   A11  HEAD "SNAP BEGIN"
COL snap_end          FORMAT                    A5  HEAD "END"
--
SELECT /* zfriese */  snap_begin, 
--snap_end,
i, 
active_sessions 
  FROM (  SELECT 
                                     (CASE
                        WHEN sn.begin_interval_time = sn.startup_time
                        THEN
                           VALUE
                        ELSE
                           VALUE
                           - LAG (
                                VALUE,
                                1)
                             OVER (
                                PARTITION BY sy.stat_id,
                                             sy.dbid,
                                             sn.instance_number,
                                             sn.startup_time
                                ORDER BY sy.snap_id)
                     END)
                    / 1000000
                    / ( (CAST (sn.end_interval_time AS DATE)
                         - CAST (sn.begin_interval_time AS DATE))
                       * 24
                       * 3600)          active_sessions,
--               sn.snap_id snap_id,
               sn.instance_number I,                  --  can comment for non-RAC
                 TO_CHAR (sn.begin_interval_time, 'MM/DD HH24:MI') snap_begin,             
                 TO_CHAR (sn.end_interval_time, 'HH24:MI')      snap_end
            FROM dba_hist_snapshot sn, dba_hist_sys_time_model sy
           WHERE     sn.dbid = sy.dbid
                 AND sn.instance_number = sy.instance_number
                 AND sn.snap_id = sy.snap_id
                 AND sy.stat_name = 'DB time'
                 AND sn.end_interval_time > SYSDATE - &DAYS_AGO_START
                 AND sn.end_interval_time < SYSDATE - &DAYS_AGO_STOP
        ORDER BY sn.snap_id, sn.instance_number)
 WHERE active_sessions IS NOT NULL     -- prevents NULL first row
--  AND active_sessions > 0            -- to suppress periods w no activity
order by snap_begin, i
 ;            

