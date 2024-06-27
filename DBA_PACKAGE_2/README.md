DBA Packages

Author : Yu (Denis) Sun

Revision History

```

DD-MON-YYYY    Who      What
-----------    ---      --------------------------------------------------
05-JUL-2015    Denis    in ADMIN pkg, add dump_data
20-JUN-2015    Denis    in ALERT_FILE pkg, remove code of renaming ggserr.log
                        in PROACTIVE pkg, added long_ops_alert procedure
05-JUN-2015    Denis    Add debug package from Connor McDonald v1.3
28-APR-2015    Denis    fixed a bug in alert_file pkg monitoring ggserr.log
22-APR-2015    Denis    Release version 1.0

```

DBA Packages V1.3 code

# Purpose

The PL/SQL packages are developed to help DBAs perform some common tasks more conveniently 
and some procedures are created to meet the security requirements for the onshore and offshore 
support model by the company. There are restrictions for DBAs to logon to the database servers.
The packages allow DBA to perform certain DBA tasks without logon to the databases servers.

## Summary of packages developed:

ADMIN - Perform DBA common administration tasks

NOTIFICATION - Send out email and/or save message in the database

ALERT_FILE - Monitor and manage alert log and GoldenGate error log

PROACTIVE - Monitor database for potenital problems

HISTORY - Manage Health check historical data for trend analysis and troubleshooting

## Installation

Before installing the packages, some supporting objects have to be created and database enironment
needs to be configured in order to compile those packages sucessfully. 

The following steps should be followed:

1. Create the schema and run grant.sql to grant privileges

Assuming those packages are installed under DB_ADMIN user . So at first, create DB_ADMIN user if it does not exist. 
Run the grant.sql script to grant all necessary privilges to DB_ADMIN.

Note: XDB is required and need to be installed first if not yet.

2. Run tables_ddl.sql to create tables

Create ALERTS, CONFIGS and HC_HISTORY tables.

Initially, configs table should at least contain the following four entries in order to enable email functionality

-- change server name as needed

```

insert into configs values ('SENDER', 'oracle@host.mycompany.com');
insert into configs values ('RECIP', 'dbateam@mycompany.com');
insert into configs values ('SMTP_SERVER', 'smtp.mycompany.com');
insert into configs values ('SMTP_SERVER_PORT', '25');

```

3. Run tables_external.sql to create external tables

Create external tables for the alert log file , GoldenGate ggserr.log and gginfo.txt file .

The SQL statements in this file are meant for examples only, DBA needs to modify the script before running it according to the specific system. 
For examples, the directory path and file names are hard-coded.

4. Load alert message to DBAETS

DBAETS is an web application with an Oracle database called etsdb at backend. It can be used as a central place to track alert messages and historical data.

Add the following entry in the local tnsnames.ora. (for RAC, add it at each node)

etsdb =
 (DESCRIPTION=(ADDRESS=(PROTOCOL=tcp)(HOST=xxx.xxx.xxx.xxx)(PORT=1521)) ( connect_data= (SID = etsdb)))

Create a database link

SQL> create database link etsdb connect to dbaets identified by &psswd using 'etsdb';

Database link created.

Create a synonym for a remote procedure

SQL> create synonym dbaets_load for  proc_event_load@etsdb;

Synonym created.

SQL> desc dbaets_load

PROCEDURE dbaets_load
 Argument Name                  Type                    In/Out Default?
 ------------------------------ ----------------------- ------ --------
 P_TITLE                        VARCHAR2                IN
 P_DATABASE                     VARCHAR2                IN
 P_SERVER                       VARCHAR2                IN
 P_DESC                         CLOB                    IN
 P_CREATED_BY                   VARCHAR2                IN     DEFAULT
 P_START_TIME                   DATE                    IN


create a synonym for a remote table

create synonym hc_history_remote for dbaets.hc_history@etsdb;

Note: in a GG replication environment, if DDL replication is enabled, the create synonym over db link will cause process abending

Extract Abends as it Finds DDLs Using Dblink (Doc ID 1598876.1). 

I don’t feel it is a good pracice to enable DDL replication during BAU. 
DDL replication may be enabled during release time in the case of replicating the DDL changes from source to multiple targets. 
DDL replication is really something need to well-thought and tested.


5. Run install.sql to install packages

Install the packages. Synonyms are also create for the packages for convenience.

Note: need to install a debug package

@@debug_ddl.sql

@@debug.pks

--  @@debug.pkb

@@debug_disable.pkb

note: run notif.tst to test email, save to db table and load message to dbaets is advisable at this stage.

6. Create scheduler jobs as shown in scheduler_job.sql

We may use Oracle built-in dbms_scheduler package to schedule the monitoring jobs. Examples are provided in this file

7. List of necessary files

All scripts may be provided in a zip file.

admin.pks - ADMIN package specification

admin.pkb - ADMIN package body

alert_file.pks - ALERT_FILE package specification

alert_file.pkb - ALERT_FILE pacakge body

notification.pks - NOTIFICATION package specification

notification.pkb - NOTIFICATION package boday

proactive.pks - PROACTIVE package specification

proactive.pkb - PROACTIVE pacakge body

history.pks - HISTORY package specification

history.pkb - HISTORY package specification

grant.sql - grant privileges to the schema owner

tables_ddl.sql - create tables needed by the packages

tables_external.sql - create external tables needed by the packages

install.sql - install packages

scheduler_job.sql - examples of scheduler jobs for monitoring

debug_ddl.sql - objects creation required by debug package

debug.pks - DEBUG package specification

debug.pkb - DEBUG package body

debug_disable.pkb - run in production to bypass debug procedures


### MISC

Create a job

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

Enable or Disable a job

execute dbms_scheduler.enable('MY_JOB_NAME');
execute dbms_scheduler.disable('MY_JOB_NAME');
Set attributes
begin
   dbms_scheduler.set_attribute (
   name => 'MONITOR_SQL_TOTAL_GETS',
   attribute => 'JOB_ACTION',
   value => 'BEGIN db_admin.proactive.SQL_TOTAL_GETS(5000000); END;'
  );
end;
/

Display Jobs

execute admin.print_table('select owner,job_name, job_action, state, next_run_date from dba_scheduler_jobs');

execute admin.print_table('select job_name, job_action, state, next_run_date from user_scheduler_jobs');

```

col job_action format a50
col job_name format a25
col next_run_date format a25
select job_name, job_action, state, next_run_date from dba_scheduler_jobs where owner='DB_ADMIN';

```

