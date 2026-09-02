//  CurriculumStoryTimeline.swift
//  Matths
//
//  음성·포인터·강조판이 한 장면을 함께 가리키는 모션 수업 보드.

import SwiftUI

private struct CurriculumTimelineWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct CurriculumStoryTimeline: View {
    let resolution: CurriculumStoryResolution
    let concept: ConceptV2
    let onLessonCompleted: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.matthsBrowseViewportSize) private var viewportSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WebMotion.preferenceKey) private var userMotionEnabled = true
    @AppStorage(ConceptNarrationPreference.key)
    private var storedNarrationVoice = ConceptNarrationPreference.appDefault.rawValue
    @StateObject private var player = CurriculumNarrationPlayer()

    /// 코드 애니메이션이 서지 못했다는 신고를 받았는가. 받으면 그 개념은 이 화면이
    /// 살아 있는 동안 기존 무대로 간다 — 같은 문서를 계속 다시 열어 봐야 같은 자리에서 넘어진다.
    @State private var webStageFailed = false
    /// 코드 애니메이션 무대가 지금 소리를 내도 되는가(앱 활성 + 화면에 보이는 중).
    @State private var webStageActive = true
    /// 카드 안쪽의 실제 폭. iPad 회전·Split View에서도 기기 이름 대신 이 값으로
    /// 세로 압축판과 가로 2열판을 고른다.
    @State private var contentWidth: CGFloat = 0

    /// 시각 영역을 시나리오 플레이어로 그릴지, 현행 Canvas 로 그릴지.
    ///
    /// 모션이 꺼져 있으면(시스템 '동작 줄이기' 또는 앱 모션 스위치) Canvas 로 폴백한다.
    /// scenario-player.js 는 MATTHS_MOTION === false 일 때 seek(0) 후 정지하므로,
    /// 모션에 예민한 학생에게 "완결된 정적 콘텐츠" 대신 "첫 프레임 + 재생 버튼" 이
    /// 남는다 — 현행 대비 접근성 회귀다. Canvas 는 같은 조건에서 마지막 beat 를
    /// 그려 두므로(resetBeat 의 reduceMotion 분기) 정적 완성본이 나온다.
    private var prefersScenarioStage: Bool {
        WebMotion.allowed(userEnabled: userMotionEnabled, reduceMotion: reduceMotion)
    }

    /// 개념 영상 규격 버전. 영상을 다시 뽑으면 올린다 — 파일명에 박혀 있어
    /// 옛 파일이 남아 있어도 새 것을 찾는다.
    private static let motionVersion = 1

    /// 가로 iPhone은 vertical compact라 바로 2열판을 쓴다. iPad는 창의 실제
    /// 가로/세로 비와 카드 폭을 함께 본다. 폭 1024pt급 구형 iPad 가로는 카드 안쪽이
    /// 960pt보다 작아도 가로판이어야 하고, 13인치 iPad 세로는 920pt가 나와도
    /// 세로판이어야 하므로 폭 하나만으로는 판정할 수 없다.
    private var motionPresentation: ConceptMotionPresentation {
        let hasViewport = viewportSize.width > 0 && viewportSize.height > 0
        let landscapeWindow = hasViewport && viewportSize.width > viewportSize.height
        if verticalSizeClass == .compact
            || (landscapeWindow && contentWidth >= 800)
            || (!hasViewport && contentWidth >= 960) {
            return .wideBoard
        }
        return .portraitBoard
    }

    /// 나레이션이 구워진 개념 영상이 준비돼 있는가.
    ///
    /// 준비돼 있으면 그걸 튼다. 그러면 그림과 말의 시계가 하나가 된다.
    /// 준비돼 있지 않으면 종전 벡터 무대 + TTS 로 내려간다 — 220개 개념 중
    /// 영상이 아직 없는 것들이 그냥 비어 버리면 안 되기 때문이다.
    private var motionVideoURL: URL? {
        ConceptMotionAsset.url(conceptID: concept.id, version: Self.motionVersion)
    }

    /// 개념 코드 애니메이션(HTML 컴포지션)이 준비돼 있는가.
    ///
    /// mp4 다음 순위다. mp4 는 소리가 그림 안에 물리적으로 구워져 있어 어긋날 여지가
    /// 아예 없고, HTML 은 오디오 currentTime 을 유일한 시계로 삼아 같은 성질을
    /// 코드로 만든다. 둘 다 없을 때만 종전 벡터 무대로 내려간다.
    ///
    /// 모션이 꺼져 있으면 쓰지 않는다. 컴포지션의 t=0 은 모든 요소가 opacity 0 인
    /// **빈 화면**이라, 첫 프레임을 세워 두면 학생에게 남는 게 아무것도 없다.
    /// 같은 조건에서 Canvas 무대는 마지막 beat 를 그려 완성된 정적 콘텐츠를 남긴다
    /// (prefersScenarioStage 주석과 같은 판단이다).
    ///
    /// 어느 컴포지션을 어느 음성과 짝지어 열지는 무대가 스스로 고른다 —
    /// 성우 설정은 전역이고, 그 짝은 무대만 아는 규칙이다. 여기서는
    /// "이 개념에 코드 애니메이션이 있는가" 만 본다.
    private var hasMotionWebStage: Bool {
        guard !webStageFailed, prefersScenarioStage else { return false }
        return ConceptMotionWebAsset.isReady(conceptID: concept.id)
    }

    /// 이 설정은 HTML 컴포지션과 그 성우별 타이밍 파일을 함께 고르는 스위치다.
    /// 소리가 이미 구워진 mp4나 TTS 폴백에서는 같은 선택을 즉시 반영할 수 없으므로
    /// 그 경로에 거짓 컨트롤을 노출하지 않는다.
    private var showsNarrationVoiceMenu: Bool {
        motionVideoURL == nil && hasMotionWebStage
    }

    /// 작은 iPhone·좁은 Split View·접근성 글자에서는 제목과 성우
    /// 메뉴를 한 행에 억지로 넣지 않는다. 제목은 읽히는 폭을 갖고
    /// 메뉴는 그 아래의 독립된 44pt 조작으로 내려간다.
    private var usesStackedNarrationHeader: Bool {
        horizontalSizeClass == .compact
            || dynamicTypeSize.isAccessibilitySize
            || (contentWidth > 0 && contentWidth < 600)
    }

    private var selectedNarrationVoice: ConceptNarrationVoice {
        ConceptNarrationVoice(rawValue: storedNarrationVoice)
            ?? ConceptNarrationPreference.appDefault
    }

    var body: some View {
        Group {
            if let story = resolution.story {
                publishedStory(story)
            } else {
                unavailableStory
            }
        }
        // 해설 음성은 영상의 일부다. 화면에 들어오면 애니메이션과 함께 시작하고
        // 나가면 함께 멈춘다. 재생·일시정지 버튼은 없다 — 영상에 재생 버튼을 따로 달지
        // 않는 것과 같은 이유다. 다만 HTML 모션은 오른쪽 메뉴에서 성우/무음을 고를 수 있고,
        // 그 선택도 컴포지션과 음성의 짝을 함께 다시 여는 방식으로만 반영한다.
        // 저절로 나는 소리라 다른 앱 소리·동작 줄이기는 지킨다(autoStart 안에서 판정).
        //
        // 영상이 있으면 TTS 를 아예 켜지 않는다. 이 게이트가 이 화면의 핵심이다 —
        // 영상 안의 소리와 TTS 가 같이 나면 시계가 둘이 되어, 고치려던 문제가
        // 그대로 재현된다. 세 진입로(등장 / 스토리 교체 / 앱 복귀) 전부에 건다.
        .onAppear {
            webStageActive = true
            guard motionVideoURL == nil, !hasMotionWebStage,
                  let story = resolution.story else { return }
            player.load(story)
            player.autoStart(allowed: !reduceMotion)
        }
        .onChange(of: concept.id) { _, _ in
            // 개념이 바뀌면 앞 개념의 실패 판정을 물려주지 않는다.
            webStageFailed = false
        }
        .onChange(of: resolution.story?.narrationCheckpointID) { _, _ in
            player.unload()
            guard motionVideoURL == nil, !hasMotionWebStage,
                  let story = resolution.story else { return }
            player.load(story)
            player.autoStart(allowed: !reduceMotion)
        }
        .onChange(of: scenePhase) { _, phase in
            webStageActive = phase == .active
            if phase != .active {
                player.pauseForInterruption()
            } else if motionVideoURL == nil, !hasMotionWebStage {
                // 돌아오면 이어서 켠다. 버튼이 없으니 여기서 되살리지 않으면
                // 잠깐 다른 앱에 다녀온 것만으로 해설이 영영 멈춘다.
                // 영상 분기에서는 AVPlayer 가, 코드 애니메이션 분기에서는
                // webStageActive 가 이어받으므로 손대지 않는다.
                player.autoStart(allowed: !reduceMotion)
            }
        }
        .onDisappear {
            webStageActive = false
            player.pauseForInterruption()
        }
    }

    @ViewBuilder
    private func publishedStory(_ story: CurriculumStudentStory) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s6) {
            if showsNarrationVoiceMenu {
                if usesStackedNarrationHeader {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        storyHeading(story)
                        narrationVoiceMenu
                    }
                    .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: Tokens.Space.s4) {
                        storyHeading(story)
                            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
                        Spacer(minLength: Tokens.Space.s3)
                        narrationVoiceMenu
                    }
                }
            } else {
                storyHeading(story)
                    .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            }

            Divider().overlay(Tokens.line)
                .frame(maxWidth: Tokens.readableWidth)

            // 설명 단계의 시각 영역만 교체한다. 학습 구조(캡션·확인 문제·정답 판정·
            // 재설명·완료 게이트)는 어느 분기에서든 story JSON 이 그대로 소유한다.
            //
            // 1순위는 나레이션이 구워진 개념 영상이다. 소리가 그림 안에 있으니
            // 둘이 어긋날 수가 없다. 이때 TTS 는 돌리지 않는다 — 돌리면 시계가
            // 다시 둘이 되어 원래 문제로 돌아간다.
            if let videoURL = motionVideoURL {
                ConceptMotionVideoView(
                    url: videoURL,
                    motionActive: prefersScenarioStage,
                    onFinished: onLessonCompleted,
                    onFailure: {}
                )
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(maxHeight: ConceptMotionPresentation.portraitBoard.maximumDisplayHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                .accessibilityIdentifier("concept-motion-video")
                .accessibilityLabel("\(concept.title) 개념 설명 영상")
            } else if hasMotionWebStage {
                if contentWidth > 0 {
                    // 세로 화면은 위아래 빈 띠를 걷어낸 1080×1560, 가로 화면은
                    // 모션판과 설명판을 나란히 둔 2160×1080이다. 어느 쪽도 내부
                    // 수학 좌표나 타임라인은 건드리지 않는다.
                    ConceptMotionWebStage(
                        conceptID: concept.id,
                        presentation: motionPresentation,
                        active: webStageActive,
                        colorScheme: colorScheme,
                        onFinished: onLessonCompleted,
                        onFailure: fallBackFromWebStage
                    )
                    .aspectRatio(motionPresentation.aspectRatio, contentMode: .fit)
                    .frame(maxHeight: motionPresentation.maximumDisplayHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                    .accessibilityIdentifier("concept-motion-web-stage")
                    .accessibilityLabel("\(concept.title) 개념 설명 애니메이션")
                } else {
                    // 첫 레이아웃에서 카드 폭을 잰 뒤 웹뷰를 한 번만 만든다. iPad 가로에서
                    // 세로 문서를 먼저 열었다가 즉시 갈아끼우면 음성이 두 번 시작할 수 있다.
                    Color.clear.frame(height: 1)
                }
            } else if prefersScenarioStage,
               CurriculumScenarioLessonView.canPresent(story: story, conceptID: concept.id) {
                CurriculumScenarioLessonView(
                    story: story,
                    conceptID: concept.id,
                    player: player,
                    onLessonCompleted: onLessonCompleted
                )
                .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            } else {
                CurriculumMotionLessonView(
                    story: story,
                    visualizationIdeas: concept.visualizationIdeas,
                    player: player,
                    onLessonCompleted: onLessonCompleted
                )
                .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: CurriculumTimelineWidthKey.self,
                                       value: proxy.size.width)
            }
        }
        .onPreferenceChange(CurriculumTimelineWidthKey.self) { width in
            guard width > 0, abs(width - contentWidth) > 0.5 else { return }
            contentWidth = width
        }
        .padding(Tokens.Space.s6)
        .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.lineStrong, lineWidth: 1)
        }
        .accessibilityIdentifier("curriculum-story-timeline")
    }

    /// 코드 애니메이션이 서지 못했을 때. 개념 하나가 통째로 비면 안 되므로 종전 무대로
    /// 내려간다. 그리고 이때는 무대가 소리를 갖고 있지 않으므로 **그제서야** 해설 음성을 켠다 —
    /// 등장 시점의 게이트가 "무대에 소리가 있다" 를 전제로 TTS 를 막아 뒀기 때문에,
    /// 여기서 켜 주지 않으면 폴백한 개념만 해설 없이 그림만 도는 화면이 된다.
    private func fallBackFromWebStage() {
        guard !webStageFailed else { return }
        webStageFailed = true
        guard motionVideoURL == nil, let story = resolution.story else { return }
        player.load(story)
        player.autoStart(allowed: !reduceMotion)
    }

    private func storyHeading(_ story: CurriculumStudentStory) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s2) {
                Text("선생님 보드")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.progressBlue)
                Text("약 \(max(1, story.estimatedSeconds / 60))분")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
            }
            Text(story.title)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(story.openingQuestion)
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 재생 수송 버튼이 아니라 HTML 모션이 실제로 소비하는 전역 성우 설정이다.
    /// `ConceptMotionWebStage`가 같은 AppStorage 키를 관찰하므로 선택 즉시 올바른
    /// 컴포지션/음성 쌍으로 다시 연다.
    private var narrationVoiceMenu: some View {
        Menu {
            ForEach(ConceptNarrationVoice.allCases) { voice in
                Button {
                    storedNarrationVoice = voice.rawValue
                } label: {
                    if voice == selectedNarrationVoice {
                        Label(voice.label, systemImage: "checkmark")
                    } else {
                        Text(voice.label)
                    }
                }
            }
        } label: {
            Label(selectedNarrationVoice.label,
                  systemImage: selectedNarrationVoice.isSpoken
                    ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.mCaption)
                .foregroundStyle(Tokens.primary)
                .padding(.horizontal, Tokens.Space.s3)
                .frame(minHeight: 44)
                .background(Tokens.surface, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Tokens.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("개념 해설 음성")
        .accessibilityValue(selectedNarrationVoice.label)
        .accessibilityIdentifier("concept-narration-voice-menu")
    }

    private var unavailableStory: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("선생님 보드")
                .font(.mMicro)
                .foregroundStyle(Tokens.progressBlue)
            Text("모션 해설은 편집 중입니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text("검수된 원고가 준비되기 전에는 자동으로 만든 해설을 보여주지 않습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: "book.closed")
                    .foregroundStyle(Tokens.progressBlue)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text("기존 개념 학습은 그대로 이어갈 수 있습니다.")
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                    Text("아래 핵심 설명과 시각 학습, 연습 문제를 이용해 주세요. 검수를 마친 모션 해설만 선생님 보드에 추가됩니다.")
                        .font(.mCallout)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Tokens.Space.s4)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        }
        .padding(Tokens.Space.s6)
        .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
        .background(Tokens.paper, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.lineStrong, lineWidth: 1)
        }
        .accessibilityIdentifier("curriculum-story-unavailable")
    }

    private func nodeColor(_ kind: CurriculumStorySceneKind) -> Color {
        switch kind {
        case .intuition: Tokens.progressBlue
        case .question: Tokens.actionPrimary
        case .misconception: Tokens.warningInk
        case .solution: Tokens.primaryDark
        case .recall: Tokens.successInk
        }
    }

    private func nodeTextColor(_ kind: CurriculumStorySceneKind) -> Color {
        switch kind {
        case .misconception: Tokens.warningInk
        case .recall: Tokens.successInk
        default: Tokens.progressBlue
        }
    }
}

enum CurriculumStoryCompactState: String {
    case current
    case next
    case locked
    case empty
    case completed

    var label: String {
        switch self {
        case .current: "현재 학습"
        case .next: "다음 학습"
        case .locked: "5분 해설 검수 중"
        case .empty: "프리뷰 없음"
        case .completed: "학습 완료"
        }
    }

    var symbol: String {
        switch self {
        case .current: "play.fill"
        case .next: "arrow.right"
        case .locked: "lock.fill"
        case .empty: "diamond"
        case .completed: "checkmark"
        }
    }

    var foreground: Color {
        switch self {
        case .current, .next: Tokens.primaryDark
        case .locked: Tokens.warningInk
        case .empty: Tokens.text2
        case .completed: Tokens.successInk
        }
    }

    var background: Color {
        switch self {
        case .current, .next: Tokens.primarySoft
        case .locked: Tokens.warningSoft
        case .empty: Tokens.paper2
        case .completed: Tokens.successSoft
        }
    }
}

struct CurriculumStoryCompactPreviewModel {
    let state: CurriculumStoryCompactState
    let openingQuestion: String?
    let storyAvailable: Bool
    let courseTitle: String?
    let unitTitle: String?
    let conceptID: String?
    let conceptTitle: String?
    let estimatedMinutes: Int?
    let progress: Int?
    let message: String

    var actionLabel: String {
        guard conceptID != nil else { return "" }
        return (progress ?? 0) > 0 ? "이어서 학습" : "개념 시작"
    }
}

/// 개념 상세의 검수된 5장면을 제목·부제만으로 축약한 상단 기억선이다.
/// narration Text와 음성 플레이어를 만들지 않아 220개 장문 SwiftUI가 생길 수 없다.
struct CurriculumStoryCompactPreview: View {
    let model: CurriculumStoryCompactPreviewModel
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            heading

            if model.conceptID != nil {
                resumePrompt
            } else {
                unavailableState
            }

            footer
        }
        .padding(Tokens.Space.s5)
        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(Tokens.lineStrong, lineWidth: 1)
        }
        .accessibilityIdentifier("curriculum-top-story-preview")
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }

    private var heading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                headingCopy
                Spacer(minLength: Tokens.Space.s3)
                stateBadge
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                headingCopy
                stateBadge
            }
        }
    }

    private var headingCopy: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("오늘 이어갈 개념")
                .font(.mMicro.weight(.bold))
                .foregroundStyle(Tokens.progressBlue)
            Text(model.conceptTitle ?? completedOrEmptyTitle)
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let courseTitle = model.courseTitle,
               let unitTitle = model.unitTitle,
               let estimatedMinutes = model.estimatedMinutes {
                Text("\(courseTitle) \(unitTitle), 예상 \(estimatedMinutes)분")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var stateBadge: some View {
        Label(model.state.label, systemImage: model.state.symbol)
            .font(.mCaption.weight(.bold))
            .foregroundStyle(model.state.foreground)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(minHeight: 32)
            .background(model.state.background,
                        in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }

    private var completedOrEmptyTitle: String {
        model.state == .completed
            ? "현재 학습 범위를 모두 마쳤습니다"
            : "다음 기억선을 준비하고 있습니다"
    }

    private var resumePrompt: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: "arrow.right")
                .font(.mBodyB)
                .foregroundStyle(Tokens.progressBlue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(model.openingQuestion ?? "이 개념부터 바로 시작할 수 있습니다.")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("5장면 모션 해설과 확인 문제는 개념 화면에서 한 단계씩 보여줍니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(alignment: .leading) {
            Rectangle().fill(Tokens.progressBlue).frame(width: 4)
        }
        .accessibilityElement(children: .combine)
    }

    private var unavailableState: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Image(systemName: model.state.symbol)
                .font(.mBodyB)
                .foregroundStyle(model.state.foreground)
                .frame(width: 34, height: 34)
                .background(model.state.background, in: Circle())
                .accessibilityHidden(true)
            Text(model.message)
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.state.label). \(model.message)")
    }

    @ViewBuilder
    private var footer: some View {
        if model.conceptID != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Tokens.Space.s4) {
                    footerMessage
                    Spacer(minLength: Tokens.Space.s3)
                    openButton
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    footerMessage
                    openButton
                }
            }
            .padding(.top, Tokens.Space.s4)
            .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
        } else {
            EmptyView()
        }
    }

    private var footerMessage: some View {
        Text(!model.storyAvailable
             ? "5분 해설 준비 여부와 관계없이 개념 학습은 바로 열 수 있습니다."
             : "현재 학습은 이 카드 하나로 시작합니다. 학습 경로와 전체 지도는 아래에서 확인할 수 있습니다.")
            .font(.mCaption)
            .foregroundStyle(Tokens.text2)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var openButton: some View {
        Button(action: onOpen) {
            HStack(spacing: Tokens.Space.s2) {
                Text(model.actionLabel)
                Image(systemName: "arrow.right")
                    .accessibilityHidden(true)
            }
            // 좌우 여백은 라벨이 갖는다. 가로 배치에서는 이 버튼에 fixedSize 가 걸려
            // 폭이 내용 크기로 줄어드는데, PrimaryButtonStyle 에는 좌우 padding 이
            // 없어서 여백이 0 이 된다. 그러면 보라색 판이 글자 바운딩박스와 같아져
            // 글자가 양 끝에 붙고, 넓은 폭에서는 판이 카드 밖으로 나가 잘린다.
            // 라벨에 여백을 주면 fixedSize 가 재는 이상 크기에 여백이 포함된다.
            .padding(.horizontal, Tokens.Space.s5)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityLabel("\(model.conceptTitle ?? "개념") \(model.actionLabel)")
        .accessibilityHint("개념 상세와 모션 해설을 엽니다")
    }
}
