#!/usr/bin/env bash
set -euo pipefail

CERT_NAME="${CODESIGN_IDENTITY:-Screenshot Manager Local Development}"
KEYCHAIN="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"
P12_PASSWORD="${P12_PASSWORD:-codex-local-signing}"

if /usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "\"$CERT_NAME\"" >/dev/null; then
  echo "Code signing identity already exists: $CERT_NAME"
  exit 0
fi

TMP_DIR="$(/usr/bin/mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Creating local code signing identity: $CERT_NAME"
/usr/bin/openssl req \
  -newkey rsa:2048 \
  -nodes \
  -keyout "$TMP_DIR/key.pem" \
  -x509 \
  -days 3650 \
  -sha256 \
  -set_serial "0x$(/usr/bin/uuidgen | /usr/bin/tr -d '-')" \
  -subj "/CN=$CERT_NAME/O=Local Development/OU=Screenshot Manager" \
  -addext "keyUsage=digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -out "$TMP_DIR/cert.pem"

/usr/bin/openssl pkcs12 \
  -export \
  -inkey "$TMP_DIR/key.pem" \
  -in "$TMP_DIR/cert.pem" \
  -name "$CERT_NAME" \
  -passout "pass:$P12_PASSWORD" \
  -out "$TMP_DIR/cert.p12"

/usr/bin/security import "$TMP_DIR/cert.p12" \
  -k "$KEYCHAIN" \
  -P "$P12_PASSWORD" \
  -A \
  -T /usr/bin/codesign \
  -T /usr/bin/security

/usr/bin/security add-trusted-cert \
  -r trustRoot \
  -p codeSign \
  -k "$KEYCHAIN" \
  "$TMP_DIR/cert.pem" >/dev/null 2>&1 || true

/usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/grep -F "$CERT_NAME"
