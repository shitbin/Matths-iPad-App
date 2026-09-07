#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-completion-signal.XXXXXX)
swiftc -swift-version 6 "$root/Matths/AsyncCompletionSignal.swift" "$root/tests/AsyncCompletionSignalCases.swift" -o "$scratch/cases"
"$scratch/cases"
