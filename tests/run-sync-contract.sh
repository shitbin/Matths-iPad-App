#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUTPUT_FILE="/tmp/matths-sync-contract-cases"
API_OUTPUT_FILE="/tmp/matths-sync-api-decode-cases"
MODULE_CACHE="/tmp/matths-sync-contract-module-cache"
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/matths-sync-journal.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT

xcrun swiftc \
  "$ROOT_DIR/tests/SyncContractCases.swift" \
  "$ROOT_DIR/Matths/WrongNoteStore.swift" \
  -module-cache-path "$MODULE_CACHE" \
  -o "$OUTPUT_FILE"

"$OUTPUT_FILE"

# 저장 실패·손상 복구 배너는 학생에게 샌드박스 경로나 NSError 원문을 노출하지 않는다.
grep -Fq '손상된 원본은 이 기기에 별도로 보관했습니다.' "$ROOT_DIR/Matths/WrongNoteStore.swift"
grep -Fq '원본은 이 기기에 별도로 보관했습니다.' "$ROOT_DIR/Matths/WrongNoteStore.swift"
grep -Fq '오답노트를 저장하지 못했습니다. 기기의 저장 공간을 확인한 뒤 다시 시도해 주세요.' \
  "$ROOT_DIR/Matths/WrongNoteStore.swift"

xcrun swiftc \
  "$ROOT_DIR/tests/SyncAPIDecodeCases.swift" \
  "$ROOT_DIR/Matths/ServerAPI.swift" \
  "$ROOT_DIR/Matths/DataScope.swift" \
  "$ROOT_DIR/Matths/ServerAuthenticationOwnership.swift" \
  "$ROOT_DIR/Matths/ServerTokenOwnership.swift" \
  -module-cache-path "$MODULE_CACHE" \
  -o "$API_OUTPUT_FILE"

"$API_OUTPUT_FILE"

# SyncEngine 전체는 iOS UI 의존성이 있지만 journal codec/actor는 Foundation+Network만
# 쓴다. 제품 파일의 MARK 앞부분을 그대로 잘라 actor 접근 제한만 테스트 모듈 범위로
# 넓혀, 복제 구현이 아닌 실제 journal을 행동 검증한다.
sed -n '1,/^\/\/ MARK: - 엔진/p' "$ROOT_DIR/Matths/SyncEngine.swift" \
  | sed -E 's/^private (struct|enum|actor) /\1 /' \
  > "$BUILD_DIR/SyncJournal.swift"

xcrun swiftc -parse-as-library \
  "$BUILD_DIR/SyncJournal.swift" \
  "$ROOT_DIR/tests/SyncJournalCases.swift" \
  -module-cache-path "$MODULE_CACHE" \
  -o "$BUILD_DIR/sync-journal-cases"

"$BUILD_DIR/sync-journal-cases"

# 구조 계약은 Swift 주석을 먼저 제거한다. 설명문에 키워드만 넣어 통과하는 grep
# false-green을 막고, actor snapshot+ID merge와 disk-ack-before-send의 실행 순서를 본다.
python3 - "$ROOT_DIR/Matths/SyncEngine.swift" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()


def fail(message: str) -> None:
    raise SystemExit("Sync journal contract failed: " + message)


def strip_comments(value: str) -> str:
    out = list(value)
    index = 0
    state = "code"
    depth = 0
    while index < len(value):
        if state == "line":
            if value[index] == "\n":
                state = "code"
            else:
                out[index] = " "
            index += 1
            continue
        if state == "block":
            if value.startswith("/*", index):
                out[index] = out[index + 1] = " "
                depth += 1
                index += 2
            elif value.startswith("*/", index):
                out[index] = out[index + 1] = " "
                depth -= 1
                index += 2
                if depth == 0:
                    state = "code"
            else:
                if value[index] != "\n":
                    out[index] = " "
                index += 1
            continue
        if state == "string":
            if value[index] == "\\" and index + 1 < len(value):
                index += 2
            elif value[index] == '"':
                state = "code"
                index += 1
            else:
                index += 1
            continue
        if state == "multiline":
            if value.startswith('"""', index):
                state = "code"
                index += 3
            else:
                index += 1
            continue
        if value.startswith("//", index):
            out[index] = out[index + 1] = " "
            state = "line"
            index += 2
        elif value.startswith("/*", index):
            out[index] = out[index + 1] = " "
            state = "block"
            depth = 1
            index += 2
        elif value.startswith('"""', index):
            state = "multiline"
            index += 3
        elif value[index] == '"':
            state = "string"
            index += 1
        else:
            index += 1
    return "".join(out)


def mask_strings(value: str) -> str:
    out = list(value)
    index = 0
    state = "code"
    while index < len(value):
        if state == "string":
            if value[index] == "\\" and index + 1 < len(value):
                out[index] = out[index + 1] = " "
                index += 2
            elif value[index] == '"':
                out[index] = " "
                state = "code"
                index += 1
            else:
                if value[index] != "\n":
                    out[index] = " "
                index += 1
            continue
        if state == "multiline":
            if value.startswith('"""', index):
                out[index] = out[index + 1] = out[index + 2] = " "
                state = "code"
                index += 3
            else:
                if value[index] != "\n":
                    out[index] = " "
                index += 1
            continue
        if value.startswith('"""', index):
            out[index] = out[index + 1] = out[index + 2] = " "
            state = "multiline"
            index += 3
        elif value[index] == '"':
            out[index] = " "
            state = "string"
            index += 1
        else:
            index += 1
    return "".join(out)


code = strip_comments(source)


def body(marker: str, within: str = code) -> str:
    start = within.find(marker)
    if start < 0:
        fail("declaration not found: " + marker)
    masked = mask_strings(within)
    brace = masked.find("{", start)
    if brace < 0:
        fail("body not found: " + marker)
    depth = 0
    for index in range(brace, len(within)):
        if masked[index] == "{":
            depth += 1
        elif masked[index] == "}":
            depth -= 1
            if depth == 0:
                return within[brace + 1:index]
    fail("unterminated body: " + marker)


def in_order(value: str, markers: list[str], message: str) -> None:
    cursor = -1
    for marker in markers:
        cursor = value.find(marker, cursor + 1)
        if cursor < 0:
            fail(message + " (missing/out of order: " + marker + ")")


if "private actor SyncQueueJournal" not in code:
    fail("queue file I/O must have a single actor owner")
if "private var states: [String: State]" not in code:
    fail("journal recovery cache must use stable owner-slot keys, not filesystem-sensitive URL keys")

journal_append = body("func append(_ operations: [SyncOp], for slot: String) -> Bool")
in_order(
    journal_append,
    [
        "guard !invalidatedSlots.contains(slot)",
        "let queueURL = Self.queueURL(for: slot)",
        "let base = state.pendingQueue ?? state.durableQueue",
        "Set(base.map(\\.id))",
        "operations.filter",
        "let candidate = base + additions",
        "SyncQueueDiskCodec.append(additions, to: queueURL)",
        "state.durableQueue = candidate",
        "states[slot] = state",
    ],
    "journal append must gate before URL access and merge by ID in FIFO order",
)

schedule = body("private func scheduleJournalAppend(")
in_order(
    schedule,
    [
        "guard !invalidatedJournalSlots.contains(slot)",
        "let previous = journalBoundaries[slot]?.task",
        "Task.detached",
        "await previous?.value",
        "SyncQueueJournal.shared.append(operations, for: slot)",
        "journalBoundaries[slot] = boundary",
    ],
    "each slot must chain append tails before entering the journal actor",
)

enqueue = body("private func enqueue(_ op: SyncOp)")
in_order(
    enqueue,
    ["queue.append(op)", "scheduleJournalAppend([op], for: loadedSlot)", "Task { await flush() }"],
    "enqueue must publish memory FIFO, schedule its disk tail, then request flush",
)
if "Data(contentsOf:" in enqueue or "FileHandle(" in enqueue:
    fail("enqueue hot path performs direct file I/O")

ensure = body("private func ensureJournalDurable(")
in_order(
    ensure,
    [
        "await boundary.task.value",
        "journalBoundaries[owner.slot]?.id == boundary.id",
        "await SyncQueueJournal.shared.snapshot(for: owner.slot)",
        "guard isCurrentAccountOwner(owner)",
        "guard journalBoundaries[owner.slot] == nil else { continue }",
        "mergeDurableSnapshot(snapshot.operations)",
    ],
    "durability barrier must drain a stable tail, recheck owner, then merge actor snapshot",
)

merge = body("private func mergeDurableSnapshot(")
in_order(
    merge,
    [
        "for operation in durable",
        "seen.insert(operation.id).inserted",
        "for operation in queue",
        "seen.insert(operation.id).inserted",
        "queue = merged",
    ],
    "restart/session hydration must ID-merge durable FIFO before memory-only FIFO",
)

flush = body("func flush() async")
in_order(
    flush,
    [
        "guard await ensureJournalDurable(for: owner)",
        "ServerAPI.captureAuthorization()",
        "guard await ensureJournalDurable(for: owner)",
        "try await send(op, owner: owner, authorization: authorization)",
    ],
    "network send must follow journal ack",
)
if "Data(contentsOf:" in flush or "FileHandle(" in flush:
    fail("flush performs direct file I/O on MainActor")

flush_success = body("do {", flush)
in_order(
    flush_success,
    [
        "try await send(op, owner: owner, authorization: authorization)",
        "let remaining = Array(queue.dropFirst())",
        "await scheduleJournalReplacement(",
        "guard persisted else",
        "queue.removeFirst()",
    ],
    "successful send must not remove the memory head before remaining FIFO is durably rewritten",
)

print("Sync journal static contract passed")
PY

# 프로필의 동기화 카드에는 SyncEngine.lastError가 그대로 보인다. 네트워크/Foundation
# 오류 원문을 저장하지 않고, 연결·만료·시간 초과·과부하·서버 장애별 복구 문구만
# 게시하는 계약을 제품 소스에서 확인한다.
python3 - "$ROOT_DIR/Matths/SyncEngine.swift" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()


def require(fragment: str, message: str) -> None:
    if fragment not in source:
        raise SystemExit("Sync status privacy contract failed: " + message)


require("private func userFacingSyncFailure(_ error: Error) -> String",
        "missing the user-facing sync failure mapper")
require("case .notConnectedToInternet", "offline failures are not categorized")
require("case .timedOut", "timeout failures are not categorized")
require("case 401:", "expired sessions are not categorized")
require("case 429:", "rate limiting is not categorized")
require("case let status? where (500...599).contains(status):",
        "server outages are not categorized")
require("학습 기록은 보관되며 자동으로 다시 시도합니다.",
        "server outage copy does not explain retention and retry")

safe_assignments = source.count("lastError = userFacingSyncFailure(error)")
if safe_assignments != 4:
    raise SystemExit(
        "Sync status privacy contract failed: expected 4 sanitized catch assignments, "
        f"found {safe_assignments}"
    )

raw_patterns = (
    'lastError = "\\(error)"',
    'lastError = (error as? ServerAPIError)?.errorDescription ?? "\\(error)"',
    'lastError = error.localizedDescription',
)
for pattern in raw_patterns:
    if pattern in source:
        raise SystemExit(
            "Sync status privacy contract failed: raw error text can reach lastError"
        )

print("Sync status privacy contract passed")
PY
