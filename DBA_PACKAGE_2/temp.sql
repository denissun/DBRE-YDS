create or replace function wait_row(
   i_v	in	varchar2,
   i_sec in	number default 5
) return varchar2
deterministic
parallel_enable
as
begin
  dbms_lock.sleep(i_sec);
  return i_v;
end;
/



-- simulate long running sql 


begin

  DBMS_APPLICATION_INFO.SET_MODULE
	      (module_name => 'EMPLOYEE'
		,action_name => 'AWARD');
  
  for i in ( select wait_row(table_name, 30)  result from dba_tables)
  loop
   dbms_output.put_line (i.result);
  end loop;
end;
/
