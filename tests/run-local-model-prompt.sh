#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary="${TMPDIR:-/tmp}/matths-local-model-prompt-cases"
xcrun swiftc \
  "$root/Matths/LocalModelPrompt.swift" \
  "$root/tests/LocalModelPromptCases.swift" \
  -o "$binary"
"$binary"
