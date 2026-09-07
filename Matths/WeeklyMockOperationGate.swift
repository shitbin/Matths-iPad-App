import Foundation

/// A mounted screen owns its requests. Retirement and 403 reset invalidate old
/// callbacks even when the same account opens the same exam again immediately.
@MainActor
final class WeeklyMockOperationGate {
    struct Ticket: Equatable {
        fileprivate let epoch: UUID
        fileprivate let key: String
        fileprivate let id: UUID
    }

    private var epoch = UUID()
    private var current: [String: UUID] = [:]
    private(set) var isActive = true

    func activate() {
        guard !isActive else { return }
        reset()
        isActive = true
    }

    func begin(_ key: String, exclusive: Bool = false) -> Ticket? {
        guard isActive, !exclusive || current[key] == nil else { return nil }
        let id = UUID()
        current[key] = id
        return Ticket(epoch: epoch, key: key, id: id)
    }

    func accepts(_ ticket: Ticket) -> Bool {
        isActive && ticket.epoch == epoch && current[ticket.key] == ticket.id
    }

    func finish(_ ticket: Ticket) {
        guard accepts(ticket) else { return }
        current.removeValue(forKey: ticket.key)
    }

    func cancel(_ key: String) { current.removeValue(forKey: key) }

    func reset() {
        epoch = UUID()
        current.removeAll()
    }

    func retire() {
        reset()
        isActive = false
    }

    static func removesProtectedContent(statusCode: Int?) -> Bool { statusCode == 403 }
}
