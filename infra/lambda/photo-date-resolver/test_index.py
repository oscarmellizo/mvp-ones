import os
import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("index.py")
SPEC = importlib.util.spec_from_file_location("photo_date_resolver", MODULE_PATH)
resolver = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(resolver)


class PhotoDateResolverTests(unittest.TestCase):
    def test_bedrock_receives_only_filenames_and_uses_tool_schema(self):
        class FakeBedrock:
            request = None

            def converse(self, **kwargs):
                self.request = kwargs
                return {
                    "output": {
                        "message": {
                            "content": [{
                                "toolUse": {
                                    "name": "resolve_photo_dates",
                                    "input": {"items": [{
                                        "dateValue": "2024-06-27",
                                        "precision": "day",
                                        "evidence": "2024-06-27",
                                        "confidence": 0.95,
                                    }]},
                                },
                            }],
                        },
                    },
                }

        previous_client = resolver._bedrock_client
        previous_model = os.environ.get("BEDROCK_MODEL_ID")
        fake = FakeBedrock()
        resolver._bedrock_client = fake
        os.environ["BEDROCK_MODEL_ID"] = "amazon.nova-micro-v1:0"
        try:
            result = resolver._infer_batch(["WhatsApp 2024-06-27.jpg"])
        finally:
            resolver._bedrock_client = previous_client
            if previous_model is None:
                os.environ.pop("BEDROCK_MODEL_ID", None)
            else:
                os.environ["BEDROCK_MODEL_ID"] = previous_model

        self.assertEqual(result[0]["dateValue"], "2024-06-27")
        prompt = fake.request["messages"][0]["content"][0]["text"]
        self.assertIn("WhatsApp 2024-06-27.jpg", prompt)
        self.assertNotIn("photoId", prompt)
        self.assertNotIn("metadataCreatedAt", prompt)
        self.assertEqual(fake.request["toolConfig"]["toolChoice"], {"any": {}})

    def test_sanitizes_filename_to_basename(self):
        self.assertEqual(resolver._safe_filename(r"C:\photos\IMG-2024.jpg"), "IMG-2024.jpg")
        self.assertIsNone(resolver._safe_filename(" \n "))

    def test_requires_exact_filename_evidence_and_valid_precision(self):
        valid = {
            "dateValue": "2024-06-27",
            "precision": "day",
            "evidence": "2024-06-27",
            "confidence": 0.95,
        }
        self.assertEqual(
            resolver._validate_model_result("WhatsApp 2024-06-27.jpg", valid),
            {"status": "resolved", "dateValue": "2024-06-27"},
        )

        invalid = dict(valid, evidence="2023-01-01")
        self.assertEqual(
            resolver._validate_model_result("WhatsApp 2024-06-27.jpg", invalid),
            {"status": "no_date"},
        )

    def test_rejects_impossible_ambiguous_and_low_confidence_results(self):
        for result in (
            {
                "dateValue": "2024-02-30",
                "precision": "day",
                "evidence": "2024-02-30",
                "confidence": 0.99,
            },
            {
                "dateValue": "2024-06-27",
                "precision": "unknown",
                "evidence": "2024-06-27",
                "confidence": 0.99,
            },
            {
                "dateValue": "2024-06-27",
                "precision": "day",
                "evidence": "2024-06-27",
                "confidence": 0.5,
            },
        ):
            self.assertEqual(
                resolver._validate_model_result("2024-06-27.jpg", result),
                {"status": "no_date"},
            )

    def test_applies_device_offset_only_when_model_date_has_no_offset(self):
        local = resolver._to_utc("2024-06-27T10:00:00", 120)
        explicit = resolver._to_utc("2024-06-27T10:00:00+02:00", -300)
        self.assertEqual(local.isoformat(), "2024-06-27T08:00:00+00:00")
        self.assertEqual(explicit.isoformat(), "2024-06-27T08:00:00+00:00")


if __name__ == "__main__":
    unittest.main()
