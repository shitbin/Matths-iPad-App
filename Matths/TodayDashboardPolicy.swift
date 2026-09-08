import Foundation

/// More context on Today must not become another directory of navigation links.
/// Only real work/review survives, and one destination is never offered twice.
enum TodayDashboardPolicy {
    static func agenda(_ candidates: [TodayActionCandidate], primary: TodayActionCandidate?, now: Date = Date()) -> [TodayActionCandidate] {
        var seen: [TodayActionCandidate.Destination] = primary.map { [$0.destination] } ?? []
        let ordered = candidates.map { $0.presentation(at: now) }.filter {
            $0.source != .navigation && $0.source != .canonicalLearning
        }.sorted {
            if ($0.freshness == .cached) != ($1.freshness == .cached) { return $0.freshness != .cached }
            if $0.deadline != $1.deadline { return ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            return $0.id < $1.id
        }
        return ordered.filter { item in
            guard !seen.contains(item.destination) else { return false }
            seen.append(item.destination)
            return true
        }.prefix(3).map { $0 }
    }
}
