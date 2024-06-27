CREATE OR REPLACE
PACKAGE BODY "ALERT_FILE"
IS
  -- extracts error messages from the alert file
  -- renames the alert file
  -- extracts all messages from the alert file
  -- calls notification package to send emails
PROCEDURE read_ggserr_log(
    external_tab IN VARCHAR2,
    error_msg_arry OUT notification.msgs,
    error_ignore_arry OUT notification.msgs,
    linecount OUT INTEGER)
IS
  c1 sys_refcursor;
  l_buffer   VARCHAR2(1000);
  l_msg_text VARCHAR2(32767);
  error_count binary_integer        :=0;
  error_ignore_count binary_integer :=0;
  -- local function
FUNCTION is_ignorable(
    p_msg VARCHAR2)
  RETURN BOOLEAN
IS
  CURSOR c
  IS
    SELECT cvalue FROM configs WHERE cname='GGSERR';
  l_alert configs.cvalue%type;
  l_ignorable BOOLEAN :=false;
BEGIN
  OPEN c;
  LOOP
    FETCH c INTO l_alert;
    EXIT
  WHEN c%NOTFOUND;
    IF ( instr(p_msg, l_alert) > 0 ) THEN
      l_ignorable             := true;
      EXIT;
    END IF;
  END LOOP;
  CLOSE c;
  RETURN l_ignorable;
END;
BEGIN
  OPEN c1 FOR 'select msg_line from ' || external_tab;
  FETCH c1 INTO l_buffer;
  WHILE c1%FOUND
  LOOP
    -- save the date line
    l_msg_text := l_buffer;
    -- read the first message body line
    FETCH c1 INTO l_buffer;
   -- dbms_output.put_line('l_buffer :' || l_buffer);
    
    while ( not regexp_like(l_buffer, '^\d{4}\-\d{2}\-\d{2}')  and c1%found)
    LOOP
      l_msg_text := l_msg_text||chr(10)||l_buffer;
      FETCH c1 INTO l_buffer;
    END LOOP;

    -- dbms_output.put_line('before check if error : ' || l_msg_text);

    IF (instr(l_msg_text, 'WARNING OGG-') > 0 ) OR (instr(l_msg_text, 'ERROR   OGG-') > 0 ) THEN
     --  dbms_output.put_line('error msg found, checking if ignorable : ' || l_msg_text);
      IF is_ignorable(l_msg_text) THEN
        error_ignore_count                    := error_ignore_count + 1 ;
        l_msg_text  := TO_CHAR(to_date(SUBSTR(l_msg_text,1,19),'YYYY-MM-DD HH24:MI:SS'), 'Dy Mon dd hh24:mi:ss yyyy') || ' ' ||
          	SUBSTR(l_msg_text,20);
        error_ignore_arry(error_ignore_count) := l_msg_text;
      ELSE
        error_count                 := error_count + 1 ;
        l_msg_text                  := TO_CHAR(to_date(SUBSTR(l_msg_text,1,19),'YYYY-MM-DD HH24:MI:SS'), 'Dy Mon dd hh24:mi:ss yyyy') || ' ' || SUBSTR(l_msg_text,20);
        error_msg_arry(error_count) := l_msg_text;
      END IF;
    END IF;


  END LOOP;
  linecount := c1%ROWCOUNT;
  CLOSE c1;
END read_ggserr_log;

PROCEDURE read_alert_file(
    external_tab IN VARCHAR2,
    error_msg_arry OUT notification.msgs,
    error_ignore_arry OUT notification.msgs,
    linecount OUT INTEGER)
IS
  -- reads the alert file
  -- Save any error messages in an associative arry
  -- error message in the alert file ussually start from a date line
  -- till next date line (excl.),
  -- however for ORA-01555 error msg across two date lines (in 9i, seem in 11 ok )
  c1 sys_refcursor;
  l_buffer   VARCHAR2(1000);
  l_msg_text VARCHAR2(32767);
  error_count binary_integer        :=0;
  error_ignore_count binary_integer :=0;
  date_to_be_skipped BOOLEAN        :=false;
  -- local function to check if a message should be ignore
FUNCTION is_ignorable(
    p_msg VARCHAR2)
  RETURN BOOLEAN
IS
  CURSOR c
  IS
    SELECT cvalue FROM configs WHERE cname='ALERTLOG';
  l_alert configs.cvalue%type;
  l_ignorable BOOLEAN :=false;
BEGIN
  OPEN c;
  LOOP
    FETCH c INTO l_alert;
    EXIT
  WHEN c%NOTFOUND;
    IF ( instr(p_msg, l_alert) > 0 ) THEN
      l_ignorable             := true;
      EXIT;
    END IF;
  END LOOP;
  CLOSE c;
  RETURN l_ignorable;
END;
BEGIN
  OPEN c1 FOR 'select msg_line from ' || NVL(external_tab, 'alert_file_ext');
  FETCH c1 INTO l_buffer;
  --  dbms_output.put_line('read_alert_file called');
  WHILE c1%FOUND
  LOOP
    -- save the date line
    l_msg_text := l_buffer;
    -- read the first message body line
    FETCH c1 INTO l_buffer;
    -- no considertion of ORA-01555
--    debug.f('first message body line: l_buffer:= ' || l_buffer);

    WHILE (l_buffer NOT LIKE '___ ___ __ __:__:__ ____' AND c1%FOUND)
    LOOP
      l_msg_text := l_msg_text||chr(10)||l_buffer;
      FETCH c1 INTO l_buffer;
    END LOOP;
--    debug.f('l_msg_text:= ' || l_msg_text);
    -- check for error
    -- for expected error we ingore and don't want to send alerts
    IF (instr(l_msg_text, 'ORA-') > 0 ) OR (instr(l_msg_text, 'Checkpoint not complete') > 0 ) THEN
      IF is_ignorable(l_msg_text) THEN
        error_ignore_count                    := error_ignore_count + 1 ;
        error_ignore_arry(error_ignore_count) := substr(l_msg_text,1,3999);
      ELSE
        error_count                 := error_count + 1 ;
--	debug.f('length(l_msg_text) :=' || length(l_msg_text) );
        error_msg_arry(error_count) := substr(l_msg_text,1,3999);
      END IF;
    END IF;
  END LOOP;
  linecount := c1%ROWCOUNT;
  debug.f('linecount :=' || linecount);
  CLOSE c1;
END read_alert_file;

PROCEDURE rename_alert_file(
    p_instance_name IN VARCHAR2,
    p_dir VARCHAR2 DEFAULT 'ALERT_DIR' )
AS
  -- It assumes that the alert log is named alert_INSTANCE.log
  -- and renames it to alert_INSANCE_YYMMDDHH24MI.log
  -- alert log located in ALERT_DIR
  alert_file_does_not_exist EXCEPTION;
  pragma exception_init(alert_file_does_not_exist, -292283);
BEGIN
  -- rename the alert_file
  utl_file.frename( 
	        src_location=>p_dir, src_filename=> 'alert_' ||p_instance_name ||'.log', 
	        dest_location=>p_dir, dest_filename =>'alert_'||p_instance_name||'_'|| TO_CHAR(sysdate,'YYMMDDHH24MI') ||'.log',
	       	overwrite => true);
EXCEPTION
WHEN alert_file_does_not_exist THEN
  debug.f('alert_file_does_not_exist');
  raise;
WHEN others then
  debug.f('SQLCODE=' || SQLCODE);
  debug.f('SQLERRM=' || SQLERRM);
  debug.f('Error stack at top level:');
  debug.f(dbms_utility.format_error_backtrace);
  raise;
END;

-- public
PROCEDURE update_skip_count(
    p_external_tab IN VARCHAR2 DEFAULT 'ALERT_FILE_EXT',
    p_count        IN NUMBER DEFAULT 0,
    reset BOOLEAN DEFAULT false)
IS
  -- update access parameters of external table
  i     NUMBER;
  j     NUMBER;
  adj   NUMBER := p_count;
  param VARCHAR2(2000);
  cv sys_refcursor;
BEGIN
  OPEN cv FOR 'select replace(access_parameters,chr(10)) param                  
from   user_external_tables                 
where  table_name = ' || ''''|| p_external_tab || '''';
  LOOP
    FETCH cv INTO param;
    EXIT
  WHEN cv%notfound;
    i := owa_pattern.amatch(param,1,'.*skip',i);
    j := owa_pattern.amatch(param,1,'.*skip \d*');
    --  to reset the count (to zero)
    IF reset THEN
      adj := -1 * to_number(SUBSTR(param,i,j-i));
    END IF;
    EXECUTE immediate 'alter table ' || p_external_tab || ' access parameters ('|| SUBSTR(param,1,i)|| 
	(to_number(SUBSTR(param,i,j-i))+ adj)|| SUBSTR(param,j)||')';
  END LOOP;
  CLOSE cv;
END;
PROCEDURE monitor_alert_file(
    p_external_tab IN VARCHAR2 DEFAULT 'ALERT_FILE_EXT',
    p_dir          IN VARCHAR2 DEFAULT 'ALERT_DIR')
IS
  error_msg_arry notification.msgs;
  error_ignore_arry notification.msgs;
  lcount          INTEGER;
  l_count          INTEGER :=0;
  l_instance_name VARCHAR2(16);
  l_hostname      VARCHAR2(16);
  l_subject_desc  VARCHAR2(100);
  exists_p        BOOLEAN;
  flength         NUMBER;
  bsize           NUMBER;
  l_recip notification.recipients       :=notification.recipients();
  l_recip_group notification.recipients :=notification.recipients();
  alert_file_does_not_exist EXCEPTION;
  pragma exception_init(alert_file_does_not_exist, -29913);
BEGIN
--  l_recip.extend(1);
--  l_recip(1) := 'yu.d.sun@mycompany.com';
--  l_recip_group.extend(1);
--  l_recip_group(1) := 'teamdba.irs@mycompany.com';

 for i in (select cvalue from configs where cname='RECIP')
 loop
   l_recip.extend;
   l_count := l_count + 1;
   l_recip(l_count) := i.cvalue;
  end loop;


  --  l_recip_group(1) := 'teamdba.irs@mycompany.com';
  --  dbms_output.put_line('inside monitor_alert_file');
  SELECT instance_name,
    host_name
  INTO l_instance_name,
    l_hostname
  FROM v$instance;
  -- rename_alert_file(l_instance_name);
  -- monitor the alert file and save errors
  debug.f('before call read_alert_file');
  read_alert_file(p_external_tab, error_msg_arry, error_ignore_arry, lcount);
  debug.f('after call read_alert_file');
  --   dbms_output.put_line('lcount =' || lcount);
  --  update the external tables's access parameters
  update_skip_count(p_external_tab, lcount);
  -- send any error messages
  --   dbms_output.put_line ( 'error_msg_arry.last =' || error_msg_arry.last );
  --   dbms_output.put_line ( 'error_ignore_arry.last =' || error_ignore_arry.last );
  IF error_msg_arry.last > 0 THEN
    l_subject_desc      := 'ALERT LOG ERROR FOUND ' || l_hostname ;
    notification.notify ( instance_name_in =>l_instance_name ,msgs_in => error_msg_arry ,
	subject_in => l_subject_desc ,result_in => NULL ,email_p => true ,db_p => true ,recip => l_recip ,dbaets_p => true );
    -- remote procedure called need to commit for load message to remote table
    COMMIT;
  END IF;
  IF error_ignore_arry.last > 0 THEN
    l_subject_desc         := 'ALERT ERROR INGNORE ' || l_hostname ;
    notification.notify ( instance_name_in =>l_instance_name ,msgs_in => error_ignore_arry ,subject_in => l_subject_desc ,result_in => NULL ,email_p => false ,db_p => true ,recip => l_recip);
  END IF;
  --  rollover the alert file based on filesize
  --  check happened at hours 6-7 everyday
  IF TO_CHAR(sysdate,'hh24') >= '02' AND TO_CHAR(sysdate,'hh24') < '03' THEN
    utl_file.fgetattr ( location => p_dir, filename => 'alert_'||l_instance_name||'.log', fexists => exists_p, file_length => flength, block_size => bsize);
   dbms_output.put_line('flength = ' || flength);
   debug.f('flength = ' || flength);
    -- 500K threshold to rename
    IF flength > 512000 THEN
      dbms_output.put_line('going to rename alert log');
      debug.f('going to rename alert log');
      debug.f('before rename_alert_file l_instance_name = ' || l_instance_name);
      rename_alert_file(l_instance_name, p_dir);
      debug.f('after rename_alert_file');
      notification.save_msg('Size ' || flength || '> 500k rename alert log!', 'HOUSEKEEPING ACTIVITY');
      update_skip_count(p_external_tab, reset=>true);
    END IF;
  END IF;
END monitor_alert_file;
PROCEDURE config_monitor_alert_file(
    p_error  IN VARCHAR2 DEFAULT NULL,
    p_option IN VARCHAR2 DEFAULT 'l')
IS
BEGIN
  IF p_option = 'a' AND p_error IS NOT NULL THEN
    INSERT INTO configs VALUES
      ('ALERTLOG', p_error
      );
    COMMIT;
    dbms_output.put_line(p_error|| ' is added and thus excluded from the monitoring');
  elsif p_option ='r' AND p_error IS NOT NULL THEN
    DELETE
    FROM configs
    WHERE cname='ALERTLOG'
    AND cvalue = p_error;
    COMMIT;
    dbms_output.put_line(p_error || ' is removed and thus included in the monitoring');
  elsif p_option ='l' THEN
    dbms_output.put_line('List Current Configrations' || chr(10) || '--------------------' );
    FOR rec IN
    (SELECT * FROM configs WHERE cname='ALERTLOG'
    )
    LOOP
      dbms_output.put_line('Configration Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    END LOOP;
  END IF;
END config_monitor_alert_file;
PROCEDURE config_monitor_ggserr(
    p_error  IN VARCHAR2 DEFAULT NULL,
    p_option IN VARCHAR2 DEFAULT 'l')
IS
BEGIN
  IF p_option = 'a' AND p_error IS NOT NULL THEN
    INSERT INTO configs VALUES
      ('GGSERR', p_error
      );
    COMMIT;
    dbms_output.put_line(p_error|| ' is added and thus excluded from the monitoring');
  elsif p_option ='r' AND p_error IS NOT NULL THEN
    DELETE
    FROM configs
    WHERE cname='GGSERR'
    AND cvalue = p_error;
    COMMIT;
    dbms_output.put_line(p_error || ' is removed and thus included in the monitoring');
  elsif p_option ='l' THEN
    dbms_output.put_line('List Current Configrations' || chr(10) || '--------------------' );
    FOR rec IN
    (SELECT * FROM configs WHERE cname='GGSERR'
    )
    LOOP
      dbms_output.put_line('Configration Name: '||rec.cname || ' - Value: ' || rec.cvalue);
    END LOOP;
  END IF;
END config_monitor_ggserr;
PROCEDURE monitor_ggserr(
    p_external_tab IN VARCHAR2 DEFAULT 'GGSERR_LOG_EXT',
    p_dir          IN VARCHAR2 DEFAULT 'GGSERR_DIR')
IS
  error_msg_arry notification.msgs;
  error_ignore_arry notification.msgs;
  l_msglog notification.msgs;
  lcount          INTEGER;
  l_count   integer :=0;
  l_instance_name VARCHAR2(16);
  l_hostname      VARCHAR2(16);
  l_subject_desc  VARCHAR2(100);
  exists_p        BOOLEAN;
  flength         NUMBER;
  bsize           NUMBER;
  l_recip notification.recipients       :=notification.recipients();
  l_recip_group notification.recipients :=notification.recipients();
  alert_file_does_not_exist EXCEPTION;
  pragma exception_init(alert_file_does_not_exist, -29913);
BEGIN
--  l_recip.extend(1);
--  l_recip(1) := 'yu.d.sun@mycompany.com';
--  l_recip_group.extend(1);
--   l_recip_group(1) := 'denissun@mycompany.com';
--  l_recip_group(1) := 'teamdba.irs@mycompany.com';
--  dbms_output.put_line('inside monitor_ggserr');

  for i in (select cvalue from configs where cname='RECIP')
  loop
	      l_recip.extend;
	      l_count := l_count + 1;
	      l_recip(l_count) := i.cvalue;
  end loop;



  SELECT instance_name,
    host_name
  INTO l_instance_name,
    l_hostname
  FROM v$instance;
  -- monitor the alert file and save errors
  read_ggserr_log(p_external_tab, error_msg_arry, error_ignore_arry, lcount);
  dbms_output.put_line('lcount =' || lcount);
  --  update the external tables's access parameters
  update_skip_count(p_external_tab, lcount);
  IF error_msg_arry.last > 0 THEN
    l_subject_desc      := 'GGSERR LOG ERROR FOUND ' || l_hostname ;
    notification.notify ( instance_name_in =>l_instance_name ,msgs_in => error_msg_arry , subject_in => l_subject_desc ,result_in => NULL ,email_p => true , db_p => true ,recip => l_recip ,dbaets_p => true );
    -- remote procedure called need to commit for load message to remote table
    COMMIT;
  END IF;
  IF error_ignore_arry.last > 0 THEN
    l_subject_desc         := 'GGSERR ERROR INGNORE ' || l_hostname ;
    notification.notify ( instance_name_in =>l_instance_name ,msgs_in => error_ignore_arry ,subject_in => l_subject_desc ,result_in => NULL ,email_p => false ,db_p => true ,recip => l_recip);
  END IF;
  -- for symplicity change ggserror on the 1st of each month
  -- should have a cron job to change the permission of ggserr.log to 664
  IF TO_CHAR(sysdate,'DDHH24') = '0101' THEN
    utl_file.fgetattr ( location => p_dir, filename => 'ggserr.log', fexists => exists_p, file_length => flength, block_size => bsize);
    dbms_output.put_line('flength = ' || flength);
    -- 500K threshold to rename
    IF flength > 512000 THEN
      dbms_output.put_line('going to rename ggserr log');
      update_skip_count(p_external_tab, reset=>true);
      utl_file.frename( src_location=>p_dir, src_filename=> 'ggserr.log', dest_location=>p_dir, dest_filename =>'ggserr_'|| TO_CHAR(sysdate,'YYMMDDHH24MI') ||'.log', overwrite => true);
    END IF;
  END IF;
END monitor_ggserr;
END;
/
