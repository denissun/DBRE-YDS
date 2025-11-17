define label=&1

col inst_id for 9999 
col name for a30 
col value for a40 
select inst_id, name, value from gv$parameter where name in ('db_recovery_file_dest',  'log_archive_dest_1');

col name for a30
col space_limit_mb for  9999999 
col space_used_mb for   9999999 
col label for a20

set lines 200

SELECT /* realtime_hc */  '~ARCH_DEST~&label' as label, NAME , round(SPACE_LIMIT/1024/1024/1024) space_limit_gb, round(SPACE_USED/1024/1024/1024) space_used_gb, 
round(SPACE_RECLAIMABLE/1024/1024/1024) space_reclaimable_gb,
round(100*space_used/space_limit) pct_used,
case when round(100*space_used/space_limit) > 80 then 'ALERT' else 'NORMAL' end evaluation 
FROM V$RECOVERY_FILE_DEST;


