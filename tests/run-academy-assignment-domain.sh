#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-academy-assignment.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc "$ROOT/Matths/AcademyAssignmentDomain.swift" \
  "$ROOT/tests/AcademyAssignmentDomainCases.swift" -o "$WORK/cases"
"$WORK/cases"
