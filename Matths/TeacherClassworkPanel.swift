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

    func prepare(classes: [ServerAPI.AcademyClassSummary]) {
        guard selectedClassID.isEmpty, let first = classes.first else { return }
        selectedClassID = first.id
    }

    func load() async {
        guard !selectedClassID.isEmpty else {
            classwork = nil
            return
        }
        let classID = selectedClassID
        let generation = UUID()
        loadGeneration = generation
        isLoading = true
        errorMessage = nil
        noticeMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyClasswork(classID: classID)
            guard generation == loadGeneration, classID == selectedClassID else { return }
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
            guard generation == loadGeneration, classID == selectedClassID else { return }
            classwork = nil
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
        draft = ServerAPI.TeacherClassWeekDraft(
            weekID: week.id,
            academicYear: week.academicYear,
            weekNumber: week.weekNumber,
            title: week.title,
            lessonSummary: week.lessonSummary,
            conceptKeys: week.concepts.map(\.id),
            assignmentTitle: week.assignmentTitle,
            assignmentInstructions: week.assignmentInstructions,
            dueAt: "")
        selectedConceptKeys = Set(week.concepts.map(\.id))
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

    func save() async {
        guard actionID == nil, !selectedClassID.isEmpty else { return }
        let assignmentTitle = draft.assignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !assignmentTitle.isEmpty else {
            errorMessage = "과제 제목을 입력해 주세요."
            return
        }
        guard !selectedConceptKeys.isEmpty else {
            errorMessage = "이번 주에 배운 개념을 한 개 이상 선택해 주세요."
            return
        }
        if let existing = existingWeek,
           existing.files.count + selectedFiles.count > 10 {
            errorMessage = "기존 파일을 포함해 한 주차에는 최대 10개까지 등록할 수 있습니다."
            return
        }
        actionID = "save"
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
            classwork = try await ServerAPI.saveTeacherAcademyClassWeek(
                classID: selectedClassID, draft: payload, files: selectedFiles)
            showsEditor = false
            selectedFiles = []
            noticeMessage = draft.weekID == nil ? "새 주차 수업과 과제를 게시했습니다." : "주차 수업과 과제를 수정했습니다."
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func delete(_ week: ServerAPI.AcademyWeek) async {
        guard actionID == nil else { return }
        actionID = "delete-\(week.id)"
        errorMessage = nil
        noticeMessage = nil
        do {
            classwork = try await ServerAPI.deleteTeacherAcademyClassWeek(
                classID: selectedClassID, weekID: week.id)
            noticeMessage = "\(week.weekNumber)주차를 삭제했습니다."
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func removeFile(_ file: ServerAPI.AcademyWeek.File, from week: ServerAPI.AcademyWeek) async {
        guard actionID == nil else { return }
        actionID = "file-\(file.id)"
        errorMessage = nil
        noticeMessage = nil
        do {
            classwork = try await ServerAPI.removeTeacherAcademyClassWeekFile(
                classID: selectedClassID, weekID: week.id, fileID: file.id)
            noticeMessage = "파일을 삭제했습니다."
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func preview(_ file: ServerAPI.AcademyWeek.File, from week: ServerAPI.AcademyWeek) async {
        guard actionID == nil else { return }
        actionID = "preview-\(file.id)"
        errorMessage = nil
        do {
            previewURL = try await ServerAPI.downloadTeacherAcademyFile(
                classID: selectedClassID, weekID: week.id, file: file)
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
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
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 교사가 휴대전화 가로 화면에서도 웹 포털 없이 주차 수업과 과제를 관리하는 작업대.
struct TeacherClassworkPanel: View {
    let classes: [ServerAPI.AcademyClassSummary]
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = TeacherClassworkPanelModel()
    @State private var importingFiles = false
    @State private var deletingWeek: ServerAPI.AcademyWeek?

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            toolbar
            feedback
            content
        }
        .task { model.prepare(classes: classes) }
        .task(id: model.selectedClassID) { await model.load() }
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
                Task { await model.delete(week) }
            }
            Button("취소", role: .cancel) { deletingWeek = nil }
        } message: { week in
            Text("수업 내용과 과제 파일이 함께 삭제되며 되돌릴 수 없습니다: \(week.title)")
        }
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
        .disabled(model.actionID != nil)
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
                .refreshable { await model.load() }
            }
        } else if !model.isLoading {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text("과제 목록을 열지 못했습니다").font(.mBodyB).foregroundStyle(Tokens.ink)
                Text("이 반의 담당 교사 권한과 네트워크 상태를 확인해 주세요.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                Button("다시 불러오기") { Task { await model.load() } }
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
                    Button(role: .destructive) { deletingWeek = week } label: {
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
                        Button("열기") { Task { await model.preview(file, from: week) } }
                            .font(.mCaption).frame(minHeight: 44)
                        Button(role: .destructive) { Task { await model.removeFile(file, from: week) } } label: {
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
                    TextField("개념 검색", text: $model.conceptSearch)
                        .textInputAutocapitalization(.never)
                    Text("\(model.selectedConceptKeys.count)/30개 선택")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    conceptPicker
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
                Section {
                    if let existing = model.existingWeek, !existing.files.isEmpty {
                        ForEach(existing.files) { file in
                            HStack {
                                Label(file.originalName, systemImage: "doc.fill").lineLimit(1)
                                Spacer(minLength: 0)
                                Button(role: .destructive) {
                                    Task { await model.removeFile(file, from: existing) }
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
                    Button { importingFiles = true } label: {
                        Label("파일 추가", systemImage: "paperclip")
                    }
                    .disabled((model.existingWeek?.files.count ?? 0) + model.selectedFiles.count >= 10)
                } header: { Text("과제 파일") }
                  footer: { Text("파일당 30MB, 합계 100MB, 기존 파일 포함 최대 10개입니다.") }
                if let error = model.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tokens.dangerInk) }
                }
            }
            .navigationTitle(model.draft.weekID == nil ? "새 주차" : "주차 수정")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(model.actionID != nil)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { model.showsEditor = false }.disabled(model.actionID != nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.actionID == "save" ? "저장 중…" : "저장") { Task { await model.save() } }
                        .disabled(model.actionID != nil)
                }
            }
            .fileImporter(
                isPresented: $importingFiles,
                allowedContentTypes: [.pdf, .image, .data, .archive],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): model.installImportedFiles(urls)
                case .failure(let error): model.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var conceptPicker: some View {
        let concepts = model.allConcepts.filter(model.matchesSearch)
        return Group {
            if concepts.isEmpty {
                Text("검색 결과가 없습니다.").font(.mCaption).foregroundStyle(Tokens.text2)
            } else {
                ForEach(concepts) { concept in
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
