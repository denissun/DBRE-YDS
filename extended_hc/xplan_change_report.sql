define label=&1
col parsing_schema_name for a20
col plan_detail_list format a50
col label for a20
col unique_plans format a6
col cv_gets_exe  for a6
set lines 200 

SELECT /* realtime_hc */ '~XPLAN~&label |' label,
    plan_data.sql_id || ' | ' as sql_id,
    COUNT(plan_data.plan_hash_value) || ' | '  AS unique_plans,
    plan_data.parsing_schema_name || ' | ' as parsing_schema_name,
    -- Coefficient of Variation (CV): Measures plan volatility
    ROUND(100 * STDDEV(plan_data.gets_per_exec) / AVG(plan_data.gets_per_exec)) || ' | ' AS cv_gets_exe,
    -- List the Plan Hash Value and the associated average Buffer Gets per execution
    LISTAGG( plan_data.plan_hash_value || ' (' || TO_CHAR(plan_data.gets_per_exec ) || ')', ' ; ')  plan_detail_list
FROM
    (
        -- Inner query: Calculates average Buffer Gets per execution for EACH plan_hash_value
        SELECT
            c.SQL_ID,
            c.plan_hash_value,
            c.parsing_schema_name,
            -- Calculate the average Buffer Gets per execution for this specific plan/schema/SQL_ID
            ROUND(SUM(c.BUFFER_GETS_DELTA) / NULLIF(SUM(c.EXECUTIONS_DELTA), 0)) AS gets_per_exec
        FROM
            DBA_HIST_SQLSTAT c
        JOIN
            DBA_HIST_SNAPSHOT d ON C.SNAP_ID = D.SNAP_ID
        WHERE
            c.EXECUTIONS_DELTA > 0
            AND TRUNC(d.END_INTERVAL_TIME) >= TRUNC(SYSDATE - 1/4)
            AND c.PARSING_SCHEMA_NAME NOT IN ('SYS', 'SYSTEM','DVSYS','DBSNMP', 'NEWRELIC_USER')
            and c.buffer_gets_delta > 0
        GROUP BY
            c.SQL_ID,
            c.plan_hash_value,
            c.parsing_schema_name
        HAVING
            SUM(c.EXECUTIONS_DELTA) > 100 -- Minimum execution count to ensure stable average
    ) plan_data
GROUP BY
    plan_data.sql_id,
    plan_data.parsing_schema_name
HAVING
    COUNT(plan_data.plan_hash_value) > 1 -- Must have more than one plan
    AND ROUND(100 * STDDEV(plan_data.gets_per_exec) / AVG(plan_data.gets_per_exec)) > 50 -- CV must exceed 50%
    and max(plan_data.gets_per_exec) > 1000
ORDER BY
    unique_plans DESC,
    cv_gets_exe DESC
;
