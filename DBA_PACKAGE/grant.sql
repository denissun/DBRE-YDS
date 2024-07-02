conn / as sysdba

-- Role

   GRANT "DBA" TO "DB_ADMIN";
   GRANT "SELECT_CATALOG_ROLE" TO "DB_ADMIN";
   GRANT "EXP_FULL_DATABASE" TO "DB_ADMIN";
   GRANT "IMP_FULL_DATABASE" TO "DB_ADMIN";

-- Sys priv

  GRANT CREATE EXTERNAL JOB TO "DB_ADMIN";
  GRANT CREATE ANY JOB TO "DB_ADMIN";
  GRANT SELECT ANY DICTIONARY TO "DB_ADMIN";
  GRANT EXECUTE ANY LIBRARY TO "DB_ADMIN";
  GRANT CREATE PROCEDURE TO "DB_ADMIN";
  GRANT CREATE SEQUENCE TO "DB_ADMIN";
  GRANT SELECT ANY TABLE TO "DB_ADMIN";
  GRANT CREATE TABLE TO "DB_ADMIN";
  GRANT UNLIMITED TABLESPACE TO "DB_ADMIN";
  GRANT CREATE SESSION TO "DB_ADMIN";
  GRANT ALTER SYSTEM TO "DB_ADMIN";
  GRANT DROP ANY TABLE TO "DB_ADMIN";
  GRANT ALTER ANY TABLE TO "DB_ADMIN";

-- Object priv

  GRANT SELECT ON "SYS"."V_$SESSION" TO "DB_ADMIN";
  GRANT EXECUTE ON "SYS"."DBMS_SHARED_POOL" TO "DB_ADMIN";
  GRANT EXECUTE ON "SYS"."DBMS_WORKLOAD_REPOSITORY" TO "DB_ADMIN";
  GRANT EXECUTE ON "SYS"."DBMS_BACKUP_RESTORE" TO "DB_ADMIN";
  GRANT WRITE ON DIRECTORY "DATA_PUMP_DIR" TO "DB_ADMIN";
  GRANT READ ON DIRECTORY "DATA_PUMP_DIR" TO "DB_ADMIN";

BEGIN

  -- Only uncomment the following line if ACL "network_services.xml" has already been created
  --DBMS_NETWORK_ACL_ADMIN.DROP_ACL('network_services.xml');

  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(
    acl => 'network_services.xml',
    description => 'NETWORK ACL',
    principal => 'DB_ADMIN',
    is_grant => true,
    privilege => 'connect');

  DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(
    acl => 'network_services.xml',
    principal => 'DB_ADMIN',
    is_grant => true,
    privilege => 'resolve');

  DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(
    acl => 'network_services.xml',
    host => '*');

  COMMIT;

END;
/

