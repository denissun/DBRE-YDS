set lines 120
set serveroutput on
select instance_name, host_name, name as db_name, to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') check_timestamp from v$instance, v$database;
pro ========================================================================================
pro checking candidate user accounts that is NOT LOCKED and NOT LOGGIN for at least 90 days
pro ========================================================================================

declare
    l_limit varchar2(128);
    l_num_objects number;
    l_host_name varchar2(128);
    l_db_name varchar2(128);
    l_instance_name varchar2(128);
    l_version varchar2(128);
    l_actiontime_str varchar2(128);


    FUNCTION to_number_or_9999 (p_string IN VARCHAR2)
       RETURN INT
    IS
    BEGIN
       return  TO_NUMBER(p_string);
    EXCEPTION
    WHEN VALUE_ERROR THEN
       RETURN 9999;
    END to_number_or_9999;
begin
   select  host_name, instance_name, upper(SYS_CONTEXT('USERENV', 'CON_NAME')) as db_name, version into l_host_name, l_instance_name, l_db_name, l_version
   from v$instance;

   dbms_output.put_line('Checking hostname: ' || l_host_name || ' instance name: ' || l_instance_name || ' db name: ' || l_db_name  || ' Version: ' || l_version);


   for rec in (select  profile, limit from dba_profiles where resource_name='PASSWORD_LIFE_TIME' and  LIMIT is not null
                 and  profile  not in ('DEFAULT','ORA_STIG_PROFILE'))
   loop
         dbms_output.put_line(chr(10));
         dbms_output.put_line('Handling profile: ' || rec.profile );
         if ( to_number_or_9999 (rec.limit) <=90 )
         then
             dbms_output.put_line('LIMIT for PASSWORD_LIFE_TIME is less or equal to 90 ' );
             begin
               select limit into l_limit from dba_profiles where profile=rec.profile and resource_name='INACTIVE_ACCOUNT_TIME';
             exception
             when others then
                 l_limit := '9999';
             end;
             dbms_output.put_line(' LIMIT for INACTIVE_ACCOUNT_TIME  is ' || l_limit );
             if ( to_number_or_9999 (l_limit) > 90 )
             then
                dbms_output.put_line(' config INACTIVE_ACCOUNT_TIME limit to be 90 ' );
                select to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') into l_actiontime_str from dual;
                execute immediate 'alter profile ' || rec.profile || ' limit INACTIVE_ACCOUNT_TIME 90';
                dbms_output.put_line('CONFIG_INACTIVE_ACCT_TIME,'|| ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| ','|| l_actiontime_str);
             end if;
         end if;
   end loop;
end;
/
