#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SOCIAL_TEST_WORK="$(mktemp -d "${TMPDIR:-/tmp}/matths-native-social-context.XXXXXX")"
cleanup() {
    case "$SOCIAL_TEST_WORK" in
        */matths-native-social-context.*) rm -rf -- "$SOCIAL_TEST_WORK" ;;
        *) echo 'Refusing unexpected test cleanup target' >&2 ;;
    esac
}
trap cleanup EXIT HUP INT TERM

# NativeSocialRegistrationContext.swift is compiled without edits. DTOs and API
# body builders below are extracted verbatim; only request transport is replaced.
node - "$ROOT" "$SOCIAL_TEST_WORK" <<'JS'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(root + '/Matths/ServerAPI.swift', 'utf8');
function block(marker, text = source) {
  const start = text.indexOf(marker);
  if (start < 0) throw new Error('Production member missing: ' + marker);
  const open = text.indexOf('{', start);
  let depth = 0, string = false, escape = false, comment = false;
  for (let i = open; i < text.length; i++) {
    const ch=text[i], next=text[i+1];
    if(comment){if(ch==='\n')comment=false;continue;}
    if(string){if(escape)escape=false;else if(ch==='\\')escape=true;else if(ch==='"')string=false;continue;}
    if(ch==='/'&&next==='/'){comment=true;i++;continue;}
    if(ch==='"'){string=true;continue;}
    if(ch==='{')depth++;
    if(ch==='}'&&--depth===0)return text.slice(start,i+1);
  }
  throw new Error('Unterminated production member: '+marker);
}
const members = [
  '    private struct NativeKakaoGrant:',
  '    struct NativeSocialRegistrationInfo:',
  '    struct NativeSocialStartResponse:',
  '    static func startNativeKakaoAuthentication(',
  '    static func startNativeAppleAuthentication(',
  '    static func completeNativeSocialRegistration(',
  '    static func exchangeSocialAuthCode('
].map(marker=>block(marker)).join('\n');
fs.writeFileSync(out+'/api.swift',`import Foundation
@MainActor enum ServerAPI {
${members}
    static func request<T: Decodable>(_ method: String, _ path: String,
                                     body: [String: Any]?, authed: Bool) async throws -> T {
        let data = try await NativeSocialTransport.request(method, path, body: body, authed: authed)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
`);
// Use a restricted test adapter: no keychain/session promotion function exists.
// Adding implicit session mutation to the context makes this build fail rather
// than silently accepting a test stub which pretends that a session was created.
const screen = fs.readFileSync(root+'/Matths/NativeSocialRegistrationScreen.swift','utf8');
const disappear = block('.onDisappear {',screen);
const disappearBody = disappear.slice(disappear.indexOf('{')+1,-1);
const errorSwitch = block('switch apiError?.code {',screen);
const submit = block('private func submit() {',screen);
const success = submit.slice(submit.indexOf('let auth = try await context.submit'),submit.indexOf('} catch {'));
if (!success.includes('guard !Task.isCancelled, submissionID == id else { return }') ||
    success.indexOf('submissionTask = nil') < 0 ||
    success.indexOf('submissionTask = nil') > success.indexOf('onComplete(auth)')) {
  throw new Error('Successful native form must release its task before handing auth to its parent');
}
if (/onCancel\s*\(|cancelAuthenticationAttempt\s*\(|signInServer\s*\(/.test(disappearBody)) {
  throw new Error('Transient form disappearance must not retire the parent authentication attempt');
}
const authScreen = fs.readFileSync(root+'/Matths/AuthScreen.swift','utf8');
const completion = block('private func completeNativeRegistration(',authScreen);
if (!completion.includes('guard nativeRegistration?.id == presentation.id') ||
    !completion.includes('(isApple ? appleAttemptID : kakaoAttemptID) == attemptID') ||
    completion.indexOf('let task = Task') < 0 ||
    completion.indexOf('let task = Task') > completion.indexOf('store.signInServer(') ||
    !completion.includes('appleTask = task') || !completion.includes('kakaoTask = task')) {
  throw new Error('Parent native registration completion must retain a separately owned authentication task');
}
fs.writeFileSync(out+'/lifecycle.swift',`import Foundation
@MainActor final class NativeRegistrationLifecycleHarness {
    let context: NativeSocialRegistrationContext
    var isSubmitting = false
    var submissionTask: Task<Void, Never>?
    var submissionID: UUID?
    var serverError: String?
    var hasExpired = false
    var reauthenticationReason: String?
    init(context: NativeSocialRegistrationContext) { self.context = context }
    func disappear() {
${disappearBody}
    }
    func handleRegistrationError(_ error: Error) {
        let apiError = error as? ServerAPIError
${errorSwitch}
    }
}
`);
JS

xcrun swiftc -swift-version 5 "$ROOT/Matths/NativeSocialRegistrationContext.swift" \
    "$SOCIAL_TEST_WORK/api.swift" "$SOCIAL_TEST_WORK/lifecycle.swift" "$ROOT/tests/NativeSocialRegistrationContextCases.swift" \
    -o "$SOCIAL_TEST_WORK/context-cases"
"$SOCIAL_TEST_WORK/context-cases"
xcrun swiftc -swift-version 5 -DDEBUG "$ROOT/Matths/NativeSocialRegistrationContext.swift" \
    "$SOCIAL_TEST_WORK/api.swift" "$SOCIAL_TEST_WORK/lifecycle.swift" "$ROOT/tests/NativeSocialRegistrationContextCases.swift" \
    -o "$SOCIAL_TEST_WORK/context-debug-cases"
"$SOCIAL_TEST_WORK/context-debug-cases" -nativeRegistrationCapture

if [ "${NATIVE_SOCIAL_CONTEXT_MUTATION_CHECK:-0}" = "1" ]; then
    node - "$ROOT" "$SOCIAL_TEST_WORK" <<'JS'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const context = fs.readFileSync(root+'/Matths/NativeSocialRegistrationContext.swift','utf8');
const api = fs.readFileSync(out+'/api.swift','utf8');
const providerGuard = 'registration.provider == provider,';
const consentValue = '"privacyAccepted": profile.privacyAccepted';
if (!context.includes(providerGuard) || !api.includes(consentValue)) throw new Error('Negative control production anchor changed');
fs.writeFileSync(out+'/context-provider-mutant.swift', context.replace(providerGuard,''));
fs.writeFileSync(out+'/api-consent-mutant.swift', api.replace(consentValue,'"privacyAccepted": true'));
JS
    xcrun swiftc -swift-version 5 "$SOCIAL_TEST_WORK/context-provider-mutant.swift" \
        "$SOCIAL_TEST_WORK/api.swift" "$SOCIAL_TEST_WORK/lifecycle.swift" "$ROOT/tests/NativeSocialRegistrationContextCases.swift" \
        -o "$SOCIAL_TEST_WORK/provider-mutant"
    if "$SOCIAL_TEST_WORK/provider-mutant" > "$SOCIAL_TEST_WORK/provider-mutant.log" 2>&1; then
        echo 'FAIL: provider-mismatch negative control survived' >&2; exit 1
    fi
    grep -Fq 'FAIL: Expected error NATIVE_SOCIAL_RESPONSE_INVALID' "$SOCIAL_TEST_WORK/provider-mutant.log"
    xcrun swiftc -swift-version 5 "$ROOT/Matths/NativeSocialRegistrationContext.swift" \
        "$SOCIAL_TEST_WORK/api-consent-mutant.swift" "$SOCIAL_TEST_WORK/lifecycle.swift" "$ROOT/tests/NativeSocialRegistrationContextCases.swift" \
        -o "$SOCIAL_TEST_WORK/consent-mutant"
    if "$SOCIAL_TEST_WORK/consent-mutant" > "$SOCIAL_TEST_WORK/consent-mutant.log" 2>&1; then
        echo 'FAIL: fabricated-consent negative control survived' >&2; exit 1
    fi
    grep -Fq 'FAIL: Consent is never silently fabricated' "$SOCIAL_TEST_WORK/consent-mutant.log"
    echo 'Native social context negative controls: provider mismatch and fabricated consent detected.'
fi
