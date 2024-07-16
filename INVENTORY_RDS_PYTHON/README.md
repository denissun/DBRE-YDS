# Purpose 

load AWS RDS instance data into a PostgreSQL DB table

# Inventory table definition

```
etsdb=> \d rdsinstances;
                                             Table "dbaets.rdsinstances"
        Column        |            Type             | Collation | Nullable |                 Default
----------------------+-----------------------------+-----------+----------+------------------------------------------
 id                   | integer                     |           | not null | nextval('rdsinstances_id_seq'::regclass)
 DBInstanceIdentifier | character varying(200)      |           |          |
 DBInstanceStatus     | character varying(200)      |           |          |
 Engine               | character varying(200)      |           |          |
 MasterUsername       | character varying(200)      |           |          |
 DBName               | character varying(100)      |           |          |
 EndpointAddress      | character varying(200)      |           |          |
 Port                 | character varying(20)       |           |          |
 AllocatedStorage     | bigint                      |           |          |
 EngineVersion        | character varying(50)       |           |          |
 Vsad                 | character varying(4)        |           |          |
 ts                   | timestamp without time zone |           |          |
 DBClusterIdentifier  | character varying(200)      |           |          |
 asset_id             | integer                     |           |          |
 server_id            | integer                     |           |          |
Indexes:
    "rdsinstances_uk2" UNIQUE, btree ("EndpointAddress")


```


# Description of scripts

* gen_rds.sh

  generate json files that contain AWS RDS info using "aws rds describe-db-instances" command.

* rdsinstance_load.sh

  driver script to run rdsins.py

* rdsins.py

  A Python program to parse json files and load data into the PostgreSQL DB

* myconfig.py

  PostgreSQL db connection info

