CREATE OR REPLACE
PACKAGE admin
IS
  /**
  *=======================================================================
  * NAME
  *    admin.pks - package specification
  *
  * DESCRIPTION
  *    Define a package used to  perform various dba tasks
  *
  * NOTES
  *    vdsi dba doesn't have privileges to read the data and they cannot
  *    su - oracle either. This prevent them from performing certain admin
  *    tasks. This package is thus developed to allow vdsi dba to perform
  *    those tasks through some procedures.
  *
  *    Assume installing this pkg under DB_ADMIN, privleges are given
  *    by executing grant.sql as sysdba
  *
  * 
  *    Denpendency :  package :  notification package
  *                   table   :  alerts  
  *
  * MODIFIED ( MM/DD/YY)
  *
  *     Denis  04/28/15  - v1.3 AWR Diff report, AWR SQL report etc       
  *     Denis  03/27/15  - v1.2 generate AWR, ASH and email etc
  *     Denis  11/21/14  - v1.1 exp with flashback_scn, execution plan,
  *                        kill rac sessions
  *     Denis  11/10/14  - creation   v1.0
  *
  *----------------------------------------------------------------------
  */
  -- data pump import full mode
  PROCEDURE impdp_full(
      dmpfile_in VARCHAR2);
  -- data pump import full mode with schema remap
  PROCEDURE impdp_full(
      dmpfile_in       VARCHAR2,
      source_schema_in VARCHAR2,
      target_schema_in VARCHAR2);
  -- data pump export table mode  - one table only
  PROCEDURE expdp_tab(
      owner_in         VARCHAR2,
      tablename_in     VARCHAR2,
      flashback_scn_in NUMBER DEFAULT NULL,
      table_filter_in  VARCHAR2 DEFAULT NULL);
  -- data pump export schema mode
  PROCEDURE expdp_schema(
      schema_in        VARCHAR2,
      flashback_scn_in NUMBER DEFAULT NULL);
  -- remove an OS file
  PROCEDURE rm_os_file(
      p_file_name IN VARCHAR2);
  -- kill a user session
  PROCEDURE kill_session(
      sid_in    IN NUMBER ,
      serial_in IN NUMBER);
  PROCEDURE kill_rac_session(
      sid_in     IN NUMBER,
      serial_in  IN NUMBER,
      inst_id_in IN INTEGER );
  PROCEDURE kill_sessions(
      p_username IN VARCHAR2,
      p_machine  IN VARCHAR2 DEFAULT NULL,
      p_event    IN VARCHAR2 DEFAULT NULL,
      p_sqlid    IN VARCHAR2 DEFAULT NULL);
  PROCEDURE kill_rac_sessions(
      p_username IN VARCHAR2,
      p_machine  IN VARCHAR2 DEFAULT NULL,
      p_event    IN VARCHAR2 DEFAULT NULL,
      p_sqlid    IN VARCHAR2 DEFAULT NULL,
      p_inst_id  IN INTEGER DEFAULT 1 );
  -- explain plan for
  PROCEDURE xplan_for(
      p_sqltext VARCHAR2);
  PROCEDURE xplan_run(
      p_sqltext VARCHAR2);
  PROCEDURE session_info(
      p_sid     IN NUMBER,
      p_inst_id IN NUMBER DEFAULT 1);
  -- generate an AWR DIFF report and email it as attachment
  PROCEDURE gen_awrdiff_email (
      p_mailto IN VARCHAR2 DEFAULT 'teamdba@example.com',	 
      p_end1 in date default sysdate,
      p_end2 in date default sysdate-7,
      p_interval_mins in number default 30,
      p_dir in varchar2 default 'DATA_PUMP_DIR');
  PROCEDURE gen_awrdiff (
      p_end1 in date default sysdate,
      p_end2 in date default sysdate-7,
      p_interval_mins in number default 30,
      p_dir in varchar2 default 'DATA_PUMP_DIR');
  -- generate an AWR report
  PROCEDURE gen_awr(
      p_end   IN DATE DEFAULT sysdate,
      p_start IN DATE DEFAULT sysdate,
      p_dir   IN VARCHAR2 DEFAULT 'DATA_PUMP_DIR',
      p_type  IN VARCHAR2 DEFAULT 'HTML' );
  -- generate an AWR and email it as attachement
  PROCEDURE gen_awr_email(
      p_mailto IN VARCHAR2 DEFAULT 'teamdba@example.com',
      p_end    IN DATE DEFAULT sysdate,
      p_start  IN DATE DEFAULT sysdate,
      p_dir    IN VARCHAR2 DEFAULT 'DATA_PUMP_DIR',
      p_type   IN VARCHAR2 DEFAULT 'HTML' );
  PROCEDURE gen_ash(
      p_start   IN DATE DEFAULT sysdate - 5/1440,
      p_dur_min IN NUMBER DEFAULT 5,
      p_sqlid   IN VARCHAR2 DEFAULT NULL,
      p_sid     IN VARCHAR2 DEFAULT NULL);
  -- send an email with attachment less than 32k
  /*  using utl_mail need to install some package ignore for now
  PROCEDURE send_email_attach(
  p_filename varchar2 ,
  p_dir varchar2 default 'DATA_PUMP_DIR'
  );
  */
  -- Display columns as rows
  PROCEDURE print_table(
      p_query    IN VARCHAR2,
      p_date_fmt IN VARCHAR2 DEFAULT 'dd-mon-yyyy hh24:mi:ss' );
  PROCEDURE mail_file(
      p_binary_file      VARCHAR2,
      p_to_name          VARCHAR2 DEFAULT 'teamdba@example.com' ,
      p_from_name        VARCHAR2 DEFAULT 'teamdba@example.com' ,
      p_subject          VARCHAR2 DEFAULT 'email file from server' ,
      p_message          VARCHAR2 DEFAULT 'file attached',
      p_oracle_directory VARCHAR2 DEFAULT 'DATA_PUMP_DIR' );
  -- Disply the partitions of tables  that have the maximum high_value
  PROCEDURE list_highest_partition;
  -- Drop partitions of time-based partitioned table by cut-off date
PROCEDURE drop_partition_by_cutoff(
	  p_owner      IN VARCHAR2 ,
	  p_table_name  IN  VARCHAR2 ,
	  p_cutoff_date IN DATE ,
	  p_is_interval IN CHAR DEFAULT 'Y',
	  p_is_drop     IN BOOLEAN DEFAULT true);

PROCEDURE impdp_table_network(p_schema in varchar2, p_tablename in varchar2, p_network_link in varchar2);
PROCEDURE impdp_table_network_sqlfile(p_schema in varchar2, p_tablename in varchar2, p_network_link in varchar2);

  FUNCTION db_version
    RETURN VARCHAR2;
  FUNCTION my_version
    RETURN VARCHAR2;
END;
/
