import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class TeacherClassworkPanelModel: ObservableObject {
    @Published var selectedClassID = ""
    @Published var classwork: ServerAPI.TeacherClasswork?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var showsEditor = false
    @Published var draft = TeacherClassworkPanelModel.blankDraft()
    @Published var selectedConceptKeys: Set<String> = []
    @Published var selectedFiles: [URL] = []
    @Published var conceptSearch = ""
    @Published var dueEnabled = false
    @Published var dueDate = Date().addingTimeInterval(86_400)
    @Published var previewURL: URL?

    private var loadGeneration = UUID()
    private var scopeGeneration = UUID()

    private func isTeacherOwner(_ owner: AccountRequestOwner, in store: AppStore) -> Bool {
        // A token/account snapshot does not include role. The canonical server
        // permits teacher (not admin/student) and separately enforces current
        // account activity, teacher expiry, academy membership and class access.
        owner.isCurrent(in: store) && store.authProvider == "server"
            && store.serverProfile?.role?.lowercased() == "teacher"
    }

    func reset() {
        scopeGeneration = UUID(); loadGeneration = UUID()
        selectedClassID = ""; classwork = nil; actionID = nil; isLoading = false
        showsEditor = false; selectedFiles = []; selectedConceptKeys = []; previewURL = nil
        draft = Self.blankDraft(); errorMessage = nil; noticeMessage = nil
    }

    func prepare(classes: [ServerAPI.AcademyClassSummary]) {
        guard selectedClassID.isEmpty, let first = classes.first else { return }
        selectedClassID = first.id
    }

    func load(owner: AccountRequestOwner, store: AppStore) async {
        guard isTeacherOwner(owner, in: store) else { return }
        guard !selectedClassID.isEmpty else {
            classwork = nil
            return
        }
        let classID = selectedClassID
        let account = DataScope.slot
        let authorization = owner.authorization
        if classwork?.academyClass.id != classID { classwork = nil }
        let generation = UUID()
        loadGeneration = generation
        isLoading = true
        defer { if generation == loadGeneration { isLoading = false } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyClasswork(classID: classID, authorization: authorization)
            guard generation == loadGeneration, classID == selectedClassID, account == DataScope.slot,
                  isTeacherOwner(owner, in: store) else { return }
            classwork = value
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-teacherClassworkEditorFixture"),
               !showsEditor {
                startNewWeek()
            }
            #endif
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, classID == selectedClassID, isTeacherOwner(owner, in: store) else { return }
            errorMessage = readable(error)
        }
        if generation == loadGeneration { isLoading = false }
    }

    func startNewWeek() {
        let year = classwork?.currentAcademicYear ?? Calendar.current.component(.year, from: Date())
        let usedWeeks = Set(classwork?.weeks.filter { $0.academicYear == year }.map(\.weekNumber) ?? [])
        let currentWeek = min(60, max(1, Calendar(identifier: .iso8601).component(.weekOfYear, from: Date())))
        let proposed = (currentWeek...60).first { !usedWeeks.contains($0) }
            ?? (1...60).first { !usedWeeks.contains($0) }
            ?? currentWeek
        draft = Self.blankDraft(year: year, week: proposed)
        selectedConceptKeys = []
        selectedFiles = []
        conceptSearch = ""
        dueEnabled = false
        dueDate = Date().addingTimeInterval(86_400)
        errorMessage = nil
        noticeMessage = nil
        showsEditor = true
    }

    func edit(_ week: ServerAPI.AcademyWeek) {
        let conceptKeys = week.concepts.map { reference in
            // Concept.id is a pipe-delimited SwiftUI identity, not the server
            // selection key. Use the catalog's canonical key for both display
            // selection and save. Keep an older reference intact if the latest
            // catalog no longer lists it; never silently drop the selection.
            allConcepts.first {
                $0.curriculumId == reference.curriculumId && $0.courseId == reference.courseId
                    && $0.unitId == reference.unitId && $0.conceptId == reference.conceptId
            }?.key ?? [reference.courseId, reference.unitId, reference.conceptId].joined(separator: "/")
        }
        draft = ServerAPI.TeacherClassWeekDraft(
            weekID: week.id,
            academicYear: week.academicYear,
            weekNumber: week.weekNumber,
            title: week.title,
            lessonSummary: week.lessonSummary,
            conceptKeys: conceptKeys,
            assignmentTitle: week.assignmentTitle,
            assignmentInstructions: week.assignmentInstructions,
            dueAt: "", assignmentOmr: week.assignmentOmr.map(AcademyAssignmentConfiguration.init))
        selectedConceptKeys = Set(conceptKeys)
        selectedFiles = []
        conceptSearch = ""
        if let dueAt = week.dueAt, let date = Self.serverDate(dueAt) {
            dueEnabled = true
            dueDate = date
        } else {
            dueEnabled = false
            dueDate = Date().addingTimeInterval(86_400)
        }
        errorMessage = nil
        noticeMessage = nil
        showsEditor = true
    }

    func toggleConcept(_ key: String) {
        if selectedConceptKeys.contains(key) {
            selectedConceptKeys.remove(key)
        } else if selectedConceptKeys.count < 30 {
            selectedConceptKeys.insert(key)
        } else {
            errorMessage = "한 주에는 개념을 최대 30개까지 선택할 수 있습니다."
        }
    }

    func installImportedFiles(_ urls: [URL]) {
        var unique = selectedFiles
        for url in urls where !unique.contains(url) { unique.append(url) }
        guard unique.count <= 10 else {
            errorMessage = "한 주차에는 새 파일을 최대 10개까지 선택할 수 있습니다."
            return
        }
        selectedFiles = unique
    }

    func save(owner: AccountRequestOwner, store: AppStore) async {
        guard isTeacherOwner(owner, in: store), actionID == nil, !selectedClassID.isEmpty else { return }
        let expectedGeneration = scopeGeneration
        let account = DataScope.slot
        let authorization = owner.authorization
        let classID = selectedClassID
        let assignmentTitle = draft.assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !assignmentTitle.isEmpty else {
            errorMessage = "과제 제목을 입력해 주세요."
            return
        }
        guard !selectedConceptKeys.isEmpty else {
            errorMessage = "이번 주에 배운 개념을 한 개 이상 선택해 주세요."
            return
        }
        if let message = draft.assignmentOmr?.validationMessage { errorMessage = message; return }
        if let existing = existingWeek,
           existing.files.count + selectedFiles.count > 10 {
            errorMessage = "기존 파일을 포함해 한 주차에는 최대 10개까지 등록할 수 있습니다."
            return
        }
        actionID = "save"
        defer { if expectedGeneration == scopeGeneration { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        var payload = draft
        payload.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.lessonSummary = draft.lessonSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.conceptKeys = selectedConceptKeys.sorted()
        payload.assignmentTitle = assignmentTitle
        payload.assignmentInstructions = draft.assignmentInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.dueAt = dueEnabled ? Self.dueFormatter.string(from: dueDate) : ""
        do {
            let response = try await ServerAPI.saveTeacherAcademyClassWeek(
                classID: classID, draft: payload, files: selectedFiles, authorization: authorization)
            guard expectedGeneration == scopeGeneration, classID == selectedClassID, account == DataScope.slot,
                  isTeacherOwner(owner, in: store) else { return }
            classwork = response
            showsEditor = false
            selectedFiles = []
            noticeMessage = draft.weekID == nil ? "새 주차 수업과 과제를 게시했습니다." : "주차 수업과 과제를 수정했습니다."
        } catch {
            guard expectedGeneration == scopeGeneration, account == DataScope.slot, isTeacherOwner(owner, in: store) else { return }
            errorMessage = readable(error)
        }
    }

    func delete(_ week: ServerAPI.AcademyWeek, owner: AccountRequestOwner, store: AppStore) async {
        guard isTeacherOwner(owner, in: store), actionID == nil, classwork?.weeks.contains(where: { $0.id == week.id }) == true else { return }
        let expectedGeneration = scopeGeneration
        let account = DataScope.slot
        let authorization = owner.authorization
        let classID = selectedClassID
        actionID = "delete-\(week.id)"
        defer { if expectedGeneration == scopeGeneration { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let response = try await ServerAPI.deleteTeacherAcademyClassWeek(
                classID: classID, weekID: week.id, authorization: authorization)
            guard expectedGeneration == scopeGeneration, classID == selectedClassID, account == DataScope.slot,
                  isTeacherOwner(owner, in: store) else { return }
            classwork = response
            noticeMessage = "\(week.weekNumber)주차를 삭제했습니다."
        } catch {
            guard expectedGeneration == scopeGeneration, account == DataScope.slot, isTeacherOwner(owner, in: store) else { return }
            errorMessage = readable(error)
        }
    }

    func removeFile(_ file: ServerAPI.AcademyWeek.File, from week: ServerAPI.AcademyWeek, owner: AccountRequestOwner, store: AppStore) async {
        guard isTeacherOwner(owner, in: store), actionID == nil, classwork?.weeks.contains(where: { $0.id == week.id }) == true else { return }
        let expectedGeneration = scopeGeneration
        let account = DataScope.slot
        let authorization = owner.authorization
        let classID = selectedClassID
        actionID = "file-\(file.id)"
        defer { if expectedGeneration == scopeGeneration { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let response = try await ServerAPI.removeTeacherAcademyClassWeekFile(
                classID: classID, weekID: week.id, fileID: file.id, authorization: authorization)
            guard expectedGeneration == scopeGeneration, classID == selectedClassID, account == DataScope.slot,
                  isTeacherOwner(owner, in: store) else { return }
            classwork = response
            noticeMessage = "파일을 삭제했습니다."
        } catch {
            guard expectedGeneration == scopeGeneration, account == DataScope.slot, isTeacherOwner(owner, in: store) else { return }
            errorMessage = readable(error)
        }
    }

    func preview(_ file: ServerAPI.AcademyWeek.File, from week: ServerAPI.AcademyWeek, owner: AccountRequestOwner, store: AppStore) async {
        guard isTeacherOwner(owner, in: store), actionID == nil, classwork?.weeks.contains(where: { $0.id == week.id }) == true else { return }
        let expectedGeneration = scopeGeneration
        let account = DataScope.slot
        let authorization = owner.authorization
        let classID = selectedClassID
        actionID = "preview-\(file.id)"
        defer { if expectedGeneration == scopeGeneration { actionID = nil } }
        errorMessage = nil
        do {
            let url = try await ServerAPI.downloadTeacherAcademyFile(
                classID: classID, weekID: week.id, file: file, account: account, authorization: authorization)
            guard expectedGeneration == scopeGeneration, classID == selectedClassID, account == DataScope.slot,
                  isTeacherOwner(owner, in: store) else { return }
            previewURL = url
        } catch {
            guard expectedGeneration == scopeGeneration, account == DataScope.slot, isTeacherOwner(owner, in: store) else { return }
            errorMessage = readable(error)
        }
    }

    var existingWeek: ServerAPI.AcademyWeek? {
        guard let id = draft.weekID else { return nil }
        return classwork?.weeks.first { $0.id == id }
    }

    var allConcepts: [ServerAPI.TeacherClassworkCatalogConcept] {
        classwork?.catalog.flatMap(\.units).flatMap(\.concepts) ?? []
    }

    func matchesSearch(_ concept: ServerAPI.TeacherClassworkCatalogConcept) -> Bool {
        let query = conceptSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return [concept.courseTitle, concept.unitTitle, concept.conceptTitle]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
    }

    private static func blankDraft(year: Int? = nil, week: Int = 1) -> ServerAPI.TeacherClassWeekDraft {
        ServerAPI.TeacherClassWeekDraft(
            weekID: nil,
            academicYear: year ?? Calendar.current.component(.year, from: Date()),
            weekNumber: week,
            title: "",
            lessonSummary: "",
            conceptKeys: [],
            assignmentTitle: "",
            assignmentInstructions: "",
            dueAt: "")
    }

    private static let dueFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    private static func serverDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: value)
            ?? ISO8601DateFormatter().date(from: value)
            ?? dueFormatter.date(from: value)
    }

    private func readable(_ error: Error) -> String {
        if (error as? ServerAPIError)?.statusCode == 403 { reset() }
        return (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 교사가 휴대전화 가로 화면에서도 웹 포털 없이 주차 수업과 과제를 관리하는 작업대.
struct TeacherClassworkPanel: View {
    let classes: [ServerAPI.AcademyClassSummary]
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = TeacherClassworkPanelModel()
    @State private var importingFiles = false
    @State private var deletingWeek: ServerAPI.AcademyWeek?
    @State private var confirmsDiscard = false
    @State private var owner: AccountRequestOwner?
    @State private var pickerOwner: AccountRequestOwner?
    @State private var deletionOwner: AccountRequestOwner?
    @State private var saveOwner: AccountRequestOwner?
    @State private var confirmsRegrade = false
    @State private var showsConceptPicker = false
    private var loadIdentity: String { model.selectedClassID + "|" + (owner?.id.uuidString ?? "none") }

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            toolbar
            feedback
            content
        }
        .task { owner = AccountRequestOwner(store: store); model.prepare(classes: classes) }
        .task(id: loadIdentity) {
            if let owner, owner.isCurrent(in: store) { await model.load(owner: owner, store: store) }
        }
        .onDisappear { owner = nil; resetInteractions(); model.reset() }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            owner = nil; resetInteractions(); model.reset()
        }
        .onChange(of: classes) { _, values in
            if !values.contains(where: { $0.id == model.selectedClassID && $0.canManage != false }) {
                model.reset(); model.prepare(classes: values.filter { $0.canManage != false })
                resetInteractions()
            }
        }
        .onChange(of: model.showsEditor) { _, presented in
            if presented { showsConceptPicker = model.selectedConceptKeys.isEmpty }
        }
        .compactHeightSheet(isPresented: $model.showsEditor) { editor }
        .compactHeightSheet(isPresented: previewPresented) {
            if let url = model.previewURL {
                CommunityFilePreview(url: url) { model.previewURL = nil }
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "이 주차를 삭제할까요?",
            isPresented: Binding(
                get: { deletingWeek != nil },
                set: { if !$0 { deletingWeek = nil } }),
            titleVisibility: .visible,
            presenting: deletingWeek
        ) { week in
            Button("\(week.weekNumber)주차 삭제", role: .destructive) {
                deletingWeek = nil
                guard let deletionOwner, deletionOwner.isCurrent(in: store) else { return }
                Task { await model.delete(week, owner: deletionOwner, store: store) }
            }
            Button("취소", role: .cancel) { deletingWeek = nil }
        } message: { week in
            Text("수업 내용과 과제 파일이 함께 삭제되며 되돌릴 수 없습니다: \(week.title)")
        }
    }

    private func resetInteractions() {
        deletingWeek = nil; importingFiles = false; pickerOwner = nil; deletionOwner = nil
        confirmsRegrade = false; saveOwner = nil
    }
    private func performOwned(_ action: @escaping @MainActor (AccountRequestOwner) async -> Void) {
        guard let owner, owner.isCurrent(in: store) else { return }
        Task { @MainActor in
            guard owner.isCurrent(in: store) else { return }
            await action(owner)
        }
    }

    private func requestSave() {
        guard model.actionID == nil, let owner, owner.isCurrent(in: store),
              store.serverProfile?.role?.lowercased() == "teacher" else { return }
        if let omr = model.draft.assignmentOmr, let existing = model.existingWeek?.assignmentOmr,
           omr != AcademyAssignmentConfiguration(existing) {
            saveOwner = owner; confirmsRegrade = true
        } else { performOwned { await model.save(owner: $0, store: store) } }
    }

    private var toolbar: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) { toolbarContents }
            } else {
                HStack(spacing: Tokens.Space.s2) { toolbarContents }
            }
        }
    }

    @ViewBuilder private var toolbarContents: some View {
        Picker("과제를 관리할 반", selection: $model.selectedClassID) {
            ForEach(classes) { academyClass in Text(academyClass.name).tag(academyClass.id) }
        }
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 220, alignment: .leading)
        .disabled(model.actionID != nil || model.showsEditor)
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
        Button { model.startNewWeek() } label: {
            Label("새 주차", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(model.actionID != nil || model.classwork == nil)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 120)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
    }

    @ViewBuilder private var feedback: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.dangerSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        } else if let notice = model.noticeMessage {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.mCaption).foregroundStyle(Tokens.successInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.successSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.classwork == nil {
            HStack(spacing: Tokens.Space.s2) {
                ProgressView().tint(Tokens.primary)
                Text("주차별 수업과 과제를 불러오는 중입니다").font(.mCaption).foregroundStyle(Tokens.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let classwork = model.classwork {
            if classwork.weeks.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Label("아직 등록한 주차가 없습니다", systemImage: "books.vertical")
                        .font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text("첫 수업 내용을 기록하고 학생에게 과제를 바로 전달해 보세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    Button("첫 주차 만들기") { model.startNewWeek() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(Tokens.Space.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(classwork.weeks) { week in weekCard(week) }
                    }
                }
                .refreshable { if let owner, owner.isCurrent(in: store) { await model.load(owner: owner, store: store) } }
            }
        } else if !model.isLoading {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text("과제 목록을 열지 못했습니다").font(.mBodyB).foregroundStyle(Tokens.ink)
                Text("이 반의 담당 교사 권한과 네트워크 상태를 확인해 주세요.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                Button("다시 불러오기") { performOwned { await model.load(owner: $0, store: store) } }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
    }

    private func weekCard(_ week: ServerAPI.AcademyWeek) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(week.academicYear) · \(week.weekNumber)주차")
                        .font(.mMicro).foregroundStyle(Tokens.primary)
                    Text(week.title).font(.mBodyB).foregroundStyle(Tokens.ink)
                    if !week.lessonSummary.isEmpty {
                        Text(week.lessonSummary).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(compactLandscape ? 2 : 4)
                    }
                }
                Spacer(minLength: 0)
                Menu {
                    Button { model.edit(week) } label: { Label("수정", systemImage: "pencil") }
                    Button(role: .destructive) {
                        guard let owner, owner.isCurrent(in: store) else { return }
                        deletionOwner = owner; deletingWeek = week
                    } label: {
                        Label("주차 삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("\(week.weekNumber)주차 관리")
                .disabled(model.actionID != nil)
            }
            if !week.concepts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Space.s1) {
                        ForEach(week.concepts) { concept in
                            Text(concept.conceptTitle)
                                .font(.mMicro).foregroundStyle(Tokens.primary)
                                .padding(.horizontal, Tokens.Space.s2).padding(.vertical, 5)
                                .background(Tokens.primarySoft, in: Capsule())
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Label(week.assignmentTitle, systemImage: "checklist")
                    .font(.mCaption).foregroundStyle(Tokens.ink)
                if !week.assignmentInstructions.isEmpty {
                    Text(week.assignmentInstructions).font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(3)
                }
                if let dueAt = week.dueAt {
                    Label(Self.dueLabel(dueAt), systemImage: "calendar.badge.clock")
                        .font(.mMicro).foregroundStyle(Tokens.warningInk)
                }
            }
            if let omr = week.assignmentOmr, omr.enabled {
                Label("온라인 답안지 · \(omr.questionCount)문항", systemImage: "list.number")
                    .font(.mCaption).foregroundStyle(Tokens.primary)
                AcademyAssignmentResults(submissions: week.submissions ?? [], answerKey: omr.answerKey)
            }
            if !week.files.isEmpty {
                ForEach(week.files) { file in
                    HStack(spacing: Tokens.Space.s2) {
                        Image(systemName: "doc.fill").foregroundStyle(Tokens.primary).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(file.originalName).font(.mCaption).foregroundStyle(Tokens.ink).lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(file.sizeBytes), countStyle: .file))
                                .font(.mMicro).foregroundStyle(Tokens.text3)
                        }
                        Spacer(minLength: 0)
                        Button("열기") { performOwned { await model.preview(file, from: week, owner: $0, store: store) } }
                            .font(.mCaption).frame(minHeight: 44)
                        Button(role: .destructive) { performOwned { await model.removeFile(file, from: week, owner: $0, store: store) } } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("\(file.originalName) 삭제")
                    }
                    .padding(.horizontal, Tokens.Space.s2)
                    .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    .disabled(model.actionID != nil)
                }
            }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section("주차") {
                    Stepper(value: $model.draft.academicYear, in: 2022...2100) {
                        Text(verbatim: "학년도 \(model.draft.academicYear)")
                    }
                    Stepper(value: $model.draft.weekNumber, in: 1...60) {
                        Text(verbatim: "\(model.draft.weekNumber)주차")
                    }
                    TextField("주차 제목(선택)", text: $model.draft.title)
                    TextField("수업 요약(선택)", text: $model.draft.lessonSummary, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section {
                    Text("\(model.selectedConceptKeys.count)/30개 선택")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    if !model.selectedConceptKeys.isEmpty {
                        Text(model.selectedConceptKeys.sorted().map { key in
                            model.allConcepts.first(where: { $0.key == key })?.conceptTitle ?? key
                        }.joined(separator: " · "))
                        .font(.mCaption).foregroundStyle(Tokens.ink)
                    }
                    DisclosureGroup("개념 선택·변경", isExpanded: $showsConceptPicker) {
                        TextField("과목·단원·개념 검색", text: $model.conceptSearch)
                            .textInputAutocapitalization(.never)
                        conceptPicker
                    }
                } header: { Text("이번 주에 배운 개념") }
                  footer: { Text("한 개 이상 선택해야 학생의 학습 화면과 과제가 연결됩니다.") }
                Section("과제") {
                    TextField("과제 제목", text: $model.draft.assignmentTitle)
                    TextField("과제 안내(선택)", text: $model.draft.assignmentInstructions, axis: .vertical)
                        .lineLimit(2...8)
                    Toggle("마감일 설정", isOn: $model.dueEnabled)
                    if model.dueEnabled {
                        DatePicker("마감", selection: $model.dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                AcademyAssignmentEditor(configuration: $model.draft.assignmentOmr)
                Section {
                    if let existing = model.existingWeek, !existing.files.isEmpty {
                        ForEach(existing.files) { file in
                            HStack {
                                Label(file.originalName, systemImage: "doc.fill").lineLimit(1)
                                Spacer(minLength: 0)
                                Button(role: .destructive) {
                                    performOwned { await model.removeFile(file, from: existing, owner: $0, store: store) }
                                } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                                .accessibilityLabel("\(file.originalName) 삭제")
                            }
                        }
                    }
                    ForEach(model.selectedFiles, id: \.self) { url in
                        HStack {
                            Label(url.lastPathComponent, systemImage: "plus.circle.fill").lineLimit(1)
                            Spacer(minLength: 0)
                            Button(role: .destructive) {
                                model.selectedFiles.removeAll { $0 == url }
                            } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }
                            .accessibilityLabel("\(url.lastPathComponent) 선택 해제")
                        }
                    }
                    Button {
                        guard let owner, owner.isCurrent(in: store) else { return }
                        pickerOwner = owner; importingFiles = true
                    } label: {
                        Label("파일 추가", systemImage: "paperclip")
                    }
                    .disabled((model.existingWeek?.files.count ?? 0) + model.selectedFiles.count >= 10)
                } header: { Text("과제 파일") }
                  footer: { Text("파일당 30MB, 합계 100MB, 기존 파일 포함 최대 10개입니다.") }
                if let error = model.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tokens.dangerInk) }
                }
                Section {
                    Button(model.actionID == "save" ? "저장 중…" : "주차 저장", action: requestSave)
                        .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: .infinity)
                        .disabled(model.actionID != nil)
                }
            }
            .disabled(model.actionID != nil)
            .navigationTitle(model.draft.weekID == nil ? "새 주차" : "주차 수정")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { confirmsDiscard = true }.disabled(model.actionID != nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.actionID == "save" ? "저장 중…" : "저장", action: requestSave)
                        .disabled(model.actionID != nil)
                }
            }
            .confirmationDialog("작성한 수업·과제를 버릴까요?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("변경 버리기", role: .destructive) { model.showsEditor = false }
                Button("계속 편집", role: .cancel) {}
            }
            .confirmationDialog("과제 답안지 변경을 적용할까요?", isPresented: $confirmsRegrade, titleVisibility: .visible) {
                Button("변경 적용") {
                    guard let saveOwner, saveOwner.isCurrent(in: store) else { return }
                    Task { await model.save(owner: saveOwner, store: store) }
                }
                Button("계속 편집", role: .cancel) {}
            } message: {
                Text("문항 구성이나 정답을 바꾸면 기존 제출 답안도 서버에서 다시 채점됩니다. 답안지를 끄면 학생의 새 제출이 중지됩니다.")
            }
            .fileImporter(
                isPresented: $importingFiles,
                allowedContentTypes: [.pdf, .image, .data, .archive],
                allowsMultipleSelection: true
            ) { result in
                guard let pickerOwner, pickerOwner.isCurrent(in: store), model.actionID == nil else { return }
                self.pickerOwner = nil
                switch result {
                case .success(let urls): model.installImportedFiles(urls)
                case .failure(let error): model.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var conceptPicker: some View {
        let concepts = model.allConcepts.filter(model.matchesSearch)
        let visibleConcepts = Array(concepts.prefix(12))
        return Group {
            if concepts.isEmpty {
                Text("검색 결과가 없습니다.").font(.mCaption).foregroundStyle(Tokens.text2)
            } else {
                ForEach(visibleConcepts) { concept in
                    Button { model.toggleConcept(concept.key) } label: {
                        HStack(alignment: .top) {
                            Image(systemName: model.selectedConceptKeys.contains(concept.key) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.selectedConceptKeys.contains(concept.key) ? Tokens.primary : Tokens.text3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(concept.conceptTitle).foregroundStyle(Tokens.ink)
                                Text("\(concept.courseTitle) · \(concept.unitTitle)")
                                    .font(.mCaption).foregroundStyle(Tokens.text2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(concept.conceptTitle), \(model.selectedConceptKeys.contains(concept.key) ? "선택됨" : "선택 안 됨")")
                }
                if concepts.count > visibleConcepts.count {
                    Text("검색 결과 \(concepts.count)개 중 12개를 표시합니다. 나머지 \(concepts.count - visibleConcepts.count)개는 과목·단원·개념 이름을 더 구체적으로 검색해 주세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
        }
    }

    private var previewPresented: Binding<Bool> {
        Binding(
            get: { model.previewURL != nil },
            set: { if !$0 { model.previewURL = nil } })
    }

    private static func dueLabel(_ value: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: value) ?? ISO8601DateFormatter().date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일(E) a h:mm 마감"
        return formatter.string(from: date)
    }
}
