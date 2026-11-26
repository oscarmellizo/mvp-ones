import importlib.util
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock


def _load_worker():
    boto3 = types.ModuleType("boto3")
    boto3.client = Mock()
    boto3.resource = Mock()
    botocore = types.ModuleType("botocore")
    exceptions = types.ModuleType("botocore.exceptions")
    exceptions.BotoCoreError = type("BotoCoreError", (Exception,), {})
    exceptions.ClientError = type("ClientError", (Exception,), {})
    sys.modules.setdefault("boto3", boto3)
    sys.modules.setdefault("botocore", botocore)
    sys.modules.setdefault("botocore.exceptions", exceptions)
    path = Path(__file__).with_name("index.py")
    spec = importlib.util.spec_from_file_location("photo_thumbnail_worker", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PhotoKeyRoutingTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.worker = _load_worker()

    def test_legacy_event_key_is_unchanged(self):
        self.assertEqual(
            ("event-123", "photo-42"),
            self.worker._parse_key(
                "eventos/event-123/guests/user-7/private/photo-42.jpg"
            ),
        )

    def test_collection_key_maps_to_deterministic_owner_shard(self):
        self.assertEqual(
            ("COLLECTION#collection-9#08", "photo-3"),
            self.worker._parse_key(
                "colecciones/collection-9/guests/user-7/private/photo-3.jpg"
            ),
        )

    def test_other_prefixes_are_rejected(self):
        self.assertEqual(
            (None, None),
            self.worker._parse_key("other/collection/guests/user/private/photo.jpg"),
        )


if __name__ == "__main__":
    unittest.main()
