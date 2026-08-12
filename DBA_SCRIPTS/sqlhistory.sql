/**********************************************************************
 * File:        sqlhistory.sql
 * Type:        SQL*Plus script
 * Author:      Tim Gorman (Evergreen Database Technologies, Inc.)
 * Date:        29sep08
 *
 * Description:
 *    SQL*Plus script to query the "history" of a specified SQL
 *    statement, using its "SQL ID" across all database instances
 *    in a database, using the AWR repository.  This report is useful
 *    for obtaining an hourly perspective on SQL statements seen in
 *    more aggregated reports.
 *
 * Modifications:
 *    Denis     7/9/2026    report reasonable LIO/row  value when return rows close to zero
 *    Denis     7/6/2026    report rows per execution, lio per row and  num of day default 15,
 *    Denis     9/15/2013   improved  SQL_TEXT section
 *    Denis     8/31/2012   Using spool and include db name, sql_id, timestamp in
 *                          the spool file name; added sql text section
 *    ZFriese   8/21/2012   to ease plan comparison,  changed output to show LIO,
 *             PIO, CPU and Elapsed time PER EXEC, rather than TOTALs.
 *    ZFriese   3/8/2012   increased decimals of CPU and elapsed time,
 *                         reduced those of LIO/PIO
 *    ZFriese   6/14/2011   added sqlid to top of report, commented
 *                          out SPOOL and SPOOL OFF
 *    TGorman    29sep08    adapted from the earlier STATSPACK-based
 *            "sphistory.sql" script
 *********************************************************************/
set echo off

-- alter session set cursor_sharing = 'exact'; -- fixes column headings  zfriese 6/5/2012

set feedback off timing off verify off pagesize 100 linesize 165 recsep off
set serveroutput on size 1000000 format wrapped trimout on trimspool on
col phv heading "Plan|Hash Value"
col snap_time format a14 heading "Snapshot|Time"
col execs format 99999,990 heading "Execs"
col lio_per_exec format 999,999,990.0 heading "Avg LIO|Per Exec"
col pio_per_exec format 999,999,990.0 heading "Avg PIO|Per Exec"
col cpu_per_exec format 999,990.000 heading "Avg|CPU secs|Per Exec"
col ela_per_exec format 999,990.000 heading "Avg|Elpsd secs|Per Exec"
col row_per_exec format 999,999,990.0 heading "Avg|Rows Prcsd|Per Exec"
col lio_per_row  format 999,999,990.0 heading "Avg LIO|Per Row"
col sql_text format a64 heading "Text of SQL statement"
clear breaks computes
ttitle off
btitle off

accept V_SQL_ID prompt "Enter the SQL_ID: "
accept V_NBR_DAYS prompt "Enter number of days (backwards from this hour) to report (default: 15): "

variable v_nbr_days number

col iname new_val iname
col curtim new_val curtim

select to_char(sysdate, 'YYMMDDHH24MI') curtim from dual;
select instance_name iname from v$instance;

spool sqlhistory_&iname._&&V_SQL_ID._&curtim..log

Pro  ===  sql text  ===

VAR sql_text CLOB;
EXEC :sql_text := NULL;

SET TERM OFF
-- get sql_text from memory
BEGIN
  IF :sql_text IS NULL THEN
    SELECT REPLACE(sql_fulltext, CHR(00), ' ')
      INTO :sql_text
      FROM gv$sqlarea
     WHERE sql_id = '&&V_SQL_ID'
       AND sql_fulltext IS NOT NULL
       AND ROWNUM = 1;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    :sql_text := NULL;
END;
/

-- get sql_text from awr
BEGIN
  IF :sql_text IS NULL THEN
    SELECT REPLACE(sql_text, CHR(00), ' ')
      INTO :sql_text
      FROM dba_hist_sqltext
     WHERE sql_id = '&&V_SQL_ID'
       AND sql_text IS NOT NULL
       AND ROWNUM = 1;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    :sql_text := NULL;
END;
/

-- breaks long lines
BEGIN
  IF :sql_text IS NOT NULL THEN
    :sql_text := '-- sqlid = ' || '&&V_SQL_ID' || CHR(10) || TRIM(CHR(10) FROM TRIM(:sql_text))||CHR(10);
    :sql_text := REPLACE(:sql_text, ',', CHR(10)||',');
    :sql_text := REPLACE(:sql_text, ' and ', CHR(10)||'and ');
    :sql_text := REPLACE(:sql_text, ' AND ', CHR(10)||'AND ');
    :sql_text := REPLACE(:sql_text, ' or ', CHR(10)||'or ');
    :sql_text := REPLACE(:sql_text, ' OR ', CHR(10)||'OR ');
    :sql_text := REPLACE(:sql_text, 'SELECT ', 'SELECT'||CHR(10));
    :sql_text := REPLACE(:sql_text, 'select ', 'select'||CHR(10));
    :sql_text := REPLACE(:sql_text, ' FROM ', CHR(10)||'FROM'||CHR(10));
    :sql_text := REPLACE(:sql_text, ' from ', CHR(10)||'from'||CHR(10));
    :sql_text := REPLACE(:sql_text, ' WHERE ', CHR(10)||'WHERE'||CHR(10));
    :sql_text := REPLACE(:sql_text, ' where ', CHR(10)||'where'||CHR(10));
    :sql_text := REPLACE(:sql_text, CHR(10)||CHR(10)||CHR(10), CHR(10));
    :sql_text := REPLACE(:sql_text, CHR(10)||CHR(10), CHR(10));
  END IF;
END;
/

set term on
PRINT sql_text;

Pro  === End of sql text  ===
Pro

col sql_text format a64 heading "Text of SQL statement"

declare
    cursor get_phv(in_sql_id in varchar2, in_days in integer)
    is
    select   ss.plan_hash_value,
        min(s.begin_interval_time) min_time,
        max(s.begin_interval_time) max_time,
        min(s.snap_id) min_snap,
        max(s.snap_id) max_snap,
        sum(ss.executions_delta) sum_execs,
        sum(ss.disk_reads_delta) sum_disk_reads,
        sum(ss.buffer_gets_delta) sum_buffer_gets,
        sum(ss.cpu_time_delta)/1000000 sum_cpu_time,
        sum(ss.elapsed_time_delta)/1000000 sum_elapsed_time,
        sum(ss.rows_processed_delta) sum_rows_processed
    from    dba_hist_sqlstat    ss,
            dba_hist_snapshot    s
    where    ss.dbid = s.dbid
    and    ss.instance_number = s.instance_number
    and    ss.snap_id = s.snap_id
    and    ss.sql_id = in_sql_id
    and    ss.executions_delta > 0
    and    s.begin_interval_time >= sysdate-in_days
    group by ss.plan_hash_value
    order by sum_elapsed_time desc;
        --
    cursor get_xplan(in_sql_id in varchar2, in_phv in number)
    is
    select    plan_table_output
    from    table(dbms_xplan.display_awr(in_sql_id, in_phv, null, 'ALL -ALIAS'));
    --
    v_prev_plan_hash_value    number := -1;
    v_text_lines        number := 0;
    v_errcontext        varchar2(100);
    v_errmsg        varchar2(100);
    v_display_sql_text    boolean;
    --
begin
    --
    v_errcontext := 'query NBR_DAYS from DUAL';
    select    decode('&&V_NBR_DAYS','',15,to_number(nvl('&&V_NBR_DAYS','15')))
    into    :v_nbr_days
    from    dual;
    --
    v_errcontext := 'open/fetch get_phv';
    for phv in get_phv('&&V_SQL_ID', :v_nbr_days) loop
        --
        if get_phv%rowcount = 1 then
            --
        dbms_output.put_line('SQLID '||'&&V_SQL_ID');
            dbms_output.put_line('+'||
                rpad('-',12,'-')||
                rpad('-',10,'-')||
                rpad('-',10,'-')||
                rpad('-',12,'-')||
                rpad('-',15,'-')||
                rpad('-',15,'-')||
                rpad('-',12,'-')||
                rpad('-',12,'-')||
                rpad('-',15,'-')||
                rpad('-',15,'-')||'+');
            dbms_output.put_line('|'||
                rpad('Plan HV',12,' ')||
                rpad('Min Snap',10,' ')||
                rpad('Max Snap',10,' ')||
                rpad('Execs',12,' ')||
                rpad('LIO/exec',15,' ')||
                rpad('PIO/exec',15,' ')||
                rpad('CPU/exec',12,' ')||
                rpad('Elpsd/exec',12,' ')||
                rpad('Rows/exec',15,' ')||
                rpad('LIO/Row',15,' ')||'|');
            dbms_output.put_line('+'||
                rpad('-',12,'-')||
                rpad('-',10,'-')||
                rpad('-',10,'-')||
                rpad('-',12,'-')||
                rpad('-',15,'-')||
                rpad('-',15,'-')||
                rpad('-',12,'-')||
                rpad('-',12,'-')||
                rpad('-',15,'-')||
                rpad('-',15,'-')||'+');
            --
        end if;
        --
        dbms_output.put_line('|'||
            rpad(trim(to_char(phv.plan_hash_value)),12,' ')||
            rpad(trim(to_char(phv.min_snap)),10,' ')||
            rpad(trim(to_char(phv.max_snap)),10,' ')||
            rpad(trim(to_char(phv.sum_execs,'999,999,990')),12,' ')||
            rpad(trim(to_char(phv.sum_buffer_gets/phv.sum_execs,'9,999,999,990.0')),15,' ')||
            rpad(trim(to_char(phv.sum_disk_reads/phv.sum_execs,'9,999,999,990.0')),15,' ')||
            rpad(trim(to_char(phv.sum_cpu_time/phv.sum_execs,'999,990.00')),12,' ')||
            rpad(trim(to_char(phv.sum_elapsed_time/phv.sum_execs,'999,990.00')),12,' ')||
            rpad(trim(to_char(phv.sum_rows_processed/phv.sum_execs,'9,999,999,990.0')),15,' ')||
            rpad(trim(to_char(
                case
                  when (phv.sum_rows_processed / phv.sum_execs) <= 1
                  then (phv.sum_buffer_gets / phv.sum_execs)
                  else (phv.sum_buffer_gets / phv.sum_rows_processed)
                end, '9,999,999,990.0')),15,' ')||'|'); -- CHANGED: Floor ratio rule for tiny/sub-1 averages
        --
        v_errcontext := 'fetch/close get_phv';
        --
    end loop;
    dbms_output.put_line('+'||
        rpad('-',12,'-')||
        rpad('-',10,'-')||
        rpad('-',10,'-')||
        rpad('-',12,'-')||
        rpad('-',15,'-')||
        rpad('-',15,'-')||
        rpad('-',12,'-')||
        rpad('-',12,'-')||
        rpad('-',15,'-')||
        rpad('-',15,'-')||'+');
    --
    v_errcontext := 'open/fetch get_phv';
    for phv in get_phv('&&V_SQL_ID', :v_nbr_days) loop
        --
        if v_prev_plan_hash_value <> phv.plan_hash_value then
            --
            v_prev_plan_hash_value := phv.plan_hash_value;
            v_display_sql_text := FALSE;
            --
            v_text_lines := 0;
            v_errcontext := 'open/fetch get_xplan';
            for s in get_xplan('&&V_SQL_ID', phv.plan_hash_value) loop
                --
                if v_text_lines = 0 then
                    dbms_output.put_line('.');
                    dbms_output.put_line('========== PHV = ' ||
                        phv.plan_hash_value ||
                        '==========');
                    dbms_output.put_line('First seen from "'||
                        to_char(phv.min_time,'MM/DD/YY HH24:MI:SS') ||
                        '" (snap #'||phv.min_snap||')');
                    dbms_output.put_line('Last seen from  "'||
                        to_char(phv.max_time,'MM/DD/YY HH24:MI:SS') ||
                        '" (snap #'||phv.max_snap||')');
                    dbms_output.put_line('.');
                    dbms_output.put_line(
                        rpad('Execs',15,' ')||
                        rpad('LIO/exec',15,' ')||
                        rpad('PIO/exec',15,' ')||
                        rpad('CPU/exec',15,' ')||
                        rpad('Elpsd/exec',15,' ')||
                        rpad('Rows/exec',15,' ')||
                        rpad('LIO/Row',15,' '));
                    dbms_output.put_line(
                        rpad('=====',15,' ')||
                        rpad('===',15,' ')||
                        rpad('===',15,' ')||
                        rpad('===',15,' ')||
                        rpad('=======',15,' ')||
                        rpad('=====',15,' ')||
                        rpad('=======',15,' '));
                    dbms_output.put_line(
                        rpad(trim(to_char(phv.sum_execs,'999,999,999,990')),15,' ')||
                        rpad(trim(to_char(phv.sum_buffer_gets/phv.sum_execs,'999,999,999,990')),15,' ')||
                        rpad(trim(to_char(phv.sum_disk_reads/phv.sum_execs,'999,999,999,990')),15,' ')||
                        rpad(trim(to_char(phv.sum_cpu_time/phv.sum_execs,'999,999,990.00')),15,' ')||
                        rpad(trim(to_char(phv.sum_elapsed_time/phv.sum_execs,'999,999,990.00')),15,' ')||
                        rpad(trim(to_char(phv.sum_rows_processed/phv.sum_execs,'999,999,999,990')),15,' ')||
                        rpad(trim(to_char(
                            case
                              when (phv.sum_rows_processed / phv.sum_execs) <= 1
                              then (phv.sum_buffer_gets / phv.sum_execs)
                              else (phv.sum_buffer_gets / phv.sum_rows_processed)
                            end, '999,999,999,990')),15,' ')); -- CHANGED: Floor ratio rule for tiny/sub-1 averages
                    dbms_output.put_line('.');
                end if;
                --
                if v_display_sql_text = FALSE and
                   s.plan_table_output like 'Plan hash value: %' then
                    --
                    v_display_sql_text := TRUE;
                    --
                end if;
                --
                if v_display_sql_text = TRUE then
                    --
                    dbms_output.put_line(s.plan_table_output);
                    --
                end if;
                --
                v_text_lines := v_text_lines + 1;
                --
            end loop;
            --
        end if;
        --
        v_errcontext := 'fetch/close get_phv';
        --
    end loop;
    --
exception
    when others then
        v_errmsg := sqlerrm;
        raise_application_error(-20000, v_errcontext || ': ' || v_errmsg);
end;
/

break on report
compute sum of execs on report
compute avg of lio_per_exec on report
compute avg of pio_per_exec on report
compute avg of cpu_per_exec on report
compute avg of ela_per_exec on report
compute avg of row_per_exec on report
compute avg of lio_per_row on report
ttitle center 'Summary Execution Statistics Over Time'
select    to_char(s.begin_interval_time, 'DD-MON HH24:MI') snap_time,
    ss.executions_delta execs,
    ss.buffer_gets_delta/decode(ss.executions_delta,0,1,ss.executions_delta) lio_per_exec,
    ss.disk_reads_delta/decode(ss.executions_delta,0,1,ss.executions_delta) pio_per_exec,
    (ss.cpu_time_delta/1000000)/decode(ss.executions_delta,0,1,ss.executions_delta) cpu_per_exec,
    (ss.elapsed_time_delta/1000000)/decode(ss.executions_delta,0,1,ss.executions_delta) ela_per_exec,
    ss.rows_processed_delta/decode(ss.executions_delta,0,1,ss.executions_delta) row_per_exec,
    case
      when (ss.rows_processed_delta / decode(ss.executions_delta,0,1,ss.executions_delta)) <= 1
      then (ss.buffer_gets_delta / decode(ss.executions_delta,0,1,ss.executions_delta))
      else (ss.buffer_gets_delta / decode(ss.rows_processed_delta,0,1,ss.rows_processed_delta))
    end lio_per_row -- CHANGED: Explicit SQL Case handling for low execution row targets
from     dba_hist_snapshot    s,
    dba_hist_sqlstat    ss
where    ss.dbid = s.dbid
and    ss.instance_number = s.instance_number
and    ss.snap_id = s.snap_id
and    ss.sql_id = '&&V_SQL_ID'
and    ss.executions_delta > 0
and    s.begin_interval_time >= sysdate - :v_nbr_days
order by s.snap_id;
clear breaks computes

break on phv skip 1 on report
compute sum of execs on phv
compute avg of lio_per_exec on phv
compute avg of pio_per_exec on phv
compute avg of cpu_per_exec on phv
compute avg of ela_per_exec on phv
compute avg of row_per_exec on phv
compute avg of lio_per_row on phv
ttitle center 'Per-Plan Execution Statistics Over Time'
select    ss.plan_hash_value phv,
    to_char(s.begin_interval_time, 'DD-MON HH24:MI') snap_time,
    ss.executions_delta execs,
    ss.buffer_gets_delta/decode(ss.executions_delta,0,1,ss.executions_delta) lio_per_exec,
    ss.disk_reads_delta/decode(ss.executions_delta,0,1,ss.executions_delta) pio_per_exec,
    (ss.cpu_time_delta/1000000)/decode(ss.executions_delta,0,1,ss.executions_delta) cpu_per_exec,
    (ss.elapsed_time_delta/1000000)/decode(ss.executions_delta,0,1,ss.executions_delta) ela_per_exec,
    ss.rows_processed_delta/decode(ss.executions_delta,0,1,ss.executions_delta) row_per_exec,
    case
      when (ss.rows_processed_delta / decode(ss.executions_delta,0,1,ss.executions_delta)) <= 1
      then (ss.buffer_gets_delta / decode(ss.executions_delta,0,1,ss.executions_delta))
      else (ss.buffer_gets_delta / decode(ss.rows_processed_delta,0,1,ss.rows_processed_delta))
    end lio_per_row -- CHANGED: Explicit SQL Case handling for low execution row targets
from     dba_hist_snapshot    s,
    dba_hist_sqlstat    ss
where    ss.dbid = s.dbid
and    ss.instance_number = s.instance_number
and    ss.snap_id = s.snap_id
and    ss.sql_id = '&&V_SQL_ID'
and    ss.executions_delta > 0
and    s.begin_interval_time >= sysdate - :v_nbr_days
order by ss.plan_hash_value, s.snap_id;
clear breaks computes

spool off
ttitle off
set verify on echo on feedback on
set def on
undefine all
