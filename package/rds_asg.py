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


def start_or_stop_rds(in_service, rds_identifier, is_cluster):
    """
    Start or stop the RDS instance/cluster
    """
    if in_service == 0:
        LOGGER.info('The number of instances in service is 0; stopping RDS.')
        stop_rds(rds_identifier, is_cluster)

    if in_service > 0:
        LOGGER.info('The number of instances in service is %s; starting RDS.', in_service)
        start_rds(rds_identifier, is_cluster)

def stop_rds(rds_identifier, is_cluster):
    """
    Stop a RDS instance/cluster
    """
    LOGGER.info('Received STOP event.')
    status = get_rds_status(rds_identifier, is_cluster)
    if status != 'available':
        LOGGER.warning('The RDS instance/cluster is already stopped.')
        return

    if is_cluster:
        LOGGER.info('Stopping RDS cluster %s', rds_identifier)
        response = RDS_CLIENT.stop_db_cluster(DBClusterIdentifier=rds_identifier)
    else:
        LOGGER.info('Stopping RDS instance %s', rds_identifier)
        response = RDS_CLIENT.stop_db_instance(DBInstanceIdentifier=rds_identifier)

        LOGGER.debug(response)

def start_rds(rds_identifier, is_cluster):
    """
    Start a RDS instance/cluster
    """
    LOGGER.info('Received START event.')
    status = get_rds_status(rds_identifier, is_cluster)
    if status == 'available':
        LOGGER.warning('The RDS instance/cluster is already running.')
        return

    if is_cluster:
        LOGGER.info('Starting RDS cluster %s', rds_identifier)
        response = RDS_CLIENT.start_db_cluster(DBClusterIdentifier=rds_identifier)
    else:
        LOGGER.info('Starting RDS instance %s', rds_identifier)
        response = RDS_CLIENT.start_db_instance(DBInstanceIdentifier=rds_identifier)

        LOGGER.debug(response)

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

def get_instance_count(asg_name):
    """
    Return the number of instances currently in-service
    """
    in_service = 0

    response = ASG_CLIENT.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
    if 'AutoScalingGroups' in response and response['AutoScalingGroups']:
        asg = response['AutoScalingGroups'][0]
        if 'Instances' in asg:
            for instance in asg['Instances']:
                if instance['LifecycleState'] in ['Pending', 'InService']:
                    in_service += 1

    else:
        LOGGER.fatal('No information for ASG named %s', asg_name)
        in_service = -1

    LOGGER.info('There are (or about to be) %s instances in service', in_service)

    return in_service

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
    asg_name = os.getenv('ASG_NAME')

    LOGGER.info('RDS_IDENTIFIER=%s', rds_identifier)
    LOGGER.info('IS_CLUSTER=%s', is_cluster)
    LOGGER.info('ASG_NAME=%s', asg_name)

    LOGGER.info('EVENT=%s', event)

    if not rds_identifier:
        LOGGER.fatal('You must set your RDS_IDENTIFIER appropriately.')
        return

    if not asg_name:
        LOGGER.fatal('You must set your ASG_NAME appropriately.')
        return

    if 'detail' in event and event['detail']:
        if 'AutoScalingGroupName' in event['detail']:
            asg_name = event['detail']['AutoScalingGroupName']

            in_service = get_instance_count(asg_name)
            start_or_stop_rds(in_service, rds_identifier, is_cluster)
