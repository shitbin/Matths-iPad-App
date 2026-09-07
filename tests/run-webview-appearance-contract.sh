#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
node "$root/tests/WebViewAppearanceCases.mjs" "$root"
