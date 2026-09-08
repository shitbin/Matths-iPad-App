#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-browse-history.XXXXXX)
swiftc "$root/Matths/BrowseNavigationHistory.swift" "$root/tests/BrowseNavigationHistoryCases.swift" -o "$scratch/cases"
"$scratch/cases"
