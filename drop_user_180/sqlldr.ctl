LOAD DATA
INFILE 'data.csv'
APPEND INTO TABLE  db_acct_action
FIELDS TERMINATED BY ','
(
action_type,
username,
profile,
host_name,
instance_name ,
db_name,
num_objects,
action_time date 'YYYY-MM_DD HH24:MI:SS'
)

