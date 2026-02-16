#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DeployBar"
BUNDLE_NAME="$APP_NAME.app"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$BUNDLE_NAME"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
BINARY_PATH="$BUILD_DIR/$APP_NAME"
WEB_ICON_SVG="$ROOT/website/public/favicon.svg"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
APP_ICON_ICNS="$APP_DIR/Contents/Resources/AppIcon.icns"
ICON_SAFE_AREA_PERCENT=84
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
SIGN_ENTITLEMENTS="${CODESIGN_ENTITLEMENTS:-}"

TARGET_DIR="$HOME/Applications"
if [[ "${1:-}" == "--system" ]]; then
  TARGET_DIR="/Applications"
fi

ALT_TARGET_DIR="/Applications"
if [[ "$TARGET_DIR" == "/Applications" ]]; then
  ALT_TARGET_DIR="$HOME/Applications"
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

if [[ ! -f "$WEB_ICON_SVG" ]]; then
  echo "Expected website icon not found at $WEB_ICON_SVG" >&2
  exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for size in 16 32 128 256 512; do
  inner_size=$((size * ICON_SAFE_AREA_PERCENT / 100))
  sips -s format png --resampleHeightWidth "$inner_size" "$inner_size" \
    "$WEB_ICON_SVG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  sips -p "$size" "$size" "$ICONSET_DIR/icon_${size}x${size}.png" \
    --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null

  retina_size=$((size * 2))
  retina_inner_size=$((retina_size * ICON_SAFE_AREA_PERCENT / 100))
  sips -s format png --resampleHeightWidth "$retina_inner_size" "$retina_inner_size" \
    "$WEB_ICON_SVG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  sips -p "$retina_size" "$retina_size" "$ICONSET_DIR/icon_${size}x${size}@2x.png" \
    --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
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
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Signing with ad-hoc identity."
  echo "Note: ad-hoc signatures can trigger repeated Keychain access prompts after app updates."
fi

if [[ -n "$SIGN_ENTITLEMENTS" ]]; then
  codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$SIGN_ENTITLEMENTS" "$APP_DIR"
else
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
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
