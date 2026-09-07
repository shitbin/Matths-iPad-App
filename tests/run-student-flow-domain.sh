#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-student-flow.XXXXXX)
swiftc "$root/Matths/StudentFlowDomain.swift" "$root/Matths/FirstLearningJourneyPersistence.swift" \
  "$root/Matths/FirstLearningJourneyStore.swift" "$root/Matths/DataScope.swift" \
  "$root/tests/StudentFlowDomainCases.swift" -o "$scratch/cases"
"$scratch/cases"
