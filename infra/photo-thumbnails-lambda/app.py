import base64
import io
import json
import os
import urllib.parse
import urllib.request

import boto3
from PIL import Image, ImageOps

s3 = boto3.client('s3')
secrets = boto3.client('secretsmanager')

M_WIDTH = int(os.environ.get('M_WIDTH', '1280'))
M_QUALITY = int(os.environ.get('M_QUALITY', '85'))
S_WIDTH = int(os.environ.get('S_WIDTH', '360'))
S_QUALITY = int(os.environ.get('S_QUALITY', '70'))


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
        return

    for rec in event.get('Records', []):
        s3info = (rec.get('s3') or {})
        obj = (s3info.get('object') or {})
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

        try:
            img = _load_jpeg(bucket, key)

            img_m = _resize_to_width(img, M_WIDTH)
            data_m = _save_jpeg_bytes(img_m, M_QUALITY)
            _put_jpeg(bucket, key_m, data_m)

            img_s = _resize_to_width(img, S_WIDTH)
            data_s = _save_jpeg_bytes(img_s, S_QUALITY)
            _put_jpeg(bucket, key_s, data_s)
        except Exception:
            # If thumbnailing fails we avoid calling backend ready.
            continue

        _call_backend_ready(event_id, photo_id, key_m, key_s)
