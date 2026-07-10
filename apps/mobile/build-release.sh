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

if [[ "$ARTIFACT" != "apk" && "$ARTIFACT" != "appbundle" && "$ARTIFACT" != "split" && "$ARTIFACT" != "web" ]]; then
  echo "Third argument must be 'apk', 'split', 'appbundle', or 'web' (got '$ARTIFACT')." >&2
  exit 1
fi

cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"

# Locate Flutter: prefer one on PATH, else the SDK bundled in the repo.
if command -v flutter >/dev/null 2>&1; then
  FLUTTER=flutter
elif [[ -x "$REPO_ROOT/.sdk/flutter/bin/flutter" ]]; then
  FLUTTER="$REPO_ROOT/.sdk/flutter/bin/flutter"
else
  echo "flutter not found on PATH or at $REPO_ROOT/.sdk/flutter/bin/flutter" >&2
  exit 1
fi

# Point at the bundled Android SDK if the environment doesn't already set one.
if [[ -z "${ANDROID_SDK_ROOT:-}" && -d "$REPO_ROOT/.sdk/android-sdk" ]]; then
  export ANDROID_SDK_ROOT="$REPO_ROOT/.sdk/android-sdk"
  export ANDROID_HOME="$REPO_ROOT/.sdk/android-sdk"
fi

echo "==> Building release ($ARTIFACT)"
echo "    flutter = $FLUTTER"
echo "    API_BASE_URL = $API_BASE_URL"
if [[ "$API_BASE_URL" == http://* ]]; then
  echo "    Note: cleartext HTTP — allowed via res/xml/network_security_config.xml."
fi
echo

# 'split' builds one small APK per architecture (~1/3 the universal size);
# most modern phones use arm64-v8a.
if [[ "$ARTIFACT" == "split" ]]; then
  "$FLUTTER" build apk --release --split-per-abi --dart-define=API_BASE_URL="$API_BASE_URL"
else
  "$FLUTTER" build "$ARTIFACT" --release --dart-define=API_BASE_URL="$API_BASE_URL"
fi

echo
if [[ "$ARTIFACT" == "web" ]]; then
  echo "Done -> build/web  (serve this folder; it talks to $API_BASE_URL)"
  echo "    The API's CORS must allow the web app's origin, and if you serve the"
  echo "    web app over HTTPS the API must also be HTTPS (no mixed content)."
elif [[ "$ARTIFACT" == "split" ]]; then
  echo "Done -> per-architecture APKs in build/app/outputs/flutter-apk/ :"
  ls -1sh build/app/outputs/flutter-apk/app-*-release.apk 2>/dev/null | sed 's/^/    /'
  echo "    Install app-arm64-v8a-release.apk on modern phones."
elif [[ "$ARTIFACT" == "apk" ]]; then
  echo "Done -> build/app/outputs/flutter-apk/app-release.apk"
else
  echo "Done -> build/app/outputs/bundle/release/app-release.aab"
fi
echo
echo "Before installing, make sure the API is reachable:"
echo "  - The server binds 0.0.0.0 (it does) and port ${PORT} is open in the firewall."
echo "  - From the phone's network:  curl ${API_BASE_URL%/}/health   (or open it in a browser)"
