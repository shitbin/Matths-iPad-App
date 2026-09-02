import SwiftUI
import QuickLook
import UniformTypeIdentifiers

private struct AdminMockPreviewRequest: Identifiable {
    let url: URL
    var id: String { url.path }
}

@MainActor
private final class AdminWeeklyMockModel: ObservableObject {
    @Published var dashboard: ServerAPI.AdminMockDashboard?
    @Published var detail: ServerAPI.AdminMockExamDetail?
    @Published var objection: ServerAPI.AdminMockObjection?
    @Published var selectedExamID: String?
    @Published var selectedAttemptID: String?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    func load() async {
        isLoading = dashboard == nil; errorMessage = nil
        do {
            let value = try await ServerAPI.adminWeeklyMockDashboard(); dashboard = value
            if selectedExamID == nil { selectedExamID = value.exams.first?.id }
            if let selectedExamID { await loadDetail(examID: selectedExamID) }
        } catch is CancellationError {} catch { errorMessage = readable(error) }
        isLoading = false
    }
    func loadDetail(examID: String) async {
        actionID = "load:\(examID)"; errorMessage = nil
        do {
            let value = try await ServerAPI.adminWeeklyMockDetail(examID: examID); detail = value
            if !value.attempts.contains(where: { $0.id == selectedAttemptID }) { selectedAttemptID = value.attempts.first?.id }
        } catch is CancellationError {} catch { errorMessage = readable(error) }
        actionID = nil
    }
    func loadObjection(id: String) async {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true; errorMessage = nil; noticeMessage = nil
        do { objection = try await ServerAPI.adminWeeklyMockObjection(id: id.trimmingCharacters(in: .whitespacesAndNewlines)) }
        catch { errorMessage = readable(error) }
        isLoading = false
    }
    func mutate(id: String, success: String, operation: () async throws -> Void) async -> Bool {
        guard actionID == nil else { return false }
        actionID = id; errorMessage = nil; noticeMessage = nil
        do { try await operation(); noticeMessage = success; actionID = nil; return true }
        catch { errorMessage = readable(error); actionID = nil; return false }
    }
    private func readable(_ error: Error) -> String { (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription }
}

struct AdminWeeklyMockScreen: View {
    private enum Section: String, CaseIterable, Identifiable { case exams = "회차·응시", objections = "이의신청"; var id: String { rawValue } }
    fileprivate enum Action: Identifiable {
        case integrityRequest(ServerAPI.AdminMockAttempt)
        case integrityReview(ServerAPI.AdminMockIntegrityCase)
        case correction(ServerAPI.AdminMockExam)
        case objectionReject(ServerAPI.AdminMockObjection)
        case objectionAccept(ServerAPI.AdminMockObjection)
        var id: String {
            switch self {
            case .integrityRequest(let value): "request:\(value.id)"
            case .integrityReview(let value): "review:\(value.id)"
            case .correction(let value): "correction:\(value.id)"
            case .objectionReject(let value): "reject:\(value.id)"
            case .objectionAccept(let value): "accept:\(value.id)"
            }
        }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminWeeklyMockModel()
    @State private var section: Section = .exams
    @State private var objectionID = ""
    @State private var action: Action?
    @State private var deleteExam: ServerAPI.AdminMockExam?
    @State private var previewRequest: AdminMockPreviewRequest?
    @State private var showsExamUpload = false
    @State private var showsFormula = false
    let onClose: () -> Void

    private var compactLandscape: Bool { verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize }
    private var selectedAttempt: ServerAPI.AdminMockAttempt? {
        model.detail?.attempts.first(where: { $0.id == model.selectedAttemptID }) ?? model.detail?.attempts.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let value = model.errorMessage { banner(value, Tokens.dangerInk, "exclamationmark.triangle.fill") }
            if let value = model.noticeMessage { banner(value, Tokens.successInk, "checkmark.circle.fill") }
            if model.isLoading && model.dashboard == nil { Spacer(); ProgressView("모의고사 운영 정보를 불러오는 중입니다"); Spacer() }
            else if section == .objections { objectionContent }
            else if compactLandscape {
                HStack(spacing: 0) { examList.frame(width: 330); Divider(); examDetail.frame(maxWidth: .infinity, maxHeight: .infinity) }
            } else {
                ScrollView { VStack(spacing: 12) { examList; examDetail }.readableWidth(Tokens.readableWidth).adaptiveHPadding().adaptiveVPadding() }
            }
        }
        .background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .task { await model.load() }
        .sheet(item: $action) { value in AdminWeeklyMockActionSheet(action: value) { form in await perform(value, form: form) } }
        .sheet(item: $previewRequest) { value in
            NavigationStack {
                AdminMockQuickLook(url: value.url).ignoresSafeArea()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { previewRequest = nil } } }
            }
        }
        .sheet(isPresented: $showsExamUpload) {
            AdminMockExamUploadSheet { await model.load() }
        }
        .sheet(isPresented: $showsFormula) {
            AdminMockFormulaSheet(resources: model.dashboard?.formulaResources ?? []) { await model.load() }
        }
        .confirmationDialog("회차를 영구 삭제할까요?", isPresented: Binding(get: { deleteExam != nil }, set: { if !$0 { deleteExam = nil } }), titleVisibility: .visible) {
            Button("회차·응시 기록 삭제", role: .destructive) { if let exam = deleteExam { Task { await delete(exam) } } }
            Button("취소", role: .cancel) { deleteExam = nil }
        } message: { Text("문제지, 답지와 응시 기록을 함께 삭제합니다. 복구할 수 없습니다.") }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("관리자 홈")
                VStack(alignment: .leading, spacing: 1) { Text("주간 공식 모의고사 운영").font(.mHeading); Text("응시·채점·공정성·정답 정정").font(.mCaption).foregroundStyle(Tokens.text2) }
                Spacer()
                Menu {
                    Button("새 회차·문제지 등록") { showsExamUpload = true }
                    Button("공식 암기 PDF 관리") { showsFormula = true }
                } label: { Image(systemName: "plus.circle").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("모의고사 자료 등록")
                Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary)
            }
            Picker("운영 종류", selection: $section) { ForEach(Section.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
    }

    private var examList: some View {
        VStack(spacing: 0) {
            HStack { Text("등록 회차").font(.mBodyB); Spacer(); Text("\(model.dashboard?.exams.count ?? 0)개").font(.mCaption).foregroundStyle(Tokens.text3) }.padding(12)
            if let exams = model.dashboard?.exams, !exams.isEmpty {
                ScrollView { LazyVStack(spacing: 8) { ForEach(exams) { examRow($0) } }.padding(.horizontal, 10).padding(.bottom, 10) }
            } else { ContentUnavailableView("등록 회차 없음", systemImage: "doc.badge.plus").frame(maxWidth: .infinity, minHeight: 180) }
        }
    }

    private func examRow(_ exam: ServerAPI.AdminMockExam) -> some View {
        Button {
            model.selectedExamID = exam.id; model.selectedAttemptID = nil
            Task { await model.loadDetail(examID: exam.id) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack { badge(statusLabel(exam.status)); Spacer(); Text(exam.formCode.isEmpty ? "CUSTOM" : "\(exam.formCode)형").font(.mMicro).foregroundStyle(Tokens.text3) }
                Text(exam.title).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                Text("응시 \(exam.attemptCount)명 · 공정성 \(exam.integrityCaseCount)건 · \(exam.questionCount)문항").font(.mMicro).foregroundStyle(Tokens.text2)
            }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
                .background(model.selectedExamID == exam.id ? Tokens.primary.opacity(0.11) : Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private var examDetail: some View {
        if let detail = model.detail {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        examSummary(detail.exam)
                        Divider()
                        if detail.attempts.isEmpty { ContentUnavailableView("응시 기록 없음", systemImage: "person.crop.circle.badge.questionmark") }
                        else {
                            attemptPicker(detail.attempts)
                            if let selectedAttempt { attemptDetail(selectedAttempt, exam: detail.exam) }
                        }
                    }.padding(14)
                }
            }
        } else { ContentUnavailableView("회차를 선택하세요", systemImage: "doc.text.magnifyingglass").frame(maxWidth: .infinity, maxHeight: .infinity) }
    }

    private func examSummary(_ exam: ServerAPI.AdminMockExam) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { badge(statusLabel(exam.status)); if exam.isTest { badge("운영 테스트") }; Spacer() }
            Text(exam.title).font(compactLandscape ? .mHeading : .mTitle)
            Text("\(exam.formCode.isEmpty ? "CUSTOM" : "\(exam.formCode)형") · 공개 \(date(exam.releaseAt)) · 마감 \(date(exam.closeAt))").font(.mCaption).foregroundStyle(Tokens.text2)
            HStack {
                Button { action = .correction(exam) } label: { Label("정답 정정·전체 재채점", systemImage: "arrow.triangle.2.circlepath") }.buttonStyle(.bordered)
                if exam.canDelete { Button("회차 삭제", role: .destructive) { deleteExam = exam }.buttonStyle(.bordered) }
            }
            HStack {
                Button { Task { await previewExamFile(exam, type: "problem", name: exam.originalName) } } label: { Label("문제지", systemImage: "doc.richtext") }.buttonStyle(.bordered)
                if exam.hasAnswerSheet { Button { Task { await previewExamFile(exam, type: "answer-sheet", name: exam.answerSheetName) } } label: { Label("확인용 답지", systemImage: "doc.text.magnifyingglass") }.buttonStyle(.bordered) }
            }
        }
    }

    private func attemptPicker(_ attempts: [ServerAPI.AdminMockAttempt]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(attempts) { item in
                    Button { model.selectedAttemptID = item.id } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.user?.name ?? "탈퇴 사용자").font(.mCaption.weight(.semibold))
                            Text("\(item.score)점 · \(statusLabel(item.status))").font(.mMicro)
                        }.padding(.horizontal, 11).frame(minHeight: 42).foregroundStyle(model.selectedAttemptID == item.id ? Color.white : Tokens.text2)
                            .background(model.selectedAttemptID == item.id ? Tokens.primary : Tokens.surface, in: Capsule())
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func attemptDetail(_ attempt: ServerAPI.AdminMockAttempt, exam: ServerAPI.AdminMockExam) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(attempt.user?.name ?? "탈퇴 사용자").font(.mHeading); Spacer(); badge(statusLabel(attempt.integrityStatus)) }
            Text(attempt.user?.email ?? "익명화 계정").font(.mCaption).foregroundStyle(Tokens.text2).textSelection(.enabled)
            HStack(spacing: 7) { metric("점수", "\(attempt.score)점"); metric("정답", "\(attempt.correctCount)/\(attempt.questionCount)"); metric("소요", duration(attempt.elapsedMs)); metric("이벤트", "\(attempt.events.count)건") }
            if let integrity = attempt.integrityCase { integrityCard(integrity) }
            else if attempt.status == "submitted" {
                Button { action = .integrityRequest(attempt) } label: { Label("풀이과정 소명 자료 요청", systemImage: "envelope.badge.shield.half.filled").frame(maxWidth: .infinity, minHeight: 44) }.buttonStyle(.borderedProminent)
            }
            Text("문항별 채점").font(.mBodyB)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 7)], spacing: 7) {
                ForEach(attempt.review) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text("\(question.number)번").font(.mBodyB); Spacer(); Text(question.isCorrect ? "정답" : "오답").foregroundStyle(question.isCorrect ? Tokens.successInk : Tokens.dangerInk) }
                        Text("제출 \(question.submittedAnswer.isEmpty ? "—" : question.submittedAnswer) · 정답 \(question.correctAnswer)").font(.mCaption.monospacedDigit())
                        if !question.isCorrect, let explanation = question.explanation, !explanation.summary.isEmpty { Text(explanation.summary).font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(3) }
                    }.padding(10).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
                }
            }
            if !attempt.events.isEmpty {
                DisclosureGroup("전체 이벤트 로그 \(attempt.events.count)건") {
                    ForEach(attempt.events) { event in
                        VStack(alignment: .leading, spacing: 2) { Text(eventLabel(event.eventType)).font(.mCaption.weight(.semibold)); Text("\(event.questionNumber.map { "\($0)번 · " } ?? "")\(event.metadata)").font(.mMicro).foregroundStyle(Tokens.text2); Text(date(event.serverAt)).font(.mMicro).foregroundStyle(Tokens.text3) }.padding(.vertical, 5)
                    }
                }.font(.mCaption)
            }
        }
    }

    private func integrityCard(_ value: ServerAPI.AdminMockIntegrityCase) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Label("공정성 소명 검토", systemImage: "shield.lefthalf.filled").font(.mBodyB); Spacer(); Text("위험 \(value.riskScore)").font(.mCaption.monospacedDigit()) }
            Text("요청 문항 \(value.requestedQuestionNumbers.map(String.init).joined(separator: ", ")) · 자료 \(value.evidenceSubmissions.count)건").font(.mCaption)
            if !value.suspicionSignals.isEmpty { Text(value.suspicionSignals.map { signalLabel($0.code) }.joined(separator: " · ")).font(.mMicro).foregroundStyle(Tokens.text2) }
            ForEach(value.evidenceSubmissions) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text("접수 \(item.receiptId)").font(.mCaption.weight(.semibold))
                    Text(item.note.isEmpty ? "메시지 없음" : item.note).font(.mMicro)
                    ForEach(item.files) { file in
                        Button { Task { await previewEvidence(value, file: file) } } label: { Label("안전 열람 · \(file.originalName)", systemImage: "eye") }.buttonStyle(.bordered)
                    }
                }.padding(8).background(Tokens.paper, in: RoundedRectangle(cornerRadius: 9))
            }
            Button { action = .integrityReview(value) } label: { Label("검토·페널티 결정", systemImage: "checkmark.shield").frame(maxWidth: .infinity, minHeight: 42) }.buttonStyle(.borderedProminent)
        }.padding(11).background(Tokens.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }

    private var objectionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack { TextField("이의신청 접수 번호", text: $objectionID).textInputAutocapitalization(.never); Button("조회") { Task { await model.loadObjection(id: objectionID) } }.buttonStyle(.borderedProminent) }.padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
                if let value = model.objection {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { badge(statusLabel(value.status)); Spacer(); Text(date(value.createdAt)).font(.mCaption).foregroundStyle(Tokens.text3) }
                        Text("\(value.examTitle) · \(value.questionNumber)번").font(.mTitle)
                        field("신청자", "\(value.user?.name ?? "익명화 사용자") · \(value.user?.email ?? "")")
                        field("현재 저장 정답", value.currentAnswer)
                        field("문제가 있다고 판단한 부분", value.issueDetail)
                        if !value.reviewReason.isEmpty { field("처리 사유", value.reviewReason) }
                        if value.status != "accepted" && value.status != "rejected" {
                            HStack { Button("반려") { action = .objectionReject(value) }.buttonStyle(.bordered); Button("인용·정답 정정") { action = .objectionAccept(value) }.buttonStyle(.borderedProminent) }
                        }
                    }
                } else { ContentUnavailableView("접수 번호로 조회", systemImage: "doc.questionmark", description: Text("운영 처리함에 표시된 이의신청 ID를 입력하세요.")) }
            }.readableWidth(760).adaptiveHPadding().adaptiveVPadding()
        }
    }

    private func perform(_ value: Action, form: AdminWeeklyMockActionForm) async -> Bool {
        guard let examID = model.detail?.exam.id ?? model.selectedExamID else {
            if case .objectionReject = value {} else if case .objectionAccept = value {} else { return false }
            return await performObjection(value, form: form)
        }
        let success: Bool
        switch value {
        case .integrityRequest(let attempt):
            success = await model.mutate(id: value.id, success: "소명 요청을 이메일과 앱 알림으로 보냈습니다.") { try await ServerAPI.requestAdminMockIntegrityEvidence(examID: examID, attemptID: attempt.id, questionNumbers: form.questionNumbers, instructions: form.instructions) }
        case .integrityReview(let item):
            success = await model.mutate(id: value.id, success: "공정성 검토와 페널티 결정을 저장했습니다.") { try await ServerAPI.reviewAdminMockIntegrity(examID: examID, caseID: item.id, reviewStatus: form.reviewStatus, penaltyDecision: form.penaltyDecision, reason: form.reason) }
        case .correction:
            var count = 0
            success = await model.mutate(id: value.id, success: "정답을 정정하고 전체 성적을 다시 계산했습니다.") { count = try await ServerAPI.correctAdminMockAnswers(examID: examID, questionNumber: form.questionNumber, questionContent: form.questionContent, newAnswer: form.newAnswer, reason: form.reason) }
            if success { model.noticeMessage = "정답 정정 완료 · 응시 \(count)건 재계산" }
        case .objectionReject, .objectionAccept: return await performObjection(value, form: form)
        }
        if success { await model.loadDetail(examID: examID) }
        return success
    }

    private func performObjection(_ value: Action, form: AdminWeeklyMockActionForm) async -> Bool {
        let success: Bool
        switch value {
        case .objectionReject(let item): success = await model.mutate(id: value.id, success: "이의신청 반려 결과를 전송했습니다.") { try await ServerAPI.rejectAdminWeeklyMockObjection(id: item.id, reason: form.reason) }
        case .objectionAccept(let item): success = await model.mutate(id: value.id, success: "이의신청을 인용하고 전체 성적을 재계산했습니다.") { try await ServerAPI.acceptAdminWeeklyMockObjection(id: item.id, newAnswer: form.newAnswer, questionContent: form.questionContent, reason: form.reason) }
        default: return false
        }
        if success, let id = model.objection?.id { await model.loadObjection(id: id) }
        return success
    }

    private func delete(_ exam: ServerAPI.AdminMockExam) async {
        let success = await model.mutate(id: "delete:\(exam.id)", success: "회차와 응시 기록을 삭제했습니다.") { try await ServerAPI.deleteAdminWeeklyMock(examID: exam.id) }
        deleteExam = nil
        if success { model.detail = nil; model.selectedExamID = nil; await model.load() }
    }

    private func previewExamFile(_ exam: ServerAPI.AdminMockExam, type: String, name: String) async {
        _ = await model.mutate(id: "file:\(exam.id):\(type)", success: "") {
            let url = try await ServerAPI.downloadAdminWeeklyMockFile(examID: exam.id, fileType: type, fileName: name)
            previewRequest = .init(url: url)
        }
        if model.noticeMessage?.isEmpty == true { model.noticeMessage = nil }
    }

    private func previewEvidence(_ integrity: ServerAPI.AdminMockIntegrityCase, file: ServerAPI.AdminMockEvidenceFile) async {
        _ = await model.mutate(id: "evidence:\(file.archiveItemId)", success: "") {
            let url = try await ServerAPI.downloadAdminMockEvidence(caseID: integrity.id, archiveItemID: file.archiveItemId, fileName: file.originalName)
            previewRequest = .init(url: url)
        }
        if model.noticeMessage?.isEmpty == true { model.noticeMessage = nil }
    }

    private func metric(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 2) { Text(value).font(.mBodyB.monospacedDigit()); Text(label).font(.mMicro).foregroundStyle(Tokens.text3) }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 9)) }
    private func field(_ label: String, _ value: String) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.mCaption).foregroundStyle(Tokens.text2); Text(value.isEmpty ? "—" : value).font(.mBody).textSelection(.enabled) }.padding(11).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12)) }
    private func badge(_ value: String) -> some View { Text(value.isEmpty ? "확인 필요" : value).font(.mMicro.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4).foregroundStyle(Tokens.primary).background(Tokens.primary.opacity(0.1), in: Capsule()) }
    private func banner(_ value: String, _ color: Color, _ icon: String) -> some View { Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(color.opacity(0.1)) }
    private func statusLabel(_ value: String) -> String { ["scheduled":"예약", "open":"진행", "closed":"마감", "submitted":"제출", "accepted":"인용", "rejected":"반려", "unreviewed":"미검토", "reviewing":"검토중", "completed":"완료", "pending":"결정 전", "clear":"정상", "flagged":"확인 필요" ][value.lowercased()] ?? value }
    private func signalLabel(_ value: String) -> String { ["FOCUS_LOSS":"화면 이탈", "ANSWER_BURST":"답안 급변", "NETWORK_CHANGE":"네트워크 변경", "TIME_ANOMALY":"시간 이상"][value] ?? value }
    private func eventLabel(_ value: String) -> String { ["answer_saved":"답안 저장", "focus_lost":"화면 이탈", "focus_restored":"화면 복귀", "heartbeat":"연결 확인", "submitted":"최종 제출"][value] ?? value }
    private func duration(_ milliseconds: Int) -> String { let seconds = max(0, milliseconds) / 1_000; return "\(seconds / 60)분 \(seconds % 60)초" }
    private func date(_ value: String?) -> String { guard let value else { return "—" }; let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return (formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value))?.formatted(date: .numeric, time: .shortened) ?? value }
}

private struct AdminMockQuickLook: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url; controller.reloadData()
    }
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

private struct AdminMockExamUploadSheet: View {
    private enum FileKind { case problem, answerKey, answerSheet }
    let onChanged: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var examDate = ""
    @State private var releaseAt = ""
    @State private var formCode = "A"
    @State private var problemURL: URL?
    @State private var answerKeyURL: URL?
    @State private var answerSheetURL: URL?
    @State private var importTarget: FileKind?
    @State private var confirming = false
    @State private var saving = false
    @State private var errorMessage: String?

    private var valid: Bool {
        problemURL != nil && answerKeyURL != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !examDate.isEmpty
    }
    private var allowedTypes: [UTType] { importTarget == .answerKey ? [.json] : [.pdf] }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tokens.dangerInk) } }
                Section("회차") {
                    TextField("시험 제목", text: $title)
                    TextField("시험 날짜 (YYYY-MM-DD)", text: $examDate).textInputAutocapitalization(.never)
                    TextField("사용자 지정 공개 시각 (선택)", text: $releaseAt).textInputAutocapitalization(.never)
                    Picker("시험지 형", selection: $formCode) { Text("A형").tag("A"); Text("B형").tag("B"); Text("CUSTOM").tag("CUSTOM") }
                }
                Section("필수 파일") {
                    fileButton("문제지 PDF", url: problemURL) { importTarget = .problem }
                    fileButton("정답·배점·해설 JSON", url: answerKeyURL) { importTarget = .answerKey }
                    fileButton("확인용 답지 PDF (선택)", url: answerSheetURL) { importTarget = .answerSheet }
                }
                Section { Text("서버가 PDF·JSON 실제 내용을 검사하고, 정답 키와 문항 수가 맞지 않으면 등록을 거부합니다.").font(.mCaption).foregroundStyle(Tokens.text2) }
            }
            .navigationTitle("주간 모의고사 등록").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("등록 검토") { confirming = true }.disabled(!valid || saving) } }
            .fileImporter(isPresented: Binding(get: { importTarget != nil }, set: { if !$0 { importTarget = nil } }), allowedContentTypes: allowedTypes) { result in
                guard let target = importTarget else { return }; defer { importTarget = nil }
                if case .success(let url) = result { switch target { case .problem: problemURL = url; case .answerKey: answerKeyURL = url; case .answerSheet: answerSheetURL = url } }
            }
            .confirmationDialog("이 회차를 등록할까요?", isPresented: $confirming, titleVisibility: .visible) {
                Button("파일 검증 후 공개 예약") { Task { await upload() } }; Button("취소", role: .cancel) {}
            } message: { Text("업로드가 성공하면 서버 일정에 따라 회원 공개와 공지가 예약됩니다.") }
        }.presentationDetents([.large])
    }

    private func fileButton(_ label: String, url: URL?, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Label(label, systemImage: url == nil ? "doc.badge.plus" : "checkmark.circle.fill"); Spacer(); Text(url?.lastPathComponent ?? "선택").font(.mCaption).foregroundStyle(url == nil ? Tokens.primary : Tokens.successInk).lineLimit(1) } }
    }
    private func upload() async {
        guard let problemURL, let answerKeyURL else { return }
        saving = true; errorMessage = nil
        do {
            _ = try await ServerAPI.uploadAdminWeeklyMock(examURL: problemURL, answerKeyURL: answerKeyURL, answerSheetURL: answerSheetURL, title: title, examDate: examDate, customReleaseAt: releaseAt, formCode: formCode)
            await onChanged(); dismiss()
        } catch { errorMessage = (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription }
        saving = false
    }
}

private struct AdminMockFormulaSheet: View {
    let resources: [ServerAPI.AdminMockFormulaResource]
    let onChanged: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var fileURL: URL?
    @State private var picking = false
    @State private var saving = false
    @State private var deleteTarget: ServerAPI.AdminMockFormulaResource?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage { Section { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Tokens.dangerInk) } }
                Section("새 공식 암기 PDF") {
                    TextField("버전 표시 (예: 2026-09)", text: $label)
                    Button { picking = true } label: { HStack { Label("PDF 선택", systemImage: "doc.badge.plus"); Spacer(); Text(fileURL?.lastPathComponent ?? "선택").font(.mCaption).lineLimit(1) } }
                    Button("업로드") { Task { await upload() } }.disabled(fileURL == nil || label.isEmpty || saving)
                }
                Section("등록 자료") {
                    if resources.isEmpty { Text("등록된 공식 암기 PDF가 없습니다.").foregroundStyle(Tokens.text2) }
                    ForEach(resources) { item in
                        HStack { VStack(alignment: .leading) { Text(item.versionLabel).font(.mBodyB); Text(item.originalName).font(.mCaption).foregroundStyle(Tokens.text2) }; Spacer(); Button("삭제", role: .destructive) { deleteTarget = item } }
                    }
                }
            }
            .navigationTitle("공식 암기 PDF").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.pdf]) { if case .success(let url) = $0 { fileURL = url } }
            .confirmationDialog("공식 암기 PDF를 삭제할까요?", isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) { Button("삭제", role: .destructive) { if let item = deleteTarget { Task { await delete(item) } } }; Button("취소", role: .cancel) {} }
        }.presentationDetents([.large])
    }
    private func upload() async {
        guard let fileURL else { return }; saving = true; errorMessage = nil
        do { try await ServerAPI.uploadAdminWeeklyMockFormula(fileURL: fileURL, versionLabel: label); await onChanged(); dismiss() }
        catch { errorMessage = (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription }
        saving = false
    }
    private func delete(_ item: ServerAPI.AdminMockFormulaResource) async {
        saving = true; errorMessage = nil
        do { try await ServerAPI.deleteAdminWeeklyMockFormula(resourceID: item.id); deleteTarget = nil; await onChanged(); dismiss() }
        catch { errorMessage = (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription }
        saving = false
    }
}

fileprivate struct AdminWeeklyMockActionForm {
    var questionNumbers = ""
    var instructions = "지정 문항의 전체 풀이과정을 사진 또는 PDF로 제출해 주세요."
    var reviewStatus = "reviewing"
    var penaltyDecision = "pending"
    var reason = ""
    var questionNumber = 1
    var questionContent = ""
    var newAnswer = ""
}

private struct AdminWeeklyMockActionSheet: View {
    let action: AdminWeeklyMockScreen.Action
    let onSubmit: (AdminWeeklyMockActionForm) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var form = AdminWeeklyMockActionForm()
    @State private var confirming = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section { fields }
                Section { Text(warning).font(.mCaption).foregroundStyle(Tokens.text2) }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("검토") { confirming = true }.disabled(!valid || saving) } }
            .confirmationDialog("최종 처리할까요?", isPresented: $confirming, titleVisibility: .visible) { Button(confirmLabel, role: destructive ? .destructive : nil) { saving = true; Task { if await onSubmit(form) { dismiss() }; saving = false } }; Button("취소", role: .cancel) {} } message: { Text(warning) }
        }.presentationDetents([.large])
    }

    @ViewBuilder private var fields: some View {
        switch action {
        case .integrityRequest(let item):
            TextField("요청 문항 (예: 20, 21, 28)", text: $form.questionNumbers).onAppear { form.questionNumbers = item.incorrectQuestionNumbers.map(String.init).joined(separator: ", ") }
            TextField("요청 안내", text: $form.instructions, axis: .vertical).lineLimit(4...8)
        case .integrityReview(let item):
            Picker("검토 상태", selection: $form.reviewStatus) { Text("미검토").tag("unreviewed"); Text("검토중").tag("reviewing"); Text("검토완료").tag("completed") }.onAppear { form.reviewStatus = item.reviewStatus; form.penaltyDecision = item.penaltyDecision; form.reason = item.decisionReason }
            Picker("페널티", selection: $form.penaltyDecision) { Text("결정 전").tag("pending"); Text("부여 안 함").tag("no_penalty"); Text("3회 응시 제한").tag("penalty") }
            TextField("판단 근거", text: $form.reason, axis: .vertical).lineLimit(4...8)
        case .correction(let exam):
            Stepper("정정 문항 \(form.questionNumber)번", value: $form.questionNumber, in: 1...max(1, exam.questionCount))
            TextField("문항 내용", text: $form.questionContent, axis: .vertical).lineLimit(3...6)
            TextField("새 정답", text: $form.newAnswer)
            TextField("정정 사유", text: $form.reason, axis: .vertical).lineLimit(3...6)
        case .objectionReject:
            TextField("반려 사유", text: $form.reason, axis: .vertical).lineLimit(5...10)
        case .objectionAccept(let item):
            TextField("문항 내용", text: $form.questionContent, axis: .vertical).lineLimit(4...8)
            TextField("새 정답", text: $form.newAnswer).onAppear { form.newAnswer = item.currentAnswer }
            TextField("인용·정정 사유", text: $form.reason, axis: .vertical).lineLimit(5...10)
        }
    }
    private var title: String { switch action { case .integrityRequest: "소명 자료 요청"; case .integrityReview: "공정성 검토"; case .correction: "정답 정정"; case .objectionReject: "이의신청 반려"; case .objectionAccept: "이의신청 인용" } }
    private var confirmLabel: String { switch action { case .integrityRequest: "요청 전송"; case .integrityReview: "검토 저장"; case .correction: "정정·전체 재채점"; case .objectionReject: "반려 결과 전송"; case .objectionAccept: "인용·전체 재계산" } }
    private var warning: String { switch action { case .integrityRequest: "학생에게 이메일과 앱 알림이 발송됩니다."; case .integrityReview: "페널티 부여 시 이후 3회차 응시가 제한됩니다."; case .correction, .objectionAccept: "전체 응시자의 성적·랭킹·GP를 다시 계산하고 공지와 이메일을 발송합니다."; case .objectionReject: "반려 사유가 신청자의 이메일과 앱 알림으로 발송됩니다." } }
    private var destructive: Bool { switch action { case .integrityReview: form.penaltyDecision == "penalty"; case .correction, .objectionReject, .objectionAccept: true; default: false } }
    private var valid: Bool { switch action { case .integrityRequest: !form.questionNumbers.isEmpty && !form.instructions.isEmpty; case .integrityReview: form.penaltyDecision != "penalty" || form.reason.count >= 5; case .correction: !form.newAnswer.isEmpty && form.reason.count >= 5; case .objectionReject: form.reason.count >= 5; case .objectionAccept: !form.questionContent.isEmpty && !form.newAnswer.isEmpty && form.reason.count >= 5 } }
}
