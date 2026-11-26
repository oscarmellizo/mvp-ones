import importlib.util
import json
import pathlib
import sys
import unittest
from datetime import datetime, timezone
from unittest.mock import MagicMock, patch


ROOT = pathlib.Path(__file__).resolve().parents[3]
LAMBDA_PATHS = (
    ROOT / "infra" / "photo-thumbnails-lambda" / "app.py",
    ROOT / "infra" / "lambda" / "photo-thumbnails-zip" / "index.py",
)


def load_handler(path, name):
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HANDLERS = (
    load_handler(LAMBDA_PATHS[0], "photo_image_handler"),
    load_handler(LAMBDA_PATHS[1], "photo_zip_handler"),
)


def s3_event(key):
    return {
        "Records": [{
            "s3": {
                "bucket": {"name": "photos"},
                "object": {"key": key},
            }
        }]
    }


class ThumbnailWorkerTests(unittest.TestCase):
    def test_internal_basic_auth_is_cached_for_each_deployed_handler(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                with (
                    patch.object(handler, "_INTERNAL_BASIC_AUTH", None),
                    patch.object(handler, "_INTERNAL_BASIC_AUTH_LOADED", False),
                    patch.object(
                        handler,
                        "_load_internal_basic_auth",
                        return_value="Basic dXNlcjpwYXNz",
                    ) as load_auth,
                ):
                    self.assertEqual(
                        handler._internal_basic_auth_cached(),
                        "Basic dXNlcjpwYXNz",
                    )
                    self.assertEqual(
                        handler._internal_basic_auth_cached(),
                        "Basic dXNlcjpwYXNz",
                    )

                load_auth.assert_called_once_with()

    def test_s3_event_parser_skips_generated_variants(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                body = {
                    "Records": [
                        s3_event("eventos/event-1/guests/user-1/private/photo-1.jpg")["Records"][0],
                        s3_event("eventos/event-1/guests/user-1/private/photo-1_m.jpg")["Records"][0],
                    ]
                }

                jobs = handler._jobs_from_body(body)

                self.assertEqual(len(jobs), 1)
                self.assertEqual(jobs[0]["eventId"], "event-1")
                self.assertEqual(jobs[0]["photoId"], "photo-1")

    def test_collection_s3_event_parser_uses_java_compatible_shard(self):
        photo_id = "photo-1"
        java_hash = 0
        for char in photo_id:
            java_hash = (31 * java_hash + ord(char)) & 0xFFFFFFFF
        expected_owner = f"COLLECTION#collection-1#{java_hash % 16:02d}"

        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                jobs = handler._jobs_from_body(s3_event(
                    "colecciones/collection-1/guests/user-1/private/photo-1.jpg"
                ))

                self.assertEqual(len(jobs), 1)
                self.assertEqual(jobs[0]["eventId"], expected_owner)
                self.assertEqual(jobs[0]["photoId"], photo_id)

    def test_backend_callback_routes_to_owner_type(self):
        response = MagicMock()
        response.__enter__.return_value = response
        response.read.return_value = b'{}'

        for handler in HANDLERS:
            for owner_ref, expected_path in (
                (
                    "COLLECTION#collection-1#03",
                    "/internal/collections/collection-1/",
                ),
                ("event-1", "/internal/events/event-1/"),
            ):
                with self.subTest(
                    handler=handler.__name__, owner_ref=owner_ref
                ):
                    with (
                        patch.dict(handler.os.environ, {
                            "BACKEND_BASE_URL": "http://backend",
                        }),
                        patch.object(
                            handler, "_internal_basic_auth_cached",
                            return_value="Basic dXNlcjpwYXNz",
                        ),
                        patch.object(
                            handler.urllib.request,
                            "urlopen",
                            return_value=response,
                        ) as urlopen,
                    ):
                        handler._call_backend(
                            owner_ref, "photo-1", "processing", {}
                        )

                    request = urlopen.call_args.args[0]
                    self.assertEqual(
                        request.full_url,
                        f"http://backend{expected_path}photos/"
                        "photo-1/processing",
                    )

    def test_photo_ready_uses_logical_collection_subscription(self):
        for handler in HANDLERS:
            for owner_ref, subscription_id in (
                ("COLLECTION#collection-1#03", "COLLECTION#collection-1"),
                ("event-1", "event-1"),
            ):
                with self.subTest(
                    handler=handler.__name__, owner_ref=owner_ref
                ):
                    table = MagicMock()
                    table.query.return_value = {
                        "Items": [{"connectionId": "connection-1"}],
                    }
                    client = MagicMock()

                    with (
                        patch.object(
                            handler, "_ws_subscriptions_table", return_value=table
                        ),
                        patch.object(handler, "_ws_client", return_value=client),
                    ):
                        handler._publish_photo_ready(owner_ref, "photo-1")

                    query_args = table.query.call_args.kwargs
                    values = query_args.get("ExpressionAttributeValues")
                    if values is not None:
                        self.assertEqual(values[":eventId"], subscription_id)
                    else:
                        condition_values = query_args[
                            "KeyConditionExpression"
                        ]._values
                        self.assertEqual(condition_values[-1], subscription_id)
                    payload = json.loads(
                        client.post_to_connection.call_args.kwargs["Data"]
                    )
                    self.assertEqual(payload["type"], "photo.ready")
                    self.assertEqual(payload["eventId"], subscription_id)

    def test_manual_retry_message_is_normalized(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                job = {
                    "eventId": "event-1",
                    "photoId": "photo-1",
                    "s3KeyOriginal": "eventos/event-1/guests/user-1/private/photo-1.jpg",
                    "manualRetry": True,
                    "jobId": "retry-1",
                }

                self.assertEqual(handler._jobs_from_body(job), [job])

    def test_backend_ready_failure_never_publishes_photo_ready(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                if hasattr(handler, "PILLOW_AVAILABLE"):
                    setattr(handler, "PILLOW_AVAILABLE", True)
                job = {
                    "eventId": "event-1",
                    "photoId": "photo-1",
                    "s3KeyOriginal": "eventos/event-1/guests/user-1/private/photo-1.jpg",
                    "manualRetry": False,
                }
                with (
                    patch.dict(handler.os.environ, {"BUCKET": "photos"}),
                    patch.object(handler, "_call_backend_claim", return_value={
                        "status": "claimed",
                        "attempts": 1,
                    }),
                    patch.object(handler, "_load_jpeg", return_value=object()),
                    patch.object(handler, "_resize_to_width", return_value=object()),
                    patch.object(handler, "_save_jpeg_bytes", return_value=b"thumbnail"),
                    patch.object(handler, "_put_jpeg"),
                    patch.object(
                        handler,
                        "_call_backend_ready",
                        side_effect=handler.ProcessingError("backend_rejected", False),
                    ),
                    patch.object(handler, "_mark_failed") as mark_failed,
                    patch.object(handler, "_publish_photo_ready") as publish_ready,
                ):
                    handler._process_photo(job, 1)

                mark_failed.assert_called_once()
                publish_ready.assert_not_called()

    def test_invalid_image_is_terminal_and_does_not_retry(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                if hasattr(handler, "PILLOW_AVAILABLE"):
                    setattr(handler, "PILLOW_AVAILABLE", True)
                job = {
                    "eventId": "event-1",
                    "photoId": "photo-1",
                    "s3KeyOriginal": "eventos/event-1/guests/user-1/private/photo-1.jpg",
                    "manualRetry": False,
                }
                with (
                    patch.dict(handler.os.environ, {"BUCKET": "photos"}),
                    patch.object(handler, "_call_backend_claim", return_value={
                        "status": "claimed",
                        "attempts": 1,
                    }),
                    patch.object(
                        handler,
                        "_load_jpeg",
                        side_effect=handler.UnidentifiedImageError("invalid"),
                    ),
                    patch.object(handler, "_mark_failed") as mark_failed,
                    patch.object(handler, "_mark_retrying") as mark_retrying,
                ):
                    handler._process_photo(job, 1)

                mark_failed.assert_called_once_with(job, "invalid_image")
                mark_retrying.assert_not_called()

    def test_dlq_message_marks_the_photo_failed(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                record = {
                    "eventSource": "aws:sqs",
                    "eventSourceARN": "arn:aws:sqs:us-east-1:123:photo-dlq",
                    "messageId": "message-dlq",
                    "body": json.dumps(s3_event(
                        "eventos/event-1/guests/user-1/private/photo-1.jpg"
                    )),
                }
                with (
                    patch.dict(handler.os.environ, {
                        "BUCKET": "photos",
                        "PROCESSING_DLQ_ARN": record["eventSourceARN"],
                    }),
                    patch.object(handler, "_call_backend_failed") as mark_failed,
                ):
                    result = handler.handler({"Records": [record]}, None)

                self.assertEqual(result, {"batchItemFailures": []})
                mark_failed.assert_called_once()
                self.assertEqual(mark_failed.call_args.args[1], "retry_exhausted")

    def test_dlq_recovers_missing_photo_metadata_from_existing_s3_original(self):
        last_modified = datetime(2026, 11, 17, 22, 10, tzinfo=timezone.utc)
        job = {
            "eventId": "event-1",
            "photoId": "photo-1",
            "s3KeyOriginal": "eventos/event-1/guests/user-1/private/photo-1.jpg",
            "manualRetry": False,
        }
        record = {
            "eventSource": "aws:sqs",
            "eventSourceARN": "arn:aws:sqs:us-east-1:123:photo-dlq",
            "messageId": "message-dlq",
            "body": json.dumps(job),
        }

        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                with (
                    patch.dict(handler.os.environ, {
                        "BUCKET": "photos",
                        "PROCESSING_DLQ_ARN": record["eventSourceARN"],
                    }),
                    patch.object(handler, "_call_backend_failed", return_value={"updated": False}),
                    patch.object(handler, "_call_backend_recover", return_value={
                        "status": "uploaded",
                        "processingQueued": True,
                    }) as recover,
                    patch.object(handler.s3, "head_object", return_value={
                        "LastModified": last_modified,
                    }),
                ):
                    result = handler.handler({"Records": [record]}, None)

                self.assertEqual(result, {"batchItemFailures": []})
                recover.assert_called_once_with(job, last_modified.isoformat())

    def test_retryable_sqs_failure_returns_only_failed_message(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                record = {
                    "eventSource": "aws:sqs",
                    "eventSourceARN": "arn:aws:sqs:us-east-1:123:photo-work",
                    "messageId": "message-1",
                    "receiptHandle": "receipt-1",
                    "attributes": {"ApproximateReceiveCount": "2"},
                    "body": json.dumps(s3_event(
                        "eventos/event-1/guests/user-1/private/photo-1.jpg"
                    )),
                }
                event = {"Records": [record]}
                with (
                    patch.dict(handler.os.environ, {
                        "BUCKET": "photos",
                        "PROCESSING_DLQ_ARN": "arn:aws:sqs:us-east-1:123:photo-dlq",
                    }),
                    patch.object(
                        handler,
                        "_record_jobs",
                        side_effect=handler.ProcessingError("s3_unavailable", True),
                    ),
                    patch.object(handler, "_change_message_visibility") as change_visibility,
                ):
                    result = handler.handler(event, None)

                self.assertEqual(result, {
                    "batchItemFailures": [{"itemIdentifier": "message-1"}]
                })
                change_visibility.assert_called_once()

    def test_busy_duplicate_waits_for_the_current_processing_lease(self):
        for handler in HANDLERS:
            with self.subTest(handler=handler.__name__):
                record = {
                    "eventSource": "aws:sqs",
                    "eventSourceARN": "arn:aws:sqs:us-east-1:123:photo-work",
                    "messageId": "duplicate-1",
                    "receiptHandle": "receipt-1",
                    "attributes": {"ApproximateReceiveCount": "1"},
                    "body": json.dumps(s3_event(
                        "eventos/event-1/guests/user-1/private/photo-1.jpg"
                    )),
                }
                with (
                    patch.dict(handler.os.environ, {
                        "BUCKET": "photos",
                        "PROCESSING_DLQ_ARN": "arn:aws:sqs:us-east-1:123:photo-dlq",
                    }),
                    patch.object(
                        handler,
                        "_record_jobs",
                        side_effect=handler.ProcessingError("processing_busy", True, 37),
                    ),
                    patch.object(handler, "_change_message_visibility") as change_visibility,
                ):
                    result = handler.handler({"Records": [record]}, None)

                self.assertEqual(
                    result,
                    {"batchItemFailures": [{"itemIdentifier": "duplicate-1"}]},
                )
                change_visibility.assert_called_once_with(record, 37)


if __name__ == "__main__":
    unittest.main()
