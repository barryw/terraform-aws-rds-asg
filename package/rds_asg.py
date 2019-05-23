"""
Lambda function to start/stop an RDS instance/cluster based on the
number of instances attached to an autoscaling group. This can be
used to stop an RDS cluster/instance when there are no active EC2
instances attached to the group, and start an RDS cluster/instance
when the group scales up.
"""
import os
import logging

import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

RDS_CLIENT = boto3.client('rds')
ASG_CLIENT = boto3.client('autoscaling')

def scale_down(asg_name, rds_identifier, is_cluster):
    """
    Stop an RDS instance/cluster if we've scaled to 0 nodes
    """
    LOGGER.info('Received SCALE DOWN event.')

def scale_up(asg_name, rds_identifier, is_cluster):
    """
    Start an RDS instance/cluster if we've scaled > 0 nodes
    """
    LOGGER.info('Received SCALE UP event.')

def get_rds_status(rds_identifier, is_cluster):
    """
    Grab the database instance/cluster
    """
    status = ""

    if is_cluster:
        response = RDS_CLIENT.describe_db_clusters(DBClusterIdentifier=rds_identifier)
        if 'DBClusters' in response and response['DBClusters']:
            cluster = response['DBClusters'][0]
            status = cluster['Status']

    else:
        response = RDS_CLIENT.describe_db_instances(DBInstanceIdentifier=rds_identifier)
        if 'DBInstances' in response and response['DBInstances']:
            instance = response['DBInstances'][0]
            status = instance['DBInstanceStatus']

    return status

def lambda_handler(event, context):
    """
    Lambda event handler
    """
    skip_execution = os.getenv('SKIP_EXECUTION') == "true" or os.getenv('SKIP_EXECUTION') == '1'
    if skip_execution:
        LOGGER.warning('SKIP_EXECUTION is set to true - skipping execution.')
        return

    rds_identifier = os.getenv('RDS_IDENTIFIER')
    is_cluster = os.getenv('IS_CLUSTER', 'false') == 'true' or os.getenv('IS_CLUSTER', '0') == '1'
    up_event_arn = os.getenv('UP_EVENT_ARN')
    down_event_arn = os.getenv('DOWN_EVENT_ARN')
    asg_name = os.getenv('ASG_NAME')

    LOGGER.info('RDS_IDENTIFIER=%s', rds_identifier)
    LOGGER.info('IS_CLUSTER=%s', is_cluster)
    LOGGER.info('START_EVENT_ARN=%s', start_event_arn)
    LOGGER.info('STOP_EVENT_ARN=%s', stop_event_arn)
    LOGGER.info('ASG_NAME=%s', asg_name)

    if not rds_identifier:
        LOGGER.fatal('You must set your RDS_IDENTIFIER appropriately.')
        return

    if not asg_name:
        LOGGER.fatal('You must set your ASG_NAME appropriately.')
        return

    if 'resources' in event and event['resources']:
        source_event = event['resources'][0]
        if source_event == up_event_arn:
            scale_up(asg_name, rds_identifier, is_cluster)

        if source_event == down_event_arn:
            scale_down(asg_name, rds_identifier, is_cluster)
