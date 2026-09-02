//  ConceptScreenV2.swift
//  Matths
//
//  개념 화면 v2 — 웹의 4단계: 01 개념 이해(성취기준·요약·스텝 카드)
//  → 02 시각 강의 → 03 플레이그라운드 → 04 문제풀이(유형 다양성 게이트).
//
//  단계 소유권: 시각 강의는 **설명 단계 하나만** 소유한다.
//  탐색 단계도 lesson.html 을 통째로 띄우던 때는 설명에서 본 시나리오가
//  탐색에서 한 번 더 재생돼, 학생 입장에서 같은 강의가 두 번 나왔다.
//  지금 탐색에는 개념 정리 글·직접 조작(놀이터)만 남는다.
//
//  원래 CurriculumHubScreen.swift 안에 죽은 허브 화면(CurriculumHubScreen·
//  FeaturedLearningTrack·CourseRowV2·UnitBlockV2·ConceptRowV2)과 한 파일로
//  섞여 있었다. 죽은 코드를 지우면서 살아있는 뷰들(RootView 가 쓰는 이 화면,
//  QuickPracticeScreen·WrongNoteRow 가 쓰는 KatexText, 이 화면이 쓰는
//  ProgressRing)만 여기로 옮겼다 — 파일 경계와 보존 계약을 일치시키기 위해.

import SwiftUI
import WebKit

/// 세리프 숫자 완성도 링 — 카드·글로우 없이 선 하나로
struct ProgressRing: View {
    let percent: Int

    private var displayedPercent: Int { min(100, max(0, percent)) }

    var body: some View {
        ZStack {
            Circle().stroke(Tokens.line, lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(displayedPercent) / 100)
                .stroke(Tokens.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            // 단위 없는 "90"은 점수처럼 보인다. %를 숫자와 함께 넣고, 네 자리
            // "100%"도 작은 링 안에서 잘리지 않도록 끝까지 줄여 보여 준다.
            Text("\(displayedPercent)%")
                .font(.mStat)
                .foregroundStyle(Tokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("학습 진도")
        .accessibilityValue("\(displayedPercent)퍼센트")
    }
}

// MARK: - 개념 화면 v2 (웹 4단계)

private enum ConceptLearningStage: String, CaseIterable, Identifiable {
    case explain, explore, practice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .explain: "설명"
        case .explore: "탐색"
        case .practice: "연습"
        }
    }

    var symbol: String {
        switch self {
        case .explain: "play.rectangle.fill"
        case .explore: "pencil.and.outline"
        case .practice: "checkmark.circle.fill"
        }
    }
}

struct ConceptScreenV2: View {
    @EnvironmentObject private var store: AppStore
    // 기기 이름이 아니라 size class 로 나눈다. Split View 와 Stage Manager 의 iPad 도
    // compact 폭으로 들어오고, iPhone 가로는 폭이 넓어도 세로가 compact 다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var lessonHeight: CGFloat = 420
    @State private var summaryHeight: CGFloat = 60
    @State private var keyHeight: CGFloat = 60
    @State private var dwellStart: Date?
    @State private var activeStage: ConceptLearningStage = .explain

    private var compactWidth: Bool { horizontalSizeClass == .compact }

    /// iPhone 가로에서 본문에 남는 높이는 약 390pt다(상단바, 하단 탭, 홈 인디케이터 제외).
    /// 이 조건에서는 섹션 간격과 크롬 높이를 줄여 한 화면에 실제 내용이 남게 한다.
    private var shortHeight: Bool { verticalSizeClass == .compact }

    private var sectionSpacing: CGFloat { shortHeight ? Tokens.Space.s4 : Tokens.Space.s6 }

    /// 3단계 전환 버튼의 최소 높이. 좁아져도 44pt 아래로 내리지 않는다.
    private var stageMinHeight: CGFloat { shortHeight ? 44 : 52 }

    /// 큰 글씨는 compact 폭에서만 세로로 쌓는다. regular 폭은 900pt 본문이라
    /// 지금처럼 3칸 가로 배치로 충분하다(iPad 회귀 방지).
    private var stacksStages: Bool { compactWidth && dynamicTypeSize.isAccessibilitySize }

    /// 세로가 짧은 문맥(아이폰 가로)에서 탐색·연습 화면을 좌우 두 기둥으로 나눈다.
    ///
    /// 세로로만 쌓으면 설명을 읽고 나서 다시 한참 내려야 문제와 완료가 나온다.
    /// 왼쪽에 설명·탐색, 오른쪽에 연습·완료를 두면 스크롤을 내리기 전에도
    /// 지금 할 것과 다음 할 것이 함께 보인다. 다만 설명 단계의 모션 수업은 그 자체가
    /// 주 작업이므로 320pt 연습 rail을 옆에 두지 않는다. 그 rail 때문에 9:16 무대가
    /// 약 180pt까지 줄어 실제 수식과 포인터를 읽을 수 없었다.
    ///
    /// 접근성 글씨에서는 기둥 하나에 서너 글자만 남으므로 다시 한 기둥으로 돌아간다.
    /// 판단 기준은 기기 이름이 아니라 size class 다.
    private var dashboardLayout: Bool {
        shortHeight && !dynamicTypeSize.isAccessibilitySize && activeStage != .explain
    }

    /// 좌표 없이 개념 탭에 처음 들어온 시작 화면은 아직 학습 단계가 없으므로
    /// `activeStage`로 2열 여부를 막으면 안 된다. 종전에는 초기값 `.explain` 때문에
    /// 아래에 만들어 둔 시작 2열이 영원히 실행되지 않아 `이어서 학습`이 첫 화면
    /// 밖으로 밀렸다. 시작 화면은 높이와 큰 글씨만으로 독립 판정한다.
    private var startDashboardLayout: Bool {
        shortHeight && !dynamicTypeSize.isAccessibilitySize
    }

    /// 오른쪽 기둥의 최대 폭. 왼쪽 본문이 한 줄에 30자 안팎을 유지할 만큼만 가져간다.
    private let railWidth: CGFloat = 320

    /// 좌우로 나눌 때 왼쪽 기둥이 갖는 단계. 연습·완료는 오른쪽 기둥이 상주로 갖는다.
    private var stageChoices: [ConceptLearningStage] {
        dashboardLayout ? [.explain, .explore] : ConceptLearningStage.allCases
    }

    /// 좌우로 나뉜 화면에서 activeStage 가 .practice 인 경우(세로에서 연습을 고른 뒤
    /// 가로로 돌린 때)는 그 내용이 이미 오른쪽에 떠 있으므로 왼쪽은 설명 화면을 둔다.
    /// 강의가 끝났을 때는 여기 오지 않는다 — 강의 종료는 .explore 로만 간다
    /// (finishLesson 참조).
    private var effectiveStage: ConceptLearningStage {
        if dashboardLayout, activeStage == .practice { return .explain }
        return activeStage
    }

    /// 설명 단계의 강의(코드 애니메이션·mp4·시나리오·Canvas 어느 무대든)가 끝났을 때.
    ///
    /// 다음 단계는 **탐색**이다. 설명 → 탐색 → 연습이 이 화면의 순서이고, 연습은
    /// 학생이 탭을 눌러야만 들어간다 — 강의가 끝나자마자 문제 화면으로 던져지면
    /// 탐색 단계가 통째로 건너뛰어진다(예전 코드는 여기서 .practice 로 보냈다).
    ///
    /// 설명 단계에 있을 때만 옮긴다. 종료 신호는 무대마다 따로 오고(오디오 ended,
    /// 벽시계, 문서 재로드 뒤 재생 완료), 아이폰 가로에서는 연습 rail 을 보는 동안에도
    /// 왼쪽 무대가 살아 있어 뒤늦게 신호가 올 수 있다. 그때 학생이 이미 고른
    /// 탭에서 끌어내리면 안 되고, 같은 신호가 두 번 와도 한 칸만 움직여야 한다.
    private func finishLesson() {
        guard activeStage == .explain else { return }
        activeStage = .explore
    }

    var body: some View {
        if let id = store.selectedConceptV2ID,
           let (course, unit, concept) = CurriculumV2.concept(id) {
            content(course: course, unit: unit, concept: concept)
                .id(id)
                .onChange(of: id) { _, _ in activeStage = .explain }
                // 개념 체류 이벤트 — 대시보드 학습 분의 원천
                .onAppear { dwellStart = Date() }
                .onDisappear {
                    if let s = dwellStart {
                        let ms = Int(Date().timeIntervalSince(s) * 1000)
                        EventLog.append("concept-closed", conceptId: id, durationMs: ms)
                        // 서버로도 보낸다. 서버 eventType enum 은 이 값을 받는데
                        // 전송 배선만 없어서 체류 시간이 기기 안에만 쌓였다(감사 적발).
                        SyncEngine.shared.enqueueEvent("concept-closed", conceptId: id,
                                                       correct: nil, durationMs: ms)
                    }
                }
        } else {
            conceptStart
        }
    }

    /// 직접 좌표 없이 개념 탭으로 들어온 상태.
    ///
    /// 예전 화면은 아이콘·설명·버튼 하나를 화면 중앙에 띄워 iPad의 대부분을
    /// 빈 면으로 만들었다. 여기서는 진도 정본이 고른 실제 다음 개념을 먼저
    /// 보여 주고, 과목·단원·예상 시간·진도라는 선택 근거를 함께 준다.
    @ViewBuilder
    private var conceptStart: some View {
        if let (course, unit, concept) = store.progressV2.continueConcept() {
            let percent = store.progressV2.percent(for: concept)
            let minutes = concept.lesson?.estimatedMinutes ?? 15

            Group {
                if startDashboardLayout {
                    // 아이폰 가로: 왼쪽에 무엇을 이어서 배우는지, 오른쪽에 지금 누를 것.
                    // 세로로 쌓으면 버튼이 화면 밖으로 내려가 스크롤해야 보인다.
                    HStack(alignment: .top, spacing: Tokens.Space.s5) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                            startIntro(percent: percent)
                            startCard(course: course, unit: unit,
                                      concept: concept, percent: percent, minutes: minutes)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .contain)

                        startActions(concept: concept, percent: percent)
                            .frame(maxWidth: railWidth, alignment: .leading)
                            .accessibilityElement(children: .contain)
                    }
                } else {
                    VStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s5 : Tokens.Space.s8) {
                        startIntro(percent: percent)
                        startCard(course: course, unit: unit,
                                  concept: concept, percent: percent, minutes: minutes)
                        startActions(concept: concept, percent: percent)
                    }
                }
            }
            // 520pt 를 고정하면 iPhone 가로(본문 약 390pt)에서 첫 화면이 빈 면으로 시작한다.
            // 모션 수업만 1280pt 작업대를 쓴다. 시작 화면은 문서형 정보라
            // 900pt 행 길이를 유지해 iPad 가로에서 문장이 과하게 늘어나지 않게 한다.
            .frame(maxWidth: Tokens.readableWidth, minHeight: startMinHeight, alignment: .topLeading)
            .padding(.top, shortHeight ? Tokens.Space.s3 : Tokens.Space.s6)
        } else {
            ContentUnavailableView(
                "모든 개념을 학습했어요",
                systemImage: "checkmark.seal",
                description: Text("학습 지도에서 완료한 개념을 다시 보거나 다른 과목을 복습할 수 있습니다."))
            Button("학습 지도 보기") { store.route = .curriculum }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 320)
        }
    }

    /// 개념 탭 첫 화면의 머리말. 배치가 어떻게 바뀌든 문구는 하나다.
    private func startIntro(percent: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("다음 학습")
                .font(.mCaption)
                .foregroundStyle(Tokens.progressBlue)
            Text(percent > 0 ? "멈춘 곳에서 바로 이어가세요" : "오늘 첫 개념을 시작하세요")
                .font(compactWidth || shortHeight ? .mHeading : .mTitle)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("13과목 전체를 훑지 않아도, 현재 진도에서 가장 먼저 이어갈 개념을 골랐습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            ExamRule()
        }
    }

    /// 이어서 배울 개념 카드 — 과목·단원·제목·예상 시간·진도.
    @ViewBuilder
    private func startCard(course: CourseV2,
                           unit: UnitV2,
                           concept: ConceptV2,
                           percent: Int,
                           minutes: Int) -> some View {
        Group {
            // 큰 글씨 + 좁은 폭에서는 링과 제목이 같은 줄에서 서로를 밀어낸다.
            if compactWidth && dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    ProgressRing(percent: percent)
                        .frame(width: startRingSize, height: startRingSize)
                    continueConceptCopy(course: course, unit: unit,
                                        concept: concept, minutes: minutes)
                }
            } else {
                HStack(alignment: .center, spacing: compactWidth ? Tokens.Space.s4 : Tokens.Space.s6) {
                    ProgressRing(percent: percent)
                        .frame(width: startRingSize, height: startRingSize)
                    continueConceptCopy(course: course, unit: unit,
                                        concept: concept, minutes: minutes)
                }
            }
        }
        .padding(compactWidth ? Tokens.Space.s4 : Tokens.Space.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("다음 학습, \(course.title), \(unit.title), \(concept.title), 진도 \(percent)퍼센트, 약 \(minutes)분")
    }

    /// 지금 누를 것 — 핵심 한 줄과 두 버튼.
    @ViewBuilder
    private func startActions(concept: ConceptV2, percent: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            if let takeaway = concept.lesson?.keyTakeaway {
                Text("이번에 잡을 핵심")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                Text(MathText.plain(takeaway))
                    .font(.mBody)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(percent > 0 ? "이어서 학습" : "개념 시작") {
                store.openConceptV2(concept.id)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 360)

            Button("13과목 학습 지도 보기") { store.route = .curriculum }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    /// 이어학습 카드의 본문. 좁은 폭에서 링 아래로 내려가도 같은 문구를 쓴다.
    private func continueConceptCopy(course: CourseV2,
                                     unit: UnitV2,
                                     concept: ConceptV2,
                                     minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("\(course.title) \(unit.title)")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
            Text(concept.title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Label("약 \(minutes)분", systemImage: "clock")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 진도 링은 조작 대상이 아니라 표시다. 좁은 폭에서는 제목이 설 자리를 먼저 준다.
    private var startRingSize: CGFloat { compactWidth ? 56 : 72 }

    private var startMinHeight: CGFloat {
        if shortHeight { return dashboardLayout ? 240 : 300 }
        return compactWidth ? 440 : 520
    }

    @ViewBuilder
    private func content(course: CourseV2, unit: UnitV2, concept: ConceptV2) -> some View {
        let progress = store.progressV2
        let pct = progress.percent(for: concept)

        if dashboardLayout {
            // 아이폰 가로: 왼쪽 기둥이 설명과 탐색을, 오른쪽 기둥이 연습과 완료를 갖는다.
            // 강의를 보는 동안에도 다음에 할 것이 화면에서 사라지지 않는다.
            HStack(alignment: .top, spacing: Tokens.Space.s5) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    conceptHeader(course: course, unit: unit, concept: concept, percent: pct)
                        .entrance(0)
                    learningStageNavigation(concept: concept)
                    stageContent(course: course, unit: unit, concept: concept)
                        .entrance(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                actionRail(concept: concept)
                    .frame(maxWidth: railWidth, alignment: .leading)
                    .entrance(2)
            }
        } else {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                conceptHeader(course: course, unit: unit, concept: concept, percent: pct)
                    .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .entrance(0)
                learningStageNavigation(concept: concept)
                    .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                stageContent(course: course, unit: unit, concept: concept)
                    // 설명의 모션판만 iPad 가로 전체 폭을 쓴다. 탐색·연습의
                    // 장문과 문제는 기존 900pt 행 길이를 지켜 읽기성을 보존한다.
                    .frame(
                        maxWidth: effectiveStage == .explain ? .infinity : Tokens.readableWidth,
                        alignment: .leading
                    )
                    // 900pt 제한만 걸면 leading VStack 안에서 블록 전체가 왼쪽에
                    // 붙는다. 제한 뒤 남는 폭을 한 번 더 받아 탐색·연습을 중앙에 둔다.
                    .frame(
                        maxWidth: .infinity,
                        alignment: effectiveStage == .explain ? .leading : .center
                    )
                    .entrance(1)
            }
        }
    }

    /// 머리에는 현재 위치와 진도만 남긴다. 성취기준·세부 설명은 탐색 단계로 보낸다.
    private func conceptHeader(course: CourseV2,
                               unit: UnitV2,
                               concept: ConceptV2,
                               percent: Int) -> some View {
        VStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
            Button { store.route = .curriculum } label: {
                Label("커리큘럼", systemImage: "chevron.left")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    // 시각 크기는 13pt 그대로 두고 히트 영역만 44pt 로 넓힌다.
                    // 바깥 음수 패딩이 레이아웃 높이를 원래대로 되돌리므로
                    // regular 폭(iPad)의 머리 간격은 1pt 도 바뀌지 않는다.
                    .padding(.vertical, 14)
                    .padding(.trailing, Tokens.Space.s5)
                    .contentShape(Rectangle())
                    .padding(.vertical, -14)
                    .padding(.trailing, -Tokens.Space.s5)
            }
            .buttonStyle(.plain)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(course.title) \(unit.title)")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(concept.title)
                        .font(compactWidth || shortHeight ? .mHeading : .mTitle)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.s3)
                ProgressRing(percent: percent)
                    .frame(width: headerRingSize, height: headerRingSize)
            }
        }
    }

    /// 지금 선택된 단계의 본문. 좌우로 나뉜 화면에서는 연습·완료가 오른쪽 기둥에 있어
    /// 이 자리에는 설명과 탐색만 온다.
    @ViewBuilder
    private func stageContent(course: CourseV2, unit: UnitV2, concept: ConceptV2) -> some View {
        switch effectiveStage {
        case .explain:
            CurriculumStoryTimeline(
                resolution: CurriculumStoryCatalog.resolve(
                    courseID: course.id,
                    unitID: unit.id,
                    conceptID: concept.id
                ),
                concept: concept,
                onLessonCompleted: finishLesson
            )
        case .explore:
            explorationStage(concept: concept)
        case .practice:
            VStack(alignment: .leading, spacing: sectionSpacing) {
                practiceSection(concept: concept)
                if showsCompletionSection(for: concept) {
                    completeSection(concept: concept)
                }
            }
        }
    }

    /// 아이폰 가로의 오른쪽 기둥. 왼쪽에서 설명을 보는 동안에도 문제와 완료가 남는다.
    /// 담는 내용은 세로 배치의 연습 단계와 같다 — 새로 만든 버튼이 아니다.
    private func actionRail(concept: ConceptV2) -> some View {
        let readyToPractice = activeStage == .practice

        return VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            if readyToPractice {
                Label("지금 할 차례", systemImage: "arrow.right.circle.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.progressBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            practiceSection(concept: concept)
            if showsCompletionSection(for: concept) {
                Divider().overlay(Tokens.line)
                completeSection(concept: concept)
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(readyToPractice ? Tokens.actionPrimary : Tokens.line, lineWidth: 1)
        }
        .accessibilityIdentifier("concept-action-rail")
    }

    /// 진도 링. 세로가 짧으면 44pt 까지만 줄인다 — 그 아래로 내리면 세 자리 숫자가
    /// 링 안에서 줄어들기 시작하고, 머리 높이는 어차피 두 줄 글자가 정한다.
    private var headerRingSize: CGFloat { compactWidth || shortHeight ? 44 : 52 }

    private func learningStageNavigation(concept: ConceptV2) -> some View {
        Group {
            // 접근성 글씨 + compact 폭에서는 3칸 가로 배치가 아이콘만 남기고 잘린다.
            // 이때만 세로로 쌓고, regular 폭은 지금 배치를 그대로 둔다.
            if stacksStages {
                VStack(spacing: Tokens.Space.s2) { learningStageButtons(concept: concept) }
            } else {
                HStack(spacing: Tokens.Space.s2) { learningStageButtons(concept: concept) }
            }
        }
        .accessibilityIdentifier("concept-learning-stage-navigation")
    }

    @ViewBuilder
    private func learningStageButtons(concept: ConceptV2) -> some View {
        let choices = stageChoices
        ForEach(Array(choices.enumerated()), id: \.element.id) { index, stage in
            let selected = effectiveStage == stage
            Button {
                selectLearningStage(stage, concept: concept)
            } label: {
                VStack(spacing: Tokens.Space.s1) {
                    Label(stage.label, systemImage: stage.symbol)
                        .font(.mBodyB)
                        // 좁은 폭에서 "설명", "탐색", "연습" 이 줄바꿈되거나 잘리지 않게 한다.
                        .lineLimit(1)
                        .minimumScaleFactor(compactWidth ? 0.8 : 1)
                    Text("\(index + 1) / \(choices.count)")
                        .font(.mMicro.monospacedDigit())
                        .lineLimit(1)
                }
                .padding(.horizontal, Tokens.Space.s1)
                .foregroundStyle(selected ? Tokens.onPrimary : Tokens.text2)
                .frame(maxWidth: .infinity, minHeight: stageMinHeight)
                .background(
                    selected ? Tokens.actionPrimary : Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(selected ? Tokens.actionPrimary : Tokens.line, lineWidth: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(index + 1)단계, \(stage.label)")
            .accessibilityValue(selected ? "현재 단계" : "")
        }
    }

    /// 연습 탭은 또 다른 시작 버튼을 열기 위한 중간 화면이 아니다. 아직 유형 게이트를
    /// 채우지 못한 학생은 탭을 고르는 동작 자체로 기존 출제 경로에 들어간다.
    /// 이미 게이트가 열렸거나 완료한 학생에게는 완료·진도 화면을 보여 주고 재시험을
    /// 강제하지 않는다.
    private func selectLearningStage(_ stage: ConceptLearningStage, concept: ConceptV2) {
        activeStage = stage
        guard stage == .practice else { return }

        let progress = store.progressV2
        let completed = progress.byConcept[concept.id]?.userCompleted == true
        guard !completed, !progress.masteryUnlocked(for: concept) else { return }
        startPractice(concept)
    }

    @ViewBuilder
    private func explorationStage(concept: ConceptV2) -> some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if let std = concept.achievementStandard {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    SectionRule(title: "학습 목표")
                    // 성취기준 코드는 뺀다 — 학습 목표 문장 앞에 붙은 식별자는
                    // 학생이 읽을 것이 아니다. 문장만 남긴다.
                    Text(std)
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            explorationInteractiveCard(concept: concept)

            if let lesson = concept.lesson {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    SectionRule(title: "핵심 정리, 약 \(lesson.estimatedMinutes)분")
                    KatexText(text: lesson.summary, height: $summaryHeight)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("핵심 한 줄").font(.mMicro).foregroundStyle(Tokens.primary)
                        KatexText(text: lesson.keyTakeaway, height: $keyHeight)
                    }
                    .padding(Tokens.Space.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.primarySoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    ForEach(lesson.steps, id: \.order) { step in LessonStepRow(step: step) }
                }
            } else if let text = concept.legacy?.lessonText {
                Text(text)
                    .font(.mBody)
                    .foregroundStyle(Tokens.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }

    /// 탐색은 먼저 손으로 값을 바꿔 보고, 그 뒤에 핵심 정리를 읽는다.
    /// 설명 단계의 강의를 다시 띄우지 않는 기존 hasPlayground 계약은 그대로 둔다.
    @ViewBuilder
    private func explorationInteractiveCard(concept: ConceptV2) -> some View {
        // 예전 조건은 `hasLesson(시나리오 존재) || web || scene` 이었다.
        // 시나리오는 220개념 전부에 있으므로 이 조건은 사실상 항상 참이었고,
        // 그래서 설명 단계에서 이미 본 시각 강의가 탐색에서 또 재생됐다.
        // 이제는 **직접 손으로 만질 것이 실제로 있는 개념**(hasPlayground, 42개)에서만
        // 놀이터를 열고, 나머지는 네이티브 탐색 카드로 간다.
        if concept.legacy?.hasPlayground == true {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "직접 움직여 보기")
                Text("강의 화면은 설명 단계에 있습니다. 여기서는 값을 바꿔가며 직접 확인해 보세요.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                ConceptPlaygroundWebView(conceptID: concept.legacy?.appId ?? concept.id,
                                         height: $lessonHeight)
                    .frame(height: lessonHeight)
            }
        } else {
            GenericConceptExplorer(concept: concept)
        }
    }

    @ViewBuilder
    private func practiceSection(concept: ConceptV2) -> some View {
        let progress = store.progressV2
        let required = progress.requiredDistinctTypes(for: concept)
        let got = progress.byConcept[concept.id]?.correctTypeIds.count ?? 0
        let credited = min(got, required)
        let unlocked = progress.masteryUnlocked(for: concept)
        let completed = progress.byConcept[concept.id]?.userCompleted == true
        // 출제 경로는 **요구 유형 수와 같은 근거**로 정한다.
        // 예전엔 `!practiceTypes.isEmpty` 로 따로 판단해서, 웹 생성기가 10유형을
        // 요구하는 개념인데 출제는 네이티브 1~2유형으로만 나갔다 —
        // 아무리 풀어도 게이트가 안 열리는 벽이 됐다.

        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "연습 문제")
            if required > 0 {
                Label(
                    "유형 학습 \(credited)/\(required)",
                    systemImage: unlocked ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.mBodyB)
                .foregroundStyle(unlocked ? Tokens.successInk : Tokens.ink)

                if completed {
                    Text("필요한 유형을 모두 맞혔습니다.")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                } else if unlocked {
                    Text("필요한 유형을 모두 맞혔습니다. 아래에서 학습 완료를 확정하세요.")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                } else {
                    Text("완료까지 서로 다른 유형 \(required - credited)개가 남았습니다.")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                    Button("연습 이어가기") {
                        startPractice(concept)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 240)
                }
            } else {
                // 220개념 모두 출제 경로가 있어야 하므로 이 분기는 콘텐츠 준비 상태가
                // 아니라 번들 연결 실패다. 영구 미지원처럼 말하지 않고 복구 행동을 준다.
                Text("연습 자료를 불러오지 못했습니다. 앱을 다시 연 뒤에도 같으면 학습 지도에서 다른 개념을 선택해 주세요.")
                    .font(.mCallout).foregroundStyle(Tokens.warningInk)
            }
        }
    }

    /// 연습 탭과 아이폰 가로 action rail이 공유하는 단 하나의 출제 진입점.
    /// 요구 유형 수를 계산하는 ProgressV2와 같은 근거로 native/web을 고른다.
    private func startPractice(_ concept: ConceptV2) {
        if store.progressV2.usesWebGenerator(concept) {
            // 웹 로컬 생성기 (WebGen) — 220개념 커버리지 확장의 핵심
            store.startWebPractice(concept)
            return
        }

        let types = concept.practiceTypes.compactMap(ProblemType.init(rawValue:))
        guard !types.isEmpty else { return }
        store.startExam(types: types, count: max(3, min(5, types.count)))
        store.examSourceConceptV2ID = concept.id
    }

    @ViewBuilder
    private func completeSection(concept: ConceptV2) -> some View {
        let progress = store.progressV2
        let unlocked = progress.masteryUnlocked(for: concept)
        let completed = progress.byConcept[concept.id]?.userCompleted == true

        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if completed {
                Label("학습 완료", systemImage: "checkmark.seal.fill")
                    .font(.mBodyB).foregroundStyle(Tokens.successInk)
            } else if unlocked {
                Button("학습 완료로 표시") {
                    store.completeConceptV2(concept)
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
            }
        }
    }

    /// 완료 CTA는 유형 게이트가 열린 뒤에만 나타난다. 닫힌 동안에는 연습 CTA만
    /// 보여서 같은 위계의 주 행동 두 개가 한 화면에 경쟁하지 않게 한다.
    private func showsCompletionSection(for concept: ConceptV2) -> Bool {
        let progress = store.progressV2
        return progress.masteryUnlocked(for: concept)
            || progress.byConcept[concept.id]?.userCompleted == true
    }
}

/// 탐색 단계의 놀이터(직접 조작)만 여는 WKWebView.
///
/// 번들 LessonWeb/lesson.html 을 그대로 연다 — 새 엔진을 만들지 않는다.
/// 다만 같은 페이지에 들어 있는 시각 강의(#scenario-section)와 확인 문제(#quiz-section)는
/// 닫는다. 시각 강의는 설명 단계가, 확인 문제는 설명 단계의 장면 확인과 연습 단계가
/// 이미 소유한다. 탐색에서 또 띄우면 학생에게 같은 것이 두 번 나온다.
///
/// 감추는 것만으로 부족한 이유: scenario-player.js 는 생성자에서 바로 30fps 타임라인을
/// 돌린다. display:none 이어도 requestAnimationFrame 은 계속 돌아 배터리만 먹는다.
/// 그래서 부팅 직전에 모션 플래그를 내려 첫 프레임만 그리고 멈추게 한다.
/// lesson.html 의 bootLesson() 은 DOMContentLoaded 보다 먼저 실행되고, 접근성
/// 부트스트랩이 DOMContentLoaded 에서 플래그를 실제 설정값으로 되돌린다. 멈춘 플레이어를
/// 다시 재생시키는 경로는 재생 버튼 클릭뿐인데 그 버튼째 닫혀 있으므로 되살아나지 않는다.
/// 놀이터 쪽은 이 플래그를 읽지 않아(LessonWeb 전체에서 scenario-player.js 만 읽는다)
/// 조작 응답과 그림은 그대로다.
///
/// WKWebView + WKUserScript 주입은 LessonWebView·CurriculumScenarioLessonView 패턴 그대로다.
private struct ConceptPlaygroundWebView: UIViewRepresentable {
    let conceptID: String
    @Binding var height: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        for script in userScripts() {
            config.userContentController.addUserScript(script)
        }
        config.userContentController.add(context.coordinator, name: "lessonHeight")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        WebContentAccessibility.configure(web)

        context.coordinator.loadedConcept = conceptID
        if let html = LessonWebView.lessonURL {
            web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        // 개념이 바뀌면 새 주입이 필요하므로 다시 로드
        if context.coordinator.loadedConcept != conceptID, let html = LessonWebView.lessonURL {
            context.coordinator.loadedConcept = conceptID
            web.configuration.userContentController.removeAllUserScripts()
            for script in userScripts() {
                web.configuration.userContentController.addUserScript(script)
            }
            web.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
        } else {
            WebContentAccessibility.update(
                web,
                size: dynamicTypeSize,
                reduceMotion: reduceMotion,
                userMotionEnabled: userMotionEnabled)
        }
    }

    static func dismantleUIView(_ web: WKWebView, coordinator: Coordinator) {
        web.stopLoading()
        web.configuration.userContentController.removeScriptMessageHandler(forName: "lessonHeight")
    }

    private func userScripts() -> [WKUserScript] {
        [
            WKUserScript(
                source: "window.MATTHS_CONCEPT = \(jsString(conceptID));",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true),
            WKUserScript(
                source: WebContentAccessibility.bootstrapScript(
                    size: dynamicTypeSize,
                    reduceMotion: reduceMotion,
                    userMotionEnabled: userMotionEnabled),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true),
            // 접근성 부트스트랩 **뒤에** 와야 한다. 부트스트랩이 모션 플래그를 세우므로
            // 순서가 뒤집히면 강의가 그대로 자동 재생된다.
            WKUserScript(
                source: Self.playgroundOnlyScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true),
        ]
    }

    private static let playgroundOnlyScript = """
    (function () {
      window.MATTHS_MOTION = false;
      var css = [
        '#scenario-section, #quiz-section { display: none !important; }',
        '.lw-wrap { padding: 0; }'
      ].join('\\n');
      var applyStyle = function () {
        if (document.getElementById('matths-playground-only-style')) return;
        var style = document.createElement('style');
        style.id = 'matths-playground-only-style';
        style.textContent = css;
        (document.head || document.documentElement).appendChild(style);
      };
      applyStyle();
      document.addEventListener('DOMContentLoaded', function () {
        applyStyle();
        // 놀이터가 뜨지 않았을 때 나오는 안내문은 시각 강의를 가리키고 있었다.
        // 이 화면에는 시각 강의가 없으므로 문구도 이 화면의 사실로 바꾼다.
        var missing = document.getElementById('missing');
        if (missing) {
          missing.textContent = '직접 움직여 보는 화면을 불러오지 못했습니다. 위의 핵심 정리로 학습을 이어가 주세요.';
        }
      }, { once: true });
    })();
    """

    private func jsString(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        @Binding var height: CGFloat
        var loadedConcept: String?

        init(height: Binding<CGFloat>) { _height = height }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "lessonHeight", let h = message.body as? Double else { return }
            let clamped = max(240, min(CGFloat(h), 2400))
            if abs(clamped - height) > 4 {
                DispatchQueue.main.async { self.height = clamped }
            }
        }
    }
}

/// 전문 WebView 모듈이 없는 개념의 네이티브 탐색 단계.
///
/// 정적인 "준비 중" 안내가 아니라 curriculum-v2 정본의 시각화 아이디어를
/// 한 항목씩 읽고 전환하는 완결된 학습 표면이다. 자동 재생·무한 바운스는 없고,
/// 이전/다음 버튼은 44pt 이상이라 Split View와 Dynamic Type에서도 조작할 수 있다.
private struct GenericConceptExplorer: View {
    let concept: ConceptV2
    @State private var selectedIndex = 0

    private var ideas: [String] { concept.visualizationIdeas }
    private var safeIndex: Int {
        min(max(selectedIndex, 0), max(ideas.count - 1, 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "02~03 개념 구조 탐색")

            if let idea = ideas.indices.contains(safeIndex) ? ideas[safeIndex] : nil {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("탐색 \(safeIndex + 1)")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.progressBlue)
                        Spacer()
                        Text("\(safeIndex + 1) / \(ideas.count)")
                            .font(.mMicro)
                            .foregroundStyle(Tokens.text3)
                            .monospacedDigit()
                    }

                    Text(idea)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    if let lesson = concept.lesson {
                        // 원문에 $...$ 가 들어 있다. 이 자리는 WebView 를 띄우지 않으므로
                        // 인라인 수식만 유니코드로 옮긴다 — 안 그러면 달러째로 나온다.
                        Text(InlineMath.plain(lesson.keyTakeaway))
                            .font(.mCallout)
                            .foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: Tokens.Space.s2) {
                        ForEach(ideas.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == safeIndex ? Tokens.progressBlue : Tokens.lineStrong)
                                .frame(maxWidth: .infinity)
                                .frame(height: 3)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(Tokens.Space.s4)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(Tokens.line, lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("개념 탐색 \(safeIndex + 1)단계, \(idea)")

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s3) { navigationButtons }
                    VStack(spacing: Tokens.Space.s2) { navigationButtons }
                }
            } else {
                Text("개념 설명을 확인한 뒤 연습 문제로 이어가세요.")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
            }
        }
        .onChange(of: concept.id) { _, _ in selectedIndex = 0 }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        Button("이전 탐색") {
            selectedIndex = max(0, safeIndex - 1)
        }
        .buttonStyle(SecondaryButtonStyle())
        .frame(maxWidth: .infinity, minHeight: 44)
        .disabled(safeIndex == 0)

        Button(safeIndex == ideas.count - 1 ? "탐색 완료" : "다음 탐색") {
            selectedIndex = min(max(ideas.count - 1, 0), safeIndex + 1)
        }
        .buttonStyle(PrimaryButtonStyle())
        .frame(maxWidth: .infinity, minHeight: 44)
        .disabled(ideas.isEmpty || safeIndex == ideas.count - 1)
    }
}

struct LessonStepRow: View {
    let step: LessonStepV2
    @State private var height: CGFloat = 40

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            CircledNumber(n: step.order)
            VStack(alignment: .leading, spacing: 3) {
                // 바로 아래 description 은 KatexText 로 조판하는데 제목만 원문이었다.
                // 제목은 한 줄짜리라 WebView 를 하나 더 띄우지 않고 유니코드로 옮긴다.
                Text(InlineMath.plain(step.title)).font(.mBodyB).foregroundStyle(Tokens.ink)
                KatexText(text: step.description, height: $height)
            }
        }
        .padding(.vertical, Tokens.Space.s2)
    }
}

struct TopicCheckRow: View {
    let index: Int
    let title: String
    let concept: ConceptV2
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// 손가락으로 누르는 compact 폭에서만 행 높이를 44pt 로 올린다.
    /// regular 폭(iPad)의 목록 밀도는 지금 그대로 유지한다.
    private var rowMinHeight: CGFloat? {
        horizontalSizeClass == .compact ? 44 : nil
    }

    var body: some View {
        let done = store.progressV2.byConcept[concept.id]?.completedTopicIndexes.contains(index) == true
        Button {
            store.toggleConceptTopic(index, concept: concept)
        } label: {
            HStack(spacing: Tokens.Space.s3) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .font(.mBody).foregroundStyle(done ? Tokens.primary : Tokens.text4)
                Text(title).font(.mBody)
                    .foregroundStyle(done ? Tokens.text3 : Tokens.ink)
                    .strikethrough(done, color: Tokens.text4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .frame(minHeight: rowMinHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// $...$ 수식이 섞인 문장을 KaTeX 로 렌더 — problem.html 재사용 (선지 없이 발제문만)
struct KatexText: View {
    let text: String
    @Binding var height: CGFloat
    @State private var picked: String?

    var body: some View {
        ProblemWebView(
            problem: GeneratedProblem(
                id: "lesson-\(text.hashValue)", typeKey: "lesson", typeName: "lesson",
                unit: "", statement: text, answer: "", steps: [], minutes: 0,
                choices: nil, isTex: true),
            height: $height, pickedKey: $picked)
            .frame(height: height)
            // WKWebView 안 KaTeX/MathML을 보조 기술이 항상 같은 깊이로 탐색한다고
            // 가정하지 않는다. 이 래퍼는 보기 없는 읽기 전용 문장에만 쓰이므로,
            // 네이티브 평문 근사를 하나의 확정 라벨로 제공해 발문이 통째로 빠지는
            // 경우를 막는다. 선택지가 있는 ProblemWebView 자체는 건드리지 않는다.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MathText.plain(text))
    }
}
