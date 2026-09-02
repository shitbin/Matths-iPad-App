//  CurriculumV2MapScreen.swift
//  Matths
//
//  2022 개정 교육과정 13과목·220개념의 실제 진입 화면.
//  구 5과목 curriculum.json은 평가 호환용으로만 남기고, 학생이 보는 지도와
//  진도는 웹과 같은 curriculum-v2.json / ProgressV2Store를 사용한다.

import SwiftUI

/// CurriculumV2/AssessmentV2 정본을 화면에 읽기 좋게 투영하는 상태값이다.
/// 저장하거나 해금 판정에 다시 사용하지 않는다.
private enum CurriculumAssessmentDisplayState {
    case available, inProgress, completed, locked, unsupported

    var systemImage: String {
        switch self {
        case .available:   return "flag.fill"
        case .inProgress:  return "pencil.circle.fill"
        case .completed:   return "checkmark.seal.fill"
        case .locked:      return "lock.fill"
        case .unsupported: return "info.circle.fill"
        }
    }

    var foreground: Color {
        switch self {
        // actionPrimary는 10% 바이올렛 면 위에서 작은 글자 대비가 4.5:1 아래다.
        // 상태는 아이콘+문구로 이미 전달하므로 이 면에서는 본문 잉크를 쓴다.
        case .available, .inProgress: return Tokens.ink
        case .completed:              return Tokens.successInk
        case .locked:                 return Tokens.warningInk
        case .unsupported:            return Tokens.text2
        }
    }

    var background: Color {
        switch self {
        case .available, .inProgress: return Tokens.actionPrimary.opacity(0.10)
        case .completed:              return Tokens.successSoft
        case .locked:                 return Tokens.warningSoft
        case .unsupported:            return Tokens.paper2
        }
    }
}

private struct CurriculumAssessmentProjection {
    let state: CurriculumAssessmentDisplayState
    let title: String
    let detail: String
}

private enum CurriculumConceptDisplayState {
    case current(percent: Int), completed, available

    var label: String {
        switch self {
        case .current(let percent): return percent > 0 ? "현재 학습 \(percent)%" : "현재 학습"
        case .completed:            return "학습 완료"
        case .available:            return "학습 가능"
        }
    }

    var systemImage: String {
        switch self {
        case .current:   return "play.fill"
        case .completed: return "checkmark"
        case .available: return "lock.open.fill"
        }
    }

    var foreground: Color {
        switch self {
        case .current:   return Tokens.actionPrimary
        case .completed: return Tokens.successInk
        case .available: return Tokens.text2
        }
    }

    var background: Color {
        switch self {
        case .current:   return Tokens.actionPrimary.opacity(0.12)
        case .completed: return Tokens.successSoft
        case .available: return Tokens.paper2
        }
    }
}

struct CurriculumV2MapScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 과목 안내(잠금 규칙, 권장 선수 과목)는 기본 화면에서 접어 둔다.
    /// 매번 읽을 내용이 아니고, 펼치기 전까지는 진도와 평가 상태를 가리지 않는다.
    @State private var showsCourseGuide = false

    /// 기기 이름이 아니라 size class 로 판단한다. Split View 와 Stage Manager 의
    /// iPad 도 compact 폭으로 들어온다.
    private var compactWidth: Bool { horizontalSizeClass == .compact }

    /// iPhone 가로. 상단바, 하단 탭, 홈 인디케이터를 빼면 본문 높이가 약 390pt다.
    private var shortHeight: Bool { verticalSizeClass == .compact }

    /// 카드 안쪽 여백. 좁은 폭에서 20pt 를 양쪽에 두면 본문이 설 자리를 잃는다.
    private var cardPadding: CGFloat {
        compactWidth ? Tokens.Space.s4 : Tokens.Space.s5
    }

    /// 카드 머리(제목 + 예상 시간)를 한 줄에 둘지. 좁은 폭이나 큰 글씨에서는 1열로 접는다.
    private var stacksCardHeader: Bool {
        compactWidth || dynamicTypeSize.isAccessibilitySize
    }

    /// 개념 행의 좌우 여백과, 그에 맞춘 구분선 들여쓰기.
    /// regular 폭의 값(20pt, 62pt)은 그대로 두고 compact 에서만 4pt 씩 당긴다.
    private var conceptRowHPadding: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return Tokens.Space.s4 }
        return compactWidth ? Tokens.Space.s4 : Tokens.Space.s5
    }

    private var conceptRowDividerInset: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return Tokens.Space.s5 }
        return compactWidth ? 58 : 62
    }

    private var courses: [CourseV2] { CurriculumV2.data.courses }
    private var selectedCourse: CourseV2 {
        courses.first { $0.id == store.selectedCourseV2ID }
            ?? courses.first
            ?? CourseV2(id: "empty", title: "과목 없음", category: "common",
                        order: 0, prerequisites: [], recommendedGrades: [], units: [])
    }

    var body: some View {
        GeometryReader { geometry in
            if let loadError = CurriculumV2.loadError {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.mTitle)
                        .foregroundStyle(Tokens.warningInk)
                    Text("커리큘럼을 열지 못했습니다")
                        .font(.mTitle)
                        .foregroundStyle(Tokens.ink)
                    Text(loadError)
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("홈으로 돌아가기") { store.route = .home }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 320)
                }
                .readableWidth(680)
                .adaptiveHPadding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, Tokens.Space.s8)
            } else {
                // iPhone landscape는 760pt보다 넓을 수 있어도 compact size class다.
                // 너비만 보고 iPad 사이드바를 띄우지 않는다.
                let split = horizontalSizeClass == .regular
                    && geometry.size.width >= 760
                    && !dynamicTypeSize.isAccessibilitySize
                let narrow = geometry.size.width <= 360
                // 세로가 짧은 문맥(아이폰 가로)에서 한 기둥으로 쌓으면, 지금 이어갈 개념을
                // 읽고 과목 목록을 보려면 계속 내려야 한다. 왼쪽에 현재 개념, 오른쪽에
                // 목록을 두면 두 가지가 한 화면에 남는다. 기기 이름이 아니라 size class와
                // 실제 폭으로 판단하고, 접근성 글씨에서는 다시 한 기둥으로 돌아간다.
                let dashboard = shortHeight
                    && !dynamicTypeSize.isAccessibilitySize
                    && geometry.size.width >= 640
                Group {
                    // 세로가 짧으면 사이드바보다 이 배치가 먼저다. 큰 아이폰은 가로에서
                    // horizontalSizeClass 가 regular 로 들어와 폭 조건만으로는 iPad
                    // 사이드바에 걸린다. 사이드바는 세로 목록이라 390pt 높이에서
                    // 과목 하나를 고르는 데도 스크롤이 필요하다.
                    if dashboard {
                        HStack(spacing: 0) {
                            currentConceptColumn
                                .frame(width: leadColumnWidth(for: geometry.size.width))
                            Divider()
                            courseScroll(compact: true, narrow: false,
                                         ownsCurrentConcept: false)
                        }
                    } else if split {
                        HStack(spacing: 0) {
                            courseSidebar
                                .frame(width: 248)
                            Divider()
                            courseScroll(compact: false, narrow: false)
                        }
                    } else {
                        courseScroll(compact: true, narrow: narrow)
                    }
                }
            }
        }
        .background(Tokens.paper)
        .onAppear {
            if store.selectedCourseV2ID == nil {
                store.selectedCourseV2ID = courses.first?.id
            }
        }
        // 반복 모션은 없으며, 시스템/앱 모션 설정이 꺼진 경우 상위에서
        // 전달된 암묵 애니메이션도 이 화면 안에서는 즉시 반영한다.
        .transaction { transaction in
            if reduceMotion || !store.motionOn { transaction.animation = nil }
        }
    }

    private var courseSidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s6) {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text("과목 선택")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                    Text("13과목, 220개념")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                }

                ForEach(CurriculumV2.data.categories) { category in
                    let categoryCourses = courses.filter { $0.category == category.id }
                    if !categoryCourses.isEmpty {
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            Text(category.title)
                                .font(.mMicro.weight(.bold))
                                .foregroundStyle(Tokens.text3)
                                .accessibilityAddTraits(.isHeader)

                            ForEach(categoryCourses) { course in
                                courseButton(course)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, Tokens.Space.s6)
            .padding(.bottom, 88)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private func courseButton(_ course: CourseV2) -> some View {
        let selected = course.id == selectedCourse.id
        let percent = store.progressV2.coursePercent(course)
        return Button {
            store.selectedCourseV2ID = course.id
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                    Text(course.title)
                        .font(selected ? .mBodyB : .mBody)
                        .foregroundStyle(selected ? Tokens.ink : Tokens.text2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Tokens.Space.s2)
                    Text("\(percent)%")
                        .font(.mCaption.monospacedDigit())
                        .foregroundStyle(selected ? Tokens.actionPrimary : Tokens.text3)
                }
                ProgressBar(value: Double(percent) / 100,
                            tint: selected ? Tokens.actionPrimary : Tokens.progressBlue)
                    .frame(height: 4)
            }
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.vertical, Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(selected ? Tokens.actionPrimary.opacity(0.10) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(course.title), 진도 \(percent)퍼센트")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// 좌우로 나뉜 화면의 왼쪽 기둥 — 지금 이어갈 개념 하나와 과목 선택.
    /// 오른쪽 목록을 아무리 내려도 이 기둥은 자리에 남는다.
    private var currentConceptColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                storyPreviewCard
                compactCoursePicker
            }
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, Tokens.Space.s4)
            .padding(.bottom, 64)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    /// 왼쪽 기둥의 폭. 좁히면 카드 안에서 줄바꿈이 늘어 세로로 길어지고, 넓히면
    /// 오른쪽 개념 목록이 눌린다. 오른쪽에 개념 제목 한 줄이 남는 선에서 나눈다.
    private func leadColumnWidth(for width: CGFloat) -> CGFloat {
        min(max(width * 0.42, 300), 380)
    }

    /// 지금 이어갈 개념 카드. 좌우로 나뉘면 왼쪽 기둥이, 아니면 스크롤 머리가 갖는다.
    private var storyPreviewCard: some View {
        let timelinePreview = topTimelinePreview
        return CurriculumStoryCompactPreview(model: timelinePreview) {
            if let conceptID = timelinePreview.conceptID {
                store.openConceptV2(conceptID)
            }
        }
    }

    private func courseScroll(compact: Bool,
                              narrow: Bool,
                              ownsCurrentConcept: Bool = true) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s5 : Tokens.Space.s7) {
                pageHeader
                if ownsCurrentConcept {
                    storyPreviewCard
                    if compact { compactCoursePicker }
                }
                courseHeader(selectedCourse)
                learningTracksSection(course: selectedCourse)
                ForEach(Array(selectedCourse.units.enumerated()), id: \.element.id) { index, unit in
                    unitSection(course: selectedCourse, unit: unit, index: index)
                }
            }
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, narrow ? Tokens.Space.s3 : compact ? Tokens.Space.s4 : Tokens.Space.s8)
            // iPhone 가로에서는 위아래 32pt 가 본문의 6분의 1을 먹는다.
            .padding(.vertical, shortHeight ? Tokens.Space.s4 : Tokens.Space.s8)
            .padding(.bottom, shortHeight ? 64 : 88)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
            Text("커리큘럼")
                // 가로로 누운 iPhone 에서는 28pt 제목이 남은 높이를 먼저 가져간다.
                // 큰 아이폰은 가로에서 폭이 regular 로 들어오므로 세로 길이로 판단한다.
                .font(shortHeight ? .mHeading : .mTitle)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Text("2022 개정 교육과정의 13과목 220개념을 자유롭게 선택해 학습합니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            ExamRule()
        }
    }

    private var compactCoursePicker: some View {
        Menu {
            ForEach(CurriculumV2.data.categories) { category in
                let categoryCourses = courses.filter { $0.category == category.id }
                if !categoryCourses.isEmpty {
                    Section(category.title) {
                        ForEach(categoryCourses) { course in
                            Button {
                                store.selectedCourseV2ID = course.id
                            } label: {
                                if course.id == selectedCourse.id {
                                    Label(course.title, systemImage: "checkmark")
                                } else {
                                    Text(course.title)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        coursePickerCopy
                        Label("과목 바꾸기", systemImage: "chevron.up.chevron.down")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.actionPrimary)
                    }
                } else {
                    HStack(spacing: Tokens.Space.s3) {
                        coursePickerCopy
                        Spacer(minLength: Tokens.Space.s3)
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(Tokens.actionPrimary)
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md).stroke(Tokens.line))
        }
        .accessibilityLabel("과목 선택, 현재 \(selectedCourse.title)")
        .accessibilityHint("13과목 목록을 엽니다")
    }

    private var coursePickerCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(categoryTitle(selectedCourse.category))
                .font(.mMicro.weight(.bold))
                .foregroundStyle(Tokens.text3)
            Text(selectedCourse.title)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func courseHeader(_ course: CourseV2) -> some View {
        let percent = store.progressV2.coursePercent(course)
        let completed = course.allConcepts.filter {
            store.progressV2.percent(for: $0) >= 100
        }.count
        let totalMinutes = course.allConcepts.reduce(0) {
            $0 + ($1.lesson?.estimatedMinutes ?? 15)
        }
        let prerequisiteTitles = course.prerequisites.compactMap { prerequisiteID in
            courses.first { $0.id == prerequisiteID }?.title
        }
        return VStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s3 : Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("\(categoryTitle(course.category)) (\(gradeLabel(course.recommendedGrades)))")
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(Tokens.actionPrimary)
                Text(course.title)
                    // compact 폭에서 28pt 과목명은 두 줄로 넘어가며 카드 머리를 밀어낸다.
                    // 세로가 짧은 문맥에서도 같은 이유로 22pt 를 쓴다.
                    .font(compactWidth || shortHeight ? .mHeading : .mTitle)
                    .foregroundStyle(Tokens.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(course.units.count)개 단원, \(course.allConcepts.count)개 개념, \(estimatedTimeLabel(totalMinutes))")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text("\(completed)/\(course.allConcepts.count) 완료 (\(percent)%)")
                            .font(.mCaption.monospacedDigit())
                            .foregroundStyle(Tokens.text2)
                        ProgressBar(value: Double(percent) / 100, tint: Tokens.actionPrimary)
                    }
                } else {
                    HStack(spacing: Tokens.Space.s4) {
                        ProgressBar(value: Double(percent) / 100, tint: Tokens.actionPrimary)
                        Text("\(completed)/\(course.allConcepts.count) 완료 (\(percent)%)")
                            .font(.mCaption.monospacedDigit())
                            .foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }

            Divider()

            assessmentGatePanel(for: course)

            courseGuide(course, hasPrerequisites: !prerequisiteTitles.isEmpty)
        }
        .padding(cardPadding)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).stroke(Tokens.line))
    }

    /// 과목 안내: 잠금 규칙과 권장 선수 과목.
    ///
    /// 기본은 접힌 상태다. 개념 행마다 상태가 글자로 이미 적혀 있어 아이콘 범례가
    /// 같은 말을 세 번 반복했고, 선수 과목 설명은 지금 무엇을 누를지 정하는 데
    /// 쓰이지 않는데도 진도와 평가 상태보다 위에서 자리를 차지했다.
    @ViewBuilder
    private func courseGuide(_ course: CourseV2, hasPrerequisites: Bool) -> some View {
        DisclosureGroup(isExpanded: $showsCourseGuide) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Label("모든 개념은 바로 학습할 수 있습니다", systemImage: "lock.open.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.ink)
                Text("개념 학습에는 잠금이 없고, 평가 응시 조건만 별도로 적용됩니다.")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                if hasPrerequisites {
                    Label("권장 선수 과목", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.ink)
                    Text(prerequisiteSummary(for: course))
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("먼저 들으면 좋다는 뜻이고, 이 과목을 여는 데 제한을 두지는 않습니다.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Space.s3)
        } label: {
            Text("이 과목 안내 보기")
                .font(.mCaption)
                .foregroundStyle(Tokens.actionPrimary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .tint(Tokens.actionPrimary)
        .accessibilityHint("잠금 규칙과 권장 선수 과목을 펼칩니다")
    }

    private func prerequisiteSummary(for course: CourseV2) -> String {
        course.prerequisites.compactMap { prerequisiteID in
            guard let prerequisite = courses.first(where: { $0.id == prerequisiteID }) else {
                return nil
            }
            let percent = store.progressV2.coursePercent(prerequisite)
            return percent >= 100
                ? "\(prerequisite.title) 완료"
                : "\(prerequisite.title) \(percent)%"
        }.joined(separator: ", ")
    }

    private func assessmentGatePanel(for course: CourseV2) -> some View {
        let projection = assessmentGateProjection(for: course)
        return HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: projection.state.systemImage)
                .font(.mBodyB)
                .foregroundStyle(projection.state.foreground)
                .frame(width: 24, height: 24, alignment: .top)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(projection.title)
                    .font(.mBodyB)
                    .foregroundStyle(projection.state.foreground)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(projection.detail)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(projection.state.background,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(projection.title). \(projection.detail)")
    }

    /// 평가센터의 기존 해금 규칙을 읽어 이 화면에 설명만 투영한다.
    /// 개념 Button은 어떤 경우에도 비활성화하지 않는다.
    private func assessmentGateProjection(for course: CourseV2) -> CurriculumAssessmentProjection {
        guard let assessmentCourse = AssessCatalog.course(course.id) else {
            return CurriculumAssessmentProjection(
                state: .unsupported,
                title: "단계 평가 미지원",
                detail: "이 과목은 정식 단계 평가 카탈로그에 없습니다. 개념 학습과 연습은 모두 바로 이용할 수 있습니다."
            )
        }

        if store.coursePassedV2(course.id) {
            return CurriculumAssessmentProjection(
                state: .completed,
                title: "평가 완료: \(course.title)",
                detail: "과목 종합평가를 통과했습니다. 완료한 개념도 언제든 다시 학습할 수 있습니다."
            )
        }

        var candidates: [CurriculumAssessmentProjection] = []

        func candidate(scopeKey: String,
                       title: String,
                       unlocked: Bool,
                       unlockedDetail: String,
                       lockDetail: String) -> CurriculumAssessmentProjection? {
            if store.attemptsV2.passed(scopeKey: scopeKey) { return nil }
            if store.attemptsV2.openAttempt(scopeKey: scopeKey) != nil {
                return CurriculumAssessmentProjection(
                    state: .inProgress,
                    title: "평가 진행 중: \(title)",
                    detail: "작성 중인 답안이 저장되어 있습니다. 평가센터에서 이어서 응시할 수 있습니다."
                )
            }
            if unlocked {
                return CurriculumAssessmentProjection(
                    state: .available,
                    title: "평가 가능: \(title)",
                    detail: unlockedDetail
                )
            }
            return CurriculumAssessmentProjection(
                state: .locked,
                title: "평가 잠김: \(title)",
                detail: lockDetail
            )
        }

        for unit in assessmentCourse.units {
            for subunit in unit.subunits {
                let done = subunit.conceptIds.filter(conceptDoneForAssessment).count
                let scopeKey = "subunit/\(assessmentCourse.courseId)/\(unit.unitId)/\(subunit.id)"
                if let row = candidate(
                    scopeKey: scopeKey,
                    title: "\(subunit.title) 중간평가",
                    unlocked: done == subunit.conceptIds.count,
                    unlockedDetail: "연결 개념 \(done)/\(subunit.conceptIds.count)개를 완료해 응시 조건을 충족했습니다.",
                    lockDetail: "잠금 이유: 연결 개념 \(done)/\(subunit.conceptIds.count)개 완료. 남은 개념을 완료하면 열립니다."
                ) {
                    candidates.append(row)
                }
            }

            let conceptIDs = unit.subunits.flatMap(\.conceptIds)
            let conceptDoneCount = conceptIDs.filter(conceptDoneForAssessment).count
            let passedSubunits = unit.subunits.filter {
                store.attemptsV2.passed(
                    scopeKey: "subunit/\(assessmentCourse.courseId)/\(unit.unitId)/\($0.id)"
                )
            }.count
            let conceptsDone = conceptDoneCount == conceptIDs.count
            let subunitsPassed = passedSubunits == unit.subunits.count
            let unitLockDetail = conceptsDone
                ? "잠금 이유: 소단원 중간평가 \(passedSubunits)/\(unit.subunits.count)개 통과. 모두 통과하면 열립니다."
                : "잠금 이유: 대단원 개념 \(conceptDoneCount)/\(conceptIDs.count)개 완료. 모두 완료하면 열립니다."
            if let row = candidate(
                scopeKey: "unit/\(assessmentCourse.courseId)/\(unit.unitId)/-",
                title: "\(unit.title) 기말평가",
                unlocked: conceptsDone && subunitsPassed,
                unlockedDetail: "대단원 개념과 소단원 중간평가를 모두 완료해 응시 조건을 충족했습니다.",
                lockDetail: unitLockDetail
            ) {
                candidates.append(row)
            }
        }

        let passedUnits = assessmentCourse.units.filter {
            store.attemptsV2.passed(
                scopeKey: "unit/\(assessmentCourse.courseId)/\($0.unitId)/-"
            )
        }.count
        if let courseRow = candidate(
            scopeKey: "course/\(assessmentCourse.courseId)/-/-",
            title: "\(course.title) 과목 종합평가",
            unlocked: passedUnits == assessmentCourse.units.count,
            unlockedDetail: "모든 대단원 기말평가를 통과해 종합평가 응시 조건을 충족했습니다.",
            lockDetail: "잠금 이유: 대단원 기말평가 \(passedUnits)/\(assessmentCourse.units.count)개 통과. 모두 통과하면 열립니다."
        ) {
            candidates.append(courseRow)
        }

        return candidates.first { $0.state == .inProgress }
            ?? candidates.first { $0.state == .available }
            ?? candidates.first { $0.state == .locked }
            ?? CurriculumAssessmentProjection(
                state: .completed,
                title: "평가 완료: \(course.title)",
                detail: "이 과목의 단계 평가를 모두 통과했습니다."
            )
    }

    private func conceptDoneForAssessment(_ conceptID: String) -> Bool {
        guard let (_, _, concept) = CurriculumV2.concept(conceptID) else { return false }
        if store.progressV2.percent(for: concept) >= 100 { return true }
        if let legacyID = concept.legacy?.appId {
            return store.completedConceptIDs.contains(legacyID)
        }
        return false
    }

    @ViewBuilder
    private func learningTracksSection(course: CourseV2) -> some View {
        let tracks = CurriculumV2.data.learningTracks
            .filter { $0.courseId == course.id }
            .sorted { $0.order < $1.order }
        if !tracks.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text("추천 학습 코스")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                    // 개념마다 "코스 출발 개념 / 권장 선수 개념: ○○" 을 붙이던 줄을
                    // 여기 한 문장으로 합쳤다. 순서는 나열 순서가 이미 말해 주므로
                    // 같은 뜻을 개념 수만큼 되풀이할 이유가 없다.
                    Text("관련 개념을 배우기 좋은 순서로 묶었습니다. 앞에 적힌 개념이 뒤 개념의 권장 선수 개념입니다.")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(tracks) { track in
                    learningTrackCard(track)
                }
            }
        }
    }

    private func learningTrackCard(_ track: LearningTrackV2) -> some View {
        let concepts = CurriculumV2.concepts(in: track)
        let completed = concepts.filter { store.progressV2.percent(for: $0) >= 100 }.count
        let totalMinutes = concepts.reduce(0) { $0 + ($1.lesson?.estimatedMinutes ?? 15) }
        let sequence = concepts.map(\.title).joined(separator: ", ")
        return VStack(alignment: .leading, spacing: shortHeight ? Tokens.Space.s3 : Tokens.Space.s4) {
                Group {
                    // 코스 카드 머리를 1열로 접는다. compact 폭에서는 제목과 예상 시간이
                    // 한 줄을 나눠 가지면 22pt 제목이 두세 줄로 쪼개진다.
                    if stacksCardHeader {
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            trackHeading(track, completed: completed, total: concepts.count)
                            Text(estimatedTimeLabel(totalMinutes))
                                .font(.mCaption.monospacedDigit())
                                .foregroundStyle(Tokens.text3)
                        }
                    } else {
                        HStack(alignment: .top, spacing: Tokens.Space.s4) {
                            trackHeading(track, completed: completed, total: concepts.count)
                            Spacer(minLength: Tokens.Space.s4)
                            Text(estimatedTimeLabel(totalMinutes))
                                .font(.mCaption.monospacedDigit())
                                .foregroundStyle(Tokens.text3)
                        }
                    }
                }

                Text(track.summary)
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                // 개념을 다시 목록으로 펼치지 않는다. 같은 개념이 아래 과목 지도에
                // 눌리는 행으로 이미 있는데 여기서도 늘어놓으면, 어느 쪽을 눌러야
                // 하는지 흐려지고 "개념은 아래 전체 지도에서 선택" 같은
                // 가리키기만 하는 문구가 필요해진다. 그 문구는 지웠다.
                Text("배우는 순서: \(sequence)")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Tokens.progressBlue)
                .frame(width: 4)
                .padding(.vertical, Tokens.Space.s4)
        }
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).stroke(Tokens.line))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("추천 학습 경로, \(track.title), \(completed)개 완료, 전체 \(concepts.count)개, \(estimatedTimeLabel(totalMinutes)), 배우는 순서 \(sequence)")
    }

    private func conceptDisplayState(for concept: ConceptV2,
                                     currentConceptID: String?) -> CurriculumConceptDisplayState {
        let percent = store.progressV2.percent(for: concept)
        if percent >= 100 { return .completed }
        if percent > 0 || concept.id == currentConceptID { return .current(percent: percent) }
        return .available
    }

    private func conceptStateLabel(_ state: CurriculumConceptDisplayState) -> some View {
        Label(state.label, systemImage: state.systemImage)
            .font(.mCaption)
            .foregroundStyle(state.foreground)
    }

    private func conceptStateGlyph(_ state: CurriculumConceptDisplayState,
                                   ordinal: Int,
                                   size: CGFloat) -> some View {
        ZStack {
            Circle().fill(state.background)
            if case .available = state {
                Text("\(ordinal)")
                    .font(.mCaption.monospacedDigit().weight(.bold))
                    .foregroundStyle(state.foreground)
            } else {
                Image(systemName: state.systemImage)
                    .font(.mCaption.weight(.bold))
                    .foregroundStyle(state.foreground)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func trackHeading(_ track: LearningTrackV2, completed: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.eyebrow)
                .font(.mMicro.weight(.bold))
                .foregroundStyle(Tokens.progressBlue)
            Text(track.title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(completed)/\(total) 완료")
                .font(.mCaption.monospacedDigit())
                .foregroundStyle(Tokens.text3)
        }
    }

    private func unitSection(course: CourseV2, unit: UnitV2, index: Int) -> some View {
        let completed = unit.concepts.filter { store.progressV2.percent(for: $0) >= 100 }.count
        let currentConceptID = nextConcept(in: course)?.id
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("단원 \(index + 1)")
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(Tokens.progressBlue)
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                            Text(unit.title)
                                .font(.mHeading)
                                .foregroundStyle(Tokens.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(completed)/\(unit.concepts.count) 완료")
                                .font(.mCaption.monospacedDigit())
                                .foregroundStyle(Tokens.text3)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                            Text(unit.title)
                                .font(.mHeading)
                                .foregroundStyle(Tokens.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: Tokens.Space.s3)
                            Text("\(completed)/\(unit.concepts.count)")
                                .font(.mCaption.monospacedDigit())
                                .foregroundStyle(Tokens.text3)
                        }
                    }
                }
            }
            .padding(cardPadding)

            Divider()

            ForEach(Array(unit.concepts.enumerated()), id: \.element.id) { conceptIndex, concept in
                conceptRow(
                    concept: concept,
                    index: conceptIndex,
                    currentConceptID: currentConceptID
                )
                if conceptIndex < unit.concepts.count - 1 {
                    Divider().padding(.leading, conceptRowDividerInset)
                }
            }
        }
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).stroke(Tokens.line))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
    }

    private func conceptRow(concept: ConceptV2,
                            index: Int,
                            currentConceptID: String?) -> some View {
        let state = conceptDisplayState(for: concept, currentConceptID: currentConceptID)
        return Button {
            store.openConceptV2(concept.id)
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // 잠금이 없다는 사실은 과목 카드가 한 번 말한다. 220개 행마다
                    // 다시 붙이면 정작 제목과 상태가 묻힌다(VoiceOver 문구에는 남는다).
                    conceptCopy(concept, state: state)
                } else {
                    HStack(alignment: .top, spacing: Tokens.Space.s4) {
                        conceptStateGlyph(state, ordinal: index + 1, size: 36)
                        conceptCopy(concept, state: state)
                        Spacer(minLength: Tokens.Space.s2)
                        Image(systemName: "chevron.right")
                            .font(.mCaption.weight(.semibold))
                            .foregroundStyle(Tokens.text3)
                            .padding(.top, 8)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.horizontal, conceptRowHPadding)
            .padding(.vertical, Tokens.Space.s4)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(concept.title), \(state.label), 예상 \(concept.lesson?.estimatedMinutes ?? 15)분, 학습 가능, 잠금 없음")
        .accessibilityHint("개념 강의 화면을 엽니다")
    }

    private func conceptCopy(_ concept: ConceptV2,
                             state: CurriculumConceptDisplayState) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(concept.title)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            // 성취기준 코드("10공수1-01-01")는 학생 화면에 내보내지 않는다.
            // 교육과정 문서를 대조하는 사람에게나 쓰는 식별자이고, 학습자에게는
            // 제목 아래 첫 줄을 차지하면서 아무것도 알려주지 않는다.
            // 값 자체는 curriculum-v2.json 에 그대로 있어 대조가 필요하면 언제든 꺼낸다.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 3) {
                        conceptStateLabel(state)
                        Text("예상 \(concept.lesson?.estimatedMinutes ?? 15)분")
                            .foregroundStyle(Tokens.text3)
                            .monospacedDigit()
                    }
                } else {
                    // 남은 항목이 상태와 예상 시간 둘뿐이라 compact 폭 전용 분기가
                    // 필요 없어졌다("잠금 / 없음" 으로 접히던 세 번째 항목을 뺐다).
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Tokens.Space.s3) {
                            Text(state.label).foregroundStyle(state.foreground)
                            Text("예상 \(concept.lesson?.estimatedMinutes ?? 15)분")
                                .foregroundStyle(Tokens.text3)
                                .monospacedDigit()
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.label).foregroundStyle(state.foreground)
                            Text("예상 \(concept.lesson?.estimatedMinutes ?? 15)분")
                                .foregroundStyle(Tokens.text3)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .font(.mCaption)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nextConcept(in course: CourseV2) -> ConceptV2? {
        course.allConcepts.first {
            let percent = store.progressV2.percent(for: $0)
            return percent > 0 && percent < 100
        } ?? course.allConcepts.first {
            store.progressV2.percent(for: $0) < 100
        }
    }

    /// 웹과 같은 ProgressV2 이어학습 우선순위에서 target 한 개만 고르고,
    /// 그 한 개의 story만 resolve한다. 과목/개념 목록을 story 뷰로 확장하지 않는다.
    private var topTimelinePreview: CurriculumStoryCompactPreviewModel {
        guard let (course, unit, concept) = store.progressV2.continueConcept() else {
            let hasConcepts = courses.contains { !$0.allConcepts.isEmpty }
            return CurriculumStoryCompactPreviewModel(
                state: hasConcepts ? .completed : .empty,
                openingQuestion: nil,
                storyAvailable: false,
                courseTitle: nil,
                unitTitle: nil,
                conceptID: nil,
                conceptTitle: nil,
                estimatedMinutes: nil,
                progress: nil,
                // 가리키는 곳이 실제로 있어야 한다. "아래" 는 이 카드 밑의 과목 지도이고,
                // 거기 개념 행은 눌러서 바로 열린다. 없는 버튼을 가리키지 않는다.
                message: hasConcepts
                    ? "지금 배울 개념을 모두 마쳤습니다. 아래 과목 지도에서 개념을 골라 다시 볼 수 있습니다."
                    : "아직 시작할 개념이 없습니다."
            )
        }

        let resolution = CurriculumStoryCatalog.resolve(
            courseID: course.id,
            unitID: unit.id,
            conceptID: concept.id
        )
        let progress = store.progressV2.percent(for: concept)
        let state: CurriculumStoryCompactState
        let message: String

        if resolution.story != nil {
            state = progress > 0 ? .current : .next
            message = "이 버튼을 누르면 5분 해설과 연습 문제가 이어서 나옵니다."
        } else {
            switch resolution.availability {
            case .draft, .invalid:
                state = .locked
                message = "5분 해설을 검수하고 있습니다. 개념 학습은 바로 시작할 수 있습니다."
            case .missing, .unavailable, .published:
                state = .empty
                message = "5분 해설 미리보기가 아직 없습니다. 개념 학습은 바로 시작할 수 있습니다."
            }
        }

        return CurriculumStoryCompactPreviewModel(
            state: state,
            openingQuestion: resolution.story?.openingQuestion,
            storyAvailable: resolution.story != nil,
            courseTitle: course.title,
            unitTitle: unit.title,
            conceptID: concept.id,
            conceptTitle: concept.title,
            estimatedMinutes: concept.lesson?.estimatedMinutes ?? 15,
            progress: progress,
            message: message
        )
    }

    private func categoryTitle(_ id: String) -> String {
        CurriculumV2.data.categories.first { $0.id == id }?.title ?? "선택 과목"
    }

    private func gradeLabel(_ grades: [Int]) -> String {
        guard !grades.isEmpty else { return "학교별 편성" }
        return grades.map {
            switch $0 {
            case 10: return "고1"
            case 11: return "고2"
            case 12: return "고3"
            default: return "학교별 편성"
            }
        }.joined(separator: ", ")
    }

    private func estimatedTimeLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "예상 \(minutes)분" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0
            ? "예상 \(hours)시간"
            : "예상 \(hours)시간 \(remainder)분"
    }

}
