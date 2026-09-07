import CryptoKit
import Foundation

struct KiceStudyQuestion: Codable, Equatable, Sendable {
    let section: String
    let number: Int
    let answer: String
    let points: Int
    let isChoice: Bool
    var key: String { "\(section)-\(number)" }
}

struct KiceStudyDefinition: Codable, Equatable, Sendable {
    let examID: String
    let title: String
    let shortTitle: String
    let displayForm: String?
    let common: [KiceStudyQuestion]
    let electives: [String: [KiceStudyQuestion]]

    var fingerprint: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return KiceStudyArchive.digest((try? encoder.encode(self)) ?? Data())
    }
    var preferredSubject: String? {
        ["확률과 통계", "미적분", "기하"].first { electives[$0] != nil } ?? electives.keys.sorted().first
    }
    func questions(subject: String) -> [KiceStudyQuestion] { common + (electives[subject] ?? []) }
}

struct KiceStudyResult: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let score: Int
    let correctCount: Int
    let total: Int
    let verdicts: [String: Bool]
    var wrongCount: Int { total - correctCount }
}

struct KiceStudyWrongAnswer: Codable, Equatable, Sendable {
    let question: KiceStudyQuestion
    let submittedAnswer: String
    var notePlan: KiceWrongNotePlan? = nil
}

struct KiceWrongNotePlan: Codable, Equatable, Sendable {
    let noteID: String
    let wasNew: Bool
}

struct KiceStudyReceipt: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let examID: String
    let title: String
    let shortTitle: String
    let displayForm: String?
    let subject: String
    let gradedAt: Date
    let elapsedMs: Int
    let result: KiceStudyResult
    let answers: [String: String]
    var wrongAnswers: [KiceStudyWrongAnswer]
    let statisticsEpoch: String
    var effectsApplied = false
    var localEffectsApplied = false

    var gradingEventID: String { "kice-grading-\(id)" }
    func wrongNoteEffectID(_ key: String) -> String {
        "kice-note-" + KiceStudyArchive.digest(Data("\(id)|\(key)".utf8))
    }
}

struct KiceStudyAttempt: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let examID: String
    let contentFingerprint: String
    let startedAt: Date
    var subject: String
    var answers: [String: String] = [:]
    var elapsedMs = 0
    var pdfPageIndex = 0
    var updatedAt: Date
    var receiptID: String?
}

struct KiceStatisticsContribution: Equatable, Sendable {
    var solved = 0
    var correct = 0
    static let zero = KiceStatisticsContribution()
}

/// One atomic account-owned record contains drafts and immutable grading
/// outcomes. New KICE statistics are derived from receipt IDs, never += replayed
/// into the user's existing mixed historical counters.
struct KiceStudyArchive: Codable, Equatable, Sendable {
    static let filename = "kice-study-archive-v1.json"
    static let maximumBytes = 12 * 1_024 * 1_024
    let schemaVersion: Int
    let slot: String
    var revision: UInt64 = 0
    var statisticsEpoch: String
    var attempts: [String: KiceStudyAttempt] = [:]
    var receipts: [String: KiceStudyReceipt] = [:]

    init(slot: String) {
        schemaVersion = 1; self.slot = slot; statisticsEpoch = UUID().uuidString
    }
    enum Failure: Error { case invalid, tooLarge, incompatibleContent, alreadyGraded, notReady }

    mutating func prepare(_ definition: KiceStudyDefinition, now: Date = Date()) throws -> KiceStudyAttempt {
        if let existing = attempts[definition.examID] {
            if existing.receiptID == nil && existing.contentFingerprint != definition.fingerprint {
                throw Failure.incompatibleContent
            }
            return existing
        }
        guard let subject = definition.preferredSubject else { throw Failure.invalid }
        let value = KiceStudyAttempt(id: UUID().uuidString, examID: definition.examID,
            contentFingerprint: definition.fingerprint, startedAt: now, subject: subject, updatedAt: now)
        attempts[definition.examID] = value
        revision &+= 1
        return value
    }

    mutating func answer(examID: String, key: String, value: String, now: Date = Date()) throws {
        guard var attempt = attempts[examID], attempt.receiptID == nil else { throw Failure.alreadyGraded }
        guard key.utf8.count <= 200, value.utf8.count <= 256 else { throw Failure.tooLarge }
        attempt.answers[key] = value; attempt.updatedAt = now
        attempts[examID] = attempt; revision &+= 1
    }
    mutating func selectSubject(examID: String, subject: String, definition: KiceStudyDefinition, now: Date = Date()) throws {
        guard var attempt = attempts[examID], attempt.receiptID == nil else { throw Failure.alreadyGraded }
        guard definition.examID == examID, definition.electives[subject] != nil else { throw Failure.invalid }
        attempt.subject = subject; attempt.updatedAt = now
        attempts[examID] = attempt; revision &+= 1
    }
    mutating func checkpoint(examID: String, elapsedMs: Int, page: Int? = nil, now: Date = Date()) throws {
        guard var attempt = attempts[examID], attempt.receiptID == nil else { return }
        guard elapsedMs >= 0, elapsedMs <= 365 * 24 * 3_600_000 else { throw Failure.invalid }
        attempt.elapsedMs = max(attempt.elapsedMs, elapsedMs)
        if let page { attempt.pdfPageIndex = max(0, min(page, 1000)) }
        attempt.updatedAt = now; attempts[examID] = attempt; revision &+= 1
    }

    mutating func grade(_ definition: KiceStudyDefinition, elapsedMs: Int, now: Date = Date()) throws -> KiceStudyReceipt {
        guard var attempt = attempts[definition.examID] else { throw Failure.notReady }
        if let id = attempt.receiptID, let existing = receipts[id] { return existing }
        guard elapsedMs >= 0, elapsedMs <= 365 * 24 * 3_600_000 else { throw Failure.invalid }
        guard attempt.contentFingerprint == definition.fingerprint else { throw Failure.incompatibleContent }
        let questions = definition.questions(subject: attempt.subject)
        guard !questions.isEmpty, questions.count <= 100, Set(questions.map(\.key)).count == questions.count else { throw Failure.invalid }
        var verdicts: [String: Bool] = [:], wrong: [KiceStudyWrongAnswer] = []
        var score = 0, correct = 0
        for question in questions {
            guard Self.validQuestion(question) else { throw Failure.invalid }
            let value = (attempt.answers[question.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let matches = question.isChoice ? value == question.answer : Int(value) != nil && Int(value) == Int(question.answer)
            verdicts[question.key] = matches
            if matches { score += question.points; correct += 1 }
            else { wrong.append(.init(question: question, submittedAnswer: value)) }
        }
        let result = KiceStudyResult(id: attempt.id, score: score, correctCount: correct, total: questions.count, verdicts: verdicts)
        let receipt = KiceStudyReceipt(id: attempt.id, examID: definition.examID, title: definition.title,
            shortTitle: definition.shortTitle, displayForm: definition.displayForm, subject: attempt.subject, gradedAt: now,
            elapsedMs: max(attempt.elapsedMs, elapsedMs), result: result, answers: attempt.answers,
            wrongAnswers: wrong, statisticsEpoch: statisticsEpoch)
        attempt.receiptID = receipt.id; attempt.elapsedMs = receipt.elapsedMs; attempt.updatedAt = now
        attempts[definition.examID] = attempt; receipts[receipt.id] = receipt; revision &+= 1
        try validate(expectedSlot: slot)
        return receipt
    }

    mutating func markEffectsApplied(_ id: String) {
        guard receipts[id] != nil else { return }
        receipts[id]?.localEffectsApplied = true
        receipts[id]?.effectsApplied = true; revision &+= 1
    }
    mutating func markLocalEffectsApplied(_ id: String) {
        guard receipts[id] != nil else { return }
        receipts[id]?.localEffectsApplied = true; revision &+= 1
    }
    mutating func resetStatistics() { statisticsEpoch = UUID().uuidString; revision &+= 1 }
    mutating func beginAgain(_ definition: KiceStudyDefinition, now: Date = Date()) throws {
        if let current = attempts[definition.examID] {
            guard let id = current.receiptID, receipts[id]?.effectsApplied == true else { throw Failure.notReady }
        }
        attempts[definition.examID] = nil
        _ = try prepare(definition, now: now)
    }
    var statistics: KiceStatisticsContribution {
        receipts.values.filter { $0.statisticsEpoch == statisticsEpoch }.reduce(into: .zero) {
            $0.solved += $1.result.total; $0.correct += $1.result.correctCount
        }
    }
    var pendingEffects: [KiceStudyReceipt] {
        receipts.values.filter { !$0.effectsApplied }.sorted { ($0.gradedAt, $0.id) < ($1.gradedAt, $1.id) }
    }
    func validate(expectedSlot: String) throws {
        guard schemaVersion == 1, slot == expectedSlot, !slot.isEmpty, slot.utf8.count <= 120,
              UUID(uuidString: statisticsEpoch) != nil, attempts.count <= 100, receipts.count <= 2000 else { throw Failure.invalid }
        for (key, attempt) in attempts {
            guard key == attempt.examID, !key.isEmpty, key.utf8.count <= 120, UUID(uuidString: attempt.id) != nil,
                  attempt.contentFingerprint.count == 64, attempt.contentFingerprint.allSatisfy({ $0.isHexDigit && !$0.isUppercase }),
                  !attempt.subject.isEmpty, attempt.subject.utf8.count <= 100,
                  attempt.answers.count <= 100, attempt.answers.allSatisfy({ $0.key.utf8.count <= 200 && $0.value.utf8.count <= 256 }),
                  attempt.elapsedMs >= 0, attempt.elapsedMs <= 365 * 24 * 3_600_000, (0...1000).contains(attempt.pdfPageIndex),
                  attempt.startedAt.timeIntervalSince1970.isFinite, attempt.updatedAt.timeIntervalSince1970.isFinite else { throw Failure.invalid }
            if let id = attempt.receiptID {
                guard id == attempt.id, receipts[id]?.examID == key else { throw Failure.invalid }
            }
        }
        for (key, receipt) in receipts {
            let result = receipt.result
            guard key == receipt.id, UUID(uuidString: key) != nil, result.id == key,
                  !receipt.effectsApplied || receipt.localEffectsApplied,
                  UUID(uuidString: receipt.statisticsEpoch) != nil, !receipt.examID.isEmpty,
                  (1...100).contains(result.total), (0...result.total).contains(result.correctCount),
                  (0...100).contains(result.score), result.verdicts.count == result.total,
                  result.verdicts.values.filter({ $0 }).count == result.correctCount,
                  receipt.answers.count <= 100, receipt.answers.allSatisfy({ $0.key.utf8.count <= 200 && $0.value.utf8.count <= 256 }),
                  receipt.wrongAnswers.count == result.wrongCount,
                  Set(receipt.wrongAnswers.map { $0.question.key }).count == result.wrongCount,
                  receipt.wrongAnswers.allSatisfy({ result.verdicts[$0.question.key] == false && Self.validQuestion($0.question)
                      && $0.submittedAnswer.utf8.count <= 256
                      && ($0.notePlan.map { !$0.noteID.isEmpty && $0.noteID.utf8.count <= 160 } ?? true) }),
                  receipt.elapsedMs >= 0, receipt.elapsedMs <= 365 * 24 * 3_600_000,
                  receipt.gradedAt.timeIntervalSince1970.isFinite else { throw Failure.invalid }
        }
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func validQuestion(_ question: KiceStudyQuestion) -> Bool {
        (1...100).contains(question.number) && !question.section.isEmpty && question.section.utf8.count <= 100
            && (0...100).contains(question.points)
            && (question.isChoice ? ["1", "2", "3", "4", "5"].contains(question.answer)
                : Int(question.answer).map { (0...999).contains($0) } ?? false)
    }
}

enum KiceStudyDisk {
    enum Loaded: Sendable { case missing, archive(KiceStudyArchive), unreadable }
    static func load(at url: URL, slot: String) -> Loaded {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                  let size = attributes[.size] as? NSNumber, size.intValue > 0,
                  size.intValue <= KiceStudyArchive.maximumBytes else { return .unreadable }
            let bytes = try Data(contentsOf: url)
            let archive = try JSONDecoder().decode(KiceStudyArchive.self, from: bytes)
            try archive.validate(expectedSlot: slot)
            return .archive(archive)
        } catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain && [CocoaError.fileNoSuchFile.rawValue, CocoaError.fileReadNoSuchFile.rawValue].contains(error.code) { return .missing }
            return .unreadable
        }
    }
    static func write(_ archive: KiceStudyArchive, at url: URL) -> Bool {
        do {
            try archive.validate(expectedSlot: archive.slot)
            let bytes = try JSONEncoder().encode(archive)
            guard bytes.count <= KiceStudyArchive.maximumBytes else { return false }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try ProtectedFileWriter.write(bytes, to: url)
            return true
        } catch { return false }
    }
}
