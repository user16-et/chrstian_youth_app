#!/usr/bin/env bash
#
# Build a release of the mobile app pointed at a specific API host.
#
# Usage:
#   ./build-release.sh <api-ip>                 # -> http://<api-ip>:3000, APK
#   ./build-release.sh <api-ip> <port>          # -> http://<api-ip>:<port>, APK
#   ./build-release.sh <api-ip> <port> appbundle# -> .aab for Play Store
#   ./build-release.sh https://api.example.com  # full URL (TLS), APK
#
# Examples:
#   ./build-release.sh 196.188.0.10
#   ./build-release.sh 196.188.0.10 3000 appbundle
#   ./build-release.sh https://api.faithapp.et
#
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <api-ip-or-url> [port] [apk|appbundle]" >&2
  exit 1
fi

HOST_ARG="$1"
PORT="${2:-3000}"
ARTIFACT="${3:-apk}"

# Accept a full URL, or build http://<ip>:<port> from an IP/host.
if [[ "$HOST_ARG" == http://* || "$HOST_ARG" == https://* ]]; then
  API_BASE_URL="$HOST_ARG"
else
  API_BASE_URL="http://${HOST_ARG}:${PORT}"
fi

if [[ "$ARTIFACT" != "apk" && "$ARTIFACT" != "appbundle" ]]; then
  echo "Third argument must be 'apk' or 'appbundle' (got '$ARTIFACT')." >&2
  exit 1
fi

cd "$(dirname "$0")"

echo "==> Building release ($ARTIFACT)"
echo "    API_BASE_URL = $API_BASE_URL"
if [[ "$API_BASE_URL" == http://* ]]; then
  echo "    Note: cleartext HTTP — allowed via res/xml/network_security_config.xml."
fi
echo

flutter build "$ARTIFACT" --release --dart-define=API_BASE_URL="$API_BASE_URL"

echo
if [[ "$ARTIFACT" == "apk" ]]; then
  echo "Done -> build/app/outputs/flutter-apk/app-release.apk"
else
  echo "Done -> build/app/outputs/bundle/release/app-release.aab"
fi
echo
echo "Before installing, make sure the API is reachable:"
echo "  - The server binds 0.0.0.0 (it does) and port ${PORT} is open in the firewall."
echo "  - From the phone's network:  curl ${API_BASE_URL%/}/health   (or open it in a browser)"
