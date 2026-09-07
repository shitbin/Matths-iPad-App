import Foundation

extension KiceStudyDefinition {
    init(exam: KiceExam) {
        func question(_ item: KiceItem, section: String) -> KiceStudyQuestion {
            .init(section: section, number: item.no, answer: item.answer, points: item.points, isChoice: item.isChoice)
        }
        self.init(examID: exam.id, title: exam.title, shortTitle: exam.short, displayForm: exam.displayForm,
            common: exam.common.map { question($0, section: "공통") },
            electives: Dictionary(uniqueKeysWithValues: exam.electives.map { entry in
                (entry.key, entry.value.map { question($0, section: entry.key) })
            }))
    }
}
