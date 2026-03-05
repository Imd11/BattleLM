#!/bin/bash

set -euo pipefail

VERSION="${1:-}"
BUNDLE_DIR="${2:-flutter_app/build/linux/x64/release/bundle}"
OUTPUT_DIR="${3:-dist/linux}"
APP_NAME="BattleLM"
BINARY_NAME="battle_lm"

if [[ -z "$VERSION" ]]; then
  if [[ -f "flutter_app/pubspec.yaml" ]]; then
    VERSION="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' flutter_app/pubspec.yaml | head -n 1)"
  fi
fi

if [[ -z "$VERSION" ]]; then
  echo "Unable to resolve version" >&2
  exit 1
fi

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "Linux bundle not found: $BUNDLE_DIR" >&2
  exit 1
fi

APPIMAGETOOL="${APPIMAGETOOL:-}"
if [[ -z "$APPIMAGETOOL" ]]; then
  echo "APPIMAGETOOL is not set" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

TMP_DIR="$(mktemp -d)"
APPDIR="$TMP_DIR/${APP_NAME}.AppDir"
mkdir -p "$APPDIR"

cp -R "$BUNDLE_DIR"/. "$APPDIR"/
cp "flutter_app/assets/images/battle_logo.png" "$APPDIR/${BINARY_NAME}.png"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec "$HERE/battle_lm" "$@"
EOF
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/${BINARY_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=BattleLM AI battle platform
Exec=${BINARY_NAME}
Icon=${BINARY_NAME}
Categories=Utility;Development;
Terminal=false
EOF

OUTPUT_PATH="${OUTPUT_DIR}/BattleLM-Linux-x86_64-${VERSION}.AppImage"

if [[ "$APPIMAGETOOL" == *.AppImage ]]; then
  ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_PATH"
else
  ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_PATH"
fi

rm -rf "$TMP_DIR"

echo "Created $OUTPUT_PATH"
