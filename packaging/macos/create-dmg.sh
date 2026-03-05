#!/bin/bash

set -euo pipefail

VERSION="${1:-}"
APP_PATH="${2:-flutter_app/build/macos/Build/Products/Release/battle_lm.app}"
OUTPUT_DIR="${3:-dist/macos}"

if [[ -z "$VERSION" ]]; then
  if [[ -f "flutter_app/pubspec.yaml" ]]; then
    VERSION="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' flutter_app/pubspec.yaml | head -n 1)"
  fi
fi

if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMP_DIR="$(mktemp -d)"
STAGING_DIR="$TMP_DIR/BattleLM"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

DMG_PATH="$OUTPUT_DIR/BattleLM-macOS-${VERSION}.dmg"

hdiutil create \
  -volname "BattleLM" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$TMP_DIR"

echo "Created $DMG_PATH"
