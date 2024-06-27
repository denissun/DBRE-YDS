CREATE OR REPLACE
PACKAGE proactive
IS
  /**
  * ========================================================================
  * Project:         Database monitoring
  * Description:     This is the package for procedures that proactivly
  *                  monitor the database. If there is a problem then we can
  *                  email a notification and or save message in database
  * DB impact:       minimal
  *
  * ------------------------------------------------------------------------
  */
  -- alert when tablespace usage above thresholds
  PROCEDURE check_tablespace(
      P_FREE_MB          NUMBER DEFAULT 10000,
      P_HUGE_SIZE        NUMBER DEFAULT 1000000,
      P_BIG_SIZE         NUMBER DEFAULT 200000,
      P_MEDIUM_SIZE      NUMBER DEFAULT 20000,
      P_THRESHOLD_HUGE   NUMBER DEFAULT 99,
      P_THRESHOLD_BIG    NUMBER DEFAULT 98,
      P_THRESHOLD_MEDIUM NUMBER DEFAULT 93,
      P_THRESHOLD_STD    NUMBER DEFAULT 88);
  PROCEDURE config_check_tablespace(
      p_tablespace IN VARCHAR2 DEFAULT NULL,
      p_option VARCHAR2 DEFAULT 'l');
  -- find all sqls running longer than cerntain seconds
  PROCEDURE long_running_sqls(
      p_running_secs IN NUMBER DEFAULT 300);
  -- add or remove a SQL to or from checking by long_running_sqls
  PROCEDURE config_long_running_sqls(
      p_sqlid IN VARCHAR2 DEFAULT NULL,
      p_option VARCHAR2 DEFAULT 'l');
  -- show sqls that have total buffer gets above threshold in the most
  -- recent AWR snapshot interval 
  PROCEDURE sql_total_gets(
      p_total_gets IN NUMBER DEFAULT 2000000);
  -- add or remove a SQL to or from total gets monitoring
  PROCEDURE config_sql_total_gets(
      p_sqlid IN VARCHAR2 DEFAULT NULL,
      p_option VARCHAR2 DEFAULT 'l');
  PROCEDURE check_blockers(
      p_mins NUMBER DEFAULT 1);
  PROCEDURE check_waitevent(
      p_percent IN NUMBER DEFAULT 15,
      p_mins    IN NUMBER DEFAULT 15 );
  PROCEDURE config_waitevent(
      p_event IN VARCHAR2 DEFAULT NULL,
      p_option VARCHAR2 DEFAULT 'l');
  PROCEDURE config(
      p_cname  in varchar default null,
      p_cvalue in varchar default null,
      p_option VARCHAR2 DEFAULT 'l');

  PROCEDURE  gg_latency_alert(p_mins in number  default 5, 
	         p_latency_tab in varchar2 default 'GG_LATENCY');
END;
/
