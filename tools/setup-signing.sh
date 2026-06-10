#!/usr/bin/env bash
#
# setup-signing.sh — recreate the stable local code-signing identity for Glyph.
#
# WHY THIS EXISTS
#   Ad-hoc signing keys the macOS Screen Recording / Microphone (TCC) grant to
#   the per-build cdhash, so every rebuild invalidates permission and macOS
#   re-prompts forever. Signing with a STABLE self-signed certificate makes the
#   app's designated requirement reference the cert (not the cdhash), so the
#   permission grant persists across rebuilds. project.yml already points
#   CODE_SIGN_IDENTITY at the cert created here.
#
# WHAT IT DOES
#   Creates a self-signed code-signing certificate "Glyph Local Signing" in your
#   login keychain (codeSigning EKU, valid ~10 years) and authorises codesign to
#   use it without per-build prompts. Idempotent: if the identity already exists
#   it does nothing.
#
# USAGE
#   bash tools/setup-signing.sh
#   (run once per Mac, then build normally; grant the Screen Recording prompt once.)

set -euo pipefail

CERT_CN="Glyph Local Signing"           # must match CODE_SIGN_IDENTITY in project.yml
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
P12_PASS="glyph"                        # transient; only used to move the key into the keychain

# --- 0. Already present? -----------------------------------------------------
if security find-certificate -c "$CERT_CN" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "✓ Signing identity \"$CERT_CN\" already exists in the login keychain — nothing to do."
  echo "  (To force a rebuild of the cert, delete it in Keychain Access and re-run.)"
  exit 0
fi

echo "Creating self-signed code-signing identity \"$CERT_CN\"…"

# --- 1. Work in an isolated temp dir, always clean up ------------------------
TMP="$(mktemp -d)"
trap 'rm -f "$TMP"/glyph-signing.*' EXIT

# --- 2. Key + self-signed cert with the codeSigning EKU ----------------------
#   macOS ships LibreSSL, whose pkcs12 default format the `security` tool can
#   read (no -legacy flag — and LibreSSL doesn't support one).
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP/glyph-signing.key" -out "$TMP/glyph-signing.crt" \
  -subj "/CN=$CERT_CN/O=Glyph Dev" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

# --- 3. Bundle into PKCS#12 (a real password — empty passwords fail import) ---
openssl pkcs12 -export -out "$TMP/glyph-signing.p12" \
  -inkey "$TMP/glyph-signing.key" -in "$TMP/glyph-signing.crt" \
  -name "$CERT_CN" -passout "pass:$P12_PASS" >/dev/null 2>&1

# --- 4. Import into the login keychain; -A lets codesign use it prompt-free ---
security import "$TMP/glyph-signing.p12" -k "$KEYCHAIN" -P "$P12_PASS" -A >/dev/null

# --- 5. Verify codesign can actually sign with it ----------------------------
SIGTEST="$TMP/_sigtest"; cp /bin/echo "$SIGTEST"
if codesign -s "$CERT_CN" -f "$SIGTEST" >/dev/null 2>&1 \
   && codesign -dvv "$SIGTEST" 2>&1 | grep -q "Authority=$CERT_CN"; then
  echo "✓ Identity created and verified — codesign can sign with \"$CERT_CN\"."
else
  echo "✗ Identity imported but codesign could not use it. Open Keychain Access,"
  echo "  find \"$CERT_CN\", and set its Trust → Code Signing to \"Always Trust\", then retry."
  exit 1
fi

cat <<EOF

Next steps:
  1. Build:  xcodebuild -project Glyph.xcodeproj -scheme Glyph -configuration Debug \\
                -derivedDataPath build build
     (or just build/run in Xcode)
  2. Launch Glyph and start a recording — grant the Screen Recording prompt ONCE.
     It will persist across all future rebuilds.

If you ever change the bundle id, the grant resets (expected) — just grant once more.
EOF
