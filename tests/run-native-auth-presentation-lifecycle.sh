#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-native-auth-presentation.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swiftc \
  "$ROOT/Matths/NativeAuthenticationPresentationPolicy.swift" \
  "$ROOT/tests/NativeAuthenticationPresentationPolicyCases.swift" \
  -o "$WORK/native-auth-presentation"
"$WORK/native-auth-presentation"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
source = (root / "Matths/AuthScreen.swift").read_text()

def fail(message: str) -> None:
    raise SystemExit("Native authentication presentation contract failed: " + message)

policy_call = "NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear("
if source.count(policy_call) != 2:
    fail("Apple and Kakao must each use the native presentation policy")
if '.onDisappear { cancelGoogleSignIn() }' not in source:
    fail("the working Google web-session disappearance behavior changed")

for provider in ("Apple", "Kakao"):
    marker = f"private func start{provider}SignIn()"
    start = source.find(marker)
    if start < 0:
        fail(f"missing {provider} start flow")
    end = source.find("\n    private func ", start + len(marker))
    body = source[start:end if end >= 0 else len(source)]
    other = "Kakao" if provider == "Apple" else "Apple"
    for required in (
        f"cancel{provider}SignIn()",
        f"cancel{other}SignIn()",
        "cancelGoogleSignIn()",
        "ServerAPI.beginAuthenticationAttempt()",
        "store.signInServer(auth, attemptID: attemptID)",
    ):
        if required not in body:
            fail(f"{provider} explicit ownership boundary lost {required}")

email_button = source[source.find('Text(\"\uc774\uba54\uc77c\ub85c \uac00\uc785 \ub610는 \ub85c그인\")') - 700:]
email_end = email_button.find("} label:")
email_action = email_button[:email_end]
for required in ("cancelGoogleSignIn()", "cancelAppleSignIn()", "cancelKakaoSignIn()"):
    if required not in email_action:
        fail("email navigation no longer explicitly cancels " + required)

print("Native presentation preservation, explicit provider switching, email teardown, and Google behavior passed.")
PY
