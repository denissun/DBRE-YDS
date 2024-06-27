# Script: list_objects_cos.py 
# Purpose: list objects in the IBM Cloud Object Storge
#
# Note: 
#   set up venv for using in laptop
#      C:\Users\vxxxxx\Denis_files\python_proj\practise\venv311\Scripts\activate.bat
#
#   ref: https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-python


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


def multi_part_upload(bucket_name, item_name, file_path):
    try:
        print("Starting file transfer for {0} to bucket: {1}\n".format(item_name, bucket_name))
        # set 5 MB chunks
        part_size = 1024 * 1024 * 5

        # set threadhold to 15 MB
        file_threshold = 1024 * 1024 * 15

        # set the transfer threshold and chunk size
        transfer_config = ibm_boto3.s3.transfer.TransferConfig(
            multipart_threshold=file_threshold,
            multipart_chunksize=part_size
        )

        # the upload_fileobj method will automatically execute a multi-part upload
        # in 5 MB chunks for all files over 15 MB
        with open(file_path, "rb") as file_data:
            cos_client.upload_fileobj(
                Bucket=bucket_name,
                Key=item_name,
                Fileobj=file_data,
                Config=transfer_config
            )

        print("Transfer for {0} Complete!\n".format(item_name))
    except ClientError as be:
        print("CLIENT ERROR: {0}\n".format(be))
    except Exception as e:
        print("Unable to complete multi-part upload: {0}".format(e))



if __name__ == "__main__":
    config = dotenv_values(".env") 

    # set proxy env
    os.environ['http_proxy']=config["HTTP_PROXY"]
    os.environ['https_proxy']=config["HTTPS_PROXY"] 


    # Constants for IBM COS values
    COS_ENDPOINT = "https://s3.us-east.cloud-object-storage.appdomain.cloud"
    COS_API_KEY_ID = config["COS_API_KEY_ID"]
    COS_INSTANCE_CRN ="crn:v1:bluemix:public:cloud-object-storage:global:a/c3afbcd1812c424a9161c85df5354aa0:00806315-44bb-4cfc-af85-5c259f4d09e9::"

    # Create resource
    cos_client = ibm_boto3.client("s3",
        ibm_api_key_id=COS_API_KEY_ID,
        ibm_service_instance_id=COS_INSTANCE_CRN,
        config=Config(signature_version="oauth"),
        endpoint_url=COS_ENDPOINT
    )

    # get_buckets()
    # bucket name hard-coded
    get_bucket_contents("cloud-object-storage-cos-standard-lbx")
