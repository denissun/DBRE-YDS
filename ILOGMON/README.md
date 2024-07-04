Intelligent Oracle Database Alert Log Monitoring Framework
==========================================================

# Overview

The framework is developed as an effort to make Oracle database alert logs easy to query, filter, and visualize.  It may be one of the necessary steps along the path to observability, which aims not only showing when and what something happens but also why. 

Oracle database instance alert log is an important source of data for proactive monitoring and troubleshooting. The alert log message consists of a message header line that is a timestamp string and a message body that can span several lines. In this framework, an error alert log message is defined as an alert log message with any message body lines starting with "ORA-", 'ERROR", 'WARNING" or "TNS-".

The following chart illustrates the key data flow in this framework:

![Alt text](/ILOGMON/img/ilogmon_dataflow.png "ILOGMON data flow")



# Description of each file  

## ext_alert_error.sh

The main program script to loop through each db instance defined in the db_alertlog.cfg file and pull recent alert log messages, execute the ilogmon_extract_alertlog.py Python script to extract error messages and load the messages into repository db

This script is run every 5 min from the cron, for example:

```
*/5 * * * * /opt/oracle/dba/monitor/extract_alert_log/ext_alert_error.sh > /tmp/ext_alert_error.out 2>&1
```

12 12 * * * /opt/oracle/dba/monitor/extract_alert_log/verify_alertlog.sh > /tmp/verify_alertlog.out 2>&1


##  ilogmon_extract_alertlog.py

Given a text file of alert log, extract those error message with error codes

Usage:

```

ilogmon_extract_alertlog.py --alertlog=<Alert Logfile> --logfile=<logfile> --tsfile=<tm_file> --sqlfile=<sqlfile> --instance_name <insance_name>  --tsformat 12.1 --host_name <host>

    --alertlog  alert log file
    --logfile   log file for the python program execution
    --tsfile    a file contians timestamp from which scan should start
    --sqlfile   a temp file save the insert sql statements
    --instance_name  Oracle database instance name
    --tsformat   alert log timestamp format   12.1 or 12.2
    --host_name  the server in which the alert log resides, we use "ssh host tail -500 <alertlog>" to get alert log text in a shell script

 Note:

    An error message includes timestamp and message body. A message body can have multiple lines.
    In the following alert log snippet, first line is timestamp, line two to seven is the message body


     ---
     2018-02-02T22:38:23.257279+00:00
     Errors in file /opt/oracle/product/diag/rdbms/rac1db/rac1db1/trace/rac1db1_ora_26214.trc:
     ORA-17503: ksfdopn:2 Failed to open file +DATA_APP1_RAC1DB/RAC1DB/PASSWORD/pwdrac1db.283.967069695
     ORA-27140: attach to post/wait facility failed
     ORA-27300: OS system dependent operation:pwportcr failed with status: 11
     ORA-27301: OS failure message: Resource temporarily unavailable
     ORA-27302: failure occurred at: sskgpwatt:2
     2018-02-02T22:38:24.209723+00:00
     Process P0QJ died, see its trace file
     ---
    working with python 3.6

```

## db_alertlog.cfg

   A configuration file that contains instance name, alert log file full path, timestamp format. 

## config.py

    A configuration file that contains username, password and connection info  for the repository Oracle database.

## verify_alertlog.sh

    A script used in the cron to monitor if the alert log exits or out-of-date on the target db servers.


## ilogmon_alert_log.sh

The script runs from a cron job that is set up on the repository database server. It reports alert log errors occurred in the last 10 min by sending email notifiction to DBAs, for example:

```
1,11,21,31,41,51 * * * * /opt/oracle/product/admin/monitor/ilogmon_alert_log.sh  >/tmp/ilogmon_alert_log.out 2>&1

```

## ilogon_daily_report.sh


```
0 11 * * * /opt/oracle/product/admintpsdb/monitor/ilogmon_daily_report.sh  >/tmp/ilogmon_daily_report.out 2>&1
```



# Database Objects

## Table: ILOGMON_ALERTLOG

This table is used to store alert log message error text for each monitored Oracle db instance.
The table definition is as show below:

    SQL>  desc ilogmon_alertlog;

    Name                                        Null?    Type
    ------------------------------------------- -------- ----------------------------
    ID                                          NOT NULL NUMBER
    INSTANCE_NAME                                        VARCHAR2(14)
    CREATE_TIME                                          DATE
    HOST_NAME                                            VARCHAR2(50)
    ERR_LOG                                              VARCHAR2(3000)
    ERR_TIME                                             DATE
    SER_LABL                                             NUMBER
    SER_PRED                                             NUMBER
    ALERT_TEXT_ID                                        VARCHAR2(13)

## Table: ilogmon_action_plan 

```
 SQL> desc ilogmon_action_plan
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 ALERT_TEXT_ID                                      VARCHAR2(13)
 SAMPLE_ERR_LOG                                     VARCHAR2(3000)
 ACTION_PLAN                                        CLOB
 LAST_UPDATED_TIME                                  DATE

```



## Table: ilogmon_ora_instances

```
 SQL> desc ilogmon_ora_instances
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 INSTANCE_NAME                             NOT NULL VARCHAR2(20)
 HOST_NAME                                 NOT NULL VARCHAR2(30)
 DBA                                                VARCHAR2(50)
 EMAIL                                              VARCHAR2(100)
 APP_CODE                                           VARCHAR2(10)
 ```
                                 
## Table: ilogmon_daily_report

```
 SQL> desc ilogmon_daily_report
 Name                                      Null?    Type
 ----------------------------------------- -------- ----------------------------
 INSTANCE_NAME                             NOT NULL VARCHAR2(12)
 HOST_NAME                                 NOT NULL VARCHAR2(30)
 ALERT_TEXT_ID                             NOT NULL VARCHAR2(13)
 ERR_LOG                                            VARCHAR2(3000)
 ERR_TIME                                           DATE
```


## Package: ILOGMON

This package includes procedures and functions to manipulate data in the ilogmon tables:

### procedures and functions

    SQL> desc ilogmon

    FUNCTION COMPUTE_SQL_ID RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    SQL_TEXT                       CLOB                    IN
    FUNCTION GET_ACTION_PLAN RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_ALERT_TEXT_ID                VARCHAR2                IN
    P_ALERT_TEXT                   VARCHAR2                IN
    FUNCTION GET_ALERT_TEXT_ID RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    ALERT_TEXT                     CLOB                    IN
    P_HOSTNAME                     VARCHAR2                IN
    P_INSTNAME                     VARCHAR2                IN
    PROCEDURE GET_RECENT_ALERT
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_MIN                          NUMBER                  IN
    FUNCTION INSTANCE_INFO RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_INSTANCE_NAME                VARCHAR2                IN
    FUNCTION MASK_STRING RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_TEXT                         VARCHAR2                IN
    P_STRING                       VARCHAR2                IN
    P_RSTRING                      VARCHAR2                IN
    PROCEDURE NOTIFY_CHECK_BLACKOUT
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_INSTANCE_NAME                VARCHAR2                IN
    P_HOST_NAME                    VARCHAR2                IN
    P_ALERT_TEXT_ID                VARCHAR2                IN
    P_ERR_LOG                      VARCHAR2                IN
    MSG_ARR                        MSGS                    IN
    P_RECURRING_COUNT              NUMBER                  IN
    FUNCTION RECURRING_COUNT RETURNS NUMBER(38)
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_INSTANCE_NAME                VARCHAR2                IN
    P_HOST_NAME                    VARCHAR2                IN
    P_ALERT_TEXT_ID                VARCHAR2                IN
    FUNCTION REMOVE_DIGITS RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_TEXT                         VARCHAR2                IN
    FUNCTION TRANSFORM_TEXT RETURNS VARCHAR2
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_TEXT                         VARCHAR2                IN
    P_HOSTNAME                     VARCHAR2                IN
    P_INSTNAME                     VARCHAR2                IN
    PROCEDURE UPDATE_ALERT_TEXT_ID
    PROCEDURE UPDATE_BLACKOUT_UNTIL
    Argument Name                  Type                    In/Out Default?
    ------------------------------ ----------------------- ------ --------
    P_INSTANCE_NAME                VARCHAR2                IN
    P_HOST_NAME                    VARCHAR2                IN
    P_ALERT_TEXT_ID                VARCHAR2                IN
    P_ERR_LOG                      VARCHAR2                IN
    P_RECURRING_COUNT              NUMBER                  IN
    P_MIN                          NUMBER(38)              IN


### source code file:  ilogmon_pks.sql ilogmon_pkb.sql


# Some Features of the framework

## Centralized dashboard for recent alert log event message, action plan and blackout schedule reporting 

DBAETS is a web applicaiton developed using Python Flask Framework. It includes UI compoments to allow users to browse the alert log error messages and update action plan etc more conveniently.

Example screenshots :


### Fig. 1 Recent messages

![Alt text](/ILOGMON/img/ilogmon_1.png "fig 1")


### Fig. 2 action plans

![Alt text](/ILOGMON/img/ilogmon_2.png "fig 2")



### Fig. 3 count and blackout notification info

![Alt text](/ILOGMON/img/ilogmon_3.png "fig 3")

## Automatic notification blackout strategy based on the past occurrence of the event.

   for examples:

   occurrence 1-3 times, send notification immediately

   occurrence 4-15 times, blackout for 1 day

   occurrence  > 16 times, blackout for 1 week

## Alert log  message text is normalized to generate a unique alert_text_id for each message.


## Notification is tied with the available action plan through alert_text_id

An example alert email sent to dba team


![Alt text](/ILOGMON/img/ilogmon_4.png "fig 4")