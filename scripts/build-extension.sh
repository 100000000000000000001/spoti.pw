#!/usr/bin/env bash
# Builds the Live Activity widget extension without an Xcode project.
#
#   scripts/build-extension.sh <host Info.plist> <out dir>
#
# Writes <out dir>/SpotifyGlassLiveActivity.appex. Needs Xcode (xcode-select or DEVELOPER_DIR) for the
# iPhoneOS Swift toolchain.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_PLIST="${1:?usage: $0 <host Info.plist> <out dir>}"
OUT="${2:?usage: $0 <host Info.plist> <out dir>}"
NAME=SpotifyGlassLiveActivity
APPEX="$OUT/$NAME.appex"
SHARED="$ROOT/tweak/Sources/Redesigned/LiveActivity/LiveActivityShared.swift"
WIDGET="$ROOT/extension/LiveActivity/LiveActivityWidget.swift"

rm -rf "$APPEX"
mkdir -p "$APPEX"

echo "==> building $NAME.appex"
xcrun --sdk iphoneos swiftc -O -wmo -parse-as-library -target arm64-apple-ios17.0 -module-name "$NAME" \
  -Xlinker -e -Xlinker _NSExtensionMain -o "$APPEX/$NAME" "$SHARED" "$WIDGET"

sed -e "s/HOST_BUNDLE_ID/$(plutil -extract CFBundleIdentifier raw -o - "$HOST_PLIST")/" \
    -e "s/HOST_SHORT_VERSION/$(plutil -extract CFBundleShortVersionString raw -o - "$HOST_PLIST")/" \
    -e "s/HOST_VERSION/$(plutil -extract CFBundleVersion raw -o - "$HOST_PLIST")/" \
    "$ROOT/extension/LiveActivity/Info.plist" > "$APPEX/Info.plist"
plutil -convert binary1 "$APPEX/Info.plist"

codesign -f -s - "$APPEX" >/dev/null 2>&1
echo "    $APPEX"
