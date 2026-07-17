import argparse
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import boto3


MIGRATION_ACTOR = "system-migration"


def _now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def _resolve_table_name(env: str) -> str:
    # Allow explicit override.
    override = os.environ.get("ONES_TRANSLATIONS_TABLE", "").strip()
    if override:
        return override

    if env == "dev":
        return "ones-dev-translations"

    # NOTE: in this repo, prod table is documented as `ones-translations`.
    if env == "prod":
        return "ones-translations"

    raise ValueError(f"Unsupported env: {env}")


def _resolve_region() -> str:
    region = os.environ.get("AWS_REGION", "").strip() or os.environ.get("AWS_DEFAULT_REGION", "").strip()
    if not region:
        raise SystemExit("ERROR: AWS_REGION (or AWS_DEFAULT_REGION) is required")
    return region


def _resolve_translations_file_path() -> Path:
    repo_root = Path(__file__).resolve().parents[2]
    return (
        repo_root
        / "services"
        / "ones-api"
        / "src"
        / "main"
        / "resources"
        / "initial-translations.json"
    )


def _load_translations_json(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"ERROR: translations file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Populate DynamoDB translations table from services/ones-api/src/main/resources/initial-translations.json"
    )
    parser.add_argument("env", choices=["dev", "prod"], help="Target environment")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not write to DynamoDB; only print counts",
    )

    args = parser.parse_args()

    region = _resolve_region()
    table_name = _resolve_table_name(args.env)
    translations_path = _resolve_translations_file_path()
    data = _load_translations_json(translations_path)

    total_items = 0
    for _, langs in data.items():
        if isinstance(langs, dict):
            total_items += len(langs.keys())

    print("Translations fill script")
    print(f"- env={args.env}")
    print(f"- region={region}")
    print(f"- table={table_name}")
    print(f"- file={translations_path}")
    print(f"- items={total_items}")

    if args.dry_run:
        print("DRY RUN: no writes performed")
        return

    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)

    now = _now_iso()

    written = 0
    # batch_writer handles buffering, parallelization, and unprocessed item retries.
    with table.batch_writer(overwrite_by_pkeys=["translationKey", "languageCode"]) as batch:
        for translation_key, langs in data.items():
            if not isinstance(langs, dict):
                continue

            for language_code, value in langs.items():
                if value is None:
                    continue

                item = {
                    "translationKey": str(translation_key),
                    "languageCode": str(language_code).strip().lower(),
                    "value": str(value),
                    "context": None,
                    "createdAt": now,
                    "updatedAt": now,
                    "createdBy": MIGRATION_ACTOR,
                    "updatedBy": MIGRATION_ACTOR,
                }
                batch.put_item(Item=item)
                written += 1

    print(f"DONE: wrote {written} items")


if __name__ == "__main__":
    main()
