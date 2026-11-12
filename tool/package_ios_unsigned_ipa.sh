#!/usr/bin/env bash
set -euo pipefail

# Packages a --no-codesign iOS Release Runner.app into a versioned unsigned .ipa
# ready for Xcode re-signing or sideloading (AltStore / Sideloadly / Impactor).

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION_RAW="$(awk -F': *' '/^version:/{print $2; exit}' pubspec.yaml | tr -d '[:space:]')"
VERSION_NAME="${1:-${VERSION_RAW%%+*}}"
if [[ -z "$VERSION_NAME" ]]; then
  echo "Error: Could not determine app version from pubspec.yaml." >&2
  exit 1
fi

APP_BUNDLE="${ROOT_DIR}/build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Error: Built iOS Runner.app not found at $APP_BUNDLE." >&2
  echo "Run: flutter build ios --release --no-codesign" >&2
  exit 1
fi

OUT_DIR="${ROOT_DIR}/build/ios/ipa"
OUT_IPA="${OUT_DIR}/CCDauthau-v${VERSION_NAME}-unsigned.ipa"
mkdir -p "$OUT_DIR"

STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "${STAGING_DIR}/Payload"
if command -v ditto >/dev/null 2>&1; then
  ditto "$APP_BUNDLE" "${STAGING_DIR}/Payload/Runner.app"
else
  cp -a "$APP_BUNDLE" "${STAGING_DIR}/Payload/Runner.app"
fi

rm -f "$OUT_IPA"
(
  cd "$STAGING_DIR"
  zip -qry "$OUT_IPA" Payload
)

echo "Created unsigned iOS package: $OUT_IPA"
ls -lh "$OUT_IPA"
