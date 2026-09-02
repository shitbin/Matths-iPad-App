#!/usr/bin/env bash
set -euo pipefail

# 개념 코드 애니메이션 자산을 **앱 저장소 안의 번들 페이로드**로 동기화한다.
#
# 왜 앱 저장소에 사본을 두는가:
#   TestFlight·App Store 설치본에는 Application Support/ConceptMotion 이 비어 있다.
#   개발 중에는 push-concept-motion.sh 가 밀어넣어 주지만 설치본에는 그 단계가 없어
#   개념학습이 통째로 빈 화면이 됐다. 그래서 자산 한 벌을 앱 번들에 동봉한다.
#
#   동봉본의 출처를 "빌드할 때 제작 저장소에서 가져오기" 로 하면 제작 저장소가 없는
#   머신에서 앱 빌드가 통째로 깨진다. 앱 빌드는 제작 저장소를 몰라야 한다 —
#   그래서 이 스크립트가 **사람이 명시적으로 돌릴 때만** 사본을 갱신하고,
#   Xcode 는 앱 저장소 안의 ConceptMotion/ 폴더 참조만 본다.
#
# 용량 근거(2026-08 실측, 음성 재인코딩 후):
#   compositions/*.html   220 + 여성 220 =  34MB
#   assets/voice-female   220 × full.mp3 =  77MB   ← 동봉하는 유일한 음성
#   (assets/voice 남성 66MB 는 **동봉하지 않는다** — 아래 이유)
#   assets/fonts                          = 0.4MB
#   vendor/gsap.min.js                    = 0.1MB
#   합계 약 177MB. 재인코딩 전(458MB)에는 불가능했던 선택지다.
#
# 트리 모양이 제작 저장소와 같아야 하는 이유:
#   컴포지션 HTML 은 <base href="../"> 로 자산을 찾는다. compositions/ 한 칸 위가
#   assets/ 여야 폰트와 음성이 붙는다. Application Support 로 밀어넣든 번들에
#   동봉하든 **같은 모양**이라야 앱 코드가 두 자리를 구분하지 않고 쓸 수 있다.
#
# 쓰는 법:
#   scripts/sync-concept-motion-bundle.sh              # 제작 저장소 → ConceptMotion/
#   scripts/sync-concept-motion-bundle.sh --src <경로>  # 제작 저장소 위치 지정
#   scripts/sync-concept-motion-bundle.sh --check      # 갱신하지 않고 현황만 본다

SRC="${MATTHS_CONCEPT_MOTION_SRC:-$HOME/Desktop/Matths/저장소/matths-concept-motion}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$REPO/ConceptMotion"
CHECK_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --check) CHECK_ONLY=1; shift ;;
    -h|--help) sed -n '3,33p' "$0"; exit 0 ;;
    *) echo "모르는 인자: $1" >&2; exit 2 ;;
  esac
done

report_dest() {
  local html voice female
  html="$(ls -1 "$DEST/compositions"/*.html 2>/dev/null | wc -l | tr -d ' ')"
  voice="$(find "$DEST/assets/voice" -name full.mp3 2>/dev/null | wc -l | tr -d ' ')"   # 기대값 0
  female="$(find "$DEST/assets/voice-female" -name full.mp3 2>/dev/null | wc -l | tr -d ' ')"
  echo "번들 페이로드: $DEST"
  echo "  컴포지션 ${html}개 / 남성 음성 ${voice}개 / 여성 음성 ${female}개 / $(du -sh "$DEST" 2>/dev/null | cut -f1)"
}

if [ "$CHECK_ONLY" = "1" ]; then
  [ -d "$DEST" ] || { echo "번들 페이로드가 없습니다: $DEST" >&2; exit 1; }
  report_dest
  exit 0
fi

[ -d "$SRC/compositions" ] || { echo "제작 저장소를 못 찾았습니다: $SRC" >&2; exit 1; }

STAGE="$(mktemp -d)/ConceptMotion"
trap 'rm -rf "$(dirname "$STAGE")"' EXIT
mkdir -p "$STAGE/compositions" "$STAGE/assets" "$STAGE/vendor"

# 폰트는 전부. 서브셋이라 개념별로 나눌 수 없다 — 한 벌이 220개를 다 덮는다.
cp -R "$SRC/assets/fonts" "$STAGE/assets/fonts"

count=0
for html in "$SRC"/compositions/*.html; do
  id="$(basename "$html" .html)"
  # 검증용(_verify-*)·스타일 테스트(*.dark/*.light)는 개념 id 가 아니라 앱이 절대
  # 찾지 않는다. *.female 은 짝으로 따라오므로 여기서 또 세지 않는다.
  case "$id" in _*|*.dark|*.light|*.female) continue ;; esac

  cp "$html" "$STAGE/compositions/$id.html"
  # 여성 타이밍으로 다시 구운 무대가 있을 때만 여성 짝을 가져간다. 음성만
  # 갈아끼우면 자막이 목소리와 10초씩 어긋난다(ConceptMotionWebAsset.stage 주석).
  [ -f "$SRC/compositions/$id.female.html" ] \
    && cp "$SRC/compositions/$id.female.html" "$STAGE/compositions/$id.female.html"

  # full.mp3 만 가져간다. 제작 저장소의 구간별 mp3(01.mp3…)와 _scratch 는
  # 굽는 과정의 중간물이라 앱이 열 일이 없다 — 넣으면 76MB 가 그냥 늘어난다.
  # 여성 음성 한 벌만 동봉한다.
  #
  # 왜 남성을 뺐나 — 두 벌이면 음성만 144MB 다. 앱 전체가 셀룰러 다운로드 경고선
  # (200MB)을 음성만으로 넘긴다. 밖에서 앱을 받으려는 학생이 "Wi-Fi 에 연결하세요"
  # 를 보게 되는데, 그 대가로 얻는 게 "대체 성우" 라면 값이 안 맞는다.
  #
  # 앱은 이 결정을 코드에 박아 두지 않았다. ConceptNarrationVoice.isInstalled 가
  # 번들을 실제로 들여다보고 선택지를 만든다. 그래서 나중에 남성 음성을 다시
  # 넣거나 서버에서 내려받게 하면 **이 배열에 voice 를 되돌리는 것만으로** 선택지가
  # 저절로 살아난다. 앱 코드는 고칠 것이 없다.
  for voice in voice-female; do
    if [ -f "$SRC/assets/$voice/$id/full.mp3" ]; then
      mkdir -p "$STAGE/assets/$voice/$id"
      cp "$SRC/assets/$voice/$id/full.mp3" "$STAGE/assets/$voice/$id/full.mp3"
    fi
  done
  count=$((count + 1))
done

[ "$count" -gt 0 ] || { echo "가져올 컴포지션이 하나도 없습니다: $SRC/compositions" >&2; exit 1; }

# GSAP 로컬 사본. 컴포지션이 부르는 것과 **같은 버전**이어야 한다 — HTML 에서 읽어낸다.
# 이게 있어야 오프라인 교실에서 CDN 을 기다리며 화면이 하얗게 서 있지 않는다.
GSAP_CACHE="$SRC/vendor/gsap.min.js"
if [ ! -f "$GSAP_CACHE" ]; then
  echo "경고: $GSAP_CACHE 가 없습니다. push-concept-motion.sh 를 한 번 돌려 받아 두세요." >&2
else
  cp "$GSAP_CACHE" "$STAGE/vendor/gsap.min.js"
fi

# Finder 부산물은 서명 대상 번들에 들어갈 이유가 없다.
find "$STAGE" -name '.DS_Store' -delete

mkdir -p "$DEST"
# .gitkeep 은 지우지 않는다 — 이 폴더는 Xcode 폴더 참조라 폴더 자체가 사라지면
# "Build input file cannot be found" 로 빌드가 죽는다. 내용물은 .gitignore 대상이고
# 빈 껍데기만 저장소에 남아 빌드를 살려 둔다(그때는 앱이 기존 벡터 무대로 폴백한다).
touch "$DEST/.gitkeep"
rsync -a --delete --exclude='.gitkeep' "$STAGE/" "$DEST/"

echo "제작 저장소: $SRC"
report_dest
