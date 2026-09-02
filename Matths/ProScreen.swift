//  ProScreen.swift
//  Matths
//
//  Pro — 모의고사 사진 채점.
//
//  흐름: 시험지 사진 선택 → 온디바이스 파이프라인(sheet-grader)이
//        기준점 검출 → 원근 보정 → 손글씨 판독 → 풀이 채점 →
//        문항별 정오와 "틀린 유형" 이 돌아온다.
//
//  여기서 끝나면 반쪽이다. 핵심은 그다음이다:
//  틀린 유형 키를 ProblemGenerator 에 넣어 **비슷한 문제로만 짠 새 모의고사를
//  그 자리에서 만든다.** AI 호출 없음, 서버 왕복 없음, 비용 0.
//  수치는 시드 난수라 만들 때마다 다르다.
//
//  분석은 앱에 내장된 로컬 비전·추론 모델로 실행한다. 서버에는 사진을 보내지 않는다.

import SwiftUI
import PhotosUI

struct ProScreen: View {
    @EnvironmentObject private var store: AppStore
    // 접근성이 앱 설정보다 우선한다(Motion.swift 규칙 2). SwiftUI 는 동작 줄이기에서
    // withAnimation 을 자동으로 억제하지 않으므로, 이 화면의 펼침·스크롤 연출도
    // 전부 store.anim(_:reduceMotion) 을 거쳐야 한다.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 가로로 든 iPhone. 세로 여백과 미리보기 크기를 여기서만 줄인다
    /// (2열 전환 자체는 CompactHeightColumns 가 같은 축으로 판정한다).
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var shortHeight: Bool { verticalSizeClass == .compact }

    private enum Stage { case idle, scanning, report }
    @State private var stage: Stage = {
        #if DEBUG
        // 스크린샷용: -proReport 로 결과 화면 직행
        if ProcessInfo.processInfo.arguments.contains("-proReport") { return .report }
        #endif
        return .idle
    }()
    @State private var stepsDone = 0

    // ── 온디바이스 분석 (SheetGrader) ───────────────────────────────
    @StateObject private var grader = SheetGrader()
    @ObservedObject private var tutor = AITutor.shared
    @ObservedObject private var modelPack = LocalAIModelPack.shared
    @State private var showPhotoPicker = false
    #if DEBUG
    @State private var showLog = false
    /// nil = 자동(기기 판정대로)
    @State private var debugTier: String? = ModelDownloader.debugForcedTier
    #endif
    @State private var showFileImporter = false
    @State private var shotImage: UIImage?
    @State private var shotPath: String?
    @State private var showCamera = false
    @State private var pickBusy = false
    @State private var showTrace = false
    @State private var waitingForModel = false
    @State private var explainHeight: CGFloat = 420
    @State private var showExplain = true
    @State private var errorText: String?
    @State private var cheatingReviewQueued = false
    @State private var preparingAnalysis = false
    /// 모델 준비·공유 엔진 대기 Task의 세대와 핸들. 계정 전환이나 사용자의 중단은
    /// 대기열에서 즉시 제거하고, 늦게 끝난 이전 Task가 새 분석 상태를 덮지 못하게 한다.
    @State private var analysisPreparationID: UUID?
    @State private var analysisPreparationTask: Task<Void, Never>?
    @State private var recoveryText: String?
    /// 분석을 시작한 계정 슬롯과 복구 디렉터리를 실행 내내 고정한다.
    /// DataScope는 로그인·로그아웃 순간 전역 슬롯을 바꾸므로, 동적 경로를 다시
    /// 읽으면 이전 학생 사진의 단계 기록·검토 결과가 새 학생 슬롯에 들어갈 수 있다.
    @State private var analysisOwnerSlot: String?
    @State private var analysisRecoveryDirectory: URL?


    /// 분석 결과 — 실물 고3 모의고사 2쪽의 골든 예시 (SheetAnalysis.swift 참고).
    /// 서버 연결 후에는 skill/SKILL.md 템플릿 JSON 디코드로 대체된다.
    #if DEBUG
    /// 스크린샷용 골든 예시. **릴리스에는 컴파일되지 않는다** —
    /// 도달 불가라도 심사용 바이너리에 남의 채점표가 들어갈 이유가 없다.
    private let pages = SheetAnalysisDemo.pages
    #endif
    @State private var expanded: Set<Int> = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-proReport") { return [10] }
        #endif
        return []
    }()

    /// 실제 분석이 잡아낸 약한 유형 (없으면 빈 배열 — 데모로 메우지 않는다)
    private var wrongTypes: [ProblemType] {
        var seen = Set<String>()
        // 약한 유형도 같은 원칙 — 분석 결과가 없으면 없는 것이다.
        // 데모 유형을 섞으면 "약한 유형 모의고사" 가 남의 약점으로 출제된다.
        var source = grader.weakTypes
        #if DEBUG
        if grader.result == nil,
           ProcessInfo.processInfo.arguments.contains("-proReport") {
            source = SheetAnalysisDemo.weakGeneratorTypes
        }
        #endif
        return source.filter { seen.insert($0.rawValue).inserted }
    }

    /// 화면에 그릴 페이지 — 실제 분석 결과만
    private var shownPages: [(title: String, items: [ProblemAnalysisItem])] {
        if let r = grader.result { return [(r.title, r.items)] }
        // 실제 분석 결과가 없으면 아무것도 보여 주지 않는다.
        //
        // 예전엔 여기서 SheetAnalysisDemo.pages 로 떨어졌고, "데모 결과 보기" 버튼이
        // 사진 한 장 없이 그 화면을 띄웠다. 학생 눈에는 남의 시험지 채점표가
        // 제 결과처럼 보인다 — 사용자가 걷어내라고 지목한 그 옛 화면이다.
        // 데모 데이터는 스크린샷용 디버그 인자로만 남긴다.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-proReport") { return pages }
        #endif
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s7) {
            HStack(alignment: .lastTextBaseline, spacing: Tokens.Space.s3) {
                Text("시험지 채점").font(.mTitle).foregroundStyle(Tokens.ink)
                Text("PRO").font(.mMicro)
                    .foregroundStyle(Tokens.onPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Tokens.primary, in: RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
            .entrance(0)

            switch stage {
            case .idle:     idleView
            case .scanning: scanningView
            case .report:   reportView
            }
        }
        .onAppear {
            // ⚠️ 여기서 모델을 미리 열지 않는다.
            // VLM과 프로젝터가 올라간 상태에서는 시스템이 사진 항목을
            // 재료화하지 못해 앨범에서 고른 사진을 **한 장도 읽지 못한다**
            // (CloudPhotoLibraryError 1005 · 기기 로그로 확정).
            // 그래서 순서를 뒤집는다: 사진을 손에 넣은 **뒤에** 모델을 연다.
            recoverPendingAnalysisIfNeeded()
            #if DEBUG
            // 화면 회귀 검증용 — 추론 완주를 기다리지 않고 사고과정·설명 UI 를 그린다
            if ProcessInfo.processInfo.arguments.contains("-fakeAnalysis") {
                grader.seedForUITest()
                stage = .report
                showTrace = true
            }
            // 사고과정 UI 는 **스캔 화면** 에만 있는데 위 인자는 결과로 건너뛴다 —
            // 그래서 그 화면을 못 본다. 스캔 단계에 머무는 인자를 따로 둔다.
            if ProcessInfo.processInfo.arguments.contains("-fakeTrace") {
                grader.seedForUITest()
                stage = .scanning
                showTrace = true
            }
            // 전역 디버그 바에서 "Pro" 를 눌러 들어온 경우 결과 화면 직행
            if store.debugProReport {
                store.debugProReport = false
                stage = .report
                expanded = [10]
            }
            #endif
        }
        .onDisappear {
            // 진행 중 파이프라인은 다음 비전 호출에서도 경로가 필요하다. 끝난 사진만 지운다.
            if !grader.running && !preparingAnalysis { discardSourcePhoto(clearRecovery: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
            let newSlot = note.object as? String ?? DataScope.slot
            guard let owner = analysisOwnerSlot, owner != newSlot else {
                recoverPendingAnalysisIfNeeded()
                return
            }
            // 이전 학생의 실행은 현재 화면에 결과를 발행하거나 새 슬롯의 검토 큐에
            // 기록할 수 없다. 원본 복구 묶음은 이전 슬롯에 그대로 남겨, 다시 로그인한
            // 학생만 처음부터 재시작할 수 있게 한다.
            grader.stop()
            cancelAnalysisPreparation()
            preparingAnalysis = false
            waitingForModel = false
            stage = .idle
            shotPath = nil
            shotImage = nil
            analysisOwnerSlot = nil
            analysisRecoveryDirectory = nil
            cheatingReviewQueued = false
            errorText = nil
            recoveryText = nil
            recoverPendingAnalysisIfNeeded()
        }
    }

    // MARK: 1. 업로드 전

    private var idleView: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            Text("종이에 푼 모의고사를 찍어 올리면 손글씨 풀이를 읽고 문항별로 채점합니다. "
                 + "어느 단계에서 틀렸는지, 어떤 유형이 약한지까지 짚습니다.")
                .font(.mBody).foregroundStyle(Tokens.text2)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            // 가로 iPhone 에서는 "미리보기와 촬영 요령" 과 "버튼·상태" 를 좌우로 나눈다.
            // 세로로 쌓으면 미리보기(최대 260pt)만으로 뷰포트가 차서 주 버튼이
            // 처음부터 화면 밖에 있다. 세로 방향과 iPad 는 아래 stacked 경로 그대로다.
            CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s4) {
                idleGuideColumn
            } trailing: {
                idleActionColumn
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, shortHeight ? Tokens.Space.s5 : Tokens.Space.s8)
            .card()

            #if DEBUG
            if !RuntimeMode.isReviewCapture {
                debugModelPicker

                // 디버그 전용 — 지난 실행에서 로컬 모델이 주고받은 컨텍스트를 통째로 본다.
                // 사진 썸네일을 누르면 단계별 프롬프트·원문 출력이 펼쳐진다.
                Button {
                    showLog = true
                } label: {
                    Label("기록 보기 (디버그)", systemImage: "clock.arrow.circlepath")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            #endif
        }
        #if DEBUG
        .compactHeightSheet(isPresented: $showLog) { GraderLogScreen() }
        #endif
        .compactHeightSheet(isPresented: $showPhotoPicker) {
            SystemPhotoPicker { provider, assetID in
                showPhotoPicker = false
                guard let provider else { return }      // 취소
                loadPicked(provider: provider, assetID: assetID)
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFileImporter,
                      allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // 보안 스코프 — 파일 앱이 준 URL 은 접근 권한을 열고 닫아야 한다
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let img = PhotoIntake.downsample(fileURL: url) {
                    PhotoIntakeLog.write("성공 · 파일에서 고르기 \(Int(img.size.width))x\(Int(img.size.height))")
                    finishPick(img, nil)
                } else {
                    finishPick(nil, "이 파일은 이미지로 읽지 못했습니다.")
                }
            case .failure(let e):
                #if DEBUG
                print("Pro 분석 파일 열기 실패:", e)
                #endif
                finishPick(nil, "파일을 열지 못했습니다. 사진 접근 권한과 파일 상태를 확인해 주세요.")
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                showCamera = false
                guard let img else { return }
                store(img)
            }
            .ignoresSafeArea()
        }
    }

    /// 왼쪽 열 — 지금 무엇을 찍는지(미리보기)와 어떻게 찍는지(요령).
    /// 읽고 확인하는 정보만 모은다.
    private var idleGuideColumn: some View {
        VStack(spacing: Tokens.Space.s4) {
            if let img = shotImage {
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    // 가로 iPhone 은 뷰포트 자체가 300pt 안팎이다. 260pt 미리보기를
                    // 그대로 두면 옆 열의 버튼과 높이가 맞지 않아 카드가 또 길어진다.
                    .frame(maxHeight: shortHeight ? 170 : 260)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(Tokens.line, lineWidth: 1))
            } else {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Tokens.text3)
            }
            Text("한 페이지씩, 그림자 없이, 모서리 포함")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .multilineTextAlignment(.center)
            // 다음에 올 단계를 미리 말한다 — 작게, 예고만
            Text("촬영, 문항 확인, 채점 결과 순서")
                .font(.mMicro).foregroundStyle(Tokens.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    /// 오른쪽 열 — 누를 것과 그 결과로 나오는 상태 문구.
    /// 상태 문구를 버튼과 같은 열에 두어야 "눌렀는데 왜 안 되나" 의 답이 눈에 붙는다.
    private var idleActionColumn: some View {
        VStack(spacing: Tokens.Space.s4) {
            // 주 경로는 촬영이다 — 시험지는 손에 있다. 보관함·파일은 예외 경로라
            // 같은 무게로 늘어놓지 않고 메뉴 하나로 접는다. 위계는 세로가 정직하다.
            VStack(spacing: Tokens.Space.s3) { photoSourceButtons }
                .frame(maxWidth: 420)

            if pickBusy {
                HStack(spacing: Tokens.Space.s2) {
                    ProgressView().controlSize(.small)
                    Text("사진 읽는 중…").font(.mCaption).foregroundStyle(Tokens.text3)
                }
            }

            if shotPath != nil {
                // 모델이 아직이어도 **누를 수 있게** 둔다. 누르면 진행 화면으로 넘어가
                // 거기서 모델이 열리길 기다렸다 자동으로 시작한다.
                // (비활성 버튼 + "준비 중" 문구 조합은 사용자에게 "고장" 으로 읽힌다)
                Button("이 사진 분석하기 (기기 안에서)") { startOnDeviceAnalysis() }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 420)
            }

            if ModelDownloader.visionOffForCurrentModel {
                // 사진 분석은 시작할 때 전용 판독 모델로 전환하므로, 지금 열린 텍스트
                // 모델의 visionReady=false는 정상이다. 그 상태를 오류처럼 안내하면
                // Release에 없는 디버그 모델 선택기를 찾게 된다. 실제 크래시 래치가
                // 걸렸을 때만 이유와 이 화면에서 수행할 수 있는 복구 동선을 보인다.
                Text("지난 실행에서 사진 분석 모듈을 여는 도중 앱이 종료돼 자동으로 꺼 두었습니다. 아래 버튼으로 다시 시도할 수 있습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.warningInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("사진 분석 다시 시도") {
                    ModelDownloader.clearVisionDisabled()
                    tutor.reloadModel()
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: 420)
            }

            if let e = errorText {
                Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let message = recoveryText {
                Text(message).font(.mCaption).foregroundStyle(Tokens.warningInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let e = grader.error {
                Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 데모는 **결과 화면으로 바로** 간다. 가짜 진행 연출을 보여 주면
            // 실제 분석과 구분이 안 돼 "안 넘어간다" 로 읽힌다.
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var photoSourceButtons: some View {
        if CameraPicker.isAvailable {
            // "이 사진 분석하기" 와 같은 조건(shotPath)으로 가른다 — 사진 저장이
            // 실패한 화면에 주 버튼이 하나도 없는 순간을 만들지 않는다.
            if shotPath == nil {
                Button {
                    Task {
                        await tutor.releaseForMemory()   // 촬영 중에도 메모리를 비운다
                        showCamera = true
                    }
                } label: {
                    Label("시험지 촬영하기", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                // 사진을 손에 넣은 뒤에는 주 버튼 자리를 "이 사진 분석하기" 가 가진다
                // (화면당 주 버튼 1개 원칙)
                Button {
                    Task {
                        await tutor.releaseForMemory()
                        showCamera = true
                    }
                } label: {
                    Label("다시 촬영하기", systemImage: "camera")
                        .font(.mBodyB).frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }

        Menu {
            Button {
                // 사진을 고르는 동안에는 메모리를 시스템에 돌려준다
                Task {
                    await tutor.releaseForMemory()
                    showPhotoPicker = true
                }
            } label: {
                Label("보관함에서 고르기", systemImage: "photo.on.rectangle")
            }
            // 사진 라이브러리를 아예 거치지 않는 길. iCloud 원본이 비워져
            // Photos 가 화소를 못 주는 사진이 실제로 있었다 — 그때 이 길이 답이다.
            Button {
                showFileImporter = true
            } label: {
                Label("파일 가져오기", systemImage: "folder")
            }
        } label: {
            // SecondaryButtonStyle 은 ButtonStyle 이라 Menu 에 못 붙는다 — 같은 모양을 그린다
            Label("보관함과 파일에서 가져오기", systemImage: "photo.on.rectangle")
                .font(.mBodyB).foregroundStyle(Tokens.text1)
                .padding(.horizontal, Tokens.Space.s5)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1.5))
        }
    }

    private var analyzeButtonTitle: String {
        tutor.visionAvailable ? "이 사진 분석하기 (기기 안에서)" : "모델 준비 중…"
    }

    /// 앨범에서 고른 사진을 읽어 파일로 떨군다 (모델은 경로로 읽는다).
    /// 네 경로를 차례로 시도하고, 실패해도 조용히 사라지지 않는다 —
    /// 무반응이 제일 나쁜 실패다. 실패 상세는 Documents/photo-intake.log 에 남는다.
    private func loadPicked(provider: NSItemProvider, assetID: String?) {
        pickBusy = true
        errorText = nil
        Task {
            switch await PhotoIntake.load(provider: provider, assetID: assetID) {
            case .success(let img):
                finishPick(img, nil)
            case .failure(let e):
                // 네 경로가 다 막히는 원인은 대개 메모리다 — 모델이 올라가 있으면
                // 시스템이 사진 항목을 재료화하지 못한다. 모델을 내리고 한 번만 더.
                if tutor.isReady {
                    PhotoIntakeLog.write("재시도 · 모델을 내리고 다시 시도한다")
                    await tutor.releaseForMemory()
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    switch await PhotoIntake.load(provider: provider, assetID: assetID) {
                    case .success(let img): finishPick(img, nil); return
                    case .failure(let e2):  finishPick(nil, e2.message); return
                    }
                }
                finishPick(nil, e.message)
            }
        }
    }

    @MainActor private func finishPick(_ img: UIImage?, _ message: String?) {
        pickBusy = false
        if let m = message { errorText = m }
        guard let img else { return }
        if !grader.running { discardSourcePhoto() }
        recoveryText = nil
        cheatingReviewQueued = false
        shotImage = img
        guard let jpeg = img.jpegData(compressionQuality: 0.9) else {
            errorText = "사진을 저장하지 못했습니다"
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("matths-sheet-\(UUID().uuidString.prefix(8)).jpg")
        do { try jpeg.write(to: url, options: [.atomic, .completeFileProtection]) }
        catch {
            #if DEBUG
            print("Pro 분석 임시 사진 저장 실패:", error)
            #endif
            errorText = "사진을 저장하지 못했습니다. 기기의 저장 공간을 확인한 뒤 다시 시도해 주세요."
            return
        }
        shotPath = url.path
        grader.stop()
        // 사진을 고른 직후에는 모델을 열지 않는다. 8GB 기기는 사진 판독기와
        // 수학 추론기를 순차로 써야 하므로 분석 시작 때 전용 팩을 준비한다.
    }

    /// 촬영본은 이미 UIImage 로 온다 — 같은 예산으로 줄여 같은 경로에 태운다
    private func store(_ img: UIImage) {
        finishPick(img.normalizedUp().resizedToPixelBudget(ModelDownloader.photoPixelBudget), nil)
    }

    /// 분석 시작. 모델이 아직 열리는 중이어도 **화면은 먼저 넘긴다** —
    /// 버튼을 눌렀는데 아무 일도 안 일어나는 것이 제일 나쁜 실패다.
    /// 준비되면 자동으로 이어서 시작한다(waitingForModel).
    private func startOnDeviceAnalysis() {
        guard let path = shotPath, !preparingAnalysis, !grader.running else { return }
        let ownerSlot = DataScope.slot
        let recoveryDirectory = DataScope.url(LocalAIJobRecovery.directoryName)
        let durablePath: String
        do {
            durablePath = try LocalAIJobRecovery.begin(
                sourcePath: path,
                stageLabel: "분석 준비",
                in: recoveryDirectory)
            shotPath = durablePath
            analysisOwnerSlot = ownerSlot
            analysisRecoveryDirectory = recoveryDirectory
            recoveryText = nil
        } catch {
            #if DEBUG
            print("Pro 분석 복구 사진 저장 실패:", error)
            #endif
            errorText = "분석 사진을 안전하게 보관하지 못했습니다. 기기의 저장 공간을 확인한 뒤 다시 시도해 주세요."
            return
        }
        stage = .scanning
        preparingAnalysis = true
        errorText = nil
        let preparationID = UUID()
        analysisPreparationID = preparationID

        analysisPreparationTask = Task {
            var workLease: LocalAIWorkCoordinator.Lease?
            var handedLeaseToGrader = false
            do {
                LocalAIJobRecovery.update(stageLabel: "모델 준비", in: recoveryDirectory)
                try await modelPack.prepareForSheetAnalysis()
                try assertAnalysisOwnership(ownerSlot, preparationID: preparationID)
                // 다운로드는 엔진을 쓰지 않으므로 먼저 끝낸다. 실제 모델 전환부터
                // 파이프라인 종료까지는 공유 엔진의 단일 소유권을 유지한다.
                let acquiredLease = try await LocalAIWorkCoordinator.shared.acquire(.sheetGrading)
                workLease = acquiredLease
                try assertAnalysisOwnership(ownerSlot, preparationID: preparationID)
                let vision = ModelDownloader.analysisVisionSpec
                guard await tutor.switchModel(toFile: vision.file),
                      tutor.visionAvailable,
                      let engine = tutor.localEngine else {
                    throw LocalAIAnalysisStartError.visionUnavailable
                }
                try assertAnalysisOwnership(ownerSlot, preparationID: preparationID)

                let reasoningFile = ModelDownloader.analysisReasoningSpec.file
                LocalAIJobRecovery.update(stageLabel: "사진 판독", in: recoveryDirectory)
                grader.run(
                    imagePath: durablePath,
                    engine: engine,
                    beforeReasoning: {
                        guard DataScope.slot == ownerSlot else {
                            throw CancellationError()
                        }
                        guard reasoningFile != vision.file else { return }
                        let switched = await AITutor.shared.switchModel(toFile: reasoningFile)
                        guard switched else {
                            throw LocalAIAnalysisStartError.reasoningUnavailable
                        }
                        guard DataScope.slot == ownerSlot else {
                            throw CancellationError()
                        }
                    },
                    workLease: acquiredLease)
                handedLeaseToGrader = true
                if analysisPreparationID == preparationID {
                    preparingAnalysis = false
                    clearAnalysisPreparation(ifOwnedBy: preparationID)
                }
            } catch is CancellationError {
                if analysisPreparationID == preparationID {
                    preparingAnalysis = false
                    waitingForModel = false
                    stage = .idle
                    clearAnalysisPreparation(ifOwnedBy: preparationID)
                }
            } catch {
                if analysisPreparationID == preparationID {
                    preparingAnalysis = false
                    errorText = Self.analysisStartFailureMessage(error)
                    recoveryText = "분석이 중단됐습니다. 같은 사진으로 처음부터 다시 시작할 수 있습니다."
                    LocalAIJobRecovery.update(stageLabel: "다시 시작 대기", in: recoveryDirectory)
                    stage = .idle
                    clearAnalysisPreparation(ifOwnedBy: preparationID)
                }
            }
            if let workLease, !handedLeaseToGrader {
                await LocalAIWorkCoordinator.shared.release(workLease)
            }
        }
    }

    private func tryStartIfReady() {
        guard !preparingAnalysis,
              stage == .scanning, !grader.running, grader.result == nil,
              let path = shotPath else { return }
        preparingAnalysis = true
        let ownerSlot = analysisOwnerSlot ?? DataScope.slot
        let preparationID = UUID()
        analysisPreparationID = preparationID
        analysisPreparationTask = Task {
            var workLease: LocalAIWorkCoordinator.Lease?
            var handedLeaseToGrader = false
            do {
                let acquiredLease = try await LocalAIWorkCoordinator.shared.acquire(.sheetGrading)
                workLease = acquiredLease
                try assertAnalysisOwnership(ownerSlot, preparationID: preparationID)
                guard let engine = tutor.localEngine else {
                    throw LocalAIAnalysisStartError.reasoningUnavailable
                }
                waitingForModel = false
                grader.run(imagePath: path, engine: engine, workLease: acquiredLease)
                handedLeaseToGrader = true
            } catch is CancellationError {
                if analysisPreparationID == preparationID { waitingForModel = false }
            } catch {
                if analysisPreparationID == preparationID {
                    errorText = Self.analysisStartFailureMessage(error)
                }
            }
            if let workLease, !handedLeaseToGrader {
                await LocalAIWorkCoordinator.shared.release(workLease)
            }
            if analysisPreparationID == preparationID {
                preparingAnalysis = false
                clearAnalysisPreparation(ifOwnedBy: preparationID)
            }
        }
    }

    private static func analysisStartFailureMessage(_ error: Error) -> String {
        if let startError = error as? LocalAIAnalysisStartError {
            return startError.errorDescription
                ?? "분석 모델을 준비하지 못했습니다. 다른 앱을 닫고 다시 시도해 주세요."
        }
        #if DEBUG
        print("Pro 분석 시작 실패:", error)
        #endif
        return "분석을 시작하지 못했습니다. 다른 앱을 닫고 같은 사진으로 다시 시도해 주세요."
    }

    // MARK: 2. 파이프라인 진행

    /// 진행 화면은 **하나뿐이다** — 실제 온디바이스 파이프라인.
    /// (옛 "기준점 4점 검출 → 원근 보정(호모그래피)" 데모 연출은 걷어냈다.
    ///  그건 서버 파이프라인 설명이라 앱에서 도는 것과 아무 관계가 없었고,
    ///  실제로 그 화면에서 멈춰 다음으로 넘어가지 않는 것처럼 보였다.)
    private var scanningView: some View { onDeviceScanningView }

    private var onDeviceScanningView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 모델이 아직 열리는 중이면 그 사실을 말한다 — 단계 목록만 멈춰 있으면
            // 사용자는 "안 넘어간다" 로 읽는다.
            if !grader.running && grader.result == nil {
                HStack(spacing: Tokens.Space.s3) {
                    ProgressView().controlSize(.small)
                    Text(preparingAnalysis
                         ? modelPack.statusText
                         : (tutor.isReady ? "분석을 시작합니다…" : "AI 모델을 여는 중입니다 (처음 한 번만 오래 걸립니다)"))
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                    Spacer()
                }
                .padding(.bottom, Tokens.Space.s4)
            }

            ForEach(SheetGrader.Stage.allCases, id: \.rawValue) { st in
                if st.rawValue > 0 { DottedRule() }
                HStack(spacing: Tokens.Space.s4) {
                    if let cur = grader.stage {
                        if st.rawValue < cur.rawValue {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.successInk)
                        } else if st == cur {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "circle").foregroundStyle(Tokens.lineStrong)
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.successInk)
                    }
                    Text(st.label).font(.mBody)
                        .foregroundStyle(grader.stage.map { st.rawValue <= $0.rawValue } ?? true
                                         ? Tokens.ink : Tokens.text4)
                    if st == grader.stage, !grader.detail.isEmpty {
                        Text(grader.detail).font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    Spacer()
                }
                .padding(.vertical, Tokens.Space.s4)
            }

            DottedRule()

            #if DEBUG
            if !RuntimeMode.isReviewCapture {
                // 원시 모델 토큰은 품질 진단 자료다. 학생 풀이 설명이 아니므로
                // 릴리스 화면에는 노출하지 않는다.
                Button {
                    withAnimation(store.anim(.easeOut(duration: 0.18), reduceMotion)) { showTrace.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "brain")
                        Text(showTrace ? "모델 출력 접기" : "모델 출력 보기 (DEBUG)")
                        if !grader.trace.isEmpty, !showTrace {
                            Text("토큰 흐르는 중").foregroundStyle(Tokens.text3)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(showTrace ? 180 : 0))
                    }
                    .font(.mCaption).foregroundStyle(Tokens.primary)
                    .padding(.top, Tokens.Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showTrace { traceView }
            }
            #endif

            HStack {
                Text("기기 안에서 처리 중입니다. 사진은 서버로 가지 않습니다")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                Spacer()
                Button("중단") {
                    grader.stop()
                    cancelAnalysisPreparation()
                    preparingAnalysis = false
                    discardSourcePhoto()
                    recoveryText = nil
                    stage = .idle
                }
                    .font(.mCaption).foregroundStyle(Tokens.primary)
                    .buttonStyle(.plain)
            }
            .padding(.top, Tokens.Space.s3)

            Text("다른 앱을 열면 운영체제가 허용하는 짧은 시간 동안만 이어집니다. 중단되거나 앱이 종료돼도 이 사진을 보존해 다음 실행에서 처음부터 다시 시작할 수 있습니다.")
                .font(.mMicro)
                .foregroundStyle(Tokens.text4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("백그라운드 처리 안내. 다른 앱을 열면 잠시만 이어지며, 중단되면 보존한 사진으로 다음 실행에서 처음부터 다시 시작합니다.")

            if let e = grader.error {
                Text(e).font(.mCaption).foregroundStyle(Tokens.dangerInk)
                    .padding(.top, Tokens.Space.s3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
        .onAppear { tryStartIfReady() }
        .onChange(of: tutor.modelState) { tryStartIfReady() }
        .onChange(of: grader.result?.items.count) {
            if grader.result != nil {
                guard analysisOwnerSlot == DataScope.slot else {
                    grader.stop()
                    return
                }
                stage = .report
                queueCheatingReviewIfNeeded(context: grader.cheatingReviewContext)
                discardSourcePhoto()
            }
        }
        .onChange(of: grader.error) {
            if grader.error != nil, stage == .scanning {
                if let directory = analysisRecoveryDirectory {
                    LocalAIJobRecovery.update(stageLabel: "다시 시작 대기", in: directory)
                }
                recoveryText = "분석이 끝나지 않았습니다. 같은 사진으로 다시 시도할 수 있습니다."
                stage = .idle
            }
        }
        .onChange(of: grader.stage?.rawValue) {
            if let label = grader.stage?.label,
               let directory = analysisRecoveryDirectory,
               analysisOwnerSlot == DataScope.slot {
                LocalAIJobRecovery.update(stageLabel: label, in: directory)
            }
        }
        .onChange(of: grader.running) { _, running in
            // 오류·OS 종료 복구용 사진은 명시적으로 중단하거나 성공했을 때만 지운다.
            if !running && stage == .idle, LocalAIJobRecovery.restore() == nil {
                discardSourcePhoto(clearRecovery: false)
            }
        }
    }

    /// 사고과정 — 단계별로 모델이 뱉은 토큰을 그대로 흘린다.
    /// 마지막 단계가 항상 보이도록 자동으로 아래로 붙는다.
    private var traceView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    ForEach(grader.trace) { e in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(e.stage.label)
                                .font(.mMicro).foregroundStyle(Tokens.primary)
                            Text(e.text)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(e.thinking ? Tokens.text4 : Tokens.text2)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(e.id)
                    }
                    if grader.trace.isEmpty {
                        Text("아직 토큰이 없습니다. 이미지 인코딩 중입니다.")
                            .font(.mCaption).foregroundStyle(Tokens.text3)
                    }
                    Color.clear.frame(height: 1).id("traceBottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Tokens.Space.s2)
            }
            .frame(height: 220)
            .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            .onChange(of: grader.trace.count) {
                withAnimation(store.anim(.linear(duration: 0.12), reduceMotion)) {
                    proxy.scrollTo("traceBottom", anchor: .bottom)
                }
            }
        }
        .padding(.top, Tokens.Space.s2)
    }

    // MARK: 3. 결과 + 유사 모의고사 생성

    #if DEBUG
    /// 어느 모델로 돌릴지 임시로 고르는 곳 (디버그 전용).
    ///
    /// 같은 사진을 체급별로 돌려 보고 결과를 비교하려고 둔다 — 오답이 모델 탓인지
    /// 프롬프트 탓인지 가르는 가장 빠른 방법이다. 파일이 없는 체급은 고를 수 있게
    /// 두되 "없음" 을 표시한다(고르면 다운로드가 시작된다).
    private var debugModelPicker: some View {
        DebugLocalModelSelector(selection: $debugTier, openModelLabel: openModelLabel)
    }

    /// 지금 엔진이 쥐고 있는 모델 (또는 그 상태)
    private var openModelLabel: String {
        switch tutor.modelState {
        case .ready(let file):
            // 파일 존재가 아니라 **실제로 켜지는지**를 본다.
            // 전자만 보던 시절엔 "· 비전" 이라 적어 놓고 로드는 mmproj 없음으로 실패했다.
            let vision = ModelDownloader.visionWillLoad(file: file)
            // 자리가 없어 **비전만 접은** 경우는 그 사실을 그대로 적는다.
            // 예전엔 여기서 그냥 "비전없음" 이라 적어 놓아, 사진을 넣고 한참
            // 기다린 끝에야 이상하다는 걸 알아챘다. 이유까지 적어 준다.
            if let why = UserDefaults.standard.string(forKey: "matths.visionSkipReason"), !why.isEmpty {
                return "열림: \(file), 비전 꺼짐(\(why)). VL 3B 판독 모델로 바꾸면 사진 분석이 된다"
            }
            return "열림: \(file)\(vision ? ", 비전" : ", 비전없음")"
        case .loading:  return "여는 중…"
        case .missing:  return "안 열림"
        case .failed(let m): return "실패: \(m)"
        }
    }

    #endif

    private var reportView: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            #if DEBUG
            if !RuntimeMode.isReviewCapture,
               let review = store.latestCheatingReview(source: .sheetPhoto) {
                CheatingReviewDebugCard(record: review)
            }
            #endif

            // 설명 — 채점표보다 **먼저** 온다. 학생이 알고 싶은 건 점수가 아니라
            // "그래서 뭘 몰랐나" 다. 수식·개념을 한눈에 펼쳐 보여 준다.
            if let js = grader.explainJSON, !js.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Button {
                        withAnimation(store.anim(.easeOut(duration: 0.2), reduceMotion)) { showExplain.toggle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("설명 보기, 뭘 몰랐는지부터")
                                .font(.mBodyB)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.mMicro)
                                .rotationEffect(.degrees(showExplain ? 180 : 0))
                        }
                        .foregroundStyle(Tokens.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showExplain {
                        SheetExplainView(json: js, height: $explainHeight)
                            .frame(height: explainHeight)
                            .id("explain-\(js.hashValue)")
                    }
                }
                .entrance(0)
            }

            // 문항별 분석 — 행을 누르면 "어디까지 잘했고 어디서 막혔는지" 가 펼쳐진다
            ForEach(Array(shownPages.enumerated()), id: \.offset) { _, page in
                VStack(alignment: .leading, spacing: 0) {
                    SectionRule(title: page.title)
                        .padding(.bottom, Tokens.Space.s2)
                    ForEach(Array(page.items.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { DottedRule() }
                        AnalysisRow(item: item, isOpen: expanded.contains(item.no)) {
                            withAnimation(store.anim(.easeOut(duration: 0.18), reduceMotion)) {
                                if expanded.contains(item.no) { expanded.remove(item.no) }
                                else { expanded.insert(item.no) }
                            }
                        }
                    }
                }
                .card()
            }

            // 틀린 유형 → 즉석 유사 모의고사
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                Text("약한 유형").font(.mCaption).foregroundStyle(Tokens.text3)

                // 가로 iPhone 에서는 읽는 쪽(유형·설명)과 누르는 쪽(출제·재촬영)을
                // 좌우로 나눈다. 결과 화면은 위쪽 문항 분석만으로도 이미 길어서,
                // 이 카드까지 세로로 쌓으면 다음 행동 버튼이 스크롤 끝에 숨는다.
                CompactHeightColumns(spacing: Tokens.Space.s5, stackedSpacing: Tokens.Space.s4) {
                    weakTypeSummary
                } trailing: {
                    weakTypeActions
                }
            }
            .card()
        }
    }

    /// 무엇이 약한지 — 읽는 쪽.
    @ViewBuilder private var weakTypeSummary: some View {
        // 유형이 하나도 안 잡히는 건 고장이 아니라 **정상 도달 상태**다 —
        // S4·S5 프롬프트가 type_key: null 을 명시적으로 허용하므로
        // (SheetGrader 의 닫힌 어휘 규약) 결과가 있어도 weakTypes 는 빌 수 있다.
        // 그때 빈 배열로 출제하면 ExamFactory.make 의 types[i % types.count] 가
        // 0 나머지 연산으로 죽는다. 없는 것을 있는 척하지 말고 버튼을 내린다.
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            if wrongTypes.isEmpty {
                Text("이번 분석에서는 다시 낼 만한 유형이 잡히지 않았습니다. "
                     + "문항별 분석은 위에서 볼 수 있고, 사진을 더 또렷하게 다시 찍으면 유형까지 잡힐 수 있습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: Tokens.Space.s2) {
                    ForEach(wrongTypes, id: \.rawValue) { t in
                        Text(t.name).font(.mCaption)
                            .foregroundStyle(Tokens.primary)
                            .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 6)
                            .background(Tokens.primarySoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    }
                }

                Text("이 유형만으로 새 모의고사를 만듭니다. 수치와 정답은 회차마다 다시 뽑히므로 "
                     + "같은 문제를 외워서 넘어갈 수 없습니다. 생성은 기기 안에서 끝납니다 (AI와 서버 불필요).")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 그래서 무엇을 하나 — 누르는 쪽.
    @ViewBuilder private var weakTypeActions: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            if !wrongTypes.isEmpty {
                Button("약한 유형 모의고사 시작 (\(wrongTypes.count)유형, 4문항)") {
                    store.startExam(types: wrongTypes, count: 4)
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            Button("다시 찍기") {
                stage = .idle
                stepsDone = 0
                cheatingReviewQueued = false
            }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    private func queueCheatingReviewIfNeeded(context: CheatingProblemContext?) {
        guard !cheatingReviewQueued,
              analysisOwnerSlot == DataScope.slot,
              let path = shotPath else { return }
        cheatingReviewQueued = true
        let fallback = CheatingProblemContext(
            statement: "업로드한 수학 시험지 전체",
            expectedAnswer: "",
            referenceSteps: [],
            studentFinalAnswer: nil,
            requiresWork: true)
        store.enqueueSheetCheatingReview(imagePath: path, context: context ?? fallback)
    }

    private func recoverPendingAnalysisIfNeeded() {
        guard stage == .idle, shotPath == nil,
              let pending = LocalAIJobRecovery.restore(),
              let image = UIImage(contentsOfFile: pending.imagePath) else { return }
        analysisOwnerSlot = DataScope.slot
        analysisRecoveryDirectory = DataScope.url(LocalAIJobRecovery.directoryName)
        shotPath = pending.imagePath
        shotImage = image
        recoveryText = "이 기기에서 '\(pending.job.stageLabel)' 단계에 중단된 분석을 찾았습니다. 분석 버튼을 누르면 처음부터 안전하게 다시 시작합니다."
    }

    private func discardSourcePhoto(clearRecovery: Bool = true) {
        if let path = shotPath {
            if let directory = analysisRecoveryDirectory {
                if !LocalAIJobRecovery.owns(path: path, in: directory) {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
                }
            } else {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }
        }
        if clearRecovery, let directory = analysisRecoveryDirectory {
            LocalAIJobRecovery.clear(in: directory)
        }
        shotPath = nil
        shotImage = nil
        analysisOwnerSlot = nil
        analysisRecoveryDirectory = nil
    }

    private func assertAnalysisOwnership(
        _ ownerSlot: String,
        preparationID: UUID? = nil
    ) throws {
        try Task.checkCancellation()
        guard DataScope.slot == ownerSlot,
              analysisOwnerSlot == ownerSlot,
              preparationID.map({ analysisPreparationID == $0 }) ?? true else {
            throw CancellationError()
        }
    }

    private func cancelAnalysisPreparation() {
        analysisPreparationTask?.cancel()
        analysisPreparationTask = nil
        analysisPreparationID = nil
    }

    private func clearAnalysisPreparation(ifOwnedBy preparationID: UUID) {
        guard analysisPreparationID == preparationID else { return }
        analysisPreparationTask = nil
        analysisPreparationID = nil
    }

    // MARK: 문항 분석 행 — 접힘: 번호·주제·판정 / 펼침: 잘한 것 → 막힌 곳 → 교정

    private struct AnalysisRow: View {
        let item: ProblemAnalysisItem
        let isOpen: Bool
        let toggle: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: toggle) {
                    HStack(spacing: Tokens.Space.s4) {
                        Text("\(item.no)").font(.mStat).foregroundStyle(Tokens.text3)
                            .frame(width: 34, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.topic).font(.mBodyB).foregroundStyle(Tokens.ink)
                            // 학생이 쓴 답에는 수식이 그대로 들어온다 — 조판해서 보여 준다
                            MathInline(text: item.studentAnswer, font: .mCaption,
                                       color: Tokens.text3, pixelSize: 13)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: item.status.icon).font(.mMicro)
                            Text(item.status.label).font(.mMicro)
                        }
                        .foregroundStyle(item.status.color)
                        Image(systemName: "chevron.down")
                            .font(.mMicro).foregroundStyle(Tokens.text4)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                    .padding(.vertical, Tokens.Space.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.no)번 \(item.topic), \(item.status.label)")

                if isOpen {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        if !item.didWell.isEmpty {
                            detailBlock("여기까지 잘했다", color: Tokens.successInk) {
                                ForEach(Array(item.didWell.enumerated()), id: \.offset) { _, line in
                                    bullet(line)
                                }
                            }
                        }
                        if let stuck = item.stuckAt {
                            detailBlock("여기서 막혔다", color: Tokens.primary) {
                                MathInline(text: stuck, font: .mCallout,
                                           color: Tokens.text1, pixelSize: 16)
                                if let why = item.errorWhy {
                                    MathInline(text: why, font: .mCaption,
                                               color: Tokens.text3, pixelSize: 13)
                                }
                            }
                        } else if let why = item.errorWhy {
                            detailBlock("참고", color: Tokens.warningInk) {
                                MathInline(text: why, font: .mCaption,
                                           color: Tokens.text2, pixelSize: 13)
                            }
                        }
                        if let fix = item.errorFix {
                            detailBlock("다음에는", color: Tokens.text2) {
                                MathInline(text: fix, font: .mCallout,
                                           color: Tokens.text1, pixelSize: 16)
                            }
                        }
                        // 코치 한마디 — 수위 반영은 결과 화면 CoachEngine 몫,
                        // 여기서는 분석 리포트의 기본 톤으로 보여준다
                        HStack(alignment: .top, spacing: Tokens.Space.s2) {
                            Image(systemName: "flame.fill")
                                .font(.mMicro).foregroundStyle(Tokens.primary)
                                .padding(.top, 3)
                            MathInline(text: item.coachNote, font: .mCallout,
                                       color: Tokens.text2, pixelSize: 16)
                        }
                        .padding(Tokens.Space.s3)
                        .background(Tokens.primarySoft.opacity(0.5),
                                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    }
                    .padding(.leading, 34 + Tokens.Space.s4)
                    .padding(.bottom, Tokens.Space.s4)
                }
            }
        }

        @ViewBuilder
        private func detailBlock(_ title: String, color: Color,
                                 @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(title).font(.mCaption).foregroundStyle(color)
                }
                content()
            }
        }

        private func bullet(_ text: String) -> some View {
            HStack(alignment: .top, spacing: Tokens.Space.s2) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 5))
                    .foregroundStyle(Tokens.text3)
                    .padding(.top, 7)
                    .accessibilityHidden(true)
                MathInline(text: text, font: .mCallout,
                           color: Tokens.text1, pixelSize: 16)
            }
        }
    }

}

private enum LocalAIAnalysisStartError: LocalizedError {
    case visionUnavailable
    case reasoningUnavailable

    var errorDescription: String? {
        switch self {
        case .visionUnavailable:
            return "사진 판독 모델을 열지 못했습니다. 다른 앱을 닫고 다시 시도해 주세요."
        case .reasoningUnavailable:
            return "사진 전사 뒤 수학 추론 모델로 전환하지 못했습니다."
        }
    }
}
