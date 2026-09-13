#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tokens="$root/Matths/DesignTokens.swift"
quick="$root/Matths/QuickPracticeScreen.swift"
home="$root/Matths/RootView.swift"
today="$root/Matths/TodayActivityStore.swift"
api="$root/Matths/ServerAPI.swift"
defense="$root/Matths/ArenaDefenseInbox.swift"
arena="$root/Matths/GoatArenaScreen.swift"
archive="$root/Matths/AdminArchiveScreen.swift"
me="$root/Matths/LearningFlowScreens.swift"

grep -Fq 'static let actionForeground = adaptive(light: 0xFDFCFF, dark: 0x090C1B)' "$tokens"
grep -Fq '.foregroundStyle(isEnabled ? Tokens.actionForeground : Tokens.text4)' "$tokens"
if grep -Fq 'if !answerFocused' "$quick"; then
  echo "landscape note still disappears when answer receives focus" >&2
  exit 1
fi
grep -Fq 'if let action = store.resolvedTodayAction' "$home"
grep -Fq 'TodayDashboardPolicy.agenda' "$home"
grep -Fq 'async let weekly: Void = self.refreshWeekly' "$today"
grep -Fq 'title = "받은 Arena 공격 확인"' "$today"
grep -Fq 'getGoatArenaActionableDefenses' "$api"
grep -Fq 'getGoatArenaActionableDefenses' "$defense"
grep -Fq 'recentMatchesError = recentMatches.isEmpty' "$arena"
grep -Fq 'Text("마지막 확인 \(loadedAt.formatted' "$arena"
grep -Fq 'case .bulk(let ids, let titles)' "$archive"
grep -Fq 'viewport.size.width >= 760' "$archive"
grep -Fq 'store.serverProfile?.profileAvatar?.bundledImageName' "$me"

python3 - <<'PY'
def linear(v):
    v /= 255
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
def luminance(value):
    r, g, b = ((value >> 16) & 255, (value >> 8) & 255, value & 255)
    r, g, b = linear(r), linear(g), linear(b)
    return 0.2126*r + 0.7152*g + 0.0722*b
def contrast(a, b):
    x, y = sorted((luminance(a), luminance(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)
assert contrast(0x090C1B, 0x9A7BFF) >= 4.5
PY

echo "GPT-6 feedback P1 and high-risk P2 remediation contracts passed"
