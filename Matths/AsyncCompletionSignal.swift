import Foundation

/// Cancellation-aware completion event. Waiting after completion is immediate;
/// an old completion never releases the next operation's waiters.
@MainActor
final class AsyncCompletionSignal {
    private(set) var current: UUID?
    private var waiters: [UUID: CheckedContinuation<Bool, Never>] = [:]
    var waiterCount: Int { waiters.count }
    func begin() -> UUID {
        if let current { return current }
        let value = UUID(); current = value; return value
    }
    func finish(_ epoch: UUID) {
        guard current == epoch else { return }
        current = nil
        let pending = Array(waiters.values); waiters.removeAll()
        for continuation in pending { continuation.resume(returning: true) }
    }
    func wait(for epoch: UUID) async -> Bool {
        guard !Task.isCancelled else { return false }
        guard current == epoch else { return true }
        let id = UUID()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { continuation.resume(returning: false) }
                else if current != epoch { continuation.resume(returning: true) }
                else { waiters[id] = continuation }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.waiters.removeValue(forKey: id)?.resume(returning: false)
            }
        }
    }
}
