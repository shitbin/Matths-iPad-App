#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="$ROOT/Matths/CommerceAPI.swift"
HUB="$ROOT/Matths/CommerceHubScreen.swift"
APP="$ROOT/Matths/MatthsApp.swift"
ROOT_VIEW="$ROOT/Matths/RootView.swift"
PROFILE="$ROOT/Matths/ProfileScreen.swift"
SERVICE_HUB="$ROOT/Matths/ServiceHubScreen.swift"
ARENA="$ROOT/Matths/GoatArenaScreen.swift"
SERVER_API="$ROOT/Matths/ServerAPI.swift"
COMMUNITY="$ROOT/Matths/CommunityScreen.swift"
ARENA_WEB_MODEL="$ROOT/Matths/ArenaWeb/ArenaWebModel.swift"
ARENA_WEB_SCREEN="$ROOT/Matths/ArenaWeb/ArenaWebScreen.swift"
IAP="$ROOT/Matths/MatthsIAP.swift"
STOREKIT="$ROOT/Matths.storekit"

for file in "$API" "$HUB" "$APP" "$ROOT_VIEW" "$PROFILE" "$SERVICE_HUB" "$ARENA"; do
  test -f "$file" || { echo "missing commerce source: $file" >&2; exit 1; }
done

grep -q '"/api/v1/commerce/storefront"' "$API"
grep -q '"/api/v1/commerce/handoffs"' "$API"
grep -q 'authed: true' "$API"

# ─── iOS 결제 경계 ────────────────────────────────────────────────────────────
#
# 이 검사의 방향이 2026-08-20 에 **뒤집혔다.**
#
# 전에는 "이 화면이 SFSafariViewController 로 서버 결제창을 연다"를 지켰다. 그런데
# 앱 안에서 쓰는 디지털 콘텐츠를 외부 결제로 파는 것은 심사지침 3.1.1 정면 위반이다.
# 그래서 iOS 에서는 그 길을 닫고 App Store 인앱 결제만 남겼다.
#
# 아래는 **없어야 할 것**을 지킨다. 누군가 편의를 위해 웹 결제를 되살리면 여기서 걸린다.
# 되살리는 순간 심사에서 반려되고, 반려는 재제출까지 며칠을 먹는다.

# 패턴은 **코드에만 걸리게** 잡는다. 맨 단어로 찾으면 "왜 이걸 쓰면 안 되는가" 를
# 설명한 주석이 스스로 걸린다 — 실제로 한 번 걸렸다. 그러면 다음 사람은 검사를
# 못 믿게 되고, 못 믿는 검사는 결국 꺼진다.
for banned in '^import SafariServices' 'SFSafariViewController\(' 'func openHandoff' 'mode: "parent-request"'; do
  if grep -qE "$banned" "$HUB"; then
    echo "CommerceHubScreen 에 외부 결제 경로가 되살아났습니다: $banned" >&2
    echo "iOS 앱 안의 디지털 콘텐츠 결제는 App Store 인앱 결제만 허용됩니다 (심사지침 3.1.1)." >&2
    exit 1
  fi
done

# 인앱 결제가 실제로 붙어 있어야 한다.
test -f "$IAP" || { echo "missing StoreKit source: $IAP" >&2; exit 1; }
test -f "$STOREKIT" || { echo "missing StoreKit configuration: $STOREKIT" >&2; exit 1; }
grep -q 'import StoreKit' "$IAP"
grep -q 'kr.matths.app.pass.29d' "$IAP"
grep -q 'kr.matths.app.mock.30d' "$IAP"
grep -q 'LEARNING_PACKAGE_29' "$IAP"
grep -q 'MOCK_EXAM_ONLY' "$IAP"
grep -q '"/api/v1/commerce/apple/redeem"' "$IAP"
grep -q 'App Store 계정을 확인한 뒤 구매 복원을 다시 시도해 주세요.' "$IAP"
grep -q 'App Store 연결을 확인한 뒤 다시 시도해 주세요.' "$IAP"
grep -q '1개월 자동 갱신 · 결제마다 29일 학습 사이클' "$HUB"
grep -q '한 달마다 자동 갱신됩니다' "$HUB"

# 로컬 StoreKit 검수도 App Store Connect의 실제 상품과 같은 ID·가격을 써야 한다.
# 서버 storefront가 보여 주는 원화 fallback과 테스트 가격이 다르면, 캡처에서는
# 멀쩡해 보여도 Sandbox에서 상품이 도착하는 순간 금액이 바뀐다.
python3 - "$STOREKIT" <<'CHECK'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
application_internal_id = data.get("settings", {}).get("_applicationInternalID")
if application_internal_id != "6803569629":
    raise SystemExit(
        f"StoreKit app Apple ID mismatch: {application_internal_id}"
    )
products = {
    item["productID"]: item
    for group in data.get("subscriptionGroups", [])
    for item in group.get("subscriptions", [])
}
expected = {
    "kr.matths.app.pass.29d": ("6803570339", "29000"),
    "kr.matths.app.mock.30d": ("6803570684", "5500"),
}
if set(products) != set(expected):
    raise SystemExit(f"StoreKit product IDs mismatch: {sorted(products)}")
for product_id, (internal_id, price) in expected.items():
    item = products[product_id]
    if item.get("internalID") != internal_id:
        raise SystemExit(f"{product_id} internalID mismatch: {item.get('internalID')}")
    if item.get("displayPrice") != price:
        raise SystemExit(f"{product_id} local review price mismatch: {item.get('displayPrice')}")
    localizations = item.get("localizations", [])
    if not localizations:
        raise SystemExit(f"{product_id} needs at least one localization")
    for localization in localizations:
        name = localization.get("displayName", "")
        description = localization.get("description", "")
        if not 2 <= len(name) <= 30:
            raise SystemExit(f"{product_id} display name is outside 2...30 characters")
        if len(description) > 45:
            raise SystemExit(f"{product_id} description exceeds 45 characters")
CHECK

# 구입 요청(Ask to Buy)·갱신·환불은 구매 화면 밖에서 도착한다. 리스너가 없으면
# 부모가 승인해도 학생의 학습권이 열리지 않는다.
grep -q 'Transaction.updates' "$IAP"
grep -q 'Transaction.unfinished' "$IAP"
grep -q 'MatthsIAPStore.shared.start()' "$APP"
grep -q 'bindAppleAppAccountToken' "$IAP"
grep -q 'let ownerSlot = DataScope.slot' "$IAP"
grep -q 'authorization: authorization' "$IAP"
grep -q '/api/v1/commerce/apple/account-token' "$IAP"
python3 - "$IAP" <<'CHECK'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
purchase = src[src.index("func purchase(_ item:"):src.index("    /// 기기 변경", src.index("func purchase(_ item:"))]
capture = purchase.index("captureAuthorization()")
bind = purchase.index("bindAppleAppAccountToken")
sheet = purchase.index("product.purchase")
if not capture < bind < sheet:
    raise SystemExit("IAP 계정 스냅샷/토큰 바인딩이 구매 시트보다 먼저 실행되지 않습니다")
if ".appAccountToken(boundToken)" not in purchase:
    raise SystemExit("서버에 귀속한 appAccountToken을 StoreKit 구매에 쓰지 않습니다")
redeem = src[src.index("private func redeem("):src.index("    /// 지난 실행", src.index("private func redeem("))]
if "suppliedAuthorization ?? ServerAPI.captureAuthorization()" not in redeem:
    raise SystemExit("지연 승인 redeem에 인증 스냅샷 경계가 없습니다")
if "authorization: authorization" not in redeem:
    raise SystemExit("redeem 요청이 캡처한 Bearer를 전달하지 않습니다")
CHECK

# 서버가 권한을 준 **뒤에만** finish() 한다. 순서가 뒤집히면 결제는 됐는데 학습권이
# 없는 상태가 복구 불가능해진다.
python3 - "$IAP" <<'CHECK'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
body = src[src.index("private func redeem("):]
body = body[:body.index("\n    /// 지난 실행")]
grant = body.index("redeemAppleTransaction")
finish = body.index("await transaction.finish()", grant)
if finish < grant:
    sys.exit("redeem(): 서버 권한 부여보다 finish() 가 먼저입니다")
CHECK

# 복원 경로는 애플이 요구한다. 기기를 바꾼 학생이 이미 산 이용권을 되찾을 길.
grep -q 'func restore()' "$IAP"
grep -q 'AppStore.sync()' "$IAP"
grep -q '구매 내역 복원' "$HUB"
grep -q 'var syncError: String?' "$IAP"
grep -q 'if restored > 0' "$IAP"
grep -q '구매 내역을 복원했습니다' "$IAP"
grep -q '구매 복원 결과' "$HUB"
grep -q 'preservingFeedback: Bool = false' "$IAP"
grep -q 'load(preservingPurchaseFeedback: true)' "$HUB"

# 자동갱신 구독 고지 — 애플이 구매 화면에 요구하는 항목이다.
# 이용약관·개인정보처리방침 링크가 없으면 심사지침 3.1.2 로 반려된다.
# 상품 설명에 적는 것으로는 부족하고 구매 버튼이 있는 화면에서 손이 닿아야 한다.
grep -q '이용약관' "$HUB"
grep -q '개인정보처리방침' "$HUB"
grep -q 'Link(' "$HUB"
grep -q '자동으로 갱신' "$HUB"
grep -q '해지' "$HUB"
grep -q 'Ranked 상점은.*서로 다른 지갑' "$HUB"
grep -q 'if compactHeight' "$HUB"
grep -q 'private var compactHeader' "$HUB"
grep -q 'compactAccessSummary(storefront.access)' "$HUB"
grep -q 'if !compactHeight || dynamicTypeSize.isAccessibilitySize' "$HUB"
grep -q 'if dynamicTypeSize.isAccessibilitySize' "$HUB"
grep -q '.frame(minHeight: 24)' "$HUB"
grep -q '.background(Tokens.paper2, in: RoundedRectangle' "$HUB"
grep -q 'compactProductRow(product, checkoutEnabled: checkoutEnabled)' "$HUB"
grep -q '결제·환불은 Apple 계정에서 처리' "$HUB"
grep -q '이용권은 App Store 결제 · Ranked 기능은 학습일 사용' "$HUB"
grep -q 'if let storeProduct' "$HUB"
grep -q 'Label("가격 다시 불러오기", systemImage: "arrow.clockwise")' "$HUB"
grep -q 'Task { await iap.loadProducts() }' "$HUB"
grep -q 'let missingIDs = MatthsProduct.allIdentifiers.subtracting(fetchedIDs)' "$IAP"
grep -q '일부 App Store 상품을 불러오지 못했습니다' "$IAP"
grep -q '현재 판매가 잠시 중지되었습니다' "$HUB"
grep -q 'access.rankedShopAvailable' "$HUB"
grep -q 'store.route = \.arenaShop' "$HUB"
grep -q 'store.route = \.rank' "$HUB"

grep -q 'case .*commerce' "$APP"
grep -q 'store.route == \.commerce' "$ROOT_VIEW"
grep -q 'CommerceHubScreen()' "$ROOT_VIEW"
grep -q 'store.route = \.services' "$PROFILE"
grep -q 'Text("학원·서비스")' "$PROFILE"
grep -q 'store.route = \.commerce' "$SERVICE_HUB"
grep -q 'title: "이용권과 Ranked 상점"' "$SERVICE_HUB"
grep -q 'store.route = \.commerce' "$ARENA"
grep -q 'Label("상점·이용권"' "$ARENA"
grep -q 'heroButton("이용권과 상점 보기"' "$ARENA"

# 로그인 쿠키를 잇는 게시판·Arena 웹뷰에서도 웹 가격/Toss 결제로 빠질 수 없어야 한다.
# 최초 세션 핸드오프만 예외이고, 이후 같은 호스트 결제 링크는 StoreKit 화면으로 보낸다.
for purchase_root in '/pricing' '/checkout' '/payments' '/parent/pricing' '/parent/checkout' '/parent/payments' '/app/commerce'; do
  grep -Fq "\"$purchase_root\"" "$SERVER_API"
done
grep -Fq 'static func isWebPurchaseSurface(_ url: URL) -> Bool' "$SERVER_API"
grep -Fq 'ServerAPI.isWebPurchaseSurface(url)' "$COMMUNITY"
grep -Fq 'ServerAPI.isWebPurchaseSurface(url)' "$ARENA_WEB_MODEL"
grep -Fq '@Published var wantsNativeCommerce = false' "$COMMUNITY"
grep -Fq '@Published var wantsNativeCommerce = false' "$ARENA_WEB_MODEL"
grep -Fq 'store.route = .commerce' "$COMMUNITY"
grep -Fq 'object: AppStore.Route.commerce' "$ARENA_WEB_SCREEN"
python3 - "$COMMUNITY" "$ARENA_WEB_MODEL" <<'CHECK'
import sys
for filename in sys.argv[1:]:
    source = open(filename, encoding="utf-8").read()
    redirect = source.index('if handingOff, isServerHost(url), url.path == "/pricing"')
    token = source.index('if handingOff, isServerHost(url), url.path.hasPrefix("/app/commerce/")', redirect)
    boundary = source.index('if isServerHost(url), ServerAPI.isWebPurchaseSurface(url)', token)
    if not redirect < token < boundary:
        raise SystemExit(f"handoff exceptions do not precede native commerce boundary: {filename}")
    if 'if isServerHost(url), ["/login", "/register"].contains(url.path)' not in source:
        raise SystemExit(f"login/register interception is not server-host scoped: {filename}")
CHECK

# 정액 결제와 Ranked 학습일 상점은 한 화면에서 설명하되, 앱에서 가격·
# 경기 규칙을 새로 정의하지 않는다. 서버 storefront/shop 응답만 표시해야 한다.
if grep -Eq 'priceDays[[:space:]]*=[[:space:]]*[0-9]|stakeDays[[:space:]]*=[[:space:]]*[0-9]' "$HUB"; then
  echo "commerce hub must not hard-code Arena economy values" >&2
  exit 1
fi

echo "iPad commerce hub and browser handoff contract passed"
