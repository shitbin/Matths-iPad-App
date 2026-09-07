import Foundation

@main enum KiceWrongNoteEffectsCases {
    static func main() throws {
        let definition = KiceStudyDefinition(examID: "exam-A", title: "검증 기출", shortTitle: "검증", displayForm: nil,
            common: [.init(section: "공통", number: 1, answer: "3", points: 100, isChoice: true)], electives: ["미적분": []])
        var archive = KiceStudyArchive(slot: "account-A")
        _ = try archive.prepare(definition)
        try archive.answer(examID: "exam-A", key: "공통-1", value: "2")
        let receipt = try archive.grade(definition, elapsedMs: 1000, now: Date(timeIntervalSince1970: 1700000000))
        let planned = KiceWrongNoteEffects.planned(receipt, existing: [])
        let first = try KiceWrongNoteEffects.applying(planned, to: [])
        precondition(first.count == 1 && first[0].wrongCount == 1)
        precondition(first[0].answer == "c" && first[0].myAnswer == "2")
        precondition(first[0].kiceReceiptIDs == [receipt.id])
        let encoded = try JSONEncoder().encode(first)
        let afterCrash = try JSONDecoder().decode([WrongNoteEntry].self, from: encoded)
        let replay = try KiceWrongNoteEffects.applying(planned, to: afterCrash)
        precondition(replay.count == 1 && replay[0].id == first[0].id && replay[0].wrongCount == 1,
                     "crash after wrong-note write but before receipt marker must not create/increment twice")
        var reviewed = afterCrash
        WrongNoteSRS.afterCorrect(&reviewed[0])
        let afterReviewReplay = try KiceWrongNoteEffects.applying(planned, to: reviewed)
        precondition(afterReviewReplay.count == 1 && afterReviewReplay[0].isMastered,
                     "recovery must not reopen a note already mastered after the receipt")

        var existing = first[0]
        existing.kiceReceiptIDs = nil; existing.wrongCount = 7
        let reuse = KiceWrongNoteEffects.planned(receipt, existing: [existing])
        precondition(reuse.wrongAnswers[0].notePlan?.wasNew == false)
        let increment = try KiceWrongNoteEffects.applying(reuse, to: [existing])
        precondition(increment[0].wrongCount == 8)
        precondition(increment[0].nextReviewAt == WrongNoteSRS.nextKSTMidnight(from: receipt.gradedAt))
        let retriedIncrement = try KiceWrongNoteEffects.applying(reuse, to: increment)
        precondition(retriedIncrement[0].wrongCount == 8)
        do {
            _ = try KiceWrongNoteEffects.applying(reuse, to: [])
            preconditionFailure("missing existing record must not be silently recreated")
        } catch KiceWrongNoteEffects.Failure.missingExistingNote {}
        var localDone = reuse; localDone.localEffectsApplied = true
        let alreadyLocal = try KiceWrongNoteEffects.applying(localDone, to: [])
        precondition(alreadyLocal.isEmpty)
        print("KICE wrong-note effects PASS: frozen plan, stable IDs, Codable receipt markers, crash replay, SRS once, later review preservation, missing-record safety.")
    }
}
