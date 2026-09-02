#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
profile="$root/Matths/ProfileScreen.swift"

# iPhone 가로의 계정 삭제는 sheet 드래그와 내부 ScrollView가 경쟁하지 않아야 한다.
grep -Fq '.fullScreenCover(isPresented: $showWithdraw) { WithdrawSheet() }' "$profile"
if grep -Fq '.sheet(isPresented: $showWithdraw) { WithdrawSheet() }' "$profile"; then
  echo 'FAIL: account deletion must not use a draggable sheet' >&2
  exit 1
fi

# 남는 가로 폭에 결과/본인확인을 나눠 최종 동의와 삭제 버튼을 처음부터 노출한다.
awk '/private struct WithdrawSheet:/,/private func bullet/' "$profile" > "${TMPDIR:-/tmp}/matths-withdraw-sheet.$$"
trap 'rm -f "${TMPDIR:-/tmp}/matths-withdraw-sheet.$$"' EXIT HUP INT TERM
sheet="${TMPDIR:-/tmp}/matths-withdraw-sheet.$$"
grep -Fq 'CompactHeightColumns(' "$sheet"
grep -Fq '.scrollIndicators(.visible)' "$sheet"
grep -Fq '.scrollDismissesKeyboard(.interactively)' "$sheet"
grep -Fq 'usesCompactHeightActionBar' "$sheet"
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$sheet"
grep -Fq 'private enum FocusedField { case password, phrase }' "$sheet"
grep -Fq '@FocusState private var focusedField: FocusedField?' "$sheet"
grep -Fq 'if usesCompactHeightActionBar && focusedField == nil {' "$sheet"
grep -Fq '.focused($focusedField, equals: .password)' "$sheet"
grep -Fq '.focused($focusedField, equals: .phrase)' "$sheet"
grep -Fq '.onSubmit { focusedField = .phrase }' "$sheet"
grep -Fq '.onSubmit { focusedField = nil }' "$sheet"
grep -Fq 'private var submitButton:' "$sheet"
grep -Fq 'private var compactReauthenticationControls:' "$sheet"
grep -Fq 'private var withdrawalSupportLink:' "$sheet"
grep -Fq 'Label("고객지원 열기", systemImage: "questionmark.circle")' "$sheet"
grep -Fq 'ServerAPI.baseURL.appendingPathComponent("faq")' "$sheet"
grep -Fq 'private var withdrawalOptionsRetry:' "$sheet"
grep -Fq '"본인 확인 방법 다시 불러오기"' "$sheet"
grep -Fq 'guard !loadingWithdrawalOptions else { return }' "$profile"
grep -Fq 'withdrawalOptionsLoadError = unsupported ? nil' "$profile"
grep -Fq '이메일 계정은 현재 비밀번호로 계속할 수 있습니다' "$profile"
grep -Fq 'errorText = Self.withdrawalFailureMessage(error)' "$profile"
grep -Fq '인터넷 연결이 끊겨 탈퇴를 완료하지 못했습니다' "$profile"
grep -Fq '계속 실패하면 고객지원으로 문의해 주세요.' "$profile"
grep -Fq '"현재 비밀번호 또는 소셜 계정 본인 확인"' "$sheet"

# 운영 설정 실패를 사용자가 고칠 수 있는 서버 구성 문제처럼 말하지 않는다.
if grep -Fq '서버에 설정되지 않았습니다' "$sheet" \
  || grep -Fq '이 서버에서 제공되지 않습니다' "$sheet"; then
  echo "account deletion copy exposes server implementation details" >&2
  exit 1
fi
grep -Fq '아래에서 다시 불러오거나 고객센터로 문의해 주세요.' "$sheet"
grep -Fq 'fullWidth ? "Google로 본인 확인" : "Google"' "$sheet"
grep -Fq 'fullWidth ? "Apple로 본인 확인" : "Apple"' "$sheet"
grep -Fq 'fullWidth ? "카카오로 본인 확인" : "카카오"' "$sheet"
grep -Fq 'reauthenticateForAccountDeletion()' "$profile"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' "$sheet"
grep -Fq 'Text(busy ? "처리 중…" : "탈퇴하기")' "$sheet"

# Matths 계정 탈퇴와 App Store 자동갱신 해지는 서로 다른 작업이다. 이 고지가 없으면
# 사용자가 계정만 지운 뒤에도 청구될 수 있고, 새 계정으로 권한이 자동 이전된다고
# 오해한다. 탈퇴를 막지는 않되 같은 화면에서 Apple 구독 관리로 바로 갈 수 있어야 한다.
grep -Fq 'Apple 구독은 별도로 해지해야 합니다' "$sheet"
grep -Fq '회원 탈퇴만으로 App Store 자동 갱신은 취소되지 않습니다' "$sheet"
grep -Fq '남은 이용기간과 결제 내역은 새 Matths 계정으로 자동 이전되지 않습니다' "$sheet"
grep -Fq 'Label("Apple 구독 관리 열기", systemImage: "arrow.up.right.square")' "$sheet"
grep -Fq 'components.host = "apps.apple.com"' "$sheet"
grep -Fq 'components.path = "/account/subscriptions"' "$sheet"
grep -Fq '.frame(minHeight: 44, alignment: .leading)' "$sheet"

# 비밀번호가 없는 Apple/Google 계정도 앱 안에서 새 본인 확인 후 탈퇴할 수 있어야 한다.
api="$root/Matths/ServerAPI.swift"
apple="$root/Matths/AppleSignInCoordinator.swift"
grep -Fq 'var appleReauthentication: AppleReauthentication' "$api"
grep -Fq 'var kakaoReauthentication: KakaoReauthentication' "$api"
grep -Fq '"appleIdentityToken": reauthentication.identityToken' "$api"
grep -Fq '"appleNonce": reauthentication.nonce' "$api"
grep -Fq 'expectedPath: "/google-reauth"' "$root/Matths/GoogleSignInCoordinator.swift"
grep -Fq 'expectedPath: "/kakao-reauth"' "$root/Matths/KakaoSignInCoordinator.swift"
grep -Fq 'func reauthenticateForAccountDeletion()' "$apple"
grep -Fq 'requestedScopes: []' "$apple"

echo 'account deletion landscape contract passed'
