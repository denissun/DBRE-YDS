set serveroutput on;
declare
   l_recip   db_admin.notification.recipients := db_admin.notification.recipients(); 
BEGIN
   l_recip.extend(2);
   l_recip(1) := 'user1@example.com';
   l_recip(2) := 'user2@example2.com';

   dbms_output.put_line(l_recip(2)); 
end;
/
