import boto3
import sys
import logging

sys.path.append("./site-packages")
from crhelper import CfnResource

helper = CfnResource()

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
handler = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter('[%(asctime)s %(levelname)s]: %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


@helper.create
def on_create(_, __):
    pass


@helper.update
def on_update(_, __):
    pass


def delete_sagemaker_endpoint(endpoint_name):
    sagemaker_client = boto3.client("sagemaker")
    try:
        sagemaker_client.delete_endpoint(EndpointName=endpoint_name)
        logger.info("Successfully deleted the endpoint: %s.", endpoint_name)
    except sagemaker_client.exceptions.ClientError as e:
        if "Could not find endpoint" in str(e):
            logger.warning("Could not find the endpoint called %s. Skip deleting the endpoint.", endpoint_name)
        else:
            raise e


def delete_sagemaker_endpoint_config(endpoint_config_name):
    sagemaker_client = boto3.client("sagemaker")
    try:
        sagemaker_client.delete_endpoint_config(EndpointConfigName=endpoint_config_name)
        logger.info("Successfully deleted the endpoint configuration called: %s.", endpoint_config_name)
    except sagemaker_client.exceptions.ClientError as e:
        if "Could not find endpoint configuration" in str(e):
            logger.warning("Could not find the endpoint configuration called: %s. Skip deleting the endpoint config.",
                            endpoint_config_name)
        else:
            raise e


def delete_sagemaker_model(model_name):
    sagemaker_client = boto3.client("sagemaker")
    try:
        sagemaker_client.delete_model(ModelName=model_name)
        logger.info("Successfully deleted the model called: %s.", model_name)
    except sagemaker_client.exceptions.ClientError as e:
        if "Could not find model" in str(e):
            logger.warning("Could not find the model called: %s. Skip deleting the model.", model_name)
        else:
            raise e


def delete_s3_objects(bucket_name):
    s3_resource = boto3.resource("s3")
    try:
        s3_resource.Bucket(bucket_name).objects.all().delete()
        logger.info("Successfully deleted the objects in the s3 bucket called: %s.", bucket_name)
    except s3_resource.meta.client.exceptions.NoSuchBucket:
        logger.warning("Could not find the s3 bucket called: %s. Skip deleting the s3 objects.", bucket_name)


def delete_s3_bucket(bucket_name):
    s3_resource = boto3.resource("s3")
    try:
        s3_resource.Bucket(bucket_name).delete()
        logger.info("Successfully deleted the bucket called: %s.", bucket_name)
    except s3_resource.meta.client.exceptions.NoSuchBucket:
        logger.warning("Could not find the bucket called: %s. Skip deleting the bucket.", bucket_name)


@helper.delete
def on_delete(event, __):
    # remove sagemaker endpoints
    solution_prefix = event["ResourceProperties"]["SolutionPrefix"]
    endpoint_names = [
        "{}-endpoint".format(solution_prefix),  # make sure it is the same as your endpoint name
    ]
    for endpoint_name in endpoint_names:
        delete_sagemaker_model(endpoint_name)
        delete_sagemaker_endpoint_config(endpoint_name)
        delete_sagemaker_endpoint(endpoint_name)

    # remove files in s3
    output_bucket = event["ResourceProperties"]["S3Bucket"]
    delete_s3_objects(output_bucket)

    # delete buckets
    delete_s3_bucket(output_bucket)


def handler(event, context):
    helper(event, context)
