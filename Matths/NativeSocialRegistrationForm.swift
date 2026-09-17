import Foundation

/// Provider credentials and registration tokens never enter the editable draft.
/// Dates and education status stay unselected until the person supplies them.
struct NativeSocialRegistrationDraft {
    var realName = ""
    var name = ""
    var birthDate: Date?
    var schoolGrade: Int?
    var schoolRegion = ""
    var schoolCode = ""
    var schoolName = ""
    var universityCode = ""
    var universityName = ""
    var termsAccepted = false
    var privacyAccepted = false

    var needsSchool: Bool { schoolGrade.map { (10...12).contains($0) } ?? false }
    var needsUniversity: Bool { schoolGrade == 14 }
    var isOverseasSchool: Bool { schoolCode == "OVERSEAS_HIGH_SCHOOL" }
    var isOverseasUniversity: Bool { universityCode == "OVERSEAS_UNIVERSITY" }

    var birthDateString: String? {
        guard let birthDate else { return nil }
        let parts = Self.calendar.dateComponents([.year, .month, .day], from: birthDate)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static var calendar: Calendar {
        // The API accepts a Gregorian calendar date, not a locale-specific year
        // or a UTC instant that can move a birthday to the previous day.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static var earliestBirthDate: Date {
        calendar.date(from: DateComponents(year: 1900, month: 1, day: 1))!
    }

    func firstIssue(now: Date = Date()) -> NativeSocialRegistrationIssue? {
        let realName = Self.normalizedRealName(realName)
        if !(2...40).contains(realName.utf16.count) {
            return .init(field: .realName, message: "실명은 2자 이상 40자 이하로 입력해 주세요.")
        }
        if realName.range(of: #"^[\p{L}][\p{L}\p{M}\s.'’-]*$"#, options: .regularExpression) == nil {
            return .init(field: .realName, message: "실명에는 문자, 공백, 마침표, 작은따옴표와 붙임표를 사용할 수 있습니다.")
        }
        let name = Self.normalizedNickname(name)
        if !(2...30).contains(name.utf16.count) {
            return .init(field: .name, message: "닉네임은 2자 이상 30자 이하로 입력해 주세요.")
        }
        if name.contains("<") || name.contains(">") {
            return .init(field: .name, message: "닉네임에는 꺾쇠 괄호를 사용할 수 없습니다.")
        }
        guard let birthDate else {
            return .init(field: .birthDate, message: "생년월일을 선택해 주세요.")
        }
        let birthday = Self.calendar.startOfDay(for: birthDate)
        if birthday < Self.earliestBirthDate || birthday > Self.calendar.startOfDay(for: now) {
            return .init(field: .birthDate, message: "생년월일은 1900년 1월 1일부터 오늘까지 선택할 수 있습니다.")
        }
        guard let schoolGrade, (10...15).contains(schoolGrade) else {
            return .init(field: .schoolGrade, message: "학년 또는 현재 상태를 선택해 주세요.")
        }
        if needsSchool {
            if Self.trimmed(schoolRegion).isEmpty || Self.trimmed(schoolCode).isEmpty {
                return .init(field: .school, message: "재학 중인 고등학교를 선택해 주세요.")
            }
            if isOverseasSchool, let message = Self.institutionNameIssue(schoolName, label: "해외 고등학교") {
                return .init(field: .schoolName, message: message)
            }
        }
        if needsUniversity {
            if Self.trimmed(universityCode).isEmpty {
                return .init(field: .university, message: "재학 중인 대학교를 선택해 주세요.")
            }
            if isOverseasUniversity, let message = Self.institutionNameIssue(universityName, label: "해외 대학교") {
                return .init(field: .universityName, message: message)
            }
        }
        if !termsAccepted {
            return .init(field: .terms, message: "이용약관을 확인하고 필수 동의 항목을 선택해 주세요.")
        }
        if !privacyAccepted {
            return .init(field: .privacy, message: "개인정보 처리방침을 확인하고 필수 동의 항목을 선택해 주세요.")
        }
        return nil
    }

    static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedInstitutionName(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func normalizedRealName(_ value: String) -> String {
        value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func normalizedNickname(_ value: String) -> String {
        let normalized = value.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: #"[\u0000-\u001f\u007f]+"#, with: "", options: .regularExpression)
        return normalized.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func institutionNameIssue(_ value: String, label: String) -> String? {
        let name = normalizedInstitutionName(value)
        if !(2...120).contains(name.utf16.count) {
            return "\(label) 이름은 2자 이상 120자 이하로 입력해 주세요."
        }
        if name.range(of: #"[<>\u0000-\u001f\u007f]"#, options: .regularExpression) != nil {
            return "\(label) 이름에서 꺾쇠 괄호와 제어 문자를 제외해 주세요."
        }
        return nil
    }
}

struct NativeSocialRegistrationIssue: Equatable {
    enum Field: String {
        case realName, name, birthDate, schoolGrade, school, schoolName
        case university, universityName, terms, privacy
    }

    let field: Field
    let message: String
}
