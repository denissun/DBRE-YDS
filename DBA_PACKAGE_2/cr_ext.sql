
Create or replace directory alert_dir1 as '/apps/opt/oracle/admin/icondb/diag/rdbms/icondb/icondb/trace';

 CREATE TABLE "ALERT_FILE1_EXT"
(    "MSG_LINE" VARCHAR2(1000))
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
( MSG_LINE (1:1000) CHAR(1000))
)
LOCATION
( 'alert_icondb.log')
)
REJECT LIMIT UNLIMITED
/

