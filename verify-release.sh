#!/bin/bash
# Release 빌드 출시 전 검증 — 백로그 L-4 를 사람이 눈으로 보는 대신 기계가 막는다.
#
#   bash ipad-app/verify-release.sh
#
# 무엇을 막는가
#  1) 비밀정보가 바이너리에 섞여 나가는 것 (DB 문자열·SECRET·API 키).
#     원칙: 앱은 서버 API 만 부른다. 이 원칙이 깨지면 앱을 뜯는 누구나 DB 를 연다.
#  2) DEBUG 전용 통로가 출시판에 남는 것 (서버 주소 입력 필드·기록 보기·런치 인자).
#     특히 서버 주소 필드는 학생이 속아 임의 서버에 계정·토큰을 보내는 통로가 된다.
#  3) **임시 터널 주소로 출시되는 것.** trycloudflare/ngrok 호스트는 수명이 짧고,
#     터널이 죽으면 그 이름을 남이 다시 잡을 수 있다. 그 상태로 출시된 앱은
#     학생 로그인 정보를 모르는 서버로 보낸다. 정식 도메인으로 바꾼 뒤 출시한다.
#     ※ 이 검사(소스의 defaultURL 선언 기준)는 Xcode 타깃의 "Release 서버 주소 게이트"
#     Run Script 페이즈가 Release 빌드마다 자동으로도 수행한다 — 사람이 이 스크립트를
#     잊어도 빌드가 먼저 실패한다. 여기서는 최종 바이너리를 사후 감사(다층 방어)한다.
#
# 함정 12(Release 검증 후 Debug 로 되돌리기)를 피하려고 파생 데이터를 따로 쓴다.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DD="${DD:-/tmp/matths-rel}"
APP="${APP:-$DD/Build/Products/Release-iphoneos/Matths.app}"
BIN="$APP/Matths"

# macOS `strings` 는 기본 설정에서 UTF-8 한글을 출력하지 않을 수 있다.
# 출시 바이너리 원문을 C locale 의 고정 바이트열로 직접 검색해 한글 DEBUG 문구도 잡는다.
count_fixed_bytes() { # 바이너리, 검색할 고정 문자열
  LC_ALL=C grep -aF -o -- "$2" "$1" 2>/dev/null | wc -l | tr -d '[:space:]'
}

binary_scanner_self_test() {
  local fixture marker detected
  marker="개발 서버 미리보기 코드"
  fixture="$(mktemp "${TMPDIR:-/tmp}/matths-release-scanner.XXXXXX")" || return 1
  # 실제 Mach-O 처럼 NUL 바이트 사이에 UTF-8 문자열이 있어도 탐지해야 한다.
  printf '\000release-prefix\000%s\000release-suffix\000' "$marker" > "$fixture"
  detected="$(count_fixed_bytes "$fixture" "$marker")"
  rm -f -- "$fixture"
  [ "$detected" -eq 1 ]
}

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo "▶ Release 빌드…"
  xcodebuild -project "$HERE/Matths.xcodeproj" -scheme Matths -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$DD" \
    -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD" | tail -3
  build_status=${PIPESTATUS[0]}
  if [ "$build_status" -ne 0 ]; then
    echo "✗ Release 빌드가 실패했다 — 이전 DerivedData 바이너리를 감사하지 않는다"
    exit "$build_status"
  fi
fi

[ -f "$BIN" ] || { echo "✗ Release 바이너리가 없다: $BIN"; exit 2; }

if binary_scanner_self_test; then
  echo "✓ Release 바이너리 스캐너 양성 대조 통과"
else
  echo "✗ Release 바이너리 스캐너가 UTF-8 양성 대조를 탐지하지 못했다"
  exit 3
fi

fail=0
report() { # 이름, 개수, 기대(0)
  if [ "$2" -eq 0 ]; then printf "  ✓ %-26s 없음\n" "$1"
  else printf "  ✗ %-26s %s건 발견\n" "$1" "$2"; fail=$((fail+1)); fi
}

echo
echo "[1/6] 비밀정보"
for s in "mongodb" "mongodb+srv" "API_TOKEN_SECRET" "EMAIL_API_KEY" "SECRET="; do
  report "$s" "$(count_fixed_bytes "$BIN" "$s")"
done

echo
echo "[2/6] DEBUG 전용 통로"
# "개발 서버 미리보기 코드": 비밀번호 재설정 코드를 화면에 그대로 보여주는 개발 편의 문구.
# 출시판에 남으면 운영 서버가 메일 키를 잃는 순간 계정 탈취 통로가 된다 — #if DEBUG 회귀를 기계로 잡는다.
for s in "서버 주소 (개발용)" "기록 보기 (디버그)" "채점 기록 · 디버그" \
         "개발 서버 미리보기 코드" \
         "LESSON-DEBUG" "-fakeAnalysis" "-fakeTrace" "-proReport"; do
  report "$s" "$(count_fixed_bytes "$BIN" "$s")"
done

echo
echo "[3/6] 서버 주소"
report "변경 가능한 모델 /resolve/main" "$(count_fixed_bytes "$BIN" "/resolve/main/")"
hosts=$(strings "$BIN" | grep -oE "https://[a-zA-Z0-9._/-]+" | grep -v "huggingface.co" | sort -u)
if [ -z "$hosts" ]; then
  echo "  ✗ API 주소가 하나도 없다 — 빌드가 잘못됐다"; fail=$((fail+1))
else
  while IFS= read -r h; do
    case "$h" in
      https://www.matths.kr|https://www.matths.kr/*)
        echo "  ✓ $h" ;;
      *)
        echo "  ✗ 운영 정본이 아닌 API 주소다: $h"
        echo "     → ServerAPI.defaultURL 을 https://www.matths.kr 로 고정한 뒤 다시 돌려라."
        fail=$((fail+1)) ;;
    esac
  done <<< "$hosts"
fi

echo
echo "[4/6] 커리큘럼 5분 해설 번들"
curriculum_status=0
curriculum_output="$("$HERE/scripts/verify-curriculum-story-bundle.sh" "$APP" 2>&1)" \
  || curriculum_status=$?
if [ "$curriculum_status" -eq 0 ]; then
  echo "  ✓ $curriculum_output"
else
  echo "  ✗ 커리큘럼 5분 해설 번들 실패: $curriculum_output"
  fail=$((fail+1))
fi

echo
echo "[5/6] 개념 코드 애니메이션 번들 동봉"
# 왜 검사하는가: 이 자산은 한때 Application Support 에서만 읽혔고, 그 자리를 채우는
# 것은 개발자 맥의 push-concept-motion.sh 뿐이었다. 그래서 TestFlight·App Store
# 설치본은 개념학습 220개가 통째로 빈 화면이었다 — 개발자 맥에서는 멀쩡히 보였으므로
# 사람 눈으로는 절대 잡히지 않는 종류의 사고다. 이제 번들에 동봉하고, 그 동봉이
# 실제로 이뤄졌는지 출시 바이너리에서 되읽어 확인한다.
CM="$APP/ConceptMotion"
if [ ! -d "$CM" ]; then
  echo "  ✗ 번들에 ConceptMotion/ 이 없다 — scripts/sync-concept-motion-bundle.sh 를 돌린 뒤 다시 빌드하라"
  fail=$((fail+1))
else
  cm_html=$(ls -1 "$CM/compositions"/*.html 2>/dev/null | grep -cv '\.female\.html$' || true)
  cm_female=$(ls -1 "$CM/compositions"/*.female.html 2>/dev/null | wc -l | tr -d ' ')
  cm_voice=$(find "$CM/assets/voice" -name full.mp3 2>/dev/null | wc -l | tr -d ' ')
  cm_voice_f=$(find "$CM/assets/voice-female" -name full.mp3 2>/dev/null | wc -l | tr -d ' ')
  cm_fonts=$(ls -1 "$CM/assets/fonts"/*.woff2 2>/dev/null | wc -l | tr -d ' ')
  # 220 은 커리큘럼 개념 수다. 하나라도 모자라면 그 개념만 조용히 벡터 무대로
  # 내려가므로, "대충 많으면 통과" 가 아니라 정확히 220 을 요구한다.
  # 출시 번들은 용량 정책상 여성 음성 한 벌만 싣는다. 남성 음성 220개까지
  # 요구하면 sync-concept-motion-bundle.sh 가 의도대로 만든 정상 IPA를 거부한다.
  # 반대로 남성 음성이 일부만 섞인 상태도 허용하면 다운로드 용량만 늘고 앱의
  # 선택지가 개념마다 들쭉날쭉해지므로 정확히 0개를 요구한다.
  for pair in "컴포지션:$cm_html:220" "여성 컴포지션:$cm_female:220" \
              "남성 음성:$cm_voice:0" "여성 음성:$cm_voice_f:220"; do
    name=${pair%%:*}; rest=${pair#*:}; got=${rest%%:*}; want=${rest#*:}
    if [ "$got" -eq "$want" ]; then printf "  ✓ %-14s %s개\n" "$name" "$got"
    else printf "  ✗ %-14s %s개 (기대 %s)\n" "$name" "$got" "$want"; fail=$((fail+1)); fi
  done
  if [ "$cm_fonts" -ge 1 ]; then echo "  ✓ 폰트           ${cm_fonts}개"
  else echo "  ✗ 폰트 서브셋이 없다 — 컴포지션이 두부 글자로 나온다"; fail=$((fail+1)); fi
  if [ -f "$CM/vendor/gsap.min.js" ]; then echo "  ✓ GSAP 로컬 사본"
  else echo "  ✗ vendor/gsap.min.js 가 없다 — 오프라인 교실에서 무대가 서지 않는다"; fail=$((fail+1)); fi
  # 트리 모양이 어긋나면 컴포지션의 <base href=\"../\"> 가 음성·폰트를 못 찾는다.
  # 평탄화(compositions/ 가 사라지고 최상단에 흩어짐)는 이 검사로만 잡힌다.
  if [ -d "$CM/compositions" ] && [ -d "$CM/assets" ]; then echo "  ✓ 트리 모양 (compositions/ + assets/)"
  else echo "  ✗ 번들 안에서 트리가 평탄화됐다 — 폴더 참조가 아니라 그룹으로 들어간 것이다"; fail=$((fail+1)); fi
  echo "  · 동봉 용량 $(du -sh "$CM" | cut -f1)"
fi

echo
echo "[6/6] 앱 아이콘"
# 앱스토어는 **알파 채널이 있는 1024 아이콘을 거부한다**
# ("Invalid large app icon … can't be transparent or contain an alpha channel").
# 실제로 이 저장소의 아이콘 두 장에 모서리 라운딩 때문에 투명 픽셀이 있었다
# (2026-07-29). 업로드하고 나서야 알게 되면 제출이 한 판 통째로 밀린다.
ICONSET="Matths/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICONSET" ]; then
  for png in "$ICONSET"/*.png; do
    [ -e "$png" ] || continue
    mode=$(python3 -c "from PIL import Image;im=Image.open('$png');print(im.mode,im.size[0])" 2>/dev/null || echo "?")
    case "$mode" in
      RGBA*|LA*|PA*)
        echo "  ✗ $(basename "$png") 에 알파 채널이 있다 — 업로드가 거부된다"
        echo "     → 배경색 위로 평탄화해 RGB 로 저장하라"
        fail=$((fail+1)) ;;
      "?") echo "  · $(basename "$png") 검사 건너뜀 (Pillow 없음)" ;;
      *)  echo "  ✓ $(basename "$png") ($mode)" ;;
    esac
  done
else
  echo "  ✗ AppIcon.appiconset 이 없다"; fail=$((fail+1))
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "✅ Release 바이너리 감사 통과 — 서명 아카이브·자산 카탈로그·App Store 제출은 별도 검증"
else
  echo "❌ 실패 $fail 건 — 위 항목을 고치기 전에는 출시하지 마라"
fi
exit "$fail"
