#!/usr/bin/env bash
# Build universal (arm64 + x86_64) release binaries, generate completions and man
# pages, and package a distributable tarball with checksums and a simple SBOM.
#
# Usage: scripts/release.sh <version>   (e.g. scripts/release.sh 1.0.0)
set -euo pipefail

VERSION="${1:?usage: release.sh <version>}"
DIST="dist"
STAGE="$DIST/chronicle-$VERSION"

rm -rf "$DIST"
mkdir -p "$STAGE/bin" "$STAGE/completions" "$STAGE/share/man/man1"

echo "==> Building universal release binaries"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
cp "$BIN/chronicle" "$BIN/chronicled" "$STAGE/bin/"

echo "==> Generating shell completions"
"$STAGE/bin/chronicle" --generate-completion-script zsh  > "$STAGE/completions/_chronicle"
"$STAGE/bin/chronicle" --generate-completion-script bash > "$STAGE/completions/chronicle.bash"
"$STAGE/bin/chronicle" --generate-completion-script fish > "$STAGE/completions/chronicle.fish"

echo "==> Generating man pages (best effort)"
swift package plugin --allow-writing-to-directory "$STAGE/share/man/man1" \
  generate-manual --output-directory "$STAGE/share/man/man1" 2>/dev/null || \
  echo "   (manual plugin unavailable; skipping)"

cp LICENSE README.md "$STAGE/"

echo "==> Writing SBOM"
{
  echo "Chronicle $VERSION — dependency SBOM"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  grep -E '"identity"|"version"' Package.resolved 2>/dev/null || cat Package.resolved
} > "$STAGE/SBOM.txt"

echo "==> Packaging"
TARBALL="$DIST/chronicle-$VERSION-macos-universal.tar.gz"
tar -czf "$TARBALL" -C "$DIST" "chronicle-$VERSION"
shasum -a 256 "$TARBALL" | tee "$DIST/SHA256SUMS"

echo "==> Done: $TARBALL"
