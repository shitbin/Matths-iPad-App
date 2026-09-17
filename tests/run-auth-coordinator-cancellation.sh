#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-auth-coordinator.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
node - "$ROOT" "$WORK" <<'JS'
const fs=require('node:fs');const[root,out]=process.argv.slice(2);
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<i)throw Error('Review coordinator boundary '+a);return s.slice(i,j)}
const apple=fs.readFileSync(root+'/Matths/AppleSignInCoordinator.swift','utf8');
let output='import Foundation\n@MainActor final class AppleSignInCoordinator:NSObject {\n'+between(apple,'    private var continuation:','    // MARK: 진입점')+between(apple,'    func cancel() {','    // MARK: nonce')+'\nfunc begin()->Task<ASAuthorizationAppleIDCredential,Error>{Task{try await requestCredential(nonceHash:"synthetic-request",requestedScopes:[])}}\nvar activeController:ASAuthorizationController?{controller}\n}\n'+between(apple,'extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {','extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {');
for(const label of ['Google','Kakao']){
 const s=fs.readFileSync(root+'/Matths/'+label+'SignInCoordinator.swift','utf8');
 output+='\n@MainActor final class '+label+'Harness:NSObject {\n'+between(s,'    private var session:','    func signIn()')+between(s,'    private func openAuthenticationSession(',label==='Google'?'    private func callbackCode(':'    /// 콜백은 반드시')+between(s,'    func cancel() {','    private static func makeCodeVerifier')+'\nfunc begin()->Task<URL,Error>{Task{try await openAuthenticationSession(startURL:URL(string:"https://example.invalid/auth")!)}}\nvar activeSession:ASWebAuthenticationSession?{session}\n}\n';
}
fs.writeFileSync(out+'/Coordinators.swift',output);
JS
# Exact product state machine methods, controlled OS callback boundary only.
xcrun swiftc -swift-version 5 "$ROOT/Matths/AuthFlowDiagnostics.swift" "$ROOT/Matths/NativeAuthenticationPresentationPolicy.swift" "$WORK/Coordinators.swift" "$ROOT/tests/AuthCoordinatorCancellationCases.swift" -o "$WORK/cases"
"$WORK/cases"
# Use real Apple SDK APIs at the shipping minimum OS, without performing login,
# launching a simulator, linking/running an app, or using provider credentials.
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun swiftc -swift-version 5 -target arm64-apple-ios17.0 -sdk "$SDK" -typecheck \
  "$ROOT/Matths/GoogleSignInCoordinator.swift" "$ROOT/Matths/KakaoSignInCoordinator.swift" "$ROOT/Matths/AppleSignInCoordinator.swift" \
  "$ROOT/Matths/AuthFlowDiagnostics.swift" \
  "$ROOT/Matths/NativeSocialRegistrationContext.swift" \
  "$ROOT/tests/AuthCoordinatorSDKStubs.swift"
echo 'Authentication coordinator actual iOS 17 SDK typecheck passed'
