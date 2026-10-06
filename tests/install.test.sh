#!/usr/bin/env bash
set -euo pipefail

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/touch-guard-installer-test.XXXXXX")
mock_bin="$test_dir/bin"
mock_log="$test_dir/mock.log"
installed_extension_dir="$test_dir/data/gnome-shell/extensions"
installed_extension_dir="$installed_extension_dir/"\
"touch-guard@marcus-friction.github.io"
mkdir -p "$mock_bin"
trap 'rm -rf -- "$test_dir"' EXIT

write_mocks() {
    cat >"$mock_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
output=''
url=''
while [[ $# -gt 0 ]]; do
    if [[ "$1" == '--output' ]]; then
        output=$2
        shift 2
    else
        url=$1
        shift
    fi
done
printf 'curl %s\n' "$url" >>"$MOCK_LOG"
if [[ "$url" == *'/releases?per_page=10' ]]; then
    printf '%s\n' '[{"tag_name":"v0.1.0-alpha.1","draft":false}]' >"$output"
else
    : >"$output"
fi
EOF

    cat >"$mock_bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    cat >"$mock_bin/unzip" <<'EOF'
#!/usr/bin/env bash
set -eu
printf 'unzip %s\n' "$*" >>"$MOCK_LOG"
printf 'mock content\n'
EOF

    cat >"$mock_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -eu
printf 'sudo %s\n' "$*" >>"$MOCK_LOG"
EOF

    cat >"$mock_bin/gnome-extensions" <<'EOF'
#!/usr/bin/env bash
set -eu
printf 'gnome-extensions %s\n' "$*" >>"$MOCK_LOG"
if [[ "$1" == 'info' && "$MOCK_INSTALLED_RESULT" == 'failure' ]]; then
    exit 1
fi
if [[ "$1" == 'enable' && "$MOCK_ENABLE_RESULT" == 'failure' ]]; then
    printf 'Extension does not exist\n' >&2
    exit 1
fi
EOF

    cat >"$mock_bin/gsettings" <<'EOF'
#!/usr/bin/env bash
set -eu
printf 'gsettings %s\n' "$*" >>"$MOCK_LOG"
if [[ "$1" == 'get' && "$3" == 'enabled-extensions' ]]; then
    printf '%s\n' "$MOCK_ENABLED_EXTENSIONS"
elif [[ "$1" == 'get' && "$3" == 'disabled-extensions' ]]; then
    printf '%s\n' "$MOCK_DISABLED_EXTENSIONS"
elif [[ "$1" == 'set' && "$MOCK_GSETTINGS_RESULT" == 'failure' ]]; then
    exit 1
fi
EOF

    chmod +x "$mock_bin/curl" "$mock_bin/sha256sum" \
        "$mock_bin/gnome-extensions" "$mock_bin/gsettings" \
        "$mock_bin/unzip" "$mock_bin/sudo"
}

assert_contains() {
    local haystack=$1 needle=$2
    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'Expected output to contain: %s\nActual output:\n%s\n' \
            "$needle" "$haystack" >&2
        exit 1
    fi
}

run_installer() {
    : >"$mock_log"
    PATH="$mock_bin:$PATH" \
        MOCK_LOG="$mock_log" \
        MOCK_ENABLE_RESULT="$1" \
        MOCK_GSETTINGS_RESULT="$2" \
        MOCK_ENABLED_EXTENSIONS="$3" \
        MOCK_DISABLED_EXTENSIONS="$4" \
        MOCK_INSTALLED_RESULT="$5" \
        XDG_DATA_HOME="$test_dir/data" \
        bash "$project_dir/install.sh" 2>&1
}

write_mocks

output=$(run_installer success success '@as []' '@as []' failure)
assert_contains "$output" 'Touch Guard is installed and enabled.'
assert_contains "$(<"$mock_log")" \
    'releases/download/v0.1.0-alpha.1/touch-guard@marcus-friction.github.io.shell-extension.zip'
assert_contains "$(<"$mock_log")" \
    'sudo install -D -m 0755'
if grep -Fq 'gsettings' "$mock_log"; then
    printf 'Immediate enablement should not modify GNOME settings.\n' >&2
    exit 1
fi

output=$(run_installer failure success \
    "['existing@example.org']" \
    "['touch-guard@marcus-friction.github.io', 'blocked@example.org']" \
    failure)
assert_contains "$output" 'Log out and back in once; it will enable automatically.'
assert_contains "$(<"$mock_log")" \
    "gsettings set org.gnome.shell disabled-extensions ['blocked@example.org']"
assert_contains "$(<"$mock_log")" \
    "gsettings set org.gnome.shell enabled-extensions ['existing@example.org', 'touch-guard@marcus-friction.github.io']"

output=$(run_installer failure failure '@as []' '@as []' failure)
assert_contains "$output" 'Extension does not exist'
assert_contains "$output" 'Log out and back in, then run:'
assert_contains "$output" \
    'gnome-extensions enable touch-guard@marcus-friction.github.io'

mkdir -p "$installed_extension_dir"
output=$(run_installer success success '@as []' '@as []' failure)
assert_contains "$output" 'Updating the existing extension...'
assert_contains "$output" 'Touch Guard update is installed and enabled.'
assert_contains "$output" \
    'Log out and back in once to load the updated extension code.'

printf 'Installer tests passed.\n'
