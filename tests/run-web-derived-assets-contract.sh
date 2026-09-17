#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
# Generated assets attest a pinned historical source, while API/behavior tests
# use the latest server checkout. Keep both strict checks with separate inputs.
asset_web_root=${MATTHS_WEB_ASSET_REPO:-${MATTHS_WEB_REPO:-}}
: "${asset_web_root:?Exact clean Web asset checkout required}"
node "$root/tools/verify-web-derived-assets.mjs" "$asset_web_root"
