#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$ROOT/Matths/WeeklyMockAPI.swift"
screen="$ROOT/Matths/WeeklyMockScreen.swift"

# 시험지 다운로드 완료 시점의 전역 계정이 아니라 요청 시작 계정 캐시에 쓴다.
grep -Fq 'downloadWeeklyMockPaper(' "$api"
grep -Fq 'accountSlot: String' "$api"
grep -Fq '.appendingPathComponent(accountSlot, isDirectory: true)' "$api"
grep -Fq 'accountSlot: accountSlot)' "$screen"

# 소명 제출은 계정·사건별 동일 키를 응답 확인 전까지 보존한다.
grep -Fq 'submissionId: String' "$api"
grep -Fq 'request.setValue(submissionId, forHTTPHeaderField: "Idempotency-Key")' "$api"
grep -Fq 'WeeklyMockEvidenceCommandStore.loadOrCreate' "$screen"
grep -Fq 'WeeklyMockEvidenceCommandStore.clear' "$screen"
grep -Fq 'DataScope.defaultsKey(' "$screen"

# 화면 인스턴스도 계정 전환 알림을 받아 이전 학생의 비동기 상태를 폐기한다.
grep -Fq 'DataScope.didSwitchNotification' "$screen"
grep -Fq '.id(accountSlot)' "$screen"

# 서버 상태 코드를 그대로 학생에게 노출하지 않고, 긴 시험명은 세로로 확장한다.
grep -Fq 'examStatusLabel(exam.attemptStatus)' "$screen"
grep -Fq 'case "submitted": return "제출 완료"' "$screen"
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$screen"
grep -Fq '작성한 답안은 이 기기에 보관됩니다. 잠시 후 다시 시도해 주세요.' "$screen"

# 최초 조회 실패를 정상 빈 목록으로 위장하지 않고, 소명·이의제기 양쪽 모두
# 별도 실패 상태와 재시도 동선을 유지한다.
test "$(grep -Fc '@State private var loadError: String?' "$screen")" -ge 2
grep -Fq 'title: "소명 요청을 불러오지 못했습니다"' "$screen"
grep -Fq 'title: "이의제기 내역을 불러오지 못했습니다"' "$screen"
test "$(grep -Fc 'loadError = WeeklyMockFormat.message(error)' "$screen")" -ge 2
test "$(grep -Fc 'retry: { Task { await load() } }' "$screen")" -ge 2

echo 'Account-bound weekly mock download and evidence contracts passed.'
