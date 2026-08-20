#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
"$root/tests/backend-test.sh"
node "$root/tests/model-test.js"
bash -n "$root/scripts/signal-api" "$root/scripts/signal-setup"
omarchy plugin validate "$root"
printf 'all tests passed\n'
