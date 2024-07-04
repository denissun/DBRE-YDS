# Overview

  Who can access which password?  This a problem that challenges us.
  
  There are various common functional user account passwords that DBAs have to know or manage. For example, those for RDS database master user account, Database Vault administer accounts, OEM sysman user, RMAN Catalog user account, monitoring user accounts, application user accounts, schema owners, and db code deployment user account etc. Sometimes, passwords may be not tied to a user, for examples TDE password, OEM agent registration password. It is obvious that not every DBA need to know every password. Onshore/offshore support model also adds some requirements,  such as offshore DBA should not access application data.
  
  Oracle Label Security (OLS) looks like a viable solution to the password management problem we face.  According to Oracle official document, OLS can achieve the followings:
  
  Enforce data access by security levels
  User access to data is controlled by defined data labels (restricted, sensitive, public). Hundreds of levels are supported.
  Users only see authorized data for their defined groups
  Use group labels to ensure users only access data relevant to their specific needs. Thousands of groups can be defined.
  Flexible security modeling
  Combine level and group labels to model almost any security policy, ensuring users only access appropriate data.
  
  EZPASS is a command line utility program developed by Gobang to help DBAs put and get passwords into and from Oracle database table  that is protected by OLS. In the following sections,  some details of the OLS and EZPASS program will be described.
  

# Backend Database

## Schema

  In the EZPASS repository Oracle database, under schema EZPASS, there are four application tables:

###  Table: SECRET_OBJECTS - storing encrypted password text and info related to the password

```

 Name                                  Null?    Type
 ------------------------------------- -------- ------------------------
 ID                                    NOT NULL NUMBER(38)
 NAME                                           VARCHAR2(200)
 TYPE                                           VARCHAR2(100)
 USERNAME                                       VARCHAR2(50)
 PASSWORD                                       VARCHAR2(100)
 ACCESS_LEVEL                                   NUMBER
 CREATED                                        TIMESTAMP(6)
 OLS_COL                                        NUMBER(10)
 NOTES                                          VARCHAR2(250)

```

### Table: ACCESS_KEYS  - storing access keys

```

 Name                 null?    Type
  ------------------- -------- --------------------------------------
 KEY                            VARCHAR2(200)
 IS_ACTIVE                      CHAR(1)
 CREATED                        TIMESTAMP(6)

```
### Table: ACTIVITY_LOG - logging user activities

```

 Name                     Null?    Type
 ------------------------ -------- ---------------------------------
 WHO                               VARCHAR2(100)
 ACTION                            VARCHAR2(20)
 WORKDIR                           VARCHAR2(200)
 HOSTNAME                          VARCHAR2(100)
 NAME                              VARCHAR2(200)
 TYPE                              VARCHAR2(100)
 USERNAME                          VARCHAR2(50)
 ACCESS_LEVEL                      NUMBER
 LOGTIME                           TIMESTAMP(6)

 ```

### Table: ACCESS_BY_KEY_LOG - logging the event of getting password by key

```
 Name                               Null?    Type
 ---------------------------------- -------- ----------------------
 USERNAME                                    VARCHAR2(100) WORKDIR                                     VARCHAR2(200)
 HOSTNAME                                    VARCHAR2(100)
 STATUS                                      VARCHAR2(30)
 LOGTIME                                     TIMESTAMP(6)
```

## The EZPASS repository Oracle database is Vault enabled and the tables are protected by realm

## Users must have accounts in the EZPASS Repo DB to use the program. 
   
Oracle standard role and privs are used to control who can access the tables under EZPASS schema. User can directly login to it to change initial password if needed.

## Row-Level Security is enforced with Oracle Label Security 

  Currently each row of the tables is assigned with one of the three labels:  'C' (access_level=1), 'S' (access_level=2) or 'HS' (access_level =10) 

  The following example shows 'USER1' is given access up to 'HS' labeled rows, whereas 'USER2' only can access up to  'S' labeled rows.

```
    BEGIN
       SA_USER_ADMIN.SET_LEVELS (
          policy_name  => 'EZPASS_OLS_POL',
          user_name    => 'USER1', 
          max_level    => 'HS',
          min_level    => 'C');

       SA_USER_ADMIN.SET_LEVELS (
          policy_name  => 'EZPASS_OLS_POL',
          user_name    => 'USER2', 
          max_level    => 'S',
          min_level    => 'C');
    END;
    /

```

Reference for Oracle Label Security: 

https://docs.oracle.com/en/database/oracle/oracle-database/19/olsag/getting-started-with-oracle-label-security.html#GUID-4B228EB5-A092-4D0F-9EFB-C2109D3BD85D


# Usage Examples:

##  Create a secret entry with "PUT"

```
$> ezpass put -h
Put password in repository with name, type, username and acccess_level info.

Usage:
  ezpass put [flags]

Flags:
      --ez_pass string    EZPass App Password
      --ez_user string    EZPass App User Name
  -h, --help              help for put
  -l, --level int         access control level (1,2,10)  (default 2)
  -n, --name string       Secret Object Target Name
  -d, --note string       Shot notes (max 250 chars)
  -p, --password string   Password
  -t, --type string       Secret Object Target Type
  -u, --username string   User Name


$> ezpass put -n test1.example.com:1521/db1 -u test -p welcome -t dsn
You need an account to use EZPass, if you don't have, CTRL-C and contact admins
Enter EZPASS Account Username: username1
Enter EZPASS Account Password:

put a password is done!

```

## Retreive the secret with "GET"

```

$> ezpass get -h
Get passwords from repository

Usage:
  ezpass get [flags]

Flags:
  -e, --Expand            List rows vertically with notes field
  -c, --clear             Whetehr showing clear-text password
  -h, --help              help for get
  -n, --name string       Secret Object Target Name
  -t, --type string       Secret Object Target Type
  -u, --username string   User Name


$> ezpass get -n test1 -c -e
You need an account to use EZPass, if you don't have, CTRL-C and contact admins
Enter EZPASS Account Username: username1
Enter EZPASS Account Password:

                Name: test1.example.com:1521/db1
                Type: dsn
            Username: test
            Password: welcome
         AccessLevel: 2
               Notes:
             Created: 2024-07-02 10:51:37
------------------------------------------

```

## Retreive the secret with ACCESS KEY (not interatively)

```

/u01/app/denis/gocode/ezpass []
$> ezpass getByKey -n test1.example.com:1521/db1 -t dsn -u test
welcome

```
