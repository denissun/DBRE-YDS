col  sql_text format a30
col plan_hash_value for 99999999999
col prfl_bsln format a40
set lines 200



SELECT
    inst_id
  , child_number c_n
  -- ,last_load_time
  , last_active_time
  -- ,loads
  , executions excton
  , ROUND(cpu_time / GREATEST(executions, 1) / 1000000, 1) "AveCpuTmSec"
  , ROUND(elapsed_time / GREATEST(executions, 1) / 1000000, 1) "AveElaTmSec"
  , CEIL(buffer_gets / GREATEST(executions, 1)) "AveBufGets"
  , CEIL(rows_processed / GREATEST(executions, 1)) "AveRowPrcsd"
  , plan_hash_value
  , sql_profile || '|' || sql_plan_baseline prfl_bsln
FROM
    gv$sql
WHERE
  sql_id = '&sqlid'
ORDER BY
  last_active_time
/

