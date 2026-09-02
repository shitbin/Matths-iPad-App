import Foundation

@main
enum LocalAIWorkCoordinatorCases {
    actor OrderRecorder {
        private var values: [LocalAIWorkCoordinator.WorkKind] = []
        func append(_ value: LocalAIWorkCoordinator.WorkKind) { values.append(value) }
        func read() -> [LocalAIWorkCoordinator.WorkKind] { values }
    }

    actor IntRecorder {
        private var values: [Int] = []
        func append(_ value: Int) { values.append(value) }
        func read() -> [Int] { values }
    }

    static func main() async throws {
        try await priorityAndFIFO()
        try await samePriorityFIFO()
        try await waitingCancellation()
        try await staleReleaseCannotUnlockNewOwner()
        print("Local AI single-engine work coordinator cases passed")
    }

    private static func priorityAndFIFO() async throws {
        let coordinator = LocalAIWorkCoordinator()
        let first = try await coordinator.acquire(.integrityReview)
        let order = OrderRecorder()

        let low = Task {
            let lease = try await coordinator.acquire(.integrityReview)
            await order.append(lease.kind)
            await coordinator.release(lease)
        }
        let tutor = Task {
            let lease = try await coordinator.acquire(.tutorResponse)
            await order.append(lease.kind)
            await coordinator.release(lease)
        }
        let maintenance = Task {
            let lease = try await coordinator.acquire(.modelMaintenance)
            await order.append(lease.kind)
            await coordinator.release(lease)
        }
        let grading = Task {
            let lease = try await coordinator.acquire(.sheetGrading)
            await order.append(lease.kind)
            await coordinator.release(lease)
        }

        try await waitUntil(coordinator: coordinator, waitingCount: 4)
        await coordinator.release(first)
        _ = try await (low.value, tutor.value, maintenance.value, grading.value)

        let values = await order.read()
        require(
            values == [.sheetGrading, .modelMaintenance, .tutorResponse, .integrityReview],
            "대기열은 채점 → 모델 유지보수 → 튜터 → 무결성 검토 순이어야 한다: \(values)")
        let final = await coordinator.snapshot()
        require(final.active == nil && final.waiting.isEmpty, "완료 뒤 lease가 남으면 안 된다")
    }

    private static func samePriorityFIFO() async throws {
        let coordinator = LocalAIWorkCoordinator()
        let blocker = try await coordinator.acquire(.sheetGrading)
        let order = IntRecorder()
        let first = Task {
            let lease = try await coordinator.acquire(.tutorResponse)
            await order.append(1)
            await coordinator.release(lease)
        }
        try await waitUntil(coordinator: coordinator, waitingCount: 1)
        let second = Task {
            let lease = try await coordinator.acquire(.tutorResponse)
            await order.append(2)
            await coordinator.release(lease)
        }
        try await waitUntil(coordinator: coordinator, waitingCount: 2)
        await coordinator.release(blocker)
        _ = try await (first.value, second.value)
        let values = await order.read()
        require(values == [1, 2], "같은 우선순위는 요청 순서를 지켜야 한다")
    }

    private static func waitingCancellation() async throws {
        let coordinator = LocalAIWorkCoordinator()
        let first = try await coordinator.acquire(.sheetGrading)
        let waiting = Task {
            try await coordinator.acquire(.integrityReview)
        }
        try await waitUntil(coordinator: coordinator, waitingCount: 1)
        waiting.cancel()

        do {
            _ = try await waiting.value
            throw CaseError.failed("취소한 대기 요청이 lease를 받았다")
        } catch is CancellationError {
            // expected
        }
        await coordinator.release(first)
        let final = await coordinator.snapshot()
        require(final.active == nil && final.waiting.isEmpty, "취소한 waiter가 대기열에 남으면 안 된다")
    }

    private static func staleReleaseCannotUnlockNewOwner() async throws {
        let coordinator = LocalAIWorkCoordinator()
        let first = try await coordinator.acquire(.tutorResponse)
        let waiting = Task { try await coordinator.acquire(.integrityReview) }
        try await waitUntil(coordinator: coordinator, waitingCount: 1)
        await coordinator.release(first)
        let second = try await waiting.value

        // 이미 반납한 예전 lease가 늦게 한 번 더 도착해도 현재 소유자는 유지된다.
        await coordinator.release(first)
        let snapshot = await coordinator.snapshot()
        require(
            snapshot.active == .integrityReview,
            "오래된 release가 새 소유권을 풀면 안 된다")
        await coordinator.release(second)
    }

    private static func waitUntil(
        coordinator: LocalAIWorkCoordinator,
        waitingCount: Int
    ) async throws {
        for _ in 0..<100 {
            if await coordinator.snapshot().waiting.count == waitingCount { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CaseError.failed("대기열 \(waitingCount)건이 만들어지지 않았다")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }

    private enum CaseError: Error {
        case failed(String)
    }
}
