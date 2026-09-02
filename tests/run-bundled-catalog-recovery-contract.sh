#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

for source in CurriculumV2.swift AssessmentV2.swift Schools.swift; do
  if grep -Fq 'fatalError(' "$root/Matths/$source"; then
    echo "$source must not terminate the whole app for a damaged bundled catalog" >&2
    exit 1
  fi
  grep -Fq 'static let loadError' "$root/Matths/$source"
done

grep -Fq 'if let loadError = CurriculumV2.loadError' "$root/Matths/CurriculumV2MapScreen.swift"
grep -Fq 'Button("홈으로 돌아가기") { store.route = .home }' "$root/Matths/CurriculumV2MapScreen.swift"
grep -Fq 'if let catalogError = AssessCatalog.loadError' "$root/Matths/Screens.swift"
grep -Fq '주간 공식 모의고사는 계속 이용할 수 있으며' "$root/Matths/AssessmentV2.swift"

# Runtime fallback must not weaken the release resource gate. The source JSON
# still has to exist and decode to the full authoritative catalog.
node "$root/tests/CurriculumPracticeCoverage.js" >/dev/null
node - "$root" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const root = process.argv[2];
const assessment = JSON.parse(fs.readFileSync(path.join(root, 'Matths/assessment-catalog.json'), 'utf8'));
const schools = JSON.parse(fs.readFileSync(path.join(root, 'Matths/schools.json'), 'utf8'));
if (!Array.isArray(assessment.courses) || assessment.courses.length !== 5) {
  throw new Error('assessment catalog must keep the five authoritative courses');
}
if (!Array.isArray(schools.regions) || schools.regions.length !== 17) {
  throw new Error('bundled school fallback must keep all 17 regions');
}
NODE

echo 'bundled catalog runtime recovery and release resource contracts passed'
