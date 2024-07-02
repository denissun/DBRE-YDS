CREATE OR REPLACE  PACKAGE BODY "NOTIFICATION"  as



procedure send_email (instance_name_in varchar2, msgs_in msgs,
                      subject_in varchar2,
                      recip recipients) is

l_sender varchar2(60) ;
l_smtp_server varchar2(255);
l_smtp_server_port NUMBER ;

-- local_domain constant varchar2(255) := 'example.com';

lvDate varchar2(30) := to_char(sysdate,'MM/DD/YYYY HH24:MI');
lvBody varchar2(32000);
c utl_smtp.connection;
line_no number :=0;

recipient_list varchar2(1000);
-- local procedure to reduce redundancy
procedure write_header (name in varchar2, header in varchar2)
is
begin
      utl_smtp.write_data(c, name || ': ' || header || utl_tcp.CRLF);
end;

begin
   select cvalue into  l_sender from configs where cname='SENDER' and rownum=1;
   select cvalue into  l_smtp_server from configs where cname='SMTP_SERVER';
   select to_number(cvalue) into  l_smtp_server_port from configs where cname='SMTP_SERVER_PORT';

	 
   if recip is not null
   then
     for i in 1 .. recip.count loop
       if i= 1  then
         recipient_list := recip(1);
       else 	 
         recipient_list := ','||recip(i);
       end if;
     end loop;
   else
       recipient_list := l_sender;
   end if;

--   line_no :=10;

   -- Open SMTP connection
   c := utl_smtp.open_connection(l_smtp_server, l_smtp_server_port);

--   line_no :=20;
   -- Perform initial handshaking with the SMTP server after connecting
   utl_smtp.helo(c, l_smtp_server );
   -- Initiate a mail transacation
   utl_smtp.mail(c, l_sender);
   
--   line_no :=30;

   if recip is not null
   then
     for i in 1 .. recip.count loop
	utl_smtp.rcpt(c, recip(i));
     end loop;
   else
     utl_smtp.rcpt(c, l_sender);
   end if;

--   line_no :=40;
--   dbms_output.put_line ('recipient_list = ' || recipient_list);
   -- Send the data command to the SMTP server
   utl_smtp.open_data(c);
   -- Write the header part of the email body
--   write_header('Date',lvDate);
   write_header('From',l_sender);
   write_header('Subject',instance_name_in||' '||subject_in);
   write_header('To',recipient_list);
   write_header('Content-Type', 'text/html;');
--   line_no :=47;

   -- format the message body in HTML
   lvbody := '<html><head><style type="text/css">
              BODY, P, li, {font-family: courier-new,courier; font-size : 8pt;}
               </style></head><body><p>';
--   line_no :=48;

   -- the body of the email consists of the input message array
   for i in 1 .. msgs_in.last loop
	 lvbody := lvbody||'<br>'||
            replace(msgs_in(i),chr(10),'<br>');
   end loop;

--   line_no :=50;

   lvbody := lvbody||'</body></html>';
   -- write less than 1000 characters at a time
   for x in 1 .. (length(lvbody)/800 + 1) loop
      utl_smtp.write_data(c, utl_tcp.CRLF ||
            substr(lvBody,(x-1)*800 +1,800));
    end loop;

   -- end the email message
   utl_smtp.close_data(c);
   
   -- disconnect from the smtp server
   utl_smtp.quit(c);

exception
  when others then
      dbms_output.put_line('debug line_no =' ||line_no ); 
      utl_smtp.quit(c);
      raise;
end;

procedure save_in_db(instance_in varchar2, msgs_in msgs,
                     subject_in varchar2, result_in number) is
-- this program saves messages to a database table
-- it assumes that each message passed in begins with a string
-- that evaluates to a date in a specific format
run_time date;
begin

   forall i in 1.. msgs_in.last
      
      insert into alerts (event_date, instance_name,
              event_type, result, result_text)
      values (to_date(substr(msgs_in(i),1,24),
         'Dy Mon dd hh24:mi:ss yyyy'),
          instance_in,subject_in,
          result_in,msgs_in(i));
exception
   when others then
   debug.f('save_in_db error');  
   debug.f('SQLCODE = ' || SQLCODE );
   debug.f('SQLERRM = ' || SQLERRM );
   debug.f('\n %s', dbms_utility.format_call_stack );
end save_in_db;

procedure save_in_dbaets(instance_in varchar2, msgs_in msgs,
                     subject_in varchar2, result_in number) 
is
  lvBody varchar2(32000);
  l_hostname varchar2(20);
begin
   select host_name into l_hostname from v$instance;

   lvbody := '<html><head><style type="text/css">
              BODY, P, li, {font-family: courier-new,courier; font-size : 8pt;}
               </style></head><body><p>';

-- the body of the email consists of the input message array
   for i in 1 .. msgs_in.last loop
	 lvbody := lvbody||'<br>'||
            replace(msgs_in(i),chr(10),'<br>');
   end loop;
   lvbody := lvbody||'</body></html>';

-- dbaets_load is a synonym for a remote procedure proc_event_load@etsdb

dbaets_load( p_title => subject_in,
	     p_database => instance_in,
	     p_server => l_hostname,
	     p_desc => lvbody,
	     p_created_by => 'NOTIFICATION PKG', 
	     p_start_time =>  sysdate );

exception
when others then
   debug.f('-----  save_in_dbaets error -------------');  
   debug.f('SQLCODE = ' || SQLCODE );
   debug.f('SQLERRM = ' || SQLERRM );
   debug.f('\n %s', dbms_utility.format_call_stack );
end;


-- public
PROCEDURE save_msg (
	        p_msg in varchar2,
		p_event in varchar2 default 'DEBUG'
		)
is
  l_instance_name varchar2(20); 
  l_msgs  msgs;
begin
  select instance_name into l_instance_name from v$instance;

  l_msgs(1) := TO_CHAR(sysdate,'Dy Mon dd hh24:mi:ss yyyy')||chr(10) || substr(p_msg, 1, 3800);
       	save_in_db(instance_in => l_instance_name,
	       	   msgs_in => l_msgs,
		   subject_in => p_event , result_in => null);
exception
when others then
   debug.f('-----  save msg -------------');  
   debug.f('SQLCODE = ' || SQLCODE );
   debug.f('SQLERRM = ' || SQLERRM );
   debug.f('\n %s', dbms_utility.format_call_stack );
end save_msg;


PROCEDURE notify(
	      instance_name_in IN VARCHAR2,
	      msgs_in          IN msgs,
	      subject_in       IN VARCHAR2 DEFAULT NULL,
	      result_in        IN NUMBER DEFAULT NULL,
	      email_p          IN BOOLEAN,
	      db_p             IN BOOLEAN,
	      recip            recipients DEFAULT NULL,
	      dbaets_p         IN BOOLEAN DEFAULT false) is
begin
-- send email
if email_p = true then
	debug.f('before call send email');
    send_email (instance_name_in, msgs_in,
                subject_in, recip);
	debug.f('after call send email');
end if;

if db_p = true then
	debug.f('before call save in db');
    save_in_db (  instance_name_in, msgs_in,
                  subject_in, result_in);
	 
	debug.f('after call save in db');
end if;

if dbaets_p = true then
   debug.f('before call save in dbaets');
    save_in_dbaets (  instance_name_in, msgs_in,
                  subject_in, result_in);
   debug.f('after call save in dbaets');
end if;
end;

end;
/



