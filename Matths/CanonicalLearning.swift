import Foundation

/// Read-only subset of GET /api/v1/learning, including Web's exact course order.
struct CanonicalLearningSnapshot: Codable, Equatable, Sendable {
    struct Concept: Codable, Equatable, Sendable { let id: String; let progress: Int }
    struct Unit: Codable, Equatable, Sendable { let id: String; let concepts: [Concept] }
    struct Course: Codable, Equatable, Sendable {
        let id: String
        let category: String
        let developmentLocked: Bool
        let hasActivity: Bool
        let units: [Unit]
    }
    struct Next: Codable, Equatable, Sendable { let id: String; let href: String }
    let overallProgress: Int
    let completedConcepts: Int
    let totalConcepts: Int
    let continueConcept: Next?
    let courses: [Course]

    struct Projection: Equatable {
        let percent: Int
        let done: Int
        let total: Int
        let nextConceptID: String?
    }

    var isValid: Bool {
        !courses.isEmpty && Set(courses.map(\.id)).count == courses.count
            && (0...100).contains(overallProgress) && completedConcepts >= 0
            && totalConcepts >= completedConcepts
            && courses.allSatisfy { course in
                !course.id.isEmpty && course.units.allSatisfy { unit in
                    !unit.id.isEmpty && unit.concepts.allSatisfy { !$0.id.isEmpty && (0...100).contains($0.progress) }
                }
            }
    }

    /// Web curriculumService.buildLearningViewModel @ e3cc063:
    /// active common/elective scope, Math.round, in-progress → common → any.
    /// Used only if availability changed since this verified server projection.
    func projection(using availability: CurriculumAvailabilitySnapshot) -> Projection {
        let eligible = courses.filter { availability.isAvailable($0.id) && !$0.developmentLocked }
        let scoped = eligible.filter { $0.category == "common" || $0.hasActivity }
            .flatMap { $0.units.flatMap(\.concepts) }
        let all = eligible.flatMap { $0.units.flatMap(\.concepts) }
        let common = eligible.filter { $0.category == "common" }.flatMap { $0.units.flatMap(\.concepts) }
        let compatible = courses.allSatisfy { availability.locked[$0.id] == $0.developmentLocked }
        let next = all.first { $0.progress > 0 && $0.progress < 100 }
            ?? common.first { $0.progress < 100 } ?? all.first { $0.progress < 100 }
        let serverNext = continueConcept.flatMap { candidate in all.contains { $0.id == candidate.id } ? candidate.id : nil }
        return Projection(
            percent: compatible ? overallProgress : (scoped.isEmpty ? 0 : Int((Double(scoped.reduce(0) { $0 + $1.progress }) / Double(scoped.count)).rounded())),
            done: compatible ? completedConcepts : scoped.filter { $0.progress >= 100 }.count,
            total: compatible ? totalConcepts : scoped.count,
            nextConceptID: compatible ? serverNext : next?.id)
    }
}
