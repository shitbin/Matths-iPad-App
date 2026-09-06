import Foundation

// The production progress reducer is tested independently of JavaScriptCore and
// bundled content. Native fixture types provide an initial unconfirmed local gate.
enum WebGen {
    struct ConceptGenInfo { let requiredDistinctTypes: Int; let typeIds: [String] }
    static func conceptInfo(courseId: String, unitId: String, conceptId: String,
                            includeCurriculumChecks: Bool) -> ConceptGenInfo? { nil }
}

@main
struct ProgressAuthorityCases {
    static func main() {
        let concept = ConceptV2(id: "fixture", order: 1, title: "Fixture", standardCode: nil,
            achievementStandard: nil, topics: ["topic"], scopeNotes: [], visualizationIdeas: [], lesson: nil,
            legacy: LegacyV2(appId: "fixture", tag: nil, oneLiner: nil, scene: nil, hasPlayground: false,
                             web: nil, generatorTypes: ["a", "b"], lessonText: nil))
        let course = CourseV2(id: "common-math-1", title: "공통수학1", category: "common", order: 1,
                              prerequisites: [], recommendedGrades: [10],
                              units: [UnitV2(id: "unit", title: "단원", order: 1, concepts: [concept])])
        var progress = ProgressV2Store()
        progress.recordCorrectType("a", conceptID: concept.id)
        progress.recordCorrectType("b", conceptID: concept.id)
        progress.setUserCompleted(true, concept: concept)
        precondition(progress.percent(for: concept) == 100)
        progress.mergeRemote(conceptId: concept.id, topicIndexes: [], correctTypeIds: [], userCompleted: false,
                             lastStudiedAt: nil, serverPercent: 0, serverRequiredDistinctTypes: 2,
                             serverCorrectTypeIDs: [])
        precondition(progress.percent(for: concept) == 0)
        precondition(!progress.masteryUnlocked(for: concept))
        precondition(progress.byConcept[concept.id]?.correctTypeIds == ["a", "b"], "Local draft must remain preserved")
        let canonical = CanonicalLearningSnapshot(overallProgress: 0, completedConcepts: 0, totalConcepts: 1,
            continueConcept: .init(id: concept.id, href: "/learn/common-math-1/unit/fixture"),
            courses: [.init(id: course.id, category: "common", developmentLocked: false, hasActivity: false,
                            units: [.init(id: "unit", concepts: [.init(id: concept.id, progress: 0)])])])
        progress.applyCanonical(canonical)
        precondition(!progress.hasActivity(course))
        precondition(!progress.masteryUnlocked(for: concept))
        progress.mergeRemote(conceptId: concept.id, topicIndexes: [0], correctTypeIds: ["a", "b"], userCompleted: true,
                             lastStudiedAt: nil, serverPercent: 100, serverRequiredDistinctTypes: 2,
                             serverCorrectTypeIDs: ["a", "b"])
        precondition(progress.percent(for: concept) == 100 && progress.masteryUnlocked(for: concept))
        print("Confirmed server progress/gate overrides preserve unconfirmed local drafts: PASS")
    }
}
