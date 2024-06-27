CREATE OR REPLACE
PACKAGE "NOTIFICATION"
IS
  /**
  * ========================================================================<br/>
  * Project:         Database monitoring<br/>
  * Description:     Send email message andor save message in database<br/>
  * DB impact:       minimal<br/>
  * Commit inside:   the save_in_db procedure commits<br/>
  * Rollback inside: no<br/>
  * ------------------------------------------------------------------------<br/>
  */
type msgs
IS
  TABLE OF VARCHAR2(4000) INDEX BY binary_integer;
type recipients
IS
  TABLE OF VARCHAR2(255) ;
PROCEDURE notify(
      instance_name_in IN VARCHAR2,
      msgs_in          IN msgs,
      subject_in       IN VARCHAR2 DEFAULT NULL,
      result_in        IN NUMBER DEFAULT NULL,
      email_p          IN BOOLEAN,
      db_p             IN BOOLEAN,
      recip recipients DEFAULT NULL,
      dbaets_p         IN BOOLEAN DEFAULT false);

-- save message for an event in the alerts table
PROCEDURE save_msg (
	p_msg in varchar2,
	p_event in varchar2 default 'DEBUG' );

END;
/
