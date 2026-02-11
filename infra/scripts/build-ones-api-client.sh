#!/usr/bin/env sh
set -e

ROOT_DIR=$(cd "$(dirname "$0")/../.." && pwd)
CLIENT_DIR="$ROOT_DIR/packages/ones_api_client"

if [ ! -d "$CLIENT_DIR" ]; then
  echo "Client package not found: $CLIENT_DIR" >&2
  exit 1
fi

( cd "$CLIENT_DIR" && dart run build_runner build --delete-conflicting-outputs )
