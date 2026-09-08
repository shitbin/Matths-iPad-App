import Foundation

enum AppWorkspace: String, CaseIterable, Codable {
    case student, teacher, administrator
    var title: String {
        switch self { case .student: "내 학습"; case .teacher: "수업 관리"; case .administrator: "운영 관리" }
    }
    func allowed(role: String) -> Bool {
        self == .student || (self == .teacher && role == "teacher") || (self == .administrator && role == "admin")
    }
    static func initial(role: String, savedValue: String?) -> Self {
        let role = role.lowercased()
        if let savedValue, let saved = Self(rawValue: savedValue), saved.allowed(role: role) { return saved }
        switch role {
        case "teacher": return .teacher
        case "admin": return .administrator
        default: return .student
        }
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
        case .learn, .curriculum, .concept, .assess, .paper, .quickPractice, .kice, .weeklyMock, .placement, .pro, .solve, .result: .learn
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
