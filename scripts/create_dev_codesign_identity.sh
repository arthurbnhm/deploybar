#!/usr/bin/env bash
set -euo pipefail

IDENTITY_NAME="${LOCAL_DEV_IDENTITY:-DeployBar Local Development}"
KEYCHAIN="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

if security find-identity -v -p codesigning | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
  echo "Code signing identity already exists: $IDENTITY_NAME"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

OPENSSL_CONFIG="$TMP_DIR/codesign.cnf"
KEY_PATH="$TMP_DIR/codesign.key"
CERT_PATH="$TMP_DIR/codesign.crt"
P12_PATH="$TMP_DIR/codesign.p12"
P12_PASSWORD="$(uuidgen)"

cat > "$OPENSSL_CONFIG" <<EOF
[ req ]
prompt = no
distinguished_name = dn
x509_extensions = codesign

[ dn ]
CN = $IDENTITY_NAME

[ codesign ]
basicConstraints = critical,CA:true
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -days 3650 \
  -config "$OPENSSL_CONFIG" \
  -keyout "$KEY_PATH" \
  -out "$CERT_PATH" >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -legacy \
  -name "$IDENTITY_NAME" \
  -inkey "$KEY_PATH" \
  -in "$CERT_PATH" \
  -out "$P12_PATH" \
  -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

security import "$P12_PATH" \
  -k "$KEYCHAIN" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign >/dev/null

echo "Created local code signing identity: $IDENTITY_NAME"
echo "Run ./scripts/install_app.sh to sign DeployBar with this stable identity."
echo "If macOS asks whether codesign can use this key, choose Always Allow."
