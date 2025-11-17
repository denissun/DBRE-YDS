define label=&1
define dsn=&2

col tablespace_name  format     a24    justify c heading 'Tablespace'
col autoextensible  format      a14
col bigfile  format   a8
col size_g  format  a10  
col free_g  format  a10
col pctused  format a10   
col eval format a25
set pages 200

set lines 200

-- tu.used_space:  for undo tablespaces, the value of this column includes space consumed by both expired and unexpired undo segments.
--


SELECT /* realtime_hc */  label  
       , '| ' || tablespace_name  as tablespace_name
       , '| ' || SIZE_G as SIZE_G
       , '| ' || pctusd as pctused 
       , '| ' || FREE_G as FREE_G
       , '| ' || autoextensible as autoextensible
       , '| ' ||  bigfile as bigfile
       , '| ' || eval as eval
       , '| ' ||to_char(check_ts,'YYYY-MM-DD HH24:MI') check_ts
FROM HC_TABLESPACE_USAGE
order by 1,2
/
