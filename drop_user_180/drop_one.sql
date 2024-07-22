-- drop one user
--

set lines 120
set serveroutput on
select instance_name, host_name, name as db_name, to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') check_timestamp from v$instance, v$database;
pro =================================================================================================
pro checking and drop candidate user accounts that are  LOCKED and NOT LOGGIN for at least 180 days
pro =================================================================================================

declare
    l_limit varchar2(128);
    l_num_objects number;
    l_host_name varchar2(128);
    l_db_name varchar2(128);
    l_instance_name varchar2(128);
    l_droptime_str varchar2(128);

begin
   select  host_name, instance_name, upper(SYS_CONTEXT('USERENV', 'CON_NAME')) as db_name into l_host_name, l_instance_name, l_db_name
     from v$instance;

   for rec in (select username, profile, last_login
         from dba_users where account_status not in ('OPEN') and  ( last_login < sysdate -180 or expiry_date < sysdate - 180)  and ORACLE_MAINTAINED = 'N'
          and profile not in ('SYSACCOUNT_PROFILE','DEFAULT')
          and username = upper('&username')
         )
   loop
         dbms_output.put_line(chr(10));
         select count(*) into l_num_objects from dba_objects where owner = rec.username;
         select to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') into l_droptime_str from dual;
         begin
            --  dbms_output.put_line('INFO_ONLY,'|| rec.username || ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| l_num_objects ||','|| l_droptime_str);
            execute immediate 'drop user ' || rec.username  || ' cascade';
            dbms_output.put_line('DROP_AFT_RVW,'|| rec.username || ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| l_num_objects ||','|| l_droptime_str);
         exception

          when others THEN
             dbms_output.put_line('DROP_AFT_RVW,'|| rec.username || ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| l_num_objects ||','|| l_droptime_str);
             dbms_output.put_line('Warning: not able to drop the user account ' || rec.username || '.' );
             raise_application_error(-20001,'An error was encountered - '||SQLCODE||' -ERROR- '||SQLERRM);
         end;
   end loop;
end;
/
