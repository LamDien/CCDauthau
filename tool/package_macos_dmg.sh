#!/usr/bin/env bash
set -euo pipefail

# Packages the release macOS .app bundle into a compressed, versioned .dmg
# image with an /Applications drag-and-drop symlink.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: macOS .dmg packaging requires macOS (hdiutil & ditto)." >&2
  exit 1
fi

VERSION_RAW="$(awk -F': *' '/^version:/{print $2; exit}' pubspec.yaml | tr -d '[:space:]')"
VERSION_NAME="${1:-${VERSION_RAW%%+*}}"
if [[ -z "$VERSION_NAME" ]]; then
  echo "Error: Could not determine app version from pubspec.yaml." >&2
  exit 1
fi

RELEASE_DIR="${ROOT_DIR}/build/macos/Build/Products/Release"
APP_BUNDLE="$(find "$RELEASE_DIR" -maxdepth 1 -type d -name "*.app" | head -n 1 || true)"
if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
  echo "Error: Release .app bundle not found under $RELEASE_DIR." >&2
  echo "Run: flutter build macos --release" >&2
  exit 1
fi

OUT_DMG="${RELEASE_DIR}/CCDauthau-v${VERSION_NAME}.dmg"
VOLUME_NAME="CC Dau Thau v${VERSION_NAME}"
STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

ditto "$APP_BUNDLE" "${STAGING_DIR}/CC Đấu Thầu.app"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "$OUT_DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUT_DMG" >/dev/null

echo "Created macOS installer: $OUT_DMG"
ls -lh "$OUT_DMG"
