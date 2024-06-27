rem  Script: sort_used.sql 
rem 
rem   -- Display information about all sort segments in the database. 
rem  
rem   Note:
rem     We use the term sort segment to refer to a temporary segment 
rem     in a temporary tablespace. Typically, Oracle will create a new sort segment 
rem     the very first time a sort to  disk occurs in a new temporary tablespace. 
rem 
rem     The sort segment will grow as needed, but it will not shrink and will 
rem     not go away after all sorts to disk are completed. A database with one 
rem     temporary tablespace will typically 
rem      have just one sort segment.

set echo  off
set head on

SELECT   A.tablespace_name tablespace, D.mb_total,
         SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_used,
         D.mb_total - SUM (A.used_blocks * D.block_size) / 1024 / 1024 mb_free
FROM     v$sort_segment A,
         (
         SELECT   B.name, C.block_size, SUM (C.bytes) / 1024 / 1024 mb_total
         FROM     v$tablespace B, v$tempfile C
         WHERE    B.ts#= C.ts#
         GROUP BY B.name, C.block_size
         ) D
WHERE    A.tablespace_name = D.name
GROUP by A.tablespace_name, D.mb_total
/
set echo on
