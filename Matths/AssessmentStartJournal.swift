import Foundation

/// Persist the server idempotency key before sending. Retrying after response loss
/// or process termination must recover that same attempt, not start a new exam.
actor AssessmentStartJournal {
    static let shared = AssessmentStartJournal()
    private let directory: URL?
    init(directory: URL? = nil) { self.directory = directory }
    private func location(slot: String) -> URL {
        directory?.appendingPathComponent(slot + "-start-intents.json")
            ?? DataScope.url("assessment-start-intents.json", for: slot)
    }
    func ticket(scope: String, slot: String) throws -> String {
        let url = location(slot: slot)
        var entries: [String: String] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            entries = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        }
        if let ticket = entries[scope] {
            guard UUID(uuidString: ticket) != nil else { throw CocoaError(.fileReadCorruptFile) }
            return ticket
        }
        let ticket = UUID().uuidString
        entries[scope] = ticket
        try JSONEncoder().encode(entries).write(to: url, options: .atomic)
        return ticket
    }
    func acknowledge(scope: String, ticket: String, slot: String) throws {
        let url = location(slot: slot)
        var entries = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
        guard entries[scope] == ticket else { return }
        entries.removeValue(forKey: scope)
        try JSONEncoder().encode(entries).write(to: url, options: .atomic)
    }

    @discardableResult
    func acknowledgeAbandoned(scope: String, ticket: String, slot: String,
                              status: Int?, code: String?) throws -> Bool {
        guard AssessmentServerConflict(status: status, code: code)?.releasesStartTicket == true else { return false }
        try acknowledge(scope: scope, ticket: ticket, slot: slot)
        return true
    }
}
