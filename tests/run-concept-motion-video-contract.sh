#!/usr/bin/env bash
set -euo pipefail

# 개념 설명 영상 = 소리를 소유하는 단일 산출물 (2026-08-16)
#
# 사용자 보고: "지금 영상이랑 목소리 다 따로나오잖아."
#
# 원인은 시계가 둘이었다는 것이다. WKWebView 가 애니메이션을 그리고
# AVSpeechSynthesizer 가 별도로 TTS 를 읽었다. 웹 애니메이션은 수십 초,
# TTS 는 수백 초로 흘러 같은 순간에 서로 다른 데를 가리켰다.
#
# 해법은 나레이션을 영상에 굽는 것이다. 소리가 그림 안에 있으면 어긋날 여지가 없다.
# 이 검사가 지키는 것은 하나다 — **영상이 있을 때 TTS 가 같이 돌지 않는 것.**
# 이 게이트가 뚫리면 고치려던 문제가 그대로 재현된다.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIDEO="$ROOT/Matths/ConceptMotionVideo.swift"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"

test -f "$VIDEO"
test -f "$TIMELINE"

# ── 재생 표면 ───────────────────────────────────────────────────────
grep -Fq 'layerClass: AnyClass { AVPlayerLayer.self }' "$VIDEO"
# 9:16 원본을 가로 화면에서 자르지 않는다.
grep -Fq 'videoGravity = .resizeAspect' "$VIDEO"

# 소리는 영상의 일부다. 음소거하면 이 파일이 존재할 이유가 사라진다.
grep -Fq 'player.isMuted = false' "$VIDEO"
if grep -Fq 'isMuted = true' "$VIDEO"; then
  echo "개념 영상이 음소거됐습니다 — 나레이션을 구워 넣은 의미가 사라집니다" >&2
  exit 1
fi

# 저절로 시작하는 소리라 무음 스위치를 따른다.
grep -Fq 'setCategory(.ambient' "$VIDEO"

# ── 자산은 번들에 넣지 않는다 ───────────────────────────────────────
# 개념 220개면 1GB 를 넘는다. Application Support 에서 읽는다.
grep -Fq 'applicationSupportDirectory' "$VIDEO"
if grep -Fq 'Bundle.main.url(forResource' "$VIDEO"; then
  echo "개념 영상을 앱 번들에서 찾고 있습니다 — 220개면 앱이 1GB를 넘습니다" >&2
  exit 1
fi

# 파일명 버전 — 영상을 다시 뽑아도 옛 파일을 붙들지 않게.
grep -Fq '.v\(version).mp4' "$VIDEO"

# ── 핵심: 영상이 있으면 TTS 를 켜지 않는다 ──────────────────────────
grep -Fq 'ConceptMotionAsset.url(conceptID: concept.id' "$TIMELINE"
grep -Fq 'ConceptMotionVideoView(' "$TIMELINE"

# 세 진입로 전부에 게이트가 걸려야 한다.
# (등장 / 스토리 교체 / 앱 복귀) — 하나라도 빠지면 그 경로에서 소리가 겹친다.
gates=$(grep -c 'motionVideoURL == nil' "$TIMELINE" || true)
if [ "$gates" -lt 3 ]; then
  echo "TTS 억제 게이트가 $gates 곳뿐입니다. 등장·스토리교체·앱복귀 세 경로 전부 필요합니다" >&2
  exit 1
fi

# ── 폴백이 살아 있어야 한다 ─────────────────────────────────────────
# 220개 중 영상이 아직 없는 개념이 빈 화면이 되면 안 된다.
grep -Fq 'CurriculumScenarioLessonView(' "$TIMELINE"
grep -Fq 'CurriculumMotionLessonView(' "$TIMELINE"

# ── 재생 버튼은 여전히 없다 ─────────────────────────────────────────
if grep -rq 'CurriculumNarrationTransport' "$ROOT/Matths"; then
  echo "해설 재생 컨트롤이 되살아났습니다" >&2
  exit 1
fi

echo "개념 영상 계약 통과 (소리 내장 · TTS 억제 3경로 · 번들 미포함 · 폴백 유지)"
