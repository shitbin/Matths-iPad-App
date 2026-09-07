import Foundation

enum UserDefaults {
    static let standard = Defaults()
    final class Defaults {
        var values: [String: Int] = [:]
        func set(_ value: Int, forKey key: String) { values[key] = value }
    }
}
final class AppStore {
    var storedSolvedTotal = 100
    var storedCorrectTotal = 80
    var kiceStatisticsContribution = KiceStatisticsContribution.zero
    var activityDays = Set<String>()
    static func slotKey(_ key: String) -> String { key }
}
enum DataScope { static var slot = "account-A" }
enum ActivityLog {
    static var days = Set<String>()
    static func record(dates: [Date]) -> Set<String> {
        days.formUnion(dates.map { String($0.timeIntervalSince1970) })
        return days
    }
}
enum KiceBank {
    static var scores: [String: Int] = [:]
    static func recordScore(_ examID: String, score: Int) { scores[examID] = max(scores[examID] ?? -1, score) }
}

@main enum KiceStatisticsProjectionCases {
    static func main() throws {
        let live = AppStore()
        precondition(live.solvedTotal == 100 && live.correctTotal == 80)
        // The historical base is opaque and may contain pre-fix KICE work.
        // Only this newly recorded receipt is composed on top of it.
        live.kiceStatisticsContribution = .init(solved: 30, correct: 20)
        precondition(live.solvedTotal == 130 && live.correctTotal == 100)
        live.persist()
        precondition(UserDefaults.standard.values["matths.solved"] == 100)
        precondition(UserDefaults.standard.values["matths.correct"] == 80)
        let relaunched = AppStore()
        relaunched.storedSolvedTotal = UserDefaults.standard.values["matths.solved"]!
        relaunched.storedCorrectTotal = UserDefaults.standard.values["matths.correct"]!
        relaunched.kiceStatisticsContribution = .init(solved: 30, correct: 20)
        precondition(relaunched.solvedTotal == 130 && relaunched.correctTotal == 100,
                     "relaunch composes a receipt once instead of importing the previous composed value as base")
        for _ in 0..<20 { relaunched.kiceStatisticsContribution = .init(solved: 30, correct: 20) }
        precondition(relaunched.solvedTotal == 130)
        relaunched.solvedTotal += 1; relaunched.correctTotal += 1; relaunched.persist()
        precondition(relaunched.storedSolvedTotal == 101 && relaunched.storedCorrectTotal == 81)
        precondition(UserDefaults.standard.values["matths.solved"] == 101)
        precondition(relaunched.solvedTotal == 131 && relaunched.correctTotal == 101)
        relaunched.storedSolvedTotal = 0; relaunched.storedCorrectTotal = 0
        relaunched.kiceStatisticsContribution = .zero; relaunched.persist()
        precondition(relaunched.solvedTotal == 0 && relaunched.correctTotal == 0)

        let definition = KiceStudyDefinition(examID: "exam-A", title: "기출", shortTitle: "기출", displayForm: nil,
            common: [.init(section: "공통", number: 1, answer: "3", points: 100, isChoice: true)],
            electives: ["기하": []])
        var archive = KiceStudyArchive(slot: "account-A")
        _ = try archive.prepare(definition)
        try archive.answer(examID: "exam-A", key: "공통-1", value: "3")
        let receipt = try archive.grade(definition, elapsedMs: 1000, now: Date(timeIntervalSince1970: 1000))
        relaunched.restoreMirrors(archive)
        precondition(KiceBank.scores.isEmpty && ActivityLog.days.isEmpty, "unfinished effects are not falsely marked complete by mirror repair")
        archive.markEffectsApplied(receipt.id)
        for _ in 0..<3 { relaunched.restoreMirrors(archive) }
        precondition(KiceBank.scores == ["exam-A": 100] && relaunched.activityDays == ["1000.0"], "missing preferences reconstruct from durable receipt, replay is a union/max")
        precondition(relaunched.solvedTotal == 0, "mirror repair never replays grading into reset counters")
        KiceBank.scores = [:]; ActivityLog.days = []; DataScope.slot = "account-B"
        relaunched.restoreMirrors(archive)
        precondition(KiceBank.scores.isEmpty && ActivityLog.days.isEmpty, "an old account cannot repair mirrors into a new account")
        print("Production AppStore statistics projection PASS: opaque historical base, new receipt once, crash/relaunch, normal grading increments base only, explicit reset, replay-safe preferences repair and account isolation.")
    }
}
