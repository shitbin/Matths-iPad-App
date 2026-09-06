#if DEBUG
import Foundation

@MainActor
enum OfflinePracticeSelfTest {
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-offlinePracticeSelfTest") else { return }
        var rows: [[String: Any]] = []
        for course in AssessCatalog.data.courses where CurriculumPolicy.isAvailable(course.courseId) {
            guard let unit = course.units.first, let subunit = unit.subunits.first else { continue }
            for seed in 1...10 {
                let questions = PaperFactory.make(scope: .subunit, course: course, unit: unit, subunit: subunit,
                                                  seed: UInt64(seed), avoid: [])
                rows.append(["course": course.courseId, "seed": seed, "count": questions.count,
                             "passed": questions.count == 10 && Set(questions.map(\.prompt)).count == 10])
            }
        }
        if let course = AssessCatalog.data.courses.first {
            let shortage = PaperFactory.make(scope: .subunit, course: course, unit: nil, subunit: nil, seed: 1, avoid: [])
            rows.append(["case": "missing-range", "count": shortage.count, "passed": shortage.isEmpty])
        }
        let result: [String: Any] = ["environment": "DEBUG synthetic practice; no server mutations", "cases": rows,
                                     "passed": rows.allSatisfy { $0["passed"] as? Bool == true }]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: DataScope.url("offline-practice-qa.json"), options: .atomic)
        }
        print("OFFLINE-PRACTICE-QA \(rows.filter { $0["passed"] as? Bool == true }.count)/\(rows.count)")
    }
}
#endif
