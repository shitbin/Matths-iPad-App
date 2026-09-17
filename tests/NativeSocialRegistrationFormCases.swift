import Foundation

@main
enum NativeSocialRegistrationFormCases {
    static func main() {
        let calendar = NativeSocialRegistrationDraft.calendar
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 17))!
        let birthday = calendar.date(from: DateComponents(year: 2008, month: 2, day: 29))!

        func issue(_ draft: NativeSocialRegistrationDraft) -> NativeSocialRegistrationIssue.Field? {
            draft.firstIssue(now: today)?.field
        }
        func expect(_ draft: NativeSocialRegistrationDraft, _ field: NativeSocialRegistrationIssue.Field?, _ reason: String) {
            precondition(issue(draft) == field, reason)
        }
        var draft = NativeSocialRegistrationDraft()
        precondition(draft.birthDate == nil && draft.schoolGrade == nil,
                     "a birthday or education status must never be silently invented")
        precondition(!draft.termsAccepted && !draft.privacyAccepted,
                     "each mandatory consent must start off")
        expect(draft, .realName, "empty profile should begin at real name")
        draft.realName = "홍길동"
        expect(draft, .name, "nickname is required after the provider-suggested real name")
        draft.name = "풀이연습"
        expect(draft, .birthDate, "birth date must be explicitly selected")
        draft.birthDate = birthday
        precondition(draft.birthDateString == "2008-02-29", "Gregorian leap day must retain its local calendar date")
        expect(draft, .schoolGrade, "education must be explicitly selected")
        draft.schoolGrade = 13
        expect(draft, .terms, "retakers do not need a school but do need consent")
        draft.termsAccepted = true
        expect(draft, .privacy, "agreeing to terms must not agree to privacy")
        draft.privacyAccepted = true
        expect(draft, nil, "retaker profile is valid without school or university")

        let valid = draft
        for grade in [13, 15] {
            draft = valid
            draft.schoolGrade = grade
            draft.schoolCode = "OVERSEAS_HIGH_SCHOOL"
            draft.schoolName = "<invalid unused school>"
            draft.universityCode = "OVERSEAS_UNIVERSITY"
            draft.universityName = "<invalid unused university>"
            expect(draft, nil, "unused affiliation must not block retaker or worker registration")
            precondition(!draft.needsSchool && !draft.needsUniversity)
        }
        for grade in [10, 11, 12] {
            draft = valid
            draft.schoolGrade = grade
            expect(draft, .school, "all high-school grades require a school")
            draft.schoolRegion = "서울"
            expect(draft, .school, "region without a school code is insufficient")
            draft.schoolCode = "TEST-HIGH-SCHOOL"
            draft.schoolName = "테스트 고등학교"
            expect(draft, nil, "a domestic catalog school completes high-school profile")
            draft.schoolRegion = "해외"
            draft.schoolCode = "OVERSEAS_HIGH_SCHOOL"
            draft.schoolName = ""
            expect(draft, .schoolName, "overseas sentinel requires the school's actual name")
            draft.schoolName = "Example High School"
            expect(draft, nil, "overseas school with a valid custom name is accepted")
        }
        draft = valid
        draft.schoolGrade = 14
        expect(draft, .university, "university students require a university instead of a school")
        draft.universityCode = "TEST-UNIVERSITY"
        expect(draft, nil, "domestic university code is sufficient for catalog validation on the server")
        draft.universityCode = "OVERSEAS_UNIVERSITY"
        draft.universityName = "x"
        expect(draft, .universityName, "one-character overseas institution name is rejected")
        draft.universityName = String(repeating: "A", count: 121)
        expect(draft, .universityName, "overseas institution name follows server length limit")
        draft.universityName = "Example <University>"
        expect(draft, .universityName, "markup-like institution names are rejected")
        draft.universityName = "Example\u{0001}University"
        expect(draft, .universityName, "control characters in institution names are rejected")
        draft.universityName = "　Ｅｘａｍｐｌｅ   University  "
        expect(draft, nil, "valid institution is normalized before measuring and sending")
        precondition(NativeSocialRegistrationDraft.normalizedInstitutionName(draft.universityName) == "Example University")

        draft = valid
        draft.birthDate = calendar.date(from: DateComponents(year: 1899, month: 12, day: 31))!
        expect(draft, .birthDate, "pre-1900 date must be rejected")
        draft.birthDate = NativeSocialRegistrationDraft.earliestBirthDate
        expect(draft, nil, "1900-01-01 is the first accepted birth date")
        draft.birthDate = today.addingTimeInterval(60 * 60 * 18)
        expect(draft, nil, "today remains valid regardless of time-of-day")
        draft.birthDate = calendar.date(byAdding: .day, value: 1, to: today)!
        expect(draft, .birthDate, "future calendar date must be rejected")
        for grade in [-1, 0, 9, 16, 99] {
            draft = valid
            draft.schoolGrade = grade
            expect(draft, .schoolGrade, "unknown grade must fail closed")
        }
        for invalidName in [" ", "김", "Test123", "<학생>", "'Anne", "--", String(repeating: "가", count: 41)] {
            draft = valid
            draft.realName = invalidName
            expect(draft, .realName, "real name validation must match the server constraints")
        }
        for name in ["홍길동", "D'Angelo", "D’Angelo", "Anne-Marie", "A. Kim", "Élodie", "E\u{0301}lodie"] {
            draft = valid
            draft.realName = name
            expect(draft, nil, "international names must remain usable")
        }
        for invalidNickname in [" ", "가", "<학생>", String(repeating: "가", count: 31)] {
            draft = valid
            draft.name = invalidNickname
            expect(draft, .name, "nickname validation must trim whitespace and respect length")
        }
        precondition(NativeSocialRegistrationDraft.normalizedRealName(" Anne  Marie ") == "Anne Marie")
        precondition(NativeSocialRegistrationDraft.normalizedNickname(" Ａ\u{0001}  B ") == "A B")
        print("Native social registration form cases passed: empty defaults, independent consent, 6 education statuses, overseas names, Gregorian dates, and profile boundaries.")
    }
}
