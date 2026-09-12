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
APP_VERSION="${APP_VERSION:-$(cat "$ROOT/VERSION" 2>/dev/null || echo 0.1.0)}"
CASK_TEMPLATE="$ROOT/packaging/homebrew/deploybar.rb.tmpl"
CASK_OUTPUT="$ROOT/packaging/homebrew/deploybar.rb"
UNSIGNED_RELEASE=0

if [[ "$#" -gt 1 ]]; then
  echo "Usage: $0 [--unsigned]" >&2
  exit 1
fi

case "${1:-}" in
  --unsigned) UNSIGNED_RELEASE=1 ;;
  "") ;;
  *) echo "Usage: $0 [--unsigned]" >&2; exit 1 ;;
esac

write_checksum() {
  printf '%s  %s\n' "$ZIP_SHA256" "$APP_NAME.zip" > "$ZIP_PATH.sha256"
}

select_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F '"' '$2 ~ /^Developer ID Application:/ { print $2; exit }'
}

# Renders the Homebrew cask from packaging/homebrew/deploybar.rb.tmpl, substituting
# the release version and the zip's SHA256. Every future release must re-run this
# (via package_release.sh) so the cask stays pinned to the artifact it describes.
render_cask() {
  local version="$1"
  local sha256="$2"

  if [[ ! -f "$CASK_TEMPLATE" ]]; then
    echo "Cask template not found at $CASK_TEMPLATE, skipping cask render." >&2
    return 0
  fi

  sed -e "s/__VERSION__/$version/g" -e "s/__SHA256__/$sha256/g" \
    "$CASK_TEMPLATE" > "$CASK_OUTPUT"
  echo "Rendered Homebrew cask: $CASK_OUTPUT (version $version, sha256 $sha256)"
}

if [[ "$UNSIGNED_RELEASE" == "1" ]]; then
  ALLOW_ADHOC_SIGNING=1 \
  CODESIGN_IDENTITY=- \
  SKIP_INSTALL=1 \
  APP_VERSION="$APP_VERSION" \
  "$ROOT/scripts/install_app.sh"

  codesign --verify --deep --strict "$APP_DIR"
  rm -f "$ZIP_PATH"
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
  ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
  write_checksum
  render_cask "$APP_VERSION" "$ZIP_SHA256"
  echo "Created unsigned preview: $ZIP_PATH"
  echo "This uses an ad-hoc signature, not Developer ID. It is not notarized."
  echo "Label the download as unsigned and link to https://deploybar.com/#install."
  echo "SHA256: $ZIP_SHA256"
  exit 0
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(select_developer_id_identity)"
fi

if [[ -z "$SIGN_IDENTITY" || "$SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
  cat >&2 <<EOF
The default release path requires a Developer ID Application identity.

Install a Developer ID Application certificate or pass one explicitly:

  CODESIGN_IDENTITY="Developer ID Application: Name (TEAMID)" ./scripts/package_release.sh

For an explicitly labeled unsigned preview:

  ./scripts/package_release.sh --unsigned
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
APP_VERSION="$APP_VERSION" \
"$ROOT/scripts/install_app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Created unnotarized dry-run artifact: $ZIP_PATH"
  echo "Notarization skipped. Do not upload this artifact to GitHub Releases."
  echo "SHA256: $ZIP_SHA256"
  render_cask "$APP_VERSION" "$ZIP_SHA256"
  exit 0
fi

xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

xcrun stapler staple "$APP_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
ZIP_SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"

spctl --assess --type execute --verbose "$APP_DIR"

write_checksum
render_cask "$APP_VERSION" "$ZIP_SHA256"
echo "Created Developer ID signed, notarized release artifact: $ZIP_PATH"
echo "SHA256: $ZIP_SHA256"
