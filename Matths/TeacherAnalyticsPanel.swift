import SwiftUI

@MainActor
private final class TeacherAnalyticsModel: ObservableObject {
    @Published var analytics: ServerAPI.TeacherAcademyAnalytics?
    @Published var selectedClassID = ""
    @Published var selectedPeriodKey = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var generation = UUID()
    private var requestID = UUID()

    func load(classID: String? = nil, period: String? = nil) async {
        if let classID { selectedClassID = classID }
        if let period { selectedPeriodKey = period }
        let currentGeneration = generation
        let currentRequestID = UUID()
        requestID = currentRequestID
        isLoading = true
        errorMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyAnalytics(
                period: selectedPeriodKey.isEmpty ? nil : selectedPeriodKey,
                classID: selectedClassID.isEmpty ? nil : selectedClassID)
            guard currentGeneration == generation, currentRequestID == requestID else { return }
            analytics = value
            selectedClassID = value.scope.academyClass?.id ?? ""
            selectedPeriodKey = value.period.key
        } catch is CancellationError {
            return
        } catch {
            guard currentGeneration == generation, currentRequestID == requestID else { return }
            errorMessage = (error as? ServerAPIError)?.errorDescription
                ?? (error as NSError).localizedDescription
        }
        if currentGeneration == generation, currentRequestID == requestID { isLoading = false }
    }

    func resetAndLoad() async {
        generation = UUID()
        analytics = nil
        selectedClassID = ""
        selectedPeriodKey = ""
        await load()
    }
}

/// 웹 학원 대시보드와 반 통계가 쓰는 동일한 서버 집계 결과를 이동 중에도 읽을 수 있게
/// 재구성한다. 가로 화면에서는 핵심 지표와 조치 대상을 좌우 독립 스크롤로 분리한다.
struct TeacherAnalyticsPanel: View {
    let classes: [ServerAPI.AcademyClassSummary]
    let onInspectStudent: (String) -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = TeacherAnalyticsModel()

    private var splitLayout: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    private var accessibleClasses: [ServerAPI.AcademyClassSummary] {
        classes.filter { $0.canManage != false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            filterBar
            Group {
                if model.isLoading && model.analytics == nil {
                    ProgressView("학습 현황을 계산하는 중입니다")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let analytics = model.analytics {
                    analyticsBody(analytics)
                } else {
                    failureState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { if model.analytics == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.resetAndLoad() }
        }
    }

    private var filterBar: some View {
        HStack(spacing: Tokens.Space.s2) {
            Menu {
                Button {
                    Task { await model.load(classID: "") }
                } label: {
                    if model.selectedClassID.isEmpty {
                        Label("학원 전체", systemImage: "checkmark")
                    } else {
                        Text("학원 전체")
                    }
                }
                if !accessibleClasses.isEmpty { Divider() }
                ForEach(accessibleClasses) { academyClass in
                    Button {
                        Task { await model.load(classID: academyClass.id) }
                    } label: {
                        if model.selectedClassID == academyClass.id {
                            Label(academyClass.name, systemImage: "checkmark")
                        } else {
                            Text(academyClass.name)
                        }
                    }
                }
            } label: {
                Label(scopeTitle, systemImage: "building.2")
                    .font(.mCaption)
                    .lineLimit(1)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(model.isLoading)

            if let analytics = model.analytics {
                Menu {
                    ForEach(analytics.period.options) { option in
                        Button {
                            Task { await model.load(period: option.key) }
                        } label: {
                            if option.key == analytics.period.key {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    Label(shortPeriod(analytics.period.key), systemImage: "calendar")
                        .font(.mCaption)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
                .disabled(model.isLoading)
            }
            Spacer(minLength: 0)
            if model.isLoading { ProgressView().tint(Tokens.primary) }
            Button {
                Task { await model.load() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .disabled(model.isLoading)
            .accessibilityLabel("학습 현황 새로고침")
        }
    }

    @ViewBuilder
    private func analyticsBody(_ analytics: ServerAPI.TeacherAcademyAnalytics) -> some View {
        if splitLayout {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        headline(analytics)
                        healthCard(analytics.health)
                        growthCard(analytics.growth)
                    }
                    .padding(.bottom, Tokens.Space.s2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        attentionCard(analytics.attentionStudents)
                        mathMapCard(analytics.mathMap)
                        summaryCard(analytics.summary)
                    }
                    .padding(.bottom, Tokens.Space.s2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    headline(analytics)
                    healthCard(analytics.health)
                    growthCard(analytics.growth)
                    attentionCard(analytics.attentionStudents)
                    mathMapCard(analytics.mathMap)
                    summaryCard(analytics.summary)
                }
            }
        }
    }

    private func headline(_ analytics: ServerAPI.TeacherAcademyAnalytics) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(analytics.scope.academyClass?.name ?? analytics.academy.name)
                        .font(.mHeading).foregroundStyle(Tokens.ink)
                    Text("\(analytics.period.label) · 미학습 학생도 평균에 포함")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Spacer(minLength: 0)
                Text(analytics.hasActivity ? "집계 완료" : "학습 기록 없음")
                    .font(.mMicro)
                    .foregroundStyle(analytics.hasActivity ? Tokens.successInk : Tokens.text3)
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: splitLayout ? 116 : 142), spacing: Tokens.Space.s2)],
                spacing: Tokens.Space.s2
            ) {
                ForEach(analytics.cards) { card in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.label).font(.mMicro).foregroundStyle(Tokens.text3)
                        Text(card.value).font(.mBodyB.monospacedDigit()).foregroundStyle(Tokens.ink)
                        Text(card.detail).font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .padding(Tokens.Space.s2)
                    .background(Tokens.paper2,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .analyticsSurface()
    }

    private func healthCard(_ health: ServerAPI.TeacherAcademyAnalytics.Health) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("학습 건강도").font(.mBodyB)
                    Text("목표 학습일 \(health.targetLearningDays)일 · 데이터 반영 \(Int(health.dataCoverage.rounded()))%")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Spacer(minLength: 0)
                Text(health.score.map { "\(Int($0.rounded()))점" } ?? "—")
                    .font(.mHeading.monospacedDigit())
                    .foregroundStyle(healthColor(health.key))
            }
            HStack(spacing: Tokens.Space.s2) {
                healthDistribution("건강", health.distribution.healthy, Tokens.successInk)
                healthDistribution("관찰", health.distribution.watch, Tokens.warningInk)
                healthDistribution("주의", health.distribution.risk, Tokens.dangerInk)
            }
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Tokens.Space.s2
            ) {
                healthComponent("학습 참여", health.components.engagement)
                healthComponent("첫 시도 정확도", health.components.accuracy)
                healthComponent("오답 복습", health.components.review)
                healthComponent("재도전 회복", health.components.recovery)
            }
        }
        .analyticsSurface()
    }

    private func healthDistribution(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Text("\(value)명").font(.mBodyB.monospacedDigit()).foregroundStyle(Tokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func healthComponent(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.mMicro).foregroundStyle(Tokens.text2)
                Spacer(minLength: 0)
                Text(value.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(.mMicro.monospacedDigit()).foregroundStyle(Tokens.ink)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Tokens.line)
                    Capsule().fill(Tokens.actionPrimary)
                        .frame(width: geometry.size.width * CGFloat(min(max(value ?? 0, 0), 100) / 100))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
    }

    private func growthCard(_ points: [ServerAPI.TeacherAcademyAnalytics.GrowthPoint]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("주차별 성장").font(.mBodyB)
            Text("막대는 중복 제외 문제 수, 숫자는 첫 시도 정답률입니다.")
                .font(.mMicro).foregroundStyle(Tokens.text3)
            if points.isEmpty {
                Text("표시할 주차별 기록이 없습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            } else {
                let maximum = max(points.map(\.uniqueProblems).max() ?? 0, 1)
                HStack(alignment: .bottom, spacing: Tokens.Space.s2) {
                    ForEach(points) { point in
                        VStack(spacing: 4) {
                            Text(point.accuracy.map { "\(Int($0.rounded()))%" } ?? "—")
                                .font(.mMicro.monospacedDigit()).foregroundStyle(Tokens.text2)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Tokens.actionPrimary)
                                .frame(height: max(6, 74 * CGFloat(point.uniqueProblems) / CGFloat(maximum)))
                            Text(point.label).font(.mMicro).foregroundStyle(Tokens.text3)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(point.label), \(point.uniqueProblems)문제, 정답률 \(point.accuracy.map { "\(Int($0.rounded()))퍼센트" } ?? "데이터 없음")")
                    }
                }
                .frame(minHeight: 112, alignment: .bottom)
            }
        }
        .analyticsSurface()
    }

    private func attentionCard(
        _ students: [ServerAPI.TeacherAcademyAnalytics.AttentionStudent]
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Text("지금 확인할 학생").font(.mBodyB)
                Spacer(minLength: 0)
                Text("\(students.count)명")
                    .font(.mCaption.monospacedDigit())
                    .foregroundStyle(students.isEmpty ? Tokens.successInk : Tokens.dangerInk)
            }
            if students.isEmpty {
                Label("현재 확인 항목이 없습니다", systemImage: "checkmark.circle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            } else {
                ForEach(students.prefix(splitLayout ? 6 : 8)) { item in
                    Button {
                        onInspectStudent(item.membership.id)
                    } label: {
                        HStack(spacing: Tokens.Space.s2) {
                            Text(item.membership.student.name.first.map(String.init) ?? "학")
                                .font(.mCaption).foregroundStyle(Tokens.onBrand)
                                .frame(width: 34, height: 34)
                                .background(Tokens.dangerInk,
                                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.membership.student.name)
                                    .font(.mCaption).foregroundStyle(Tokens.ink)
                                Text(item.reasons.joined(separator: " · "))
                                    .font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Tokens.text3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("학생 상세 통계로 이동합니다")
                    if item.id != students.prefix(splitLayout ? 6 : 8).last?.id {
                        Divider()
                    }
                }
            }
        }
        .analyticsSurface()
    }

    private func mathMapCard(_ map: ServerAPI.TeacherAcademyAnalytics.MathMap) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("반 수학 지도").font(.mBodyB)
                    Text("분석 \(map.analyzedConceptCount)개 · \(map.graphVersion)")
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(map.overallMastery.map { "평균 \(Int($0.rounded()))%" } ?? "분석 전")
                    .font(.mCaption).foregroundStyle(Tokens.primary)
            }
            if let recommendation = map.recommendation {
                VStack(alignment: .leading, spacing: 3) {
                    Text("우선 복습 · \(recommendation.conceptTitle)")
                        .font(.mCaption).foregroundStyle(Tokens.warningInk)
                    Text(recommendation.reason).font(.mMicro).foregroundStyle(Tokens.text2)
                    if recommendation.problemCount > 0 {
                        Text("학생별 \(recommendation.problemCount)문제 구성 제안 · 자동 배정 아님")
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                    }
                }
                .padding(Tokens.Space.s2)
                .background(Tokens.warningSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            }
            if map.heatmap.isEmpty {
                Text("개념별 풀이가 5개 이상 쌓이면 숙달도 지도가 표시됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: splitLayout ? 102 : 126), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(map.heatmap) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.conceptTitle).font(.mMicro).lineLimit(2)
                            Text(item.mastery.map { "\(Int($0.rounded()))%" } ?? "Unknown")
                                .font(.mCaption.monospacedDigit())
                            Text("\(item.analyzedCount)/\(item.totalStudents)명")
                                .font(.mMicro)
                        }
                        .foregroundStyle(heatmapInk(item.mastery))
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .padding(7)
                        .background(heatmapColor(item.mastery),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .analyticsSurface()
    }

    private func summaryCard(_ bullets: [ServerAPI.TeacherStudentStatistics.Bullet]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("운영 요약").font(.mBodyB)
            ForEach(bullets) { bullet in
                VStack(alignment: .leading, spacing: 2) {
                    Text(bullet.label).font(.mCaption).foregroundStyle(Tokens.ink)
                    Text(bullet.text).font(.mMicro).foregroundStyle(Tokens.text2)
                }
            }
        }
        .analyticsSurface(fill: Tokens.primarySoft)
    }

    private var failureState: some View {
        VStack(spacing: Tokens.Space.s3) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32)).foregroundStyle(Tokens.text3)
            Text("학습 현황을 열지 못했습니다").font(.mHeading)
            Text(model.errorMessage ?? "네트워크 연결을 확인한 뒤 다시 시도해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center)
            Button("다시 불러오기") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle()).frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, Tokens.Space.s4)
    }

    private var scopeTitle: String {
        if model.selectedClassID.isEmpty { return "학원 전체" }
        return classes.first(where: { $0.id == model.selectedClassID })?.name ?? "선택한 반"
    }

    private func shortPeriod(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return "기간" }
        return "\(month)월"
    }

    private func healthColor(_ key: String) -> Color {
        switch key {
        case "HEALTHY": Tokens.successInk
        case "WATCH": Tokens.warningInk
        default: Tokens.dangerInk
        }
    }

    private func heatmapColor(_ mastery: Double?) -> Color {
        guard let mastery else { return Tokens.paper2 }
        if mastery < 45 { return Tokens.dangerSoft }
        if mastery < 65 { return Tokens.warningSoft }
        if mastery < 80 { return Tokens.primarySoft }
        return Tokens.successSoft
    }

    private func heatmapInk(_ mastery: Double?) -> Color {
        guard let mastery else { return Tokens.text3 }
        if mastery < 45 { return Tokens.dangerInk }
        if mastery < 65 { return Tokens.warningInk }
        if mastery < 80 { return Tokens.primary }
        return Tokens.successInk
    }
}

private struct TeacherAnalyticsSurface: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s3)
            .background(fill,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func analyticsSurface(fill: Color = Tokens.paper) -> some View {
        modifier(TeacherAnalyticsSurface(fill: fill))
    }
}
