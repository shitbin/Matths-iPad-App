import Foundation

struct AcademyInviteDraft: Equatable, Sendable {
    static let expiryOptions = [7, 14, 30]
    var label = "학생 초대"
    var classID = ""
    var expiryDays = 14
    var maxUses = 30

    var normalizedLabel: String {
        let value = label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return value.isEmpty ? "학생 초대" : value
    }
    var validationMessage: String? {
        if normalizedLabel.utf16.count > 60 { return "초대 이름은 60자 이하로 입력해 주세요." }
        if !Self.expiryOptions.contains(expiryDays) { return "초대 유효기간을 7일, 14일, 30일 중에서 선택해 주세요." }
        if !(1...200).contains(maxUses) { return "최대 사용 횟수는 1~200회로 입력해 주세요." }
        return nil
    }
    var requestBody: [String: Any] {
        ["label": normalizedLabel, "classId": classID, "expiryDays": expiryDays, "maxUses": maxUses]
    }
}

enum AcademyInviteHistoryFilter: String, CaseIterable, Identifiable {
    case all = "전체", active = "사용 가능", inactive = "종료된 초대"
    var id: String { rawValue }
    func includes(_ rawState: String) -> Bool {
        switch self {
        case .all: true
        case .active: rawState == "ACTIVE"
        case .inactive: rawState != "ACTIVE"
        }
    }
}

enum AcademyInvitePresentation {
    static func stateLabel(_ raw: String) -> String {
        switch raw {
        case "ACTIVE": "사용 가능"
        case "REVOKED": "회수됨"
        case "EXPIRED": "기간 만료"
        case "EXHAUSTED": "사용 횟수 소진"
        default: "상태 확인 필요"
        }
    }
    static func link(token: String?, base: URL) -> URL? {
        guard let token, token.range(of: "^[A-Za-z0-9_-]{16,120}$", options: .regularExpression) != nil,
              let component = token.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")) else { return nil }
        return MatthsServiceURLPolicy.serviceURL(for: .academy, path: "/academy/join/" + component, base: base)
    }
    static func expirationLabel(_ raw: String?) -> String {
        guard let raw else { return "유효기간 정보 없음" }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        guard let date = iso.date(from: raw) ?? plain.date(from: raw) else { return "유효기간 확인 필요" }
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul"); formatter.dateFormat = "yyyy.M.d HH:mm"
        return formatter.string(from: date) + "까지"
    }
}
