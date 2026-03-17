#!/usr/bin/env zsh
set -euo pipefail

# Production release pipeline:
# 1) Build Release app
# 2) Sign app + extension with Developer ID Application
# 3) Create DMG with drag-to-Applications layout
# 4) Sign DMG
# 5) Notarize DMG and staple ticket
#
# Required environment variables:
# - DEVELOPER_ID_APP_CERT: e.g. "Developer ID Application: Your Name (TEAMID)"
# - NOTARY_PROFILE: keychain profile configured for notarytool
#
# Optional:
# - PROJECT_PATH (default: ./FileConverter.xcodeproj)
# - SCHEME (default: FileConverter)
# - DERIVED_DATA_PATH (default: ./build_release)
# - APP_NAME (default: FileConverter.app)
# - OUTPUT_DMG (default: FileConverter-Installer.dmg)

PROJECT_PATH="${PROJECT_PATH:-$(pwd)/FileConverter.xcodeproj}"
SCHEME="${SCHEME:-FileConverter}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$(pwd)/build_release}"
APP_NAME="${APP_NAME:-FileConverter.app}"
OUTPUT_DMG="${OUTPUT_DMG:-$(pwd)/FileConverter-Installer.dmg}"
CREATE_DMG_SCRIPT="$(pwd)/scripts/create_dmg.sh"

if [[ -z "${DEVELOPER_ID_APP_CERT:-}" ]]; then
  echo "Missing DEVELOPER_ID_APP_CERT"
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "Missing NOTARY_PROFILE"
  exit 1
fi

if [[ ! -f "$CREATE_DMG_SCRIPT" ]]; then
  echo "Missing DMG script: $CREATE_DMG_SCRIPT"
  exit 1
fi

echo "[1/7] Building Release app..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >/tmp/fileconverter_release_build.log

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"
APPEX_PATH="$APP_PATH/Contents/PlugIns/convert.io.appex"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build output app not found: $APP_PATH"
  exit 1
fi

if [[ ! -d "$APPEX_PATH" ]]; then
  echo "Finder extension not found: $APPEX_PATH"
  exit 1
fi

echo "[2/7] Signing extension..."
/usr/bin/codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APP_CERT" --entitlements "$(pwd)/signing-extension.entitlements" "$APPEX_PATH"

echo "[3/7] Signing app..."
/usr/bin/codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APP_CERT" --entitlements "$(pwd)/signing-app.entitlements" "$APP_PATH"

echo "[4/7] Verifying signed app..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv --type exec "$APP_PATH" || true

echo "[5/7] Creating installer DMG..."
rm -f "$OUTPUT_DMG"
"$CREATE_DMG_SCRIPT" "$APP_PATH" "$OUTPUT_DMG"

echo "[6/7] Signing DMG..."
/usr/bin/codesign --force --timestamp --sign "$DEVELOPER_ID_APP_CERT" "$OUTPUT_DMG"
/usr/bin/codesign --verify --verbose=2 "$OUTPUT_DMG"

echo "[7/7] Notarizing + stapling DMG..."
xcrun notarytool submit "$OUTPUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$OUTPUT_DMG"

echo "Validating stapled DMG..."
spctl -a -vv -t open "$OUTPUT_DMG" || true

echo "Done: $OUTPUT_DMG"
