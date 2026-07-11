#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DeployBar"
BUNDLE_NAME="$APP_NAME.app"
DIST_DIR="$ROOT/dist"
APP_DIR="$DIST_DIR/$BUNDLE_NAME"
ZIP_PATH="$DIST_DIR/$APP_NAME.zip"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

select_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '$2 ~ /^Developer ID Application:/ { print $2; exit }'
}

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(select_developer_id_identity)"
fi

if [[ -z "$SIGN_IDENTITY" || "$SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
  cat >&2 <<EOF
Public release builds must be signed with a Developer ID Application identity.

Install a Developer ID Application certificate or pass one explicitly:

  CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/package_release.sh
EOF
  exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" && -z "$NOTARY_PROFILE" ]]; then
  cat >&2 <<EOF
Public release builds should be notarized before upload.

Create a notarytool profile once:

  xcrun notarytool store-credentials deploybar-notary \\
    --apple-id you@example.com \\
    --team-id TEAMID \\
    --password app-specific-password

Then package with:

  NOTARY_PROFILE=deploybar-notary ./scripts/package_release.sh

For a local dry run only:

  SKIP_NOTARIZATION=1 ./scripts/package_release.sh
EOF
  exit 1
fi

CODESIGN_IDENTITY="$SIGN_IDENTITY" \
CODESIGN_OPTIONS="runtime" \
CODESIGN_TIMESTAMP=1 \
SKIP_INSTALL=1 \
"$ROOT/scripts/install_app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Created unnotarized dry-run artifact: $ZIP_PATH"
  echo "Notarization skipped. Do not upload this artifact to GitHub Releases."
  exit 0
fi

xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

spctl --assess --type execute --verbose "$APP_DIR"

echo "Created Developer ID signed, notarized release artifact: $ZIP_PATH"
