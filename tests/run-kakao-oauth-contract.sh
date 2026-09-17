#!/bin/sh
# 카카오 로그인이 구글과 **같은 길**을 지나게 묶는다.
#
# 막으려는 사고:
#   SDK 인증이 끝나도 카카오 토큰을 맵쓰 세션으로 직접 사용하지 않는다.
#   서버의 발급 앱·사용자 검증과 일회용 grant·PKCE 교환을 반드시 거친다.
#
#   또 하나: 콜백 경로를 확인하지 않으면 구글 왕복 결과가 카카오 로그인으로
#   들어온다. 서버는 provider 별로 matths://oauth/<provider> 를 쓰는데,
#   앱이 경로를 안 보면 그 구분이 무의미해진다.
#
# 실행: sh tests/run-kakao-oauth-contract.sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
coordinator="$root/Matths/KakaoSignInCoordinator.swift"
auth_screen="$root/Matths/AuthScreen.swift"

fail() { echo "FAIL: $1" >&2; exit 1; }

# ── 서버 PKCE 왕복을 탄다 ───────────────────────────────────────────────────
grep -Fq 'ASWebAuthenticationSession' "$coordinator" \
  || fail "카카오가 ASWebAuthenticationSession 을 쓰지 않습니다."
if grep -Fq 'appendingPathComponent("/auth/kakao/app")' "$coordinator"; then
  fail "네이티브 개인정보 입력을 웹 가입 페이지로 우회합니다."
fi
grep -Fq 'codeChallenge: codeChallenge' "$coordinator" \
  || fail "네이티브 인증에 PKCE challenge를 보내지 않습니다."
grep -Fq 'ServerAPI.exchangeSocialAuthCode(' "$root/Matths/NativeSocialRegistrationContext.swift" \
  || fail "서버 교환 경로를 지나지 않습니다."

# Native app switching is now supported, but Matths identity still comes from
# the server's validated grant and PKCE exchange, never the SDK profile alone.
grep -Fq 'UserApi.shared.loginWithKakaoTalk' "$root/Matths/KakaoNativeSignIn.swift"
grep -Eq 'guard (self\.)?requestID == id, phase == callbackPhase' "$root/Matths/KakaoNativeSignIn.swift"
grep -Fq 'ServerAPI.startNativeKakaoAuthentication' "$coordinator"
grep -Fq 'NativeSocialRegistrationContext.resolve(response, provider: "kakao", codeVerifier: codeVerifier' "$coordinator"
grep -Fq 'KakaoNativeSignIn.handle(url)' "$root/Matths/MatthsApp.swift"
grep -Fq 'kakao54f59f482b5e69baaf8102c6f1433c1f' "$root/Info.plist"
python3 - "$root/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as source:
    info = plistlib.load(source)
assert "kakaokompassauth" in info["LSApplicationQueriesSchemes"]
assert all("LSApplicationQueriesSchemes" not in row for row in info["CFBundleURLTypes"])
assert any("kakao54f59f482b5e69baaf8102c6f1433c1f" in row["CFBundleURLSchemes"] for row in info["CFBundleURLTypes"])
PY

# ── 콜백은 카카오 것만 받는다 ───────────────────────────────────────────────
grep -Fq 'callbackCode(callbackURL, expectedPath: "/kakao-reauth")' "$coordinator" \
  || fail "탈퇴 재인증 콜백의 카카오 경로를 지정하지 않습니다."
grep -Fq 'callbackURL.path == expectedPath' "$coordinator" \
  || fail "콜백 경로를 확인하지 않습니다. 다른 provider 결과가 섞여 들어옵니다."
grep -Fq 'callbackURL.host?.lowercased() == "oauth"' "$coordinator" \
  || fail "콜백 host 를 확인하지 않습니다."
grep -Fq 'SOCIAL_AUTH_CALLBACK_DUPLICATE' "$coordinator" \
  || fail "콜백 쿼리 중복 방어가 없습니다."
grep -Fq 'let codeVerifier = try Self.makeCodeVerifier()' "$coordinator" \
  || fail "PKCE 보안 난수 실패를 호출자에게 전달하지 않습니다."
grep -Fq 'SOCIAL_AUTH_SECURE_RANDOM_UNAVAILABLE' "$coordinator" \
  || fail "PKCE 보안 난수 실패가 사용자 오류로 변환되지 않습니다."
if grep -Fq 'precondition(status == errSecSuccess' "$coordinator"; then
  fail "보안 난수 실패가 앱 전체 종료로 번집니다."
fi

# ── 서버가 켜 줄 때만 그린다 ────────────────────────────────────────────────
# 눌러도 안 되는 버튼을 먼저 보여주면 학생은 자기 계정 문제로 읽는다.
grep -Fq 'if kakaoAvailable {' "$auth_screen" \
  || fail "서버 응답과 무관하게 카카오 버튼을 그립니다."
grep -Fq '$0.key == "kakao" && $0.configured' "$auth_screen" \
  || fail "카카오 configured 여부를 서버에 묻지 않습니다."

# ── 로그인 시도는 셋이 서로를 덮지 않는다 ───────────────────────────────────
# 하나의 busy/attempt 를 공유하면 늦게 온 응답이 다른 로그인을 덮는다.
for token in 'kakaoAttemptID' 'cancelKakaoSignIn()' 'ServerAPI.beginAuthenticationAttempt()'; do
  grep -Fq "$token" "$auth_screen" || fail "$token 이 없습니다. 시도 격리가 깨집니다."
done
grep -Fq 'NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(' "$auth_screen" \
  || fail "카카오톡 앱 전환을 진짜 AuthScreen 종료와 구분하지 않습니다."
grep -Fq 'isBusy: kakaoBusy' "$auth_screen" \
  || fail "진행 중인 카카오 자격 증명을 disappear 시점에 보존하지 않습니다."

# ── 조회는 한 번만 ──────────────────────────────────────────────────────────
# 애플·카카오가 각각 물으면 진입마다 같은 요청이 두 번 나간다.
grep -Fq 'private func refreshSocialAvailability() async' "$auth_screen" \
  || fail "소셜 가용성 조회가 하나로 모여 있지 않습니다."
grep -cq . /dev/null 2>/dev/null || true
if [ "$(grep -c 'ServerAPI.socialAuthProviders()' "$auth_screen")" != "1" ]; then
  fail "AuthScreen 이 providers 를 두 번 이상 조회합니다."
fi

echo "PASS: 카카오가 구글과 같은 서버 PKCE 경로를 지납니다."
