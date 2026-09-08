import Foundation

@main struct TodayDashboardPolicyCases {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_000)
        func candidate(_ id: String, _ destination: TodayActionCandidate.Destination,
                       source: TodayActionCandidate.Source = .serverAssessment,
                       freshness: TodayActionCandidate.Freshness = .current,
                       deadline: Date? = nil) -> TodayActionCandidate {
            .init(id: id, kind: .timedWork, title: id, reason: "실제 기록", action: "확인", minutes: nil,
                  destination: destination, source: source, freshness: freshness,
                  fetchedAt: now, deadline: deadline)
        }
        let primary = candidate("primary", .officialAssessment("a"))
        let repeatedPrimary = candidate("different-id", .officialAssessment("a"))
        let first = candidate("b", .weeklyMock("week"), deadline: now.addingTimeInterval(60))
        let duplicate = candidate("b-duplicate", .weeklyMock("week"), deadline: now.addingTimeInterval(61))
        let review = candidate("review", .review, source: .durableReview, freshness: .local)
        let navigation = candidate("navigation", .learn, source: .navigation)
        let concept = candidate("concept", .concept("c1"), source: .canonicalLearning)
        let items = TodayDashboardPolicy.agenda([repeatedPrimary, first, duplicate, review, navigation, concept], primary: primary, now: now)
        precondition(items.map(\.id) == ["b", "review"], "primary destination, duplicate links and navigation must not repeat")
        precondition(TodayDashboardPolicy.agenda([], primary: nil, now: now).isEmpty, "no invented work")
        let many = (0..<10).map { candidate("item-\($0)", .officialAssessment("\($0)")) }
        precondition(TodayDashboardPolicy.agenda(many, primary: nil, now: now).count == 3, "agenda remains bounded")
        var old = candidate("old", .arena("match"), deadline: now)
        old.fetchedAt = now.addingTimeInterval(-600)
        let ordered = TodayDashboardPolicy.agenda([old, first], primary: nil, now: now)
        precondition(ordered.first?.id == "b", "current state sorts before stale state")
        precondition(ordered.last?.visibleAction == "최신 상태 확인", "stale state never promises permission")
        let expiredPrimary = candidate("main", .review, source: .durableReview)
        precondition(TodayDashboardPolicy.agenda([review], primary: expiredPrimary, now: now).isEmpty)
        print("Today dashboard policy: 6 cases passed")
    }
}
