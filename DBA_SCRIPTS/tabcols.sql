rem script: tabcols.sql 
rem  Show table column statistics
rem 
rem  Usage:  @tabcols.sql  schema.tablename
rem
rem

set echo off verify off


-- ==========================================================================
--
-- Copyright (C) RoughSea Ltd, 2006
-- http://www.roughsea.com
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
--
-- ==========================================================================
--
-- Many cases when the cost-based optimizer "has it wrong" can be traced
-- back to missing or incorrect statistics. One of the subtlest cases
-- occurs when there is skewness in the distribution of data, or
-- when the existence of dummy values (particularly true with dates)
-- suggests to the optimizer that the values are uniformly spread over
-- a very large span - when they are not. These situations are usually
-- remedied with a careful usage of histograms.
--
-- This script decodes the raw low and high values stored in the data
-- dictionary for each column, specifies the number of buckets used
-- for histograms and shows the values on which the CBO calculations
-- are based.
--
-- Usage:  @stat_sanity [schema.]tablename
--
--
--  Usage:  @tabcols.sql  schema.tablename

col density format 90.000
col bkts    format  990
col lo format A16
col hi format A16
select column_name,
       num_distinct "DISTINCT",
       round(density, 3) density,
       num_nulls "NULLS",
       num_buckets BKTS,
       to_char(to_date(to_char(sum(low_val), '00000000000000'), 'YYYYMMDDHH24MISS'), 'DD-MON-YYYY') lo,
       to_char(to_date(to_char(sum(high_val), '00000000000000'), 'YYYYMMDDHH24MISS'), 'DD-MON-YYYY') hi
from (select column_name,
             num_distinct,
             density,
             num_nulls,
             num_buckets,
             case rn
               when 1 then low_byte_value - 100  -- century
               when 2 then low_byte_value - 100  -- year
               when 3 then low_byte_value        -- month
               when 4 then low_byte_value        -- day
               else low_byte_value - 1           -- hour, minute, second
             end * power(100, 7 - rn) low_val,
             case rn
               when 1 then high_byte_value - 100  -- century
               when 2 then high_byte_value - 100  -- year
               when 3 then high_byte_value        -- month
               when 4 then high_byte_value        -- day
               else high_byte_value - 1           -- hour, minute, second
             end * power(100, 7 - rn) high_val
      from (select a.column_name,
                   a.num_distinct,
                   a.density,
                   a.num_nulls,
                   a.num_buckets,
                   b.rn,
                   to_number(substr(low_value, instr(low_value, ' ', 1, 1 + b.rn),
                                    instr(low_value || ' ', ' ', 1, 2 + b.rn)
                                    - instr(low_value || ' ', ' ', 1, 1 + b.rn))) low_byte_value,
                   to_number(substr(high_value, instr(high_value, ' ', 1, 1 + b.rn),
                                    instr(high_value || ' ', ' ', 1, 2 + b.rn)
                                    - instr(high_value || ' ', ' ', 1, 1 + b.rn))) high_byte_value
            from (select c.data_type,
                         t.num_rows,
                         c.column_name,
                         c.num_distinct,
                         translate(dump(c.low_value), ',', ' ') low_value,
                         translate(dump(c.high_value), ',', ' ') high_value,
                         c.density,
                         c.num_nulls,
                         c.num_buckets
                  from dba_tables t,
                       dba_tab_columns c
                  where t.owner = c.owner
                    and t.owner = decode(instr('&1', '.'),
                                         0, sys_context('USERENV', 'CURRENT_SCHEMA'),
                                            upper(substr('&1', 1, instr('&1', '.') - 1)))
                    and t.table_name = decode(instr('&1', '.'),
                                              0, upper('&1'),
                                                 upper(substr('&1', instr('&1', '.') + 1)))
                    and t.table_name = c.table_name
                    and (c.data_type  = 'DATE'
                         or c.data_type like 'TIMESTAMP%')) a,
                 (select rownum rn
                  from dual
                  connect by level <= 7) b))
group by column_name,
         num_distinct,
         density,
         num_nulls,
         num_buckets
union all
select column_name,
       num_distinct,
       round(density, 3),
       num_nulls,
       num_buckets,
       substr(low_value, 1, 16),
       substr(high_value, 1, 16)
from (select c.data_type,
             t.num_rows,
             c.column_name,
             c.num_distinct,
             case c.data_type
               when 'FLOAT'  then lpad(to_char(utl_raw.cast_to_number(c.low_value)), 16)
               when 'NUMBER' then lpad(to_char(utl_raw.cast_to_number(c.low_value)), 16)
               else utl_raw.cast_to_varchar2(c.low_value)
             end low_value,
             case c.data_type
               when 'FLOAT'  then lpad(to_char(utl_raw.cast_to_number(c.high_value)), 16)
               when 'NUMBER' then lpad(to_char(utl_raw.cast_to_number(c.high_value)), 16)
               else utl_raw.cast_to_varchar2(c.high_value)
             end high_value,
             c.density,
             c.num_nulls,
             c.num_buckets
      from dba_tables t,
           dba_tab_columns c
      where t.owner = c.owner
        and t.owner = decode(instr('&1', '.'),
                             0, sys_context('USERENV', 'CURRENT_SCHEMA'),
                                upper(substr('&1', 1, instr('&1', '.') - 1)))
        and t.table_name = decode(instr('&1', '.'),
                                  0, upper('&1'),
                                     upper(substr('&1', instr('&1', '.') + 1)))
        and t.table_name = c.table_name
        and (c.data_type <> 'DATE'
             and c.data_type not like 'TIMESTAMP%'))
order by column_name
/
clear col
clear breaks

