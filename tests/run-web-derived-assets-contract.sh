#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
node "$root/tools/verify-web-derived-assets.mjs" "${MATTHS_WEB_REPO:?Exact Web checkout required}"
