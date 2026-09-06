#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-parity-cases.XXXXXX)
swiftc "$root/Matths/CurriculumAvailability.swift" "$root/Matths/CanonicalLearning.swift" \
  "$root/Matths/PasswordChangeValidation.swift" "$root/tests/CurriculumParityCases.swift" -o "$scratch/cases"
"$scratch/cases" "$root/tests/fixtures/web-learning-parity.json"
