#!/usr/bin/env bash
set -euo pipefail

# 해설 음성은 영상의 일부다 (2026-08-16)
#
# 지시: "음성 재생 버튼을 만들지 말고 영상에 통합하라."
#
# 영상에 재생 버튼을 따로 달지 않는 것과 같은 이유다. 학생은 개념을 보러 왔지
# 음성을 조작하러 온 것이 아니다. 그래서 화면에 들어오면 애니메이션과 함께
# 소리가 시작하고, 나가면 함께 멈춘다. 누를 것이 없다.
#
# 이 검사가 막는 것은 "편의상 버튼 하나만 다시 달자" 는 되돌림이다.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLAYER="$ROOT/Matths/CurriculumSpeechPlayer.swift"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"
SCENARIO="$ROOT/Matths/CurriculumScenarioLessonView.swift"
MOTION="$ROOT/Matths/CurriculumMotionLessonView.swift"
WEB_STAGE="$ROOT/Matths/ConceptMotionWebStage.swift"

for f in "$PLAYER" "$TIMELINE" "$SCENARIO" "$MOTION" "$WEB_STAGE"; do test -f "$f"; done

# ── 버튼이 없어야 한다 ──────────────────────────────────────────────
# 컨트롤 컴포넌트 자체가 사라졌는지.
if grep -rq 'CurriculumNarrationTransport' "$ROOT/Matths"; then
  echo "해설 재생 컨트롤이 되살아났습니다 (CurriculumNarrationTransport)" >&2
  exit 1
fi

# 버튼 글자·아이콘을 만들던 코드도 남아 있으면 안 된다 — 남아 있으면
# 다음 사람이 "버튼이 어딘가 있나" 하고 찾는다.
for dead in 'primaryButtonLabel' 'primaryButtonSymbol'; do
  if grep -Fq "$dead" "$PLAYER"; then
    echo "쓰지 않는 버튼용 코드가 남아 있습니다: $dead" >&2
    exit 1
  fi
done

# 학습 화면에 재생 조작 문구가 다시 뜨면 안 된다.
for phrase in '5분 해설 듣기' '이어서 듣기' '잠시 멈추기' '다시 듣기'; do
  if grep -rFq "$phrase" "$SCENARIO" "$MOTION" "$TIMELINE"; then
    echo "학습 화면에 재생 조작 문구가 돌아왔습니다: $phrase" >&2
    exit 1
  fi
done

# ── 대신 저절로 들려야 한다 ─────────────────────────────────────────
# 버튼이 없으므로 자동 시작이 유일한 진입로다. 여기가 좁아지면 무음이 된다.
#
# 특히 .paused / .completed 를 받아야 한다. 예전에는 .idle 에서만 켰는데,
# 버튼이 있을 때는 그래도 됐지만 지금은 지난 세션 체크포인트가 .paused 로
# 남아 있으면 학생이 되살릴 방법이 없다.
grep -Fq 'state == .idle || state == .paused || state == .completed' "$PLAYER"
grep -Fq 'player.autoStart(allowed: !reduceMotion)' "$TIMELINE"

# off↔male가 같은 base HTML과 nil narration을 쓰더라도 음성 선택은 서로
# 다른 문서 신원이어야 한다. voice가 key에 없으면 남성 재생 중
# '끄기'를 눌러도 소리가 계속 나거나 그 반대가 된다.
if ! grep -A7 'private var documentKey' "$WEB_STAGE" | grep -Fq 'stage?.voice.rawValue'; then
  echo "HTML 모션 문서 key에 음성 상태가 없습니다 (off↔male 전환 무시)" >&2
  exit 1
fi

# 앱에 돌아왔을 때도 이어져야 한다. 잠깐 다른 앱에 다녀온 것만으로
# 해설이 영영 멈추면 안 된다.
grep -Fq 'player.pauseForInterruption()' "$TIMELINE"
# 탐색 창을 12줄로 둔다. 개념 영상 분기가 들어오면서 이 블록에 TTS 억제 게이트
# (motionVideoURL == nil)와 그 이유를 적은 주석이 붙어 autoStart 가 아래로 밀렸다.
# 6줄로 두면 동작은 멀쩡한데 검사만 실패한다.
if ! grep -A12 'onChange(of: scenePhase)' "$TIMELINE" | grep -Fq 'player.autoStart'; then
  echo "앱 복귀 시 해설이 다시 시작되지 않습니다 (scenePhase .active 경로 없음)" >&2
  exit 1
fi

# ── 무음일 때는 이유를 말해야 한다 ──────────────────────────────────
# 버튼과 함께 상태줄도 사라졌다. 그대로 두면 음성을 못 쓰는 기기에서
# 학생이 이유 없는 무음을 본다. 조작은 되살리지 않되 사실은 알린다.
grep -Fq 'var silentNotice: String?' "$PLAYER"
grep -Fq 'curriculum-narration-silent-notice' "$SCENARIO"
grep -Fq 'curriculum-narration-silent-notice' "$MOTION"

# 정상 상태에서는 아무 말도 하지 않아야 한다 — load 직후 안내문을 채우면
# silentNotice 가 그걸 그대로 화면에 올린다.
grep -Fq 'message = ""' "$PLAYER"
for chatter in '기기의 한국어 여성 음성을 우선 사용합니다' '멈춘 문장부터 이어 들을 수 있습니다'; do
  if grep -Fq "$chatter" "$PLAYER"; then
    echo "정상 상태 안내문이 남아 있어 무음 안내로 새어 나옵니다: $chatter" >&2
    exit 1
  fi
done

echo "해설 음성 영상 통합 계약 통과 (버튼 없음 · 자동 재생 · 무음 사유 고지)"
