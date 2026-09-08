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
 assert(source.includes('func signIn() async throws -> AuthResponse {\n        try Task.checkCancellation()\n        let diagnosticAttemptID = AuthFlowDiagnostics.currentAttemptID'), 'cancelled queued login may claim a newer diagnostic attempt');
 for(const stage of ['provider_lookup','callback_received','exchange_started','exchange_succeeded'])assert(source.includes('"'+stage+'"'),name+' misses '+stage);
 for(const call of source.matchAll(/AuthFlowDiagnostics\.record\(([^\n]+)\)/g))assert.match(call[1],/^"[a-z_]+", attemptID: (?:diagnosticAttemptID|sessionDiagnosticAttemptID|credentialDiagnosticAttemptID)$/);
}
const source=fs.readFileSync(root+'/Matths/AuthFlowDiagnostics.swift','utf8');
assert(source.includes('.cachesDirectory'));assert(!source.includes('.documentDirectory'));
assert(!source.includes('localizedDescription'));assert(!source.includes('errorDescription'));
assert(!source.includes('print('));assert(!source.includes('NSLog('));
console.log('Auth diagnostic fixed-stage wiring and cache/privacy source guards passed');
JS
