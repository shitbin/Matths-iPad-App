#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-auth-flow-diagnostics.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
for mode in debug diagnostic release; do
  case "$mode" in
    debug) set -- -D DEBUG ;;
    diagnostic) set -- -D MATTHS_AUTH_DIAGNOSTICS ;;
    release) set -- ;;
  esac
  xcrun swiftc -swift-version 5 "$@" "$ROOT/Matths/ProtectedFileWriter.swift" \
    "$ROOT/Matths/AuthFlowDiagnostics.swift" "$ROOT/tests/AuthFlowDiagnosticsCases.swift" -o "$WORK/$mode"
  "$WORK/$mode"
  "$WORK/$mode" -authDiagnostics
done
# Preserve privacy at wiring sites too. Provider events use one captured opaque
# attempt ID; only fixed stage names are passed, never callback URLs or payloads.
node - "$ROOT" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict');const[root]=process.argv.slice(2);
for(const name of ['GoogleSignInCoordinator','KakaoSignInCoordinator','AppleSignInCoordinator']) {
 const source=fs.readFileSync(root+'/Matths/'+name+'.swift','utf8');
 assert(source.includes('let diagnosticAttemptID = AuthFlowDiagnostics.currentAttemptID'));
 const resultType=name==='GoogleSignInCoordinator'?'AuthResponse':'NativeSocialSignInResult';
 assert(source.includes('func signIn() async throws -> '+resultType+' {\n        try Task.checkCancellation()\n        let diagnosticAttemptID = AuthFlowDiagnostics.currentAttemptID'), 'cancelled queued login may claim a newer diagnostic attempt');
 for(const stage of ['provider_lookup','callback_received','exchange_started'])assert(source.includes('"'+stage+'"'),name+' misses '+stage);
 if(name==='GoogleSignInCoordinator')assert(source.includes('"exchange_succeeded"'));
 else assert(source.includes('NativeSocialRegistrationContext.resolve')&&source.includes('diagnosticAttemptID: diagnosticAttemptID'));
 for(const call of source.matchAll(/AuthFlowDiagnostics\.record\(([^)]+)\)/g)) {
  const args=call[1].replace(/\s+/g,' ').trim();
  if(args.startsWith('"native_fallback"')) {
   assert.equal(name,'KakaoSignInCoordinator');
   assert.match(args,/^"native_fallback", attemptID: diagnosticAttemptID, apiCode: (?:code|"KAKAO_NATIVE_REGISTRATION_REQUIRED")$/);
  } else {
   assert.match(args,/^"[a-z_]+", attemptID: (?:diagnosticAttemptID|sessionDiagnosticAttemptID|credentialDiagnosticAttemptID)$/);
  }
 }
}
const registration=fs.readFileSync(root+'/Matths/NativeSocialRegistrationContext.swift','utf8');
assert(registration.includes('"exchange_succeeded", attemptID: diagnosticAttemptID'));
assert(!registration.includes('AuthFlowDiagnostics.currentAttemptID'), 'native form must not claim a newer attempt for diagnostics');
const source=fs.readFileSync(root+'/Matths/AuthFlowDiagnostics.swift','utf8');
assert(source.includes('.cachesDirectory'));assert(!source.includes('.documentDirectory'));
assert(!source.includes('localizedDescription'));assert(!source.includes('errorDescription'));
assert(!source.includes('print('));assert(!source.includes('NSLog('));
assert(source.includes('Self.apiCodes.contains(apiCode)'), 'fallback codes must use the same explicit privacy allowlist');
console.log('Auth diagnostic fixed-stage wiring and cache/privacy source guards passed');
JS
