#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIGURATION="${CONFIGURATION:-Release}"
APP="build/DerivedData/Build/Products/$CONFIGURATION-iphoneos/NextFM.app"
test -d "$APP" || { echo "Build NextFM.app before packaging." >&2; exit 1; }
# Work in a fresh temporary directory so repeated builds cannot retain stale resources.
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$STAGING/Payload"
cp -R "$APP" "$STAGING/Payload/NextFM.app"
OUTPUT="$PWD/build/next.fm-unsigned.ipa"
(cd "$STAGING" && zip -q -r next.fm-unsigned.ipa Payload)
mv "$STAGING/next.fm-unsigned.ipa" "$OUTPUT"
echo "Created $OUTPUT"
