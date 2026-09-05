#!/usr/bin/env bash
# Build LimitMeter and package a runnable .app under .build/LimitMeter.app
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-debug}"
PRODUCT="LimitMeter"
APP_DIR=".build/${PRODUCT}.app"
TRIPLE="$(swift -print-target-info | python3 -c 'import json,sys; print(json.load(sys.stdin)["target"]["unversionedTriple"])')"
BIN_DIR=".build/${TRIPLE}/${CONFIG}"

echo "==> Building (${CONFIG})"
swift build -c "${CONFIG}" --product "${PRODUCT}"

echo "==> Packaging ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp "${BIN_DIR}/${PRODUCT}" "${APP_DIR}/Contents/MacOS/${PRODUCT}"
cp "LimitMeter/Info.plist" "${APP_DIR}/Contents/Info.plist"

# Logo PNGs (also live in the SwiftPM resource bundle; keep both for safety)
cp LimitMeterApp/Resources/*.png "${APP_DIR}/Contents/Resources/" 2>/dev/null || true

BUNDLE="${BIN_DIR}/${PRODUCT}_${PRODUCT}.bundle"
if [[ -d "${BUNDLE}" ]]; then
  cp -R "${BUNDLE}" "${APP_DIR}/Contents/Resources/"
fi

codesign --force --deep --sign - "${APP_DIR}" >/dev/null

echo "OK: ${APP_DIR}"
echo "Run: open ${APP_DIR}"
