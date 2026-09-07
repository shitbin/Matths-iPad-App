import Foundation
import Combine

/// Student drafts contain only the student's answers. The server remains the
/// authority for membership, question configuration, deadlines and grading.
@MainActor
final class AcademyAssignmentStudentModel: ObservableObject {
    @Published private(set) var response: ServerAPI.AcademyWeekResponse
    @Published private(set) var answers: [String] = []
    @Published private(set) var receipt: AcademyAssignmentSubmission?
    @Published private(set) var busy = false
    @Published private(set) var loaded = false
    @Published private(set) var denied = false
    @Published private(set) var configurationChanged = false
    @Published private(set) var draftError: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?

    private let owner: AccountRequestOwner
    private let store: AppStore
    private var active = true
    private var operation = UUID()
    private var draft: NativeServiceDraft
    private var draftLoaded = false
    private var dirty = false
    private var serverClock: Date?
    private var receivedAt: TimeInterval?

    init(response: ServerAPI.AcademyWeekResponse, owner: AccountRequestOwner, store: AppStore) {
        self.response = response; self.owner = owner; self.store = store
        draft = .init(slot: owner.slot, resource: "academy-assignment-\(response.week.id)")
    }

    var omr: AcademyAssignmentOMR? {
        guard !denied, let value = response.week.assignmentOmr, value.isValid else { return nil }
        return value
    }
    var answeredCount: Int { answers.filter { !AcademyAssignmentConfiguration.normalizedAnswer($0).isEmpty }.count }
    var firstMissing: Int? { answers.firstIndex { AcademyAssignmentConfiguration.normalizedAnswer($0).isEmpty } }
    var hasUnstoredChanges: Bool { dirty && draftError != nil && draftLoaded }
    var canEdit: Bool { loaded && current && !denied && !busy && draftLoaded && !configurationChanged && omr != nil && !deadlinePassed }
    var canSubmit: Bool { canEdit && draftError == nil && dirty && validationMessage == nil }
    var deadlinePassed: Bool {
        guard let deadline = Self.date(response.week.dueAt), let serverClock, let receivedAt else { return false }
        // This monotonic estimate is informational. Every submission first
        // fetches serverTime again, and the server enforces the real deadline.
        return deadline <= serverClock.addingTimeInterval(max(0, ProcessInfo.processInfo.systemUptime - receivedAt))
    }
    var validationMessage: String? {
        guard let omr, answers.count == omr.questionCount else { return "답안지를 다시 불러와 주세요." }
        for (index, raw) in answers.enumerated() {
            let value = AcademyAssignmentConfiguration.normalizedAnswer(raw)
            guard !value.isEmpty else { return "\(index + 1)번 답을 입력해 주세요." }
            guard value.utf16.count <= 80 else { return "\(index + 1)번 답은 80자 이내로 입력해 주세요." }
            if let section = omr.section(for: index + 1), section.answerType == .multipleChoice,
               !(value.count == 1 && Int(value).map({ (1...section.choiceCount).contains($0) }) == true) {
                return "\(index + 1)번 답을 1~\(section.choiceCount) 중에서 선택해 주세요."
            }
        }
        return nil
    }

    func start() async {
        guard current, !loaded, !busy else { return }
        do {
            draft = try NativeServiceDraftDisk.load(slot: owner.slot, resource: draft.resource)
            draftLoaded = true
            if let encoded = draft.fields["answers"] {
                guard let data = encoded.data(using: .utf8) else { throw CocoaError(.fileReadCorruptFile) }
                let restored = try JSONDecoder().decode([String].self, from: data)
                guard (1...100).contains(restored.count), restored.allSatisfy({ $0.utf16.count <= 160 }),
                      draft.fields["configuration"] != nil else { throw CocoaError(.fileReadCorruptFile) }
                answers = restored; dirty = draft.fields["dirty"] == "true"
            }
        } catch {
            draftLoaded = false
            draftError = "저장된 답안을 읽지 못했습니다. 원본을 덮어쓰지 않았습니다. 재시도하거나 원본 백업 후 새로 작성해 주세요."
        }
        await refresh()
    }

    func refresh() async {
        guard current, !busy else { return }
        let ticket = UUID(); operation = ticket; busy = true; errorMessage = nil
        defer { if accepts(ticket) { busy = false; loaded = true } }
        do {
            let latest = try await ServerAPI.academyWeek(response.week.id, authorization: owner.authorization)
            guard accepts(ticket) else { return }
            install(latest)
        } catch {
            guard accepts(ticket) else { return }
            handle(error)
        }
    }

    func setAnswer(_ value: String, at index: Int) {
        guard canEdit, answers.indices.contains(index) else { return }
        // Do not split a grapheme or UTF16 surrogate at the server's 80-unit
        // boundary. Preserve readable input and reject excessive input below.
        let value = String(value.prefix(80))
        guard value.utf16.count <= 160 else { return }
        answers[index] = value; dirty = true; notice = nil
        persist()
    }

    func retryDraft() {
        guard current, !busy else { return }
        if draftLoaded { persist() }
        else { loaded = false; Task { await start() } }
    }

    func useCurrentConfiguration(reuseAnswers: Bool) {
        guard current, !busy, !denied, let omr else { return }
        do {
            // Explicit resolution preserves the previous question-set draft.
            try NativeServiceDraftDisk.backup(slot: owner.slot, resource: draft.resource)
            let oldAnswers = answers
            var next = NativeServiceDraft(slot: owner.slot, resource: draft.resource)
            let nextAnswers = (0..<omr.questionCount).map { index in
                reuseAnswers && oldAnswers.indices.contains(index) ? oldAnswers[index] : ""
            }
            next.fields = try fields(dirty: true, answers: nextAnswers)
            try NativeServiceDraftDisk.save(next)
            answers = nextAnswers
            draft = next; draftLoaded = true; dirty = true; configurationChanged = false; draftError = nil
            notice = reuseAnswers ? "이전 답을 옮겼습니다. 바뀐 문항과 답을 확인한 뒤 제출해 주세요." : "이전 원본을 백업했습니다. 현재 답안지에 새로 작성해 주세요."
        } catch {
            draftError = "원본 백업 또는 새 답안 저장에 실패했습니다. 기존 원본은 유지되며 제출하지 않았습니다."
        }
    }

    func submit() async {
        guard canSubmit else { return }
        let ticket = UUID(); operation = ticket; busy = true; errorMessage = nil; notice = nil
        let sent = answers.map(AcademyAssignmentConfiguration.normalizedAnswer)
        let sentConfiguration = fingerprint(response.week)
        defer { if accepts(ticket) { busy = false } }
        do {
            let latest = try await ServerAPI.academyWeek(response.week.id, authorization: owner.authorization)
            guard accepts(ticket) else { return }
            install(latest)
            guard !denied, !configurationChanged, draftError == nil, omr != nil,
                  fingerprint(latest.week) == sentConfiguration else { return }
            // A previous response may have been lost after the server saved it.
            // Confirm the same receipt before issuing a repeat mutation.
            if let previous = matchingReceipt(latest.submission, answers: sent) {
                confirm(previous); return
            }
            guard !deadlinePassed else { errorMessage = "과제 제출 마감 시간이 지났습니다. 입력한 답은 이 기기에 보관했습니다."; return }
            if let validationMessage { errorMessage = validationMessage; return }
            guard accepts(ticket) else { return }
            do {
                let result = try await ServerAPI.submitAcademyAssignment(weekID: latest.week.id,
                    answers: sent, authorization: owner.authorization)
                guard accepts(ticket) else { return }
                if let configuration = latest.week.assignmentOmr?.configuredAt,
                   result.answerKeyConfiguredAt != configuration {
                    throw ServerAPIError(message: "제출 중 선생님이 답안지를 변경했습니다. 최신 과제와 제출 내역을 확인해 주세요.", code: "ACADEMY_OMR_CONFIGURATION_CHANGED")
                }
                confirm(result)
            } catch {
                guard accepts(ticket) else { return }
                let originalError = error
                if [401, 403, 404].contains((error as? ServerAPIError)?.statusCode ?? 0) { handle(error); return }
                // Reconciliation is read-only. A failed POST is never blindly
                // replayed, and a different device's answers stay untouched.
                do {
                    let latest = try await ServerAPI.academyWeek(response.week.id, authorization: owner.authorization)
                    guard accepts(ticket) else { return }
                    install(latest)
                    if fingerprint(latest.week) == sentConfiguration,
                       let result = matchingReceipt(latest.submission, answers: sent) { confirm(result); return }
                } catch {
                    guard accepts(ticket) else { return }
                    if [401, 403, 404].contains((error as? ServerAPIError)?.statusCode ?? 0) { handle(error); return }
                }
                handle(originalError)
            }
        } catch {
            guard accepts(ticket) else { return }
            handle(error)
        }
    }

    func retire() {
        active = false; operation = UUID(); busy = false
        answers = []; receipt = nil
    }

    private var current: Bool { active && owner.isCurrent(in: store) }
    private func accepts(_ ticket: UUID) -> Bool { current && operation == ticket }

    private func install(_ latest: ServerAPI.AcademyWeekResponse) {
        guard latest.week.id == response.week.id else {
            errorMessage = "다른 과제 응답을 받아 적용하지 않았습니다."; return
        }
        response = latest; denied = false
        serverClock = Self.date(latest.serverTime); receivedAt = ProcessInfo.processInfo.systemUptime
        receipt = latest.submission.flatMap { $0.isValid && ($0.weekId == nil || $0.weekId == latest.week.id) ? $0 : nil }
        if latest.submission != nil && receipt == nil { errorMessage = "서버 제출 내역의 형식을 확인하지 못했습니다. 다시 불러와 주세요." }
        guard let omr else { errorMessage = "이 과제의 온라인 답안지가 종료되었거나 형식을 확인할 수 없습니다."; return }
        guard draftLoaded else { return }
        if draft.fields["configuration"] != nil && draft.fields["configuration"] != fingerprint(latest.week) && dirty {
            configurationChanged = true; return
        }
        if !dirty {
            answers = receipt?.answers.count == omr.questionCount ? (receipt?.answers ?? []) : Array(repeating: "", count: omr.questionCount)
            configurationChanged = false
        } else if answers.count != omr.questionCount { configurationChanged = true }
        if !configurationChanged { persist() }
    }

    private func matchingReceipt(_ value: AcademyAssignmentSubmission?, answers: [String]) -> AcademyAssignmentSubmission? {
        guard let value, value.isValid, value.status == "SUBMITTED", value.weekId == response.week.id,
              response.week.assignmentOmr?.configuredAt == nil || value.answerKeyConfiguredAt == response.week.assignmentOmr?.configuredAt,
              value.answers.map(AcademyAssignmentConfiguration.normalizedAnswer) == answers else { return nil }
        return value
    }

    private func confirm(_ result: AcademyAssignmentSubmission) {
        receipt = result; response.submission = result; answers = result.answers; dirty = false
        persist()
        notice = draftError == nil ? "서버에서 제출과 채점을 확인했습니다." : "서버 제출은 완료됐지만 이 기기의 보관 상태 갱신에 실패했습니다. 다시 불러오면 서버 내역을 확인합니다."
    }

    private func fields(dirty: Bool, answers value: [String]? = nil) throws -> [String: String] {
        let encoded = try JSONEncoder().encode(value ?? answers)
        guard let text = String(data: encoded, encoding: .utf8) else { throw CocoaError(.coderInvalidValue) }
        return ["answers": text, "configuration": fingerprint(response.week), "dirty": dirty ? "true" : "false"]
    }

    private func persist() {
        guard current, draftLoaded, !configurationChanged else { return }
        do {
            var updated = draft; updated.fields = try fields(dirty: dirty)
            try NativeServiceDraftDisk.save(updated)
            draft = updated; draftError = nil
        } catch { draftError = "답안을 이 기기에 저장하지 못했습니다. 화면의 입력은 유지했습니다. 저장 재시도 후 제출해 주세요." }
    }

    private func fingerprint(_ week: ServerAPI.AcademyWeek) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let sections = (try? encoder.encode(week.assignmentOmr?.sections)) ?? Data()
        let files = (try? encoder.encode(week.files)) ?? Data()
        return NativeServiceDraft.fingerprint([
            "week": week.id, "count": String(week.assignmentOmr?.questionCount ?? 0),
            "configuredAt": week.assignmentOmr?.configuredAt ?? "", "sections": sections.base64EncodedString(),
            "title": week.assignmentTitle, "instructions": week.assignmentInstructions, "files": files.base64EncodedString()
        ])
    }

    private func handle(_ error: Error) {
        if [401, 403, 404].contains((error as? ServerAPIError)?.statusCode ?? 0) {
            denied = true; answers = []; receipt = nil
            errorMessage = "이 과제를 열 권한이 없거나 과제가 삭제되었습니다. 학원 화면에서 소속과 접근 권한을 확인해 주세요."
        } else {
            errorMessage = ((error as? ServerAPIError)?.errorDescription ?? error.localizedDescription) + " 입력한 답안은 보관했습니다."
        }
    }

    static func date(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
