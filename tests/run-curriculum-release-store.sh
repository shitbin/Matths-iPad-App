#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/matths-course-release.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
# Compile the real ObservableObject Store, with only its network adapter replaced
# by a controlled boundary. No product state/merge behavior is copied into tests.
sed '/^extension ServerAPI/,$d' "$root/Matths/CurriculumAvailabilityStore.swift" > "$scratch/ProductionStore.swift"
swiftc "$root/Matths/CurriculumAvailability.swift" "$scratch/ProductionStore.swift" \
  "$root/tests/CurriculumReleaseStoreCases.swift" -o "$scratch/cases"
"$scratch/cases"
node "$root/scripts/verifyCurriculumStoryBundle.js" "$root/Matths"
