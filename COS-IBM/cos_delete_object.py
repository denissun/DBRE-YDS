# Script:  cos_delete_object.py
# Purpose: Delete an object in the IBM Cloud Object Storge
#
# Note: 
#     set up venv for using in laptop
#        C:\Users\xxxxxx\Denis_files\python_proj\practise\venv311\Scripts\activate.bat
#
#     ref:  https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-python

import ibm_boto3
import os,sys
from ibm_botocore.client import Config, ClientError
from dotenv import dotenv_values


def get_buckets():
    print("Retrieving list of buckets")
    try:
        buckets = cos_client.list_buckets()
        for bucket in buckets["Buckets"]:
            print("Bucket Name: {0}".format(bucket["Name"]))
    except ClientError as be:
        print("CLIENT ERROR: {0}\n".format(be))
    except Exception as e:
        print("Unable to retrieve list buckets: {0}".format(e))

def get_bucket_contents(bucket_name):
    print("Retrieving bucket contents from: {0}".format(bucket_name))
    try:
        files = cos_client.list_objects(Bucket=bucket_name)
        for file in files.get("Contents", []):
            print("Item: {0} ({1} bytes).".format(file["Key"], file["Size"]))
    except ClientError as be:
        print("CLIENT ERROR: {0}\n".format(be))
    except Exception as e:
        print("Unable to retrieve bucket contents: {0}".format(e))


def delete_item(bucket_name, object_name):
    try:
        cos_client.delete_object(Bucket=bucket_name, Key=object_name)
        print("\n Deleted object: {0}!\n".format(object_name))
    except ClientError as be:
        print("CLIENT ERROR: {0}\n".format(be))
    except Exception as e:
        print("Unable to delete object: {0}".format(e))



if __name__ == "__main__":
 

    if len(sys.argv) < 2:

        print(""" 
        This script deletes an object in IBM Cloud Object Storage.
        - item_name: name of the object in COS 

        Usage:  python """ + sys.argv[0] + " item_name " 
        )
        sys.exit(0)

    item_name=sys.argv[1]

    config = dotenv_values(".env") 

    # set proxy env
    os.environ['http_proxy']=config["HTTP_PROXY"]
    os.environ['https_proxy']=config["HTTPS_PROXY"] 


    # Constants for IBM COS values
    COS_ENDPOINT = "https://s3.us-east.cloud-object-storage.appdomain.cloud"
    COS_API_KEY_ID = config["COS_API_KEY_ID"]
    COS_INSTANCE_CRN ="crn:v1:bluemix:public:cloud-object-storage:global:a/c3afbcd1812c424a9161c85df5354aa0:00806315-44bb-4cfc-af85-5c259f4d09e9::"
    MY_BUCKET_NAME="cloud-object-storage-cos-standard-lbx"

    # Create resource
    cos_client = ibm_boto3.client("s3",
        ibm_api_key_id=COS_API_KEY_ID,
        ibm_service_instance_id=COS_INSTANCE_CRN,
        config=Config(signature_version="oauth"),
        endpoint_url=COS_ENDPOINT
    )

    #  get_buckets()
    print( " ~~~~~~~  before delete ~~~~~~~~~~~~~")
    get_bucket_contents(MY_BUCKET_NAME)
   
    # delete
    delete_item(MY_BUCKET_NAME, item_name)

    print( " ~~~~~~~  after delete ~~~~~~~~~~~~~")
    get_bucket_contents(MY_BUCKET_NAME)


