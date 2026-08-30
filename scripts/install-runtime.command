#!/bin/zsh
# Transactional, existing-environment-first Node.js and DeepSeek Harness runtime installer.

set -euo pipefail
setopt NULL_GLOB
unsetopt BG_NICE
IFS=$'\n\t'
umask 077

readonly DEFAULT_NODE_VERSION='22.21.1'
readonly DEFAULT_MIN_NODE_MAJOR='20'
readonly DEFAULT_DSH_VERSION='0.1.1-rc.2'
readonly NODE_VERSION="${DEEPSEEK_HARNESS_NODE_VERSION:-$DEFAULT_NODE_VERSION}"
readonly MIN_NODE_MAJOR="${DEEPSEEK_HARNESS_MIN_NODE_MAJOR:-$DEFAULT_MIN_NODE_MAJOR}"
readonly DSH_VERSION="${DEEPSEEK_HARNESS_DSH_VERSION:-$DEFAULT_DSH_VERSION}"
readonly REUSE_COMPATIBLE_ENVIRONMENT="${DEEPSEEK_HARNESS_REUSE_COMPATIBLE_ENVIRONMENT:-1}"
readonly DISCOVERY_TIMEOUT="${DEEPSEEK_HARNESS_DISCOVERY_TIMEOUT:-10}"
typeset -i physical_memory_mb=0
typeset -i default_npm_heap_mb=3072
physical_memory_bytes="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || print -r -- 0)"
if [[ "$physical_memory_bytes" == <-> ]]; then
  physical_memory_mb=$(( physical_memory_bytes / 1024 / 1024 ))
fi
if (( physical_memory_mb >= 24576 )); then
  default_npm_heap_mb=8192
elif (( physical_memory_mb >= 16384 )); then
  default_npm_heap_mb=6144
elif (( physical_memory_mb >= 8192 )); then
  default_npm_heap_mb=4096
fi
readonly NPM_INSTALL_HEAP_MB="${DEEPSEEK_HARNESS_NPM_HEAP_MB:-$default_npm_heap_mb}"
readonly SUPPORT_DIR="${DEEPSEEK_HARNESS_SUPPORT_DIR:-$HOME/Library/Application Support/DeepSeek Harness}"
readonly RUNTIME_DIR="$SUPPORT_DIR/runtime/current"
readonly NPM_PREFIX="$SUPPORT_DIR/npm"
readonly ENVIRONMENT_RECORD="$SUPPORT_DIR/environment.plist"
readonly LOCK_DIR="$SUPPORT_DIR/.runtime-install.lock"

language_hint="${DEEPSEEK_HARNESS_LANGUAGE:-}"
if [[ -z "$language_hint" ]]; then
  language_hint="$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2{s/[",[:space:]]//g;p;}' || true)"
fi
case "$language_hint" in
  zh*|ZH*) readonly USE_CHINESE=1 ;;
  *) readonly USE_CHINESE=0 ;;
esac

localized() {
  if (( USE_CHINESE )); then print -r -- "$2"; else print -r -- "$1"; fi
}
say_note() { print; print -r -- "==> $(localized "$1" "$2")"; }
stop_with_error() { print -u2; print -u2 -r -- "$(localized "Runtime installation did not finish:" "运行环境安装未完成：") $1"; exit 1; }

print -r -- "$NODE_VERSION" | /usr/bin/grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || stop_with_error "$(localized "Invalid Node.js version." "Node.js 版本格式无效。")"
print -r -- "$MIN_NODE_MAJOR" | /usr/bin/grep -Eq '^[0-9]+$' \
  || stop_with_error "$(localized "Invalid minimum Node.js major version." "Node.js 最低主版本格式无效。")"
print -r -- "$DSH_VERSION" | /usr/bin/grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$' \
  || stop_with_error "$(localized "Invalid DSH version." "DSH 版本格式无效。")"
[[ "$REUSE_COMPATIBLE_ENVIRONMENT" == 0 || "$REUSE_COMPATIBLE_ENVIRONMENT" == 1 ]] \
  || stop_with_error "$(localized "Invalid environment reuse option." "环境复用选项无效。")"
[[ "$DISCOVERY_TIMEOUT" == <-> ]] && (( DISCOVERY_TIMEOUT >= 1 && DISCOVERY_TIMEOUT <= 30 )) \
  || stop_with_error "$(localized "Invalid environment discovery timeout." "环境检测超时时间无效。")"
[[ "$NPM_INSTALL_HEAP_MB" == <-> ]] && (( NPM_INSTALL_HEAP_MB >= 2048 && NPM_INSTALL_HEAP_MB <= 16384 )) \
  || stop_with_error "$(localized "Invalid npm installation memory limit." "npm 安装内存上限无效。")"
[[ "$SUPPORT_DIR" == /* ]] || stop_with_error "$(localized "The support directory must be an absolute path." "运行环境目录必须是绝对路径。")"
[[ "$(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}')" -ge 13 ]] \
  || stop_with_error "$(localized "macOS 13 or later is required." "需要 macOS 13 或更高版本。")"

case "$(/usr/bin/uname -m)" in
  arm64) readonly NODE_PLATFORM='darwin-arm64' ;;
  x86_64) readonly NODE_PLATFORM='darwin-x64' ;;
  *) stop_with_error "$(localized "Unsupported Mac architecture:" "不支持的 Mac 架构：") $(/usr/bin/uname -m)" ;;
esac

readonly NODE_ARCHIVE="node-v${NODE_VERSION}-${NODE_PLATFORM}.tar.xz"
readonly NODE_BASE_URL="https://nodejs.org/dist/v${NODE_VERSION}"

/bin/mkdir -p "$SUPPORT_DIR"
if ! /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
  existing_pid="$(/bin/cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [[ -n "$existing_pid" ]] && /bin/kill -0 "$existing_pid" 2>/dev/null; then
    stop_with_error "$(localized "Another runtime installation is already running." "另一个运行环境安装正在进行。")"
  fi
  /bin/rm -rf "$LOCK_DIR"
  /bin/mkdir "$LOCK_DIR" || stop_with_error "$(localized "Could not create the installation lock." "无法创建安装锁。")"
fi
print -r -- "$$" > "$LOCK_DIR/pid"

temporary_dir="$(/usr/bin/mktemp -d "$SUPPORT_DIR/.runtime-install.XXXXXX")"
typeset -i active_child_pid=0
cleanup() {
  if (( active_child_pid > 0 )) && /bin/kill -0 "$active_child_pid" 2>/dev/null; then
    /bin/kill -TERM "$active_child_pid" 2>/dev/null || true
    wait "$active_child_pid" 2>/dev/null || true
  fi
  /bin/rm -rf "$temporary_dir"
  /bin/rm -rf "$LOCK_DIR"
}
abort_install() { exit 130; }
trap cleanup EXIT
trap abort_install INT TERM HUP

run_with_timeout() {
  local timeout_seconds="$1"
  local elapsed=0
  local command_status=0
  shift
  "$@" &
  active_child_pid=$!
  while /bin/kill -0 "$active_child_pid" 2>/dev/null; do
    if (( elapsed >= timeout_seconds )); then
      /bin/kill -TERM "$active_child_pid" 2>/dev/null || true
      wait "$active_child_pid" 2>/dev/null || true
      active_child_pid=0
      return 124
    fi
    /bin/sleep 1
    elapsed=$((elapsed + 1))
  done
  if wait "$active_child_pid"; then command_status=0; else command_status=$?; fi
  active_child_pid=0
  return "$command_status"
}

capture_with_timeout() {
  local timeout_seconds="$1" output_path="$2"
  shift 2
  : > "$output_path"
  run_with_timeout "$timeout_seconds" "$@" > "$output_path" 2>/dev/null
}

version_at_least() {
  local left="${1#v}" right="${2#v}" left_core right_core left_pre right_pre
  local -a left_parts right_parts left_pre_parts right_pre_parts
  local index left_part right_part
  left="${left%%+*}"
  right="${right%%+*}"
  left_core="${left%%-*}"
  right_core="${right%%-*}"
  left_parts=("${(@s:.:)left_core}")
  right_parts=("${(@s:.:)right_core}")
  for index in 1 2 3; do
    left_part="${left_parts[$index]:-0}"
    right_part="${right_parts[$index]:-0}"
    [[ "$left_part" == <-> && "$right_part" == <-> ]] || return 1
    (( left_part > right_part )) && return 0
    (( left_part < right_part )) && return 1
  done

  left_pre="${left#${left_core}}"
  right_pre="${right#${right_core}}"
  left_pre="${left_pre#-}"
  right_pre="${right_pre#-}"
  if [[ -z "$right_pre" ]]; then
    [[ -z "$left_pre" ]]
    return
  fi
  [[ -z "$left_pre" ]] && return 0
  left_pre_parts=("${(@s:.:)left_pre}")
  right_pre_parts=("${(@s:.:)right_pre}")
  for index in {1..12}; do
    (( index > ${#left_pre_parts} && index > ${#right_pre_parts} )) && return 0
    (( index > ${#left_pre_parts} )) && return 1
    (( index > ${#right_pre_parts} )) && return 0
    left_part="${left_pre_parts[$index]}"
    right_part="${right_pre_parts[$index]}"
    if [[ "$left_part" == <-> && "$right_part" == <-> ]]; then
      (( left_part > right_part )) && return 0
      (( left_part < right_part )) && return 1
    elif [[ "$left_part" == <-> ]]; then
      return 1
    elif [[ "$right_part" == <-> ]]; then
      return 0
    else
      [[ "$left_part" > "$right_part" ]] && return 0
      [[ "$left_part" < "$right_part" ]] && return 1
    fi
  done
  return 0
}

typeset -a node_candidates dsh_candidates compatible_node_candidates
node_candidates=()
dsh_candidates=()
compatible_node_candidates=()

append_unique_executable() {
  local kind="$1" candidate="$2" existing
  [[ -n "$candidate" && -x "$candidate" && ! -d "$candidate" ]] || return 0
  if [[ "$kind" == node ]]; then
    for existing in "${node_candidates[@]}"; do [[ "$existing" == "$candidate" ]] && return 0; done
    node_candidates+=("$candidate")
  else
    for existing in "${dsh_candidates[@]}"; do [[ "$existing" == "$candidate" ]] && return 0; done
    dsh_candidates+=("$candidate")
  fi
}

record_value() {
  [[ -f "$ENVIRONMENT_RECORD" ]] || return 0
  /usr/libexec/PlistBuddy -c "Print :$1" "$ENVIRONMENT_RECORD" 2>/dev/null || true
}

recorded_dsh="$(record_value dshPath)"
recorded_node="$(record_value nodePath)"
append_unique_executable dsh "$recorded_dsh"
append_unique_executable node "$recorded_node"

typeset -a search_path_entries
search_path_entries=("${(@s/:/)PATH}")
for candidate_dir in "${search_path_entries[@]}"; do
  [[ -n "$candidate_dir" ]] || continue
  append_unique_executable dsh "$candidate_dir/dsh"
  append_unique_executable node "$candidate_dir/node"
done

for candidate in \
  "$HOME/.local/bin/dsh" "$HOME/.volta/bin/dsh" "$HOME/.asdf/shims/dsh" "$HOME/.mise/shims/dsh" \
  "$HOME/.bun/bin/dsh" "$HOME/Library/pnpm/dsh" "/opt/homebrew/bin/dsh" "/usr/local/bin/dsh" "/opt/local/bin/dsh"; do
  append_unique_executable dsh "$candidate"
done
for candidate in \
  "$HOME/.local/bin/node" "$HOME/.volta/bin/node" "$HOME/.asdf/shims/node" "$HOME/.mise/shims/node" \
  "/opt/homebrew/bin/node" "/usr/local/bin/node" "/opt/local/bin/node"; do
  append_unique_executable node "$candidate"
done

for candidate in \
  "$HOME/.nvm/versions/node/"*/bin/dsh \
  "$HOME/.fnm/node-versions/"*/installation/bin/dsh \
  "$HOME/Library/Application Support/fnm/node-versions/"*/installation/bin/dsh \
  "$HOME/.nodenv/versions/"*/bin/dsh; do
  append_unique_executable dsh "$candidate"
done
for candidate in \
  "$HOME/.nvm/versions/node/"*/bin/node \
  "$HOME/.fnm/node-versions/"*/installation/bin/node \
  "$HOME/Library/Application Support/fnm/node-versions/"*/installation/bin/node \
  "$HOME/.nodenv/versions/"*/bin/node; do
  append_unique_executable node "$candidate"
done

# App-managed paths are fallbacks unless a previous selection record explicitly chose them.
append_unique_executable dsh "$NPM_PREFIX/node_modules/.bin/dsh"
append_unique_executable node "$RUNTIME_DIR/bin/node"

candidate_index=0
for candidate in "${node_candidates[@]}"; do
  candidate_index=$((candidate_index + 1))
  candidate_output="$temporary_dir/node-candidate-${candidate_index}.txt"
  if capture_with_timeout "$DISCOVERY_TIMEOUT" "$candidate_output" "$candidate" --version; then
    candidate_version="$(/usr/bin/tail -n 1 "$candidate_output")"
  else
    continue
  fi
  candidate_major="${candidate_version#v}"
  candidate_major="${candidate_major%%.*}"
  [[ "$candidate_major" == <-> ]] || continue
  (( candidate_major >= MIN_NODE_MAJOR )) || continue
  compatible_node_candidates+=("$candidate")
done

typeset -a runtime_path_entries
runtime_path_entries=()
for candidate in "${compatible_node_candidates[@]}"; do runtime_path_entries+=("${candidate:h}"); done
for candidate in "${dsh_candidates[@]}"; do runtime_path_entries+=("${candidate:h}"); done
runtime_path_entries+=("${search_path_entries[@]}" /usr/bin /bin /usr/sbin /sbin)
typeset -a unique_runtime_path_entries
unique_runtime_path_entries=()
for candidate_dir in "${runtime_path_entries[@]}"; do
  [[ -n "$candidate_dir" ]] || continue
  (( ${unique_runtime_path_entries[(Ie)$candidate_dir]} )) || unique_runtime_path_entries+=("$candidate_dir")
done
readonly DISCOVERY_PATH="${(j/:/)unique_runtime_path_entries}"

write_environment_record() {
  local dsh_path="$1" node_path="$2" dsh_version="$3" source="$4"
  local record_tmp="$temporary_dir/environment.plist" node_version=''
  [[ -n "$node_path" ]] && node_version="$("$node_path" --version 2>/dev/null || true)"
  /usr/bin/plutil -create xml1 "$record_tmp"
  /usr/bin/plutil -insert dshPath -string "$dsh_path" "$record_tmp"
  /usr/bin/plutil -insert dshVersion -string "$dsh_version" "$record_tmp"
  /usr/bin/plutil -insert source -string "$source" "$record_tmp"
  /usr/bin/plutil -insert updatedAt -string "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" "$record_tmp"
  if [[ -n "$node_path" ]]; then
    /usr/bin/plutil -insert nodePath -string "$node_path" "$record_tmp"
    /usr/bin/plutil -insert nodeVersion -string "$node_version" "$record_tmp"
  fi
  /bin/mv "$record_tmp" "$ENVIRONMENT_RECORD" \
    || stop_with_error "$(localized "Could not save the selected runtime environment." "无法保存选定的运行环境。")"
}

if (( REUSE_COMPATIBLE_ENVIRONMENT )); then
  candidate_index=0
  for candidate in "${dsh_candidates[@]}"; do
    candidate_index=$((candidate_index + 1))
    candidate_output="$temporary_dir/dsh-candidate-${candidate_index}.txt"
    if capture_with_timeout "$DISCOVERY_TIMEOUT" "$candidate_output" /usr/bin/env PATH="$DISCOVERY_PATH" "$candidate" --version; then
      candidate_version="$(/usr/bin/tail -n 1 "$candidate_output")"
    else
      continue
    fi
    print -r -- "$candidate_version" | /usr/bin/grep -Eq '^[v]?[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$' || continue
    version_at_least "$candidate_version" "$DSH_VERSION" || continue
    selected_node="${compatible_node_candidates[1]:-}"
    selected_source='external'
    [[ "$candidate" == "$SUPPORT_DIR"/* ]] && selected_source='managed'
    write_environment_record "$candidate" "$selected_node" "${candidate_version#v}" "$selected_source"
    say_note "Reusing the existing compatible DeepSeek Harness ${candidate_version#v}" "复用现有兼容的 DeepSeek Harness ${candidate_version#v}"
    print -r -- "DSH: $candidate"
    [[ -n "$selected_node" ]] && print -r -- "Node.js: $selected_node ($("$selected_node" --version 2>/dev/null || true))"
    print -r -- "$(localized "No existing user runtime was replaced or downloaded." "未替换或下载任何已有用户运行环境。")"
    exit 0
  done
fi

typeset staged_runtime=''
typeset staged_prefix=''
typeset node_for_install=''
typeset npm_for_install=''
typeset -i needs_node=0
typeset -i needs_dsh=0

stage_node_runtime() {
  local archive_path="$temporary_dir/$NODE_ARCHIVE"
  local shasums_path="$temporary_dir/SHASUMS256.txt"
  local expected actual extracted_dir

  say_note "Downloading verified Node.js ${NODE_VERSION}" "下载受校验的 Node.js ${NODE_VERSION} 运行时"
  /usr/bin/curl --fail --location --silent --show-error --connect-timeout 15 --max-time 120 \
    "$NODE_BASE_URL/SHASUMS256.txt" -o "$shasums_path" \
    || stop_with_error "$(localized "Could not download the Node.js checksum file." "无法下载 Node.js 校验文件。")"
  expected="$(/usr/bin/awk -v file="$NODE_ARCHIVE" '$2 == file {print $1}' "$shasums_path")"
  [[ -n "$expected" ]] || stop_with_error "$(localized "The checksum list does not contain $NODE_ARCHIVE." "Node.js 校验文件中缺少 $NODE_ARCHIVE。")"
  /usr/bin/curl --fail --location --silent --show-error --connect-timeout 15 --max-time 180 \
    "$NODE_BASE_URL/$NODE_ARCHIVE" -o "$archive_path" \
    || stop_with_error "$(localized "Could not download Node.js." "无法下载 Node.js 运行时。")"
  actual="$(/usr/bin/shasum -a 256 "$archive_path" | /usr/bin/awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || stop_with_error "$(localized "The Node.js checksum did not match. The download was not used." "Node.js 下载校验失败，未使用该文件。")"
  /usr/bin/tar -xJf "$archive_path" -C "$temporary_dir" \
    || stop_with_error "$(localized "Could not extract Node.js." "无法解压 Node.js 运行时。")"
  extracted_dir="$temporary_dir/node-v${NODE_VERSION}-${NODE_PLATFORM}"
  [[ -x "$extracted_dir/bin/node" && -x "$extracted_dir/bin/npm" ]] \
    || stop_with_error "$(localized "The Node.js runtime is incomplete." "Node.js 运行时内容不完整。")"
  [[ "$("$extracted_dir/bin/node" --version)" == "v${NODE_VERSION}" ]] \
    || stop_with_error "$(localized "Node.js version verification failed." "Node.js 版本校验失败。")"

  staged_runtime="$temporary_dir/runtime-stage"
  /bin/mv "$extracted_dir" "$staged_runtime"
}

for candidate in "${compatible_node_candidates[@]}"; do
  candidate_npm="${candidate:h}/npm"
  [[ -x "$candidate_npm" ]] || continue
  candidate_output="$temporary_dir/npm-candidate.txt"
  capture_with_timeout "$DISCOVERY_TIMEOUT" "$candidate_output" /usr/bin/env PATH="${candidate:h}:$DISCOVERY_PATH" "$candidate_npm" --version \
    || continue
  node_for_install="$candidate"
  npm_for_install="$candidate_npm"
  break
done

if [[ -n "$node_for_install" ]]; then
  say_note "Reusing compatible Node.js $("$node_for_install" --version)" "复用兼容的 Node.js $("$node_for_install" --version)"
  print -r -- "Node.js: $node_for_install"
else
  needs_node=1
  stage_node_runtime
  node_for_install="$staged_runtime/bin/node"
  npm_for_install="$staged_runtime/bin/npm"
fi

readonly DSH_BIN="$NPM_PREFIX/node_modules/.bin/dsh"
installed_dsh_version="$(PATH="${node_for_install:h}:$DISCOVERY_PATH" "$DSH_BIN" --version 2>/dev/null | /usr/bin/tail -n 1 || true)"
if [[ "$installed_dsh_version" == "$DSH_VERSION" ]]; then
  say_note "Reusing app-managed DeepSeek Harness CLI ${DSH_VERSION}" "复用应用托管的 DeepSeek Harness CLI ${DSH_VERSION}"
else
  needs_dsh=1
  say_note "Installing app-managed DeepSeek Harness CLI ${DSH_VERSION}" "安装应用托管的 DeepSeek Harness CLI ${DSH_VERSION}"
  print -r -- "$(localized "Node.js installation heap limit: ${NPM_INSTALL_HEAP_MB} MB" "Node.js 安装堆内存上限：${NPM_INSTALL_HEAP_MB} MB")"
  staged_prefix="$temporary_dir/npm-stage"
  /bin/mkdir -p "$staged_prefix"
  if run_with_timeout 720 /usr/bin/env PATH="${node_for_install:h}:$DISCOVERY_PATH" \
      NODE_OPTIONS="--max-old-space-size=${NPM_INSTALL_HEAP_MB}" "$npm_for_install" \
      --prefix "$staged_prefix" install --no-audit --no-fund --save-exact \
      --registry=https://registry.npmjs.org/ \
      --fetch-timeout=60000 --fetch-retries=2 --fetch-retry-mintimeout=5000 --fetch-retry-maxtimeout=15000 \
      "@deepseek-ai/dsh@${DSH_VERSION}"; then
    :
  else
    npm_status=$?
    if (( npm_status == 124 )); then
      stop_with_error "$(localized "The DSH download timed out after 12 minutes. Check the network and retry." "DSH 下载等待超过 12 分钟。请检查网络后重试。")"
    fi
    stop_with_error "$(localized "Could not install the DeepSeek Harness CLI." "无法安装 DeepSeek Harness CLI。")"
  fi
  staged_dsh="$staged_prefix/node_modules/.bin/dsh"
  [[ -x "$staged_dsh" ]] || stop_with_error "$(localized "The DeepSeek Harness CLI installation is incomplete." "DeepSeek Harness CLI 安装不完整。")"
  staged_version="$(PATH="${node_for_install:h}:$DISCOVERY_PATH" "$staged_dsh" --version 2>/dev/null | /usr/bin/tail -n 1 || true)"
  [[ "$staged_version" == "$DSH_VERSION" ]] \
    || stop_with_error "$(localized "DeepSeek Harness CLI version verification failed." "DeepSeek Harness CLI 版本校验失败。")"
fi

readonly runtime_backup="$SUPPORT_DIR/runtime/.previous-$$"
readonly npm_backup="$SUPPORT_DIR/.npm-previous-$$"
typeset -i moved_runtime_backup=0
typeset -i moved_npm_backup=0
typeset -i activated_runtime=0
typeset -i activated_npm=0

rollback_activation() {
  if (( activated_npm )); then /bin/rm -rf "$NPM_PREFIX"; fi
  if (( moved_npm_backup )) && [[ -e "$npm_backup" ]]; then /bin/mv "$npm_backup" "$NPM_PREFIX"; fi
  if (( activated_runtime )); then /bin/rm -rf "$RUNTIME_DIR"; fi
  if (( moved_runtime_backup )) && [[ -e "$runtime_backup" ]]; then /bin/mv "$runtime_backup" "$RUNTIME_DIR"; fi
}

/bin/mkdir -p "${RUNTIME_DIR:h}"
/bin/rm -rf "$runtime_backup" "$npm_backup"

if (( needs_node )); then
  if [[ -e "$RUNTIME_DIR" ]]; then
    /bin/mv "$RUNTIME_DIR" "$runtime_backup" \
      || stop_with_error "$(localized "Could not stage the current Node.js runtime for replacement." "无法暂存当前 Node.js 运行时以进行替换。")"
    moved_runtime_backup=1
  fi
  if ! /bin/mv "$staged_runtime" "$RUNTIME_DIR"; then
    rollback_activation
    stop_with_error "$(localized "Could not activate the Node.js runtime." "无法启用 Node.js 运行时。")"
  fi
  activated_runtime=1
  node_for_install="$RUNTIME_DIR/bin/node"
fi

if (( needs_dsh )); then
  if [[ -e "$NPM_PREFIX" ]]; then
    if ! /bin/mv "$NPM_PREFIX" "$npm_backup"; then
      rollback_activation
      stop_with_error "$(localized "Could not stage the current DeepSeek Harness CLI for replacement." "无法暂存当前 DeepSeek Harness CLI 以进行替换。")"
    fi
    moved_npm_backup=1
  fi
  if ! /bin/mv "$staged_prefix" "$NPM_PREFIX"; then
    rollback_activation
    stop_with_error "$(localized "Could not activate the DeepSeek Harness CLI." "无法启用 DeepSeek Harness CLI。")"
  fi
  activated_npm=1
fi

active_node_version="$("$node_for_install" --version 2>/dev/null || true)"
active_dsh_version="$(PATH="${node_for_install:h}:$DISCOVERY_PATH" "$DSH_BIN" --version 2>/dev/null | /usr/bin/tail -n 1 || true)"
if [[ "${active_node_version#v}" != <->.<->.<-> || "$active_dsh_version" != "$DSH_VERSION" ]]; then
  rollback_activation
  stop_with_error "$(localized "The activated runtime did not pass final verification. The previous managed runtime was restored." "启用后的运行环境未通过最终校验，已恢复此前的托管运行环境。")"
fi
active_node_major="${active_node_version#v}"
active_node_major="${active_node_major%%.*}"
if (( active_node_major < MIN_NODE_MAJOR )); then
  rollback_activation
  stop_with_error "$(localized "The selected Node.js version is no longer supported. The previous managed runtime was restored." "选定的 Node.js 版本已不受支持，已恢复此前的托管运行环境。")"
fi

write_environment_record "$DSH_BIN" "$node_for_install" "$active_dsh_version" managed
/bin/rm -rf "$runtime_backup" "$npm_backup"

print
print -r -- "$(localized "Runtime setup completed." "运行环境配置完成。")"
print -r -- "Node.js: $active_node_version ($node_for_install)"
print -r -- "DeepSeek Harness: $active_dsh_version ($DSH_BIN)"
