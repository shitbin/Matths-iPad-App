#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/GoatArenaScreen.swift"
recovery="$root/Matths/GoatArenaRecoverySheets.swift"
router="$root/Matths/DemoMode.swift"
fixture="$root/Matths/DemoArenaRecoveryFixtures.swift"

for route in \
  '"/api/v1/goat-arena/revenge-rights/pending"' \
  '"/api/v1/goat-arena/revenge-rights/\(rightId)/claim"' \
  '"/api/v1/goat-arena/revenge-rights/\(rightId)/forfeit"' \
  '"/api/v1/goat-arena/matches/\(matchId)/supplemental-evidence"'
do
  grep -Fq "$route" "$recovery"
done

# 민감한 사진 초안은 계정 슬롯에만 두고 계정 전환 시 작업을 폐기한다.
grep -Fq 'DataScope.url("arena-supplemental-' "$recovery"
grep -Fq 'DataScope.didSwitchNotification' "$recovery"
grep -Fq 'SupplementalDraftStore.clear' "$recovery"
grep -Fq 'files.count <= 5' "$recovery"
grep -Fq 'totalBytes <= 30 * 1024 * 1024' "$recovery"
grep -Fq 'Idempotency-Key' "$recovery"
grep -Fq 'X-Matths-Client-Version' "$recovery"

# 운영 검토 중인 경기는 홈에서 요청 확인·제출까지 막힘 없이 들어간다.
grep -Fq 'heldReviewSection' "$screen"
grep -Fq 'GoatArenaSupplementalEvidenceSheet(' "$screen"
grep -Fq 'GoatArenaRevengeRightSheet(' "$screen"
grep -Fq 'onOpenRevengeRights' "$screen"

for route in \
  'GET /api/v1/goat-arena/revenge-rights/pending' \
  '/api/v1/goat-arena/revenge-rights/{id}/claim' \
  '/api/v1/goat-arena/revenge-rights/{id}/forfeit' \
  '/api/v1/goat-arena/matches/{matchId}/supplemental-evidence'
do
  grep -Fq "$route" "$router"
done
grep -Fq 'static let revengeRight' "$fixture"
grep -Fq 'static func supplementalRequest' "$fixture"
grep -Fq 'static let supplementalSubmission' "$fixture"

echo 'Native Arena revenge and supplemental evidence contracts passed.'
