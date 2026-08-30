#!/bin/zsh
# Build a reproducible local release from this source folder.

set -euo pipefail
IFS=$'\n\t'

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly WORK_DIR="$ROOT_DIR/.build"
readonly OUTPUT_DIR="$ROOT_DIR/dist"
readonly APP_NAME='DeepSeek Harness.app'
readonly RELEASE_NAME='DeepSeek-Harness-1.0.0-macOS'
readonly APP_DIR="$WORK_DIR/$APP_NAME"
readonly LOGIN_HELPER_DIR="$APP_DIR/Contents/Library/LoginItems/DeepSeek Harness Login Helper.app"
readonly ICONSET_DIR="$WORK_DIR/DeepSeekHarness.iconset"
readonly RELEASE_DIR="$WORK_DIR/$RELEASE_NAME"
readonly ZIP_PATH="$OUTPUT_DIR/$RELEASE_NAME.zip"

/bin/rm -rf "$WORK_DIR"
/bin/mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources/en.lproj" \
  "$APP_DIR/Contents/Resources/zh-Hans.lproj" "$LOGIN_HELPER_DIR/Contents/MacOS" "$ICONSET_DIR" "$OUTPUT_DIR"

/usr/bin/clang -Wall -Wextra -fobjc-arc -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
  -framework Cocoa -framework WebKit -framework ServiceManagement "$ROOT_DIR/src/DeepSeekHarness.m" \
  -o "$APP_DIR/Contents/MacOS/DeepSeekHarness"
/usr/bin/clang -Wall -Wextra -fobjc-arc -arch arm64 -arch x86_64 -mmacosx-version-min=13.0 \
  -framework Cocoa "$ROOT_DIR/src/DeepSeekHarnessLoginHelper.m" \
  -o "$LOGIN_HELPER_DIR/Contents/MacOS/DeepSeekHarnessLoginHelper"
/usr/bin/clang -fobjc-arc -mmacosx-version-min=13.0 -framework Cocoa \
  "$ROOT_DIR/tools/OfficialWhaleIconRenderer.m" -o "$WORK_DIR/render-icon"
/usr/bin/clang -fobjc-arc -mmacosx-version-min=13.0 -framework Foundation \
  "$ROOT_DIR/tools/IcnsBuilder.m" -o "$WORK_DIR/build-icns"
"$WORK_DIR/render-icon" "$ROOT_DIR/assets/DeepSeekWhale.svg" "$WORK_DIR/icon-1024.png"

for spec in '16 icon_16x16.png' '32 icon_16x16@2x.png' '32 icon_32x32.png' '64 icon_32x32@2x.png' '128 icon_128x128.png' '256 icon_128x128@2x.png' '256 icon_256x256.png' '512 icon_256x256@2x.png' '512 icon_512x512.png' '1024 icon_512x512@2x.png'; do
  size="${spec%% *}"
  filename="${spec#* }"
  /usr/bin/sips -z "$size" "$size" "$WORK_DIR/icon-1024.png" --out "$ICONSET_DIR/$filename" >/dev/null
done
"$WORK_DIR/build-icns" "$ICONSET_DIR" "$APP_DIR/Contents/Resources/DeepSeekHarness.icns"
/bin/cp "$ROOT_DIR/assets/DeepSeekWhale.svg" "$APP_DIR/Contents/Resources/DeepSeekWhale.svg"
/bin/cp "$ROOT_DIR/resources/en.lproj/Localizable.strings" "$ROOT_DIR/resources/en.lproj/InfoPlist.strings" "$APP_DIR/Contents/Resources/en.lproj/"
/bin/cp "$ROOT_DIR/resources/zh-Hans.lproj/Localizable.strings" "$ROOT_DIR/resources/zh-Hans.lproj/InfoPlist.strings" "$APP_DIR/Contents/Resources/zh-Hans.lproj/"
/bin/cp "$ROOT_DIR/src/DeepSeekHarness-Info.plist" "$APP_DIR/Contents/Info.plist"
/bin/cp "$ROOT_DIR/src/DeepSeekHarnessLoginHelper-Info.plist" "$LOGIN_HELPER_DIR/Contents/Info.plist"
/usr/bin/plutil -lint "$APP_DIR/Contents/Info.plist" "$LOGIN_HELPER_DIR/Contents/Info.plist" \
  "$APP_DIR/Contents/Resources/en.lproj/Localizable.strings" "$APP_DIR/Contents/Resources/zh-Hans.lproj/Localizable.strings"
/usr/bin/codesign --force --sign - "$LOGIN_HELPER_DIR"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_DIR"
/usr/bin/lipo -archs "$APP_DIR/Contents/MacOS/DeepSeekHarness" | /usr/bin/grep -Eq 'arm64.*x86_64|x86_64.*arm64'
/usr/bin/lipo -archs "$LOGIN_HELPER_DIR/Contents/MacOS/DeepSeekHarnessLoginHelper" | /usr/bin/grep -Eq 'arm64.*x86_64|x86_64.*arm64'

/bin/mkdir -p "$RELEASE_DIR"
/usr/bin/ditto "$APP_DIR" "$RELEASE_DIR/$APP_NAME"
/bin/cp "$ROOT_DIR/scripts/install.command" "$RELEASE_DIR/install.command"
/bin/chmod 755 "$RELEASE_DIR/install.command"
/bin/cp "$ROOT_DIR/README.md" "$ROOT_DIR/README.zh-Hans.md" "$ROOT_DIR/RELEASE-NOTES.md" \
  "$ROOT_DIR/RELEASE-NOTES.zh-Hans.md" "$ROOT_DIR/manifest.json" "$RELEASE_DIR/"
/bin/rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$RELEASE_DIR" "$ZIP_PATH"
(cd "$OUTPUT_DIR" && /usr/bin/shasum -a 256 "$RELEASE_NAME.zip" > "$RELEASE_NAME.zip.sha256")
/usr/bin/unzip -t "$ZIP_PATH" >/dev/null
/bin/rm -rf "$RELEASE_DIR" "$APP_DIR" "$ICONSET_DIR"

print -r -- "Built: $ZIP_PATH"
print -r -- "SHA-256: $ZIP_PATH.sha256"
