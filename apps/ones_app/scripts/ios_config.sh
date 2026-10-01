#!/usr/bin/env bash
# Configura el proyecto iOS (ios/Flutter/Generated.xcconfig) con los dart-defines
# del entorno indicado, para luego compilar/correr desde Xcode.
#
# Uso:
#   scripts/ios_config.sh prod            # apunta a prod (debug)
#   scripts/ios_config.sh prod --release  # apunta a prod (release)
#   scripts/ios_config.sh dev             # vuelve a dev (usa assets/config/app_config.json)
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_NAME="${1:-dev}"
MODE="${2:---debug}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

case "$ENV_NAME" in
  prod)
    DEFINES=(
      --dart-define=ONES_ENV=prod
      --dart-define=ONES_API_BASE_URL=https://app.ones.events
      --dart-define=GOOGLE_WEB_CLIENT_ID=403122779240-ahjm73ogughiivnn3o23jfsk25usmfng.apps.googleusercontent.com
      --dart-define=ONES_PHOTOS_WS_URL=wss://iex9i00vt5.execute-api.us-east-1.amazonaws.com/prod
    )
    ;;
  dev)
    DEFINES=()
    ;;
  *)
    echo "Entorno desconocido: $ENV_NAME (usa dev|prod)" >&2; exit 1 ;;
esac

flutter build ios --config-only "$MODE" "${DEFINES[@]}"
echo
echo "Generated.xcconfig configurado para '$ENV_NAME' ($MODE). Ahora abre ios/Runner.xcworkspace y corre desde Xcode."
