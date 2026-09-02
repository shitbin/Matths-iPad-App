//
//  ArenaMatchIntroOverlay.swift
//  Matths
//
//  경기 시작과 문항 전환을 **몸으로 알리는** 오버레이.
//
//  WHY. 웹 경기 화면에는 두 개의 연출이 있다.
//   1) 시작 커튼   READY → FIGHT! → QUESTION 1  (goat-arena.css `.arena-fight-overlay`, 3.65s)
//   2) 라운드 인트로 QUESTION N                  (goat-arena.css `.arena-question-intro`, 1.7s)
//  앱에는 둘 다 없었다. 시작은 스피너 두 줄로 조용히 지나갔고, 다음 문항은
//  서버 응답이 도착하는 순간 questionPack 이 통째로 갈리며 0프레임에 바뀌었다.
//  "방금 내 답이 확정됐고 지금 몇 번으로 넘어왔는가" 를 알려 주는 순간이 없었다.
//
//  이 오버레이는 **상태를 말하는 연출**이다. 새 정보를 만들지 않는다 —
//  문항 번호는 서버가 준 currentQuestionNumber 그대로다.
//
//  접근성:
//   · 모션 끄기(store.motionOn) 또는 시스템 동작 줄이기에서는 안무를 재생하지 않고
//     같은 내용을 **정지 화면 한 컷**으로 보여 준다(요구: 강한 연출의 정적 대체).
//   · 화면 어디를 눌러도 즉시 건너뛴다. 제한 시간이 흐르는 화면이라 연출이
//     학생의 시간을 먹어서는 안 된다.
//   · VoiceOver 는 안무 대신 한 문장("경기 시작, 1번 문항")으로 읽는다.
//

import SwiftUI

struct ArenaMatchIntroOverlay: View {
    enum Kind: Equatable, Identifiable {
        /// 경기 시작 — READY → FIGHT! → QUESTION N
        case matchStart(questionNumber: Int)
        /// 문항 전환 — QUESTION N 한 컷
        case round(questionNumber: Int)

        var id: String {
            switch self {
            case .matchStart(let number): return "start-\(number)"
            case .round(let number): return "round-\(number)"
            }
        }

        var questionNumber: Int {
            switch self {
            case .matchStart(let number), .round(let number): return number
            }
        }

        var voiceOverLabel: String {
            switch self {
            case .matchStart(let number): return "경기 시작, \(number)번 문항"
            case .round(let number): return "\(number)번 문항"
            }
        }
    }

    let kind: Kind
    var onFinish: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 안무의 마디. 정지 대체에서는 `.still` 한 칸만 쓴다.
    private enum Beat {
        case ready
        case fight
        case question
        case still
        case gone
    }

    @State private var beat: Beat = .ready
    @State private var visible = false
    @State private var finished = false

    private var motionActive: Bool { store.motionOn && !reduceMotion }

    var body: some View {
        ZStack {
            curtain
            content
        }
        .opacity(visible ? 1 : 0)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.voiceOverLabel)
        .accessibilityAddTraits(.isStaticText)
        .task { await run() }
    }

    // MARK: 배경

    /// 웹의 `radial-gradient(...) , linear-gradient(135deg, …)` 커튼.
    /// 새 hex 를 만들지 않고 브랜드 토큰(네이비 · 시안 · 바이올렛)으로 같은 무게를 낸다.
    private var curtain: some View {
        ZStack {
            Tokens.brandNavy
            RadialGradient(
                colors: [Tokens.brandCyan.opacity(0.30), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 320)
            LinearGradient(
                colors: [.clear, Tokens.brandViolet.opacity(0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }

    // MARK: 글자

    @ViewBuilder
    private var content: some View {
        switch beat {
        case .ready:
            word("READY", size: 44, tint: Tokens.onNavy.opacity(0.86))
                .transition(enter(scale: 1.7))
        case .fight:
            fightWord
                .transition(enter(scale: 2.6))
        case .question:
            questionWord(kind.questionNumber)
                .transition(enter(scale: 0.82))
        case .still:
            stillFrame
                .transition(.opacity)
        case .gone:
            EmptyView()
        }
    }

    /// 모션이 살아 있을 때만 확대/축소가 붙는다. 꺼져 있으면 교차 페이드만 남는다.
    private func enter(scale: CGFloat) -> AnyTransition {
        motionActive
            ? .scale(scale: scale).combined(with: .opacity)
            : .opacity
    }

    private var fightWord: some View {
        word("FIGHT!", size: 78, tint: Tokens.onNavy)
            .shadow(color: Tokens.brandCyan.opacity(0.65), radius: 18)
            .shadow(color: Tokens.brandViolet.opacity(0.55), radius: 34)
    }

    private func questionWord(_ number: Int) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            Text("NEXT ROUND")
                .font(.mMicro)
                .tracking(6)
                .foregroundStyle(Tokens.brandCyan)
            word("QUESTION \(number)", size: 46, tint: Tokens.onNavy)
            Capsule()
                .fill(Tokens.brandCyan)
                .frame(width: 132, height: 3)
        }
    }

    /// 모션을 끈 사용자에게 보여 주는 한 컷. 안무 없이 같은 사실만 남긴다.
    private var stillFrame: some View {
        VStack(spacing: Tokens.Space.s3) {
            Text(kind.isMatchStart ? "경기 시작" : "다음 문항")
                .font(.mMicro)
                .tracking(4)
                .foregroundStyle(Tokens.brandCyan)
            Text("\(kind.questionNumber)번 문항")
                .font(.mTitle)
                .foregroundStyle(Tokens.onNavy)
        }
        .padding(.horizontal, Tokens.Space.s6)
    }

    /// 웹의 Impact / Arial Black + letter-spacing .12em + uppercase 대응.
    /// 시스템 rounded heavy 로 같은 밀도를 내고, 폭이 좁으면 한 줄 안에서 줄인다.
    private func word(
        _ text: String,
        size: CGFloat,
        tint: Color
    ) -> some View {
        Text(text)
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(size * 0.06)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(.horizontal, Tokens.Space.s6)
    }

    // MARK: 진행

    @MainActor
    private func run() async {
        if motionActive {
            withAnimation(ArenaIntroMotion.curtain) { visible = true }
        } else {
            visible = true
        }

        guard motionActive else {
            beat = .still
            await hold(kind.isMatchStart
                       ? ArenaIntroMotion.staticHold
                       : ArenaIntroMotion.roundHold)
            finish()
            return
        }

        if kind.isMatchStart {
            withAnimation(ArenaIntroMotion.wordIn) { beat = .ready }
            await hold(ArenaIntroMotion.readyHold)
            guard !finished else { return }
            withAnimation(ArenaIntroMotion.wordIn) { beat = .fight }
            await hold(ArenaIntroMotion.fightHold)
            guard !finished else { return }
        }

        withAnimation(ArenaIntroMotion.wordIn) { beat = .question }
        await hold(kind.isMatchStart
                   ? ArenaIntroMotion.questionHold
                   : ArenaIntroMotion.roundHold)
        guard !finished else { return }
        finish()
    }

    private func hold(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    @MainActor
    private func finish() {
        guard !finished else { return }
        finished = true
        if motionActive {
            withAnimation(ArenaIntroMotion.wordOut) {
                beat = .gone
                visible = false
            }
        } else {
            visible = false
        }
        // 커튼이 걷힌 뒤에 호출부의 상태를 지운다 — 즉시 지우면 페이드가 잘린다.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            onFinish()
        }
    }
}

private extension ArenaMatchIntroOverlay.Kind {
    var isMatchStart: Bool {
        if case .matchStart = self { return true }
        return false
    }
}
