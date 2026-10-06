#!/usr/bin/env bash
set -euo pipefail

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
uuid='touch-guard@marcus-friction.github.io'
source_dir="$project_dir/$uuid"
dist_dir="$project_dir/dist"
archive="$dist_dir/$uuid.shell-extension.zip"

"$project_dir/check.sh"
for command_name in glib-compile-schemas zip sha256sum unzip; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Missing required build command: %s\n' "$command_name" >&2
        exit 1
    }
done

mkdir -p "$dist_dir"
stage=$(mktemp -d "${TMPDIR:-/tmp}/touch-guard-build.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
cp "$source_dir/metadata.json" "$source_dir/extension.js" \
    "$source_dir/controller.js" "$source_dir/helper.py" \
    "$source_dir/org.marcusfriction.touchguard.policy" \
    "$source_dir/LICENSE" "$stage/"
mkdir "$stage/schemas"
cp "$source_dir/schemas/"*.gschema.xml "$stage/schemas/"
glib-compile-schemas --strict "$stage/schemas"

rm -f "$archive" "$archive.sha256"
(
    cd "$stage"
    zip -q -r "$archive" .
)
unzip -t "$archive" >/dev/null
(
    cd "$dist_dir"
    sha256sum "$(basename "$archive")" >"$(basename "$archive.sha256")"
)
printf 'Validated and built:\n  %s\n  %s\n' "$archive" "$archive.sha256"
