#! /u01/app/venv_python36/bin/python

"""
file: ilogmon_extract_alertlog.py

Given a text file of alert log, extract those error message with error codes

Usage:

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

"""

import argparse
import logging
from datetime import datetime, timedelta
import re
import subprocess as sp
from config import Config


def checkDBAlertErrors(alertlog, tsformat, start_ts):
    """ Find the error message in the db alert log
        Arguments:
            alerlog - db  alert log file name
            start_ts - datetime type: timestemp from which the crs log entries are searched
        Returns:
            alert_errors - a list of dictionary object eg. {'ts':'2020-03-28 02:12:27.478', 'msg': 'error message text'}
            prev_str_ts - the last timestamp in the alert log file
            
    """ 
    prev_str_ts=''
    prev_msg=''
    dt_ts = datetime.now()
    prev_dt_ts=start_ts
     
    if tsformat=='12.2' :
        tspattern=r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}'
    else:
        tspattern=r'^\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2}\ \d{4}'

    # print (tspattern)

    alert_errors=[]

    with open(alertlog, 'r') as file: 
        while True: 
            line = file.readline() 
            if not line: 
                #if prev_msg and re.search(r'ORA-|^ERROR|^WARNING|TNS-' , prev_msg, re.IGNORECASE ):
                if prev_msg and re.search(r'^ORA-|^ERROR|^WARNING|^TNS-' , prev_msg, re.IGNORECASE ):
                    if dt_ts > start_ts :
                        d={}
                        d['ts']=prev_str_ts
                        d['msg']=prev_msg
                        if prev_dt_ts > start_ts:
                             alert_errors.append(d)
                break

            # check if the current line is a timestamp line
            if tsformat=='12.2' :
                str_ts=line[0:26]
            else:
                str_ts=line[0:24]

            # it is a timestampe line
            if  re.search(tspattern , str_ts):  
                # str_ts format '2020-03-31T17:00:52.596175'
                #print (str_ts + " is matching ts pattern ")
                if tsformat=='12.2':
                    dt_ts  = datetime.strptime(str_ts[:-7], '%Y-%m-%dT%H:%M:%S')
                else:
                    dt_ts  = datetime.strptime(str_ts, '%a %b %d %H:%M:%S %Y')
                
                if dt_ts > start_ts :
                    print('~~~~~~  timestamp in alert log greater than start checking timestamp ')
                    print(dt_ts)
                    print(start_ts)

                    # The current message text ends, check if it is an erorr/warning or problem message
                    if prev_msg and  re.search(r'ORA-|^ERROR|^WARNING|TNS-' , prev_msg, re.IGNORECASE ):
                        d={}
                        d['ts']=prev_str_ts
                        d['msg']=prev_msg
                        # print ("### error msg : " + prev_msg)
                        # to avoid duplicat entry, the message with the timestamp = start_ts already added in the previous scan
                        # the current scan starting from the "start_ts", so it should skip the message with timestampe=start-ts
                        if prev_dt_ts > start_ts:
                            alert_errors.append(d)

                # clear the previous message text
                prev_str_ts=str_ts
                prev_dt_ts = dt_ts
                prev_msg=''

            # if it is not a timestamp line, we accumulate the line to message text
            else: 
                prev_msg = prev_msg + line 
    return alert_errors, prev_str_ts

def insert_ilogmon_alertlog(alert_errors,sqlfile,hostname,dbuser,dbpass,dbname,instance_name, tsformat):
    """ Insert error message to a table in an Oracle database table
        Arguments:
            alert_errors  : a list of dictionary  ts:  msg:
            sqlfile     : a file save sqlplus insert statements from crs_errors
            hostname    : server name in  which this program runs
            dbuser      : oracle db user account
            dbuser      : oacle db user password
            dbname      : tns entry name
            instance_name : Oracle database instance name
        Returns:  None 
    """ 

    # contruct a sql script
    with open(sqlfile, 'w') as file:
        file.write("set sqlblanklines on define off echo on\n\n") 
        spoolfile= "/tmp/" + instance_name + ".spool"
        file.write("spool " + spoolfile + "  \n") 
        for data in alert_errors:
           try:
               # timestamp format 2018-02-02T22:32:05.918516
               if tsformat == '12.2' :
                  err_tm = data['ts'][:-7].replace('T',' ')
                  sqlstatement = "insert into APEX_MON.ILOGMON_ALERTLOG (instance_name, create_time, host_name, err_time, err_log) values('{0}',sysdate,'{1}',to_date('{2}','YYYY-MM-DD HH24:MI:SS'),\n".format(instance_name, hostname, err_tm)
               else:  
                  err_tm = data['ts']
                  sqlstatement = "insert into APEX_MON.ILOGMON_ALERTLOG (instance_name, create_time, host_name, err_time, err_log) values('{0}',sysdate,'{1}',to_date('{2}','Dy Mon DD HH24:MI:SS YYYY'),\n".format(instance_name, hostname, err_tm)

               err_msg = data['msg'][0:3000] 
           except:
                continue 

           file.write(sqlstatement)
           file.write("q'~")
           file.write(err_msg)
           file.write("~');\n")
           file.write("-------------------------------\n\n")


        file.write("commit;\n")
        file.write("spool off;\n")
        file.write("exit;\n")

    # database usename and password
    logging.info("Running the .sql file on the database.")
    connectionString='{0}/"{1}"@{2}'.format(dbuser,dbpass,dbname)
    sqlCommand = b'@' + str.encode(sqlfile)
    logging.info("conn: %s, sqlcommand: %s\n" % (connectionString,sqlCommand))

    try:
       sess = sp.Popen(['sqlplus', '-S', connectionString], stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE)
       sess.stdin.write(sqlCommand)
       logging.info("Inserting the data into the ilogmon_alertlog table OK.")
       return sess.communicate()
    except:
       logging.info("Something went wrong in Inserting the data into the ilogmon_alertlog table.")
       print("Something went wrong in Inserting the data into the ilogmon_alertlog table\n ")
       return False

if (__name__ == '__main__'):

    parser = argparse.ArgumentParser(
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description='''\
                ilogmon_extract_alertlog - Extract error messages from Oracle database alert log   
                         - Version 1.0 by Yu (Denis) Sun
                                 created: 25-Aug-2020
                                 updated: 25-Aug-2020
                usage:  ilogmon_extract_alertlog.py --alertlog temp_alert.log --tsfile=temp.tm --logfile temp.log --sqlfile temp.sql --instance_name tempinstance --host_name testhost --tsformat 12.1
               ''')     

    parser.add_argument("--alertlog", help="input alertlog file ")
    parser.add_argument("--logfile",  help="log file for the python program execution")
    parser.add_argument("--tsfile", help="a file contians timestamp from which scan should start") 
    parser.add_argument("--instance_name", help="Oracle database instance name") 
    parser.add_argument("--host_name", help="the server in which the alert log resides") 
    parser.add_argument("--tsformat", help="alert log timestamp format   12.1 or 12.2")
    parser.add_argument("--sqlfile", help="a temp file save the insert sql statements")

    args = parser.parse_args() 

    alertlogfile=args.alertlog
    logfile=args.logfile
    tsfile = args.tsfile 
    insertsqlfile = args.sqlfile 
    instance_name = args.instance_name 
    tsformat = args.tsformat 
    hostname=args.host_name
    
    
    logging.basicConfig(filename='{0}'.format(args.logfile), filemode='w', format='[%(asctime)s] : %(message)s',level=logging.INFO)
    #
    # note: time offset in the alert log  wrt eastenr time may need to be coniser
    #
    str_ts_now = datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S')
    logging.info("Starting the execution of script: " + str_ts_now  )

    
    try:
        with open(tsfile, 'r') as file:
            lines=file.readlines() 
            s=lines[0].strip("\n")
            if tsformat=='12.2':
                start_ts  = datetime.strptime(s[:-7], '%Y-%m-%dT%H:%M:%S')
            else:
                start_ts  = datetime.strptime(s, '%a %b %d %H:%M:%S %Y')

        logging.info("set start timestamp from the tsfile is good")
        print ('~~~~~ read from tm fle, start_ts is')
        print (start_ts)
    except:
        logging.info("Not able to set start timestamp from the tsfile, set it to be two hour ago ")
        start_ts = datetime.now() - timedelta(hours = 2)
        s=datetime.strftime(start_ts, '%Y-%m-%d %H:%M:%S')

    logging.info("Obtain the error message, search from " + s )

    logging.info("Timestamp FORMAT: " + tsformat )

    print ('~~~~~ before call checkDBAAlertErrors, start_ts is')
    print (start_ts)
    alert_err, str_ts_last = checkDBAlertErrors(alertlogfile,tsformat, start_ts)

    print ("////////////  print out error message  ///////")
    for e in alert_err:
        print (e)

    dbuser=Config.dbuser 
    dbname=Config.dbname  
    dbpass=Config.dbpass

    insert_ilogmon_alertlog(alert_err,insertsqlfile,hostname,dbuser,dbpass,dbname, instance_name, tsformat)

    try:
        with open(tsfile, 'w') as file:
            file.write(str_ts_last) 
            logging.info("Write last timestamp to the tsfile:  " + tsfile)
    except:
        logging.info("Problem write last timestamp to the tsfile:  " + tsfile)

    logging.info("The execution of script finished")
