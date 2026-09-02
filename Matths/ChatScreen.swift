//  ChatScreen.swift
//  Matths
//
//  AI 튜터 채팅 — 온디바이스 역할 분리형 로컬 AI (AITutor.swift).
//  브라우즈 셸의 바깥 ScrollView 에 넣지 않는 유일한 브라우즈 화면이다
//  (자체 스크롤 + 하단 입력바, RootView.browseContent 참조).

import SwiftUI
import PhotosUI

struct ChatScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ObservedObject private var tutor = AITutor.shared
    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    // 사진 질문 (mmproj 비전) — 선택 → 축소 저장 → 전송 시 경로 전달
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var pickBusy = false
    @State private var photoError: String?
    /// 생각 과정 펼침 상태 (기본은 생성 중 펼침 · 끝나면 접힘, 사용자가 바꾸면 그 값 유지)
    @State private var thinkingOpen: [UUID: Bool] = [:]
    @State private var pendingImagePath: String?
    @State private var pendingThumb: UIImage?
    /// 여는 중 표시가 시작된 시각 — 지연 판정(다시 시도 노출)용 화면 상태
    @State private var loadingSince: Date?
    /// 준비 전 전송 — draft 를 그대로 쥐고 있다가 준비되는 즉시 보낸다
    @State private var sendQueued = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Tokens.line)
            messagesList
            if showsSetupActionBar {
                setupActionBar
            } else {
                inputBar
            }
        }
        .readableWidth()
        .adaptiveHPadding()
        .onAppear {
            // 지난 실행이 9B 로드 중 죽었으면 안정적인 기본 모델로 되돌린 뒤 연다.
            if ModelDownloader.recoverFromLoadCrashIfNeeded() { tutor.revertedAfterCrash = true }
            tutor.discoverAndLoad()
            // discoverAndLoad 가 이 자리에서 .loading 으로 바꾸면 onChange 보다 먼저다
            if case .loading = tutor.modelState, loadingSince == nil { loadingSince = Date() }
        }
        .onChange(of: tutor.modelState) { _, state in
            switch state {
            case .loading:
                if loadingSince == nil { loadingSince = Date() }
            case .ready:
                loadingSince = nil
                // 준비 전에 받아 둔 질문은 준비되는 즉시 그대로 보낸다
                if sendQueued { sendQueued = false; send(draft) }
            case .missing, .failed:
                loadingSince = nil
                sendQueued = false
            }
        }
        .onDisappear {
            // 아직 전송하지 않은 사진은 대화 기록에도 필요 없으므로 즉시 지운다.
            discardPendingPhoto()
        }
    }

    // MARK: 헤더 — 제목 + 모델 상태 알약

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline) {
                tutorTitle
                statusPill
                Spacer(minLength: Tokens.Space.s4)
                clearConversationButton
            }
            .frame(minWidth: 420)

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack(alignment: .lastTextBaseline) {
                    tutorTitle
                    Spacer(minLength: Tokens.Space.s3)
                    clearConversationButton
                }
                statusPill
            }
        }
        .padding(.vertical, Tokens.Space.s4)
    }

    private var tutorTitle: some View {
        Text("AI 튜터").font(.mTitle).foregroundStyle(Tokens.ink)
    }

    @ViewBuilder private var clearConversationButton: some View {
        if !tutor.messages.isEmpty {
            Button("대화 지우기") { tutor.clear() }
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .disabled(tutor.isGenerating)
        }
    }

    /// 파일명에서 사람이 읽을 티어 라벨을 만든다 — "지금 뭐가 도는지" 가 한눈에.
    private func tierLabel(_ file: String) -> String {
        if file.contains("DeepSeek-R1") { return "DeepSeek-R1 7B" }
        if file.contains("Qwen2.5-VL-3B") { return "Qwen2.5-VL 3B" }
        if file.contains("9B") { return file.contains("IQ2") || file.contains("IQ3") ? "9B 경량" : "9B" }
        if file.contains("4B") { return "4B" }
        return "로컬 모델"
    }

    @ViewBuilder private var statusPill: some View {
        switch tutor.modelState {
        case .ready(let file):
            pill("온디바이스 \(tierLabel(file))", color: Tokens.success)
        case .loading:
            // 정상 로딩은 중립 톤 — 주황은 지연·주의에만 쓴다(지연 안내는 loadingCard 몫)
            pill("준비하는 중…", color: Tokens.text3)
        case .missing:
            pill("모델 없음", color: Tokens.text3)
        case .failed:
            pill("엔진 오류", color: Tokens.danger)
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text).font(.mMicro).foregroundStyle(color)
            .padding(.horizontal, Tokens.Space.s2).padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
    }

    // MARK: 본문

    @ViewBuilder private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    if tutor.revertedAfterCrash {
                        Label("메모리가 부족해 9B 로드 중 앱이 종료됐어요. 기본 DeepSeek 7B로 되돌렸습니다. 프로필에서 다시 켤 수 있어요.",
                              systemImage: "exclamationmark.triangle")
                            .font(.mCaption).foregroundStyle(Tokens.warningInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(Tokens.Space.s3)
                            .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    }
                    if case .loading = tutor.modelState, tutor.messages.isEmpty { loadingCard }
                    if case .missing = tutor.modelState { missingCard }
                    if case .failed(let why) = tutor.modelState { failedCard(why) }
                    if tutor.messages.isEmpty, tutorUsable { emptyHints }
                    if let ctx = store.chatSeedContext { contextCard(ctx) }

                    ForEach(tutor.messages) { m in
                        bubble(m).id(m.id)
                    }
                    Color.clear.frame(height: 8).id("tail")
                }
                .padding(.vertical, Tokens.Space.s5)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: tutor.messages.last?.text) {
                proxy.scrollTo("tail", anchor: .bottom)
            }
        }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == .user {
                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 20 : 60)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                // 첨부 사진 썸네일
                if let ip = m.imagePath, let ui = UIImage(contentsOfFile: ip) {
                    Image(uiImage: ui)
                        .resizable().scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                        .accessibilityLabel("첨부한 풀이 사진")
                }
                #if DEBUG
                // 원시 추론 토큰은 모델 품질 진단 자료다. 학생에게 제공할 검증된
                // 풀이 설명이 아니므로 디버그 빌드에서만 펼쳐 본다.
                if !m.thinking.isEmpty {
                    // 생성 중에는 **펼쳐 둔다.** 접혀 있으면 몇 분간 도는 동안
                    // 모델이 무슨 생각을 하는지 볼 방법이 없다(2026-07-29 요구).
                    DisclosureGroup(isExpanded: Binding(
                        get: { thinkingOpen[m.id] ?? !m.done },
                        set: { thinkingOpen[m.id] = $0 })) {
                        Text(MathText.plain(m.thinking))
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Label(m.done ? "생각 과정" : "생각하는 중…", systemImage: "brain")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    .tint(Tokens.text3)
                }
                #endif
                if m.text.isEmpty && !m.done {
                    // **점 하나만 두지 않는다.** 사진이 붙으면 첫 글자까지 몇 분이
                    // 걸리는데(ViT 인코딩), 그동안 화면이 비어 있으면 사용자는
                    // 앱이 죽은 줄 안다. 진행률을 지어내지 않고 **무슨 단계인지와
                    // 얼마나 지났는지**만 정직하게 적는다.
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        HStack(spacing: Tokens.Space.s2) {
                            ProgressView().controlSize(.small)
                            if !tutor.runStage.isEmpty {
                                Text(tutor.runStage).font(.mCaption).foregroundStyle(Tokens.text3)
                            }
                            if let t0 = tutor.runStartedAt {
                                Text("\(Int(ctx.date.timeIntervalSince(t0)))초")
                                    .font(.mCaption).foregroundStyle(Tokens.text4)
                                    .monospacedDigit()
                            }
                        }
                    }
                } else if !m.text.isEmpty {
                    // 모델의 마크다운 볼드(**)는 뷰에서 지운다
                    let body = m.text.replacingOccurrences(of: "**", with: "")
                    // 답변이 **끝난 뒤에만** KaTeX 로 조판한다.
                    //
                    // 토큰이 흐르는 중에는 수식이 반만 와 있어서(`$3^{\frac{1` …)
                    // 매 토큰마다 웹뷰를 다시 그리게 되고, 조판도 계속 깨진다.
                    // 흐르는 동안은 평문 근사로 보여 주고, done 이 되면 갈아 끼운다.
                    if m.done, m.role == .assistant, MathText.containsMath(body) {
                        MathInline(text: body, font: .mBody, color: Tokens.ink, pixelSize: 17)
                    } else {
                        Text(MathText.plain(body))
                            .font(.mBody)
                            .foregroundStyle(m.role == .user ? Tokens.primary : Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(Tokens.Space.s4)
            .background(
                m.role == .user ? Tokens.primarySoft : Tokens.surface,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(m.role == .user ? .clear : Tokens.line, lineWidth: 1))
            if m.role == .assistant {
                Spacer(minLength: dynamicTypeSize.isAccessibilitySize ? 20 : 60)
            }
        }
    }

    // MARK: 상태 카드들

    /// 여는 중 안내 — 헤더 알약만으로는 첫 방문자가 "왜 아직인지" 를 모른다.
    /// 진행률을 지어내지 않고 무엇을 하는 중인지만 적고, 오래 걸리면
    /// 기다리게만 두지 않고 다시 시도 길을 연다.
    private var loadingCard: some View {
        TimelineView(.periodic(from: .now, by: 5)) { ctx in
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                HStack(spacing: Tokens.Space.s3) {
                    ProgressView().controlSize(.small)
                    Text("AI 튜터를 준비하고 있어요").font(.mBodyB).foregroundStyle(Tokens.ink)
                }
                Text("수학 모델을 불러오는 중이에요. 보통 몇 초 걸려요")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                if let t0 = loadingSince, ctx.date.timeIntervalSince(t0) > 60 {
                    Text("평소보다 오래 걸리고 있어요. 계속 안 열리면 다시 시도해 주세요.")
                        .font(.mCaption).foregroundStyle(Tokens.warningInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("다시 시도") { tutor.reloadModel() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    @ViewBuilder private var missingCard: some View {
        if ModelDownloader.deviceSupported {
            if verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: Tokens.Space.s5) {
                    compactTutorSetupIllustration
                    compactTutorSetupCopy
                }
                .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
                .padding(Tokens.Space.s4)
                .background(Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.line, lineWidth: 1))
            } else {
                ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Tokens.Space.s6) {
                    tutorSetupIllustration
                    tutorSetupCopy
                        .frame(maxWidth: 620, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 320, alignment: .leading)
                .padding(Tokens.Space.s6)
                .background(Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.xl))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                    .strokeBorder(Tokens.line, lineWidth: 1))

                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    tutorSetupIllustration
                    tutorSetupCopy
                }
                .padding(Tokens.Space.s5)
                .background(Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                    .strokeBorder(Tokens.line, lineWidth: 1))
                }
            }
        } else {
            // 로컬 모델 하한 미만 — 강등할 곳이 더 없으니 정직하게 미지원 고지
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Label("이 기기에서는 AI 튜터를 쓸 수 없어요", systemImage: "cpu")
                    .font(.mBodyB).foregroundStyle(Tokens.ink)
                Text("온디바이스 AI는 메모리 6GB 이상 기기가 필요합니다. 12GB 이상이면 더 똑똑한 9B 모델이 자동으로 선택돼요.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
            }
            .card()
        }
    }

    private var tutorSetupIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl)
                .fill(Tokens.primarySoft)
            Circle()
                .fill(Tokens.surface)
                .frame(width: 104, height: 104)
            Image(systemName: "function")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(Tokens.actionPrimary)
            Image(systemName: "sparkle")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Tokens.progressBlue)
                .offset(x: 58, y: -54)
        }
        .frame(width: 200, height: 200)
        .accessibilityHidden(true)
    }

    private var compactTutorSetupIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .fill(Tokens.primarySoft)
            Circle()
                .fill(Tokens.surface)
                .frame(width: 76, height: 76)
            Image(systemName: "function")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Tokens.actionPrimary)
            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.progressBlue)
                .offset(x: 40, y: -38)
        }
        .frame(width: 140, height: 140)
        .accessibilityHidden(true)
    }

    private var compactTutorSetupCopy: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("이 기기에 수학 튜터 설치")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            Text("질문과 풀이 사진을 서버로 보내지 않고 기기 안에서 분석합니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text("\(ModelDownloader.recommended.shortName) · \(ModelDownloader.recommended.sizeLabel) · Wi-Fi 권장 · 중단해도 이어받기")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tutorSetupCopy: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("이 기기에 수학 튜터 설치")
                    .font(.mHeading).foregroundStyle(Tokens.ink)
                Text("한 번 내려받으면 질문과 풀이 사진을 서버에 보내지 않고 이 기기 안에서 분석합니다.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Tokens.Space.s2) {
                setupFact("모델", ModelDownloader.recommended.shortName, "cpu")
                setupFact("다운로드", ModelDownloader.recommended.sizeLabel, "internaldrive")
                setupFact("권장", "Wi-Fi", "wifi")
            }

            Button {
                ModelDownloader.shared.start()
            } label: {
                DownloadButtonLabel()
            }
            .buttonStyle(.plain)
            .accessibilityHint("다운로드가 끝나면 AI 튜터가 자동으로 열립니다")

            Label("다운로드를 멈춰도 다음에 이어받을 수 있어요.", systemImage: "arrow.clockwise")
                .font(.mCaption).foregroundStyle(Tokens.text3)
        }
    }

    private func setupFact(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.mMicro).foregroundStyle(Tokens.text3)
            Text(value)
                .font(.mCaption.weight(.semibold)).foregroundStyle(Tokens.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(.horizontal, Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }

    private func failedCard(_ why: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label("엔진을 열지 못했어요", systemImage: "exclamationmark.triangle")
                .font(.mBodyB).foregroundStyle(Tokens.dangerInk)
            Text(modelFailureCopy(why)).font(.mCaption).foregroundStyle(Tokens.text3)
            // 실패를 읽는 것으로 끝내지 않는다 — 여기서 바로 다시 열 수 있다
            Button("다시 시도") { tutor.reloadModel() }
                .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private func modelFailureCopy(_ debugReason: String) -> String {
        #if DEBUG
        return debugReason
        #else
        return "AI 모델을 열지 못했습니다. 앱을 다시 시작하거나 모델을 다시 받아 주세요."
        #endif
    }

    /// 모델이 준비됐거나 여는 중이면 빈 화면 대신 시작 안내를 그린다.
    /// 여는 데 몇 분이 걸리는 동안 헤더와 입력바만 있으면 첫 화면이 텅 빈다.
    /// missing·failed 는 각자의 상태 카드가 화면을 채우므로 겹치지 않는다.
    private var tutorUsable: Bool {
        switch tutor.modelState {
        case .ready, .loading: return true
        case .missing, .failed: return false
        }
    }

    private var emptyHints: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("물어보면 답한다. 단, 정답은 안 준다. 길만 알려준다.")
                .font(.mCallout).foregroundStyle(Tokens.text2)
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                ForEach(["극한의 뜻을 그래프로 설명해줘",
                         "미분계수와 순간변화율의 차이를 알려줘",
                         "이 풀이에서 처음 틀린 단계를 찾아줘",
                         "확률 문제에서 자꾸 틀리는 이유를 짚어줘"], id: \.self) { s in
                    Button {
                        // 여는 중이면 send 가 draft 큐로 받아 둔다 — 준비되는 즉시 자동 전송
                        send(s)
                    } label: {
                        Text(s).font(.mCallout).foregroundStyle(Tokens.primary)
                            .padding(.horizontal, Tokens.Space.s4)
                            .frame(minHeight: 44)
                            .overlay(Capsule().strokeBorder(Tokens.primarySoft, lineWidth: 1.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, Tokens.Space.s3)
    }

    private func contextCard(_ ctx: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Label("보고 있는 문제", systemImage: "doc.text")
                    .font(.mCaption).foregroundStyle(Tokens.primary)
                Spacer()
                Button { store.chatSeedContext = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.text4)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("보고 있는 문제 연결 해제")
            }
            Text(MathText.plain(ctx)).font(.mCaption).foregroundStyle(Tokens.text2)
                .lineLimit(4)
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.primarySoft.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    // MARK: 입력바

    private var showsSetupActionBar: Bool {
        guard ModelDownloader.deviceSupported else { return false }
        if case .missing = tutor.modelState { return true }
        return false
    }

    /// 모델이 없을 때 잠긴 입력창은 행동이 아니라 장벽이다. iPhone 가로에서는 설치
    /// 버튼이 큰 카드 아래로 밀렸으므로, 입력창 자리에 항상 보이는 설치 행동을 둔다.
    private var setupActionBar: some View {
        HStack(spacing: Tokens.Space.s4) {
            VStack(alignment: .leading, spacing: 2) {
                Text("온디바이스 AI 준비")
                    .font(.mCaption.weight(.semibold))
                    .foregroundStyle(Tokens.ink)
                Text("다운로드 후 질문과 사진 분석을 시작할 수 있어요")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: Tokens.Space.s3)
            Button { ModelDownloader.shared.start() } label: {
                DownloadButtonLabel()
            }
            .buttonStyle(.plain)
            .accessibilityHint("다운로드가 끝나면 AI 튜터가 자동으로 열립니다")
        }
        .padding(.vertical, Tokens.Space.s3)
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            // 사진을 못 읽었으면 **그 사실과 이유를 말한다.**
            // 예전엔 loadTransferable 이 실패해도 아무 일도 안 일어나서,
            // 학생은 첨부가 됐는지 안 됐는지조차 알 수 없었다.
            if pickBusy {
                HStack(spacing: Tokens.Space.s2) {
                    ProgressView().controlSize(.small)
                    Text("사진 읽는 중…").font(.mCaption).foregroundStyle(Tokens.text3)
                }
            }
            if let e = photoError {
                Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // 첨부 대기 중인 사진 미리보기
            if let thumb = pendingThumb {
                HStack(spacing: Tokens.Space.s2) {
                    Image(uiImage: thumb)
                        .resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    Text("사진 첨부됨. 질문과 함께 보내집니다")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                    Button {
                        discardPendingPhoto()
                        photoItem = nil; photoError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Tokens.text4)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("첨부한 풀이 사진 삭제")
                }
            }
            // 준비 전에도 입력은 받는다 — 대신 그 사실을 미리 말한다
            if case .loading = tutor.modelState {
                Text(sendQueued ? "받아 뒀어요. 준비되는 즉시 답할게요"
                                : "지금 입력해도 돼요. 전송하면 준비되는 즉시 답할게요")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            inputRow
        }
        .padding(.vertical, Tokens.Space.s3)
        .compactHeightSheet(isPresented: $showPhotoPicker) {
            SystemPhotoPicker { provider, assetID in
                showPhotoPicker = false
                guard let provider else { return }      // 취소
                loadPicked(provider: provider, assetID: assetID)
            }
        }
    }

    /// 고른 사진을 파일로 떨군다 — 채점 Pro 와 **같은 경로**(PhotoIntake 5단계).
    /// 실패해도 조용히 사라지지 않는다. 무반응이 제일 나쁜 실패다.
    private func loadPicked(provider: NSItemProvider, assetID: String?) {
        pickBusy = true
        photoError = nil
        Task {
            let result = await PhotoIntake.load(provider: provider, assetID: assetID)
            await MainActor.run {
                pickBusy = false
                switch result {
                case .success(let img):
                    // 비전 인코더 부담을 줄이도록 긴 변 1280 으로 축소
                    let scaled = img.scaledToFit(maxSide: 1280)
                    guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else {
                        photoError = "사진을 저장하지 못했습니다"; return
                    }
                    discardPendingPhoto()
                    let url = FileManager.default.temporaryDirectory
                        .appendingPathComponent("matths-chat-\(UUID().uuidString).jpg")
                    do {
                        try jpeg.write(
                            to: url,
                            options: [.atomic, .completeFileProtection])
                    }
                    catch { photoError = "사진을 저장하지 못했습니다"; return }
                    pendingImagePath = url.path
                    pendingThumb = scaled
                case .failure(let e):
                    photoError = e.message
                }
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: Tokens.Space.s3) {
            // 버튼은 **항상 그린다.** 조건부로 숨기면 사용자는 기능이 없는 건지,
            // 고장난 건지, 아직 안 켜진 건지 알 수 없다 — 실제로 그렇게 사라져서
            // "사진 첨부 기능을 넣어라" 는 말을 반복해서 들었다. 못 쓰는 상태면
            // 눌렀을 때 **이유를 말한다.**
            do {
                // SwiftUI PhotosPicker 가 아니라 **PHPicker** 를 쓴다.
                // 전자의 loadTransferable 은 항목 타입에
                // com.apple.private.photos.thumbnail.* 이 섞여 있으면
                // `CoreTransferable.TransferableSupportError 오류 0` 으로 실패한다 —
                // 채점 Pro 에서 실기기로 확인하고 갈아탄 경로인데
                // 여기만 옛 API 로 남아 있었다(2026-07-29 사용자 지적).
                Button {
                    if ModelDownloader.deviceSupported { showPhotoPicker = true }
                    else { photoError = "이 기기에서는 로컬 사진 판독을 지원하지 않습니다." }
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 24))
                        .foregroundStyle(ModelDownloader.deviceSupported ? Tokens.text3 : Tokens.text4)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("풀이 사진 첨부")
                .accessibilityHint("사진 보관함에서 수학 문제 또는 풀이 사진을 고릅니다")
                .disabled(tutor.isGenerating || pickBusy)
            }
            TextField(inputPlaceholder, text: $draft, axis: .vertical)
                .font(.mBody)
                .lineLimit(1...4)
                .focused($inputFocused)
                .disabled(inputLocked)
                .padding(.horizontal, Tokens.Space.s4)
                .padding(.vertical, Tokens.Space.s3)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1))
                .onSubmit { send(draft) }

            if tutor.isGenerating {
                Button { tutor.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 30)).foregroundStyle(Tokens.dangerInk)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("답변 생성 중지")
            } else {
                Button { send(draft) } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? Tokens.primary : Tokens.text4)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("질문 보내기")
                .disabled(!canSend)
            }
        }
        .padding(.vertical, Tokens.Space.s3)
    }

    /// 입력을 잠글 때는 그 사유를 입력창 안(placeholder)에서 말한다 —
    /// 회색 입력창만 있으면 고장인지 정책인지 구분이 안 된다.
    private var inputLocked: Bool {
        switch tutor.modelState {
        case .missing, .failed: return true
        case .ready, .loading:  return false
        }
    }

    private var inputPlaceholder: String {
        switch tutor.modelState {
        case .ready, .loading:
            return "수학 질문을 입력하세요"
        case .missing:
            return ModelDownloader.deviceSupported
                ? "위 안내로 AI 튜터를 내려받으면 질문할 수 있어요"
                : "이 기기에서는 AI 튜터를 쓸 수 없어요"
        case .failed:
            return "여는 데 실패했어요. 위에서 다시 시도해 주세요"
        }
    }

    private var canSend: Bool {
        let hasContent = !draft.trimmingCharacters(in: .whitespaces).isEmpty
            || pendingImagePath != nil
        switch tutor.modelState {
        case .ready:   return hasContent && !tutor.isGenerating
        case .loading: return hasContent && !sendQueued   // 준비 전에도 받아 둔다
        case .missing, .failed: return false
        }
    }

    private func send(_ text: String) {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 사진만 첨부하고 질문을 안 쓰면 기본 요청으로
        if t.isEmpty, pendingImagePath != nil { t = "이 문제 푸는 법을 알려줘" }
        guard !t.isEmpty, !tutor.isGenerating else { return }
        // 여는 중 전송 — 입력창의 글을 그대로 쥐고 있다가(draft 큐) 준비되는 즉시 보낸다
        if case .loading = tutor.modelState {
            draft = t
            sendQueued = true
            return
        }
        // 모델 상태를 직접 본다. canSend 는 draft 가 비면 false 라 제안 칩(문자열
        // 직접 전달)을 막아 버리므로 여기서 쓰면 안 된다.
        guard case .ready = tutor.modelState else { return }
        draft = ""
        tutor.send(t, seedContext: store.chatSeedContext, imagePath: pendingImagePath,
                   coachLevel: store.coach.level)
        store.chatSeedContext = nil   // 맥락은 첫 질문에만 싣는다
        pendingImagePath = nil; pendingThumb = nil; photoItem = nil
    }

    /// 전송된 사진은 AITutor의 현재 대화가 소유하고 clear()에서 지운다.
    /// 여기서는 아직 전송되지 않은 임시 사진만 정리한다.
    private func discardPendingPhoto() {
        if let path = pendingImagePath {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
        pendingImagePath = nil
        pendingThumb = nil
    }
}

// 사진 축소 헬퍼 — 비전 인코더 입력 부담을 줄인다
private extension UIImage {
    func scaledToFit(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

/// 다운로드 버튼 라벨 — ModelDownloader 진행률 구독
private struct DownloadButtonLabel: View {
    @ObservedObject private var dl = ModelDownloader.shared

    var body: some View {
        Group {
            switch dl.state {
            case .idle:
                Label("모델 내려받기 (\(ModelDownloader.recommended.sizeLabel))", systemImage: "arrow.down.to.line")
            case .downloading(let pct):
                Label(String(format: "받는 중… %.0f%%", pct * 100), systemImage: "arrow.down.to.line")
            case .failed(let why):
                Label("실패, 다시 시도 (\(why))", systemImage: "arrow.clockwise")
            case .done:
                Label("완료, 여는 중", systemImage: "checkmark")
            }
        }
        .font(.mBodyB).foregroundStyle(Tokens.primary)
        .padding(.horizontal, Tokens.Space.s4).padding(.vertical, Tokens.Space.s2)
        .overlay(Capsule().strokeBorder(Tokens.primary, lineWidth: 1.3))
    }
}
