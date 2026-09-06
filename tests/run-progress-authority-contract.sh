#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-progress-authority.XXXXXX)
swiftc "$root/Matths/CurriculumV2.swift" "$root/Matths/CurriculumAvailability.swift" \
  "$root/Matths/CanonicalLearning.swift" "$root/Matths/CurriculumStore.swift" "$root/Matths/DataScope.swift" \
  "$root/tests/ProgressAuthorityCases.swift" -o "$scratch/cases"
"$scratch/cases"
