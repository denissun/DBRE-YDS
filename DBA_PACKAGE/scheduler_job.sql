begin
	 DBMS_SCHEDULER.create_job (
		    job_name        => 'Monitor_Long_Running_SQLs',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.proactive.LONG_RUNNING_SQLS; END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=5,35',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/


begin
	 DBMS_SCHEDULER.create_job (
		    job_name        => 'Monitor_Tablespace',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.proactive.check_tablespace; END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=0,20,40',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/

begin
	 DBMS_SCHEDULER.create_job (
		    job_name        => 'MONITOR_SQL_TOTAL_GETS',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.proactive.SQL_TOTAL_GETS; END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=3,33',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/

begin

	 DBMS_SCHEDULER.create_job (
		    job_name        => 'MONITOR_BLOCKERS',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.proactive.check_blockers; END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=7,37',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/





begin
	 DBMS_SCHEDULER.create_job (
		    job_name        => 'MONITOR_WAITEVENT',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.proactive.check_waitevent(60); END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=1,16,31,46',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/




--- following lines after doc for reference purpose, they will be ignored for execution
set doc off
doc

-- may be need to set up a cron job to do : chmod 664 /path/to/ggserr.log
begin
	 DBMS_SCHEDULER.create_job (
		    job_name        => 'Monitor_GGSERR_LOG',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.alert_file.monitor_ggserr; END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=0,15,30,45',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/

begin
	 DBMS_SCHEDULER.create_job (
		    job_name        => 'MONITOR_GG_LATENCY',
		    job_type        => 'PLSQL_BLOCK',
		    job_action      => 'BEGIN db_admin.proactive.gg_latency_alert; END;',
		    start_date      => trunc(sysdate, 'HH24'),
		    repeat_interval => 'freq=hourly; byminute=1,21,41',
		    end_date        => NULL,
		    enabled         => TRUE
		    );
end;
/


-- GG_LATENCY_ALERT



-- modify attribute example

begin
	  dbms_scheduler.set_attribute(
		             name => 'MONITOR_SQL_TOTAL_GETS' 
	                    ,attribute=>'JOB_ACTION'
                            ,value=>'BEGIN db_admin.proactive.SQL_TOTAL_GETS(10000000); END;' );
end;
/

begin
 DBMS_SCHEDULER.create_job (
    job_name        => 'Monitor_Alert_File_inst_2',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN db_admin.alert_file.monitor_alert_file(''ALERT_FILE2_EXT'', ''ALERT_DIR2''); END;',
    start_date      => trunc(sysdate, 'HH24'),
    repeat_interval => 'freq=hourly; byminute=0,10,20,30,40,50',
    end_date        => NULL,
    enabled         => TRUE
    );
end;
/

-- note for RAC it is important to make sure  the job run in the desirable instance
begin
  dbms_scheduler.set_attribute(name => 'Monitor_Alert_File_inst_2' ,attribute=>'INSTANCE_ID', value=> 2);
end;
/

begin
 DBMS_SCHEDULER.create_job (
    job_name        => 'Monitor_Alert_File_inst_1',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN db_admin.alert_file.monitor_alert_file(''ALERT_FILE1_EXT'', ''ALERT_DIR1''); END;',
    start_date      => trunc(sysdate, 'HH24'),
    repeat_interval => 'freq=hourly; byminute=0,10,20,30,40,50',
    end_date        => NULL,
    enabled         => TRUE
    );
end;
/

-- note for RAC it is important to make sure  the job run in the desirable instance

begin
  dbms_scheduler.set_attribute(name => 'Monitor_Alert_File_inst_1' ,attribute=>'INSTANCE_ID', value=> 1);
end;
/


* sameple jobs


db_admin@vvoprdtp4_vvottpd4> exec admin.print_table('select job_name, job_action, enabled, instance_id from user_scheduler_jobs');
JOB_NAME                      : MONITOR_ALERT_FILE_INST_1
JOB_ACTION                    : BEGIN db_admin.alert_file.monitor_alert_file('ALERT_FILE1_EXT', 'ALERT_DIR1'); END;
ENABLED                       : TRUE
INSTANCE_ID                   : 1
-----------------
JOB_NAME                      : MONITOR_ALERT_FILE_INST_2
JOB_ACTION                    : BEGIN db_admin.alert_file.monitor_alert_file('ALERT_FILE2_EXT', 'ALERT_DIR2'); END;
ENABLED                       : TRUE
INSTANCE_ID                   : 2
-----------------
JOB_NAME                      : MONITOR_ALERT_FILE_INST_3
JOB_ACTION                    : BEGIN db_admin.alert_file.monitor_alert_file('ALERT_FILE3_EXT', 'ALERT_DIR3'); END;
ENABLED                       : TRUE
INSTANCE_ID                   : 3
-----------------
JOB_NAME                      : MONITOR_ALERT_FILE_INST_4
JOB_ACTION                    : BEGIN db_admin.alert_file.monitor_alert_file('ALERT_FILE4_EXT', 'ALERT_DIR4'); END;
ENABLED                       : TRUE
INSTANCE_ID                   : 4
-----------------
JOB_NAME                      : MONITOR_BLOCKERS
JOB_ACTION                    : BEGIN db_admin.proactive.check_blockers; END;
ENABLED                       : TRUE
INSTANCE_ID                   :
-----------------
JOB_NAME                      : MONITOR_GGSERR_LOG
JOB_ACTION                    : BEGIN db_admin.alert_file.monitor_ggserr; END;
ENABLED                       : TRUE
INSTANCE_ID                   :
-----------------
JOB_NAME                      : MONITOR_LONG_RUNNING_SQLS
JOB_ACTION                    : BEGIN db_admin.proactive.LONG_RUNNING_SQLS; END;
ENABLED                       : TRUE
INSTANCE_ID                   :
-----------------
JOB_NAME                      : MONITOR_SQL_TOTAL_GETS
JOB_ACTION                    : BEGIN db_admin.proactive.SQL_TOTAL_GETS(10000000); END;
ENABLED                       : TRUE
INSTANCE_ID                   :
-----------------
JOB_NAME                      : MONITOR_TABLESPACE
JOB_ACTION                    : BEGIN db_admin.proactive.check_tablespace; END;
ENABLED                       : TRUE
INSTANCE_ID                   :
-----------------
JOB_NAME                      : MONITOR_WAITEVENT
JOB_ACTION                    : BEGIN db_admin.proactive.check_waitevent; END;
ENABLED                       : TRUE
INSTANCE_ID                   :
-----------------

PL/SQL procedure successfully completed.


#
