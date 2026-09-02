#!/bin/sh
set -eu

# 데모 모드(DEBUG 전용)의 전송 계약과 게시판 목업 배선을 지킨다.
#
# 왜 이 검사가 필요한가 — 전부 실제로 한 번씩 무너졌던 것들이다.
#   ① authorizedRequest(PDF 다운로드·multipart 업로드)가 데모 분기 없이 토큰을 요구해
#      "시험장 입장 → 시작" 이 401 로 끝났다.
#   ② 새 목업 HTML 을 DemoWeb/ 에 넣기만 하고 프로젝트의 membershipExceptions 에
#      안 넣으면, 동기화 폴더 그룹이 그 파일을 번들 최상단으로 평탄화해
#      **Release 번들에도 데모 목업이 실린다**(Debug 에서는 아무 증상이 없다).
#   ③ 목업끼리 거는 링크가 없는 파일을 가리키면 file:// 웹뷰가 통째로 시스템 오류
#      화면으로 넘어가 감독의 목업 순회가 그 자리에서 끊긴다.

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
demo="$root/Matths/DemoMode.swift"
api="$root/Matths/ServerAPI.swift"
screen="$root/Matths/CommunityScreen.swift"
web="$root/Matths/DemoWeb"
project="$root/Matths.xcodeproj/project.pbxproj"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# ── ① JSON 이외 경로도 데모에서 끝난다 ────────────────────────────────
grep -Fq 'if DemoMode.isOn {' "$api" || fail "ServerAPI 에 데모 분기가 없습니다."
grep -Fq 'private static let stateLock = NSLock()' "$demo" || fail "데모 공유 상태를 보호하는 lock이 없습니다."
grep -Fq 'storedMissingRoutes.insert(key)' "$demo" || fail "missing route 기록이 잠금 대상 저장소를 쓰지 않습니다."
grep -Fq 'private static let resolveLock = NSLock()' "$demo" || fail "동시 날짜 토큰 치환 보호가 없습니다."
grep -Fq 'private static let routeLock = NSLock()' "$demo" || fail "동시 데모 라우팅 보호가 없습니다."
# authorizedRequest 안의 분기가 토큰 검사보다 **앞**에 있어야 한다.
auth_line=$(grep -n 'static func authorizedRequest' "$api" | head -1 | cut -d: -f1)
demo_line=$(awk -v start="$auth_line" 'NR > start && /if DemoMode.isOn \{/ { print NR; exit }' "$api")
token_line=$(awk -v start="$auth_line" 'NR > start && /guard let token = TokenBox.load\(\)/ { print NR; exit }' "$api")
[ -n "$demo_line" ] || fail "authorizedRequest 에 데모 분기가 없습니다(PDF 다운로드가 401 로 막힙니다)."
[ -n "$token_line" ] || fail "authorizedRequest 의 토큰 검사를 찾지 못했습니다."
[ "$demo_line" -lt "$token_line" ] \
  || fail "authorizedRequest 의 데모 분기가 토큰 검사보다 뒤에 있습니다(데모에 토큰이 없어 401 이 납니다)."

# 데모 요청은 해석되지 않는 호스트로만 나간다 — 가로채기가 안 걸려도 운영 서버로 새면 안 된다.
grep -Fq 'static let networkHost = "demo.matths.invalid"' "$demo" \
  || fail "데모 전용 호스트가 .invalid 예약 TLD 가 아닙니다."
grep -Fq 'URLProtocol.registerClass(DemoURLProtocol.self)' "$demo" \
  || fail "DemoURLProtocol 을 등록하지 않습니다."
grep -Fq 'DemoURLProtocol.installOnce()' "$demo" \
  || fail "데모 슬롯 진입에서 가로채기를 설치하지 않습니다."

# 프로필의 튜토리얼 재시작은 PATCH 성공 → GET /me의 PENDING 상태 → 실제
# 네이티브 오버레이까지 이어져야 한다. 정적 프로필만 돌려주면 버튼은 보여도
# "픽스처가 없는 경로" 오류로 끝나므로 두 튜토리얼 왕복을 모두 고정한다.
for route in \
  'POST /api/v1/auth/social/exchange' \
  'PATCH /api/v1/me/tutorials/dashboard' \
  'PATCH /api/v1/me/tutorials/arena'
do
  grep -Fq "$route" "$demo" || fail "소셜 로그인/튜토리얼 데모 경로가 없습니다: $route"
done

for route in \
  'GET /api/v1/goat-arena/profile/payback-account' \
  'POST /api/v1/goat-arena/profile/payback-account/confirm'
do
  grep -Fq "$route" "$demo" || fail "페이백 계좌 데모 경로가 없습니다: $route"
done
grep -Fq 'static let paybackAccountStatus' "$root/Matths/DemoFixtures/DemoFixturesArena.swift" \
  || fail "페이백 계좌 마스킹 상태 픽스처가 없습니다."
grep -Fq 'static func paybackAccountConfirmation' "$root/Matths/DemoFixtures/DemoFixturesArena.swift" \
  || fail "페이백 계좌 저장 결과 픽스처가 없습니다."
grep -Fq 'dashboardTutorialStatus == "PENDING" ? "true" : "false"' "$demo" \
  || fail "대시보드 재시작 뒤 GET /me가 자동 시작 상태를 돌려주지 않습니다."
grep -Fq '"common", "unranked", "unranked_match", "ranked", "ranked_battle", "ranked_shop"' "$demo" \
  || fail "Arena 튜토리얼 6개 챕터가 데모 프로필에 없습니다."

# 세 개의 비 JSON 경로가 모두 준비되어 있어야 한다.
for route in \
  '"api", "v1", "weekly-mock-exams", "{examId}", "paper"' \
  '"api", "v1", "weekly-mock-exams", "integrity-cases", "{caseId}", "evidence"' \
  '"api", "v1", "goat-arena", "matches", "{matchId}", "evidence"'
do
  grep -Fq "$route" "$demo" || fail "DemoBinaryRouter 에 경로가 없습니다: $route"
done

# 시험지는 진짜 PDF 여야 한다(WeeklyMockAPI 가 앞 5바이트를 검사한다).
grep -Fq 'contentType: "application/pdf"' "$demo" || fail "데모 시험지를 PDF 로 돌려주지 않습니다."
grep -Fq 'UIGraphicsPDFRenderer' "$demo" || fail "데모 시험지 PDF 를 생성하지 않습니다."

# 응시할 수 있는 회차가 하나는 있어야 시험지 다운로드 경로가 실행된다.
grep -Fq 'enum DemoWeeklyMockLive' "$demo" || fail "응시 가능한 데모 회차 픽스처가 없습니다."
grep -Fq 'started ? "in-progress" : "lobby"' "$demo" \
  || fail "데모 회차가 대기실→응시중 상태를 만들지 않습니다(시험지 다운로드가 실행되지 않습니다)."

# ── ② DemoWeb 목업이 전부 Release 격리 예외 목록에 있다 ───────────────
missing=""
for file in "$web"/*; do
  [ -f "$file" ] || continue
  name=$(basename "$file")
  grep -Fq "DemoWeb/$name" "$project" || missing="$missing $name"
done
[ -z "$missing" ] && : || fail "membershipExceptions 에 빠진 DemoWeb 파일:$missing
  → 그대로 두면 동기화 그룹이 번들 최상단으로 평탄화해 Release 에도 실립니다."

# ── ③ 목업이 거는 링크가 전부 존재한다 ────────────────────────────────
broken=""
for file in "$web"/*.html; do
  # href="community-xxx.html" 형태만 본다(#, http, 앵커는 대상이 아니다).
  for target in $(sed -n 's/.*href="\([a-z0-9-]*\.html\)".*/\1/p' "$file" | sort -u); do
    [ -f "$web/$target" ] || broken="$broken $(basename "$file")→$target"
  done
done
[ -z "$broken" ] && : || fail "없는 목업으로 거는 링크(웹뷰가 시스템 오류 화면으로 넘어갑니다):$broken"

# ── ④ 앱이 지정해 여는 경로가 모두 실재하는 목업으로 간다 ─────────────
for target in $(sed -n 's/.*return "\(community[a-z0-9-]*\.html\)".*/\1/p' "$screen" | sort -u); do
  [ -f "$web/$target" ] || fail "CommunityScreen 이 없는 목업을 가리킵니다: $target"
done
grep -Fq 'community-operations.html' "$screen" || fail "운영 게시판(board=operations) 매핑이 없습니다."
grep -Fq 'community-search.html' "$screen" || fail "검색 결과 매핑이 없습니다."

# 실서버 첫 문서가 늦을 때 WKWebView 배경만 보이면 앱이 멈춘 것으로 보인다.
# 첫 완료 전에는 명시적인 로딩 카드가 있어야 하고, 계정 전환(openFresh)에서는
# 이전 계정의 문서가 잠깐 비치지 않게 표시 완료 상태를 반드시 초기화한다.
grep -Fq 'if model.isLoading && !model.hasDisplayedPage' "$screen" \
  || fail "게시판 첫 문서 로딩 중 빈 화면을 가리는 상태 UI가 없습니다."
grep -Fq 'Text("게시판을 불러오는 중입니다")' "$screen" \
  || fail "게시판 초기 로딩 안내 문구가 없습니다."
grep -Fq 'hasDisplayedPage = false' "$screen" \
  || fail "게시판 계정 전환/실패 시 이전 문서 표시 상태를 초기화하지 않습니다."
grep -Fq 'hasDisplayedPage = true' "$screen" \
  || fail "게시판 문서 로드 완료 상태를 기록하지 않습니다."

# 첫 라우트 전환의 0pt 배치에서 로드를 시작하면 문서는 받아도 첫 화면만 빈다.
grep -Fq 'guard viewport.size.width > 1, viewport.size.height > 1' "$screen" \
  || fail "게시판 최초 로드가 실제 뷰포트 확정 전 시작될 수 있습니다."
grep -Fq 'await Task.yield()' "$screen" \
  || fail "게시판 최초 로드가 레이아웃 런루프를 기다리지 않습니다."
grep -Fq 'CommunityWebHostView(webView: model.webView)' "$screen" \
  || fail "공유 WKWebView를 새 SwiftUI 호스트에 격리하지 않습니다."
grep -Fq 'static func dismantleUIView' "$screen" \
  || fail "게시판 호스트 해제 시 공유 WKWebView를 분리하지 않습니다."

# ── ⑤ 감독이 볼 상태 목업이 실제로 다 있다 ────────────────────────────
for name in \
  community.html community-school.html community-operations.html \
  community-search.html community-empty.html community-announcement.html \
  community-guest.html community-school-guest.html community-post-guest.html \
  community-new-restricted.html community-new-quota.html
do
  [ -f "$web/$name" ] || fail "게시판 상태 목업이 없습니다: $name"
done

# 상태 이동줄은 모든 목업에 있어야 감독이 어디서든 다른 상태로 건너뛸 수 있다.
for file in "$web"/community*.html; do
  grep -Fq 'class="demo-state-bar"' "$file" \
    || fail "데모 상태 이동줄이 없습니다: $(basename "$file")"
done

# 라벨을 모노스페이스로 그리면 한글이 두부(▯)가 된다(iPad 웹뷰 실측).
# 선언(font-family:)만 본다 — 이유를 적어 둔 주석의 "monospace" 는 잡지 않는다.
if awk '/^\.demo-state-bar > span \{/ { inrule = 1 }
        inrule && /^\}/ { inrule = 0 }
        inrule && /font-family:/ { print }' "$web/demo-extras.css" | grep -Fq 'monospace'; then
  fail ".demo-state-bar 라벨에 monospace 를 쓰면 한글이 두부로 그려집니다."
fi

echo "Demo transport, mockup wiring, and Release isolation contracts passed"
