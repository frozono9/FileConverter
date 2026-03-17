#!/usr/bin/env zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/FileConverter.app [output-dmg]"
  exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="${2:-FileConverter-Installer.dmg}"
VOLUME_NAME="FileConverter Installer"
TMP_ROOT="$(mktemp -d /tmp/fileconverter-dmg.XXXXXX)"
RW_DMG="${TMP_ROOT}/${VOLUME_NAME}.dmg"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
STAGE_DIR="${TMP_ROOT}/stage"
mkdir -p "$STAGE_DIR"

cp -R "$APP_PATH" "$STAGE_DIR/$APP_NAME"
ln -s /Applications "$STAGE_DIR/Applications"

cat > "$STAGE_DIR/INSTALL.txt" <<'EOF'
FileConverter Installation

1. Drag FileConverter.app to Applications
2. Open FileConverter from Applications (not from the DMG)
3. On first launch, follow the setup guide

That's it. The app handles everything else automatically.
EOF

SIZE_MB=$(du -sm "$STAGE_DIR" | awk '{print $1 + 40}')

hdiutil create -size "${SIZE_MB}m" -fs HFS+ -volname "$VOLUME_NAME" "$RW_DMG" -ov >/dev/null

MOUNT_POINT="$(hdiutil attach "$RW_DMG" -nobrowse -noverify | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "Failed to mount temporary DMG"
  exit 1
fi

cp -R "$STAGE_DIR/"* "$MOUNT_POINT/"
sync
hdiutil detach "$MOUNT_POINT" -force >/dev/null

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$OUTPUT_DMG" -ov >/dev/null

echo "DMG generated: $OUTPUT_DMG"
