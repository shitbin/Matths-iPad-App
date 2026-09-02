import Foundation

private struct TestKey: Hashable, Sendable {
    let slot: String
    let resource: String
}

private struct TestPayload: Sendable {
    let value: Int
}

private final class Recorder: @unchecked Sendable {
    struct Event {
        let key: TestKey
        let value: Int
        let succeeded: Bool
    }

    private let lock = NSLock()
    private var events: [Event] = []
    private let failingValues: Set<Int>

    init(failingValues: Set<Int> = []) {
        self.failingValues = failingValues
    }

    func write(_ key: TestKey, _ payload: TestPayload) -> Bool {
        let succeeded = !failingValues.contains(payload.value)
        lock.lock()
        events.append(Event(key: key, value: payload.value, succeeded: succeeded))
        lock.unlock()
        return succeeded
    }

    func snapshot() -> [Event] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func read() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// 첫 sink 호출만 실패시켜 writeImmediately 실패 payload가 pending으로 되돌아가는지 본다.
private final class FailOnceSink: @unchecked Sendable {
    private let lock = NSLock()
    private var shouldFail = true
    private var attemptedValues: [Int] = []

    func write(_ key: TestKey, _ payload: TestPayload) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        attemptedValues.append(payload.value)
        if shouldFail {
            shouldFail = false
            return false
        }
        return true
    }

    func attempts() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return attemptedValues
    }
}

/// schedule이 sink를 기다리는 회귀를 wall-clock 성능 수치 대신 동기 gate로 잡는다.
/// 정상 구현은 긴 debounce 뒤에 sink를 부르므로 schedule Task가 gate와 무관하게 끝난다.
private final class BlockingSink: @unchecked Sendable {
    private let condition = NSCondition()
    private var released = false

    func write(_ key: TestKey, _ payload: TestPayload) -> Bool {
        condition.lock()
        while !released { condition.wait() }
        condition.unlock()
        return true
    }

    func release() {
        condition.lock()
        released = true
        condition.broadcast()
        condition.unlock()
    }
}

@main
private enum LearningSnapshotWriterCases {
    static func main() async throws {
        try await latestSnapshotWinsPerKey()
        try await enqueueReturnsBeforeSlowSink()
        try await differentKeysDoNotCancelEachOther()
        try await flushWritesPendingValueBeforeDelay()
        try await immediateWriteRejectsOlderWakeup()
        try await invalidationDrainsAndRejectsOldMail()
        try await immediateFailureIsRetriedByFlush()
        try await failureDoesNotPoisonNextWrite()
        await supersededWritePreservesFailedPendingPayload()
        await invalidatedImmediateWriteIsSupersededWithoutSink()
        await writeOutcomesDistinguishSupersededAndIOFailure()
        print("Learning snapshot writer debounce, revision, flush, and invalidation cases passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    /// 느린 CI에서도 "정확히 N ms 뒤"에 기대지 않고 상태가 도착할 때까지 기다린다.
    /// 2초 안에도 actor가 진행하지 못하면 기능 고장으로 취급한다.
    private static func eventually(
        timeoutMilliseconds: Int = 2_000,
        _ condition: @escaping () -> Bool
    ) async throws -> Bool {
        let pollMilliseconds = 5
        for _ in 0..<(timeoutMilliseconds / pollMilliseconds) {
            if condition() { return true }
            try await Task.sleep(nanoseconds: UInt64(pollMilliseconds) * 1_000_000)
        }
        return condition()
    }

    /// 없어야 할 늦은 wakeup은 짧은 quiet window 전체에서 상태가 유지되는지 본다.
    private static func remainsTrue(
        milliseconds: Int,
        _ condition: @escaping () -> Bool
    ) async throws -> Bool {
        let pollMilliseconds = 5
        for _ in 0..<max(1, milliseconds / pollMilliseconds) {
            if !condition() { return false }
            try await Task.sleep(nanoseconds: UInt64(pollMilliseconds) * 1_000_000)
        }
        return condition()
    }

    private static func latestSnapshotWinsPerKey() async throws {
        let recorder = Recorder()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 30_000_000,
            sink: { recorder.write($0, $1) })
        let key = TestKey(slot: "acct-a", resource: "answers")

        await writer.schedule(TestPayload(value: 1), for: key, revision: 1)
        await writer.schedule(TestPayload(value: 2), for: key, revision: 2)
        await writer.schedule(TestPayload(value: 3), for: key, revision: 3)
        let latestArrived = try await eventually { !recorder.snapshot().isEmpty }
        require(latestArrived, "debounce 뒤 최신 snapshot 저장이 도착하지 않았다")
        let stayedSingle = try await remainsTrue(milliseconds: 100) {
            recorder.snapshot().count == 1
        }
        require(stayedSingle, "취소한 옛 wakeup이 뒤늦게 중복 저장했다")

        let events = recorder.snapshot()
        require(events.count == 1, "연속 snapshot은 한 번만 써야 한다")
        require(events.first?.value == 3, "마지막 snapshot이 남아야 한다")
    }

    private static func enqueueReturnsBeforeSlowSink() async throws {
        let sink = BlockingSink()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            // 정상 경로에서는 이 테스트가 끝나기 전에 sink 자체가 시작되지 않는다.
            debounceNanoseconds: 5_000_000_000,
            sink: { sink.write($0, $1) })
        let key = TestKey(slot: "large-account", resource: "wrongNotes")
        let completed = AtomicFlag()

        let scheduling = Task {
            await writer.schedule(TestPayload(value: 9), for: key, revision: 1)
            completed.set()
        }
        let returnedBeforeRelease = try await eventually(timeoutMilliseconds: 1_000) {
            completed.read()
        }
        sink.release()
        await scheduling.value

        require(returnedBeforeRelease,
                "enqueue가 막힌 JSON/파일 sink 완료를 기다리면 버튼이 다시 막힌다")
    }

    private static func differentKeysDoNotCancelEachOther() async throws {
        let recorder = Recorder()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 25_000_000,
            sink: { recorder.write($0, $1) })
        let progress = TestKey(slot: "acct-a", resource: "progress")
        let answers = TestKey(slot: "acct-a", resource: "answers")
        let otherSlot = TestKey(slot: "acct-b", resource: "answers")

        await writer.schedule(TestPayload(value: 10), for: progress, revision: 1)
        await writer.schedule(TestPayload(value: 20), for: answers, revision: 2)
        await writer.schedule(TestPayload(value: 30), for: otherSlot, revision: 3)
        let allKeysArrived = try await eventually { recorder.snapshot().count == 3 }
        require(allKeysArrived, "서로 다른 key의 저장이 모두 도착하지 않았다")

        let events = recorder.snapshot()
        require(events.count == 3, "다른 resource/slot의 pending 저장은 서로 취소하면 안 된다")
        require(Set(events.map(\.value)) == Set([10, 20, 30]), "각 key의 값이 모두 보존돼야 한다")
    }

    private static func flushWritesPendingValueBeforeDelay() async throws {
        let recorder = Recorder()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 1_000_000_000,
            sink: { recorder.write($0, $1) })
        let key = TestKey(slot: "guest", resource: "progress")

        await writer.schedule(TestPayload(value: 40), for: key, revision: 1)
        let result = await writer.flush(Set([key]))

        require(result[key] == true, "flush는 실제 sink 결과가 나온 뒤 반환해야 한다")
        require(recorder.snapshot().map(\.value) == [40], "flush는 sleep 전에 최신 pending을 써야 한다")
    }

    private static func immediateWriteRejectsOlderWakeup() async throws {
        let recorder = Recorder()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 40_000_000,
            sink: { recorder.write($0, $1) })
        let key = TestKey(slot: "acct-a", resource: "answers")

        await writer.schedule(TestPayload(value: 50), for: key, revision: 1)
        let saved = await writer.writeImmediately(TestPayload(value: 51), for: key, revision: 2)
        require(saved == .written, "최신 즉시 저장은 written 결과여야 한다")
        let immediateStayedLatest = try await remainsTrue(milliseconds: 120) {
            recorder.snapshot().map(\.value) == [51]
        }
        require(immediateStayedLatest, "오래된 debounce가 즉시 저장 뒤를 덮었다")

        require(recorder.snapshot().map(\.value) == [51], "오래된 debounce가 즉시 저장 뒤를 덮으면 안 된다")
    }

    private static func invalidationDrainsAndRejectsOldMail() async throws {
        let recorder = Recorder()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 40_000_000,
            sink: { recorder.write($0, $1) })
        let key = TestKey(slot: "withdrawn", resource: "wrongNotes")

        await writer.schedule(TestPayload(value: 60), for: key, revision: 1)
        await writer.invalidate(Set([key]), through: 2)
        // actor 우편함에 늦게 도착한 탈퇴 전 세대를 흉내 낸다.
        await writer.schedule(TestPayload(value: 61), for: key, revision: 1)
        let stayedInvalidated = try await remainsTrue(milliseconds: 120) {
            recorder.snapshot().isEmpty
        }
        require(stayedInvalidated, "탈퇴 장벽 뒤 옛 snapshot이 파일을 되살렸다")
        require(recorder.snapshot().isEmpty, "탈퇴 장벽 뒤 옛 snapshot이 파일을 되살리면 안 된다")

        // 같은 이메일로 새 계정을 만든 경우처럼, cutoff 이후의 진짜 새 세대는 허용한다.
        await writer.schedule(TestPayload(value: 62), for: key, revision: 3)
        let newGenerationArrived = try await eventually {
            recorder.snapshot().map(\.value) == [62]
        }
        require(newGenerationArrived, "cutoff 이후 새 세대 저장이 도착하지 않았다")
        require(recorder.snapshot().map(\.value) == [62], "cutoff 이후 새 세대까지 영구 차단하면 안 된다")
    }

    private static func failureDoesNotPoisonNextWrite() async throws {
        let recorder = Recorder(failingValues: [70])
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 20_000_000,
            sink: { recorder.write($0, $1) })
        let key = TestKey(slot: "guest", resource: "wrongNotes")

        let first = await writer.writeImmediately(TestPayload(value: 70), for: key, revision: 1)
        let second = await writer.writeImmediately(TestPayload(value: 71), for: key, revision: 2)

        require(first == .ioFailed && second == .written,
                "한 번 I/O 실패해도 다음 snapshot은 written으로 저장할 수 있어야 한다")
        require(recorder.snapshot().map(\.succeeded) == [false, true], "실패와 복구 결과가 둘 다 드러나야 한다")
    }

    private static func immediateFailureIsRetriedByFlush() async throws {
        let sink = FailOnceSink()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 1_000_000_000,
            sink: { sink.write($0, $1) })
        let key = TestKey(slot: "guest", resource: "progress")

        let immediate = await writer.writeImmediately(
            TestPayload(value: 72), for: key, revision: 1)
        require(immediate == .ioFailed,
                "첫 즉시 쓰기는 sink 실패를 ioFailed로 호출자에게 드러내야 한다")

        let retried = await writer.flush(Set([key]))
        require(retried[key] == true, "flush가 실패 payload를 재시도해 성공 결과를 반환해야 한다")
        require(sink.attempts() == [72, 72],
                "즉시 쓰기 실패 payload를 버리거나 다른 값으로 재시도하면 안 된다")
    }

    private static func supersededWritePreservesFailedPendingPayload() async {
        let sink = FailOnceSink()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 1_000_000_000,
            sink: { sink.write($0, $1) })
        let key = TestKey(slot: "acct-a", resource: "wrongNotes")

        let failed = await writer.writeImmediately(
            TestPayload(value: 74), for: key, revision: 2)
        let stale = await writer.writeImmediately(
            TestPayload(value: 75), for: key, revision: 1)
        let retried = await writer.flush(Set([key]))

        require(failed == .ioFailed, "최신 sink 실패는 ioFailed여야 한다")
        require(stale == .superseded, "낮은 revision은 superseded여야 한다")
        require(retried[key] == true,
                "superseded 호출이 기존 I/O 실패 pending을 지우면 안 된다")
        require(sink.attempts() == [74, 74],
                "낮은 revision payload가 실패한 최신 pending을 대체하면 안 된다")
    }

    private static func invalidatedImmediateWriteIsSupersededWithoutSink() async {
        let recorder = Recorder()
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 1_000_000_000,
            sink: { recorder.write($0, $1) })
        let key = TestKey(slot: "withdrawn", resource: "assessments")

        await writer.invalidate(Set([key]), through: 5)
        let outcome = await writer.writeImmediately(
            TestPayload(value: 76), for: key, revision: 5)

        require(outcome == .superseded,
                "invalidate cutoff 이하 immediate는 I/O 실패가 아니라 superseded여야 한다")
        require(recorder.snapshot().isEmpty,
                "invalidate cutoff 이하 immediate가 삭제 슬롯 sink를 호출하면 안 된다")
    }

    /// 오래된 revision 폐기와 실제 디스크 실패를 같은 false로 뭉치면, 호출부가
    /// 정상 경합을 저장 실패로 중단하거나 반대로 I/O 실패를 성공으로 넘길 수 있다.
    private static func writeOutcomesDistinguishSupersededAndIOFailure() async {
        let recorder = Recorder(failingValues: [82])
        let writer = DebouncedSnapshotWriter<TestKey, TestPayload>(
            debounceNanoseconds: 1_000_000_000,
            sink: { recorder.write($0, $1) })
        let supersededKey = TestKey(slot: "acct-a", resource: "progress")
        let failedKey = TestKey(slot: "acct-a", resource: "wrongNotes")
        let writtenKey = TestKey(slot: "acct-a", resource: "assessments")

        let newest = await writer.writeImmediately(
            TestPayload(value: 80), for: supersededKey, revision: 2)
        require(newest == .written, "선행 최신 revision은 실제 저장돼야 한다")

        let outcomes = await writer.writeImmediately([
            (key: supersededKey, payload: TestPayload(value: 81), revision: 1),
            (key: failedKey, payload: TestPayload(value: 82), revision: 1),
            (key: writtenKey, payload: TestPayload(value: 83), revision: 1),
        ])

        require(outcomes[supersededKey] == .superseded,
                "더 높은 revision이 선점한 쓰기는 superseded여야 한다")
        require(outcomes[failedKey] == .ioFailed,
                "최신 revision의 sink 실패는 ioFailed여야 한다")
        require(outcomes[writtenKey] == .written,
                "sink에 반영된 최신 revision은 written이어야 한다")
        require(recorder.snapshot().map(\.value) == [80, 82, 83],
                "superseded payload는 sink에 도달하지 않고 I/O 실패 시도는 기록돼야 한다")
    }
}
