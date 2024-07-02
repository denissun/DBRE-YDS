CREATE OR REPLACE
PACKAGE "ALERT_FILE"
IS
  /**
  * ========================================================================<br/>
  * Project:         Alert file<br/>
  * Description:     Monitor and manage the alert file<br/>
  * DB impact:       reads exernal table<br/>
  * Commit inside:   no<br/>
  * Rollback inside: no<br/>
  * ------------------------------------------------------------------------<br/>
  */
  PROCEDURE monitor_alert_file(
      p_external_tab IN VARCHAR2 DEFAULT 'ALERT_FILE_EXT',
      p_dir          IN VARCHAR2 DEFAULT 'ALERT_DIR');
  PROCEDURE config_monitor_alert_file(
      p_error  IN VARCHAR2 DEFAULT NULL,
      p_option IN VARCHAR2 DEFAULT 'l');
  PROCEDURE monitor_ggserr(
      p_external_tab IN VARCHAR2 DEFAULT 'GGSERR_LOG_EXT',
      p_dir          IN VARCHAR2 DEFAULT 'GGSERR_DIR');
  PROCEDURE config_monitor_ggserr(
      p_error  IN VARCHAR2 DEFAULT NULL,
      p_option IN VARCHAR2 DEFAULT 'l');

  PROCEDURE update_skip_count(
	    p_external_tab IN VARCHAR2 DEFAULT 'ALERT_FILE_EXT',
	    p_count        IN NUMBER DEFAULT 0,
	    reset BOOLEAN DEFAULT false);
END;
/
