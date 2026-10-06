#!/usr/bin/env bash
set -euo pipefail

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
source_dir="$project_dir/touch-guard@marcus-friction.github.io"

bash -n "$project_dir/install.sh" "$project_dir/uninstall.sh"
bash "$project_dir/tests/install.test.sh"
node --check "$source_dir/extension.js"
node --check "$source_dir/controller.js"
node "$project_dir/tests/controller.test.js"
python3 - "$source_dir/helper.py" <<'PY'
import ast
import sys
with open(sys.argv[1], encoding='utf-8') as source:
    ast.parse(source.read(), filename=sys.argv[1])
PY
python3 -m unittest discover -s "$project_dir/tests" -p 'test_*.py'
glib-compile-schemas --strict --dry-run "$source_dir/schemas"
