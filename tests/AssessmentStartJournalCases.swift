import Foundation

@main
struct AssessmentStartJournalCases {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("assessment-start-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = AssessmentStartJournal(directory: directory)
        let keys = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<20 { group.addTask { try await journal.ticket(scope: "course/math/-/-", slot: "account-a") } }
            var values: [String] = []
            for try await value in group { values.append(value) }
            return values
        }
        precondition(Set(keys).count == 1, "Duplicate starts did not converge")
        let restarted = AssessmentStartJournal(directory: directory)
        let replay = try await restarted.ticket(scope: "course/math/-/-", slot: "account-a")
        precondition(replay == keys[0], "Response loss/process restart changed the server idempotency key")
        let anotherAccount = try await restarted.ticket(scope: "course/math/-/-", slot: "account-b")
        precondition(anotherAccount != replay)
        try await restarted.acknowledge(scope: "course/math/-/-", ticket: UUID().uuidString, slot: "account-a")
        let staleAck = try await restarted.ticket(scope: "course/math/-/-", slot: "account-a")
        precondition(staleAck == replay)
        try await restarted.acknowledge(scope: "course/math/-/-", ticket: replay, slot: "account-a")
        let next = try await restarted.ticket(scope: "course/math/-/-", slot: "account-a")
        precondition(next != replay, "A new completed-attempt retry must get a new key")
        // Corruption must not silently mint a different key and create another exam.
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("broken-start-intents.json"))
        do {
            _ = try await restarted.ticket(scope: "scope", slot: "broken")
            preconditionFailure("Corrupt journal was discarded")
        } catch {}
        print("20 concurrent starts, restart replay, account separation, stale ACK and corrupt journal preservation: PASS")
    }
}
