import base64
import json
import os
import urllib.parse
import urllib.request

import boto3

s3 = boto3.client('s3')
secrets = boto3.client('secretsmanager')


def _load_internal_basic_auth():
    arn = os.environ.get('INTERNAL_SECRET_ARN', '')
    if not arn:
        return None
    v = secrets.get_secret_value(SecretId=arn).get('SecretString', '{}')
    try:
        data = json.loads(v)
    except Exception:
        data = {}
    u = (data.get('username') or '').strip()
    p = (data.get('password') or '').strip()
    if not u or not p:
        return None
    token = base64.b64encode((u + ':' + p).encode('utf-8')).decode('utf-8')
    return 'Basic ' + token


def _call_backend_ready(event_id, photo_id, key_m, key_s):
    base = os.environ.get('BACKEND_BASE_URL', '').rstrip('/')
    if not base:
        return

    url = f"{base}/internal/events/{urllib.parse.quote(event_id)}/photos/{urllib.parse.quote(photo_id)}/ready"
    auth = _load_internal_basic_auth()
    if not auth:
        return

    body = json.dumps({"s3KeyMedium": key_m, "s3KeySmall": key_s}).encode('utf-8')
    req = urllib.request.Request(url, data=body, method='POST')
    req.add_header('Content-Type', 'application/json')
    req.add_header('Authorization', auth)
    with urllib.request.urlopen(req, timeout=10) as resp:
        resp.read()


def _parse_key(key: str):
    parts = key.split('/')
    if len(parts) < 6:
        return None, None
    if parts[0] != 'eventos':
        return None, None
    event_id = parts[1]
    filename = parts[-1]
    if not filename.endswith('.jpg'):
        return None, None
    photo_id = filename[:-4]
    return event_id, photo_id


def handler(event, context):
    bucket = os.environ.get('BUCKET')
    if not bucket:
        return {"ok": False}

    for rec in event.get('Records', []):
        s3info = rec.get('s3') or {}
        obj = s3info.get('object') or {}
        key = obj.get('key')
        if not key:
            continue
        key = urllib.parse.unquote_plus(key)

        if key.endswith('_m.jpg') or key.endswith('_s.jpg'):
            continue

        event_id, photo_id = _parse_key(key)
        if not event_id or not photo_id:
            continue

        key_m = key[:-4] + '_m.jpg'
        key_s = key[:-4] + '_s.jpg'

        copy_source = {'Bucket': bucket, 'Key': key}
        s3.copy_object(Bucket=bucket, Key=key_m, CopySource=copy_source, ContentType='image/jpeg', MetadataDirective='REPLACE')
        s3.copy_object(Bucket=bucket, Key=key_s, CopySource=copy_source, ContentType='image/jpeg', MetadataDirective='REPLACE')

        _call_backend_ready(event_id, photo_id, key_m, key_s)

    return {"ok": True}
