#!/bin/zsh
# DeepSeek Harness 1.0.0 bilingual per-user installer.

set -euo pipefail
IFS=$'\n\t'
umask 077

readonly APP_NAME='DeepSeek Harness.app'
readonly APP_EXECUTABLE='DeepSeekHarness'
readonly BUNDLE_IDENTIFIER='com.yestar.deepseek-harness'
readonly APP_VERSION='1.0.0'
readonly NODE_VERSION='22.21.1'
readonly DSH_VERSION='0.1.1-rc.2'
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
readonly APP_SOURCE="$SCRIPT_DIR/$APP_NAME"
readonly SYSTEM_APP="/Applications/$APP_NAME"
readonly USER_APPLICATIONS="$HOME/Applications"
readonly USER_APP="$USER_APPLICATIONS/$APP_NAME"
readonly SUPPORT_DIR="$HOME/Library/Application Support/DeepSeek Harness"
readonly RUNTIME_DIR="$SUPPORT_DIR/runtime/current"
readonly NPM_PREFIX="$SUPPORT_DIR/npm"
readonly BACKUP_DIR="$SUPPORT_DIR/Archived App Versions"
readonly LEGACY_LOGIN_PLIST="$HOME/Library/LaunchAgents/com.yestar.deepseek-harness.unified.plist"
readonly LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'

system_language="$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2{s/[",[:space:]]//g;p;}' || true)"
case "${system_language:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}" in
  zh*|ZH*) readonly USE_CHINESE=1 ;;
  *) readonly USE_CHINESE=0 ;;
esac

localized() {
  if (( USE_CHINESE )); then print -r -- "$2"; else print -r -- "$1"; fi
}
say_note() { print -r -- "\n==> $(localized "$1" "$2")"; }
stop_with_error() { print -u2 -r -- "\n$(localized "Installation did not finish:" "安装未完成：") $1"; exit 1; }

bundle_identifier_at() {
  /usr/bin/defaults read "$1/Contents/Info" CFBundleIdentifier 2>/dev/null || true
}

is_harness_app() {
  [[ -d "$1" && "$(bundle_identifier_at "$1")" == "$BUNDLE_IDENTIFIER" ]]
}

archive_and_remove_app() {
  local candidate="$1" label="$2" allow_legacy="${3:-0}" archive_path
  if [[ "$allow_legacy" == 1 ]]; then
    [[ -d "$candidate" && "$candidate" == "$SUPPORT_DIR"/* && "$candidate" == *.app ]] || return 0
  else
    is_harness_app "$candidate" || return 0
  fi
  archive_path="$BACKUP_DIR/${label}-$(/bin/date '+%Y%m%d-%H%M%S')-${RANDOM}.zip"
  "$LSREGISTER" -u "$candidate" >/dev/null 2>&1 || true
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$candidate" "$archive_path" \
    || stop_with_error "$(localized "Could not archive the old app." "无法归档旧应用。")"
  /bin/rm -rf "$candidate"
  print -r -- "$(localized "Archived:" "已归档：") $archive_path"
}

[[ -d "$APP_SOURCE" ]] || stop_with_error "$(localized "Keep install.command beside $APP_NAME." "未找到 $APP_NAME；请不要单独移动 install.command。")"
[[ -x "$APP_SOURCE/Contents/MacOS/$APP_EXECUTABLE" ]] || stop_with_error "$(localized "The app bundle is incomplete." "应用包不完整。")"
[[ "$(bundle_identifier_at "$APP_SOURCE")" == "$BUNDLE_IDENTIFIER" ]] || stop_with_error "$(localized "The app bundle identifier is invalid." "应用标识无效。")"
[[ "$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')" -ge 13 ]] || stop_with_error "$(localized "macOS 13 or later is required." "需要 macOS 13 或更高版本。")"

case "$(/usr/bin/uname -m)" in
  arm64) readonly NODE_PLATFORM='darwin-arm64' ;;
  x86_64) readonly NODE_PLATFORM='darwin-x64' ;;
  *) stop_with_error "$(localized "Unsupported Mac architecture:" "不支持的 Mac 架构：") $(/usr/bin/uname -m)" ;;
esac

if [[ -e "$SYSTEM_APP" ]] && ! is_harness_app "$SYSTEM_APP"; then
  stop_with_error "$(localized "$SYSTEM_APP exists but belongs to another app." "$SYSTEM_APP 已存在，但它不是本安装包的应用。")"
fi
if [[ -e "$USER_APP" ]] && ! is_harness_app "$USER_APP"; then
  stop_with_error "$(localized "$USER_APP exists but belongs to another app." "$USER_APP 已存在，但它不是本安装包的应用。")"
fi

if is_harness_app "$SYSTEM_APP"; then
  readonly APP_DESTINATION="$SYSTEM_APP"
elif is_harness_app "$USER_APP"; then
  readonly APP_DESTINATION="$USER_APP"
else
  readonly APP_DESTINATION="$USER_APP"
fi

readonly NODE_ARCHIVE="node-v${NODE_VERSION}-${NODE_PLATFORM}.tar.xz"
readonly NODE_BASE_URL="https://nodejs.org/dist/v${NODE_VERSION}"

say_note "Verifying the release" "检查发布包完整性"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_SOURCE" \
  || stop_with_error "$(localized "Signature verification failed. Download the complete release again." "应用签名校验失败。请重新下载完整安装包。")"
/usr/bin/lipo "$APP_SOURCE/Contents/MacOS/$APP_EXECUTABLE" -verify_arch arm64 x86_64 \
  || stop_with_error "$(localized "The universal app binary is incomplete." "通用应用二进制不完整。")"

say_note "Stopping the old controller (the Harness service keeps running)" "正在停止旧控制器（Harness 服务会继续运行）"
if [[ -f "$LEGACY_LOGIN_PLIST" ]]; then
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$LEGACY_LOGIN_PLIST" >/dev/null 2>&1 || true
fi
typeset -a controller_pids
controller_pids=( ${(@f)$(/usr/bin/pgrep -x "$APP_EXECUTABLE" 2>/dev/null || true)} )
for controller_pid in "${controller_pids[@]}"; do
  [[ -n "$controller_pid" ]] && /bin/kill -TERM "$controller_pid" 2>/dev/null || true
done
for attempt in {1..50}; do
  /usr/bin/pgrep -x "$APP_EXECUTABLE" >/dev/null 2>&1 || break
  /bin/sleep 0.1
done
/usr/bin/pgrep -x "$APP_EXECUTABLE" >/dev/null 2>&1 \
  && stop_with_error "$(localized "Quit DeepSeek Harness from its menu and run the installer again." "请先从菜单退出 DeepSeek Harness，再重新运行安装器。")"

say_note "Installing DeepSeek Harness ${APP_VERSION}" "安装 DeepSeek Harness ${APP_VERSION}"
/bin/mkdir -p "$USER_APPLICATIONS" "$SUPPORT_DIR" "$BACKUP_DIR"
if [[ "$APP_DESTINATION" == "$SYSTEM_APP" && ! -w "/Applications" ]]; then
  stop_with_error "$(localized "The existing app in /Applications is not writable. Move it to Trash or reinstall for this user." "/Applications 中的现有应用不可写。请先移到废纸篓，或改为当前用户安装。")"
fi

temporary_app="${APP_DESTINATION}.installing.$$"
/bin/rm -rf "$temporary_app"
/usr/bin/ditto "$APP_SOURCE" "$temporary_app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$temporary_app" \
  || stop_with_error "$(localized "The copied app did not pass verification." "复制后的应用未通过校验。")"

archive_and_remove_app "$APP_DESTINATION" "DeepSeek-Harness-previous"
if [[ "$APP_DESTINATION" == "$SYSTEM_APP" ]]; then
  archive_and_remove_app "$USER_APP" "DeepSeek-Harness-duplicate-user-copy"
else
  archive_and_remove_app "$SYSTEM_APP" "DeepSeek-Harness-duplicate-system-copy"
fi

/bin/mv "$temporary_app" "$APP_DESTINATION"

say_note "Archiving old app-bundle backups to prevent duplicate app registration" "正在压缩旧应用备份，避免系统重复注册"
while IFS= read -r -d '' legacy_app; do
  archive_and_remove_app "$legacy_app" "DeepSeek-Harness-legacy-backup" 1
done < <(/usr/bin/find "$SUPPORT_DIR" -type d -name '*.app' -prune -print0 2>/dev/null)

install_runtime() {
  local temporary_dir archive_path shasums_path expected actual extracted_dir runtime_backup
  temporary_dir="$(/usr/bin/mktemp -d "${TMPDIR:-/private/tmp}/deepseek-harness.XXXXXX")"
  trap '/bin/rm -rf "$temporary_dir"' EXIT
  archive_path="$temporary_dir/$NODE_ARCHIVE"
  shasums_path="$temporary_dir/SHASUMS256.txt"

  say_note "Downloading verified Node.js ${NODE_VERSION}" "下载受校验的 Node.js ${NODE_VERSION} 运行时"
  /usr/bin/curl --fail --location --silent --show-error "$NODE_BASE_URL/SHASUMS256.txt" -o "$shasums_path" \
    || stop_with_error "$(localized "Could not download the Node.js checksum file." "无法下载 Node.js 校验文件。")"
  expected="$(/usr/bin/awk -v file="$NODE_ARCHIVE" '$2 == file {print $1}' "$shasums_path")"
  [[ -n "$expected" ]] || stop_with_error "$(localized "The checksum list does not contain $NODE_ARCHIVE." "Node.js 校验文件中缺少 $NODE_ARCHIVE。")"
  /usr/bin/curl --fail --location --silent --show-error "$NODE_BASE_URL/$NODE_ARCHIVE" -o "$archive_path" \
    || stop_with_error "$(localized "Could not download Node.js." "无法下载 Node.js 运行时。")"
  actual="$(/usr/bin/shasum -a 256 "$archive_path" | /usr/bin/awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || stop_with_error "$(localized "The Node.js checksum did not match. The download was not used." "Node.js 下载校验失败，未使用该文件。")"
  /usr/bin/tar -xJf "$archive_path" -C "$temporary_dir" \
    || stop_with_error "$(localized "Could not extract Node.js." "无法解压 Node.js 运行时。")"
  extracted_dir="$temporary_dir/node-v${NODE_VERSION}-${NODE_PLATFORM}"
  [[ -x "$extracted_dir/bin/node" ]] || stop_with_error "$(localized "The Node.js runtime is incomplete." "Node.js 运行时内容不完整。")"

  if [[ -e "$RUNTIME_DIR" ]]; then
    runtime_backup="$SUPPORT_DIR/runtime/previous-$(/bin/date '+%Y%m%d%H%M%S')"
    /bin/mv "$RUNTIME_DIR" "$runtime_backup"
  fi
  /bin/mkdir -p "${RUNTIME_DIR:h}"
  /bin/mv "$extracted_dir" "$RUNTIME_DIR"
  [[ "$("$RUNTIME_DIR/bin/node" --version)" == "v${NODE_VERSION}" ]] \
    || stop_with_error "$(localized "Node.js version verification failed." "Node.js 版本校验失败。")"
  trap - EXIT
  /bin/rm -rf "$temporary_dir"
}

if [[ ! -x "$RUNTIME_DIR/bin/node" || "$("$RUNTIME_DIR/bin/node" --version 2>/dev/null || true)" != "v${NODE_VERSION}" ]]; then
  install_runtime
else
  say_note "Reusing verified Node.js ${NODE_VERSION}" "复用已校验的 Node.js ${NODE_VERSION} 运行时"
fi

readonly DSH_BIN="$NPM_PREFIX/node_modules/.bin/dsh"
installed_dsh_version="$(PATH="$RUNTIME_DIR/bin:$PATH" "$DSH_BIN" --version 2>/dev/null || true)"
if [[ "$installed_dsh_version" == "$DSH_VERSION" ]]; then
  say_note "Reusing the verified DeepSeek Harness CLI ${DSH_VERSION}" "复用已校验的 DeepSeek Harness CLI ${DSH_VERSION}"
else
  say_note "Installing the pinned DeepSeek Harness CLI ${DSH_VERSION}" "安装固定版本的 DeepSeek Harness CLI ${DSH_VERSION}"
  /bin/mkdir -p "$NPM_PREFIX"
  "$RUNTIME_DIR/bin/node" "$RUNTIME_DIR/lib/node_modules/npm/bin/npm-cli.js" \
    --prefix "$NPM_PREFIX" install --no-audit --no-fund --save-exact "@deepseek-ai/dsh@${DSH_VERSION}" \
    || stop_with_error "$(localized "Could not install the DeepSeek Harness CLI." "无法安装 DeepSeek Harness CLI。")"
fi

[[ -x "$DSH_BIN" ]] || stop_with_error "$(localized "The DeepSeek Harness CLI installation is incomplete." "DeepSeek Harness CLI 安装不完整。")"
installed_dsh_version="$(PATH="$RUNTIME_DIR/bin:$PATH" "$DSH_BIN" --version 2>/dev/null || true)"
[[ "$installed_dsh_version" == "$DSH_VERSION" ]] \
  || stop_with_error "$(localized "DeepSeek Harness CLI version check failed; found: ${installed_dsh_version:-unknown}." "DeepSeek Harness CLI 版本校验失败（得到：${installed_dsh_version:-未知}）。")"

say_note "Registering the app, Dock icon, and menu bar controller" "注册应用、Dock 图标和菜单栏控制器"
"$LSREGISTER" -f "$APP_DESTINATION" >/dev/null 2>&1 || true
if ! /usr/bin/defaults read com.apple.dock persistent-apps 2>/dev/null | /usr/bin/grep -Fq '"file-label" = "DeepSeek Harness"'; then
  /usr/bin/defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${APP_DESTINATION}</string><key>_CFURLStringType</key><integer>0</integer></dict><key>file-label</key><string>DeepSeek Harness</string></dict><key>tile-type</key><string>file-tile</string></dict>"
  /usr/bin/killall Dock 2>/dev/null || true
fi
/usr/bin/open "$APP_DESTINATION"
/bin/rm -rf "$BACKUP_DIR"

print -r -- "\n$(localized "Done. DeepSeek Harness was installed at:" "完成。DeepSeek Harness 已安装到：") $APP_DESTINATION"
print -r -- "$(localized "The Dock and menu bar now share one controller. Clicking the Dock icon reuses an existing page or window whenever possible." "Dock 与菜单栏现在共用同一个控制器；点击 Dock 会优先复用已有网页或应用内窗口。")"
print -r -- "$(localized "Temporary rollback archives were removed after the successful upgrade; no old app packages are retained." "升级成功后已删除临时回滚归档，不保留任何旧应用包。")"
