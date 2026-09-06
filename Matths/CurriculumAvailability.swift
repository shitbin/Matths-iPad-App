import Foundation

/// Public policy is independent of bundled lesson content and account progress.
struct CurriculumAvailabilitySnapshot: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable { case liveServer, lastVerifiedCache, bundledSafeBaseline }
    var environment: String
    var curriculumID: String
    var schemaVersion: Int
    var orderedCourseIDs: [String]
    var locked: [String: Bool]
    var fetchedAt: Date
    var source: Source

    func isAvailable(_ courseID: String) -> Bool { locked[courseID] == false }

    static func safeBaseline(environment: String) -> Self {
        let order = ["common-math-1", "common-math-2", "algebra", "calculus-1",
                     "probability-statistics", "calculus-2", "geometry", "economics-math",
                     "ai-math", "vocational-math", "math-and-culture", "practical-statistics",
                     "math-research-project"]
        return Self(environment: environment, curriculumID: "kr-2022", schemaVersion: 1,
                    orderedCourseIDs: order,
                    locked: Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset >= 5) }),
                    fetchedAt: .distantPast, source: .bundledSafeBaseline)
    }

    var isValid: Bool {
        schemaVersion == 1 && !environment.isEmpty && !curriculumID.isEmpty
            && !orderedCourseIDs.isEmpty && Set(orderedCourseIDs).count == orderedCourseIDs.count
            && Set(locked.keys) == Set(orderedCourseIDs)
            && orderedCourseIDs.allSatisfy { !$0.isEmpty && !$0.contains("/") }
    }
}

/// Exact envelope of apiController.curriculum at Web e3cc063.
struct CurriculumAvailabilityResponse: Decodable {
    struct Catalog: Decodable {
        struct Identity: Decodable { let id: String }
        struct Course: Decodable { let id: String; let developmentLocked: Bool }
        let schemaVersion: Int
        let curriculum: Identity
        let courses: [Course]
    }
    let curriculum: Catalog

    func validated(environment: String, now: Date = Date()) throws -> CurriculumAvailabilitySnapshot {
        let ids = curriculum.courses.map(\.id)
        guard !ids.isEmpty, Set(ids).count == ids.count else { throw CurriculumPolicyError.malformed }
        let result = CurriculumAvailabilitySnapshot(
            environment: environment, curriculumID: curriculum.curriculum.id,
            schemaVersion: curriculum.schemaVersion, orderedCourseIDs: ids,
            locked: Dictionary(uniqueKeysWithValues: curriculum.courses.map { ($0.id, $0.developmentLocked) }),
            fetchedAt: now, source: .liveServer)
        guard result.isValid else { throw CurriculumPolicyError.malformed }
        return result
    }
}

enum CurriculumPolicyError: Error { case malformed }

/// Synchronous pure projections and background journals share one immutable snapshot.
/// The network/cache owner below is the only writer; no View keeps its own allowlist.
enum CurriculumPolicy {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var snapshot = CurriculumAvailabilitySnapshot.safeBaseline(environment: "https://www.matths.kr")
    }
    private static let storage = Storage()
    static var snapshot: CurriculumAvailabilitySnapshot {
        storage.lock.lock(); defer { storage.lock.unlock() }
        return storage.snapshot
    }
    static func apply(_ value: CurriculumAvailabilitySnapshot) {
        guard value.isValid else { return }
        storage.lock.lock(); defer { storage.lock.unlock() }
        storage.snapshot = value
    }
    static func isAvailable(_ courseID: String) -> Bool { snapshot.isAvailable(courseID) }
}
