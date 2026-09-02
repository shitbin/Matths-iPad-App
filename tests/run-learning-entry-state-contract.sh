#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

grep -Fq 'LearningEntryStatePolicy.isWeeklyMockLobby(attempt.state)' "$ROOT/Matths/WeeklyMockScreen.swift"
grep -Fq 'case .unavailable(let status)' "$ROOT/Matths/PlacementExamScreen.swift"
xcrun swiftc \
  "$ROOT/Matths/LearningEntryStatePolicy.swift" \
  "$ROOT/tests/LearningEntryStateCases.swift" \
  -o /tmp/matths-learning-entry-state-cases
/tmp/matths-learning-entry-state-cases

echo 'Learning entry state contract passed.'
