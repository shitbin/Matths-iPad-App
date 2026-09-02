#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
auth="$root/Matths/AuthScreen.swift"
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-auth-landscape.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

# 이메일 인증은 page sheet 드래그와 폼 스크롤이 경쟁하지 않는 독립 화면이다.
grep -Fq '.fullScreenCover(isPresented: $showEmailAuth) { EmailAuthSheet() }' "$auth"
if grep -Fq '.sheet(isPresented: $showEmailAuth) { EmailAuthSheet() }' "$auth"; then
  echo 'FAIL: email auth must not use a draggable sheet' >&2
  exit 1
fi

awk '/struct EmailAuthSheet:/,/private var formValid:/' "$auth" > "$work/sheet"
grep -Fq 'CompactHeightColumns(' "$work/sheet"
grep -Fq 'identityAndCredentialFields' "$work/sheet"
grep -Fq 'registrationRequirements' "$work/sheet"
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$work/sheet"
grep -Fq 'submitButton.frame(maxWidth: 320)' "$work/sheet"
grep -Fq 'if compactHeight && focusedField == nil' "$work/sheet"
grep -Fq '.scrollIndicators(.visible)' "$work/sheet"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' "$work/sheet"
grep -Fq '.accessibilityElement(children: .contain)' "$work/sheet"
grep -Fq '.accessibilitySortPriority(-10)' "$work/sheet"
grep -Fq '@Environment(\.dynamicTypeSize) private var dynamicTypeSize' "$work/sheet"
grep -Fq 'compactHeight && !dynamicTypeSize.isAccessibilitySize' "$work/sheet"
grep -Fq 'if usesCompactFieldRows' "$work/sheet"
awk '/struct EmailAuthSheet:/,/\/\/ MARK: - 서버 학교 목록 피커/' "$auth" > "$work/controls"
if [ "$(grep -Fc '.frame(minHeight: 44)' "$work/controls")" -lt 5 ]; then
  echo 'FAIL: auth fields and controls must preserve 44pt touch targets' >&2
  exit 1
fi

# 인증 장애가 있어도 로그인 화면에서 정책·지원 문서로 갈 수 있어야 한다. 프로필
# 안에만 두면 로그인하지 못한 사용자와 심사자가 개인정보처리방침에 접근하지 못한다.
grep -Fq 'destination: ServerAPI.baseURL.appendingPathComponent("terms")' "$auth"
grep -Fq 'destination: ServerAPI.baseURL.appendingPathComponent("privacy")' "$auth"
grep -Fq 'destination: ServerAPI.baseURL.appendingPathComponent("faq")' "$auth"
grep -Fq '.frame(minHeight: 44)' "$auth"
grep -Fq 'private var signInButtonHeight: CGFloat { compactHeight ? 44 : 52 }' "$auth"
[ "$(grep -Fc '.frame(maxWidth: .infinity, minHeight: signInButtonHeight)' "$auth")" -eq 4 ]
grep -Fq 'ViewThatFits(in: .horizontal)' "$auth"
grep -Fq 'private var termsLink: some View' "$auth"
grep -Fq 'private var privacyLink: some View' "$auth"
grep -Fq 'private var supportLink: some View' "$auth"

# 소셜 로그인 사전 조회가 느릴 때 수단을 바꾸거나 이메일 폼을 열어도 이전 작업이
# 뒤늦게 인증창을 띄우지 않는다. 세 버튼은 하나의 busy 게이트를 공유하고, 각
# Task는 화면 이탈·수단 전환 때 코디네이터와 함께 취소한다.
for provider in google apple kakao; do
  grep -Fq "@State private var ${provider}Task: Task<Void, Never>?" "$auth"
  grep -Fq "${provider}Task?.cancel()" "$auth"
done
grep -Fq 'private var socialAuthenticationBusy: Bool' "$auth"
[ "$(grep -Fc '.disabled(socialAuthenticationBusy)' "$auth")" -eq 3 ]
for coordinator in AppleSignInCoordinator GoogleSignInCoordinator KakaoSignInCoordinator; do
  file="$root/Matths/${coordinator}.swift"
  grep -Fq 'try Task.checkCancellation()' "$file"
done

python3 - "$auth" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
starts = {
    "Apple": source.index("private func startAppleSignIn()"),
    "Kakao": source.index("private func startKakaoSignIn()"),
    "Google": source.index("private func startGoogleSignIn()"),
}
for provider, start in starts.items():
    end = source.index("\n    private func cancel", start)
    body = source[start:end]
    others = {"Apple", "Kakao", "Google"} - {provider}
    for other in others:
        required = f"cancel{other}SignIn()"
        if required not in body:
            raise SystemExit(f"FAIL: {provider} sign-in must cancel in-flight {other} sign-in")
PY

# 폼 안에서 여는 학교·비밀번호 재설정도 page sheet로 되돌아가면 iPhone 가로에서
# 닫기 제스처와 내부 스크롤이 다시 경쟁한다.
grep -Fq '.fullScreenCover(isPresented: $showSchoolPicker)' "$work/sheet"
grep -Fq '.fullScreenCover(isPresented: $showReset)' "$work/sheet"
if grep -Eq '\.sheet\(isPresented: \$(showSchoolPicker|showReset)' "$work/sheet"; then
  echo 'FAIL: nested auth flows must not use draggable sheets' >&2
  exit 1
fi

awk '/struct PasswordResetSheet:/,/private var stepValid:/' "$auth" > "$work/reset"
grep -Fq 'private var compactHeight: Bool' "$work/reset"
grep -Fq 'if !compactHeight { advanceButton }' "$work/reset"
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$work/reset"
grep -Fq 'if compactHeight && !keyboardVisible' "$work/reset"
grep -Fq 'UIResponder.keyboardWillShowNotification' "$work/reset"
grep -Fq 'Button("완료") { focusedField = nil }' "$work/reset"

echo 'auth landscape form contract passed'
