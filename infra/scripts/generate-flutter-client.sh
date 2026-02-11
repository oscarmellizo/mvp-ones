#!/usr/bin/env sh
set -e

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
OPENAPI_FILE="$ROOT_DIR/contracts/openapi.yaml"
OUT_DIR="$ROOT_DIR/packages/ones_api_client"

mkdir -p "$OUT_DIR"

docker run --rm \
  -v "$ROOT_DIR:/local" \
  openapitools/openapi-generator-cli:v7.6.0 generate \
  -i /local/contracts/openapi.yaml \
  -g dart-dio \
  -o /local/packages/ones_api_client \
  --additional-properties=pubName=ones_api_client,pubVersion=0.1.0
