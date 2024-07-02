declare
   l_dba varchar2(30);
begin
    for rec in (select instance_name, host_name from ilogmon_ora_instances where dba is null)
    loop
        begin
            select dba into l_dba from instance_dba_stg2 where instance_name = lower(translate(rec.instance_name, 'a0123456789', 'a'));
            -- dbms_output.put_line(rec.instance_name ||':' || l_dba);
            update ilogmon_ora_instances set dba=l_dba where instance_name = rec.instance_name and host_name = rec.host_name;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN 
            dbms_output.put_line(rec.instance_name || ': ' || 'no data found for dba');
        end;
    end loop;
    commit;

end;
/