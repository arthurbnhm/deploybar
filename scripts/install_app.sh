#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DeployBar"
BUNDLE_NAME="$APP_NAME.app"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$BUNDLE_NAME"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
BINARY_PATH="$BUILD_DIR/$APP_NAME"

TARGET_DIR="$HOME/Applications"
if [[ "${1:-}" == "--system" ]]; then
  TARGET_DIR="/Applications"
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

codesign --force --deep --sign - "$APP_DIR"

mkdir -p "$TARGET_DIR"
rm -rf "$TARGET_DIR/$BUNDLE_NAME"
cp -R "$APP_DIR" "$TARGET_DIR/$BUNDLE_NAME"

echo "Installed: $TARGET_DIR/$BUNDLE_NAME"
echo "Launching app..."
open "$TARGET_DIR/$BUNDLE_NAME"
