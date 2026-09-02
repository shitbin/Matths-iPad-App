#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

grep -Fq '"GET", "/api/v1/assessments"' "$ROOT/Matths/AssessmentSyncAPI.swift"
grep -Fq '"POST", "/api/v1/assessments/start"' "$ROOT/Matths/AssessmentSyncAPI.swift"
grep -Fq '"PATCH", "/api/v1/assessments/\(id)/draft"' "$ROOT/Matths/AssessmentSyncAPI.swift"
grep -Fq '"POST", "/api/v1/assessments/\(id)/submit"' "$ROOT/Matths/AssessmentSyncAPI.swift"
grep -Fq 'Task { [weak self] in await self?.pullServerAssessments() }' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'assessmentStartGeneration' "$ROOT/Matths/MatthsApp.swift"
grep -Fq 'serverQuestionId' "$ROOT/Matths/AssessmentV2.swift"
grep -Fq 'Self.date(from: $0.updatedAt)' "$ROOT/Matths/SyncEngine.swift"

echo 'Assessment and wrong-note sync contract passed.'
