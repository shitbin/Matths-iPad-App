#!/bin/sh
set -eu

# 2026-08-21 제출 전 성능 감사에서, @MainActor AppStore의 채점 버튼과 평가 답안 입력이
# 전체 진도/오답/과거 회차를 JSON 인코딩하고 backup·atomic replace까지 끝낸 뒤 반환해
# 오래 쓴 계정일수록 pressed 효과와 화면 전환이 밀리는 사고를 막는다.
# 값+슬롯 snapshot, 150ms key별 debounce, 즉시 내구 경계, 탈퇴 cancel-and-drain을 함께 고정한다.

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary=/tmp/matths-learning-snapshot-writer-cases

xcrun swiftc \
  "$root/Matths/DebouncedSnapshotWriter.swift" \
  "$root/tests/LearningSnapshotWriterCases.swift" \
  -o "$binary"
"$binary"

python3 - "$root" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
core = (root / "Matths/DebouncedSnapshotWriter.swift").read_text()
domain = (root / "Matths/LearningPersistence.swift").read_text()
app = (root / "Matths/MatthsApp.swift").read_text()
paper = (root / "Matths/AssessmentPaperScreen.swift").read_text()
concept = (root / "Matths/ConceptScreenV2.swift").read_text()
profile = (root / "Matths/ProfileScreen.swift").read_text()
iap = (root / "Matths/MatthsIAP.swift").read_text()
wrong_store = (root / "Matths/WrongNoteStore.swift").read_text()
sync_engine = (root / "Matths/SyncEngine.swift").read_text()
server_api = (root / "Matths/ServerAPI.swift").read_text()

def fail(message: str) -> None:
    raise SystemExit("학습 저장 계약 실패: " + message)

def strip_swift_comments(source: str) -> str:
    """주석의 계약 문자열이 실제 코드인 것처럼 통과하지 않게 한다.

    문자열 안의 //·/* 는 보존하고, 중첩 block comment도 처리한다. 위치와 줄바꿈을
    유지해 아래 brace matcher가 원문과 같은 인덱스를 쓸 수 있게 주석만 공백으로 바꾼다.
    """
    out = list(source)
    i = 0
    block_depth = 0
    state = "code"
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
    """본문 경계를 찾을 때 문자열 안의 { }를 세지 않는다."""
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
        fail(f"선언을 찾지 못했습니다: {marker}")
    brace = mask.find("{", start)
    if brace < 0:
        fail(f"본문 시작을 찾지 못했습니다: {marker}")
    depth = 0
    for index in range(brace, len(source)):
        char = mask[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    fail(f"본문 끝을 찾지 못했습니다: {marker}")

def require_in_order(source: str, markers: list[str], message: str) -> None:
    cursor = 0
    for marker in markers:
        index = source.find(marker, cursor)
        if index < 0:
            fail(message + f" (누락: {marker})")
        cursor = index + len(marker)

def require_assessment_persist_gates(
    source: str, slot: str, label: str, gate_marker: str | None = None
) -> None:
    """각 평가 내구 await 뒤 결과/UI를 만지기 전에 계정 전환 게이트를 다시 본다."""
    awaited = "await persistLearningImmediately"
    gate = gate_marker or f"isLearningAccountOperationActive(for: {slot})"
    cursor = 0
    count = 0
    while True:
        await_index = source.find(awaited, cursor)
        if await_index < 0:
            break
        next_await = source.find(awaited, await_index + len(awaited))
        limit = len(source) if next_await < 0 else next_await
        gate_index = source.find(gate, await_index + len(awaited), limit)
        result_checks = [source.find(marker, await_index + len(awaited), limit) for marker in (
            "if !persisted",
            "guard persisted else",
            "guard wrongNotesPersisted else",
            "guard assessmentPersisted else",
        )]
        result_checks = [index for index in result_checks if index >= 0]
        failure_index = min(result_checks) if result_checks else -1
        if gate_index < 0 or failure_index < 0 or gate_index > failure_index:
            fail(f"{label}의 로컬 저장 await 뒤 결과 반영 전에 계정 전환 게이트를 다시 검사하지 않습니다")
        count += 1
        cursor = await_index + len(awaited)
    if count == 0:
        fail(f"{label}에서 평가 snapshot 내구 저장 await를 찾지 못했습니다")

core_code = strip_swift_comments(core)
domain_code = strip_swift_comments(domain)
app_code = strip_swift_comments(app)
paper_code = strip_swift_comments(paper)
profile_code = strip_swift_comments(profile)
iap_code = strip_swift_comments(iap)
wrong_store_code = strip_swift_comments(wrong_store)
sync_engine_code = strip_swift_comments(sync_engine)
server_api_code = strip_swift_comments(server_api)

if not re.search(r"^actor DebouncedSnapshotWriter<", core_code, re.M):
    fail("직렬 writer가 actor가 아닙니다")
if re.search(r"@MainActor\s+actor DebouncedSnapshotWriter", core_code):
    fail("writer를 @MainActor에 묶으면 JSON/파일 I/O가 다시 UI를 막습니다")
if "where Key: Hashable & Sendable, Payload: Sendable" not in core_code:
    fail("writer key/payload가 Sendable 값 계약이 아닙니다")
if "@unchecked Sendable" in core_code or "@unchecked Sendable" in domain_code:
    fail("앱 writer snapshot에서 unchecked Sendable로 검사를 우회했습니다")

# 오래된 revision의 정상 폐기와 실제 I/O 실패를 Bool 하나로 합치면 account-switch
# barrier가 정상 경합을 실패로 멈추거나, 반대로 디스크 실패를 성공으로 넘길 수 있다.
if not re.search(
    r"enum\s+SnapshotWriteOutcome\s*:\s*Equatable\s*,\s*Sendable",
    core_code,
):
    fail("writer 결과가 Equatable·Sendable SnapshotWriteOutcome 값 계약이 아닙니다")
write_outcome = body(core, "enum SnapshotWriteOutcome")
for case in ("case written", "case superseded", "case ioFailed"):
    if write_outcome.count(case) != 1:
        fail(f"writer 결과가 {case}를 정확히 한 번 선언하지 않습니다")
single_immediate = body(core, "func writeImmediately(\n        _ payload")
if not re.search(r"\)\s*->\s*SnapshotWriteOutcome\s*\{", core_code):
    fail("단일 즉시 저장이 SnapshotWriteOutcome을 반환하지 않습니다")
require_in_order(
    single_immediate,
    [
        "guard revision > (latestRevision[key] ?? 0) else { return .superseded }",
        "let succeeded = sink(key, payload)",
        "return succeeded ? .written : .ioFailed",
    ],
    "단일 즉시 저장이 superseded·written·ioFailed 의미를 구분하지 않습니다",
)
if not re.search(
    r"func\s+writeImmediately\s*\(\s*_\s+writes:[\s\S]*?\)\s*->\s*\[Key:\s*SnapshotWriteOutcome\]",
    core_code,
):
    fail("batch 즉시 저장이 key별 SnapshotWriteOutcome을 보존하지 않습니다")
if "debounceNanoseconds: 150_000_000" not in domain_code:
    fail("일반 학습 저장의 150ms debounce가 바뀌었습니다")
account_activity = body(app, "private func isLearningAccountOperationActive")
if "slot == DataScope.slot" not in account_activity:
    fail("계정 작업 게이트가 캡처한 owner slot과 현재 슬롯의 일치를 검사하지 않습니다")
if "transitioningLearningPersistenceSlots[slot] == nil" not in account_activity:
    fail("계정 작업 게이트가 전환 중 source 슬롯을 닫지 않습니다")

slot_writable = body(app, "private func isLearningSlotWritable")
if "slot == DataScope.slot" not in slot_writable or "!disabledLearningPersistenceSlots.contains(slot)" not in slot_writable:
    fail("remote mutation 쓰기 가능 여부가 current owner와 탈퇴 장벽을 함께 검사하지 않습니다")
if "transitioningLearningPersistenceSlots" in slot_writable:
    fail("remote mutation을 계정 전환 중 drop하면 pull cursor만 전진하고 로컬 snapshot은 유실됩니다")

# 같은 이메일로 로그아웃→재로그인하면 물리 slot 문자열은 같아진다. 네트워크 요청의
# 진짜 owner는 slot과 성공 session generation을 합친 값이어야 한다.
if not re.search(
    r"struct\s+SyncAccountOwner\s*:\s*Equatable\s*,\s*Sendable",
    sync_engine_code,
):
    fail("동기 owner가 Equatable·Sendable SyncAccountOwner 값 계약이 아닙니다")
sync_owner = body(sync_engine, "struct SyncAccountOwner")
if sync_owner.count("let slot: String") != 1 or sync_owner.count("let sessionGeneration: UUID") != 1:
    fail("SyncAccountOwner가 slot과 sessionGeneration을 함께 고정하지 않습니다")
if "private var loadedSessionGeneration: UUID?" not in sync_engine_code:
    fail("메모리 sync queue가 물리 slot과 별도의 loaded session generation을 기억하지 않습니다")
if not re.search(r"var\s+captureAccountOwner:\s*\(\(\)\s*->\s*SyncAccountOwner\?\)\?", sync_engine_code):
    fail("SyncEngine이 AppStore의 현재 SyncAccountOwner 공급자를 받지 않습니다")

current_sync_owner = body(sync_engine, "private func currentAccountOwner()")
require_in_order(
    current_sync_owner,
    ["captureAccountOwner?()", "owner.slot == DataScope.slot", "return owner"],
    "SyncEngine이 AppStore owner와 현재 물리 slot의 일치를 확인하지 않습니다",
)
is_current_sync_owner = body(sync_engine, "private func isCurrentAccountOwner(")
if "currentAccountOwner() == owner" not in is_current_sync_owner:
    fail("SyncEngine post-await owner 검사가 slot+sessionGeneration 값 전체를 비교하지 않습니다")

sync_owner_active = body(app, "private func isSyncAccountOwnerActive(")
require_in_order(
    sync_owner_active,
    [
        "owner.slot == DataScope.slot",
        "owner.sessionGeneration == accountSessionGeneration",
        "!disabledLearningPersistenceSlots.contains(owner.slot)",
    ],
    "AppStore가 callback owner의 slot·sessionGeneration·탈퇴 게이트를 함께 검사하지 않습니다",
)

wire_sync = body(app, "func wireSyncCallbacks()")
owner_provider = body(wire_sync, "SyncEngine.shared.captureAccountOwner =")
require_in_order(
    owner_provider,
    [
        "SyncAccountOwner(",
        "slot: DataScope.slot",
        "sessionGeneration: self.accountSessionGeneration",
    ],
    "AppStore가 현재 slot과 성공 session generation을 SyncEngine에 제공하지 않습니다",
)
provider_wire = wire_sync.find("SyncEngine.shared.captureAccountOwner =")
first_sync = wire_sync.find("Task { await SyncEngine.shared.syncNow() }")
if provider_wire < 0 or first_sync < 0 or provider_wire > first_sync:
    fail("owner 공급자를 연결하기 전에 SyncEngine 네트워크 작업을 시작합니다")

# owner를 캡처해도 각 endpoint가 URLRequest 생성 시점의 전역 Keychain을 다시 읽으면
# old queue가 새 세션 Bearer로 전송될 수 있다. 요청 시작 credential 값도 함께 고정한다.
if not re.search(r"struct\s+AuthorizationSnapshot\s*:\s*Sendable", server_api_code):
    fail("ServerAPI가 요청 시작 Bearer를 고정하는 Sendable AuthorizationSnapshot을 제공하지 않습니다")
authorization_snapshot = body(server_api, "struct AuthorizationSnapshot")
if "fileprivate let token: String?" not in authorization_snapshot:
    fail("AuthorizationSnapshot이 외부에 노출하지 않는 token 값을 보존하지 않습니다")
capture_authorization = body(server_api, "static func captureAuthorization()")
require_in_order(
    capture_authorization,
    ["TokenBox.load()", "!token.isEmpty", "return AuthorizationSnapshot(token: token)"],
    "ServerAPI가 비어 있지 않은 현재 Bearer snapshot을 원자적으로 캡처하지 않습니다",
)
if not re.search(
    r"static\s+func\s+request<T:\s*Decodable>[\s\S]*?authorization:\s*AuthorizationSnapshot\?\s*=\s*nil",
    server_api_code,
):
    fail("ServerAPI request 경계가 캡처 AuthorizationSnapshot을 받지 않습니다")
server_request = body(server_api, "static func request<T: Decodable>")
require_in_order(
    server_request,
    [
        "if authed, let authorization",
        "guard let token = authorization.token",
        "TokenBox.load() == token else { throw CancellationError() }",
        "requestToken = token",
        'req.setValue("Bearer \\(requestToken)", forHTTPHeaderField: "Authorization")',
    ],
    "ServerAPI가 캡처 token 일치 확인 뒤 그 token으로만 Authorization 헤더를 만들지 않습니다",
)
for marker, label in [
    ("static func patchMastery(", "mastery upload"),
    ("static func patchTopic(", "topic upload"),
    ("static func patchProgressSnapshot(", "progress snapshot upload"),
    ("static func getLearning(", "progress pull"),
    ("static func postEvents(", "event upload"),
    ("static func postWrongNotes(", "wrong-note upload"),
    ("static func getWrongNotes(", "wrong-note pull"),
    ("static func postReviewResult(", "review upload"),
    ("static func postStuckPoint(", "stuck-point upload"),
    ("static func getStuckPoints(", "stuck-point pull"),
    ("static func resetLearningProgress(", "progress reset upload"),
]:
    endpoint = body(server_api, marker)
    declaration = server_api_code[server_api_code.find(marker):server_api_code.find(marker) + 700]
    if "authorization: AuthorizationSnapshot? = nil" not in declaration:
        fail(f"ServerAPI {label} 경계가 AuthorizationSnapshot을 받지 않습니다")
    if endpoint.count("authorization: authorization") != 1:
        fail(f"ServerAPI {label}가 캡처 AuthorizationSnapshot을 generic request에 전달하지 않습니다")

# pull/ack callback도 String slot으로 축소하지 않고 캡처한 owner 전체를 전달한다.
callback_contracts = [
    (r"var\s+onServerID:\s*\(\(String,\s*String,\s*SyncAccountOwner\)\s*->\s*Void\)\?", "server ID ack"),
    (r"var\s+onRemoteWrongNotes:\s*\(\(\[WrongNoteEntry\],\s*SyncAccountOwner\)\s*async\s*->\s*Bool\)\?", "remote 오답 ack"),
    (r"var\s+onRemoteProgress:\s*\(\(\[ServerAPI\.RemoteConceptProgress\],\s*SyncAccountOwner\)\s*->\s*Void\)\?", "remote 진도"),
    (r"var\s+onRemoteStuckPoints:\s*\(\(\[ServerAPI\.RemoteStuckPoint\],\s*SyncAccountOwner\)\s*->\s*Void\)\?", "remote 막힘 지점"),
]
for pattern, label in callback_contracts:
    if not re.search(pattern, sync_engine_code):
        fail(f"{label} callback이 SyncAccountOwner 전체를 전달하지 않습니다")

for marker, save_call, label in [
    ("func mergeRemoteProgress(", "saveProgressV2()", "remote 진도 병합"),
    ("func attachServerAttemptID(", "saveWrongNotes()", "remote attempt 주소 반영"),
    ("func mergeRemoteStuckPoints(", "saveStuckPoints()", "remote 막힘 지점 병합"),
]:
    remote_mutation = body(app, marker)
    if "owner: SyncAccountOwner" not in app_code[app_code.find(marker) - 80:app_code.find(marker) + 240]:
        fail(f"{label}이 캡처한 SyncAccountOwner를 받지 않습니다")
    mutation_index = remote_mutation.find(save_call)
    owner_guard = remote_mutation.find("isSyncAccountOwnerActive(owner)")
    writable_guard = remote_mutation.find("isLearningSlotWritable(for: owner.slot)")
    if min(owner_guard, writable_guard, mutation_index) < 0 or not (
        owner_guard < mutation_index and writable_guard < mutation_index
    ):
        fail(f"{label}이 mutation 전에 session owner와 owner slot 쓰기 가능 여부를 검사하지 않습니다")
    if "isLearningAccountOperationActive(for: DataScope.slot)" in remote_mutation:
        fail(f"{label}이 source 전환 gate 때문에 mutation을 drop합니다")

# 오답 pull cursor는 AppStore가 캡처 owner 파일을 실제 저장했다는 async ack 뒤에만
# 전진한다. 별도 Task로 합치거나 owner slot을 버리면 handler 반환과 cursor가 앞선다.
if not re.search(
    r"func\s+mergeRemoteWrongNotes\s*\([\s\S]*?owner:\s*SyncAccountOwner[\s\S]*?\)\s*async\s*->\s*Bool",
    app_code,
):
    fail("remote 오답 병합이 SyncAccountOwner를 받는 async Bool ack 경계가 아닙니다")
remote_wrong_notes = body(app, "func mergeRemoteWrongNotes(")
if "saveWrongNotes()" in remote_wrong_notes or "Task {" in remote_wrong_notes:
    fail("remote 오답 병합이 owner 저장 완료를 기다리지 않고 fire-and-forget 합니다")
remote_persist = remote_wrong_notes.find("await persistLearningImmediately(snapshot, for: owner.slot)")
early_success = remote_wrong_notes.find("return true")
if remote_persist < 0 or (early_success >= 0 and early_success < remote_persist):
    fail("remote 오답 재시도가 changed=false일 때 내구 저장 전에 cursor 성공 ack를 반환합니다")
require_in_order(
    remote_wrong_notes,
    [
        "isSyncAccountOwnerActive(owner)",
        "isLearningSlotWritable(for: owner.slot)",
        "LearningPersistenceSnapshot.wrongNotes(wrongNotes)",
        "await persistLearningImmediately(snapshot, for: owner.slot)",
        "guard persisted, isSyncAccountOwnerActive(owner)",
        "isLearningSlotWritable(for: owner.slot)",
        "return true",
    ],
    "remote 오답 병합이 session owner 확인 → snapshot 내구 저장 → post-await session owner ack 순서를 지키지 않습니다",
)

wrong_note_handler = body(wire_sync, "SyncEngine.shared.onRemoteWrongNotes =")
if "Task {" in wrong_note_handler:
    fail("remote 오답 handler를 Task로 감싸면 저장 ack 전에 SyncEngine cursor가 전진합니다")
if wrong_note_handler.count("return await self.mergeRemoteWrongNotes(notes, owner: owner)") != 1:
    fail("remote 오답 handler가 SyncAccountOwner를 전달하고 merge 저장 ack를 await하지 않습니다")

pull_wrong_notes = body(sync_engine, "func pullWrongNotes() async")
if "Task {" in pull_wrong_notes:
    fail("remote 오답 pull이 handler를 별도 Task로 보내 cursor ack 순서를 끊습니다")
owner_capture = pull_wrong_notes.find("guard let owner = currentAccountOwner() else { return }")
slot_sync = pull_wrong_notes.find("syncSlotIfNeeded()", owner_capture)
loaded_slot_guard = pull_wrong_notes.find("loadedSlot == owner.slot", slot_sync)
loaded_generation_guard = pull_wrong_notes.find(
    "loadedSessionGeneration == owner.sessionGeneration", loaded_slot_guard)
authorization_capture = pull_wrong_notes.find(
    "let authorization = ServerAPI.captureAuthorization() else { return }", loaded_generation_guard)
throttle_check = pull_wrong_notes.find("if let last = lastPullAt", authorization_capture)
network_await = pull_wrong_notes.find("try await ServerAPI.getWrongNotes")
pre_merge_guard = pull_wrong_notes.find("guard isCurrentAccountOwner(owner) else { return }", network_await)
cursor_capture = pull_wrong_notes.find('let cursorKey = "matths.sync.lastPull." + owner.slot')
handler_ack = pull_wrong_notes.find("guard await handler(notes, owner) else")
post_owner_guard = pull_wrong_notes.find("guard isCurrentAccountOwner(owner) else { return }", handler_ack)
cursor_write = pull_wrong_notes.find("UserDefaults.standard.set(")
captured_cursor_use = pull_wrong_notes.find("forKey: cursorKey", cursor_write)
if (min(owner_capture, slot_sync, loaded_slot_guard, loaded_generation_guard,
        authorization_capture, throttle_check, cursor_capture, network_await,
        pre_merge_guard, handler_ack, post_owner_guard, cursor_write, captured_cursor_use) < 0
        or not (owner_capture < slot_sync < loaded_slot_guard < loaded_generation_guard
                < authorization_capture < throttle_check < cursor_capture
                < network_await < pre_merge_guard
                < handler_ack < post_owner_guard < cursor_write < captured_cursor_use)):
    fail("remote 오답이 owner 캡처 → same-slot epoch reload → credential/throttle → 응답 guard → durable ack → cursor 순서를 지키지 않습니다")

wrong_page = body(pull_wrong_notes, "repeat")
require_in_order(
    wrong_page,
    [
        "try await ServerAPI.getWrongNotes(",
        "authorization: authorization",
        "guard isCurrentAccountOwner(owner) else { return }",
        "rows.append(contentsOf: page.entries)",
        "cursor = page.hasMore == true ? page.nextCursor : nil",
    ],
    "remote 오답 pagination이 같은 credential을 쓰고 각 page await 직후 owner를 확인하지 않습니다",
)

for marker, network_call, handler_call, label in [
    ("func pullProgress() async", "try await ServerAPI.getLearning(authorization: authorization)", "handler(rows, owner)", "remote 진도 pull"),
    ("func pullStuckPoints() async", "try await ServerAPI.getStuckPoints(authorization: authorization)", "handler(rows, owner)", "remote 막힘 지점 pull"),
]:
    pull = body(sync_engine, marker)
    require_in_order(
        pull,
        [
            "guard let owner = currentAccountOwner()",
            "let authorization = ServerAPI.captureAuthorization() else { return }",
            network_call,
            "guard isCurrentAccountOwner(owner) else { return }",
            handler_call,
        ],
        f"{label}이 시작 시점 session owner를 캡처하고 post-await 검증 뒤 callback에 전달하지 않습니다",
    )

# stale session의 실패도 새 세션 UI에 쓰지 않는다. 모든 pull catch와 wrong-note
# durable-ack 실패 분기는 lastError보다 먼저 캡처 owner를 다시 확인해야 한다.
for marker, label in [
    ("func pullWrongNotes() async", "remote 오답 pull"),
    ("func pullProgress() async", "remote 진도 pull"),
    ("func pullStuckPoints() async", "remote 막힘 지점 pull"),
]:
    pull = body(sync_engine, marker)
    catch = body(pull, "catch")
    require_in_order(
        catch,
        ["guard isCurrentAccountOwner(owner) else { return }", "lastError ="],
        f"{label}의 stale session 오류가 새 세션 UI에 반영될 수 있습니다",
    )
wrong_ack_failure = body(pull_wrong_notes, "guard await handler(notes, owner) else")
require_in_order(
    wrong_ack_failure,
    ["if isCurrentAccountOwner(owner)", "lastError ="],
    "remote 오답 durable ack 실패가 stale session에서도 새 세션 오류 UI를 갱신합니다",
)

# 같은 물리 slot의 새 session에서는 아직 actor ack 전인 memory op를 버리지 않는다.
# 새 slot의 disk load/decode는 enqueue 버튼이 아니라 durable actor 경계에서 ID 병합한다.
sync_slot = body(sync_engine, "private func syncSlotIfNeeded()")
require_in_order(
    sync_slot,
    [
        "guard let owner = currentAccountOwner() else { return }",
        "guard loadedSlot != owner.slot",
        "|| loadedSessionGeneration != owner.sessionGeneration else { return }",
        "loadedSlot = owner.slot",
        "loadedSessionGeneration = owner.sessionGeneration",
        "queue = []",
        "lastPullAt = nil",
    ],
    "syncSlotIfNeeded가 owner 변경을 반영하되 enqueue hot path의 disk load를 제거하지 않습니다",
)
same_physical_slot = body(sync_slot, "if loadedSlot == owner.slot")
require_in_order(
    same_physical_slot,
    ["loadedSessionGeneration = owner.sessionGeneration", "lastPullAt = nil", "return"],
    "same-slot 새 session이 memory-only FIFO를 보존한 채 epoch/throttle을 갱신하지 않습니다",
)
if "loadQueue" in sync_slot or "Data(contentsOf:" in sync_slot:
    fail("sync enqueue hot path가 queue file read/decode를 동기로 수행합니다")

ensure_journal = body(sync_engine, "private func ensureJournalDurable(")
require_in_order(
    ensure_journal,
    [
        "await boundary.task.value",
        "await SyncQueueJournal.shared.snapshot",
        "guard isCurrentAccountOwner(owner)",
        "guard journalBoundaries[owner.slot] == nil else { continue }",
        "mergeDurableSnapshot(snapshot.operations)",
    ],
    "sync journal이 tail disk ack 뒤 actor snapshot을 owner 재검증·ID 병합하지 않습니다",
)
merge_journal = body(sync_engine, "private func mergeDurableSnapshot(")
require_in_order(
    merge_journal,
    ["for operation in durable", "for operation in queue", "queue = merged"],
    "sync journal 재적재가 durable FIFO 뒤 memory-only FIFO를 ID 병합하지 않습니다",
)
belongs_to_owner = body(sync_engine, "private func belongsToCurrentAccount(")
require_in_order(
    belongs_to_owner,
    [
        "guard let owner = currentAccountOwner() else { return false }",
        "loadedSlot == owner.slot",
        "loadedSessionGeneration == owner.sessionGeneration",
        "(op.slot ?? loadedSlot) == owner.slot",
    ],
    "outbound queue 항목이 현재 slot+sessionGeneration의 메모리 queue 소유권을 확인하지 않습니다",
)

# outbound flush는 시작 owner를 한 번 캡처해 모든 await 결과와 queue 변경에 사용한다.
sync_flush = body(sync_engine, "func flush() async")
require_in_order(
    sync_flush,
    [
        "syncSlotIfNeeded()",
        "guard let owner = currentAccountOwner()",
        "loadedSessionGeneration == owner.sessionGeneration",
        "await ensureJournalDurable(for: owner)",
        "let authorization = ServerAPI.captureAuthorization()",
    ],
    "outbound flush가 durable journal 뒤 request owner와 AuthorizationSnapshot을 캡처하지 않습니다",
)
flush_success = body(sync_flush, "do")
require_in_order(
    flush_success,
    [
        "try await send(op, owner: owner, authorization: authorization)",
        "guard isCurrentAccountOwner(owner)",
        "!invalidatedJournalSlots.contains(owner.slot)",
        "belongsToCurrentAccount(op)",
        "queue.first?.id == op.id else { return }",
        "await scheduleJournalReplacement(",
        "guard persisted else",
        "queue.removeFirst()",
    ],
    "outbound flush가 owner/head 확인과 remaining rewrite disk ack 전에 memory head를 제거합니다",
)
flush_catch = body(sync_flush, "catch")
require_in_order(
    flush_catch,
    [
        "guard isCurrentAccountOwner(owner)",
        "!invalidatedJournalSlots.contains(owner.slot)",
        "belongsToCurrentAccount(op)",
        "queue.first?.id == op.id else { return }",
        "lastError =",
    ],
    "outbound flush의 stale session 실패가 owner queue 확인 전에 오류/재시도 상태를 변경합니다",
)

sync_send = body(sync_engine, "private func send(\n        _ op: SyncOp")
if not re.search(
    r"private\s+func\s+send\s*\([\s\S]*?owner:\s*SyncAccountOwner[\s\S]*?authorization:\s*ServerAPI\.AuthorizationSnapshot",
    sync_engine_code,
):
    fail("outbound send가 request owner와 AuthorizationSnapshot을 함께 받지 않습니다")
sync_server_calls = re.findall(r"ServerAPI\.\w+\s*\(", sync_send)
if not sync_server_calls or sync_send.count("authorization: authorization") != len(sync_server_calls):
    fail("outbound send의 모든 ServerAPI 호출이 시작 시 캡처한 AuthorizationSnapshot을 쓰지 않습니다")
wrong_send_start = sync_send.find("case .wrongNote:")
wrong_send_end = sync_send.find("case .reviewResult:", wrong_send_start)
if wrong_send_start < 0 or wrong_send_end < 0:
    fail("outbound wrong-note send 분기를 찾지 못했습니다")
wrong_send = sync_send[wrong_send_start:wrong_send_end]
require_in_order(
    wrong_send,
    [
        "try await ServerAPI.postWrongNotes",
        "guard isCurrentAccountOwner(owner) else { return }",
        "onServerID?(cid, sid, owner)",
    ],
    "server attempt ID ack가 postWrongNotes await 뒤 session owner 확인 없이 전달됩니다",
)
server_id_wire = body(wire_sync, "SyncEngine.shared.onServerID =")
if "Task {" in server_id_wire:
    fail("server attempt ID ack를 Task로 미뤄 캡처 owner 검증 경계를 끊습니다")
if "self?.attachServerAttemptID(client: client, server: server, owner: owner)" not in server_id_wire:
    fail("AppStore server attempt ID ack가 캡처한 SyncAccountOwner를 전달하지 않습니다")

if "private var learningPersistenceMutationGeneration: UInt64 = 0" not in app_code:
    fail("flush 명령 revision과 실제 메모리 mutation 세대를 분리하지 않았습니다")
mutation_marker = body(app, "private func markLearningPersistenceMutation")
if "learningPersistenceMutationGeneration &+= 1" not in mutation_marker:
    fail("학습 snapshot mutation 세대가 단조 증가하지 않습니다")

schedule_persistence = body(app, "private func scheduleLearningPersistence")
if "let slot = DataScope.slot" not in schedule_persistence:
    fail("enqueue 시점의 계정 슬롯을 캡처하지 않습니다")
if "!disabledLearningPersistenceSlots.contains(slot)" not in schedule_persistence:
    fail("탈퇴 장벽 재진입 중 새 저장 명령을 막는 로컬 슬롯 게이트가 없습니다")
if any(gate in schedule_persistence for gate in (
    "transitioningLearningPersistenceSlots", "isLearningAccountOperationActive", "isLearningSlotWritable"
)):
    fail("계정 전환 중 mutation 저장을 drop하면 remote cursor와 마지막 snapshot이 유실됩니다")
require_in_order(
    schedule_persistence,
    ["let slot = DataScope.slot", "!disabledLearningPersistenceSlots.contains(slot)",
     "markLearningPersistenceMutation()", "nextLearningPersistenceRevision()"],
    "schedule이 disabled 검사 뒤 mutation 세대와 command revision을 발급하지 않습니다",
)

request_immediate = body(app, "private func requestImmediateLearningPersistence")
if "!disabledLearningPersistenceSlots.contains(slot)" not in request_immediate:
    fail("탈퇴 장벽 중 fire-and-forget 즉시 저장을 막지 않습니다")
if any(gate in request_immediate for gate in (
    "transitioningLearningPersistenceSlots", "isLearningAccountOperationActive", "isLearningSlotWritable"
)):
    fail("계정 전환 중 즉시 mutation 저장을 drop하면 마지막 snapshot이 유실됩니다")
require_in_order(
    request_immediate,
    ["let slot = DataScope.slot", "!disabledLearningPersistenceSlots.contains(slot)",
     "markLearningPersistenceMutation()", "nextLearningPersistenceRevision()"],
    "fire-and-forget 즉시 저장이 disabled 검사 뒤 mutation/revision을 발급하지 않습니다",
)

persist_immediately = body(app, "private func persistLearningImmediately")
if "!disabledLearningPersistenceSlots.contains(slot)" not in persist_immediately:
    fail("탈퇴 장벽 중 awaited 즉시 저장을 막지 않습니다")
if any(gate in persist_immediately for gate in (
    "transitioningLearningPersistenceSlots", "isLearningAccountOperationActive", "isLearningSlotWritable"
)):
    fail("계정 전환 중 awaited mutation 저장을 drop하면 remote cursor가 유실됩니다")
require_in_order(
    persist_immediately,
    ["let slot = ownerSlot ?? DataScope.slot",
     "!disabledLearningPersistenceSlots.contains(slot)",
     "markLearningPersistenceMutation()", "nextLearningPersistenceRevision()",
     "await LearningPersistence.writer.writeImmediately(",
     "return outcome == .written"],
    "awaited 즉시 저장이 disabled 검사 뒤 mutation/revision을 발급하고 written만 성공 처리하지 않습니다",
)
if app_code.count("markLearningPersistenceMutation()") != 4:
    fail("mutation 세대 증가는 schedule/request/persist 세 경계에만 있어야 합니다")
slot_save = body(wrong_store, "static func save(_ list: [WrongNoteEntry], for slot: String)")
if 'DataScope.url("wrongnotes.json", for: slot)' not in slot_save:
    fail("오답 writer가 캡처한 슬롯 URL을 쓰지 않습니다")
wrong_write = body(wrong_store, "private static func save(")
for required, message in [
    ("fm.copyItem(at: fileURL, to: backupURL)", "오답 직전 세대 backup 복사가 사라졌습니다"),
    ("data.write(to: tmp, options: .atomic)", "오답 임시 파일 atomic 쓰기가 사라졌습니다"),
    ("fm.replaceItemAt(fileURL, withItemAt: tmp)", "오답 본 파일 원자 교체가 사라졌습니다"),
    ("WrongNoteStorageAlertCenter.shared.raise", "오답 저장 실패 사용자 배너가 사라졌습니다"),
]:
    if required not in wrong_write:
        fail(message)

grade = body(app, "func gradeCurrent(")
if "WrongNoteDisk.save(wrongNotes)" in grade or "progressV2.save()" in grade:
    fail("채점 버튼 본문에 동기 전체 snapshot 저장이 돌아왔습니다")
if "saveWrongNotes()" not in grade or "saveProgressV2()" not in grade:
    fail("채점 메모리 변경이 actor writer에 배선되지 않았습니다")

answer = body(app, "func setPaperAnswer(")
if "attemptsV2.save()" in answer or "JSONEncoder" in answer or ".write(" in answer:
    fail("평가 입력이 매 글자마다 메인 액터에서 전체 회차를 저장합니다")
if "saveAttemptsV2()" not in answer:
    fail("평가 입력 최신 snapshot이 writer로 가지 않습니다")

flush = body(app, "func flushAssessmentDraft() async")
if not re.search(r"await\s+persistLearningImmediately\s*\(\s*\.assessments", flush):
    fail("평가 화면 이탈 전 로컬 최신 답안을 즉시 저장하지 않습니다")
header = body(paper, "private var header: some View")
exit_task = body(header, "Task")
draft_flush = exit_task.find("await store.flushAssessmentDraft()")
exit_route = exit_task.find("store.route = .assess")
if draft_flush < 0 or exit_route < 0 or draft_flush > exit_route:
    fail("평가 나가기에서 로컬 flush 완료 전에 화면을 전환합니다")

# 평가 네트워크/파일 await 동안 같은 물리 슬롯의 새 세션이 시작될 수도 있다.
# 캡처한 AccountSessionBoundary가 아직 활성인지 다시 확인한 뒤에만 상태를 반영한다.
start_server_paper = body(app, "private func startServerPaper(")
pull_assessments = body(app, "func pullServerAssessments() async")
flush_draft = body(app, "func flushAssessmentDraft() async")
submit_server_paper = body(app, "private func submitServerPaper(")
submit_local_paper = body(app, "private func submitLocalPaper(")
schedule_draft = body(app, "private func scheduleAssessmentDraft(")

require_in_order(
    submit_local_paper,
    [
        "guard var a = currentAttempt",
        "assessmentPersistenceTransactionInFlight = true",
        "defer { assessmentPersistenceTransactionInFlight = false }",
        "await persistLearningImmediately(",
    ],
    "로컬 평가 제출이 첫 파일 await 전에 stable-flush 직렬화 게이트를 소유하지 않습니다",
)

for function_body, slot, label in [
    (start_server_paper, "account", "서버 평가 시작"),
    (pull_assessments, "account", "서버 평가 pull"),
    (flush_draft, "account", "평가 draft flush"),
    (submit_server_paper, "account", "서버 평가 제출"),
]:
    require_assessment_persist_gates(function_body, slot, label)
require_assessment_persist_gates(
    submit_local_paper,
    "account",
    "로컬 평가 제출",
    "ownsLocalAssessmentPersistenceTransaction(account)",
)
if submit_local_paper.count("ownsLocalAssessmentPersistenceTransaction(account)") != 4:
    fail("로컬 평가 제출의 snapshot 세 경계와 side-effect journal 경계가 트랜잭션 owner를 검사해야 합니다")

# 로컬 제출은 제출 완료 회차만 먼저 저장하고 오답을 debounce하면 안 된다. 오답 정본을
# 먼저 내구 저장하고 assessment까지 성공한 뒤에만 submitted 메모리와 통계/동기 부작용을
# 공개해야, 두 파일 사이 종료에서도 재제출 가능 상태가 남는다.
require_in_order(
    submit_local_paper,
    [
        "var updatedAttempts = attemptsV2",
        "var updatedWrongNotes = wrongNotes",
        "let wrongNotesPersisted = await persistLearningImmediately(",
        ".wrongNotes(updatedWrongNotes)",
        "ownsLocalAssessmentPersistenceTransaction(account)",
        "guard wrongNotesPersisted else",
        "let assessmentPersisted = await persistLearningImmediately(",
        ".assessments(updatedAttempts.attempts)",
        "ownsLocalAssessmentPersistenceTransaction(account)",
        "guard assessmentPersisted else",
        "attemptsV2 = updatedAttempts",
        "wrongNotes = updatedWrongNotes",
        "EventLog.appendGrading(",
        "SyncEngine.shared.enqueueGradingEvents(",
    ],
    "로컬 평가 제출이 오답→회차 내구 저장을 닫기 전에 submitted 상태나 통계·동기 부작용을 공개합니다",
)
wrong_failure = body(submit_local_paper, "guard wrongNotesPersisted else")
if "attemptsV2 = updatedAttempts" in wrong_failure or "wrongNotes = updatedWrongNotes" in wrong_failure:
    fail("오답 저장 실패인데 로컬 평가 제출 상태를 메모리에 공개합니다")
assessment_failure = body(submit_local_paper, "guard assessmentPersisted else")
if "wrongNotes = updatedWrongNotes" not in assessment_failure or "attemptsV2 = updatedAttempts" in assessment_failure:
    fail("회차 저장 실패 시 이미 내구 저장된 오답만 유지하고 submitted 회차는 공개하지 않아야 합니다")
if "saveWrongNotes()" in submit_local_paper:
    fail("로컬 평가 제출의 파생 오답을 성공 경계 뒤 debounce 저장하면 종료 시 영구 누락됩니다")
require_in_order(
    submit_local_paper,
    [
        "if let existing = updatedWrongNotes.firstIndex",
        "updatedWrongNotes[existing].serverAttemptId == nil",
        "wrongNotesToSync.append(updatedWrongNotes[existing])",
        "guard assessmentPersisted else",
        "for note in wrongNotesToSync",
        "SyncEngine.shared.enqueueWrongNote(note)",
        "await EventLog.flushPendingWrites(for: account.slot)",
        "await SyncEngine.shared.flushLocalQueuePersistence()",
        "ownsLocalAssessmentPersistenceTransaction(account)",
    ],
    "회차 저장 실패 뒤 재시도한 기존 오답이나 제출 side effect journal이 영구 누락될 수 있습니다",
)

require_in_order(
    start_server_paper,
    [
        "try await ServerAPI.startAssessment(",
        "isLearningAccountOperationActive(for: account)",
        "attemptsV2.upsert(attempt)",
    ],
    "서버 평가 시작 응답이 계정 전환 게이트보다 먼저 새 attempt를 반영합니다",
)
require_in_order(
    pull_assessments,
    [
        "try await ServerAPI.assessmentSnapshot()",
        "isLearningAccountOperationActive(for: account)",
        "attemptsV2.replaceServerSnapshot(values)",
    ],
    "서버 평가 pull 응답이 계정 전환 게이트보다 먼저 snapshot을 반영합니다",
)
require_in_order(
    schedule_draft,
    [
        "await Task.sleep",
        "isLearningAccountOperationActive(for: account)",
        "await ServerAPI.saveAssessmentDraft(",
    ],
    "debounce된 평가 draft가 await 뒤 전환 중 source 계정으로 전송될 수 있습니다",
)
for network_call in (
    "await ServerAPI.expireAssessment(",
    "await ServerAPI.submitAssessment(",
):
    network_index = submit_server_paper.find(network_call)
    gate_index = submit_server_paper.find(
        "isLearningAccountOperationActive(for: account)", network_index)
    mutation_index = submit_server_paper.find("attemptsV2.upsert(updated)", network_index)
    if network_index < 0 or gate_index < 0 or mutation_index < 0 or gate_index > mutation_index:
        fail("서버 평가 제출 응답이 계정 전환 게이트보다 먼저 attempt를 반영합니다")

for function_body, slot, label in [
    (start_server_paper, "account", "서버 평가 시작"),
    (pull_assessments, "account", "서버 평가 pull"),
    (schedule_draft, "account", "평가 draft 저장"),
    (flush_draft, "account", "평가 draft flush"),
    (submit_server_paper, "account", "서버 평가 제출"),
]:
    catch_body = body(function_body, "catch")
    require_in_order(
        catch_body,
        [f"isLearningAccountOperationActive(for: {slot})", "assessmentSyncError"],
        f"{label} await 실패가 계정 전환 게이트보다 먼저 오류 UI를 갱신합니다",
    )

# scenePhase background 경계는 iOS background assertion을 잡은 helper로 들어가야 한다.
# helper Task가 async flush를 실제 await한 뒤 정상·만료 경로 모두 assertion을 끝내고,
# async flush 자체도 writer 완료를 await해야 한다.
learning_flush = body(app, "func flushLearningPersistence() async")
if "Task {" in learning_flush:
    fail("background flush 내부에서 다시 fire-and-forget Task를 만들면 내구 장벽이 아닙니다")
if "await " not in learning_flush:
    fail("background flush가 writer 완료를 실제로 기다리지 않습니다")
if learning_flush.count("let slot = DataScope.slot") != 1:
    fail("flush가 owner slot을 진입 시점에 정확히 한 번만 캡처하지 않습니다")
if "private var assessmentPersistenceTransactionInFlight = false" not in app_code:
    fail("로컬 평가의 두 파일 제출을 stable flush와 직렬화하는 게이트가 없습니다")
require_in_order(
    learning_flush,
    [
        "while assessmentPersistenceTransactionInFlight",
        "DataScope.slot == slot",
        "await Task.sleep",
        "while !Task.isCancelled",
    ],
    "stable flush가 로컬 평가 wrongNotes→assessment 트랜잭션 전에 옛 메모리를 쓸 수 있습니다",
)
flush_loop = body(learning_flush, "while !Task.isCancelled")
if "let slot = DataScope.slot" in flush_loop:
    fail("flush 반복 중 현재 슬롯을 다시 캡처하면 새 계정 메모리를 old URL에 쓸 수 있습니다")
if "markLearningPersistenceMutation()" in learning_flush:
    fail("flush 명령 자체가 mutation 세대를 올리면 동시 flush가 서로를 깨워 livelock합니다")
if "learningPersistenceRevision == captured" in learning_flush:
    fail("flush 안정성을 command revision으로 판정하면 동시 flush가 livelock합니다")
for snapshot in (".progress(", ".wrongNotes(", ".assessments(", ".stuckPoints("):
    if flush_loop.count(snapshot) != 1:
        fail(f"background flush가 {snapshot} 최신 snapshot을 정확히 한 번 제출하지 않습니다")
pre_capture_disabled = flush_loop.find(
    "guard !disabledLearningPersistenceSlots.contains(slot) else { return false }")
first_snapshot = flush_loop.find("let snapshots:")
if pre_capture_disabled < 0 or first_snapshot < 0 or pre_capture_disabled > first_snapshot:
    fail("flush 재캡처 반복이 invalidate된 슬롯에 새 revision을 발급할 수 있습니다")
require_in_order(
    flush_loop,
    [
        "LearningPersistence.key(for: snapshot, slot: slot)",
        "let capturedMutationGeneration = learningPersistenceMutationGeneration",
        "let outcomes = await LearningPersistence.writer.writeImmediately(writes)",
        "guard outcomes.count == writes.count else { return false }",
        "if outcomes.values.contains(.ioFailed) { return false }",
        "guard DataScope.slot == slot else { return true }",
        "guard !disabledLearningPersistenceSlots.contains(slot) else { return false }",
        "if outcomes.values.contains(.superseded) { continue }",
        "if learningPersistenceMutationGeneration == capturedMutationGeneration { return true }",
    ],
    "flush가 batch 결과 → I/O 실패 → old-slot 종료 → superseded 재캡처 → mutation 안정성을 올바른 순서로 판정하지 않습니다",
)
if "allSatisfy" in flush_loop or "outcomes.values.contains(.written)" in flush_loop:
    fail("flush가 superseded 정상 경합을 I/O 실패로 오인할 수 있습니다")
slot_changed_exit = flush_loop.find("guard DataScope.slot == slot else { return true }")
first_superseded_check = flush_loop.find(".superseded")
if first_superseded_check < 0 or first_superseded_check < slot_changed_exit:
    fail("flush가 old-slot 종료 전에 superseded를 실패 처리하거나 재캡처해 새 메모리를 old URL에 쓸 수 있습니다")

scene_phase = body(app, ".onChange(of: scenePhase)")
background_branch = body(scene_phase, "if phase == .background {")
background_start = "LearningPersistenceBackgroundFlush.shared.start(store: store)"
if background_branch.count(background_start) != 1:
    fail("scenePhase background 분기가 학습 저장 background assertion helper를 정확히 한 번 시작하지 않습니다")
if "store.flushLearningPersistence()" in background_branch:
    fail("scenePhase가 helper 밖에서 별도 flush를 호출해 저장을 중복합니다")

background_helper = body(app, "private final class LearningPersistenceBackgroundFlush")
background_start_body = body(background_helper, "func start(store: AppStore)")
begin_call = "UIApplication.shared.beginBackgroundTask("
if background_start_body.count(begin_call) != 1:
    fail("background flush helper가 iOS background task를 정확히 한 번 시작하지 않습니다")

background_task = body(background_start_body, "task = Task")
await_flush = "await store.flushLearningPersistence()"
if background_task.count(await_flush) != 1:
    fail("background assertion 안의 Task가 async 학습 저장 flush를 정확히 한 번 await하지 않습니다")
for durable_flush, label in [
    ("await EventLog.flushPendingWrites()", "로컬 학습 이벤트"),
    ("await SyncEngine.shared.flushLocalQueuePersistence()", "서버 동기화 journal"),
]:
    if background_task.count(durable_flush) != 1:
        fail(f"background assertion이 {label} disk ack를 정확히 한 번 await하지 않습니다")
await_index = background_task.find(await_flush)
normal_finish_index = background_task.find("finish(token)", await_index)
if normal_finish_index < 0:
    fail("background 학습 저장 await가 끝난 뒤 정상 완료 경로에서 assertion을 종료하지 않습니다")

expiration_handler = body(background_start_body, "withName:")
if "finish(token, cancelling: true)" not in expiration_handler:
    fail("iOS background task 만료 경로가 저장 Task를 취소하고 assertion을 종료하지 않습니다")

background_finish = body(background_helper, "private func finish(")
if "guard generation == token else { return }" not in background_finish:
    fail("background task 정상 완료와 만료가 겹칠 때 중복 종료를 막는 세대 guard가 없습니다")
if background_finish.count("UIApplication.shared.endBackgroundTask(") != 1:
    fail("background flush helper가 iOS background task를 정확히 한 번 끝내는 경계를 갖지 않습니다")
if "activeIdentifier != .invalid" not in background_finish:
    fail("유효하지 않은 iOS background task 식별자를 종료할 수 있습니다")

complete = body(concept, "private func completeSection(")
if complete.count("store.completeConceptV2(concept)") != 1:
    fail("완료 CTA가 단일 AppStore 경계를 정확히 한 번 타지 않습니다")
if "store.progressV2.setUserCompleted" in complete or "store.markConceptComplete" in complete:
    fail("완료 CTA에 중복 진도 저장/서버 enqueue 경로가 돌아왔습니다")
complete_boundary = body(app, "func completeConceptV2(")
required_once = [
    ("progressV2.setUserCompleted(true, concept: concept)", "v2 완료 메모리 변경"),
    ("completedConceptIDs.insert(appID)", "legacy 완료 ID 반영"),
    ("Progress.save(completedConceptIDs)", "legacy 완료 ID 저장"),
    ("saveProgressV2()", "v2 snapshot 저장"),
    ("SyncEngine.shared.enqueueConceptCompletion(", "서버 완료 enqueue"),
]
for call, label in required_once:
    if complete_boundary.count(call) != 1:
        fail(f"completeConceptV2의 {label} 경로는 정확히 한 번이어야 합니다")
if "markConceptComplete(" in complete_boundary:
    fail("completeConceptV2가 legacy helper를 다시 호출해 v2 저장·서버 enqueue를 중복합니다")
completion_order = [complete_boundary.find(call) for call, _ in required_once]
if completion_order != sorted(completion_order):
    fail("completeConceptV2는 메모리/legacy 저장 → v2 snapshot → 서버 enqueue 순서여야 합니다")

topic_button = body(concept, "struct TopicCheckRow: View")
if "store.toggleConceptTopic(index, concept: concept)" not in topic_button:
    fail("토픽 체크가 계정 전환 게이트 밖에서 progress를 직접 바꿉니다")
for forbidden in ("progressV2.toggleTopic", "saveProgressV2()", "EventLog.append", "enqueueTopic"):
    if forbidden in topic_button:
        fail("토픽 체크 View가 AppStore 단일 mutation 경계를 우회합니다")
topic_boundary = body(app, "func toggleConceptTopic(")
require_in_order(
    topic_boundary,
    [
        "isLearningAccountOperationActive(for: DataScope.slot)",
        "progressV2.toggleTopic",
        "saveProgressV2()",
        "EventLog.append(",
        "SyncEngine.shared.enqueueTopic(",
    ],
    "토픽 체크가 계정 게이트 → 메모리 → snapshot → 이벤트 순서를 지키지 않습니다",
)

for marker, first_mutation, label in [
    ("func recordKice(", "EventLog.appendGrading", "기출 채점"),
    ("func setErrorType(", "wrongNotes[idx].errorType", "오답 유형 수정"),
    ("func setDivergence(", "divergenceStep = step", "오답 갈림 단계 수정"),
]:
    mutation_body = body(app, marker)
    require_in_order(
        mutation_body,
        ["isLearningAccountOperationActive(for: DataScope.slot)", first_mutation],
        f"{label}가 계정 전환 게이트보다 먼저 메모리/이벤트를 바꿉니다",
    )

reset = body(app, "func resetProgress() async")
if not re.search(r"persistLearningImmediately\s*\(\s*\.progress", reset):
    fail("파괴적 진도 초기화가 pending을 이긴 즉시 저장을 기다리지 않습니다")
reset_started = reset.find("progressResetInFlight = true")
reset_release = reset.find("defer { progressResetInFlight = false }")
reset_persist = reset.find("await persistLearningImmediately")
reset_post_await_gate = reset.find("isLearningAccountOperationActive(for: slot)", reset_persist)
if (min(reset_started, reset_release, reset_persist, reset_post_await_gate) < 0
        or not (reset_started < reset_release < reset_persist < reset_post_await_gate)):
    fail("진도 초기화 in-flight 직렬화가 내구 저장 await 전체를 감싸지 않습니다")
if "store.progressV2 = ProgressV2Store()" in profile_code:
    fail("프로필 호출부가 AppStore 초기화를 다시 반복합니다")
require_in_order(
    reset,
    [
        "await persistLearningImmediately(",
        "guard persisted else",
        "await SyncEngine.shared.enqueueProgressResetDurably()",
        "guard resetQueued else",
    ],
    "진도 초기화가 빈 snapshot 뒤 서버 reset journal의 disk ack까지 닫지 않습니다",
)
if "SyncEngine.shared.enqueueProgressReset()" in reset:
    fail("파괴적 진도 초기화가 fire-and-forget sync journal을 사용합니다")

switch_slot = body(app, "private func switchDataSlot(")

# reset을 기다리는 중에도 나중 요청이 앞 요청을 선점해야 하므로 generation은
# wait 진입 전에 갱신한다. 같은-slot 조기 성공 역시 이 새 세대를 소유한다.
generation_created = switch_slot.find("let generation = UUID()")
generation_updated = switch_slot.find("accountTransitionGeneration = generation")
reset_wait_start = switch_slot.find("while progressResetInFlight")
same_slot_return = switch_slot.find("guard target != DataScope.slot else")
if (min(generation_created, generation_updated, reset_wait_start, same_slot_return) < 0
        or not (generation_created < generation_updated < reset_wait_start < same_slot_return)):
    fail("계정 전환 generation을 reset 대기 전에 선점하지 않습니다")

# 성공한 세션 epoch는 전환 시도 generation과 별개다. 같은 물리 slot 재인증도 새
# session이다. 실제 switchTo는 알림을 동기로 게시하므로 새 epoch를 먼저 공개하고,
# switch 실패 때만 이전 epoch로 되돌린다.
same_slot_branch = body(switch_slot, "guard target != DataScope.slot else")
require_in_order(
    same_slot_branch,
    ["guard beforeSwitch?() ?? true else { return false }", "accountSessionGeneration = UUID()", "return true"],
    "same-slot 재인증이 commit 성공 뒤 새 session generation을 발급하지 않습니다",
)
require_in_order(
    switch_slot,
    [
        "guard beforeSwitch?() ?? true else { return false }",
        "let previousSessionGeneration = accountSessionGeneration",
        "accountSessionGeneration = UUID()",
        "guard DataScope.switchTo(target) else",
        "clearTransientAccountState()",
        "reloadLocalData()",
    ],
    "slot 변경이 새 session generation 공개 → switchTo 알림 → 새 데이터 reload 순서를 지키지 않습니다",
)
failed_data_scope_switch = body(switch_slot, "guard DataScope.switchTo(target) else")
require_in_order(
    failed_data_scope_switch,
    ["accountSessionGeneration = previousSessionGeneration", "return false"],
    "DataScope.switchTo 실패가 미리 공개한 session generation을 복원하지 않습니다",
)

# reset의 빈 snapshot 저장과 서버 journal 적재가 끝날 때까지 슬롯 전환을 시작하지 않는다.
target_capture = switch_slot.find("let target = DataScope.slotName")
reset_wait = body(switch_slot, "while progressResetInFlight")
if (reset_wait_start < 0 or target_capture < 0 or reset_wait_start > target_capture
        or not re.search(r"\bawait\b", reset_wait)):
    fail("계정 전환이 진행 중인 진도 초기화를 await해 직렬화하지 않습니다")
if "generation == accountTransitionGeneration" not in reset_wait:
    fail("reset을 기다리는 앞 계정 전환이 더 최신 generation에 선점돼도 계속 진행합니다")

# source gate는 Set이 아니라 [slot:generation] owner map이다. 앞 전환의 defer가 같은
# source를 이어받은 새 전환의 gate를 열지 못하도록 자기 generation일 때만 제거한다.
if "private var transitioningLearningPersistenceSlots: [String: UUID] = [:]" not in app_code:
    fail("계정 전환 source gate가 slot별 generation owner map이 아닙니다")
source_gate_close = switch_slot.find("transitioningLearningPersistenceSlots[source] = generation")
flush_capture = switch_slot.find("await flushLearningPersistence()")
data_scope_switch = switch_slot.find("DataScope.switchTo(target)")
if (min(source_gate_close, flush_capture, data_scope_switch) < 0
        or not (source_gate_close < flush_capture < data_scope_switch)):
    fail("source generation 소유권을 잡기 전에 최종 snapshot을 flush하거나 슬롯을 바꿉니다")
source_gate_defer = body(switch_slot, "defer")
require_in_order(
    source_gate_defer,
    [
        "transitioningLearningPersistenceSlots[source] == generation",
        "transitioningLearningPersistenceSlots.removeValue(forKey: source)",
    ],
    "앞 계정 전환 defer가 더 최신 source generation의 gate를 열 수 있습니다",
)
if switch_slot.count("transitioningLearningPersistenceSlots.removeValue(forKey: source)") != 1:
    fail("source generation gate 제거는 owner 확인 defer 한 곳에만 있어야 합니다")
flush_pending = body(switch_slot, "if flushPending")
require_in_order(
    flush_pending,
    [
        "await flushLearningPersistence()",
        "await EventLog.flushPendingWrites(for: source)",
        "await SyncEngine.shared.flushLocalQueuePersistence()",
        "if !(snapshotsPersisted && eventsPersisted && syncQueuePersisted)",
        "return false",
    ],
    "계정 전환이 source snapshot·event·sync journal disk ack 실패 뒤에도 계속할 수 있습니다",
)
require_in_order(
    switch_slot,
    [
        "await SyncEngine.shared.activateLocalQueuePersistence(for: target)",
        "await EventLog.activatePendingWrites(for: target)",
        "guard generation == accountTransitionGeneration",
        "guard beforeSwitch?() ?? true else { return false }",
        "DataScope.switchTo(target)",
    ],
    "계정 전환이 target writer tombstone 재개와 generation 검증을 안전한 순서로 닫지 않습니다",
)

withdraw = body(profile, "private func submit() async")
withdraw_owner = withdraw.find("let withdrawn = await MainActor.run")
withdraw_slot = withdraw.find("slot: DataScope.slot", withdraw_owner)
withdraw_directory = withdraw.find("directory: DataScope.directory", withdraw_owner)
withdraw_session = withdraw.find("session: store.captureAccountSessionBoundary()", withdraw_owner)
withdraw_requests = [match.start() for match in re.finditer(
    re.escape("try await ServerAPI.withdrawMe("), withdraw)]
if (min(withdraw_owner, withdraw_slot, withdraw_directory, withdraw_session) < 0
        or len(withdraw_requests) != 4
        or not all(withdraw_session < request for request in withdraw_requests)):
    fail("탈퇴 owner slot·directory·session을 withdrawMe 네트워크 await 전에 캡처하지 않습니다")

capture_session = body(app, "func captureAccountSessionBoundary()")
if "private var accountSessionGeneration = UUID()" not in app_code:
    fail("성공한 owner session 세대를 전환 시도 generation과 분리하지 않았습니다")
if "slot: DataScope.slot" not in capture_session or "generation: accountSessionGeneration" not in capture_session:
    fail("탈퇴 세션 경계가 owner slot과 account generation을 함께 캡처하지 않습니다")
owns_session = body(app, "func ownsCurrentAccountSession(")
if "boundary.slot == DataScope.slot" not in owns_session or "boundary.generation == accountSessionGeneration" not in owns_session:
    fail("탈퇴 응답 뒤 현재 세션 소유권을 slot+generation으로 검증하지 않습니다")
for required, message in [
    ("invalidateLearningPersistence(for: withdrawn.slot)", "탈퇴 writer 장벽이 캡처한 owner slot을 쓰지 않습니다"),
    ("ownsCurrentAccountSession(withdrawn.session)", "탈퇴 응답이 캡처한 session 소유권을 확인하지 않습니다"),
    ("purgeWithdrawnSlot(named: withdrawn.slot, directory: withdrawn.directory)", "탈퇴 정리가 캡처한 owner directory를 쓰지 않습니다"),
]:
    if required not in withdraw:
        fail(message)
order = [
    withdraw.find("withdrawMe("),
    withdraw.find("invalidateLearningPersistence"),
    withdraw.find("signOut(discardingCurrentSlot: true)"),
    withdraw.find("purgeWithdrawnSlot"),
]
if any(index < 0 for index in order) or order != sorted(order):
    fail("탈퇴 순서가 서버 2xx → writer 장벽 → 세션 전환 → 슬롯 삭제가 아닙니다")
invalidate = body(app, "func invalidateLearningPersistence(for slot: String) async")
local_close = invalidate.find("disabledLearningPersistenceSlots.insert(slot)")
sync_close = invalidate.find("await SyncEngine.shared.invalidateLocalQueuePersistence(for: slot)")
event_close = invalidate.find("await EventLog.invalidatePendingWrites(for: slot)")
actor_close = invalidate.find("await LearningPersistence.writer.invalidate")
if (min(local_close, sync_close, event_close, actor_close) < 0
        or not (local_close < sync_close < event_close < actor_close)):
    fail("탈퇴가 owner 슬롯 로컬 게이트 → sync/event/snapshot writer 순서로 닫히지 않습니다")
if "disabledLearningPersistenceSlots.remove(target)" not in switch_slot:
    fail("명시적 재가입 슬롯 전환에서만 저장 게이트를 다시 열어야 합니다")
if "LearningPersistence" in iap_code or "DebouncedSnapshotWriter" in iap_code:
    fail("결제 흐름을 일반 debounce writer에 연결하면 안 됩니다")

print("Learning persistence source wiring contract passed")
PY
