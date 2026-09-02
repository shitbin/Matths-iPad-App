import SwiftUI

@MainActor
private final class AdminUserActivityModel: ObservableObject {
    @Published var activity: ServerAPI.AdminUserActivityPage?
    @Published var assessment: ServerAPI.AdminAssessmentDetail?
    @Published var selectedID: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(userID: String, kind: String, page: Int = 1) async {
        isLoading = activity == nil
        errorMessage = nil
        assessment = nil
        do {
            let value = try await ServerAPI.adminUserActivity(userID: userID, kind: kind, page: page)
            activity = value
            if !value.items.contains(where: { $0.id == selectedID }) { selectedID = value.items.first?.id }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
        isLoading = false
    }

    func loadAssessment(userID: String, attemptID: String) async {
        guard !attemptID.isEmpty else { return }
        isLoading = assessment == nil
        errorMessage = nil
        do { assessment = try await ServerAPI.adminUserAssessment(userID: userID, attemptID: attemptID) }
        catch is CancellationError { return }
        catch { errorMessage = readable(error) }
        isLoading = false
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription
    }
}

struct AdminUserActivityScreen: View {
    private enum Kind: String, CaseIterable, Identifiable {
        case learning, problems, quick, assessments, community, moderation
        var id: String { rawValue }
        var label: String {
            switch self {
            case .learning: "학습"
            case .problems: "문제"
            case .quick: "눈풀이"
            case .assessments: "평가"
            case .community: "게시판"
            case .moderation: "관리"
            }
        }
        var icon: String {
            switch self {
            case .learning: "book.pages"
            case .problems: "checkmark.square"
            case .quick: "timer"
            case .assessments: "doc.text.magnifyingglass"
            case .community: "bubble.left.and.bubble.right"
            case .moderation: "shield.checkered"
            }
        }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminUserActivityModel()
    @State private var kind: Kind = .learning

    let userID: String
    var initialAttemptID: String?
    let onClose: () -> Void

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    private var selectedItem: ServerAPI.AdminUserActivityItem? {
        model.activity?.items.first(where: { $0.id == model.selectedID }) ?? model.activity?.items.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading).background(Tokens.dangerSoft)
            }
            if model.isLoading && model.activity == nil && model.assessment == nil {
                Spacer(); ProgressView("활동 기록을 불러오는 중입니다"); Spacer()
            } else if compactLandscape {
                HStack(spacing: 0) {
                    listColumn.frame(width: 340)
                    Divider()
                    detailColumn.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) { listColumn; detailColumn }
                        .readableWidth(Tokens.readableWidth).adaptiveHPadding().adaptiveVPadding()
                }
            }
        }
        .background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .task {
            if let attemptID = initialAttemptID, !attemptID.isEmpty {
                kind = .assessments
                async let list: Void = model.load(userID: userID, kind: Kind.assessments.rawValue)
                async let detail: Void = model.loadAssessment(userID: userID, attemptID: attemptID)
                _ = await (list, detail)
            } else {
                await model.load(userID: userID, kind: kind.rawValue)
            }
        }
        .onChange(of: kind) { _, value in Task { await model.load(userID: userID, kind: value.rawValue) } }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: onClose) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("활동 기록 닫기")
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.activity?.user.name ?? model.assessment?.user.name ?? "사용자").font(.mHeading)
                    Text("전체 활동·평가 원본 기록").font(.mCaption).foregroundStyle(Tokens.text2)
                }
                Spacer()
                Button { Task { await model.load(userID: userID, kind: kind.rawValue, page: model.activity?.pagination.page ?? 1) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("새로고침")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Kind.allCases) { item in
                        Button { kind = item } label: {
                            Label(item.label, systemImage: item.icon).font(.mCaption.weight(.semibold))
                                .padding(.horizontal, 12).frame(minHeight: 36)
                                .foregroundStyle(kind == item ? Color.white : Tokens.text2)
                                .background(kind == item ? Tokens.primary : Tokens.paper, in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(kind.label) 기록").font(.mBodyB)
                Spacer()
                Text("\(model.activity?.pagination.total ?? 0)건").font(.mCaption.monospacedDigit()).foregroundStyle(Tokens.text3)
            }.padding(12)
            if let items = model.activity?.items, !items.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in activityRow(item) }
                    }.padding(.horizontal, 10).padding(.bottom, 10)
                }
                pagination
            } else {
                ContentUnavailableView("기록 없음", systemImage: "clock.badge.questionmark", description: Text("이 유형의 활동 기록이 없습니다."))
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }.background(Tokens.paper)
    }

    private func activityRow(_ item: ServerAPI.AdminUserActivityItem) -> some View {
        Button {
            model.selectedID = item.id
            if kind == .assessments, !item.attemptId.isEmpty {
                Task { await model.loadAssessment(userID: userID, attemptID: item.attemptId) }
            } else { model.assessment = nil }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(statusLabel(item.status)).font(.mMicro).foregroundStyle(statusColor(item.status))
                    Spacer()
                    Text(dateLabel(item.occurredAt)).font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Text(item.title).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                if !item.subtitle.isEmpty { Text(item.subtitle).font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(1) }
            }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(model.selectedID == item.id ? Tokens.primary.opacity(0.11) : Tokens.surface,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }.buttonStyle(.plain).accessibilityHint("활동 세부 내용을 표시합니다")
    }

    @ViewBuilder private var detailColumn: some View {
        if let value = model.assessment {
            assessmentDetail(value)
        } else if let item = selectedItem {
            ScrollView { activityDetail(item).padding(16) }
        } else {
            ContentUnavailableView("활동을 선택하세요", systemImage: "cursorarrow.click")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func activityDetail(_ item: ServerAPI.AdminUserActivityItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { badge(statusLabel(item.status)); Spacer(); Text(dateLabel(item.occurredAt)).font(.mCaption).foregroundStyle(Tokens.text3) }
            Text(item.title).font(compactLandscape ? .mHeading : .mTitle)
            if !item.subtitle.isEmpty { field("범위", item.subtitle) }
            field("상세", item.detail)
            if !item.metadata.isEmpty { field("부가 기록", item.metadata) }
            if kind == .assessments, !item.attemptId.isEmpty {
                Button {
                    Task { await model.loadAssessment(userID: userID, attemptID: item.attemptId) }
                } label: { Label("문항·제출 답안 보기", systemImage: "list.number").frame(maxWidth: .infinity, minHeight: 46) }
                    .buttonStyle(.borderedProminent)
            }
        }.frame(maxWidth: 760, alignment: .leading)
    }

    private func assessmentDetail(_ value: ServerAPI.AdminAssessmentDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { model.assessment = nil } label: { Label("활동 목록", systemImage: "chevron.left") }.buttonStyle(.bordered)
                    Spacer(); badge(statusLabel(value.attempt.status))
                }
                Text(value.attempt.title).font(compactLandscape ? .mHeading : .mTitle)
                HStack(spacing: 8) {
                    metric("점수", value.attempt.scorePercent.map { "\($0)점" } ?? "미채점")
                    metric("득점", "\(value.attempt.earnedPoints)/\(value.attempt.totalPoints)")
                    metric("답안", "\(value.attempt.answeredCount)개")
                    metric("소요", duration(value.attempt.elapsedTimeMs))
                }
                if !value.attempt.disqualifiedReason.isEmpty { field("무효 처리 사유", value.attempt.disqualifiedReason) }
                Text("문항별 답안").font(.mBodyB)
                ForEach(value.attempt.questions) { question in questionCard(question) }
            }.padding(16).frame(maxWidth: 820, alignment: .leading)
        }
    }

    private func questionCard(_ question: ServerAPI.AdminAssessmentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(question.number)번").font(.mBodyB)
                if !question.typeLabel.isEmpty { badge(question.typeLabel) }
                Spacer()
                badge(question.isCorrect == nil ? "미채점" : question.isCorrect == true ? "정답" : "오답")
            }
            Text(question.prompt.isEmpty ? "문항 내용 없음" : question.prompt).font(.mBody)
            ForEach(question.choices) { choice in
                Text("\(choice.key). \(choice.text)").font(.mCaption)
                    .foregroundStyle(choice.key == question.answer ? Tokens.successInk : Tokens.text2)
            }
            Divider()
            HStack { Text("제출 \(question.submittedAnswer.isEmpty ? "—" : question.submittedAnswer)"); Spacer(); Text("정답 \(question.answer.isEmpty ? "—" : question.answer)") }
                .font(.mCaption.monospacedDigit())
            Text("\(question.points)점 · \(duration(question.responseTimeMs)) · 답 변경 \(question.answerChanges)회")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            if !question.solution.isEmpty { field("해설", question.solution) }
        }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var pagination: some View {
        Group {
            if let page = model.activity?.pagination, page.totalPages > 1 {
                HStack {
                    Button("이전") { Task { await model.load(userID: userID, kind: kind.rawValue, page: page.page - 1) } }.disabled(!page.hasPrevious)
                    Spacer(); Text("\(page.page) / \(page.totalPages)").font(.mCaption.monospacedDigit()); Spacer()
                    Button("다음") { Task { await model.load(userID: userID, kind: kind.rawValue, page: page.page + 1) } }.disabled(!page.hasNext)
                }.buttonStyle(.bordered).padding(10).background(Tokens.surface)
            }
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value).font(.mBodyB.monospacedDigit()); Text(label).font(.mMicro).foregroundStyle(Tokens.text3) }
            .padding(9).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
    }
    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(label).font(.mCaption).foregroundStyle(Tokens.text2); Text(value.isEmpty ? "—" : value).font(.mBody).textSelection(.enabled) }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
    }
    private func badge(_ value: String) -> some View {
        Text(value.isEmpty ? "기록" : value).font(.mCaption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(Tokens.primary).background(Tokens.primary.opacity(0.1), in: Capsule())
    }
    private func statusLabel(_ value: String) -> String {
        ["correct": "정답", "wrong": "오답", "submitted": "제출", "completed": "완료", "published": "공개", "hidden": "숨김", "deleted": "삭제", "disqualified": "무효"][value.lowercased()] ?? (value.isEmpty ? "기록" : value)
    }
    private func statusColor(_ value: String) -> Color {
        value == "correct" || value == "completed" ? Tokens.successInk : value == "wrong" || value == "deleted" ? Tokens.dangerInk : Tokens.primary
    }
    private func duration(_ milliseconds: Int) -> String {
        let seconds = max(0, milliseconds) / 1_000
        return seconds >= 60 ? "\(seconds / 60)분 \(seconds % 60)초" : "\(seconds)초"
    }
    private func dateLabel(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        return date?.formatted(date: .numeric, time: .shortened) ?? value
    }
}
