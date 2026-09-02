import SwiftUI
import UIKit

struct AdminClassOperationsInput {
    let weekdays: [Int]
    let startTime: String
    let endTime: String
    let effectiveFrom: String
    let attendanceMode: String
    let opensBeforeMinutes: Int
    let lateAfterMinutes: Int
    let closesAfterMinutes: Int
}

private struct AdminClassOperationsEditor: View {
    let academyClass: ServerAPI.AcademyClassSummary
    let onCancel: () -> Void
    let onSave: (AdminClassOperationsInput) -> Void

    @State private var weekdays: Set<Int>
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var effectiveFrom: Date
    @State private var attendanceMode: String
    @State private var opensBeforeMinutes: Int
    @State private var lateAfterMinutes: Int
    @State private var closesAfterMinutes: Int
    @State private var showsSaveConfirmation = false

    private let weekdayLabels = ["일", "월", "화", "수", "목", "금", "토"]

    init(
        academyClass: ServerAPI.AcademyClassSummary,
        onCancel: @escaping () -> Void,
        onSave: @escaping (AdminClassOperationsInput) -> Void
    ) {
        self.academyClass = academyClass
        self.onCancel = onCancel
        self.onSave = onSave
        let schedule = academyClass.schedule
        let policy = academyClass.attendancePolicy
        _weekdays = State(initialValue: Set(schedule?.weekdays ?? []))
        _startTime = State(initialValue: Self.parseTime(schedule?.startTime, fallbackHour: 16))
        _endTime = State(initialValue: Self.parseTime(schedule?.endTime, fallbackHour: 18))
        _effectiveFrom = State(initialValue: Self.parseDate(schedule?.effectiveFrom) ?? Date())
        _attendanceMode = State(initialValue: policy?.mode == "SELF_CODE" ? "SELF_CODE" : "MANUAL")
        _opensBeforeMinutes = State(initialValue: policy?.opensBeforeMinutes ?? 10)
        _lateAfterMinutes = State(initialValue: policy?.lateAfterMinutes ?? 5)
        _closesAfterMinutes = State(initialValue: policy?.closesAfterMinutes ?? 20)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(academyClass.name)
                        .font(.mHeading)
                    Text("변경 적용 시 아직 시작하지 않은 기존 회차는 취소되고 새 일정으로 다시 생성됩니다.")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.warning)
                }

                Section("수업 요일") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(weekdayLabels.indices, id: \.self) { day in
                            Button {
                                if weekdays.contains(day) { weekdays.remove(day) }
                                else { weekdays.insert(day) }
                            } label: {
                                Text(weekdayLabels[day])
                                    .font(.mCaption)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        weekdays.contains(day) ? Tokens.primary : Tokens.surface,
                                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                                    .foregroundStyle(weekdays.contains(day) ? Color.white : Tokens.text2)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(weekdayLabels[day])요일")
                            .accessibilityValue(weekdays.contains(day) ? "선택됨" : "선택 안 됨")
                        }
                    }
                }

                Section("수업 시간") {
                    DatePicker("시작", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("종료", selection: $endTime, displayedComponents: .hourAndMinute)
                    DatePicker("새 일정 적용일", selection: $effectiveFrom, displayedComponents: .date)
                }

                Section("출석 방식") {
                    Picker("출석 방식", selection: $attendanceMode) {
                        Text("선생님 기록").tag("MANUAL")
                        Text("학생 코드").tag("SELF_CODE")
                    }
                    .pickerStyle(.segmented)
                    Stepper("수업 \(opensBeforeMinutes)분 전 출석 열기", value: $opensBeforeMinutes, in: 0...120)
                    Stepper("시작 \(lateAfterMinutes)분 후 지각", value: $lateAfterMinutes, in: 0...120)
                    Stepper("시작 \(closesAfterMinutes)분 후 마감", value: $closesAfterMinutes, in: 1...240)
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.mMicro)
                            .foregroundStyle(Tokens.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.surface)
            .navigationTitle("일정·출석 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { showsSaveConfirmation = true }
                        .disabled(validationMessage != nil)
                }
            }
            .confirmationDialog(
                "새 운영 설정을 적용할까요?",
                isPresented: $showsSaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("적용") { onSave(input) }
                Button("취소", role: .cancel) {}
            } message: {
                Text("아직 시작하지 않은 기존 회차가 취소되고 새 일정으로 다시 생성됩니다.")
            }
        }
        .presentationDetents([.large])
    }

    private var validationMessage: String? {
        if weekdays.isEmpty { return "수업 요일을 하나 이상 선택해 주세요." }
        if minuteOfDay(endTime) <= minuteOfDay(startTime) {
            return "수업 종료 시간은 시작 시간보다 늦어야 합니다."
        }
        if lateAfterMinutes > closesAfterMinutes {
            return "지각 기준은 출석 마감보다 빠르거나 같아야 합니다."
        }
        return nil
    }

    private var input: AdminClassOperationsInput {
        AdminClassOperationsInput(
            weekdays: weekdays.sorted(),
            startTime: Self.timeKey(startTime),
            endTime: Self.timeKey(endTime),
            effectiveFrom: Self.dateKey(effectiveFrom),
            attendanceMode: attendanceMode,
            opensBeforeMinutes: opensBeforeMinutes,
            lateAfterMinutes: lateAfterMinutes,
            closesAfterMinutes: closesAfterMinutes)
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func parseTime(_ raw: String?, fallbackHour: Int) -> Date {
        let parts = (raw ?? "").split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(
            bySettingHour: parts.first ?? fallbackHour,
            minute: parts.count > 1 ? parts[1] : 0,
            second: 0,
            of: Date()) ?? Date()
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private static func timeKey(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private static func dateKey(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

private struct AdminClassHomeroomEditor: View {
    let academyClass: ServerAPI.AcademyClassSummary
    let staff: [ServerAPI.TeacherAcademyStaff]
    let onCancel: () -> Void
    let onSave: (String, Bool) -> Void

    @State private var nextTeacherUserID: String
    @State private var retainPreviousAsCoTeacher = true
    @State private var showsSaveConfirmation = false

    init(
        academyClass: ServerAPI.AcademyClassSummary,
        staff: [ServerAPI.TeacherAcademyStaff],
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, Bool) -> Void
    ) {
        self.academyClass = academyClass
        self.staff = staff
        self.onCancel = onCancel
        self.onSave = onSave
        let currentID = academyClass.homeroomTeacher?.id
        let firstCandidate = staff.first {
            $0.status == "ACTIVE" && $0.user != nil && $0.user?.id != currentID
        }?.user?.id ?? ""
        _nextTeacherUserID = State(initialValue: firstCandidate)
    }

    private var candidates: [ServerAPI.TeacherAcademyStaff] {
        staff.filter {
            $0.status == "ACTIVE" && $0.user != nil
                && $0.user?.id != academyClass.homeroomTeacher?.id
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("현재 담임") {
                    LabeledContent("반", value: academyClass.name)
                    LabeledContent("담임", value: academyClass.homeroomTeacher?.name ?? "정보 없음")
                }
                Section("새 담임") {
                    if candidates.isEmpty {
                        Label("이전할 수 있는 활성 선생님이 없습니다.", systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                    } else {
                        Picker("선생님", selection: $nextTeacherUserID) {
                            ForEach(candidates) { member in
                                Text("\(member.user?.name ?? "이름 없음") · \(member.role == "OWNER" ? "원장" : "교사")")
                                    .tag(member.user?.id ?? "")
                            }
                        }
                        Toggle("기존 담임을 보조 선생님으로 유지", isOn: $retainPreviousAsCoTeacher)
                    }
                }
                Section {
                    Text("담임 변경 즉시 새 선생님이 반 운영 권한을 갖습니다. 기존 담임 유지 옵션을 끄면 보조 교사에서도 제외됩니다.")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text2)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.surface)
            .navigationTitle("담임 이전")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("이전") { showsSaveConfirmation = true }
                        .disabled(nextTeacherUserID.isEmpty)
                }
            }
            .confirmationDialog(
                "담임 선생님을 이전할까요?",
                isPresented: $showsSaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("담임 이전") {
                    onSave(nextTeacherUserID, retainPreviousAsCoTeacher)
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text(retainPreviousAsCoTeacher
                     ? "기존 담임은 보조 선생님으로 유지됩니다."
                     : "기존 담임은 이 반의 교사 목록에서도 제외됩니다.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct AdminAttendanceOverrideEditor: View {
    let record: ServerAPI.AdminAcademyAttendanceRecord
    let onCancel: () -> Void
    let onSave: (String, String) -> Void

    @State private var status: String
    @State private var note: String
    @State private var showsSaveConfirmation = false

    init(
        record: ServerAPI.AdminAcademyAttendanceRecord,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String) -> Void
    ) {
        self.record = record
        self.onCancel = onCancel
        self.onSave = onSave
        _status = State(initialValue: record.status)
        _note = State(initialValue: record.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("학생·수업") {
                    LabeledContent("학생", value: record.student?.name ?? "정보 없음")
                    LabeledContent("반", value: record.academyClass?.name ?? "미배정")
                    LabeledContent("수업일", value: record.dateKey ?? "정보 없음")
                    LabeledContent("현재 기록", value: attendanceLabel(record.status))
                }
                Section("보정 결과") {
                    Picker("출결 상태", selection: $status) {
                        Text("출석").tag("PRESENT")
                        Text("지각").tag("LATE")
                        Text("결석").tag("ABSENT")
                        Text("인정결석").tag("EXCUSED")
                    }
                    TextField("보정 사유 또는 메모", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .onChange(of: note) { _, value in
                            if value.count > 200 { note = String(value.prefix(200)) }
                        }
                    Text("\(note.count)/200")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                }
                Section {
                    Text("운영자 보정은 이전 상태와 함께 출결 감사 이력에 영구 기록됩니다.")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.warning)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Tokens.surface)
            .navigationTitle("출결 기록 보정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { showsSaveConfirmation = true }
                }
            }
            .confirmationDialog(
                "출결 기록을 보정할까요?",
                isPresented: $showsSaveConfirmation,
                titleVisibility: .visible
            ) {
                Button("보정 저장") { onSave(status, note) }
                Button("취소", role: .cancel) {}
            } message: {
                Text("\(attendanceLabel(record.status))에서 \(attendanceLabel(status))(으)로 변경하며 감사 이력을 남깁니다.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func attendanceLabel(_ status: String) -> String {
        switch status.uppercased() {
        case "PRESENT": "출석"
        case "LATE": "지각"
        case "ABSENT": "결석"
        case "EXCUSED": "인정결석"
        default: status
        }
    }
}

@MainActor
final class AdminAcademyExplorerModel: ObservableObject {
    @Published var page: ServerAPI.AdminAcademyListResponse?
    @Published var detail: ServerAPI.AdminAcademyDetail?
    @Published var selectedAcademyID: String?
    @Published var searchText = ""
    @Published var status = "ALL"
    @Published var isLoadingList = false
    @Published var isLoadingDetail = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var previewURL: URL?

    private var listGeneration = UUID()
    private var detailGeneration = UUID()

    func resetAndLoad() async {
        listGeneration = UUID()
        detailGeneration = UUID()
        page = nil
        detail = nil
        selectedAcademyID = nil
        errorMessage = nil
        noticeMessage = nil
        await loadList(pageNumber: 1)
    }

    func loadList(pageNumber: Int = 1, preserveSelection: Bool = false) async {
        let generation = UUID()
        listGeneration = generation
        isLoadingList = true
        errorMessage = nil
        do {
            let response = try await ServerAPI.adminAcademyList(
                search: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status,
                page: pageNumber)
            guard listGeneration == generation else { return }
            page = response
            let stillVisible = preserveSelection
                && response.academies.contains { $0.id == selectedAcademyID }
            let nextID = stillVisible ? selectedAcademyID : response.academies.first?.id
            if nextID != selectedAcademyID {
                selectedAcademyID = nextID
                detail = nil
            }
            if let nextID { await loadDetail(academyID: nextID) }
        } catch is CancellationError {
            return
        } catch {
            guard listGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if listGeneration == generation { isLoadingList = false }
    }

    func select(_ academy: ServerAPI.AdminAcademyListItem) async {
        guard academy.id != selectedAcademyID || detail == nil else { return }
        selectedAcademyID = academy.id
        detail = nil
        await loadDetail(academyID: academy.id)
    }

    func loadDetail(academyID: String? = nil, period: String? = nil) async {
        guard let academyID = academyID ?? selectedAcademyID else { return }
        let generation = UUID()
        detailGeneration = generation
        isLoadingDetail = true
        errorMessage = nil
        do {
            let response = try await ServerAPI.adminAcademyDetail(
                academyID: academyID, period: period)
            guard detailGeneration == generation, selectedAcademyID == academyID else { return }
            detail = response
        } catch is CancellationError {
            return
        } catch {
            guard detailGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if detailGeneration == generation { isLoadingDetail = false }
    }

    func changeStatus(_ next: String) async {
        guard status != next else { return }
        status = next
        await loadList(pageNumber: 1)
    }

    func updateProfile(action: String, name: String? = nil) async {
        guard let academyID = selectedAcademyID, actionID == nil else { return }
        actionID = action
        errorMessage = nil
        noticeMessage = nil
        do {
            detail = try await ServerAPI.updateAdminAcademyProfile(
                academyID: academyID, action: action, name: name)
            noticeMessage = switch action {
            case "RENAME": "학원 이름을 변경했습니다."
            case "PAUSE": "학원 운영을 일시중지했습니다."
            case "ACTIVATE": "학원 운영을 재개했습니다."
            case "REOPEN": "학원을 재검토 대기로 복구했습니다."
            default: "학원 정보를 변경했습니다."
            }
            await refreshListSummary()
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func updateProfileImage(jpegData: Data) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "profile-image", notice: "학원 대표 사진을 저장했습니다.") {
            try await ServerAPI.updateAdminAcademyProfileImage(
                academyID: academyID, jpegData: jpegData)
        }
    }

    func removeProfileImage() async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "profile-image-remove", notice: "학원 대표 사진을 기본 이미지로 되돌렸습니다.") {
            try await ServerAPI.removeAdminAcademyProfileImage(academyID: academyID)
        }
    }

    func selectAnalyticsPeriod(_ period: String) async {
        await loadDetail(period: period)
    }

    func preview(_ file: ServerAPI.AcademyWeek.File, from week: ServerAPI.AdminAcademyWeek) async {
        guard let academyID = selectedAcademyID, actionID == nil else { return }
        actionID = "preview:\(file.id)"
        errorMessage = nil
        do {
            previewURL = try await ServerAPI.downloadAdminAcademyFile(
                academyID: academyID, weekID: week.id, file: file)
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func updateContract(endsAt: Date) async {
        guard let academyID = selectedAcademyID, actionID == nil else { return }
        actionID = "CONTRACT"
        errorMessage = nil
        noticeMessage = nil
        do {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            let components = calendar.dateComponents([.year, .month, .day], from: endsAt)
            let dateKey = String(
                format: "%04d-%02d-%02d",
                components.year ?? 0, components.month ?? 0, components.day ?? 0)
            detail = try await ServerAPI.updateAdminAcademyContract(
                academyID: academyID, contractEndsAt: dateKey)
            noticeMessage = "계약 만료일을 변경했습니다."
            await refreshListSummary()
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func updateStaff(staffID: String, action: String) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "staff:\(staffID)", notice: staffNotice(action)) {
            try await ServerAPI.updateAdminAcademyStaff(
                academyID: academyID, staffID: staffID, action: action)
        }
    }

    func transferOwner(to staffID: String) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "owner:\(staffID)", notice: "원장 권한을 이전했습니다.") {
            try await ServerAPI.transferAdminAcademyOwner(
                academyID: academyID, newOwnerStaffID: staffID)
        }
    }

    func updateStudent(membershipID: String, action: String) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "student:\(membershipID)", notice: studentNotice(action)) {
            try await ServerAPI.updateAdminAcademyStudent(
                academyID: academyID, membershipID: membershipID, action: action)
        }
    }

    func assignStudentClass(membershipID: String, classID: String?) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "student-class:\(membershipID)", notice: "학생의 반 배정을 변경했습니다.") {
            try await ServerAPI.assignAdminAcademyStudentClass(
                academyID: academyID, membershipID: membershipID, classID: classID)
        }
    }

    func updateClass(classID: String, action: String) async {
        guard let academyID = selectedAcademyID else { return }
        let notice = action == "DEACTIVATE" ? "반을 보관했습니다." : "반을 복구했습니다."
        await performMutation(actionID: "class:\(classID)", notice: notice) {
            try await ServerAPI.updateAdminAcademyClass(
                academyID: academyID, classID: classID, action: action)
        }
    }

    func updateClassOperations(classID: String, input: AdminClassOperationsInput) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "class-operations:\(classID)", notice: "수업 일정과 출석 방식을 변경했습니다.") {
            try await ServerAPI.updateAdminAcademyClassOperations(
                academyID: academyID,
                classID: classID,
                weekdays: input.weekdays,
                startTime: input.startTime,
                endTime: input.endTime,
                effectiveFrom: input.effectiveFrom,
                attendanceMode: input.attendanceMode,
                opensBeforeMinutes: input.opensBeforeMinutes,
                lateAfterMinutes: input.lateAfterMinutes,
                closesAfterMinutes: input.closesAfterMinutes)
        }
    }

    func transferClassHomeroom(
        classID: String, nextTeacherUserID: String, retainPreviousAsCoTeacher: Bool
    ) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "class-homeroom:\(classID)", notice: "담임 선생님을 변경했습니다.") {
            try await ServerAPI.transferAdminAcademyClassHomeroom(
                academyID: academyID,
                classID: classID,
                nextTeacherUserID: nextTeacherUserID,
                retainPreviousAsCoTeacher: retainPreviousAsCoTeacher)
        }
    }

    func updateInvite(inviteID: String, action: String) async {
        guard let academyID = selectedAcademyID else { return }
        let notice = action == "REVOKE" ? "초대를 비활성화했습니다." : "초대를 다시 활성화했습니다."
        await performMutation(actionID: "invite:\(inviteID)", notice: notice) {
            try await ServerAPI.updateAdminAcademyInvite(
                academyID: academyID, inviteID: inviteID, action: action)
        }
    }

    func regenerateAttendanceCode(sessionID: String) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "attendance:\(sessionID)", notice: "출결 코드를 재발급했습니다.") {
            try await ServerAPI.regenerateAdminAcademyAttendanceCode(
                academyID: academyID, sessionID: sessionID)
        }
    }

    func updateAttendance(attendanceID: String, status: String, note: String) async {
        guard let academyID = selectedAcademyID else { return }
        await performMutation(actionID: "attendance-record:\(attendanceID)", notice: "출결 기록을 보정했습니다.") {
            try await ServerAPI.updateAdminAcademyAttendance(
                academyID: academyID,
                attendanceID: attendanceID,
                status: status,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func performMutation(
        actionID nextActionID: String,
        notice: String,
        operation: () async throws -> ServerAPI.AdminAcademyDetail
    ) async {
        guard actionID == nil else { return }
        actionID = nextActionID
        errorMessage = nil
        noticeMessage = nil
        do {
            detail = try await operation()
            noticeMessage = notice
            await refreshListSummary()
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    private func staffNotice(_ action: String) -> String {
        switch action {
        case "APPROVE": "교사 소속을 승인했습니다."
        case "REJECT": "교사 소속 요청을 반려했습니다."
        case "REVOKE": "교사 권한을 해제했습니다."
        default: "교사 소속을 복구했습니다."
        }
    }

    private func studentNotice(_ action: String) -> String {
        switch action {
        case "APPROVE": "학생 소속을 승인했습니다."
        case "REJECT": "학생 소속 요청을 반려했습니다."
        case "REMOVE": "학생을 학원에서 내보냈습니다."
        default: "학생 소속을 복구했습니다."
        }
    }

    private func refreshListSummary() async {
        guard let current = page?.pagination.page else { return }
        if let response = try? await ServerAPI.adminAcademyList(
            search: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            page: current) {
            page = response
        }
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 운영 중인 모든 학원을 검색하고 핵심 운영 상태를 한 화면에서 확인하는 네이티브 작업대.
/// 아이폰 가로에서는 목록과 상세가 각각 스크롤되어 문맥을 잃지 않는다.
struct AdminAcademyExplorer: View {
    private enum MutationKind {
        case staff(id: String, action: String)
        case owner(staffID: String)
        case student(id: String, action: String)
        case academyClass(id: String, action: String)
        case editClassOperations(classID: String)
        case transferClassHomeroom(classID: String)
        case invite(id: String, action: String)
        case attendance(sessionID: String)
        case editAttendance(recordID: String)
    }

    private struct MutationIntent: Identifiable {
        let id: String
        let title: String
        let message: String
        let button: String
        let destructive: Bool
        let kind: MutationKind
    }

    private enum DetailSection: String, CaseIterable, Identifiable {
        case overview = "요약"
        case analytics = "통계"
        case staff = "직원"
        case students = "학생"
        case classes = "반"
        case classwork = "수업"
        case invites = "초대"
        case attendance = "출결"
        var id: String { rawValue }
    }

    private let onClose: () -> Void
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminAcademyExplorerModel()
    @State private var detailSection: DetailSection = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-adminAcademySection"),
           arguments.indices.contains(index + 1),
           let section = DetailSection(rawValue: arguments[index + 1]) {
            return section
        }
        #endif
        return .overview
    }()
    @State private var renameDraft = ""
    @State private var contractDraft = Date().addingTimeInterval(86_400 * 30)
    @State private var showsRenameEditor = false
    @State private var showsContractEditor = false
    @State private var profileActionToConfirm: String?
    @State private var mutationIntent: MutationIntent?
    @State private var operationsClass: ServerAPI.AcademyClassSummary?
    @State private var homeroomClass: ServerAPI.AcademyClassSummary?
    @State private var attendanceRecord: ServerAPI.AdminAcademyAttendanceRecord?
    @State private var showsAcademyPhotoPicker = false
    @State private var confirmsProfileImageRemoval = false

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { viewport in
            Group {
                if compactLandscape {
                    HStack(spacing: Tokens.Space.s3) {
                        listPane
                            .frame(width: min(330, viewport.size.width * 0.38))
                        detailPane
                    }
                    .padding(.horizontal, max(12, viewport.safeAreaInsets.leading + 12))
                    .padding(.vertical, Tokens.Space.s2)
                } else {
                    ScrollView {
                        VStack(spacing: Tokens.Space.s4) {
                            listPane
                                .frame(minHeight: 360)
                            detailPane
                                .frame(minHeight: 420)
                        }
                        .readableWidth(Tokens.readableWidth)
                        .adaptiveHPadding()
                        .adaptiveVPadding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.paper)
        .task { if model.page == nil { await model.loadList() } }
        .onAppear { requestDebugLandscapeIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.resetAndLoad() }
        }
        .compactHeightSheet(isPresented: $showsRenameEditor) { renameEditor }
        .compactHeightSheet(isPresented: $showsContractEditor) { contractEditor }
        .compactHeightSheet(item: $operationsClass) { academyClass in
            AdminClassOperationsEditor(
                academyClass: academyClass,
                onCancel: { operationsClass = nil },
                onSave: { input in
                    operationsClass = nil
                    Task { await model.updateClassOperations(classID: academyClass.id, input: input) }
                })
        }
        .compactHeightSheet(item: $homeroomClass) { academyClass in
            AdminClassHomeroomEditor(
                academyClass: academyClass,
                staff: model.detail?.staff ?? [],
                onCancel: { homeroomClass = nil },
                onSave: { nextTeacherUserID, retainPrevious in
                    homeroomClass = nil
                    Task {
                        await model.transferClassHomeroom(
                            classID: academyClass.id,
                            nextTeacherUserID: nextTeacherUserID,
                            retainPreviousAsCoTeacher: retainPrevious)
                    }
                })
        }
        .compactHeightSheet(item: $attendanceRecord) { record in
            AdminAttendanceOverrideEditor(
                record: record,
                onCancel: { attendanceRecord = nil },
                onSave: { status, note in
                    attendanceRecord = nil
                    Task {
                        await model.updateAttendance(
                            attendanceID: record.id, status: status, note: note)
                    }
                })
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
                    Task { await model.updateProfileImage(jpegData: data) }
                })
                .ignoresSafeArea()
        }
        .compactHeightSheet(isPresented: Binding(
            get: { model.previewURL != nil },
            set: { if !$0 { model.previewURL = nil } })
        ) {
            if let url = model.previewURL {
                CommunityFilePreview(url: url) { model.previewURL = nil }
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "학원 대표 사진을 기본 이미지로 되돌릴까요?",
            isPresented: $confirmsProfileImageRemoval,
            titleVisibility: .visible
        ) {
            Button("대표 사진 삭제", role: .destructive) {
                Task { await model.removeProfileImage() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("학생과 선생님 화면에는 기본 학원 이미지가 표시됩니다.")
        }
        .confirmationDialog(
            profileActionTitle(profileActionToConfirm),
            isPresented: Binding(
                get: { profileActionToConfirm != nil },
                set: { if !$0 { profileActionToConfirm = nil } }),
            titleVisibility: .visible
        ) {
            if let action = profileActionToConfirm {
                Button(profileActionButton(action), role: action == "PAUSE" ? .destructive : nil) {
                    profileActionToConfirm = nil
                    Task { await model.updateProfile(action: action) }
                }
            }
            Button("취소", role: .cancel) { profileActionToConfirm = nil }
        } message: {
            Text(profileActionMessage(profileActionToConfirm))
        }
        .confirmationDialog(
            mutationIntent?.title ?? "운영 정보를 변경할까요?",
            isPresented: Binding(
                get: { mutationIntent != nil },
                set: { if !$0 { mutationIntent = nil } }),
            titleVisibility: .visible,
            presenting: mutationIntent
        ) { intent in
            Button(intent.button, role: intent.destructive ? .destructive : nil) {
                mutationIntent = nil
                Task { await execute(intent.kind) }
            }
            Button("취소", role: .cancel) { mutationIntent = nil }
        } message: { intent in
            Text(intent.message)
        }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s2) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .accessibilityLabel("승인함으로 돌아가기")

                VStack(alignment: .leading, spacing: 1) {
                    Text("전체 학원")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                    if let total = model.page?.pagination.total {
                        Text("검색 결과 \(total)곳")
                            .font(.mMicro)
                            .foregroundStyle(Tokens.text3)
                    }
                }
                Spacer(minLength: 0)
                if model.isLoadingList { ProgressView().tint(Tokens.primary) }
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Tokens.text3)
                    .accessibilityHidden(true)
                TextField("학원명 검색", text: $model.searchText)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.loadList(pageNumber: 1) } }
                Button("검색") { Task { await model.loadList(pageNumber: 1) } }
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
            }
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 44)
            .background(Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }

            statusFilters

            if let message = model.errorMessage, model.page == nil {
                failure(message)
            } else if let page = model.page, page.academies.isEmpty {
                emptyList
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.page?.academies ?? []) { academy in
                            academyRow(academy)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .refreshable { await model.loadList(preserveSelection: true) }
            }

            if let pagination = model.page?.pagination, pagination.totalPages > 1 {
                HStack {
                    Button("이전") {
                        Task { await model.loadList(pageNumber: pagination.page - 1) }
                    }
                    .disabled(pagination.page <= 1)
                    Spacer()
                    Text("\(pagination.page) / \(pagination.totalPages)")
                        .font(.mMicro.monospacedDigit())
                        .foregroundStyle(Tokens.text2)
                    Spacer()
                    Button("다음") {
                        Task { await model.loadList(pageNumber: pagination.page + 1) }
                    }
                    .disabled(pagination.page >= pagination.totalPages)
                }
                .font(.mCaption)
            }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private var statusFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(["ALL", "ACTIVE", "PENDING", "PAUSED", "REJECTED", "ARCHIVED"], id: \.self) { status in
                    Button {
                        Task { await model.changeStatus(status) }
                    } label: {
                        Text("\(statusLabel(status)) \(statusCount(status))")
                            .font(.mMicro)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(model.status == status
                                        ? Tokens.actionPrimary : Tokens.paper,
                                        in: Capsule())
                            .foregroundStyle(model.status == status
                                             ? Tokens.onBrand : Tokens.text2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.status == status ? .isSelected : [])
                }
            }
        }
    }

    private func academyRow(_ academy: ServerAPI.AdminAcademyListItem) -> some View {
        let selected = academy.id == model.selectedAcademyID
        return Button {
            detailSection = .overview
            Task { await model.select(academy) }
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                academyImage(academy)
                VStack(alignment: .leading, spacing: 2) {
                    Text(academy.name)
                        .font(.mCaption)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(statusLabel(academy.status))
                        if let students = academy.counts?.approvedStudents {
                            Text("학생 \(students)")
                        }
                        if let classes = academy.counts?.activeClasses {
                            Text("반 \(classes)")
                        }
                    }
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selected ? Tokens.primary : Tokens.text3)
            }
            .padding(.horizontal, Tokens.Space.s2)
            .frame(minHeight: 58)
            .background(selected ? Tokens.primary.opacity(0.10) : Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                    .strokeBorder(selected ? Tokens.primary.opacity(0.55) : Tokens.line,
                                  lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(academy.name), \(statusLabel(academy.status))")
        .accessibilityHint("학원 운영 상세를 엽니다")
    }

    @ViewBuilder
    private var detailPane: some View {
        if model.isLoadingDetail && model.detail == nil {
            statePane(icon: nil, title: "학원 정보를 불러오는 중") {
                ProgressView().tint(Tokens.primary)
            }
        } else if let detail = model.detail {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                detailHeader(detail)
                feedbackBanner
                detailTabs
                ScrollView {
                    detailContent(detail)
                        .padding(.vertical, 1)
                }
                .refreshable { await model.loadDetail() }
            }
            .padding(Tokens.Space.s3)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
        } else if let message = model.errorMessage, model.selectedAcademyID != nil {
            statePane(icon: "wifi.exclamationmark", title: "상세 정보를 열지 못했습니다") {
                Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
                Button("다시 시도") { Task { await model.loadDetail() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else {
            statePane(icon: "building.2", title: "학원을 선택하세요") {
                Text("왼쪽 목록에서 학원을 고르면 운영 상태가 여기에 표시됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func detailHeader(_ detail: ServerAPI.AdminAcademyDetail) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            academyImage(detail.academy, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.academy.name)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                Text("\(statusLabel(detail.academy.status)) · \(planLabel(detail.academy.planCode))")
                    .font(.mCaption)
                    .foregroundStyle(statusColor(detail.academy.status))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button("새로고침", systemImage: "arrow.clockwise") {
                    Task { await model.loadDetail() }
                }
                Button("학원명 변경", systemImage: "pencil") {
                    renameDraft = detail.academy.name
                    showsRenameEditor = true
                }
                Button("계약 만료일 변경", systemImage: "calendar") {
                    contractDraft = suggestedContractDate(detail.academy.contractEndsAt)
                    showsContractEditor = true
                }
                Button("대표 사진 변경", systemImage: "photo.badge.plus") {
                    showsAcademyPhotoPicker = true
                }
                if detail.academy.profileImageURL != nil {
                    Button("대표 사진 삭제", systemImage: "photo.badge.minus", role: .destructive) {
                        confirmsProfileImageRemoval = true
                    }
                }
                if let action = availableProfileAction(detail.academy.status) {
                    Divider()
                    Button(profileActionButton(action), systemImage: profileActionIcon(action),
                           role: action == "PAUSE" ? .destructive : nil) {
                        profileActionToConfirm = action
                    }
                }
            } label: {
                if model.actionID != nil {
                    ProgressView().tint(Tokens.primary).frame(width: 44, height: 44)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
            }
            .foregroundStyle(Tokens.primary)
            .disabled(model.actionID != nil)
            .accessibilityLabel("학원 관리")
        }
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        if let message = model.errorMessage, model.detail != nil {
            Text(message)
                .font(.mCaption)
                .foregroundStyle(Tokens.danger)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("오류: \(message)")
        } else if let message = model.noticeMessage {
            Text(message)
                .font(.mCaption)
                .foregroundStyle(Tokens.success)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("완료: \(message)")
        }
    }

    private var detailTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(DetailSection.allCases) { item in
                    Button {
                        detailSection = item
                    } label: {
                        Text(item.rawValue)
                            .font(.mMicro)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .foregroundStyle(detailSection == item
                                             ? Tokens.onBrand : Tokens.text2)
                            .background(detailSection == item
                                        ? Tokens.actionPrimary : Tokens.paper,
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(detailSection == item ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder
    private func detailContent(_ detail: ServerAPI.AdminAcademyDetail) -> some View {
        switch detailSection {
        case .overview: overview(detail)
        case .analytics: analyticsView(detail.analytics)
        case .staff: staffList(detail.staff)
        case .students: studentList(detail.students)
        case .classes: classList(detail.classes)
        case .classwork: classworkList(detail.classWeeks ?? [])
        case .invites: inviteList(detail.invites)
        case .attendance: attendanceList(detail)
        }
    }

    private func overview(_ detail: ServerAPI.AdminAcademyDetail) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                      spacing: Tokens.Space.s2) {
                metric(detail.counts.approvedStudents, "학생")
                metric(detail.counts.activeStaff, "직원")
                metric(detail.counts.activeClasses, "운영 반")
                metric(detail.counts.pendingStudents, "학생 대기", warning: true)
                metric(detail.counts.pendingStaff, "직원 대기", warning: true)
                metric(detail.counts.activeInvites ?? 0, "유효 초대")
            }

            infoCard(title: "계약·상품") {
                labeled("계약 기간", contractPeriod(detail.academy))
                labeled("모의고사", detail.academy.includesMockExam ? "포함" : "미포함")
                labeled("신청자", applicantLabel(detail.academy.applicant))
            }
        }
    }

    @ViewBuilder
    private func analyticsView(_ analytics: ServerAPI.TeacherAcademyAnalytics?) -> some View {
        if let analytics {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Picker("조회 기간", selection: Binding(
                    get: { analytics.period.key },
                    set: { period in Task { await model.selectAnalyticsPeriod(period) } })
                ) {
                    ForEach(analytics.period.options) { option in
                        Text(option.label).tag(option.key)
                    }
                }
                .pickerStyle(.menu)
                .disabled(model.isLoadingDetail || model.actionID != nil)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 145), spacing: Tokens.Space.s2)],
                    spacing: Tokens.Space.s2
                ) {
                    ForEach(analytics.cards) { card in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.label).font(.mMicro).foregroundStyle(Tokens.text3)
                            Text(card.value).font(.mBodyB.monospacedDigit()).foregroundStyle(Tokens.ink)
                            Text(card.detail).font(.mMicro).foregroundStyle(Tokens.text2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                        .padding(Tokens.Space.s2)
                        .background(Tokens.paper,
                                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    }
                }

                infoCard(title: "확인이 필요한 학생 · \(analytics.attentionStudents.count)명") {
                    if analytics.attentionStudents.isEmpty {
                        Text("현재 기준에서 별도 확인이 필요한 학생이 없습니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    } else {
                        ForEach(analytics.attentionStudents) { item in
                            labeled(item.membership.student.name, item.reasons.joined(separator: " · "))
                        }
                    }
                }

                infoCard(title: "Math Map") {
                    labeled("학원 평균 숙달도", analytics.mathMap.overallMastery.map { "\(Int($0.rounded()))%" } ?? "분석 전")
                    labeled("분석 개념", "\(analytics.mathMap.analyzedConceptCount)개")
                    labeled("분석 학생", "\(analytics.mathMap.totalStudents)명")
                    if let recommendation = analytics.mathMap.recommendation {
                        labeled("우선 복습", recommendation.conceptTitle)
                        Text(recommendation.reason)
                            .font(.mMicro).foregroundStyle(Tokens.text2)
                    }
                    ForEach(analytics.mathMap.heatmap) { concept in
                        labeled(
                            concept.conceptTitle,
                            concept.mastery.map { "\(Int($0.rounded()))% · \(concept.analyzedCount)/\(concept.totalStudents)명" }
                                ?? "Unknown · \(concept.analyzedCount)/\(concept.totalStudents)명")
                    }
                    Text("그래프 \(analytics.mathMap.graphVersion) · 계산 모델 \(analytics.mathMap.modelVersion)")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }

                infoCard(title: "운영 요약") {
                    ForEach(analytics.summary) { bullet in
                        labeled(bullet.label, bullet.text)
                    }
                }
            }
        } else {
            Text("통계 데이터를 불러오지 못했습니다. 서버 배포 상태를 확인한 뒤 새로고침해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .frame(maxWidth: .infinity, minHeight: 150)
        }
    }

    private func classworkList(_ weeks: [ServerAPI.AdminAcademyWeek]) -> some View {
        entityList(empty: "등록된 주차 수업과 과제가 없습니다.") {
            ForEach(weeks) { week in classworkRow(week) }
        }
    }

    private func staffList(_ staff: [ServerAPI.TeacherAcademyStaff]) -> some View {
        entityList(empty: "등록된 직원이 없습니다.") {
            ForEach(staff) { member in
                staffRow(member)
            }
        }
    }

    private func studentList(_ students: [ServerAPI.AdminAcademyStudent]) -> some View {
        entityList(empty: "등록된 학생이 없습니다.") {
            ForEach(students) { membership in
                studentRow(membership)
            }
        }
    }

    private func classList(_ classes: [ServerAPI.AcademyClassSummary]) -> some View {
        entityList(empty: "등록된 반이 없습니다.") {
            ForEach(classes) { academyClass in
                classRow(academyClass)
            }
        }
    }

    private func inviteList(_ invites: [ServerAPI.TeacherAcademyInvite]) -> some View {
        entityList(empty: "발급된 초대 코드가 없습니다.") {
            ForEach(invites) { invite in
                inviteRow(invite)
            }
        }
    }

    private func attendanceList(_ detail: ServerAPI.AdminAcademyDetail) -> some View {
        entityList(empty: "최근 출결 세션과 기록이 없습니다.") {
            if !detail.attendanceSessions.isEmpty {
                Text("최근 수업 회차")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.ink)
                ForEach(detail.attendanceSessions) { session in
                    attendanceRow(session)
                }
            }
            if !(detail.attendanceRecords ?? []).isEmpty {
                Text("최근 학생 출결")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.ink)
                    .padding(.top, Tokens.Space.s2)
                ForEach(detail.attendanceRecords ?? []) { record in
                    attendanceRecordRow(record)
                }
            }
            if !(detail.attendanceAudits ?? []).isEmpty {
                Text("최근 감사 이력")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.ink)
                    .padding(.top, Tokens.Space.s2)
                ForEach(detail.attendanceAudits ?? []) { audit in
                    attendanceAuditRow(audit)
                }
            }
        }
    }

    private func entityList<Content: View>(
        empty: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if isCurrentSectionEmpty {
                Text(empty)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                content()
            }
        }
    }

    private var isCurrentSectionEmpty: Bool {
        guard let detail = model.detail else { return true }
        return switch detailSection {
        case .overview: false
        case .analytics: detail.analytics == nil
        case .staff: detail.staff.isEmpty
        case .students: detail.students.isEmpty
        case .classes: detail.classes.isEmpty
        case .classwork: (detail.classWeeks ?? []).isEmpty
        case .invites: detail.invites.isEmpty
        case .attendance:
            detail.attendanceSessions.isEmpty
                && (detail.attendanceRecords ?? []).isEmpty
                && (detail.attendanceAudits ?? []).isEmpty
        }
    }

    private func staffRow(_ member: ServerAPI.TeacherAcademyStaff) -> some View {
        entityRow(
            title: member.user?.name.isEmpty == false ? member.user!.name : "이름 없음",
            subtitle: [roleLabel(member.role), statusLabel(member.status), member.user?.email,
                       member.user?.accountStatus.map { "계정 \(statusLabel($0))" },
                       member.requestedAt.map { "요청 \(displayDate($0))" },
                       member.joinedAt.map { "합류 \(displayDate($0))" },
                       member.reviewedAt.map { "검토 \(displayDate($0))" },
                       member.rejectedAt.map { "반려 \(displayDate($0))" },
                       member.revokedAt.map { "해제 \(displayDate($0))" },
                       member.reviewedBy.map { "검토자 \($0.name)" }]
                .compactMap { $0 }.joined(separator: " · "),
            icon: member.role == "OWNER" ? "person.crop.circle.badge.checkmark" : "person.crop.circle",
            actions: staffActions(member))
    }

    private func studentRow(_ membership: ServerAPI.AdminAcademyStudent) -> some View {
        entityRow(
            title: membership.student.name,
            subtitle: [statusLabel(membership.status), membership.academyClass?.name,
                       gradeLabel(membership.student.schoolGrade), membership.student.school?.name,
                       membership.joinSource.map(joinSourceLabel),
                       membership.requestedAt.map { "신청 \(displayDate($0))" },
                       membership.dataConsentAt.map { "동의 \(displayDate($0))" },
                       membership.approvedAt.map { "승인 \(displayDate($0))" },
                       membership.rejectedAt.map { "반려 \(displayDate($0))" },
                       membership.leftAt.map { "해제 \(displayDate($0))" },
                       membership.reviewedBy.map { "검토자 \($0.name)" }]
                .compactMap { $0 }.joined(separator: " · "),
            icon: "graduationcap",
            actions: studentActions(membership),
            assignmentMembership: membership.status == "APPROVED" ? membership : nil)
    }

    private func classRow(_ academyClass: ServerAPI.AcademyClassSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            entityRow(
                title: academyClass.name,
                subtitle: [academyClass.isActive == false ? "보관됨" : "운영 중",
                           academyClass.homeroomTeacher.map { "담임 \($0.name)" },
                           academyClass.coTeachers?.isEmpty == false
                                ? "보조 \(academyClass.coTeachers!.map(\.name).joined(separator: ", "))" : nil,
                           academyClass.archivedAt.map { "보관 \(displayDate($0))" }]
                    .compactMap { $0 }.joined(separator: " · "),
                icon: academyClass.isActive == false ? "archivebox" : "person.3",
                actions: classActions(academyClass))
            if !(academyClass.teacherHistory ?? []).isEmpty {
                DisclosureGroup("담임 변경 이력 \(academyClass.teacherHistory?.count ?? 0)건") {
                    ForEach(Array((academyClass.teacherHistory ?? []).reversed()), id: \.stableID) { history in
                        Text("\(displayOptionalDate(history.changedAt)) · \(history.previousTeacher?.name ?? "없음") → \(history.nextTeacher?.name ?? "없음") · 변경 \(history.changedBy?.name ?? "확인 불가")")
                            .font(.mMicro).foregroundStyle(Tokens.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 3)
                    }
                }
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .padding(.horizontal, Tokens.Space.s2).padding(.bottom, Tokens.Space.s2)
            }
            if !(academyClass.lifecycleHistory ?? []).isEmpty {
                DisclosureGroup("반 생명주기 이력 \(academyClass.lifecycleHistory?.count ?? 0)건") {
                    ForEach(Array((academyClass.lifecycleHistory ?? []).reversed()), id: \.stableID) { history in
                        Text("\(displayOptionalDate(history.occurredAt)) · \(history.action == "ARCHIVED" ? "보관" : "복구") · \(history.actor?.name ?? history.actorType) · 학생 \(history.unassignedStudentCount)명 / 회차 \(history.canceledSessionCount)개 / 초대 \(history.revokedInviteCount)개")
                            .font(.mMicro).foregroundStyle(Tokens.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 3)
                    }
                }
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .padding(.horizontal, Tokens.Space.s2).padding(.bottom, Tokens.Space.s2)
            }
        }
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    private func inviteRow(_ invite: ServerAPI.TeacherAcademyInvite) -> some View {
        entityRow(
            title: invite.label,
            subtitle: [
                statusLabel(invite.displayState),
                "\(invite.useCount)/\(invite.maxUses)회",
                invite.academyClass?.name ?? "전체 반",
                invite.expiresAt.map { "만료 \(displayDate($0))" },
                invite.createdBy.map { "생성 \($0.name)" },
            ].compactMap { $0 }.joined(separator: " · "),
            icon: "link",
            trailing: invite.token?.isEmpty == false ? invite.token : invite.code,
            actions: inviteActions(invite))
    }

    private func classworkRow(_ week: ServerAPI.AdminAcademyWeek) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(Tokens.primary)
                    .frame(width: 30, height: 30)
                    .background(Tokens.primary.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(week.academyClass?.name ?? "삭제된 반") · \(week.title)")
                        .font(.mCaption).foregroundStyle(Tokens.ink)
                    Text("\(week.academicYear)년 \(week.weekNumber)주차 · \(statusLabel(week.status)) · 개념 \(week.concepts.count)개")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                    Text([week.createdBy.map { "등록 \($0.name)" },
                          week.updatedBy.map { "수정 \($0.name)" },
                          week.updatedAt.map(displayDate)]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Spacer(minLength: 0)
            }
            if !week.lessonSummary.isEmpty {
                Text(week.lessonSummary)
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !week.concepts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(week.concepts) { concept in
                            Text(concept.conceptTitle)
                                .font(.mMicro).foregroundStyle(Tokens.primary)
                                .padding(.horizontal, 8).frame(minHeight: 28)
                                .background(Tokens.primary.opacity(0.08), in: Capsule())
                        }
                    }
                }
            }
            if !week.assignmentTitle.isEmpty || !week.assignmentInstructions.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(week.assignmentTitle.isEmpty ? "과제" : week.assignmentTitle)
                        .font(.mCaption).foregroundStyle(Tokens.ink)
                    if !week.assignmentInstructions.isEmpty {
                        Text(week.assignmentInstructions)
                            .font(.mMicro).foregroundStyle(Tokens.text2)
                    }
                    if let dueAt = week.dueAt {
                        Text("마감 \(displayDate(dueAt))")
                            .font(.mMicro).foregroundStyle(Tokens.warningInk)
                    }
                }
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.paper2,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            }
            ForEach(week.files) { file in
                Button {
                    Task { await model.preview(file, from: week) }
                } label: {
                    HStack(spacing: Tokens.Space.s2) {
                        Image(systemName: "doc.fill")
                        Text(file.originalName).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(ByteCountFormatter.string(
                            fromByteCount: Int64(file.sizeBytes), countStyle: .file))
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                        if model.actionID == "preview:\(file.id)" { ProgressView() }
                        else { Image(systemName: "arrow.down.circle") }
                    }
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(model.actionID != nil)
                .accessibilityHint("인증 후 파일을 내려받아 미리 봅니다")
            }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func attendanceRow(_ session: ServerAPI.AdminAcademyAttendanceSession) -> some View {
        entityRow(
            title: session.academyClass?.name ?? "반 정보 없음",
            subtitle: [session.dateKey, attendanceModeLabel(session.attendanceMode),
                       statusLabel(session.state ?? ""),
                       session.startsAt.map { "시작 \(displayDate($0))" },
                       session.endsAt.map { "종료 \(displayDate($0))" },
                       session.rosterCount.map { "명단 \($0)명" },
                       session.createdBy.map { "생성 \($0.name)" }]
                .compactMap { $0 }.joined(separator: " · "),
            icon: "checkmark.circle",
            trailing: session.code?.isEmpty == false ? session.code : nil,
            actions: attendanceActions(session))
    }

    private func attendanceRecordRow(_ record: ServerAPI.AdminAcademyAttendanceRecord) -> some View {
        entityRow(
            title: record.student?.name ?? "학생 정보 없음",
            subtitle: [record.academyClass?.name, record.dateKey,
                       attendanceStatusLabel(record.status), record.note.isEmpty ? nil : record.note]
                .compactMap { $0 }.joined(separator: " · "),
            icon: "person.crop.circle.badge.clock",
            actions: [intent(
                id: "attendance-record-\(record.id)",
                title: "출결 기록 보정",
                message: "출결 상태와 보정 사유를 입력합니다.",
                button: "출결 보정",
                destructive: false,
                kind: .editAttendance(recordID: record.id))])
    }

    private func attendanceAuditRow(_ audit: ServerAPI.AdminAcademyAttendanceAudit) -> some View {
        let transition = "\(attendanceStatusLabel(audit.previousStatus)) → \(attendanceStatusLabel(audit.nextStatus))"
        return entityRow(
            title: audit.student?.name ?? "학생 정보 없음",
            subtitle: [audit.academyClass?.name, transition,
                       audit.actor?.name, audit.note.isEmpty ? nil : audit.note]
                .compactMap { $0 }.joined(separator: " · "),
            icon: "clock.arrow.circlepath")
    }

    private func staffActions(_ member: ServerAPI.TeacherAcademyStaff) -> [MutationIntent] {
        guard member.role != "OWNER" else { return [] }
        switch member.status {
        case "PENDING":
            return [
                intent(id: "staff-approve-\(member.id)", title: "교사 소속을 승인할까요?",
                       message: "활성 교사 계정인지 확인한 뒤 학원 직원으로 연결합니다.",
                       button: "승인", destructive: false,
                       kind: .staff(id: member.id, action: "APPROVE")),
                intent(id: "staff-reject-\(member.id)", title: "교사 요청을 반려할까요?",
                       message: "이 교사의 학원 소속 요청을 반려합니다.",
                       button: "반려", destructive: true,
                       kind: .staff(id: member.id, action: "REJECT")),
            ]
        case "ACTIVE":
            return [
                intent(id: "owner-\(member.id)", title: "원장 권한을 이전할까요?",
                       message: "현재 원장은 일반 교사가 되고 이 교사가 새 원장이 됩니다.",
                       button: "원장 이전", destructive: false,
                       kind: .owner(staffID: member.id)),
                intent(id: "staff-revoke-\(member.id)", title: "교사 권한을 해제할까요?",
                       message: "담당 반은 원장에게 자동 이전되고 공동 교사 지정도 제거됩니다.",
                       button: "권한 해제", destructive: true,
                       kind: .staff(id: member.id, action: "REVOKE")),
            ]
        case "REJECTED", "REVOKED":
            return [intent(
                id: "staff-restore-\(member.id)", title: "교사 소속을 복구할까요?",
                message: "다른 학원 소속 여부와 교사 계정 상태를 확인한 뒤 복구합니다.",
                button: "복구", destructive: false,
                kind: .staff(id: member.id, action: "RESTORE"))]
        default: return []
        }
    }

    private func studentActions(_ membership: ServerAPI.AdminAcademyStudent) -> [MutationIntent] {
        switch membership.status {
        case "PENDING":
            return [
                intent(id: "student-approve-\(membership.id)", title: "학생 소속을 승인할까요?",
                       message: "다른 학원 소속 여부를 확인한 뒤 승인합니다.",
                       button: "승인", destructive: false,
                       kind: .student(id: membership.id, action: "APPROVE")),
                intent(id: "student-reject-\(membership.id)", title: "학생 요청을 반려할까요?",
                       message: "이 학생의 학원 가입 요청을 반려합니다.",
                       button: "반려", destructive: true,
                       kind: .student(id: membership.id, action: "REJECT")),
            ]
        case "APPROVED":
            return [intent(
                id: "student-remove-\(membership.id)", title: "학생을 학원에서 내보낼까요?",
                message: "학생의 반 배정도 함께 해제됩니다.",
                button: "내보내기", destructive: true,
                kind: .student(id: membership.id, action: "REMOVE"))]
        case "REJECTED", "LEFT":
            return [intent(
                id: "student-restore-\(membership.id)", title: "학생 소속을 복구할까요?",
                message: "다른 학원 소속 여부와 학생 계정 상태를 확인한 뒤 복구합니다.",
                button: "복구", destructive: false,
                kind: .student(id: membership.id, action: "RESTORE"))]
        default: return []
        }
    }

    private func classActions(_ academyClass: ServerAPI.AcademyClassSummary) -> [MutationIntent] {
        let active = academyClass.isActive != false
        var actions = [
            intent(
                id: "class-operations-\(academyClass.id)",
                title: "수업 일정·출석 방식",
                message: "수업 운영 설정을 편집합니다.",
                button: "일정·출석 설정",
                destructive: false,
                kind: .editClassOperations(classID: academyClass.id)),
            intent(
                id: "class-homeroom-\(academyClass.id)",
                title: "담임 선생님 이전",
                message: "새 담임과 기존 담임의 보조 교사 유지 여부를 선택합니다.",
                button: "담임 이전",
                destructive: false,
                kind: .transferClassHomeroom(classID: academyClass.id)),
        ]
        actions.append(intent(
            id: "class-\(academyClass.id)-\(active)",
            title: active ? "반을 보관할까요?" : "반을 복구할까요?",
            message: active
                ? "학생 배정이 해제되고 예정 출결 세션과 연결된 초대가 취소됩니다."
                : "반을 다시 활성화합니다. 학생과 교사는 자동 재배정되지 않습니다.",
            button: active ? "반 보관" : "반 복구",
            destructive: active,
            kind: .academyClass(id: academyClass.id, action: active ? "DEACTIVATE" : "ACTIVATE")))
        return actions
    }

    private func inviteActions(_ invite: ServerAPI.TeacherAcademyInvite) -> [MutationIntent] {
        let active = invite.displayState.uppercased() == "ACTIVE"
        return [intent(
            id: "invite-\(invite.id)-\(active)",
            title: active ? "초대를 비활성화할까요?" : "초대를 다시 활성화할까요?",
            message: active
                ? "이 코드를 이용한 새 가입을 즉시 막습니다."
                : "유효기간과 사용 횟수, 연결 반 상태를 확인한 뒤 활성화합니다.",
            button: active ? "비활성화" : "다시 활성화",
            destructive: active,
            kind: .invite(id: invite.id, action: active ? "REVOKE" : "RESTORE"))]
    }

    private func attendanceActions(_ session: ServerAPI.AdminAcademyAttendanceSession) -> [MutationIntent] {
        guard session.attendanceMode == "SELF_CODE",
              !["CLOSED", "CANCELED"].contains(session.state?.uppercased() ?? "") else { return [] }
        return [intent(
            id: "attendance-\(session.id)", title: "출결 코드를 재발급할까요?",
            message: "기존 코드는 즉시 무효화되고 로그인 시도 제한 기록도 초기화됩니다.",
            button: "코드 재발급", destructive: false,
            kind: .attendance(sessionID: session.id))]
    }

    private func intent(
        id: String, title: String, message: String, button: String,
        destructive: Bool, kind: MutationKind
    ) -> MutationIntent {
        MutationIntent(id: id, title: title, message: message,
                       button: button, destructive: destructive, kind: kind)
    }

    private func entityRow(
        title: String, subtitle: String, icon: String, trailing: String? = nil,
        actions: [MutationIntent] = [],
        assignmentMembership: ServerAPI.AdminAcademyStudent? = nil
    ) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Image(systemName: icon)
                .foregroundStyle(Tokens.primary)
                .frame(width: 32, height: 32)
                .background(Tokens.primary.opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.mCaption).foregroundStyle(Tokens.ink).lineLimit(1)
                Text(subtitle).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(2)
            }
            Spacer(minLength: Tokens.Space.s2)
            if let trailing {
                Text(trailing)
                    .font(.mMicro.monospacedDigit().weight(.bold))
                    .foregroundStyle(Tokens.primary)
                    .textSelection(.enabled)
            }
            if !actions.isEmpty || assignmentMembership != nil {
                Menu {
                    if let membership = assignmentMembership {
                        Section("반 배정") {
                            Button("미배정") {
                                Task {
                                    await model.assignStudentClass(
                                        membershipID: membership.id, classID: nil)
                                }
                            }
                            ForEach(model.detail?.classes.filter { $0.isActive != false } ?? []) { academyClass in
                                Button(academyClass.name) {
                                    Task {
                                        await model.assignStudentClass(
                                            membershipID: membership.id, classID: academyClass.id)
                                    }
                                }
                            }
                        }
                    }
                    ForEach(actions) { action in
                        Button(role: action.destructive ? .destructive : nil) {
                            choose(action)
                        } label: {
                            Text(action.button)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Tokens.primary)
                .disabled(model.actionID != nil)
                .accessibilityLabel("\(title) 관리")
            }
        }
        .padding(Tokens.Space.s2)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityElement(children: (!actions.isEmpty || assignmentMembership != nil)
                              ? .contain : .combine)
    }

    private func execute(_ kind: MutationKind) async {
        switch kind {
        case let .staff(id, action):
            await model.updateStaff(staffID: id, action: action)
        case let .owner(staffID):
            await model.transferOwner(to: staffID)
        case let .student(id, action):
            await model.updateStudent(membershipID: id, action: action)
        case let .academyClass(id, action):
            await model.updateClass(classID: id, action: action)
        case .editClassOperations, .transferClassHomeroom:
            break
        case let .invite(id, action):
            await model.updateInvite(inviteID: id, action: action)
        case let .attendance(sessionID):
            await model.regenerateAttendanceCode(sessionID: sessionID)
        case .editAttendance:
            break
        }
    }

    private func choose(_ action: MutationIntent) {
        switch action.kind {
        case let .editClassOperations(classID):
            operationsClass = model.detail?.classes.first { $0.id == classID }
        case let .transferClassHomeroom(classID):
            homeroomClass = model.detail?.classes.first { $0.id == classID }
        case let .editAttendance(recordID):
            attendanceRecord = model.detail?.attendanceRecords?.first { $0.id == recordID }
        default:
            mutationIntent = action
        }
    }

    private func metric(_ value: Int, _ label: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)").font(.mHeading.monospacedDigit())
            Text(label).font(.mMicro).lineLimit(1)
        }
        .foregroundStyle(warning && value > 0 ? Tokens.danger : Tokens.ink)
        .padding(Tokens.Space.s2)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(warning && value > 0 ? Tokens.danger.opacity(0.08) : Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    private func infoCard<Content: View>(
        title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.mCaption).foregroundStyle(Tokens.ink)
            content()
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            Spacer(minLength: Tokens.Space.s2)
            Text(value).font(.mCaption).foregroundStyle(Tokens.ink).multilineTextAlignment(.trailing)
        }
    }

    private func academyImage(_ academy: ServerAPI.AdminAcademyListItem, size: CGFloat = 38) -> some View {
        Group {
            if let raw = academy.profileImageURL, let url = URL(string: raw) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(Tokens.primary)
                }
            } else {
                Image(systemName: "building.2.fill")
                    .foregroundStyle(Tokens.primary)
            }
        }
        .frame(width: size, height: size)
        .background(Tokens.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
    }

    private func statePane<Content: View>(
        icon: String?, title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Tokens.primary)
            }
            Text(title).font(.mHeading).foregroundStyle(Tokens.ink)
            content()
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: Tokens.Space.s2) {
            Image(systemName: "wifi.exclamationmark").foregroundStyle(Tokens.danger)
            Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await model.loadList() } }
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyList: some View {
        VStack(spacing: Tokens.Space.s2) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 28))
                .foregroundStyle(Tokens.text3)
            Text("조건에 맞는 학원이 없습니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.ink)
            Button("필터 초기화") {
                model.searchText = ""
                model.status = "ALL"
                Task { await model.loadList(pageNumber: 1) }
            }
            .font(.mCaption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var renameEditor: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text("앱과 웹에 표시할 학원 이름을 입력하세요.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                TextField("학원 이름", text: $renameDraft)
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, Tokens.Space.s3)
                    .frame(minHeight: 50)
                    .background(Tokens.paper,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm,
                                                     style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .strokeBorder(Tokens.line, lineWidth: 1)
                    }
                Text("2자 이상 80자 이하")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                Spacer(minLength: 0)
                Button("이름 저장") {
                    let name = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    showsRenameEditor = false
                    Task { await model.updateProfile(action: "RENAME", name: name) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
                          || renameDraft.trimmingCharacters(in: .whitespacesAndNewlines).count > 80)
            }
            .padding(Tokens.Space.s4)
            .background(Tokens.surface)
            .navigationTitle("학원명 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showsRenameEditor = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var contractEditor: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text("계약을 연장하면 만료로 보관된 학원은 이전 운영 상태로 복구되고, 원장 교사 접근 기한도 함께 갱신됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                DatePicker(
                    "새 계약 만료일",
                    selection: $contractDraft,
                    in: minimumContractDate...,
                    displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(Tokens.primary)
                Spacer(minLength: 0)
                Button("계약 만료일 저장") {
                    let date = contractDraft
                    showsContractEditor = false
                    Task { await model.updateContract(endsAt: date) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Tokens.Space.s4)
            .background(Tokens.surface)
            .navigationTitle("계약 연장")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showsContractEditor = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var minimumContractDate: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400)
    }

    private func suggestedContractDate(_ raw: String?) -> Date {
        let baseline = shortISODate(raw) ?? Date()
        let suggested = Calendar.current.date(byAdding: .month, value: 1, to: baseline)
            ?? baseline.addingTimeInterval(86_400 * 30)
        return max(suggested, minimumContractDate)
    }

    private func shortISODate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private func displayDate(_ raw: String) -> String {
        guard let date = shortISODate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }

    private func displayOptionalDate(_ raw: String?) -> String {
        raw.map(displayDate) ?? "시각 미확인"
    }

    private func availableProfileAction(_ status: String) -> String? {
        switch status.uppercased() {
        case "ACTIVE": "PAUSE"
        case "PAUSED": "ACTIVATE"
        case "REJECTED": "REOPEN"
        default: nil
        }
    }

    private func profileActionButton(_ action: String?) -> String {
        switch action {
        case "PAUSE": "운영 일시중지"
        case "ACTIVATE": "운영 재개"
        case "REOPEN": "재검토 대기로 복구"
        default: "상태 변경"
        }
    }

    private func profileActionIcon(_ action: String) -> String {
        switch action {
        case "PAUSE": "pause.circle"
        case "ACTIVATE": "play.circle"
        default: "arrow.uturn.backward.circle"
        }
    }

    private func profileActionTitle(_ action: String?) -> String {
        switch action {
        case "PAUSE": "학원 운영을 일시중지할까요?"
        case "ACTIVATE": "학원 운영을 재개할까요?"
        case "REOPEN": "학원을 재검토 대기로 복구할까요?"
        default: "학원 상태를 변경할까요?"
        }
    }

    private func profileActionMessage(_ action: String?) -> String {
        switch action {
        case "PAUSE": "학원 데이터는 유지되지만 교사와 학생의 운영 기능이 제한될 수 있습니다."
        case "ACTIVATE": "계약 상태를 확인한 뒤 학원 운영 기능을 다시 활성화합니다."
        case "REOPEN": "반려된 학원과 원장 소속을 승인 대기 상태로 복구합니다."
        default: "변경 후 학원 상세 상태를 다시 확인합니다."
        }
    }

    private func statusCount(_ status: String) -> Int {
        guard let page = model.page else { return 0 }
        if status == "ALL" { return page.statusCounts.values.reduce(0, +) }
        return page.statusCounts[status] ?? 0
    }

    private func statusLabel(_ status: String) -> String {
        switch status.uppercased() {
        case "ALL": "전체"
        case "ACTIVE", "APPROVED", "OPEN": "운영 중"
        case "PENDING": "대기"
        case "PAUSED": "일시중지"
        case "REJECTED": "반려"
        case "ARCHIVED": "보관됨"
        case "REVOKED": "폐기"
        case "EXPIRED": "만료"
        case "CLOSED": "종료"
        case "CANCELED": "취소"
        default: status.isEmpty ? "상태 미확인" : status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status.uppercased() {
        case "ACTIVE": Tokens.success
        case "PENDING": Tokens.warning
        case "REJECTED": Tokens.danger
        default: Tokens.text2
        }
    }

    private func roleLabel(_ role: String) -> String {
        role.uppercased() == "OWNER" ? "원장" : "교사"
    }

    private func gradeLabel(_ grade: Int?) -> String? {
        guard let grade else { return nil }
        return grade <= 6 ? "초\(grade)" : grade <= 9 ? "중\(grade - 6)" : "고\(grade - 9)"
    }

    private func joinSourceLabel(_ source: String) -> String {
        switch source.uppercased() {
        case "INVITE": "초대 가입"
        case "REQUEST": "직접 신청"
        case "ADMIN": "운영자 등록"
        default: source
        }
    }

    private func attendanceModeLabel(_ mode: String?) -> String? {
        guard let mode else { return nil }
        return mode == "SELF_CODE" ? "코드 출석" : "교사 기록"
    }

    private func attendanceStatusLabel(_ status: String?) -> String {
        switch status?.uppercased() {
        case "PRESENT": "출석"
        case "LATE": "지각"
        case "ABSENT": "결석"
        case "EXCUSED": "인정결석"
        case .none: "미기록"
        default: status ?? "미기록"
        }
    }

    private func planLabel(_ plan: String?) -> String {
        guard let plan, !plan.isEmpty else { return "상품 미지정" }
        return switch plan.uppercased() {
        case "ACADEMY_PRO": "프로 요금제"
        case "ACADEMY_STANDARD": "스탠다드 요금제"
        case "ACADEMY_MOCK_INCLUDED": "모의고사 포함"
        default: plan
        }
    }

    private func applicantLabel(_ applicant: ServerAPI.AdminAcademyApplicant?) -> String {
        guard let applicant else { return "정보 없음" }
        return applicant.email.isEmpty ? applicant.name : "\(applicant.name) · \(applicant.email)"
    }

    private func contractPeriod(_ academy: ServerAPI.AdminAcademyListItem) -> String {
        "\(shortDate(academy.contractStartsAt)) ~ \(shortDate(academy.contractEndsAt))"
    }

    private func shortDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "미정" }
        let input = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fractional.date(from: raw) ?? input.date(from: raw) else {
            return String(raw.prefix(10))
        }
        let output = DateFormatter()
        output.locale = Locale(identifier: "ko_KR")
        output.timeZone = TimeZone(identifier: "Asia/Seoul")
        output.dateFormat = "yyyy.M.d"
        return output.string(from: date)
    }

    private func requestDebugLandscapeIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-forceLandscape"),
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
            assertionFailure("가로 화면 전환 실패: \(error.localizedDescription)")
        }
        #endif
    }

}
