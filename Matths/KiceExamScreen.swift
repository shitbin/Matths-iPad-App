//  KiceExamScreen.swift
//  Matths
//
//  기출 응시 — 실제 수능 문제지(PDF)를 왼쪽에, OMR 답안지를 오른쪽에 둔다.
//  세로·큰 글자에서는 문제지/답안지 세그먼트 전환으로 내려간다.
//  iPhone 가로에서는 900pt보다 좁아도 두 면을 동시에 보여준다.
//
//  채점 규약:
//   · 공통 1~15 선다 + 16~22 단답, 선택과목 23~28 선다 + 29~30 단답
//   · 무응답은 오답. 채점 후에도 정답은 보여주지 않는다 —
//     동적 문항과 같은 계약("정답은 알려드리지 않습니다")을 기출에도 지킨다.
//   · 틀린 문항은 오답노트에 "기출" 태그로 적재되어 SRS 복습 루프를 탄다.
//  입력한 답·선택과목·경과 시간·채점 결과는 계정별 보호 파일에 저장한다.
//
//  문제지-답안지 동기화:
//   · 페이지→문항 매핑 데이터가 없다. 전체 문항을 PDF 페이지 수로 등분한
//     근사로 "지금 보는 페이지의 문항 묶음"을 잡는다 — 표지·과목 분기 페이지가
//     끼면 한두 문항 어긋날 수 있지만, 길을 잃지 않게 하는 것이 목적이다.

import SwiftUI
import PDFKit

struct KiceExamScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // 기기 이름이 아니라 크기 클래스로 분기한다 — Split View·Stage Manager 의
    // iPad 도 compact 로 들어오고, 그때 필요한 상단바는 iPhone 과 같다.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var timer = ExamTimer()
    @State private var timerLifecycle = KiceTimerLifecycle()
    @State private var pane: Pane = .paper       // 좁은 폭에서의 현재 면
    private var result: KiceStudyResult? { store.kiceCurrentReceipt?.result }
    @State private var restoredAttemptID: String?
    @State private var sessionOwner: AppStore.AccountSessionBoundary?
    @State private var confirmsRecovery = false
    @State private var confirmsNewAttempt = false
    @State private var recoveryOwner: AppStore.AccountSessionBoundary?
    @State private var newAttemptOwner: AppStore.AccountSessionBoundary?
    @State private var newAttemptReceiptID: String?
    private var loadIdentity: String { store.kiceLoadIdentity }

    // 문제지 페이지는 응시 기록으로 복원하고, 스크롤/이동 포커스는 화면 안에서만 유지한다.
    @State private var pdfPageIndex = 0
    @State private var pdfPageCount = 1
    @State private var omrScrollTarget: String?  // "공통-14" 꼴의 행 id
    @State private var lastJumpKey: String?      // 미응답 순환 이동의 기준점

    /// 100분 시험 — 남은 시간 경고 단계의 기준
    private static let examLengthMs = 100 * 60_000

    private enum Pane: String, CaseIterable {
        case paper = "문제지", omr = "답안지"
    }

    // MARK: 폭·높이 적응
    //
    // 폭 compact = iPhone 세로 / iPad Split View. 상단바에 들어갈 자리가 없다.
    // 높이 compact = iPhone 가로(가용 약 390pt). 크롬 1pt 가 문제지 1pt 다.

    private var isNarrow: Bool { horizontalSizeClass == .compact }
    private var isShort: Bool { verticalSizeClass == .compact }

    /// iPhone 가로에서는 문제를 보며 바로 마킹할 수 있어야 한다. 폭 900pt만 기준으로
    /// 삼으면 852pt Pro Max에서도 세그먼트 전환이 생겨, 매 문항마다 문제지와 답안지를
    /// 왕복해야 한다. 다만 접근성 큰 글자는 352pt 답안지 안에서 텍스트가 잘릴 수 있어
    /// 기존의 한 면 전환형을 유지한다.
    private var usesLandscapeSplitWorkspace: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    /// 부제("100분, 30문항…")는 시험 중 다시 볼 일이 없다. 높이가 없거나
    /// 글자가 커진 상황에서 제일 먼저 접는다 — 제목과 타이머는 접지 않는다.
    private var showsExamSubtitle: Bool {
        !isShort && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        let displayedOwner = sessionOwner
        return VStack(spacing: 0) {
            header(store.kiceExam)
            storageStatus

            if let exam = store.kiceExam {
                GeometryReader { geo in
                    // 넓은 화면과 iPhone 가로에서는 문제지·답안지를 나란히 둔다.
                    // OMR 352pt는 compact 행 292 + 카드 좌우 24 + 스크롤 좌우 32 +
                    // Divider 여유 4를 모두 포함한 최소값이다. 선택지마다 44pt 히트 영역을
                    // 유지하면서도 852pt 화면에서 문제지에 약 499pt를 남긴다.
                    if UniversalLayoutPolicy.usesProblemSplit(width: geo.size.width, height: geo.size.height,
                        accessibilityText: dynamicTypeSize.isAccessibilitySize) {
                        let omrWidth = min(max(geo.size.width * 0.36, 300), min(420, geo.size.width * 0.52))
                        ResponsiveProblemWorkspace(spacing: 1, trailingWidth: omrWidth) {
                            pdfPane(exam)
                            omrPane(exam).frame(width: omrWidth)
                        }
                    } else {
                        VStack(spacing: 0) {
                            Picker("면", selection: $pane) {
                                ForEach(Pane.allCases, id: \.self) { Text($0.rawValue) }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, Tokens.Space.s4)
                            // 가로모드는 세로 여백부터 줄인다 — 세그먼트는 그대로 44pt대
                            .padding(.vertical, isShort ? Tokens.Space.s1 : Tokens.Space.s2)

                            switch pane {
                            case .paper: pdfPane(exam)
                            case .omr:   omrPane(exam)
                            }
                        }
                    }
                }
            } else {
                // 딥링크 직후 동기화·다른 기기 삭제로 데이터가 사라질 수 있다.
                // 오류 문장만 남기지 말고 평가센터로 복귀하는 행동을 같은 화면에 둔다.
                missingExamView
            }
        }
        .background(Tokens.paper)
        .onAppear {
            timerLifecycle.appeared(sceneIsActive: scenePhase == .active)
            syncTimerAvailability()
        }
        .task(id: loadIdentity) {
            guard !Task.isCancelled else { return }
            timer.pause()
            let owner = store.captureAccountSessionBoundary()
            sessionOwner = owner
            guard let exam = store.kiceExam, await store.prepareKiceStudy(exam),
                  !Task.isCancelled, timerLifecycle.isVisible,
                  store.ownsCurrentAccountSession(owner), store.kiceExamID == exam.id else { return }
            sessionOwner = owner
            pdfPageIndex = store.kiceCurrentAttempt?.pdfPageIndex ?? 0
            syncTimerAvailability(restore: true)
        }
        .onChange(of: store.canEditKice) { _, canEdit in
            if canEdit { sessionOwner = store.captureAccountSessionBoundary() }
            syncTimerAvailability()
        }
        .onChange(of: store.kiceCurrentAttempt?.id) { _, id in
            if id != nil && store.kiceStudyReady { sessionOwner = store.captureAccountSessionBoundary() }
            pdfPageIndex = store.kiceCurrentAttempt?.pdfPageIndex ?? 0
            lastJumpKey = nil
            omrScrollTarget = nil
            syncTimerAvailability(restore: true)
        }
        .onChange(of: result?.id) { _, _ in syncTimerAvailability(restore: true) }
        .onReceive(timer.$elapsedSeconds) { _ in
            guard let sessionOwner, store.ownsCurrentAccountSession(sessionOwner) else { return }
            store.checkpointKice(elapsedMs: timer.exactElapsedMs(), page: pdfPageIndex)
        }
        .onReceive(NotificationCenter.default.publisher(for: KiceStudyRepository.failedNotification)) { notification in
            if let handle = notification.object as? KiceStudyRepository.Handle { store.kicePersistenceFailed(handle) }
        }
        .onChange(of: scenePhase) { _, phase in
            timerLifecycle.sceneChanged(isActive: phase == .active)
            if phase == .active { syncTimerAvailability() } else { pauseAndSave(expectedOwner: displayedOwner) }
        }
        .onDisappear {
            timerLifecycle.disappeared()
            pauseAndSave(expectedOwner: displayedOwner)
        }
        .confirmationDialog("기출 기록을 원본 보관 후 초기화할까요?", isPresented: $confirmsRecovery, titleVisibility: .visible) {
            Button("원본 보관 후 초기화", role: .destructive) {
                if let owner = recoveryOwner { Task { await store.resetKicePreservingOriginal(expectedOwner: owner) } }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 계정의 기출 기록 원본을 별도 보관한 뒤 기출 답안·결과를 초기화합니다. 다른 학습 기록과 오답노트는 삭제하지 않습니다.")
        }
        .confirmationDialog("같은 기출을 새로 풀까요?", isPresented: $confirmsNewAttempt, titleVisibility: .visible) {
            Button("새 응시 시작") {
                if let exam = store.kiceExam, let owner = newAttemptOwner, let receiptID = newAttemptReceiptID {
                    Task { await store.beginKiceAgain(exam, expectedOwner: owner, expectedReceiptID: receiptID) }
                }
            }
            Button("취소", role: .cancel) {}
        } message: { Text("이전 채점 결과는 보관됩니다. 새 응시는 별도 기록으로 계산합니다.") }
        .onChange(of: pdfPageIndex) { _, page in
            // 문제지 페이지가 넘어가면 그 페이지 첫 문항 행으로 OMR 을 따라가게 한다
            guard let exam = store.kiceExam else { return }
            if let key = firstKey(onPage: page, exam) { omrScrollTarget = key }
            if let sessionOwner, store.ownsCurrentAccountSession(sessionOwner) {
                store.checkpointKice(elapsedMs: timer.exactElapsedMs(), page: page)
            }
        }
    }

    // MARK: 상단 바

    private func header(_ exam: KiceExam?) -> some View {
        let displayedOwner = sessionOwner
        return VStack(spacing: Tokens.Space.s1) {
            HStack(spacing: isNarrow ? Tokens.Space.s2 : Tokens.Space.s4) {
                Button {
                    guard let owner = displayedOwner, store.ownsCurrentAccountSession(owner) else { return }
                    timer.pause()
                    let elapsed = timer.exactElapsedMs(), page = pdfPageIndex
                    Task { await store.leaveKiceStudy(elapsedMs: elapsed, page: page, expectedOwner: owner) }
                } label: {
                    Image(systemName: "xmark").font(.mBodyB).foregroundStyle(Tokens.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("나가기")
                .disabled(store.kiceBusy)

                VStack(alignment: .leading, spacing: 1) {
                    Text(exam.map { e in
                        e.displayForm.map { "\(e.short) 수학 (\($0))" } ?? "\(e.short) 수학"
                    } ?? "기출")
                        .font(.mBodyB).foregroundStyle(Tokens.ink)
                        // 좁은 폭에서 제목이 세 줄로 자라면 타이머가 밀린다. 두 줄까지만.
                        .lineLimit(isNarrow ? 2 : nil)
                    if showsExamSubtitle {
                        Text("100분, 30문항, 100점 만점")
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: Tokens.Space.s2)

                if result == nil, let exam, unansweredCount(exam) > 0 {
                    unansweredControl(exam)
                }

                if exam != nil {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 2) {
                            if timer.isRunning {
                                Circle().fill(Tokens.danger).frame(width: 6, height: 6)
                                    .padding(.trailing, 4)
                            }
                            Text(timer.display).font(.mNumeric).monospacedDigit()
                                .foregroundStyle(timeStage == .critical ? Tokens.danger
                                                 : timeStage == .closing ? Tokens.warningInk
                                                 : Tokens.ink)
                        }
                        // 색만 바꾸면 색약 학생이 놓친다 — 단계마다 문구를 함께 띄운다.
                        // 좁은 폭에서는 이 문구가 상단바 폭의 절반을 먹어 제목과 타이머를
                        // 밀어낸다. 지우지 않고 아래 전폭 띠로 내린다(아래 분기).
                        if !isNarrow, let notice = timeNotice {
                            Text(notice)
                                .font(.mMicro)
                                .foregroundStyle(timeStage == .critical ? Tokens.danger : Tokens.warningInk)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("경과 시간 \(timer.display). \(timeNotice ?? "")")
                }
            }

            if isNarrow, let notice = timeNotice {
                Text(notice)
                    .font(.mMicro)
                    .foregroundStyle(timeStage == .critical ? Tokens.danger : Tokens.warningInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    // 위 타이머 요소의 라벨이 같은 문장을 이미 읽는다 — 두 번 읽지 않는다
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, isShort ? Tokens.Space.s1 : Tokens.Space.s2)
        .background(Tokens.surface)
        .overlay(alignment: .bottom) { Divider().overlay(Tokens.line) }
    }

    private var missingExamView: some View {
        VStack(spacing: isShort ? Tokens.Space.s3 : Tokens.Space.s4) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: isShort ? 36 : 42, weight: .medium))
                .foregroundStyle(Tokens.text4)
                .accessibilityHidden(true)
            Text("기출 데이터를 찾을 수 없습니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("목록이 갱신됐거나 다른 기기에서 응시 기록이 변경됐을 수 있습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("평가센터로 돌아가기") { store.route = .assess }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 280)
        }
        .padding(isShort ? Tokens.Space.s4 : Tokens.Space.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncTimerAvailability(restore: Bool = false) {
        guard timerLifecycle.isVisible else { timer.pause(); return }
        guard let attempt = store.kiceCurrentAttempt else { timer.pause(); return }
        if restore || restoredAttemptID != attempt.id {
            timer.pause()
            timer.restore(elapsedMs: store.kiceCurrentReceipt?.elapsedMs ?? attempt.elapsedMs)
            restoredAttemptID = attempt.id
        }
        if store.canEditKice && timerLifecycle.permitsRunning { timer.start() } else { timer.pause() }
    }

    private func pauseAndSave(expectedOwner: AppStore.AccountSessionBoundary?) {
        guard let owner = expectedOwner, store.ownsCurrentAccountSession(owner) else { return }
        timer.pause()
        store.checkpointKice(elapsedMs: timer.exactElapsedMs(), page: pdfPageIndex)
        Task {
            guard store.ownsCurrentAccountSession(owner) else { return }
            _ = await store.flushKiceStudy()
        }
    }

    @ViewBuilder private var storageStatus: some View {
        let displayedOwner = sessionOwner
        if store.kiceStudyLoading {
            HStack { ProgressView(); Text("저장된 기출 답안을 불러오고 있습니다.").font(.mCaption) }
                .padding(Tokens.Space.s3)
        }
        if let error = store.kiceSaveError {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(error).font(.mCaption).foregroundStyle(Tokens.warningInk).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("다시 저장") {
                        if let owner = displayedOwner { Task { await store.retryKicePersistence(expectedOwner: owner) } }
                    }
                    Button("원본 보관 후 초기화") {
                        recoveryOwner = displayedOwner
                        confirmsRecovery = true
                    }
                }.buttonStyle(.bordered).disabled(store.kiceBusy)
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface)
        }
    }

    /// 미응답 이동 버튼. 좁은 폭에서는 "미응답 12" 다섯 글자가 상단바 폭의 3분의 1을
    /// 가져간다. 글자는 접되 44pt 조작 영역과 VoiceOver 문장은 그대로 둔다.
    @ViewBuilder private func unansweredControl(_ exam: KiceExam) -> some View {
        if isNarrow {
            Button {
                jumpToNextUnanswered(exam)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "circle.dashed").font(.mMicro)
                    Text("\(unansweredCount(exam))").font(.mNumeric).monospacedDigit()
                }
                .foregroundStyle(Tokens.text1)
                .padding(.horizontal, Tokens.Space.s2)
                .frame(minWidth: 44, minHeight: 44)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("미응답 \(unansweredCount(exam))문항. 누르면 다음 빈 문항으로 이동합니다")
        } else {
            Button {
                jumpToNextUnanswered(exam)
            } label: {
                Text("미응답 \(unansweredCount(exam))").monospacedDigit()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("미응답 \(unansweredCount(exam))문항. 누르면 다음 빈 문항으로 이동합니다")
        }
    }

    // MARK: 남은 시간 단계

    private enum TimeStage { case neutral, closing, critical }

    private var timeStage: TimeStage {
        guard result == nil else { return .neutral }   // 채점 후에는 경고할 시간이 없다
        let remaining = Self.examLengthMs - timer.elapsedSeconds * 1000
        if remaining <= 60_000 { return .critical }
        if remaining <= 600_000 { return .closing }
        return .neutral
    }

    private var timeNotice: String? {
        switch timeStage {
        case .neutral:  return nil
        case .closing:  return "10분 남았습니다. 빈 문항부터 채우세요."
        case .critical:
            return Self.examLengthMs - timer.elapsedSeconds * 1000 <= 0
                ? "시험 시간이 끝났습니다. 지금 채점하세요."
                : "1분 안에 끝납니다. 마킹을 마무리하세요."
        }
    }

    // MARK: 문제지 (PDF)

    @ViewBuilder private func pdfPane(_ exam: KiceExam) -> some View {
        if let url = KiceBank.pdfURL(for: exam) {
            KicePDFView(url: url, pageIndex: $pdfPageIndex, pageCount: $pdfPageCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) { pageControl }
        } else {
            ContentUnavailableView("문제지 PDF가 번들에 없습니다",
                                   systemImage: "doc.questionmark")
        }
    }

    private var pageControl: some View {
        HStack(spacing: Tokens.Space.s1) {
            Button {
                pdfPageIndex = max(0, pdfPageIndex - 1)
            } label: {
                Image(systemName: "chevron.left").font(.mBodyB)
                    .foregroundStyle(pdfPageIndex == 0 ? Tokens.text4 : Tokens.text1)
                    .frame(width: 44, height: 44)
            }
            .disabled(pdfPageIndex == 0)
            .accessibilityLabel("이전 페이지")

            Text("\(pdfPageIndex + 1) / \(pdfPageCount)")
                .font(.mNumeric).monospacedDigit()
                .foregroundStyle(Tokens.ink)
                .frame(minWidth: 56)
                .accessibilityLabel("\(pdfPageCount)페이지 중 \(pdfPageIndex + 1)페이지")

            Button {
                pdfPageIndex = min(pdfPageCount - 1, pdfPageIndex + 1)
            } label: {
                Image(systemName: "chevron.right").font(.mBodyB)
                    .foregroundStyle(pdfPageIndex >= pdfPageCount - 1 ? Tokens.text4 : Tokens.text1)
                    .frame(width: 44, height: 44)
            }
            .disabled(pdfPageIndex >= pdfPageCount - 1)
            .accessibilityLabel("다음 페이지")
        }
        .padding(.horizontal, Tokens.Space.s2)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
            .strokeBorder(Tokens.line, lineWidth: 1))
        .padding(.bottom, isShort ? Tokens.Space.s2 : Tokens.Space.s4)
    }

    // MARK: 답안지 (OMR)

    private func omrPane(_ exam: KiceExam) -> some View {
        let displayedOwner = sessionOwner, displayedAttemptID = store.kiceCurrentAttempt?.id
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    if let result {
                        resultCard(exam, result)
                            .id("kice-result-summary")
                    }

                    // 선택과목 — 시험지 순서(확통·미적·기하)로. 답은 과목별로 따로 남는다.
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text("선택과목").font(.mCaption).foregroundStyle(Tokens.text3)
                        Picker("선택과목", selection: subjectBinding(exam)) {
                            ForEach(KiceBank.electiveOrder, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                        .disabled(!store.canEditKice)
                    }

                    section(title: "공통 (1~22)", items: exam.common,
                            sectionKey: "공통", exam: exam)
                    section(title: "\(subject(exam)) (23~30)",
                            items: exam.electives[subject(exam)] ?? [],
                            sectionKey: subject(exam), exam: exam)

                    if result == nil {
                        // ▼▼▼ 디버그 답안 숏컷 — 이 묶음 하나만 주석 처리하면 통째로 사라진다 ▼▼▼
                        #if DEBUG
                        if !RuntimeMode.isReviewCapture {
                            KiceDebugShortcut(exam: exam, subject: subject(exam))
                        }
                        #endif
                        // ▲▲▲ 디버그 답안 숏컷 끝 ▲▲▲
                    }
                }
                .padding(Tokens.Space.s4)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if result == nil {
                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        Button("채점하기 · \(answeredCount(exam))문항 응답") {
                            grade(exam, owner: displayedOwner, attemptID: displayedAttemptID)
                        }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(answeredCount(exam) == 0 || !store.canEditKice)
                        Text("무응답은 오답으로 처리됩니다. 답안과 경과 시간은 이 계정에 저장됩니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    .padding(.horizontal, Tokens.Space.s4)
                    .padding(.vertical, Tokens.Space.s2)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
                }
            }
            .background(Tokens.paper)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: result != nil) { _, hasResult in
                if hasResult { proxy.scrollTo("kice-result-summary", anchor: .top) }
            }
            .onChange(of: omrScrollTarget) { _, target in
                guard let target else { return }
                scroll(proxy, to: target)
                omrScrollTarget = nil   // 같은 행으로 다시 갈 수 있게 소비 즉시 비운다
            }
            .onAppear {
                // 좁은 폭에서 답안지 면으로 전환되며 생겼을 때, 대기 중인 목표를 소화한다
                guard let target = omrScrollTarget else { return }
                proxy.scrollTo(target, anchor: UnitPoint(x: 0, y: 0.15))
                omrScrollTarget = nil
            }
        }
        .id(store.kiceCurrentAttempt?.id)
    }

    private func scroll(_ proxy: ScrollViewProxy, to key: String) {
        let anchor = UnitPoint(x: 0, y: 0.15)
        if store.motionOn && !reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(key, anchor: anchor) }
        } else {
            proxy.scrollTo(key, anchor: anchor)
        }
    }

    private func section(title: String, items: [KiceItem],
                         sectionKey: String, exam: KiceExam) -> some View {
        // 10문항 구간(1–10·11–20·21~)으로 카드를 끊는다 — 종이 OMR 의 구획과 같다.
        // 8문항짜리 선택과목처럼 구간이 하나뿐이면 헤더 없이 종전 모양 그대로.
        let bands = Dictionary(grouping: items) { ($0.no - 1) / 10 }
            .sorted { $0.key < $1.key }
            .map(\.value)
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
            ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    if bands.count > 1, let lo = band.first?.no, let hi = band.last?.no {
                        Text("\(lo)~\(hi)번")
                            .font(.mMicro).foregroundStyle(Tokens.text3).monospacedDigit()
                            .accessibilityAddTraits(.isHeader)
                    }
                    VStack(spacing: 0) {
                        ForEach(band) { item in
                            if item.no != band.first?.no { DottedRule() }
                            KiceOMRRow(item: item,
                                       answer: answerBinding(exam, sectionKey, item),
                                       verdict: verdict(sectionKey, item),
                                       onCurrentPage: isOnCurrentPage(exam, sectionKey, item))
                                .disabled(!store.canEditKice)
                                .id("\(sectionKey)-\(item.no)")
                        }
                    }
                    .padding(.horizontal, Tokens.Space.s3)
                    .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    // 현재 페이지 틴트·표시선이 카드 모서리 밖으로 삐치지 않게 자른다
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(Tokens.line, lineWidth: 1))
                }
            }
        }
    }

    // MARK: 채점 결과 카드

    private func resultCard(_ exam: KiceExam, _ r: KiceStudyResult) -> some View {
        let displayedOwner = sessionOwner
        return VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s2) {
                if store.motionOn && !reduceMotion {
                    LottieWebView(name: r.wrongCount == 0 ? "lottie-correct" : "lottie-wrong")
                        .frame(width: 40, height: 40)
                        .alignmentGuide(.lastTextBaseline) { $0[VerticalAlignment.center] + 16 }
                        .accessibilityHidden(true)
                }
                Text("\(r.score)").font(.mStat).foregroundStyle(Tokens.ink)
                Text("/ 100점").font(.mCaption).foregroundStyle(Tokens.text3)
                Spacer()
                Text(timer.display).font(.mNumeric).foregroundStyle(Tokens.text3)
            }
            Text("\(r.correctCount) / \(r.total)문항 정답, \(subject(exam))")
                .font(.mCallout).foregroundStyle(Tokens.text2)
            if r.wrongCount > 0 {
                Text(store.kiceCurrentReceipt?.localEffectsApplied == true
                     ? "틀린 \(r.wrongCount)문항이 오답노트에 들어갔습니다. 정답은 알려드리지 않습니다. 문제지에서 다시 풀어 복습으로 통과하세요."
                     : "채점 결과는 저장됐습니다. 틀린 \(r.wrongCount)문항을 오답노트에 반영하고 있습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
                Button("오답노트로 가기") { store.route = .wrongNotes }
                    .buttonStyle(PressScaleStyle())
                    .font(.mBodyB).foregroundStyle(Tokens.onPrimary)
                    .padding(.horizontal, Tokens.Space.s5)
                    .frame(minHeight: 44)
                    .background(Tokens.primary, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    .disabled(store.kiceCurrentReceipt?.localEffectsApplied != true)
            } else {
                Text("만점입니다. 실전에서도 이 페이스면 됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.successInk)
            }
            Button("새 응시로 다시 풀기") {
                newAttemptOwner = displayedOwner
                newAttemptReceiptID = r.id
                confirmsNewAttempt = true
            }
                .buttonStyle(.bordered)
                .disabled(store.kiceBusy || store.kiceCurrentReceipt?.effectsApplied != true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: 상태 접근

    private func subject(_ exam: KiceExam) -> String {
        store.kiceSubject[exam.id] ?? KiceBank.electiveOrder[0]
    }

    private func subjectBinding(_ exam: KiceExam) -> Binding<String> {
        let owner = sessionOwner, attemptID = store.kiceCurrentAttempt?.id
        return Binding(get: { subject(exam) },
                set: {
                    guard let owner, store.ownsCurrentAccountSession(owner), store.kiceCurrentAttempt?.id == attemptID else { return }
                    store.setKiceSubject($0, exam: exam)
                })
    }

    private func answerBinding(_ exam: KiceExam, _ sectionKey: String,
                               _ item: KiceItem) -> Binding<String> {
        let owner = sessionOwner, attemptID = store.kiceCurrentAttempt?.id
        return Binding(get: { store.kiceAnswers[exam.id]?["\(sectionKey)-\(item.no)"] ?? "" },
                set: {
                    guard let owner, store.ownsCurrentAccountSession(owner), store.kiceCurrentAttempt?.id == attemptID else { return }
                    store.setKiceAnswer(examID: exam.id, key: "\(sectionKey)-\(item.no)", value: $0)
                })
    }

    private func answeredCount(_ exam: KiceExam) -> Int {
        let map = store.kiceAnswers[exam.id] ?? [:]
        let keys = exam.common.map { "공통-\($0.no)" }
            + (exam.electives[subject(exam)] ?? []).map { "\(subject(exam))-\($0.no)" }
        return keys.filter { !(map[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private func verdict(_ sectionKey: String, _ item: KiceItem) -> Bool? {
        result?.verdicts["\(sectionKey)-\(item.no)"]
    }

    // MARK: 미응답 탐색 · 페이지-문항 근사 매핑

    /// 시험지 순서(공통 → 현재 선택과목)의 (행 id, 문항) 목록
    private func orderedEntries(_ exam: KiceExam) -> [(key: String, item: KiceItem)] {
        exam.common.map { ("공통-\($0.no)", $0) }
            + (exam.electives[subject(exam)] ?? []).map { ("\(subject(exam))-\($0.no)", $0) }
    }

    private func unansweredCount(_ exam: KiceExam) -> Int {
        exam.common.count + (exam.electives[subject(exam)] ?? []).count - answeredCount(exam)
    }

    /// 마지막으로 건너뛴 문항 뒤의 빈 문항으로, 끝에 닿으면 처음으로 돌아 순환한다
    private func jumpToNextUnanswered(_ exam: KiceExam) {
        let map = store.kiceAnswers[exam.id] ?? [:]
        let order = orderedEntries(exam).map(\.key)
        let empty = order.filter { (map[$0] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        guard !empty.isEmpty else { return }
        let lastIdx = lastJumpKey.flatMap { order.firstIndex(of: $0) } ?? -1
        let next = empty.first { (order.firstIndex(of: $0) ?? -1) > lastIdx } ?? empty[0]
        lastJumpKey = next
        pane = .omr                    // 좁은 폭이면 답안지 면으로 데려간다. 넓은 폭에선 무해.
        omrScrollTarget = next
    }

    /// 전체 문항을 페이지 수로 등분한 근사 — i번째 문항이 속한 페이지
    private func approxPage(forOrder i: Int, of total: Int) -> Int {
        guard total > 0, pdfPageCount > 0 else { return 0 }
        return min(pdfPageCount - 1, i * pdfPageCount / total)
    }

    private func firstKey(onPage page: Int, _ exam: KiceExam) -> String? {
        let entries = orderedEntries(exam)
        return entries.indices
            .first { approxPage(forOrder: $0, of: entries.count) == page }
            .map { entries[$0].key }
    }

    private func isOnCurrentPage(_ exam: KiceExam, _ sectionKey: String, _ item: KiceItem) -> Bool {
        guard pdfPageCount > 1 else { return false }   // 페이지 정보가 없으면 전부 칠하는 소음이 된다
        let entries = orderedEntries(exam)
        guard let i = entries.firstIndex(where: { $0.key == "\(sectionKey)-\(item.no)" })
        else { return false }
        return approxPage(forOrder: i, of: entries.count) == pdfPageIndex
    }

    // MARK: 채점

    private func grade(_ exam: KiceExam, owner: AppStore.AccountSessionBoundary?, attemptID: String?) {
        guard let sessionOwner = owner, store.ownsCurrentAccountSession(sessionOwner), store.canEditKice,
              let attemptID, store.kiceCurrentAttempt?.id == attemptID else { return }
        timer.pause()
        let elapsed = timer.exactElapsedMs()
        store.checkpointKice(elapsedMs: elapsed, page: pdfPageIndex)
        Task { await store.gradeKice(exam, elapsedMs: elapsed, expectedOwner: sessionOwner, expectedAttemptID: attemptID) }
    }
}

// MARK: - OMR 한 행

private struct KiceOMRRow: View {
    let item: KiceItem
    @Binding var answer: String
    /// nil = 채점 전, true/false = 채점 후 정오
    let verdict: Bool?
    /// 지금 문제지에서 보고 있는 페이지의 문항인가 — 배경 틴트 + 좌측 시안 표시선
    let onCurrentPage: Bool

    private static let circled = ["①", "②", "③", "④", "⑤"]
    @FocusState private var focused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// iPhone 가로의 전체 horizontal size class가 regular여도 오른쪽 OMR pane은
    /// 352pt뿐이다. 전체 창의 폭 등급이 아니라 짧은 가로모드까지 compact 행으로
    /// 취급해야 다섯 선택지의 44pt 조작 영역이 pane 밖으로 넘치지 않는다.
    private var usesCompactMetrics: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    /// 버블 사이 간격과 히트 폭. 좁은 폭에서는 사이 여백(12pt)을 버튼 히트 영역으로
    /// 흡수해 34pt 원을 그대로 둔 채 조작 영역만 44pt 로 넓힌다.
    /// 줄 전체 폭은 오히려 **줄어든다**:
    ///   regular  26 + 12 + (5×34 + 4×12 = 218) + 12 + 12 + 22 = 302pt
    ///   compact  26 +  8 + (5×44 +  0    = 220) +  8 +  8 + 22 = 292pt
    /// 44pt 조작 영역을 얻으면서 폭은 10pt 아낀다.
    private var bubbleSpacing: CGFloat { 0 }
    private var bubbleHitWidth: CGFloat { 44 }
    private var rowSpacing: CGFloat { usesCompactMetrics ? Tokens.Space.s2 : Tokens.Space.s3 }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalRow
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                HStack {
                    Text("\(item.no)번").font(.mNumeric).foregroundStyle(Tokens.text2)
                    Spacer()
                    trailingMark
                }
                if item.isChoice {
                    HStack(spacing: 0) { ForEach(1...5, id: \.self) { n in bubble(n) } }
                } else { answerField }
            }
        }
        .frame(minHeight: 48)
        .background(onCurrentPage ? Tokens.primarySoft : .clear)
    }

    private var horizontalRow: some View {
        HStack(spacing: rowSpacing) {
            Text("\(item.no)")
                .font(.mNumeric).foregroundStyle(Tokens.text2)
                .frame(width: 26, alignment: .trailing)
                .monospacedDigit()

            if item.isChoice {
                // 5지선다 버블 — 다시 누르면 해제.
                // regular 에서는 간격이 s3 라 예전 평면 배치와 픽셀이 같다.
                HStack(spacing: bubbleSpacing) {
                    ForEach(1...5, id: \.self) { n in bubble(n) }
                }
            } else {
                answerField
            }

            Spacer(minLength: 0)

            trailingMark
        }
        .frame(minHeight: 48)
        .background {
            if onCurrentPage {
                // 카드 안쪽 여백(-s3)까지 넓혀 연속된 행이 한 띠로 이어지게 한다
                Rectangle().fill(Tokens.primarySoft)
                    .padding(.horizontal, -Tokens.Space.s3)
            }
        }
        .overlay(alignment: .leading) {
            if onCurrentPage {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Tokens.brandCyan)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .offset(x: -Tokens.Space.s3)
                    .accessibilityHidden(true)
            }
        }
    }

    private func bubble(_ n: Int) -> some View {
        let key = "\(n)"
        return Button {
            answer = (answer == key) ? "" : key
        } label: {
            Text(Self.circled[n - 1])
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(answer == key ? Tokens.onPrimary : Tokens.text2)
                .frame(width: 34, height: 34)
                .background(answer == key ? Tokens.primary : Tokens.surface,
                            in: Circle())
                .overlay(Circle().strokeBorder(
                    answer == key ? Tokens.primary : Tokens.line, lineWidth: 1.3))
                // 원은 34pt 로 두고 히트 영역만 늘린다 — 세로는 항상 44pt,
                // 좁은 폭에서는 가로도 44pt (사이 여백을 히트 영역이 대신한다)
                .frame(width: bubbleHitWidth, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(verdict != nil)
        .accessibilityLabel("\(item.no)번 \(n)번 선지")
        .accessibilityAddTraits(answer == key ? .isSelected : [])
    }

    private var answerField: some View {
        TextField("0~999", text: $answer)
            .font(.mBody)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            // 좁은 폭에서는 이 칸이 그 행의 유일한 조작 영역이다 — 44pt 로 세운다
            .frame(width: 92, height: usesCompactMetrics ? 44 : 34)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(focused ? Tokens.primary : Tokens.line, lineWidth: 1.3))
            .focused($focused)
            .disabled(verdict != nil)
            .accessibilityLabel("\(item.no)번 답")
    }

    @ViewBuilder private var trailingMark: some View {
        if let verdict {
            // 정오만 알려준다 — 정답 비공개 계약은 기출에서도 유지
            Image(systemName: verdict ? "circle" : "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(verdict ? Tokens.success : Tokens.danger)
                .accessibilityLabel(verdict ? "정답" : "오답")
        } else {
            Text("\(item.points)점").font(.mMicro).foregroundStyle(Tokens.text4)
        }
    }
}

// MARK: - PDF 뷰어

private struct KicePDFView: UIViewRepresentable {
    let url: URL
    /// 현재 페이지(0기준). 사용자 스크롤이면 코디네이터가 올리고,
    /// 이전·다음 버튼이면 updateUIView 가 내려서 양방향으로 맞춘다.
    @Binding var pageIndex: Int
    @Binding var pageCount: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = false
        view.backgroundColor = .clear
        context.coordinator.observe(view)
        let count = view.document?.pageCount ?? 1
        DispatchQueue.main.async {   // 뷰 갱신 도중의 상태 변경을 피한다
            pageCount = max(1, count)
            pageIndex = 0
        }
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
            let count = view.document?.pageCount ?? 1
            DispatchQueue.main.async {
                pageCount = max(1, count)
                pageIndex = 0
            }
            return
        }
        // 바인딩 쪽이 앞서 있으면(페이지 버튼) 그 페이지로 이동.
        // 사용자 스크롤 경로는 코디네이터가 이미 맞춰 둬서 여기선 no-op 이다.
        if let doc = view.document, doc.pageCount > 0 {
            let clamped = max(0, min(pageIndex, doc.pageCount - 1))
            if let current = view.currentPage, doc.index(for: current) != clamped,
               let target = doc.page(at: clamped) {
                view.go(to: target)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: KicePDFView
        init(_ parent: KicePDFView) { self.parent = parent }

        func observe(_ view: PDFView) {
            NotificationCenter.default.addObserver(
                self, selector: #selector(pageChanged(_:)),
                name: .PDFViewPageChanged, object: view)
        }

        @objc private func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView,
                  let doc = view.document, let page = view.currentPage else { return }
            let idx = doc.index(for: page)
            guard parent.pageIndex != idx else { return }
            DispatchQueue.main.async { self.parent.pageIndex = idx }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

#if DEBUG
// ┌─────────────────────────── 디버그 전용 컴포넌트 ───────────────────────────┐
// │ 기출 답안 숏컷 — 30문항을 손으로 채우지 않아도 되게 정답/오답 채우기를     │
// │ 한 컴포지션으로 묶었다. 채우기만 하고 채점은 정규 "채점하기" 경로를 탄다.  │
// │ 제거 방법: KiceExamScreen 의 "디버그 답안 숏컷" 호출 묶음 하나만 주석 처리.│
// └────────────────────────────────────────────────────────────────────────────┘
private struct KiceDebugShortcut: View {
    @EnvironmentObject private var store: AppStore
    let exam: KiceExam
    let subject: String

    var body: some View {
        HStack(spacing: Tokens.Space.s3) {
            Text("DEBUG").font(.mMicro).foregroundStyle(Tokens.text4)

            Button("정답 채우기") { fill(correct: true) }
                .font(.mCaption).foregroundStyle(Tokens.successInk)
                .padding(.horizontal, Tokens.Space.s3)
                .frame(minHeight: 34)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.success, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))

            Button("오답 채우기") { fill(correct: false) }
                .font(.mCaption).foregroundStyle(Tokens.primary)
                .padding(.horizontal, Tokens.Space.s3)
                .frame(minHeight: 34)
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.primary, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))

            Spacer()
        }
        .padding(Tokens.Space.s2)
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
            .strokeBorder(Tokens.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func fill(correct: Bool) {
        func wrongValue(_ item: KiceItem) -> String {
            if item.isChoice {
                // 정답과 절대 겹치지 않는 다음 선지
                return "\(((Int(item.answer) ?? 1) % 5) + 1)"
            }
            return Int(item.answer) == 999 ? "998" : "999"
        }
        for item in exam.common {
            store.setKiceAnswer(examID: exam.id, key: "공통-\(item.no)", value: correct ? item.answer : wrongValue(item))
        }
        for item in exam.electives[subject] ?? [] {
            store.setKiceAnswer(examID: exam.id, key: "\(subject)-\(item.no)", value: correct ? item.answer : wrongValue(item))
        }
    }
}
#endif
