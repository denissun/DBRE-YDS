set lines 200 
-- col sql_text for a50 trunc
col last_executed for a28
col enabled for a7
col plan_hash_value for a16
col last_executed for a16
col sql_handle for a25
col plan_name for a35

select spb.sql_handle, spb.plan_name, to_char(so.plan_id) plan_id,
spb.enabled, spb.accepted, spb.fixed,
to_char(spb.last_executed,'dd-mon-yy HH24:MI') last_executed
,dbms_lob.substr(sql_text,3999,1) sql_text
from
dba_sql_plan_baselines spb, sys.sqlobj$ so
where spb.signature = so.signature
and spb.plan_name = so.name
and spb.plan_name like nvl('&plan_name',spb.plan_name)
and dbms_lob.substr(sql_text,3999,1) like nvl( '%' || '&sql_text' || '%', dbms_lob.substr(sql_text,3999,1))
-- spb.sql_text like 'SELECT %')
and spb.sql_handle like nvl('&sql_handle',spb.sql_handle)
/
