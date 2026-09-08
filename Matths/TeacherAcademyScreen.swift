import Foundation
import SwiftUI
import UIKit

@MainActor
final class TeacherAcademyScreenModel: ObservableObject {
    // Immutable mounted-account owner: child panels may queue Tasks, but an old
    // model is never rebound to the next account before those Tasks execute.
    private let accountOwner: AccountRequestOwner?
    private weak var accountStore: AppStore?
    init(store: AppStore) {
        accountOwner = AccountRequestOwner(store: store)
        accountStore = store
    }
    private var isMountedOwnerCurrent: Bool {
        guard let accountOwner, let accountStore else { return false }
        return accountOwner.isCurrent(in: accountStore)
            && accountStore.authProvider == "server"
            && accountStore.serverProfile?.role?.lowercased() == "teacher"
    }
    // End mounted-account owner
    enum Section: String, CaseIterable, Identifiable {
        case overview = "현황"
        case requests = "승인 요청"
        case students = "학생"
        case attendance = "출결"
        case classwork = "과제"
        case forensics = "추적"
        case classes = "반"
        case staff = "선생님"
        case invites = "초대"
        case settings = "설정"
        var id: String { rawValue }
    }

    typealias AttendanceDraft = ServerAPI.TeacherAttendanceRecord.Value

    @Published var dashboard: ServerAPI.TeacherAcademyDashboard?
    @Published var setup: ServerAPI.TeacherAcademySetup?
    @Published var section: Section = TeacherAcademyScreenModel.initialSection
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var showsInviteComposer = false
    @Published var inviteLabel = "학생 초대"
    @Published var inviteClassID = ""
    @Published var inviteExpiryDays = 14
    @Published private(set) var inviteCreationSequence: UInt = 0
    @Published var inviteMaxUsesText = "30"
    var inviteMaxUses: Int {
        get { Int(inviteMaxUsesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0 }
        set { inviteMaxUsesText = String(newValue) }
    }
    @Published var attendance: ServerAPI.TeacherAttendanceRoster?
    @Published var attendanceDateKey = TeacherAcademyScreenModel.kstDateKey(Date())
    @Published var attendanceClassID = ""
    @Published var attendanceDrafts: [String: AttendanceDraft] = [:]
    @Published var isAttendanceLoading = false
    @Published private(set) var attendanceConflicts: Set<String> = []

    private var generation = UUID()
    private var attendanceRequestID = UUID()
    private var attendanceBaseline: [String: AttendanceDraft] = [:]
    private var pendingAttendance: [String: (baseline: [String: AttendanceDraft], edited: [String: AttendanceDraft])] = [:]

    var hasAttendanceChanges: Bool {
        attendanceDrafts.mapValues { $0.normalized } != attendanceBaseline.mapValues { $0.normalized }
    }
    var attendanceMatchesSelection: Bool {
        guard let attendance else { return false }
        return attendance.dateKey == attendanceDateKey && (attendance.selectedClass?.id ?? "") == attendanceClassID
    }

    private static var initialSection: Section {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-teacherAttendanceFixture") {
            return .attendance
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherAnalyticsFixture") {
            return .overview
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherProfileFixture") {
            return .settings
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherForensicsFixture") {
            return .forensics
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherClassworkFixture") {
            return .classwork
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherStaffFixture") {
            return .staff
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherStudentsFixture") {
            return .students
        }
        if ProcessInfo.processInfo.arguments.contains("-teacherClassesFixture")
            || ProcessInfo.processInfo.arguments.contains("-teacherClassesEditorFixture")
            || ProcessInfo.processInfo.arguments.contains("-teacherClassTeachersFixture") {
            return .classes
        }
        #endif
        return .overview
    }

    func resetAndLoad() async {
        generation = UUID()
        attendanceRequestID = UUID()
        dashboard = nil
        setup = nil
        actionID = nil
        attendance = nil
        attendanceDrafts = [:]
        attendanceBaseline = [:]
        pendingAttendance = [:]
        attendanceConflicts = []
        attendanceClassID = ""
        isAttendanceLoading = false
        showsInviteComposer = false
        inviteLabel = "학생 초대"
        inviteClassID = ""
        inviteExpiryDays = 14
        inviteMaxUses = 30
        errorMessage = nil
        noticeMessage = nil
        await load()
    }

    func load() async {
        guard isMountedOwnerCurrent, let authorization = accountOwner?.authorization else { return }
        let requestGeneration = generation
        isLoading = dashboard == nil && setup == nil
        errorMessage = nil
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-teacherSetupFixture") {
                let value = try await ServerAPI.teacherAcademySetup(authorization: authorization)
                guard isMountedOwnerCurrent, requestGeneration == generation else { return }
                setup = value
                isLoading = false
                return
            }
            #endif
            let value = try await ServerAPI.teacherAcademyDashboard(authorization: authorization)
            guard isMountedOwnerCurrent, requestGeneration == generation else { return }
            install(value)
        } catch is CancellationError {
            return
        } catch let error as ServerAPIError where error.code == "ACADEMY_SETUP_REQUIRED" {
            guard isMountedOwnerCurrent, requestGeneration == generation else { return }
            do {
                let value = try await ServerAPI.teacherAcademySetup(authorization: authorization)
                guard isMountedOwnerCurrent, requestGeneration == generation else { return }
                if value.isReady {
                    let dashboard = try await ServerAPI.teacherAcademyDashboard(authorization: authorization)
                    guard isMountedOwnerCurrent, requestGeneration == generation else { return }
                    install(dashboard)
                } else {
                    setup = value
                }
            } catch {
                guard isMountedOwnerCurrent, requestGeneration == generation else { return }
                errorMessage = readable(error)
            }
        } catch {
            guard isMountedOwnerCurrent, requestGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation { isLoading = false }
    }

    func createAcademy(name: String) async -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(normalized.count) else {
            errorMessage = "학원 이름은 2자 이상 80자 이하로 입력해 주세요."
            return false
        }
        return await performSetup(id: "setup-create", notice: "학원 등록 요청을 보냈습니다.") { authorization in
            try await ServerAPI.createTeacherAcademy(name: normalized, authorization: authorization)
        }
    }

    func requestAcademyJoin(academyID: String) async -> Bool {
        guard !academyID.isEmpty else {
            errorMessage = "참여할 학원을 선택해 주세요."
            return false
        }
        return await performSetup(id: "setup-join", notice: "학원 참여 요청을 보냈습니다.") { authorization in
            try await ServerAPI.requestTeacherAcademyJoin(academyID: academyID, authorization: authorization)
        }
    }

    func cancelAcademyJoin() async -> Bool {
        await performSetup(id: "setup-cancel", notice: "학원 참여 요청을 취소했습니다.") { authorization in
            try await ServerAPI.cancelTeacherAcademyJoin(authorization: authorization)
        }
    }

    func updateAcademyProfileImage(jpegData: Data) async {
        await perform(id: "academy-profile-upload", notice: "학원 대표 사진을 저장했습니다.") { authorization in
            try await ServerAPI.updateTeacherAcademyProfileImage(jpegData: jpegData, authorization: authorization)
        }
    }

    func removeAcademyProfileImage() async {
        await perform(id: "academy-profile-remove", notice: "학원 대표 사진을 기본 이미지로 되돌렸습니다.") { authorization in
            try await ServerAPI.removeTeacherAcademyProfileImage(authorization: authorization)
        }
    }

    func review(_ membership: ServerAPI.TeacherAcademyMembership, approve: Bool) async {
        await perform(id: membership.id, notice: approve ? "학생을 승인했습니다." : "승인 요청을 거절했습니다.") { authorization in
            try await ServerAPI.reviewAcademyStudent(membershipID: membership.id, approve: approve, authorization: authorization)
        }
    }

    func assign(_ membership: ServerAPI.TeacherAcademyMembership, classID: String?) async {
        await perform(id: membership.id, notice: classID == nil ? "반 배정을 해제했습니다." : "반을 배정했습니다.") { authorization in
            try await ServerAPI.assignAcademyStudent(membershipID: membership.id, classID: classID, authorization: authorization)
        }
    }

    func removeStudent(_ membership: ServerAPI.TeacherAcademyMembership) async {
        await perform(id: membership.id, notice: "학생을 학원 명단에서 제외했습니다.") { authorization in
            try await ServerAPI.removeAcademyStudent(membershipID: membership.id, authorization: authorization)
        }
    }

    var inviteDraft: AcademyInviteDraft {
        .init(label: inviteLabel, classID: inviteClassID, expiryDays: inviteExpiryDays, maxUses: inviteMaxUses)
    }
    var hasInviteDraftChanges: Bool { inviteDraft != AcademyInviteDraft() }
    var canUseInvites: Bool { isMountedOwnerCurrent && dashboard != nil }

    func openInviteComposer() {
        guard isMountedOwnerCurrent, actionID == nil else { return }
        errorMessage = nil
        showsInviteComposer = true
    }

    func discardInviteDraft() {
        guard actionID == nil else { return }
        inviteLabel = "학생 초대"; inviteClassID = ""; inviteExpiryDays = 14; inviteMaxUses = 30
        showsInviteComposer = false
    }

    func createInvite() async {
        let draft = inviteDraft
        if let message = draft.validationMessage { errorMessage = message; return }
        let saved = await perform(id: "new-invite", notice: "새 초대 코드를 만들었습니다.") { authorization in
            try await ServerAPI.createAcademyInvite(
                label: draft.normalizedLabel,
                classID: draft.classID.isEmpty ? nil : draft.classID,
                expiryDays: draft.expiryDays, maxUses: draft.maxUses, authorization: authorization)
        }
        if saved {
            inviteLabel = "학생 초대"
            inviteClassID = ""
            inviteExpiryDays = 14
            inviteMaxUses = 30
            showsInviteComposer = false
            section = .invites
            inviteCreationSequence &+= 1
        }
    }

    func revoke(_ invite: ServerAPI.TeacherAcademyInvite) async {
        await perform(id: invite.id, notice: "초대 코드를 회수했습니다.") { authorization in
            try await ServerAPI.revokeAcademyInvite(invite.id, authorization: authorization)
        }
    }

    func reviewStaff(_ staff: ServerAPI.TeacherAcademyStaff, approve: Bool) async {
        await perform(
            id: staff.id,
            notice: approve ? "선생님 참여 요청을 승인했습니다." : "선생님 참여 요청을 거절했습니다."
        ) { authorization in
            try await ServerAPI.reviewAcademyStaff(staffID: staff.id, approve: approve, authorization: authorization)
        }
    }

    func revokeStaff(_ staff: ServerAPI.TeacherAcademyStaff) async {
        await perform(id: staff.id, notice: "선생님의 학원 접근 권한을 해제했습니다.") { authorization in
            try await ServerAPI.revokeAcademyStaff(staff.id, authorization: authorization)
        }
    }

    func saveClass(classID: String?, draft: ServerAPI.TeacherAcademyClassDraft) async -> Bool {
        let creating = classID == nil
        return await perform(
            id: classID.map { "class-\($0)" } ?? "class-new",
            notice: creating ? "새 반을 만들었습니다." : "반 일정과 출결 방식을 저장했습니다."
        ) { authorization in
            if let classID {
                return try await ServerAPI.updateTeacherAcademyClass(classID: classID, draft: draft, authorization: authorization)
            }
            return try await ServerAPI.createTeacherAcademyClass(draft, authorization: authorization)
        }
    }

    func archiveClass(_ academyClass: ServerAPI.AcademyClassSummary) async {
        await perform(id: "class-\(academyClass.id)", notice: "\(academyClass.name) 반을 보관했습니다.") { authorization in
            try await ServerAPI.archiveTeacherAcademyClass(academyClass.id, authorization: authorization)
        }
    }

    func restoreClass(_ academyClass: ServerAPI.AcademyClassSummary) async {
        await perform(id: "class-\(academyClass.id)", notice: "\(academyClass.name) 반을 복구했습니다.") { authorization in
            try await ServerAPI.restoreTeacherAcademyClass(academyClass.id, authorization: authorization)
        }
    }

    func addClassCoTeacher(classID: String, teacherUserID: String) async -> Bool {
        return await perform(id: "class-\(classID)", notice: "공동 담당 선생님을 추가했습니다.") { authorization in
            try await ServerAPI.addTeacherAcademyClassCoTeacher(
                classID: classID, teacherUserID: teacherUserID, authorization: authorization)
        }
    }

    func removeClassCoTeacher(classID: String, teacherUserID: String) async {
        await perform(id: "class-\(classID)", notice: "공동 담당 선생님을 해제했습니다.") { authorization in
            try await ServerAPI.removeTeacherAcademyClassCoTeacher(
                classID: classID, teacherUserID: teacherUserID, authorization: authorization)
        }
    }

    func transferClassHomeroom(
        classID: String, teacherUserID: String, keepPreviousAsCoTeacher: Bool
    ) async -> Bool {
        return await perform(id: "class-\(classID)", notice: "담임 선생님을 이전했습니다.") { authorization in
            try await ServerAPI.transferTeacherAcademyClassHomeroom(
                classID: classID,
                teacherUserID: teacherUserID,
                keepPreviousAsCoTeacher: keepPreviousAsCoTeacher, authorization: authorization)
        }
    }

    func loadAttendance() async {
        guard isMountedOwnerCurrent, let authorization = accountOwner?.authorization else { return }
        guard section == .attendance else { return }
        stashAttendanceDraft()
        let requestGeneration = generation
        let requestID = UUID()
        attendanceRequestID = requestID
        let account = DataScope.slot
        let requestedDateKey = attendanceDateKey
        let requestedClassID = attendanceClassID
        isAttendanceLoading = true
        errorMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyAttendance(
                dateKey: requestedDateKey,
                classID: requestedClassID.isEmpty ? nil : requestedClassID,
                authorization: authorization)
            guard requestGeneration == generation, requestID == attendanceRequestID,
                  account == DataScope.slot, ServerAPI.isCurrentAuthorization(authorization), section == .attendance,
                  attendanceDateKey == requestedDateKey,
                  attendanceClassID == requestedClassID else { return }
            installAttendance(value)
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, requestID == attendanceRequestID,
                  account == DataScope.slot, section == .attendance,
                  attendanceDateKey == requestedDateKey,
                  attendanceClassID == requestedClassID else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation, requestID == attendanceRequestID, section == .attendance,
           attendanceDateKey == requestedDateKey,
           attendanceClassID == requestedClassID {
            isAttendanceLoading = false
        }
    }

    func moveAttendanceDay(_ offset: Int) {
        guard let date = Self.date(from: attendanceDateKey),
              let moved = Self.kstCalendar.date(byAdding: .day, value: offset, to: date)
        else { return }
        attendanceDateKey = Self.kstDateKey(moved)
    }

    func jumpAttendanceToToday() {
        attendanceDateKey = Self.kstDateKey(Date())
    }

    func updateAttendanceStatus(entryID: String, status: String) {
        var drafts = attendanceDrafts
        let current = drafts[entryID] ?? AttendanceDraft(status: "", note: "")
        drafts[entryID] = AttendanceDraft(status: status, note: current.note)
        attendanceDrafts = drafts
        attendanceConflicts.remove(entryID)
    }

    func updateAttendanceNote(entryID: String, note: String) {
        var drafts = attendanceDrafts
        let current = drafts[entryID] ?? AttendanceDraft(status: "", note: "")
        drafts[entryID] = AttendanceDraft(status: current.status, note: note)
        attendanceDrafts = drafts
        attendanceConflicts.remove(entryID)
    }

    func saveAttendance() async {
        guard isMountedOwnerCurrent, let authorization = accountOwner?.authorization else { return }
        guard let attendance, actionID == nil, attendanceMatchesSelection,
              !isAttendanceLoading, attendanceConflicts.isEmpty else { return }
        let requestGeneration = generation
        let account = DataScope.slot
        let requestedKey = attendanceKey(attendance)
        stashAttendanceDraft()
        actionID = "attendance-save"
        defer { if generation == requestGeneration, actionID == "attendance-save" { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let records = try ServerAPI.changedTeacherAttendanceRecords(
                roster: attendance, baseline: attendanceBaseline, edited: attendanceDrafts)
            guard !records.isEmpty else { return }
            let value = try await ServerAPI.saveTeacherAcademyAttendance(
                dateKey: attendance.dateKey,
                classID: attendance.selectedClass?.id,
                sessionID: attendance.session?.id,
                records: records, authorization: authorization)
            guard generation == requestGeneration, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            pendingAttendance.removeValue(forKey: requestedKey)
            guard attendanceDateKey == attendance.dateKey,
                  attendanceClassID == (attendance.selectedClass?.id ?? ""),
                  self.attendance.map(attendanceKey) == requestedKey else { return }
            installAttendance(value, discardingDraft: true)
            noticeMessage = "출결을 저장했습니다."
        } catch {
            guard generation == requestGeneration, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            if (error as? ServerAPIError)?.code == "ATTENDANCE_WRITE_CONFLICT",
               attendanceDateKey == attendance.dateKey,
               attendanceClassID == (attendance.selectedClass?.id ?? "") {
                // Refresh the comparison baseline, but keep every edited value
                // and mark collisions until the teacher explicitly resolves it.
                if let latest = try? await ServerAPI.teacherAcademyAttendance(
                    dateKey: attendance.dateKey, classID: attendance.selectedClass?.id, authorization: authorization),
                   generation == requestGeneration, account == DataScope.slot,
                   ServerAPI.isCurrentAuthorization(authorization),
                   attendanceDateKey == attendance.dateKey,
                   attendanceClassID == (attendance.selectedClass?.id ?? "") {
                    installAttendance(latest)
                }
            }
            guard generation == requestGeneration, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return }
            guard attendanceDateKey == attendance.dateKey,
                  attendanceClassID == (attendance.selectedClass?.id ?? "") else { return }
            errorMessage = readable(error)
        }
    }

    func regenerateAttendanceCode() async {
        guard isMountedOwnerCurrent, let authorization = accountOwner?.authorization else { return }
        guard let sessionID = attendance?.session?.id, actionID == nil else { return }
        let requestGeneration = generation
        let account = DataScope.slot
        actionID = "attendance-code"
        errorMessage = nil
        noticeMessage = nil
        do {
            let session = try await ServerAPI.regenerateTeacherAttendanceCode(sessionID, authorization: authorization)
            guard generation == requestGeneration, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization), attendance?.session?.id == sessionID else { return }
            attendance?.session = session
            noticeMessage = "새 출석 코드를 만들었습니다."
        } catch {
            guard generation == requestGeneration, account == DataScope.slot else { return }
            errorMessage = readable(error)
        }
        actionID = nil
    }

    @discardableResult private func perform(
        id: String,
        notice: String,
        operation: (ServerAPI.AuthorizationSnapshot) async throws -> ServerAPI.TeacherAcademyDashboard
    ) async -> Bool {
        guard isMountedOwnerCurrent, let authorization = accountOwner?.authorization, actionID == nil else { return false }
        let requestGeneration = generation
        let account = DataScope.slot
        actionID = id
        defer { if generation == requestGeneration { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let response = try await operation(authorization)
            guard isMountedOwnerCurrent, generation == requestGeneration, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return false }
            install(response)
            noticeMessage = notice
            return true
        } catch {
            guard isMountedOwnerCurrent, generation == requestGeneration, account == DataScope.slot else { return false }
            errorMessage = readable(error)
        }
        return false
    }

    private func performSetup(
        id: String,
        notice: String,
        operation: (ServerAPI.AuthorizationSnapshot) async throws -> ServerAPI.TeacherAcademySetup
    ) async -> Bool {
        guard isMountedOwnerCurrent, let authorization = accountOwner?.authorization, actionID == nil else { return false }
        let requestGeneration = generation
        let account = DataScope.slot
        actionID = id
        errorMessage = nil
        noticeMessage = nil
        do {
            let response = try await operation(authorization)
            guard isMountedOwnerCurrent, generation == requestGeneration, account == DataScope.slot,
                  ServerAPI.isCurrentAuthorization(authorization) else { return false }
            setup = response
            noticeMessage = notice
            actionID = nil
            return true
        } catch {
            guard isMountedOwnerCurrent, generation == requestGeneration, account == DataScope.slot else { return false }
            errorMessage = readable(error)
            actionID = nil
            return false
        }
    }

    private func install(_ value: ServerAPI.TeacherAcademyDashboard) {
        dashboard = value
        setup = nil
        if value.requests.isEmpty && section == .requests { section = .students }
        if !value.isOwner && section == .settings { section = .overview }
    }

    private func installAttendance(_ value: ServerAPI.TeacherAttendanceRoster, discardingDraft: Bool = false) {
        if !discardingDraft { stashAttendanceDraft() }
        attendance = value
        attendanceDateKey = value.dateKey
        attendanceClassID = value.selectedClass?.id ?? ""
        let server = Dictionary(value.roster.map { entry in
            (
                entry.id,
                AttendanceDraft(
                    status: entry.attendance?.status ?? "",
                    note: entry.attendance?.note ?? "")
            )
        }, uniquingKeysWith: { _, last in last })
        if !discardingDraft, let cached = pendingAttendance[attendanceKey(value)] {
            let merged = StaffDraftMerge(server: server, baseline: cached.baseline, edited: cached.edited)
            attendanceDrafts = merged.values
            attendanceConflicts = merged.conflicts
        } else {
            attendanceDrafts = server
            attendanceConflicts = []
        }
        attendanceBaseline = server
    }

    private func attendanceKey(_ roster: ServerAPI.TeacherAttendanceRoster) -> String {
        [roster.dateKey, roster.selectedClass?.id ?? "", roster.session?.id ?? ""].joined(separator: "|")
    }

    private func stashAttendanceDraft() {
        guard let attendance else { return }
        let key = attendanceKey(attendance)
        if hasAttendanceChanges { pendingAttendance[key] = (attendanceBaseline, attendanceDrafts) }
        else { pendingAttendance.removeValue(forKey: key) }
    }

    func useServerAttendance() {
        attendanceDrafts = attendanceBaseline
        attendanceConflicts = []
        if let attendance { pendingAttendance.removeValue(forKey: attendanceKey(attendance)) }
    }

    func confirmLocalAttendance() { attendanceConflicts = [] }

    func preserveAttendanceDraft() { stashAttendanceDraft() }

    private static var kstCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private static var dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = kstCalendar
        formatter.timeZone = kstCalendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func kstDateKey(_ date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    private static func date(from key: String) -> Date? {
        dateKeyFormatter.date(from: key)
    }

    private func readable(_ error: Error) -> String {
        if (error as? ServerAPIError)?.statusCode == 403 {
            generation = UUID(); attendanceRequestID = UUID()
            dashboard = nil; setup = nil; attendance = nil; actionID = nil; isLoading = false
            attendanceDrafts = [:]; attendanceBaseline = [:]; pendingAttendance = [:]
            attendanceConflicts = []; showsInviteComposer = false; isAttendanceLoading = false
        }
        return (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 교사 모바일 작업대. 반복 빈도가 높은 승인·반 배정·출결·과제·초대를 네이티브에서
/// 빠르게 끝내고, 원장 전용 반 설정은 인증된 전체 관리 포털로 이어진다.
struct TeacherAcademyScreen: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        AccountScopedTeacherAcademyScreen(store: store)
            .id(String(describing: store.captureAccountSessionBoundary()) + "#" + (store.serverProfile?.role ?? ""))
    }
}

private struct AccountScopedTeacherAcademyScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: TeacherAcademyScreenModel
    init(store: AppStore) {
        _model = StateObject(wrappedValue: TeacherAcademyScreenModel(store: store))
    }
    @State private var removingStudent: ServerAPI.TeacherAcademyMembership?
    @State private var focusedStudentID: String?
    @State private var showsAcademyPhotoPicker = false
    @State private var inviteFilter: AcademyInviteHistoryFilter = .all
    @State private var revokingInvite: ServerAPI.TeacherAcademyInvite?
    @State private var confirmsInviteDiscard = false
    @State private var visitedSections: Set<TeacherAcademyScreenModel.Section> = []
    @State private var lastSections: [TeacherWorkspaceArea: TeacherAcademyScreenModel.Section] = [:]

    private var area: TeacherWorkspaceArea { Self.area(for: model.section) }

    private static func area(for section: TeacherAcademyScreenModel.Section) -> TeacherWorkspaceArea {
        switch section {
        case .overview, .requests: .overview
        case .classes, .classwork: .classes
        case .students: .students
        case .attendance: .attendance
        case .forensics, .staff, .invites, .settings: .more
        }
    }

    private func selectArea(_ next: TeacherWorkspaceArea) {
        model.preserveAttendanceDraft()
        lastSections[area] = model.section
        let fallback: TeacherAcademyScreenModel.Section = switch next {
        case .overview: .overview
        case .classes: .classes
        case .students: .students
        case .attendance: .attendance
        case .more: .staff
        }
        model.section = lastSections[next] ?? fallback
    }

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { viewport in
            Group {
                if model.isLoading && model.dashboard == nil && model.setup == nil {
                    stateShell {
                        ProgressView().tint(Tokens.primary)
                        Text("학원 관리 정보를 불러오는 중입니다").font(.mHeading)
                    }
                } else if let dashboard = model.dashboard {
                    dashboardView(dashboard, viewport: viewport)
                } else if let setup = model.setup {
                    TeacherAcademySetupPanel(setup: setup, model: model)
                } else {
                    failureState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.paper)
        .onAppear { visitedSections.insert(model.section) }
        .onChange(of: model.section) { _, next in visitedSections.insert(next) }
        .onChange(of: model.inviteCreationSequence) { _, _ in inviteFilter = .all }
        .onChange(of: model.dashboard?.isOwner) { _, isOwner in
            if isOwner == false { visitedSections.remove(.settings); lastSections.removeValue(forKey: .more) }
        }
        .task { if model.dashboard == nil && model.setup == nil { await model.load() } }
        .task(id: "\(model.section.rawValue)|\(model.attendanceDateKey)|\(model.attendanceClassID)") {
            await model.loadAttendance()
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            visitedSections = []
            lastSections = [:]
            removingStudent = nil
            focusedStudentID = nil
            showsAcademyPhotoPicker = false
            revokingInvite = nil
            confirmsInviteDiscard = false
            inviteFilter = .all
            Task { await model.resetAndLoad() }
        }
        .compactHeightSheet(isPresented: $model.showsInviteComposer) {
            inviteComposer
        }
        .confirmationDialog("이 초대를 회수할까요?", isPresented: Binding(
            get: { revokingInvite != nil }, set: { if !$0 { revokingInvite = nil } }),
            titleVisibility: .visible, presenting: revokingInvite) { invite in
                Button("초대 회수", role: .destructive) {
                    revokingInvite = nil
                    Task { await model.revoke(invite) }
                }
                Button("유지", role: .cancel) { revokingInvite = nil }
            } message: { invite in
                Text("\(invite.label)의 코드와 링크를 더 이상 사용할 수 없게 됩니다. 이미 연결된 학생은 해제되지 않습니다.")
            }
        .compactHeightSheet(isPresented: $showsAcademyPhotoPicker) {
            ProfilePhotoCropPicker(
                onCancel: { showsAcademyPhotoPicker = false },
                onPick: { image in
                    showsAcademyPhotoPicker = false
                    guard let data = image.jpegData(compressionQuality: 0.84) else {
                        model.errorMessage = "선택한 사진을 처리하지 못했습니다. 다른 사진을 선택해 주세요."
                        return
                    }
                    Task { await model.updateAcademyProfileImage(jpegData: data) }
                })
                .ignoresSafeArea()
        }
        .confirmationDialog(
            "이 학생을 학원에서 제외할까요?",
            isPresented: Binding(
                get: { removingStudent != nil },
                set: { if !$0 { removingStudent = nil } }),
            titleVisibility: .visible,
            presenting: removingStudent
        ) { membership in
            Button("\(membership.student.name) 제외", role: .destructive) {
                removingStudent = nil
                Task { await model.removeStudent(membership) }
            }
            Button("취소", role: .cancel) { removingStudent = nil }
        } message: { _ in
            Text("반 배정이 해제되고 학생은 더 이상 학원 수업과 과제를 볼 수 없습니다.")
        }
    }

    @ViewBuilder
    private func dashboardView(
        _ dashboard: ServerAPI.TeacherAcademyDashboard,
        viewport: GeometryProxy
    ) -> some View {
        StaffWorkspaceContainer(
            title: "수업 관리", subtitle: dashboard.academy.name,
            destinations: TeacherWorkspaceArea.allCases.map {
                StaffWorkspaceDestination(id: $0.rawValue, title: $0.title, symbol: $0.symbol)
            }, selectedID: area.rawValue,
            onSelect: { if let next = TeacherWorkspaceArea(rawValue: $0) { selectArea(next) } }
        ) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack(spacing: Tokens.Space.s2) {
                    if compactLandscape {
                        Text(area.title).font(.mBodyB).foregroundStyle(Tokens.ink).fixedSize()
                        managementSectionPicker(dashboard).frame(maxWidth: 420)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(area.title).font(.mHeading).foregroundStyle(Tokens.ink)
                            Text(dashboard.academy.name).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                        }
                    }
                    Spacer()
                    if model.hasAttendanceChanges {
                        Button("출결 초안") { model.section = .attendance }.font(.mCaption)
                    }
                    if model.actionID != nil { ProgressView() }
                    Button { Task { await model.load() } } label: {
                        Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                    }.disabled(model.actionID != nil).accessibilityLabel("학원 정보 새로고침")
                }
                if !compactLandscape { managementSectionPicker(dashboard) }
                feedbackText
                // Keep each visited feature at a stable identity. A tab switch
                // must not discard search, selected student, file draft or scroll.
                ZStack(alignment: .topLeading) {
                    ForEach(availableSections(dashboard).filter { visitedSections.contains($0) || model.section == $0 }) { section in
                        sectionContent(section, dashboard: dashboard)
                            .environment(\.staffWorkspaceActive, model.section == section)
                            .opacity(model.section == section ? 1 : 0)
                            .allowsHitTesting(model.section == section)
                            .accessibilityHidden(model.section != section)
                            .zIndex(model.section == section ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.top, Tokens.Space.s2)
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: TeacherAcademyScreenModel.Section, dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        switch section {
        case .overview:
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack(spacing: Tokens.Space.s2) {
                    Button("승인 대기 \(dashboard.pendingCount)") { model.section = .requests }
                        .buttonStyle(.bordered)
                    Button("오늘 출결") { model.jumpAttendanceToToday(); model.section = .attendance }
                        .buttonStyle(.borderedProminent).tint(Tokens.actionPrimary)
                    Button("수업·과제") { model.section = .classwork }.buttonStyle(.bordered)
                }
                TeacherAnalyticsPanel(classes: dashboard.classes) { membershipID in
                    focusedStudentID = membershipID
                    model.section = .students
                }
            }
        case .requests: requestList(dashboard)
        case .students:
            TeacherStudentManagementPanel(initialMembershipID: focusedStudentID) { await model.load() }
        case .attendance: attendanceBoard(dashboard)
        case .classwork: TeacherClassworkPanel(classes: dashboard.classes).id(store.captureAccountSessionBoundary())
        case .forensics: TeacherAcademyForensicsPanel()
        case .classes: TeacherClassManagementPanel(dashboard: dashboard, model: model)
        case .staff: staffList(dashboard)
        case .invites: inviteList(dashboard)
        case .settings:
            TeacherAcademyProfilePanel(dashboard: dashboard, model: model, onChoosePhoto: { showsAcademyPhotoPicker = true })
        }
    }

    @ViewBuilder
    private func managementSectionPicker(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("관리 항목", selection: $model.section) {
                ForEach(availableSections(dashboard).filter { Self.area(for: $0) == area }) { section in
                    Text(sectionTitle(section, dashboard: dashboard)).tag(section)
                }
            }
            .pickerStyle(.menu)
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(model.actionID != nil)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: Tokens.Space.s1) {
                        ForEach(availableSections(dashboard).filter { Self.area(for: $0) == area }) { section in
                            Button {
                                model.section = section
                            } label: {
                                Text(sectionTitle(section, dashboard: dashboard))
                                    .font(.mCaption)
                                    .foregroundStyle(model.section == section ? Tokens.onBrand : Tokens.text2)
                                    .padding(.horizontal, Tokens.Space.s2)
                                    .frame(minHeight: 44)
                                    .background(
                                        model.section == section ? Tokens.actionPrimary : Tokens.paper2,
                                        in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(model.section == section ? .isSelected : [])
                            .id(section)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    proxy.scrollTo(model.section, anchor: .center)
                }
                .onChange(of: model.section) { _, section in
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(section, anchor: .center)
                    }
                }
            }
            .disabled(model.actionID != nil)
        }
    }

    private func requestList(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        listContainer {
            if dashboard.requests.isEmpty {
                emptyState("대기 중인 요청이 없습니다", "새 요청이 오면 여기서 바로 승인할 수 있습니다.")
            } else {
                ForEach(dashboard.requests) { membership in
                    personRow(membership) {
                        Button("거절", role: .destructive) {
                            Task { await model.review(membership, approve: false) }
                        }
                        .buttonStyle(.bordered)
                        .tint(Tokens.dangerInk)
                        Button("승인") { Task { await model.review(membership, approve: true) } }
                            .buttonStyle(.borderedProminent)
                            .tint(Tokens.actionPrimary)
                    }
                    .disabled(model.actionID != nil)
                }
            }
        }
    }

    private func attendanceBoard(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if !model.attendanceConflicts.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text("다른 작업자가 변경한 출결 \(model.attendanceConflicts.count)건과 초안이 다릅니다.")
                        .font(.mCaption).foregroundStyle(Tokens.warningInk)
                    HStack {
                        Button("서버 기록 사용") { model.useServerAttendance() }
                        Button("내 초안 확인·유지") { model.confirmLocalAttendance() }
                    }.buttonStyle(.bordered)
                }
            } else if model.hasAttendanceChanges {
                Text("저장하지 않은 출결이 있습니다. 반·날짜를 바꾸어도 이 작업공간의 초안을 유지합니다.")
                    .font(.mMicro).foregroundStyle(Tokens.warningInk)
            }
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        attendanceClassPicker(dashboard)
                        attendanceDateControl
                        attendanceSaveButton
                    }
                } else if compactLandscape {
                    HStack(spacing: Tokens.Space.s2) {
                        attendanceClassPicker(dashboard)
                        attendanceDateControl
                        attendanceSaveButton
                            .frame(width: 88)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: Tokens.Space.s2) {
                        attendanceClassPicker(dashboard)
                        attendanceDateControl
                        Spacer(minLength: 0)
                        attendanceSaveButton
                    }
                }
            }
            .disabled(model.actionID != nil)

            if model.isAttendanceLoading && !model.attendanceMatchesSelection {
                HStack(spacing: Tokens.Space.s2) {
                    ProgressView().tint(Tokens.primary)
                    Text("출결부를 불러오는 중입니다").font(.mCaption).foregroundStyle(Tokens.text2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let attendance = model.attendance, model.attendanceMatchesSelection {
                attendanceSummary(attendance)
                if attendance.roster.isEmpty {
                    emptyState("이 반에 출결 학생이 없습니다", "학생을 반에 배정하면 날짜별 출결부가 만들어집니다.")
                } else {
                    listContainer(refreshesAttendance: true) {
                        ForEach(attendance.roster) { entry in
                            attendanceRow(entry)
                        }
                        if attendance.truncated {
                            Label("학생이 많아 현재 출결부는 일부만 표시됩니다.", systemImage: "exclamationmark.triangle.fill")
                                .font(.mCaption).foregroundStyle(Tokens.warningInk)
                                .padding(Tokens.Space.s3)
                        }
                    }
                }
            } else if !model.isAttendanceLoading {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    emptyState("출결부를 열지 못했습니다", "반과 날짜를 확인한 뒤 다시 불러와 주세요.")
                    Button("출결부 다시 불러오기") { Task { await model.loadAttendance() } }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }

    private func attendanceClassPicker(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
                Picker("출결 반", selection: $model.attendanceClassID) {
                    ForEach(dashboard.classes) { academyClass in
                        Text(academyClass.name).lineLimit(1).tag(academyClass.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                // 날짜 이동과 저장 버튼이 같은 줄에 있어도 선택한 반 이름이 한 글자씩
                // 세로로 무너지지 않도록 iPhone 가로에서는 식별 가능한 폭을 선점한다.
                .frame(width: compactLandscape ? 144 : nil, alignment: .leading)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 180, alignment: .leading)
                .layoutPriority(1)
                .accessibilityLabel("출결을 기록할 반")
    }

    private var attendanceDateControl: some View {
                HStack(spacing: 0) {
                    Button { model.moveAttendanceDay(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("이전 날짜")
                    Button { model.jumpAttendanceToToday() } label: {
                        Text(attendanceDateLabel(model.attendanceDateKey))
                            .font(.mCaption)
                            .lineLimit(1)
                            .frame(minWidth: compactLandscape ? 72 : 92, minHeight: 44)
                    }
                    .accessibilityLabel("오늘 출결로 이동")
                    Button { model.moveAttendanceDay(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("다음 날짜")
                }
                .foregroundStyle(Tokens.ink)
                .background(Tokens.paper2,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    private var attendanceSaveButton: some View {
                Button("저장") { Task { await model.saveAttendance() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.actionID != nil || model.isAttendanceLoading || !model.attendanceMatchesSelection
                              || !model.attendanceConflicts.isEmpty || !model.hasAttendanceChanges
                              || model.attendance?.roster.isEmpty != false)
                    .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
    }

    private func attendanceSummary(_ attendance: ServerAPI.TeacherAttendanceRoster) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Tokens.Space.s2)], spacing: Tokens.Space.s2) {
                    attendanceMetric("전체", attendance.counts.TOTAL, Tokens.ink)
                    attendanceMetric("출석", attendance.counts.PRESENT, Tokens.successInk)
                    attendanceMetric("지각", attendance.counts.LATE, Tokens.warningInk)
                    attendanceMetric("결석", attendance.counts.ABSENT, Tokens.dangerInk)
                    attendanceMetric("미기록", attendance.counts.UNRECORDED, Tokens.text2)
                }
            } else {
                HStack(spacing: Tokens.Space.s2) {
                    attendanceMetric("전체", attendance.counts.TOTAL, Tokens.ink)
                    attendanceMetric("출석", attendance.counts.PRESENT, Tokens.successInk)
                    attendanceMetric("지각", attendance.counts.LATE, Tokens.warningInk)
                    attendanceMetric("결석", attendance.counts.ABSENT, Tokens.dangerInk)
                    attendanceMetric("미기록", attendance.counts.UNRECORDED, Tokens.text2)
                }
            }
            if let session = attendance.session {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            HStack(spacing: Tokens.Space.s2) {
                                attendanceSessionIcon(session)
                                Text(attendanceSessionLabel(session.state))
                                    .font(.mCaption).foregroundStyle(Tokens.text2)
                            }
                            attendanceSessionControls(session)
                        }
                    } else {
                        HStack(spacing: Tokens.Space.s2) {
                            attendanceSessionIcon(session)
                            attendanceSessionControls(session)
                            Spacer(minLength: 0)
                            Text(attendanceSessionLabel(session.state))
                                .font(.mMicro).foregroundStyle(Tokens.text2)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.s3)
                .padding(.vertical, Tokens.Space.s2)
                .background(Tokens.primarySoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            }
        }
    }

    private func attendanceSessionIcon(_ session: ServerAPI.TeacherAttendanceSession) -> some View {
        Image(systemName: session.attendanceMode == "SELF_CODE"
              ? "number.square.fill" : "person.crop.circle.badge.checkmark")
            .foregroundStyle(Tokens.primary)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func attendanceSessionControls(_ session: ServerAPI.TeacherAttendanceSession) -> some View {
        if let code = session.code, !code.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text("학생 출석 코드").font(.mMicro).foregroundStyle(Tokens.text3)
                Text(code).font(.mHeading.monospacedDigit()).foregroundStyle(Tokens.ink)
            }
            ShareLink(item: "Matths 출석 코드: \(code)") {
                Label("공유", systemImage: "square.and.arrow.up")
                    .font(.mCaption).frame(minHeight: 44)
            }
            Button("새 코드") { Task { await model.regenerateAttendanceCode() } }
                .font(.mCaption)
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(model.actionID != nil || ["CLOSED", "CANCELED"].contains(session.state))
        } else {
            Text(session.attendanceMode == "MANUAL" ? "선생님 수동 출결" : "출석 코드 준비 중")
                .font(.mCaption).foregroundStyle(Tokens.text2)
        }
    }

    private func attendanceMetric(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text("\(value)").font(.mBodyB.monospacedDigit()).foregroundStyle(color)
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.s1)
        .background(Tokens.paper2,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func attendanceRow(_ entry: ServerAPI.TeacherAttendanceEntry) -> some View {
        let draft = model.attendanceDrafts[entry.id] ?? .init(status: "", note: "")
        Group {
            if compactLandscape {
                HStack(spacing: Tokens.Space.s2) {
                    attendanceStudent(entry.student)
                        .frame(width: 120, alignment: .leading)
                    attendanceNoteField(entry.id)
                    attendanceStatusMenu(entry.id, status: draft.status)
                }
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    HStack(spacing: Tokens.Space.s2) {
                        attendanceStudent(entry.student)
                        Spacer(minLength: 0)
                        attendanceStatusMenu(entry.id, status: draft.status)
                    }
                    attendanceNoteField(entry.id)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.s3)
        .padding(.vertical, Tokens.Space.s2)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .disabled(model.actionID != nil)
    }

    private func attendanceStudent(_ student: ServerAPI.AcademyPerson) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(student.name).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
            Text(studentDetail(student)).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
        }
    }

    private func attendanceNoteField(_ entryID: String) -> some View {
        TextField("메모(선택)", text: Binding(
            get: { model.attendanceDrafts[entryID]?.note ?? "" },
            set: { model.updateAttendanceNote(entryID: entryID, note: $0) }
        ))
        .textFieldStyle(.plain)
        .font(.mCaption)
        .foregroundStyle(Tokens.ink)
        .padding(.horizontal, Tokens.Space.s2)
        .frame(minHeight: 44)
        .background(Tokens.paper2,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityLabel("출결 메모")
    }

    private func attendanceStatusMenu(_ entryID: String, status: String) -> some View {
        Menu {
            ForEach(["PRESENT", "LATE", "ABSENT", "EXCUSED", ""], id: \.self) { option in
                Button {
                    model.updateAttendanceStatus(entryID: entryID, status: option)
                } label: {
                    if option == status {
                        Label(attendanceStatusLabel(option), systemImage: "checkmark")
                    } else {
                        Text(attendanceStatusLabel(option))
                    }
                }
            }
        } label: {
            Text(attendanceStatusLabel(status))
                .font(.mCaption)
                .foregroundStyle(attendanceStatusInk(status))
                .frame(minWidth: 76, minHeight: 44)
                .background(attendanceStatusBackground(status),
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        }
        .accessibilityLabel("출결 상태, \(attendanceStatusLabel(status))")
    }

    private func inviteList(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Button { model.openInviteComposer() } label: {
                Label("새 초대 만들기", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.actionID != nil || !model.canUseInvites)
            HStack {
                Text("최근 초대 \(dashboard.invites.count)개").font(.mCaption).foregroundStyle(Tokens.text2)
                Spacer()
                Picker("초대 이력", selection: $inviteFilter) {
                    ForEach(AcademyInviteHistoryFilter.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
            }
            listContainer {
                let invites = dashboard.invites.filter { inviteFilter.includes($0.displayState) }
                if invites.isEmpty {
                    emptyState("표시할 초대가 없습니다", inviteFilter == .all ? "새 초대를 만들어 학생에게 전달하세요." : "다른 이력 필터를 선택해 보세요.")
                } else {
                    ForEach(invites) { invite in inviteRow(invite) }
                }
            }
            .id("invite-history-\(model.inviteCreationSequence)")
        }
    }

    private func inviteRow(_ invite: ServerAPI.TeacherAcademyInvite) -> some View {
        let url = AcademyInvitePresentation.link(token: invite.token, base: ServerAPI.baseURL)
        let shareText = ["Matths 학원 초대: \(invite.label)", url?.absoluteString, "초대 코드: \(invite.code)"]
            .compactMap { $0 }.joined(separator: "\n")
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .top) {
                Text(invite.label).font(.mBodyB).foregroundStyle(Tokens.ink)
                Spacer(minLength: Tokens.Space.s2)
                Text(AcademyInvitePresentation.stateLabel(invite.displayState))
                    .font(.mMicro).foregroundStyle(invite.displayState == "ACTIVE" ? Tokens.successInk : Tokens.text2)
            }
            Text(invite.code).font(.mBodyB.monospaced()).foregroundStyle(Tokens.primary).textSelection(.enabled)
            Text("\(invite.useCount)/\(invite.maxUses)회 사용 · \(invite.academyClass?.name ?? "반 미지정")")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Text(AcademyInvitePresentation.expirationLabel(invite.expiresAt))
                .font(.mMicro).foregroundStyle(Tokens.text3)
            if url == nil {
                Text("링크 정보가 없어 코드로 초대할 수 있습니다.").font(.mMicro).foregroundStyle(Tokens.text2)
            }
            HStack(spacing: Tokens.Space.s2) {
                Menu {
                    Button("코드 복사") {
                        guard model.canUseInvites else { return }
                        UIPasteboard.general.string = invite.code
                        model.noticeMessage = "초대 코드를 복사했습니다."
                    }
                    if let url {
                        Button("링크 복사") {
                            guard model.canUseInvites else { return }
                            UIPasteboard.general.string = url.absoluteString
                            model.noticeMessage = "초대 링크를 복사했습니다."
                        }
                    }
                } label: { Label("복사", systemImage: "doc.on.doc").frame(minHeight: 44) }
                ShareLink(item: shareText) { Label("공유", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                Spacer(minLength: 0)
                if invite.displayState == "ACTIVE" {
                    Button("회수", role: .destructive) { revokingInvite = invite }
                        .frame(minHeight: 44).disabled(model.actionID != nil)
                }
            }.disabled(!model.canUseInvites)
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    private func staffList(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        listContainer {
            let requests = dashboard.staffRequests ?? []
            let activeStaff = dashboard.activeStaff ?? []
            if dashboard.isOwner, !requests.isEmpty {
                Text("참여 요청")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(requests) { staff in
                    staffRow(staff) {
                        Button("거절", role: .destructive) {
                            Task { await model.reviewStaff(staff, approve: false) }
                        }
                        .buttonStyle(.bordered)
                        .tint(Tokens.dangerInk)
                        Button("승인") { Task { await model.reviewStaff(staff, approve: true) } }
                            .buttonStyle(.borderedProminent)
                            .tint(Tokens.actionPrimary)
                    }
                    .disabled(model.actionID != nil)
                }
            }
            Text("현재 선생님")
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, requests.isEmpty ? 0 : Tokens.Space.s2)
            if activeStaff.isEmpty {
                emptyState("등록된 선생님이 없습니다", "원장 계정과 승인된 선생님이 여기에 표시됩니다.")
            } else {
                ForEach(activeStaff) { staff in
                    staffRow(staff) {
                        if dashboard.isOwner, staff.role == "TEACHER" {
                            Button("권한 해제", role: .destructive) {
                                Task { await model.revokeStaff(staff) }
                            }
                            .buttonStyle(.bordered)
                            .tint(Tokens.dangerInk)
                            .disabled(model.actionID != nil)
                        }
                    }
                }
            }
        }
    }

    private func staffRow<Actions: View>(
        _ staff: ServerAPI.TeacherAcademyStaff,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Text(staff.user?.name.first.map(String.init) ?? "선")
                .font(.mBodyB).foregroundStyle(Tokens.primary)
                .frame(width: 40, height: 40)
                .background(Tokens.primarySoft, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Tokens.Space.s1) {
                    Text(staff.user?.name ?? "알 수 없는 선생님")
                        .font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text(staff.role == "OWNER" ? "원장" : "선생님")
                        .font(.mMicro).foregroundStyle(Tokens.primary)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Tokens.primarySoft, in: Capsule())
                }
                if let email = staff.user?.email, !email.isEmpty {
                    Text(email).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    private func personRow<Actions: View>(
        _ membership: ServerAPI.TeacherAcademyMembership,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Text(membership.student.name.first.map(String.init) ?? "학")
                .font(.mBodyB)
                .foregroundStyle(Tokens.primary)
                .frame(width: 40, height: 40)
                .background(Tokens.primarySoft, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(membership.student.name).font(.mBodyB).foregroundStyle(Tokens.ink)
                Text(studentDetail(membership.student))
                    .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
            }
            Spacer(minLength: 0)
            actions()
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    private func listContainer<Content: View>(
        refreshesAttendance: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: Tokens.Space.s2) { content() }
        }
        .refreshable {
            if refreshesAttendance {
                await model.loadAttendance()
            } else {
                await model.load()
            }
        }
    }

    private var inviteComposer: some View {
        NavigationStack {
            Form {
                Section("초대 정보") {
                    TextField("초대 이름", text: $model.inviteLabel)
                    Picker("배정할 반", selection: $model.inviteClassID) {
                        Text("반 미지정").tag("")
                        ForEach(model.dashboard?.classes ?? []) { academyClass in
                            Text(academyClass.name).tag(academyClass.id)
                        }
                    }
                    Picker("유효기간", selection: $model.inviteExpiryDays) {
                        ForEach(AcademyInviteDraft.expiryOptions, id: \.self) { Text("\($0)일").tag($0) }
                    }
                    TextField("최대 사용 횟수 (1~200)", text: $model.inviteMaxUsesText)
                        .keyboardType(.numberPad)
                }
                Section {
                    Text("링크와 코드는 \(model.inviteExpiryDays)일 동안 최대 \(model.inviteMaxUses)회 사용할 수 있습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
                if let message = model.inviteDraft.validationMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(Tokens.warningInk) }
                }
                if let message = model.errorMessage {
                    Section { Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(Tokens.dangerInk) }
                }
            }
            .disabled(model.actionID != nil)
            .navigationTitle("새 초대 만들기")
            .interactiveDismissDisabled(model.actionID != nil || model.hasInviteDraftChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if model.hasInviteDraftChanges { confirmsInviteDiscard = true }
                        else { model.discardInviteDraft() }
                    }.disabled(model.actionID != nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.actionID == "new-invite" ? "만드는 중…" : "만들기") { Task { await model.createInvite() } }
                        .disabled(model.actionID != nil || model.inviteDraft.validationMessage != nil)
                }
            }
            .confirmationDialog("작성한 초대를 버릴까요?", isPresented: $confirmsInviteDiscard, titleVisibility: .visible) {
                Button("작성 취소", role: .destructive) { model.discardInviteDraft() }
                Button("계속 작성", role: .cancel) {}
            }
        }
    }

    private var failureState: some View {
        stateShell {
            Image(systemName: "building.2.crop.circle")
                .font(.mTitle).foregroundStyle(Tokens.primary)
            Text("학원 관리 화면을 열지 못했습니다").font(.mHeading)
            feedbackText
            Button("다시 시도") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    @ViewBuilder private var feedbackText: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.dangerSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        } else if let notice = model.noticeMessage {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.mCaption).foregroundStyle(Tokens.successInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.successSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        }
    }

    private func stateShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) { content() }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: 560, alignment: .leading)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
            Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    private func attendanceDateLabel(_ key: String) -> String {
        guard let date = Self.attendanceDateInput.date(from: key) else { return key }
        return Self.attendanceDateOutput.string(from: date)
    }

    private func attendanceStatusLabel(_ status: String) -> String {
        switch status {
        case "PRESENT": "출석"
        case "LATE": "지각"
        case "ABSENT": "결석"
        case "EXCUSED": "사유 결석"
        default: "미기록"
        }
    }

    private func attendanceSessionLabel(_ state: String) -> String {
        switch state {
        case "OPEN": "입력 가능"
        case "SCHEDULED": "시작 전"
        case "CLOSED": "마감"
        case "CANCELED": "취소됨"
        default: state
        }
    }

    private func attendanceStatusInk(_ status: String) -> Color {
        switch status {
        case "PRESENT": Tokens.successInk
        case "LATE": Tokens.warningInk
        case "ABSENT": Tokens.dangerInk
        case "EXCUSED": Tokens.primary
        default: Tokens.text2
        }
    }

    private func attendanceStatusBackground(_ status: String) -> Color {
        switch status {
        case "PRESENT": Tokens.successSoft
        case "LATE": Tokens.warningSoft
        case "ABSENT": Tokens.dangerSoft
        case "EXCUSED": Tokens.primarySoft
        default: Tokens.paper2
        }
    }

    private static let attendanceDateInput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let attendanceDateOutput: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 E"
        return formatter
    }()

    private func sectionBadge(
        _ section: TeacherAcademyScreenModel.Section,
        dashboard: ServerAPI.TeacherAcademyDashboard
    ) -> String {
        switch section {
        case .overview: ""
        case .requests: dashboard.pendingCount > 0 ? " \(dashboard.pendingCount)" : ""
        case .students: " \(dashboard.studentCount)"
        case .attendance: ""
        case .classwork: ""
        case .forensics: ""
        case .classes: " \(dashboard.classes.count)"
        case .staff: (dashboard.staffPendingCount ?? 0) > 0
            ? " \(dashboard.staffPendingCount ?? 0)" : ""
        case .invites: ""
        case .settings: ""
        }
    }

    private func availableSections(
        _ dashboard: ServerAPI.TeacherAcademyDashboard
    ) -> [TeacherAcademyScreenModel.Section] {
        TeacherAcademyScreenModel.Section.allCases.filter { section in
            section != .settings || dashboard.isOwner
        }
    }

    private func sectionTitle(
        _ section: TeacherAcademyScreenModel.Section,
        dashboard: ServerAPI.TeacherAcademyDashboard
    ) -> String {
        if compactLandscape {
            if section == .requests { return "승인" + sectionBadge(section, dashboard: dashboard) }
            if section == .students { return "학생" }
            if section == .staff { return "교사" + sectionBadge(section, dashboard: dashboard) }
        }
        return section.rawValue + sectionBadge(section, dashboard: dashboard)
    }

    private func studentDetail(_ student: ServerAPI.AcademyPerson) -> String {
        [student.schoolGrade.map { "\($0)학년" }, student.school?.name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

private struct TeacherAcademySurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s4)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func teacherAcademySurface() -> some View { modifier(TeacherAcademySurface()) }
}
