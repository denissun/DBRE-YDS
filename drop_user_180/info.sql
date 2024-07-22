-- sql script  to show various info about a user account
-- help to make desicion about whether to drop the user account

set pages 200 lines 200
col username for a16
col profile for a30
col LAST_LOGIN for a30
col object_name for a30
col owner for a16
col account_status for a20

spool info_&&username..spool

select username, profile, account_status, lock_date, last_login, expiry_date
from dba_users where username like upper('&&username');


select owner, object_name, object_type
from dba_objects where owner= upper('&&username');


pro ##################  check num of grant #################


select count(*)
from dba_tab_privs
where (owner, table_name)
in
(
select owner, object_name
from dba_objects
where owner=upper('&&username')
and object_type in ('TABLE', 'PACKAGE', 'PROCEDURE', 'FUNCTION')
);

pro ##################  list  of grants #################


col grantee for a30
col table_name for a30

select grantee, owner, table_name, PRIVILEGE
from dba_tab_privs
where (owner, table_name)
in
(
select owner, object_name
from dba_objects
where owner=upper('&&username')
and object_type in ('TABLE', 'PACKAGE', 'PROCEDURE', 'FUNCTION')
);

spool off

undefine username

