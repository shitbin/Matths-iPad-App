import Foundation

enum KiceWrongNoteEffects {
    enum Failure: Error { case missingPlan, missingExistingNote, mismatchedNote }

    static func planned(_ receipt: KiceStudyReceipt, existing: [WrongNoteEntry]) -> KiceStudyReceipt {
        var result = receipt
        for index in result.wrongAnswers.indices where result.wrongAnswers[index].notePlan == nil {
            let wrong = result.wrongAnswers[index]
            let problemID = "\(receipt.examID)-\(wrong.question.section)-\(wrong.question.number)"
            let stableID = receipt.wrongNoteEffectID(wrong.question.key)
            if let alreadyApplied = existing.first(where: { $0.problemID == problemID && ($0.kiceReceiptIDs ?? []).contains(receipt.id) }) {
                result.wrongAnswers[index].notePlan = .init(noteID: alreadyApplied.id, wasNew: alreadyApplied.id == stableID)
            } else if let note = existing.first(where: { $0.problemID == problemID && !$0.isMastered }) {
                result.wrongAnswers[index].notePlan = .init(noteID: note.id, wasNew: false)
            } else {
                result.wrongAnswers[index].notePlan = .init(noteID: stableID, wasNew: true)
            }
        }
        return result
    }

    static func applying(_ receipt: KiceStudyReceipt, to current: [WrongNoteEntry]) throws -> [WrongNoteEntry] {
        guard !receipt.localEffectsApplied else { return current }
        var notes = current
        for wrong in receipt.wrongAnswers {
            guard let plan = wrong.notePlan else { throw Failure.missingPlan }
            let item = wrong.question
            let problemID = "\(receipt.examID)-\(item.section)-\(item.number)"
            if let index = notes.firstIndex(where: { $0.id == plan.noteID }) {
                guard notes[index].problemID == problemID else { throw Failure.mismatchedNote }
                if (notes[index].kiceReceiptIDs ?? []).contains(receipt.id) { continue }
                WrongNoteSRS.afterWrong(&notes[index], now: receipt.gradedAt)
                notes[index].myAnswer = wrong.submittedAnswer.isEmpty ? nil : wrong.submittedAnswer
                notes[index].kiceReceiptIDs = Array(Set((notes[index].kiceReceiptIDs ?? []) + [receipt.id])).sorted()
            } else {
                guard plan.wasNew else { throw Failure.missingExistingNote }
                let choiceKeys = ["a", "b", "c", "d", "e"]
                let answer: String
                if item.isChoice {
                    guard let value = Int(item.answer), (1...5).contains(value) else { throw Failure.mismatchedNote }
                    answer = choiceKeys[value - 1]
                } else { answer = item.answer }
                notes.insert(WrongNoteEntry(id: plan.noteID, problemID: problemID, typeKey: "kice-\(receipt.examID)",
                    typeName: "\(receipt.shortTitle) \(item.section) \(item.number)번", unit: "기출 \(receipt.shortTitle)",
                    statement: "“\(receipt.title)” 수학 영역\(receipt.displayForm.map { "(\($0))" } ?? "") \(item.section) \(item.number)번, \(item.points)점 문항입니다. 평가센터의 기출에서 문제지 PDF를 열어 다시 풀어보세요.",
                    answer: answer,
                    steps: ["기출 문항은 앱이 모범 풀이를 제공하지 않습니다. 문제지 PDF로 다시 푼 뒤, 해설이 필요하면 EBSi 무료 해설 강의를 참고하세요."],
                    seed: 0, divergenceStep: nil, drawingPNGBase64: nil, srsStage: 0, nextReviewAt: receipt.gradedAt,
                    wrongCount: 1, createdAt: receipt.gradedAt, choices: item.isChoice ? ["", "", "", "", ""] : nil,
                    isTex: item.isChoice, myAnswer: wrong.submittedAnswer.isEmpty ? nil : wrong.submittedAnswer,
                    kiceReceiptIDs: [receipt.id]), at: 0)
            }
        }
        return notes
    }
}
