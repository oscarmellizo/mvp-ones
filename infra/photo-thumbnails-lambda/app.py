import base64
import io
import json
import os
import urllib.parse
import urllib.request

import boto3
from boto3.dynamodb.conditions import Key
from PIL import Image, ImageOps

s3 = boto3.client('s3')
secrets = boto3.client('secretsmanager')
ddb = boto3.resource('dynamodb')

M_WIDTH = int(os.environ.get('M_WIDTH', '1280'))
M_QUALITY = int(os.environ.get('M_QUALITY', '85'))
S_WIDTH = int(os.environ.get('S_WIDTH', '360'))
S_QUALITY = int(os.environ.get('S_QUALITY', '70'))


def _load_internal_basic_auth():
    arn = os.environ.get('INTERNAL_SECRET_ARN', '')
    print(f"INTERNAL_SECRET_ARN: {arn}")
    if not arn:
        print("ERROR: INTERNAL_SECRET_ARN not set")
        return None
    try:
        v = secrets.get_secret_value(SecretId=arn).get('SecretString', '{}')
        print(f"Secret value retrieved successfully")
        data = json.loads(v)
        print(f"Secret data parsed: username={data.get('username')}")
    except Exception as e:
        print(f"ERROR: Failed to load secret: {e}")
        data = {}
    u = (data.get('username') or '').strip()
    p = (data.get('password') or '').strip()
    if not u or not p:
        print(f"ERROR: username or password missing from secret")
        return None
    token = base64.b64encode((u + ':' + p).encode('utf-8')).decode('utf-8')
    print(f"Basic auth token generated successfully")
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


def _ws_subscriptions_table():
    name = (os.environ.get('WS_SUBSCRIPTIONS_TABLE') or '').strip()
    if not name:
        return None
    return ddb.Table(name)


def _ws_client():
    endpoint = (os.environ.get('WS_ENDPOINT') or '').strip()
    if not endpoint:
        return None
    return boto3.client('apigatewaymanagementapi', endpoint_url=endpoint)


def _publish_photo_ready(event_id: str, photo_id: str):
    if not event_id or not photo_id:
        return
    table = _ws_subscriptions_table()
    client = _ws_client()
    if table is None or client is None:
        return

    payload = json.dumps({
        "type": "photo.ready",
        "eventId": event_id,
        "photoId": photo_id,
    }).encode('utf-8')

    last_key = None
    while True:
        args = {
            'KeyConditionExpression': Key('eventId').eq(event_id),
            'Limit': 100,
        }
        if last_key:
            args['ExclusiveStartKey'] = last_key
        res = table.query(**args)
        items = res.get('Items') or []
        for it in items:
            cid = (it.get('connectionId') or '').strip()
            if not cid:
                continue
            try:
                client.post_to_connection(ConnectionId=cid, Data=payload)
            except Exception as e:
                code = None
                try:
                    code = getattr(getattr(e, 'response', None), 'get', lambda _k, _d=None: None)('ResponseMetadata', {}).get('HTTPStatusCode')
                except Exception:
                    code = None

                # Typical case when the client disconnected.
                if hasattr(client, 'exceptions') and hasattr(client.exceptions, 'GoneException') and isinstance(e, client.exceptions.GoneException):
                    table.delete_item(Key={'eventId': event_id, 'connectionId': cid})
                elif code == 410:
                    table.delete_item(Key={'eventId': event_id, 'connectionId': cid})

        last_key = res.get('LastEvaluatedKey')
        if not last_key:
            break


def _parse_key(key: str):
    # expected: eventos/<eventId>/guests/<guestId>/private/<photoId>.jpg
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


def _load_jpeg(bucket: str, key: str) -> Image.Image:
    obj = s3.get_object(Bucket=bucket, Key=key)
    body = obj['Body'].read()
    img = Image.open(io.BytesIO(body))
    img = ImageOps.exif_transpose(img)
    if img.mode not in ('RGB', 'L'):
        img = img.convert('RGB')
    elif img.mode == 'L':
        img = img.convert('RGB')
    return img


def _resize_to_width(img: Image.Image, target_width: int) -> Image.Image:
    if target_width <= 0:
        return img
    w, h = img.size
    if w <= target_width:
        return img
    ratio = target_width / float(w)
    target_height = max(1, int(h * ratio))
    return img.resize((target_width, target_height), resample=Image.Resampling.LANCZOS)


def _save_jpeg_bytes(img: Image.Image, quality: int) -> bytes:
    q = max(1, min(95, int(quality)))
    out = io.BytesIO()
    img.save(out, format='JPEG', quality=q, optimize=True, progressive=True)
    return out.getvalue()


def _put_jpeg(bucket: str, key: str, data: bytes):
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType='image/jpeg',
    )


def handler(event, context):
    bucket = os.environ.get('BUCKET')
    if not bucket:
        print("ERROR: BUCKET environment variable not set")
        return

    print(f"Processing event with {len(event.get('Records', []))} records")
    
    for rec in event.get('Records', []):
        s3info = (rec.get('s3') or {})
        obj = s3info.get('object') or {}
        key = obj.get('key')
        if not key:
            print("WARNING: No key in S3 event record")
            continue
        key = urllib.parse.unquote_plus(key)
        print(f"Processing S3 key: {key}")

        if key.endswith('_m.jpg') or key.endswith('_s.jpg'):
            print(f"Skipping thumbnail: {key}")
            continue

        event_id, photo_id = _parse_key(key)
        if not event_id or not photo_id:
            print(f"WARNING: Failed to parse key: {key}")
            continue
        
        print(f"Parsed event_id={event_id}, photo_id={photo_id}")

        key_m = key[:-4] + '_m.jpg'
        key_s = key[:-4] + '_s.jpg'

        try:
            print(f"Loading image from S3: {key}")
            img = _load_jpeg(bucket, key)
            print(f"Image loaded successfully")

            print(f"Generating medium thumbnail: {key_m}")
            img_m = _resize_to_width(img, M_WIDTH)
            data_m = _save_jpeg_bytes(img_m, M_QUALITY)
            _put_jpeg(bucket, key_m, data_m)
            print(f"Medium thumbnail saved")

            print(f"Generating small thumbnail: {key_s}")
            img_s = _resize_to_width(img, S_WIDTH)
            data_s = _save_jpeg_bytes(img_s, S_QUALITY)
            _put_jpeg(bucket, key_s, data_s)
            print(f"Small thumbnail saved")
        except Exception as e:
            print(f"ERROR: Thumbnail generation failed: {e}")
            # If thumbnailing fails we avoid calling backend ready.
            continue

        print(f"Calling backend ready endpoint")
        _call_backend_ready(event_id, photo_id, key_m, key_s)
        print(f"Publishing photo.ready event to WebSocket")
        _publish_photo_ready(event_id, photo_id)
        print(f"Photo processing completed successfully")
