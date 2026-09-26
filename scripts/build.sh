#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
APP="$ROOT/build/Klipp.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
ICONSET="$ROOT/build/Klipp.iconset"

python3 "$ROOT/scripts/generate_icon.py"

rm -rf "$APP" "$ICONSET"
mkdir -p "$MACOS" "$RES" "$ICONSET"

SRC=(${(f)"$(find "$ROOT/Klipp" -name '*.swift' | sort)"})

echo "Compilando Klipp (${#SRC[@]} archivos)…"
swiftc \
  -swift-version 5 \
  -parse-as-library \
  -module-name Klipp \
  -target x86_64-apple-macosx14.0 \
  -sdk "$SDK" \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  -framework Carbon \
  -framework ServiceManagement \
  -framework ApplicationServices \
  -framework Combine \
  -framework CryptoKit \
  -o "$MACOS/Klipp" \
  "${SRC[@]}"

ICON_SRC="$ROOT/Klipp/Resources/Assets.xcassets/AppIcon.appiconset"
cp "$ICON_SRC/icon_16.png"      "$ICONSET/icon_16x16.png"
cp "$ICON_SRC/icon_16@2x.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICON_SRC/icon_32.png"      "$ICONSET/icon_32x32.png"
cp "$ICON_SRC/icon_32@2x.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICON_SRC/icon_128.png"     "$ICONSET/icon_128x128.png"
cp "$ICON_SRC/icon_128@2x.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICON_SRC/icon_256.png"     "$ICONSET/icon_256x256.png"
cp "$ICON_SRC/icon_256@2x.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICON_SRC/icon_512.png"     "$ICONSET/icon_512x512.png"
cp "$ICON_SRC/icon_512@2x.png"  "$ICONSET/icon_512x512@2x.png"
iconutil -c icns -o "$RES/AppIcon.icns" "$ICONSET"

cp "$ROOT/scripts/Info.plist" "$APP/Contents/Info.plist"
echo -n "APPLKLIP" > "$APP/Contents/PkgInfo"
IDENTITY="${CODESIGN_IDENTITY:-Apple Development: rauldnet@icloud.com (8NZF5579GJ)}"
if security find-identity -v -p codesigning | grep -F "$IDENTITY" >/dev/null; then
  codesign --force --deep --sign "$IDENTITY" --identifier app.klipp.Klipp "$APP"
else
  echo "No está la identidad de desarrollo; firmo ad-hoc."
  codesign --force --deep --sign - --identifier app.klipp.Klipp "$APP"
fi

STABLE="$HOME/Applications/Klipp.app"
mkdir -p "$HOME/Applications"
rm -rf "$STABLE"
cp -R "$APP" "$STABLE"
xattr -dr com.apple.quarantine "$STABLE" 2>/dev/null || true
codesign --force --deep --sign "$IDENTITY" --identifier app.klipp.Klipp "$STABLE" 2>/dev/null || codesign --force --deep --sign - --identifier app.klipp.Klipp "$STABLE"

echo "Listo: $STABLE"
