#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DeployBar"
BUNDLE_NAME="$APP_NAME.app"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$BUNDLE_NAME"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
BINARY_PATH="$BUILD_DIR/$APP_NAME"
APP_ICON_SVG="$ROOT/scripts/app-icon.svg"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
APP_ICON_ICNS="$APP_DIR/Contents/Resources/AppIcon.icns"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
SIGN_ENTITLEMENTS="${CODESIGN_ENTITLEMENTS:-}"
CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-}"
CODESIGN_TIMESTAMP="${CODESIGN_TIMESTAMP:-0}"
APP_VERSION="${APP_VERSION:-$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)}"
BUILD_VERSION="${BUILD_VERSION:-$(date +%Y%m%d%H%M%S)}"
ALLOW_ADHOC_SIGNING="${ALLOW_ADHOC_SIGNING:-0}"
LOCAL_DEV_IDENTITY="${LOCAL_DEV_IDENTITY:-DeployBar Local Development}"
SKIP_INSTALL="${SKIP_INSTALL:-0}"

TARGET_DIR="$HOME/Applications"
if [[ "${1:-}" == "--system" ]]; then
  TARGET_DIR="/Applications"
fi

ALT_TARGET_DIR="/Applications"
if [[ "$TARGET_DIR" == "/Applications" ]]; then
  ALT_TARGET_DIR="$HOME/Applications"
fi

select_signing_identity() {
  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  local patterns=(
    "Developer ID Application:"
    "Apple Distribution:"
    "Apple Development:"
    "$LOCAL_DEV_IDENTITY"
  )

  local pattern
  for pattern in "${patterns[@]}"; do
    local match
    match="$(printf '%s\n' "$identities" | awk -F '"' -v pattern="$pattern" '$2 ~ pattern { print $2; exit }')"
    if [[ -n "$match" ]]; then
      printf '%s\n' "$match"
      return 0
    fi
  done

  printf '%s\n' "$identities" | awk -F '"' '/\) [A-F0-9]+ "/ { print $2; exit }'
}

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(select_signing_identity)"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  if [[ "$ALLOW_ADHOC_SIGNING" == "1" ]]; then
    SIGN_IDENTITY="-"
  else
    cat >&2 <<EOF
No valid macOS code signing identity was found.

Keychain permissions do not stick reliably across ad-hoc signed builds. Create a
local development signing identity, then rerun this installer:

  ./scripts/create_dev_codesign_identity.sh
  ./scripts/install_app.sh

For a one-off unsigned-style install, rerun with:

  ALLOW_ADHOC_SIGNING=1 ./scripts/install_app.sh
EOF
    exit 1
  fi
fi

echo "Building $APP_NAME (release, arm64)..."
cd "$ROOT"
swift build --configuration release --arch arm64

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Expected binary not found at $BINARY_PATH" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

if [[ ! -f "$APP_ICON_SVG" ]]; then
  echo "Expected app icon not found at $APP_ICON_SVG" >&2
  exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
  sips -s format png --resampleHeightWidth "$size" "$size" \
    "$APP_ICON_SVG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null

  retina_size=$((size * 2))
  sips -s format png --resampleHeightWidth "$retina_size" "$retina_size" \
    "$APP_ICON_SVG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_DIR" -o "$APP_ICON_ICNS"
rm -rf "$ICONSET_DIR"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>DeployBar</string>
  <key>CFBundleDisplayName</key>
  <string>DeployBar</string>
  <key>CFBundleIdentifier</key>
  <string>com.deploybar.app</string>
  <key>CFBundleExecutable</key>
  <string>DeployBar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$ROOT/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Signing with ad-hoc identity."
  echo "Note: ad-hoc signatures can trigger repeated Keychain access prompts after app updates."
else
  echo "Signing with identity: $SIGN_IDENTITY"
fi

codesign_args=(--force --deep --sign "$SIGN_IDENTITY")
if [[ -n "$CODESIGN_OPTIONS" ]]; then
  codesign_args+=(--options "$CODESIGN_OPTIONS")
fi
if [[ "$CODESIGN_TIMESTAMP" == "1" ]]; then
  codesign_args+=(--timestamp)
fi
if [[ -n "$SIGN_ENTITLEMENTS" ]]; then
  codesign_args+=(--entitlements "$SIGN_ENTITLEMENTS")
fi
codesign "${codesign_args[@]}" "$APP_DIR"

if [[ "$SKIP_INSTALL" == "1" ]]; then
  echo "Packaged: $APP_DIR"
  exit 0
fi

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_DIR/$BUNDLE_NAME"
cp -R "$APP_DIR" "$TARGET_DIR/$BUNDLE_NAME"

if [[ -d "$ALT_TARGET_DIR/$BUNDLE_NAME" ]]; then
  echo "Removing stale install at $ALT_TARGET_DIR/$BUNDLE_NAME"
  rm -rf "$ALT_TARGET_DIR/$BUNDLE_NAME"
fi

echo "Installed: $TARGET_DIR/$BUNDLE_NAME"
echo "Launching app..."
open "$TARGET_DIR/$BUNDLE_NAME"
