import Foundation

enum AppWorkspace: String, CaseIterable, Codable {
    case student, teacher, administrator
    var title: String {
        switch self { case .student: "내 학습"; case .teacher: "수업 관리"; case .administrator: "운영 관리" }
    }
    func allowed(role: String) -> Bool {
        self == .student || (self == .teacher && role == "teacher") || (self == .administrator && role == "admin")
    }
}

enum StudentDestination: String, CaseIterable, Identifiable {
    case today, learn, arena, records, me
    var id: String { rawValue }
    var title: String {
        switch self { case .today: "오늘"; case .learn: "학습"; case .arena: "Arena"; case .records: "기록"; case .me: "나" }
    }
    var icon: String {
        switch self { case .today: "sun.max"; case .learn: "book"; case .arena: "crown"; case .records: "chart.bar.xaxis"; case .me: "person.crop.circle" }
    }
    var route: AppStore.Route {
        switch self { case .today: .home; case .learn: .learn; case .arena: .rank; case .records: .records; case .me: .me }
    }
    static func containing(_ route: AppStore.Route) -> Self {
        switch route {
        case .home: .today
        case .learn, .curriculum, .concept, .assess, .paper, .quickPractice, .kice, .weeklyMock, .placement, .solve, .result: .learn
        case .rank, .arenaShop: .arena
        case .records, .wrongNotes: .records
        default: .me
        }
    }
}

enum ProductExperience {
    /// Release rollback does not touch progress, routes or stored drafts.
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "matths.productFlow.v2.enabled") as? Bool ?? true
    }
}

struct TodayActionCandidate: Equatable {
    enum Kind: Int { case timedWork, academy, review, curriculum, explore }
    let id: String
    let kind: Kind
    let title: String
    let reason: String
    let action: String
    let minutes: Int?
}

/// Candidates already carry validated destinations. This sorts presentation only;
/// it has no scoring, unlock, availability, entitlement or expiry calculations.
enum TodayActionResolver {
    static func resolve(_ candidates: [TodayActionCandidate]) -> TodayActionCandidate? {
        candidates.sorted {
            $0.kind.rawValue == $1.kind.rawValue ? $0.id < $1.id : $0.kind.rawValue < $1.kind.rawValue
        }.first
    }
}
