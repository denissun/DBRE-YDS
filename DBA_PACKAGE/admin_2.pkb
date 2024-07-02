CREATE OR REPLACE
PACKAGE body admin
IS
 --- private section ----------------------------------------
g_awr_filename VARCHAR2(50);
g_awrdiff_filename VARCHAR2(100);


PROCEDURE awrdiff_report(
	   p_dir       IN VARCHAR2, 
	   p_filename  IN VARCHAR2,
  	   p_dbid1     IN NUMBER,
	   p_inst_num1 IN NUMBER,
	   p_bid1      IN NUMBER,
	   p_eid1      IN NUMBER,
	   p_dbid2     IN NUMBER,
	   p_inst_num2 IN NUMBER,
	   p_bid2      IN NUMBER,
	   p_eid2      IN NUMBER)
is
  v_file UTL_FILE.file_type;
begin
    v_file          := UTL_FILE.fopen(p_dir, p_filename, 'w', 32767);
    FOR c_report IN
    (SELECT output
    FROM TABLE(dbms_workload_repository.awr_diff_report_html(
  	   p_dbid1     ,
	   p_inst_num1 ,
	   p_bid1      ,
	   p_eid1      ,
	   p_dbid2     ,
	   p_inst_num2 ,
	   p_bid2      ,
	   p_eid2      ))
    )
    LOOP
      UTL_FILE.PUT_LINE(v_file, c_report.output);
    END LOOP;
    UTL_FILE.fclose(v_file);
    dbms_output.put_line (p_filename || ' is generated at Oracle Directory: ' || p_dir);
    g_awrdiff_filename := p_filename ;
end awrdiff_report;


PROCEDURE awr_report(
    p_dir      VARCHAR2,
    p_filename VARCHAR2,
    p_inst_num NUMBER,
    p_dbid     NUMBER,
    p_type     VARCHAR2,
    p_begin    NUMBER,
    p_end      NUMBER,
    p_options  NUMBER)
IS
  v_file UTL_FILE.file_type;
  v_filename_full VARCHAR2(50);
BEGIN
  IF p_type          = 'HTML' THEN
    v_filename_full := p_filename || '.html';
    v_file          := UTL_FILE.fopen(p_dir, v_filename_full , 'w', 32767);
    FOR c_report IN
    (SELECT output
    FROM TABLE(dbms_workload_repository.awr_report_html( p_dbid, p_inst_num, p_begin, p_end, p_options ))
    )
    LOOP
      UTL_FILE.PUT_LINE(v_file, c_report.output);
    END LOOP;
  ELSE
    v_filename_full := p_filename || '.txt';
    v_file          := UTL_FILE.fopen(p_dir, v_filename_full, 'w', 32767);
    FOR c_report IN
    (SELECT output
    FROM TABLE(dbms_workload_repository.awr_report_text( p_dbid, p_inst_num, p_begin, p_end, p_options ))
    )
    LOOP
      UTL_FILE.PUT_LINE(v_file, c_report.output);
    END LOOP;
  END IF;
  UTL_FILE.fclose(v_file);
  dbms_output.put_line (v_filename_full || ' is generated at Oracle Directory:' || p_dir);
  g_awr_filename := v_filename_full;
END awr_report;

-------  public section ---------------------------

PROCEDURE print_table(
    p_query    IN VARCHAR2,
    p_date_fmt IN VARCHAR2 DEFAULT 'dd-mon-yyyy hh24:mi:ss' )
  -- from Tom Kyte
  --
IS
  l_theCursor   INTEGER DEFAULT dbms_sql.open_cursor;
  l_columnValue VARCHAR2(4000);
  l_status      INTEGER;
  l_descTbl dbms_sql.desc_tab;
  l_colCnt   NUMBER;
  l_cs       VARCHAR2(255);
  l_date_fmt VARCHAR2(255);
  -- Small inline procedure to restore the session's state.
  -- We may have modified the cursor sharing and nls date format
  -- session variables. This just restores them.
PROCEDURE restore
IS
BEGIN
  IF ( upper(l_cs) NOT IN ( 'FORCE','SIMILAR' )) THEN
    EXECUTE immediate 'alter session set cursor_sharing=exact';
  END IF;
  IF ( p_date_fmt IS NOT NULL ) THEN
    EXECUTE immediate 'alter session set nls_date_format=''' || l_date_fmt || '''';
  END IF;
  dbms_sql.close_cursor(l_theCursor);
END restore;
BEGIN
  -- I like to see the dates print out with times, by default. The
  -- format mask I use includes that.  In order to be "friendly"
  -- we save the current session's date format and then use
  -- the one with the date and time.  Passing in NULL will cause
  -- this routine just to use the current date format.
  IF ( p_date_fmt IS NOT NULL ) THEN
    SELECT sys_context( 'userenv', 'nls_date_format' )
    INTO l_date_fmt
    FROM dual;
    EXECUTE immediate 'alter session set nls_date_format=''' || p_date_fmt || '''';
  END IF;
  -- To be bind variable friendly on ad-hoc queries, we
  -- look to see if cursor sharing is already set to FORCE or
  -- similar. If not, set it to force so when we parse literals
  -- are replaced with binds.
  IF ( dbms_utility.get_parameter_value ( 'cursor_sharing', l_status, l_cs ) = 1 ) THEN
    IF ( upper(l_cs) NOT IN ('FORCE','SIMILAR')) THEN
      EXECUTE immediate 'alter session set cursor_sharing=force';
    END IF;
  END IF;
  -- Parse and describe the query sent to us.  We need
  -- to know the number of columns and their names.
  dbms_sql.parse( l_theCursor, p_query, dbms_sql.native );
  dbms_sql.describe_columns ( l_theCursor, l_colCnt, l_descTbl );
  -- Define all columns to be cast to varchar2s. We
  -- are just printing them out.
  FOR i IN 1 .. l_colCnt
  LOOP
    dbms_sql.define_column (l_theCursor, i, l_columnValue, 4000);
  END LOOP;
  -- Execute the query, so we can fetch.
  l_status := dbms_sql.execute(l_theCursor);
  -- Loop and print out each column on a separate line.
  -- Bear in mind that dbms_output prints only 255 characters/line
  -- so we'll see only the first 200 characters by my design...
  WHILE ( dbms_sql.fetch_rows(l_theCursor) > 0 )
  LOOP
    FOR i IN 1 .. l_colCnt
    LOOP
      dbms_sql.column_value ( l_theCursor, i, l_columnValue );
      dbms_output.put_line ( rpad( l_descTbl(i).col_name, 30 ) || ': ' || SUBSTR( l_columnValue, 1, 200 ) );
    END LOOP;
    dbms_output.put_line( '-----------------' );
  END LOOP;
  -- Now, restore the session state, no matter what.
  restore;
EXCEPTION
WHEN OTHERS THEN
  restore;
  raise;
END print_table;
FUNCTION db_version
  RETURN VARCHAR2
IS
  lv_version VARCHAR2(100) :='';
  lv_compat  VARCHAR2(100) :='';
BEGIN
  dbms_utility.db_version(lv_version, lv_compat);
  RETURN lv_version;
END;
FUNCTION my_version
  RETURN VARCHAR2
IS
  my_version VARCHAR2(100) :='ADMIN PAKCAGE VERSION 1.3 by Denis';
BEGIN
  RETURN my_version;
END;
-- public
PROCEDURE kill_session(
    sid_in    IN NUMBER ,
    serial_in IN NUMBER)
IS
BEGIN
  EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION '''|| sid_in || ',' || serial_in || '''';
END kill_session;
PROCEDURE kill_rac_session(
    sid_in     IN NUMBER,
    serial_in  IN NUMBER,
    inst_id_in IN INTEGER )
IS
  l_version NUMBER;
  l_sqlstmt VARCHAR2(100);
BEGIN
  --  dbms_output.put_line('DB Version :' || db_version);
  l_version    := to_number(SUBSTR(db_version, 1,2));
  IF l_version <= 10 THEN
    dbms_output.put_line('DB Version must be 11g or above to use this procedure ');
  ELSE
    l_sqlstmt := 'ALTER SYSTEM KILL SESSION '''|| sid_in || ',' || serial_in || ',@'|| inst_id_in || '''';
    --    dbms_output.put_line('SQL to be executed: ' || l_sqlstmt );
    EXECUTE IMMEDIATE l_sqlstmt;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Error in  kill_rac_session ...');
  dbms_output.put_line(DBMS_UTILITY.format_error_backtrace);
END kill_rac_session;
PROCEDURE kill_sessions(
    p_username IN VARCHAR2,
    p_machine  IN VARCHAR2 DEFAULT NULL,
    p_event    IN VARCHAR2 DEFAULT NULL,
    p_sqlid    IN VARCHAR2 DEFAULT NULL)
IS
BEGIN
  FOR x IN
  (SELECT s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.event,
    s.machine
  FROM v$session s
  WHERE username=upper(p_username)
  AND sql_id    =NVL(p_sqlid, sql_id)
  AND event     = NVL(p_event, event)
  AND machine   = NVL(p_machine, machine)
  )
  LOOP
    kill_session(x.sid, x.serial#);
    dbms_output.put_line ('--- The following session has been killed ...');
    dbms_output.put_line ('sid-serial# : ' || x.sid || ' - ' || x.serial# );
    dbms_output.put_line ('username    : ' || x.username );
    dbms_output.put_line ('machine     : ' || x.machine);
    dbms_output.put_line ('event       : ' || x.event);
    dbms_output.put_line ('sql_id      : ' || x.sql_id);
  END LOOP;
END kill_sessions;
PROCEDURE kill_rac_sessions(
    p_username IN VARCHAR2,
    p_machine  IN VARCHAR2 DEFAULT NULL,
    p_event    IN VARCHAR2 DEFAULT NULL,
    p_sqlid    IN VARCHAR2 DEFAULT NULL,
    p_inst_id  IN INTEGER DEFAULT 1 )
IS
BEGIN
  FOR x IN
  (SELECT s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.event,
    s.machine
  FROM gv$session s
  WHERE username=upper(p_username)
  AND sql_id    =NVL(p_sqlid, sql_id)
  AND event     = NVL(p_event, event)
  AND machine   = NVL(p_machine, machine)
  AND s.inst_id =(
    CASE p_inst_id
      WHEN 0
      THEN s.inst_id
      ELSE p_inst_id
    END)
  )
  LOOP
    kill_rac_session(x.sid, x.serial#, x.inst_id);
    dbms_output.put_line ('--- The following session has been killed ...');
    dbms_output.put_line ('instance    : ' || x.inst_id );
    dbms_output.put_line ('sid-serial# : ' || x.sid || ' - ' || x.serial# );
    dbms_output.put_line ('username    : ' || x.username );
    dbms_output.put_line ('machine     : ' || x.machine);
    dbms_output.put_line ('event       : ' || x.event);
    dbms_output.put_line ('sql_id      : ' || x.sql_id);
  END LOOP;
END kill_rac_sessions;

PROCEDURE impdp_table_network_sqlfile(p_schema in varchar2, p_tablename in varchar2, p_network_link in varchar2)
is
-- impdp a table through network link
-- does not work
  l_dp_handle       NUMBER;
  l_last_job_state  VARCHAR2(30) := 'UNDEFINED';
  l_job_state       VARCHAR2(30) := 'UNDEFINED';
  l_sts             KU$_STATUS;
BEGIN
   if p_network_link is null
   then
     dbms_output.put_line('Network link is null !');
   end if;

      l_dp_handle := DBMS_DATAPUMP.open(
		    operation   => 'IMPORT',
		    job_mode    => 'TABLE',
		    remote_link => p_network_link,
		    job_name    =>  'imp_'|| to_char(sysdate, 'HH24MI_') || p_tablename,
		    version     => 'LATEST');

	DBMS_DATAPUMP.METADATA_FILTER( 
		   handle    => l_dp_handle,
		   name      => 'SCHEMA_EXPR',
		   value     =>  '=' || '''' ||p_schema || '''',
		   object_path  =>NULL);


	DBMS_DATAPUMP.METADATA_FILTER( 
		   handle    => l_dp_handle,
		   name      => 'NAME_EXPR',
		   value     =>  '= '|| '''' || p_tablename || '''',
		   object_path  =>NULL);


        DBMS_DATAPUMP.add_file(
 	    handle    => l_dp_handle,
	    filename  => p_tablename ||'_ddl.sql',
            directory => 'DATA_PUMP_DIR',
	    filetype  => DBMS_DATAPUMP.KU$_FILE_TYPE_SQL_FILE);

       DBMS_DATAPUMP.start_job(l_dp_handle);

       DBMS_DATAPUMP.detach(l_dp_handle);


end;


PROCEDURE impdp_table_network(p_schema in varchar2, p_tablename in varchar2, p_network_link in varchar2)
is
-- impdp a table through network link
  l_dp_handle       NUMBER;
  l_last_job_state  VARCHAR2(30) := 'UNDEFINED';
  l_job_state       VARCHAR2(30) := 'UNDEFINED';
  l_sts             KU$_STATUS;
BEGIN
   if p_network_link is null
   then
     dbms_output.put_line('Network link is null !');
     debug.f('Network link is NULL for schema %s and table %s', p_schema, p_tablename);
   end if;

      l_dp_handle := DBMS_DATAPUMP.open(
		    operation   => 'IMPORT',
		    job_mode    => 'TABLE',
		    remote_link => p_network_link,
		    job_name    =>  'imp_'|| to_char(sysdate, 'HH24MI_') || p_tablename,
		    version     => 'LATEST');

	DBMS_DATAPUMP.METADATA_FILTER( 
		   handle    => l_dp_handle,
		   name      => 'SCHEMA_EXPR',
		   value     =>  '=' || '''' ||p_schema || '''',
		   object_path  =>NULL);


	DBMS_DATAPUMP.METADATA_FILTER( 
		   handle    => l_dp_handle,
		   name      => 'NAME_EXPR',
		   value     =>  '= '|| '''' || p_tablename || '''',
		   object_path  =>NULL);

        DBMS_DATAPUMP.METADATA_FILTER( 
	   handle    => l_dp_handle,
	   name      => 'EXCLUDE_PATH_EXPR',
	   value => 'IN (''INDEX'', ''OBJECT_GRANT'')' 
	   );


        DBMS_DATAPUMP.add_file(
 	    handle    => l_dp_handle,
	    filename  => p_tablename ||'_impdp.log',
            directory => 'DATA_PUMP_DIR',
	    filetype  => DBMS_DATAPUMP.KU$_FILE_TYPE_LOG_FILE);


       DBMS_DATAPUMP.start_job(l_dp_handle);

       DBMS_DATAPUMP.detach(l_dp_handle);


end impdp_table_network; 



PROCEDURE impdp_full(
    dmpfile_in VARCHAR2)
IS
  h1            NUMBER;                         -- Data Pump job handle
  v_default_dir VARCHAR(30) := 'DATA_PUMP_DIR'; -- directory
  v_line_no     INTEGER     :=0;
  v_filename    VARCHAR2(100); -- filename without suffix
BEGIN
  v_filename :=SUBSTR(dmpfile_in, 1,instr(dmpfile_in, '.')-1 );
  h1         := dbms_datapump.open('IMPORT', 'FULL', NULL, 'IMPDP_' || v_filename);
  v_line_no  :=100;
  dbms_datapump.add_file(h1, dmpfile_in, v_default_dir);
  dbms_datapump.add_file(h1, v_filename ||'_impdp.log', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_log_file);
  DBMS_DATAPUMP.SET_PARAMETER(h1,'TABLE_EXISTS_ACTION','TRUNCATE');
  DBMS_DATAPUMP.START_JOB(h1);
  dbms_output.put_line('please checking log or dba_datapump_jobs view to see job status');
  dbms_datapump.detach(h1);
EXCEPTION
WHEN OTHERS THEN
  BEGIN
    DBMS_DATAPUMP.detach(h1);
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  DBMS_OUTPUT.put_line(SUBSTR('Value of v_line_no=' || TO_CHAR(v_line_no), 1, 255));
  RAISE;
END impdp_full;
PROCEDURE impdp_full(
    dmpfile_in       VARCHAR2,
    source_schema_in VARCHAR2,
    target_schema_in VARCHAR2)
IS
  h1            NUMBER;                         -- Data Pump job handle
  v_default_dir VARCHAR(30) := 'DATA_PUMP_DIR'; -- directory
  v_line_no     INTEGER     :=0;
  v_filename    VARCHAR2(100); -- filename without suffix
BEGIN
  v_filename :=SUBSTR(dmpfile_in, 1,instr(dmpfile_in, '.')-1 );
  h1         := dbms_datapump.open('IMPORT', 'FULL', NULL, 'IMPDP_' || v_filename);
  v_line_no  :=100;
  dbms_datapump.add_file(h1, dmpfile_in, v_default_dir);
  dbms_datapump.add_file(h1, v_filename ||'_impdp.log', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_log_file);
  DBMS_DATAPUMP.METADATA_REMAP(h1,'REMAP_SCHEMA',source_schema_in,target_schema_in);
  DBMS_DATAPUMP.SET_PARAMETER(h1,'TABLE_EXISTS_ACTION','SKIP');
  DBMS_DATAPUMP.START_JOB(h1);
  dbms_output.put_line('please checking log or dba_datapump_jobs view to see job status');
  dbms_datapump.detach(h1);
EXCEPTION
WHEN OTHERS THEN
  BEGIN
    DBMS_DATAPUMP.detach(h1);
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  DBMS_OUTPUT.put_line(SUBSTR('Value of v_line_no=' || TO_CHAR(v_line_no), 1, 255));
  RAISE;
END impdp_full;
-- data pump export schema mode
PROCEDURE expdp_schema(
    schema_in        VARCHAR2,
    flashback_scn_in NUMBER DEFAULT NULL)
IS
  h1            NUMBER;                         -- Data Pump job handle
  v_line_no     INTEGER     :=0;                -- debug
  v_default_dir VARCHAR(30) := 'DATA_PUMP_DIR'; -- directory
  v_sqltext     VARCHAR2(400);
BEGIN
  h1                                     := dbms_datapump.open( operation =>'EXPORT', job_mode => 'TABLE', job_name => 'EXPDP_SCHEMA_' || schema_in);
  v_line_no                              :=200;
  IF ( to_number(SUBSTR(db_version, 1,2)) < 11 ) THEN
    v_sqltext                            :='dbms_datapump.add_file(h1, schema_in' ||'.dmp' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_dump_file)';
  ELSE
    v_sqltext :='dbms_datapump.add_file(h1, schema_in' ||'.dmp' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_dump_file, reusefile => 1)';
  END IF;
  EXECUTE immediate v_sqltext;
  IF ( to_number(SUBSTR(db_version, 1,2)) < 11 ) THEN
    v_sqltext                            :='dbms_datapump.add_file(h1, schema_in' ||'_expdp.log' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_log_file)';
  ELSE
    v_sqltext :='dbms_datapump.add_file(h1, schema_in' ||'_expdp.log' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_log_file, reusefile => 1)';
  END IF;
  EXECUTE immediate v_sqltext;
  v_line_no :=300;
  DBMS_DATAPUMP.METADATA_FILTER(h1,'SCHEMA_EXPR','IN ( ''' || schema_in || ''')' );
  IF flashback_scn_in IS NOT NULL THEN
    dbms_datapump.set_parameter ( handle =>h1, name => 'FLASHBACK_SCN', value => flashback_scn_in);
    -- log the start time and SCN
    dbms_datapump.log_entry ( handle => h1, MESSAGE => 'Job starting at '||TO_CHAR(sysdate, 'HH24:MI:SS')||' for SCN '|| flashback_scn_in );
  END IF;
  dbms_datapump.start_job(h1);
  dbms_output.put_line('please checking log or dba_datapump_jobs view to see job status');
  DBMS_DATAPUMP.detach(h1);
EXCEPTION
WHEN OTHERS THEN
  BEGIN
    DBMS_DATAPUMP.detach(h1);
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  DBMS_OUTPUT.put_line(SUBSTR('Value of v_line_no=' || TO_CHAR(v_line_no), 1, 255));
  RAISE;
END expdp_schema;
PROCEDURE expdp_tab(
    owner_in         VARCHAR2,
    tablename_in     VARCHAR2,
    flashback_scn_in NUMBER DEFAULT NULL,
    table_filter_in  VARCHAR2 DEFAULT NULL)
IS
  h1            NUMBER;                         -- Data Pump job handle
  v_line_no     INTEGER     :=0;                -- debug
  v_default_dir VARCHAR(30) := 'DATA_PUMP_DIR'; -- directory
  v_sqltext     VARCHAR2(2000);
BEGIN
  v_line_no :=100;
  BEGIN
    h1 := dbms_datapump.open('EXPORT', 'TABLE', NULL, 'EXPDP_TAB_' || tablename_in);
  EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error in  datapump.open ...');
    dbms_output.put_line(DBMS_UTILITY.format_error_backtrace);
  END;
  v_line_no                              :=200;
  IF ( to_number(SUBSTR(db_version, 1,2)) < 11 ) THEN
    v_sqltext                            :='dbms_datapump.add_file(h1, schema_in' ||'.dmp' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_dump_file)';
  ELSE
    v_sqltext :='dbms_datapump.add_file(h1, schema_in' ||'.dmp' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_dump_file, reusefile => 1)';
  END IF;
  EXECUTE immediate v_sqltext;
  IF ( to_number(SUBSTR(db_version, 1,2)) < 11 ) THEN
    v_sqltext                            :='dbms_datapump.add_file(h1, schema_in' ||'_expdp.log' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_log_file)';
  ELSE
    v_sqltext :='dbms_datapump.add_file(h1, schema_in' ||'_expdp.log' || ', v_default_dir, filetype => DBMS_DATAPUMP.ku$_file_type_log_file, reusefile => 1)';
  END IF;
  EXECUTE immediate v_sqltext;
  v_line_no :=300;
  -- Filter for the schemma
  DBMS_DATAPUMP.metadata_filter(handle => h1, name => 'SCHEMA_LIST', VALUE => '''' || owner_in || '''');
  --Filter for the table
  DBMS_DATAPUMP.metadata_filter(handle => h1, name => 'NAME_LIST', VALUE => '''' || tablename_in || '''');
  v_line_no           :=400;
  IF flashback_scn_in IS NOT NULL THEN
    dbms_datapump.set_parameter ( handle =>h1, name => 'FLASHBACK_SCN', value => flashback_scn_in);
    -- log the start time and SCN
    dbms_datapump.log_entry ( handle => h1, MESSAGE => 'Job starting at '||TO_CHAR(sysdate, 'HH24:MI:SS')||' for SCN '|| flashback_scn_in );
  END IF;
  IF table_filter_in IS NOT NULL THEN
    -- Add a subquery
    DBMS_DATAPUMP.data_filter(handle =>h1, name => 'SUBQUERY', VALUE => table_filter_in);
    -- log the start time and filter
    dbms_datapump.log_entry ( handle => h1, MESSAGE => 'Job starting at '||TO_CHAR(sysdate, 'HH24:MI:SS')||' for filter '|| table_filter_in );
    v_line_no := 600; -- debug line no
  END IF;
  dbms_datapump.start_job(h1);
  dbms_output.put_line('please checking log or dba_datapump_jobs view to see job status');
  DBMS_DATAPUMP.detach(h1);
EXCEPTION
WHEN OTHERS THEN
  BEGIN
    DBMS_DATAPUMP.detach(h1);
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  DBMS_OUTPUT.put_line(SUBSTR('Value of v_line_no=' || TO_CHAR(v_line_no), 1, 255));
  RAISE;
END expdp_tab;
PROCEDURE rm_os_file(
    p_file_name IN VARCHAR2)
IS
BEGIN
  sys.dbms_backup_restore.deletefile(p_file_name);
EXCEPTION
WHEN OTHERS THEN
  dbms_output.put_line('Error in dbms_backup_restore.deletefile  ...');
  dbms_output.put_line(DBMS_UTILITY.format_error_backtrace);
END rm_os_file;
PROCEDURE xplan_for(
    p_sqltext VARCHAR2)
IS
  l_sql VARCHAR2(10000);
BEGIN
  l_sql := 'explain plan for ' || p_sqltext;
  EXECUTE immediate l_sql;
  FOR s IN
  (SELECT plan_table_output
  FROM TABLE(dbms_xplan.display('plan_table',NULL,'serial'))
  )
  LOOP
    dbms_output.put_line(s.plan_table_output);
  END LOOP;
END xplan_for;
PROCEDURE xplan_run(
    p_sqltext VARCHAR2)
IS
  l_sql VARCHAR2(10000);
BEGIN
  EXECUTE immediate ' alter session set statistics_level=all';
  EXECUTE immediate p_sqltext;
  FOR s IN
  (SELECT plan_table_output
  FROM TABLE(dbms_xplan.display_cursor(NULL,NULL,'COST IOSTATS LAST'))
  )
  LOOP
    dbms_output.put_line(s.plan_table_output);
  END LOOP;
END xplan_run;
PROCEDURE session_info(
    p_sid     IN NUMBER,
    p_inst_id IN NUMBER DEFAULT 1)
IS
BEGIN
  print_table('select * from gv$session where sid=' || p_sid || ' and inst_id = ' || p_inst_id);
END session_info;

PROCEDURE gen_ash(
	p_start in date default sysdate - 5/1440,
	p_dur_min in number default 5,
	p_sqlid in varchar2 default null,
	p_sid  in varchar2 default null
)
is
  v_dbid v$database.dbid%TYPE;
  v_inst_num v$instance.instance_number%TYPE := 1;
  v_end date;
begin
  SELECT dbid INTO v_dbid FROM v$database;
  SELECT instance_number INTO v_inst_num FROM v$instance;

  v_end := p_start + p_dur_min/1440;

  FOR c_report IN
(SELECT output
	    FROM TABLE(dbms_workload_repository.ash_report_text( 
			    v_dbid, 
			    v_inst_num, 
			    p_start,
			    v_end,
	                    null,
	                    null,
	                    p_sid,
	                    p_sqlid))
)
  LOOP
	 dbms_output.PUT_LINE(c_report.output);
  END LOOP;
end gen_ash;

PROCEDURE gen_awrdiff_email (
	    p_mailto IN VARCHAR2 DEFAULT 'teamdba@example.com',
	    p_end1 in date default sysdate,
	    p_end2 in date default sysdate-7,
	    p_interval_mins in number default 30,
	    p_dir in varchar2 default 'DATA_PUMP_DIR')
is
   v_msg varchar2(100);
begin
    SELECT instance_name ||'_' || host_name INTO v_msg FROM v$instance;
     gen_awrdiff(p_end1, p_end2, p_interval_mins, p_dir);
     dbms_output.put_line ('AWR  DIFF report file name ' || g_awrdiff_filename );
     mail_file(p_binary_file => g_awrdiff_filename , p_to_name =>p_mailto, p_subject => 'AWR DIFF Report ' || v_msg, p_oracle_directory=> p_dir);

end gen_awrdiff_email;



PROCEDURE gen_awrdiff (
	p_end1 in date default sysdate, 
	p_end2 in date default sysdate-7,
	p_interval_mins in number default 30,
        p_dir in varchar2 default 'DATA_PUMP_DIR')
is
  v_filename varchar2(50);
  v_dbid v$database.dbid%TYPE;
  v_dbname v$database.name%TYPE;
  v_inst_num v$instance.instance_number%TYPE := 1;
  v_instance_name v$instance.instance_name%TYPE;
  v_bid1 number;
  v_eid1 number;
  v_bid2 number;
  v_eid2 number;
  v_imins number;
begin
  v_imins := p_interval_mins -1;
  SELECT dbid, name INTO v_dbid, v_dbname FROM v$database;
  SELECT instance_name, instance_number INTO v_instance_name, v_inst_num FROM v$instance;
 
  SELECT MAX(snap_id)
  INTO v_eid1
  FROM dba_hist_snapshot
  WHERE trunc(end_interval_time, 'MI')  <= p_end1;

  SELECT MAX(snap_id)
  INTO v_bid1
  FROM dba_hist_snapshot
  WHERE trunc(end_interval_time, 'MI')  <= p_end1 - v_imins/1440;

  SELECT MAX(snap_id)
  INTO v_eid2
  FROM dba_hist_snapshot
  WHERE trunc(end_interval_time, 'MI')  <= p_end2;

  SELECT MAX(snap_id)
  INTO v_bid2
  FROM dba_hist_snapshot
  WHERE trunc(end_interval_time, 'MI')  <= p_end2 - v_imins/1440;

  dbms_output.put_line( 'v_eid1 =' || v_eid1  || '  v_eid2 = ' || v_eid2 );
  dbms_output.put_line( 'v_bid1 =' || v_bid1  || '  v_bid2 = ' || v_bid2 );

  v_filename := 'awrdiff_'|| v_instance_name || '_' || to_char(p_end1, 'YYMMDDHH24MI') || '_' || to_char(p_end2, 'YYMMDDHH24MI') ||
              '_' || p_interval_mins || '.html';
  dbms_output.put_line ( v_filename);


awrdiff_report( p_dir,  
	        p_filename  => v_filename,
                p_dbid1     => v_dbid,
                p_inst_num1 => v_inst_num,
                p_bid1      => v_bid1 ,
                p_eid1      => v_eid1 ,
                p_dbid2     => v_dbid,
                p_inst_num2 => v_inst_num ,
                p_bid2      => v_bid2,
                p_eid2      => v_eid2);


end gen_awrdiff;	


PROCEDURE gen_awr(
    p_end   IN DATE DEFAULT sysdate,
    p_start IN DATE DEFAULT sysdate,
    p_dir   IN VARCHAR2 DEFAULT 'DATA_PUMP_DIR',
    p_type  IN VARCHAR2 DEFAULT 'HTML' )
IS
  c_dir CONSTANT VARCHAR2(256) := '/tmp';
  --  v_dir         VARCHAR2(256) ;
  v_dbid v$database.dbid%TYPE;
  v_dbname v$database.name%TYPE;
  v_inst_num v$instance.instance_number%TYPE := 1;
  v_instance_name v$instance.instance_name%TYPE;
  v_begin      NUMBER;
  v_end        NUMBER;
  v_start_date VARCHAR2(20);
  v_end_date   VARCHAR2(20);
  v_options    NUMBER := 0; -- 0=no options, 8=enable addm feature
  v_file UTL_FILE.file_type;
  v_file_name            VARCHAR(50);
  v_line_no              NUMBER :=0;
  AWR_INTERVAL_TOO_SMALL EXCEPTION;
BEGIN
  SELECT dbid, name INTO v_dbid, v_dbname FROM v$database;
  SELECT MIN(snap_id),
    MAX(snap_id)
  INTO v_begin,
    v_end
  FROM dba_hist_snapshot
  WHERE end_interval_time <= p_end
  AND end_interval_time   >=p_start ;
  IF v_begin              >= v_end OR v_begin IS NULL OR v_end IS NULL THEN
    dbms_output.put_line ('Using most recent snapshot interval for the AWR report');
    SELECT MAX(snap_id)
    INTO v_end
    FROM dba_hist_snapshot
    WHERE end_interval_time <= p_end;
    SELECT MAX(snap_id) INTO v_begin FROM dba_hist_snapshot WHERE snap_id < v_end;
    --     raise AWR_INTERVAL_TOO_SMALL;
  END IF;
  --   dbms_output.put_line ( v_begin  || ' - ' || v_end );
  SELECT instance_name,
    instance_number
  INTO v_instance_name,
    v_inst_num
  FROM v$instance;
  SELECT TO_CHAR(end_interval_time,'YYMMDD_HH24MI')
  INTO v_start_date
  FROM dba_hist_snapshot
  WHERE snap_id       = v_begin
  AND instance_number = v_inst_num;
  --    dbms_output.put_line('v_start_date '||v_start_date);
  SELECT TO_CHAR(end_interval_time,'HH24MI')
  INTO v_end_date
  FROM dba_hist_snapshot
  WHERE snap_id       = v_end
  AND instance_number =v_inst_num;
  --  dbms_output.put_line('v_end_date '||v_end_date);
  v_line_no   := 5;
  v_file_name := 'awr_' || v_instance_name || '_' || v_start_date || '_' || v_end_date;
  v_line_no   := 20;
  awr_report(p_dir, v_file_name , v_inst_num, v_dbid, p_type, v_begin,v_end, v_options);
EXCEPTION
WHEN AWR_INTERVAL_TOO_SMALL THEN
  dbms_output.put_line ('awr interval too small');
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('v_line_no = ' || v_line_no);
  DBMS_OUTPUT.PUT_LINE(SQLERRM);
  IF UTL_FILE.is_open(v_file) THEN
    UTL_FILE.fclose(v_file);
  END IF;
END gen_awr;
/*
PROCEDURE send_email_attach( p_filename varchar2, p_dir varchar2 default 'DATA_PUMP_DIR')
is
--
--  attached file must be smaller than 32k
--
fHandle  utl_file.file_type;
vTextOut varchar2(32000);
text varchar2(32000) := NULL;
v_line_no number :=0;
begin
EXECUTE IMMEDIATE 'ALTER SESSION SET smtp_out_server = ''127.0.0.1''';
fHandle :=utl_file.fopen(p_dir, p_filename, 'r');
IF UTL_FILE.IS_OPEN(fHandle) THEN
DBMS_OUTPUT.PUT_LINE('File read open');
ELSE
DBMS_OUTPUT.PUT_LINE('File read not open');
END IF;
v_line_no :=10;
loop
begin
UTL_FILE.GET_LINE(fHandle,vTextOut);
IF text IS NULL THEN
text := text || vTextOut;
ELSE
text := text || UTL_TCP.CRLF || vTextOut;
END IF;
dbms_output.put_line('length ' || length(text));
EXCEPTION
WHEN NO_DATA_FOUND THEN EXIT;
end;
END LOOP;
v_line_no :=20;
--dbms_output.put_line(length(text));
UTL_FILE.FCLOSE(fHandle);
v_line_no :=30;
UTL_MAIL.SEND_ATTACH_VARCHAR2(sender => 'teamdba@example.com',
recipients => 'yu.d.sun@example.com',
subject => 'Testmail',
message => 'attached file',
attachment => text, ATT_INLINE => FALSE);
EXCEPTION
WHEN OTHERS THEN
dbms_output.put_line('v_line_no = ' || v_line_no);
raise_application_error(-20001,'The following error has occured: ' || sqlerrm);
end send_email_attach;
*/
PROCEDURE mail_file(
    p_binary_file      VARCHAR2,
    p_to_name          VARCHAR2 DEFAULT 'teamdba@example.com' ,
    p_from_name        VARCHAR2 DEFAULT 'teamdba@example.com' ,
    p_subject          VARCHAR2 DEFAULT 'email file from server' ,
    p_message          VARCHAR2 DEFAULT 'file attached',
    p_oracle_directory VARCHAR2 DEFAULT 'DATA_PUMP_DIR' )
IS
  -- Example procedure to send a mail with an in line attachment
  -- encoded in Base64
  -- this procedure uses the following nested functions:
  --   binary_attachment - calls:
  --   begin_attachment - calls:
  --   write_boundary
  --   write_mime_header
  --
  --   end attachment - calls;
  --   write_boundary
  -- change the following line to refer to your mail server
  --  v_smtp_server VARCHAR2(100) := '127.0.0.1';
  v_smtp_server      VARCHAR2(100) := 'smtp.example.com';
  v_smtp_server_port NUMBER        := 25;
  v_directory_name   VARCHAR2(100);
  v_file_name        VARCHAR2(100);
  v_mesg             VARCHAR2(32767);
  v_conn UTL_SMTP.CONNECTION;
  --
PROCEDURE write_mime_header(
    p_conn  IN OUT nocopy utl_smtp.connection,
    p_name  IN VARCHAR2,
    p_value IN VARCHAR2)
IS
BEGIN
  UTL_SMTP.WRITE_RAW_DATA( p_conn, UTL_RAW.CAST_TO_RAW( p_name || ': ' || p_value || UTL_TCP.CRLF) );
END write_mime_header;
--
PROCEDURE write_boundary(
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_last IN BOOLEAN DEFAULT false)
IS
BEGIN
  IF (p_last) THEN
    UTL_SMTP.WRITE_DATA(p_conn, '--DMW.Boundary.605592468--'||UTL_TCP.CRLF);
  ELSE
    UTL_SMTP.WRITE_DATA(p_conn, '--DMW.Boundary.605592468'||UTL_TCP.CRLF);
  END IF;
END write_boundary;
--
PROCEDURE end_attachment(
    p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_last IN BOOLEAN DEFAULT TRUE)
IS
BEGIN
  UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);
  IF (p_last) THEN
    write_boundary(p_conn, p_last);
  END IF;
END end_attachment;
--
PROCEDURE begin_attachment(
    p_conn         IN OUT NOCOPY UTL_SMTP.CONNECTION,
    p_mime_type    IN VARCHAR2 DEFAULT 'text/plain',
    p_inline       IN BOOLEAN DEFAULT false,
    p_filename     IN VARCHAR2 DEFAULT NULL,
    p_transfer_enc IN VARCHAR2 DEFAULT NULL)
IS
BEGIN
  write_boundary(p_conn);
  IF (p_transfer_enc IS NOT NULL) THEN
    write_mime_header(p_conn, 'Content-Transfer-Encoding',p_transfer_enc);
  END IF;
  write_mime_header(p_conn, 'Content-Type', p_mime_type);
  IF (p_filename IS NOT NULL) THEN
    IF (p_inline) THEN
      write_mime_header( p_conn, 'Content-Disposition', 'inline; filename="' || p_filename || '"' );
    ELSE
      write_mime_header( p_conn, 'Content-Disposition', 'attachment; filename="' || p_filename || '"' );
    END IF;
  END IF;
  UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);
END begin_attachment;
--
PROCEDURE binary_attachment(
    p_conn      IN OUT UTL_SMTP.CONNECTION,
    p_file_name IN VARCHAR2,
    p_mime_type IN VARCHAR2)
IS
  c_max_line_width CONSTANT PLS_INTEGER DEFAULT 54;
  v_amt BINARY_INTEGER := 672 * 3;
  /* ensures proper format; 2016 */
  v_bfile BFILE;
  v_file_length PLS_INTEGER;
  v_buf RAW(2100);
  v_modulo PLS_INTEGER;
  v_pieces PLS_INTEGER;
  v_file_pos pls_integer := 1;
BEGIN
  begin_attachment( p_conn => p_conn, p_mime_type => p_mime_type, p_inline => TRUE, p_filename => p_file_name, p_transfer_enc => 'base64');
  BEGIN
    v_bfile := BFILENAME(p_oracle_directory, p_file_name);
    -- Get the size of the file to be attached
    v_file_length := DBMS_LOB.GETLENGTH(v_bfile);
    -- Calculate the number of pieces the file will be split up into
    v_pieces := TRUNC(v_file_length / v_amt);
    -- Calculate the remainder after dividing the file into v_amt chunks
    v_modulo     := MOD(v_file_length, v_amt);
    IF (v_modulo <> 0) THEN
      -- Since the file does not devide equally
      -- we need to go round the loop an extra time to write the last
      -- few bytes - so add one to the loop counter.
      v_pieces := v_pieces + 1;
    END IF;
    DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);
    FOR i IN 1 .. v_pieces
    LOOP
      -- we can read at the beginning of the loop as we have already calculated
      -- how many iterations we will take and so do not need to check
      -- end of file inside the loop.
      v_buf := NULL;
      DBMS_LOB.READ(v_bfile, v_amt, v_file_pos, v_buf);
      v_file_pos := I * v_amt + 1;
      UTL_SMTP.WRITE_RAW_DATA(p_conn, UTL_ENCODE.BASE64_ENCODE(v_buf));
    END LOOP;
  END;
  DBMS_LOB.FILECLOSE(v_bfile);
  end_attachment(p_conn => p_conn);
EXCEPTION
WHEN NO_DATA_FOUND THEN
  end_attachment(p_conn => p_conn);
  DBMS_LOB.FILECLOSE(v_bfile);
END binary_attachment;
--
-- Main Routine
--
BEGIN
  --
  -- Connect and set up header information:
  --
  v_conn:= UTL_SMTP.OPEN_CONNECTION( v_smtp_server, v_smtp_server_port );
  UTL_SMTP.HELO( v_conn, v_smtp_server );
  UTL_SMTP.MAIL( v_conn, p_from_name );
  UTL_SMTP.RCPT( v_conn, p_to_name );
  UTL_SMTP.OPEN_DATA ( v_conn );
  UTL_SMTP.WRITE_DATA(v_conn, 'Subject: '||p_subject||UTL_TCP.CRLF);
  --
  v_mesg:= 'Content-Transfer-Encoding: 7bit' || UTL_TCP.CRLF || 'Content-Type: multipart/mixed;boundary="DMW.Boundary.605592468"' || UTL_TCP.CRLF || 'Mime-Version: 1.0' || UTL_TCP.CRLF || '--DMW.Boundary.605592468' || UTL_TCP.CRLF || 'Content-Transfer-Encoding: binary'||UTL_TCP.CRLF|| 'Content-Type: text/plain' ||UTL_TCP.CRLF || UTL_TCP.CRLF || p_message || UTL_TCP.CRLF ;
  --
  UTL_SMTP.write_data(v_conn, 'To: ' || p_to_name || UTL_TCP.crlf);
  UTL_SMTP.WRITE_RAW_DATA ( v_conn, UTL_RAW.CAST_TO_RAW(v_mesg) );
  --
  -- Add the Attachment
  --
  binary_attachment( p_conn => v_conn, p_file_name => p_binary_file,
  -- Modify the mime type at the beginning of this line depending
  -- on the type of file being loaded.
  p_mime_type => 'text/plain; name="'||p_binary_file||'"' );
  --
  -- Send the email
  --
  UTL_SMTP.CLOSE_DATA( v_conn );
  UTL_SMTP.QUIT( v_conn );
END mail_file;

PROCEDURE gen_awr_email(
    p_mailto IN VARCHAR2 DEFAULT 'teamdba@example.com',
    p_end    IN DATE DEFAULT sysdate,
    p_start  IN DATE DEFAULT sysdate,
    p_dir    IN VARCHAR2 DEFAULT 'DATA_PUMP_DIR',
    p_type   IN VARCHAR2 DEFAULT 'HTML' )
IS
  v_msg VARCHAR2(100);
BEGIN
  SELECT instance_name ||'_' || host_name INTO v_msg FROM v$instance;
  gen_awr(p_end, p_start, p_dir, p_type);
  dbms_output.put_line ('AWR file ' || g_awr_filename );
  mail_file(p_binary_file => g_awr_filename , p_to_name =>p_mailto, p_subject => 'AWR Report ' || v_msg, p_oracle_directory=> p_dir);
END gen_awr_email;


PROCEDURE list_highest_partition
is
-- list the partition of each partitioned table that has  highest HIGH_VALUE
-- excluding tables owned SYS and SYSTEM
begin
	dbms_output.put_line('table_owner   ' || ' ' || 'table_name                     ' || ' ' || 'partition_name' || ' ' ||  'high_value' ) ;
	dbms_output.put_line('--------------' || ' ' || '-------------------------------' || ' ' || '--------------' || ' ' ||  '---------------------' ) ;

 for each_part in (
       select table_owner, table_name, partition_name, high_value from 
	(
	select a.table_owner, a.table_name, a.partition_name, a.high_value,
	  rank () over ( partition by a.table_owner, a.table_name ORDER BY high_value desc) r 
	from
	  xmltable( '/ROWSET/ROW'
		     passing dbms_xmlgen.getXMLType('
				 select
				    table_owner
				   ,table_name
				   ,partition_name
				   ,high_value
				 from dba_tab_partitions
				 where table_owner not in (''SYS'' , ''SYSTEM'')
				 ')
		      columns
			   TABLE_OWNER    VARCHAR2(30)
			   ,TABLE_NAME     VARCHAR2(30)
			   ,PARTITION_NAME  VARCHAR2(30)
			   ,HIGH_VALUE     VARCHAR2(4000)
		  )  A 
	)
	where r=1
 )
 loop
	dbms_output.put_line(rpad(each_part.table_owner, 14)  || ' ' || rpad( each_part.table_name,32) || ' ' || 
		             rpad(each_part.partition_name,14) || ' ' ||  each_part.high_value ); 
 end loop;
end list_highest_partition;

PROCEDURE drop_partition_by_cutoff(
          p_owner      IN VARCHAR2 ,
          p_table_name  IN  VARCHAR2 ,
          p_cutoff_date IN DATE ,
          p_is_interval IN CHAR DEFAULT 'Y',
          p_is_drop     IN BOOLEAN DEFAULT true)
IS
-- Drop partitions of time-based partitioned table by cut-off date
	l_hv       DATE;
	l_out      VARCHAR2(2000);
	l_drop_sql VARCHAR2(1000);
	l_sql      VARCHAR2(2000);
  
BEGIN
  -- for interval partition last partition in the range section cannot be dropped
  -- assuming we only have 1 parition in the range section
  -- in such case partition_position=1 cannot be dropped
  FOR part_cur IN
  (SELECT partition_name,
    high_value
  FROM dba_tab_partitions
  WHERE table_owner       = p_owner
  AND table_name          = p_table_name
  AND partition_position != DECODE(p_is_interval, 'Y',1,0)
  ORDER BY partition_position
  )
  LOOP
    --   dbms_output.put_line('partition_name: '|| part_cur.partition_name);
    --   dbms_output.put_line('high_value: '|| part_cur.high_value);
    IF part_cur.high_value != 'MAXVALUE' THEN
      EXECUTE immediate 'select ' || part_cur.high_value || ' from dual' INTO l_hv;
      IF p_cutoff_date > l_hv THEN
        l_out          := 'Partition ' || part_cur.partition_name || ' with high value ' || l_hv || ' to be dropped ...';
        dbms_output.put_line(l_out);
        l_drop_sql := 'alter table '|| p_owner||'.'|| p_table_name|| ' drop partition '|| part_cur.partition_name|| ' update global indexes';
        --          dbms_output.put_line('l_drop_sql='||l_drop_sql);
        BEGIN
          l_sql := l_drop_sql;
          -- disable FK omit
	  if p_is_drop
		then
              EXECUTE immediate l_sql;
              dbms_output.put_line(l_sql || ' is sucessful ');
          else
             dbms_output.put_line('#### only show drop sql statment no acutaul drop ' || chr(10) || l_drop_sql);
          end if;

          -- enable FK   omit
        EXCEPTION
        WHEN OTHERS THEN
          dbms_output.put_line( l_sql || ' is failed : ' || SQLERRM || '  ' || SQLCODE );
        END;
      END IF;
    END IF;
  END LOOP;
END drop_partition_by_cutoff;


function col_list_concat(p_owner varchar2, p_tablename varchar2, p_delimiter varchar2 default '~')
return varchar2
is
  l_collist varchar2(32000);
begin
  for r in ( select column_name, column_id from dba_tab_columns where owner=p_owner and table_name=p_tablename order by column_id )
  loop
     if r.column_id = 1
     then
       l_collist := r.column_name || chr(10) ;
     else
       l_collist :=  l_collist || ' || ''' || p_delimiter || '''||' || r.column_name || chr(10);
     end if;
  end loop;
  return l_collist;

end;

procedure dump_data (
            p_query in varchar2,
            p_directory in varchar2 default 'DATA_PUMP_DIR',
            p_file_name in varchar2 default 'sample.dat',
            p_delimited in varchar2 default '|',
            p_status   out number )        /* 0 - Sucess / other than 0 is error */
as
            l_exec_status number;
            l_file_handle utl_file.file_type;
            l_desc_tab    dbms_sql.desc_tab;
            l_column_count number ;
            l_line varchar2(32760) := null;
            l_column_value varchar2(4000);           
            g_cursor number := dbms_sql.open_cursor;
            l_nls_values nls_database_parameters.value%type;
begin
            p_status := 0;
            select value
            into l_nls_values
            from nls_database_parameters
            where parameter = 'NLS_DATE_FORMAT';
           
            execute immediate ' alter session set nls_date_format = ''ddmmyyyyhh24miss'' ';
           
            l_file_handle := utl_file.fopen (p_directory,p_file_name,'w',32760);
           
            dbms_sql.parse(g_cursor,p_query,dbms_sql.native);
            dbms_sql.describe_columns (g_cursor,l_column_count,l_desc_tab);
           
            for i in 1..l_column_count
            loop
                dbms_sql.define_column (g_cursor,i,l_column_value,4000);
            end loop;
           
            l_exec_status := dbms_sql.execute(g_cursor);
           
            while ( dbms_sql.fetch_rows(g_cursor) > 0 )
            loop
                l_line := null;

                for i in 1..l_column_count
                loop
                    dbms_sql.column_value(g_cursor,i,l_column_value);
                    l_line := l_line ||p_delimited||l_column_value;
                end loop;
                l_line := l_line || chr(13) || chr(10); /* line  terminator in windows */
                utl_file.put(l_file_handle,l_line);
            end loop;
           
            utl_file.fclose(l_file_handle);
           
            execute immediate ' alter session set nls_date_format = '''|| l_nls_values ||'''';
           
        exception
            when others then
                if dbms_sql.is_open(g_cursor) then
                    dbms_sql.close_cursor(g_cursor);
                end if;
               
                if utl_file.is_open (l_file_handle) then
                    utl_file.fclose(l_file_handle);
                end if;
                p_status := sqlcode;
                raise_application_error ( -20458,sqlerrm);
        end dump_data;

END;
/
