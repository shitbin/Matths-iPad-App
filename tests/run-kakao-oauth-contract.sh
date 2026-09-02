#!/bin/sh
# 카카오 로그인이 구글과 **같은 길**을 지나게 묶는다.
#
# 막으려는 사고:
#   카카오는 SDK 를 넣는 방법도 있다. 그 길로 새면 앱에 네이티브 키가 박히고,
#   카카오톡 전환·웹 폴백 두 갈래가 생기며, 서버 PKCE 왕복을 우회해 토큰을
#   기기에서 직접 다루게 된다. 그 순간 run-auth-screen-protection-contract.sh 가
#   지키던 "소셜 교환은 서버를 지난다" 가 무너진다.
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
grep -Fq 'appendingPathComponent("/auth/kakao/app")' "$coordinator" \
  || fail "카카오 앱 진입점(/auth/kakao/app)을 쓰지 않습니다."
grep -Fq 'URLQueryItem(name: "code_challenge", value: codeChallenge)' "$coordinator" \
  || fail "PKCE code_challenge 를 보내지 않습니다."
grep -Fq 'ServerAPI.exchangeSocialAuthCode(' "$coordinator" \
  || fail "서버 교환 경로를 지나지 않습니다."

# ── 카카오 SDK 를 들이지 않는다 ─────────────────────────────────────────────
# SDK 가 들어오면 토큰을 기기에서 직접 다루게 되고 서버 교환 계약이 깨진다.
if grep -rn -iE 'import (KakaoSDK|KakaoSDKAuth|KakaoSDKUser)' "$root/Matths"; then
  fail "카카오 SDK 가 들어왔습니다. 서버 PKCE 왕복 계약이 깨집니다."
fi

# ── 콜백은 카카오 것만 받는다 ───────────────────────────────────────────────
grep -Fq 'callbackCode(callbackURL, expectedPath: "/kakao")' "$coordinator" \
  || fail "로그인 콜백의 카카오 경로를 지정하지 않습니다."
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
grep -Fq '.onDisappear { cancelKakaoSignIn() }' "$auth_screen" \
  || fail "화면을 벗어날 때 카카오 세션을 접지 않습니다."

# ── 조회는 한 번만 ──────────────────────────────────────────────────────────
# 애플·카카오가 각각 물으면 진입마다 같은 요청이 두 번 나간다.
grep -Fq 'private func refreshSocialAvailability() async' "$auth_screen" \
  || fail "소셜 가용성 조회가 하나로 모여 있지 않습니다."
grep -cq . /dev/null 2>/dev/null || true
if [ "$(grep -c 'ServerAPI.socialAuthProviders()' "$auth_screen")" != "1" ]; then
  fail "AuthScreen 이 providers 를 두 번 이상 조회합니다."
fi

echo "PASS: 카카오가 구글과 같은 서버 PKCE 경로를 지납니다."
