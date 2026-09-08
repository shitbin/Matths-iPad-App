#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-today-dashboard.XXXXXX)
swiftc "$root/Matths/StudentFlowDomain.swift" "$root/Matths/TodayDashboardPolicy.swift" \
  "$root/tests/TodayDashboardPolicyCases.swift" -o "$scratch/cases"
"$scratch/cases"
