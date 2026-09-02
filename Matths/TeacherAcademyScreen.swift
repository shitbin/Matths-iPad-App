import Foundation
import SwiftUI
import UIKit

@MainActor
final class TeacherAcademyScreenModel: ObservableObject {
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

    struct AttendanceDraft: Equatable {
        var status: String
        var note: String
    }

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
    @Published var attendance: ServerAPI.TeacherAttendanceRoster?
    @Published var attendanceDateKey = TeacherAcademyScreenModel.kstDateKey(Date())
    @Published var attendanceClassID = ""
    @Published var attendanceDrafts: [String: AttendanceDraft] = [:]
    @Published var isAttendanceLoading = false

    private var generation = UUID()

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
        dashboard = nil
        setup = nil
        errorMessage = nil
        noticeMessage = nil
        await load()
    }

    func load() async {
        let requestGeneration = generation
        isLoading = dashboard == nil && setup == nil
        errorMessage = nil
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-teacherSetupFixture") {
                let value = try await ServerAPI.teacherAcademySetup()
                guard requestGeneration == generation else { return }
                setup = value
                isLoading = false
                return
            }
            #endif
            let value = try await ServerAPI.teacherAcademyDashboard()
            guard requestGeneration == generation else { return }
            install(value)
        } catch is CancellationError {
            return
        } catch let error as ServerAPIError where error.code == "ACADEMY_SETUP_REQUIRED" {
            guard requestGeneration == generation else { return }
            do {
                let value = try await ServerAPI.teacherAcademySetup()
                guard requestGeneration == generation else { return }
                if value.isReady {
                    install(try await ServerAPI.teacherAcademyDashboard())
                } else {
                    setup = value
                }
            } catch {
                guard requestGeneration == generation else { return }
                errorMessage = readable(error)
            }
        } catch {
            guard requestGeneration == generation else { return }
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
        return await performSetup(id: "setup-create", notice: "학원 등록 요청을 보냈습니다.") {
            try await ServerAPI.createTeacherAcademy(name: normalized)
        }
    }

    func requestAcademyJoin(academyID: String) async -> Bool {
        guard !academyID.isEmpty else {
            errorMessage = "참여할 학원을 선택해 주세요."
            return false
        }
        return await performSetup(id: "setup-join", notice: "학원 참여 요청을 보냈습니다.") {
            try await ServerAPI.requestTeacherAcademyJoin(academyID: academyID)
        }
    }

    func cancelAcademyJoin() async -> Bool {
        await performSetup(id: "setup-cancel", notice: "학원 참여 요청을 취소했습니다.") {
            try await ServerAPI.cancelTeacherAcademyJoin()
        }
    }

    func updateAcademyProfileImage(jpegData: Data) async {
        await perform(id: "academy-profile-upload", notice: "학원 대표 사진을 저장했습니다.") {
            try await ServerAPI.updateTeacherAcademyProfileImage(jpegData: jpegData)
        }
    }

    func removeAcademyProfileImage() async {
        await perform(id: "academy-profile-remove", notice: "학원 대표 사진을 기본 이미지로 되돌렸습니다.") {
            try await ServerAPI.removeTeacherAcademyProfileImage()
        }
    }

    func review(_ membership: ServerAPI.TeacherAcademyMembership, approve: Bool) async {
        await perform(id: membership.id, notice: approve ? "학생을 승인했습니다." : "승인 요청을 거절했습니다.") {
            try await ServerAPI.reviewAcademyStudent(membershipID: membership.id, approve: approve)
        }
    }

    func assign(_ membership: ServerAPI.TeacherAcademyMembership, classID: String?) async {
        await perform(id: membership.id, notice: classID == nil ? "반 배정을 해제했습니다." : "반을 배정했습니다.") {
            try await ServerAPI.assignAcademyStudent(membershipID: membership.id, classID: classID)
        }
    }

    func removeStudent(_ membership: ServerAPI.TeacherAcademyMembership) async {
        await perform(id: membership.id, notice: "학생을 학원 명단에서 제외했습니다.") {
            try await ServerAPI.removeAcademyStudent(membershipID: membership.id)
        }
    }

    func createInvite() async {
        let label = inviteLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else {
            errorMessage = "초대 이름을 입력해 주세요."
            return
        }
        await perform(id: "new-invite", notice: "새 초대 코드를 만들었습니다.") {
            try await ServerAPI.createAcademyInvite(
                label: label,
                classID: inviteClassID.isEmpty ? nil : inviteClassID)
        }
        if errorMessage == nil {
            inviteLabel = "학생 초대"
            inviteClassID = ""
            showsInviteComposer = false
            section = .invites
        }
    }

    func revoke(_ invite: ServerAPI.TeacherAcademyInvite) async {
        await perform(id: invite.id, notice: "초대 코드를 회수했습니다.") {
            try await ServerAPI.revokeAcademyInvite(invite.id)
        }
    }

    func reviewStaff(_ staff: ServerAPI.TeacherAcademyStaff, approve: Bool) async {
        await perform(
            id: staff.id,
            notice: approve ? "선생님 참여 요청을 승인했습니다." : "선생님 참여 요청을 거절했습니다."
        ) {
            try await ServerAPI.reviewAcademyStaff(staffID: staff.id, approve: approve)
        }
    }

    func revokeStaff(_ staff: ServerAPI.TeacherAcademyStaff) async {
        await perform(id: staff.id, notice: "선생님의 학원 접근 권한을 해제했습니다.") {
            try await ServerAPI.revokeAcademyStaff(staff.id)
        }
    }

    func saveClass(classID: String?, draft: ServerAPI.TeacherAcademyClassDraft) async -> Bool {
        let creating = classID == nil
        await perform(
            id: classID.map { "class-\($0)" } ?? "class-new",
            notice: creating ? "새 반을 만들었습니다." : "반 일정과 출결 방식을 저장했습니다."
        ) {
            if let classID {
                return try await ServerAPI.updateTeacherAcademyClass(classID: classID, draft: draft)
            }
            return try await ServerAPI.createTeacherAcademyClass(draft)
        }
        return errorMessage == nil
    }

    func archiveClass(_ academyClass: ServerAPI.AcademyClassSummary) async {
        await perform(id: "class-\(academyClass.id)", notice: "\(academyClass.name) 반을 보관했습니다.") {
            try await ServerAPI.archiveTeacherAcademyClass(academyClass.id)
        }
    }

    func restoreClass(_ academyClass: ServerAPI.AcademyClassSummary) async {
        await perform(id: "class-\(academyClass.id)", notice: "\(academyClass.name) 반을 복구했습니다.") {
            try await ServerAPI.restoreTeacherAcademyClass(academyClass.id)
        }
    }

    func addClassCoTeacher(classID: String, teacherUserID: String) async -> Bool {
        await perform(id: "class-\(classID)", notice: "공동 담당 선생님을 추가했습니다.") {
            try await ServerAPI.addTeacherAcademyClassCoTeacher(
                classID: classID, teacherUserID: teacherUserID)
        }
        return errorMessage == nil
    }

    func removeClassCoTeacher(classID: String, teacherUserID: String) async {
        await perform(id: "class-\(classID)", notice: "공동 담당 선생님을 해제했습니다.") {
            try await ServerAPI.removeTeacherAcademyClassCoTeacher(
                classID: classID, teacherUserID: teacherUserID)
        }
    }

    func transferClassHomeroom(
        classID: String, teacherUserID: String, keepPreviousAsCoTeacher: Bool
    ) async -> Bool {
        await perform(id: "class-\(classID)", notice: "담임 선생님을 이전했습니다.") {
            try await ServerAPI.transferTeacherAcademyClassHomeroom(
                classID: classID,
                teacherUserID: teacherUserID,
                keepPreviousAsCoTeacher: keepPreviousAsCoTeacher)
        }
        return errorMessage == nil
    }

    func loadAttendance() async {
        guard section == .attendance else { return }
        let requestedDateKey = attendanceDateKey
        let requestedClassID = attendanceClassID
        isAttendanceLoading = true
        errorMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyAttendance(
                dateKey: requestedDateKey,
                classID: requestedClassID.isEmpty ? nil : requestedClassID)
            guard section == .attendance,
                  attendanceDateKey == requestedDateKey,
                  attendanceClassID == requestedClassID else { return }
            installAttendance(value)
        } catch is CancellationError {
            return
        } catch {
            guard section == .attendance,
                  attendanceDateKey == requestedDateKey,
                  attendanceClassID == requestedClassID else { return }
            errorMessage = readable(error)
        }
        if section == .attendance,
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
    }

    func updateAttendanceNote(entryID: String, note: String) {
        var drafts = attendanceDrafts
        let current = drafts[entryID] ?? AttendanceDraft(status: "", note: "")
        drafts[entryID] = AttendanceDraft(status: current.status, note: note)
        attendanceDrafts = drafts
    }

    func saveAttendance() async {
        guard let attendance, actionID == nil else { return }
        actionID = "attendance-save"
        errorMessage = nil
        noticeMessage = nil
        do {
            let records = attendance.roster.map { entry in
                let draft = attendanceDrafts[entry.id] ?? AttendanceDraft(status: "", note: "")
                return ServerAPI.TeacherAttendanceRecord(
                    studentUserID: entry.student.id,
                    status: draft.status,
                    note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let value = try await ServerAPI.saveTeacherAcademyAttendance(
                dateKey: attendance.dateKey,
                classID: attendance.selectedClass?.id,
                sessionID: attendance.session?.id,
                records: records)
            installAttendance(value)
            noticeMessage = "출결을 저장했습니다."
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func regenerateAttendanceCode() async {
        guard let sessionID = attendance?.session?.id, actionID == nil else { return }
        actionID = "attendance-code"
        errorMessage = nil
        noticeMessage = nil
        do {
            let session = try await ServerAPI.regenerateTeacherAttendanceCode(sessionID)
            attendance?.session = session
            noticeMessage = "새 출석 코드를 만들었습니다."
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    private func perform(
        id: String,
        notice: String,
        operation: () async throws -> ServerAPI.TeacherAcademyDashboard
    ) async {
        guard actionID == nil else { return }
        actionID = id
        errorMessage = nil
        noticeMessage = nil
        do {
            install(try await operation())
            noticeMessage = notice
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    private func performSetup(
        id: String,
        notice: String,
        operation: () async throws -> ServerAPI.TeacherAcademySetup
    ) async -> Bool {
        guard actionID == nil else { return false }
        actionID = id
        errorMessage = nil
        noticeMessage = nil
        do {
            setup = try await operation()
            noticeMessage = notice
            actionID = nil
            return true
        } catch {
            errorMessage = readable(error)
            actionID = nil
            return false
        }
    }

    private func install(_ value: ServerAPI.TeacherAcademyDashboard) {
        dashboard = value
        setup = nil
        if value.requests.isEmpty && section == .requests { section = .students }
    }

    private func installAttendance(_ value: ServerAPI.TeacherAttendanceRoster) {
        attendance = value
        attendanceDateKey = value.dateKey
        attendanceClassID = value.selectedClass?.id ?? ""
        attendanceDrafts = Dictionary(uniqueKeysWithValues: value.roster.map { entry in
            (
                entry.id,
                AttendanceDraft(
                    status: entry.attendance?.status ?? "",
                    note: entry.attendance?.note ?? "")
            )
        })
    }

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
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 교사 모바일 작업대. 반복 빈도가 높은 승인·반 배정·출결·과제·초대를 네이티브에서
/// 빠르게 끝내고, 원장 전용 반 설정은 인증된 전체 관리 포털로 이어진다.
struct TeacherAcademyScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = TeacherAcademyScreenModel()
    @State private var removingStudent: ServerAPI.TeacherAcademyMembership?
    @State private var focusedStudentID: String?
    @State private var showsAcademyPhotoPicker = false

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
        .task { if model.dashboard == nil && model.setup == nil { await model.load() } }
        .task(id: "\(model.section.rawValue)|\(model.attendanceDateKey)|\(model.attendanceClassID)") {
            await model.loadAttendance()
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.resetAndLoad() }
        }
        .compactHeightSheet(isPresented: $model.showsInviteComposer) {
            inviteComposer
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
        let leadingInset = max(12, viewport.safeAreaInsets.leading + 12)
        let trailingInset = max(12, viewport.safeAreaInsets.trailing + 12)
        let compactSummaryWidth = min(260, viewport.size.width * 0.31)
        let compactWorkWidth = max(
            300,
            viewport.size.width - leadingInset - trailingInset
                - compactSummaryWidth - Tokens.Space.s3)

        if verticalSizeClass == .compact
            && (model.section == .overview
                || model.section == .forensics
                || model.section == .settings) {
            workColumn(dashboard)
                .padding(.leading, max(12, viewport.safeAreaInsets.leading + 12))
                .padding(.trailing, max(12, viewport.safeAreaInsets.trailing + 12))
                .padding(.vertical, Tokens.Space.s2)
        } else if compactLandscape && model.section == .students {
            workColumn(dashboard)
                .padding(.leading, max(12, viewport.safeAreaInsets.leading + 12))
                .padding(.trailing, max(12, viewport.safeAreaInsets.trailing + 12))
                .padding(.vertical, Tokens.Space.s2)
        } else if compactLandscape {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                summaryColumn(dashboard)
                    .frame(width: compactSummaryWidth)
                workColumn(dashboard)
                    // maxWidth만 주면 출결 HStack의 이상적 폭이 부모보다 커질 때
                    // 안전영역 바깥까지 실제 프레임이 팽창한다. 남은 폭을 정확히
                    // 제안해 탭·요약·입력 행이 Island 앞에서 압축되게 한다.
                    .frame(width: compactWorkWidth, alignment: .topLeading)
            }
            // Dynamic Island가 어느 쪽에 있든 그 방향의 실제 인셋을 각각 사용한다.
            // leading 한 값을 양쪽에 재사용하면 기기를 반대로 돌렸을 때 작업대가
            // trailing Island 아래로 들어가 출결 저장·입력 안내가 가려진다.
            .padding(.leading, max(12, viewport.safeAreaInsets.leading + 12))
            .padding(.trailing, max(12, viewport.safeAreaInsets.trailing + 12))
            .padding(.vertical, Tokens.Space.s2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    summaryColumn(dashboard)
                    workColumn(dashboard)
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .refreshable { await model.load() }
        }
    }

    private func summaryColumn(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        academyIdentity(dashboard)
                    }
                } else {
                    HStack(spacing: Tokens.Space.s3) {
                        academyIdentity(dashboard)
                    }
                }
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Tokens.Space.s2) {
                    metric(value: dashboard.pendingCount, label: "승인 대기", emphasized: dashboard.pendingCount > 0)
                    metric(value: dashboard.studentCount, label: "학생", emphasized: false)
                    metric(value: dashboard.classes.count, label: "반", emphasized: false)
                }
            } else {
                HStack(spacing: Tokens.Space.s2) {
                    metric(value: dashboard.pendingCount, label: "승인 대기", emphasized: dashboard.pendingCount > 0)
                    metric(value: dashboard.studentCount, label: "학생", emphasized: false)
                    metric(value: dashboard.classes.count, label: "반", emphasized: false)
                }
            }
            feedbackText
        }
        .teacherAcademySurface()
    }

    private func academyIdentity(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        Group {
                Text(dashboard.academy.name.first.map(String.init) ?? "학")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.onBrand)
                    .frame(width: 48, height: 48)
                    .background(Tokens.actionPrimary,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dashboard.academy.name)
                        .font(compactLandscape ? .mBodyB : .mTitle)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(2)
                    Text(dashboard.isOwner ? "원장" : "선생님")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                }
        }
    }

    private func metric(value: Int, label: String, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)").font(.mHeading.monospacedDigit())
            Text(label).font(.mMicro)
        }
        .foregroundStyle(emphasized ? Tokens.dangerInk : Tokens.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.s2)
        .background(emphasized ? Tokens.dangerSoft : Tokens.primarySoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func workColumn(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                managementSectionPicker(dashboard)
                if model.actionID != nil { ProgressView().tint(Tokens.primary) }
            }
            Group {
                switch model.section {
                case .overview:
                    TeacherAnalyticsPanel(classes: dashboard.classes) { membershipID in
                        focusedStudentID = membershipID
                        model.section = .students
                    }
                case .requests: requestList(dashboard)
                case .students:
                    TeacherStudentManagementPanel(initialMembershipID: focusedStudentID) {
                        await model.load()
                    }
                case .attendance: attendanceBoard(dashboard)
                case .classwork: TeacherClassworkPanel(classes: dashboard.classes)
                case .forensics: TeacherAcademyForensicsPanel()
                case .classes: TeacherClassManagementPanel(dashboard: dashboard, model: model)
                case .staff: staffList(dashboard)
                case .invites: inviteList(dashboard)
                case .settings:
                    TeacherAcademyProfilePanel(
                        dashboard: dashboard,
                        model: model,
                        onChoosePhoto: { showsAcademyPhotoPicker = true })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func managementSectionPicker(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("관리 항목", selection: $model.section) {
                ForEach(availableSections(dashboard)) { section in
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
                        ForEach(availableSections(dashboard)) { section in
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

    private func studentList(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        listContainer {
            if dashboard.students.isEmpty {
                emptyState("승인된 학생이 없습니다", "초대 코드를 보내거나 들어온 요청을 승인해 주세요.")
            } else {
                ForEach(dashboard.students) { membership in
                    personRow(membership) {
                        Menu {
                            Button("미배정") { Task { await model.assign(membership, classID: nil) } }
                            ForEach(dashboard.classes) { academyClass in
                                Button(academyClass.name) {
                                    Task { await model.assign(membership, classID: academyClass.id) }
                                }
                            }
                            Divider()
                            Button("학원에서 제외", role: .destructive) {
                                removingStudent = membership
                            }
                        } label: {
                            Label(membership.academyClass?.name ?? "반 배정", systemImage: "person.2")
                                .font(.mCaption)
                                .frame(minHeight: 44)
                        }
                        .disabled(model.actionID != nil)
                    }
                }
            }
        }
    }

    private func attendanceBoard(_ dashboard: ServerAPI.TeacherAcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
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

            if model.isAttendanceLoading && model.attendance == nil {
                HStack(spacing: Tokens.Space.s2) {
                    ProgressView().tint(Tokens.primary)
                    Text("출결부를 불러오는 중입니다").font(.mCaption).foregroundStyle(Tokens.text2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let attendance = model.attendance {
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
                    .disabled(model.actionID != nil || model.attendance?.roster.isEmpty != false)
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
            Button { model.showsInviteComposer = true } label: {
                Label("새 초대 코드", systemImage: "plus")
            }
            .buttonStyle(PrimaryButtonStyle())
            listContainer {
                let activeInvites = dashboard.invites.filter { $0.displayState == "ACTIVE" }
                if activeInvites.isEmpty {
                    emptyState("사용 가능한 초대가 없습니다", "새 코드를 만들어 학생에게 전달하세요.")
                } else {
                    ForEach(activeInvites) { invite in
                        HStack(spacing: Tokens.Space.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(invite.label).font(.mBodyB).foregroundStyle(Tokens.ink)
                                Text(invite.code).font(.mCaption.monospaced()).foregroundStyle(Tokens.primary)
                                Text("\(invite.useCount)/\(invite.maxUses)명 · \(invite.academyClass?.name ?? "반 미지정")")
                                    .font(.mMicro).foregroundStyle(Tokens.text3)
                            }
                            Spacer(minLength: 0)
                            ShareLink(item: "Matths 학원 초대 코드: \(invite.code)") {
                                Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("\(invite.code) 공유")
                            Button(role: .destructive) { Task { await model.revoke(invite) } } label: {
                                Image(systemName: "trash").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("\(invite.label) 초대 회수")
                            .disabled(model.actionID != nil)
                        }
                        .padding(Tokens.Space.s3)
                        .background(Tokens.surface,
                                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                    }
                }
            }
        }
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
                }
                Section {
                    Text("코드는 14일 동안 최대 30명이 사용할 수 있습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
            .navigationTitle("새 초대 코드")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { model.showsInviteComposer = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기") { Task { await model.createInvite() } }
                        .disabled(model.actionID != nil)
                }
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
