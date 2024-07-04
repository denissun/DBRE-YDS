CREATE or replace PACKAGE BODY ilogmon IS

  FUNCTION remove_digits ( p_text IN varchar2) RETURN varchar2 IS
    l_text varchar2(3000);
  BEGIN
     l_text :=lower(translate(p_text,'a0123456789', 'a'));
     RETURN l_text;
  END remove_digits;

  FUNCTION mask_string( p_text in varchar2, p_string in varchar2, p_rstring in varchar2) RETURN VARCHAR2 IS
     l_text varchar2(3000);
  BEGIN
     l_text := replace(p_text, p_string, p_rstring);
     return l_text;
  end mask_string;

   FUNCTION transform_text( p_text in varchar2 , p_hostname in varchar2, p_instname in varchar2) 
       RETURN VARCHAR2
   IS
       l_text varchar2(3000);
   BEGIN
       -- mask SCN -  SCN: 0x0e93.f872e608
       l_text := REGEXP_REPLACE(p_text, 'SCN: 0x[0-9a-z.]{13}', 'SCN: 0xaaaaaaaaaaaaa');
       -- mask path
       -- +DATA/testdb2/onlinelog/group_1.303.976792193
       -- /opt/oracle/product/diag/rdbms/testdb/testdb1/trace/testdb1_ora_30865.trc
       --
       l_text := REGEXP_REPLACE(l_text,  '[/+](\S+/)+\S+\.\S+', '/path/to/filename');
       l_text := remove_digits(l_text);
       -- mask host_name and instance_name
       l_text := mask_string(l_text, remove_digits(p_hostname), 'hostname');
       l_text := mask_string(l_text, remove_digits(p_instname), 'instname');
       return l_text;
   END transform_text;

--- from: https://carlos-sierra.net/2013/09/12/function-to-compute-sql_id-out-of-sql_text/
   FUNCTION compute_sql_id (sql_text IN CLOB)
   RETURN VARCHAR2 IS
      BASE_32 CONSTANT VARCHAR2(32) := '0123456789abcdfghjkmnpqrstuvwxyz';
      l_raw_128 RAW(128);
      l_hex_32 VARCHAR2(32);
      l_low_16 VARCHAR(16);
      l_q3 VARCHAR2(8);
      l_q4 VARCHAR2(8);
      l_low_16_m VARCHAR(16);
      l_number NUMBER;
      l_idx INTEGER;
      l_sql_id VARCHAR2(13);
   BEGIN
 l_raw_128 := /* use md5 algorithm on sql_text and produce 128 bit hash */
 SYS.DBMS_CRYPTO.hash(TRIM(CHR(0) FROM sql_text)||CHR(0), SYS.DBMS_CRYPTO.hash_md5);
 l_hex_32 := RAWTOHEX(l_raw_128); /* 32 hex characters */
 l_low_16 := SUBSTR(l_hex_32, 17, 16); /* we only need lower 16 */
 l_q3 := SUBSTR(l_low_16, 1, 8); /* 3rd quarter (8 hex characters) */
 l_q4 := SUBSTR(l_low_16, 9, 8); /* 4th quarter (8 hex characters) */
 /* need to reverse order of each of the 4 pairs of hex characters */
 l_q3 := SUBSTR(l_q3, 7, 2)||SUBSTR(l_q3, 5, 2)||SUBSTR(l_q3, 3, 2)||SUBSTR(l_q3, 1, 2);
 l_q4 := SUBSTR(l_q4, 7, 2)||SUBSTR(l_q4, 5, 2)||SUBSTR(l_q4, 3, 2)||SUBSTR(l_q4, 1, 2);
 /* assembly back lower 16 after reversing order on each quarter */
 l_low_16_m := l_q3||l_q4;
 /* convert to number */
 SELECT TO_NUMBER(l_low_16_m, 'xxxxxxxxxxxxxxxx') INTO l_number FROM DUAL;
 /* 13 pieces base-32 (5 bits each) make 65 bits. we do have 64 bits */
 FOR i IN 1 .. 13
 LOOP
 l_idx := TRUNC(l_number / POWER(32, (13 - i))); /* index on BASE_32 */
 l_sql_id := l_sql_id||SUBSTR(BASE_32, (l_idx + 1), 1); /* stitch 13 characters */
 l_number := l_number - (l_idx * POWER(32, (13 - i))); /* for next piece */
 END LOOP;
 RETURN l_sql_id;
END compute_sql_id;

FUNCTION get_alert_text_id (alert_text IN CLOB, p_hostname in varchar2, p_instname in varchar2)
   RETURN VARCHAR2
IS
begin
   return compute_sql_id(transform_text(alert_text, p_hostname, p_instname));
end get_alert_text_id;

PROCEDURE update_alert_text_id
IS
BEGIN
   for rec in (select * from ilogmon_alertlog where alert_text_id is null and rownum <=10)
   loop
      -- dbms_output.put_line(rec.err_log);
      update ilogmon_alertlog set alert_text_id = get_alert_text_id(rec.err_log, rec.host_name, rec.instance_name) 
      where id =rec.id;
   end loop;
END update_alert_text_id;

FUNCTION recurring_count(p_instance_name in varchar2, p_host_name in varchar2,  p_alert_text_id in varchar2)
RETURN INTEGER
IS
   l_occurence_count number :=0;
BEGIN
   select count(*) into l_occurence_count 
      from ilogmon_alertlog  
      where instance_name=p_instance_name 
       and host_name=p_host_name
       and alert_text_id = p_alert_text_id 
       and create_time > sysdate -30;

   return l_occurence_count;
END recurring_count;

FUNCTION get_action_plan(p_alert_text_id varchar2, p_alert_text varchar2)
RETURN VARCHAR2
IS
    l_action_plan varchar2(4000);
BEGIN
    
   BEGIN
      select action_plan into l_action_plan from ilogmon_action_plan
      where alert_text_id = p_alert_text_id;

   EXCEPTION
      WHEN NO_DATA_FOUND THEN 
          dbms_output.put_line('no data found - action plan is not available');
          insert into ilogmon_action_plan(alert_text_id, sample_err_log) values (p_alert_text_id, p_alert_text);
          commit;
      WHEN OTHERS THEN
        dbms_output.put_line('others - failed to get action plan');
   END;

   if l_action_plan is null
   then
        dbms_output.put_line('action plan is not available');
        return 'action plan is not determined';
   else
        dbms_output.put_line(l_action_plan);
        return l_action_plan;
   end if;
END;

PROCEDURE update_blackout_until(p_instance_name varchar2, p_host_name varchar2,  p_alert_text_id varchar2, p_err_log varchar2, p_recurring_count number, p_min integer) 
IS
BEGIN
      merge into ilogmon_blackout  a
            USING (select p_instance_name as instance_name
                        , p_host_name as host_name
                        , p_alert_text_id as alert_text_id 
                        , p_err_log as err_log
                        , p_recurring_count as count30 
                        , p_min as mins 
                        from dual) b
      on (a.instance_name = b.instance_name and a.host_name=b.host_name and a.alert_text_id = b.alert_text_id)
      when MATCHED then
         update set a.sample_err_log=b.err_log, a.blackout_until = sysdate + b.mins/1440, a.count_thirty_day=b.count30, a.last_updated_on=sysdate
      when not MATCHED then
         insert (instance_name, host_name, alert_text_id, sample_err_log, blackout_until, count_thirty_day, last_updated_on)
         values (b.instance_name, b.host_name, b.alert_text_id, b.err_log, sysdate+b.mins/1440, b.count30, sysdate);
      commit;
END update_blackout_until;

PROCEDURE notify_check_blackout(p_instance_name varchar2, p_host_name varchar2, 
           p_alert_text_id varchar2, p_err_log varchar2, msg_arr db_admin.notification.msgs, p_recurring_count number)
IS
    l_blackout_until date;
    l_recip   db_admin.notification.recipients := db_admin.notification.recipients(); 
BEGIN
   l_recip.extend(2);
   l_recip(1) := 'sun@example.com';
   l_recip(2) := 'dba.irs@example.com';
   begin
      select blackout_until into l_blackout_until from ilogmon_blackout 
      where instance_name=p_instance_name
      and host_name=p_host_name
      and alert_text_id=p_alert_text_id;
   exception
      WHEN OTHERS THEN
         l_blackout_until := sysdate-1;
   end;

   IF sysdate  > l_blackout_until  THEN
         dbms_output.put_line('------Notify email to be sent ----');
         db_admin.notification.notify (
            instance_name_in => p_instance_name || '_' || p_host_name
            ,msgs_in          => msg_arr 
            ,subject_in       => 'DB ALERT LOG alert'
            ,result_in        => null
            ,email_p          => true 
            ,db_p             => true
            ,recip            => l_recip 
            ,dbaets_p => false);

         if p_recurring_count < 3 then
             update_blackout_until(p_instance_name, p_host_name,  p_alert_text_id, p_err_log, p_recurring_count, 15);  -- 15 min
         elsif p_recurring_count < 15 then
             update_blackout_until(p_instance_name, p_host_name,  p_alert_text_id, p_err_log, p_recurring_count, 1*24*60); -- 1 days 
         else
             update_blackout_until(p_instance_name, p_host_name,  p_alert_text_id, p_err_log, p_recurring_count,  7*24*60); -- 7 days
         end if;
         commit;
   END IF;
END;

PROCEDURE get_recent_alert(p_min in number)
IS
   msg_arr db_admin.notification.msgs;
   msg_arr_i pls_integer :=0;
   l_recurring_count integer :=0;
   l_msg varchar2(2000);
BEGIN

   update ilogmon_alertlog set alert_text_id = ilogmon.get_alert_text_id(err_log, host_name, instance_name)  where alert_text_id='aaaaaaaaaaaaa';
   commit;

   FOR rec in (select instance_name, host_name, err_time, err_log, alert_text_id from ilogmon_alertlog where create_time > sysdate - p_min/1440)
   LOOP
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

       msg_arr(1) := l_msg;
       msg_arr(2) := rec.err_log || chr(10) || '--------------------------------';

       -- check if this is an recurring alert since past 30 days?
       l_recurring_count := recurring_count(rec.instance_name, rec.host_name, rec.alert_text_id);

       msg_arr(3) := '!!! This type of alert message occurred ' || l_recurring_count || ' times in the past 30 day!';
       msg_arr(4) := 'ACTION PLAN: ' || get_action_plan(rec.alert_text_id, rec.err_log);
       notify_check_blackout(rec.instance_name, rec.host_name, rec.alert_text_id, rec.err_log, msg_arr, l_recurring_count);
   END LOOP;

END get_recent_alert;

END ilogmon;
/
