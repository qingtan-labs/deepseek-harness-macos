#!/bin/zsh

set -euo pipefail
IFS=$'\n\t'

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly EXPECTED_VERSION='1.0.0'
readonly REQUIRED_FILES=(
  README.md README.zh-Hans.md CHANGELOG.md CONTRIBUTING.md SECURITY.md SUPPORT.md
  CODE_OF_CONDUCT.md LICENSE manifest.json
  src/DeepSeekHarness.m src/DeepSeekHarnessLoginHelper.m
  scripts/build-release.command scripts/install.command
  docs/images/harness-live.en.jpg docs/images/harness-live.zh-Hans.jpg docs/images/menu-bar-live.zh-Hans.png
  docs/images/menu-bar-controller.svg docs/images/browser-reuse.svg docs/images/in-app-window.svg
  docs/images/menu-bar-controller.zh-Hans.svg docs/images/browser-reuse.zh-Hans.svg docs/images/in-app-window.zh-Hans.svg
)

cd "$ROOT_DIR"

for required_file in "${REQUIRED_FILES[@]}"; do
  [[ -f "$required_file" ]] || { print -u2 -r -- "Missing required file: $required_file"; exit 1; }
done

/bin/zsh -n scripts/build-release.command scripts/check-repository.command scripts/install.command
/usr/bin/plutil -lint \
  src/DeepSeekHarness-Info.plist \
  src/DeepSeekHarnessLoginHelper-Info.plist \
  resources/en.lproj/InfoPlist.strings \
  resources/en.lproj/Localizable.strings \
  resources/zh-Hans.lproj/InfoPlist.strings \
  resources/zh-Hans.lproj/Localizable.strings >/dev/null

plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' src/DeepSeekHarness-Info.plist)"
manifest_version="$(/usr/bin/plutil -extract version raw manifest.json)"
[[ "$plist_version" == "$EXPECTED_VERSION" ]] || { print -u2 -r -- "Unexpected plist version: $plist_version"; exit 1; }
[[ "$manifest_version" == "$EXPECTED_VERSION" ]] || { print -u2 -r -- "Unexpected manifest version: $manifest_version"; exit 1; }
/usr/bin/grep -Fq "readonly APP_VERSION='$EXPECTED_VERSION'" scripts/install.command
/usr/bin/grep -Fq "DeepSeek-Harness-$EXPECTED_VERSION-macOS" scripts/build-release.command
/usr/bin/grep -Fq "DeepSeek-Harness-$EXPECTED_VERSION-macOS.zip" README.md
/usr/bin/grep -Fq "DeepSeek-Harness-$EXPECTED_VERSION-macOS.zip" README.zh-Hans.md
/usr/bin/xmllint --noout \
  docs/images/menu-bar-controller.svg \
  docs/images/browser-reuse.svg \
  docs/images/in-app-window.svg \
  docs/images/menu-bar-controller.zh-Hans.svg \
  docs/images/browser-reuse.zh-Hans.svg \
  docs/images/in-app-window.zh-Hans.svg
/usr/bin/sips -g format docs/images/harness-live.en.jpg | /usr/bin/grep -Fq 'format: jpeg'
/usr/bin/sips -g format docs/images/harness-live.zh-Hans.jpg | /usr/bin/grep -Fq 'format: jpeg'
/usr/bin/sips -g format docs/images/menu-bar-live.zh-Hans.png | /usr/bin/grep -Fq 'format: png'

if /usr/bin/find . -path './.git' -prune -o -path './.build' -prune -o -path './dist' -prune \
  -o \( -name '.DS_Store' -o -name '*.app' -o -name '*.zip' \) -print | /usr/bin/grep -q .; then
  print -u2 -r -- 'Generated artifacts are present outside ignored build directories.'
  exit 1
fi

print -r -- "Repository checks passed for version $EXPECTED_VERSION."
