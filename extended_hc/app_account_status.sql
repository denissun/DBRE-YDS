define label=&1

col label for a24
col username for a30
col account_status for a15
col lock_date for a30 
col profile for a26
set lines 160
select '~APP_USER~&label' as label,  username, account_status, profile, lock_date
  from dba_users
  where profile in (
      SELECT profile FROM dba_profiles WHERE resource_name = 'PASSWORD_LIFE_TIME' AND limit = 'UNLIMITED' and profile not in ('DEFAULT')
  )
and account_status !='OPEN'
and ( 
lock_date > sysdate -30 
or EXPIRY_DATE > sysdate -30 
);



