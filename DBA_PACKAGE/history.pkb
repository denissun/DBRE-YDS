CREATE OR REPLACE
PACKAGE body "HISTORY"
IS


FUNCTION  get_hc_email_recip 
return varchar2
is
-- return a coma seprated email address string
 l_email_list varchar2(2000);
 i pls_integer :=0;
begin
  for rec in (SELECT cname, cvalue FROM configs WHERE cname='HC_EMAIL')
  loop 
	if i = 0 then
          l_email_list := rec.cvalue ;
        else
          l_email_list :=  l_email_list  || ',' || rec.cvalue; 
        end if; 
	i := i + 1;
  end loop;
  return l_email_list;
end;


PROCEDURE do_hc (p_check_gg boolean default false)
-- hc_history is a synonum for a remote table
-- Bug 469264 "INSERT INTO REMOTE TABLE SELECT FROM LOCAL DICTIONARY VIEW GIVES 2070"
is

-- instance status
  cursor cur_inst is select
  sysdate etime
, 'INSTANCE STATUS' etype
, 'DB STATUS: ' ||  DATABASE_STATUS || ' LOGIN: ' || LOGINS || ' STATUS: ' || STATUS  rtext
, null rnum
, instance_name
, host_name
from  gv$instance;


-- avg CPU util % in the past 1 min
  cursor cpu_cur is
   select inst_id, round(avg(value),1) val 
   from
     (  SELECT inst_id, round(a.value) value
       FROM gv$sysmetric_history a
       where upper(a.metric_name) like upper('%Host CPU Utilization%') and begin_time >= sysdate-1/1440  
     ) g
   group by inst_id;

-- session stauts
  cursor ses_cur is
        select  inst_id,  count(*) c,       status
          from    gv$session
          where   type='USER'
         group by        inst_id, status;



-- Transaction per Sec
-- PROMPT TRANSACTION PER SEC
  cursor trans_cur is 
      SELECT inst_id, a.begin_time, round(a.value) value
      FROM gv$sysmetric_history a
      where upper(a.metric_name) like upper('%User Transaction Per Sec%') and begin_time >= sysdate-2/1440;


-- WAIT EVENTS
  cursor wait_cur is
     select inst_id,event,wait_class,round(evttot*100/tot,2) pct,snap_start,snap_end
       from(select  inst_id,decode(event,null,'CPU+Wait for CPU',event) event,decode(wait_class,null,'CPU',wait_class) wait_class,
	         evttot,tot,mint snap_start, maxt snap_end,
		 row_number() over (partition by inst_id order by evttot desc) rn
            from (select distinct inst_id, event,wait_class,count(*) over (partition by inst_id,event) evttot,count(*) over () tot,
	      min(sample_time) over () mint,max(sample_time) over () maxt
	             from gv$active_session_history
	     where sample_time >= sysdate -5/1440))
	where rn <=5 order by inst_id;



  v_hostname  varchar2(16);
  v_instname  varchar2(16);
begin
  -- instance
  for r in cur_inst
  loop
    insert into hc_history(  event_time , event_type , result_text , result_number , instance_name , host_name)
    values (r.etime, r.etype, r.rtext, r.rnum, r.instance_name, r.host_name);
  end loop;

  for r in cpu_cur 
  loop
    select instance_name, host_name into v_instname, v_hostname from gv$instance where inst_id = r.inst_id;

    insert into hc_history(  event_time , event_type , result_text , result_number , instance_name , host_name)
    values (sysdate, 'CPU STATUS', 'Host CPU Utilization - Avg in last 1 min', r.val, v_instname, v_hostname);

  end loop;

  for r in ses_cur 
  loop
    select instance_name, host_name into v_instname, v_hostname from gv$instance where inst_id = r.inst_id;

    insert into hc_history(  event_time , event_type , result_text , result_number , instance_name , host_name)
    values (sysdate, 'SESSION STATUS', r.status, r.c, v_instname, v_hostname);

  end loop;

  for r in trans_cur 
  loop
    select instance_name, host_name into v_instname, v_hostname from gv$instance where inst_id = r.inst_id;

    insert into hc_history(  event_time , event_type , result_text , result_number , instance_name , host_name)
    values (r.begin_time, 'WORKLOAD', 'User Transaction Per Sec', r.value, v_instname, v_hostname);

  end loop;

  for r in wait_cur 
  loop
    select instance_name, host_name into v_instname, v_hostname from gv$instance where inst_id = r.inst_id;

    insert into hc_history(  event_time , event_type , result_text , result_number , instance_name , host_name)
    values (r.snap_end, 'WAIT EVENT', to_char(r.snap_start, 'HH24:MI:SS ') || r.event || ' - ' || r.wait_class,
	  r.pct, v_instname, v_hostname);

  end loop;
   if p_check_gg
   then
  
-- load data from gginfo_ext (external table ) to  hc_history
-- gginfo_ext should be populated with data with externel job immeidately  before running do_hc;
   select instance_name, host_name into v_instname, v_hostname from v$instance;

   insert into hc_history (event_time, event_type, result_text, result_number , instance_name , host_name)
   select sysdate, 'GOLDENGATE', g.msg_line, null, v_instname, v_hostname 
     from gginfo_ext g where instr(msg_line,'REPLICAT') > 0 
      or instr(msg_line,'EXTRACT') >0 or instr(msg_line,'MANAGER') >0;

   end if;
   -- commit local data load into hc_history
   commit;


   -- load data into a remote table
   -- if failed ignore
   begin
     insert into  hc_history_remote  select * from hc_history where event_time > sysdate - 5/1440;
     commit;
   exception 
    when others then
     dbms_output.put_line ( 'load data to remote table failed ');
     notification.save_msg('load data to remote table failed', 'HC JOB ERROR');
   end;

end;

PROCEDURE config_hc_email(
	    p_email IN VARCHAR2 DEFAULT NULL,
	    p_option VARCHAR2 DEFAULT 'l')
IS
  -- add or remove a email id from HC report 
BEGIN
  IF p_option = 'a' AND p_email IS NOT NULL THEN
    INSERT INTO configs VALUES
     ('HC_EMAIL', p_email
      );
    COMMIT;
    dbms_output.put_line(p_email|| ' is added');
  elsif p_option ='r' AND p_email IS NOT NULL THEN
   DELETE
    FROM configs
   WHERE cname='HC_EMAIL'
   AND cvalue = p_email;
   COMMIT;
   dbms_output.put_line(p_email || ' is removed');
  elsif p_option ='l' THEN
  dbms_output.put_line('List Current Configuratons' || chr(10) || '--------------------' );
   FOR rec IN
     (SELECT * FROM configs WHERE cname='HC_EMAIL'
    )
   LOOP
     dbms_output.put_line('Configuraton Name: '||rec.cname || ' - Value: ' || rec.cvalue);
   END LOOP;
 END IF;
END config_hc_email;


END;
/
