//  DebouncedSnapshotWriter.swift
//  Matths
//
//  메인 액터에서 값 스냅샷만 받아, JSON 인코딩과 파일 교체를 한 줄로 직렬화한다.
//  호출 순서와 actor 도착 순서는 같다고 가정하지 않는다. 호출부가 매긴 revision으로
//  오래된 Task가 최신 즉시 저장을 뒤늦게 덮는 일을 막는다.

import Foundation

enum SnapshotWriteOutcome: Equatable, Sendable {
    /// 이 호출의 payload가 sink까지 실제 반영됐다.
    case written
    /// actor에 같거나 더 높은 revision(탈퇴 invalidate cutoff 포함)이 먼저 도착해
    /// 이 payload는 의도적으로 폐기됐다. 상위 값의 실제 저장 성공을 뜻하지는 않는다.
    case superseded
    /// 최신 payload였지만 sink가 실패했다. actor pending에는 재시도용으로 남는다.
    case ioFailed
}

actor DebouncedSnapshotWriter<Key, Payload>
where Key: Hashable & Sendable, Payload: Sendable {
    typealias Sink = @Sendable (Key, Payload) -> Bool

    private struct Pending: Sendable {
        let revision: UInt64
        let payload: Payload
    }

    private let debounceNanoseconds: UInt64
    private let sink: Sink
    private var latestRevision: [Key: UInt64] = [:]
    private var pending: [Key: Pending] = [:]
    private var wakeups: [Key: Task<Void, Never>] = [:]

    init(debounceNanoseconds: UInt64, sink: @escaping Sink) {
        self.debounceNanoseconds = debounceNanoseconds
        self.sink = sink
    }

    /// latest-wins 저장. 같은 key의 연속 변경은 debounce 구간 동안 하나로 합친다.
    /// 메인 액터는 이 메서드를 기다려 actor 우편함에 값을 넘기는 데까지만 하고,
    /// 실제 sink(JSONEncoder·파일 I/O)는 이 actor 안에서 나중에 실행된다.
    func schedule(_ payload: Payload, for key: Key, revision: UInt64) {
        guard revision > (latestRevision[key] ?? 0) else { return }

        latestRevision[key] = revision
        pending[key] = Pending(revision: revision, payload: payload)
        wakeups.removeValue(forKey: key)?.cancel()

        let delay = debounceNanoseconds
        wakeups[key] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.commitPending(for: key, revision: revision)
        }
    }

    /// 제출·초기화처럼 지연할 수 없는 경계. 같은 key의 debounce를 취소하고 이 값을
    /// actor의 직렬 sink에서 곧바로 쓴 뒤, 실제 쓰기 결과가 나온 다음 반환한다.
    @discardableResult
    func writeImmediately(
        _ payload: Payload,
        for key: Key,
        revision: UInt64
    ) -> SnapshotWriteOutcome {
        guard revision > (latestRevision[key] ?? 0) else { return .superseded }

        latestRevision[key] = revision
        wakeups.removeValue(forKey: key)?.cancel()
        pending.removeValue(forKey: key)
        let succeeded = sink(key, payload)
        // 일시적인 디스크 실패가 곧 데이터 폐기를 뜻하면 안 된다. 다음 lifecycle
        // flush가 같은 스냅샷을 다시 시도할 수 있게 보관하되, 그 사이 더 최신 revision이
        // 들어왔다면 오래된 값을 되살리지 않는다.
        if !succeeded, latestRevision[key] == revision {
            pending[key] = Pending(revision: revision, payload: payload)
        }
        return succeeded ? .written : .ioFailed
    }

    /// 계정 전환·background처럼 여러 resource가 하나의 내구 경계인 경우를 위한
    /// 단일 actor 명령. 호출 전체가 끝날 때까지 다른 schedule/flush가 끼어들지 않아,
    /// "진도만 저장된 뒤 슬롯 전환" 같은 반쪽 장벽을 만들지 않는다.
    @discardableResult
    func writeImmediately(
        _ writes: [(key: Key, payload: Payload, revision: UInt64)]
    ) -> [Key: SnapshotWriteOutcome] {
        var results: [Key: SnapshotWriteOutcome] = [:]
        for write in writes {
            results[write.key] = writeImmediately(
                write.payload, for: write.key, revision: write.revision)
        }
        return results
    }

    /// 지정 key의 최신 pending 값을 debounce 만료를 기다리지 않고 실제로 쓴다.
    /// 반환은 모든 sink가 끝난 뒤다. 화면 이탈·background 경계에서 사용한다.
    @discardableResult
    func flush(_ keys: Set<Key>) -> [Key: Bool] {
        var results: [Key: Bool] = [:]
        for key in keys {
            guard let item = pending[key] else { continue }
            wakeups.removeValue(forKey: key)?.cancel()
            pending.removeValue(forKey: key)
            guard latestRevision[key] == item.revision else { continue }
            let succeeded = sink(key, item.payload)
            results[key] = succeeded
            if !succeeded, latestRevision[key] == item.revision {
                pending[key] = item
            }
        }
        return results
    }

    /// 탈퇴용 cancel-and-drain 장벽. 이 호출은 진행 중 sink가 끝난 뒤 실행되며,
    /// cutoff 이전에 만들어졌다가 늦게 도착한 schedule도 거절한다. 삭제한 슬롯
    /// 디렉터리가 옛 스냅샷으로 부활하지 않는다.
    func invalidate(_ keys: Set<Key>, through cutoff: UInt64) {
        for key in keys {
            latestRevision[key] = max(latestRevision[key] ?? 0, cutoff)
            wakeups.removeValue(forKey: key)?.cancel()
            pending.removeValue(forKey: key)
        }
    }

    private func commitPending(for key: Key, revision: UInt64) {
        guard latestRevision[key] == revision,
              let item = pending[key], item.revision == revision else { return }
        pending.removeValue(forKey: key)
        wakeups.removeValue(forKey: key)
        if !sink(key, item.payload), latestRevision[key] == revision {
            // 자동 재시도 루프는 만들지 않는다. 실패한 최신값을 남겨 두고 다음 명시적
            // flush 또는 후속 변경이 재시도/대체하게 한다.
            pending[key] = item
        }
    }
}
