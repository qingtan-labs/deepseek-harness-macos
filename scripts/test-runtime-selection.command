#!/bin/zsh

set -euo pipefail
IFS=$'\n\t'

readonly ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly INSTALLER="$ROOT_DIR/scripts/install-runtime.command"
readonly TEST_ROOT="$(/usr/bin/mktemp -d /private/tmp/deepseek-harness-runtime-tests.XXXXXX)"

cleanup() { /bin/rm -rf "$TEST_ROOT"; }
trap cleanup EXIT INT TERM HUP

make_node_and_npm() {
  local bin_dir="$1" node_version="$2"
  /bin/mkdir -p "$bin_dir"
  /usr/bin/printf '#!/bin/zsh\n[[ "${1:-}" == "--version" ]] && { print -r -- "%s"; exit 0; }\nexit 0\n' \
    "$node_version" > "$bin_dir/node"
  /usr/bin/printf '%s\n' \
    '#!/bin/zsh' \
    'set -euo pipefail' \
    'if [[ "${1:-}" == "--version" ]]; then print -r -- "10.0.0"; exit 0; fi' \
    'typeset prefix=""' \
    'while (( $# > 0 )); do' \
    '  if [[ "$1" == "--prefix" ]]; then shift; prefix="$1"; break; fi' \
    '  shift' \
    'done' \
    '[[ -n "$prefix" ]] || exit 2' \
    '[[ "${NODE_OPTIONS:-}" == --max-old-space-size=<-> ]] || exit 3' \
    '/usr/bin/printf "%s\n" "$NODE_OPTIONS" > "$prefix/npm-heap.txt"' \
    '/bin/mkdir -p "$prefix/node_modules/.bin"' \
    '/usr/bin/printf '\''#!/bin/zsh\nprint -r -- "0.1.1-rc.2"\n'\'' > "$prefix/node_modules/.bin/dsh"' \
    '/bin/chmod 755 "$prefix/node_modules/.bin/dsh"' > "$bin_dir/npm"
  /bin/chmod 755 "$bin_dir/node" "$bin_dir/npm"
}

make_dsh() {
  local path="$1" version="$2"
  /bin/mkdir -p "${path:h}"
  /usr/bin/printf '#!/bin/zsh\nprint -r -- "%s"\n' "$version" > "$path"
  /bin/chmod 755 "$path"
}

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1"; }

scenario_reuses_compatible_dsh() {
  local scenario="$TEST_ROOT/reuse-dsh"
  local home="$scenario/home" bin_dir="$scenario/bin" support="$scenario/support"
  /bin/mkdir -p "$home"
  make_node_and_npm "$bin_dir" v22.14.0
  make_dsh "$bin_dir/dsh" 0.1.1-rc.3
  HOME="$home" PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin" DEEPSEEK_HARNESS_SUPPORT_DIR="$support" \
    DEEPSEEK_HARNESS_LANGUAGE=en "$INSTALLER" >/dev/null
  [[ "$(plist_value "$support/environment.plist" dshPath)" == "$bin_dir/dsh" ]]
  [[ "$(plist_value "$support/environment.plist" source)" == external ]]
  [[ ! -e "$support/runtime/current/bin/node" && ! -e "$support/npm/node_modules/.bin/dsh" ]]
}

scenario_reuses_node_and_installs_only_dsh() {
  local scenario="$TEST_ROOT/reuse-node"
  local home="$scenario/home" bin_dir="$scenario/bin" support="$scenario/support"
  /bin/mkdir -p "$home"
  make_node_and_npm "$bin_dir" v20.19.6
  HOME="$home" PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin" DEEPSEEK_HARNESS_SUPPORT_DIR="$support" \
    DEEPSEEK_HARNESS_LANGUAGE=en DEEPSEEK_HARNESS_NPM_HEAP_MB=4096 "$INSTALLER" >/dev/null
  [[ "$(plist_value "$support/environment.plist" nodePath)" == "$bin_dir/node" ]]
  [[ "$(plist_value "$support/environment.plist" source)" == managed ]]
  [[ -x "$support/npm/node_modules/.bin/dsh" ]]
  [[ "$(/bin/cat "$support/npm/npm-heap.txt")" == '--max-old-space-size=4096' ]]
  [[ ! -e "$support/runtime/current/bin/node" ]]
}

scenario_preserves_old_external_dsh() {
  local scenario="$TEST_ROOT/old-dsh"
  local home="$scenario/home" bin_dir="$scenario/bin" support="$scenario/support"
  local before after
  /bin/mkdir -p "$home"
  make_node_and_npm "$bin_dir" v22.14.0
  make_dsh "$bin_dir/dsh" 0.1.0
  before="$(/usr/bin/shasum -a 256 "$bin_dir/dsh" | /usr/bin/awk '{print $1}')"
  HOME="$home" PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin" DEEPSEEK_HARNESS_SUPPORT_DIR="$support" \
    DEEPSEEK_HARNESS_LANGUAGE=en "$INSTALLER" >/dev/null
  after="$(/usr/bin/shasum -a 256 "$bin_dir/dsh" | /usr/bin/awk '{print $1}')"
  [[ "$before" == "$after" ]]
  [[ "$(plist_value "$support/environment.plist" dshPath)" == "$support/npm/node_modules/.bin/dsh" ]]
  [[ ! -e "$support/runtime/current/bin/node" ]]
}

scenario_skips_a_hanging_recorded_dsh() {
  local scenario="$TEST_ROOT/hanging-dsh"
  local home="$scenario/home" bin_dir="$scenario/bin" support="$scenario/support" hanging="$scenario/hanging-dsh"
  /bin/mkdir -p "$home/.local/bin" "$support"
  make_node_and_npm "$bin_dir" v22.14.0
  /usr/bin/printf '%s\n' '#!/bin/zsh' '/bin/sleep 30' > "$hanging"
  /bin/chmod 755 "$hanging"
  make_dsh "$home/.local/bin/dsh" 0.1.1
  /usr/bin/plutil -create xml1 "$support/environment.plist"
  /usr/bin/plutil -insert dshPath -string "$hanging" "$support/environment.plist"
  HOME="$home" PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin" DEEPSEEK_HARNESS_SUPPORT_DIR="$support" \
    DEEPSEEK_HARNESS_LANGUAGE=en DEEPSEEK_HARNESS_DISCOVERY_TIMEOUT=1 "$INSTALLER" >/dev/null
  [[ "$(plist_value "$support/environment.plist" dshPath)" == "$home/.local/bin/dsh" ]]
}

scenario_explicit_update_switches_to_managed_dsh() {
  local scenario="$TEST_ROOT/explicit-update"
  local home="$scenario/home" bin_dir="$scenario/bin" support="$scenario/support"
  local before after
  /bin/mkdir -p "$home"
  make_node_and_npm "$bin_dir" v22.14.0
  make_dsh "$bin_dir/dsh" 0.1.1
  before="$(/usr/bin/shasum -a 256 "$bin_dir/dsh" | /usr/bin/awk '{print $1}')"
  HOME="$home" PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin" DEEPSEEK_HARNESS_SUPPORT_DIR="$support" \
    DEEPSEEK_HARNESS_LANGUAGE=en DEEPSEEK_HARNESS_REUSE_COMPATIBLE_ENVIRONMENT=0 "$INSTALLER" >/dev/null
  after="$(/usr/bin/shasum -a 256 "$bin_dir/dsh" | /usr/bin/awk '{print $1}')"
  [[ "$before" == "$after" ]]
  [[ "$(plist_value "$support/environment.plist" dshPath)" == "$support/npm/node_modules/.bin/dsh" ]]
  [[ "$(plist_value "$support/environment.plist" nodePath)" == "$bin_dir/node" ]]
}

scenario_reuses_compatible_dsh
scenario_reuses_node_and_installs_only_dsh
scenario_preserves_old_external_dsh
scenario_skips_a_hanging_recorded_dsh
scenario_explicit_update_switches_to_managed_dsh

print -r -- 'Runtime selection tests passed.'
