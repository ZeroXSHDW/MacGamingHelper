#!/usr/bin/env bash
# Lightweight repository hygiene checks for MacGamingHelper.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== required files =="
test -f README.md
if [[ ! -f LICENSE && ! -f LICENSE.md && ! -f COPYING ]]; then
  echo "(no LICENSE file — noted)"
fi

echo "== shell syntax =="
mapfile -t sh_files < <(find . -type f -name '*.sh' ! -path './.git/*' | sort)
if ((${#sh_files[@]})); then
  for f in "${sh_files[@]}"; do
    echo "bash -n $f"
    bash -n "$f"
  done
else
  echo "(no .sh files)"
fi

echo "== python compile =="
mapfile -t py_files < <(find . -type f -name '*.py' ! -path './.git/*' ! -path '*/.venv/*' ! -path '*/venv/*' | sort)
if ((${#py_files[@]})); then
  python3 -m py_compile "${py_files[@]}"
  echo "compiled ${#py_files[@]} python files"
else
  echo "(no .py files)"
fi

echo "== README relative links =="
python3 scripts/ci-check-readme-links.py

echo "== validate OK =="
