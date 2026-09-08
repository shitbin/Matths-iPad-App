import SwiftUI

/// A read-only summary, not another set of links to the five tabs. It reuses the
/// existing account-scoped dashboard cache and the server's activity contract.
struct TodayLearningOverview: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    var compact = false
    @State private var dashboard = DashboardActivityCache.load() ?? LocalDashboardSnapshot.make()
    @State private var source = DashboardActivityCache.load() == nil ? "이 기기 기록" : "마지막 동기화 기록"
    @State private var loadedSlot = DataScope.slot
    @State private var refreshing = false
    @State private var failed = false
    @State private var retryID = UUID()
    @State private var requestID = UUID()

    private var visible: ServerAPI.DashboardActivity {
        loadedSlot == DataScope.slot ? dashboard : LocalDashboardSnapshot.make()
    }
    private var accountIdentity: String { DataScope.slot + "|" + (store.authProvider ?? "guest") }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Tokens.Space.s3 : Tokens.Space.s4) {
            HStack {
                Text("최근 7일의 공부").font(.mBodyB)
                Spacer()
                if refreshing { ProgressView().controlSize(.small) }
            }
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                statistic("학습 시간", value: EventLog.formatStudyTime(visible.stats.weeklyStudyMinutes))
                statistic("푼 문제", value: "\(visible.stats.weeklySolvedProblems)개")
                statistic("정답률", value: visible.stats.weeklySolvedProblems > 0 ? "\(visible.stats.correctRate)%" : "—")
            }
            if !compact { activityStrip }
            Divider()
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack {
                    Text("내 학습 진도").font(.mCaption)
                    Spacer()
                    Text("\(store.learningSummary.done) / \(store.learningSummary.total)개 완료")
                        .font(.mCaption).monospacedDigit()
                }
                ProgressView(value: Double(store.learningSummary.done), total: Double(max(1, store.learningSummary.total)))
                    .tint(Tokens.actionPrimary)
                    .accessibilityLabel("전체 개념 학습 진도")
                HStack {
                    Text("오늘 복습할 문제").font(.mCaption).foregroundStyle(Tokens.text2)
                    Spacer()
                    Text("\(store.todayReviewIDs.count)개").font(.mCaption.weight(.semibold)).monospacedDigit()
                }
            }
            Text(loadedSlot == DataScope.slot ? source : "이 기기 기록")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            if failed {
                Button("학습 기록 다시 확인") { retryID = UUID() }
                    .font(.mCaption).frame(minHeight: 44).disabled(refreshing)
            }
        }
        .padding(compact ? Tokens.Space.s3 : Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .accessibilityIdentifier("today-learning-overview")
        .tutorialTarget(.todayProgress)
        .task(id: accountIdentity + "|" + retryID.uuidString) { await refresh() }
        .onChange(of: scenePhase) { _, value in
            if value == .active { retryID = UUID() }
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            requestID = UUID()
            dashboard = LocalDashboardSnapshot.make()
            loadedSlot = DataScope.slot
            source = "이 기기 기록"
            refreshing = false
            failed = false
            retryID = UUID()
        }
    }

    private func statistic(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text2)
            Text(value).font(.mBodyB).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activityStrip: some View {
        HStack(alignment: .bottom, spacing: Tokens.Space.s2) {
            ForEach(Array(visible.weeklyActivity.days.suffix(7).enumerated()), id: \.offset) { _, day in
                VStack(spacing: Tokens.Space.s1) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4).fill(Tokens.paper2)
                        if day.minutes > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.isToday ? Tokens.actionPrimary : Tokens.actionPrimary.opacity(0.45))
                                .frame(height: max(4, 28 * min(1, Double(day.minutes) / Double(max(1, visible.weeklyActivity.maxMinutes)))))
                        }
                    }.frame(height: 28)
                    Text(day.isToday ? "오늘" : day.label).font(.mMicro)
                        .foregroundStyle(day.isToday ? Tokens.ink : Tokens.text2)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.label), \(day.minutes)분 학습")
            }
        }
    }

    @MainActor private func refresh() async {
        let owner = store.captureAccountSessionBoundary()
        let slot = DataScope.slot
        let id = UUID()
        requestID = id
        failed = false
        loadedSlot = slot
        if let cached = DashboardActivityCache.load() {
            dashboard = cached
            source = "마지막 동기화 기록"
        } else {
            dashboard = LocalDashboardSnapshot.make()
            source = "이 기기 기록"
        }
        guard store.authProvider == "server", ServerAPI.hasToken,
              !["teacher", "admin"].contains(store.serverProfile?.role ?? "student") else { return }
        refreshing = true
        defer { if requestID == id { refreshing = false } }
        do {
            let value = try await ServerAPI.getDashboardActivity()
            guard !Task.isCancelled, requestID == id, store.ownsCurrentAccountSession(owner), DataScope.slot == slot else { return }
            dashboard = value
            source = "모든 기기의 학습 기록"
            DashboardActivityCache.save(value, slot: slot)
        } catch {
            guard !Task.isCancelled, requestID == id, store.ownsCurrentAccountSession(owner), DataScope.slot == slot else { return }
            failed = true
            source = DashboardActivityCache.load() == nil ? "연결 전 · 이 기기 기록" : "연결 전 · 마지막 동기화 기록"
        }
    }
}
