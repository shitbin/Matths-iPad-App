#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-quick-stats.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

# iPhone 가로 시작 화면은 문제 시작과 누적 기록을 같은 첫 화면에 둔다.
grep -Fq 'private var usesLandscapeOverviewLayout: Bool' \
  "$root/Matths/QuickPracticeScreen.swift"
grep -Fq 'HStack(alignment: .top, spacing: Tokens.Space.s4)' \
  "$root/Matths/QuickPracticeScreen.swift"

# 가로 결과 화면도 헤더를 한 줄로 줄이고 다음/그만하기를 한 행에 둔다.
grep -Fq 'private var usesCompactExerciseHeader: Bool' \
  "$root/Matths/QuickPracticeScreen.swift"
grep -Fq 'case .solving, .graded: return true' \
  "$root/Matths/QuickPracticeScreen.swift"
grep -Fq 'if usesCompactExerciseHeader {' \
  "$root/Matths/QuickPracticeScreen.swift"
grep -Fq 'guard isShort else { return false }' \
  "$root/Matths/QuickPracticeScreen.swift"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' \
  "$root/Matths/QuickPracticeScreen.swift"
grep -Fq 'dynamicTypeSize.isAccessibilitySize || (isNarrow && !isShort)' \
  "$root/Matths/QuickPracticeScreen.swift"

# 화면과 같은 Swift 구현을 독립 컴파일해 신·구 서버 값, 모순 응답, 경계값을 잠근다.
sed -n '/^enum QuickPracticeStatsDisplay/,/^struct QuickPracticeScreen/p' \
  "$root/Matths/QuickPracticeScreen.swift" | sed '$d' > "$work/main.swift"
cat >> "$work/main.swift" <<'SWIFT'
func expect(_ actual: Int, _ expected: Int, _ label: String) {
    precondition(actual == expected, "\(label): \(actual) != \(expected)")
}

// 실제 문항 수가 있으면 reported 형식과 무관하게 counts가 진실원이다.
expect(QuickPracticeStatsDisplay.accuracyPercent(total: 86, correct: 61, reported: 0.709), 71, "legacy ratio fixture")
expect(QuickPracticeStatsDisplay.accuracyPercent(total: 86, correct: 61, reported: 71), 71, "current percent")
expect(QuickPracticeStatsDisplay.accuracyPercent(total: 4, correct: 3, reported: 0), 75, "stale reported value")

// counts가 없는 저장 응답만 reported를 0...1/0...100 양쪽으로 호환한다.
expect(QuickPracticeStatsDisplay.accuracyPercent(total: nil, correct: nil, reported: 0.709), 71, "ratio fallback")
expect(QuickPracticeStatsDisplay.accuracyPercent(total: nil, correct: nil, reported: 70.9), 71, "percent fallback")
expect(QuickPracticeStatsDisplay.accuracyPercent(total: nil, correct: nil, reported: 120), 100, "upper clamp")
expect(QuickPracticeStatsDisplay.accuracyPercent(total: nil, correct: nil, reported: -4), 0, "lower clamp")
print("Quick practice stats display contract passed")
SWIFT

swiftc -module-cache-path "$work/ModuleCache" "$work/main.swift" -o "$work/test"
"$work/test"
