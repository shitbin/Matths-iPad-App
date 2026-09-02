//  LocalAIWorkCoordinator.swift
//  Matths
//
//  앱의 로컬 AI 기능은 하나의 LLMEngine을 공유한다. llama.cpp 내부 큐는 개별
//  load/generate 호출만 직렬화하므로, `비전 모델 로드 → 판독 → 추론 모델 전환` 같은
//  여러 호출로 된 작업 전체를 보호하지 못한다. 이 actor가 그 작업 단위의 단일 소유권을
//  제공한다. 현재 native generate를 선점 중단하지는 않고, 대기열에서만 우선순위를 쓴다.

import Foundation

actor LocalAIWorkCoordinator {
    static let shared = LocalAIWorkCoordinator()

    enum WorkKind: String, Sendable {
        /// 학생이 화면에서 완료를 기다리는 시험지 채점.
        case sheetGrading = "sheet-grading"
        /// 학생이 방금 보낸 튜터 질문·사진 질문.
        case tutorResponse = "tutor-response"
        /// 사용자가 요청한 모델 재로드·사진 선택 전 메모리 해제.
        case modelMaintenance = "model-maintenance"
        /// 채점·정산을 바꾸지 않는 비동기 풀이 무결성 검토.
        case integrityReview = "integrity-review"

        fileprivate var priority: Int {
            switch self {
            case .sheetGrading:   return 300
            case .modelMaintenance:return 250
            case .tutorResponse:  return 200
            case .integrityReview:return 100
            }
        }
    }

    struct Lease: Equatable, Sendable {
        fileprivate let id: UUID
        let kind: WorkKind
        let requestedAt: Date
        let acquiredAt: Date
    }

    struct Snapshot: Equatable, Sendable {
        let active: WorkKind?
        let waiting: [WorkKind]
    }

    private struct Waiter {
        let id: UUID
        let kind: WorkKind
        let requestedAt: Date
        let sequence: UInt64
        let continuation: CheckedContinuation<Lease, Error>
    }

    private var active: Lease?
    private var waiters: [Waiter] = []
    private var nextSequence: UInt64 = 0

    /// 하나의 모델 작업 묶음에 대한 소유권을 얻는다. 이미 시작한 native 추론은
    /// 끝까지 두되, 대기 중인 요청은 채점 → 튜터 → 후속 무결성 검토 순으로 고른다.
    /// 대기 Task가 취소되면 continuation도 즉시 CancellationError로 닫는다.
    func acquire(_ kind: WorkKind) async throws -> Lease {
        let id = UUID()
        let requestedAt = Date()
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if active == nil {
                    let lease = Lease(
                        id: id,
                        kind: kind,
                        requestedAt: requestedAt,
                        acquiredAt: Date())
                    active = lease
                    continuation.resume(returning: lease)
                    return
                }
                nextSequence &+= 1
                waiters.append(Waiter(
                    id: id,
                    kind: kind,
                    requestedAt: requestedAt,
                    sequence: nextSequence,
                    continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiting(id: id) }
        }
    }

    /// 소유자가 받은 lease와 정확히 같은 id만 해제할 수 있다. 늦게 끝난 이전 Task가
    /// 현재 작업을 풀어 버리는 것을 막는다.
    func release(_ lease: Lease) {
        guard active?.id == lease.id else { return }
        active = nil
        grantNextIfPossible()
    }

    func snapshot() -> Snapshot {
        Snapshot(
            active: active?.kind,
            waiting: waiters
                .sorted(by: Self.precedes)
                .map(\.kind))
    }

    private func cancelWaiting(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func grantNextIfPossible() {
        guard active == nil, !waiters.isEmpty else { return }
        waiters.sort(by: Self.precedes)
        let waiter = waiters.removeFirst()
        let lease = Lease(
            id: waiter.id,
            kind: waiter.kind,
            requestedAt: waiter.requestedAt,
            acquiredAt: Date())
        active = lease
        waiter.continuation.resume(returning: lease)
    }

    private static func precedes(_ lhs: Waiter, _ rhs: Waiter) -> Bool {
        if lhs.kind.priority != rhs.kind.priority {
            return lhs.kind.priority > rhs.kind.priority
        }
        return lhs.sequence < rhs.sequence
    }
}
