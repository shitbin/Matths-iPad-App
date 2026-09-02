#!/usr/bin/env bash
set -euo pipefail

# 개념 모션은 iPhone/iPad의 세로·가로 화면에서 읽을 수 있는 크기를 유지한다.
# 수학 좌표를 늘이거나 자르지 않고, 검증된 공통 band 부모만 재배치하는 계약이다.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB_STAGE="$ROOT/Matths/ConceptMotionWebStage.swift"
TIMELINE="$ROOT/Matths/CurriculumStoryTimeline.swift"
CONCEPT="$ROOT/Matths/ConceptScreenV2.swift"
ROOT_VIEW="$ROOT/Matths/RootView.swift"

for file in "$WEB_STAGE" "$TIMELINE" "$CONCEPT" "$ROOT_VIEW"; do
  test -f "$file"
done

# 세로는 빈 상·하단을 압축하고, 가로는 1200 모션판 + 960 설명판이다.
grep -Fq 'case portraitBoard = "portrait-board"' "$WEB_STAGE"
grep -Fq 'case wideBoard = "wide-board"' "$WEB_STAGE"
grep -Fq 'CGSize(width: 1080, height: 1560)' "$WEB_STAGE"
grep -Fq 'CGSize(width: 2160, height: 1080)' "$WEB_STAGE"

# 내부 SVG/viewBox는 건드리지 않는다. 가로 모션판만 10/9 균등 확대하고
# 1200×1080 왼쪽 작업대의 정중앙에 둔다.
for rule in \
  '.band-title{left:1200px!important;top:96px!important;width:960px!important}' \
  '.band-panel{left:1200px!important;top:342px!important;width:960px!important}' \
  '.band-stage{left:0!important;top:81.333px!important;transform:scale(1.111111)!important;transform-origin:0 0!important}' \
  '.band-caption{left:1200px!important;top:650px!important;width:960px!important}' \
  '.band-title{top:24px!important}' \
  '.band-panel{top:235px!important}' \
  '.band-stage{top:450px!important}' \
  '.band-caption{top:1310px!important}'; do
  grep -Fq "$rule" "$WEB_STAGE"
done

# viewport/root/Surface가 같은 캔버스를 써야 WebKit이 임의 배율을 끼우지 않는다.
grep -Fq 'meta.setAttribute("content", "width=" + width + ", height=" + height' "$WEB_STAGE"
grep -Fq 'root.setAttribute("data-width", String(width))' "$WEB_STAGE"
grep -Fq 'surface.canvasSize = presentation.canvasSize' "$WEB_STAGE"
grep -Fq 'let scale = min(bounds.width / canvasSize.width' "$WEB_STAGE"
grep -Fq 'window.MATTHS_MOTION_SET_PRESENTATION = applyPresentation' "$WEB_STAGE"
grep -Fq 'didFinish navigation: WKNavigation!' "$WEB_STAGE"
grep -Fq 'applyDesiredRuntimeState(to: webView)' "$WEB_STAGE"

# 긴 패널 식은 수식 조각의 애니메이션 transform과 분리된 row zoom으로만 맞춘다.
grep -Fq 'function fitWidePanelRows(wide)' "$WEB_STAGE"
grep -Fq 'var available = 880' "$WEB_STAGE"
grep -Fq 'row.style.setProperty("zoom", String(available / width))' "$WEB_STAGE"
grep -Fq 'row.style.removeProperty("zoom")' "$WEB_STAGE"
grep -Fq 'document.fonts.ready.then' "$WEB_STAGE"

# 회전은 같은 수업 문서에서 CSS만 바꾼다. documentKey에 규격을 넣으면 음성이 0초로 간다.
if grep -A5 'private var documentKey' "$WEB_STAGE" | grep -Fq 'presentation.rawValue'; then
  echo "회전이 문서를 재로드해 개념 음성을 0초로 되돌립니다" >&2
  exit 1
fi

# 가로 iPhone과 가로형 iPad 창만 2열판, 세로/분할 화면은 큰 세로판을 쓴다.
grep -Fq '@Environment(\.matthsBrowseViewportSize) private var viewportSize' "$TIMELINE"
grep -Fq 'let landscapeWindow = hasViewport && viewportSize.width > viewportSize.height' "$TIMELINE"
grep -Fq '|| (landscapeWindow && contentWidth >= 800)' "$TIMELINE"
grep -Fq 'presentation: motionPresentation' "$TIMELINE"
grep -Fq '.aspectRatio(motionPresentation.aspectRatio, contentMode: .fit)' "$TIMELINE"

# 설명 중인 가로 iPhone에 320pt 연습 rail을 붙여 모션을 다시 줄이면 안 된다.
grep -Fq 'activeStage != .explain' "$CONCEPT"

# iPad 가로에서는 개념 수업만 일반 문서 900pt 제한을 벗어난다.
grep -Fq '.readableWidth(store.route == .concept ? 1280 : Tokens.readableWidth)' "$ROOT_VIEW"
grep -Fq 'maxWidth: effectiveStage == .explain ? .infinity : Tokens.readableWidth' "$CONCEPT"
grep -Fq '.frame(maxWidth: Tokens.readableWidth, minHeight: startMinHeight' "$CONCEPT"

# 비율을 채운다는 이유로 비균일 확대를 쓰면 가장자리 수식이 잘린다.
grep -Fq 'CGAffineTransform(scaleX: scale, y: scale)' "$WEB_STAGE"

# 오른쪽 설명판은 기존 최대 930px 자막보다 좁아지면 안 된다.
python3 - <<'PY'
stage_width = 1080 * (10 / 9)
stage_height = 825.6 * (10 / 9)
assert abs(stage_width - 1200) < 0.001
assert abs((1080 - stage_height) / 2 - 81.3333333333) < 0.001
assert 960 >= 930
PY

echo "개념 모션 반응형 계약 통과 (iPhone/iPad 세로·가로 · 내부 좌표 보존)"
