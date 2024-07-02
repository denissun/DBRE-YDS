
CREATE TABLE ALERTS
   (    EVENT_DATE DATE,
        EVENT_TYPE VARCHAR2(100) NOT NULL,
        RESULT NUMBER,
        RESULT_TEXT VARCHAR2(4000),
        INSTANCE_NAME VARCHAR2(16)
   );


CREATE TABLE HC_HISTORY
 (    "EVENT_TIME" DATE,
      "EVENT_TYPE" VARCHAR2(100),
      "RESULT_TEXT" VARCHAR2(150),
      "RESULT_NUMBER" NUMBER,
      "INSTANCE_NAME" VARCHAR2(16),
      "HOST_NAME" VARCHAR2(16)
 ); 




create table configs
( cname varchar2(50),
  cvalue varchar2(50)
);

create unique index configs_pk on configs(cname, cvalue);


-- example: excluding undo tablepsace from monitoring
-- usually procedures are provided to modify the configs table
insert into configs values ('TABLESPACE', 'UNDOTBS');
insert into configs values ('TABLESPACE', 'UNDOTBS1');
insert into configs values ('TABLESPACE', 'UNDOTBS2');
insert into configs values ('TABLESPACE', 'UNDOTBS3');
insert into configs values ('TABLESPACE', 'UNDOTBS4');
insert into configs values ('SENDER', 'oracle@ei0frdspd01.mycompany.com');
-- insert into configs values ('RECIP', 'cmb.ops.oracle.dba.irs@mycompany.com');
insert into configs values ('RECIP', 'myname@mycompany.com');
insert into configs values ('SMTP_SERVER', 'smtp.mycompany.com');
insert into configs values ('SMTP_SERVER_PORT', '25');


commit;

