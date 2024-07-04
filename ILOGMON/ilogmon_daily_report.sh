#!/bin/bash
#

. ~/.bash_profile

sqlplus / <<EOF
spool /tmp/ilogmon_daily.log
set serveroutput on;
set echo off

DECLARE
   msg_arr db_admin.notification.msgs;
   msg_arr_i pls_integer :=0;
   l_msg varchar2(2000);
   l_recurring_count integer;
   l_recip   db_admin.notification.recipients := db_admin.notification.recipients(); 
BEGIN
   l_recip.extend(1);
   l_recip(1) := 'denissun@example.com';


   FOR rec in ( select instance_name, host_name, alert_text_id, err_log, err_time
	from
	(
		select instance_name, host_name, alert_text_id, err_log,  err_time, 
		rank() over (
		    partition by instance_name, host_name, alert_text_id
		    order by err_time desc
		) as r
		from apex_mon.ILOGMON_ALERTLOG 
		where err_time between sysdate-25/24 and sysdate - 1/24
	) 
	where r=1
   )
   LOOP
       msg_arr_i := 0;
       dbms_output.put_line('-----------------------------------');
       dbms_output.put_line(rec.instance_name);
       dbms_output.put_line(rec.host_name);
       dbms_output.put_line(rec.err_time);
       dbms_output.put_line(rec.alert_text_id);
       dbms_output.put_line(rec.err_log);
       dbms_output.put_line('-----------------------------------');

       l_msg := '---------------------------------' || chr(10) ||
                 'INSTANCE_NAME  : ' || rec.instance_name || chr(10) ||
                 'HOST_NAME      : ' || rec.host_name || chr(10) ||
                 'EVENT_TIMESTAMP: ' || to_char(rec.err_time, 'YYYY-MM-DD HH24:MI:SS') || chr(10) ||
                 'ALERT_TEXT_ID  : ' || '<a href="http://dbaets.example.com:8081/oem/alert_action_show?id='||rec.alert_text_id ||'">' || rec.alert_text_id ||'</a>' || chr(10); 

       msg_arr_i := msg_arr_i + 1;
       msg_arr(msg_arr_i) := l_msg;
       msg_arr_i := msg_arr_i + 1;
       msg_arr(msg_arr_i) := rec.err_log ;

       l_recurring_count := apex_mon.ilogmon.recurring_count(rec.instance_name, rec.host_name, rec.alert_text_id);
       msg_arr_i := msg_arr_i + 1;
       msg_arr(msg_arr_i) := '!!! This type of alert message occurred ' || l_recurring_count || ' times in the past 30 day!';
       msg_arr_i := msg_arr_i + 1;
       msg_arr(msg_arr_i) := 'ACTION PLAN: ' || apex_mon.ilogmon.get_action_plan(rec.alert_text_id, rec.err_log) || chr(10) ||  '<a href="http://dbaets.example.com:8081/oem/alert_action_show?id='||rec.alert_text_id ||'"> UPDATE' ||'</a>'  ;
       db_admin.notification.notify (
            instance_name_in => rec.instance_name || '_' || rec.host_name 
            ,msgs_in          => msg_arr 
            ,subject_in       => 'Daily Report - DB ALERT LOG alert'
            ,result_in        => null
            ,email_p          => true 
            ,db_p             => true
            ,recip            => l_recip 
            ,dbaets_p => false);
  END LOOP;

END;
/
spool off
exit;
EOF
