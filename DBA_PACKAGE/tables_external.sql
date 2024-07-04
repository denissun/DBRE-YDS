

-- external table for alert log
-- for single instance database

select name from v$database;
show user;

prompt have you used the directories and alert file names specific to your environment?
prompt if not hit ctrl - c otherwise any key to continue
pause;

create or replace directory alert_dir
as '/apps/opt/oracle/diag/rdbms/obilldb/obilldb/trace';


CREATE TABLE "ALERT_FILE_EXT"
 (    "MSG_LINE" VARCHAR2(1000)
 )
 ORGANIZATION EXTERNAL
  ( TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "ALERT_DIR"
    ACCESS PARAMETERS
    ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
    )
    LOCATION
     ( 'alert_obilldb.log')
  )
 REJECT LIMIT UNLIMITED
/

-- external table for OGG ggserr.log


create or replace directory ggserr_dir as '/apps/opt/oracle/product/goldengate/10.2.0';



CREATE TABLE "GGSERR_LOG_EXT"
 (    "MSG_LINE" VARCHAR2(1000)
 )
 ORGANIZATION EXTERNAL
  ( TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "GGSERR_DIR"
    ACCESS PARAMETERS
    ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
    )
    LOCATION
     ( 'ggserr.log')
  )
 REJECT LIMIT UNLIMITED
/



-- ignore the below line
set doc off
doc


-- example 
-- modify according to your specific system

Create or replace directory alert_dir1 as '/opt/oracle/product/diag/rdbms/omrdb/omrdb1/trace';
Create or replace directory alert_dir2 as '/opt/oracle/product/diag/rdbms/omrdb/omrdb2/trace';

CREATE TABLE "ALERT_FILE1_EXT"
 (    "MSG_LINE" VARCHAR2(1000)
 )
 ORGANIZATION EXTERNAL
  ( TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "ALERT_DIR1"
    ACCESS PARAMETERS
    ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
    )
    LOCATION
     ( 'alert_omrdb1.log')
  )
 REJECT LIMIT UNLIMITED
/

CREATE TABLE "ALERT_FILE2_EXT"
 (    "MSG_LINE" VARCHAR2(1000)
 )
 ORGANIZATION EXTERNAL
  ( TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "ALERT_DIR2"
    ACCESS PARAMETERS
    ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
    )
    LOCATION
     ( 'alert_omrdb2.log')
  )
 REJECT LIMIT UNLIMITED
/


exit;


-- for RAC 
-- create directory and external table for each instance

Create or replace directory alert_dir1 as '/opt/oracle/product/diag/rdbms/testdba/testdba1/trace';
Create or replace directory alert_dir2 as '/opt/oracle/product/diag/rdbms/testdba/testdba2/trace';
Create or replace directory alert_dir3 as '/opt/oracle/product/diag/rdbms/testdba/testdba3/trace';
Create or replace directory alert_dir4 as '/opt/oracle/product/diag/rdbms/testdba/testdba4/trace';


CREATE TABLE "ALERT_FILE1_EXT"
 (    "MSG_LINE" VARCHAR2(1000)
 )
 ORGANIZATION EXTERNAL
  ( TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "ALERT_DIR1"
    ACCESS PARAMETERS
    ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
    )
    LOCATION
     ( 'alert_testdba1.log')
  )
 REJECT LIMIT UNLIMITED
/

CREATE TABLE "ALERT_FILE2_EXT"
 (    "MSG_LINE" VARCHAR2(1000)
 )
 ORGANIZATION EXTERNAL
  ( TYPE ORACLE_LOADER
    DEFAULT DIRECTORY "ALERT_DIR2"
    ACCESS PARAMETERS
    ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
    )
    LOCATION
     ( 'alert_testdba2.log')
  )
 REJECT LIMIT UNLIMITED
/





-- external table for gginfo.txt used in HISTORY pacakge
-- even we don't have GG this table shold be creaed to make sure the package can compile for now
-- in the future may change this

/*
create or replace directory TMPDIR as '/tmp';


 

  CREATE TABLE "GGINFO_EXT"
   (    "MSG_LINE" VARCHAR2(1000)
   )
   ORGANIZATION EXTERNAL
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY "TMPDIR"
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE CHARACTERSET US7ASCII
      nobadfile nologfile nodiscardfile
      skip 0
      READSIZE 1048576
      FIELDS LDRTRIM
      REJECT ROWS WITH ALL NULL FIELDS
      (
        MSG_LINE (1:1000) CHAR(1000)
      )
        )
      LOCATION
       ( 'gginfo.txt'
       )
    )
   REJECT LIMIT UNLIMITED ;


*/

