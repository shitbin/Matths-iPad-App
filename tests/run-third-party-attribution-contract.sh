#!/bin/sh
# 번들에 들어가는 서드파티가 프로필의 고지 목록에도 있는지 묶는다.
#
# 막으려는 사고 (2026-08-21):
#   ProfileScreen 의 고지 목록 주석은 "번들·다운로드로 탑재되는 서드파티 전부"
#   라고 적혀 있었는데, 개념 모션 220편을 돌리는 GSAP 이 빠져 있었다. GSAP 은
#   오프라인 교실용 로컬 사본으로 번들에 실제로 들어간다
#   (scripts/sync-concept-motion-bundle.sh, ConceptMotionWebStage.swift:65).
#
#   목록이 스스로 선언한 계약을 어겼는데 아무도 못 잡았다. 목록은 손으로만
#   늘어나므로, 자산이 늘 때 고지가 따라오지 않으면 조용히 어긋난다.
#
# 이 테스트는 "번들에 넣는다고 선언한 파일"과 "고지 목록의 이름"을 잇는다.
# 새 서드파티를 실으면 여기 한 줄을 같이 늘려야 한다 — 그게 목적이다.
#
# 실행: sh tests/run-third-party-attribution-contract.sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
profile="$root/Matths/ProfileScreen.swift"
sync="$root/scripts/sync-concept-motion-bundle.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 이름이 **배열 항목**으로 있는지 본다. 그냥 낱말로 찾으면 바로 위에 붙은 주석에
# 걸려서, 항목을 지워도 통과한다. 실제로 이 테스트를 쓰면서 그렇게 새어 나갔다.
listed() {
  grep -Eq '^[[:space:]]*\("[^"]*'"$1"'[^"]*",' "$profile"
}

# 번들 선언 → 고지에 있어야 할 이름
#   "찾을 파일 표식|고지 목록에 있어야 하는 문자열|어디서 실리는가"
check_pair() {
  marker="$1"; needle="$2"; where="$3"; haystack="$4"
  grep -Fq "$marker" "$haystack" || return 0      # 안 싣는다면 검사할 것도 없다
  listed "$needle" \
    || fail "$where 가 $marker 를 번들에 넣는데 고지 목록에 '$needle' 항목이 없습니다."
}

check_pair "vendor/gsap.min.js" "GSAP" "sync-concept-motion-bundle.sh" "$sync"

# 저장소에 그대로 들어 있는 것들
for pair in \
  "LessonWeb/katex.min.js|KaTeX" \
  "LessonWeb/lottie_light.min.js|lottie-web" \
  "LessonWeb/PretendardVariable.woff2|Pretendard"
do
  marker=$(printf '%s' "$pair" | cut -d'|' -f1)
  needle=$(printf '%s' "$pair" | cut -d'|' -f2)
  [ -e "$root/Matths/$marker" ] || continue
  listed "$needle" \
    || fail "Matths/$marker 를 번들에 싣는데 고지 목록에 '$needle' 항목이 없습니다."
done

# ── 성격을 잘못 부르지 않는다 ───────────────────────────────────────────────
# GSAP 은 "All rights reserved" 인 독자 라이선스라 OSI 오픈소스가 아니다.
# 목록에 그런 항목이 있으면 제목을 "오픈소스"라고 붙일 수 없다.
if grep -Fq "GreenSock Standard License" "$profile"; then
  grep -Eq 'Text\(KiceBank.exams.isEmpty \? "오픈소스' "$profile" \
    && fail "오픈소스가 아닌 항목이 있는데 고지 제목이 '오픈소스'입니다."
  grep -Fq '"서드파티 라이선스"' "$profile" \
    || fail "고지 제목이 '서드파티'로 되어 있지 않습니다."
fi

# ── DEBUG 전용 실험 모델은 고지 대상이 아니다(싣지 않으므로) ────────────────
# 다만 Release 진입이 열리는 순간 고지가 필요하다. 그 게이트가 살아 있는지 본다.
grep -Fq 'shippingEligible: false' "$root/Matths/ExperimentalLocalModelCatalog.swift" \
  || fail "실험 모델이 Release 대상이 됐습니다. 고지·라이선스 검토가 먼저입니다."

echo "PASS: 번들 서드파티가 모두 고지 목록에 있습니다."
