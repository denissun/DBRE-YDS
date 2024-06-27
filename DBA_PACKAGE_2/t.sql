
create or replace directory ggserr_dir as '/apps/opt/oracle/grid/acfsmounts/ogg_ogg1/product/11.2.1';



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



