#!/usr/bin/env bash
set -euo pipefail

# 개념 코드 애니메이션 자산을 기기/시뮬레이터로 밀어넣는다.
#
# 왜 스크립트가 여전히 필요한가:
#   ※ 2026-08 부터 자산 한 벌(약 177MB)이 **앱 번들에도 동봉**된다
#     (scripts/sync-concept-motion-bundle.sh → ConceptMotion/ 폴더 참조).
#     그래서 설치본에서도 개념학습이 비지 않는다.
#   그런데 앱은 **개념마다 Application Support 를 먼저 본다**. 자산을 고쳐도
#   앱이 빌드 당시의 동봉본만 계속 틀면 제작 쪽 반복이 죽기 때문이다.
#   이 스크립트는 그 "먼저 보는 자리" 를 채우는 개발용 통로이고, 여기에 없는
#   개념은 번들 동봉본으로 내려간다 — `--only` 로 하나만 밀어넣어도
#   나머지 219개가 사라지지 않는다.
#   (실배포 음성 패키지 내려받기는 여전히 별도 과제다)
#
# 트리 모양을 제작 저장소와 똑같이 유지하는 이유:
#   컴포지션 HTML 은 <base href="../"> 로 자산을 찾는다. compositions/ 한 칸
#   위가 assets/ 여야 폰트와 음성이 붙는다. 한 칸이라도 어긋나면 소리 없는
#   두부 글자 화면이 나온다.
#
# 쓰는 법:
#   scripts/push-concept-motion.sh                       # 부팅된 시뮬레이터에 전부
#   scripts/push-concept-motion.sh --only algebra-01-01  # 개념 하나만 (빠른 확인)
#   scripts/push-concept-motion.sh --device <UDID>       # 실기기 (Xcode 15+ devicectl)
#   scripts/push-concept-motion.sh --sim <UDID>          # 시뮬레이터 지정 (여러 대 부팅 중일 때)
#   scripts/push-concept-motion.sh --src <경로>          # 제작 저장소 위치 지정

BUNDLE_ID="kr.matths.app"
SRC="${MATTHS_CONCEPT_MOTION_SRC:-$HOME/Desktop/Matths/저장소/matths-concept-motion}"
DEVICE=""
SIM="booted"
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --sim) SIM="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    -h|--help) sed -n '3,27p' "$0"; exit 0 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done

[ -d "$SRC/compositions" ] || { echo "제작 저장소를 못 찾았습니다: $SRC" >&2; exit 1; }

STAGE="$(mktemp -d)/ConceptMotion"
trap 'rm -rf "$(dirname "$STAGE")"' EXIT
mkdir -p "$STAGE/compositions" "$STAGE/assets" "$STAGE/vendor"

# 폰트는 전부(156KB). 서브셋이라 개념별로 나눌 수 없다 — 한 벌이 220개를 다 덮는다.
cp -R "$SRC/assets/fonts" "$STAGE/assets/fonts"

copy_concept() {
  local id="$1"
  [ -f "$SRC/compositions/$id.html" ] || return 0
  cp "$SRC/compositions/$id.html" "$STAGE/compositions/$id.html"
  # 여성 타이밍으로 다시 구운 무대가 있으면 짝째로 가져간다. 이게 없으면 앱은
  # 여성 해설을 켜지 않는다 — 음성만 갈아끼우면 자막이 목소리와 10초씩 어긋난다.
  [ -f "$SRC/compositions/$id.female.html" ] \
    && cp "$SRC/compositions/$id.female.html" "$STAGE/compositions/$id.female.html"
  local voice
  for voice in voice voice-female; do
    if [ -f "$SRC/assets/$voice/$id/full.mp3" ]; then
      mkdir -p "$STAGE/assets/$voice/$id"
      cp "$SRC/assets/$voice/$id/full.mp3" "$STAGE/assets/$voice/$id/full.mp3"
    fi
  done
}

if [ -n "$ONLY" ]; then
  copy_concept "$ONLY"
  [ -f "$STAGE/compositions/$ONLY.html" ] || { echo "그런 컴포지션이 없습니다: $ONLY" >&2; exit 1; }
else
  # 검증용 파일(_verify-*, 01/02 스타일 테스트)은 개념 id 가 아니라 앱이 절대
  # 찾지 않는다. 옮겨 봐야 용량만 먹는다.
  for html in "$SRC"/compositions/*.html; do
    id="$(basename "$html" .html)"
    # 검증용(_verify-*)·스타일 테스트(*.dark/*.light)는 개념 id 가 아니라 앱이
    # 절대 찾지 않는다. *.female 은 짝으로 따라오므로 여기서 또 세지 않는다.
    case "$id" in _*|*.dark|*.light|*.female) continue ;; esac
    copy_concept "$id"
  done
fi

# GSAP 로컬 사본. 컴포지션이 부르는 것과 **같은 버전**이어야 한다 — HTML 에서 읽어낸다.
# 이게 있어야 오프라인 교실에서 CDN 을 기다리며 화면이 하얗게 서 있지 않는다.
GSAP_VER="$(grep -ho 'gsap@[0-9.]*' "$SRC"/compositions/*.html | head -1 | cut -d@ -f2)"
GSAP_CACHE="$SRC/vendor/gsap.min.js"
if [ ! -f "$GSAP_CACHE" ] && [ -n "$GSAP_VER" ]; then
  mkdir -p "$SRC/vendor"
  echo "GSAP $GSAP_VER 내려받는 중 (한 번만)"
  curl -fsSL "https://cdn.jsdelivr.net/npm/gsap@$GSAP_VER/dist/gsap.min.js" -o "$GSAP_CACHE" \
    || echo "경고: GSAP 을 못 받았습니다. 앱은 CDN 에 의존하게 됩니다(오프라인이면 무대가 서지 않습니다)." >&2
fi
[ -f "$GSAP_CACHE" ] && cp "$GSAP_CACHE" "$STAGE/vendor/gsap.min.js"

COUNT="$(ls -1 "$STAGE/compositions" | wc -l | tr -d ' ')"
SIZE="$(du -sh "$STAGE" | cut -f1)"

DEST="Library/Application Support/ConceptMotion"

if [ -n "$DEVICE" ]; then
  # 실기기. Xcode 15+ 의 devicectl 이 앱 데이터 컨테이너에 직접 쓴다.
  # (앱이 한 번은 실행된 적이 있어야 컨테이너가 존재한다)
  xcrun devicectl device info apps --device "$DEVICE" >/dev/null
  # ⚠️ devicectl copy 는 소스 **디렉터리째** 가 아니라 그 **안의 것** 을 목적지에 푼다.
  # --destination "Library/Application Support/" 로 주면 ConceptMotion/ 껍데기가
  # 사라지고 assets·compositions 가 Application Support 바로 아래로 흩어진다.
  # 앱은 ConceptMotion/ 아래를 보므로 자산을 하나도 못 찾는다 —
  # 실제로 409MB 를 밀고도 앱은 예전 화면만 냈다.
  # 목적지에 ConceptMotion 까지 적어야 트리가 맞는다.
  xcrun devicectl device copy to \
    --device "$DEVICE" \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "$STAGE" \
    --destination "$DEST"

  # 밀어넣고 끝내지 않는다. 앱이 실제로 찾는 경로에 파일이 있는지 되읽어 확인한다.
  # 스크립트가 "성공" 이라고 말하는 것과 자산이 거기 있는 것은 다른 일이다.
  landed="$(xcrun devicectl device info files --device "$DEVICE" \
    --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" 2>/dev/null \
    | grep -c "$DEST/compositions/" || true)"
  if [ "$landed" -lt 1 ]; then
    echo "밀어넣기 실패: $DEST/compositions 가 기기에 없습니다." >&2
    exit 1
  fi
  echo "실기기($DEVICE)에 ${COUNT}개 개념 / $SIZE 밀어넣었습니다 (컴포지션 ${landed}개 확인)."
else
  # 시뮬레이터가 여러 대 켜져 있으면 "booted" 가 어느 하나를 고를 수 없다. --sim 으로 지정한다.
  CONTAINER="$(xcrun simctl get_app_container "$SIM" "$BUNDLE_ID" data)" \
    || { echo "그 시뮬레이터에 앱이 없습니다(설치 먼저). 여러 대 켜져 있으면 --sim <UDID> 로 지정하세요." >&2; exit 1; }
  mkdir -p "$CONTAINER/Library/Application Support"
  rm -rf "$CONTAINER/$DEST"
  cp -R "$STAGE" "$CONTAINER/$DEST"
  echo "시뮬레이터에 ${COUNT}개 개념 / $SIZE 밀어넣었습니다."
  echo "  $CONTAINER/$DEST"
fi
