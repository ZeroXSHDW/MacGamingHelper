#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
bin="$root/dist/Mac Gaming Helper.app/Contents/MacOS/MacGamingHelper"
if [[ ! -x "$bin" ]]; then
  "$root/scripts/build.sh"
fi
exec "$bin" --self-test
