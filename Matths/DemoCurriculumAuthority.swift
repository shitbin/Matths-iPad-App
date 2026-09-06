#if DEBUG
import Foundation

enum DemoCurriculumAuthority {
    private static func json(_ value: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
    static var availability: String {
        let baseline = CurriculumAvailabilitySnapshot.safeBaseline(environment: ServerAPI.defaultURL)
        return json(["curriculum": ["schemaVersion": 1, "curriculum": ["id": "kr-2022"],
                                    "courses": baseline.orderedCourseIDs.map { ["id": $0, "developmentLocked": baseline.locked[$0] ?? true] as [String: Any] }]])
    }
    static var learning: String {
        let baseline = CurriculumAvailabilitySnapshot.safeBaseline(environment: ServerAPI.defaultURL)
        let courses: [[String:Any]] = CurriculumV2.data.courses.map { course in
            ["id": course.id, "category": course.category, "developmentLocked": !baseline.isAvailable(course.id),
             "hasActivity": false, "units": course.units.map { unit in
                ["id": unit.id, "concepts": unit.concepts.map { ["id": $0.id, "progress": 0] as [String:Any] }] as [String:Any]
             }]
        }
        let common = CurriculumV2.data.courses.filter { $0.category == "common" && baseline.isAvailable($0.id) }
        var next: Any = NSNull()
        if let c = common.first, let u = c.units.first, let x = u.concepts.first {
            next = ["id": x.id, "href": "/learn/\(c.id)/\(u.id)/\(x.id)"]
        }
        return json(["learning": ["overallProgress": 0, "completedConcepts": 0,
                                  "totalConcepts": common.flatMap(\.allConcepts).count,
                                  "continueConcept": next, "courses": courses]])
    }
}
#endif
