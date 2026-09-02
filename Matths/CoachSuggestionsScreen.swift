import SwiftUI

@MainActor
final class CoachSuggestionsScreenModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case mine = "내 제안"
        case approved = "반영됨"
        case pending = "검수 대기"
        var id: String { rawValue }
    }

    @Published var board: ServerAPI.CoachSuggestionBoard?
    @Published var section: Section = .mine
    @Published var mode = "mild"
    @Published var situation = "study_prompt"
    @Published var message = ""
    @Published var rejectionReason = ""
    @Published var rejectingSuggestion: ServerAPI.CoachSuggestion?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private var generation = UUID()

    var visibleSections: [Section] {
        board?.isAdmin == true ? [.pending, .mine, .approved] : [.mine, .approved]
    }

    var items: [ServerAPI.CoachSuggestion] {
        guard let board else { return [] }
        switch section {
        case .mine: return board.mine
        case .approved: return board.approved
        case .pending: return board.pending
        }
    }

    func load(reset: Bool = false) async {
        if reset {
            generation = UUID()
            board = nil
        }
        let requestGeneration = generation
        isLoading = board == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.coachSuggestionBoard()
            guard requestGeneration == generation else { return }
            board = value
            if value.isAdmin && !value.pending.isEmpty && section == .mine { section = .pending }
            if !value.isAdmin && section == .pending { section = .mine }
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation { isLoading = false }
    }

    func submit() async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else {
            errorMessage = "문구를 4자 이상 입력해 주세요."
            return
        }
        guard trimmed.count <= 120 else {
            errorMessage = "문구는 120자까지 입력할 수 있습니다."
            return
        }
        await perform(id: "new", notice: "제안을 접수했습니다. 검수 결과는 내 제안에서 확인할 수 있습니다.") {
            _ = try await ServerAPI.createCoachSuggestion(
                mode: mode, situation: situation, message: trimmed)
        }
        if errorMessage == nil {
            message = ""
            section = .mine
        }
    }

    func approve(_ suggestion: ServerAPI.CoachSuggestion) async {
        await perform(id: suggestion.id, notice: "문구를 코치 메시지에 반영했습니다.") {
            _ = try await ServerAPI.moderateCoachSuggestion(
                suggestionID: suggestion.id, approve: true)
        }
    }

    func beginReject(_ suggestion: ServerAPI.CoachSuggestion) {
        rejectionReason = ""
        rejectingSuggestion = suggestion
    }

    func reject() async {
        guard let suggestion = rejectingSuggestion else { return }
        let reason = rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else {
            errorMessage = "반려 사유를 입력해 주세요."
            return
        }
        await perform(id: suggestion.id, notice: "문구를 반려하고 제안자에게 사유를 전달했습니다.") {
            _ = try await ServerAPI.moderateCoachSuggestion(
                suggestionID: suggestion.id, approve: false, rejectionReason: reason)
        }
        if errorMessage == nil { rejectingSuggestion = nil }
    }

    private func perform(id: String, notice: String, operation: () async throws -> Void) async {
        guard actionID == nil else { return }
        actionID = id
        errorMessage = nil
        noticeMessage = nil
        do {
            try await operation()
            board = try await ServerAPI.coachSuggestionBoard()
            noticeMessage = notice
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

struct CoachSuggestionsScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = CoachSuggestionsScreenModel()
    private let onClose: (() -> Void)?

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { viewport in
            Group {
                if model.isLoading && model.board == nil {
                    stateShell {
                        ProgressView().tint(Tokens.primary)
                        Text("코치 의견함을 불러오는 중입니다").font(.mHeading)
                    }
                } else if model.board != nil {
                    content(viewport)
                } else {
                    failureState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.paper)
        .task { if model.board == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.load(reset: true) }
        }
        .compactHeightSheet(item: $model.rejectingSuggestion) { _ in rejectSheet }
    }

    @ViewBuilder private func content(_ viewport: GeometryProxy) -> some View {
        if compactLandscape {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                composer
                    .frame(width: min(330, viewport.size.width * 0.39))
                suggestionList
            }
            .padding(.horizontal, max(12, viewport.safeAreaInsets.leading + 12))
            .padding(.vertical, Tokens.Space.s2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    pageHeader
                    composer
                    suggestionList
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .refreshable { await model.load() }
        }
    }

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("코치 의견함").font(.mTitle).foregroundStyle(Tokens.ink)
                Text("학생이 실제로 듣고 싶은 문구를 제안하고 반영 상태를 확인합니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Spacer()
            closeButton
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: compactLandscape ? Tokens.Space.s2 : Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("새 코치 문구").font(.mHeading).foregroundStyle(Tokens.ink)
                    if !compactLandscape {
                        Text("4~120자 · 외부 링크 제외").font(.mMicro).foregroundStyle(Tokens.text3)
                    }
                }
                Spacer(minLength: Tokens.Space.s2)
                if compactLandscape { closeButton }
            }

            Picker("말투", selection: $model.mode) {
                Text("부드럽게").tag("mild")
                Text("직설적으로").tag("spicy")
                Text("담백하게").tag("silent")
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(situations, id: \.key) { item in
                    Button(item.label) { model.situation = item.key }
                }
            } label: {
                HStack {
                    Label(situationLabel(model.situation), systemImage: "text.bubble")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                }
                .font(.mCaption)
                .foregroundStyle(Tokens.ink)
                .padding(.horizontal, Tokens.Space.s3)
                .frame(minHeight: compactLandscape ? 38 : 44)
                .background(Tokens.paper,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            }
            .accessibilityLabel("문구 상황, \(situationLabel(model.situation))")

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $model.message)
                    .font(.mBody)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: compactLandscape ? 52 : 120)
                    .background(Tokens.paper,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm,
                                                     style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .strokeBorder(model.message.count > 120 ? Tokens.danger : Tokens.line,
                                          lineWidth: 1)
                    }
                    .accessibilityLabel("제안할 코치 문구")
                if model.message.isEmpty {
                    Text("듣고 싶은 한 문장")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .padding(.leading, 12)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topLeading)
                        .allowsHitTesting(false)
                }
                Text("\(model.message.count)/120")
                    .font(.mMicro.monospacedDigit())
                    .foregroundStyle(model.message.count > 120 ? Tokens.danger : Tokens.text3)
                    .padding(8)
                    .allowsHitTesting(false)
            }

            submitButton

            feedbackText
        }
        .coachSuggestionSurface()
    }

    @ViewBuilder private var submitButton: some View {
        let disabled = model.actionID != nil
            || model.message.trimmingCharacters(in: .whitespacesAndNewlines).count < 4
            || model.message.count > 120
        if compactLandscape {
            Button {
                Task { await model.submit() }
            } label: {
                if model.actionID == "new" { ProgressView().tint(Tokens.onBrand) }
                else { Text("검수 요청 보내기") }
            }
            .buttonStyle(.borderedProminent)
            .tint(Tokens.actionPrimary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(disabled)
        } else {
            Button {
                Task { await model.submit() }
            } label: {
                if model.actionID == "new" { ProgressView().tint(Tokens.onBrand) }
                else { Text("검수 요청 보내기") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(disabled)
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                Picker("목록", selection: $model.section) {
                    ForEach(model.visibleSections) { section in
                        Text(sectionTitle(section)).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                Button { Task { await model.load() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .accessibilityLabel("코치 의견함 새로고침")
            }

            if model.items.isEmpty {
                VStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "bubble.left.and.exclamationmark.bubble.right")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Tokens.text3)
                    Text(emptyLabel).font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text(emptyDetail).font(.mCaption).foregroundStyle(Tokens.text3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(model.items) { suggestion in suggestionRow(suggestion) }
                    }
                }
                .refreshable { await model.load() }
            }
        }
        .coachSuggestionSurface()
    }

    private func suggestionRow(_ suggestion: ServerAPI.CoachSuggestion) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Label(modeLabel(suggestion.mode), systemImage: modeIcon(suggestion.mode))
                    .font(.mMicro).foregroundStyle(Tokens.primary)
                Text(situationLabel(suggestion.situation))
                    .font(.mMicro).foregroundStyle(Tokens.text3)
                Spacer(minLength: Tokens.Space.s2)
                statusBadge(suggestion.status)
            }
            Text(suggestion.message)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text(suggestion.authorName).font(.mMicro).foregroundStyle(Tokens.text3)
                Spacer()
                if model.section == .pending && model.board?.isAdmin == true {
                    Button("반려", role: .destructive) { model.beginReject(suggestion) }
                        .buttonStyle(.bordered).tint(Tokens.danger)
                    Button("반영") { Task { await model.approve(suggestion) } }
                        .buttonStyle(.borderedProminent).tint(Tokens.actionPrimary)
                }
            }
            if suggestion.status == "rejected", !suggestion.rejectionReason.isEmpty {
                Text("반려 사유 · \(suggestion.rejectionReason)")
                    .font(.mMicro).foregroundStyle(Tokens.danger)
            }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .opacity(model.actionID == suggestion.id ? 0.55 : 1)
        .disabled(model.actionID != nil)
    }

    private var rejectSheet: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("제안 반려").font(.mTitle).foregroundStyle(Tokens.ink)
            Text(model.rejectingSuggestion?.message ?? "")
                .font(.mBody).foregroundStyle(Tokens.text2)
                .padding(Tokens.Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            TextField("반려 사유", text: $model.rejectionReason, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                Button("취소") { model.rejectingSuggestion = nil }
                    .buttonStyle(SecondaryButtonStyle())
                Button("사유 전달 후 반려", role: .destructive) { Task { await model.reject() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.rejectionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            feedbackText
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: 560)
    }

    private var closeButton: some View {
        Button {
            if let onClose { onClose() } else { store.route = .services }
        } label: {
            Image(systemName: "xmark").frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.text3)
        .accessibilityLabel("코치 의견함 닫기")
    }

    @ViewBuilder private var feedbackText: some View {
        if let message = model.errorMessage {
            Text(message).font(.mCaption).foregroundStyle(Tokens.danger)
                .fixedSize(horizontal: false, vertical: true)
        } else if let message = model.noticeMessage {
            Text(message).font(.mCaption).foregroundStyle(Tokens.success)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var failureState: some View {
        stateShell {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Tokens.danger)
            Text("코치 의견함을 열지 못했습니다").font(.mHeading)
            Text(model.errorMessage ?? "잠시 후 다시 시도해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            Button("다시 시도") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func stateShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Tokens.Space.s3) { content() }
            .padding(Tokens.Space.s5).frame(maxWidth: 460).coachSuggestionSurface()
    }

    private var situations: [(key: String, label: String)] { [
        ("correct", "정답을 맞혔을 때"),
        ("incorrect", "틀렸을 때"),
        ("unanswered", "답을 비웠을 때"),
        ("study_prompt", "공부를 시작할 때"),
    ] }

    private func situationLabel(_ key: String) -> String {
        situations.first(where: { $0.key == key })?.label ?? "기타 상황"
    }

    private func modeLabel(_ key: String) -> String {
        switch key { case "spicy": "직설"; case "silent": "담백"; default: "부드러움" }
    }

    private func modeIcon(_ key: String) -> String {
        switch key { case "spicy": "flame.fill"; case "silent": "minus.circle.fill"; default: "heart.fill" }
    }

    private func sectionTitle(_ section: CoachSuggestionsScreenModel.Section) -> String {
        guard let board = model.board else { return section.rawValue }
        switch section {
        case .mine: return "내 제안 \(board.mine.count)"
        case .approved: return "반영됨 \(board.approved.count)"
        case .pending: return "검수 \(board.pending.count)"
        }
    }

    private var emptyLabel: String {
        switch model.section {
        case .mine: "아직 제안한 문구가 없습니다."
        case .approved: "아직 반영된 문구가 없습니다."
        case .pending: "검수를 기다리는 문구가 없습니다."
        }
    }

    private var emptyDetail: String {
        model.section == .mine
            ? "왼쪽 입력창에서 듣고 싶은 코치 문구를 제안해 보세요."
            : "새 항목이 생기면 이 목록에 표시됩니다."
    }

    @ViewBuilder private func statusBadge(_ status: String) -> some View {
        let value: (String, Color) = switch status {
        case "approved": ("반영됨", Tokens.success)
        case "rejected": ("반려", Tokens.danger)
        default: ("검수 중", Tokens.primary)
        }
        Text(value.0)
            .font(.mMicro).foregroundStyle(value.1)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(value.1.opacity(0.10), in: Capsule())
    }
}

private struct CoachSuggestionSurface: ViewModifier {
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
    func coachSuggestionSurface() -> some View { modifier(CoachSuggestionSurface()) }
}
