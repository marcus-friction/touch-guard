#!/usr/bin/env bash
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
archive="$project_dir/dist/touch-guard@marcus-friction.github.io.shell-extension.zip"

if ! command -v gnome-shell-test-tool >/dev/null 2>&1; then
    printf 'Missing required test command: gnome-shell-test-tool\n' >&2
    exit 1
fi

if [ ! -f "$archive" ]; then
    "$project_dir/build.sh"
fi

test_runtime_dir=$(mktemp -d /tmp/touch-guard-shell-test.XXXXXX)
trap 'rm -rf -- "$test_runtime_dir"' EXIT
chmod 0700 "$test_runtime_dir"
mkdir -p "$test_runtime_dir/cache" \
    "$test_runtime_dir/config" \
    "$test_runtime_dir/data"

XDG_RUNTIME_DIR="$test_runtime_dir" \
XDG_CACHE_HOME="$test_runtime_dir/cache" \
XDG_CONFIG_HOME="$test_runtime_dir/config" \
XDG_DATA_HOME="$test_runtime_dir/data" \
XAUTHORITY="$test_runtime_dir/Xauthority" \
dbus-run-session -- \
    gnome-shell-test-tool --headless --extension "$archive" \
        "$project_dir/tests/extension-smoke.js"
