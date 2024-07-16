import sys
import json
import psycopg2
from myconfig import  params
from datetime import datetime
from cryptography.fernet import Fernet


def get_decrypted_password(encrypted_password):
    f=open('.key','r')
    for line in f:
       key = line.strip()
       encryption_type = Fernet(key)
       decrypted_pass = encryption_type.decrypt(bytes(encrypted_password,  encoding='utf-8'))
       dpass = decrypted_pass.decode('utf-8')
    f.close()
    return dpass

def getValueOrNone(i, key):
    if key in i:
        return i[key]
    else:
        return "n/a"


def getVsad(taglist):
    for i in taglist:
        if i["Key"] == "Vsad":
            return i["Value"]

def insert_rds_instance(cur, instance):
    insert_sql = '''insert into dbaets.rdsinstances(
       "DBInstanceIdentifier"
      ,"DBInstanceStatus"
      ,"Engine"
      ,"MasterUsername"
      ,"DBName"
      ,"EndpointAddress"
      ,"Port"
      ,"AllocatedStorage"
      ,"EngineVersion"
      ,"Vsad"
      , ts 
      ,"DBClusterIdentifier"
    ) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    ON CONFLICT ("EndpointAddress")
    DO UPDATE SET
        "EngineVersion" = EXCLUDED."EngineVersion"
    ,   "DBInstanceStatus"= EXCLUDED."DBInstanceStatus"
    ,   "AllocatedStorage"= EXCLUDED."AllocatedStorage"
    ,   ts = EXCLUDED.ts
    ;
    '''
    cur.execute(insert_sql,instance)

def  print_rds_instance(instance):
    print(instance)

if   (__name__ == '__main__'):

    if len(sys.argv) != 2:
       print("Usage: " + sys.argv[0] + "<rds json file")
       sys.exit(1)

    jsonfile=sys.argv[1]
    # print(jsonfile)

    # connect to the PostgreSQL database
    params['password'] = get_decrypted_password(params['password'])

    try:
        conn = psycopg2.connect(**params)
    except:
       print ("Unable to connect to database")
       sys.exit(1)

    cur=conn.cursor()

    now = datetime.now()
    current_time = now.strftime("%Y-%m-%d %H:%M:%S")

    with open(jsonfile) as f:
        data = json.load(f)

        # Print the data of dictionary
        for i in data["DBInstances"]:
            try:
                print("---process: " + i["DBInstanceIdentifier"] )
                DBInstanceIdentifier = i["DBInstanceIdentifier"]
                DBInstanceStatus = i["DBInstanceStatus"]
                Engine=i["Engine"]
                MasterUsername=i["MasterUsername"]
                if "DBName" in i:
                    DBName=i["DBName"]
                else:
                    DBName="n/a"
                Endpoint_Address=i["Endpoint"]["Address"]
                Port=i["Endpoint"]["Port"]
                AllocatedStorage=i["AllocatedStorage"]
                EngineVersion=i["EngineVersion"]
                Vsad = getVsad(i["TagList"])
                DBClusterIdentifier=getValueOrNone(i, "DBClusterIdentifier")

                instance=(
                    DBInstanceIdentifier
                    ,DBInstanceStatus
                    ,Engine
                    ,MasterUsername
                    ,DBName
                    ,Endpoint_Address
                    ,Port
                    ,AllocatedStorage
                    ,EngineVersion
                    ,Vsad
                    ,current_time
                    ,DBClusterIdentifier
                )


                insert_rds_instance(cur, instance)
                # print_rds_instance(instance)
                conn.commit()
            except:
                print("---process failure skip: " + i["DBInstanceIdentifier"] )
    # close the communication with the PostgreSQL database server
    cur.close()
    conn.close()
