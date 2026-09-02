//  CurriculumMotionLessonView.swift
//  Matths
//
//  5개 목차를 한꺼번에 펼치지 않는다. 현재 장면 하나에서 포인터·강조판·도형을
//  함께 움직이고, 학생 응답에 따라 순한맛/매운맛 설명으로 갈라진다.

import Foundation
import SwiftUI

private enum CurriculumMotionVisualMode: String {
    case equation, blocks, graph, geometry, plot
}

private struct CurriculumMotionScene {
    let source: CurriculumStudentStoryScene
    let authored: Bool
    let focus: String
    let visualIdea: String
    let mode: CurriculumMotionVisualMode
    let beats: [CurriculumMotionBeat]
    let mild: String
    let spicy: String
    let checkPrompt: String
    let choices: [String]
    let answerIndex: Int
    let correctFeedback: String
    let retryFeedback: String
}

private enum CurriculumMotionProjector {
    static func build(
        story: CurriculumStudentStory,
        visualizationIdeas: [String]
    ) -> [CurriculumMotionScene] {
        _ = visualizationIdeas
        let subtitles = story.scenes.map(\.subtitle)
        return story.scenes.enumerated().map { index, scene in
            if let motion = scene.motion,
               let mode = CurriculumMotionVisualMode(rawValue: motion.mode) {
                return CurriculumMotionScene(
                    source: scene,
                    authored: true,
                    focus: motion.focus,
                    visualIdea: motion.instruction,
                    mode: mode,
                    beats: motion.beats,
                    mild: motion.mild.explanation,
                    spicy: "핵심 대상은 \(motion.focus)입니다. \(motion.spicy.explanation)",
                    checkPrompt: motion.check.prompt,
                    choices: motion.check.choices,
                    answerIndex: motion.check.answerIndex,
                    correctFeedback: motion.check.correctFeedback,
                    retryFeedback: motion.check.retryFeedback
                )
            }
            let focus = focusToken(scene)
            let idea = guidedVisualIdea(scene: scene, focus: focus)
            let distractors = subtitles.filter { $0 != scene.subtitle }
            let base = [scene.subtitle] + Array(distractors.prefix(2))
            let offset = index % max(1, base.count)
            let choices = Array(base[offset...]) + Array(base[..<offset])
            let beats = guidedMotionBeats(
                scene: scene,
                focus: focus,
                visualIdea: idea
            )
            return CurriculumMotionScene(
                source: scene,
                authored: false,
                focus: focus,
                visualIdea: idea,
                mode: visualMode("\(idea) \(scene.title) \(scene.subtitle)"),
                beats: beats,
                mild: "\(scene.subtitle) 화면에서는 \(quoteWithParticle(focus, withBatchim: "을", withoutBatchim: "를")) 먼저 찾고, 관련 요소를 한 단계씩 연결해요.",
                spicy: "핵심은 \(focus)입니다. \(scene.subtitle)",
                checkPrompt: "지금 장면에서 가장 먼저 확인할 것은 무엇인가요?",
                choices: choices,
                answerIndex: choices.firstIndex(of: scene.subtitle) ?? 0,
                correctFeedback: "‘\(focus)’부터 보세요. \(scene.subtitle)",
                retryFeedback: "지금 가리키는 대상은 ‘\(focus)’입니다. 이 장면의 관계를 다시 확인해요."
            )
        }
    }

    private static func guidedMotionBeats(
        scene: CurriculumStudentStoryScene,
        focus: String,
        visualIdea: String
    ) -> [CurriculumMotionBeat] {
        let sentences = scene.narration
            .split(whereSeparator: { ".!?。！？…".contains($0) })
            .map { compact(String($0), maximum: 62) }
            .filter { !$0.isEmpty }
        let first = sentences.first ?? compact(scene.subtitle, maximum: 62)
        let middle = sentences.dropFirst().first ?? compact(scene.subtitle, maximum: 62)
        let conclusion = sentences.last ?? compact(scene.subtitle, maximum: 68)
        let target = compact(scene.subtitle, maximum: 48)

        return [
            CurriculumMotionBeat(
                id: "guided-focus",
                action: "highlight",
                target: focus,
                expression: compact(scene.title, maximum: 44),
                result: target,
                caption: "먼저 ‘\(focus)’부터 가리키고, 무엇을 판단할지 한 문장으로 고정합니다.",
                durationMs: 1_800
            ),
            CurriculumMotionBeat(
                id: "guided-connect",
                action: "transform",
                target: target,
                expression: first,
                result: middle,
                caption: "\(visualIdea). 앞 조건과 다음 변화를 선으로 연결해 보세요.",
                durationMs: 2_000
            ),
            CurriculumMotionBeat(
                id: "guided-verify",
                action: "verify",
                target: target,
                expression: focus,
                result: conclusion,
                caption: "마지막으로 ‘\(target)’에 필요한 조건과 결론을 함께 확인합니다.",
                durationMs: 2_200
            ),
        ]
    }

    private static func compact(_ value: String, maximum: Int) -> String {
        let normalized = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard normalized.count > maximum else { return normalized }
        return String(normalized.prefix(maximum - 1)) + "…"
    }

    private static func koreanParticle(
        _ value: String,
        withBatchim: String,
        withoutBatchim: String
    ) -> String {
        guard let scalar = value.unicodeScalars.reversed().first(where: {
            (0xAC00...0xD7A3).contains(Int($0.value))
        }) else { return withoutBatchim }
        return (Int(scalar.value) - 0xAC00) % 28 == 0 ? withoutBatchim : withBatchim
    }

    private static func quoteWithParticle(
        _ value: String,
        withBatchim: String,
        withoutBatchim: String
    ) -> String {
        "‘\(value)’\(koreanParticle(value, withBatchim: withBatchim, withoutBatchim: withoutBatchim))"
    }

    private static func guidedVisualIdea(
        scene: CurriculumStudentStoryScene,
        focus: String
    ) -> String {
        switch visualMode("\(scene.title) \(scene.subtitle) \(focus)") {
        case .graph:
            return "\(quoteWithParticle(focus, withBatchim: "이", withoutBatchim: "가")) 바뀔 때 좌표·기준선·곡선이 함께 움직이는 과정을 추적"
        case .geometry:
            return "\(quoteWithParticle(focus, withBatchim: "과", withoutBatchim: "와")) 연결된 점·선·거리 관계를 한 단계씩 표시"
        case .plot:
            return "‘\(focus)’의 값 변화를 축·분포·비교표에서 순서대로 표시"
        case .blocks:
            return "\(quoteWithParticle(focus, withBatchim: "을", withoutBatchim: "를")) 같은 크기의 블록으로 나누고 다시 조립"
        case .equation:
            return "\(quoteWithParticle(focus, withBatchim: "이", withoutBatchim: "가")) 식의 어느 항에서 다음 결론으로 이어지는지 밑줄과 화살표로 표시"
        }
    }

    private static func focusToken(_ scene: CurriculumStudentStoryScene) -> String {
        let source = "\(scene.title) \(scene.subtitle)" as NSString
        let pattern = #"(?:[A-Za-z][A-Za-z0-9²³ⁿ₀-₉]*|\d+(?:\.\d+)?)(?:\s*[=+−\-×÷·/<>]\s*[A-Za-z0-9()²³ⁿ₀-₉+−\-×÷·/]+){1,5}"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(
            in: source as String,
            range: NSRange(location: 0, length: source.length)
           ) {
            return String(source.substring(with: match.range).prefix(48))
        }
        if let keyword = keywordToken(scene.title) ?? keywordToken(scene.subtitle) {
            return keyword
        }
        return scene.title
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .map(stripParticle)
            .first(where: {
                $0.count >= 2
                    && !["어떻게", "무엇", "다시", "먼저", "모두", "같은"].contains($0)
            }) ?? "핵심 관계"
    }

    private static func keywordToken(_ value: String) -> String? {
        let pairs = [
            ("초점", "준선", "초점·준선"),
            ("정의역", "치역", "정의역·치역"),
            ("평균", "분산", "평균·분산"),
            ("속도", "가속도", "속도·가속도"),
            ("필요조건", "충분조건", "필요·충분조건"),
            ("비용", "수익", "비용·수익"),
        ]
        if let pair = pairs.first(where: { value.contains($0.0) && value.contains($0.1) }) {
            return pair.2
        }
        let keywords = [
            "조건부확률", "표준편차", "확률변수", "연립방정식", "부분적분", "치환적분",
            "삼각함수", "신뢰구간", "필요조건", "충분조건", "정규분포", "이항분포",
            "부정적분", "정적분", "도함수", "판별식", "상관관계", "인공지능",
            "포물선", "쌍곡선", "알고리즘", "표본공간", "표본", "모집단", "최적화",
            "수열", "극한", "공비", "부분합", "급수", "지수", "로그", "미분", "접선",
            "적분", "넓이", "부피", "속도", "가속도", "확률", "평균", "분산", "통계",
            "초점", "준선", "타원", "벡터", "행렬", "집합", "명제", "함수", "그래프",
            "순열", "조합", "방정식", "부등식", "데이터", "경제", "비용", "수익", "이윤",
            "가설", "회귀", "거리", "변화율", "극값", "점근선", "대칭", "좌표",
        ]
        return keywords.first(where: value.contains)
    }

    private static func stripParticle(_ value: String) -> String {
        let particles = [
            "에서는", "으로는", "이라는", "라는", "이면", "에서", "에게", "까지", "부터",
            "처럼", "보다", "으로", "로", "은", "는", "이", "가", "을", "를", "과", "와",
        ]
        guard let particle = particles.first(where: {
            value.hasSuffix($0) && value.count > $0.count + 1
        }) else { return value }
        return String(value.dropLast(particle.count))
    }

    private static func visualMode(_ source: String) -> CurriculumMotionVisualMode {
        if source.range(of: "그래프|좌표|곡선|함수|포물선|직선", options: .regularExpression) != nil {
            return .graph
        }
        if source.range(of: "블록|타일|넓이|직사각형|조각", options: .regularExpression) != nil {
            return .blocks
        }
        if source.range(of: "도형|원|벡터|점|각|공간|평면", options: .regularExpression) != nil {
            return .geometry
        }
        if source.range(of: "자료|분포|통계|확률|표|빈도|평균", options: .regularExpression) != nil {
            return .plot
        }
        return .equation
    }
}

struct CurriculumMotionLessonView: View {
    let story: CurriculumStudentStory
    let visualizationIdeas: [String]
    @ObservedObject var player: CurriculumNarrationPlayer
    let onLessonCompleted: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sceneIndex = 0
    @State private var beatIndex = 0
    @State private var misses = 0
    @State private var explanation: String?
    @State private var explanationMode = "mild"
    @State private var focusIsDrawn = false
    @State private var advanceTask: Task<Void, Never>?

    private var scenes: [CurriculumMotionScene] {
        CurriculumMotionProjector.build(
            story: story,
            visualizationIdeas: visualizationIdeas
        )
    }

    private var current: CurriculumMotionScene {
        scenes[min(sceneIndex, max(0, scenes.count - 1))]
    }

    private var currentBeat: CurriculumMotionBeat {
        current.beats[min(beatIndex, max(0, current.beats.count - 1))]
    }

    var body: some View {
        if !scenes.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                teacherBoard
                understandingBranch
                sceneDots
            }
            .onAppear { resetBeat() }
            .task(id: "\(sceneIndex)-\(beatIndex)-\(reduceMotion)") {
                guard !reduceMotion, beatIndex < current.beats.count - 1 else { return }
                try? await Task.sleep(for: .milliseconds(currentBeat.durationMs))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.42)) { beatIndex += 1 }
                animateFocus()
            }
            .onChange(of: player.currentSceneID) { _, sceneID in
                guard let sceneID,
                      let index = story.scenes.firstIndex(where: { $0.id == sceneID })
                else { return }
                selectScene(index, pauseNarration: false)
            }
            .onDisappear { advanceTask?.cancel() }
            .accessibilityIdentifier("curriculum-motion-lesson")
        }
    }

    private var teacherBoard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            HStack {
                Text(current.source.kind.label)
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(kindColor(current.source.kind))
                Spacer()
                Text(
                    current.authored
                        ? "장면 \(sceneIndex + 1)/\(scenes.count) · 동작 \(beatIndex + 1)/\(current.beats.count)"
                        : "\(sceneIndex + 1) / \(scenes.count)"
                )
                    .font(.mNumeric)
                    .foregroundStyle(Tokens.text3)
            }

            ZStack(alignment: .topLeading) {
                CurriculumMotionCanvas(
                    sceneID: current.source.id,
                    mode: current.mode,
                    beat: currentBeat
                )

                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    // 시나리오 무대와 같이 재생 버튼을 두지 않는다.
                    // 해설 음성은 영상의 일부이지 별도로 조작하는 물건이 아니다.
                    Text("지금 볼 곳")
                        .font(.mMicro.weight(.bold))
                        .foregroundStyle(Tokens.text3)
                    Text(currentBeat.target)
                        .font(.system(.title, design: .rounded, weight: .black))
                        .foregroundStyle(Tokens.ink)
                        .padding(.horizontal, 6)
                        .background(alignment: .bottom) {
                            Rectangle()
                                .fill(Color(red: 1, green: 0.89, blue: 0.48))
                                .frame(height: 14)
                                .scaleEffect(
                                    x: focusIsDrawn ? 1 : 0,
                                    y: 1,
                                    anchor: .leading
                                )
                        }
                    // 소리가 안 날 때만 그 사실을 알린다. 시나리오 무대와 같은 규칙이다.
                    if let notice = player.silentNotice {
                        Label(notice, systemImage: "speaker.slash")
                            .font(.mMicro)
                            .foregroundStyle(Tokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("curriculum-narration-silent-notice")
                    }
                    Rectangle()
                        .fill(Tokens.progressBlue)
                        .frame(width: focusIsDrawn ? 220 : 0, height: 4)
                        .clipShape(Capsule())
                }
                .padding(Tokens.Space.s5)

                Image(systemName: "pencil.tip")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(Tokens.progressBlue)
                    .offset(
                        x: focusIsDrawn ? 238 : 20,
                        y: focusIsDrawn ? 96 : 68
                    )
                    .opacity(focusIsDrawn ? 0.78 : 0)

                Text(currentBeat.caption)
                    .font(.mCaption.weight(.semibold))
                    .foregroundStyle(Tokens.text2)
                    .padding(Tokens.Space.s3)
                    .background(Tokens.surface.opacity(0.94))
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Tokens.progressBlue).frame(width: 3)
                    }
                    .frame(maxWidth: 430, alignment: .leading)
                    .padding(Tokens.Space.s4)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomTrailing
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 340)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.lineStrong, lineWidth: 1)
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "지금 볼 곳, \(currentBeat.target). \(currentBeat.caption)"
            )

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(current.source.title)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.ink)
                Text(current.source.subtitle)
                    .font(.mCallout)
                    .foregroundStyle(Tokens.text2)
                    .lineSpacing(4)
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.5),
            value: focusIsDrawn
        )
        .accessibilityIdentifier("curriculum-motion-teacher-board")
    }

    private var understandingBranch: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            checkCard

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("답이 막히면 설명 방식을 바꿔보세요.")
                    .font(.mCallout.weight(.semibold))
                    .foregroundStyle(Tokens.text2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s2) { branchButtons }
                    VStack(spacing: Tokens.Space.s2) { branchButtons }
                }
            }

            if let explanation {
                Text("\(explanationMode == "mild" ? "순한맛" : explanationMode == "spicy" ? "매운맛" : "확인") · \(explanation)")
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
                    .accessibilityIdentifier("curriculum-motion-reexplanation")
            }

        }
        .padding(.top, Tokens.Space.s4)
        .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
    }

    @ViewBuilder
    private var branchButtons: some View {
        Button("순한맛으로 다시") { explain(mode: "mild") }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: .infinity, minHeight: 48)

        Button("매운맛 핵심") { explain(mode: "spicy") }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: .infinity, minHeight: 48)
    }

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(current.checkPrompt)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)

            ForEach(Array(current.choices.enumerated()), id: \.offset) { index, choice in
                Button(choice) { selectChoice(index) }
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
        .accessibilityIdentifier("curriculum-motion-check")
    }

    private var sceneDots: some View {
        HStack(spacing: Tokens.Space.s2) {
            ForEach(scenes.indices, id: \.self) { index in
                Button { selectScene(index) } label: {
                    Capsule()
                        .fill(index == sceneIndex ? Tokens.progressBlue : Tokens.lineStrong)
                        .frame(width: index == sceneIndex ? 24 : 9, height: 9)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(index + 1)번째 장면, \(scenes[index].source.title)")
                .accessibilityValue(index == sceneIndex ? "현재 장면" : "")
            }
            Spacer()
            Text("한 번에 한 장면")
                .font(.mMicro)
                .foregroundStyle(Tokens.text3)
        }
    }

    private func selectChoice(_ index: Int) {
        player.pauseForInterruption()
        if index == current.answerIndex {
            explanationMode = "correct"
            explanation = "\(current.correctFeedback) \(sceneIndex < scenes.count - 1 ? "다음 장면으로 이어집니다." : "아래 연습 문제로 이어집니다.")"
            scheduleAdvance()
        } else {
            misses += 1
            explanationMode = "retry"
            explanation = current.retryFeedback
            if misses >= 2 { explain(mode: "mild") }
        }
    }

    private func explain(mode: String) {
        player.pauseForInterruption()
        explanationMode = misses >= 2 ? "mild" : mode
        explanation = explanationMode == "mild" ? current.mild : current.spicy
        animateFocus()
    }

    private func selectScene(_ index: Int, pauseNarration: Bool = true) {
        advanceTask?.cancel()
        sceneIndex = min(max(0, index), scenes.count - 1)
        misses = 0
        explanation = nil
        explanationMode = "mild"
        if pauseNarration { player.pauseForInterruption() }
        resetBeat()
    }

    private func scheduleAdvance() {
        advanceTask?.cancel()
        let delay = reduceMotion ? 350 : 900
        advanceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            if sceneIndex < scenes.count - 1 {
                selectScene(sceneIndex + 1)
            } else {
                explanationMode = "complete"
                explanation = "모션 설명을 마쳤습니다. 바로 아래 연습 문제에서 같은 관계를 사용해 보세요."
                onLessonCompleted()
            }
        }
    }

    private func resetBeat() {
        beatIndex = reduceMotion ? max(0, current.beats.count - 1) : 0
        animateFocus()
    }

    private func animateFocus() {
        focusIsDrawn = false
        if reduceMotion {
            focusIsDrawn = true
        } else {
            withAnimation(.easeOut(duration: 0.5)) { focusIsDrawn = true }
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

private struct CurriculumMotionCanvas: View {
    let sceneID: String
    let mode: CurriculumMotionVisualMode
    let beat: CurriculumMotionBeat

    var body: some View {
        Canvas { context, size in
            drawGrid(context: &context, size: size)
            if vocationalMathSceneIDs.contains(sceneID) {
                drawVocationalMathScene(context: &context, size: size, beat: beat)
            } else if mathResearchSceneIDs.contains(sceneID) {
                drawMathResearchScene(context: &context, size: size, beat: beat)
            } else if mathCultureSceneIDs.contains(sceneID) {
                drawMathCultureScene(context: &context, size: size, beat: beat)
            } else if aiMathSceneIDs.contains(sceneID) {
                drawAiMathScene(context: &context, size: size, beat: beat)
            } else if economicsMathSceneIDs.contains(sceneID) {
                drawEconomicsMathScene(context: &context, size: size, beat: beat)
            } else if practicalStatisticsSceneIDs.contains(sceneID) {
                drawPracticalStatisticsScene(context: &context, size: size, beat: beat)
            } else if geometryCourseSceneIDs.contains(sceneID) {
                drawGeometryCourseScene(context: &context, size: size, beat: beat)
            } else {
                switch mode {
                case .equation: drawEquation(context: &context, size: size, beat: beat)
                case .blocks: drawBlocks(context: &context, size: size, beat: beat)
                case .graph: drawGraph(context: &context, size: size, beat: beat)
                case .geometry: drawGeometry(context: &context, size: size, beat: beat)
                case .plot: drawPlot(context: &context, size: size, beat: beat)
                }
            }
            drawBeatCopy(context: &context, size: size, beat: beat)
        }
        .accessibilityHidden(true)
    }

    private func drawBeatCopy(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        context.draw(
            Text(compact(beat.expression, maximum: 42))
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.ink),
            at: CGPoint(x: size.width - 28, y: 42),
            anchor: .trailing
        )
        guard let result = beat.result, !result.isEmpty else { return }
        context.draw(
            Text(compact(result, maximum: 42))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width - 28, y: size.height - 32),
            anchor: .trailing
        )
    }

    private func compact(_ value: String, maximum: Int) -> String {
        value.count > maximum ? "\(value.prefix(maximum - 1))…" : value
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        let color = Color(red: 0.93, green: 0.95, blue: 0.98)
        for x in stride(from: 0.0, through: size.width, by: 40) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        for y in stride(from: 0.0, through: size.height, by: 40) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
    }

    private func drawEquation(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let width = min(110, size.width / 6)
        for index in 0..<4 {
            let rect = CGRect(
                x: 42 + CGFloat(index) * (width + 28),
                y: size.height * 0.48 + CGFloat(index % 2) * 28,
                width: width,
                height: 62
            )
            let shape = Path(roundedRect: rect, cornerRadius: 10)
            context.fill(
                shape,
                with: .color(index == 1 ? Color.yellow.opacity(0.55) : Tokens.paper2)
            )
            context.stroke(
                shape,
                with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong),
                lineWidth: 2
            )
        }
        if beat.action == "highlight" || beat.action == "point" {
            context.stroke(
                Path(ellipseIn: CGRect(x: 150, y: size.height * 0.40, width: 150, height: 128)),
                with: .color(Tokens.warningInk),
                lineWidth: 4
            )
        }
    }

    private func drawBlocks(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        for index in 0..<5 {
            let rect = CGRect(
                x: 46 + CGFloat(index) * 86,
                y: size.height * 0.5 + CGFloat(index % 2) * 58,
                width: index == 4 ? 132 : 70,
                height: 52
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 9),
                with: .color(index < 2 ? Color.yellow.opacity(0.55) : Tokens.primarySoft)
            )
        }
        if beat.action == "group" || beat.action == "highlight" {
            context.stroke(
                Path(roundedRect: CGRect(x: 34, y: size.height * 0.43, width: 362, height: 176), cornerRadius: 18),
                with: .color(Tokens.warningInk),
                style: StrokeStyle(lineWidth: 4, dash: [10, 7])
            )
        }
    }

    private func drawGraph(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        var axes = Path()
        axes.move(to: CGPoint(x: 60, y: size.height - 55))
        axes.addLine(to: CGPoint(x: size.width - 35, y: size.height - 55))
        axes.move(to: CGPoint(x: 80, y: size.height - 30))
        axes.addLine(to: CGPoint(x: 80, y: 95))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)

        var curve = Path()
        curve.move(to: CGPoint(x: 90, y: size.height - 85))
        curve.addCurve(
            to: CGPoint(x: size.width - 45, y: 130),
            control1: CGPoint(x: size.width * 0.3, y: 100),
            control2: CGPoint(x: size.width * 0.63, y: size.height - 70)
        )
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        if beat.action == "point" || beat.action == "highlight" {
            context.stroke(
                Path(ellipseIn: CGRect(x: size.width * 0.44, y: size.height * 0.42, width: 54, height: 54)),
                with: .color(Tokens.warningInk),
                lineWidth: 4
            )
        }
    }

    private func drawGeometry(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let circle = CGRect(
            x: size.width * 0.32,
            y: size.height * 0.34,
            width: 150,
            height: 150
        )
        context.stroke(
            Path(ellipseIn: circle),
            with: .color(Tokens.progressBlue),
            lineWidth: 5
        )
        var line = Path()
        line.move(to: CGPoint(x: 60, y: size.height - 45))
        line.addLine(to: CGPoint(x: size.width - 50, y: 115))
        context.stroke(line, with: .color(Tokens.text3), lineWidth: 4)
        if beat.action == "verify" {
            context.stroke(
                Path(ellipseIn: CGRect(x: size.width * 0.39, y: size.height * 0.42, width: 64, height: 64)),
                with: .color(Tokens.warningInk),
                lineWidth: 4
            )
        }
    }

    private var coordinateGeometrySceneIDs: Set<String> {
        [
            "triangle-and-slider", "closer-side-question", "cross-weight-misread", "coordinate-route", "segment-recall",
            "road-directions", "two-lines-question", "axis-exception", "parameter-slope", "slope-recall",
            "shortest-rope", "distance-meter-question", "absolute-and-normalization", "parallel-gap", "perpendicular-recall",
            "compass-trace", "radius-from-point", "sign-and-square-trap", "complete-the-circle", "circle-recall",
            "fence-and-path", "moving-line-question", "compare-like-quantities", "position-decision", "radius-gate-recall",
            "transparent-sticker", "parabola-slide-question", "same-sign-error", "translate-equation", "translation-recall",
            "folding-paper", "coordinate-mirror-question", "axis-name-confusion", "reflect-circle", "mirror-recall",
        ]
    }

    private var geometryParabolaSceneIDs: Set<String> {
        ["equal-distance-trail", "square-emerges", "graph-shape-trap", "focus-two-example", "parabola-memory-hook"]
    }

    private var geometryEllipseSceneIDs: Set<String> {
        ["taut-string", "axes-and-focus", "ellipse-swap-trap", "ellipse-five-three", "ellipse-memory-route"]
    }

    private var geometryHyperbolaSceneIDs: Set<String> {
        ["two-branches-one-rule", "outside-focus", "difference-and-asymptote-trap", "three-four-five-hyperbola", "hyperbola-memory-frame"]
    }

    private var geometryTangentSceneIDs: Set<String> {
        ["sliding-line-boundary", "point-and-slope-question", "tangent-shortcuts-trap", "parabola-tangent-example", "tangent-memory-rhythm"]
    }

    private var geometrySpaceRelationSceneIDs: Set<String> {
        ["room-lines-and-walls", "classify-by-sharing", "perspective-is-not-proof", "cube-relation-check", "space-relation-memory"]
    }

    private var geometryThreePerpendicularSceneIDs: Set<String> {
        ["lamp-shadow-right-angle", "three-perpendicular-links", "one-perpendicular-is-not-enough", "roof-edge-example", "height-shadow-recall"]
    }

    private var geometryProjectionSceneIDs: Set<String> {
        ["vertical-light-shadow", "cosine-shrink", "wrong-angle-shadow", "ten-unit-rod", "projection-memory-test"]
    }

    private var geometrySpaceCoordinateSceneIDs: Set<String> {
        ["three-direction-move", "opposite-weights", "coordinate-distance-traps", "six-root-three-example", "coordinate-memory-rhythm"]
    }

    private var geometrySphereSceneIDs: Set<String> {
        ["fixed-radius-shell", "complete-three-squares", "sphere-versus-ball-trap", "sphere-general-example", "sphere-memory-shell"]
    }

    private var geometryVectorOperationSceneIDs: Set<String> {
        ["slide-the-arrow", "head-to-tail", "magnitude-addition-trap", "vector-operation-example", "vector-memory-arrow"]
    }

    private var geometryPositionVectorSceneIDs: Set<String> {
        ["origin-as-anchor", "destination-minus-start", "point-vector-confusion", "position-vector-example", "position-vector-memory"]
    }

    private var geometryDotProductSceneIDs: Set<String> {
        ["directional-shadow", "geometry-meets-components", "dot-product-is-scalar", "zero-dot-example", "dot-product-memory"]
    }

    private var geometryLineSceneIDs: Set<String> {
        ["bead-on-a-wire", "one-parameter-three-coordinates", "direction-normal-confusion", "line-through-two-points", "line-equation-memory"]
    }

    private var geometryPlaneSphereSceneIDs: Set<String> {
        ["normal-pins-the-plane", "linear-plane-quadratic-sphere", "normal-versus-in-plane", "plane-and-sphere-example", "plane-sphere-memory"]
    }

    private var geometryCourseSceneIDs: Set<String> {
        geometryParabolaSceneIDs
            .union(geometryEllipseSceneIDs)
            .union(geometryHyperbolaSceneIDs)
            .union(geometryTangentSceneIDs)
            .union(geometrySpaceRelationSceneIDs)
            .union(geometryThreePerpendicularSceneIDs)
            .union(geometryProjectionSceneIDs)
            .union(geometrySpaceCoordinateSceneIDs)
            .union(geometrySphereSceneIDs)
            .union(geometryVectorOperationSceneIDs)
            .union(geometryPositionVectorSceneIDs)
            .union(geometryDotProductSceneIDs)
            .union(geometryLineSceneIDs)
            .union(geometryPlaneSphereSceneIDs)
    }

    private var practicalVariationSceneIDs: Set<String> {
        ["bus-arrival-variation", "statistical-question-test", "single-case-certainty-trap", "route-choice-evidence", "variation-evidence-recall"]
    }

    private var practicalInquirySceneIDs: Set<String> {
        [
            "cafeteria-cycle-map", "operational-question-design", "method-first-trap", "waste-study-walkthrough", "cycle-diagnostic-recall",
            "decision-needs-evidence-chain", "decision-criterion-question", "popular-option-trap", "library-pilot-inquiry", "inquiry-decision-recall",
            "rewind-bike-route-study", "four-audit-gates", "desired-result-immunity-trap", "transparent-reanalysis-plan", "critical-reflection-recall",
        ]
    }

    private var practicalSamplingSceneIDs: Set<String> {
        ["city-soup-sample", "sampling-frame-choice", "bigger-biased-sample", "stratified-transit-plan", "population-sample-recall"]
    }

    private var practicalScaleSceneIDs: Set<String> {
        ["festival-data-labels", "four-scale-card-sort", "rating-average-trap", "festival-variable-dictionary", "scale-permission-recall"]
    }

    private var practicalCollectionSceneIDs: Set<String> {
        ["collection-lens-choice", "cause-or-description-question", "leading-memory-trap", "sleep-study-protocol", "collection-method-recall"]
    }

    private var practicalGraphSceneIDs: Set<String> {
        ["graph-as-camera-lens", "graph-selection-diagnosis", "cropped-axis-distortion", "commute-dashboard-solution", "honest-graph-recall"]
    }

    private var practicalCenterSpreadSceneIDs: Set<String> {
        ["same-mean-different-wait", "center-spread-pairing", "average-only-trap", "delivery-summary-comparison", "center-island-spread-sea"]
    }

    private var practicalNormalTSceneIDs: Set<String> {
        ["filling-bell-shape", "why-t-has-heavy-tails", "automatic-normality-trap", "distribution-tool-exploration", "normal-t-recall"]
    }

    private var practicalIntervalSceneIDs: Set<String> {
        [
            "interval-net-for-mean", "confidence-width-tradeoff", "fixed-interval-probability-trap", "sleep-mean-interval-calculation", "mean-estimation-recall",
            "proportion-as-moving-share", "success-failure-condition", "margin-covers-bias-trap", "helmet-interval-calculation", "proportion-estimation-recall",
        ]
    }

    private var practicalHypothesisSceneIDs: Set<String> {
        ["null-world-simulation", "hypotheses-and-alpha", "p-value-meaning-trap", "checkout-t-test-solution", "hypothesis-test-recall"]
    }

    private var practicalStatisticsSceneIDs: Set<String> {
        practicalVariationSceneIDs
            .union(practicalInquirySceneIDs)
            .union(practicalSamplingSceneIDs)
            .union(practicalScaleSceneIDs)
            .union(practicalCollectionSceneIDs)
            .union(practicalGraphSceneIDs)
            .union(practicalCenterSpreadSceneIDs)
            .union(practicalNormalTSceneIDs)
            .union(practicalIntervalSceneIDs)
            .union(practicalHypothesisSceneIDs)
    }

    private var economicsIndexSceneIDs: Set<String> {
        ["dashboard-with-a-base", "index-or-growth-question", "rising-but-slowing", "basket-index-worked", "four-label-recall"]
    }

    private var economicsExchangeSceneIDs: Set<String> {
        ["currency-price-tag", "trip-budget-question", "reverse-quote-trap", "import-price-worked", "unit-arrow-recall"]
    }

    private var economicsTaxSceneIDs: Set<String> {
        ["tax-base-lens", "included-vat-question", "marginal-rate-misread", "progressive-tax-worked", "three-box-tax-recall"]
    }

    private var economicsInterestSceneIDs: Set<String> {
        ["interest-family-tree", "future-to-present-question", "rate-period-mismatch", "compare-loans-worked", "timeline-interest-recall"]
    }

    private var economicsAnnuitySceneIDs: Set<String> {
        ["cashflow-beads", "first-payment-question", "total-payment-trap", "three-payment-worked", "bring-each-home-recall"]
    }

    private var economicsFunctionSceneIDs: Set<String> {
        ["economic-machine", "cost-rule-question", "association-is-not-rule", "food-truck-model", "input-output-recall"]
    }

    private var economicsMarketLineSceneIDs: Set<String> {
        [
            "two-market-lines", "read-demand-table", "axis-and-shift-confusion", "plot-two-curves", "price-slider-recall",
            "market-handshake", "solve-crossing-question", "fairness-and-coordinate-trap", "farmers-market-worked", "market-seesaw-recall",
            "move-the-whole-curve", "tax-wedge-question", "all-demand-rises-trap", "income-shift-worked", "cause-curve-equilibrium-recall",
        ]
    }

    private var economicsUtilitySceneIDs: Set<String> {
        ["satisfaction-altimeter", "utility-increment-question", "utility-score-trap", "quadratic-utility-worked", "height-slope-recall"]
    }

    private var economicsLinearProgramSceneIDs: Set<String> {
        ["overlapping-fences", "which-side-question", "boundary-is-not-optimum", "bakery-corners-worked", "fence-corners-recall"]
    }

    private var economicsMatrixSceneIDs: Set<String> {
        [
            "labeled-data-tray", "add-sales-question", "multiply-like-addition-trap", "store-revenue-worked", "labels-survive-recall",
            "undo-mixing-machine", "determinant-gate-question", "entry-reciprocal-trap", "two-bundles-worked", "undo-check-recall",
            "compress-and-recover", "ticket-system-question", "algebra-only-trap", "production-mix-worked", "encode-solve-interpret-recall",
        ]
    }

    private var economicsMarginalSceneIDs: Set<String> {
        [
            "marginal-speedometer", "marginal-cost-question", "average-versus-marginal", "revenue-derivative-worked", "total-to-margin-recall",
            "derivative-traffic-map", "u-cost-question", "zero-derivative-trap", "profit-shape-worked", "sign-road-recall",
        ]
    }

    private var economicsElasticitySceneIDs: Set<String> {
        ["percentage-shock-absorber", "elasticity-at-price-question", "slope-equals-elasticity-trap", "revenue-response-worked", "normalized-ruler-recall"]
    }

    private var economicsOptimumSceneIDs: Set<String> {
        ["profit-hill", "where-stop-question", "stationary-only-trap", "pricing-production-worked", "objective-domain-recall"]
    }

    private var economicsMathSceneIDs: Set<String> {
        economicsIndexSceneIDs
            .union(economicsExchangeSceneIDs)
            .union(economicsTaxSceneIDs)
            .union(economicsInterestSceneIDs)
            .union(economicsAnnuitySceneIDs)
            .union(economicsFunctionSceneIDs)
            .union(economicsMarketLineSceneIDs)
            .union(economicsUtilitySceneIDs)
            .union(economicsLinearProgramSceneIDs)
            .union(economicsMatrixSceneIDs)
            .union(economicsMarginalSceneIDs)
            .union(economicsElasticitySceneIDs)
            .union(economicsOptimumSceneIDs)
    }

    private var aiLearningSceneIDs: Set<String> {
        [
            "feedback-shapes-learning", "choose-learning-signal", "understanding-mirage", "perceptron-update-rhythm", "learning-contract-recall",
            "questions-become-numbers", "perceptron-xor-turn", "single-hero-myth", "spam-history-lens", "history-four-lenses",
            "city-bus-stream", "useful-data-question", "more-data-trap", "cafeteria-data-audit", "big-data-four-questions",
        ]
    }

    private var aiTextSceneIDs: Set<String> {
        [
            "sentence-to-coordinates", "set-or-count", "order-disappears", "three-message-vectors", "vocabulary-coordinate-recall",
            "common-word-fades", "two-scales-one-weight", "rare-does-not-mean-useful", "four-document-weight", "inside-outside-recall",
            "direction-over-length", "similarity-or-sentiment", "shared-word-trap", "review-comparison-rhythm", "representation-context-recall",
        ]
    }

    private var aiImageSceneIDs: Set<String> {
        [
            "pixel-tile-grid", "row-column-channel", "cell-is-not-object", "six-pixel-threshold", "grid-value-channel-recall",
            "editor-as-number-rule", "local-or-neighborhood", "overflow-and-operation-trap", "brightness-matrix-worked", "rule-range-result-recall",
            "nearest-labeled-picture", "distance-choice", "pixel-closeness-trap", "binary-image-distance", "represent-measure-check-recall",
        ]
    }

    private var aiPredictionSceneIDs: Set<String> {
        [
            "forecast-from-counts", "reference-group-choice", "probability-is-not-promise", "absence-risk-example", "count-divide-interpret-recall",
            "crowd-direction-line", "read-slope-intercept-domain", "perfect-line-myth", "temperature-demand-line", "direction-residual-range-recall",
            "scoreboard-for-errors", "why-square-errors", "training-loss-mirage", "constant-prediction-loss", "predict-measure-compare-recall",
            "dimmer-knob-descent", "slope-and-learning-rate", "biggest-step-trap", "quadratic-descent-steps", "slope-opposite-repeat-recall",
        ]
    }

    private var aiInquirySceneIDs: Set<String> {
        [
            "goal-changes-choice", "rational-for-whom", "highest-score-is-not-fair", "cooling-policy-scores", "goal-constraint-impact-recall",
            "question-before-tool", "measurable-fair-question", "accuracy-only-project-trap", "school-energy-project", "inquiry-card-recall",
        ]
    }

    private var aiMathSceneIDs: Set<String> {
        aiLearningSceneIDs
            .union(aiTextSceneIDs)
            .union(aiImageSceneIDs)
            .union(aiPredictionSceneIDs)
            .union(aiInquirySceneIDs)
    }

    private var cultureArtSceneIDs: Set<String> {
        [
            "monochord-ratio", "concert-a-question", "equal-hertz-trap", "build-a-chord", "music-ratio-recall",
            "window-perspective", "three-times-distance", "golden-ratio-myth", "tile-the-plane", "art-geometry-recall",
            "count-the-form", "five-beat-line", "meaning-by-counting", "refrain-map", "literature-pattern-recall",
            "film-as-numbers", "frame-and-crop", "resolution-speed-confusion", "edit-rhythm-study", "film-math-recall",
        ]
    }

    private var cultureLeisureSceneIDs: Set<String> {
        [
            "court-measurements", "parabola-vertex", "forty-five-degree-myth", "compare-shot-records", "sports-model-recall",
            "rules-as-tree", "coin-expectation", "gambler-fallacy", "leave-multiples-of-four", "game-math-recall",
            "binary-switches", "grayscale-storage", "binary-does-not-compress", "parity-check", "digital-math-recall",
            "ballots-to-method", "three-way-profile", "method-neutrality-myth", "choose-a-voting-rule", "voting-recall",
        ]
    }

    private var cultureSocietySceneIDs: Set<String> {
        [
            "many-mathematical-languages", "base-twenty-conversion", "primitive-number-system", "symmetry-field-study", "culture-math-recall",
            "six-dot-cell", "encode-dot-pattern", "sixty-four-letters", "accessible-label-design", "braille-recall",
            "define-media-sample", "headline-percentage", "frequency-means-opinion", "compare-comment-distributions", "media-data-recall",
            "values-into-criteria", "weighted-shoe-score", "objective-weight-myth", "weight-sensitivity", "value-choice-recall",
        ]
    }

    private var cultureEnvironmentSceneIDs: Set<String> {
        [
            "common-food-unit", "waste-per-student", "total-versus-rate", "cafeteria-improvement", "food-analysis-recall",
            "air-time-series", "three-day-moving-average", "one-day-cause", "clean-air-action-study", "air-data-recall",
            "change-as-model", "five-year-growth", "forever-extrapolation", "intervention-scenario", "desertification-recall",
            "richness-and-evenness", "simpson-comparison", "index-is-whole-ecosystem", "habitat-monitoring-plan", "biodiversity-recall",
        ]
    }

    private var mathCultureSceneIDs: Set<String> {
        cultureArtSceneIDs
            .union(cultureLeisureSceneIDs)
            .union(cultureSocietySceneIDs)
            .union(cultureEnvironmentSceneIDs)
    }

    private var researchFoundationSceneIDs: Set<String> {
        [
            "fountain-question-lens", "claim-to-inquiry-test", "answer-hunt-misconception", "fountain-mini-inquiry", "inquiry-bridge-recall",
            "trust-chain-intuition", "ethical-decision-question", "clean-data-misconception", "ethical-crosswalk-protocol", "ethics-trace-recall",
        ]
    }

    private var researchMethodSceneIDs: Set<String> {
        [
            "literature-map-intuition", "source-trace-question", "search-summary-misconception", "paper-ratio-literature-synthesis", "literature-chain-recall",
            "case-window-intuition", "case-selection-question", "anecdote-generalization-misconception", "cross-case-signal-matrix", "case-context-recall",
            "random-pattern-intuition", "experiment-variable-question", "desired-value-misconception", "buffon-trial-solution", "experiment-loop-recall",
            "artifact-cycle-intuition", "requirements-question", "first-prototype-misconception", "puzzle-generator-iteration", "development-evidence-recall",
        ]
    }

    private var researchExecutionSceneIDs: Set<String> {
        [
            "topic-funnel-intuition", "topic-matrix-question", "grand-topic-misconception", "daylight-project-plan", "plan-contract-recall",
            "execution-log-intuition", "checkpoint-question", "protocol-obedience-misconception", "battery-study-execution", "execution-trail-recall",
            "evidence-story-intuition", "audience-claim-question", "polished-slide-misconception", "shade-route-presentation", "presentation-trace-recall",
            "reflection-mirror-intuition", "rubric-evidence-question", "successful-result-misconception", "bridge-project-reflection", "reflection-cycle-recall",
        ]
    }

    private var mathResearchSceneIDs: Set<String> {
        researchFoundationSceneIDs
            .union(researchMethodSceneIDs)
            .union(researchExecutionSceneIDs)
    }

    private var vocationalNumberSceneIDs: Set<String> {
        [
            "work-order-number-tags", "operation-verbs-question", "unit-and-order-trap", "purchase-balance-solution", "role-unit-recall",
            "number-resolution-dashboard", "rounding-purpose-question", "automatic-rounding-trap", "budget-rounding-solution", "direction-label-recall",
            "unit-label-change", "conversion-bridge-question", "decimal-clock-trap", "batch-mass-solution", "unchanged-quantity-recall",
        ]
    }

    private var vocationalRelationSceneIDs: Set<String> {
        [
            "recipe-shape-intuition", "corresponding-order-question", "ratio-total-trap", "catering-scale-solution", "same-scale-recall",
            "hundred-slot-scale", "baseline-question", "percent-point-trap", "discount-tax-solution", "hundred-percent-recall",
            "input-output-counter", "difference-ratio-question", "piecewise-rate-trap", "delivery-table-solution", "table-rule-recall",
            "production-monitor-intuition", "height-slope-question", "visual-steepness-trap", "cold-storage-solution", "graph-verbs-recall",
            "constraint-fence-intuition", "unknown-and-bound-question", "integer-and-sign-trap", "purchase-limit-solution", "target-zone-recall",
        ]
    }

    private var vocationalGeometrySceneIDs: Set<String> {
        [
            "box-two-languages", "hinge-edge-question", "opposite-face-trap", "carton-net-solution", "folding-preview-recall",
            "three-camera-intuition", "height-grid-question", "silhouette-uniqueness-trap", "pallet-stack-solution", "projection-crosscheck-recall",
            "template-transform-intuition", "corresponding-side-question", "area-scale-trap", "floorplan-scale-solution", "move-or-scale-recall",
            "boundary-surface-intuition", "decompose-shape-question", "opening-and-unit-trap", "flooring-order-solution", "line-or-surface-recall",
            "skin-and-space-intuition", "base-layer-question", "capacity-dimension-trap", "shipping-carton-solution", "skin-space-recall",
        ]
    }

    private var vocationalDataSceneIDs: Set<String> {
        [
            "choice-tree-intuition", "and-or-question", "restriction-double-count-trap", "uniform-order-solution", "path-count-recall",
            "frequency-gauge-intuition", "relevant-denominator-question", "certainty-small-sample-trap", "line-risk-solution", "chance-with-context-recall",
            "data-workbench-intuition", "chart-purpose-question", "dirty-category-trap", "weekly-sales-solution", "purpose-chart-recall",
            "chart-reading-order-intuition", "signal-question", "truncated-axis-causation-trap", "service-dashboard-solution", "evidence-reading-recall",
            "decision-compass-intuition", "criterion-measure-question", "single-metric-bias-trap", "supplier-choice-solution", "evidence-decision-recall",
        ]
    }

    private var vocationalMathSceneIDs: Set<String> {
        vocationalNumberSceneIDs
            .union(vocationalRelationSceneIDs)
            .union(vocationalGeometrySceneIDs)
            .union(vocationalDataSceneIDs)
    }

    private var setsPropositionsSceneIDs: Set<String> {
        [
            "objective-guest-list", "membership-question", "braces-do-not-decide", "representation-check", "set-recall",
            "nested-boxes", "divisor-box-question", "element-versus-subset", "two-way-equality", "inclusion-recall",
            "overlapping-spotlights", "numbers-under-ten", "demorgan-switch", "shade-from-outside", "logic-lights-recall",
            "truth-switchboard", "all-or-some-question", "quantifier-negation", "truth-set-solution", "verdict-recall",
            "one-way-arrow", "multiple-of-four", "converse-is-not-equivalent", "label-and-turn", "arrow-recall",
            "gate-and-requirement", "square-rectangle-question", "language-reversal", "interval-condition", "tail-head-recall",
            "two-detours", "even-square-question", "fake-contradiction", "irrational-root-two", "proof-route-recall",
            "square-floor", "two-numbers-question", "unsafe-divi" + "sion", "difference-to-square", "inequality-recall",
        ]
    }

    private var functionsGraphsSceneIDs: Set<String> {
        [
            "vending-buttons", "mapping-question", "horizontal-test-error", "graph-from-rule", "function-recall",
            "assembly-line", "order-question", "missing-parentheses", "numeric-pipeline", "composition-recall",
            "undo-button", "linear-undo-question", "negative-one-is-not-reciprocal", "solve-swap-check", "inverse-recall",
            "forbidden-wall-horizon", "divide-to-see-question", "asymptote-is-not-graph", "rational-sketch", "rational-recall",
            "trailhead-boundary", "direction-question", "start-sign-error", "perfect-square-points", "radical-recall",
        ]
    }

    private var algebraPowerExponentSceneIDs: Set<String> {
        [
            "power-machine-and-rewind", "root-count-by-parity", "principal-root-trap", "root-calculation-route", "rewind-question-recall",
            "exponent-number-line-zoom", "fractional-exponent-meaning", "negative-base-extension-trap", "fractional-exponent-conversion", "dense-exponent-line-recall",
            "factor-ledger", "operation-diagnosis", "sum-power-trap", "exponent-law-layered-solution", "ledger-verbs-recall",
        ]
    }

    private var algebraLogFunctionSceneIDs: Set<String> {
        [
            "exponent-question-language", "log-domain-gates", "log-sum-trap", "log-expression-solution", "log-three-roles-recall",
            "powers-of-ten-elevator", "digit-count-question", "scale-difference-trap", "common-log-application-route", "magnitude-floor-recall",
            "forward-and-reverse-machines", "fixed-base-variable-place", "domain-range-swap-trap", "inverse-composition-solution", "two-machines-recall",
            "graph-mirror-and-anchors", "base-direction-switch", "asymptote-not-intercept", "graph-reconstruction-route", "graph-fingerprint-recall",
            "multiplicative-clock", "inverse-time-question", "model-and-domain-trap", "growth-model-solution", "exponential-model-recall",
        ]
    }

    private var algebraTrigonometrySceneIDs: Set<String> {
        [
            "arc-as-angle-ruler", "directed-turn-counter", "degree-radian-mixup", "sector-measure-solution", "radius-ruler-recall",
            "rotating-beacon-shadows", "wave-landmarks-question", "tangent-gap-trap", "transformed-wave-solution", "circle-wave-recall",
            "triangulation-measurement", "law-selection-question", "opposite-pair-trap", "triangulation-solution-route", "triangle-tool-recall",
        ]
    }

    private var algebraSequenceSceneIDs: Set<String> {
        [
            "numbered-lockers", "term-rule-question", "index-value-confusion", "general-term-and-sum-solution", "address-map-recall",
            "constant-step-staircase", "n-minus-one-steps", "difference-ratio-and-offbyone", "paired-arithmetic-sum", "equal-stride-recall",
            "constant-zoom-lens", "n-minus-one-multiplications", "geometric-middle-sign-trap", "shifted-geometric-sum", "constant-scale-recall",
            "summation-conveyor", "inclusive-count-question", "false-product-linearity", "sigma-polynomial-solution", "summation-command-recall",
            "telescoping-zipper", "method-shape-question", "vanishing-endpoint-trap", "telescoping-sum-solution", "cancellation-fingerprint-recall",
            "starter-and-recipe", "required-history-question", "missing-initial-condition", "recursive-table-solution", "recipe-chain-recall",
            "domino-chain-proof", "why-assume-pk", "missing-base-or-link", "odd-sum-induction-solution", "induction-chain-recall",
        ]
    }

    private var probabilityCountingSceneIDs: Set<String> {
        [
            "repeat-or-identical-objects", "counting-question-fork", "blind-divi" + "sion-trap", "aabbc-arrangement", "repeat-arrangement-recall",
            "cookie-stars-bars", "h-combination-question", "positive-share-trap", "flavor-scoop-solution", "stars-bars-recall",
            "term-choice-expansion", "general-term-question", "coefficient-sign-trap", "target-coefficient-solution", "binomial-recall",
        ]
    }

    private var probabilitySetSceneIDs: Set<String> {
        [
            "possibility-map", "equally-likely-question", "unequal-outcome-trap", "two-coin-solution", "probability-map-recall",
            "club-overlap", "or-means-union", "mutually-exclusive-shortcut-trap", "survey-union-solution", "addition-rule-recall",
            "opposite-door", "name-the-complement", "exactly-one-confusion", "even-at-least-once", "complement-recall",
        ]
    }

    private var probabilityConditionalSceneIDs: Set<String> {
        [
            "fence-the-room", "read-the-bar", "cause-and-order", "table-rhythm", "denominator-recall",
            "news-that-changes-odds", "independence-tests", "disjoint-independent-confusion", "replacement-comparison", "independence-recall",
            "shrinking-tree-path", "which-condition-after-a", "marginal-product-trap", "different-colors-tree", "multiply-paths-recall",
        ]
    }

    private var probabilityDistributionSceneIDs: Set<String> {
        [
            "heads-count-label", "distribution-validity-question", "outcome-variable-confusion", "die-payoff-distribution", "random-variable-recall",
            "weighted-balance-point", "distance-from-mean-question", "expected-value-certainty-trap", "same-mean-different-spread", "center-spread-recall",
            "free-throw-count", "binomial-four-conditions", "changing-p-trap", "free-throw-binomial-solution", "binomial-count-recall",
        ]
    }

    private var probabilityNormalSceneIDs: Set<String> {
        [
            "bell-curve-balance", "binomial-to-normal-question", "continuity-gap-trap", "central-binomial-approximation", "normal-binomial-recall",
        ]
    }

    private var probabilityInferenceSceneIDs: Set<String> {
        [
            "soup-taste-sample", "sampling-design-question", "large-convenience-sample", "stratified-school-sample", "sampling-recall",
            "many-sample-means", "sampling-center-spread", "sample-equals-population-trap", "mean-proportion-sampling", "statistic-parameter-recall",
            "flashlight-interval", "confidence-meaning-question", "confidence-certainty-trap", "tool-based-two-intervals", "estimation-recall",
        ]
    }

    private var probabilityStatisticsSceneIDs: Set<String> {
        probabilityCountingSceneIDs
            .union(probabilitySetSceneIDs)
            .union(probabilityConditionalSceneIDs)
            .union(probabilityDistributionSceneIDs)
            .union(probabilityNormalSceneIDs)
            .union(probabilityInferenceSceneIDs)
    }

    private var calculusLimitApproachSceneIDs: Set<String> {
        [
            "walk-toward-a", "both-sides", "substitution-trap", "hole-example", "three-questions-recall",
            "limit-building-blocks", "limit-law-check", "zero-denominator-warning", "factor-limit-example", "assemble-the-limit",
        ]
    }

    private var calculusContinuitySceneIDs: Set<String> {
        [
            "continuity-pencil-path", "three-continuity-tests", "defined-is-not-continuous", "piecewise-continuity-fit", "continuity-gate-memory",
            "continuous-mountain-trail", "root-between-endpoints", "sign-change-needs-continuity", "closed-interval-extrema", "continuity-guarantees",
        ]
    }

    private var calculusDerivativeDefinitionSceneIDs: Set<String> {
        [
            "secant-becomes-tangent", "square-at-two", "zero-increment-trap", "coefficient-from-definition", "derivative-coefficient-memory",
            "road-with-a-corner", "continuity-or-differentiability", "reverse-arrow-error", "piecewise-smooth-join", "one-way-smoothness",
        ]
    }

    private var calculusDerivativeRuleSceneIDs: Set<String> {
        [
            "power-growth-layers", "cube-definition-proof", "power-rule-half-remembered", "fifth-power-slope", "power-rule-memory",
            "polynomial-change-parts", "termwise-polynomial", "product-of-derivatives-error", "polynomial-product-example", "polynomial-derivative-map",
            "tangent-point-direction", "parabola-tangent-at-one", "tangent-through-origin-error", "cubic-tangent-example", "tangent-two-clues",
            "average-speed-moment", "parabola-mean-value", "mean-value-condition-gap", "derivative-bound-change", "mean-value-bridge",
        ]
    }

    private var calculusDerivativeGraphSceneIDs: Set<String> {
        [
            "slope-direction-arrows", "cubic-sign-chart", "stationary-not-extreme", "increase-decrease-example", "derivative-sign-memory",
            "graph-clue-map", "cubic-outline-clues", "dot-plot-graph-error", "draw-cubic-outline", "graph-outline-memory",
            "roots-as-crossings", "unique-root-by-growth", "derivative-root-confusion", "three-root-proof", "equation-inequality-graph",
            "motion-three-gauges", "motion-direction-times", "acceleration-direction-error", "motion-distance-example", "motion-derivative-chain",
        ]
    }

    private var calculusAntiderivativeSceneIDs: Set<String> {
        [
            "reverse-the-derivative", "antiderivative-family", "missing-integration-constant", "initial-value-selects-curve", "antiderivative-memory",
            "reverse-power-rule", "integrate-four-terms", "integration-power-slip", "polynomial-antiderivative-condition", "polynomial-integral-memory",
        ]
    }

    private var calculusAccumulationSceneIDs: Set<String> {
        [
            "signed-accumulation", "trapezoid-definite-integral", "integral-always-area-error", "split-signed-integral", "definite-integral-memory",
            "accumulation-endpoint-difference", "evaluate-linear-integral", "endpoint-order-error", "evaluate-polynomial-integral", "fundamental-link-memory",
        ]
    }

    private var calculusAreaMotionSceneIDs: Set<String> {
        [
            "vertical-area-strips", "line-parabola-unit-area", "area-formula-order-error", "parabola-line-area", "area-top-minus-bottom",
            "velocity-signed-area", "velocity-crosses-zero", "displacement-equals-distance-error", "round-trip-from-velocity", "velocity-integral-memory",
        ]
    }

    private var calculusOneSceneIDs: Set<String> {
        calculusLimitApproachSceneIDs
            .union(calculusContinuitySceneIDs)
            .union(calculusDerivativeDefinitionSceneIDs)
            .union(calculusDerivativeRuleSceneIDs)
            .union(calculusDerivativeGraphSceneIDs)
            .union(calculusAntiderivativeSceneIDs)
            .union(calculusAccumulationSceneIDs)
            .union(calculusAreaMotionSceneIDs)
    }

    private func drawCoordinateAxes(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.63)
        var axes = Path()
        axes.move(to: CGPoint(x: 38, y: center.y))
        axes.addLine(to: CGPoint(x: size.width - 34, y: center.y))
        axes.move(to: CGPoint(x: center.x, y: size.height - 28))
        axes.addLine(to: CGPoint(x: center.x, y: 64))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)
        context.draw(
            Text("x").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2),
            at: CGPoint(x: size.width - 48, y: center.y - 18)
        )
        context.draw(
            Text("y").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2),
            at: CGPoint(x: center.x + 22, y: 74)
        )
    }

    private func drawCoordinateSegment(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCoordinateAxes(context: &context, size: size)
        let a = CGPoint(x: size.width * 0.20, y: size.height * 0.68)
        let b = CGPoint(x: size.width * 0.78, y: size.height * 0.25)
        let nearB = sceneID == "coordinate-route"
        let p = CGPoint(
            x: nearB ? a.x + (b.x - a.x) * 0.67 : a.x + (b.x - a.x) * 0.33,
            y: nearB ? a.y + (b.y - a.y) * 0.67 : a.y + (b.y - a.y) * 0.33
        )
        var triangle = Path()
        triangle.move(to: a)
        triangle.addLine(to: CGPoint(x: b.x, y: a.y))
        triangle.addLine(to: b)
        triangle.closeSubpath()
        context.stroke(
            triangle,
            with: .color(Tokens.text3.opacity(0.65)),
            style: StrokeStyle(lineWidth: 3, dash: [8, 6])
        )
        var segment = Path()
        segment.move(to: a)
        segment.addLine(to: b)
        context.stroke(segment, with: .color(Tokens.progressBlue), lineWidth: 6)
        for (point, label, focused) in [(a, "A", false), (b, "B", false), (p, "P", true)] {
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)),
                with: .color(focused ? Color.yellow : Tokens.primarySoft)
            )
            context.draw(
                Text(label).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink),
                at: CGPoint(x: point.x + 22, y: point.y - 16)
            )
        }
        context.draw(
            Text(nearB ? "AP:PB=2:1" : "AP:PB=1:2")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height - 42)
        )
        if beat.action == "point" || beat.action == "highlight" || beat.action == "verify" {
            context.stroke(
                Path(ellipseIn: CGRect(x: p.x - 27, y: p.y - 27, width: 54, height: 54)),
                with: .color(Tokens.warningInk),
                lineWidth: 4
            )
        }
    }

    private func drawCoordinateSlopes(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCoordinateAxes(context: &context, size: size)
        if sceneID == "axis-exception" {
            var vertical = Path()
            vertical.move(to: CGPoint(x: size.width * 0.34, y: 70))
            vertical.addLine(to: CGPoint(x: size.width * 0.34, y: size.height - 36))
            context.stroke(vertical, with: .color(Tokens.progressBlue), lineWidth: 5)
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: 45, y: size.height * 0.42))
            horizontal.addLine(to: CGPoint(x: size.width - 38, y: size.height * 0.42))
            context.stroke(horizontal, with: .color(Tokens.warningInk), lineWidth: 5)
            return
        }
        var first = Path()
        first.move(to: CGPoint(x: 50, y: size.height - 48))
        first.addLine(to: CGPoint(x: size.width * 0.76, y: 78))
        context.stroke(first, with: .color(Tokens.progressBlue), lineWidth: 5)
        var parallel = Path()
        parallel.move(to: CGPoint(x: 48, y: size.height * 0.66))
        parallel.addLine(to: CGPoint(x: size.width * 0.74, y: 30))
        context.stroke(parallel, with: .color(Tokens.primarySoft), lineWidth: 4)
        var perpendicular = Path()
        perpendicular.move(to: CGPoint(x: size.width * 0.31, y: 64))
        perpendicular.addLine(to: CGPoint(x: size.width * 0.82, y: size.height - 44))
        context.stroke(perpendicular, with: .color(Tokens.warningInk), lineWidth: 5)
        context.draw(
            Text("m=3").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.75, y: 96)
        )
        context.draw(
            Text("m=−1/3").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.warningInk),
            at: CGPoint(x: size.width * 0.77, y: size.height - 68)
        )
    }

    private func drawCoordinateDistance(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCoordinateAxes(context: &context, size: size)
        let point = CGPoint(x: size.width * 0.31, y: size.height * 0.24)
        let foot = CGPoint(x: size.width * 0.43, y: size.height * 0.56)
        var line = Path()
        line.move(to: CGPoint(x: 44, y: size.height * 0.78))
        line.addLine(to: CGPoint(x: size.width - 42, y: size.height * 0.30))
        context.stroke(line, with: .color(Tokens.progressBlue), lineWidth: 5)
        if sceneID == "parallel-gap" {
            var parallel = line
            parallel = Path()
            parallel.move(to: CGPoint(x: 44, y: size.height * 0.60))
            parallel.addLine(to: CGPoint(x: size.width - 42, y: size.height * 0.12))
            context.stroke(parallel, with: .color(Tokens.primarySoft), lineWidth: 4)
        }
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)),
            with: .color(Color.yellow)
        )
        var perpendicular = Path()
        perpendicular.move(to: point)
        perpendicular.addLine(to: foot)
        context.stroke(perpendicular, with: .color(Tokens.warningInk), lineWidth: 5)
        context.draw(
            Text(sceneID == "distance-meter-question" ? "10 ÷ 5 = 2" : "d ⟂ 직선")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.warningInk),
            at: CGPoint(x: size.width * 0.60, y: size.height - 54)
        )
    }

    private func drawCoordinateCircle(
        context: inout GraphicsContext,
        size: CGSize,
        lineRelation: Bool,
        beat: CurriculumMotionBeat
    ) {
        drawCoordinateAxes(context: &context, size: size)
        let center = CGPoint(x: size.width * 0.50, y: size.height * 0.48)
        let radius = min(size.width * 0.19, size.height * 0.27)
        let circle = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.stroke(Path(ellipseIn: circle), with: .color(Tokens.progressBlue), lineWidth: 6)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)),
            with: .color(Color.yellow)
        )
        if lineRelation {
            let outside = beat.id.contains("outside")
                || beat.id.contains("no-intersection")
                || sceneID == "position-decision"
            let tangent = beat.id.contains("tangent")
                || beat.id.contains("boundary")
                || beat.id.contains("set-tangent")
            let offset = outside ? radius * 1.30 : tangent ? radius : radius * 0.55
            var line = Path()
            line.move(to: CGPoint(x: 42, y: center.y - offset + 56))
            line.addLine(to: CGPoint(x: size.width - 42, y: center.y - offset - 56))
            context.stroke(line, with: .color(Tokens.warningInk), lineWidth: 5)
            var normal = Path()
            normal.move(to: center)
            normal.addLine(to: CGPoint(x: center.x + 20, y: center.y - offset))
            context.stroke(normal, with: .color(Tokens.warningInk), lineWidth: 4)
            context.draw(
                Text(outside ? "d > r" : tangent ? "d = r" : "d < r")
                    .font(.mCallout.weight(.black))
                    .foregroundStyle(Tokens.warningInk),
                at: CGPoint(x: size.width * 0.77, y: size.height - 48)
            )
        } else {
            var radiusPath = Path()
            radiusPath.move(to: center)
            radiusPath.addLine(to: CGPoint(x: center.x + radius * 0.80, y: center.y - radius * 0.60))
            context.stroke(radiusPath, with: .color(Tokens.warningInk), lineWidth: 5)
            context.draw(
                Text(sceneID == "radius-from-point" ? "C(2,−1), r=5" : "(x−a)²+(y−b)²=r²")
                    .font(.mCallout.weight(.black))
                    .foregroundStyle(Tokens.progressBlue),
                at: CGPoint(x: size.width * 0.5, y: size.height - 44)
            )
        }
    }

    private func drawCoordinateTranslation(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCoordinateAxes(context: &context, size: size)
        if sceneID == "translate-equation" {
            let first = CGRect(x: size.width * 0.48, y: size.height * 0.48, width: 92, height: 92)
            let second = first.offsetBy(dx: -size.width * 0.22, dy: -size.height * 0.29)
            context.stroke(Path(ellipseIn: first), with: .color(Tokens.text3), lineWidth: 4)
            context.stroke(Path(ellipseIn: second), with: .color(Tokens.progressBlue), lineWidth: 5)
            var arrow = Path()
            arrow.move(to: CGPoint(x: first.midX, y: first.midY))
            arrow.addLine(to: CGPoint(x: second.midX, y: second.midY))
            context.stroke(arrow, with: .color(Tokens.warningInk), lineWidth: 4)
        } else {
            var original = Path()
            original.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.69))
            original.addQuadCurve(
                to: CGPoint(x: size.width * 0.44, y: size.height * 0.69),
                control: CGPoint(x: size.width * 0.28, y: size.height * 0.14)
            )
            context.stroke(original, with: .color(Tokens.text3), lineWidth: 4)
            var moved = Path()
            moved.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.79))
            moved.addQuadCurve(
                to: CGPoint(x: size.width * 0.82, y: size.height * 0.79),
                control: CGPoint(x: size.width * 0.66, y: size.height * 0.24)
            )
            context.stroke(moved, with: .color(Tokens.progressBlue), lineWidth: 6)
            var arrow = Path()
            arrow.move(to: CGPoint(x: size.width * 0.28, y: size.height * 0.69))
            arrow.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.79))
            context.stroke(arrow, with: .color(Tokens.warningInk), lineWidth: 4)
        }
        context.draw(
            Text(sceneID == "translate-equation" ? "+(−1,3)" : "+(3,−2)")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.warningInk),
            at: CGPoint(x: size.width * 0.5, y: size.height - 44)
        )
    }

    private func drawCoordinateReflection(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCoordinateAxes(context: &context, size: size)
        let diagonal = sceneID == "reflect-circle" || beat.id.contains("diagonal")
        if diagonal {
            var mirror = Path()
            mirror.move(to: CGPoint(x: size.width * 0.20, y: size.height - 36))
            mirror.addLine(to: CGPoint(x: size.width * 0.80, y: 62))
            context.stroke(
                mirror,
                with: .color(Tokens.text3),
                style: StrokeStyle(lineWidth: 3, dash: [8, 6])
            )
        }
        if sceneID == "reflect-circle" {
            let original = CGRect(x: size.width * 0.63, y: size.height * 0.52, width: 82, height: 82)
            let reflected = CGRect(x: size.width * 0.29, y: size.height * 0.18, width: 82, height: 82)
            context.stroke(Path(ellipseIn: original), with: .color(Tokens.text3), lineWidth: 4)
            context.stroke(Path(ellipseIn: reflected), with: .color(Tokens.progressBlue), lineWidth: 5)
            context.draw(
                Text("C(2,−1) → C′(−1,2)")
                    .font(.mCallout.weight(.black))
                    .foregroundStyle(Tokens.progressBlue),
                at: CGPoint(x: size.width * 0.5, y: size.height - 42)
            )
            return
        }
        let p = CGPoint(x: size.width * 0.70, y: size.height * 0.52)
        var reflected = CGPoint(x: size.width * 0.70, y: size.height * 0.78)
        if beat.id.contains("y-axis") { reflected = CGPoint(x: size.width * 0.30, y: p.y) }
        if beat.id.contains("origin") { reflected = CGPoint(x: size.width * 0.30, y: size.height * 0.78) }
        if diagonal { reflected = CGPoint(x: size.width * 0.35, y: size.height * 0.22) }
        var link = Path()
        link.move(to: p)
        link.addLine(to: reflected)
        context.stroke(
            link,
            with: .color(Tokens.text3.opacity(0.7)),
            style: StrokeStyle(lineWidth: 3, dash: [7, 5])
        )
        context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(Tokens.primarySoft))
        context.fill(Path(ellipseIn: CGRect(x: reflected.x - 10, y: reflected.y - 10, width: 20, height: 20)), with: .color(Color.yellow))
        context.draw(Text("P").font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: p.x + 22, y: p.y - 14))
        context.draw(Text("P′").font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: reflected.x + 24, y: reflected.y - 14))
    }

    private func drawCoordinateGeometryScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let segmentScenes: Set<String> = ["triangle-and-slider", "closer-side-question", "cross-weight-misread", "coordinate-route", "segment-recall"]
        let slopeScenes: Set<String> = ["road-directions", "two-lines-question", "axis-exception", "parameter-slope", "slope-recall"]
        let distanceScenes: Set<String> = ["shortest-rope", "distance-meter-question", "absolute-and-normalization", "parallel-gap", "perpendicular-recall"]
        let circleScenes: Set<String> = ["compass-trace", "radius-from-point", "sign-and-square-trap", "complete-the-circle", "circle-recall"]
        let relationScenes: Set<String> = ["fence-and-path", "moving-line-question", "compare-like-quantities", "position-decision", "radius-gate-recall"]
        let translationScenes: Set<String> = ["transparent-sticker", "parabola-slide-question", "same-sign-error", "translate-equation", "translation-recall"]
        if segmentScenes.contains(sceneID) {
            drawCoordinateSegment(context: &context, size: size, beat: beat)
        } else if slopeScenes.contains(sceneID) {
            drawCoordinateSlopes(context: &context, size: size, beat: beat)
        } else if distanceScenes.contains(sceneID) {
            drawCoordinateDistance(context: &context, size: size, beat: beat)
        } else if circleScenes.contains(sceneID) {
            drawCoordinateCircle(context: &context, size: size, lineRelation: false, beat: beat)
        } else if relationScenes.contains(sceneID) {
            drawCoordinateCircle(context: &context, size: size, lineRelation: true, beat: beat)
        } else if translationScenes.contains(sceneID) {
            drawCoordinateTranslation(context: &context, size: size, beat: beat)
        } else {
            drawCoordinateReflection(context: &context, size: size, beat: beat)
        }
    }

    private func drawSetDefinition(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let board = CGRect(x: size.width * 0.08, y: size.height * 0.20, width: size.width * 0.84, height: size.height * 0.56)
        context.fill(Path(roundedRect: board, cornerRadius: 22), with: .color(Tokens.paper2))
        context.stroke(Path(roundedRect: board, cornerRadius: 22), with: .color(Tokens.lineStrong), lineWidth: 3)
        var divider = Path()
        divider.move(to: CGPoint(x: board.midX, y: board.minY + 12))
        divider.addLine(to: CGPoint(x: board.midX, y: board.maxY - 12))
        context.stroke(divider, with: .color(Tokens.text3.opacity(0.6)), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
        context.draw(Text("판정 기준").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: board.minX + board.width * 0.25, y: board.minY + 30))
        context.draw(Text("집합 A").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: board.minX + board.width * 0.75, y: board.minY + 30))
        let labels = ["1", "2", "3", "4", "5"]
        for (index, label) in labels.enumerated() {
            let x = board.minX + 28 + CGFloat(index) * ((board.width - 72) / 5)
            let card = CGRect(x: x, y: board.midY - 22, width: 48, height: 52)
            context.fill(Path(roundedRect: card, cornerRadius: 10), with: .color(index % 2 == 1 ? Color.yellow.opacity(0.62) : Tokens.primarySoft))
            context.draw(Text(label).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: card.midX, y: card.midY))
        }
        context.draw(
            Text(sceneID == "braces-do-not-decide" ? "기호보다 기준" : "조건 ⇄ 명단")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: board.midX, y: board.maxY - 26)
        )
    }

    private func drawInclusion(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let outer = CGRect(x: size.width * 0.13, y: size.height * 0.19, width: size.width * 0.74, height: size.height * 0.57)
        let inner = CGRect(x: size.width * 0.24, y: size.height * 0.31, width: size.width * 0.38, height: size.height * 0.33)
        context.stroke(Path(ellipseIn: outer), with: .color(Tokens.progressBlue), lineWidth: 5)
        context.fill(Path(ellipseIn: inner), with: .color(Color.yellow.opacity(0.34)))
        context.stroke(Path(ellipseIn: inner), with: .color(Tokens.warningInk), lineWidth: 4)
        context.draw(Text("B").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: outer.maxX - 36, y: outer.minY + 30))
        context.draw(Text("A").font(.mCallout.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: inner.midX, y: inner.minY + 24))
        let points: [(CGPoint, String, Bool)] = [
            (CGPoint(x: inner.midX - 36, y: inner.midY + 10), "1", true),
            (CGPoint(x: inner.midX + 38, y: inner.midY + 22), "2", true),
            (CGPoint(x: outer.midX + 150, y: outer.midY - 28), sceneID == "divisor-box-question" ? "8" : "3", false),
        ]
        for (point, label, focused) in points {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)), with: .color(focused ? Color.yellow : Tokens.primarySoft))
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: point)
        }
        context.draw(
            Text(sceneID == "element-versus-subset" ? "2∈A   ·   {2}⊆A" : sceneID == "two-way-equality" ? "A⊆B  +  B⊆A  ⇒  A=B" : "A⊆B")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.ink),
            at: CGPoint(x: size.width * 0.5, y: size.height - 40)
        )
    }

    private func drawVenn(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let left = CGRect(x: size.width * 0.23, y: size.height * 0.25, width: size.width * 0.34, height: size.height * 0.46)
        let right = left.offsetBy(dx: size.width * 0.19, dy: 0)
        context.stroke(Path(ellipseIn: left), with: .color(Tokens.progressBlue), lineWidth: 5)
        context.stroke(Path(ellipseIn: right), with: .color(Tokens.warningInk), lineWidth: 5)
        context.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.43, y: size.height * 0.32, width: size.width * 0.14, height: size.height * 0.32)),
            with: .color(Color.yellow.opacity(0.46))
        )
        context.draw(Text("A").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: left.minX + 30, y: left.minY + 25))
        context.draw(Text("B").font(.mCallout.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: right.maxX - 30, y: right.minY + 25))
        for (point, label) in [
            (CGPoint(x: left.midX - 42, y: left.midY), "2"),
            (CGPoint(x: size.width * 0.50, y: left.midY), "6"),
            (CGPoint(x: right.midX + 42, y: right.midY), "9"),
        ] {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 17, y: point.y - 17, width: 34, height: 34)), with: .color(label == "6" ? Color.yellow : Tokens.primarySoft))
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: point)
        }
        let copy = sceneID == "demorgan-switch" ? "(A∪B)ᶜ = Aᶜ∩Bᶜ" : sceneID == "numbers-under-ten" ? "A∩B={6}" : "∪ 또는  ·  ∩ 그리고  ·  ᶜ 아닌"
        context.draw(Text(copy).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: size.width * 0.5, y: size.height - 38))
    }

    private func drawTruthBoard(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let labels = sceneID == "truth-set-solution" ? ["−2", "−1", "0", "1", "2"] : ["P(1)", "P(2)", "P(3)", "P(4)"]
        context.draw(
            Text(beat.id.contains("exist") || beat.id.contains("witness") ? "어떤 ∃ · 증인 하나" : "모든 ∀ · 반례 하나")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.ink),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.23)
        )
        let gap = size.width * 0.78 / CGFloat(labels.count)
        for (index, label) in labels.enumerated() {
            let rect = CGRect(x: size.width * 0.11 + CGFloat(index) * gap, y: size.height * 0.36, width: gap - 10, height: 82)
            let active = sceneID == "truth-set-solution" ? [1, 3].contains(index) : index != 2
            context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(active ? Color.yellow.opacity(0.56) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(active ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY - 12))
            context.draw(Text(active ? "참" : "거짓").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.midY + 18))
        }
        context.draw(Text(sceneID == "quantifier-negation" ? "¬∀P ⇔ ∃¬P" : "진리집합 T").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.75))
    }

    private func drawImplication(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let conditionScenes: Set<String> = ["gate-and-requirement", "square-rectangle-question", "language-reversal", "interval-condition", "tail-head-recall"]
        let isCondition = conditionScenes.contains(sceneID)
        let left = CGRect(x: size.width * 0.12, y: size.height * 0.35, width: size.width * 0.27, height: 92)
        let right = CGRect(x: size.width * 0.61, y: size.height * 0.35, width: size.width * 0.27, height: 92)
        context.fill(Path(roundedRect: left, cornerRadius: 16), with: .color(Color.yellow.opacity(0.55)))
        context.fill(Path(roundedRect: right, cornerRadius: 16), with: .color(Tokens.primarySoft))
        context.stroke(Path(roundedRect: left, cornerRadius: 16), with: .color(Tokens.warningInk), lineWidth: 3)
        context.stroke(Path(roundedRect: right, cornerRadius: 16), with: .color(Tokens.progressBlue), lineWidth: 3)
        context.draw(Text(isCondition ? "p · 충분" : "p").font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink), at: CGPoint(x: left.midX, y: left.midY))
        context.draw(Text(isCondition ? "q · 필요" : "q").font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink), at: CGPoint(x: right.midX, y: right.midY))
        var arrow = Path()
        arrow.move(to: CGPoint(x: left.maxX + 12, y: left.midY))
        arrow.addLine(to: CGPoint(x: right.minX - 12, y: right.midY))
        context.stroke(arrow, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.draw(Text("p → q").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: left.minY - 30))
        let reverse = beat.id.contains("contra") || beat.id.contains("negate") || sceneID == "multiple-of-four"
        context.draw(
            Text(isCondition ? "P ⊆ Q" : reverse ? "¬q → ¬p" : "역 q → p는 별도")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.warningInk),
            at: CGPoint(x: size.width * 0.5, y: left.maxY + 54)
        )
    }

    private func drawProofFlow(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let labels: [String]
        if sceneID == "irrational-root-two" {
            labels = ["√2=a/b", "a 짝수", "b 짝수", "서로소 모순"]
        } else if sceneID == "even-square-question" {
            labels = ["n=2k+1", "제곱 전개", "2m+1", "대우 완료"]
        } else {
            labels = ["p", "¬q", "R∧¬R", "가정 기각"]
        }
        let width = size.width * 0.19
        for (index, label) in labels.enumerated() {
            let rect = CGRect(x: size.width * 0.07 + CGFloat(index) * size.width * 0.235, y: size.height * 0.38, width: width, height: 76)
            context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 3 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 3 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
            if index < labels.count - 1 {
                var link = Path()
                link.move(to: CGPoint(x: rect.maxX + 5, y: rect.midY))
                link.addLine(to: CGPoint(x: rect.maxX + size.width * 0.04, y: rect.midY))
                context.stroke(link, with: .color(Tokens.progressBlue), lineWidth: 4)
            }
        }
        context.draw(Text(sceneID == "fake-contradiction" ? "이상함 ≠ 모순" : "우회 증명 흐름").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.73))
    }

    private func drawInequalityFloor(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        var floor = Path()
        floor.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.76))
        floor.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.76))
        context.stroke(floor, with: .color(Tokens.text3), lineWidth: 4)
        let side = min(size.width * 0.25, size.height * 0.34)
        let square = CGRect(x: size.width * 0.28, y: size.height * 0.76 - side, width: side, height: side)
        context.fill(Path(roundedRect: square, cornerRadius: 10), with: .color(Color.yellow.opacity(0.55)))
        context.stroke(Path(roundedRect: square, cornerRadius: 10), with: .color(Tokens.warningInk), lineWidth: 4)
        context.draw(Text("(a−b)²").font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink), at: CGPoint(x: square.midX, y: square.midY))
        let rightCopy = sceneID == "unsafe-divi" + "sion" ? "a>0 / a<0 / a=0" : "≥ 0"
        context.draw(Text(rightCopy).font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.70, y: size.height * 0.62))
        context.draw(Text("0 바닥 · 등호 조건 확인").font(.mCallout.weight(.black)).foregroundStyle(Tokens.text2), at: CGPoint(x: size.width * 0.5, y: size.height * 0.85))
    }

    private func drawSetsPropositionsScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let definitions: Set<String> = ["objective-guest-list", "membership-question", "braces-do-not-decide", "representation-check", "set-recall"]
        let inclusion: Set<String> = ["nested-boxes", "divisor-box-question", "element-versus-subset", "two-way-equality", "inclusion-recall"]
        let venn: Set<String> = ["overlapping-spotlights", "numbers-under-ten", "demorgan-switch", "shade-from-outside", "logic-lights-recall"]
        let truth: Set<String> = ["truth-switchboard", "all-or-some-question", "quantifier-negation", "truth-set-solution", "verdict-recall"]
        let arrows: Set<String> = ["one-way-arrow", "multiple-of-four", "converse-is-not-equivalent", "label-and-turn", "arrow-recall", "gate-and-requirement", "square-rectangle-question", "language-reversal", "interval-condition", "tail-head-recall"]
        let proofs: Set<String> = ["two-detours", "even-square-question", "fake-contradiction", "irrational-root-two", "proof-route-recall"]
        if definitions.contains(sceneID) {
            drawSetDefinition(context: &context, size: size, beat: beat)
        } else if inclusion.contains(sceneID) {
            drawInclusion(context: &context, size: size, beat: beat)
        } else if venn.contains(sceneID) {
            drawVenn(context: &context, size: size, beat: beat)
        } else if truth.contains(sceneID) {
            drawTruthBoard(context: &context, size: size, beat: beat)
        } else if arrows.contains(sceneID) {
            drawImplication(context: &context, size: size, beat: beat)
        } else if proofs.contains(sceneID) {
            drawProofFlow(context: &context, size: size, beat: beat)
        } else {
            drawInequalityFloor(context: &context, size: size, beat: beat)
        }
    }

    private func drawFunctionMapping(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let leftX = size.width * 0.23
        let rightX = size.width * 0.77
        context.draw(Text("입력 x").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: leftX, y: size.height * 0.18))
        context.draw(Text("출력 f(x)").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rightX, y: size.height * 0.18))
        let inputs = ["−1", "0", "1"]
        let outputs = sceneID == "horizontal-test-error" ? ["1", "0", "1"] : ["−1", "1", "3"]
        for index in inputs.indices {
            let y = size.height * (0.31 + CGFloat(index) * 0.20)
            let left = CGPoint(x: leftX, y: y)
            let right = CGPoint(x: rightX, y: y)
            var link = Path()
            link.move(to: CGPoint(x: left.x + 28, y: y))
            link.addCurve(
                to: CGPoint(x: right.x - 28, y: y),
                control1: CGPoint(x: size.width * 0.40, y: y),
                control2: CGPoint(x: size.width * 0.60, y: y)
            )
            context.stroke(link, with: .color(index == 1 ? Tokens.progressBlue : Tokens.text3), lineWidth: index == 1 ? 5 : 3)
            for (point, label) in [(left, inputs[index]), (right, outputs[index])] {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50)), with: .color(index == 1 ? Color.yellow.opacity(0.72) : Tokens.paper2))
                context.stroke(Path(ellipseIn: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50)), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
                context.draw(Text(label).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: point)
            }
        }
        context.draw(
            Text(sceneID == "horizontal-test-error" ? "세로선: x 하나에 y 하나" : "입력 하나 → 출력 하나")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.88)
        )
        if beat.action == "point" || beat.action == "highlight" || beat.action == "verify" {
            context.stroke(
                Path(roundedRect: CGRect(x: size.width * 0.17, y: size.height * 0.42, width: size.width * 0.66, height: size.height * 0.17), cornerRadius: 18),
                with: .color(Tokens.warningInk),
                lineWidth: 4
            )
        }
    }

    private func drawCompositionPipeline(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let reversed = sceneID == "order-question" && (beat.id.contains("reverse") || beat.id.contains("swap"))
        let stages = reversed
            ? [("x", "3"), ("g", "×2"), ("f", "+1"), ("결과", "7")]
            : [("x", "3"), ("f", "+1"), ("g", "×2"), ("결과", "8")]
        let width = size.width * 0.18
        let gap = size.width * 0.055
        for (index, stage) in stages.enumerated() {
            let rect = CGRect(x: size.width * 0.045 + CGFloat(index) * (width + gap), y: size.height * 0.36, width: width, height: size.height * 0.28)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.60) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(stage.0).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.minY + 26))
            context.draw(Text(stage.1).font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY + 15))
            if index < stages.count - 1 {
                var arrow = Path()
                arrow.move(to: CGPoint(x: rect.maxX + 5, y: rect.midY))
                arrow.addLine(to: CGPoint(x: rect.maxX + gap - 5, y: rect.midY))
                context.stroke(arrow, with: .color(Tokens.progressBlue), lineWidth: 5)
            }
        }
        context.draw(
            Text(sceneID == "missing-parentheses" ? "g(f(x))에서 안쪽 f부터" : "기계의 순서가 답을 바꿉니다")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.79)
        )
    }

    private func drawInverseRoundTrip(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        var mirror = Path()
        mirror.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.78))
        mirror.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.20))
        context.stroke(mirror, with: .color(Tokens.text3), style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
        let nodes = [
            (CGPoint(x: size.width * 0.20, y: size.height * 0.62), "x=3"),
            (CGPoint(x: size.width * 0.50, y: size.height * 0.38), "f(x)=7"),
            (CGPoint(x: size.width * 0.80, y: size.height * 0.62), "f⁻¹(7)=3"),
        ]
        for (index, item) in nodes.enumerated() {
            context.fill(Path(ellipseIn: CGRect(x: item.0.x - 43, y: item.0.y - 43, width: 86, height: 86)), with: .color(index == 1 ? Color.yellow.opacity(0.68) : Tokens.paper2))
            context.stroke(Path(ellipseIn: CGRect(x: item.0.x - 43, y: item.0.y - 43, width: 86, height: 86)), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 4)
            context.draw(Text(item.1).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: item.0)
            if index < nodes.count - 1 {
                var link = Path()
                link.move(to: CGPoint(x: item.0.x + 48, y: item.0.y))
                link.addLine(to: CGPoint(x: nodes[index + 1].0.x - 48, y: nodes[index + 1].0.y))
                context.stroke(link, with: .color(Tokens.progressBlue), lineWidth: 5)
            }
        }
        context.draw(
            Text(sceneID == "negative-one-is-not-reciprocal" ? "f⁻¹는 되돌리기, 1/f가 아님" : "입력과 출력을 바꾸고 다시 확인")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.warningInk),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.87)
        )
    }

    private func drawRationalAsymptotes(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let verticalX = size.width * 0.37
        let horizontalY = size.height * 0.48
        var axes = Path()
        axes.move(to: CGPoint(x: 36, y: size.height * 0.75))
        axes.addLine(to: CGPoint(x: size.width - 30, y: size.height * 0.75))
        axes.move(to: CGPoint(x: size.width * 0.5, y: size.height - 24))
        axes.addLine(to: CGPoint(x: size.width * 0.5, y: 58))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)
        var asymptotes = Path()
        asymptotes.move(to: CGPoint(x: verticalX, y: 58))
        asymptotes.addLine(to: CGPoint(x: verticalX, y: size.height - 28))
        asymptotes.move(to: CGPoint(x: 34, y: horizontalY))
        asymptotes.addLine(to: CGPoint(x: size.width - 30, y: horizontalY))
        context.stroke(asymptotes, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: [9, 7]))
        var branches = Path()
        branches.move(to: CGPoint(x: 46, y: horizontalY - 22))
        branches.addCurve(to: CGPoint(x: verticalX - 22, y: 72), control1: CGPoint(x: size.width * 0.18, y: horizontalY - 24), control2: CGPoint(x: verticalX - 42, y: size.height * 0.31))
        branches.move(to: CGPoint(x: verticalX + 22, y: size.height - 44))
        branches.addCurve(to: CGPoint(x: size.width - 38, y: horizontalY + 10), control1: CGPoint(x: verticalX + 54, y: size.height * 0.71), control2: CGPoint(x: size.width * 0.75, y: horizontalY + 22))
        context.stroke(branches, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.draw(Text("x=−1").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: verticalX, y: size.height - 34))
        context.draw(Text("y=3").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width - 52, y: horizontalY - 20))
        context.draw(
            Text(sceneID == "asymptote-is-not-graph" ? "점근선은 가까워지는 길" : "금지값과 중심을 먼저 표시")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.ink),
            at: CGPoint(x: size.width * 0.5, y: 38)
        )
    }

    private func drawRadicalTrail(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let start = CGPoint(x: size.width * 0.24, y: size.height * 0.70)
        var axes = Path()
        axes.move(to: CGPoint(x: 38, y: start.y))
        axes.addLine(to: CGPoint(x: size.width - 34, y: start.y))
        axes.move(to: CGPoint(x: start.x, y: size.height - 30))
        axes.addLine(to: CGPoint(x: start.x, y: 66))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)
        var curve = Path()
        curve.move(to: start)
        curve.addCurve(to: CGPoint(x: size.width - 46, y: size.height * 0.23), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.48), control2: CGPoint(x: size.width * 0.55, y: size.height * 0.26))
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.fill(Path(ellipseIn: CGRect(x: start.x - 11, y: start.y - 11, width: 22, height: 22)), with: .color(Color.yellow))
        context.stroke(Path(ellipseIn: CGRect(x: start.x - 12, y: start.y - 12, width: 24, height: 24)), with: .color(Tokens.warningInk), lineWidth: 3)
        var allowed = Path()
        allowed.move(to: start)
        allowed.addLine(to: CGPoint(x: size.width - 38, y: start.y))
        context.stroke(allowed, with: .color(Tokens.warningInk), lineWidth: 5)
        context.draw(Text("시작점").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: start.x, y: start.y - 28))
        context.draw(Text("루트 안 ≥ 0").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.60, y: size.height * 0.86))
    }

    private func drawFunctionsGraphsScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let mapping: Set<String> = ["vending-buttons", "mapping-question", "horizontal-test-error", "graph-from-rule", "function-recall"]
        let composition: Set<String> = ["assembly-line", "order-question", "missing-parentheses", "numeric-pipeline", "composition-recall"]
        let inverse: Set<String> = ["undo-button", "linear-undo-question", "negative-one-is-not-reciprocal", "solve-swap-check", "inverse-recall"]
        let rational: Set<String> = ["forbidden-wall-horizon", "divide-to-see-question", "asymptote-is-not-graph", "rational-sketch", "rational-recall"]
        if mapping.contains(sceneID) {
            drawFunctionMapping(context: &context, size: size, beat: beat)
        } else if composition.contains(sceneID) {
            drawCompositionPipeline(context: &context, size: size, beat: beat)
        } else if inverse.contains(sceneID) {
            drawInverseRoundTrip(context: &context, size: size, beat: beat)
        } else if rational.contains(sceneID) {
            drawRationalAsymptotes(context: &context, size: size, beat: beat)
        } else {
            drawRadicalTrail(context: &context, size: size, beat: beat)
        }
    }

    private func drawPowerRootMachine(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let stages = [
            ("입력", sceneID == "principal-root-trap" ? "−3, 3" : "a"),
            ("거듭제곱", "× 자기 자신"),
            ("결과", sceneID == "root-calculation-route" ? "16" : "a²"),
        ]
        let width = min(size.width * 0.22, 162)
        let gap = min(size.width * 0.07, 56)
        let total = width * 3 + gap * 2
        let start = (size.width - total) / 2
        for (index, stage) in stages.enumerated() {
            let rect = CGRect(
                x: start + CGFloat(index) * (width + gap),
                y: size.height * 0.36,
                width: width,
                height: size.height * 0.28
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 18),
                with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2)
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 18),
                with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong),
                lineWidth: 3
            )
            context.draw(
                Text(stage.0).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2),
                at: CGPoint(x: rect.midX, y: rect.minY + 27)
            )
            context.draw(
                Text(stage.1).font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink),
                at: CGPoint(x: rect.midX, y: rect.midY + 16)
            )
            guard index < stages.count - 1 else { continue }
            var arrow = Path()
            arrow.move(to: CGPoint(x: rect.maxX + 6, y: rect.midY))
            arrow.addLine(to: CGPoint(x: rect.maxX + gap - 6, y: rect.midY))
            context.stroke(arrow, with: .color(Tokens.progressBlue), lineWidth: 5)
        }
        var rewind = Path()
        rewind.move(to: CGPoint(x: start + total - width / 2, y: size.height * 0.69))
        rewind.addCurve(
            to: CGPoint(x: start + width / 2, y: size.height * 0.69),
            control1: CGPoint(x: size.width * 0.77, y: size.height * 0.91),
            control2: CGPoint(x: size.width * 0.23, y: size.height * 0.91)
        )
        context.stroke(rewind, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: [9, 6]))
        context.draw(
            Text("제곱근은 결과에서 입력으로 되감기")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.86)
        )
    }

    private func drawFractionalExponentLine(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let y = size.height * 0.59
        var line = Path()
        line.move(to: CGPoint(x: size.width * 0.09, y: y))
        line.addLine(to: CGPoint(x: size.width * 0.91, y: y))
        context.stroke(line, with: .color(Tokens.text3), lineWidth: 4)
        let ticks = [(0.14, "0"), (0.33, "1/3"), (0.50, "1/2"), (0.67, "2/3"), (0.86, "1")]
        for (index, item) in ticks.enumerated() {
            let x = size.width * item.0
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: y - 14))
            tick.addLine(to: CGPoint(x: x, y: y + 14))
            context.stroke(tick, with: .color(Tokens.text3), lineWidth: 3)
            context.fill(
                Path(ellipseIn: CGRect(x: x - (index == 2 ? 11 : 7), y: y - (index == 2 ? 11 : 7), width: index == 2 ? 22 : 14, height: index == 2 ? 22 : 14)),
                with: .color(index == 2 ? Color.yellow : Tokens.primarySoft)
            )
            context.draw(Text(item.1).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: x, y: y + 36))
        }
        context.draw(
            Text("a¹ᐟⁿ = ⁿ√a").font(.system(.title2, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.30)
        )
        context.draw(
            Text(sceneID == "negative-base-extension-trap" ? "음수 밑: 홀수 뿌리만 실수로 통과" : "분모 n은 몇 제곱근인지 정합니다")
                .font(.mCallout.weight(.black))
                .foregroundStyle(sceneID == "negative-base-extension-trap" ? Tokens.warningInk : Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.82)
        )
    }

    private func drawExponentLedger(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID == "sum-power-trap" {
            let board = CGRect(x: size.width * 0.27, y: size.height * 0.25, width: size.width * 0.46, height: size.height * 0.48)
            let cells = [
                (CGRect(x: board.minX, y: board.minY, width: board.width * 0.52, height: board.height * 0.52), "a²", Color.yellow.opacity(0.62)),
                (CGRect(x: board.minX + board.width * 0.52, y: board.minY, width: board.width * 0.48, height: board.height * 0.52), "ab", Tokens.primarySoft),
                (CGRect(x: board.minX, y: board.minY + board.height * 0.52, width: board.width * 0.52, height: board.height * 0.48), "ab", Tokens.primarySoft),
                (CGRect(x: board.minX + board.width * 0.52, y: board.minY + board.height * 0.52, width: board.width * 0.48, height: board.height * 0.48), "b²", Tokens.paper2),
            ]
            for cell in cells {
                context.fill(Path(roundedRect: cell.0, cornerRadius: 8), with: .color(cell.2))
                context.stroke(Path(roundedRect: cell.0, cornerRadius: 8), with: .color(Tokens.lineStrong), lineWidth: 2)
                context.draw(Text(cell.1).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: cell.0.midX, y: cell.0.midY))
            }
            context.draw(
                Text("(a+b)² = a² + 2ab + b²").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
                at: CGPoint(x: size.width * 0.5, y: size.height * 0.84)
            )
            return
        }
        let rows = [(0.34, "aᵐ × aⁿ", "+", "aᵐ⁺ⁿ", "곱셈"), (0.66, "aᵐ ÷ aⁿ", "−", "aᵐ⁻ⁿ", "나눗셈")]
        for row in rows {
            let left = CGRect(x: size.width * 0.08, y: size.height * row.0 - 34, width: size.width * 0.28, height: 68)
            let right = CGRect(x: size.width * 0.58, y: size.height * row.0 - 34, width: size.width * 0.24, height: 68)
            context.fill(Path(roundedRect: left, cornerRadius: 12), with: .color(Tokens.paper2))
            context.stroke(Path(roundedRect: left, cornerRadius: 12), with: .color(Tokens.lineStrong), lineWidth: 3)
            context.fill(Path(roundedRect: right, cornerRadius: 12), with: .color(Color.yellow.opacity(0.62)))
            context.stroke(Path(roundedRect: right, cornerRadius: 12), with: .color(Tokens.warningInk), lineWidth: 3)
            context.draw(Text(row.1).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: left.midX, y: left.midY))
            context.draw(Text(row.2).font(.system(.title2, design: .rounded, weight: .black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.47, y: left.midY))
            context.draw(Text(row.3).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: right.midX, y: right.midY))
            context.draw(Text(row.4).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: size.width * 0.91, y: right.midY))
        }
    }

    private func drawAlgebraPowerExponentScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let powerRoot: Set<String> = ["power-machine-and-rewind", "root-count-by-parity", "principal-root-trap", "root-calculation-route", "rewind-question-recall"]
        let fractional: Set<String> = ["exponent-number-line-zoom", "fractional-exponent-meaning", "negative-base-extension-trap", "fractional-exponent-conversion", "dense-exponent-line-recall"]
        if powerRoot.contains(sceneID) {
            drawPowerRootMachine(context: &context, size: size, beat: beat)
        } else if fractional.contains(sceneID) {
            drawFractionalExponentLine(context: &context, size: size, beat: beat)
        } else {
            drawExponentLedger(context: &context, size: size, beat: beat)
        }
    }

    private func drawLogTranslator(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID == "log-sum-trap" {
            let cards = [(0.08, "logₐM"), (0.38, "+ logₐN"), (0.70, "logₐ(MN)")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * card.0, y: size.height * 0.38, width: size.width * 0.22, height: size.height * 0.25)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
                context.draw(Text(card.1).font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
            }
            context.draw(Text("바깥의 +는 진수 안에서 ×").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.80))
            return
        }
        let labels = sceneID == "log-domain-gates"
            ? [("밑", "a>0"), ("관문", "a≠1"), ("진수", "b>0")]
            : [("밑 버튼", "a"), ("횟수", "x"), ("도착값", "b")]
        let width = size.width * 0.22
        let gap = size.width * 0.07
        let start = (size.width - width * 3 - gap * 2) / 2
        for (index, label) in labels.enumerated() {
            let rect = CGRect(x: start + CGFloat(index) * (width + gap), y: size.height * 0.36, width: width, height: size.height * 0.28)
            context.fill(Path(roundedRect: rect, cornerRadius: 18), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 18), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(label.0).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.minY + 27))
            context.draw(Text(label.1).font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY + 16))
            guard index < 2 else { continue }
            var arrow = Path()
            arrow.move(to: CGPoint(x: rect.maxX + 6, y: rect.midY))
            arrow.addLine(to: CGPoint(x: rect.maxX + gap - 6, y: rect.midY))
            context.stroke(arrow, with: .color(Tokens.progressBlue), lineWidth: 5)
        }
        context.draw(
            Text(sceneID == "log-expression-solution" ? "조건 → 묶기 → 지수 문장 검산" : "aˣ=b  ⇄  logₐb=x")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.82)
        )
    }

    private func drawDecadeElevator(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let floors = [("10⁰", "1"), ("10¹", "10"), ("10²", "100"), ("10³", "1000")]
        for (index, floor) in floors.enumerated() {
            let rect = CGRect(
                x: size.width * 0.12 + CGFloat(index) * size.width * 0.18,
                y: size.height * (0.66 - CGFloat(index) * 0.13),
                width: size.width * 0.26,
                height: size.height * 0.11
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(index == 2 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(index == 2 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text("\(floor.0) = \(floor.1)").font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
        }
        context.draw(
            Text(sceneID == "digit-count-question" ? "층 번호 + 1 = 자릿수" : "로그 한 칸 = 원래 값 10배")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.87)
        )
        if sceneID == "common-log-application-route" {
            context.draw(Text("2.505 = 2층 + 층 안 3.2배").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.5, y: size.height * 0.20))
        }
    }

    private func drawInverseMachinePair(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let boxes = [(0.10, "실수 x", "지수 aˣ"), (0.67, "양수 y", "로그 logₐy")]
        for (index, box) in boxes.enumerated() {
            let rect = CGRect(x: size.width * box.0, y: size.height * 0.36, width: size.width * 0.22, height: size.height * 0.30)
            context.fill(Path(roundedRect: rect, cornerRadius: 20), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 20), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(box.1).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY - 16))
            context.draw(Text(box.2).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.midY + 24))
        }
        var forward = Path()
        forward.move(to: CGPoint(x: size.width * 0.34, y: size.height * 0.43))
        forward.addCurve(to: CGPoint(x: size.width * 0.65, y: size.height * 0.43), control1: CGPoint(x: size.width * 0.43, y: size.height * 0.25), control2: CGPoint(x: size.width * 0.56, y: size.height * 0.25))
        context.stroke(forward, with: .color(Tokens.progressBlue), lineWidth: 5)
        var reverse = Path()
        reverse.move(to: CGPoint(x: size.width * 0.65, y: size.height * 0.60))
        reverse.addCurve(to: CGPoint(x: size.width * 0.34, y: size.height * 0.60), control1: CGPoint(x: size.width * 0.56, y: size.height * 0.79), control2: CGPoint(x: size.width * 0.43, y: size.height * 0.79))
        context.stroke(reverse, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: [9, 6]))
        context.draw(
            Text(sceneID == "domain-range-swap-trap" ? "ℝ  ⇄  (0,∞)" : "logₐ(aˣ)=x")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.88)
        )
    }

    private func drawLogGraphMirror(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.68)
        var axes = Path()
        axes.move(to: CGPoint(x: 36, y: center.y))
        axes.addLine(to: CGPoint(x: size.width - 32, y: center.y))
        axes.move(to: CGPoint(x: center.x, y: size.height - 24))
        axes.addLine(to: CGPoint(x: center.x, y: 52))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)
        var mirror = Path()
        mirror.move(to: CGPoint(x: size.width * 0.18, y: size.height - 32))
        mirror.addLine(to: CGPoint(x: size.width * 0.82, y: 54))
        context.stroke(mirror, with: .color(Tokens.text3.opacity(0.7)), style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
        var exponential = Path()
        exponential.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.64))
        exponential.addCurve(to: CGPoint(x: size.width * 0.88, y: size.height * 0.15), control1: CGPoint(x: size.width * 0.34, y: size.height * 0.62), control2: CGPoint(x: size.width * 0.52, y: size.height * 0.20))
        context.stroke(exponential, with: .color(Tokens.progressBlue), lineWidth: 6)
        var logarithm = Path()
        logarithm.move(to: CGPoint(x: size.width * 0.53, y: size.height * 0.88))
        logarithm.addCurve(to: CGPoint(x: size.width * 0.91, y: size.height * 0.23), control1: CGPoint(x: size.width * 0.55, y: size.height * 0.54), control2: CGPoint(x: size.width * 0.72, y: size.height * 0.29))
        context.stroke(logarithm, with: .color(Tokens.warningInk), lineWidth: 5)
        context.fill(Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - size.height * 0.18 - 9, width: 18, height: 18)), with: .color(Color.yellow))
        context.fill(Path(ellipseIn: CGRect(x: center.x + size.width * 0.08 - 9, y: center.y - 9, width: 18, height: 18)), with: .color(Tokens.primarySoft))
        context.draw(
            Text(sceneID == "asymptote-not-intercept" ? "축에 가까워져도 닿지 않음" : "한 점 · 한 점근선 · 한 방향")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.94)
        )
    }

    private func drawGrowthClock(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let values = sceneID == "growth-model-solution"
            ? [("0h", "200"), ("4h", "160"), ("12h", "102.4"), ("16h", "81.92")]
            : [("0", "A₀"), ("1주기", "A₀r"), ("2주기", "A₀r²"), ("3주기", "A₀r³")]
        for (index, value) in values.enumerated() {
            let x = size.width * (0.12 + CGFloat(index) * 0.25)
            let point = CGPoint(x: x, y: size.height * 0.51)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 38, y: point.y - 38, width: 76, height: 76)), with: .color(index == values.count - 1 ? Color.yellow.opacity(0.70) : Tokens.paper2))
            context.stroke(Path(ellipseIn: CGRect(x: point.x - 38, y: point.y - 38, width: 76, height: 76)), with: .color(index == values.count - 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 4)
            context.draw(Text(value.1).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: point)
            context.draw(Text(value.0).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: point.x, y: point.y + 58))
            guard index < values.count - 1 else { continue }
            var arrow = Path()
            arrow.move(to: CGPoint(x: point.x + 42, y: point.y))
            arrow.addLine(to: CGPoint(x: point.x + size.width * 0.20, y: point.y))
            context.stroke(arrow, with: .color(Tokens.progressBlue), lineWidth: 5)
        }
        context.draw(
            Text(sceneID == "inverse-time-question" ? "목표 ÷ 초기값 → 로그로 시간 되찾기" : "같은 양이 아니라 같은 배수를 반복")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.82)
        )
        if sceneID == "growth-model-solution" {
            context.draw(Text("연속 임계 12.43h · 관측 최초 16h").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.5, y: size.height * 0.24))
        }
    }

    private func drawAlgebraLogFunctionScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let translator: Set<String> = ["exponent-question-language", "log-domain-gates", "log-sum-trap", "log-expression-solution", "log-three-roles-recall"]
        let decades: Set<String> = ["powers-of-ten-elevator", "digit-count-question", "scale-difference-trap", "common-log-application-route", "magnitude-floor-recall"]
        let inverse: Set<String> = ["forward-and-reverse-machines", "fixed-base-variable-place", "domain-range-swap-trap", "inverse-composition-solution", "two-machines-recall"]
        let graphs: Set<String> = ["graph-mirror-and-anchors", "base-direction-switch", "asymptote-not-intercept", "graph-reconstruction-route", "graph-fingerprint-recall"]
        if translator.contains(sceneID) {
            drawLogTranslator(context: &context, size: size, beat: beat)
        } else if decades.contains(sceneID) {
            drawDecadeElevator(context: &context, size: size, beat: beat)
        } else if inverse.contains(sceneID) {
            drawInverseMachinePair(context: &context, size: size, beat: beat)
        } else if graphs.contains(sceneID) {
            drawLogGraphMirror(context: &context, size: size, beat: beat)
        } else {
            drawGrowthClock(context: &context, size: size, beat: beat)
        }
    }

    private func drawRadianWheel(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let center = CGPoint(x: size.width * 0.38, y: size.height * 0.50)
        let radius = min(size.width, size.height) * 0.28
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(Tokens.text3),
            lineWidth: 3
        )
        var radii = Path()
        radii.move(to: center)
        radii.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        radii.move(to: center)
        radii.addLine(to: CGPoint(x: center.x + radius * 0.52, y: center.y - radius * 0.86))
        context.stroke(radii, with: .color(Tokens.progressBlue), lineWidth: 5)
        var arc = Path()
        arc.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(-59),
            clockwise: true
        )
        context.stroke(arc, with: .color(Tokens.warningInk), lineWidth: 8)
        context.draw(Text("r").font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: center.x + radius * 0.52, y: center.y + 22))
        context.draw(Text("호 l").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: center.x + radius * 1.04, y: center.y - radius * 0.50))
        context.draw(Text("θ").font(.system(.title3, design: .rounded, weight: .black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: center.x + 38, y: center.y - 30))

        let card = CGRect(x: size.width * 0.61, y: size.height * 0.30, width: size.width * 0.32, height: size.height * 0.36)
        context.fill(Path(roundedRect: card, cornerRadius: 18), with: .color(Color.yellow.opacity(0.60)))
        context.stroke(Path(roundedRect: card, cornerRadius: 18), with: .color(Tokens.warningInk), lineWidth: 3)
        let copy = sceneID == "degree-radian-mixup"
            ? "180° = πrad"
            : sceneID == "sector-measure-solution"
                ? "150° → 5π/6\nl=5π · S=15π"
                : "θ = l/r\n한 바퀴 = 2π"
        context.draw(Text(copy).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: card.midX, y: card.midY))
        context.draw(
            Text(sceneID == "directed-turn-counter" ? "+ 반시계 · − 시계 · 2π마다 같은 동경" : "반지름 자로 원 위의 회전을 잽니다")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.88)
        )
    }

    private func drawUnitCircleWave(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let center = CGPoint(x: size.width * 0.25, y: size.height * 0.48)
        let radius = min(size.width, size.height) * 0.24
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(Tokens.text3),
            lineWidth: 3
        )
        var axes = Path()
        axes.move(to: CGPoint(x: center.x - radius * 1.18, y: center.y))
        axes.addLine(to: CGPoint(x: center.x + radius * 1.18, y: center.y))
        axes.move(to: CGPoint(x: center.x, y: center.y + radius * 1.18))
        axes.addLine(to: CGPoint(x: center.x, y: center.y - radius * 1.18))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 2)
        let point = CGPoint(x: center.x + radius * 0.68, y: center.y - radius * 0.72)
        var shadows = Path()
        shadows.move(to: center)
        shadows.addLine(to: point)
        shadows.move(to: point)
        shadows.addLine(to: CGPoint(x: point.x, y: center.y))
        shadows.move(to: point)
        shadows.addLine(to: CGPoint(x: center.x, y: point.y))
        context.stroke(shadows, with: .color(Tokens.progressBlue), lineWidth: 4)
        context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(Color.yellow))
        context.draw(Text("cosθ").font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: point.x, y: center.y + 25))
        context.draw(Text("sinθ").font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: center.x - 34, y: point.y))

        let waveStart = size.width * 0.48
        let waveWidth = size.width * 0.47
        var baseline = Path()
        baseline.move(to: CGPoint(x: waveStart, y: center.y))
        baseline.addLine(to: CGPoint(x: waveStart + waveWidth, y: center.y))
        context.stroke(baseline, with: .color(Tokens.text3), lineWidth: 2)
        var wave = Path()
        let samples = 72
        for index in 0...samples {
            let progress = CGFloat(index) / CGFloat(samples)
            let x = waveStart + progress * waveWidth
            let y = center.y - sin(progress * .pi * 2) * radius * 0.70
            if index == 0 { wave.move(to: CGPoint(x: x, y: y)) }
            else { wave.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(wave, with: .color(Tokens.warningInk), lineWidth: 5)
        let copy = sceneID == "tangent-gap-trap"
            ? "tanθ=sinθ/cosθ · cosθ=0에서 끊기"
            : sceneID == "transformed-wave-solution"
                ? "진폭 |A| · 주기 2π/|B| · 중심선 D"
                : "원 위의 그림자를 각도 축에 펼칩니다"
        context.draw(Text(copy).font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.88))
    }

    private func drawTriangulationTool(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let a = CGPoint(x: size.width * 0.12, y: size.height * 0.72)
        let b = CGPoint(x: size.width * 0.86, y: size.height * 0.72)
        let c = CGPoint(x: size.width * 0.61, y: size.height * 0.18)
        var triangle = Path()
        triangle.move(to: a)
        triangle.addLine(to: b)
        triangle.addLine(to: c)
        triangle.closeSubpath()
        context.stroke(triangle, with: .color(Tokens.progressBlue), lineWidth: 5)
        for item in [(a, "A"), (b, "B"), (c, "C")] {
            context.fill(Path(ellipseIn: CGRect(x: item.0.x - 9, y: item.0.y - 9, width: 18, height: 18)), with: .color(Color.yellow))
            context.draw(Text(item.1).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: item.0.x, y: item.0.y - 23))
        }
        context.draw(Text("a ↔ A").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.73, y: size.height * 0.43))
        context.draw(Text("b ↔ B").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.38, y: size.height * 0.43))
        context.draw(Text("기준선 c").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: size.width * 0.49, y: size.height * 0.78))
        let tool = sceneID == "law-selection-question"
            ? "두 변+끼인각 → 코사인법칙"
            : "맞은편 쌍 → a/sinA = b/sinB"
        let card = CGRect(x: size.width * 0.20, y: size.height * 0.81, width: size.width * 0.60, height: size.height * 0.14)
        context.fill(Path(roundedRect: card, cornerRadius: 12), with: .color(Color.yellow.opacity(0.60)))
        context.draw(Text(tool).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: card.midX, y: card.midY))
    }

    private func drawAlgebraTrigonometryScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let radians: Set<String> = ["arc-as-angle-ruler", "directed-turn-counter", "degree-radian-mixup", "sector-measure-solution", "radius-ruler-recall"]
        let waves: Set<String> = ["rotating-beacon-shadows", "wave-landmarks-question", "tangent-gap-trap", "transformed-wave-solution", "circle-wave-recall"]
        if radians.contains(sceneID) {
            drawRadianWheel(context: &context, size: size, beat: beat)
        } else if waves.contains(sceneID) {
            drawUnitCircleWave(context: &context, size: size, beat: beat)
        } else {
            drawTriangulationTool(context: &context, size: size, beat: beat)
        }
    }

    private func drawSequenceAddressScale(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let arithmetic: Set<String> = ["constant-step-staircase", "n-minus-one-steps", "difference-ratio-and-offbyone", "paired-arithmetic-sum", "equal-stride-recall"]
        let geometric: Set<String> = ["constant-zoom-lens", "n-minus-one-multiplications", "geometric-middle-sign-trap", "shifted-geometric-sum", "constant-scale-recall"]
        let labels = arithmetic.contains(sceneID)
            ? ["a₁", "a₁+d", "a₁+2d", "…", "a₁+(n−1)d"]
            : geometric.contains(sceneID)
                ? ["a₁", "a₁r", "a₁r²", "…", "a₁rⁿ⁻¹"]
                : ["a₁", "a₂", "a₃", "…", "aₙ"]
        for (index, label) in labels.enumerated() {
            let width = index == 4 ? size.width * 0.22 : size.width * 0.14
            let x = size.width * 0.055 + CGFloat(index) * size.width * 0.185
            let height = geometric.contains(sceneID)
                ? size.height * (0.15 + CGFloat(index) * 0.025)
                : arithmetic.contains(sceneID)
                    ? size.height * (0.16 + CGFloat(index) * 0.035)
                    : size.height * 0.21
            let rect = CGRect(x: x, y: size.height * 0.66 - height, width: width, height: height)
            context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 4 ? Color.yellow.opacity(0.65) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 4 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
            context.draw(Text("\(index + 1)").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: size.height * 0.73))
            if index < labels.count - 1 {
                context.draw(
                    Text(arithmetic.contains(sceneID) ? "+d" : geometric.contains(sceneID) ? "×r" : "→")
                        .font(.mMicro.weight(.black)).foregroundStyle(Tokens.progressBlue),
                    at: CGPoint(x: rect.maxX + size.width * 0.022, y: size.height * 0.52)
                )
            }
        }
        let copy = arithmetic.contains(sceneID)
            ? "공차 d · 이동 n−1번 · 양끝 평균×n"
            : geometric.contains(sceneID)
                ? "공비 r · 통과 n−1번 · Sₙ과 rSₙ 밀어 빼기"
                : "n은 주소 · aₙ은 값 · Sₙ은 누적"
        context.draw(Text(copy).font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.87))
    }

    private func drawSummationCancellation(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let telescope: Set<String> = ["telescoping-zipper", "method-shape-question", "vanishing-endpoint-trap", "telescoping-sum-solution", "cancellation-fingerprint-recall"]
        if !telescope.contains(sceneID) {
            let cards = [("시작", "k=1"), ("끝", "n"), ("항식", "k²+2k+1"), ("출력", "Σ 항")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.05 + CGFloat(index) * 0.24), y: size.height * 0.34, width: size.width * 0.18, height: size.height * 0.30)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
                context.draw(Text(card.0).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.minY + 28))
                context.draw(Text(card.1).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY + 18))
            }
            context.draw(Text("항 수 = 끝−시작+1 · 합과 상수배만 선형 분리").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.84))
            return
        }
        let terms = ["1−1/2", "1/2−1/3", "1/3−1/4", "…", "1/n−1/(n+1)"]
        for (index, label) in terms.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.19), y: size.height * 0.37, width: size.width * 0.17, height: size.height * 0.20)
            context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 0 || index == 4 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 0 || index == 4 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
            if index > 0 && index < 4 {
                var slash = Path()
                slash.move(to: CGPoint(x: rect.minX + 8, y: rect.minY - 8))
                slash.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.maxY + 8))
                context.stroke(slash, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
            }
        }
        context.draw(Text("가운데 소거 → 1−1/(n+1) 경계만 남음").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.82))
    }

    private func drawRecurrenceMachine(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let nodes = [(0.07, 0.20, "씨앗", "a₁"), (0.36, 0.29, "레시피", "aₙ₊₁=f(aₙ)"), (0.75, 0.20, "다음 항", "aₙ₊₁")]
        for (index, node) in nodes.enumerated() {
            let rect = CGRect(x: size.width * node.0, y: size.height * 0.35, width: size.width * node.1, height: size.height * 0.30)
            context.fill(Path(roundedRect: rect, cornerRadius: 18), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 18), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(node.2).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.minY + 28))
            context.draw(Text(node.3).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY + 18))
            if index < 2 {
                var arrow = Path()
                arrow.move(to: CGPoint(x: rect.maxX + 6, y: rect.midY))
                arrow.addLine(to: CGPoint(x: rect.maxX + size.width * 0.07, y: rect.midY))
                context.stroke(arrow, with: .color(Tokens.progressBlue), lineWidth: 5)
            }
        }
        context.draw(Text("초기 상태 + 필요한 과거 항 + 전이 규칙").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.84))
    }

    private func drawInductionDominoes(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let labels = ["P(1)", "P(2)", "P(3)", "…", "P(k)", "P(k+1)"]
        for (index, label) in labels.enumerated() {
            let width = size.width * 0.095
            let x = size.width * (0.06 + CGFloat(index) * 0.155)
            let tilt = beat.action == "verify" && index < 3 ? CGFloat(10) : 0
            let rect = CGRect(x: x, y: size.height * 0.34 + tilt, width: width, height: size.height * 0.34)
            context.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(index == 0 || index >= 4 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(index == 0 || index >= 4 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(label).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
            if index < labels.count - 1 {
                var link = Path()
                link.move(to: CGPoint(x: rect.maxX + 5, y: rect.midY))
                link.addLine(to: CGPoint(x: rect.maxX + size.width * 0.055, y: rect.midY))
                context.stroke(link, with: .color(Tokens.progressBlue), lineWidth: 4)
            }
        }
        context.draw(Text("기초 P(1) + 임의의 k에서 P(k)⇒P(k+1)").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.84))
        if sceneID == "odd-sum-induction-solution" {
            context.draw(Text("k²+(2k+1)=(k+1)²").font(.mCallout.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.5, y: size.height * 0.22))
        }
    }

    private func drawAlgebraSequenceScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let addressAndScale: Set<String> = [
            "numbered-lockers", "term-rule-question", "index-value-confusion", "general-term-and-sum-solution", "address-map-recall",
            "constant-step-staircase", "n-minus-one-steps", "difference-ratio-and-offbyone", "paired-arithmetic-sum", "equal-stride-recall",
            "constant-zoom-lens", "n-minus-one-multiplications", "geometric-middle-sign-trap", "shifted-geometric-sum", "constant-scale-recall",
        ]
        let summation: Set<String> = [
            "summation-conveyor", "inclusive-count-question", "false-product-linearity", "sigma-polynomial-solution", "summation-command-recall",
            "telescoping-zipper", "method-shape-question", "vanishing-endpoint-trap", "telescoping-sum-solution", "cancellation-fingerprint-recall",
        ]
        let recurrence: Set<String> = ["starter-and-recipe", "required-history-question", "missing-initial-condition", "recursive-table-solution", "recipe-chain-recall"]
        if addressAndScale.contains(sceneID) {
            drawSequenceAddressScale(context: &context, size: size, beat: beat)
        } else if summation.contains(sceneID) {
            drawSummationCancellation(context: &context, size: size, beat: beat)
        } else if recurrence.contains(sceneID) {
            drawRecurrenceMachine(context: &context, size: size, beat: beat)
        } else {
            drawInductionDominoes(context: &context, size: size, beat: beat)
        }
    }

    private func probabilityCard(
        context: inout GraphicsContext,
        rect: CGRect,
        label: String,
        focused: Bool = false
    ) {
        context.fill(
            Path(roundedRect: rect, cornerRadius: 14),
            with: .color(focused ? Color.yellow.opacity(0.64) : Tokens.paper2)
        )
        context.stroke(
            Path(roundedRect: rect, cornerRadius: 14),
            with: .color(focused ? Tokens.warningInk : Tokens.lineStrong),
            lineWidth: 3
        )
        context.draw(
            Text(label).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink),
            at: CGPoint(x: rect.midX, y: rect.midY)
        )
    }

    private func drawProbabilityCounting(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let stars = sceneID.contains("star") || sceneID.contains("scoop") || sceneID.contains("share")
        let binomial = sceneID.contains("term") || sceneID.contains("coefficient") || sceneID.contains("binomial")
        let labels = stars
            ? ["★", "★", "|", "★", "|", "★", "★"]
            : binomial ? ["a", "b", "a", "b", "a"] : ["A", "A", "B", "B", "C"]
        let width = size.width * (labels.count == 7 ? 0.095 : 0.13)
        let gap = size.width * (labels.count == 7 ? 0.025 : 0.045)
        let total = CGFloat(labels.count) * width + CGFloat(labels.count - 1) * gap
        let start = (size.width - total) / 2
        for (index, label) in labels.enumerated() {
            let rect = CGRect(
                x: start + CGFloat(index) * (width + gap),
                y: size.height * 0.34,
                width: width,
                height: size.height * 0.24
            )
            probabilityCard(context: &context, rect: rect, label: label, focused: index < 2 || label == "|")
        }
        var underline = Path()
        underline.move(to: CGPoint(x: start, y: size.height * 0.67))
        underline.addCurve(
            to: CGPoint(x: start + total, y: size.height * 0.67),
            control1: CGPoint(x: size.width * 0.30, y: size.height * 0.84),
            control2: CGPoint(x: size.width * 0.70, y: size.height * 0.84)
        )
        context.stroke(underline, with: .color(Tokens.progressBlue), lineWidth: 4)
        context.draw(
            Text(stars ? "별은 값 · 막은 분배" : binomial ? "b 선택 횟수 = r" : "같은 것의 교환은 접기")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.84)
        )
    }

    private func drawProbabilitySets(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let space = CGRect(x: size.width * 0.08, y: size.height * 0.17, width: size.width * 0.84, height: size.height * 0.66)
        context.fill(Path(roundedRect: space, cornerRadius: 20), with: .color(Tokens.paper2))
        context.stroke(Path(roundedRect: space, cornerRadius: 20), with: .color(Tokens.lineStrong), lineWidth: 3)
        let complement = sceneID.contains("complement") || sceneID.contains("opposite") || sceneID.contains("exactly-one")
        let left = CGRect(x: size.width * 0.20, y: size.height * 0.27, width: size.width * 0.34, height: size.height * 0.42)
        let right = CGRect(x: size.width * 0.46, y: size.height * 0.27, width: size.width * 0.34, height: size.height * 0.42)
        context.fill(Path(ellipseIn: left), with: .color(Tokens.progressBlue.opacity(0.20)))
        context.stroke(Path(ellipseIn: left), with: .color(Tokens.progressBlue), lineWidth: 4)
        context.fill(Path(ellipseIn: right), with: .color(complement ? Color.yellow.opacity(0.42) : Color.green.opacity(0.18)))
        context.stroke(Path(ellipseIn: right), with: .color(complement ? Tokens.warningInk : Color.green), lineWidth: 4)
        context.draw(Text("A").font(.mTitle.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: left.midX - size.width * 0.06, y: left.minY + 30))
        context.draw(Text(complement ? "Aᶜ" : "B").font(.mTitle.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: right.midX + size.width * 0.06, y: right.minY + 30))
        context.draw(
            Text(complement ? "전체를 둘로 가르는 반대 사건" : "겹친 몫은 한 번만")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.87)
        )
    }

    private func drawProbabilityConditional(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let tree = sceneID.contains("tree") || sceneID.contains("path") || sceneID.contains("colors")
        if tree {
            let root = CGPoint(x: size.width * 0.12, y: size.height * 0.50)
            context.fill(Path(ellipseIn: CGRect(x: root.x - 12, y: root.y - 12, width: 24, height: 24)), with: .color(Color.yellow))
            for first in 0..<2 {
                let joint = CGPoint(x: size.width * 0.38, y: size.height * (first == 0 ? 0.30 : 0.70))
                var branch = Path()
                branch.move(to: root)
                branch.addLine(to: joint)
                context.stroke(branch, with: .color(first == 0 ? Tokens.progressBlue : Tokens.text3), lineWidth: first == 0 ? 6 : 3)
                context.draw(Text(first == 0 ? "A" : "Aᶜ").font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: joint.x, y: joint.y - 24))
                for second in 0..<2 {
                    let end = CGPoint(x: size.width * 0.82, y: joint.y + size.height * (second == 0 ? -0.12 : 0.12))
                    var child = Path()
                    child.move(to: joint)
                    child.addLine(to: end)
                    context.stroke(child, with: .color(first == 0 && second == 0 ? Tokens.warningInk : Tokens.text3.opacity(0.65)), lineWidth: first == 0 && second == 0 ? 6 : 3)
                    context.draw(Text(second == 0 ? "B | 앞선 길" : "Bᶜ | 앞선 길").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: end.x - size.width * 0.02, y: end.y - 18))
                }
            }
            context.draw(Text("경로 안 곱 · 도착 경로 사이 합").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.90))
            return
        }
        let outer = CGRect(x: size.width * 0.08, y: size.height * 0.18, width: size.width * 0.84, height: size.height * 0.64)
        let condition = CGRect(x: size.width * 0.28, y: size.height * 0.24, width: size.width * 0.55, height: size.height * 0.52)
        let intersection = CGRect(x: size.width * 0.48, y: size.height * 0.32, width: size.width * 0.24, height: size.height * 0.36)
        context.fill(Path(roundedRect: outer, cornerRadius: 18), with: .color(Tokens.paper2))
        context.stroke(Path(roundedRect: outer, cornerRadius: 18), with: .color(Tokens.lineStrong), lineWidth: 3)
        context.fill(Path(roundedRect: condition, cornerRadius: 16), with: .color(Tokens.progressBlue.opacity(0.18)))
        context.stroke(Path(roundedRect: condition, cornerRadius: 16), with: .color(Tokens.progressBlue), lineWidth: 4)
        context.fill(Path(roundedRect: intersection, cornerRadius: 14), with: .color(Color.yellow.opacity(0.68)))
        context.stroke(Path(roundedRect: intersection, cornerRadius: 14), with: .color(Tokens.warningInk), lineWidth: 3)
        context.draw(Text("전체 Ω").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: outer.minX + 54, y: outer.minY + 24))
        context.draw(Text("새 전체 B").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: condition.midX, y: condition.minY + 28))
        context.draw(Text("A∩B").font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: intersection.midX, y: intersection.midY))
    }

    private func drawProbabilityDistribution(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        var axes = Path()
        axes.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.78))
        axes.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.78))
        axes.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.78))
        axes.addLine(to: CGPoint(x: size.width * 0.10, y: size.height * 0.16))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)
        let heights: [CGFloat] = sceneID.contains("spread") ? [0.20, 0.30, 0.42, 0.30, 0.20] : [0.12, 0.27, 0.54, 0.27, 0.12]
        for (index, height) in heights.enumerated() {
            let rect = CGRect(
                x: size.width * (0.18 + CGFloat(index) * 0.15),
                y: size.height * (0.78 - height),
                width: size.width * 0.08,
                height: size.height * height
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(index == 2 ? Color.yellow.opacity(0.72) : Tokens.progressBlue.opacity(0.25)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 7), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 2)
        }
        var center = Path()
        center.move(to: CGPoint(x: size.width * 0.52, y: size.height * 0.12))
        center.addLine(to: CGPoint(x: size.width * 0.52, y: size.height * 0.84))
        context.stroke(center, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
        context.draw(Text("확률의 무게중심 μ").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.52, y: size.height * 0.90))
    }

    private func drawProbabilityNormal(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        var axis = Path()
        axis.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.78))
        axis.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.78))
        context.stroke(axis, with: .color(Tokens.text3), lineWidth: 3)
        let heights: [CGFloat] = [0.08, 0.20, 0.38, 0.52, 0.38, 0.20, 0.08]
        for (index, height) in heights.enumerated() {
            let rect = CGRect(x: size.width * (0.12 + CGFloat(index) * 0.11), y: size.height * (0.78 - height), width: size.width * 0.075, height: size.height * height)
            context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(Tokens.progressBlue.opacity(0.22)))
        }
        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.09, y: size.height * 0.77))
        curve.addCurve(
            to: CGPoint(x: size.width * 0.91, y: size.height * 0.77),
            control1: CGPoint(x: size.width * 0.30, y: size.height * 0.06),
            control2: CGPoint(x: size.width * 0.70, y: size.height * 0.06)
        )
        context.stroke(curve, with: .color(Color.green), lineWidth: 6)
        for x in [size.width * 0.45, size.width * 0.59] {
            var boundary = Path()
            boundary.move(to: CGPoint(x: x, y: size.height * 0.20))
            boundary.addLine(to: CGPoint(x: x, y: size.height * 0.82))
            context.stroke(boundary, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
        }
        context.draw(Text("정수 경계 ± 0.5").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.52, y: size.height * 0.90))
    }

    private func drawProbabilityInference(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let confidence = sceneID.contains("confidence") || sceneID.contains("interval") || sceneID.contains("estimation")
        var truth = Path()
        truth.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.12))
        truth.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.88))
        context.stroke(truth, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
        let centers: [CGFloat] = [0.44, 0.55, 0.38, 0.63, 0.49, 0.69]
        for (index, center) in centers.enumerated() {
            let y = size.height * (0.20 + CGFloat(index) * 0.11)
            if confidence {
                let half: CGFloat = [0.12, 0.14, 0.08, 0.17, 0.10, 0.07][index]
                var interval = Path()
                interval.move(to: CGPoint(x: size.width * (center - half), y: y))
                interval.addLine(to: CGPoint(x: size.width * (center + half), y: y))
                let hit = center - half <= 0.50 && center + half >= 0.50
                context.stroke(interval, with: .color(hit ? Color.green : Tokens.warningInk), lineWidth: 7)
            }
            context.fill(
                Path(ellipseIn: CGRect(x: size.width * center - 8, y: y - 8, width: 16, height: 16)),
                with: .color(Tokens.progressBlue)
            )
        }
        context.draw(
            Text(confidence ? "반복한 구간의 포함률" : "n↑ → 표본 통계량의 흔들림↓")
                .font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.93)
        )
    }

    private func drawProbabilityStatisticsScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if probabilityCountingSceneIDs.contains(sceneID) {
            drawProbabilityCounting(context: &context, size: size, beat: beat)
        } else if probabilitySetSceneIDs.contains(sceneID) {
            drawProbabilitySets(context: &context, size: size, beat: beat)
        } else if probabilityConditionalSceneIDs.contains(sceneID) {
            drawProbabilityConditional(context: &context, size: size, beat: beat)
        } else if probabilityDistributionSceneIDs.contains(sceneID) {
            drawProbabilityDistribution(context: &context, size: size, beat: beat)
        } else if probabilityNormalSceneIDs.contains(sceneID) {
            drawProbabilityNormal(context: &context, size: size, beat: beat)
        } else {
            drawProbabilityInference(context: &context, size: size, beat: beat)
        }
    }

    private func drawCalculusAxes(
        context: inout GraphicsContext,
        size: CGSize,
        vertical: CGFloat = 0.5,
        horizontal: CGFloat = 0.67
    ) {
        var axes = Path()
        axes.move(to: CGPoint(x: 34, y: size.height * horizontal))
        axes.addLine(to: CGPoint(x: size.width - 28, y: size.height * horizontal))
        axes.move(to: CGPoint(x: size.width * vertical, y: size.height - 22))
        axes.addLine(to: CGPoint(x: size.width * vertical, y: 48))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)
    }

    private func drawCalculusLimitApproach(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCalculusAxes(context: &context, size: size)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.31)
        var left = Path()
        left.move(to: CGPoint(x: size.width * 0.09, y: size.height * 0.74))
        left.addCurve(
            to: CGPoint(x: center.x - 24, y: center.y),
            control1: CGPoint(x: size.width * 0.24, y: size.height * 0.72),
            control2: CGPoint(x: size.width * 0.38, y: size.height * 0.39)
        )
        var right = Path()
        right.move(to: CGPoint(x: center.x + 24, y: center.y))
        right.addCurve(
            to: CGPoint(x: size.width * 0.91, y: size.height * 0.74),
            control1: CGPoint(x: size.width * 0.62, y: size.height * 0.39),
            control2: CGPoint(x: size.width * 0.76, y: size.height * 0.72)
        )
        context.stroke(left, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.stroke(right, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.stroke(
            Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)),
            with: .color(Tokens.warningInk), lineWidth: 4
        )
        let actual = CGPoint(x: center.x, y: size.height * 0.59)
        context.fill(
            Path(ellipseIn: CGRect(x: actual.x - 9, y: actual.y - 9, width: 18, height: 18)),
            with: .color(Color.yellow)
        )
        var arrows = Path()
        arrows.move(to: CGPoint(x: center.x - size.width * 0.19, y: center.y + 44))
        arrows.addLine(to: CGPoint(x: center.x - 30, y: center.y + 8))
        arrows.move(to: CGPoint(x: center.x + size.width * 0.19, y: center.y + 44))
        arrows.addLine(to: CGPoint(x: center.x + 30, y: center.y + 8))
        context.stroke(arrows, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
        context.draw(Text("x→a⁻").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: center.x - size.width * 0.24, y: center.y + 66))
        context.draw(Text("x→a⁺").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: center.x + size.width * 0.24, y: center.y + 66))
        context.draw(Text("L").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: center.x + 28, y: center.y - 18))
        context.draw(Text("f(a)").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: actual.x + 34, y: actual.y))
        if sceneID.contains("zero") || sceneID.contains("substitution") || sceneID.contains("factor") {
            let card = CGRect(x: size.width * 0.08, y: size.height * 0.13, width: size.width * 0.28, height: size.height * 0.16)
            context.fill(Path(roundedRect: card, cornerRadius: 14), with: .color(Color.yellow.opacity(0.60)))
            context.stroke(Path(roundedRect: card, cornerRadius: 14), with: .color(Tokens.warningInk), lineWidth: 3)
            context.draw(Text(sceneID.contains("factor") ? "인수분해 → 약분" : "0/0 = 정리 신호").font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: card.midX, y: card.midY))
        }
    }

    private func drawCalculusContinuity(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCalculusAxes(context: &context, size: size, vertical: 0.22, horizontal: 0.72)
        let mountainIDs: Set<String> = [
            "continuous-mountain-trail", "root-between-endpoints", "sign-change-needs-continuity",
            "closed-interval-extrema", "continuity-guarantees",
        ]
        if mountainIDs.contains(sceneID) {
            var mountain = Path()
            mountain.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.72))
            mountain.addCurve(
                to: CGPoint(x: size.width * 0.92, y: size.height * 0.37),
                control1: CGPoint(x: size.width * 0.30, y: size.height * 0.78),
                control2: CGPoint(x: size.width * 0.47, y: size.height * 0.10)
            )
            context.stroke(mountain, with: .color(Tokens.progressBlue), lineWidth: 6)
            var level = Path()
            level.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.49))
            level.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.49))
            context.stroke(level, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            context.draw(Text("중간 높이 k").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.80, y: size.height * 0.45))
            context.draw(Text("닫힌구간: 끝점도 후보").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.87))
            return
        }
        let disconnected = sceneID == "defined-is-not-continuous"
        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.72))
        curve.addCurve(
            to: CGPoint(x: size.width * (disconnected ? 0.47 : 0.92), y: size.height * (disconnected ? 0.36 : 0.23)),
            control1: CGPoint(x: size.width * 0.28, y: size.height * 0.68),
            control2: CGPoint(x: size.width * 0.45, y: size.height * 0.42)
        )
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        if disconnected {
            var right = Path()
            right.move(to: CGPoint(x: size.width * 0.55, y: size.height * 0.54))
            right.addCurve(to: CGPoint(x: size.width * 0.92, y: size.height * 0.23), control1: CGPoint(x: size.width * 0.67, y: size.height * 0.46), control2: CGPoint(x: size.width * 0.82, y: size.height * 0.29))
            context.stroke(right, with: .color(Tokens.progressBlue), lineWidth: 6)
        }
        let gates = [("정의", 0.17), ("좌=우", 0.43), ("극한=점", 0.71)]
        for (index, gate) in gates.enumerated() {
            let rect = CGRect(x: size.width * gate.1, y: size.height * 0.78, width: size.width * 0.20, height: size.height * 0.12)
            context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 2 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 2 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(gate.0).font(.mMicro.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    private func drawCalculusDerivativeDefinition(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCalculusAxes(context: &context, size: size, vertical: 0.16, horizontal: 0.75)
        let cornerIDs: Set<String> = ["road-with-a-corner", "continuity-or-differentiability", "reverse-arrow-error", "piecewise-smooth-join", "one-way-smoothness"]
        if cornerIDs.contains(sceneID) {
            var road = Path()
            road.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.70))
            road.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.25))
            road.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.66))
            context.stroke(road, with: .color(Tokens.progressBlue), lineWidth: 7)
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.50 - 11, y: size.height * 0.25 - 11, width: 22, height: 22)), with: .color(Color.yellow))
            context.draw(Text("이어짐").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.28, y: size.height * 0.80))
            context.draw(Text("좌기울기 ≠ 우기울기").font(.mCallout.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.68, y: size.height * 0.80))
            return
        }
        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.74))
        curve.addCurve(to: CGPoint(x: size.width * 0.92, y: size.height * 0.22), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.70), control2: CGPoint(x: size.width * 0.64, y: size.height * 0.16))
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        let a = CGPoint(x: size.width * 0.40, y: size.height * 0.56)
        let b = CGPoint(x: beat.action == "verify" ? size.width * 0.48 : size.width * 0.75, y: beat.action == "verify" ? size.height * 0.50 : size.height * 0.25)
        var secant = Path()
        secant.move(to: CGPoint(x: a.x - size.width * 0.12, y: a.y + size.height * 0.12))
        secant.addLine(to: CGPoint(x: b.x + size.width * 0.12, y: b.y - size.height * 0.12))
        context.stroke(secant, with: .color(Tokens.warningInk), lineWidth: 5)
        for point in [a, b] {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(Color.yellow))
        }
        context.draw(Text("h→0 : 할선 → 접선").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.62, y: size.height * 0.86))
    }

    private func drawCalculusDerivativeRule(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let meanValueIDs: Set<String> = ["average-speed-moment", "parabola-mean-value", "mean-value-condition-gap", "derivative-bound-change", "mean-value-bridge"]
        let tangentIDs: Set<String> = ["tangent-point-direction", "parabola-tangent-at-one", "tangent-through-origin-error", "cubic-tangent-example", "tangent-two-clues"]
        if meanValueIDs.contains(sceneID) || tangentIDs.contains(sceneID) {
            drawCalculusAxes(context: &context, size: size, vertical: 0.14, horizontal: 0.75)
            var curve = Path()
            curve.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.72))
            curve.addCurve(to: CGPoint(x: size.width * 0.92, y: size.height * 0.28), control1: CGPoint(x: size.width * 0.28, y: size.height * 0.72), control2: CGPoint(x: size.width * 0.58, y: size.height * 0.10))
            context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
            var first = Path()
            first.move(to: CGPoint(x: size.width * 0.16, y: size.height * 0.70))
            first.addLine(to: CGPoint(x: size.width * 0.87, y: size.height * 0.25))
            context.stroke(first, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: meanValueIDs.contains(sceneID) ? [9, 7] : []))
            if meanValueIDs.contains(sceneID) {
                var parallel = Path()
                parallel.move(to: CGPoint(x: size.width * 0.39, y: size.height * 0.50))
                parallel.addLine(to: CGPoint(x: size.width * 0.68, y: size.height * 0.32))
                context.stroke(parallel, with: .color(Tokens.progressBlue), lineWidth: 5)
                context.draw(Text("할선 ∥ 내부 접선").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.55, y: size.height * 0.84))
            } else {
                context.draw(Text("점 (a,f(a)) + 방향 f′(a)").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.55, y: size.height * 0.84))
            }
            return
        }
        let productIDs: Set<String> = ["polynomial-change-parts", "termwise-polynomial", "product-of-derivatives-error", "polynomial-product-example", "polynomial-derivative-map"]
        let cards = productIDs.contains(sceneID)
            ? [("f·g", "원래 곱"), ("f′g", "첫째 변화"), ("fg′", "둘째 변화"), ("더하기", "결과")]
            : [("xⁿ", "원래 층"), ("n", "앞으로"), ("n−1", "한 칸 아래"), ("nxⁿ⁻¹", "도함수")]
        for (index, card) in cards.enumerated() {
            let width = size.width * 0.19
            let rect = CGRect(x: size.width * (0.055 + CGFloat(index) * 0.235), y: size.height * 0.35, width: width, height: size.height * 0.28)
            context.fill(Path(roundedRect: rect, cornerRadius: 14), with: .color(index == 1 || index == 2 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 14), with: .color(index == 1 || index == 2 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(card.0).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY - 14))
            context.draw(Text(card.1).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.midY + 24))
        }
        context.draw(Text(productIDs.contains(sceneID) ? "한쪽씩 변한 두 효과를 더합니다" : "지수를 내리고 한 칸 낮춥니다").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.82))
    }

    private func drawCalculusDerivativeGraph(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let motionIDs: Set<String> = ["motion-three-gauges", "motion-direction-times", "acceleration-direction-error", "motion-distance-example", "motion-derivative-chain"]
        if motionIDs.contains(sceneID) {
            let rows = [("위치 s", "현재 장소"), ("속도 v=s′", "진행 방향"), ("가속도 a=v′", "속도 변화")]
            for (index, row) in rows.enumerated() {
                let rect = CGRect(x: size.width * 0.12, y: size.height * (0.18 + CGFloat(index) * 0.22), width: size.width * 0.76, height: size.height * 0.16)
                context.fill(Path(roundedRect: rect, cornerRadius: 14), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 14), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
                context.draw(Text(row.0).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.minX + size.width * 0.20, y: rect.midY))
                context.draw(Text(row.1).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.maxX - size.width * 0.18, y: rect.midY))
            }
            context.draw(Text("v=0에서 시간축을 나눠 거리 계산").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.88))
            return
        }
        drawCalculusAxes(context: &context, size: size, vertical: 0.11, horizontal: 0.68)
        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.64))
        curve.addCurve(to: CGPoint(x: size.width * 0.48, y: size.height * 0.46), control1: CGPoint(x: size.width * 0.22, y: size.height * 0.22), control2: CGPoint(x: size.width * 0.34, y: size.height * 0.20))
        curve.addCurve(to: CGPoint(x: size.width * 0.92, y: size.height * 0.20), control1: CGPoint(x: size.width * 0.62, y: size.height * 0.82), control2: CGPoint(x: size.width * 0.78, y: size.height * 0.72))
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        let turns = [(0.32, 0.25, "+ → −", "극대"), (0.66, 0.68, "− → +", "극소")]
        for turn in turns {
            let point = CGPoint(x: size.width * turn.0, y: size.height * turn.1)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20)), with: .color(Color.yellow))
            var guide = Path()
            guide.move(to: CGPoint(x: point.x, y: size.height * 0.13))
            guide.addLine(to: CGPoint(x: point.x, y: size.height * 0.83))
            context.stroke(guide, with: .color(Tokens.warningInk.opacity(0.72)), style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            context.draw(Text(turn.2).font(.mMicro.weight(.black)).foregroundStyle(Tokens.text2), at: CGPoint(x: point.x, y: size.height * 0.87))
            context.draw(Text(turn.3).font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: point.x, y: point.y - 25))
        }
        context.draw(Text("f=0: 교점 · f′=0: 전환 후보").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.70, y: size.height * 0.10))
    }

    private func drawCalculusAntiderivative(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let cards = [("도함수", "f(x)"), ("되감기", "∫ dx"), ("원시함수", "F(x)+C")]
        for (index, card) in cards.enumerated() {
            let rect = CGRect(x: size.width * (0.08 + CGFloat(index) * 0.31), y: size.height * 0.30, width: size.width * 0.24, height: size.height * 0.28)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            context.draw(Text(card.0).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2), at: CGPoint(x: rect.midX, y: rect.midY - 18))
            context.draw(Text(card.1).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: rect.midX, y: rect.midY + 22))
        }
        for index in 0..<3 {
            var curve = Path()
            curve.move(to: CGPoint(x: size.width * 0.55, y: size.height * (0.70 + CGFloat(index) * 0.05)))
            curve.addCurve(to: CGPoint(x: size.width * 0.88, y: size.height * (0.66 + CGFloat(index) * 0.05)), control1: CGPoint(x: size.width * 0.66, y: size.height * (0.57 + CGFloat(index) * 0.05)), control2: CGPoint(x: size.width * 0.77, y: size.height * (0.57 + CGFloat(index) * 0.05)))
            context.stroke(curve, with: .color(index == 1 ? Tokens.progressBlue : Tokens.text3.opacity(0.55)), lineWidth: index == 1 ? 5 : 3)
        }
        context.draw(Text(sceneID.contains("power") || sceneID.contains("integrate") ? "지수 +1 → 새 지수로 나눔" : "+C는 세로 위치가 다른 함수 가족").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.88))
    }

    private func drawCalculusAccumulation(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCalculusAxes(context: &context, size: size, vertical: 0.10, horizontal: 0.58)
        let points = [
            CGPoint(x: size.width * 0.10, y: size.height * 0.58),
            CGPoint(x: size.width * 0.25, y: size.height * 0.32),
            CGPoint(x: size.width * 0.42, y: size.height * 0.24),
            CGPoint(x: size.width * 0.58, y: size.height * 0.64),
            CGPoint(x: size.width * 0.72, y: size.height * 0.76),
            CGPoint(x: size.width * 0.90, y: size.height * 0.38),
        ]
        var positive = Path()
        positive.move(to: points[0])
        positive.addLine(to: points[1])
        positive.addLine(to: points[2])
        positive.addLine(to: CGPoint(x: points[3].x, y: size.height * 0.58))
        positive.closeSubpath()
        context.fill(positive, with: .color(Tokens.progressBlue.opacity(0.20)))
        var negative = Path()
        negative.move(to: CGPoint(x: points[3].x, y: size.height * 0.58))
        negative.addLine(to: points[3])
        negative.addLine(to: points[4])
        negative.addLine(to: CGPoint(x: size.width * 0.82, y: size.height * 0.58))
        negative.closeSubpath()
        context.fill(negative, with: .color(Tokens.warningInk.opacity(0.20)))
        var curve = Path()
        curve.move(to: points[0])
        for point in points.dropFirst() { curve.addLine(to: point) }
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.draw(Text("+ 누적").font(.mMicro.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.35, y: size.height * 0.45))
        context.draw(Text("− 누적").font(.mMicro.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.70, y: size.height * 0.69))
        if ["accumulation-endpoint-difference", "evaluate-linear-integral", "endpoint-order-error", "evaluate-polynomial-integral", "fundamental-link-memory"].contains(sceneID) {
            let card = CGRect(x: size.width * 0.24, y: size.height * 0.10, width: size.width * 0.52, height: size.height * 0.14)
            context.fill(Path(roundedRect: card, cornerRadius: 14), with: .color(Color.yellow.opacity(0.62)))
            context.stroke(Path(roundedRect: card, cornerRadius: 14), with: .color(Tokens.warningInk), lineWidth: 3)
            context.draw(Text("∫ₐᵇ f(x)dx = F(b) − F(a)").font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink), at: CGPoint(x: card.midX, y: card.midY))
        }
    }

    private func drawCalculusAreaMotion(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        drawCalculusAxes(context: &context, size: size, vertical: 0.10, horizontal: 0.66)
        let velocityIDs: Set<String> = ["velocity-signed-area", "velocity-crosses-zero", "displacement-equals-distance-error", "round-trip-from-velocity", "velocity-integral-memory"]
        if velocityIDs.contains(sceneID) {
            var curve = Path()
            curve.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.66))
            curve.addCurve(to: CGPoint(x: size.width * 0.50, y: size.height * 0.66), control1: CGPoint(x: size.width * 0.24, y: size.height * 0.20), control2: CGPoint(x: size.width * 0.38, y: size.height * 0.24))
            curve.addCurve(to: CGPoint(x: size.width * 0.90, y: size.height * 0.66), control1: CGPoint(x: size.width * 0.62, y: size.height * 0.94), control2: CGPoint(x: size.width * 0.78, y: size.height * 0.88))
            context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
            context.draw(Text("∫v = 변위").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.30, y: size.height * 0.42))
            context.draw(Text("∫|v| = 거리").font(.mCallout.weight(.black)).foregroundStyle(Tokens.warningInk), at: CGPoint(x: size.width * 0.70, y: size.height * 0.84))
            return
        }
        var top = Path()
        top.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.66))
        top.addCurve(to: CGPoint(x: size.width * 0.90, y: size.height * 0.40), control1: CGPoint(x: size.width * 0.34, y: size.height * 0.18), control2: CGPoint(x: size.width * 0.62, y: size.height * 0.16))
        var bottom = Path()
        bottom.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.72))
        bottom.addCurve(to: CGPoint(x: size.width * 0.90, y: size.height * 0.22), control1: CGPoint(x: size.width * 0.38, y: size.height * 0.66), control2: CGPoint(x: size.width * 0.65, y: size.height * 0.42))
        context.stroke(top, with: .color(Tokens.progressBlue), lineWidth: 6)
        context.stroke(bottom, with: .color(Tokens.warningInk), lineWidth: 5)
        for index in 0..<7 {
            let x = size.width * (0.18 + CGFloat(index) * 0.10)
            var strip = Path()
            strip.move(to: CGPoint(x: x, y: size.height * (0.32 + CGFloat(abs(3 - index)) * 0.035)))
            strip.addLine(to: CGPoint(x: x, y: size.height * (0.65 - CGFloat(index) * 0.045)))
            context.stroke(strip, with: .color(Color.yellow.opacity(0.75)), lineWidth: 11)
        }
        context.draw(Text("띠 높이 = 위 함수 − 아래 함수").font(.mCallout.weight(.black)).foregroundStyle(Tokens.progressBlue), at: CGPoint(x: size.width * 0.5, y: size.height * 0.87))
    }

    private func drawCalculusOneScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if calculusLimitApproachSceneIDs.contains(sceneID) {
            drawCalculusLimitApproach(context: &context, size: size, beat: beat)
        } else if calculusContinuitySceneIDs.contains(sceneID) {
            drawCalculusContinuity(context: &context, size: size, beat: beat)
        } else if calculusDerivativeDefinitionSceneIDs.contains(sceneID) {
            drawCalculusDerivativeDefinition(context: &context, size: size, beat: beat)
        } else if calculusDerivativeRuleSceneIDs.contains(sceneID) {
            drawCalculusDerivativeRule(context: &context, size: size, beat: beat)
        } else if calculusDerivativeGraphSceneIDs.contains(sceneID) {
            drawCalculusDerivativeGraph(context: &context, size: size, beat: beat)
        } else if calculusAntiderivativeSceneIDs.contains(sceneID) {
            drawCalculusAntiderivative(context: &context, size: size, beat: beat)
        } else if calculusAccumulationSceneIDs.contains(sceneID) {
            drawCalculusAccumulation(context: &context, size: size, beat: beat)
        } else {
            drawCalculusAreaMotion(context: &context, size: size, beat: beat)
        }
    }

    private func geometryLabel(
        _ text: String,
        at point: CGPoint,
        color: Color,
        context: inout GraphicsContext
    ) {
        context.draw(
            Text(text)
                .font(.mCallout.weight(.black))
                .foregroundStyle(color),
            at: point
        )
    }

    private func geometryPoint(
        _ point: CGPoint,
        emphasized: Bool = false,
        context: inout GraphicsContext
    ) {
        let radius: CGFloat = emphasized ? 10 : 8
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(emphasized ? Color.yellow : Tokens.primarySoft)
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(emphasized ? Tokens.warningInk : Tokens.progressBlue),
            lineWidth: 2
        )
    }

    private func geometryLine(
        _ points: [CGPoint],
        color: Color = Tokens.progressBlue,
        dashed: Bool = false,
        context: inout GraphicsContext
    ) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: dashed ? 3 : 5, dash: dashed ? [8, 6] : [])
        )
    }

    private func drawPracticalInquiry(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if practicalVariationSceneIDs.contains(sceneID) {
            let rows: [(CGFloat, String, [CGFloat])] = [
                (size.height * 0.34, "노선 A", [0.28, 0.34, 0.40, 0.46, 0.52, 0.58, 0.64]),
                (size.height * 0.64, "노선 B", [0.22, 0.31, 0.40, 0.50, 0.61, 0.72, 0.83]),
            ]
            for (rowIndex, row) in rows.enumerated() {
                geometryLabel(row.1, at: CGPoint(x: size.width * 0.12, y: row.0), color: Tokens.text2, context: &context)
                for (index, fraction) in row.2.enumerated() {
                    let point = CGPoint(
                        x: size.width * fraction,
                        y: row.0 + CGFloat((index % 3) - 1) * CGFloat(rowIndex == 0 ? 5 : 11)
                    )
                    geometryPoint(point, emphasized: rowIndex == 0, context: &context)
                }
            }
            geometryLabel("중심만 말고 흔들림까지 비교", at: CGPoint(x: size.width * 0.57, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
            return
        }

        let reverse = sceneID.contains("rewind") || sceneID.contains("audit") || sceneID.contains("reflection")
        let labels = reverse ? ["결론", "분석", "자료", "질문"] : ["질문", "자료", "분석", "결정"]
        let cardWidth = size.width * 0.18
        for (index, label) in labels.enumerated() {
            let rect = CGRect(
                x: size.width * 0.05 + CGFloat(index) * size.width * 0.24,
                y: size.height * 0.34,
                width: cardWidth,
                height: size.height * 0.28
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 0 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 0 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
            geometryLabel(String(index + 1), at: CGPoint(x: rect.minX + 22, y: rect.minY + 22), color: Tokens.text3, context: &context)
            geometryLabel(label, at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
            if index < labels.count - 1 {
                geometryLine(
                    [CGPoint(x: rect.maxX + 6, y: rect.midY), CGPoint(x: rect.maxX + size.width * 0.055, y: rect.midY)],
                    color: reverse ? Tokens.text3 : Tokens.progressBlue,
                    dashed: reverse,
                    context: &context
                )
            }
        }
        geometryLabel(
            reverse ? "결론에서 질문까지 거꾸로 근거 확인" : "방법보다 질문이 먼저 · 결정 기준은 미리",
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.84),
            color: Tokens.progressBlue,
            context: &context
        )
    }

    private func drawPracticalDataDesign(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if practicalScaleSceneIDs.contains(sceneID) {
            let scales: [(String, String)] = [("명목", "분류"), ("서열", "순서"), ("등간", "차이"), ("비율", "비율")]
            let cardWidth = size.width * 0.18
            for (index, scale) in scales.enumerated() {
                let rect = CGRect(x: size.width * 0.05 + CGFloat(index) * size.width * 0.24, y: size.height * 0.28, width: cardWidth, height: size.height * 0.38)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: 3)
                geometryLabel(scale.0, at: CGPoint(x: rect.midX, y: rect.midY - 20), color: Tokens.ink, context: &context)
                geometryLabel("허용: \(scale.1)", at: CGPoint(x: rect.midX, y: rect.midY + 22), color: Tokens.text2, context: &context)
            }
            geometryLabel("숫자 모양보다 척도가 허용하는 계산", at: CGPoint(x: size.width * 0.5, y: size.height * 0.84), color: Tokens.progressBlue, context: &context)
            return
        }

        let lenses: [(String, String)] = [("관찰", "있는 그대로"), ("설문", "기억·표현"), ("실험", "원인 비교")]
        for (index, lens) in lenses.enumerated() {
            let center = CGPoint(x: size.width * (0.20 + CGFloat(index) * 0.30), y: size.height * 0.48)
            let circle = CGRect(x: center.x - 54, y: center.y - 54, width: 108, height: 108)
            context.fill(Path(ellipseIn: circle), with: .color(index == 2 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(ellipseIn: circle), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 4)
            geometryLabel(lens.0, at: CGPoint(x: center.x, y: center.y - 13), color: Tokens.ink, context: &context)
            geometryLabel(lens.1, at: CGPoint(x: center.x, y: center.y + 22), color: Tokens.text2, context: &context)
        }
        geometryLabel(
            sceneID.contains("leading") ? "유도 질문·회상 편향부터 제거" : "설명인가, 원인인가에 맞춰 렌즈 선택",
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.84),
            color: Tokens.progressBlue,
            context: &context
        )
    }

    private func drawPracticalDescriptive(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if practicalGraphSceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.78), CGPoint(x: size.width * 0.90, y: size.height * 0.78)], color: Tokens.text3, context: &context)
            let heights: [CGFloat] = [0.20, 0.36, 0.52, 0.31, 0.45]
            for (index, height) in heights.enumerated() {
                let rect = CGRect(x: size.width * (0.17 + CGFloat(index) * 0.14), y: size.height * (0.78 - height), width: size.width * 0.075, height: size.height * height)
                context.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(index == 2 ? Color.yellow.opacity(0.68) : Tokens.primarySoft))
                context.stroke(Path(roundedRect: rect, cornerRadius: 7), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            }
            geometryLabel(
                sceneID == "cropped-axis-distortion" ? "0을 자르면 차이가 과장됨" : "질문에 맞는 그래프 · 축과 단위 공개",
                at: CGPoint(x: size.width * 0.5, y: size.height * 0.88),
                color: Tokens.progressBlue,
                context: &context
            )
            return
        }

        let rows: [(CGFloat, String, [CGFloat])] = [
            (0.35, "배달 A", [0.31, 0.36, 0.41, 0.46, 0.51, 0.56, 0.61, 0.66, 0.71]),
            (0.66, "배달 B", [0.20, 0.29, 0.38, 0.47, 0.56, 0.65, 0.74, 0.83]),
        ]
        for (rowIndex, row) in rows.enumerated() {
            geometryLabel(row.1, at: CGPoint(x: size.width * 0.11, y: size.height * row.0), color: Tokens.text2, context: &context)
            for fraction in row.2 {
                geometryPoint(CGPoint(x: size.width * fraction, y: size.height * row.0), emphasized: rowIndex == 0, context: &context)
            }
            geometryLine([CGPoint(x: size.width * 0.52, y: size.height * (row.0 - 0.09)), CGPoint(x: size.width * 0.52, y: size.height * (row.0 + 0.09))], color: Tokens.text3, dashed: true, context: &context)
        }
        geometryLabel("평균은 같아도 흩어짐은 다름", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
    }

    private func drawPracticalDistribution(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        geometryLine([CGPoint(x: size.width * 0.08, y: size.height * 0.78), CGPoint(x: size.width * 0.92, y: size.height * 0.78)], color: Tokens.text3, context: &context)
        var normal = Path()
        normal.move(to: CGPoint(x: size.width * 0.09, y: size.height * 0.77))
        normal.addCurve(to: CGPoint(x: size.width * 0.50, y: size.height * 0.22), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.76), control2: CGPoint(x: size.width * 0.35, y: size.height * 0.22))
        normal.addCurve(to: CGPoint(x: size.width * 0.91, y: size.height * 0.77), control1: CGPoint(x: size.width * 0.65, y: size.height * 0.22), control2: CGPoint(x: size.width * 0.70, y: size.height * 0.76))
        context.stroke(normal, with: .color(Tokens.progressBlue), lineWidth: 6)
        var studentT = Path()
        studentT.move(to: CGPoint(x: size.width * 0.09, y: size.height * 0.72))
        studentT.addCurve(to: CGPoint(x: size.width * 0.50, y: size.height * 0.33), control1: CGPoint(x: size.width * 0.28, y: size.height * 0.67), control2: CGPoint(x: size.width * 0.37, y: size.height * 0.33))
        studentT.addCurve(to: CGPoint(x: size.width * 0.91, y: size.height * 0.72), control1: CGPoint(x: size.width * 0.63, y: size.height * 0.33), control2: CGPoint(x: size.width * 0.72, y: size.height * 0.67))
        context.stroke(studentT, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
        geometryLabel("정규분포", at: CGPoint(x: size.width * 0.50, y: size.height * 0.15), color: Tokens.progressBlue, context: &context)
        geometryLabel("t분포: 꼬리가 더 두꺼움", at: CGPoint(x: size.width * 0.70, y: size.height * 0.66), color: Tokens.warningInk, context: &context)
        geometryLabel("표본이 작고 σ를 모르면 t", at: CGPoint(x: size.width * 0.5, y: size.height * 0.89), color: Tokens.ink, context: &context)
    }

    private func drawPracticalInterval(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let parameter = sceneID.contains("proportion") ? "모비율 p" : "모평균 μ"
        let centerX = size.width * 0.51
        geometryLine([CGPoint(x: centerX, y: size.height * 0.13), CGPoint(x: centerX, y: size.height * 0.82)], color: Tokens.text3, dashed: true, context: &context)
        geometryLabel(parameter, at: CGPoint(x: centerX, y: size.height * 0.10), color: Tokens.ink, context: &context)
        let intervals: [(CGFloat, CGFloat)] = [(0.30, 0.62), (0.38, 0.59), (0.44, 0.56), (0.53, 0.73), (0.61, 0.82), (0.68, 0.88)]
        for (index, interval) in intervals.enumerated() {
            let y = size.height * (0.23 + CGFloat(index) * 0.10)
            let hit = interval.0 <= 0.51 && interval.1 >= 0.51
            geometryLine(
                [CGPoint(x: size.width * interval.0, y: y), CGPoint(x: size.width * interval.1, y: y)],
                color: hit ? Tokens.progressBlue : Tokens.warningInk,
                context: &context
            )
            geometryPoint(CGPoint(x: size.width * ((interval.0 + interval.1) / 2), y: y), emphasized: hit, context: &context)
        }
        geometryLabel(
            beat.action == "verify" ? "반복 표본의 구간들이 참값을 덮는 비율" : "추정값 ± 오차한계",
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.90),
            color: Tokens.progressBlue,
            context: &context
        )
    }

    private func drawPracticalHypothesis(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        geometryLine([CGPoint(x: size.width * 0.08, y: size.height * 0.79), CGPoint(x: size.width * 0.92, y: size.height * 0.79)], color: Tokens.text3, context: &context)
        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.09, y: size.height * 0.78))
        curve.addCurve(to: CGPoint(x: size.width * 0.50, y: size.height * 0.24), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.77), control2: CGPoint(x: size.width * 0.36, y: size.height * 0.24))
        curve.addCurve(to: CGPoint(x: size.width * 0.91, y: size.height * 0.78), control1: CGPoint(x: size.width * 0.64, y: size.height * 0.24), control2: CGPoint(x: size.width * 0.70, y: size.height * 0.77))
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        let tail = CGRect(x: size.width * 0.74, y: size.height * 0.46, width: size.width * 0.16, height: size.height * 0.33)
        context.fill(Path(roundedRect: tail, cornerRadius: 8), with: .color(Color.yellow.opacity(0.48)))
        context.stroke(Path(roundedRect: tail, cornerRadius: 8), with: .color(Tokens.warningInk), lineWidth: 3)
        geometryPoint(CGPoint(x: size.width * 0.79, y: size.height * 0.64), emphasized: true, context: &context)
        geometryLabel("H₀가 맞는 세계", at: CGPoint(x: size.width * 0.5, y: size.height * 0.16), color: Tokens.ink, context: &context)
        geometryLabel("관측값보다 극단적인 꼬리 = p값", at: CGPoint(x: size.width * 0.68, y: size.height * 0.89), color: Tokens.progressBlue, context: &context)
        if beat.action == "verify" {
            geometryLabel("p≤α일 때만 H₀ 기각", at: CGPoint(x: size.width * 0.27, y: size.height * 0.33), color: Tokens.warningInk, context: &context)
        }
    }

    private func drawPracticalStatisticsScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if practicalVariationSceneIDs.contains(sceneID) || practicalInquirySceneIDs.contains(sceneID) {
            drawPracticalInquiry(context: &context, size: size, beat: beat)
        } else if practicalSamplingSceneIDs.contains(sceneID) {
            drawProbabilityInference(context: &context, size: size, beat: beat)
        } else if practicalIntervalSceneIDs.contains(sceneID) {
            drawPracticalInterval(context: &context, size: size, beat: beat)
        } else if practicalScaleSceneIDs.contains(sceneID) || practicalCollectionSceneIDs.contains(sceneID) {
            drawPracticalDataDesign(context: &context, size: size, beat: beat)
        } else if practicalGraphSceneIDs.contains(sceneID) || practicalCenterSpreadSceneIDs.contains(sceneID) {
            drawPracticalDescriptive(context: &context, size: size, beat: beat)
        } else if practicalNormalTSceneIDs.contains(sceneID) {
            drawPracticalDistribution(context: &context, size: size, beat: beat)
        } else {
            drawPracticalHypothesis(context: &context, size: size, beat: beat)
        }
    }

    private func drawEconomicsFinance(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if economicsIndexSceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.10, y: size.height * 0.80), CGPoint(x: size.width * 0.91, y: size.height * 0.80)], color: Tokens.text3, context: &context)
            let values: [CGFloat] = [100, 118, 132, 140]
            for (index, value) in values.enumerated() {
                let height = size.height * value / 230
                let rect = CGRect(x: size.width * (0.17 + CGFloat(index) * 0.19), y: size.height * 0.80 - height, width: size.width * 0.10, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 0 || index == 3 ? Color.yellow.opacity(0.68) : Tokens.primarySoft))
                context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 0 || index == 3 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(String(Int(value)), at: CGPoint(x: rect.midX, y: rect.minY - 16), color: Tokens.ink, context: &context)
            }
            geometryLabel("기준시점 = 100", at: CGPoint(x: size.width * 0.72, y: size.height * 0.32), color: Tokens.warningInk, context: &context)
            geometryLabel("수준 · 변화량 · 변화율 · 기준시점", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        if economicsExchangeSceneIDs.contains(sceneID) {
            let cards: [(String, String)] = [("1 USD", "₩1,350"), ("100 USD", "₩135,000")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.12 + CGFloat(index) * 0.50), y: size.height * 0.30, width: size.width * 0.27, height: size.height * 0.34)
                context.fill(Path(roundedRect: rect, cornerRadius: 18), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 18), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.text2, context: &context)
                geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.ink, context: &context)
            }
            geometryLine([CGPoint(x: size.width * 0.42, y: size.height * 0.47), CGPoint(x: size.width * 0.59, y: size.height * 0.47)], color: Tokens.progressBlue, context: &context)
            geometryLabel("달러 × (원/달러) = 원", at: CGPoint(x: size.width * 0.5, y: size.height * 0.82), color: Tokens.progressBlue, context: &context)
            geometryLabel("단위 화살표를 먼저 맞춘다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.text2, context: &context)
            return
        }

        if economicsTaxSceneIDs.contains(sceneID) {
            let boxes: [(String, String)] = [("과세표준", "3,000"), ("세율 규칙", "구간별"), ("세액", "합산")]
            for (index, box) in boxes.enumerated() {
                let rect = CGRect(x: size.width * (0.04 + CGFloat(index) * 0.32), y: size.height * 0.31, width: size.width * 0.25, height: size.height * 0.32)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(box.0, at: CGPoint(x: rect.midX, y: rect.midY - 20), color: Tokens.text2, context: &context)
                geometryLabel(box.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.ink, context: &context)
            }
            geometryLabel("전체 금액 × 마지막 세율이 아니다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.82), color: Tokens.warningInk, context: &context)
            geometryLabel("표준 → 구간 규칙 → 세액", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        let annuity = economicsAnnuitySceneIDs.contains(sceneID)
        geometryLine([CGPoint(x: size.width * 0.10, y: size.height * 0.60), CGPoint(x: size.width * 0.90, y: size.height * 0.60)], color: Tokens.text3, context: &context)
        for period in 0..<4 {
            let x = size.width * (0.14 + CGFloat(period) * 0.23)
            geometryLine([CGPoint(x: x, y: size.height * 0.54), CGPoint(x: x, y: size.height * 0.66)], color: Tokens.text3, context: &context)
            geometryLabel("t=\(period)", at: CGPoint(x: x, y: size.height * 0.72), color: Tokens.text2, context: &context)
            if annuity && period > 0 {
                geometryPoint(CGPoint(x: x, y: size.height * 0.40), emphasized: true, context: &context)
                geometryLabel("C", at: CGPoint(x: x, y: size.height * 0.31), color: Tokens.ink, context: &context)
            }
        }
        geometryLabel(
            annuity ? "각 현금흐름을 같은 시점으로 옮겨 더한다" : "현재가치 × (1+i)ⁿ = 미래가치",
            at: CGPoint(x: size.width * 0.5, y: size.height * 0.87),
            color: Tokens.progressBlue,
            context: &context
        )
        if !annuity {
            geometryLabel("이율과 기간 단위를 먼저 맞춘다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.95), color: Tokens.warningInk, context: &context)
        }
    }

    private func drawEconomicsMarket(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if economicsFunctionSceneIDs.contains(sceneID) {
            let cards: [(String, String)] = [("입력 q", "판매량"), ("규칙 C(q)", "고정비+변동비"), ("출력", "총비용")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.04 + CGFloat(index) * 0.32), y: size.height * 0.31, width: size.width * 0.25, height: size.height * 0.32)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 20), color: Tokens.text2, context: &context)
                geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.ink, context: &context)
            }
            geometryLabel("입력마다 하나의 출력 규칙", at: CGPoint(x: size.width * 0.5, y: size.height * 0.86), color: Tokens.progressBlue, context: &context)
            return
        }

        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.91, y: size.height * 0.82)], color: Tokens.text3, context: &context)
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.11, y: size.height * 0.12)], color: Tokens.text3, context: &context)
        if economicsUtilitySceneIDs.contains(sceneID) {
            var utility = Path()
            utility.move(to: CGPoint(x: size.width * 0.13, y: size.height * 0.78))
            utility.addCurve(to: CGPoint(x: size.width * 0.88, y: size.height * 0.20), control1: CGPoint(x: size.width * 0.33, y: size.height * 0.32), control2: CGPoint(x: size.width * 0.60, y: size.height * 0.20))
            context.stroke(utility, with: .color(Tokens.progressBlue), lineWidth: 6)
            geometryLine([CGPoint(x: size.width * 0.34, y: size.height * 0.51), CGPoint(x: size.width * 0.60, y: size.height * 0.35)], color: Tokens.warningInk, context: &context)
            geometryLabel("높이 = 총효용 · 접선 = 한계효용", at: CGPoint(x: size.width * 0.56, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        geometryLine([CGPoint(x: size.width * 0.16, y: size.height * 0.18), CGPoint(x: size.width * 0.86, y: size.height * 0.76)], color: Tokens.progressBlue, context: &context)
        geometryLine([CGPoint(x: size.width * 0.16, y: size.height * 0.76), CGPoint(x: size.width * 0.86, y: size.height * 0.18)], color: Tokens.warningInk, context: &context)
        let shifted = sceneID.contains("move") || sceneID.contains("tax") || sceneID.contains("income") || sceneID.contains("cause")
        if shifted {
            geometryLine([CGPoint(x: size.width * 0.24, y: size.height * 0.76), CGPoint(x: size.width * 0.94, y: size.height * 0.18)], color: Tokens.text3, dashed: true, context: &context)
        }
        geometryPoint(CGPoint(x: size.width * (shifted ? 0.57 : 0.51), y: size.height * (shifted ? 0.45 : 0.47)), emphasized: true, context: &context)
        geometryLabel(shifted ? "원인이 바뀌면 곡선 전체가 이동" : "수요량=공급량인 좌표", at: CGPoint(x: size.width * 0.56, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
    }

    private func drawEconomicsLinearMatrix(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if economicsLinearProgramSceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.91, y: size.height * 0.82)], color: Tokens.text3, context: &context)
            geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.11, y: size.height * 0.12)], color: Tokens.text3, context: &context)
            let feasible = Path { path in
                path.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.76))
                path.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.30))
                path.addLine(to: CGPoint(x: size.width * 0.49, y: size.height * 0.46))
                path.addLine(to: CGPoint(x: size.width * 0.69, y: size.height * 0.64))
                path.closeSubpath()
            }
            context.fill(feasible, with: .color(Color.yellow.opacity(0.42)))
            context.stroke(feasible, with: .color(Tokens.warningInk), lineWidth: 4)
            [CGPoint(x: size.width * 0.14, y: size.height * 0.76), CGPoint(x: size.width * 0.14, y: size.height * 0.30), CGPoint(x: size.width * 0.49, y: size.height * 0.46), CGPoint(x: size.width * 0.69, y: size.height * 0.64)].forEach {
                geometryPoint($0, emphasized: true, context: &context)
            }
            geometryLabel("가능영역의 꼭짓점에서 목적함수 비교", at: CGPoint(x: size.width * 0.54, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        let rows: [[String]] = [["서울", "30", "12"], ["부산", "25", "18"]]
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, value) in row.enumerated() {
                let rect = CGRect(x: size.width * (0.14 + CGFloat(columnIndex) * 0.20), y: size.height * (0.28 + CGFloat(rowIndex) * 0.25), width: size.width * 0.17, height: size.height * 0.19)
                context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(columnIndex == 0 ? Tokens.paper2 : rowIndex == 0 ? Color.yellow.opacity(0.58) : Tokens.primarySoft))
                context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(columnIndex == 0 ? Tokens.lineStrong : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(value, at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
            }
        }
        geometryLabel("행·열 이름을 계산 끝까지 보존", at: CGPoint(x: size.width * 0.72, y: size.height * 0.34), color: Tokens.progressBlue, context: &context)
        geometryLabel(sceneID.contains("undo") || sceneID.contains("determinant") || sceneID.contains("recover") ? "역행렬은 섞은 규칙을 되돌리는 문" : "행×열은 원래 단위의 의미를 연결", at: CGPoint(x: size.width * 0.60, y: size.height * 0.83), color: Tokens.warningInk, context: &context)
    }

    private func drawEconomicsMarginal(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.91, y: size.height * 0.82)], color: Tokens.text3, context: &context)
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.11, y: size.height * 0.12)], color: Tokens.text3, context: &context)
        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.13, y: size.height * 0.76))
        curve.addCurve(to: CGPoint(x: size.width * 0.55, y: size.height * 0.24), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.66), control2: CGPoint(x: size.width * 0.40, y: size.height * 0.20))
        curve.addCurve(to: CGPoint(x: size.width * 0.89, y: size.height * 0.77), control1: CGPoint(x: size.width * 0.70, y: size.height * 0.26), control2: CGPoint(x: size.width * 0.80, y: size.height * 0.66))
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)

        if economicsElasticitySceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.27, y: size.height * 0.66), CGPoint(x: size.width * 0.78, y: size.height * 0.34)], color: Tokens.warningInk, context: &context)
            geometryLabel("탄력성 = 수량 변화율 ÷ 가격 변화율", at: CGPoint(x: size.width * 0.55, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            geometryLabel("기울기만 보면 단위에 속는다", at: CGPoint(x: size.width * 0.67, y: size.height * 0.18), color: Tokens.warningInk, context: &context)
            return
        }
        if economicsOptimumSceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.55, y: size.height * 0.82), CGPoint(x: size.width * 0.55, y: size.height * 0.24)], color: Tokens.text3, dashed: true, context: &context)
            geometryPoint(CGPoint(x: size.width * 0.55, y: size.height * 0.24), emphasized: true, context: &context)
            geometryLabel("MR = MC", at: CGPoint(x: size.width * 0.55, y: size.height * 0.15), color: Tokens.warningInk, context: &context)
            geometryLabel("정지점 + 정의역 + 끝점까지 비교", at: CGPoint(x: size.width * 0.55, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        let point = CGPoint(x: size.width * (beat.action == "verify" ? 0.66 : 0.44), y: size.height * (beat.action == "verify" ? 0.40 : 0.28))
        geometryLine([CGPoint(x: point.x - size.width * 0.14, y: point.y + size.height * 0.12), CGPoint(x: point.x + size.width * 0.14, y: point.y - size.height * 0.12)], color: Tokens.warningInk, context: &context)
        geometryPoint(point, emphasized: true, context: &context)
        geometryLabel("한계량 = 총량 곡선의 그 점 접선 기울기", at: CGPoint(x: size.width * 0.55, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
    }

    private func drawEconomicsMathScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if economicsIndexSceneIDs.contains(sceneID) || economicsExchangeSceneIDs.contains(sceneID) || economicsTaxSceneIDs.contains(sceneID) || economicsInterestSceneIDs.contains(sceneID) || economicsAnnuitySceneIDs.contains(sceneID) {
            drawEconomicsFinance(context: &context, size: size, beat: beat)
        } else if economicsFunctionSceneIDs.contains(sceneID) || economicsMarketLineSceneIDs.contains(sceneID) || economicsUtilitySceneIDs.contains(sceneID) {
            drawEconomicsMarket(context: &context, size: size, beat: beat)
        } else if economicsLinearProgramSceneIDs.contains(sceneID) || economicsMatrixSceneIDs.contains(sceneID) {
            drawEconomicsLinearMatrix(context: &context, size: size, beat: beat)
        } else {
            drawEconomicsMarginal(context: &context, size: size, beat: beat)
        }
    }

    private func drawAiLearning(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("history") || sceneID.contains("xor") || sceneID.contains("spam") || sceneID.contains("hero") {
            geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.55), CGPoint(x: size.width * 0.89, y: size.height * 0.55)], color: Tokens.text3, context: &context)
            let labels = ["규칙", "퍼셉트론", "데이터", "맥락"]
            for (index, label) in labels.enumerated() {
                let point = CGPoint(x: size.width * (0.16 + CGFloat(index) * 0.23), y: size.height * 0.55)
                geometryPoint(point, emphasized: index == 1, context: &context)
                geometryLabel(label, at: CGPoint(x: point.x, y: point.y + 46), color: Tokens.text2, context: &context)
            }
            geometryLabel("도구 영웅담보다 질문→수학 표현→한계", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("data") || sceneID.contains("bus") || sceneID.contains("cafeteria") || sceneID.contains("more") {
            let windows: [(String, String)] = [("수집", "누가 빠졌나"), ("표현", "무엇을 셌나"), ("맥락", "언제·어디서"), ("영향", "누가 손해나")]
            for (index, window) in windows.enumerated() {
                let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.35)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(window.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.ink, context: &context)
                geometryLabel(window.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
            }
            geometryLabel("크기보다 먼저 어떤 세계를 담았는지 확인", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
            return
        }
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.80), CGPoint(x: size.width * 0.90, y: size.height * 0.80)], color: Tokens.text3, context: &context)
        geometryLine([CGPoint(x: size.width * 0.50, y: size.height * 0.17), CGPoint(x: size.width * 0.50, y: size.height * 0.80)], color: Tokens.text3, context: &context)
        let examples: [(CGFloat, CGFloat, String)] = [(0.30, 0.34, "+"), (0.70, 0.66, "−"), (0.36, 0.64, "+"), (0.66, 0.30, "−")]
        for (index, example) in examples.enumerated() {
            let point = CGPoint(x: size.width * example.0, y: size.height * example.1)
            geometryPoint(point, emphasized: index == 1, context: &context)
            geometryLabel(example.2, at: point, color: Tokens.ink, context: &context)
        }
        geometryLine(
            beat.action == "verify"
                ? [CGPoint(x: size.width * 0.20, y: size.height * 0.69), CGPoint(x: size.width * 0.80, y: size.height * 0.28)]
                : [CGPoint(x: size.width * 0.21, y: size.height * 0.60), CGPoint(x: size.width * 0.79, y: size.height * 0.40)],
            color: Tokens.warningInk,
            context: &context
        )
        geometryLabel("오답 방향만큼 경계를 조금 이동", at: CGPoint(x: size.width * 0.5, y: size.height * 0.90), color: Tokens.progressBlue, context: &context)
    }

    private func drawAiText(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("similarity") || sceneID.contains("direction") || sceneID.contains("sentiment") || sceneID.contains("review") || sceneID.contains("context") {
            let origin = CGPoint(x: size.width * 0.20, y: size.height * 0.80)
            let endpoints: [(CGPoint, String)] = [
                (CGPoint(x: size.width * 0.82, y: size.height * 0.24), "문장 A"),
                (CGPoint(x: size.width * 0.75, y: size.height * 0.37), "문장 B"),
                (CGPoint(x: size.width * 0.43, y: size.height * 0.20), "문장 C"),
            ]
            for endpoint in endpoints {
                geometryLine([origin, endpoint.0], color: Tokens.progressBlue, context: &context)
                geometryLabel(endpoint.1, at: CGPoint(x: endpoint.0.x, y: endpoint.0.y - 18), color: Tokens.text2, context: &context)
            }
            geometryLabel("길이보다 방향의 각도 = 코사인 유사도", at: CGPoint(x: size.width * 0.55, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        let words = ["수학", "재미", "어려움", "추천"]
        let weighted = sceneID.contains("weight") || sceneID.contains("common") || sceneID.contains("rare")
        let values: [CGFloat] = weighted ? [0.08, 0.62, 0.74, 0.31] : [0.72, 0.45, 0.12, 0.45]
        for (index, value) in values.enumerated() {
            let rect = CGRect(x: size.width * (0.08 + CGFloat(index) * 0.23), y: size.height * (0.78 - value * 0.55), width: size.width * 0.13, height: size.height * value * 0.55)
            context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 2 ? Color.yellow.opacity(0.68) : Tokens.primarySoft))
            context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(words[index], at: CGPoint(x: rect.midX, y: size.height * 0.85), color: Tokens.text2, context: &context)
        }
        geometryLabel(weighted ? "문서 안 빈도 × 문서 밖 희소성" : "단어를 축으로 바꾸면 문장이 좌표", at: CGPoint(x: size.width * 0.5, y: size.height * 0.93), color: Tokens.progressBlue, context: &context)
    }

    private func drawAiImage(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let values: [CGFloat] = [32, 84, 168, 220, 52, 124, 196, 244, 18, 72, 154, 232]
        for (index, value) in values.enumerated() {
            let column = index % 4
            let row = index / 4
            let rect = CGRect(x: size.width * (0.20 + CGFloat(column) * 0.15), y: size.height * (0.16 + CGFloat(row) * 0.20), width: size.width * 0.13, height: size.height * 0.16)
            context.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(Color(white: value / 255)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 7), with: .color(index == 6 ? Tokens.warningInk : Tokens.lineStrong), lineWidth: index == 6 ? 5 : 2)
            geometryLabel(String(Int(value)), at: CGPoint(x: rect.midX, y: rect.midY), color: value > 150 ? .black : .white, context: &context)
        }
        if sceneID.contains("editor") || sceneID.contains("brightness") || sceneID.contains("operation") || sceneID.contains("range") {
            geometryLabel("+40", at: CGPoint(x: size.width * 0.82, y: size.height * 0.30), color: Tokens.warningInk, context: &context)
            geometryLabel("연산 뒤 0~255 범위를 다시 확인", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
        } else if sceneID.contains("distance") || sceneID.contains("nearest") || sceneID.contains("closeness") || sceneID.contains("represent") {
            geometryLabel("픽셀 거리와 모양의 닮음은 같은 질문이 아니다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
        } else {
            geometryLabel("행 · 열 · 채널 · 값", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
        }
    }

    private func drawAiPrediction(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("forecast") || sceneID.contains("reference") || sceneID.contains("probability") || sceneID.contains("absence") || sceneID.contains("count-divide") {
            let total = CGRect(x: size.width * 0.15, y: size.height * 0.31, width: size.width * 0.70, height: size.height * 0.30)
            let share = CGRect(x: total.minX, y: total.minY, width: total.width * 0.65, height: total.height)
            context.fill(Path(roundedRect: total, cornerRadius: 18), with: .color(Tokens.paper2))
            context.fill(Path(roundedRect: share, cornerRadius: 18), with: .color(Color.yellow.opacity(0.58)))
            context.stroke(Path(roundedRect: total, cornerRadius: 18), with: .color(Tokens.progressBlue), lineWidth: 3)
            geometryLabel("해당 65", at: CGPoint(x: share.midX, y: share.midY), color: Tokens.ink, context: &context)
            geometryLabel("전체 100", at: CGPoint(x: total.maxX - total.width * 0.16, y: total.midY), color: Tokens.text2, context: &context)
            geometryLabel("과거 비율은 가능성이지 개인의 약속이 아니다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.86), color: Tokens.progressBlue, context: &context)
            return
        }
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.91, y: size.height * 0.82)], color: Tokens.text3, context: &context)
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.11, y: size.height * 0.12)], color: Tokens.text3, context: &context)
        let isLoss = sceneID.contains("loss") || sceneID.contains("square") || sceneID.contains("scoreboard") || sceneID.contains("compare") || sceneID.contains("descent") || sceneID.contains("slope") || sceneID.contains("step") || sceneID.contains("dimmer")
        if isLoss {
            var bowl = Path()
            bowl.move(to: CGPoint(x: size.width * 0.16, y: size.height * 0.18))
            bowl.addCurve(to: CGPoint(x: size.width * 0.84, y: size.height * 0.18), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.88), control2: CGPoint(x: size.width * 0.70, y: size.height * 0.88))
            context.stroke(bowl, with: .color(Tokens.progressBlue), lineWidth: 6)
            let point = CGPoint(x: size.width * (beat.action == "verify" ? 0.52 : 0.70), y: size.height * (beat.action == "verify" ? 0.74 : 0.56))
            geometryPoint(point, emphasized: true, context: &context)
            geometryLine([CGPoint(x: point.x + size.width * 0.12, y: point.y - size.height * 0.13), CGPoint(x: point.x + 12, y: point.y - 8)], color: Tokens.warningInk, context: &context)
            geometryLabel("기울기 반대 방향 × 학습률", at: CGPoint(x: size.width * 0.5, y: size.height * 0.92), color: Tokens.progressBlue, context: &context)
            return
        }
        let points: [(CGFloat, CGFloat)] = [(0.18, 0.67), (0.27, 0.59), (0.35, 0.57), (0.44, 0.43), (0.54, 0.49), (0.63, 0.32), (0.72, 0.38), (0.83, 0.23)]
        for (index, pair) in points.enumerated() {
            geometryPoint(CGPoint(x: size.width * pair.0, y: size.height * pair.1), emphasized: index == 4, context: &context)
        }
        geometryLine([CGPoint(x: size.width * 0.16, y: size.height * 0.72), CGPoint(x: size.width * 0.86, y: size.height * 0.20)], color: Tokens.progressBlue, context: &context)
        geometryLabel("선의 방향 · 잔차 · 적용 범위를 함께 읽는다", at: CGPoint(x: size.width * 0.53, y: size.height * 0.92), color: Tokens.progressBlue, context: &context)
    }

    private func drawAiInquiry(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let isProject = sceneID.contains("question") || sceneID.contains("project") || sceneID.contains("inquiry")
        let labels: [(String, String)] = isProject
            ? [("질문", "측정 가능"), ("자료", "대표성"), ("평가", "정확+공정"), ("결정", "한계 공개")]
            : [("정확도", "40%"), ("공정성", "25%"), ("비용", "20%"), ("영향", "15%")]
        for (index, label) in labels.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.35)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(label.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.ink, context: &context)
            geometryLabel(label.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
        }
        geometryLabel("목표·제약·영향을 공개해야 합리성을 검토할 수 있다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
    }

    private func drawAiMathScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if aiLearningSceneIDs.contains(sceneID) {
            drawAiLearning(context: &context, size: size, beat: beat)
        } else if aiTextSceneIDs.contains(sceneID) {
            drawAiText(context: &context, size: size, beat: beat)
        } else if aiImageSceneIDs.contains(sceneID) {
            drawAiImage(context: &context, size: size, beat: beat)
        } else if aiPredictionSceneIDs.contains(sceneID) {
            drawAiPrediction(context: &context, size: size, beat: beat)
        } else {
            drawAiInquiry(context: &context, size: size, beat: beat)
        }
    }

    private func drawCultureArt(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("monochord") || sceneID.contains("concert") || sceneID.contains("hertz") || sceneID.contains("chord") || sceneID.contains("music") {
            for (row, parts) in [4, 3].enumerated() {
                let y = size.height * (row == 0 ? 0.34 : 0.64)
                geometryLine([CGPoint(x: size.width * 0.13, y: y), CGPoint(x: size.width * 0.87, y: y)], color: row == 0 ? Tokens.text3 : Tokens.progressBlue, context: &context)
                for part in 0...parts {
                    let x = size.width * (0.13 + CGFloat(part) * 0.74 / CGFloat(parts))
                    geometryLine([CGPoint(x: x, y: y - 18), CGPoint(x: x, y: y + 18)], color: Tokens.text3, context: &context)
                }
            }
            geometryLabel("줄 길이의 간단한 비가 음정의 비를 만든다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.89), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("perspective") || sceneID.contains("distance") || sceneID.contains("ratio") || sceneID.contains("tile") || sceneID.contains("geometry") {
            let vanishing = CGPoint(x: size.width * 0.5, y: size.height * 0.18)
            [0.10, 0.28, 0.72, 0.90].forEach { fraction in
                geometryLine([CGPoint(x: size.width * fraction, y: size.height * 0.84), vanishing], color: Tokens.text3, context: &context)
            }
            [0.34, 0.49, 0.65, 0.80].forEach { fraction in
                geometryLine([CGPoint(x: size.width * (0.16 + fraction * 0.20), y: size.height * fraction), CGPoint(x: size.width * (0.84 - fraction * 0.20), y: size.height * fraction)], color: Tokens.progressBlue, context: &context)
            }
            geometryLabel("소실점 · 비례 · 반복 타일", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("film") || sceneID.contains("frame") || sceneID.contains("resolution") || sceneID.contains("edit") {
            for index in 0..<5 {
                let rect = CGRect(x: size.width * (0.05 + CGFloat(index) * 0.19), y: size.height * 0.30, width: size.width * 0.15, height: size.height * 0.34)
                context.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(index == 2 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(String(index + 1), at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
            }
            geometryLabel("프레임 수 · 좌표 · crop · 편집 간격", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
            return
        }
        let counts: [CGFloat] = [5, 7, 5, 7, 5]
        for (index, count) in counts.enumerated() {
            let rect = CGRect(x: size.width * (0.07 + CGFloat(index) * 0.19), y: size.height * (0.78 - count * 0.06), width: size.width * 0.13, height: size.height * count * 0.06)
            context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 2 ? Color.yellow.opacity(0.62) : Tokens.primarySoft))
            context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel("\(Int(count))박", at: CGPoint(x: rect.midX, y: size.height * 0.85), color: Tokens.text2, context: &context)
        }
        geometryLabel("수열은 리듬을 보이게 하지만 의미를 대신하지 않는다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.93), color: Tokens.progressBlue, context: &context)
    }

    private func drawCultureLeisure(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("court") || sceneID.contains("parabola") || sceneID.contains("shot") || sceneID.contains("sports") || sceneID.contains("degree") {
            geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.91, y: size.height * 0.82)], color: Tokens.text3, context: &context)
            var shot = Path()
            shot.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.77))
            shot.addCurve(to: CGPoint(x: size.width * 0.86, y: size.height * 0.77), control1: CGPoint(x: size.width * 0.34, y: size.height * 0.06), control2: CGPoint(x: size.width * 0.66, y: size.height * 0.06))
            context.stroke(shot, with: .color(Tokens.progressBlue), lineWidth: 6)
            geometryPoint(CGPoint(x: size.width * 0.50, y: size.height * 0.22), emphasized: true, context: &context)
            geometryLabel("꼭짓점 · 발사 조건 · 실제 기록 비교", at: CGPoint(x: size.width * 0.53, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("binary") || sceneID.contains("grayscale") || sceneID.contains("parity") || sceneID.contains("digital") || sceneID.contains("compress") {
            let bits = [1, 0, 1, 1, 0, 1, 0, 1]
            for (index, bit) in bits.enumerated() {
                let rect = CGRect(x: size.width * (0.04 + CGFloat(index) * 0.12), y: size.height * 0.35, width: size.width * 0.09, height: size.height * 0.24)
                context.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(bit == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 10), with: .color(bit == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(String(bit), at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
            }
            geometryLabel("자료 비트 + 오류검사 비트", at: CGPoint(x: size.width * 0.5, y: size.height * 0.73), color: Tokens.progressBlue, context: &context)
            geometryLabel("표현·압축·무결성은 다른 문제", at: CGPoint(x: size.width * 0.5, y: size.height * 0.86), color: Tokens.text2, context: &context)
            return
        }
        if sceneID.contains("ballot") || sceneID.contains("profile") || sceneID.contains("voting") || sceneID.contains("method") {
            let ballots: [(String, String)] = [("A>B>C", "4표"), ("B>C>A", "3표"), ("C>A>B", "2표")]
            for (index, ballot) in ballots.enumerated() {
                let rect = CGRect(x: size.width * (0.10 + CGFloat(index) * 0.30), y: size.height * 0.30, width: size.width * 0.23, height: size.height * 0.35)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(ballot.0, at: CGPoint(x: rect.midX, y: rect.midY - 20), color: Tokens.ink, context: &context)
                geometryLabel(ballot.1, at: CGPoint(x: rect.midX, y: rect.midY + 25), color: Tokens.text2, context: &context)
            }
            geometryLabel("같은 선호표도 규칙에 따라 당선자가 달라진다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
            return
        }
        let nodes: [(CGFloat, CGFloat, String)] = [(0.50, 0.16, "시작"), (0.31, 0.40, "앞"), (0.69, 0.40, "뒤"), (0.20, 0.72, "승"), (0.40, 0.72, "패"), (0.60, 0.72, "승"), (0.80, 0.72, "패")]
        let links = [(0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6)]
        for link in links {
            geometryLine([CGPoint(x: size.width * nodes[link.0].0, y: size.height * nodes[link.0].1), CGPoint(x: size.width * nodes[link.1].0, y: size.height * nodes[link.1].1)], color: Tokens.progressBlue, context: &context)
        }
        for (index, node) in nodes.enumerated() {
            geometryPoint(CGPoint(x: size.width * node.0, y: size.height * node.1), emphasized: index == 3 || index == 5, context: &context)
            geometryLabel(node.2, at: CGPoint(x: size.width * node.0, y: size.height * node.1 + 28), color: Tokens.text2, context: &context)
        }
        geometryLabel("규칙을 나무로 펼쳐 확률·기댓값·필승 수를 확인", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
    }

    private func drawCultureSociety(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("braille") || sceneID.contains("dot") || sceneID.contains("accessible") || sceneID.contains("letters") {
            let active = Set([0, 3, 4])
            for index in 0..<6 {
                let column = index >= 3 ? 1 : 0
                let row = index % 3
                geometryPoint(CGPoint(x: size.width * (0.41 + CGFloat(column) * 0.19), y: size.height * (0.24 + CGFloat(row) * 0.22)), emphasized: active.contains(index), context: &context)
            }
            geometryLabel("6개 점의 조합 → 64개 패턴", at: CGPoint(x: size.width * 0.5, y: size.height * 0.90), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("media") || sceneID.contains("headline") || sceneID.contains("frequency") || sceneID.contains("comment") {
            let values: [CGFloat] = [0.18, 0.54, 0.31, 0.68, 0.42]
            for (index, value) in values.enumerated() {
                let rect = CGRect(x: size.width * (0.14 + CGFloat(index) * 0.16), y: size.height * (0.78 - value * 0.65), width: size.width * 0.10, height: size.height * value * 0.65)
                context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 3 ? Color.yellow.opacity(0.62) : Tokens.primarySoft))
                context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 3 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            }
            geometryLabel("분모·표본·분포를 함께 공개", at: CGPoint(x: size.width * 0.5, y: size.height * 0.90), color: Tokens.progressBlue, context: &context)
            return
        }
        let weighted = sceneID.contains("values") || sceneID.contains("weighted") || sceneID.contains("weight") || sceneID.contains("choice")
        let cards: [(String, String)] = weighted ? [("가격", "35%"), ("환경", "30%"), ("내구", "20%"), ("접근", "15%")] : [("10진", "셈법"), ("20진", "셈법"), ("대칭", "구조"), ("무늬", "문화")]
        for (index, card) in cards.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.35)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 20), color: Tokens.ink, context: &context)
            geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 25), color: Tokens.text2, context: &context)
        }
        geometryLabel(weighted ? "가중치는 공개할 가치 선택" : "문화의 질문을 수학 구조로 번역", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
    }

    private func drawCultureEnvironment(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.91, y: size.height * 0.82)], color: Tokens.text3, context: &context)
        geometryLine([CGPoint(x: size.width * 0.11, y: size.height * 0.82), CGPoint(x: size.width * 0.11, y: size.height * 0.12)], color: Tokens.text3, context: &context)
        if sceneID.contains("air") || sceneID.contains("moving") || sceneID.contains("day") {
            let points: [(CGFloat, CGFloat)] = [(0.14, 0.64), (0.24, 0.40), (0.34, 0.57), (0.44, 0.31), (0.54, 0.53), (0.64, 0.36), (0.74, 0.48), (0.85, 0.28)]
            geometryLine(points.map { CGPoint(x: size.width * $0.0, y: size.height * $0.1) }, color: Tokens.progressBlue, context: &context)
            for (index, point) in points.enumerated() { geometryPoint(CGPoint(x: size.width * point.0, y: size.height * point.1), emphasized: index == 3, context: &context) }
            geometryLine([CGPoint(x: size.width * 0.14, y: size.height * 0.57), CGPoint(x: size.width * 0.85, y: size.height * 0.38)], color: Tokens.warningInk, dashed: true, context: &context)
            geometryLabel("원자료와 이동평균을 겹쳐 흐름을 읽는다", at: CGPoint(x: size.width * 0.54, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("model") || sceneID.contains("growth") || sceneID.contains("extrapolation") || sceneID.contains("intervention") || sceneID.contains("desert") {
            geometryLine([CGPoint(x: size.width * 0.14, y: size.height * 0.76), CGPoint(x: size.width * 0.86, y: size.height * 0.22)], color: Tokens.progressBlue, context: &context)
            var intervention = Path()
            intervention.move(to: CGPoint(x: size.width * 0.53, y: size.height * 0.47))
            intervention.addCurve(to: CGPoint(x: size.width * 0.86, y: size.height * 0.76), control1: CGPoint(x: size.width * 0.66, y: size.height * 0.55), control2: CGPoint(x: size.width * 0.76, y: size.height * 0.68))
            context.stroke(intervention, with: .color(Tokens.warningInk), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
            geometryPoint(CGPoint(x: size.width * 0.53, y: size.height * 0.47), emphasized: true, context: &context)
            geometryLabel("모형 범위 밖을 영원히 외삽하지 않는다", at: CGPoint(x: size.width * 0.54, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("richness") || sceneID.contains("simpson") || sceneID.contains("ecosystem") || sceneID.contains("habitat") || sceneID.contains("biodiversity") {
            let values: [CGFloat] = [0.72, 0.18, 0.06, 0.04]
            for (index, value) in values.enumerated() {
                let rect = CGRect(x: size.width * (0.16 + CGFloat(index) * 0.19), y: size.height * (0.78 - value * 0.68), width: size.width * 0.12, height: size.height * value * 0.68)
                context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 0 ? Color.yellow.opacity(0.62) : Tokens.primarySoft))
                context.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(index == 0 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            }
            geometryLabel("종 수(풍부도) + 고른 분포(균등도)", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        let labels = ["총량", "학생 수", "1인당", "전후 비교"]
        for (index, label) in labels.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.31, width: size.width * 0.20, height: size.height * 0.33)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(label, at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
        }
        geometryLabel("공통 단위로 나눈 뒤 개선 전후를 비교", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
    }

    private func drawMathCultureScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if cultureArtSceneIDs.contains(sceneID) {
            drawCultureArt(context: &context, size: size, beat: beat)
        } else if cultureLeisureSceneIDs.contains(sceneID) {
            drawCultureLeisure(context: &context, size: size, beat: beat)
        } else if cultureSocietySceneIDs.contains(sceneID) {
            drawCultureSociety(context: &context, size: size, beat: beat)
        } else {
            drawCultureEnvironment(context: &context, size: size, beat: beat)
        }
    }

    private func drawResearchFoundation(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let ethical = sceneID.contains("trust") || sceneID.contains("ethical") || sceneID.contains("clean") || sceneID.contains("ethics")
        let steps: [(String, String)] = ethical
            ? [("동의", "참여자"), ("수집", "최소 자료"), ("분석", "변경 기록"), ("공개", "한계")]
            : [("불편", "현상"), ("질문", "측정 가능"), ("자료", "판정 기준"), ("답", "범위")]
        for (index, step) in steps.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.35)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(step.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.ink, context: &context)
            geometryLabel(step.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
            if index < 3 {
                geometryLine([CGPoint(x: rect.maxX + 4, y: rect.midY), CGPoint(x: rect.maxX + size.width * 0.04, y: rect.midY)], color: Tokens.progressBlue, context: &context)
            }
        }
        geometryLabel(ethical ? "결과보다 오래 남는 정직한 의사결정 흔적" : "답을 정해 놓지 말고 반증 가능한 질문으로", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
    }

    private func drawResearchMethod(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("literature") || sceneID.contains("source") || sceneID.contains("paper") || sceneID.contains("search") {
            let nodes: [(CGFloat, CGFloat, String)] = [(0.20, 0.30, "출처 A"), (0.50, 0.20, "핵심 주장"), (0.80, 0.30, "출처 B"), (0.33, 0.68, "방법"), (0.67, 0.68, "한계")]
            let links = [(0, 1), (2, 1), (0, 3), (2, 4), (1, 3), (1, 4)]
            for link in links {
                geometryLine([CGPoint(x: size.width * nodes[link.0].0, y: size.height * nodes[link.0].1), CGPoint(x: size.width * nodes[link.1].0, y: size.height * nodes[link.1].1)], color: Tokens.text3, dashed: true, context: &context)
            }
            for (index, node) in nodes.enumerated() {
                let rect = CGRect(x: size.width * node.0 - size.width * 0.09, y: size.height * node.1 - size.height * 0.08, width: size.width * 0.18, height: size.height * 0.16)
                context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(node.2, at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
            }
            geometryLabel("요약 목록이 아니라 주장·방법·한계의 논증 지도", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("case") || sceneID.contains("anecdote") || sceneID.contains("cross") {
            let cards: [(String, String)] = [("사례 A", "맥락1"), ("사례 B", "맥락2"), ("공통", "신호"), ("차이", "조건")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.30, width: size.width * 0.20, height: size.height * 0.35)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.ink, context: &context)
                geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
            }
            geometryLabel("사례 하나의 인상을 같은 질문으로 비교", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
            return
        }
        let development = sceneID.contains("artifact") || sceneID.contains("prototype") || sceneID.contains("puzzle") || sceneID.contains("requirements") || sceneID.contains("development")
        let labels = development ? ["요구", "시제품", "시험", "수정"] : ["가설", "무작위", "반복", "비율"]
        let centers: [(CGFloat, CGFloat)] = [(0.50, 0.20), (0.76, 0.50), (0.50, 0.78), (0.24, 0.50)]
        for (index, label) in labels.enumerated() {
            let center = CGPoint(x: size.width * centers[index].0, y: size.height * centers[index].1)
            geometryPoint(center, emphasized: index == 2, context: &context)
            geometryLabel(label, at: CGPoint(x: center.x, y: center.y + 30), color: Tokens.text2, context: &context)
            let next = centers[(index + 1) % centers.count]
            geometryLine([center, CGPoint(x: size.width * next.0, y: size.height * next.1)], color: Tokens.progressBlue, dashed: true, context: &context)
        }
        geometryLabel(development ? "반복마다 남긴 변경 근거" : "원하는 값이 아니라 반복 결과의 분포", at: CGPoint(x: size.width * 0.5, y: size.height * 0.93), color: Tokens.progressBlue, context: &context)
    }

    private func drawResearchExecution(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("topic") || sceneID.contains("plan") || sceneID.contains("grand") || sceneID.contains("daylight") {
            let widths: [CGFloat] = [0.78, 0.60, 0.43, 0.27]
            let labels = ["관심", "가치×가능", "측정 질문", "실행 계획"]
            for (index, width) in widths.enumerated() {
                let rect = CGRect(x: size.width * (0.5 - width / 2), y: size.height * (0.15 + CGFloat(index) * 0.17), width: size.width * width, height: size.height * 0.12)
                context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 3 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 3 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(labels[index], at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
            }
            geometryLabel("큰 주제를 오늘 실행 가능한 질문으로 좁힌다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }
        let reflection = sceneID.contains("reflection") || sceneID.contains("mirror") || sceneID.contains("rubric") || sceneID.contains("successful") || sceneID.contains("bridge")
        let presentation = sceneID.contains("evidence-story") || sceneID.contains("audience") || sceneID.contains("slide") || sceneID.contains("shade-route") || sceneID.contains("presentation")
        let labels = reflection ? ["기대", "증거", "차이", "다음 질문"] : presentation ? ["주장", "근거", "경로", "한계"] : ["계획", "실행", "변경", "체크"]
        for (index, label) in labels.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.31, width: size.width * 0.20, height: size.height * 0.33)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(String(index + 1), at: CGPoint(x: rect.minX + 22, y: rect.minY + 22), color: Tokens.text3, context: &context)
            geometryLabel(label, at: CGPoint(x: rect.midX, y: rect.midY), color: Tokens.ink, context: &context)
        }
        geometryLabel(reflection ? "근거로 다음 질문을 만든다" : presentation ? "청중이 근거의 길을 다시 걷게" : "변경 이유를 실행 로그에 남긴다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
    }

    private func drawMathResearchScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if researchFoundationSceneIDs.contains(sceneID) {
            drawResearchFoundation(context: &context, size: size, beat: beat)
        } else if researchMethodSceneIDs.contains(sceneID) {
            drawResearchMethod(context: &context, size: size, beat: beat)
        } else {
            drawResearchExecution(context: &context, size: size, beat: beat)
        }
    }

    private func drawVocationalNumber(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("rounding") || sceneID.contains("resolution") || sceneID.contains("direction-label") {
            let y = size.height * 0.50
            geometryLine([CGPoint(x: size.width * 0.12, y: y), CGPoint(x: size.width * 0.88, y: y)], color: Tokens.ink, context: &context)
            let labels = ["1,200", "1,250", "1,300"]
            for (index, label) in labels.enumerated() {
                let x = size.width * (0.20 + CGFloat(index) * 0.30)
                geometryLine([CGPoint(x: x, y: y - 24), CGPoint(x: x, y: y + 24)], color: index == 1 ? Tokens.warningInk : Tokens.progressBlue, context: &context)
                geometryLabel(label, at: CGPoint(x: x, y: y + 54), color: index == 1 ? Tokens.warningInk : Tokens.text2, context: &context)
            }
            geometryLabel("무엇을 위해 어느 자리에서 버릴지 먼저", at: CGPoint(x: size.width * 0.5, y: size.height * 0.22), color: Tokens.ink, context: &context)
            geometryLabel("예산은 올림 · 재고는 목적에 맞춰", at: CGPoint(x: size.width * 0.5, y: size.height * 0.82), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("unit") || sceneID.contains("conversion") || sceneID.contains("clock") || sceneID.contains("mass") || sceneID.contains("quantity") {
            let cards: [(String, String)] = [("1 kg", "× 1,000"), ("1,000 g", "같은 양"), ("0.001 t", "단위만 변화")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.06 + CGFloat(index) * 0.31), y: size.height * 0.31, width: size.width * 0.25, height: size.height * 0.36)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 24), color: Tokens.ink, context: &context)
                geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 26), color: Tokens.text2, context: &context)
            }
            geometryLabel("숫자와 단위를 한 묶음으로 이동", at: CGPoint(x: size.width * 0.5, y: size.height * 0.84), color: Tokens.progressBlue, context: &context)
            return
        }
        let steps: [(String, String)] = [("수량", "12개"), ("단가", "₩2,500"), ("연산", "12×2,500"), ("검산", "₩30,000")]
        for (index, step) in steps.enumerated() {
            let rect = CGRect(x: size.width * (0.035 + CGFloat(index) * 0.245), y: size.height * 0.31, width: size.width * 0.20, height: size.height * 0.34)
            context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Color.yellow.opacity(0.58) : Tokens.paper2))
            context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 2 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            geometryLabel(step.0, at: CGPoint(x: rect.midX, y: rect.midY - 24), color: Tokens.ink, context: &context)
            geometryLabel(step.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
        }
        geometryLabel("숫자보다 역할·단위·연산 순서를 먼저 표시", at: CGPoint(x: size.width * 0.5, y: size.height * 0.84), color: Tokens.progressBlue, context: &context)
    }

    private func drawVocationalRelation(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("recipe") || sceneID.contains("ratio") || sceneID.contains("catering") || sceneID.contains("same-scale") {
            let groups = [(0.23, 3, "기준 3"), (0.70, 6, "확대 6")]
            for group in groups {
                for index in 0..<group.1 {
                    let column = index % 3
                    let row = index / 3
                    geometryPoint(CGPoint(x: size.width * CGFloat(group.0) + CGFloat(column - 1) * 42, y: size.height * 0.43 + CGFloat(row) * 48), emphasized: group.1 == 6, context: &context)
                }
                geometryLabel(group.2, at: CGPoint(x: size.width * CGFloat(group.0), y: size.height * 0.72), color: group.1 == 6 ? Tokens.warningInk : Tokens.progressBlue, context: &context)
            }
            geometryLabel("대응하는 항목마다 같은 배율", at: CGPoint(x: size.width * 0.5, y: size.height * 0.20), color: Tokens.ink, context: &context)
            return
        }
        if sceneID.contains("hundred") || sceneID.contains("percent") || sceneID.contains("discount") || sceneID.contains("tax") || sceneID.contains("baseline") {
            let bar = CGRect(x: size.width * 0.10, y: size.height * 0.39, width: size.width * 0.80, height: size.height * 0.18)
            context.fill(Path(roundedRect: bar, cornerRadius: 14), with: .color(Tokens.paper2))
            let active = CGRect(x: bar.minX, y: bar.minY, width: bar.width * 0.72, height: bar.height)
            context.fill(Path(roundedRect: active, cornerRadius: 14), with: .color(Color.yellow.opacity(0.68)))
            context.stroke(Path(roundedRect: bar, cornerRadius: 14), with: .color(Tokens.progressBlue), lineWidth: 4)
            geometryLabel("기준 100%", at: CGPoint(x: bar.minX + 58, y: bar.minY - 32), color: Tokens.text2, context: &context)
            geometryLabel("72%", at: CGPoint(x: active.maxX - 34, y: active.midY), color: Tokens.warningInk, context: &context)
            geometryLabel("퍼센트와 퍼센트포인트를 섞지 않는다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.78), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("input-output") || sceneID.contains("difference-ratio") || sceneID.contains("piecewise") || sceneID.contains("delivery") || sceneID.contains("table-rule") {
            let cards: [(String, String)] = [("0~5 km", "기본요금"), ("5~10 km", "+ km당"), ("10 km+", "+ 할증")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.06 + CGFloat(index) * 0.31), y: size.height * 0.31, width: size.width * 0.25, height: size.height * 0.36)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.ink, context: &context)
                geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
            }
            geometryLabel("구간이 바뀌면 규칙도 바뀐다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.84), color: Tokens.progressBlue, context: &context)
            return
        }
        let origin = CGPoint(x: size.width * 0.17, y: size.height * 0.79)
        geometryLine([origin, CGPoint(x: size.width * 0.90, y: origin.y)], color: Tokens.ink, context: &context)
        geometryLine([origin, CGPoint(x: origin.x, y: size.height * 0.15)], color: Tokens.ink, context: &context)
        if sceneID.contains("constraint") || sceneID.contains("unknown") || sceneID.contains("integer") || sceneID.contains("purchase") || sceneID.contains("target-zone") {
            var region = Path()
            region.move(to: origin)
            region.addLine(to: CGPoint(x: size.width * 0.68, y: origin.y))
            region.addLine(to: CGPoint(x: size.width * 0.53, y: size.height * 0.34))
            region.addLine(to: CGPoint(x: origin.x, y: size.height * 0.50))
            region.closeSubpath()
            context.fill(region, with: .color(Color.yellow.opacity(0.44)))
            context.stroke(region, with: .color(Tokens.warningInk), lineWidth: 4)
            geometryLabel("가능 영역", at: CGPoint(x: size.width * 0.40, y: size.height * 0.60), color: Tokens.warningInk, context: &context)
        } else {
            geometryLine([origin, CGPoint(x: size.width * 0.43, y: size.height * 0.61), CGPoint(x: size.width * 0.70, y: size.height * 0.36), CGPoint(x: size.width * 0.88, y: size.height * 0.24)], color: Tokens.progressBlue, context: &context)
            geometryLabel("기울기 = 변화량 ÷ 간격", at: CGPoint(x: size.width * 0.58, y: size.height * 0.86), color: Tokens.progressBlue, context: &context)
        }
    }

    private func drawVocationalGeometry(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("box-two") || sceneID.contains("hinge") || sceneID.contains("opposite") || sceneID.contains("carton-net") || sceneID.contains("folding-preview") {
            let side = min(size.width * 0.14, size.height * 0.22)
            let origin = CGPoint(x: size.width * 0.5 - side * 0.5, y: size.height * 0.42 - side * 0.5)
            let offsets: [(Int, Int)] = [(0, 0), (-1, 0), (1, 0), (2, 0), (0, -1), (0, 1)]
            for (index, offset) in offsets.enumerated() {
                let rect = CGRect(x: origin.x + CGFloat(offset.0) * side, y: origin.y + CGFloat(offset.1) * side, width: side, height: side)
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(index == 0 ? Color.yellow.opacity(0.62) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(index == 0 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
            }
            geometryLabel("붙은 변은 접히고, 마주 보는 면은 떨어진다", at: CGPoint(x: size.width * 0.5, y: size.height * 0.84), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("camera") || sceneID.contains("height-grid") || sceneID.contains("silhouette") || sceneID.contains("pallet") || sceneID.contains("projection") {
            let labels = ["정면", "평면", "측면"]
            for index in 0..<3 {
                let rect = CGRect(x: size.width * (0.06 + CGFloat(index) * 0.31), y: size.height * 0.28, width: size.width * 0.25, height: size.height * 0.42)
                context.stroke(Path(roundedRect: rect, cornerRadius: 12), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                for line in 1..<3 {
                    let x = rect.minX + rect.width * CGFloat(line) / 3
                    let y = rect.minY + rect.height * CGFloat(line) / 3
                    geometryLine([CGPoint(x: x, y: rect.minY), CGPoint(x: x, y: rect.maxY)], color: Tokens.lineStrong, dashed: true, context: &context)
                    geometryLine([CGPoint(x: rect.minX, y: y), CGPoint(x: rect.maxX, y: y)], color: Tokens.lineStrong, dashed: true, context: &context)
                }
                geometryLabel(labels[index], at: CGPoint(x: rect.midX, y: rect.maxY + 28), color: index == 1 ? Tokens.warningInk : Tokens.text2, context: &context)
            }
            geometryLabel("한 시점이 가리는 정보를 세 방향으로 교차검사", at: CGPoint(x: size.width * 0.5, y: size.height * 0.87), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("template") || sceneID.contains("corresponding") || sceneID.contains("area-scale") || sceneID.contains("floorplan") || sceneID.contains("move-or-scale") {
            let small = CGRect(x: size.width * 0.13, y: size.height * 0.38, width: size.width * 0.22, height: size.height * 0.25)
            let large = CGRect(x: size.width * 0.55, y: size.height * 0.24, width: size.width * 0.34, height: size.height * 0.43)
            context.fill(Path(roundedRect: small, cornerRadius: 8), with: .color(Tokens.paper2))
            context.stroke(Path(roundedRect: small, cornerRadius: 8), with: .color(Tokens.progressBlue), lineWidth: 4)
            context.fill(Path(roundedRect: large, cornerRadius: 8), with: .color(Color.yellow.opacity(0.46)))
            context.stroke(Path(roundedRect: large, cornerRadius: 8), with: .color(Tokens.warningInk), lineWidth: 4)
            geometryLabel("길이 ×k", at: CGPoint(x: small.midX, y: small.maxY + 30), color: Tokens.progressBlue, context: &context)
            geometryLabel("넓이 ×k²", at: CGPoint(x: large.midX, y: large.maxY + 30), color: Tokens.warningInk, context: &context)
            return
        }
        let box = CGRect(x: size.width * 0.27, y: size.height * 0.28, width: size.width * 0.46, height: size.height * 0.40)
        context.fill(Path(roundedRect: box, cornerRadius: 16), with: .color(Color.yellow.opacity(0.28)))
        context.stroke(Path(roundedRect: box, cornerRadius: 16), with: .color(Tokens.progressBlue), lineWidth: 5)
        let inset = box.insetBy(dx: box.width * 0.15, dy: box.height * 0.18)
        context.stroke(Path(roundedRect: inset, cornerRadius: 12), with: .color(Tokens.warningInk), lineWidth: 4)
        geometryLine([CGPoint(x: box.minX, y: box.minY), CGPoint(x: inset.minX, y: inset.minY)], color: Tokens.text3, context: &context)
        geometryLine([CGPoint(x: box.maxX, y: box.minY), CGPoint(x: inset.maxX, y: inset.minY)], color: Tokens.text3, context: &context)
        geometryLabel("겉넓이 = 포장하는 면", at: CGPoint(x: size.width * 0.5, y: size.height * 0.18), color: Tokens.progressBlue, context: &context)
        geometryLabel("부피 = 담기는 공간", at: CGPoint(x: size.width * 0.5, y: size.height * 0.82), color: Tokens.warningInk, context: &context)
    }

    private func drawVocationalData(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID.contains("choice-tree") || sceneID.contains("and-or") || sceneID.contains("restriction") || sceneID.contains("uniform-order") || sceneID.contains("path-count") {
            let root = CGPoint(x: size.width * 0.16, y: size.height * 0.50)
            let middle = [CGPoint(x: size.width * 0.45, y: size.height * 0.30), CGPoint(x: size.width * 0.45, y: size.height * 0.70)]
            let leaves = [CGPoint(x: size.width * 0.78, y: size.height * 0.19), CGPoint(x: size.width * 0.78, y: size.height * 0.40), CGPoint(x: size.width * 0.78, y: size.height * 0.60), CGPoint(x: size.width * 0.78, y: size.height * 0.81)]
            middle.forEach { geometryLine([root, $0], color: Tokens.progressBlue, context: &context) }
            geometryLine([middle[0], leaves[0]], color: Tokens.progressBlue, context: &context)
            geometryLine([middle[0], leaves[1]], color: Tokens.progressBlue, context: &context)
            geometryLine([middle[1], leaves[2]], color: Tokens.progressBlue, context: &context)
            geometryLine([middle[1], leaves[3]], color: Tokens.progressBlue, context: &context)
            geometryPoint(root, emphasized: true, context: &context)
            middle.forEach { geometryPoint($0, context: &context) }
            leaves.forEach { geometryPoint($0, emphasized: true, context: &context) }
            geometryLabel("그리고 = 가지를 이어 곱하기 · 또는 = 갈래를 모아 더하기", at: CGPoint(x: size.width * 0.5, y: size.height * 0.92), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("frequency") || sceneID.contains("denominator") || sceneID.contains("certainty") || sceneID.contains("risk") || sceneID.contains("chance") {
            let gauge = CGRect(x: size.width * 0.12, y: size.height * 0.40, width: size.width * 0.76, height: size.height * 0.20)
            context.fill(Path(roundedRect: gauge, cornerRadius: 18), with: .color(Tokens.paper2))
            let count = CGRect(x: gauge.minX, y: gauge.minY, width: gauge.width * 0.28, height: gauge.height)
            context.fill(Path(roundedRect: count, cornerRadius: 18), with: .color(Color.yellow.opacity(0.68)))
            context.stroke(Path(roundedRect: gauge, cornerRadius: 18), with: .color(Tokens.progressBlue), lineWidth: 4)
            geometryLabel("위험 14회", at: CGPoint(x: count.midX, y: count.midY), color: Tokens.warningInk, context: &context)
            geometryLabel("전체 50회", at: CGPoint(x: gauge.midX, y: gauge.minY - 34), color: Tokens.ink, context: &context)
            geometryLabel("14 ÷ 50 = 0.28 · 표본 크기와 맥락까지", at: CGPoint(x: size.width * 0.5, y: size.height * 0.78), color: Tokens.progressBlue, context: &context)
            return
        }
        if sceneID.contains("decision") || sceneID.contains("criterion") || sceneID.contains("single-metric") || sceneID.contains("supplier") || sceneID.contains("evidence-decision") {
            let cards: [(String, String)] = [("가격", "40%"), ("불량률", "35%"), ("납기", "25%")]
            for (index, card) in cards.enumerated() {
                let rect = CGRect(x: size.width * (0.06 + CGFloat(index) * 0.31), y: size.height * 0.31, width: size.width * 0.25, height: size.height * 0.36)
                context.fill(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Color.yellow.opacity(0.58) : Tokens.paper2))
                context.stroke(Path(roundedRect: rect, cornerRadius: 16), with: .color(index == 1 ? Tokens.warningInk : Tokens.progressBlue), lineWidth: 3)
                geometryLabel(card.0, at: CGPoint(x: rect.midX, y: rect.midY - 22), color: Tokens.ink, context: &context)
                geometryLabel(card.1, at: CGPoint(x: rect.midX, y: rect.midY + 24), color: Tokens.text2, context: &context)
            }
            geometryLabel("기준·측정값·가중치를 함께 공개", at: CGPoint(x: size.width * 0.5, y: size.height * 0.84), color: Tokens.progressBlue, context: &context)
            return
        }
        let origin = CGPoint(x: size.width * 0.14, y: size.height * 0.78)
        geometryLine([origin, CGPoint(x: size.width * 0.90, y: origin.y)], color: Tokens.ink, context: &context)
        geometryLine([origin, CGPoint(x: origin.x, y: size.height * 0.16)], color: Tokens.ink, context: &context)
        let bars: [(CGFloat, CGFloat)] = [(0.24, 0.52), (0.39, 0.40), (0.54, 0.61), (0.69, 0.30), (0.84, 0.22)]
        for (index, item) in bars.enumerated() {
            let rect = CGRect(x: size.width * item.0 - 18, y: size.height * item.1, width: 36, height: origin.y - size.height * item.1)
            context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(index == 3 ? Color.yellow.opacity(0.74) : Tokens.primarySoft))
        }
        if sceneID.contains("truncated-axis") {
            geometryLabel("⚠ 0이 아닌 축: 차이가 과장될 수 있음", at: CGPoint(x: size.width * 0.55, y: size.height * 0.90), color: Tokens.warningInk, context: &context)
        } else {
            geometryLabel("목적 → 정리 → 그래프 → 근거 문장", at: CGPoint(x: size.width * 0.55, y: size.height * 0.90), color: Tokens.progressBlue, context: &context)
        }
    }

    private func drawVocationalMathScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if vocationalNumberSceneIDs.contains(sceneID) {
            drawVocationalNumber(context: &context, size: size, beat: beat)
        } else if vocationalRelationSceneIDs.contains(sceneID) {
            drawVocationalRelation(context: &context, size: size, beat: beat)
        } else if vocationalGeometrySceneIDs.contains(sceneID) {
            drawVocationalGeometry(context: &context, size: size, beat: beat)
        } else {
            drawVocationalData(context: &context, size: size, beat: beat)
        }
    }

    private func drawGeometryCourseConic(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if geometryParabolaSceneIDs.contains(sceneID) {
            let directrixX = size.width * 0.19
            geometryLine(
                [CGPoint(x: directrixX, y: size.height * 0.16), CGPoint(x: directrixX, y: size.height * 0.84)],
                color: Tokens.warningInk,
                dashed: true,
                context: &context
            )
            var curve = Path()
            curve.move(to: CGPoint(x: size.width * 0.32, y: size.height * 0.10))
            curve.addCurve(
                to: CGPoint(x: size.width * 0.32, y: size.height * 0.90),
                control1: CGPoint(x: size.width * 0.72, y: size.height * 0.26),
                control2: CGPoint(x: size.width * 0.72, y: size.height * 0.74)
            )
            context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
            let focus = CGPoint(x: size.width * 0.43, y: size.height * 0.50)
            let moving = CGPoint(x: size.width * 0.59, y: size.height * 0.27)
            geometryPoint(focus, emphasized: true, context: &context)
            geometryPoint(moving, context: &context)
            geometryLine([moving, focus], color: Tokens.text3, dashed: true, context: &context)
            geometryLine([moving, CGPoint(x: directrixX, y: moving.y)], color: Tokens.text3, dashed: true, context: &context)
            geometryLabel("초점 F(p,0)", at: CGPoint(x: focus.x, y: focus.y + 28), color: Tokens.ink, context: &context)
            geometryLabel("준선 x=−p", at: CGPoint(x: directrixX, y: size.height * 0.91), color: Tokens.warningInk, context: &context)
            geometryLabel("두 거리 = 같음", at: CGPoint(x: size.width * 0.72, y: size.height * 0.15), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometryEllipseSceneIDs.contains(sceneID) {
            let ellipse = CGRect(x: size.width * 0.14, y: size.height * 0.24, width: size.width * 0.72, height: size.height * 0.52)
            context.stroke(Path(ellipseIn: ellipse), with: .color(Tokens.progressBlue), lineWidth: 6)
            let f1 = CGPoint(x: size.width * 0.36, y: ellipse.midY)
            let f2 = CGPoint(x: size.width * 0.64, y: ellipse.midY)
            let moving = CGPoint(x: size.width * 0.62, y: ellipse.minY + 8)
            geometryPoint(f1, emphasized: true, context: &context)
            geometryPoint(f2, emphasized: true, context: &context)
            geometryPoint(moving, context: &context)
            geometryLine([moving, f1], color: Tokens.text3, dashed: true, context: &context)
            geometryLine([moving, f2], color: Tokens.text3, dashed: true, context: &context)
            geometryLabel("F₁", at: CGPoint(x: f1.x, y: f1.y + 28), color: Tokens.ink, context: &context)
            geometryLabel("F₂", at: CGPoint(x: f2.x, y: f2.y + 28), color: Tokens.ink, context: &context)
            geometryLabel("PF₁ + PF₂ = 2a", at: CGPoint(x: size.width * 0.5, y: size.height * 0.88), color: Tokens.progressBlue, context: &context)
            geometryLabel("c² = a² − b²", at: CGPoint(x: size.width * 0.76, y: size.height * 0.13), color: Tokens.warningInk, context: &context)
            return
        }

        if geometryHyperbolaSceneIDs.contains(sceneID) {
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            geometryLine([CGPoint(x: size.width * 0.14, y: size.height * 0.13), CGPoint(x: size.width * 0.86, y: size.height * 0.87)], color: Tokens.text3, dashed: true, context: &context)
            geometryLine([CGPoint(x: size.width * 0.14, y: size.height * 0.87), CGPoint(x: size.width * 0.86, y: size.height * 0.13)], color: Tokens.text3, dashed: true, context: &context)
            var left = Path()
            left.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.16))
            left.addCurve(to: CGPoint(x: size.width * 0.08, y: size.height * 0.84), control1: CGPoint(x: size.width * 0.33, y: size.height * 0.28), control2: CGPoint(x: size.width * 0.33, y: size.height * 0.72))
            var right = Path()
            right.move(to: CGPoint(x: size.width * 0.92, y: size.height * 0.16))
            right.addCurve(to: CGPoint(x: size.width * 0.92, y: size.height * 0.84), control1: CGPoint(x: size.width * 0.67, y: size.height * 0.28), control2: CGPoint(x: size.width * 0.67, y: size.height * 0.72))
            context.stroke(left, with: .color(Tokens.progressBlue), lineWidth: 6)
            context.stroke(right, with: .color(Tokens.progressBlue), lineWidth: 6)
            let f1 = CGPoint(x: size.width * 0.28, y: center.y)
            let f2 = CGPoint(x: size.width * 0.72, y: center.y)
            geometryPoint(f1, emphasized: true, context: &context)
            geometryPoint(f2, emphasized: true, context: &context)
            geometryLabel("|PF₁ − PF₂| = 2a", at: CGPoint(x: center.x, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            geometryLabel("c² = a² + b²", at: CGPoint(x: size.width * 0.75, y: size.height * 0.12), color: Tokens.warningInk, context: &context)
            return
        }

        var curve = Path()
        curve.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.82))
        curve.addCurve(to: CGPoint(x: size.width * 0.57, y: size.height * 0.20), control1: CGPoint(x: size.width * 0.30, y: size.height * 0.80), control2: CGPoint(x: size.width * 0.43, y: size.height * 0.54))
        context.stroke(curve, with: .color(Tokens.progressBlue), lineWidth: 6)
        geometryLine([CGPoint(x: size.width * 0.13, y: size.height * 0.80), CGPoint(x: size.width * 0.86, y: size.height * 0.28)], color: Tokens.warningInk, context: &context)
        let contact = CGPoint(x: size.width * 0.49, y: size.height * 0.50)
        geometryPoint(contact, emphasized: true, context: &context)
        geometryLabel("연립 → 중근", at: CGPoint(x: size.width * 0.50, y: size.height * 0.12), color: Tokens.ink, context: &context)
        geometryLabel("접점 1개 · D=0", at: CGPoint(x: size.width * 0.72, y: size.height * 0.78), color: Tokens.progressBlue, context: &context)
    }

    private func drawGeometryCourseSpace(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if geometrySpaceRelationSceneIDs.contains(sceneID) {
            let front = CGRect(x: size.width * 0.16, y: size.height * 0.34, width: size.width * 0.42, height: size.height * 0.40)
            let back = front.offsetBy(dx: size.width * 0.20, dy: -size.height * 0.18)
            context.stroke(Path(front), with: .color(Tokens.progressBlue), lineWidth: 5)
            context.stroke(Path(back), with: .color(Tokens.progressBlue), lineWidth: 5)
            let pairs = [
                [CGPoint(x: front.minX, y: front.minY), CGPoint(x: back.minX, y: back.minY)],
                [CGPoint(x: front.maxX, y: front.minY), CGPoint(x: back.maxX, y: back.minY)],
                [CGPoint(x: front.maxX, y: front.maxY), CGPoint(x: back.maxX, y: back.maxY)],
                [CGPoint(x: front.minX, y: front.maxY), CGPoint(x: back.minX, y: back.maxY)],
            ]
            pairs.forEach { geometryLine($0, color: Tokens.text3, dashed: true, context: &context) }
            geometryLabel("공유점? 방향? 공통 평면?", at: CGPoint(x: size.width * 0.5, y: size.height * 0.90), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometryThreePerpendicularSceneIDs.contains(sceneID) {
            let plane = [CGPoint(x: size.width * 0.12, y: size.height * 0.68), CGPoint(x: size.width * 0.74, y: size.height * 0.68), CGPoint(x: size.width * 0.88, y: size.height * 0.84), CGPoint(x: size.width * 0.26, y: size.height * 0.84), CGPoint(x: size.width * 0.12, y: size.height * 0.68)]
            geometryLine(plane, color: Tokens.progressBlue, context: &context)
            let p = CGPoint(x: size.width * 0.39, y: size.height * 0.16)
            let h = CGPoint(x: size.width * 0.39, y: size.height * 0.71)
            let q = CGPoint(x: size.width * 0.69, y: size.height * 0.71)
            geometryLine([p, h, q], color: Tokens.text3, context: &context)
            geometryLine([p, q], color: Tokens.warningInk, context: &context)
            [(p, "P"), (h, "H"), (q, "Q")].forEach { item in
                geometryPoint(item.0, emphasized: true, context: &context)
                geometryLabel(item.1, at: CGPoint(x: item.0.x - 18, y: item.0.y - 16), color: Tokens.ink, context: &context)
            }
            geometryLabel("PH ⟂ 평면 · HQ ⟂ l ⇒ PQ ⟂ l", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometryProjectionSceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.10, y: size.height * 0.72), CGPoint(x: size.width * 0.80, y: size.height * 0.72), CGPoint(x: size.width * 0.91, y: size.height * 0.84), CGPoint(x: size.width * 0.21, y: size.height * 0.84), CGPoint(x: size.width * 0.10, y: size.height * 0.72)], color: Tokens.progressBlue, context: &context)
            let start = CGPoint(x: size.width * 0.24, y: size.height * 0.72)
            let end = CGPoint(x: size.width * 0.72, y: size.height * 0.20)
            let shadow = CGPoint(x: end.x, y: start.y)
            geometryLine([start, end], color: Tokens.warningInk, context: &context)
            geometryLine([start, shadow, end], color: Tokens.text3, dashed: true, context: &context)
            geometryLabel("원래 L", at: CGPoint(x: size.width * 0.53, y: size.height * 0.38), color: Tokens.ink, context: &context)
            geometryLabel("정사영 L cosθ", at: CGPoint(x: size.width * 0.49, y: size.height * 0.78), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometrySpaceCoordinateSceneIDs.contains(sceneID) {
            let origin = CGPoint(x: size.width * 0.34, y: size.height * 0.70)
            geometryLine([origin, CGPoint(x: size.width * 0.88, y: origin.y)], color: Tokens.text3, context: &context)
            geometryLine([origin, CGPoint(x: size.width * 0.12, y: size.height * 0.88)], color: Tokens.text3, context: &context)
            geometryLine([origin, CGPoint(x: origin.x, y: size.height * 0.14)], color: Tokens.text3, context: &context)
            let a = CGPoint(x: size.width * 0.45, y: size.height * 0.61)
            let b = CGPoint(x: size.width * 0.76, y: size.height * 0.28)
            let p = CGPoint(x: size.width * 0.66, y: size.height * 0.39)
            geometryLine([a, b], color: Tokens.progressBlue, context: &context)
            [(a, "A"), (p, "P"), (b, "B")].forEach { item in
                geometryPoint(item.0, emphasized: item.1 == "P", context: &context)
                geometryLabel(item.1, at: CGPoint(x: item.0.x, y: item.0.y - 20), color: Tokens.ink, context: &context)
            }
            geometryLabel("거리: Δx²+Δy²+Δz²", at: CGPoint(x: size.width * 0.55, y: size.height * 0.89), color: Tokens.progressBlue, context: &context)
            geometryLabel("반대편 비로 내분", at: CGPoint(x: size.width * 0.71, y: size.height * 0.13), color: Tokens.warningInk, context: &context)
            return
        }

        let shell = CGRect(x: size.width * 0.28, y: size.height * 0.14, width: size.width * 0.44, height: size.height * 0.66)
        context.stroke(Path(ellipseIn: shell), with: .color(Tokens.progressBlue), lineWidth: 5)
        context.stroke(Path(ellipseIn: CGRect(x: shell.minX, y: shell.midY - 44, width: shell.width, height: 88)), with: .color(Tokens.text3), style: StrokeStyle(lineWidth: 3, dash: [7, 5]))
        let center = CGPoint(x: shell.midX, y: shell.midY)
        geometryPoint(center, emphasized: true, context: &context)
        geometryLine([center, CGPoint(x: shell.maxX - 24, y: shell.minY + 42)], color: Tokens.warningInk, context: &context)
        geometryLabel("중심 C(a,b,c)", at: CGPoint(x: center.x, y: center.y + 28), color: Tokens.ink, context: &context)
        geometryLabel("(x−a)²+(y−b)²+(z−c)²=r²", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
    }

    private func drawGeometryCourseVector(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if geometryVectorOperationSceneIDs.contains(sceneID) {
            let o = CGPoint(x: size.width * 0.12, y: size.height * 0.78)
            let a = CGPoint(x: size.width * 0.42, y: size.height * 0.28)
            let b = CGPoint(x: size.width * 0.78, y: size.height * 0.48)
            geometryLine([o, a, b], color: Tokens.progressBlue, context: &context)
            geometryLine([o, b], color: Tokens.warningInk, context: &context)
            geometryLabel("a", at: CGPoint(x: size.width * 0.27, y: size.height * 0.47), color: Tokens.ink, context: &context)
            geometryLabel("b", at: CGPoint(x: size.width * 0.60, y: size.height * 0.32), color: Tokens.ink, context: &context)
            geometryLabel("a+b", at: CGPoint(x: size.width * 0.47, y: size.height * 0.70), color: Tokens.progressBlue, context: &context)
            geometryLabel("끝에 시작을 붙여 처음→마지막", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometryPositionVectorSceneIDs.contains(sceneID) {
            let o = CGPoint(x: size.width * 0.13, y: size.height * 0.82)
            let a = CGPoint(x: size.width * 0.45, y: size.height * 0.52)
            let b = CGPoint(x: size.width * 0.82, y: size.height * 0.19)
            geometryLine([o, a], color: Tokens.text3, context: &context)
            geometryLine([o, b], color: Tokens.text3, context: &context)
            geometryLine([a, b], color: Tokens.warningInk, context: &context)
            [(o, "O"), (a, "A"), (b, "B")].forEach { item in
                geometryPoint(item.0, emphasized: true, context: &context)
                geometryLabel(item.1, at: CGPoint(x: item.0.x, y: item.0.y + 24), color: Tokens.ink, context: &context)
            }
            geometryLabel("AB = OB − OA = B − A", at: CGPoint(x: size.width * 0.53, y: size.height * 0.90), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometryDotProductSceneIDs.contains(sceneID) {
            let o = CGPoint(x: size.width * 0.16, y: size.height * 0.76)
            let a = CGPoint(x: size.width * 0.84, y: size.height * 0.76)
            let b = CGPoint(x: size.width * 0.62, y: size.height * 0.20)
            geometryLine([o, a], color: Tokens.progressBlue, context: &context)
            geometryLine([o, b], color: Tokens.warningInk, context: &context)
            geometryLine([b, CGPoint(x: b.x, y: o.y)], color: Tokens.text3, dashed: true, context: &context)
            geometryLabel("a 방향 그림자", at: CGPoint(x: size.width * 0.56, y: size.height * 0.84), color: Tokens.ink, context: &context)
            geometryLabel("a·b = |a||b|cosθ", at: CGPoint(x: size.width * 0.55, y: size.height * 0.12), color: Tokens.progressBlue, context: &context)
            return
        }

        if geometryLineSceneIDs.contains(sceneID) {
            geometryLine([CGPoint(x: size.width * 0.10, y: size.height * 0.84), CGPoint(x: size.width * 0.88, y: size.height * 0.18)], color: Tokens.progressBlue, context: &context)
            let items: [(CGPoint, String)] = [
                (CGPoint(x: size.width * 0.28, y: size.height * 0.69), "t=−1"),
                (CGPoint(x: size.width * 0.50, y: size.height * 0.50), "P₀"),
                (CGPoint(x: size.width * 0.72, y: size.height * 0.31), "t=1"),
            ]
            items.forEach { item in
                geometryPoint(item.0, emphasized: item.1 == "P₀", context: &context)
                geometryLabel(item.1, at: CGPoint(x: item.0.x, y: item.0.y - 22), color: Tokens.ink, context: &context)
            }
            geometryLabel("X = P₀ + t d", at: CGPoint(x: size.width * 0.5, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
            return
        }

        geometryLine([CGPoint(x: size.width * 0.10, y: size.height * 0.69), CGPoint(x: size.width * 0.74, y: size.height * 0.69), CGPoint(x: size.width * 0.89, y: size.height * 0.84), CGPoint(x: size.width * 0.25, y: size.height * 0.84), CGPoint(x: size.width * 0.10, y: size.height * 0.69)], color: Tokens.progressBlue, context: &context)
        let p = CGPoint(x: size.width * 0.42, y: size.height * 0.73)
        geometryLine([p, CGPoint(x: size.width * 0.61, y: size.height * 0.16)], color: Tokens.warningInk, context: &context)
        geometryPoint(p, emphasized: true, context: &context)
        geometryLabel("법선 n=(a,b,c)", at: CGPoint(x: size.width * 0.68, y: size.height * 0.16), color: Tokens.warningInk, context: &context)
        geometryLabel("n·(X−P)=0", at: CGPoint(x: size.width * 0.50, y: size.height * 0.91), color: Tokens.progressBlue, context: &context)
        context.stroke(Path(ellipseIn: CGRect(x: size.width * 0.72, y: size.height * 0.32, width: size.width * 0.16, height: size.width * 0.16)), with: .color(Tokens.text3), lineWidth: 3)
    }

    private func drawGeometryCourseScene(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if geometryParabolaSceneIDs.contains(sceneID)
            || geometryEllipseSceneIDs.contains(sceneID)
            || geometryHyperbolaSceneIDs.contains(sceneID)
            || geometryTangentSceneIDs.contains(sceneID) {
            drawGeometryCourseConic(context: &context, size: size, beat: beat)
        } else if geometrySpaceRelationSceneIDs.contains(sceneID)
            || geometryThreePerpendicularSceneIDs.contains(sceneID)
            || geometryProjectionSceneIDs.contains(sceneID)
            || geometrySpaceCoordinateSceneIDs.contains(sceneID)
            || geometrySphereSceneIDs.contains(sceneID) {
            drawGeometryCourseSpace(context: &context, size: size, beat: beat)
        } else {
            drawGeometryCourseVector(context: &context, size: size, beat: beat)
        }
    }

    private func drawPlot(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if probabilityStatisticsSceneIDs.contains(sceneID) {
            drawProbabilityStatisticsScene(context: &context, size: size, beat: beat)
            return
        }
        if calculusOneSceneIDs.contains(sceneID) {
            drawCalculusOneScene(context: &context, size: size, beat: beat)
            return
        }
        if algebraSequenceSceneIDs.contains(sceneID) {
            drawAlgebraSequenceScene(context: &context, size: size, beat: beat)
            return
        }
        if algebraTrigonometrySceneIDs.contains(sceneID) {
            drawAlgebraTrigonometryScene(context: &context, size: size, beat: beat)
            return
        }
        if algebraLogFunctionSceneIDs.contains(sceneID) {
            drawAlgebraLogFunctionScene(context: &context, size: size, beat: beat)
            return
        }
        if algebraPowerExponentSceneIDs.contains(sceneID) {
            drawAlgebraPowerExponentScene(context: &context, size: size, beat: beat)
            return
        }
        if coordinateGeometrySceneIDs.contains(sceneID) {
            drawCoordinateGeometryScene(context: &context, size: size, beat: beat)
            return
        }
        if setsPropositionsSceneIDs.contains(sceneID) {
            drawSetsPropositionsScene(context: &context, size: size, beat: beat)
            return
        }
        if functionsGraphsSceneIDs.contains(sceneID) {
            drawFunctionsGraphsScene(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("matrix-") {
            drawMatrixGrid(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("counting-") {
            drawCountingTree(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("permutation-") {
            drawPermutationSlots(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("combination-") {
            drawCombinationGroups(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("complex-") {
            drawComplexPlane(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("simquad-") {
            drawIntersectionPlot(context: &context, size: size, beat: beat)
            return
        }
        if sceneID.hasPrefix("simlinear-")
            || sceneID.hasPrefix("absolute-")
            || sceneID.hasPrefix("quadineq-") {
            drawNumberLine(context: &context, size: size, beat: beat)
            return
        }
        let values: [CGFloat] = [64, 104, 154, 92, 184]
        for (index, height) in values.enumerated() {
            let rect = CGRect(
                x: 58 + CGFloat(index) * 82,
                y: size.height - 50 - height,
                width: 48,
                height: height
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 7),
                with: .color(index == 4 ? Color.yellow.opacity(0.65) : Tokens.primarySoft)
            )
        }
        if beat.action == "group" {
            var reference = Path()
            reference.move(to: CGPoint(x: 44, y: size.height * 0.53))
            reference.addLine(to: CGPoint(x: size.width - 36, y: size.height * 0.53))
            context.stroke(
                reference,
                with: .color(Tokens.warningInk),
                style: StrokeStyle(lineWidth: 3, dash: [8, 6])
            )
        }
    }

    private func drawComplexPlane(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
        var axes = Path()
        axes.move(to: CGPoint(x: 44, y: center.y))
        axes.addLine(to: CGPoint(x: size.width - 36, y: center.y))
        axes.move(to: CGPoint(x: center.x, y: size.height - 34))
        axes.addLine(to: CGPoint(x: center.x, y: 62))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)

        context.draw(
            Text("실수").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2),
            at: CGPoint(x: size.width - 48, y: center.y - 18)
        )
        context.draw(
            Text("허수 i").font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2),
            at: CGPoint(x: center.x + 34, y: 76)
        )

        let point = CGPoint(x: size.width * 0.73, y: size.height * 0.28)
        var guides = Path()
        guides.move(to: center)
        guides.addLine(to: CGPoint(x: point.x, y: center.y))
        guides.addLine(to: point)
        context.stroke(
            guides,
            with: .color(Tokens.progressBlue),
            style: StrokeStyle(lineWidth: 3, dash: [8, 6])
        )
        context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(Color.yellow))
        context.stroke(Path(ellipseIn: CGRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48)), with: .color(Tokens.warningInk), lineWidth: 4)
        context.draw(
            Text("3+2i").font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink),
            at: CGPoint(x: point.x + 42, y: point.y - 18)
        )
    }

    private func drawIntersectionPlot(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        var axes = Path()
        axes.move(to: CGPoint(x: 42, y: size.height - 52))
        axes.addLine(to: CGPoint(x: size.width - 32, y: size.height - 52))
        axes.move(to: CGPoint(x: size.width * 0.32, y: size.height - 28))
        axes.addLine(to: CGPoint(x: size.width * 0.32, y: 62))
        context.stroke(axes, with: .color(Tokens.text3), lineWidth: 3)

        let oval = CGRect(
            x: size.width * 0.28,
            y: size.height * 0.28,
            width: min(size.width * 0.43, 210),
            height: min(size.height * 0.40, 150)
        )
        context.stroke(Path(ellipseIn: oval), with: .color(Tokens.progressBlue), lineWidth: 5)
        var line = Path()
        line.move(to: CGPoint(x: 72, y: size.height - 64))
        line.addLine(to: CGPoint(x: size.width - 54, y: 82))
        context.stroke(line, with: .color(Tokens.text2), lineWidth: 4)
        for point in [
            CGPoint(x: size.width * 0.43, y: size.height * 0.57),
            CGPoint(x: size.width * 0.70, y: size.height * 0.35),
        ] {
            context.fill(Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)), with: .color(Color.yellow))
            context.stroke(Path(ellipseIn: CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)), with: .color(Tokens.warningInk), lineWidth: 3)
        }
    }

    private func drawNumberLine(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let y = size.height * 0.58
        let left = size.width * 0.32
        let right = size.width * 0.70
        var axis = Path()
        axis.move(to: CGPoint(x: 38, y: y))
        axis.addLine(to: CGPoint(x: size.width - 38, y: y))
        context.stroke(axis, with: .color(Tokens.text3), lineWidth: 3)

        let outside = sceneID.contains("outside")
            || sceneID.contains("two-rays")
            || sceneID.contains("system-intersection")
        var selected = Path()
        if outside {
            selected.move(to: CGPoint(x: 46, y: y))
            selected.addLine(to: CGPoint(x: left, y: y))
            selected.move(to: CGPoint(x: right, y: y))
            selected.addLine(to: CGPoint(x: size.width - 46, y: y))
        } else {
            selected.move(to: CGPoint(x: left, y: y))
            selected.addLine(to: CGPoint(x: right, y: y))
        }
        context.stroke(selected, with: .color(Tokens.progressBlue), lineWidth: 12)

        for (index, x) in [left, right].enumerated() {
            let rect = CGRect(x: x - 9, y: y - 9, width: 18, height: 18)
            context.fill(Path(ellipseIn: rect), with: .color(index == 0 ? Color.yellow : Tokens.surface))
            context.stroke(Path(ellipseIn: rect), with: .color(Tokens.warningInk), lineWidth: 3)
        }
        context.draw(
            Text(outside ? "두 경계 바깥" : "두 조건이 겹치는 구간")
                .font(.mCallout.weight(.black))
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: size.width * 0.5, y: y - 38)
        )
    }

    private func drawCountingTree(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        if sceneID == "counting-overlap" {
            let radius = min(size.width * 0.19, 108)
            let left = CGRect(
                x: size.width * 0.5 - radius * 1.55,
                y: size.height * 0.34,
                width: radius * 2,
                height: radius * 2
            )
            let right = left.offsetBy(dx: radius * 1.1, dy: 0)
            context.fill(Path(ellipseIn: left), with: .color(Tokens.primarySoft.opacity(0.58)))
            context.fill(Path(ellipseIn: right), with: .color(Color.yellow.opacity(0.38)))
            context.stroke(Path(ellipseIn: left), with: .color(Tokens.progressBlue), lineWidth: 4)
            context.stroke(Path(ellipseIn: right), with: .color(Tokens.warningInk), lineWidth: 4)
            context.draw(
                Text("축구 8").font(.mCallout.weight(.bold)).foregroundStyle(Tokens.ink),
                at: CGPoint(x: left.midX - radius * 0.35, y: left.minY + 48)
            )
            context.draw(
                Text("농구 6").font(.mCallout.weight(.bold)).foregroundStyle(Tokens.ink),
                at: CGPoint(x: right.midX + radius * 0.35, y: right.minY + 48)
            )
            context.draw(
                Text("겹침 2").font(.mBodyB).foregroundStyle(Tokens.warningInk),
                at: CGPoint(x: size.width * 0.5, y: left.midY)
            )
            if beat.action == "point" || beat.action == "verify" {
                context.stroke(
                    Path(ellipseIn: CGRect(
                        x: size.width * 0.5 - 34,
                        y: left.minY + 18,
                        width: 68,
                        height: radius * 1.65
                    )),
                    with: .color(Tokens.warningInk),
                    lineWidth: 4
                )
            }
            return
        }

        var rootLabel = "코드"
        var labels = ["A", "B", "C"]
        var leafCounts = [4, 4, 4]
        if sceneID == "counting-paths" {
            rootLabel = "출발"
            if beat.id == "follow-consecutive" {
                labels = ["셔츠 1", "셔츠 2", "셔츠 3"]
                leafCounts = [2, 2, 2]
            } else if beat.id == "name-operation" {
                labels = ["또는 +", "그리고 ×"]
                leafCounts = [1, 1]
            } else {
                labels = ["버스 3", "지하철 2"]
                leafCounts = [3, 2]
            }
        } else if sceneID == "counting-mixed-dessert" {
            rootLabel = "주문"
            labels = ["케이크 2", "아이스 3"]
            leafCounts = [4, 4]
        } else if sceneID == "counting-law-recall" {
            rootLabel = "판단"
            labels = ["대안 +", "연속 ×", "겹침 −"]
            leafCounts = [1, 1, 1]
        }
        let root = CGRect(x: 34, y: size.height * 0.48, width: 92, height: 58)
        context.fill(Path(roundedRect: root, cornerRadius: 12), with: .color(Color.yellow.opacity(0.56)))
        context.stroke(Path(roundedRect: root, cornerRadius: 12), with: .color(Tokens.warningInk), lineWidth: 3)
        context.draw(
            Text(rootLabel).font(.mCallout.weight(.black)).foregroundStyle(Tokens.ink),
            at: CGPoint(x: root.midX, y: root.midY)
        )

        for (index, label) in labels.enumerated() {
            let fraction = CGFloat(index + 1) / CGFloat(labels.count + 1)
            let y = size.height * (0.25 + fraction * 0.56)
            let first = CGRect(x: size.width * 0.27, y: y - 24, width: 110, height: 48)
            var branch = Path()
            branch.move(to: CGPoint(x: root.maxX, y: root.midY))
            branch.addCurve(
                to: CGPoint(x: first.minX, y: first.midY),
                control1: CGPoint(x: size.width * 0.20, y: root.midY),
                control2: CGPoint(x: size.width * 0.22, y: first.midY)
            )
            context.stroke(branch, with: .color(Tokens.progressBlue), lineWidth: 3)
            context.fill(Path(roundedRect: first, cornerRadius: 10), with: .color(Tokens.paper2))
            context.stroke(Path(roundedRect: first, cornerRadius: 10), with: .color(Tokens.lineStrong), lineWidth: 2)
            context.draw(
                Text(label).font(.mCallout.weight(.bold)).foregroundStyle(Tokens.ink),
                at: CGPoint(x: first.midX, y: first.midY)
            )
            for leaf in 0..<leafCounts[index] {
                let x = size.width * 0.56 + CGFloat(leaf) * min(62, size.width * 0.09)
                var link = Path()
                link.move(to: CGPoint(x: first.maxX, y: first.midY))
                link.addLine(to: CGPoint(x: x, y: first.midY))
                context.stroke(link, with: .color(Tokens.text3.opacity(0.62)), lineWidth: 2)
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 8, y: first.midY - 8, width: 16, height: 16)),
                    with: .color(leaf == 3 ? Color.yellow : Tokens.primarySoft)
                )
            }
        }
    }

    private func drawMatrixCells(
        context: inout GraphicsContext,
        origin: CGPoint,
        rows: Int,
        columns: Int,
        values: [String],
        label: String,
        highlightRow: Int = -1,
        highlightColumn: Int = -1,
        highlightCell: String = "",
        cell: CGSize
    ) {
        context.draw(
            Text(label).font(.mMicro.weight(.bold)).foregroundStyle(Tokens.text2),
            at: CGPoint(
                x: origin.x + CGFloat(columns) * cell.width / 2,
                y: origin.y - 18
            )
        )
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                let focused = row == highlightRow
                    || column == highlightColumn
                    || highlightCell == "\(row),\(column)"
                let rect = CGRect(
                    x: origin.x + CGFloat(column) * cell.width,
                    y: origin.y + CGFloat(row) * cell.height,
                    width: cell.width - 5,
                    height: cell.height - 5
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 8),
                    with: .color(focused ? Color.yellow.opacity(0.58) : Tokens.paper2)
                )
                context.stroke(
                    Path(roundedRect: rect, cornerRadius: 8),
                    with: .color(focused ? Tokens.warningInk : Tokens.lineStrong),
                    lineWidth: focused ? 3 : 2
                )
                context.draw(
                    Text(index < values.count ? values[index] : "")
                        .font(.mCallout.weight(.black))
                        .foregroundStyle(Tokens.ink),
                    at: CGPoint(x: rect.midX, y: rect.midY)
                )
            }
        }
    }

    private func drawMatrixGrid(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let conceptScenes = [
            "matrix-table",
            "matrix-size-entry",
            "matrix-shape-trap",
            "matrix-sales-model",
            "matrix-reading-recall",
        ]
        if conceptScenes.contains(sceneID) {
            var rows = 2
            var columns = 3
            var values = ["12", "8", "6", "5", "10", "9"]
            var label = "2행 × 3열"
            if sceneID == "matrix-table" || sceneID == "matrix-sales-model" {
                columns = 2
                values = ["30", "12", "25", "18"]
                label = "행: 서울·부산 / 열: 연필·공책"
            }
            if sceneID == "matrix-shape-trap" && beat.id == "reflow-three-by-two" {
                rows = 3
                columns = 2
                values = ["1", "2", "3", "4", "5", "6"]
                label = "3행 × 2열"
            }
            let cellWidth = min(86, (size.width - 64) / CGFloat(columns))
            let cellHeight: CGFloat = rows == 3 ? 58 : 72
            let totalWidth = cellWidth * CGFloat(columns)
            drawMatrixCells(
                context: &context,
                origin: CGPoint(x: (size.width - totalWidth) / 2, y: rows == 3 ? 108 : 132),
                rows: rows,
                columns: columns,
                values: values,
                label: label,
                highlightRow: beat.id.contains("count-rows") || beat.id.contains("read-entry") ? 1 : -1,
                highlightColumn: beat.id.contains("count-columns") ? 2 : -1,
                highlightCell: beat.id.contains("a21") || beat.id.contains("translate-a21") ? "1,0" : "",
                cell: CGSize(width: cellWidth, height: cellHeight)
            )
            return
        }

        let isScale = sceneID == "matrix-add-scale" && beat.id == "scale-a"
        let isProduct = [
            "matrix-elementwise-trap",
            "matrix-product-computed",
            "matrix-order-recall",
        ].contains(sceneID)
        let a = ["1", "2", "3", "4"]
        let b = isProduct ? ["2", "0", "1", "5"] : ["5", "−1", "0", "2"]
        let result = isScale
            ? ["2", "4", "6", "8"]
            : isProduct ? ["4", "10", "10", "20"] : ["6", "1", "3", "6"]
        let row = beat.id == "finish-product"
            ? 1
            : (beat.id.contains("product") || beat.id.contains("row-column") || beat.id.contains("trace") ? 0 : -1)
        let column = beat.id == "compute-first-row"
            ? 1
            : (beat.id.contains("product") || beat.id.contains("row-column") || beat.id.contains("trace") ? 0 : -1)
        let cellWidth = min(54, max(34, (size.width - 112) / 6))
        let cell = CGSize(width: cellWidth, height: min(56, cellWidth + 6))
        let matrixWidth = cell.width * 2
        let gap = max(12, (size.width - matrixWidth * 3) / 4)
        let y = size.height * 0.43
        let firstX = gap
        let secondX = gap * 2 + matrixWidth
        let thirdX = gap * 3 + matrixWidth * 2
        drawMatrixCells(
            context: &context,
            origin: CGPoint(x: firstX, y: y),
            rows: 2,
            columns: 2,
            values: a,
            label: "A",
            highlightRow: row,
            cell: cell
        )
        context.draw(
            Text(isScale ? "×2" : isProduct ? "×" : "+")
                .font(.mHeading)
                .foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: firstX + matrixWidth + gap / 2, y: y + cell.height)
        )
        if !isScale {
            drawMatrixCells(
                context: &context,
                origin: CGPoint(x: secondX, y: y),
                rows: 2,
                columns: 2,
                values: b,
                label: "B",
                highlightColumn: column,
                cell: cell
            )
        }
        context.draw(
            Text("=").font(.mHeading).foregroundStyle(Tokens.progressBlue),
            at: CGPoint(x: secondX + matrixWidth + gap / 2, y: y + cell.height)
        )
        drawMatrixCells(
            context: &context,
            origin: CGPoint(x: thirdX, y: y),
            rows: 2,
            columns: 2,
            values: result,
            label: isScale ? "2A" : isProduct ? "AB" : "A+B",
            highlightCell: row >= 0 && column >= 0 ? "\(row),\(column)" : "",
            cell: cell
        )
    }

    private func drawPermutationSlots(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let together = sceneID == "permutation-together-block"
        var labels = ["금", "은", "동"]
        var details = ["6가지", "5가지", "4가지"]
        if sceneID == "permutation-seats" {
            labels = ["왼쪽", "오른쪽"]
            details = ["2가지", "1가지"]
        } else if sceneID == "permutation-two-roles" {
            labels = ["회장", "부회장"]
            details = ["5가지", "4가지"]
        } else if sceneID == "permutation-combination-trap" {
            labels = ["두 사람", "회장", "부회장"]
            details = ["10묶음", "2배치", "20결과"]
        } else if together {
            labels = ["AB묶음", "C", "D"]
            details = ["AB / BA", "책", "책"]
        }
        let gap: CGFloat = 18
        let totalWidth = min(size.width - 64, 560)
        let slotWidth = (
            totalWidth - gap * CGFloat(labels.count - 1)
        ) / CGFloat(labels.count)
        let start = (size.width - totalWidth) / 2
        for (index, label) in labels.enumerated() {
            let rect = CGRect(
                x: start + CGFloat(index) * (slotWidth + gap),
                y: size.height * 0.43,
                width: slotWidth,
                height: 104
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 14),
                with: .color(index == 0 ? Color.yellow.opacity(0.55) : Tokens.paper2)
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 14),
                with: .color(index == 0 ? Tokens.warningInk : Tokens.lineStrong),
                lineWidth: 3
            )
            context.draw(
                Text(label).font(.mHeading).foregroundStyle(Tokens.ink),
                at: CGPoint(x: rect.midX, y: rect.midY - 14)
            )
            context.draw(
                Text(details[index])
                    .font(.mMicro.weight(.bold))
                    .foregroundStyle(Tokens.text2),
                at: CGPoint(x: rect.midX, y: rect.midY + 24)
            )
        }
        if beat.action == "group" || beat.action == "transform" || beat.action == "verify" {
            let highlight = CGRect(
                x: start - 12,
                y: size.height * 0.43 - 14,
                width: together ? slotWidth + 24 : totalWidth + 24,
                height: 132
            )
            context.stroke(
                Path(roundedRect: highlight, cornerRadius: 18),
                with: .color(Tokens.warningInk),
                style: StrokeStyle(lineWidth: 4, dash: [10, 7])
            )
        }
    }

    private func drawCombinationGroups(
        context: inout GraphicsContext,
        size: CGSize,
        beat: CurriculumMotionBeat
    ) {
        let required = sceneID == "combination-required-person"
        let symmetry = sceneID == "combination-symmetry-recall"
        var labels = ["AB", "BA", "{A,B}"]
        if sceneID == "combination-five-choose-two" {
            labels = ["순열 20", "2!씩 접기", "조합 10"]
        } else if sceneID == "combination-divisor-trap" {
            labels = ["6개 순서", "3!씩 접기", "한 팀"]
        } else if required {
            labels = ["민아", "빈칸", "빈칸"]
        } else if symmetry {
            labels = ["고른 r명", "남은 n−r명"]
        }
        let gap: CGFloat = symmetry ? 52 : 24
        let totalWidth = min(size.width - 64, 610)
        let width = (totalWidth - gap * CGFloat(labels.count - 1)) / CGFloat(labels.count)
        let start = (size.width - totalWidth) / 2
        for (index, label) in labels.enumerated() {
            let rect = CGRect(
                x: start + CGFloat(index) * (width + gap),
                y: size.height * 0.42,
                width: width,
                height: 108
            )
            let focused = index == labels.count - 1 || required && index == 0
            context.fill(
                Path(roundedRect: rect, cornerRadius: 16),
                with: .color(focused ? Color.yellow.opacity(0.56) : Tokens.paper2)
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 16),
                with: .color(focused ? Tokens.warningInk : Tokens.lineStrong),
                lineWidth: 3
            )
            context.draw(
                Text(label).font(.mBodyB).foregroundStyle(Tokens.ink),
                at: CGPoint(x: rect.midX, y: rect.midY)
            )
            if index < labels.count - 1 {
                context.draw(
                    Text(symmetry ? "↔" : index == 1 ? "=" : "+")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.progressBlue),
                    at: CGPoint(x: rect.maxX + gap / 2, y: rect.midY)
                )
            }
        }
        if beat.action == "group" || beat.action == "transform" || beat.action == "verify" {
            var fold = Path()
            fold.move(to: CGPoint(x: start + 12, y: size.height * 0.42 + 126))
            fold.addCurve(
                to: CGPoint(x: start + totalWidth - 12, y: size.height * 0.42 + 126),
                control1: CGPoint(x: start + totalWidth * 0.32, y: size.height * 0.42 + 168),
                control2: CGPoint(x: start + totalWidth * 0.68, y: size.height * 0.42 + 168)
            )
            context.stroke(
                fold,
                with: .color(Tokens.progressBlue),
                style: StrokeStyle(lineWidth: 3, dash: [8, 6])
            )
        }
    }
}
