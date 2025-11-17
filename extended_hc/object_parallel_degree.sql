define label=&1

col label format a30
col object_type for a12
col owner for a12
col object_name for a34
col degree for a8

SELECT /* realtime_hc */  '~parallel-degree~&label' label, 
'INDEX' OBJECT_TYPE, OWNER, INDEX_NAME object_name, TRIM(DEGREE) DEGREE
FROM DBA_INDEXES
WHERE TRIM(DEGREE) > TO_CHAR(1)
and owner not in ('SYS','DVSYS'.'MDSYS')
UNION ALL
SELECT '~parallel-degree~&label' label, 
        'TABLE', OWNER, TABLE_NAME object_name, TRIM(DEGREE) DEGREE
FROM DBA_TABLES
WHERE TRIM(DEGREE) > TO_CHAR(1)
and owner not in ('SYS','DVSYS','MDSYS')
/

