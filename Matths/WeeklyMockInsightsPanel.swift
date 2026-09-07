import SwiftUI

/// Official weekly-mock response aggregates, not the learning Math Map model.
/// All state is ephemeral and belongs to an account generation + scope.
struct WeeklyMockInsightsPanel: View {
    let scope: WeeklyMockInsightScope
    @EnvironmentObject private var store: AppStore
    @State private var response: ServerAPI.WeeklyMockInsightsResponse?
    @State private var owner: AccountRequestOwner?
    @State private var loadedScope: WeeklyMockInsightScope?
    @State private var loadedRole = ""
    @State private var requestID = UUID()
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var role: String { store.serverProfile?.role?.lowercased() ?? "" }
    private var trigger: String {
        [String(describing: store.captureAccountSessionBoundary()), DataScope.slot, role, scope.key].joined(separator: "#")
    }
    private var belongsToCurrentView: Bool {
        owner?.isCurrent(in: store) == true && loadedScope == scope && loadedRole == role
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("주간 모의고사 · 개념 분석").font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text("최근 공식 36회차에서 확인된 답안의 개념별 오답률입니다. 학습 Math Map과 별도 집계됩니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }.buttonStyle(.plain).disabled(isLoading && belongsToCurrentView)
                    .accessibilityLabel("주간 모의고사 개념 분석 새로고침")
            }
            if belongsToCurrentView, let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                Button("다시 불러오기") { Task { await load() } }.buttonStyle(SecondaryButtonStyle())
            }
            if belongsToCurrentView, let response {
                WeeklyMockInsightSummary(insight: response.overall)
                if !response.classes.isEmpty {
                    Text("반별 비교").font(.mBodyB)
                    Text("현재 승인·배정 학생 기준입니다. 반을 펼치면 해당 반의 개념별 결과를 확인할 수 있습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    ForEach(response.classes) { row in
                        DisclosureGroup {
                            WeeklyMockInsightSummary(insight: row.insight).padding(.top, 8)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.className).font(.mBodyB)
                                Text("\(row.isActive ? "활성 반" : "보관된 반") · 배정 \(row.studentCount)명 · 응시 \(row.insight.participantCount)명")
                                    .font(.mCaption).foregroundStyle(Tokens.text2)
                            }
                        }
                    }
                }
            } else if store.authProvider != "server" || !ServerAPI.hasToken {
                Text("로그인 후 주간 모의고사 개념 분석을 확인할 수 있습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            } else if isLoading || !belongsToCurrentView {
                ProgressView("주간 모의고사 결과를 분석하는 중입니다").font(.mCaption)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding(Tokens.Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .task(id: trigger) { await load() }
        .onDisappear { requestID = UUID(); owner = nil; response = nil; isLoading = false }
    }

    @MainActor private func load() async {
        let expectedID = UUID()
        requestID = expectedID
        guard let captured = AccountRequestOwner(store: store) else {
            response = nil; owner = nil; isLoading = false; errorMessage = nil
            return
        }
        let expectedScope = scope, expectedRole = role
        owner = captured; loadedScope = expectedScope; loadedRole = expectedRole
        response = nil; errorMessage = nil; isLoading = true
        defer { if requestID == expectedID { isLoading = false } }
        do {
            let result = try await ServerAPI.weeklyMockInsights(scope: expectedScope, authorization: captured.authorization)
            guard requestID == expectedID, captured.isCurrent(in: store), scope == expectedScope, role == expectedRole else { return }
            response = result
        } catch is CancellationError { return }
        catch {
            guard requestID == expectedID, captured.isCurrent(in: store), scope == expectedScope, role == expectedRole else { return }
            errorMessage = (error as? ServerAPIError)?.errorDescription
                ?? "분석을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
    }
}

private struct WeeklyMockInsightSummary: View {
    let insight: ServerAPI.WeeklyMockInsight
    @State private var showsAllConcepts = false
    private var displayed: [ServerAPI.WeeklyMockConceptInsight] {
        showsAllConcepts ? insight.concepts : Array(insight.concepts.prefix(18))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(insight.scopeLabel).font(.mCaption).foregroundStyle(Tokens.primary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128))], alignment: .leading, spacing: 12) {
                metric("분석 응시자", "\(insight.participantCount)명", "제출 \(insight.submissionCount)건")
                metric("평균 점수", insight.averageScore.map { String(format: "%.1f점", $0) } ?? "—", "공식 \(insight.examCount)회차")
                metric("분석 개념", "\(insight.conceptCount)개", "오답률 높은 순")
            }
            if let hardest = insight.hardestConcept {
                Label("우선 보완 · \(hardest.conceptTitle) (오답률 \(hardest.difficulty)%)", systemImage: "scope")
                    .font(.mCaption).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
            }
            if insight.concepts.isEmpty {
                Text("아직 개념 분석 자료가 없습니다. 개념 정보가 포함된 공식 모의고사 제출 결과가 쌓이면 표시됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2).fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(displayed) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text([item.courseTitle, item.unitTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.mMicro).foregroundStyle(Tokens.text2)
                            Text(item.conceptTitle).font(.mBodyB).foregroundStyle(Tokens.ink)
                            HStack {
                                Text("오답률 \(item.difficulty)%").font(.mBodyB.monospacedDigit())
                                Spacer(minLength: 0)
                                Text(item.label).font(.mMicro)
                            }.foregroundStyle(color(item.level))
                            Text("답안 \(item.responseCount)개 · 정답 \(item.correctCount)개")
                                .font(.mMicro).foregroundStyle(Tokens.text2)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(color(item.level).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                if insight.concepts.count > 18 {
                    Button(showsAllConcepts ? "상위 18개만 보기" : "전체 \(insight.concepts.count)개 개념 보기") {
                        showsAllConcepts.toggle()
                    }.font(.mCaption).frame(minHeight: 44)
                }
            }
        }
    }
    private func metric(_ title: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.mMicro).foregroundStyle(Tokens.text2)
            Text(value).font(.mBodyB.monospacedDigit()).foregroundStyle(Tokens.ink)
            Text(detail).font(.mMicro).foregroundStyle(Tokens.text3)
        }
    }
    private func color(_ level: Int) -> Color {
        switch level { case 4...: Tokens.dangerInk; case 3: Tokens.primary; default: Tokens.successInk }
    }
}
