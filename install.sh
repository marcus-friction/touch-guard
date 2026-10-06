#!/usr/bin/env bash
set -euo pipefail

readonly repository='marcus-friction/touch-guard'
readonly uuid='touch-guard@marcus-friction.github.io'
readonly archive_name="$uuid.shell-extension.zip"
readonly checksum_name="$archive_name.sha256"
readonly user_data_dir="${XDG_DATA_HOME:-${HOME:?}/.local/share}"
readonly extension_dir="$user_data_dir/gnome-shell/extensions/$uuid"
readonly helper_path='/usr/local/libexec/touch-guard-helper'
readonly policy_path='/usr/share/polkit-1/actions/org.marcusfriction.touchguard.policy'

fail() {
    printf 'Touch Guard installer: %s\n' "$1" >&2
    exit 1
}

enable_on_next_login() {
    local disabled_extensions enabled_extensions entry
    local original_disabled_extensions original_enabled_extensions

    command -v gsettings >/dev/null 2>&1 || return 1

    enabled_extensions=$(gsettings get org.gnome.shell enabled-extensions) || return 1
    disabled_extensions=$(gsettings get org.gnome.shell disabled-extensions) || return 1

    [[ "$enabled_extensions" == '@as []' ]] && enabled_extensions='[]'
    [[ "$disabled_extensions" == '@as []' ]] && disabled_extensions='[]'
    [[ "$enabled_extensions" == \[*\] ]] || return 1
    [[ "$disabled_extensions" == \[*\] ]] || return 1

    original_enabled_extensions=$enabled_extensions
    original_disabled_extensions=$disabled_extensions

    entry="'$uuid'"

    if [[ "$disabled_extensions" == *"$entry"* ]]; then
        disabled_extensions=${disabled_extensions//$entry, /}
        disabled_extensions=${disabled_extensions//, $entry/}
        disabled_extensions=${disabled_extensions//$entry/}
    fi

    if [[ "$enabled_extensions" != *"$entry"* ]]; then
        if [[ "$enabled_extensions" == '[]' ]]; then
            enabled_extensions="[$entry]"
        else
            enabled_extensions="${enabled_extensions%]}, $entry]"
        fi
    fi

    if [[ "$disabled_extensions" != "$original_disabled_extensions" ]]; then
        gsettings set org.gnome.shell disabled-extensions "$disabled_extensions" || return 1
    fi
    if [[ "$enabled_extensions" != "$original_enabled_extensions" ]]; then
        gsettings set org.gnome.shell enabled-extensions "$enabled_extensions" || return 1
    fi
}

for command_name in curl gnome-extensions mktemp python3 sha256sum sudo unzip; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        fail "missing required command: $command_name"
    fi
done

is_update=false
if [[ -d "$extension_dir" ]] ||
    gnome-extensions info "$uuid" >/dev/null 2>&1; then
    is_update=true
fi

temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/touch-guard-install.XXXXXX")
trap 'rm -rf -- "$temporary_dir"' EXIT

release_tag=${TOUCH_GUARD_VERSION:-}
if [[ -z "$release_tag" ]]; then
    curl --fail --location --retry 3 --show-error --silent \
        --output "$temporary_dir/releases.json" \
        "https://api.github.com/repos/$repository/releases?per_page=10"
    release_tag=$(python3 - "$temporary_dir/releases.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as release_file:
    releases = json.load(release_file)
print(next((release['tag_name'] for release in releases
            if not release['draft']), ''))
PY
    )
fi
[[ "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]] ||
    fail 'no valid GitHub release was found'
release_url="https://github.com/$repository/releases/download/$release_tag"

printf 'Downloading Touch Guard %s...\n' "$release_tag"
curl --fail --location --retry 3 --show-error --silent \
    --output "$temporary_dir/$archive_name" \
    "$release_url/$archive_name"
curl --fail --location --retry 3 --show-error --silent \
    --output "$temporary_dir/$checksum_name" \
    "$release_url/$checksum_name"

printf 'Verifying the release checksum...\n'
(
    cd "$temporary_dir"
    sha256sum --check "$checksum_name"
) || fail 'release checksum verification failed'

unzip -p "$temporary_dir/$archive_name" helper.py \
    >"$temporary_dir/helper.py" || fail 'release lacks helper.py'
unzip -p "$temporary_dir/$archive_name" \
    org.marcusfriction.touchguard.policy \
    >"$temporary_dir/org.marcusfriction.touchguard.policy" ||
    fail 'release lacks the polkit policy'

printf 'Installing the device helper (administrator access required)...\n'
sudo install -D -m 0755 "$temporary_dir/helper.py" "$helper_path"
sudo install -D -m 0644 \
    "$temporary_dir/org.marcusfriction.touchguard.policy" "$policy_path"

if [[ "$is_update" == true ]]; then
    printf 'Updating the existing extension...\n'
else
    printf 'Installing the extension...\n'
fi
gnome-extensions install --force "$temporary_dir/$archive_name"

enable_error=''
if enable_error=$(gnome-extensions enable "$uuid" 2>&1); then
    if [[ "$is_update" == true ]]; then
        printf '%s\n' \
            'Touch Guard update is installed and enabled.' \
            'Log out and back in once to load the updated extension code.'
    else
        printf 'Touch Guard is installed and enabled.\n'
    fi
elif enable_on_next_login; then
    if [[ "$is_update" == true ]]; then
        printf '%s\n' \
            'Touch Guard update is installed and scheduled to be enabled.' \
            'Log out and back in once; the updated code will load automatically.'
    else
        printf '%s\n' \
            'Touch Guard is installed and scheduled to be enabled.' \
            'Log out and back in once; it will enable automatically.'
    fi
else
    [[ -z "$enable_error" ]] || printf '%s\n' "$enable_error" >&2
    if [[ "$is_update" == true ]]; then
        printf '%s\n' \
            'Touch Guard update is installed but could not be enabled.' \
            'Log out and back in, then run:' \
            "  gnome-extensions enable $uuid" >&2
    else
        printf '%s\n' \
            'Touch Guard is installed but could not be enabled in this session.' \
            'Log out and back in, then run:' \
            "  gnome-extensions enable $uuid" >&2
    fi
fi
