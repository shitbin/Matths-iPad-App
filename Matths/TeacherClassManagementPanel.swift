import Foundation
import SwiftUI

/// 반 생성·일정·출결 정책·보관을 앱 안에서 끝내는 교사 작업대.
struct TeacherClassManagementPanel: View {
    let dashboard: ServerAPI.TeacherAcademyDashboard
    @ObservedObject var model: TeacherAcademyScreenModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsEditor = false
    @State private var editingClass: ServerAPI.AcademyClassSummary?
    @State private var draft = TeacherClassManagementPanel.defaultDraft()
    @State private var archivingClass: ServerAPI.AcademyClassSummary?
    @State private var managingTeachersClass: ServerAPI.AcademyClassSummary?
    @State private var selectedCoTeacherID = ""
    @State private var selectedHomeroomID = ""
    @State private var keepPreviousAsCoTeacher = true
    @State private var confirmsHomeroomTransfer = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            panelHeader

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Tokens.Space.s2) {
                    if dashboard.classes.isEmpty {
                        emptyState("활성 반이 없습니다", "첫 반을 만들고 학생을 배정해 주세요.")
                    } else {
                        ForEach(dashboard.classes) { academyClass in
                            classCard(academyClass)
                        }
                    }
                    if dashboard.isOwner, !(dashboard.archivedClasses ?? []).isEmpty {
                        Text("보관된 반")
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, Tokens.Space.s2)
                        ForEach(dashboard.archivedClasses ?? []) { academyClass in
                            archivedCard(academyClass)
                        }
                    }
                }
            }
            .refreshable { await model.load() }
        }
        .compactHeightSheet(isPresented: $showsEditor) { editor }
        .compactHeightSheet(item: $managingTeachersClass) { academyClass in
            teacherAssignmentEditor(academyClass)
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-teacherClassesEditorFixture"),
               !showsEditor {
                startNew()
            } else if ProcessInfo.processInfo.arguments.contains("-teacherClassTeachersFixture"),
                      managingTeachersClass == nil,
                      let first = dashboard.classes.first {
                startTeacherManagement(first)
            }
        }
        #endif
        .confirmationDialog(
            "이 반을 보관할까요?",
            isPresented: Binding(
                get: { archivingClass != nil },
                set: { if !$0 { archivingClass = nil } }),
            titleVisibility: .visible,
            presenting: archivingClass
        ) { academyClass in
            Button("\(academyClass.name) 보관", role: .destructive) {
                archivingClass = nil
                Task { await model.archiveClass(academyClass) }
            }
            Button("취소", role: .cancel) { archivingClass = nil }
        } message: { _ in
            Text("학생의 반 배정이 해제되고 예정 출결 회차와 연결된 초대가 취소됩니다. 과거 기록은 보존됩니다.")
        }
    }

    @ViewBuilder private var panelHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                panelTitle
                newClassButton
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: Tokens.Space.s3) {
                panelTitle
                Spacer(minLength: 0)
                newClassButton
                    .frame(width: 120)
            }
        }
    }

    private var panelTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("반 설정").font(.mBodyB).foregroundStyle(Tokens.ink)
            Text("수업 일정과 출석 방식을 학생에게 적용합니다.")
                .font(.mMicro).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var newClassButton: some View {
        Button { startNew() } label: { Label("새 반", systemImage: "plus") }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.actionID != nil)
    }

    private func classCard(_ academyClass: ServerAPI.AcademyClassSummary) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                HStack(spacing: Tokens.Space.s2) {
                    Text(academyClass.name).font(.mBodyB).foregroundStyle(Tokens.ink)
                    if let count = academyClass.studentCount {
                        Text("\(count)명").font(.mMicro).foregroundStyle(Tokens.primary)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Tokens.primarySoft, in: Capsule())
                    }
                }
                Text(scheduleLabel(academyClass))
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                Text(policyLabel(academyClass))
                    .font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Spacer(minLength: 0)
            if academyClass.canManage != false {
                Button("수정") { startEdit(academyClass) }
                    .buttonStyle(.bordered).disabled(model.actionID != nil)
                Button("담당") { startTeacherManagement(academyClass) }
                    .buttonStyle(.bordered).disabled(model.actionID != nil)
            }
            if dashboard.isOwner {
                Button(role: .destructive) { archivingClass = academyClass } label: {
                    Image(systemName: "archivebox").frame(width: 44, height: 44)
                }
                .tint(Tokens.dangerInk)
                .accessibilityLabel("\(academyClass.name) 반 보관")
                .disabled(model.actionID != nil)
            }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func archivedCard(_ academyClass: ServerAPI.AcademyClassSummary) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Image(systemName: "archivebox.fill").foregroundStyle(Tokens.text3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(academyClass.name).font(.mBodyB).foregroundStyle(Tokens.ink)
                Text("학생 배정과 초대를 다시 설정해야 합니다.")
                    .font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Spacer(minLength: 0)
            Button("복구") { Task { await model.restoreClass(academyClass) } }
                .buttonStyle(.bordered).disabled(model.actionID != nil)
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper2,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section("반 정보") {
                    TextField("반 이름", text: $draft.name)
                        .textInputAutocapitalization(.never)
                        .disabled(editingClass != nil)
                    if editingClass != nil {
                        Text("반 이름은 학생 기록과 연결되어 있어 고급 설정에서 변경합니다.")
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                    }
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text("수업 요일").font(.mCaption).foregroundStyle(Tokens.text2)
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s1), count: 7),
                            spacing: Tokens.Space.s1
                        ) {
                            ForEach(1...7, id: \.self) { day in
                                Button(Self.weekdayNames[day] ?? "-") { toggleDay(day) }
                                    .buttonStyle(.plain)
                                    .font(.mCaption)
                                    .foregroundStyle(draft.weekdays.contains(day) ? Tokens.onBrand : Tokens.ink)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(
                                        draft.weekdays.contains(day) ? Tokens.actionPrimary : Tokens.paper2,
                                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                                    .accessibilityLabel("\(Self.weekdayNames[day] ?? "")요일")
                                    .accessibilityValue(draft.weekdays.contains(day) ? "선택됨" : "선택 안 됨")
                            }
                        }
                    }
                    DatePicker("시작", selection: timeBinding(\.startTime), displayedComponents: .hourAndMinute)
                    DatePicker("종료", selection: timeBinding(\.endTime), displayedComponents: .hourAndMinute)
                    DatePicker("적용 시작일", selection: effectiveDateBinding, displayedComponents: .date)
                }
                Section {
                    Picker("출결 방식", selection: $draft.attendanceMode) {
                        Text("선생님 직접 입력").tag("MANUAL")
                        Text("학생 코드 입력").tag("SELF_CODE")
                    }
                    .pickerStyle(.segmented)
                    if draft.attendanceMode == "SELF_CODE" {
                        Stepper("수업 \(draft.opensBeforeMinutes)분 전부터 입력", value: $draft.opensBeforeMinutes, in: 0...120)
                        Stepper("시작 \(draft.lateAfterMinutes)분 뒤부터 지각", value: $draft.lateAfterMinutes, in: 0...120)
                        Stepper("시작 \(draft.closesAfterMinutes)분 뒤 마감", value: $draft.closesAfterMinutes, in: 1...240)
                    }
                } header: { Text("출결") }
                  footer: {
                      Text(draft.attendanceMode == "SELF_CODE"
                           ? "마감 시간은 지각 기준보다 늦게 설정해야 합니다."
                           : "학생 코드 없이 선생님이 출결부에서 직접 기록합니다.")
                  }
                if let error = model.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tokens.dangerInk) }
                }
            }
            .navigationTitle(editingClass == nil ? "새 반" : "반 설정")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(model.actionID != nil)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showsEditor = false }.disabled(model.actionID != nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.actionID == nil ? "저장" : "저장 중…") { save() }
                        .disabled(model.actionID != nil)
                }
            }
        }
    }

    private func teacherAssignmentEditor(_ academyClass: ServerAPI.AcademyClassSummary) -> some View {
        NavigationStack {
            Form {
                Section("현재 담당") {
                    LabeledContent("담임", value: displayTeacherName(academyClass.homeroomTeacher))
                    if (academyClass.coTeachers ?? []).isEmpty {
                        Text("공동 담당 선생님이 없습니다.").foregroundStyle(Tokens.text2)
                    } else {
                        ForEach(academyClass.coTeachers ?? []) { teacher in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(teacher.name).foregroundStyle(Tokens.ink)
                                    if !teacher.email.isEmpty {
                                        Text(teacher.email).font(.mCaption).foregroundStyle(Tokens.text3)
                                    }
                                }
                                Spacer(minLength: 0)
                                Button("해제", role: .destructive) {
                                    Task {
                                        await model.removeClassCoTeacher(
                                            classID: academyClass.id, teacherUserID: teacher.id)
                                        refreshManagingClass(academyClass.id)
                                    }
                                }
                                .tint(Tokens.dangerInk)
                                .disabled(model.actionID != nil)
                            }
                        }
                    }
                }
                let available = availableCoTeachers(for: academyClass)
                Section("공동 담당 추가") {
                    if available.isEmpty {
                        Text("추가할 수 있는 활성 선생님이 없습니다.").foregroundStyle(Tokens.text2)
                    } else {
                        Picker("선생님", selection: $selectedCoTeacherID) {
                            Text("선택").tag("")
                            ForEach(available) { teacher in Text(teacher.name).tag(teacher.id) }
                        }
                        Button("공동 담당으로 추가") {
                            let teacherID = selectedCoTeacherID
                            Task {
                                if await model.addClassCoTeacher(
                                    classID: academyClass.id, teacherUserID: teacherID) {
                                    selectedCoTeacherID = ""
                                    refreshManagingClass(academyClass.id)
                                }
                            }
                        }
                        .disabled(selectedCoTeacherID.isEmpty || model.actionID != nil)
                    }
                }
                if dashboard.isOwner {
                    let candidates = activeTeacherUsers.filter { $0.id != academyClass.homeroomTeacher?.id }
                    Section {
                        Picker("새 담임", selection: $selectedHomeroomID) {
                            Text("선택").tag("")
                            ForEach(candidates) { teacher in Text(teacher.name).tag(teacher.id) }
                        }
                        Toggle("현재 담임을 공동 담당으로 유지", isOn: $keepPreviousAsCoTeacher)
                        Button("담임 이전", role: .destructive) { confirmsHomeroomTransfer = true }
                            .tint(Tokens.dangerInk)
                            .disabled(selectedHomeroomID.isEmpty || model.actionID != nil)
                    } header: { Text("담임 이전") }
                      footer: { Text("담임 이전은 원장만 할 수 있습니다.") }
                }
                if let error = model.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tokens.dangerInk) }
                }
            }
            .navigationTitle("\(academyClass.name) 담당")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { managingTeachersClass = nil }.disabled(model.actionID != nil)
                }
            }
            .confirmationDialog(
                "담임 선생님을 이전할까요?",
                isPresented: $confirmsHomeroomTransfer,
                titleVisibility: .visible
            ) {
                Button("담임 이전", role: .destructive) {
                    let teacherID = selectedHomeroomID
                    Task {
                        if await model.transferClassHomeroom(
                            classID: academyClass.id,
                            teacherUserID: teacherID,
                            keepPreviousAsCoTeacher: keepPreviousAsCoTeacher) {
                            selectedHomeroomID = ""
                            refreshManagingClass(academyClass.id)
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("새 담임에게 반 관리 권한이 즉시 넘어갑니다.")
            }
        }
    }

    private func startNew() {
        editingClass = nil
        draft = Self.defaultDraft()
        model.errorMessage = nil
        model.noticeMessage = nil
        showsEditor = true
    }

    private func startEdit(_ academyClass: ServerAPI.AcademyClassSummary) {
        editingClass = academyClass
        let policy = academyClass.attendancePolicy
        draft = ServerAPI.TeacherAcademyClassDraft(
            name: academyClass.name,
            weekdays: academyClass.schedule?.weekdays ?? [2],
            startTime: academyClass.schedule?.startTime ?? "18:00",
            endTime: academyClass.schedule?.endTime ?? "20:00",
            effectiveFrom: academyClass.schedule?.effectiveFrom ?? Self.dateFormatter.string(from: Date()),
            attendanceMode: policy?.mode ?? "MANUAL",
            opensBeforeMinutes: policy?.opensBeforeMinutes ?? 10,
            lateAfterMinutes: policy?.lateAfterMinutes ?? 5,
            closesAfterMinutes: policy?.closesAfterMinutes ?? 20)
        model.errorMessage = nil
        model.noticeMessage = nil
        showsEditor = true
    }

    private func startTeacherManagement(_ academyClass: ServerAPI.AcademyClassSummary) {
        selectedCoTeacherID = ""
        selectedHomeroomID = ""
        keepPreviousAsCoTeacher = true
        model.errorMessage = nil
        model.noticeMessage = nil
        managingTeachersClass = academyClass
    }

    private var activeTeacherUsers: [ServerAPI.TeacherAcademyStaffUser] {
        (model.dashboard?.activeStaff ?? dashboard.activeStaff ?? []).compactMap(\.user)
    }

    private func availableCoTeachers(
        for academyClass: ServerAPI.AcademyClassSummary
    ) -> [ServerAPI.TeacherAcademyStaffUser] {
        let excluded = Set(([academyClass.homeroomTeacher?.id].compactMap { $0 })
            + (academyClass.coTeachers ?? []).map(\.id))
        return activeTeacherUsers.filter { !excluded.contains($0.id) }
    }

    private func refreshManagingClass(_ classID: String) {
        guard let updated = model.dashboard?.classes.first(where: { $0.id == classID }) else {
            managingTeachersClass = nil
            return
        }
        managingTeachersClass = updated
    }

    private func displayTeacherName(_ teacher: ServerAPI.TeacherAcademyStaffUser?) -> String {
        let name = teacher?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "미지정" : name
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.name.isEmpty else { model.errorMessage = "반 이름을 입력해 주세요."; return }
        guard !draft.weekdays.isEmpty else { model.errorMessage = "수업 요일을 한 개 이상 선택해 주세요."; return }
        guard Self.timeMinutes(draft.endTime) > Self.timeMinutes(draft.startTime) else {
            model.errorMessage = "종료 시간은 시작 시간보다 늦어야 합니다."
            return
        }
        if draft.attendanceMode == "SELF_CODE", draft.closesAfterMinutes <= draft.lateAfterMinutes {
            model.errorMessage = "출석 마감 시간은 지각 기준보다 늦어야 합니다."
            return
        }
        Task {
            if await model.saveClass(classID: editingClass?.id, draft: draft) {
                showsEditor = false
            }
        }
    }

    private func toggleDay(_ day: Int) {
        if draft.weekdays.contains(day) {
            draft.weekdays.removeAll { $0 == day }
        } else {
            draft.weekdays.append(day)
            draft.weekdays.sort()
        }
    }

    private func timeBinding(_ keyPath: WritableKeyPath<ServerAPI.TeacherAcademyClassDraft, String>) -> Binding<Date> {
        Binding(
            get: { Self.timeFormatter.date(from: draft[keyPath: keyPath]) ?? Date() },
            set: { draft[keyPath: keyPath] = Self.timeFormatter.string(from: $0) })
    }

    private var effectiveDateBinding: Binding<Date> {
        Binding(
            get: { Self.dateFormatter.date(from: draft.effectiveFrom) ?? Date() },
            set: { draft.effectiveFrom = Self.dateFormatter.string(from: $0) })
    }

    private func scheduleLabel(_ academyClass: ServerAPI.AcademyClassSummary) -> String {
        guard let schedule = academyClass.schedule else { return "일정 미설정" }
        let days = (schedule.weekdays ?? []).compactMap { Self.weekdayNames[$0] }.joined(separator: "·")
        let time = [schedule.startTime, schedule.endTime].compactMap { $0 }.joined(separator: "–")
        return [days, time].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func policyLabel(_ academyClass: ServerAPI.AcademyClassSummary) -> String {
        guard let policy = academyClass.attendancePolicy else { return "출결 정책은 수정 화면에서 확인하세요." }
        if policy.mode == "SELF_CODE" {
            return "학생 코드 · 지각 +\(policy.lateAfterMinutes ?? 5)분 · 마감 +\(policy.closesAfterMinutes ?? 20)분"
        }
        return "선생님 직접 출결"
    }

    private func emptyState(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
            Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private static let weekdayNames = [1: "일", 2: "월", 3: "화", 4: "수", 5: "목", 6: "금", 7: "토"]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func timeMinutes(_ value: String) -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
    }

    private static func defaultDraft() -> ServerAPI.TeacherAcademyClassDraft {
        ServerAPI.TeacherAcademyClassDraft(
            name: "",
            weekdays: [2],
            startTime: "18:00",
            endTime: "20:00",
            effectiveFrom: dateFormatter.string(from: Date()),
            attendanceMode: "MANUAL",
            opensBeforeMinutes: 10,
            lateAfterMinutes: 5,
            closesAfterMinutes: 20)
    }
}
