//  CurriculumScenarioLessonView.swift
//  Matths
//
//  설명 단계의 **그림만** 교체하는 뷰.
//
//  왜 필요한가: 선생님 보드의 Canvas 는 beat.expression 을 읽지 않아 1,100 장면 중
//  669 장면이 3개 beat 내내 픽셀까지 같았고(스토리 220개 중 141개는 5장면이 같은 그림
//  하나), beat 타임라인 합계 중앙값 6.3초 대비 나레이션은 약 60초라 러닝타임의 90%가
//  정지화면 + TTS 였다. 반면 번들에는 이미 30fps 연속 타임라인 + 같은 id 요소의
//  좌표·점열 보간 + KaTeX 조판을 하는 진짜 애니메이션 엔진(LessonWeb/scenario-player.js)이
//  있고, SCENARIO_META 키 220개가 커리큘럼 conceptId 220개와 정확히 일치한다.
//  좋은 엔진이 탐색 단계에만 물려 있어 설명 단계로 앞당긴다.
//
//  경계: 시나리오 플레이어는 그림만 그린다. 장면 캡션·확인 문제·정답 판정·
//  순한맛/매운맛 재설명·완료 콜백은 **전부 story JSON(scene.motion)** 이 그대로
//  소유한다. 시나리오에는 check 가 하나도 없어서(220/220 부재) 통째로 갈아타면
//  학습 완료 게이트가 "정답" 에서 "재생 종료" 로 격하되기 때문이다.
//
//  자막: 시나리오 자체 자막(.sp-caption)은 끈다. 커리큘럼 나레이션 TTS 와 아래
//  story 캡션이 이미 말을 담당하므로 자막이 이중으로 나오면 안 된다.
//
//  WKWebView + WKUserScript 주입은 LessonWebView / ArenaProblemVisualizationView 의
//  패턴을 그대로 복제했다. 새 엔진을 만들지 않는다 — 번들 lesson.html 을 그대로 연다.

import SwiftUI
import WebKit

struct CurriculumScenarioLessonView: View {
    let story: CurriculumStudentStory
    let conceptID: String
    @ObservedObject var player: CurriculumNarrationPlayer
    let onLessonCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sceneIndex = 0
    @State private var beatIndex = 0
    @State private var misses = 0
    @State private var explanation: String?
    @State private var explanationMode = "mild"
    @State private var advanceTask: Task<Void, Never>?
    @State private var stageHeight: CGFloat = 360

    /// 이 개념을 시나리오로 그릴 수 있는가.
    /// 시나리오 키 존재 여부는 LessonWebView 가 이미 한 번만 파싱해 캐시해 둔
    /// SCENARIO_META 키 집합을 그대로 쓴다(1.85MB 파일을 두 번 읽지 않는다).
    /// 학습 구조는 story 가 계속 소유하므로 motion 이 하나라도 비면 폴백한다.
    static func canPresent(story: CurriculumStudentStory, conceptID: String) -> Bool {
        !story.scenes.isEmpty
            && story.scenes.allSatisfy { $0.motion != nil }
            && LessonWebView.hasLesson(conceptID: conceptID)
    }

    private var currentScene: CurriculumStudentStoryScene {
        story.scenes[min(sceneIndex, max(0, story.scenes.count - 1))]
    }

    private var currentMotion: CurriculumMotionDirective? { currentScene.motion }

    private func beat(_ motion: CurriculumMotionDirective) -> CurriculumMotionBeat {
        motion.beats[min(beatIndex, max(0, motion.beats.count - 1))]
    }

    var body: some View {
        Group {
            if let motion = currentMotion {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    scenarioBoard(motion)
                    understandingBranch(motion)
                    sceneDots
                }
                .task(id: "\(sceneIndex)-\(beatIndex)-\(reduceMotion)") {
                    guard !reduceMotion, beatIndex < motion.beats.count - 1 else { return }
                    try? await Task.sleep(for: .milliseconds(beat(motion).durationMs))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.42)) { beatIndex += 1 }
                }
            }
        }
        .onChange(of: player.currentSceneID) { _, sceneID in
            guard let sceneID,
                  let index = story.scenes.firstIndex(where: { $0.id == sceneID })
            else { return }
            selectScene(index, pauseNarration: false)
        }
        .onDisappear { advanceTask?.cancel() }
        .accessibilityIdentifier("curriculum-scenario-lesson")
    }

    // MARK: - 시각 영역 (시나리오 플레이어)

    private func scenarioBoard(_ motion: CurriculumMotionDirective) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack {
                Text(currentScene.kind.label)
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(kindColor(currentScene.kind))
                Spacer()
                Text("장면 \(sceneIndex + 1)/\(story.scenes.count), 동작 \(beatIndex + 1)/\(motion.beats.count)")
                    .font(.mNumeric)
                    .foregroundStyle(Tokens.text3)
            }

            CurriculumScenarioStageView(conceptID: conceptID, height: $stageHeight)
                .frame(height: stageHeight)
                .frame(maxWidth: .infinity)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                        .strokeBorder(Tokens.lineStrong, lineWidth: 1)
                }
                .accessibilityIdentifier("curriculum-scenario-stage")

            // 캡션·강조 대상은 story JSON 이 소유한다. 그림 위에 겹치지 않고 아래에
            // 두는 이유: 웹 스테이지를 가리면 방금 살려낸 애니메이션을 다시 덮는다.
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                // 재생 버튼을 두지 않는다. 해설 음성은 영상의 일부다 —
                // 화면에 들어오면 애니메이션과 함께 시작하고 나가면 함께 멈춘다.
                // 영상에 재생 버튼을 따로 달지 않는 것과 같은 이유다.
                Text("지금 볼 곳")
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(Tokens.text3)
                Text(beat(motion).target)
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(beat(motion).caption)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // 소리가 안 날 때만 그 사실을 알린다. 조작이 아니라 안내다.
                if let notice = player.silentNotice {
                    Label(notice, systemImage: "speaker.slash")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("curriculum-narration-silent-notice")
                }
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(alignment: .leading) {
                Rectangle().fill(Tokens.progressBlue).frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("지금 볼 곳, \(beat(motion).target). \(beat(motion).caption)")

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(currentScene.title)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(currentScene.subtitle)
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("curriculum-scenario-board")
    }

    // MARK: - 학습 구조 (story JSON 소유)

    private func understandingBranch(_ motion: CurriculumMotionDirective) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            checkCard(motion.check)

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("답이 막히면 설명 방식을 바꿔보세요.")
                    .font(.mCallout.weight(.semibold))
                    .foregroundStyle(Tokens.text2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s2) { branchButtons(motion) }
                    VStack(spacing: Tokens.Space.s2) { branchButtons(motion) }
                }
            }

            if let explanation {
                Text("\(explanationMode == "mild" ? "순한맛" : explanationMode == "spicy" ? "매운맛" : "확인"): \(explanation)")
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .lineSpacing(5)
                    .padding(Tokens.Space.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.surface)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(explanationMode == "spicy" ? Tokens.warningInk : Tokens.progressBlue)
                            .frame(width: 4)
                    }
                    .accessibilityIdentifier("curriculum-scenario-reexplanation")
            }
        }
        .padding(.top, Tokens.Space.s4)
        .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
    }

    @ViewBuilder
    private func branchButtons(_ motion: CurriculumMotionDirective) -> some View {
        Button("순한맛으로 다시") { explain(motion, mode: "mild") }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: .infinity, minHeight: 48)

        Button("매운맛 핵심") { explain(motion, mode: "spicy") }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    private func checkCard(_ check: CurriculumMotionCheck) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(check.prompt)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(check.choices.enumerated()), id: \.offset) { index, choice in
                Button(choice) { selectChoice(index, check: check) }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .disabled(explanationMode == "correct")
            }
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.lineStrong, lineWidth: 1)
        }
        .accessibilityIdentifier("curriculum-scenario-check")
    }

    private var sceneDots: some View {
        HStack(spacing: Tokens.Space.s2) {
            ForEach(story.scenes.indices, id: \.self) { index in
                Button { selectScene(index) } label: {
                    Capsule()
                        .fill(index == sceneIndex ? Tokens.progressBlue : Tokens.lineStrong)
                        .frame(width: index == sceneIndex ? 24 : 9, height: 9)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1)번째 장면, \(story.scenes[index].title)")
                .accessibilityValue(index == sceneIndex ? "현재 장면" : "")
            }
            Spacer()
            Text("한 번에 한 장면")
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
        }
    }

    // MARK: - 진행 로직 (모션 수업과 같은 게이트)

    private func selectChoice(_ index: Int, check: CurriculumMotionCheck) {
        player.pauseForInterruption()
        if index == check.answerIndex {
            explanationMode = "correct"
            explanation = "\(check.correctFeedback) \(sceneIndex < story.scenes.count - 1 ? "다음 장면으로 이어집니다." : "아래 연습 문제로 이어집니다.")"
            scheduleAdvance()
        } else {
            misses += 1
            explanationMode = "retry"
            explanation = check.retryFeedback
            if misses >= 2 { explain(currentMotion, mode: "mild") }
        }
    }

    private func explain(_ motion: CurriculumMotionDirective?, mode: String) {
        guard let motion else { return }
        player.pauseForInterruption()
        explanationMode = misses >= 2 ? "mild" : mode
        explanation = explanationMode == "mild"
            ? motion.mild.explanation
            : "핵심 대상은 \(motion.focus)입니다. \(motion.spicy.explanation)"
    }

    private func selectScene(_ index: Int, pauseNarration: Bool = true) {
        advanceTask?.cancel()
        sceneIndex = min(max(0, index), max(0, story.scenes.count - 1))
        beatIndex = 0
        misses = 0
        explanation = nil
        explanationMode = "mild"
        if pauseNarration { player.pauseForInterruption() }
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        let delay = reduceMotion ? 350 : 900
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            if sceneIndex < story.scenes.count - 1 {
                selectScene(sceneIndex + 1)
            } else {
                explanationMode = "complete"
                explanation = "모션 설명을 마쳤습니다. 바로 아래 연습 문제에서 같은 관계를 사용해 보세요."
                onLessonCompleted()
            }
        }
    }

    private func kindColor(_ kind: CurriculumStorySceneKind) -> Color {
        switch kind {
        case .misconception: Tokens.warningInk
        case .recall: Tokens.successInk
        default: Tokens.progressBlue
        }
    }
}

/// 번들 lesson.html 을 열어 시나리오 플레이어만 남기는 WKWebView.
/// 개념 id 는 쿼리가 아니라 WKUserScript 로 주입한다 — file URL 의 쿼리는 환경에 따라
/// 벗겨질 수 있어 믿을 수 없다(LessonWebView 주석의 실증 그대로).
private struct CurriculumScenarioStageView: UIViewRepresentable {
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
            WKUserScript(
                source: Self.boardChromeScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true),
        ]
    }

    /// 설명 단계용 크롬 정리 — 페이지는 그대로 두고 CSS 한 장만 얹는다.
    ///  - `.sp-caption`: 시나리오 자체 자막. 나레이션 TTS 와 story 캡션이 이미 말을
    ///    담당하므로 끈다(감독 승인). 자막이 이중으로 나오면 안 된다.
    ///  - `#pg-section`·`#quiz-section`: 커리큘럼 conceptId 로는 레거시 registry(appId 키)에
    ///    걸리는 개념이 0개라 지금은 애초에 마운트되지 않는다. 데이터가 바뀌어도
    ///    설명 단계에 두 번째 확인 문제가 튀어나오지 않도록 잠가 둔다.
    ///  - `.sp-btn`·`.sp-progress`: 재생 컨트롤이 본 학습 동선에 올라오므로 44pt 타겟으로 키운다.
    ///  - 일시정지 글리프: 번들 Pretendard 에도 시스템 서체에도 U+23F8(⏸)이 없어 버튼이
    ///    두부(□?)로 나왔다(시뮬 실측). 이모지 폰트를 체인에 넣어도 U+23F8 은 VS16 없이는
    ///    텍스트 표현으로 잡혀 그대로 두부였다. 그래서 폰트에 의존하지 않고 CSS 로 막대
    ///    두 개를 그린다. 재생(▶)은 정상 렌더라 건드리지 않는다.
    ///    ※ 근본 수정은 scenario-player.js/brand.css 몫이라 탐색 단계에는 두부가 남아 있다.
    private static let boardChromeScript = """
    (function () {
      var PAUSE = '\\u23F8';
      var css = [
        '.sp-caption { display: none !important; }',
        '#pg-section, #quiz-section, #missing { display: none !important; }',
        '#scenario-section { background: transparent; box-shadow: none;',
        '  padding: 0; margin: 0; }',
        '#scenario-section > .lw-label { display: none; }',
        '.lw-wrap { padding: 0; }',
        '.sp-btn { min-height: 44px; min-width: 44px; }',
        '.sp-progress { height: 14px; }',
        '.sp-play.sp-pause-bars::before { content: ""; display: inline-block;',
        '  width: 4px; height: 15px; background: currentColor;',
        '  box-shadow: 7px 0 0 currentColor; transform: translateX(-3px);',
        '  vertical-align: -2px; }'
      ].join('\\n');
      var applyStyle = function () {
        if (document.getElementById('matths-scenario-board-style')) return;
        var style = document.createElement('style');
        style.id = 'matths-scenario-board-style';
        style.textContent = css;
        (document.head || document.documentElement).appendChild(style);
      };
      var trackPauseGlyph = function () {
        var button = document.querySelector('.sp-play');
        if (!button) return;
        var sync = function () {
          var text = (button.textContent || '').trim();
          if (text === PAUSE) {
            // 플레이어는 textContent 를 읽지 않는다 — 비워도 재생 상태에 영향이 없다.
            button.textContent = '';
            button.classList.add('sp-pause-bars');
          } else if (text) {
            button.classList.remove('sp-pause-bars');
          }
        };
        new MutationObserver(sync).observe(button, {
          childList: true, characterData: true, subtree: true
        });
        sync();
      };
      applyStyle();
      document.addEventListener('DOMContentLoaded', function () {
        applyStyle();
        trackPauseGlyph();
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
            let clamped = max(240, min(CGFloat(h), 900))
            if abs(clamped - height) > 4 {
                DispatchQueue.main.async { self.height = clamped }
            }
        }
    }
}
