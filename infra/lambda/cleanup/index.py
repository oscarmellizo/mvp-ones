import json
import boto3
import urllib.request

s3 = boto3.client('s3')
ecr = boto3.client('ecr')


def _send(event, context, status, data=None, reason=None, physical_id=None):
    response_url = event['ResponseURL']
    body = {
        'Status': status,
        'Reason': reason or ('See CloudWatch Log Stream: ' + context.log_stream_name),
        'PhysicalResourceId': physical_id or context.log_stream_name,
        'StackId': event['StackId'],
        'RequestId': event['RequestId'],
        'LogicalResourceId': event['LogicalResourceId'],
        'Data': data or {},
    }
    req = urllib.request.Request(
        response_url,
        data=json.dumps(body).encode('utf-8'),
        method='PUT',
        headers={'content-type': ''}
    )
    with urllib.request.urlopen(req) as f:
        f.read()


def _empty_bucket(bucket):
    versioning = s3.get_bucket_versioning(Bucket=bucket).get('Status') == 'Enabled'
    if versioning:
        paginator = s3.get_paginator('list_object_versions')
        for page in paginator.paginate(Bucket=bucket):
            to_delete = []
            for v in page.get('Versions', []):
                to_delete.append({'Key': v['Key'], 'VersionId': v['VersionId']})
            for v in page.get('DeleteMarkers', []):
                to_delete.append({'Key': v['Key'], 'VersionId': v['VersionId']})
            if to_delete:
                s3.delete_objects(Bucket=bucket, Delete={'Objects': to_delete, 'Quiet': True})
    else:
        paginator = s3.get_paginator('list_objects_v2')
        for page in paginator.paginate(Bucket=bucket):
            objs = [{'Key': o['Key']} for o in page.get('Contents', [])]
            if objs:
                s3.delete_objects(Bucket=bucket, Delete={'Objects': objs, 'Quiet': True})


def _delete_all_ecr_images(repo_name):
    paginator = ecr.get_paginator('list_images')
    for page in paginator.paginate(repositoryName=repo_name, filter={'tagStatus': 'ANY'}):
        ids = page.get('imageIds', [])
        if ids:
            ecr.batch_delete_image(repositoryName=repo_name, imageIds=ids)


def handler(event, context):
    try:
        props = event.get('ResourceProperties', {})
        buckets = props.get('Buckets', [])
        repo = props.get('EcrRepositoryName', '')

        if event.get('RequestType') == 'Delete':
            for b in buckets:
                _empty_bucket(b)
            if repo:
                _delete_all_ecr_images(repo)

        _send(event, context, 'SUCCESS', data={'Cleaned': 'true'})
    except Exception as e:
        _send(event, context, 'FAILED', reason=str(e))
