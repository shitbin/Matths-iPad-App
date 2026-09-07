#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-auth-owner.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

swiftc \
  "$ROOT/Matths/ServerAuthenticationOwnership.swift" \
  "$ROOT/tests/ServerAuthenticationOwnershipCases.swift" \
  -o "$BUILD_DIR/auth-ownership"
"$BUILD_DIR/auth-ownership"

python3 - "$ROOT" "$BUILD_DIR" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
server = (root / "Matths/ServerAPI.swift").read_text()
auth = (root / "Matths/AuthScreen.swift").read_text()
app = (root / "Matths/MatthsApp.swift").read_text()

def fail(message: str) -> None:
    raise SystemExit("Authentication ownership contract failed: " + message)

def strip_swift_comments(source: str) -> str:
    out = list(source)
    i = 0
    state = "code"
    block_depth = 0
    while i < len(source):
        if state == "line":
            if source[i] == "\n":
                state = "code"
            else:
                out[i] = " "
            i += 1
            continue
        if state == "block":
            if source.startswith("/*", i):
                out[i] = out[i + 1] = " "
                block_depth += 1
                i += 2
            elif source.startswith("*/", i):
                out[i] = out[i + 1] = " "
                block_depth -= 1
                i += 2
                if block_depth == 0:
                    state = "code"
            else:
                if source[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if state == "string":
            if source[i] == "\\" and i + 1 < len(source):
                i += 2
            elif source[i] == '"':
                state = "code"
                i += 1
            else:
                i += 1
            continue
        if state == "multiline-string":
            if source.startswith('"""', i):
                state = "code"
                i += 3
            else:
                i += 1
            continue
        if source.startswith("//", i):
            out[i] = out[i + 1] = " "
            state = "line"
            i += 2
        elif source.startswith("/*", i):
            out[i] = out[i + 1] = " "
            block_depth = 1
            state = "block"
            i += 2
        elif source.startswith('"""', i):
            state = "multiline-string"
            i += 3
        elif source[i] == '"':
            state = "string"
            i += 1
        else:
            i += 1
    return "".join(out)

def mask_swift_strings(source: str) -> str:
    out = list(source)
    i = 0
    state = "code"
    while i < len(source):
        if state == "string":
            if source[i] == "\\" and i + 1 < len(source):
                out[i] = out[i + 1] = " "
                i += 2
            elif source[i] == '"':
                out[i] = " "
                state = "code"
                i += 1
            else:
                if source[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if state == "multiline-string":
            if source.startswith('"""', i):
                out[i] = out[i + 1] = out[i + 2] = " "
                state = "code"
                i += 3
            else:
                if source[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if source.startswith('"""', i):
            out[i] = out[i + 1] = out[i + 2] = " "
            state = "multiline-string"
            i += 3
        elif source[i] == '"':
            out[i] = " "
            state = "string"
            i += 1
        else:
            i += 1
    return "".join(out)

def body(source: str, marker: str) -> str:
    source = strip_swift_comments(source)
    mask = mask_swift_strings(source)
    start = source.find(marker)
    if start < 0:
        fail("declaration not found: " + marker)
    brace = mask.find("{", start)
    if brace < 0:
        fail("body not found: " + marker)
    depth = 0
    for index in range(brace, len(source)):
        if mask[index] == "{":
            depth += 1
        elif mask[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    fail("unterminated body: " + marker)

server_code = strip_swift_comments(server)
auth_code = strip_swift_comments(auth)
app_code = strip_swift_comments(app)

if "TokenBox.save(auth.accessToken)" in server_code:
    fail("network methods install a token before request ownership is accepted")
if "ServerAPI.acceptAuthentication(" in auth_code:
    fail("AuthScreen must pass auth+attemptID to AppStore, not accept a token directly")

for marker, label in [
    ("private func startAppleSignIn()", "Apple"),
    ("private func startGoogleSignIn()", "Google"),
    ("private func submit()", "email"),
]:
    flow = body(auth, marker)
    if flow.count("store.signInServer(auth, attemptID: attemptID)") != 1:
        fail(f"{label} flow must pass auth and attemptID to AppStore exactly once")
    if "ServerAPI.acceptAuthentication(" in flow:
        fail(f"{label} flow accepts authentication outside the atomic account switch")

sign_in = body(app, "func signInServer(_ auth: AuthResponse, attemptID: UUID)")
before_switch = body(sign_in, "beforeSwitch:")
accept_call = "ServerAPI.acceptAuthentication(auth, attemptID: attemptID)"
if sign_in.count(accept_call) != 1 or before_switch.count(accept_call) != 1:
    fail("AppStore must accept the authentication exactly once inside switchDataSlot.beforeSwitch")

switch_slot = body(app, "private func switchDataSlot(")
before_call = "guard beforeSwitch?() ?? true else { return false }"
if switch_slot.count(before_call) != 2:
    fail("same-slot and changed-slot transitions must both run the atomic beforeSwitch commit")
flush_index = switch_slot.find("await flushLearningPersistence()")
generation_index = switch_slot.find("guard generation == accountTransitionGeneration,", flush_index)
commit_index = switch_slot.find(before_call, generation_index)
slot_index = switch_slot.find("DataScope.switchTo(target)", commit_index)
if min(flush_index, generation_index, commit_index, slot_index) < 0 or not (
    flush_index < generation_index < commit_index < slot_index
):
    fail("authentication commit must follow old-slot flush/generation validation and precede slot switch")

if ".onDisappear { cancelAuthentication() }" not in auth_code:
    fail("email authentication ownership is not cancelled when its sheet disappears")
if ".onDisappear { cancelGoogleSignIn() }" not in auth_code:
    fail("social authentication ownership is not cancelled when AuthScreen disappears")

sync_logout = body(app, "func signOut()")
if sync_logout.find("ServerAPI.beginSignOut()") > sync_logout.find("Task {"):
    fail("signOut intent must be captured before scheduling its Task")
transition = body(app, "private func transitionToSignedOut(")
if transition.find("guard ownsIntent()") > transition.find("await switchDataSlot("):
    fail("stale auth cleanup can supersede a newer account transition")
transition_commit = body(transition, "beforeSwitch:")
for call in ["ServerAPI.finishSignOut(signOutID)", "ServerAPI.finishAuthenticationExpiration(expirationID)", "guard accepted else"]:
    if call not in transition_commit:
        fail("auth cleanup must conditionally re-check ownership after flush: " + call)
if "ServerAPI.logout()" in transition:
    fail("deferred auth cleanup must not unconditionally reset a newer login")
expired_observer = body(app, "authenticationExpiredObserver = NotificationCenter.default.addObserver(")
if "self.signOut()" in expired_observer or "expirationID" not in expired_observer:
    fail("expiration notification lost its intent ownership")
notify = body(server, "private static func notifyAuthenticationExpired(message:")
if "TokenBox.expirationTicket()" not in notify or '"expirationID": expirationID' not in notify:
    fail("auth expiration must carry a non-secret generation ticket")
token_box = body(server, "private enum TokenBox")
for marker, call in [
    ("static func finishSignOut(_ id: UUID)", "authenticationOwnership.completeSignOut(id)"),
    ("static func finishExpiration(_ id: UUID)", "authenticationOwnership.completeExpiration(id, hasCredential: loadUnlocked() != nil)"),
]:
    if call not in body(token_box, marker): fail("Keychain auth cleanup is not gated by the tested state machine")

generated = "extension AuthTransitionHarness {\n"
generated += "func signOut() {" + sync_logout + "}\n"
generated += "func signOut(discardingCurrentSlot: Bool) async -> Bool {" + body(app, "func signOut(discardingCurrentSlot: Bool)") + "}\n"
generated += "private func transitionToSignedOut(discardingCurrentSlot: Bool, signOutID: UUID? = nil, expirationID: UUID? = nil) async -> Bool {" + transition + "}\n"
generated += "func deliverExpiration(_ id: UUID) async -> Bool { await transitionToSignedOut(discardingCurrentSlot: false, expirationID: id) }\n}\n"
(Path(sys.argv[2]) / "ProductionAuthTransitions.swift").write_text("import Foundation\n" + generated)
PY

swiftc -parse-as-library \
  "$ROOT/Matths/ServerAuthenticationOwnership.swift" \
  "$ROOT/Matths/ServerTokenOwnership.swift" \
  "$ROOT/tests/ServerAuthenticationExpiryInterleavingCases.swift" \
  "$BUILD_DIR/ProductionAuthTransitions.swift" \
  -o "$BUILD_DIR/auth-expiry-interleavings"
"$BUILD_DIR/auth-expiry-interleavings"

echo "Server authentication ownership contract passed."
