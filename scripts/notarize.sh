#!/usr/bin/env bash
# Codesign (hardened runtime), notarize, and staple the release binaries.
# Requires Apple Developer credentials in the environment; no-ops with a warning
# when they are absent, so unsigned artifacts can still be produced by forks.
#
# Required env: DEVELOPER_ID ("Developer ID Application: …"), NOTARY_PROFILE
#               (a stored `notarytool` keychain profile).
# Usage: scripts/notarize.sh <staging-dir-containing-bin>
set -euo pipefail

STAGE="${1:?usage: notarize.sh <staging-dir>}"

if [[ -z "${DEVELOPER_ID:-}" || -z "${NOTARY_PROFILE:-}" ]]; then
  echo "WARNING: DEVELOPER_ID / NOTARY_PROFILE not set; producing UNSIGNED artifacts."
  exit 0
fi

echo "==> Codesigning with hardened runtime"
for binary in "$STAGE/bin/chronicle" "$STAGE/bin/chronicled"; do
  codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID" "$binary"
done

echo "==> Zipping for notarization"
ZIP="$STAGE/../chronicle-notarize.zip"
ditto -c -k --keepParent "$STAGE/bin" "$ZIP"

echo "==> Submitting to Apple notary service"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
for binary in "$STAGE/bin/chronicle" "$STAGE/bin/chronicled"; do
  xcrun stapler staple "$binary" || true
done

echo "==> Verifying"
for binary in "$STAGE/bin/chronicle" "$STAGE/bin/chronicled"; do
  codesign --verify --strict --verbose=2 "$binary"
done
echo "==> Notarization complete"
