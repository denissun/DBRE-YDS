CREATE OR REPLACE
PACKAGE body proactive
IS
  g_recip notification.recipients :=notification.recipients();
  g_count number :=0;

PROCEDURE check_tablespace(
    P_FREE_MB          NUMBER DEFAULT 10000,
    P_HUGE_SIZE        NUMBER DEFAULT 1000000,
    P_BIG_SIZE         NUMBER DEFAULT 200000,
    P_MEDIUM_SIZE      NUMBER DEFAULT 20000,
    P_THRESHOLD_HUGE   NUMBER DEFAULT 99,
    P_THRESHOLD_BIG    NUMBER DEFAULT 98,
    P_THRESHOLD_MEDIUM NUMBER DEFAULT 93,
    P_THRESHOLD_STD    NUMBER DEFAULT 88 )
IS
  l_excluded_tblspc VARCHAR2(2000);
  l_tsname dba_data_files.tablespace_name%type;
  l_tot_mb        NUMBER;
  l_free_mb       NUMBER;
  l_fullpct       NUMBER;
  l_dynsql        VARCHAR2(4000);
  l_instance_name VARCHAR2(50);
  l_hostname      VARCHAR2(50);
  l_recip notification.recipients :=notification.recipients();
  notes notification.msgs;
  notes_i pls_integer :=0;
  l_msgs VARCHAR2(2000);
  c1 SYS_REFCURSOR;
  -- Check spaced used by tablespaces
  -- alert threshold based on size of tablespac3
BEGIN
  SELECT instance_name,
    host_name
  INTO l_instance_name,
    l_hostname
  FROM v$instance;
  -- excluding some tablespace from monitoring
  l_excluded_tblspc :=q'['UNDOTBS', 'UNDOTBS1']';
  l_dynsql          :=q'[       
select a.tsname          
,round(totbytes/1048576) tot_mb   
,round(freebytes/1048576) free_mb   
,round(100-freebytes*100/totbytes, 1) fullpct      
from          
(select tablespace_name tsname, sum(bytes) totbytes from dba_data_files  group by tablespace_name) a,   
(select tablespace_name tsname,sum(bytes) freebytes from dba_free_space group by tablespace_name) b      
where a.tsname=b.tsname and b.freebytes/1024/1024 < ]' || P_FREE_MB || q'[ and a.tsname not in (select cvalue from configs where cname='TABLESPACE')]';
  OPEN c1 FOR l_dynsql;
  LOOP
    FETCH c1 INTO l_tsname, l_tot_mb, l_free_mb, l_fullpct;
    EXIT
  WHEN c1%notfound;
    IF l_tot_mb > P_HUGE_SIZE AND l_fullpct > P_THRESHOLD_HUGE THEN
      l_msgs   := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)|| 'Huge Tablespace '||l_tsname|| ' is '|| l_fullpct || '% full.' || chr(10) || 'Free space is ' || l_free_mb || ' MB' ;
      -- dbms_output.put_line(l_msgs);
    elsif l_tot_mb > P_BIG_SIZE AND l_fullpct > P_THRESHOLD_BIG THEN
      l_msgs      := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)|| 'BIG Tablespace '||l_tsname|| ' is '|| l_fullpct || '% full.' || chr(10) || 'Free space is ' || l_free_mb || ' MB' ||chr(10) ||'--------' ;
      -- dbms_output.put_line(l_msgs);
    elsif l_tot_mb > P_MEDIUM_SIZE AND l_fullpct > P_THRESHOLD_MEDIUM THEN
      l_msgs      := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)|| 'MEDIUM Tablespace '||l_tsname|| ' is '|| l_fullpct || '% full.' || chr(10) || 'Free space is ' || l_free_mb || ' MB' ||chr(10) ||'--------' ;
      -- dbms_output.put_line(l_msgs);
    elsif l_tot_mb <= P_MEDIUM_SIZE AND l_fullpct > P_THRESHOLD_STD THEN
      l_msgs       := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)|| 'Tablespace '||l_tsname|| ' is '|| l_fullpct || '% full.' || chr(10) || 'Free space is ' || l_free_mb || ' MB' ||chr(10) ||'--------' ;
      -- dbms_output.put_line(l_msgs);
    END IF;
    IF l_msgs        IS NOT NULL THEN
      notes_i        := notes_i +1;
      notes(notes_i) := l_msgs;
      l_msgs         :=NULL;
    END IF;
  END LOOP;
  CLOSE c1;
  IF notes.last > 0 THEN
    notification.notify( instance_name_in => l_instance_name, msgs_in => notes, subject_in => 'STORAGE TBS ' || l_hostname, email_p => true, db_p => true , recip => g_recip, dbaets_p => true);
    COMMIT;
  END IF;
END check_tablespace;
PROCEDURE config_check_tablespace(
    p_tablespace IN VARCHAR2 DEFAULT NULL,
    p_option VARCHAR2 DEFAULT 'l')
IS
  -- add or remove a SQL to or from checking by long_running_sqls
BEGIN
  IF p_option = 'a' AND p_tablespace IS NOT NULL THEN
    INSERT INTO configs VALUES
      ('TABLESPACE', p_tablespace
      );
    COMMIT;
    dbms_output.put_line(p_tablespace|| ' is added and thus excluded from the monitoring');
  elsif p_option ='r' AND p_tablespace IS NOT NULL THEN
    DELETE
    FROM configs
    WHERE cname='TABLESPACE'
    AND cvalue = p_tablespace;
    COMMIT;
    dbms_output.put_line(p_tablespace || ' is removed and thus included in the monitoring');
  elsif p_option ='l' THEN
    dbms_output.put_line('List Current Configuratons' || chr(10) || '--------------------' );
    FOR rec IN
    (SELECT * FROM configs WHERE cname='TABLESPACE'
    )
    LOOP
      dbms_output.put_line('Configuraton Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    END LOOP;
  END IF;
END config_check_tablespace;
PROCEDURE config_long_running_sqls(
    p_sqlid IN VARCHAR2 DEFAULT NULL,
    p_option VARCHAR2 DEFAULT 'l')
IS
  -- add or remove a SQL to or from checking by long_running_sqls
BEGIN
  IF p_option = 'a' AND p_sqlid IS NOT NULL THEN
    INSERT INTO configs VALUES
      ('LONGSQL', p_sqlid
      );
    COMMIT;
    dbms_output.put_line(p_sqlid || ' is added and thus excluded from the monitoring');
  elsif p_option ='r' AND p_sqlid IS NOT NULL THEN
    DELETE
    FROM configs
    WHERE cname='LONGSQL'
    AND cvalue = p_sqlid;
    COMMIT;
    dbms_output.put_line(p_sqlid || ' is removed and thus included in the monitoring');
  elsif p_option ='l' THEN
    dbms_output.put_line('List Current Configuratons' || chr(10) || '--------------------' );
    FOR rec IN
    (SELECT * FROM configs WHERE cname='LONGSQL'
    )
    LOOP
      dbms_output.put_line('Configuraton Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    END LOOP;
  END IF;
END config_long_running_sqls;
PROCEDURE long_running_sqls(
    p_running_secs IN NUMBER DEFAULT 300)
IS
  CURSOR longsql_cur
  IS
    SELECT inst_id,
      username,
      sid,
      serial#,
      sql_id,
      machine,
      status,
      event,
      last_call_et ela_sec,
      ROUND(last_call_et/60) ela_min
    FROM gv$session
    WHERE username  IS NOT NULL
    AND sql_id      IS NOT NULL
    AND status       ='ACTIVE'
    AND last_call_et > p_running_secs
    AND sql_id NOT  IN
      ( SELECT cvalue FROM configs WHERE cname='LONGSQL'
      )
    and username not in ( select cvalue from configs where cname = 'LONGSQL - Schema') 
  ORDER BY inst_id,
    last_call_et;
  notes notification.msgs;
  i pls_integer :=0;
  l_msgs          VARCHAR2(2000);
  l_instance_name VARCHAR2(50);
  l_hostname      VARCHAR2(50);
BEGIN
  SELECT instance_name,
    host_name
  INTO l_instance_name,
    l_hostname
  FROM v$instance;
  FOR longsql_rec IN longsql_cur
  LOOP
    l_msgs   := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)|| 'INST_ID=' || longsql_rec.inst_id || ' SID=' ||longsql_rec.sid || ' SERIAL#=' || longsql_rec.serial# || chr(10) || 'USERANME=' || longsql_rec.username || ' MACHINE=' || longsql_rec.machine || chr(10) || 'SQL_ID='||longsql_rec.sql_id || chr(10) || 'EVENT=' || longsql_rec.event || chr(10) || 'ELA_MIN=' || longsql_rec.ela_min ||' mins' || chr(10) || '-----------------------------------';
    i        := i + 1;
    notes(i) := l_msgs;
    --        dbms_output.put_line(l_msgs);
  END LOOP;
  IF notes.last > 0 THEN
    notification.notify(instance_name_in => l_instance_name, msgs_in => notes, subject_in => 'LONG RUNNING SQLS ' || l_hostname, email_p => true, db_p => true , recip=> g_recip );
  END IF;
END long_running_sqls;

PROCEDURE sql_total_gets(
    p_total_gets IN NUMBER DEFAULT 2000000)
IS
  -- find top 10 sqls during the most recent snapshot intervals
  -- that have Total Buffer Gets above the threshold
  l_bid   NUMBER;
  l_eid   NUMBER;
  l_btime DATE;
  l_etime DATE;
  notes notification.msgs;
  i pls_integer :=0;
  l_msgs          VARCHAR2(4000);
  l_instance_name VARCHAR2(50);
  l_hostname      VARCHAR2(50);
  l_nrows number;
  CURSOR sql_cur (bid_in NUMBER, eid_in NUMBER)
  IS
    SELECT inst ,
      sql_id ,
      PARSING_SCHEMA_NAME ,
      elapse ,
      cpu ,
      IO ,
      DiskR ,
      bufgets ,
      BG_exec ,
      sort ,
      ftch ,
      nrows ,
      execs ,
      SQL
    FROM
      (SELECT *
      FROM
        (SELECT instance_number inst,
          sql_id,
          PARSING_SCHEMA_NAME,
          SUM(elapsed_time_delta) elapse,
          SUM(cpu_time_delta) cpu,
          SUM(iowait_delta) IO,
          SUM(disk_reads_delta) DiskR,
          SUM(buffer_gets_delta) bufgets,
          ROUND(SUM(buffer_gets_delta)/SUM(executions_delta)) BG_exec,
          SUM(sorts_delta) sort,
          SUM(fetches_delta) ftch,
          SUM(ROWS_PROCESSED_DELTA) nrows,
          SUM(executions_delta) execs,
          (SELECT sql_text FROM dba_hist_sqltext t WHERE t.sql_id = s.sql_id and rownum=1 
          ) SQL
      FROM dba_hist_sqlstat s
      WHERE snap_id   > bid_in
      AND snap_id    <= eid_in
      AND sql_id NOT IN
        (SELECT cvalue FROM configs WHERE cname='SQL Total Gets'
        )
      and PARSING_SCHEMA_NAME not in ( select cvalue from configs where cname='SQL Total Gets - Schema') 
      GROUP BY instance_number,
        sql_id,
        PARSING_SCHEMA_NAME
      HAVING SUM(executions_delta) > 0
      ORDER BY bufgets DESC
        )
      WHERE bufgets> p_total_gets
      )
    WHERE rownum <= 10 ;
    sql_rec sql_cur%rowtype;
  BEGIN
    SELECT instance_name,
      host_name
    INTO l_instance_name,
      l_hostname
    FROM v$instance;
    SELECT MAX(snap_id)
    INTO l_eid
    FROM dba_hist_snapshot
    WHERE TRUNC(END_INTERVAL_TIME,'MI') <= sysdate;
    SELECT MAX(snap_id) INTO l_bid FROM dba_hist_snapshot WHERE snap_id < l_eid;
    -- for rac same snap_id will have several times due to multiple instances
    SELECT MAX(end_interval_time)
    INTO l_btime
    FROM dba_hist_snapshot
    WHERE snap_id = l_bid;
    SELECT MAX(end_interval_time)
    INTO l_etime
    FROM dba_hist_snapshot
    WHERE snap_id = l_eid;
    dbms_output.put_line(l_bid || ' ' || l_eid);
    dbms_output.put_line(l_btime || ' - ' || l_etime);
    OPEN sql_cur(l_bid, l_eid);
    LOOP
      FETCH sql_cur INTO sql_rec;
      EXIT
    WHEN sql_cur%notfound;
      if sql_rec.nrows =0
      then 
	   l_nrows :=1;
      else
	l_nrows := sql_rec.nrows;
      end if;
      l_msgs   := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)||
      'SNAPSHOT INTERVAL: ' || TO_CHAR(l_btime, 'YYYY-Mon-DD HH24:MI') || ' - ' || TO_CHAR(l_etime, 'HH24:MI') || chr(10) || 
      'Threshold: ' || p_total_gets  || chr(10) || 
      'INST_ID          : ' || sql_rec.inst || chr(10) || 'SQL_ID           : ' 
|| sql_rec.sql_id || chr(10) || 'BUFFER GETS TOTAL: ' || sql_rec.bufgets || chr(10) || 'EXECUTIONS       : ' || 
sql_rec.execs || chr(10) || 'GETS/EXECS       : ' || sql_rec.bg_exec || chr(10) || 'GETS/ROW         : ' || 
ROUND(sql_rec.bufgets/l_nrows) || chr(10) || 'PARSING_SCHEMA:    ' || sql_rec.PARSING_SCHEMA_NAME || chr(10) || 'SQL TEXT:          ' || chr(10) ||'         '||SUBSTR(sql_rec."SQL",1,2500) || chr(10) || '---------------------------';


     i   := i                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       + 1; 
notes(i) := l_msgs; --    dbms_output.put_line(l_msgs);
    END LOOP;
    CLOSE sql_cur;
    IF notes.last > 0 THEN
      notification.notify(instance_name_in => l_instance_name, msgs_in => notes, subject_in => 'SQL TOTAL GETS ' || l_hostname, email_p => true, db_p => true , recip=> g_recip, dbaets_p => true );
      COMMIT;
    END IF;
  END sql_total_gets;
PROCEDURE config_sql_total_gets(
    p_sqlid IN VARCHAR2 DEFAULT NULL,
    p_option VARCHAR2 DEFAULT 'l')
IS
  -- add or remove a SQL to or from checking by long_running_sqls
BEGIN
  IF p_option = 'a' AND p_sqlid IS NOT NULL THEN
    INSERT INTO configs VALUES
      ('SQL Total Gets', p_sqlid
      );
    COMMIT;
    dbms_output.put_line(p_sqlid || ' is added and thus excluded from the monitoring');
  elsif p_option ='r' AND p_sqlid IS NOT NULL THEN
    DELETE
    FROM configs
    WHERE cname='SQL Total Gets'
    AND cvalue = p_sqlid;
    COMMIT;
    dbms_output.put_line(p_sqlid || ' is removed and thus included in the monitoring');
  elsif p_option ='l' THEN
    dbms_output.put_line('List Current Configuratons' || chr(10) || '--------------------' );
    FOR rec IN
    (SELECT * FROM configs WHERE cname='SQL Total Gets'
    )
    LOOP
      dbms_output.put_line('Configuraton Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    END LOOP;
  END IF;
END config_sql_total_gets;


PROCEDURE check_blockers(
    p_mins NUMBER DEFAULT 1)
IS
  notes notification.msgs;
  CURSOR lock_cur
  IS
    SELECT INST_ID,
      SID,
      serial#,
      username,
      "TYPE",
      lockheld,
      REQUEST,
      timeheld ,
      block,
      blocking_instance,
      blocking_session,
      sql_id
    FROM
      (SELECT l.INST_ID,
        l.SID,
        s.serial#,
        s.username,
        l.TYPE,
        DECODE(l.lmode,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share',5,'S/Row-X',6,'Exclusive') lockheld,
        DECODE(REQUEST,0,'None',1,'Null',2,'Row-S',3,'Row-X',4,'Share', 5,'S/ROW',6,'Exclusive') REQUEST,
        ROUND(CTIME/60) timeheld ,
        DECODE(l.BLOCK,0,'No',1, 'Yes', 2, 'Yes') block,
        s.blocking_instance,
        s.blocking_session,
        s.sql_id
      FROM gv$lock l,
        gv$session s
      WHERE (l.ID1,l.ID2,l.TYPE) IN
        (SELECT ID1,ID2,TYPE FROM gv$lock WHERE request>0
        )
    AND l.sid    =s.sid
    AND l.inst_id=s.inst_id
    ORDER BY l.id1,
      l.lmode DESC,
      l.ctime DESC
      )
    WHERE timeheld         >= p_mins;
    v_count         NUMBER         :=0;
    l_msg           VARCHAR2(4000) :=NULL;
    l_instance_name VARCHAR2(50);
    l_hostname      VARCHAR2(50);
  BEGIN
    SELECT instance_name,
      host_name
    INTO l_instance_name,
      l_hostname
    FROM v$instance;
    FOR lock_rec IN lock_cur
    LOOP
      IF v_count=0 THEN
        l_msg  :=TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy') || chr(10);
        l_msg  := l_msg || '<pre>' || chr(10);
        l_msg  := l_msg || 'INST  SID  SERIAL# USERNAME    TYPE Lockheld timeheld REQUEST  block blk_inst blck_sess  sql_id' ||chr(10);
        l_msg  := l_msg ||'----  ---  ------  --------    ---- -------- -------- -------  ----- --------- --------   ------' || chr(10);
      END IF;
      l_msg   := l_msg || lpad(lock_rec.INST_ID,4) || ' ' || lpad(lock_rec.SID, 5) || ' ' || lpad(lock_rec.serial#,6) || ' ' || rpad(lock_rec.username,12) || ' ' || lpad(lock_rec."TYPE", 4 ) || ' ' || rpad(lock_rec.lockheld,8) || ' ' || lpad(lock_rec.timeheld, 8) || ' ' || rpad(lock_rec.REQUEST,7) || ' ' || lpad(lock_rec.block,5) || ' ' || lpad(lock_rec.blocking_instance,8) || ' ' || lpad(lock_rec.blocking_session, 7) || ' ' || lpad(lock_rec.sql_id, 14) || chr(10);
      v_count := v_count + 1;
      -- don't want to message body to long
      IF v_count > 200 THEN
        EXIT;
      END IF;
    END LOOP;
    IF l_msg   IS NOT NULL THEN
      l_msg    := l_msg || '</pre>' || chr(10);
      notes(1) := l_msg;
      notification.notify(instance_name_in => l_instance_name, msgs_in => notes, subject_in => 'Dangerous BLOCKERS found ' || l_hostname, email_p => true, db_p => true , recip=> g_recip,dbaets_p=> true );
      COMMIT;
    END IF;
  END check_blockers;


PROCEDURE check_waitevent(
    p_percent IN NUMBER DEFAULT 15,
    p_mins    IN NUMBER DEFAULT 15 )
IS
  ser NUMBER :=0;
  l_msg varchar2(4000);
  notes notification.msgs;
  ni  number :=0; 
  l_instance_name VARCHAR2(50);
  l_hostname      VARCHAR2(50);
  
  CURSOR cur_we
  IS
    SELECT inst_id ,
      event ,
      wait_class ,
      ROUND(evttot*100/tot,2) pct_wait ,
      tot ,
      snap_start ,
      snap_end
    FROM
      (SELECT inst_id,
        DECODE(event,NULL,'CPU+Wait for CPU',event) event,
        DECODE(wait_class,NULL,'CPU',wait_class) wait_class,
        evttot,
        tot,
        TO_CHAR( mint, 'MM/DD/YY HH24:MI:SS') snap_start,
        TO_CHAR( maxt, 'MM/DD/YY HH24:MI:SS') snap_end,
        row_number() over (partition BY inst_id order by evttot DESC) rn
      FROM
        ( SELECT DISTINCT inst_id,
          event,
          wait_class,
          COUNT(*) over (partition BY inst_id,event) evttot,
          COUNT(*) over () tot,
          MIN(sample_time) over () mint,
          MAX(sample_time) over () maxt
        FROM gv$active_session_history
        WHERE sample_time >= sysdate - p_mins/1440
        AND sample_time   <= sysdate
        )
	where tot > 100
      )
    WHERE rn <=5
    AND NOT EXISTS
      ( SELECT 1 FROM configs c WHERE c.cname='Wait Event' AND c.cvalue=event
      );
    -- local function
  FUNCTION isBadWait(
      p_event   IN VARCHAR2,
      p_class   IN VARCHAR2,
      p_inst_id IN NUMBER,
      p_pct     IN NUMBER,
      p_pct_i   IN NUMBER)
    RETURN NUMBER
  AS
  BEGIN
    -- ignore those events contributing less than certain pecentage of activity
    IF p_pct < p_pct_i THEN
      RETURN 0;
    elsif ( p_class = 'Concurrency' OR p_event LIKE 'enq%' OR p_event LIKE 'latch%' ) THEN
      RETURN 1;
    ELSE
      RETURN 2;
    END IF;
  END isBadWait;
FUNCTION getInstanceName(
    i IN NUMBER)
  RETURN VARCHAR2
AS
  l_instance_name VARCHAR2(64);
BEGIN
  SELECT instance_name INTO l_instance_name FROM gv$instance WHERE inst_id=i;
  RETURN l_instance_name;
END getInstanceName;
BEGIN
  SELECT instance_name,
    host_name
  INTO l_instance_name,
    l_hostname
  FROM v$instance;

  FOR i IN cur_we
  LOOP
    ser     := isBadWait(i.event,i.wait_class, i.inst_id, i.pct_wait, p_percent);
    IF ( ser > 0 ) THEN
      l_msg  :=TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy') || chr(10);
      l_msg := l_msg || 'ALERT ! - Possible Abnormal Wait Event !  Ser-' || ser || chr(10);
      l_msg := l_msg || 'Instance :' || getInstanceName(i.inst_id) || '  inst_id : ' || i.inst_id || chr(10);
      l_msg := l_msg || 'Event :' || i.event || chr(10);
      l_msg := l_msg || 'Wait Class :' || i.wait_class  || chr(10) ||
                        'pct_wait :' || i.pct_wait || chr(10) ||
                        'Total Waits :' || i.tot || chr(10) ||
                        'From :' || i.snap_start || ' To :' ||i.snap_end || chr(10) ||
                        '---------------------------------------';
     ni :=ni +1;
     notes(ni) := l_msg;
    --  dbms_output.put_line(notes(ni));
    END IF;
  END LOOP;
  IF notes.last > 0 THEN
   notification.notify( instance_name_in => l_instance_name, 
	             msgs_in => notes, 
		     subject_in => 'Possible Abnormal Wait above ' || p_percent || '% ' || l_hostname, 
		     email_p => true,
		     db_p => true , recip => g_recip, dbaets_p => true);
   COMMIT;
  END IF;


END check_waitevent;

PROCEDURE config_waitevent(
    p_event IN VARCHAR2 DEFAULT NULL,
    p_option VARCHAR2 DEFAULT 'l')
IS
BEGIN
  IF p_option = 'a' AND p_event IS NOT NULL THEN
    INSERT INTO configs VALUES
      ('Wait Event', p_event
      );
    COMMIT;
    dbms_output.put_line(p_event || ' is added and thus excluded from the monitoring');
  elsif p_option ='r' AND p_event IS NOT NULL THEN
    DELETE
    FROM configs
    WHERE cname='Wait Event'
    AND cvalue = p_event;
    COMMIT;
    dbms_output.put_line(p_event || ' is removed and thus included in the monitoring');
  elsif p_option ='l' THEN
    dbms_output.put_line('List Current Configuratons' || chr(10) || '--------------------' );
    FOR rec IN
    (SELECT * FROM configs WHERE cname='Wait Event'
    )
    LOOP
      dbms_output.put_line('Configuraton Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    END LOOP;
  END IF;
  NULL;
END config_waitevent;

PROCEDURE config(
	    p_cname  in varchar default null,
	    p_cvalue in varchar default null,
	    p_option VARCHAR2 DEFAULT 'l')
is
begin
  IF p_option = 'l' THEN
    FOR rec IN
    (SELECT * FROM configs WHERE cname=nvl(p_cname, cname) 
    )
    loop 
      dbms_output.put_line('Configuraton Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    end loop;
  elsif p_option ='a'  and  p_cname is not null and p_cvalue is not null THEN
    INSERT INTO configs VALUES(p_cname, p_cvalue);
    commit;
  elsif p_option ='r' and  p_cname is not null and p_cvalue is not null THEN
    delete from configs where cname=p_cname and cvalue=p_cvalue;	
    commit;
  else
      dbms_output.put_line('Invalid parameters ' );
  end if; 
end config;


PROCEDURE  gg_latency_alert(p_mins in number  default 5, p_latency_tab varchar2 default 'GG_LATENCY')
is
   v_extr varchar2(10);
   v_pump varchar2(10);
   v_repl varchar2(10);
   v_utime date;
   v_mins number;
   c sys_refcursor;
   notes notification.msgs;
   i number :=0;
   l_msg           VARCHAR2(4000) :=NULL;
   l_instance_name VARCHAR2(50);
   l_hostname      VARCHAR2(50);

begin
	SELECT instance_name,
	  host_name
	INTO l_instance_name,
	  l_hostname
	FROM v$instance;


  open c for  'select extr, pump, repl, update_time,
        round((sysdate - update_time) *24*60) latency_mins from ' ||  p_latency_tab;

  loop
    fetch c into v_extr, v_pump, v_repl,v_utime, v_mins;
    exit when c%notfound;
    if v_mins >= p_mins  
    then
	i := i +1;
	notes(i) := TO_CHAR(v_utime,'Dy Mon dd hh24:mi:ss yyyy')||chr(10)|| v_extr || ' --> ' || v_pump || ' --> ' || v_repl || chr(10) 
            	|| 'Latency: ' || v_mins || ' mins' || chr(10) || '------------------------';
    end if;
  end loop;
  close c;

  IF notes.last > 0 THEN
   notification.notify( instance_name_in => l_instance_name, 
	             msgs_in => notes, 
		     subject_in => 'GG Latency more than ' || p_mins || ' mins ' || l_hostname, 
		     email_p => true,
		     db_p => true , recip => g_recip, dbaets_p => true);
   COMMIT;
  END IF;

end gg_latency_alert;


-- package body initialization
BEGIN
  for i in (select cvalue from configs where cname='RECIP')
  loop
      g_recip.extend;
      g_count := g_count + 1;
      g_recip(g_count) := i.cvalue;
--      dbms_output.put_line(g_recip(g_count));
   end loop;		 
END;
/
