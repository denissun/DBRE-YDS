CREATE OR REPLACE
PACKAGE "HISTORY"
IS
  /**
  * ========================================================================<br/>
  * Dependency
  *
  * hc_history 
  * ------------------------------------------------------------------------<br/>
  */

PROCEDURE do_hc (p_check_gg boolean default false);
FUNCTION  get_hc_email_recip return varchar2;
PROCEDURE config_hc_email( p_email IN VARCHAR2 DEFAULT NULL,
		            p_option VARCHAR2 DEFAULT 'l');

END;
/
