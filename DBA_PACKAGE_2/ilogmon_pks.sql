create or replace package ilogmon
is
 /**
  *=======================================================================
  * NAME
  *    ilogmon_pks.sql - package specification
  *
  * DESCRIPTION
  *    Intelligent Alert Log Monitoring System
  *    Define a package used to  transform oracle alert log text data into a unique text_id 
  *
  * NOTES
  * 
  *    Denpendency :  package :  notification package
  *                   table   :  ilogmon_alertlog (apex_db_alertlog)
  *                              ilogmon_action_plan (alert_msg_action_plan)
                                 ilogmon_ora_instances
                                 ilogmon_daily_report
  * MODIFIED ( MM/DD/YY)
  *
  *     Denis  08/10/20  - creation   v1.0
  *
  *----------------------------------------------------------------------
  */


FUNCTION remove_digits(p_text in varchar2) 
RETURN VARCHAR2;

FUNCTION mask_string( p_text in varchar2 , p_string in varchar2, p_rstring in varchar2) 
RETURN VARCHAR2;

FUNCTION transform_text( p_text in varchar2 , p_hostname in varchar2, p_instname in varchar2) 
RETURN VARCHAR2;

FUNCTION compute_sql_id (sql_text IN CLOB)
RETURN VARCHAR2;

FUNCTION get_alert_text_id (alert_text IN CLOB, p_hostname in varchar2, p_instname in varchar2)
RETURN VARCHAR2;

FUNCTION recurring_count(p_instance_name in varchar2, p_host_name in varchar2,  p_alert_text_id in varchar2)
RETURN INTEGER;

FUNCTION get_action_plan(p_alert_text_id varchar2, p_alert_text varchar2)
RETURN VARCHAR2;

PROCEDURE update_blackout_until(p_instance_name varchar2, p_host_name varchar2,  p_alert_text_id varchar2, p_err_log varchar2,p_recurring_count number, p_min INTEGER); 

PROCEDURE update_alert_text_id;
PROCEDURE notify_check_blackout(p_instance_name varchar2, p_host_name varchar2, p_alert_text_id varchar2, p_err_log varchar2, msg_arr db_admin.notification.msgs, p_recurring_count number);
PROCEDURE get_recent_alert(p_min in number);

END;
/
