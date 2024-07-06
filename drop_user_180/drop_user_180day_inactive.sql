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

   select  host_name, instance_name, upper(SYS_CONTEXT('USERENV', 'CON_NAME')) as db_name into l_host_name, l_instance_name, l_db_name 
     from v$instance; 

   for rec in (select username, profile, last_login
         from dba_users where account_status like '%LOCKED%' 
          and  ( last_login < sysdate -180 or expiry_date < sysdate - 180 )
          and ORACLE_MAINTAINED = 'N'
          and profile not in ('SYSACCOUNT_PROFILE','DEFAULT'))
   loop
         dbms_output.put_line(chr(10));
         -- dbms_output.put_line('Checking username: ' || rec.username || ' profile: ' || rec.profile || ' last_login: ' || rec.last_login );

         -- check if profile PASSWORD_LIFE_TIME limit <=90
         select limit into l_limit from dba_profiles where profile=rec.profile and resource_name='PASSWORD_LIFE_TIME';
         -- dbms_output.put_line('PASSORD_LIFE_TIME limit is ' || l_limit);
         if to_number_or_9999(l_limit) <=90
         then
            -- dbms_output.put_line('info: check further to drop users ...');
            select count(*) into l_num_objects from dba_objects where owner = rec.username;
            -- execute immediate 'alter user ' || rec.username  || ' account lock';
            -- dbms_output.put_line('Info: user own ' || l_num_objects || ' objects.' );
            select to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') into l_droptime_str from dual;
            if l_num_objects  = 0
            then
               dbms_output.put_line('Info: user account ' || rec.username || ' does not own any objects, it should be dropped. Its profile is ' || rec.profile || '.');

              begin
                 --  dbms_output.put_line('INFO_ONLY,'|| rec.username || ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| l_num_objects ||','|| l_droptime_str);
                 execute immediate 'drop user ' || rec.username  || ' cascade';
                 dbms_output.put_line('DROP_ACCT,'|| rec.username || ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| l_num_objects ||','|| l_droptime_str);
              exception
              when others THEN
                  dbms_output.put_line('Warning: not able to drop the user account ' || rec.username || '.' );
              end;               
            else
               dbms_output.put_line('Warning: user account ' || rec.username || ' owns ' || l_num_objects || ' objects, research futher before considering drop! Its profile is ' || rec.profile || '.');
               dbms_output.put_line('REVIEW_ACCT,'|| rec.username || ',' || rec.profile ||',' ||l_host_name ||','|| l_instance_name ||',' || l_db_name|| ','|| l_num_objects ||','|| l_droptime_str);
            end if;
         else
            dbms_output.put_line('Info: user account ' || rec.username || ' should not be dropped! ' || ' Profile is ' || rec.profile || '.' );
         end if;
   end loop;
end;
/
