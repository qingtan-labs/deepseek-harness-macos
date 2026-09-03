#!/bin/zsh
# DeepSeek Harness 1.0.1 bilingual per-user installer.

set -euo pipefail
IFS=$'\n\t'
umask 077

readonly APP_NAME='DeepSeek Harness.app'
readonly APP_EXECUTABLE='DeepSeekHarness'
readonly BUNDLE_IDENTIFIER='com.yestar.deepseek-harness'
readonly APP_VERSION='1.0.1'
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
readonly APP_SOURCE="$SCRIPT_DIR/$APP_NAME"
readonly RUNTIME_INSTALLER="$APP_SOURCE/Contents/Resources/InstallRuntime.command"
readonly SYSTEM_APP="/Applications/$APP_NAME"
readonly USER_APPLICATIONS="$HOME/Applications"
readonly USER_APP="$USER_APPLICATIONS/$APP_NAME"
readonly SUPPORT_DIR="$HOME/Library/Application Support/DeepSeek Harness"
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
say_note() { print; print -r -- "==> $(localized "$1" "$2")"; }
stop_with_error() { print -u2; print -u2 -r -- "$(localized "Installation did not finish:" "安装未完成：") $1"; exit 1; }

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
[[ -x "$RUNTIME_INSTALLER" ]] || stop_with_error "$(localized "The bundled runtime installer is missing." "应用内置运行环境安装器缺失。")"
[[ "$(bundle_identifier_at "$APP_SOURCE")" == "$BUNDLE_IDENTIFIER" ]] || stop_with_error "$(localized "The app bundle identifier is invalid." "应用标识无效。")"
[[ "$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')" -ge 13 ]] || stop_with_error "$(localized "macOS 13 or later is required." "需要 macOS 13 或更高版本。")"

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

say_note "Verifying the release" "检查发布包完整性"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_SOURCE" \
  || stop_with_error "$(localized "Signature verification failed. Download the complete release again." "应用签名校验失败。请重新下载完整安装包。")"
/usr/bin/lipo "$APP_SOURCE/Contents/MacOS/$APP_EXECUTABLE" -verify_arch arm64 x86_64 \
  || stop_with_error "$(localized "The universal app binary is incomplete." "通用应用二进制不完整。")"

say_note "Checking the existing DSH and Node.js environment" "检查现有 DSH 与 Node.js 环境"
DEEPSEEK_HARNESS_LANGUAGE="$([[ "$USE_CHINESE" == 1 ]] && print -r -- 'zh-Hans' || print -r -- 'en')" \
  DEEPSEEK_HARNESS_REUSE_COMPATIBLE_ENVIRONMENT=1 \
  "$RUNTIME_INSTALLER" \
  || stop_with_error "$(localized "Could not select or install a compatible runtime. The existing app was not replaced." "无法选择或安装兼容运行环境，现有应用未被替换。")"

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

say_note "Registering the app, Dock icon, and menu bar controller" "注册应用、Dock 图标和菜单栏控制器"
"$LSREGISTER" -f "$APP_DESTINATION" >/dev/null 2>&1 || true
if ! /usr/bin/defaults read com.apple.dock persistent-apps 2>/dev/null | /usr/bin/grep -Fq '"file-label" = "DeepSeek Harness"'; then
  /usr/bin/defaults write com.apple.dock persistent-apps -array-add \
    "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>${APP_DESTINATION}</string><key>_CFURLStringType</key><integer>0</integer></dict><key>file-label</key><string>DeepSeek Harness</string></dict><key>tile-type</key><string>file-tile</string></dict>"
  /usr/bin/killall Dock 2>/dev/null || true
fi
/usr/bin/open "$APP_DESTINATION"
/bin/rm -rf "$BACKUP_DIR"

print
print -r -- "$(localized "Done. DeepSeek Harness was installed at:" "完成。DeepSeek Harness 已安装到：") $APP_DESTINATION"
print -r -- "$(localized "The Dock and menu bar now share one controller. Clicking the Dock icon reuses an existing page or window whenever possible." "Dock 与菜单栏现在共用同一个控制器；点击 Dock 会优先复用已有网页或应用内窗口。")"
print -r -- "$(localized "Temporary rollback archives were removed after the successful upgrade; no old app packages are retained." "升级成功后已删除临时回滚归档，不保留任何旧应用包。")"
