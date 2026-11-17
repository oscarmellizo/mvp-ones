import base64
import io
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import boto3
from botocore.exceptions import BotoCoreError, ClientError

s3 = boto3.client('s3')
sqs = boto3.client('sqs')
secrets = boto3.client('secretsmanager')
ddb = boto3.resource('dynamodb')

# Try to import Pillow from Lambda layer, fallback to skip thumbnail generation
try:
    from PIL import Image, ImageOps, UnidentifiedImageError
    PILLOW_AVAILABLE = True
except ImportError:
    Image = None
    ImageOps = None
    UnidentifiedImageError = OSError
    PILLOW_AVAILABLE = False


def _load_internal_basic_auth():
    arn = os.environ.get('INTERNAL_SECRET_ARN', '')
    if not arn:
        return None
    
    try:
        response = secrets.get_secret_value(SecretId=arn)
        v = response.get('SecretString', '{}')
    except Exception:
        return None
    
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


class ProcessingError(Exception):
    def __init__(self, code, retryable, retry_after_seconds=None):
        super().__init__(code)
        self.code = code
        self.retryable = retryable
        self.retry_after_seconds = retry_after_seconds


def _call_backend(event_id, photo_id, action, body):
    base = os.environ.get('BACKEND_BASE_URL', '').rstrip('/')
    if not base:
        raise ProcessingError("backend_unavailable", True)
    auth = _internal_basic_auth_cached()
    if not auth:
        raise ProcessingError("backend_unavailable", True)

    url = (
        f"{base}/internal/events/{urllib.parse.quote(event_id)}"
        f"/photos/{urllib.parse.quote(photo_id)}/{action}"
    )
    payload = json.dumps(body).encode('utf-8')
    for attempt in range(1, 4):
        req = urllib.request.Request(url, data=payload, method='POST')
        req.add_header('Content-Type', 'application/json')
        req.add_header('User-Agent', 'ones-photo-thumbnails/1.0')
        req.add_header('Authorization', auth)
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = resp.read()
            if not raw:
                return {}
            result = json.loads(raw.decode('utf-8'))
            return result if isinstance(result, dict) else {}
        except urllib.error.HTTPError as exc:
            if exc.code == 429 or exc.code >= 500:
                print(f"backend_retry eventId={event_id} photoId={photo_id} status={exc.code} attempt={attempt}")
            else:
                raise ProcessingError("backend_rejected", False)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            print(
                f"backend_retry eventId={event_id} photoId={photo_id} "
                f"attempt={attempt} error={type(exc).__name__}"
            )
        if attempt < 3:
            time.sleep(min(2, 0.25 * (2 ** (attempt - 1))))
    raise ProcessingError("backend_unavailable", True)


def _call_backend_ready(event_id, photo_id, key_original, key_m, key_s):
    return _call_backend(
        event_id,
        photo_id,
        "ready",
        {
            "s3KeyOriginal": key_original,
            "s3KeyMedium": key_m,
            "s3KeySmall": key_s,
        },
    )


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
        print("ERROR: WS subscriptions table or client not configured")
        return

    payload = json.dumps({
        "type": "photo.ready",
        "eventId": event_id,
        "photoId": photo_id,
    }).encode('utf-8')

    last_key = None
    while True:
        args = {
            'KeyConditionExpression': 'eventId = :eventId',
            'ExpressionAttributeValues': {':eventId': event_id},
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

                if hasattr(client, 'exceptions') and hasattr(client.exceptions, 'GoneException') and isinstance(e, client.exceptions.GoneException):
                    table.delete_item(Key={'eventId': event_id, 'connectionId': cid})
                elif code == 410:
                    table.delete_item(Key={'eventId': event_id, 'connectionId': cid})

        last_key = res.get('LastEvaluatedKey')
        if not last_key:
            break
    print(f"Published photo.ready event for {photo_id}")


def _load_jpeg(bucket: str, key: str):
    obj = s3.get_object(Bucket=bucket, Key=key)
    body = obj['Body'].read()
    img = Image.open(__import__('io').BytesIO(body))
    img = ImageOps.exif_transpose(img)
    if img.mode not in ('RGB', 'L'):
        img = img.convert('RGB')
    elif img.mode == 'L':
        img = img.convert('RGB')
    return img


def _resize_to_width(img, target_width: int):
    if target_width <= 0:
        return img
    w, h = img.size
    if w <= target_width:
        return img
    ratio = target_width / float(w)
    target_height = max(1, int(h * ratio))
    return img.resize((target_width, target_height), resample=Image.Resampling.LANCZOS)


def _save_jpeg_bytes(img, quality: int):
    q = max(1, min(95, int(quality)))
    out = __import__('io').BytesIO()
    img.save(out, format='JPEG', quality=q, optimize=True, progressive=True)
    return out.getvalue()


def _put_jpeg(bucket: str, key: str, data: bytes):
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType='image/jpeg',
    )


def _jobs_from_body(body):
    if not isinstance(body, dict):
        return []
    if isinstance(body.get('Records'), list):
        jobs = []
        for record in body['Records']:
            s3info = record.get('s3') or {}
            bucket_info = s3info.get('bucket') or {}
            obj = s3info.get('object') or {}
            key = obj.get('key')
            if not key or not bucket_info.get('name'):
                continue
            key = urllib.parse.unquote_plus(key)
            if key.endswith(('_m.jpg', '_s.jpg')):
                continue
            event_id, photo_id = _parse_key(key)
            if event_id and photo_id:
                jobs.append({
                    "eventId": event_id,
                    "photoId": photo_id,
                    "s3KeyOriginal": key,
                    "manualRetry": False,
                })
        return jobs
    if all(body.get(field) for field in ("eventId", "photoId", "s3KeyOriginal")):
        return [body]
    return []


def _retry_delay(receive_count):
    initial = max(1, int(os.environ.get('PROCESSING_INITIAL_RETRY_DELAY_SECONDS', '5')))
    maximum = max(initial, min(900, int(os.environ.get('PROCESSING_MAX_RETRY_DELAY_SECONDS', '300'))))
    return min(maximum, initial * (2 ** max(0, receive_count - 1)))


def _call_backend_claim(job):
    return _call_backend(
        job["eventId"],
        job["photoId"],
        "processing",
        {
            "s3KeyOriginal": job["s3KeyOriginal"],
            "manualRetry": bool(job.get("manualRetry")),
        },
    )


def _call_backend_retrying(job, error_code, retry_at_epoch):
    return _call_backend(
        job["eventId"],
        job["photoId"],
        "processing-retrying",
        {
            "s3KeyOriginal": job["s3KeyOriginal"],
            "errorCode": error_code,
            "retryAtEpoch": retry_at_epoch,
        },
    )


def _call_backend_failed(job, error_code):
    return _call_backend(
        job["eventId"],
        job["photoId"],
        "processing-failed",
        {
            "s3KeyOriginal": job["s3KeyOriginal"],
            "errorCode": error_code,
        },
    )


def _mark_retrying(job, error_code, receive_count):
    delay = _retry_delay(receive_count)
    print(
        f"photo_processing_retry eventId={job['eventId']} photoId={job['photoId']} "
        f"attempt={receive_count} errorCode={error_code}"
    )
    return _call_backend_retrying(job, error_code, int(time.time() * 1000) + delay * 1000)


def _mark_failed(job, error_code):
    print(
        f"photo_processing_failed eventId={job['eventId']} photoId={job['photoId']} "
        f"errorCode={error_code}"
    )
    return _call_backend_failed(job, error_code)


def _process_photo(job, receive_count):
    event_id = str(job["eventId"]).strip()
    photo_id = str(job["photoId"]).strip()
    key = str(job["s3KeyOriginal"]).strip()
    parsed_event, parsed_photo = _parse_key(key)
    if parsed_event != event_id or parsed_photo != photo_id:
        raise ProcessingError("invalid_key", False)

    claim = _call_backend_claim(job)
    claim_status = str(claim.get('status') or '').lower()
    if claim_status == 'claimed':
        print(
            f"photo_processing_started eventId={event_id} photoId={photo_id} "
            f"attempt={claim.get('attempts', receive_count)}"
        )
    if claim_status in ('ready', 'failed'):
        return
    if claim_status == 'busy':
        lease_until = claim.get('leaseUntilEpoch')
        remaining = max(1, int((int(lease_until) - time.time() * 1000 + 999) // 1000)) \
            if lease_until is not None else _retry_delay(receive_count)
        raise ProcessingError("processing_busy", True, remaining)
    if claim_status == 'not_found':
        print(f"photo_processing_waiting_for_complete eventId={event_id} photoId={photo_id}")
        raise ProcessingError("photo_not_completed", True)
    if claim_status != 'claimed':
        raise ProcessingError("invalid_key", False)

    key_m = key[:-4] + '_m.jpg'
    key_s = key[:-4] + '_s.jpg'
    try:
        if not PILLOW_AVAILABLE:
            raise ProcessingError("processing_unavailable", True)
        img = _load_jpeg(os.environ['BUCKET'], key)
        data_m = _save_jpeg_bytes(_resize_to_width(img, 1280), 85)
        _put_jpeg(os.environ['BUCKET'], key_m, data_m)
        data_s = _save_jpeg_bytes(_resize_to_width(img, 360), 70)
        _put_jpeg(os.environ['BUCKET'], key_s, data_s)
        ready = _call_backend_ready(event_id, photo_id, key, key_m, key_s)
        if str(ready.get('status') or '').lower() != 'ready':
            raise ProcessingError("backend_unavailable", True)
    except ProcessingError as exc:
        if exc.retryable:
            update = _mark_retrying(job, exc.code, receive_count)
            if update.get("updated") is False:
                return
            raise
        _mark_failed(job, exc.code)
        return
    except ClientError as exc:
        code = str((exc.response.get('Error') or {}).get('Code') or '')
        if code in ('NoSuchKey', 'NotFound', '404'):
            _mark_failed(job, "source_missing")
            return
        update = _mark_retrying(job, "s3_unavailable", receive_count)
        if update.get("updated") is False:
            return
        raise ProcessingError("s3_unavailable", True)
    except (UnidentifiedImageError, OSError):
        _mark_failed(job, "invalid_image")
        return
    except BotoCoreError:
        update = _mark_retrying(job, "s3_unavailable", receive_count)
        if update.get("updated") is False:
            return
        raise ProcessingError("s3_unavailable", True)
    except Exception as exc:
        if type(exc).__name__ == "DecompressionBombError":
            _mark_failed(job, "invalid_image")
            return
        update = _mark_retrying(job, "processing_failed", receive_count)
        if update.get("updated") is False:
            return
        raise ProcessingError("processing_failed", True) from exc

    try:
        _publish_photo_ready(event_id, photo_id)
    except Exception as exc:
        print(f"photo_ready_publish_failed eventId={event_id} photoId={photo_id} error={type(exc).__name__}")
    print(f"photo_processing_ready eventId={event_id} photoId={photo_id}")


def _record_jobs(message, receive_count):
    try:
        body = json.loads(message.get('body') or '{}')
    except (TypeError, json.JSONDecodeError):
        return
    for job in _jobs_from_body(body):
        _process_photo(job, receive_count)


def _record_dlq_jobs(message):
    try:
        body = json.loads(message.get('body') or '{}')
    except (TypeError, json.JSONDecodeError):
        return
    for job in _jobs_from_body(body):
        _mark_failed(job, "retry_exhausted")


def _change_message_visibility(record, delay_seconds):
    receipt_handle = record.get('receiptHandle')
    queue_url = os.environ.get('PROCESSING_QUEUE_URL', '').strip()
    if not receipt_handle or not queue_url:
        return
    try:
        sqs.change_message_visibility(
            QueueUrl=queue_url,
            ReceiptHandle=receipt_handle,
            VisibilityTimeout=max(1, min(900, int(delay_seconds))),
        )
    except Exception as exc:
        print(f"visibility_update_failed messageId={record.get('messageId')} error={type(exc).__name__}")


def _parse_key(key: str):
    parts = key.split('/')
    if len(parts) != 6:
        return None, None
    if parts[0] != 'eventos' or parts[2] != 'guests' or parts[4] != 'private':
        return None, None
    event_id = parts[1]
    filename = parts[-1]
    if not parts[3] or not filename.endswith('.jpg'):
        return None, None
    photo_id = filename[:-4]
    return event_id, photo_id


def _legacy_handler(event, context):
    bucket = os.environ.get('BUCKET')
    if not bucket:
        print("ERROR: BUCKET environment variable not set")
        return {"ok": False}

    print(f"Processing event with {len(event.get('Records', []))} records")
    
    for rec in event.get('Records', []):
        s3info = rec.get('s3') or {}
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

        # Generate thumbnails if Pillow is available
        if PILLOW_AVAILABLE:
            try:
                print(f"Loading image from S3: {key}")
                img = _load_jpeg(bucket, key)
                print(f"Image loaded successfully")

                print(f"Generating medium thumbnail: {key_m}")
                img_m = _resize_to_width(img, 1280)
                data_m = _save_jpeg_bytes(img_m, 85)
                _put_jpeg(bucket, key_m, data_m)
                print(f"Medium thumbnail saved")

                print(f"Generating small thumbnail: {key_s}")
                img_s = _resize_to_width(img, 360)
                data_s = _save_jpeg_bytes(img_s, 70)
                _put_jpeg(bucket, key_s, data_s)
                print(f"Small thumbnail saved")
            except Exception as e:
                print(f"ERROR: Thumbnail generation failed: {e}")
                # If thumbnailing fails we avoid calling backend ready.
                continue
        else:
            print(f"WARNING: Pillow not available, using original key as fallback for thumbnails")
            key_m = key
            key_s = key

        print(f"Calling backend ready endpoint")
        _call_backend_ready(event_id, photo_id, key, key_m, key_s)
        print(f"Publishing photo.ready event to WebSocket")
        _publish_photo_ready(event_id, photo_id)
        print(f"Photo processing completed successfully")

    return {"ok": True}


def handler(event, context):
    if not os.environ.get('BUCKET'):
        raise RuntimeError("BUCKET environment variable not set")

    records = event.get('Records') or []
    failed = []
    for record in records:
        if record.get('eventSource') != 'aws:sqs':
            jobs = _jobs_from_body({"Records": [record]})
            for job in jobs:
                try:
                    _process_photo(job, 1)
                except ProcessingError as exc:
                    if exc.retryable:
                        raise
                    _mark_failed(job, exc.code)
            continue

        is_dlq = record.get('eventSourceARN') == os.environ.get('PROCESSING_DLQ_ARN')
        try:
            if is_dlq:
                _record_dlq_jobs(record)
            else:
                receive_count = int(
                    (record.get('attributes') or {}).get('ApproximateReceiveCount') or 1
                )
                _record_jobs(record, receive_count)
        except ProcessingError as exc:
            if is_dlq:
                failed.append({"itemIdentifier": record.get('messageId')})
                continue
            if exc.retryable:
                receive_count = int(
                    (record.get('attributes') or {}).get('ApproximateReceiveCount') or 1
                )
                _change_message_visibility(
                    record,
                    exc.retry_after_seconds or _retry_delay(receive_count),
                )
                failed.append({"itemIdentifier": record.get('messageId')})
                continue
            try:
                body = json.loads(record.get('body') or '{}')
                for job in _jobs_from_body(body):
                    _mark_failed(job, exc.code)
            except Exception as mark_error:
                print(
                    f"photo_failure_update_failed messageId={record.get('messageId')} "
                    f"error={type(mark_error).__name__}"
                )
                failed.append({"itemIdentifier": record.get('messageId')})

    return {"batchItemFailures": failed}
