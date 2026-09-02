//  MatthsApp.swift
//  Matths — iPadOS 앱 진입점

import SwiftUI
import UserNotifications
import UIKit

struct StuckPointRecord: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var text: String
    var createdAt: Date

    init(id: String = UUID().uuidString, text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
final class MatthsAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        ResumableModelDownload.shared.acceptBackgroundEvents(
            identifier: identifier,
            completion: completionHandler)
    }
}

/// iOS가 background 진입 직후 앱을 suspend해도 학습 스냅샷의 실제 파일 교체까지
/// 짧게 실행 시간을 확보한다. 식별자를 세대별로 관리해 만료와 정상 완료가 겹쳐도
/// `endBackgroundTask`를 두 번 호출하지 않는다.
@MainActor
private final class LearningPersistenceBackgroundFlush {
    static let shared = LearningPersistenceBackgroundFlush()

    private var generation: UUID?
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var task: Task<Void, Never>?

    func start(store: AppStore) {
        if let generation { finish(generation, cancelling: true) }

        let token = UUID()
        generation = token
        identifier = UIApplication.shared.beginBackgroundTask(
            withName: "Learning persistence flush"
        ) { [weak self] in
            Task { @MainActor in self?.finish(token, cancelling: true) }
        }
        task = Task { @MainActor [weak self, weak store] in
            guard let store else {
                self?.finish(token)
                return
            }
            var succeeded = false
            // 파일 보호/일시 I/O 충돌 한 번은 같은 background assertion 안에서 재시도한다.
            // 영구 오류라면 무한 루프로 suspend를 막지 않고 로그를 남긴다.
            for _ in 0..<2 where !Task.isCancelled {
                let snapshotsPersisted = await store.flushLearningPersistence()
                let eventsPersisted = await EventLog.flushPendingWrites()
                let syncQueuePersisted = await SyncEngine.shared.flushLocalQueuePersistence()
                succeeded = snapshotsPersisted && eventsPersisted && syncQueuePersisted
                if succeeded { break }
            }
            if !succeeded {
                NSLog("LEARNING-PERSISTENCE-ERROR background 저장 실패")
            }
            self?.finish(token)
        }
    }

    private func finish(_ token: UUID, cancelling: Bool = false) {
        guard generation == token else { return }
        if cancelling { task?.cancel() }
        task = nil
        generation = nil
        let activeIdentifier = identifier
        identifier = .invalid
        if activeIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(activeIdentifier)
        }
    }
}

@main
struct MatthsApp: App {
    @UIApplicationDelegateAdaptor(MatthsAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var screenshotGuard = ScreenshotGuard()
    @StateObject private var store = AppStore()

    init() {
        #if !DEBUG
        // 같은 번들 ID의 Debug 데모 위에 TestFlight/App Store 빌드를 설치한 경우
        // 데모 슬롯을 실제 사용자 슬롯으로 되돌린 뒤에만 파일을 읽는다.
        DataScope.restoreReleaseSlotIfNeeded()
        #endif
        #if DEBUG
        // 데모 모드가 꺼져 있는데 지난 실행이 데모 슬롯에서 끝났다면 **레거시 이사보다
        // 먼저** 원래 슬롯으로 되돌린다. 그래야 평평한 옛 파일이 데모 슬롯으로 들어가지 않는다.
        DemoMode.restoreRealSlotBeforeLegacyMigration()
        #endif
        // 저장소가 파일을 읽기 **전에** 옛 평평한 파일을 현재 슬롯으로 옮긴다.
        // (AppStore 의 @Published 들이 init 에서 디스크를 읽으므로 순서가 중요하다)
        DataScope.migrateLegacyIfNeeded()
        #if DEBUG
        // 데모는 전용 슬롯에서 돈다 — 데모 응답이 감독의 실제 진도·오답·캐시 파일에
        // 섞이지 않게 한다. AppStore() 는 @StateObject autoclosure 라 아직 만들어지지 않았다.
        DemoMode.enterDemoSlotAfterLegacyMigration()
        #endif
        // 앱이 열려 있는 동안 도착한 알림도 보이게 한다. 델리게이트가 없으면 iOS 가
        // 앞면 알림을 조용히 버려서, 공부 중에 대기실 열림·방어 마감을 놓친다.
        // (권한을 여기서 묻지는 않는다 — 첫 실행 권한 창은 대부분 거절로 끝난다)
        MatthsNotificationPresenter.install()
        LocalAIBackgroundExecution.cleanupStaleSourcePhotos()
        // 지난 실행이 비전 프로젝터를 여는 도중 죽었으면(ggml_abort 는 못 잡는다)
        // 그 모델의 비전을 끄고 다시 뜬다. 부팅 루프 없이 한 번만 아프고 끝난다.
        if let died = ModelDownloader.recoverFromVisionCrashIfNeeded() {
            AITutor.visionDisabledNotice = died
        }
        #if DEBUG
        // 자가진단 도중 jetsam/강제 종료가 나도 실험 티어가 사용자 설정으로 남지 않는다.
        VisionSelfTest.restoreForcedTierIfNeeded()
        // 실행 인자로 부른 비전 자가진단 — 평소 실행에는 아무 영향이 없다.
        // (사람이 앱을 열고 사진을 고르지 않아도 기기에서 숫자를 잴 수 있어야 한다)
        VisionSelfTest.runIfRequested()
        ScreenProtectionSelfTest.runIfRequested()
        SecureCanvasProbe.runSelfTestIfRequested()
        AccessibilityDeviceSelfTest.runIfRequested()
        ModelDownloadSelfTest.runIfRequested()
        LocalAIRecoverySelfTest.runIfRequested()
        LocalAIBackgroundSelfTest.startIfRequested()
        // 아레나 웹 브리지 디버그 진입점(`-arenaWeb <목적지>` · `-arenaWeb selftest`).
        // 종전에는 이 진입점을 부르려고 ObjC `+load` 짜리 임시 통로(ArenaWebLaunchShim.m)가
        // 따로 있었다 — 앱 진입점 파일을 건드리지 않으려고 만든 것이다. 이제 정식 진입점이
        // 배선됐으므로 그 통로는 지우고, 실행 인자 하나로 목적지를 바로 띄우는 계측 경로만
        // 여기서 잇는다. 인자가 없으면 옵저버조차 걸지 않는다(평소 실행에는 흔적이 없다).
        ArenaWebLaunchHook.install()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            presentationIsolatedRootContent
                // 프로필의 테마 설정 (시스템/라이트/다크)
                .preferredColorScheme(store.themePreference == "light" ? .light
                                      : store.themePreference == "dark" ? .dark : nil)
                .environmentObject(store)
                .environmentObject(screenshotGuard)
                .tint(Tokens.primary)
                // 로그인 전에도 도착하는 비밀번호 재설정·학부모 초대 링크와 공개
                // 법적 문서를 앱이 삼키지 않는다. iPhone 가로에서는 sheet 대신
                // full-screen으로 바뀌어 짧은 높이에서도 폼과 닫기 버튼을 보장한다.
                .compactHeightSheet(item: $store.publicWebDestination) { destination in
                    CommunitySafariView(url: destination.url)
                        .ignoresSafeArea()
                }
                .overlay {
                    RankPromotionPipelinePrewarmView()
                }
                // 승급 장식은 별도 화면 흐름이 아니라 현재 결과 위를 잠깐 덮는 표현
                // 계층이다. 별도 UIKit modal 전환을 만들지 않고 같은 scene의 최상단
                // overlay로 렌더해 전환 비용을 줄이고, 앱 전환 privacy cover도 이
                // 장식 위를 확실히 덮게 한다.
                .overlay {
                    RankPromotionOverlay(
                        tierCode: store.rankPromotionPresentation?.tierCode)
                        .environmentObject(store)
                }
                .overlay {
                    FirstRunOnboardingOverlay()
                        .environmentObject(store)
                }
                .overlay {
                    NativeTutorialOverlay()
                        .environmentObject(store)
                }
                // 공통 보호 레이어는 루트와 fullScreenCover가 같은 구현을 쓴다.
                // 모달은 루트 overlay보다 위에 뜨므로 각 presentation 최상단에도
                // 붙여야 앱 전환 덮개·워터마크·캡처 안내가 경기 화면을 실제로 덮는다.
                .screenProtectionLayer(guardModel: screenshotGuard) { stuckPoint in
                    store.recordStuckPoint(stuckPoint)
                }
                // 홈 화면 위젯이 앱을 연다(matths://concept/<id> · review · home · arena).
                //
                // 아레나 웹 브리지 딥링크(matths://arena-web/<목적지>, 그리고 서버가 보낸
                // https://<서버>/goat-arena/… 주소)를 **먼저** 태운다. 우편함 알림의 링크를
                // Safari 로 새로 열면 앱 로그인과 웹 세션이 갈리는데, 브리지로 받으면 같은
                // 계정으로 앱 안에서 이어 볼 수 있다. 아레나 주소가 아니면 handle 이 false 를
                // 돌려주므로 종전 위젯 처리가 그대로 이어진다(host 가 arena-web 하나뿐이라
                // 위젯의 matths://arena 는 건드리지 않는다).
                .onOpenURL { url in
                    if ArenaWebDeepLink.handle(
                        url,
                        guardModel: screenshotGuard,
                        // 로그인 유도는 넘기지 않는다. 앱에 로그인이 없으면 브리지가
                        // "로그인이 필요합니다" 카드로 막고, 로그인 동선은 홈 배너가 갖는다 —
                        // 여기서 별도 인증 경로를 새로 만들면 두 벌이 된다.
                        onRequestSignIn: nil
                    ) {
                        return
                    }
                    // 공개 링크는 인증 포털보다 먼저 판정한다. `/parent/invite/*`는
                    // 학생 앱 세션이 아니라 별도 학부모 세션을 소유하고, 비밀번호
                    // 재설정 링크의 query token도 원문 그대로 서버에 도착해야 한다.
                    if let destination = PublicServerWebDestination.fromDeepLink(url) {
                        store.openPublicWeb(destination)
                        return
                    }
                    if let destination = HostedPortalDestination.fromDeepLink(url) {
                        store.openHostedPortal(destination)
                        return
                    }
                    if HostedPortalDestination.isTrustedServerURL(url) {
                        let href = url.query.map { "\(url.path)?\($0)" } ?? url.path
                        if let conceptID = NotificationInboxScreen.conceptID(for: href) {
                            store.openConceptV2(conceptID)
                            return
                        }
                        if let route = NotificationInboxScreen.nativeRoute(for: href) {
                            store.route = route
                            return
                        }
                    }
                    WidgetBridge.handle(url, store: store)
                }
                .onChange(of: scenePhase) { _, phase in
                    screenshotGuard.setSceneActive(phase == .active)
                    // 위젯은 앱이 마지막으로 적어 둔 스냅샷만 본다 — 앞뒤로 오갈 때 갱신한다.
                    if phase == .background || phase == .active { WidgetBridge.publish(from: store) }
                    if phase == .background {
                        // 150ms debounce 창에 남은 학습·오답·평가 draft를 즉시 writer로
                        // 보내고 파일 교체가 끝날 때까지 background 실행 시간을 잡는다.
                        LearningPersistenceBackgroundFlush.shared.start(store: store)
                        LocalAIBackgroundExecution.shared.didEnterBackground()
                        #if DEBUG
                        LocalAIBackgroundSelfTest.recordBackgroundIfRequested()
                        #endif
                    } else if phase == .active {
                        LocalAIBackgroundExecution.shared.didBecomeActive()
                        GoatArenaClientReviewOutbox.recoverCompleted(store.cheatingReviews)
                        // 알림함은 앱을 열 때마다 맞춘다. 경고·계정 안내는 늦게 보면
                        // 늦게 본 만큼 손해가 나므로 화면에 들어가야 갱신되면 안 된다.
                        NotificationInboxStore.shared.refresh()
                        Task {
                            await store.refreshNotificationAuthorization()
                            await store.refreshServerProfile()
                            await GoatArenaClientReviewOutbox.flush()
                        }
                    }
                }
                .task {
                    // 앱을 강제 종료해도 시스템은 Live Activity 배너를 지우지 않는다.
                    // 회수하지 않으면 지난 세션이 잠금화면에 "학습 중" 으로 계속 떠 있다.
                    //
                    // adoptOnLaunch 는 손잡이를 되찾고 **날짜가 바뀌었거나 6시간 넘은**
                    // 배너만 끝낸다. 그것만으로는 부족하다: 콜드 런치에는 **진행 중인
                    // 세트가 있을 수 없다.** exam 은 디스크에 남지 않아서 앱이 새로 뜨면
                    // 항상 비어 있다. 그러니 살아남은 배너는 시작 시각과 무관하게 전부
                    // 지난 실행의 잔재다 — 되찾고 곧바로 끝낸다.
                    // (실측: 시험 중 강제 종료 후 재실행하면 홈 화면인데 다이나믹
                    //  아일랜드는 "문제 풀이 1:11" 로 계속 돌고 있었다.)
                    LiveActivityController.adoptOnLaunch()

                    // 인앱 결제 리스너. **상점 화면이 아니라 여기서** 띄운다 —
                    // 구입 요청(Ask to Buy) 승인은 학생이 앱을 다시 켤 때 도착하는데,
                    // 그때 상점으로 들어가리라는 보장이 없다. 우리 사용자층이
                    // 고등학생이라 이 경로가 예외가 아니라 일상이다.
                    MatthsIAPStore.shared.start()
                    LiveActivityController.end()
                    // 앱을 다시 연 직후에도 이전 실행의 완료 결과를 복구·전송한다.
                    // scenePhase가 이미 active면 onChange가 호출되지 않을 수 있다.
                    NotificationInboxStore.shared.refresh()
                    GoatArenaClientReviewOutbox.recoverCompleted(store.cheatingReviews)
                    await store.refreshServerProfile()
                    await GoatArenaClientReviewOutbox.flush()
                }
                // 보호 범위는 "문제 푸는 동안"이다. 레이아웃 모드(isSessionMode)가
                // 아니라 보호 전용 판정(isProblemSolvingRoute)을 쓴다 — 빠른 연습을
                // 포함시키면서 RootView 의 화면 분기는 건드리지 않기 위해서다.
                .onChange(of: store.isProblemSolvingRoute, initial: true) { _, protected in
                    screenshotGuard.setBaseProtection(protected)
                }
                .task {
                    // 첫 보호 화면에서 렌더가 밀리지 않게 실행 직후 한 번만 계측한다.
                    // 결과는 OS 버전 + 앱 빌드 키로 캐싱되므로 화면 진입마다 돌지 않는다.
                    SecureCanvasProbe.warmUp()
                }
                // ▼▼▼ 전역 디버그 바 — 이 묶음 하나만 주석 처리하면 통째로 사라진다 ▼▼▼
                // (주의: 오버레이는 체인 위쪽에 있어 .environmentObject 가 흐르지 않는다.
                //  명시 주입 없이는 EnvironmentObject.error() 로 즉사한다 — 실제로 한 번 죽었다.)
                #if DEBUG
                .overlay(alignment: .bottomTrailing) {
                    DebugBar().environmentObject(store)
                }
                .task {
                    await RankPromotionPerformanceSelfTest.runIfRequested(store: store)
                }
                #endif
                // ▲▲▲ 전역 디버그 바 끝 ▲▲▲
        }
    }

    /// `.accessibilityHidden(false)`를 루트에 상시 부착하면 iOS 26 SwiftUI에서
    /// 일부 전체 화면 구성의 자식 접근성 트리가 통째로 사라진다. 숨길 발표가 있을
    /// 때만 modifier 자체를 만들고, 평소에는 손대지 않은 루트를 반환한다.
    /// 튜토리얼·승급 중에는 반대로 배경 홈/탭을 조작할 수 없게 본문만 숨긴다.
    @ViewBuilder private var presentationIsolatedRootContent: some View {
        if store.isTutorialPresentationActive || store.rankPromotionPresentation != nil {
            rootContent.accessibilityHidden(true)
        } else {
            rootContent
        }
    }

    @State private var splashDone = false

    /// 평소에는 스플래시 → RootView. DEBUG 에서 `-harness 320x1000-compact` 를 주면 폭 하네스.
    @ViewBuilder private var rootContent: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-windowEnvironmentSelfTest") {
            WindowEnvironmentSelfTestView()
        } else if ProcessInfo.processInfo.arguments.contains("-authCapture") {
            AuthScreen()
        } else if let harness = MatthsApp.harnessFromArguments() {
            harness
        } else {
            splashThenRoot
        }
        #else
        splashThenRoot
        #endif
    }

    /// 스플래시는 실제 초기화와 연동할 비동기 신호가 없다(AppStore 부트는 init 의
    /// 동기 디스크 읽기로 끝난다). 그래서 SplashView 가 총 0.8초 상한을 스스로 지키고,
    /// 동작 줄이기/모션 꺼짐은 0.25초 크로스페이드로 즉시 걷힌다 (1754).
    @ViewBuilder private var splashThenRoot: some View {
        ZStack {
            // 로그인 전에는 인증 화면. DEBUG 자동화 인자(-route/-exam)는 게스트로 통과.
            if store.authProvider == nil {
                AuthScreen()
            } else {
                RootView()
            }
            if !splashDone && !MatthsApp.skipSplash {
                SplashView { splashDone = true }
            }
        }
    }

    /// 스크린샷용 `-route` 직행 실행에서는 스플래시가 방해가 되므로 건너뛴다.
    private static var skipSplash: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-route")
        #else
        false
        #endif
    }

    #if DEBUG
    private static func harnessFromArguments() -> SizeHarness? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-harness"), i + 1 < args.count else { return nil }
        return SizeHarness.parse(args[i + 1])
    }
    #endif
}

/// 앱 전역 상태의 단일 소유자 — 계정 슬롯(DataScope)·실계정 세션·학습 세션·진도·
/// 오답노트·동기화 콜백(SyncEngine)을 지휘한다. 폐기 가능한 목업이 아니다:
/// 여기의 순서·게이트 하나가 학생 기록의 보존/유실을 가른다 (init·signInServer 주석 참조).
@MainActor
final class AppStore: ObservableObject {
    private var authenticationExpiredObserver: NSObjectProtocol?

    // MARK: 일반 학습 스냅샷 writer

    /// AppStore 호출 순서와 actor 우편함 도착 순서는 같다는 보장이 없다. 메인 액터에서
    /// 단조 revision을 먼저 붙여 오래된 debounce가 최신 상태를 덮지 못하게 한다.
    private var learningPersistenceRevision: UInt64 = 0
    /// flush 명령끼리 올리는 revision과 실제 메모리 mutation을 구분한다. 동시 flush가
    /// 서로를 새 변경으로 오인해 무한 재캡처하지 않도록 안정성 판정은 이 세대만 본다.
    private var learningPersistenceMutationGeneration: UInt64 = 0
    /// 탈퇴 장벽을 기다리는 동안 main actor가 재진입해 background flush나 sync 콜백을
    /// 처리해도, 삭제 예정 슬롯의 **새 revision 자체를 만들지 않게** 막는 로컬 게이트.
    private var disabledLearningPersistenceSlots: Set<String> = []
    /// 일반 계정 전환의 flush가 await되는 동안에도 main actor는 재진입한다. 장시간
    /// 평가 작업의 후속 side effect는 막고, 동기 mutation 저장은 stable-flush가 다시 캡처한다.
    private var transitioningLearningPersistenceSlots: [String: UUID] = [:]
    @Published private(set) var progressResetInFlight = false
    /// 계정 전환도 await 중 main actor 재진입이 가능하다. 가장 나중에 시작한 전환만
    /// 실제 DataScope를 바꾸게 해, 로그인과 로그아웃이 엇갈려 옛 요청이 이기지 못한다.
    private var accountTransitionGeneration = UUID()
    /// 시도 세대와 달리 성공한 세션 경계에서만 바뀐다. 탈퇴 요청이 기다리는 동안
    /// 실패한 전환 시도 하나가 들어왔다고 실제 owner 세션을 잃은 것으로 보지 않는다.
    private var accountSessionGeneration = UUID()

    private func nextLearningPersistenceRevision() -> UInt64 {
        learningPersistenceRevision &+= 1
        return learningPersistenceRevision
    }

    private func markLearningPersistenceMutation() {
        learningPersistenceMutationGeneration &+= 1
    }

    private func isLearningAccountOperationActive(for slot: String) -> Bool {
        slot == DataScope.slot
            && !disabledLearningPersistenceSlots.contains(slot)
            && transitioningLearningPersistenceSlots[slot] == nil
            && !assessmentPersistenceTransactionInFlight
    }

    private func isLearningSlotWritable(for slot: String) -> Bool {
        slot == DataScope.slot && !disabledLearningPersistenceSlots.contains(slot)
    }

    private func isSyncAccountOwnerActive(_ owner: SyncAccountOwner) -> Bool {
        owner.slot == DataScope.slot
            && owner.sessionGeneration == accountSessionGeneration
            && !disabledLearningPersistenceSlots.contains(owner.slot)
            && !assessmentPersistenceTransactionInFlight
    }

    private func scheduleLearningPersistence(_ snapshot: LearningPersistenceSnapshot) {
        let slot = DataScope.slot
        guard !disabledLearningPersistenceSlots.contains(slot) else { return }
        markLearningPersistenceMutation()
        let key = LearningPersistence.key(for: snapshot, slot: slot)
        let revision = nextLearningPersistenceRevision()
        Task {
            await LearningPersistence.writer.schedule(snapshot, for: key, revision: revision)
        }
    }

    /// debounce 없이 actor에 넘기되 호출부를 막지 않는 경계. 시험 시작·계정 승계처럼
    /// 화면은 곧바로 진행해도 되지만 일반 150ms 창에는 두지 않을 때 사용한다.
    private func requestImmediateLearningPersistence(_ snapshot: LearningPersistenceSnapshot) {
        let slot = DataScope.slot
        guard !disabledLearningPersistenceSlots.contains(slot) else { return }
        markLearningPersistenceMutation()
        let key = LearningPersistence.key(for: snapshot, slot: slot)
        let revision = nextLearningPersistenceRevision()
        Task {
            _ = await LearningPersistence.writer.writeImmediately(
                snapshot, for: key, revision: revision)
        }
    }

    /// 제출·파괴적 초기화처럼 디스크 쓰기 완료가 성공 경계의 일부인 작업용.
    @discardableResult
    private func persistLearningImmediately(
        _ snapshot: LearningPersistenceSnapshot,
        for ownerSlot: String? = nil
    ) async -> Bool {
        let slot = ownerSlot ?? DataScope.slot
        guard !disabledLearningPersistenceSlots.contains(slot) else { return false }
        markLearningPersistenceMutation()
        let key = LearningPersistence.key(for: snapshot, slot: slot)
        let revision = nextLearningPersistenceRevision()
        let outcome = await LearningPersistence.writer.writeImmediately(
            snapshot, for: key, revision: revision)
        return outcome == .written
    }

    /// background·계정 전환 직전에 메모리의 최신값을 새 revision으로 즉시 제출한다.
    /// 앞 schedule Task가 아직 actor에 도착하지 않았어도 이 revision보다 오래돼 폐기된다.
    @discardableResult
    func flushLearningPersistence() async -> Bool {
        let slot = DataScope.slot
        guard !disabledLearningPersistenceSlots.contains(slot) else { return false }

        // 로컬 평가 제출은 wrongNotes → assessments 두 파일을 순서대로 확정한다.
        // 그 사이 background/account flush가 아직 공개하지 않은 옛 메모리를 더 높은
        // revision으로 쓰면 제출 결과를 되감으므로, 짧은 로컬 트랜잭션만 끝까지 기다린다.
        while assessmentPersistenceTransactionInFlight {
            guard !Task.isCancelled,
                  DataScope.slot == slot,
                  !disabledLearningPersistenceSlots.contains(slot) else { return false }
            try? await Task.sleep(for: .milliseconds(5))
        }

        while !Task.isCancelled {
            // await 중 탈퇴 invalidate가 source를 닫았으면 cutoff보다 큰 revision을 새로
            // 발급하지 않는다. purge 이후 삭제한 디렉터리를 되살리는 최종 방어선이다.
            guard !disabledLearningPersistenceSlots.contains(slot) else { return false }
            // 값·owner slot·revision을 첫 await 전에 한 번에 붙잡는다. actor 내부의 batch
            // 메서드가 네 파일을 한 우편함 명령으로 처리하므로 다른 flush와 반쯤 섞이지 않는다.
            let snapshots: [LearningPersistenceSnapshot] = [
                .progress(progressV2.byConcept),
                .wrongNotes(wrongNotes),
                .assessments(attemptsV2.attempts),
                .stuckPoints(stuckPoints),
            ]
            let writes = snapshots.map { snapshot in
                (
                    key: LearningPersistence.key(for: snapshot, slot: slot),
                    payload: snapshot,
                    revision: nextLearningPersistenceRevision()
                )
            }
            let capturedMutationGeneration = learningPersistenceMutationGeneration
            let outcomes = await LearningPersistence.writer.writeImmediately(writes)
            guard outcomes.count == writes.count else { return false }
            // superseded는 저장 실패가 아니다. 더 높은 revision이 actor에 먼저 도착한
            // 정상 경합이므로 아래에서 최신 메모리를 새 revision으로 다시 캡처한다.
            // 실제 sink 실패만 계정 전환/background 장벽의 실패로 돌려보낸다.
            if outcomes.values.contains(.ioFailed) { return false }
            // 다른 전환이 이미 슬롯을 바꿨다면 old-slot batch는 완결됐다. 새 메모리를
            // old URL로 다시 캡처하지 않는다.
            guard DataScope.slot == slot else { return true }
            // invalidate cutoff도 낮은 revision에 `.superseded`를 돌려준다. 탈퇴 장벽이
            // 닫힌 슬롯에서 이를 정상 경합으로 보고 재캡처하면 purge 뒤 파일이 부활한다.
            guard !disabledLearningPersistenceSlots.contains(slot) else { return false }
            if outcomes.values.contains(.superseded) { continue }
            // await 중 mutation이 save를 호출하면 메인 액터에서 mutation 세대가 먼저 증가한다.
            // 안정될 때까지 다시 캡처해 background suspend와 계정 전환 모두 S0가 아닌
            // 마지막 S_n을 실제 파일에 쓴 뒤 반환한다.
            if learningPersistenceMutationGeneration == capturedMutationGeneration { return true }
        }
        return false
    }

    /// 서버 탈퇴 2xx 뒤 로컬 슬롯을 지우기 전 cancel-and-drain 장벽.
    /// 이 메서드가 반환한 뒤에는 cutoff 이전 작업이 해당 디렉터리를 되살릴 수 없다.
    func invalidateLearningPersistence(for slot: String) async {
        // await 전에 닫는다. actor 장벽을 기다리는 동안 scenePhase/sync 콜백이
        // 재진입하더라도 cutoff보다 큰 새 명령을 만들 수 없어야 한다.
        disabledLearningPersistenceSlots.insert(slot)
        let cutoff = nextLearningPersistenceRevision()
        // snapshot 외의 append-only writer도 같은 owner 슬롯을 먼저 tombstone한다.
        // 탈퇴 응답을 기다리는 동안 다른 계정으로 전환됐을 수 있으므로 current slot을
        // 다시 읽지 않고 캡처한 withdrawn slot URL만 닫는다.
        await SyncEngine.shared.invalidateLocalQueuePersistence(for: slot)
        await EventLog.invalidatePendingWrites(for: slot)
        await LearningPersistence.writer.invalidate(
            LearningPersistence.keys(for: slot), through: cutoff)
    }

    @Published var route: Route = .home {
        // 전환 방향 — 탭 순서에서 앞으로 가면 +1(오른쪽에서 진입), 뒤로 가면 -1.
        // didSet 은 뷰 갱신 전에 돌므로 트랜지션이 항상 올바른 방향을 읽는다.
        didSet {
            navDirection = route.navOrder >= oldValue.navOrder ? 1 : -1
            // 이용권·상점은 이제 홈·프로필·Arena 세 곳에서 들어온다. 어디서 왔는지
            // 기억해 두지 않으면 나갈 때 항상 한 곳으로 뱉어내고, 하단 탭도 엉뚱한
            // 자리에 불이 켜진다(홈에서 들어갔는데 GOAT Arena 가 켜지던 문제).
            if route == .commerce, oldValue != .commerce { commerceOrigin = oldValue }
            if route == .services, oldValue != .services, oldValue != .academy,
               oldValue != .hostedPortal {
                serviceOrigin = oldValue
            }
        }
    }

    /// 이용권·상점 화면에 들어오기 직전의 화면. 나갈 곳과 하단 탭 표시를 여기에 맞춘다.
    private(set) var commerceOrigin: Route = .profile

    /// 학원·서비스 허브에 들어오기 직전 화면. 홈과 프로필 어느 쪽에서 열어도 닫을 때
    /// 사용자가 있던 문맥으로 돌아간다.
    private(set) var serviceOrigin: Route = .home

    /// 앱 로그인 세션을 이어 열 현재 웹 포털 목적지.
    @Published var hostedPortalDestination = HostedPortalDestination.studentAcademy

    /// `/store/content/:id` 유니버설 링크를 네이티브 수험관 상세까지 보존한다.
    /// 목록 진입이면 nil이고, 화면이 한 번 소비한 뒤 다시 nil로 돌린다.
    @Published var requestedStudyHallContentID: String?

    /// `/store/products/:slug` 링크가 가리킨 공개 자료를 네이티브 상세에서 바로 연다.
    @Published var requestedStoreProductSlug: String?

    /// `/faq?code=409`처럼 오류 화면에서 넘어온 링크가 해당 답변을 곧바로 연다.
    @Published var requestedFAQCode: String?

    /// 인증 화면 위에서도 열 수 있는 공개 서버 링크. resetId/token을 문자열로
    /// 재조립하지 않고 URL 자체로 보관해 메일 링크의 query 인코딩을 보존한다.
    @Published var publicWebDestination: PublicServerWebDestination?

    func openHostedPortal(_ destination: HostedPortalDestination) {
        // 보호자 계정은 학생·교사 Bearer 세션과 완전히 별도다. 학생 토큰을 웹 세션으로
        // 교환한 뒤 보호자 로그인을 띄우면 두 계정 문맥이 한 WKWebView에 섞이므로,
        // 보호자 경로는 SFSafariViewController에서 독립 로그인으로 시작한다.
        if let parentDestination = PublicServerWebDestination.parentPortal(path: destination.path) {
            openPublicWeb(parentDestination)
            return
        }
        // 학생은 수업·출석, 교사는 승인·반 배정·초대를 네이티브에서 먼저 처리한다.
        // 운영자와 각 네이티브 화면의 명시적인 "전체 관리"만 웹 세션 셸을 사용한다.
        let role = serverProfile?.role?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "student"
        if (destination == .studentAcademy && !["teacher", "admin"].contains(role))
            || (destination == .teacherAcademy && role == "teacher")
            || (destination == .admin && role == "admin") {
            route = .academy
            return
        }
        if destination.path == "/coach-suggestions"
            || destination.path.hasPrefix("/coach-suggestions?")
            || destination.path.hasPrefix("/coach-suggestions/") {
            route = .coachSuggestions
            return
        }
        if destination.path == "/contact"
            || destination.path.hasPrefix("/contact?")
            || destination.path.hasPrefix("/contact/") {
            route = .support
            return
        }
        if destination.path == "/faq"
            || destination.path.hasPrefix("/faq?")
            || destination.path.hasPrefix("/faq/") {
            let components = URLComponents(
                string: "https://www.matths.kr\(destination.path)")
            requestedFAQCode = components?.queryItems?
                .first(where: { $0.name.lowercased() == "code" })?.value
            route = .faq
            return
        }
        if destination.path == "/archive"
            || destination.path.hasPrefix("/archive?")
            || destination.path.hasPrefix("/archive/") {
            route = .archive
            return
        }
        if destination.path == "/store"
            || destination.path.hasPrefix("/store?")
            || destination.path.hasPrefix("/store/") {
            let pathOnly = destination.path.split(separator: "?", maxSplits: 1)
                .first.map(String.init) ?? destination.path
            let parts = pathOnly.split(separator: "/").map(String.init)
            if parts.count >= 3, parts[0] == "store", parts[1] == "content" {
                requestedStudyHallContentID = parts[2]
                requestedStoreProductSlug = nil
                route = .studyHall
                return
            }
            if parts.count >= 3, parts[0] == "store", parts[1] == "products" {
                requestedStoreProductSlug = parts[2]
                requestedStudyHallContentID = nil
                route = .storeCatalog
                return
            }
            requestedStudyHallContentID = nil
            requestedStoreProductSlug = nil
            route = .studyHall
            return
        }
        hostedPortalDestination = destination
        route = .hostedPortal
    }

    func openPublicWeb(_ destination: PublicServerWebDestination) {
        publicWebDestination = destination
    }

    /// 홈에서 "바로 한 문항" 으로 들어왔다는 표시. 퀵 연습 화면이 뜨자마자
    /// 문항을 받아 온다. 급식 줄에서 두 번 누를 시간이 없기 때문이다.
    /// 화면이 한 번 읽고 지우므로, 탭으로 들어온 평소 진입은 영향받지 않는다.
    @Published var quickPracticeAutoStart = false
    /// 프로필에서 사용자가 직접 상세 대시보드 투어를 다시 열었다는 의도.
    /// 첫 로그인 자동 온보딩과 31단계 상세 투어를 같은 서버 PENDING 상태만으로
    /// 구분할 수 없으므로, 명시적인 재시작 동작만 이 플래그를 세운다.
    @Published var requestedDashboardTutorial = false
    /// 프로필에서 사용자가 직접 고른 Arena 튜토리얼 편.
    /// 서버는 편별 PENDING 상태만 주고 `autoChapter`를 고르지 않으므로,
    /// 프로필 버튼의 사용자 의도를 화면 전환까지 잠시 보존한다.
    @Published var requestedArenaTutorialChapter: String? = nil
    /// 네이티브 튜토리얼이 화면을 덮고 있는 동안의 일시 상태.
    /// 서버에서 실제 마감이 내려오더라도 온보딩 한가운데 시스템 권한창을 띄우지
    /// 않기 위해 알림 예약기가 읽는다. 이미 허용된 알림 예약은 계속 동작한다.
    @Published var isTutorialPresentationActive = false
    /// 마지막 라우트 전환의 방향 (±1). route 가 이미 @Published 라 별도 publish 불필요.
    var navDirection: CGFloat = 1
    @Published var lastGrading: GradingResult?

    // MARK: 온디바이스 풀이 무결성 검토

    /// 계정 슬롯 안의 관리자/개발자 검토 자료. 채점·랭킹·정산에는 사용하지 않는다.
    @Published private(set) var cheatingReviews: [CheatingReviewRecord] =
        CheatingReviewDisk.loadRecoveringInterrupted()
    private var cheatingReviewFlags: [UUID: CheatingDetectionCancelFlag] = [:]
    private var cheatingReviewTasks: [UUID: Task<Void, Never>] = [:]
    /// LlamaEngine 내부 호출은 직렬이지만 모델 전환까지 하나의 작업으로 묶어야 한다.
    /// 풀이를 연달아 제출해도 VLM unload/load가 서로 끼어들지 않게 검토 전체를 한 줄로 세운다.
    private var cheatingReviewQueueTail: Task<Void, Never>?

    // MARK: 오답노트 — 실데이터 (WrongNoteStore.swift)

    @Published var wrongNotes: [WrongNoteEntry] = WrongNoteDisk.load() {
        // 복습 예정일이 바뀌면 예약된 알림도 같이 바뀌어야 한다 —
        // 프로필이 약속한 "복습 예정 문항이 있는 날 저녁" 의 진실원은 이 목록이다.
        didSet { if reviewReminderOn { ReviewReminder.reschedule(wrongNotes) } }
    }

    /// 오늘 복습해야 하는 오답 수 — 하드코딩이 아니라 실제 목록에서 센다
    var dueReviewCount: Int { wrongNotes.filter(\.isDue).count }

    /// 복습 모드일 때, exam 인덱스 → 오답노트 항목 id
    var reviewingNoteIDs: [String]?

    /// 복습 세트를 잠시 접어 두는 자리 — "같은 유형 새 수치" 확인 문항 1개를 푸는 동안
    /// 보관했다가, 끝나면 그대로 펴서 이어 푼다. 이게 없으면 확인 문항이 startExam 을
    /// 타면서 진행 중이던 복습 큐를 통째로 파기했다 (2026-07-29 감사 적발).
    private struct PendingReview {
        let exam: [GeneratedProblem]
        let index: Int
        let noteIDs: [String]
        let results: [Bool]
        let startedAt: Date?
        let seed: UInt64
    }
    private var pendingReview: PendingReview?

    /// 지금 푸는 것이 "기록 없는 확인 문항" 인지.
    /// 참이면 통계·학습 이벤트·오답노트·최고 기록 어디에도 흔적을 남기지 않는다.
    private(set) var isVariationCheck = false

    // MARK: 학습일 — 연속 학습·주간 활동 (실데이터)

    @Published var activityDays: Set<String> = ActivityLog.load()
    /// 연속 학습 일수.
    ///
    /// **서버 계정이면 서버 값이 진실원이다.** 앱이 로컬 날짜 집합에서 따로 세면
    /// 기기 시간대·앱 미실행 구간 때문에 웹과 다른 숫자가 나온다
    /// (같은 학생이 웹에서는 7일, 앱에서는 4일). 게스트만 로컬 계산을 쓴다.
    var streakDays: Int {
        if authProvider == "server", let s = serverStreak { return s }
        return ActivityLog.streak(from: activityDays)
    }

    /// 서버가 내려준 스트릭. 로그인 때 채우고 슬롯에 저장해 재실행 후에도 유지한다
    /// (한 번만 세팅하면 앱을 껐다 켰을 때 로컬값으로 되돌아간다).
    @Published var serverStreak: Int? = AppStore.restoreStreak("matths.serverStreak") {
        didSet { AppStore.persistStreak(serverStreak, "matths.serverStreak") }
    }
    @Published var serverLongestStreak: Int? = AppStore.restoreStreak("matths.serverLongestStreak") {
        didSet { AppStore.persistStreak(serverLongestStreak, "matths.serverLongestStreak") }
    }

    /// -1 을 "없음" 으로 쓴다 — integer(forKey:) 는 키가 없을 때 0 을 주므로
    /// 0 을 nil 로 읽으면 "스트릭 0일" 과 구분이 안 된다.
    nonisolated static func restoreStreak(_ base: String) -> Int? {
        let v = UserDefaults.standard.object(forKey: slotKey(base)) as? Int
        return (v ?? -1) >= 0 ? v : nil
    }
    nonisolated static func persistStreak(_ value: Int?, _ base: String) {
        UserDefaults.standard.set(value ?? -1, forKey: slotKey(base))
    }

    // MARK: 시험 기록 — 랭킹 "내 기록" 의 근거

    @Published var examResults: [Bool] = []
    var examStartedAt: Date?
    /// 현재 문항 풀이 시작 시각 — 문항별 durationMs (학습 이벤트용)
    var solveStartedAt: Date?
    @Published var bestScore: Int = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.bestScore"))
    @Published var bestElapsedMs: Int = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.bestMs"))

    /// 스크린샷 감지 시 학생이 적은 "막힌 지점".
    /// 잔소리로 끝내지 않고 오답노트로 넘긴다 — 기능이 되게.
    /// 슬롯 파일(stuck-points.json)로 영속한다 — 메모리에만 두면 앱 종료로
    /// 학생이 직접 적은 기록이 증발하는데 화면에는 목록으로 남아 "저장됐다" 는
    /// 인상을 준다 (M-08 감사 적발: 조용한 데이터 유실).
    @Published var stuckPoints: [StuckPointRecord] = StuckPointsDisk.load()

    /// 오답노트 디스크 저장 실패·손상 복구를 사용자에게 알릴 한 줄 경고 문구.
    /// nil = 표시할 경고 없음. WrongNoteStore 쪽(WrongNoteDisk 저장/복구 경로)이
    /// 세팅하고, 표시는 Screens(오답노트 화면)가 한다 — 저장 실패를 삼키면
    /// "적재됐다" 고 보이고 재실행하면 사라지는 조용한 유실이 된다 (F-04).
    /// 닫기(배너 X)는 UI 가 nil 로 되돌린다.
    @Published var wrongNoteStorageAlert: String?

    enum Route: Hashable, CaseIterable {
        case home, curriculum, concept, solve, result, assess, weeklyMock, wrongNotes, rank, arenaShop, commerce, placement, pro, profile, kice, paper, chat, quickPractice
        /// 학원·자료·지원·이용권을 역할별로 정리한 허브와, 서버 세션 기능을 여는 포털.
        case services, academy, coachSuggestions, support, archive, studyHall, storeCatalog, faq, hostedPortal
        /// 게시판 — 목록·검색·글·댓글·신고·차단을 네이티브로 제공한다. 탭 6번째.
        case community
        /// 알림함 — 게시판 답글·전체 공지·관리자 안내·경고. 탭이 아니라 상단 종 버튼으로 연다
        /// (탭 6칸은 이미 꽉 찼고, 알림은 "다녀오는 곳" 이지 머무는 곳이 아니다).
        case notifications

        /// 하단 탭바에 실제로 칸이 있는 화면인지. MainTabBar 의 items 와 같은 집합이다.
        var isTab: Bool {
            switch self {
            case .home, .curriculum, .assess, .wrongNotes, .rank, .community: return true
            default: return false
            }
        }
    }

    /// 서버가 확정한 실제 티어 공개 이벤트만 재생한다. 현재 티어를 단순 조회했다고
    /// 애니메이션을 반복하지 않도록 결정적 presentation id를 계정별로 기록한다.
    struct RankPromotionPresentation: Identifiable, Equatable {
        let id: String
        let tierCode: String
    }

    @Published var rankPromotionPresentation: RankPromotionPresentation?

    func presentRankPromotion(tierCode: String, presentationId: String) {
        guard let tier = RankTier(serverCode: tierCode),
              !presentationId.isEmpty else { return }

        let seenKey = AppStore.slotKey("matths.rankPromotion.seen")
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        guard !seen.contains(presentationId) else { return }
        seen.insert(presentationId)
        UserDefaults.standard.set(Array(seen.suffix(64)), forKey: seenKey)
        UserDefaults.standard.set(
            tierCode.uppercased(),
            forKey: AppStore.slotKey("matths.rankPromotion.lastTier"))
        let presentation = RankPromotionPresentation(
            id: presentationId,
            tierCode: tierCode.uppercased())
        // 화면을 먼저 띄운 뒤 PNG와 음원을 준비하면 조립 모션이 시작되는 순간 끊긴다.
        // 결과 화면은 유지한 채 현재 티어 리소스를 백그라운드에서 준비하고 cover를 연다.
        RankBadgeAssets.prewarmPromotion(tier: tier) { [weak self] in
            guard let self else { return }
            self.rankPromotionPresentation = presentation
        }
    }

    /// GOAT Arena를 새로고침할 때 실제 승급만 포착한다. 첫 조회는 기준점을 저장할
    /// 뿐 재생하지 않고, 배치 결과 공개는 서버 presentation id 경로가 담당한다.
    func observeArenaTier(_ tierCode: String?) {
        guard let newTier = RankTier(serverCode: tierCode) else { return }
        let key = AppStore.slotKey("matths.rankPromotion.lastTier")
        guard let oldCode = UserDefaults.standard.string(forKey: key),
              let oldTier = RankTier(serverCode: oldCode) else {
            UserDefaults.standard.set(newTier.rawValue, forKey: key)
            return
        }
        UserDefaults.standard.set(newTier.rawValue, forKey: key)
        guard let oldIndex = RankTier.allCases.firstIndex(of: oldTier),
              let newIndex = RankTier.allCases.firstIndex(of: newTier),
              newIndex > oldIndex else { return }
        presentRankPromotion(
            tierCode: newTier.rawValue,
            presentationId: "arena-tier:\(oldTier.rawValue):\(newTier.rawValue)")
    }

    func dismissRankPromotion() {
        rankPromotionPresentation = nil
    }

    // MARK: AI 튜터 (온디바이스 Qwen3.5 — LocalLLM.swift)

    /// 채팅 진입 시 미리 깔아 둘 문제 맥락 (오답노트/결과 화면의 "AI에게 묻기")
    @Published var chatSeedContext: String?

    /// 마지막 제출 답 원문 — 결과 화면에서 AI 튜터 맥락으로 넘긴다
    var lastStudentInput: String?

    /// 오답노트 "AI에게 묻기" — 문제·내 답·정답을 맥락으로 채팅 진입
    func openChatAbout(problem statement: String, myAnswer: String?, correct: String?) {
        var ctx = "문제: \(statement)"
        if let m = myAnswer, !m.isEmpty { ctx += "\n내가 낸 답: \(m)" }
        if let c = correct, !c.isEmpty { ctx += "\n정답: \(c)" }
        chatSeedContext = ctx
        route = .chat
    }

    // MARK: 프로필 — 설정과 학습 통계

    /// 학년 (10=고1, 11=고2, 12=고3, 13=N수)
    @Published var schoolGrade: Int =
        UserDefaults.standard.object(forKey: AppStore.slotKey("matths.grade")) as? Int ?? 12 {
        didSet {
            UserDefaults.standard.set(schoolGrade, forKey: AppStore.slotKey("matths.grade"))
        }
    }

    /// 학교 (경쟁전 리그 기반) — 목록 검증을 거친 값만 저장된다
    @Published var schoolRegion: String? =
        UserDefaults.standard.string(forKey: AppStore.slotKey("matths.schoolRegion")) {
        didSet {
            UserDefaults.standard.set(schoolRegion, forKey: AppStore.slotKey("matths.schoolRegion"))
        }
    }
    @Published var schoolCode: String? =
        UserDefaults.standard.string(forKey: AppStore.slotKey("matths.schoolCode")) {
        didSet {
            UserDefaults.standard.set(schoolCode, forKey: AppStore.slotKey("matths.schoolCode"))
        }
    }

    var schoolName: String? {
        guard let r = schoolRegion, let c = schoolCode else { return nil }
        return Schools.find(region: r, code: c)?.name
    }

    /// 학교 선택 — 웹처럼 목록 재검증 후에만 저장
    func setSchool(region: String, code: String) {
        guard Schools.find(region: region, code: code) != nil else { return }
        schoolRegion = region
        schoolCode = code
    }

    /// 테마: system | light | dark
    @Published var themePreference: String = UserDefaults.standard.string(forKey: "matths.theme") ?? "system" {
        didSet { UserDefaults.standard.set(themePreference, forKey: "matths.theme") }
    }

    /// 복습 리마인더 — 기기 로컬 알림(ReviewReminder). 값만 저장하고 읽는 곳이 한 곳도
    /// 없어서, 켜도 저녁 알림이 오지 않던 토글이었다 (2026-07-29 감사 적발).
    /// 앱이 하지 않는 일을 한다고 말하지 않으려면 토글이 실제로 예약을 걸어야 한다.
    @Published var reviewReminderOn: Bool = UserDefaults.standard.bool(forKey: "matths.reminder") {
        didSet {
            UserDefaults.standard.set(reviewReminderOn, forKey: "matths.reminder")
            guard reviewReminderOn else { ReviewReminder.cancelAll(); return }
            ReviewReminder.reschedule(wrongNotes) { [weak self] granted in
                // 권한이 거부되면 켜진 척하지 않는다 — 화면이 거짓말하는 쪽이 더 나쁘다
                guard !granted else { return }
                Task { @MainActor in self?.reviewReminderOn = false }
            }
        }
    }

    /// iOS 설정에서 알림 권한을 끈 뒤 앱으로 돌아왔을 때 토글이 켜진 척하지 않게 한다.
    /// 예약이 가능한 권한만 켬 상태로 인정하고, 거부·미결정 상태는 저장값도 함께 내린다.
    func refreshNotificationAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let canSchedule: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            canSchedule = true
        case .denied, .notDetermined:
            canSchedule = false
        @unknown default:
            canSchedule = false
        }
        if reviewReminderOn && !canSchedule {
            reviewReminderOn = false
        }
    }

    // 오답노트의 검색·필터·펼침 상태는 라우트 화면보다 오래 살아야 한다.
    // RootView의 route 교체로 WrongNotesScreen이 재생성되어도 여기서 이어 간다.
    @Published var wrongNoteExpanded: Set<String> = []
    @Published var wrongNoteFilterUnit: String?
    @Published var wrongNoteFilterError: String?
    @Published var wrongNoteQuery = ""
    @Published var wrongNoteSortKey: WrongNoteSort = .latest

    /// 화면 모션 (전환·등장·피드백 애니메이션). 기본 켬.
    /// 시스템 "동작 줄이기" 는 이 값과 무관하게 항상 이긴다 (Motion.swift).
    @Published var motionOn: Bool = UserDefaults.standard.object(forKey: "matths.motion") as? Bool ?? true {
        didSet { UserDefaults.standard.set(motionOn, forKey: "matths.motion") }
    }

    /// 왼손잡이 모드 — 풀이 화면에서 노트를 왼쪽에 둔다 (오른손이 문제를 가리지 않게,
    /// 왼손잡이는 그 반대가 필요하다)
    @Published var leftHandedOn: Bool = UserDefaults.standard.bool(forKey: "matths.leftHanded") {
        didSet { UserDefaults.standard.set(leftHandedOn, forKey: "matths.leftHanded") }
    }

    /// 표시 이름 — 홈 인사와 프로필. 실서비스에서는 로그인 프로필에서 온다.
    /// 서버 계정 이메일 — 표시 전용 (게스트면 빈 문자열)
    @Published var userEmail: String =
        UserDefaults.standard.string(forKey: AppStore.slotKey("matths.userEmail")) ?? "" {
        didSet {
            UserDefaults.standard.set(userEmail, forKey: AppStore.slotKey("matths.userEmail"))
        }
    }

    @Published var userName: String =
        UserDefaults.standard.string(forKey: AppStore.slotKey("matths.userName")) ?? "수빈" {
        didSet {
            UserDefaults.standard.set(userName, forKey: AppStore.slotKey("matths.userName"))
        }
    }

    /// 계정 슬롯별 UserDefaults 키.
    /// 파일(DataScope)만 계정별로 갈라 놓고 통계는 전역 키에 둔 탓에, 로그아웃하고
    /// 다른 계정으로 들어와도 앞사람의 푼 문항·정답률·최고 기록이 그대로 보였다
    /// (2026-07-29 감사 적발 — 한 기기를 형제가 같이 쓰면 사고다).
    /// 게스트는 옛 평평한 키를 그대로 쓴다 — 기존 설치의 기록을 잃지 않게.
    /// nonisolated — DataScope.slot 을 읽어 문자열을 만드는 순수 계산이라
    /// 액터 격리에 묶일 이유가 없다. KiceBank·ActivityLog 처럼 격리 밖에서도 쓴다.
    nonisolated static func slotKey(_ base: String) -> String {
        DataScope.slot == "guest" ? base : "\(base).\(DataScope.slot)"
    }

    /// 계정 슬롯 도입 전에는 프로필만 전역 UserDefaults 에 남았다. 업데이트 당시
    /// 로그인된 서버 계정과 이메일 해시가 일치할 때만 새 슬롯으로 옮긴다.
    /// 복사 뒤 옛 키를 비워야 로그아웃한 게스트 화면에 서버 프로필이 노출되지 않는다.
    nonisolated private static func migrateLegacyProfileIfNeeded() {
        guard DataScope.slot != "guest" else { return }
        let defaults = UserDefaults.standard
        guard let legacyEmail = defaults.string(forKey: "matths.userEmail"),
              !legacyEmail.isEmpty,
              DataScope.slotName(forEmail: legacyEmail) == DataScope.slot else { return }

        let keys = [
            "matths.grade", "matths.schoolRegion", "matths.schoolCode",
            "matths.userEmail", "matths.userName", "matths.gradePromoYear",
            "matths.lastCourse",
        ]
        for key in keys {
            let scoped = slotKey(key)
            if defaults.object(forKey: scoped) == nil,
               let legacy = defaults.object(forKey: key) {
                defaults.set(legacy, forKey: scoped)
            }
            defaults.removeObject(forKey: key)
        }
    }

    /// 누적 학습 통계 — gradeCurrent 가 갱신한다
    @Published var solvedTotal: Int = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.solved"))
    @Published var correctTotal: Int = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.correct"))

    var accuracy: Int {
        solvedTotal == 0 ? 0 : Int((Double(correctTotal) / Double(solvedTotal) * 100).rounded())
    }

    var gradeLabel: String {
        switch schoolGrade {
        case 10: return "고등학교 1학년"
        case 11: return "고등학교 2학년"
        case 12: return "고등학교 3학년"
        default: return "N수생"
        }
    }


    // MARK: 계정별 로컬 슬롯 (DataScope)

    struct AccountSessionBoundary: Sendable {
        fileprivate let slot: String
        fileprivate let generation: UUID
    }

    func captureAccountSessionBoundary() -> AccountSessionBoundary {
        AccountSessionBoundary(slot: DataScope.slot, generation: accountSessionGeneration)
    }

    func ownsCurrentAccountSession(_ boundary: AccountSessionBoundary) -> Bool {
        boundary.slot == DataScope.slot
            && boundary.generation == accountSessionGeneration
    }

    private func isLearningAccountOperationActive(
        for boundary: AccountSessionBoundary
    ) -> Bool {
        ownsCurrentAccountSession(boundary)
            && isLearningAccountOperationActive(for: boundary.slot)
    }

    /// submitLocalPaper가 소유한 짧은 두 파일 트랜잭션 안에서만 쓰는 owner 확인.
    /// 일반 작업은 위 게이트에서 false가 되어 await 중 wrongNotes를 바꾸지 못하지만,
    /// 이 제출 continuation 자체는 계정 전환·탈퇴 여부를 계속 판정할 수 있어야 한다.
    private func ownsLocalAssessmentPersistenceTransaction(
        _ boundary: AccountSessionBoundary
    ) -> Bool {
        assessmentPersistenceTransactionInFlight
            && ownsCurrentAccountSession(boundary)
            && boundary.slot == DataScope.slot
            && !disabledLearningPersistenceSlots.contains(boundary.slot)
            && transitioningLearningPersistenceSlots[boundary.slot] == nil
    }

    /// 로그인/로그아웃으로 계정이 바뀌면 로컬 데이터 슬롯을 갈아끼우고 다시 읽는다.
    /// 이걸 안 하면 앞사람 진도·오답이 그대로 보인다.
    @discardableResult
    private func switchDataSlot(
        email: String?,
        flushPending: Bool = true,
        beforeSwitch: (() -> Bool)? = nil
    ) async -> Bool {
        // 요청 시점에 세대를 선점한다. reset을 같이 기다리던 두 요청이 깨어난 순서가
        // 아니라 실제로 더 나중에 들어온 계정 의사가 최종 승자가 돼야 한다.
        let generation = UUID()
        accountTransitionGeneration = generation
        // reset은 "빈 로컬 파일 → 서버 reset journal"까지 한 트랜잭션이다.
        // 그 중간에 계정을 바꾸면 서버 op만 빠지므로 전체 경계가 끝날 때까지 기다린다.
        while progressResetInFlight {
            guard !Task.isCancelled,
                  generation == accountTransitionGeneration else { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard generation == accountTransitionGeneration else { return false }
        let target = DataScope.slotName(forEmail: email)
        // target이 현재 슬롯과 같아도 더 최신 전환 의사다. 앞 A→B가 flush를 기다리는
        // 동안 A 유지 요청이 오면 반드시 앞 세대를 취소해야 한다.
        guard target != DataScope.slot else {
            disabledLearningPersistenceSlots.remove(target)
            guard beforeSwitch?() ?? true else { return false }
            accountSessionGeneration = UUID()
            return true
        }
        let source = DataScope.slot
        transitioningLearningPersistenceSlots[source] = generation
        defer {
            // 같은 source에서 더 최신 전환이 gate 소유권을 넘겨받았으면 앞 세대가
            // 그 gate를 열어서는 안 된다.
            if transitioningLearningPersistenceSlots[source] == generation {
                transitioningLearningPersistenceSlots.removeValue(forKey: source)
            }
        }
        // 네트워크 평가 시작은 generation으로, draft는 Task 취소로 먼저 닫는다.
        // 제출 경로는 아래 transition gate를 모든 await 뒤 다시 확인한다.
        assessmentStartGeneration = UUID()
        assessmentDraftTask?.cancel()
        // 실행 중 결과가 슬롯 전환 뒤 다른 계정 파일에 적히지 않게 먼저 닫는다.
        interruptCheatingReviews(reason: "계정이 전환되어 로컬 판정을 중단했습니다.")
        // 일반 로그인/로그아웃은 데이터를 지우는 작업이 아니다. 메모리 최신값을
        // 캡처한 **기존 슬롯**으로 실제 파일 교체까지 끝낸 뒤 전환한다. 목적지 캡처만
        // 하고 기다리지 않으면 A→guest→A에서 A의 옛 파일을 먼저 다시 읽을 수 있다.
        if flushPending {
            let snapshotsPersisted = await flushLearningPersistence()
            let eventsPersisted = await EventLog.flushPendingWrites(for: source)
            let syncQueuePersisted = await SyncEngine.shared.flushLocalQueuePersistence()
            if !(snapshotsPersisted && eventsPersisted && syncQueuePersisted) {
                NSLog("LEARNING-PERSISTENCE-ERROR 슬롯 전환 전 저장 일부 실패: %@", source)
                // 실패 payload를 actor가 pending으로 보존한다. 여기서 stale 파일을
                // reload하면 그 pending을 더 높은 revision의 옛 값으로 덮을 수 있으므로,
                // 사용자가 재시도하거나 background flush가 성공할 때까지 전환하지 않는다.
                return false
            }
        }
        // 과거 탈퇴 뒤 같은 해시 슬롯에 새 계정이 만들어질 수 있다. 실제 전환이
        // 확정되기 직전에만 append writer tombstone을 열고, 아래 generation guard가
        // 더 최신 계정 의사에 진 전환을 중단한다.
        await SyncEngine.shared.activateLocalQueuePersistence(for: target)
        await EventLog.activatePendingWrites(for: target)
        guard generation == accountTransitionGeneration,
              DataScope.slot == source else { return false }
        // 탈퇴한 이메일로 훗날 새 계정을 만든 경우 같은 해시 슬롯을 다시 쓸 수 있다.
        // 실제 슬롯 전환이라는 명시적 경계에서만 로컬 게이트를 다시 연다.
        disabledLearningPersistenceSlots.remove(target)
        // 로그아웃의 토큰·Published auth 정리는 flush 성공과 generation 검증 뒤,
        // DataScope 변경 바로 전에 실행한다. await 중 로그인 화면을 먼저 노출하지 않는다.
        guard beforeSwitch?() ?? true else { return false }
        // switchTo는 알림을 동기로 게시한다. generation을 뒤에서 바꾸면 observer가
        // "새 슬롯 + 옛 세션" owner를 캡처할 수 있으므로 알림보다 먼저 발급한다.
        let previousSessionGeneration = accountSessionGeneration
        accountSessionGeneration = UUID()
        guard DataScope.switchTo(target) else {
            accountSessionGeneration = previousSessionGeneration
            return false
        }
        clearTransientAccountState()
        reloadLocalData()
        return true
    }

    /// 파일에 저장하지 않는 풀이·튜터·시험 세션도 학생별 상태다. 새 슬롯에서 이전
    /// 학생의 답안이나 진행 중 시험을 다시 열 수 없도록 전환 순간에만 초기화한다.
    private func clearTransientAccountState() {
        // 예약해 둔 로컬 알림에도 앞 학생의 상태가 들어 있다(복습할 오답 수, 방어 마감).
        // 한 대의 iPad 를 형제가 나눠 쓰므로 슬롯이 바뀌면 예약도 함께 끊는다.
        // 새 슬롯의 예약은 reloadLocalData() 뒤 각 화면이 서버 값을 받아 다시 건다.
        MatthsLocalNotifications.cancelAccountScoped()
        assessmentDraftTask?.cancel()
        assessmentDraftTask = nil
        assessmentStartGeneration = UUID()
        assessmentSubmitting = false
        assessmentSyncError = nil
        NotificationInboxStore.shared.reloadForCurrentSlot()
        lastGrading = nil
        reviewingNoteIDs = nil
        pendingReview = nil
        isVariationCheck = false
        examResults = []
        examStartedAt = nil
        solveStartedAt = nil
        stuckPoints = []
        chatSeedContext = nil
        lastStudentInput = nil
        rankPromotionPresentation = nil
        coach = CoachEngine()
        coachLine = nil
        coachGuidance = nil
        divergenceStep = nil
        selectedConceptV2ID = nil
        examSourceConceptV2ID = nil
        exam = []
        examIndex = 0
        lastExamSeed = 0
        currentAttemptID = nil
        kiceExamID = nil
        kiceAnswers = [:]
        kiceSubject = [:]
    }

    /// SyncEngine 이 오답노트 배열을 직접 만지지 않도록, 콜백을 한 번만 걸어 둔다.
    func wireSyncCallbacks() {
        SyncEngine.shared.captureAccountOwner = { [weak self] in
            guard let self else { return nil }
            return SyncAccountOwner(
                slot: DataScope.slot,
                sessionGeneration: self.accountSessionGeneration)
        }
        SyncEngine.shared.onServerID = { [weak self] client, server, owner in
            self?.attachServerAttemptID(client: client, server: server, owner: owner)
        }
        // 서버→로컬 수신부. 이게 없으면 SyncEngine 은 pull 요청 자체를 하지 않는다
        // (커서만 밀어 두면 그 구간 오답을 영영 못 받으므로 일부러 그렇게 막혀 있다).
        SyncEngine.shared.onRemoteWrongNotes = { [weak self] notes, owner in
            // SyncEngine과 AppStore는 같은 MainActor다. 별도 Task로 미루면 handler 반환 뒤
            // cursor가 먼저 전진하고, 그 사이 슬롯 전환 시 A payload가 B로 들어갈 수 있다.
            guard let self else { return false }
            return await self.mergeRemoteWrongNotes(notes, owner: owner)
        }
        SyncEngine.shared.onRemoteProgress = { [weak self] rows, owner in
            self?.mergeRemoteProgress(rows, owner: owner)
        }
        SyncEngine.shared.onRemoteStuckPoints = { [weak self] rows, owner in
            self?.mergeRemoteStuckPoints(rows, owner: owner)
        }
        // 엔진 생성 시도는 콜백보다 먼저 일어날 수 있다. 수신부가 모두 연결된 뒤
        // 한 번 더 깨워야 첫 실행에서도 서버 진도가 즉시 보인다.
        Task { await SyncEngine.shared.syncNow() }
        Task { [weak self] in await self?.pullServerAssessments() }
    }

    /// 서버에서 받은 진도를 로컬과 합친다 — **덮지 않는다.**
    ///
    /// 덮어쓰면 비행기 모드에서 방금 푼 것이 사라진다. 유형·토픽은 합집합,
    /// 완료 플래그는 어느 쪽이든 true 면 true (진도는 되돌아가지 않는 값이다).
    /// 이 경로가 없던 동안에는 기기를 바꾸면 서버에 기록이 멀쩡한데도
    /// 학습 허브가 0% 로 보였다(2026-07-29 감사 적발).
    @MainActor
    func mergeRemoteProgress(
        _ rows: [ServerAPI.RemoteConceptProgress],
        owner: SyncAccountOwner
    ) {
        // 빈 스냅샷 저장과 reset journal 사이에 예전 서버 pull을 합치면, 초기화 직후
        // 진도가 되살아나거나 reset op보다 뒤의 로컬 저장으로 순서가 뒤집힌다.
        guard isSyncAccountOwnerActive(owner),
              isLearningSlotWritable(for: owner.slot),
              !progressResetInFlight, !rows.isEmpty else { return }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        for r in rows {
            let when = r.lastStudiedAt.flatMap { iso.date(from: $0) ?? plain.date(from: $0) }
            progressV2.mergeRemote(
                conceptId: r.conceptId,
                topicIndexes: r.completedTopicIndexes ?? [],
                correctTypeIds: r.masteryGate?.correctTypeIds ?? [],
                userCompleted: r.masteryGate?.userCompleted == true,
                lastStudiedAt: when)
            if r.masteryGate?.userCompleted == true {
                // 구 평가센터 잠금은 v2 id가 아니라 legacy.appId 집합을 읽는다.
                if let appID = CurriculumV2.concept(r.conceptId)?.2.legacy?.appId {
                    completedConceptIDs.insert(appID)
                }
            }
        }
        saveProgressV2()
        Progress.save(completedConceptIDs)
        objectWillChange.send()
    }

    /// 서버에서 받은 오답을 로컬과 합친다 — **문제 스냅샷은 로컬 우선,
    /// 복습 상태는 서버 갱신 시각 기준 최신 우선.**
    ///
    /// 로컬을 이기게 두는 이유: 필기 이미지·선지·단원처럼 서버가 보관하지 않는 것이
    /// 이쪽에만 있다. 서버 것으로 덮으면 그 자리가 빈 채로 남는다.
    /// 다른 기기에서 새로 생긴 오답은 앞에 붙이고, 이미 있는 오답은 필기·문장·
    /// 해설을 건드리지 않은 채 완료/예약/횟수와 serverAttemptId만 갱신한다.
    func mergeRemoteWrongNotes(
        _ notes: [WrongNoteEntry],
        owner: SyncAccountOwner
    ) async -> Bool {
        guard isSyncAccountOwnerActive(owner),
              isLearningSlotWritable(for: owner.slot) else { return false }
        var changed = false
        var fresh: [WrongNoteEntry] = []
        for remote in notes {
            guard let index = wrongNotes.firstIndex(where: { $0.id == remote.id }) else {
                fresh.append(remote)
                continue
            }

            // 매핑은 revision 비교와 무관하게 보완하고, 서버 관리 상태만 최신으로
            // 갱신한다. 필기·문장·해설 같은 로컬 스냅샷은 순수 병합 함수가 건드리지 않는다.
            changed = WrongNoteSyncMerge.apply(
                remote: remote, to: &wrongNotes[index]) || changed
        }
        if !fresh.isEmpty {
            wrongNotes.insert(contentsOf: fresh, at: 0)
            changed = true
        }
        // changed가 false여도 저장을 생략하지 않는다. 직전 pull의 파일 쓰기가 실패해
        // 메모리에만 같은 값이 남은 재시도라면, 여기서 true를 돌려 cursor를 밀기 전에
        // 현재 전체 snapshot이 실제 디스크에 있음을 다시 확인해야 한다.
        let snapshot = LearningPersistenceSnapshot.wrongNotes(wrongNotes)
        let persisted = await persistLearningImmediately(snapshot, for: owner.slot)
        // 파일은 캡처한 owner 경로에 저장됐다. 다만 await 중 계정이 바뀌었다면 해당
        // 응답의 cursor는 전진시키지 않아 다음 owner 진입 때 안전하게 다시 받는다.
        guard persisted, isSyncAccountOwnerActive(owner),
              isLearningSlotWritable(for: owner.slot) else { return false }
        if changed { objectWillChange.send() }
        return true
    }

    /// 서버가 오답에 붙인 id 를 받아 적는다 (복습 결과를 올릴 주소가 된다)
    func attachServerAttemptID(
        client: String,
        server: String,
        owner: SyncAccountOwner
    ) {
        guard isSyncAccountOwnerActive(owner),
              isLearningSlotWritable(for: owner.slot) else { return }
        guard let i = wrongNotes.firstIndex(where: { $0.id == client }) else { return }
        guard wrongNotes[i].serverAttemptId != server else { return }
        wrongNotes[i].serverAttemptId = server
        saveWrongNotes()
    }

    func mergeRemoteStuckPoints(
        _ rows: [ServerAPI.RemoteStuckPoint],
        owner: SyncAccountOwner
    ) {
        guard isSyncAccountOwnerActive(owner),
              isLearningSlotWritable(for: owner.slot) else { return }
        let existing = Set(stuckPoints.map(\.id))
        let formatter = ISO8601DateFormatter()
        let fresh = rows.compactMap { row -> StuckPointRecord? in
            guard !existing.contains(row.id),
                  let date = formatter.date(from: row.createdAt) else { return nil }
            return StuckPointRecord(id: row.id, text: row.text, createdAt: date)
        }
        guard !fresh.isEmpty else { return }
        stuckPoints.append(contentsOf: fresh)
        stuckPoints.sort { $0.createdAt > $1.createdAt }
        saveStuckPoints()
    }

    /// 현재 슬롯의 파일들로 메모리 상태를 통째로 다시 채운다.
    func reloadLocalData() {
        wrongNotes = WrongNoteDisk.load()
        cheatingReviews = CheatingReviewDisk.loadRecoveringInterrupted()
        var p = ProgressV2Store.load()
        p.migrate(fromLegacyCompleted: Progress.load())
        progressV2 = p
        attemptsV2 = .load()
        completedConceptIDs = Progress.load()
        activityDays = ActivityLog.load()
        stuckPoints = StuckPointsDisk.load()
        dailyPlan = DailyPlanStore.load(dateKey: ActivityLog.dayString())
        serverStreak = AppStore.restoreStreak("matths.serverStreak")
        serverLongestStreak = AppStore.restoreStreak("matths.serverLongestStreak")
        schoolGrade = UserDefaults.standard.object(
            forKey: AppStore.slotKey("matths.grade")) as? Int ?? 12
        schoolRegion = UserDefaults.standard.string(
            forKey: AppStore.slotKey("matths.schoolRegion"))
        schoolCode = UserDefaults.standard.string(
            forKey: AppStore.slotKey("matths.schoolCode"))
        userEmail = UserDefaults.standard.string(
            forKey: AppStore.slotKey("matths.userEmail")) ?? ""
        userName = UserDefaults.standard.string(
            forKey: AppStore.slotKey("matths.userName")) ?? "수빈"
        selectedCourseV2ID = UserDefaults.standard.string(
            forKey: AppStore.slotKey("matths.lastCourseV2"))
        // 통계는 파일이 아니라 UserDefaults 에 있다 — 슬롯 키로 다시 읽지 않으면
        // 계정을 바꿔도 앞사람의 푼 문항·정답률·최고 기록이 화면에 그대로 남는다.
        solvedTotal = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.solved"))
        correctTotal = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.correct"))
        bestScore = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.bestScore"))
        bestElapsedMs = UserDefaults.standard.integer(forKey: AppStore.slotKey("matths.bestMs"))
        GoatArenaClientReviewOutbox.recoverCompleted(cheatingReviews)
        Task { await GoatArenaClientReviewOutbox.flush() }
        AITutor.shared.reloadConversationForCurrentSlot()
        resumePendingGoatArenaCheatingReviews()
        objectWillChange.send()
    }

    /// 서버 계정 로그인/가입 성공 — 서버 user 를 로컬 상태에 반영하고 입장
    @discardableResult
    func signInServer(_ auth: AuthResponse, attemptID: UUID) async throws -> Bool {
        let user = auth.user
        // ⚠️ 순서가 전부다.
        //  ① 게스트로 쌓아 둔 기록을 **먼저 손에 쥔다.** 슬롯을 옮기면 reloadLocalData 가
        //     메모리를 새 슬롯(빈 계정) 파일로 덮어써서, 그 뒤에 업로드하면 언제나
        //     빈 배열이 올라간다 — 게스트로 공부하다 가입한 사람의 기록이 통째로 증발한다.
        //     (2026-07-29 감사에서 적발. 실제로 acct 슬롯에 오답 0건이 올라갔다)
        //  ② 그 다음 슬롯을 옮기고, ③ 쥐고 있던 것을 올린다.
        // 서버가 계산한 스트릭을 받아 둔다 — 앱이 로컬에서 따로 세면 웹과 다른
        // 숫자가 나온다(기기 시간대·앱 미실행 구간 때문). 서버가 진실원이다.
        let incomingStreak = user.currentStreak
        let incomingLongest = user.longestStreak

        let carriedOver = DataScope.slot == "guest" ? wrongNotes : []
        // 통계도 같이 쥔다 — 슬롯별 키로 갈라 놓은 뒤로는 슬롯을 옮기는 순간
        // 푼 문항·정답률·최고 기록이 0으로 보인다. 오답만 옮기고 이걸 두고 오면
        // 가입한 사람 눈에는 "공부한 게 사라진" 것과 똑같다.
        let guestStats: (solved: Int, correct: Int, best: Int, ms: Int)? =
            DataScope.slot == "guest"
            ? (solvedTotal, correctTotal, bestScore, bestElapsedMs) : nil
        // 진도도 같이 쥔다. 오답·통계만 옮기고 진도를 두고 오면, 가입하는 순간
        // 학습 허브가 0% 로 되돌아간다 — 23차에 "로컬 진도 무손실" 로 실증했던
        // 계약이 그 뒤 슬롯 분리로 깨져 있었다(2026-07-29 감사 적발).
        // 서버에서 진도를 되받는 경로도 없으니 여기서 안 옮기면 영영 사라진다.
        let guestProgress: (v2: ProgressV2Store, attempts: AttemptStoreV2, done: Set<String>)? =
            DataScope.slot == "guest" ? (progressV2, attemptsV2, completedConceptIDs) : nil
        var transferredProgress: ProgressV2Store?
        var tokenCommitError: Error?
        let switched = await switchDataSlot(
            email: user.email,
            beforeSwitch: {
                // Keychain token은 old-slot flush와 generation 검증이 모두 끝난 뒤에만
                // 승격한다. 새 계정 token + guest/이전 계정 slot 조합은 한 순간도 만들지 않는다.
                do {
                    return try ServerAPI.acceptAuthentication(auth, attemptID: attemptID)
                } catch {
                    tokenCommitError = error
                    return false
                }
            })
        if let tokenCommitError { throw tokenCommitError }
        guard switched else { return false }
        let accountSlot = DataScope.slot
        let transitionGeneration = accountTransitionGeneration
        if let n = user.name, !n.isEmpty { userName = n }
        // 계정 식별용 이메일 — 프로필에서 "어느 계정으로 들어와 있는지" 를 보여준다.
        // 비밀번호·토큰은 절대 여기 두지 않는다(토큰은 키체인).
        userEmail = user.email ?? userEmail
        if let g = user.schoolGrade { schoolGrade = g }
        if let r = user.school?.region, let c = user.school?.code {
            schoolRegion = r
            schoolCode = c
        }
        signIn(provider: "server")
        applyServerProfile(user)
        // **슬롯을 옮긴 뒤에** 세팅한다. slotKey 가 새 슬롯을 가리켜야
        // 이 계정의 키에 저장되고, 재실행 때도 같은 계정에서 복원된다.
        serverStreak = incomingStreak
        serverLongestStreak = incomingLongest
        // 게스트로 쌓아 둔 기록을 계정으로 승계한다 — 서버로 올리고, 이 계정 슬롯에도
        // 병합해 둔다(서버 왕복 없이도 화면에서 바로 보이게). 같은 문제는 id 로 걸러진다.
        if !carriedOver.isEmpty {
            let existing = Set(wrongNotes.map(\.id))
            let fresh = carriedOver.filter { !existing.contains($0.id) }
            if !fresh.isEmpty {
                wrongNotes.insert(contentsOf: fresh, at: 0)
            }
        }
        // 통계 승계는 **아직 기록이 없는 계정**에만 한다. 이미 쌓인 계정에 더하면
        // 재로그인마다 게스트 활동이 얹혀 숫자가 부풀고, 남이 쓰던 게스트 기록까지
        // 그 계정 것이 된다 (계정 분리를 하려다 반대쪽으로 새는 길).
        if let g = guestStats, solvedTotal == 0, correctTotal == 0 {
            solvedTotal = g.solved
            correctTotal = g.correct
            UserDefaults.standard.set(solvedTotal, forKey: AppStore.slotKey("matths.solved"))
            UserDefaults.standard.set(correctTotal, forKey: AppStore.slotKey("matths.correct"))
            if bestScore == 0 {
                bestScore = g.best
                bestElapsedMs = g.ms
                UserDefaults.standard.set(bestScore, forKey: AppStore.slotKey("matths.bestScore"))
                UserDefaults.standard.set(bestElapsedMs, forKey: AppStore.slotKey("matths.bestMs"))
            }
        }
        // 진도 승계 — 통계와 같은 가드(빈 계정에만). 이미 공부한 계정에 게스트
        // 진도를 얹으면 남이 쓰던 기록이 그 계정 것이 된다.
        if let gp = guestProgress,
           completedConceptIDs.isEmpty, progressV2.byConcept.isEmpty,
           attemptsV2.attempts.isEmpty {
            progressV2 = gp.v2
            attemptsV2 = gp.attempts
            completedConceptIDs = gp.done
            Progress.save(completedConceptIDs)
            transferredProgress = gp.v2
            objectWillChange.send()
        }
        // 슬롯 승계가 끝난 뒤 올린다. 토픽·유형·완료를 모두 서버에 먼저 밀고,
        // 이어서 서버에만 있던 진도와 오답을 다시 받아 합친다.
        if !carriedOver.isEmpty || transferredProgress != nil {
            // 세 resource를 하나의 actor batch로 먼저 내구 저장한다. 가입 직후 앱이
            // 종료돼도 서버 업로드만 시작되고 계정 슬롯은 빈 상태가 되는 틈을 없앤다.
            let transferPersisted = await flushLearningPersistence()
            guard accountTransitionGeneration == transitionGeneration,
                  isLearningAccountOperationActive(for: accountSlot) else { return false }
            guard transferPersisted else {
                // 원본 guest 슬롯은 전환 전 flush로 이미 안전하다. account 복사본 저장이
                // 실패했다면 token/session을 guest로 되돌려 "로그인은 됐지만 평가만 유실"
                // 상태를 만들지 않는다. target에 성공한 일부 복사본은 다음 재시도 때 ID로 병합된다.
                await invalidateLearningPersistence(for: accountSlot)
                _ = await signOut(discardingCurrentSlot: true)
                return false
            }
            SyncEngine.shared.uploadLocalSnapshot(
                wrongNotes: carriedOver,
                progress: transferredProgress)
        }
        // 같은 계정 재로그인 시 미전송분 재적재 (B-09).
        // 토큰 만료 구간(과거 버전은 큐에도 못 쌓았다)·큐 파일 유실로 서버 확인
        // (serverAttemptId)을 받지 못한 오답이 이 슬롯에 남아 있을 수 있다 — 재로그인이
        // 그 기록이 다시 올라갈 유일한 계기다. bulk 전송은 clientAttemptId 멱등이라
        // 이미 올라간 것이 섞여도 서버가 거르고, serverAttemptId 가 붙는 순간부터는
        // 이 필터에 다시 걸리지 않는다(자기 제한적).
        // carriedOver(게스트 승계분)는 위 uploadLocalSnapshot 이 올리므로 제외한다.
        // 상한 100건은 uploadLocalSnapshot 과 같은 규약.
        let carriedIDs = Set(carriedOver.map(\.id))
        let unsent = wrongNotes.filter {
            $0.serverAttemptId == nil && !carriedIDs.contains($0.id)
        }
        for note in unsent.prefix(100) {
            SyncEngine.shared.enqueueWrongNote(note)
        }
        Task { [weak self] in await self?.pullServerAssessments() }
        return true
    }

    /// 버튼처럼 동기 클로저에서 부르는 편의 진입점. 실제 슬롯 전환은 아래 async
    /// 경계가 기존 계정 파일 저장을 끝낸 뒤 수행한다.
    func signOut() {
        Task { [weak self] in _ = await self?.signOut(discardingCurrentSlot: false) }
    }

    @discardableResult
    func signOut(discardingCurrentSlot: Bool) async -> Bool {
        let oldSlot = DataScope.slot
        guard await switchDataSlot(
            email: nil,
            // 회원 탈퇴는 cancel-and-drain 뒤 디렉터리를 지운다. 그때 최신값을 새로
            // 제출하면 삭제 직전에 파일을 되살리는 명령이 되므로 명시적으로 끈다.
            flushPending: !discardingCurrentSlot,
            beforeSwitch: {
                ServerAPI.logout()          // 서버 계정이었으면 토큰 폐기 (게스트면 no-op)
                self.authProvider = nil
                self.serverProfile = nil
                // Application Support의 알림 파일은 Documents 슬롯 purge에 포함되지 않는다.
                // guest로 바꾸기 전에 이전 owner slot을 명시해 지운다.
                NotificationInboxStore.shared.clear(slot: oldSlot)
                return true
            }) else { return false }
        UserDefaults.standard.removeObject(forKey: "matths.auth")
        route = .home
        WidgetBridge.clear()        // 홈 화면 위젯에 앞 계정 이름·미션이 남지 않게
        return true
    }

    /// 진도 초기화 — 프로필의 파괴적 동작. 확인 다이얼로그 뒤에서만 부른다.
    ///
    /// v2 진도 초기화도 **여기서** 한다 — 호출부(다이얼로그 클로저)가 따로 기억하게
    /// 두면 resetProgress 를 부르는 두 번째 호출부가 생기는 순간 절반만 초기화되는
    /// 무음 결함이 된다 (F-01: 불변식은 소유자가 완결한다).
    @discardableResult
    func resetProgress() async -> Bool {
        guard isLearningAccountOperationActive(for: DataScope.slot),
              !progressResetInFlight else { return false }
        progressResetInFlight = true
        defer { progressResetInFlight = false }

        let slot = DataScope.slot
        let previousCompleted = completedConceptIDs
        let previousProgress = progressV2
        let previousSolved = solvedTotal
        let previousCorrect = correctTotal
        completedConceptIDs = []
        Progress.save([])
        progressV2 = ProgressV2Store()
        solvedTotal = 0
        correctTotal = 0
        UserDefaults.standard.set(0, forKey: AppStore.slotKey("matths.solved"))
        UserDefaults.standard.set(0, forKey: AppStore.slotKey("matths.correct"))
        // 파괴적 확정은 debounce하지 않는다. actor의 같은-key pending을 취소하고
        // 빈 스냅샷 쓰기가 실제로 끝난 뒤 서버 reset journal을 적재한다.
        let persisted = await persistLearningImmediately(
            .progress(progressV2.byConcept), for: slot)
        guard isLearningAccountOperationActive(for: slot) else { return false }
        guard persisted else {
            NSLog("PROGRESS-RESET-ERROR 빈 진도 스냅샷을 저장하지 못했습니다")
            // 실패를 성공처럼 보이지 않게 메모리와 UserDefaults를 원상 복구한다.
            // 더 높은 revision으로 복구본도 제출해 actor에 남은 실패한 빈 snapshot을
            // 다음 flush가 뒤늦게 쓰는 일을 막는다.
            completedConceptIDs = previousCompleted
            Progress.save(previousCompleted)
            progressV2 = previousProgress
            solvedTotal = previousSolved
            correctTotal = previousCorrect
            UserDefaults.standard.set(
                previousSolved, forKey: AppStore.slotKey("matths.solved"))
            UserDefaults.standard.set(
                previousCorrect, forKey: AppStore.slotKey("matths.correct"))
            requestImmediateLearningPersistence(.progress(previousProgress.byConcept))
            return false
        }
        if authProvider == "server" {
            let resetQueued = await SyncEngine.shared.enqueueProgressResetDurably()
            guard isLearningAccountOperationActive(for: slot) else { return false }
            guard resetQueued else {
                // op는 부분 append 가능성 때문에 안전하게 취소할 수 없다. 로컬의 빈 진도는
                // 유지하고 다음 명시적 retry/background flush가 같은 reset을 내구화하게 한다.
                NSLog("PROGRESS-RESET-ERROR 서버 reset journal 저장 실패")
                return false
            }
        }
        return true
    }

    // MARK: 코치 — 스크립트 풀 기반, LLM 불필요 (CoachEngine.swift)

    @Published var coach = CoachEngine()
    /// 채점 직후 코치가 한 말. 결과 화면 말풍선에 표시된다.
    @Published var coachLine: String?
    /// 무작위 대사 대신 결과 화면에 표시하는 관찰·이유·다음 행동.
    @Published var coachGuidance: CoachGuidance?

    /// 학생이 "여기서부터 갈라졌다" 고 짚은 풀이 단계 (1부터). nil = 아직 선택 안 함.
    /// 이 값이 errorAnalysis.firstErrorStep 후보로 서버에 가고,
    /// 오답노트 복습이 이 단계부터 다시 시작된다.
    @Published var divergenceStep: Int?

    #if DEBUG
    /// 전역 디버그 바의 "Pro" 버튼 → ProScreen 이 결과 화면으로 바로 열리게 하는 플래그
    @Published var debugProReport = false
    #endif

    // MARK: 로그인 게이트의 진실원
    //
    // 로그인 여부는 이 값(UserDefaults "matths.auth")이 결정한다 — 키체인 토큰이 아니다.
    //   nil      = 미로그인 (AuthScreen)
    //   "guest"  = 게스트 (아무것도 서버로 보내지 않는다)
    //   "server" = 서버 계정 (슬롯 acct-<해시>, 키체인에 Bearer 토큰)
    // 키체인 토큰과의 화해 규칙: 토큰은 앱 삭제 후에도 살아남으므로,
    // authProvider != "server" 인데 토큰이 남아 있으면 잘못 남은 것이다 —
    // init 이 폐기한다 (S-02: 재설치 잔존 토큰의 게스트 슬롯 오염 차단).
    @Published var authProvider: String? = UserDefaults.standard.string(forKey: "matths.auth")
    /// 서버가 현재 Bearer 토큰을 거절해 인증 화면으로 돌아온 이유. 일반 로그아웃에는
    /// 표시하지 않고, 새 로그인이 시작되거나 성공하면 지운다.
    @Published private(set) var authenticationNotice: String?
    /// `/api/v1/me`의 서버 정본 프로필. 상단 아바타·Arena 레벨·프로필 화면이
    /// 각자 요청하고 서로 다른 값을 그리지 않도록 앱 수명주기 하나에서 공유한다.
    @Published private(set) var serverProfile: ServerUser?

    @MainActor
    private func applyServerProfile(_ user: ServerUser) {
        serverProfile = user
        if let name = user.name, !name.isEmpty { userName = name }
        if let email = user.email, !email.isEmpty { userEmail = email }
        if let mode = user.coachMode, let level = SpiceLevel(rawValue: mode) {
            coach.level = level
        }
    }

    @MainActor
    func refreshServerProfile() async {
        guard authProvider == "server", ServerAPI.hasToken else {
            serverProfile = nil
            return
        }
        do {
            let user = try await ServerAPI.me()
            guard authProvider == "server" else { return }
            applyServerProfile(user)
        } catch {
            // 401은 공통 요청 계층이 인증 만료로 전환한다. 일시적 네트워크 오류에는
            // 마지막으로 검증된 아바타/레벨을 유지해 상단 UI가 매번 깜빡이지 않게 한다.
        }
    }

    func signIn(provider: String) {
        authenticationNotice = nil
        authProvider = provider
        UserDefaults.standard.set(provider, forKey: "matths.auth")
    }

    func clearAuthenticationNotice() {
        authenticationNotice = nil
    }

    // MARK: 커리큘럼 v2 — 2022 개정 전 과목 (CurriculumV2.swift, 웹 레포 진실원)

    /// v2 진도 — topic 30% + 유형 60% + 완료체크 100% (웹 공식)
    @Published var progressV2: ProgressV2Store = {
        var store = ProgressV2Store.load()
        // 구 진도 1회 이관 (v2 기록이 없는 개념만 — 사용자 데이터 보호)
        store.migrate(fromLegacyCompleted: Progress.load())
        store.save()
        return store
    }()

    /// v2 학습 화면이 보는 개념 id (웹 3계층 id)
    @Published var selectedConceptV2ID: String?
    /// v2 허브에서 펼친 과목 — Split View 전환·앱 재실행 뒤에도 같은 과목을 유지한다.
    @Published var selectedCourseV2ID: String? =
        UserDefaults.standard.string(forKey: AppStore.slotKey("matths.lastCourseV2")) {
        didSet {
            UserDefaults.standard.set(
                selectedCourseV2ID,
                forKey: AppStore.slotKey("matths.lastCourseV2"))
        }
    }
    /// v2 개념에서 시작한 연습 세트 — 유형 다양성 게이트에 정답 유형을 적립한다
    var examSourceConceptV2ID: String?

    func openConceptV2(_ id: String) {
        selectedConceptV2ID = id
        if let (course, _, _) = CurriculumV2.concept(id) {
            selectedCourseV2ID = course.id
        }
        route = .concept
    }

    /// 결과 화면처럼 개념 좌표가 직접 없는 진입도 구 5과목 화면으로 되돌리지 않는다.
    /// 현재 v2 개념을 우선하고, 네이티브 유형이 가리키는 개념, 이어서 학습 순으로 연다.
    func openRelevantConceptV2(typeKey: String? = nil) {
        if let selectedConceptV2ID,
           CurriculumV2.concept(selectedConceptV2ID) != nil {
            openConceptV2(selectedConceptV2ID)
            return
        }

        let rawType = typeKey ?? ""
        let canonicalType = rawType.hasPrefix("web-")
            ? String(rawType.dropFirst(4))
            : rawType
        if ProblemType(rawValue: canonicalType) != nil {
            for course in CurriculumV2.data.courses {
                for unit in course.units {
                    if let concept = unit.concepts.first(where: {
                        $0.practiceTypes.contains(canonicalType)
                    }) {
                        openConceptV2(concept.id)
                        return
                    }
                }
            }
        }

        if let (_, _, concept) = progressV2.continueConcept() {
            openConceptV2(concept.id)
        } else {
            route = .curriculum
        }
    }

    func saveProgressV2() {
        scheduleLearningPersistence(.progress(progressV2.byConcept))
    }

    /// 토픽 체크의 단일 mutation 경계. View가 배열을 먼저 바꾼 뒤 save만 호출하면,
    /// 계정 전환 flush가 source 슬롯을 닫은 짧은 구간에 메모리만 바뀌고 곧 reload되어
    /// 학생의 마지막 탭이 사라질 수 있다. 슬롯 게이트를 mutation보다 먼저 확인하고
    /// snapshot·로컬 이벤트·서버 journal을 같은 호출에서 한 번씩만 만든다.
    func toggleConceptTopic(_ index: Int, concept: ConceptV2) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        let wasCompleted = progressV2.byConcept[concept.id]?
            .completedTopicIndexes.contains(index) == true
        progressV2.toggleTopic(index, concept: concept)
        saveProgressV2()
        let completed = !wasCompleted
        EventLog.append(
            completed ? "topic-completed" : "topic-uncompleted",
            conceptId: concept.id)
        if let (course, unit, _) = CurriculumV2.concept(concept.id) {
            SyncEngine.shared.enqueueTopic(
                courseId: course.id,
                unitId: unit.id,
                conceptId: concept.id,
                topicIndex: index,
                completed: completed)
        }
    }

    private func saveWrongNotes() {
        scheduleLearningPersistence(.wrongNotes(wrongNotes))
    }

    private func saveAttemptsV2() {
        scheduleLearningPersistence(.assessments(attemptsV2.attempts))
    }

    private func saveStuckPoints() {
        scheduleLearningPersistence(.stuckPoints(stuckPoints))
    }

    // MARK: 구 앱 완료 ID 하위 호환 (v2 마이그레이션·과거 평가 기록용)

    @Published var completedConceptIDs: Set<String> = Progress.load()

    /// v2 완료 CTA의 단일 경계. v2 상태·legacy 호환 ID·서버 op를 각각 한 번만 바꾼다.
    /// 호출부에서 먼저 v2를 저장한 뒤 markConceptComplete를 다시 부르면 같은 전체
    /// 스냅샷과 completion op가 두 번 생겨 버튼 반환도 늦고 큐도 중복된다.
    func completeConceptV2(_ concept: ConceptV2) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        progressV2.setUserCompleted(true, concept: concept)
        if let appID = concept.legacy?.appId {
            completedConceptIDs.insert(appID)
            Progress.save(completedConceptIDs)
        }
        saveProgressV2()
        if let (course, unit, _) = CurriculumV2.concept(concept.id) {
            SyncEngine.shared.enqueueConceptCompletion(
                courseId: course.id, unitId: unit.id, conceptId: concept.id)
        }
    }

    func markConceptComplete(_ id: String) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        completedConceptIDs.insert(id)
        Progress.save(completedConceptIDs)
        // v2 화면에서 legacy.appId 호환 기록을 남긴 경우에도 같은 완료를 v2 진도와
        // 서버 큐에 즉시 반영한다. reloadLocalData의 마이그레이션을 기다리지 않아야
        // 같은 세션에서 평가센터 잠금과 다른 기기의 진도가 바로 일치한다.
        guard let (course, unit, concept) = Self.v2Concept(forLegacyAppID: id) else {
            // 매핑 불가 — v2 커리큘럼(curriculum-v2.json)에 legacy.appId 대응이 없는
            // 구 개념이다(개편에서 빠진 id 등). 서버 진도 문서는 v2 id 좌표계라
            // 표현할 주소 자체가 없다. 로컬 구 진도에는 위에서 이미 남겼으므로
            // 학생 화면은 완료로 보인다 — 서버 전송만 건너뛰고 증거를 남긴다.
            NSLog("SYNC-SKIP v2 매핑 없는 개념 완료 — 서버 미전송: %@", id)
            return
        }
        progressV2.setUserCompleted(true, concept: concept)
        saveProgressV2()
        SyncEngine.shared.enqueueConceptCompletion(
            courseId: course.id, unitId: unit.id, conceptId: concept.id)
    }

    /// 구 커리큘럼 개념 id(legacy.appId) → v2 (과목, 단원, 개념) 역매핑.
    /// migrate(fromLegacyCompleted:)·mergeRemoteProgress 가 쓰는 것과 같은
    /// legacy.appId 대응 관계의 역방향이다 — 근거가 갈라지면 안 된다.
    private static func v2Concept(forLegacyAppID appID: String) -> (CourseV2, UnitV2, ConceptV2)? {
        for course in CurriculumV2.data.courses {
            for unit in course.units {
                if let concept = unit.concepts.first(where: { $0.legacy?.appId == appID }) {
                    return (course, unit, concept)
                }
            }
        }
        return nil
    }

    // MARK: 동적 모의고사 — ProblemGenerator 가 기기 안에서 만든다 (AI·서버 불필요)

    @Published var exam: [GeneratedProblem] = []
    @Published var examIndex = 0
    /// 이 회차를 재현할 수 있는 시드. 이의제기·리포트에 그대로 쓴다.
    @Published var lastExamSeed: UInt64 = 0

    var currentProblem: GeneratedProblem? {
        exam.indices.contains(examIndex) ? exam[examIndex] : nil
    }

    /// 새 모의고사 시작. seed 를 안 주면 시각 기반 — 회차마다 수치·정답이 달라진다.
    // MARK: 잠금화면 · 다이나믹 아일랜드
    //
    // WHY 여기인가 — LiveActivityController 는 다 만들어져 있었는데 **프로덕션에서
    // 한 번도 불리지 않았다.** 자가진단(DEBUG)만 건드리고 있어서, 실기기에서는
    // 다이나믹 아일랜드가 영원히 안 떴다. 감독이 "다이나믹 아일랜드 활용도 적극적으로"
    // 라고 지시한 기능이 통째로 죽어 있던 것이다.
    //
    // 배너를 여는 곳은 **세션이 실제로 시작되는 세 곳**(문제 세트·복습·확인 문항)이고,
    // 닫는 곳은 세션이 끝나는 두 곳(정상 종료 advanceExam · 중도 이탈 abandonExam)뿐이다.
    // 화면이 각자 Activity.request 를 부르면 배너가 두 장 쌓이고 다이나믹 아일랜드가
    // minimal 두 칸으로 쪼개져 아무것도 못 읽는다 — 그래서 통로를 하나로 묶는다.

    /// 진행 중인 학습 세션을 잠금화면·다이나믹 아일랜드에 띄운다.
    /// 기기·사용자 설정이 꺼져 있으면 컨트롤러가 조용히 무시한다 — 학습 흐름은 막지 않는다.
    private func beginStudyLiveActivity(title: String, subtitle: String,
                                        deepLink: String = "matths://home") {
        LiveActivityController.startStudySession(
            title: title,
            subtitle: subtitle,
            streakDays: streakDays,
            todayStudyMinutes: EventLog.todayMinutes(),
            solvedCount: 0,
            totalCount: exam.count,
            dueReviewCount: dueReviewCount,
            deepLink: deepLink)
    }

    /// 세트가 진행되는 동안 문항 수를 따라가게 한다. 배너의 진행 막대가 멈춰 있으면
    /// 학생은 배너가 죽었다고 읽는다.
    private func syncLiveActivityProgress() {
        guard LiveActivityController.isRunning else { return }
        LiveActivityController.update { state in
            state.solvedCount = examIndex
            state.totalCount = exam.count
        }
    }

    func startExam(types: [ProblemType], count: Int = 4, seed: UInt64? = nil) {
        let s = seed ?? UInt64(Date().timeIntervalSince1970)
        lastExamSeed = s
        exam = ExamFactory.make(types: types, count: count, seed: s)
        examIndex = 0
        lastGrading = nil
        examSourceConceptV2ID = nil     // 스테일 소스로 남의 개념에 유형이 적립되면 안 된다
        reviewingNoteIDs = nil
        examResults = []
        // 새 세트는 확인 문항이 아니다 — 플래그가 남으면 다음 채점이 통째로 기록되지 않는다.
        // (startVariationCheck 는 이 함수 **뒤에** 다시 세운다)
        pendingReview = nil
        isVariationCheck = false
        examStartedAt = Date()
        solveStartedAt = Date()
        route = .solve
        beginStudyLiveActivity(title: "문제 풀이", subtitle: "\(exam.count)문항")
    }

    /// 이미 만들어진 문항 배열로 시험 시작 (뱅크 시험용)
    func startExam(problems: [GeneratedProblem], seed: UInt64) {
        guard !problems.isEmpty else { return }
        lastExamSeed = seed
        exam = problems
        examIndex = 0
        lastGrading = nil
        examSourceConceptV2ID = nil     // 웹 연습은 호출측이 이 함수 뒤에 다시 세팅한다
        reviewingNoteIDs = nil
        examResults = []
        pendingReview = nil             // 새 세트 — 접어 둔 복습을 잘못 펴지 않게
        isVariationCheck = false
        examStartedAt = Date()
        // 이미 조립된 뱅크/WebGen 문항도 첫 문항부터 풀이 시간을 재야 한다.
        // 이 값이 없으면 첫 문항의 durationMs만 nil로 서버에 올라간다.
        solveStartedAt = examStartedAt
        route = .solve
    }

    /// 오답 복습 시작 — 틀렸던 **바로 그 문제들**을 그대로 다시 낸다.
    /// 수치를 바꾸지 않는 것이 요점이다. 맞히면 간격 전진, 틀리면 처음부터.
    /// ids 를 주면 그 목록으로 좁힌다 — 오답노트에서 필터·검색을 걸어 둔 상태라면
    /// 화면에 보이는 그 집합만 복습해야 한다("(N)" 라벨과 실제 세트가 어긋나던 버그).
    ///
    /// - Parameters:
    ///   - ids: 열 오답의 id. **넘긴 순서가 곧 출제 순서다** (아래 왜-주석 참조).
    ///   - includingMastered: 졸업(복습 완료)한 오답도 포함할지. 기본 false.
    ///     학생이 **한 문제를 콕 집어** 다시 풀겠다고 누른 경우에만 true 로 연다.
    ///
    /// WHY 순서를 호출부에 맡기는가 — 감독 피드백: "코스 마냥 주어진 순서로
    /// 복습하는게 맘에 안들어." 종전 구현은 `Set` 멤버십으로 걸러서 넘긴 배열 순서를
    /// 버리고 `wrongNotes` 의 **적재 순서**(항상 최신 오답 먼저)를 따라갔다. 그래서
    /// 화면에서 "많이 틀린 순"·"기한 임박 순" 으로 정렬해 놓고 복습을 시작해도
    /// 큐는 늘 같은 순서로 나왔다 — 그게 "주어진 순서" 의 실체였다. 이제 화면이 보여
    /// 준 순서가 그대로 출제 순서가 된다.
    func startReview(ids: [String]? = nil, includingMastered: Bool = false) {
        let selected: [WrongNoteEntry]
        if let ids {
            // 호출부가 고른 목록을 **그 순서 그대로** 연다. 오답노트의 "미리 복습"은
            // 아직 예정일이 오지 않은 항목을 넘기므로 여기서 다시 isDue로 거르면 버튼이
            // 아무 일도 하지 않는다. 졸업 항목은 기본적으로 제외해 이미 끝난 복습이
            // 덩어리 복습에 되살아나는 것을 막되, 학생이 한 문제를 지목한 경우
            // (includingMastered)는 연다 — 그때는 "부활" 이 아니라 요청이다.
            let byID = Dictionary(wrongNotes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            selected = ids.compactMap { byID[$0] }
                .filter { includingMastered || !$0.isMastered }
        } else {
            selected = wrongNotes.filter(\.isDue)
        }
        guard !selected.isEmpty else { return }
        exam = selected.map(\.asProblem)
        reviewingNoteIDs = selected.map(\.id)
        examIndex = 0
        lastGrading = nil
        // 복습은 특정 개념의 연습이 아니다. 남겨 두면 직전에 이탈한 개념에
        // 오답 문항의 유형이 적립돼 진도가 부풀고, 세트 종료 후 오답노트가 아니라
        // 그 개념 화면으로 튄다 (startExam 두 진입점과 같은 규약).
        examSourceConceptV2ID = nil
        examResults = []
        pendingReview = nil             // 새 복습 세트 — 접어 둔 옛 세트는 버린다
        isVariationCheck = false
        examStartedAt = Date()
        route = .solve
        beginStudyLiveActivity(title: "오답 복습", subtitle: "\(exam.count)문항",
                               deepLink: "matths://review")
    }

    /// 세션 중도 이탈 — 풀이 화면 좌상단 닫기. 진행 상태를 한 곳에서 정리한다.
    /// exam 만 비우고 소스 id 를 남기면 다음 세션이 그 개념에 결과를 적립한다.
    func abandonExam() {
        let wasExam = !exam.isEmpty
        // 복습에서 나가면 오답노트로 — 정상 종료(advanceExam)와 같은 목적지여야 한다.
        // .assess 로 보내면 복습하러 들어온 학생이 평가센터에 떨어진다.
        // (확인 문항 도중 이탈도 출발지는 복습이므로 pendingReview 를 함께 본다)
        let wasReview = reviewingNoteIDs != nil || pendingReview != nil
        exam = []
        examResults = []
        examIndex = 0
        lastGrading = nil
        divergenceStep = nil
        examSourceConceptV2ID = nil
        reviewingNoteIDs = nil
        pendingReview = nil
        isVariationCheck = false
        // 배너를 안 끝내면 잠금화면에 "학습 중" 이 몇 시간 남는다.
        LiveActivityController.end()
        route = wasReview ? .wrongNotes : (wasExam ? .assess : .concept)
    }

    /// 최종 답만 로컬 대조한다. 풀이 단계 채점은 서버(ai-grader)의 몫이고,
    /// 여기서는 그 결과 계약(GradingResult)에 맞춰 채워 넣는다.
    /// drawingPNG: 풀이 노트 필기 스냅샷 — 틀리면 오답노트에 함께 저장된다.
    func gradeCurrent(input: String, drawingPNG: Data? = nil) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        guard let p = currentProblem else { return }
        lastStudentInput = input          // 결과 화면 "AI에게 묻기" 맥락용
        if let drawingPNG {
            enqueueCheatingReview(
                imageData: drawingPNG,
                source: .practiceDrawing,
                problemID: p.id,
                context: CheatingProblemContext(
                    statement: p.statement,
                    expectedAnswer: p.answer,
                    referenceSteps: p.steps,
                    studentFinalAnswer: input,
                    // 객관식은 최종 답 제출만으로도 정상이라 answer-only 근거를 허용하지 않는다.
                    requiresWork: !p.isMultipleChoice))
        }
        let ok = p.matches(input)
        // 코치는 채점하지 않는다. 정오 결과를 받아 관찰 → 점검 이유 → 다음 행동만 만든다.
        coachGuidance = coach.guidance(
            problem: p,
            studentInput: input,
            correct: ok
        )
        coachLine = nil
        divergenceStep = nil          // 문항마다 새로 짚는다
        // "같은 유형 새 수치" 확인 문항은 **기록 없는 확인**이 규약이다(16차 ②).
        // 여기서 빠져나가지 않으면 확인용 1문항이 새 오답을 만들어(복습이 끝나지 않는다)
        // 유형 게이트·정답률·학습 이벤트까지 확인 문항으로 부풀린다.
        guard !isVariationCheck else {
            lastGrading = makeGrading(p, correct: ok)
            route = .result
            return
        }
        // v2 유형 다양성 게이트 + 정오 신호 (웹 masteryGate·signals)
        if let v2id = examSourceConceptV2ID {
            if ok { progressV2.recordCorrectType(p.typeKey, conceptID: v2id) }
            progressV2.recordAttempt(correct: ok, conceptID: v2id)
            saveProgressV2()
            // 서버에도 같은 사실을 올린다(로컬 우선 — 큐에 쌓고 온라인 때 전송)
            if ok, let (course, unit, _) = CurriculumV2.concept(v2id) {
                SyncEngine.shared.enqueueMastery(courseId: course.id, unitId: unit.id,
                                                 conceptId: v2id, typeKey: p.typeKey)
            }
        }
        SyncEngine.shared.enqueueEvent(ok ? "problem-correct" : "problem-wrong",
                                       conceptId: examSourceConceptV2ID, correct: ok,
                                       durationMs: solveStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) })
        // 학습 이벤트 — 대시보드 주간 통계의 원천
        EventLog.append(ok ? "problem-correct" : "problem-wrong",
                        conceptId: examSourceConceptV2ID,
                        durationMs: solveStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) })
        solveStartedAt = Date()
        // 누적 통계 (프로필 정답률) + 학습일 기록
        solvedTotal += 1
        if ok { correctTotal += 1 }
        UserDefaults.standard.set(solvedTotal, forKey: AppStore.slotKey("matths.solved"))
        UserDefaults.standard.set(correctTotal, forKey: AppStore.slotKey("matths.correct"))
        activityDays = ActivityLog.recordToday()
        examResults.append(ok)

        // ── 오답노트 실동작 ─────────────────────────────────────────────
        if let idx = reviewingNoteIDs?.indices.contains(examIndex) == true
                     ? reviewingNoteIDs?[examIndex] : nil,
           let noteIdx = wrongNotes.firstIndex(where: { $0.id == idx }) {
            // 복습 중 — 간격 전진 또는 리셋. 새 항목은 만들지 않는다(중복 방지).
            if ok { WrongNoteSRS.afterCorrect(&wrongNotes[noteIdx]) }
            else {
                WrongNoteSRS.afterWrong(&wrongNotes[noteIdx])
                // 복습에서 또 틀렸으면 **그때 쓴 답**이 진단의 최신 재료다.
                // 이걸 갱신하지 않으면 AI 진단이 학생 답 없이 모범 풀이만 읽는다.
                // (맞혔을 때는 덮지 않는다 — 진단이 볼 것은 틀렸던 답이다)
                wrongNotes[noteIdx].myAnswer = input
                if let png = drawingPNG {
                    wrongNotes[noteIdx].drawingPNGBase64 = png.base64EncodedString()
                }
            }
            saveWrongNotes()
            // 서버에도 올린다 — 이걸 빠뜨리면 기기를 바꿨을 때 복습 진도가 통째로 되감긴다.
            // (엔드포인트는 있었는데 호출부가 한 곳도 없었다 — 2026-07-29 감사 적발)
            SyncEngine.shared.enqueueReviewResult(wrongNotes[noteIdx], correct: ok)
        } else if !ok {
            // 일반 풀이에서 틀림 — 같은 문항이 이미 있으면 갱신, 없으면 적재
            if let existing = wrongNotes.firstIndex(where: {
                $0.problemID == p.id && $0.typeKey == p.typeKey && !$0.isMastered
            }) {
                WrongNoteSRS.afterWrong(&wrongNotes[existing])
                wrongNotes[existing].myAnswer = input
                if let png = drawingPNG { wrongNotes[existing].drawingPNGBase64 = png.base64EncodedString() }
                // 재오답도 서버에 알린다 — 서버 id 유무에 따라 SyncEngine 이 경로를 고른다.
                // (id 가 없던 새 오답이 조용히 버려지던 구멍을 막는다)
                SyncEngine.shared.enqueueWrongAgain(wrongNotes[existing])
            } else {
                wrongNotes.insert(WrongNoteEntry(
                    id: UUID().uuidString, problemID: p.id, typeKey: p.typeKey,
                    typeName: p.typeName, unit: p.unit, statement: p.statement,
                    answer: p.answer, steps: p.steps, seed: lastExamSeed,
                    divergenceStep: nil,
                    drawingPNGBase64: drawingPNG?.base64EncodedString(),
                    srsStage: 0, nextReviewAt: Date(),   // 최초 복습은 당일
                    wrongCount: 1, createdAt: Date(),
                    // 뱅크 5지선다 문항은 선지·KaTeX 플래그가 있어야 복습 때
                    // 같은 모습(웹뷰 + ①~⑤)으로 재출제된다 — 빠뜨리면 주관식으로 둔갑한다
                    choices: p.choices, isTex: p.needsMathTypesetting,
                    myAnswer: input,         // 진단이 볼 "그때 내가 쓴 답"
                    // 시각 힌트도 함께 — 복습 화면의 그래프 힌트 원천
                    hintText: p.hintText, visualizationJSON: p.visualizationJSON
                ), at: 0)
                if let fresh = wrongNotes.first { SyncEngine.shared.enqueueWrongNote(fresh) }
            }
            saveWrongNotes()
        }
        lastGrading = makeGrading(p, correct: ok)
        route = .result
    }

    /// Pro 시험지 사진 분석이 끝난 뒤 같은 원본을 딱 한 번만 추가 검사한다.
    /// SheetGrader가 만든 문항/정답 맥락을 받되 그 채점 결과 자체는 절대 수정하지 않는다.
    func enqueueSheetCheatingReview(imagePath: String, context: CheatingProblemContext) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: imagePath)), !data.isEmpty else {
            let result = CheatingDetectionResult.inconclusive("시험지 사진 파일을 다시 열지 못했습니다.")
            let begun = CheatingReviewDisk.begin(
                source: .sheetPhoto, problemID: nil, context: context, imageData: Data())
            cheatingReviews.insert(begun.record, at: 0)
            cheatingReviews = CheatingReviewDisk.finish(id: begun.record.id, result: result)
            return
        }
        enqueueCheatingReview(imageData: data, source: .sheetPhoto,
                              problemID: nil, context: context)
    }

    /// GOAT 사진 접수는 60초 안에 먼저 끝낸다. 접수된 원본을 로컬 보관 크기로
    /// 복사한 뒤 사진별 비전 검토를 직렬 실행하고, 결과는 비확정 신호로만 후속 전송한다.
    func enqueueGoatArenaEvidenceReviews(
        fileURLs: [URL],
        matchId: String,
        evidenceId: String,
        clientBuildVersion: String,
        context: CheatingProblemContext
    ) {
        let delivery = GoatArenaCheatingReviewDelivery(
            matchId: matchId,
            evidenceId: evidenceId,
            clientBuildVersion: clientBuildVersion)
        for (index, url) in fileURLs.prefix(5).enumerated() {
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            enqueueCheatingReview(
                imageData: data,
                source: .goatArenaEvidence,
                problemID: "\(matchId):\(index + 1)",
                context: context,
                arenaDelivery: delivery,
                onComplete: goatArenaReviewCompletion(delivery))
        }
    }

    private func goatArenaReviewCompletion(
        _ delivery: GoatArenaCheatingReviewDelivery
    ) -> (UUID, CheatingDetectionResult) -> Void {
        { reviewId, result in
            GoatArenaClientReviewOutbox.enqueue(
                GoatArenaClientReviewOutbox.item(
                    reviewId: reviewId,
                    result: result,
                    delivery: delivery))
            Task { await GoatArenaClientReviewOutbox.flush() }
        }
    }

    func latestCheatingReview(problemID: String? = nil,
                              source: CheatingReviewSource? = nil) -> CheatingReviewRecord? {
        cheatingReviews.first {
            (problemID == nil || $0.problemID == problemID)
                && (source == nil || $0.source == source)
        }
    }

    private func enqueueCheatingReview(imageData: Data,
                                       source: CheatingReviewSource,
                                       problemID: String?,
                                       context: CheatingProblemContext,
                                       arenaDelivery: GoatArenaCheatingReviewDelivery? = nil,
                                       onComplete: ((UUID, CheatingDetectionResult) -> Void)? = nil) {
        let begun = CheatingReviewDisk.begin(
            source: source, problemID: problemID, context: context,
            imageData: imageData, arenaDelivery: arenaDelivery)
        cheatingReviews.removeAll { $0.id == begun.record.id }
        cheatingReviews.insert(begun.record, at: 0)

        guard let imagePath = begun.imagePath else {
            let result = CheatingDetectionResult.inconclusive(
                "풀이 이미지를 검토용 크기로 준비하지 못했습니다.")
            cheatingReviews = CheatingReviewDisk.finish(
                id: begun.record.id,
                result: result)
            onComplete?(begun.record.id, result)
            return
        }

        startCheatingReview(
            record: begun.record,
            imagePath: imagePath,
            context: context,
            onComplete: onComplete)
    }

    private func startCheatingReview(
        record: CheatingReviewRecord,
        imagePath: String,
        context: CheatingProblemContext,
        onComplete: ((UUID, CheatingDetectionResult) -> Void)?
    ) {
        guard cheatingReviewTasks[record.id] == nil else { return }

        let flag = CheatingDetectionCancelFlag()
        cheatingReviewFlags[record.id] = flag
        let predecessor = cheatingReviewQueueTail
        let task = Task { [weak self] in
            // 앞 검토의 모델 전환·추론·정리가 전부 끝난 뒤 다음 사진을 연다.
            await predecessor?.value
            let backgroundToken = LocalAIBackgroundExecution.shared.beginWork("풀이 무결성 검토")
            defer { LocalAIBackgroundExecution.shared.endWork(backgroundToken) }
            guard let self else { return }
            let result = await self.runCheatingReview(
                imagePath: imagePath, context: context, cancel: flag)
            guard !flag.isCancelled else { return }
            self.cheatingReviews = CheatingReviewDisk.finish(id: record.id, result: result)
            onComplete?(record.id, result)
            self.cheatingReviewFlags.removeValue(forKey: record.id)
            self.cheatingReviewTasks.removeValue(forKey: record.id)
            if self.cheatingReviewTasks.isEmpty {
                self.cheatingReviewQueueTail = nil
            }
        }
        cheatingReviewTasks[record.id] = task
        cheatingReviewQueueTail = task
    }

    private func resumePendingGoatArenaCheatingReviews() {
        for record in cheatingReviews where record.state == .pending &&
            record.source == .goatArenaEvidence {
            guard let context = record.problemContext,
                  let delivery = record.arenaDelivery,
                  let imagePath = CheatingReviewDisk.imageURL(for: record)?.path,
                  FileManager.default.fileExists(atPath: imagePath)
            else {
                cheatingReviews = CheatingReviewDisk.finish(
                    id: record.id,
                    result: .inconclusive("재시작할 로컬 검토 자료를 찾지 못했습니다."))
                continue
            }
            startCheatingReview(
                record: record,
                imagePath: imagePath,
                context: context,
                onComplete: goatArenaReviewCompletion(delivery))
        }
    }

    private func runCheatingReview(imagePath: String,
                                   context: CheatingProblemContext,
                                   cancel: CheatingDetectionCancelFlag) async -> CheatingDetectionResult {
        if cancel.isCancelled || Task.isCancelled {
            return .inconclusive("로컬 판정이 중단되었습니다.")
        }

        // 모델 파일 다운로드·해시는 LLMEngine을 쓰지 않는다. 낮은 우선순위 검토가
        // 이 준비 시간까지 lease를 쥐면, 첫 다운로드 동안 학생이 기다리는 채점·튜터가
        // 대기열 우선순위와 무관하게 전부 막힌다. 준비가 끝난 뒤에만 엔진을 소유한다.
        do {
            try await LocalAIModelPack.shared.prepareForSheetAnalysis()
        } catch {
            #if DEBUG
            print("무결성 검토 모델 준비 실패:", error)
            #endif
            return .inconclusive("사진 판독 모델을 준비하지 못했습니다. 제출된 원본은 그대로 보관되며 다음 실행에서 다시 확인합니다.")
        }
        if cancel.isCancelled || Task.isCancelled {
            return .inconclusive("로컬 판정이 중단되었습니다.")
        }

        let workLease: LocalAIWorkCoordinator.Lease
        do {
            // 후속 검토는 학생이 기다리는 채점·튜터보다 낮은 우선순위로 기다린다.
            // 바쁘다는 이유만으로 영구 판정불가 처리하지 않는다.
            workLease = try await LocalAIWorkCoordinator.shared.acquire(.integrityReview)
        } catch is CancellationError {
            return .inconclusive("로컬 판정이 중단되었습니다.")
        } catch {
            return .inconclusive("로컬 판정 순서를 준비하지 못했습니다.")
        }

        let result = await runCheatingReviewWithLease(
            imagePath: imagePath,
            context: context,
            cancel: cancel)
        await LocalAIWorkCoordinator.shared.release(workLease)
        return result
    }

    private func runCheatingReviewWithLease(
        imagePath: String,
        context: CheatingProblemContext,
        cancel: CheatingDetectionCancelFlag
    ) async -> CheatingDetectionResult {
        let tutor = AITutor.shared
        if cancel.isCancelled || Task.isCancelled {
            return .inconclusive("로컬 판정이 중단되었습니다.")
        }

        let visionFile = ModelDownloader.analysisVisionSpec.file
        guard await tutor.switchModel(toFile: visionFile), tutor.visionAvailable else {
            return .inconclusive("현재 기기에서 사진 판독 모델을 열지 못했습니다.")
        }
        return await tutor.inspectCheating(
            imagePath: imagePath, context: context, cancel: cancel)
    }

    private func interruptCheatingReviews(reason: String) {
        guard !cheatingReviewFlags.isEmpty || cheatingReviews.contains(where: { $0.state == .pending })
        else { return }
        for flag in cheatingReviewFlags.values { flag.cancel() }
        for task in cheatingReviewTasks.values { task.cancel() }
        cheatingReviewFlags.removeAll()
        cheatingReviewTasks.removeAll()
        cheatingReviewQueueTail = nil
        cheatingReviews = CheatingReviewDisk.interruptPending(reason: reason)
    }

    /// 채점 결과 계약 채우기. 확인 문항도 같은 결과 화면을 쓰므로,
    /// "기록하는 일" 과 "보여 주는 일" 을 갈라 놓고 보여 주는 쪽은 한 곳에서만 만든다.
    ///
    /// **단계 코멘트를 비우는 이유.** 이 채점은 최종 답 하나만 맞춰 본 것이라 단계별로
    /// 아는 것이 없다. 그런데 종전에는 모든 단계에 같은 문장을 넣어서, 결과 화면
    /// '단계별 채점' 이 똑같은 회색 줄을 단계 수만큼(실측 5회) 반복해 보여 줬다 —
    /// 감독이 지적한 "이미 나온 텍스트 또 보여주기" 와 같은 부류다. 게다가 그 문장은
    /// 바로 아래 피드백 카드가 이미 한 번 하는 말이다("아래 모범 풀이의 단계와 본인
    /// 풀이가 어디서 갈라지는지 찾아보세요"). 그래서 반복은 지우고 안내는 피드백 카드
    /// 한 곳에만 둔다. 단계별 판정 자체는 원문자 색과 아이콘(체크·마이너스)이 계속
    /// 나르므로 색만으로 말하는 화면이 되지도 않는다.
    /// 없는 단계 판정을 지어내지 않는다 — 서버 채점이 붙으면 그때 진짜 코멘트가 들어온다.
    private func makeGrading(_ p: GeneratedProblem, correct ok: Bool) -> GradingResult {
        GradingResult(
            overall: ok ? .correct : .incorrect,
            firstErrorStep: nil,
            errorType: .none,
            stepResults: p.steps.enumerated().map { i, _ in
                StepResult(step: i + 1,
                           verdict: ok ? .correct : .unverifiable,
                           comment: "",
                           errorType: nil)
            },
            awardedPoints: ok ? 4 : 0,
            feedback: ok
                ? "정답입니다. 같은 유형이 GOAT Arena에 다른 수치로 다시 나옵니다."
                : "정답이 아닙니다. 아래 모범 풀이의 단계와 본인 풀이가 어디서 갈라지는지 찾아보세요.",
            confidence: 1.0,
            needsHumanReview: false
        )
    }

    /// 다음 문항으로. 마지막이면:
    ///  개념에서 온 세트 → 그 개념을 완료 처리하고 커리큘럼으로 (진도가 나간다)
    ///  복습 세트       → 오답노트로
    ///  평가센터 세트   → 평가센터로
    func advanceExam() {
        if examIndex + 1 < exam.count {
            examIndex += 1
            route = .solve
            // 배너의 진행 막대가 멈춰 있으면 학생은 배너가 죽었다고 읽는다.
            syncLiveActivityProgress()
        } else {
            // 확인 문항이 끝났다 — 기록을 남기지 않는 것이 규약이므로 최고 기록 갱신
            // **전에** 빠져나가고(1문항 100점이 최고 기록으로 남으면 안 된다),
            // 접어 뒀던 복습 세트를 그대로 펴서 원래 자리에서 이어 푼다.
            if isVariationCheck {
                isVariationCheck = false
                guard let saved = pendingReview else {
                    // 복습 밖에서 시작된 확인 문항 — 조용히 오답노트로
                    exam = []
                    examIndex = 0
                    examResults = []
                    route = .wrongNotes
                    return
                }
                pendingReview = nil
                exam = saved.exam
                examIndex = saved.index
                reviewingNoteIDs = saved.noteIDs
                examResults = saved.results
                examStartedAt = saved.startedAt
                lastExamSeed = saved.seed
                solveStartedAt = Date()     // 확인 문항에 쓴 시간이 다음 복습 문항의 풀이시간이 되면 안 된다
                // 확인하러 새지 않고 "다음" 을 눌렀을 때와 똑같이 이어간다.
                // (isVariationCheck 를 이미 내렸으므로 재귀는 여기서 한 번뿐이다)
                advanceExam()
                return
            }

            // 시험 기록 — 점수(백분율)와 소요 시간. 랭킹 "내 기록" 의 근거.
            if !examResults.isEmpty {
                let score = Int((Double(examResults.filter { $0 }.count)
                                 / Double(examResults.count) * 100).rounded())
                let elapsed = examStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
                if score > bestScore || (score == bestScore && elapsed < bestElapsedMs) {
                    bestScore = score
                    bestElapsedMs = elapsed
                    UserDefaults.standard.set(score, forKey: AppStore.slotKey("matths.bestScore"))
                    UserDefaults.standard.set(elapsed, forKey: AppStore.slotKey("matths.bestMs"))
                }
            }

            let wasReview = reviewingNoteIDs != nil
            exam = []
            reviewingNoteIDs = nil
            // 세트 종료 — 잠깐 남겨 결과를 보여 주고 사라진다(linger).
            LiveActivityController.end(linger: 8)
            if examSourceConceptV2ID != nil {
                // v2 연습 세트 — 자동 완료 없음(유형 게이트가 완료를 다스린다).
                // 개념 화면으로 돌아가 적립된 유형·진도%를 보여준다.
                examSourceConceptV2ID = nil
                route = .concept
            } else {
                route = wasReview ? .wrongNotes : .assess
            }
        }
    }

    // MARK: 평가 v2 — 웹 규칙 시험지 (AssessmentV2.swift)

    @Published var attemptsV2: AttemptStoreV2 = .load()
    @Published var currentAttemptID: String?
    @Published var assessmentSyncError: String?
    @Published private(set) var assessmentSubmitting = false
    private var assessmentStartGeneration = UUID()
    private var assessmentDraftTask: Task<Void, Never>?
    /// 로컬 제출의 wrongNotes→assessment 내구 순서가 끝나기 전 stable flush가
    /// 미공개 옛 메모리로 두 파일을 되감지 못하게 하는 짧은 직렬화 게이트.
    private var assessmentPersistenceTransactionInFlight = false

    var currentAttempt: AssessmentAttemptV2? {
        currentAttemptID.flatMap { id in attemptsV2.attempts.first { $0.id == id } }
    }

    /// 시험지 시작 — 문항을 확정 저장하고(웹 AssessmentAttempt) 응시 화면으로.
    func startPaper(scope: PaperScope, course: AssessCourse,
                    unit: AssessUnit? = nil, subunit: AssessSubunit? = nil) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        if ServerAPI.hasToken {
            let generation = UUID()
            assessmentStartGeneration = generation
            let account = captureAccountSessionBoundary()
            assessmentSyncError = nil
            Task { [weak self] in
                await self?.startServerPaper(
                    scope: scope, course: course, unit: unit, subunit: subunit,
                    generation: generation, account: account)
            }
            return
        }
        startLocalPaper(scope: scope, course: course, unit: unit, subunit: subunit)
    }

    private func startLocalPaper(scope: PaperScope, course: AssessCourse,
                                 unit: AssessUnit? = nil, subunit: AssessSubunit? = nil) {
        let scopeKey = "\(scope.rawValue)/\(course.courseId)/\(unit?.unitId ?? "-")/\(subunit?.id ?? "-")"
        // 평가센터가 "진행 중"이라고 표시한 회차는 새로 뽑지 말고 실제 저장 답안으로
        // 돌아간다. 종전에는 같은 CTA가 매번 새 AssessmentAttempt를 만들어
        // "이어서 응시"가 사실상 데이터 유실 버튼이었다.
        if let open = attemptsV2.openAttempt(scopeKey: scopeKey) {
            currentAttemptID = open.id
            route = .paper
            return
        }
        let title: String
        switch scope {
        case .subunit: title = "“\(subunit?.title ?? "")” 중간평가"
        case .unit:    title = "“\(unit?.title ?? "")” 기말평가"
        case .course:  title = "“\(course.title)” 과목 종합평가"
        }
        // 심화 템플릿의 스테이지 선택 근거 — 이 과목의 완료 개념 (웹 learnedConceptIds)
        let learned = CurriculumV2.course(course.courseId)?.allConcepts
            .filter { progressV2.percent(for: $0) >= 100 }.map(\.id) ?? []
        let questions = PaperFactory.make(
            scope: scope, course: course, unit: unit, subunit: subunit,
            seed: UInt64(Date().timeIntervalSince1970),
            avoid: attemptsV2.avoidedTypeKeys(scopeKey: scopeKey),
            learned: learned)
        guard !questions.isEmpty else { return }
        let attempt = AssessmentAttemptV2(
            id: UUID().uuidString, scope: scope, courseId: course.courseId,
            unitId: unit?.unitId, subunitId: subunit?.id, title: title,
            questions: questions, answers: Array(repeating: "", count: questions.count),
            submittedAt: nil, scorePercent: nil, passed: nil, createdAt: Date(),
            // 제한 시간을 **시작할 때 박아 둔다** — 레포와 같은 값(10/30/60분).
            timeLimitMs: AssessTimeLimit.ms(for: scope.rawValue), disqualified: false)
        attemptsV2.upsert(attempt)
        requestImmediateLearningPersistence(.assessments(attemptsV2.attempts))
        currentAttemptID = attempt.id
        route = .paper
    }

    private func startServerPaper(scope: PaperScope, course: AssessCourse,
                                  unit: AssessUnit?, subunit: AssessSubunit?,
                                  generation: UUID,
                                  account: AccountSessionBoundary) async {
        do {
            let remote = try await ServerAPI.startAssessment(
                scope: scope, courseId: course.courseId, unitId: unit?.unitId,
                subunitId: subunit?.id, clientStartId: generation.uuidString)
            guard generation == assessmentStartGeneration,
                  isLearningAccountOperationActive(for: account),
                  let attempt = remote.localValue() else { return }
            attemptsV2.upsert(attempt)
            let persisted = await persistLearningImmediately(
                .assessments(attemptsV2.attempts), for: account.slot)
            guard generation == assessmentStartGeneration,
                  isLearningAccountOperationActive(for: account) else { return }
            if !persisted {
                assessmentSyncError = "평가 시작 기록을 이 기기에 저장하지 못했습니다. 저장 공간을 확인해주세요."
            }
            currentAttemptID = attempt.id
            route = .paper
        } catch {
            guard generation == assessmentStartGeneration,
                  isLearningAccountOperationActive(for: account) else { return }
            assessmentSyncError = (error as? ServerAPIError)?.errorDescription
                ?? "평가를 시작하지 못했습니다. 연결을 확인하고 다시 시도해주세요."
        }
    }

    func pullServerAssessments() async {
        guard ServerAPI.hasToken else { return }
        let account = captureAccountSessionBoundary()
        do {
            let values = try await ServerAPI.assessmentSnapshot().compactMap { $0.localValue() }
            guard isLearningAccountOperationActive(for: account) else { return }
            attemptsV2.replaceServerSnapshot(values)
            let persisted = await persistLearningImmediately(
                .assessments(attemptsV2.attempts), for: account.slot)
            guard isLearningAccountOperationActive(for: account) else { return }
            if !persisted {
                assessmentSyncError = "동기화한 평가 기록을 이 기기에 저장하지 못했습니다."
            }
            objectWillChange.send()
        } catch {
            guard isLearningAccountOperationActive(for: account) else { return }
            assessmentSyncError = (error as? ServerAPIError)?.errorDescription
                ?? "평가 기록을 동기화하지 못했습니다."
        }
    }

    func setPaperAnswer(no: Int, value: String) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        guard var a = currentAttempt, a.submittedAt == nil,
              no >= 1 && no <= a.answers.count else { return }
        a.answers[no - 1] = value
        attemptsV2.upsert(a)
        saveAttemptsV2()
        if a.serverBacked == true { scheduleAssessmentDraft(a) }
    }

    private func scheduleAssessmentDraft(_ attempt: AssessmentAttemptV2) {
        assessmentDraftTask?.cancel()
        let account = captureAccountSessionBoundary()
        assessmentDraftTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled,
                  self?.isLearningAccountOperationActive(for: account) == true else { return }
            do {
                try await ServerAPI.saveAssessmentDraft(
                    id: attempt.id, answers: AssessmentSyncPayload.answers(for: attempt))
            } catch {
                guard self?.isLearningAccountOperationActive(for: account) == true else { return }
                self?.assessmentSyncError = (error as? ServerAPIError)?.errorDescription
                    ?? "평가 답안을 서버에 저장하지 못했습니다. 기기에는 보관했습니다."
            }
        }
    }

    func flushAssessmentDraft() async {
        assessmentDraftTask?.cancel()
        let account = captureAccountSessionBoundary()
        let attempt = currentAttempt
        let persisted = await persistLearningImmediately(
            .assessments(attemptsV2.attempts), for: account.slot)
        guard isLearningAccountOperationActive(for: account) else { return }
        if !persisted {
            assessmentSyncError = "마지막 답안을 이 기기에 저장하지 못했습니다. 저장 공간을 확인해주세요."
        }
        guard let attempt, attempt.submittedAt == nil,
              attempt.serverBacked == true else { return }
        // 화면 이탈은 위 로컬 내구 저장까지만 기다린다. 네트워크 왕복 때문에 닫기
        // 버튼이 멈추지 않도록 서버 flush는 종전처럼 별도 Task에서 이어 간다.
        Task { [weak self] in
            guard self?.isLearningAccountOperationActive(for: account) == true else { return }
            do {
                try await ServerAPI.saveAssessmentDraft(
                    id: attempt.id, answers: AssessmentSyncPayload.answers(for: attempt))
            } catch {
                guard self?.isLearningAccountOperationActive(for: account) == true else { return }
                self?.assessmentSyncError = (error as? ServerAPIError)?.errorDescription
                    ?? "평가 답안을 서버에 저장하지 못했습니다. 기기에는 보관했습니다."
            }
        }
    }

    /// 제출 — 웹 규칙: 균등 배점 100점, PASS 80. 오답은 오답노트에도 적재(앱 강점 유지).
    /// 시험 제출.
    ///
    /// `monotonicElapsed` 는 ExamTimer 가 잰 단조 경과(초). 기기 시각 조작을
    /// 막기 위해 월클럭과 함께 본다 — 자세한 이유는 `remainingSeconds` 주석.
    func submitPaper(monotonicElapsed: TimeInterval = 0) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        guard let current = currentAttempt, current.submittedAt == nil else { return }
        let account = captureAccountSessionBoundary()
        if current.serverBacked == true, ServerAPI.hasToken {
            guard !assessmentSubmitting else { return }
            assessmentSubmitting = true
            assessmentDraftTask?.cancel()
            Task { [weak self] in
                await self?.submitServerPaper(
                    current, monotonicElapsed: monotonicElapsed, account: account)
            }
            return
        }
        guard !assessmentSubmitting else { return }
        assessmentSubmitting = true
        assessmentDraftTask?.cancel()
        Task { [weak self] in
            await self?.submitLocalPaper(
                monotonicElapsed: monotonicElapsed, account: account)
        }
    }

    private func submitServerPaper(_ attempt: AssessmentAttemptV2,
                                   monotonicElapsed: TimeInterval,
                                   account: AccountSessionBoundary) async {
        defer {
            if ownsCurrentAccountSession(account) { assessmentSubmitting = false }
        }
        do {
            let payload = AssessmentSyncPayload.answers(for: attempt)
            let remote: ServerAPI.RemoteAssessment
            if attempt.remainingSeconds(monotonicElapsed: monotonicElapsed) <= 0 {
                remote = try await ServerAPI.expireAssessment(id: attempt.id, answers: payload)
            } else {
                remote = try await ServerAPI.submitAssessment(id: attempt.id, answers: payload)
            }
            guard isLearningAccountOperationActive(for: account),
                  let updated = remote.localValue() else { return }
            attemptsV2.upsert(updated)
            let persisted = await persistLearningImmediately(
                .assessments(attemptsV2.attempts), for: account.slot)
            guard isLearningAccountOperationActive(for: account) else { return }
            if !persisted {
                assessmentSyncError = "서버 제출은 완료됐지만 이 기기의 평가 기록 저장에 실패했습니다."
            } else {
                assessmentSyncError = nil
            }
            currentAttemptID = updated.id
            await SyncEngine.shared.pullWrongNotes()
        } catch {
            guard isLearningAccountOperationActive(for: account) else { return }
            assessmentSyncError = (error as? ServerAPIError)?.errorDescription
                ?? "평가를 제출하지 못했습니다. 답안은 기기에 보관되어 있습니다."
        }
    }

    private func submitLocalPaper(
        monotonicElapsed: TimeInterval = 0,
        account: AccountSessionBoundary
    ) async {
        defer {
            if ownsCurrentAccountSession(account) { assessmentSubmitting = false }
        }
        guard isLearningAccountOperationActive(for: account) else { return }
        guard var a = currentAttempt, a.submittedAt == nil else { return }
        assessmentPersistenceTransactionInFlight = true
        defer { assessmentPersistenceTransactionInFlight = false }

        // **시간이 지났으면 0점 실격이다.** 레포는 이때 status="disqualified",
        // reason="time-limit", earnedPoints=0 으로 저장한다. 앱에는 이 처리가
        // 아예 없어서, 몇 시간이 걸려도 정상 점수가 나왔다 —
        // 같은 시험을 앱에서 보는 쪽이 더 유리했다.
        if a.remainingSeconds(monotonicElapsed: monotonicElapsed) <= 0 {
            a.disqualified = true
            a.scorePercent = 0
            a.passed = false
            a.submittedAt = Date()
            var updatedAttempts = attemptsV2
            updatedAttempts.upsert(a)
            let persisted = await persistLearningImmediately(
                .assessments(updatedAttempts.attempts), for: account.slot)
            guard ownsLocalAssessmentPersistenceTransaction(account) else { return }
            guard persisted else {
                assessmentSyncError = "시간 초과 결과를 이 기기에 저장하지 못했습니다."
                return
            }
            attemptsV2 = updatedAttempts
            assessmentSyncError = nil
            return
        }

        let result = PaperFactory.grade(questions: a.questions, answers: a.answers)
        a.scorePercent = result.scorePercent
        a.passed = result.scorePercent >= AssessCatalog.data.passScore
        a.submittedAt = Date()

        // 제출 완료 회차를 먼저 저장한 뒤 오답을 debounce하면, 그 150ms 사이 종료 시
        // 재제출은 막혔는데 파생 오답은 없는 복구 불가능 상태가 된다. 메모리를 아직
        // 공개하지 않은 값 스냅샷으로 둘 다 만들고, 재생성 가능한 assessment보다
        // 오답 정본을 먼저 내구 저장한다.
        var updatedAttempts = attemptsV2
        updatedAttempts.upsert(a)
        var updatedWrongNotes = wrongNotes
        var wrongNotesToSync: [WrongNoteEntry] = []
        for (i, q) in a.questions.enumerated() where !result.verdicts[i] {
            let pid = "paper-\(a.id)-\(q.no)"
            if let existing = updatedWrongNotes.firstIndex(where: { $0.problemID == pid }) {
                // 첫 제출에서 오답 파일은 성공하고 assessment 파일만 실패했을 수 있다.
                // 재시도 때 기존 problemID를 건너뛰더라도 아직 서버 id가 없는 항목은
                // 성공 경계 뒤 멱등 큐에 다시 태워야 영구 로컬 전용으로 남지 않는다.
                if updatedWrongNotes[existing].serverAttemptId == nil {
                    wrongNotesToSync.append(updatedWrongNotes[existing])
                }
                continue
            }
            let note = WrongNoteEntry(
                id: UUID().uuidString, problemID: pid, typeKey: q.typeKey,
                typeName: a.title, unit: "평가 \(a.title)",
                statement: q.prompt, answer: q.answer,
                // 해설이 비어 있으면 "평가 결과 화면에서 보라" 고 안내했었는데, 제출한
                // 시험지를 다시 여는 진입점이 앱에 없다 — 도달 못 하는 화면을 가리키는
                // 안내는 없느니만 못하다. 없는 것은 없다고 말한다 (2026-07-29 감사 적발).
                steps: q.solution.isEmpty
                    ? ["이 문항은 모범 풀이가 제공되지 않습니다. 정답과 대조하며 풀이를 다시 확인해 보세요."]
                    : [q.solution],
                seed: 0, divergenceStep: nil, drawingPNGBase64: nil,
                srsStage: 0, nextReviewAt: Date(), wrongCount: 1, createdAt: Date(),
                choices: q.choices, isTex: true)
            updatedWrongNotes.insert(note, at: 0)
            wrongNotesToSync.append(note)
        }

        let wrongNotesPersisted = await persistLearningImmediately(
            .wrongNotes(updatedWrongNotes), for: account.slot)
        guard ownsLocalAssessmentPersistenceTransaction(account) else { return }
        guard wrongNotesPersisted else {
            assessmentSyncError = "평가 오답을 이 기기에 저장하지 못해 제출을 완료하지 않았습니다."
            return
        }
        let assessmentPersisted = await persistLearningImmediately(
            .assessments(updatedAttempts.attempts), for: account.slot)
        guard ownsLocalAssessmentPersistenceTransaction(account) else { return }
        guard assessmentPersisted else {
            // 오답 파일은 이미 안전하다. 메모리에도 같은 값을 유지해 같은 실행에서
            // 재시도할 때 problemID 중복 방지가 작동하게 하고, 회차만 미제출로 둔다.
            wrongNotes = updatedWrongNotes
            assessmentSyncError = "평가 결과를 이 기기에 저장하지 못해 제출을 완료하지 않았습니다."
            objectWillChange.send()
            return
        }

        attemptsV2 = updatedAttempts
        wrongNotes = updatedWrongNotes
        assessmentSyncError = nil

        let correctCount = result.verdicts.filter { $0 }.count
        let elapsedMs = monotonicElapsed > 0
            ? Int((monotonicElapsed * 1_000).rounded()) : nil
        EventLog.appendGrading(
            correct: correctCount,
            total: a.questions.count,
            durationMs: elapsedMs)
        SyncEngine.shared.enqueueGradingEvents(
            correct: correctCount,
            total: a.questions.count,
            durationMs: elapsedMs)
        solvedTotal += a.questions.count
        correctTotal += correctCount
        UserDefaults.standard.set(solvedTotal, forKey: AppStore.slotKey("matths.solved"))
        UserDefaults.standard.set(correctTotal, forKey: AppStore.slotKey("matths.correct"))
        activityDays = ActivityLog.recordToday()

        for note in wrongNotesToSync {
            // 평가 오답도 서버로 올린다. 이 한 줄이 없어서 로그인 이후 생긴 평가
            // 오답만 영영 안 올라갔다 — 기출 경로에서 이미 같은 구멍을 메웠는데
            // 평가 경로에만 남아 있었다(2026-07-29 감사 적발).
            SyncEngine.shared.enqueueWrongNote(note)
        }
        // 제출된 회차는 submittedAt 때문에 재실행에서 다시 side effect를 만들 수 없다.
        // 따라서 일반 학습 debounce와 달리, 로컬 대시보드 이벤트와 서버 outbox도 이
        // 제출 트랜잭션에서 actor disk ack까지 닫는다. UI는 위 Published assignment로
        // 이미 리뷰 모드가 됐고, JSON/FileHandle 작업만 별도 writer에서 진행된다.
        let eventsPersisted = await EventLog.flushPendingWrites(for: account.slot)
        let syncQueuePersisted = await SyncEngine.shared.flushLocalQueuePersistence()
        guard ownsLocalAssessmentPersistenceTransaction(account) else { return }
        if !(eventsPersisted && syncQueuePersisted) {
            assessmentSyncError = "평가 결과는 저장했지만 활동·동기화 기록을 안전하게 보관하지 못했습니다. 저장 공간을 확인해주세요."
        }
        objectWillChange.send()
    }

    /// 과목 종합평가 통과 여부 — 진도 95% 캡의 근거 (웹 applyAssessmentGates)
    func coursePassedV2(_ webCourseID: String) -> Bool {
        attemptsV2.passed(scopeKey: "course/\(webCourseID)/-/-")
    }

    /// 표시용 과목 진도 — 개념을 다 끝내도 종합평가 미통과면 95 에서 멈춘다
    func displayCoursePercent(_ course: CourseV2) -> Int {
        let p = progressV2.coursePercent(course)
        if p >= 100 && AssessCatalog.course(course.id) != nil && !coursePassedV2(course.id) {
            return 95
        }
        return p
    }

    // MARK: 기출 (KICE) — 3개년 수능 실전 문제지 (KiceBank.swift)

    /// 응시 중인 기출 시험 id
    @Published var kiceExamID: String?
    /// 시험별 입력 답안 (examID → "구간-문항" → 입력). 나갔다 돌아와도 유지된다.
    @Published var kiceAnswers: [String: [String: String]] = [:]
    /// 시험별 선택과목 (examID → 과목명)
    @Published var kiceSubject: [String: String] = [:]

    var kiceExam: KiceExam? {
        kiceExamID.flatMap { id in KiceBank.exams.first { $0.id == id } }
    }

    func startKice(_ exam: KiceExam) {
        kiceExamID = exam.id
        route = .kice
    }

    // MARK: 오늘의 학습 계획 (웹 DailyPlan — 로컬 생성)

    @Published var dailyPlan: DailyPlanV1?

    /// 오늘 계획 로드/생성 — 복습 due → 이어서 학습 → 유형 게이트 순으로 최대 3개
    func ensureDailyPlan() {
        let key = ActivityLog.dayString()
        if let existing = dailyPlan, existing.dateKey == key { return }
        if let saved = DailyPlanStore.load(dateKey: key) { dailyPlan = saved; return }

        var tasks: [DailyPlanTask] = []
        if dueReviewCount > 0 {
            tasks.append(DailyPlanTask(id: "review", kind: "review",
                title: "오답 \(dueReviewCount)문항 복습", estimatedMinutes: dueReviewCount * 4, done: false))
        }
        if let (course, _, con) = progressV2.continueConcept() {
            tasks.append(DailyPlanTask(id: "concept-\(con.id)", kind: "concept",
                title: "\(course.title) \(con.title) 학습",
                estimatedMinutes: con.lesson?.estimatedMinutes ?? 15, done: false))
            let required = progressV2.requiredDistinctTypes(for: con)
            let got = progressV2.byConcept[con.id]?.correctTypeIds.count ?? 0
            if required > 0 && got < required {
                tasks.append(DailyPlanTask(id: "practice-\(con.id)", kind: "practice",
                    title: "유형 게이트 채우기 (\(got)/\(required))", estimatedMinutes: 10, done: false))
            }
        }
        let plan = DailyPlanV1(dateKey: key, tasks: tasks)
        dailyPlan = plan
        DailyPlanStore.save(plan)
    }

    func togglePlanTask(_ id: String) {
        guard var plan = dailyPlan,
              let i = plan.tasks.firstIndex(where: { $0.id == id }) else { return }
        plan.tasks[i].done.toggle()
        dailyPlan = plan
        DailyPlanStore.save(plan)
    }

    /// 웹 로컬 생성기 연습 — 네이티브 유형이 없는 개념의 STEP04 (웹 practiceService)
    func startWebPractice(_ concept: ConceptV2) {
        guard let (course, unit, _) = CurriculumV2.concept(concept.id) else { return }
        let seed = UInt64(Date().timeIntervalSince1970 * 1_000)
        let problems = WebGen.practiceProblems(
            courseId: course.id, unitId: unit.id, conceptId: concept.id,
            count: 5, seed: seed,
            includeCurriculumChecks: true)
        guard !problems.isEmpty else { return }
        // 문항을 만든 시드와 오답·이의제기에 기록할 시드는 반드시 같아야 한다.
        // 직전 세션의 lastExamSeed를 넘기면 재현 시 전혀 다른 문제가 생성된다.
        startExam(problems: problems, seed: seed)
        examSourceConceptV2ID = concept.id      // startExam 이 초기화하므로 반드시 뒤에
    }

    /// 기출 채점 후 실데이터 반영 — 누적 통계·학습일·최고점·오답노트 적재.
    /// 오답노트 항목은 문제 본문 대신 "문제지 PDF 로 다시 풀라" 는 지시문을 담는다
    /// (기출 발제문은 저작물이라 앱 텍스트로 복제하지 않는다).
    func recordKice(exam: KiceExam, score: Int, correct: Int, total: Int,
                    elapsedMs: Int,
                    wrong: [(KiceItem, String, String)]) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        EventLog.appendGrading(correct: correct, total: total, durationMs: elapsedMs)
        SyncEngine.shared.enqueueGradingEvents(
            correct: correct, total: total, durationMs: elapsedMs)
        solvedTotal += total
        correctTotal += correct
        UserDefaults.standard.set(solvedTotal, forKey: AppStore.slotKey("matths.solved"))
        UserDefaults.standard.set(correctTotal, forKey: AppStore.slotKey("matths.correct"))
        activityDays = ActivityLog.recordToday()
        KiceBank.recordScore(exam.id, score: score)

        let choiceKeys = ["a", "b", "c", "d", "e"]
        for (item, section, myInput) in wrong {
            let pid = "\(exam.id)-\(section)-\(item.no)"
            if let i = wrongNotes.firstIndex(where: { $0.problemID == pid && !$0.isMastered }) {
                WrongNoteSRS.afterWrong(&wrongNotes[i])
                // 이번 회차에 쓴 답으로 갱신 — 진단은 "가장 최근에 뭘 썼는지" 를 본다
                if !myInput.isEmpty { wrongNotes[i].myAnswer = myInput }
                SyncEngine.shared.enqueueReviewResult(wrongNotes[i], correct: false)
            } else {
                wrongNotes.insert(WrongNoteEntry(
                    id: UUID().uuidString, problemID: pid, typeKey: "kice-\(exam.id)",
                    typeName: "\(exam.short) \(section) \(item.no)번",
                    unit: "기출 \(exam.short)",
                    statement: "“\(exam.title)” 수학 영역\(exam.displayForm.map { "(\($0))" } ?? "") \(section) \(item.no)번, \(item.points)점 문항입니다. 평가센터의 기출에서 문제지 PDF를 열어 다시 풀어보세요.",
                    // 선다는 SolveScreen 의 5지선다 키(a~e), 단답은 숫자 그대로
                    answer: item.isChoice ? choiceKeys[(Int(item.answer) ?? 1) - 1] : item.answer,
                    steps: ["기출 문항은 앱이 모범 풀이를 제공하지 않습니다. 문제지 PDF로 다시 푼 뒤, 해설이 필요하면 EBSi 무료 해설 강의를 참고하세요."],
                    seed: 0, divergenceStep: nil, drawingPNGBase64: nil,
                    srsStage: 0, nextReviewAt: Date(),   // 최초 복습은 당일
                    wrongCount: 1, createdAt: Date(),
                    // 발제문 없는 선다 복습용 — 빈 텍스트 선지는 ①~⑤ 버블만 그린다
                    choices: item.isChoice ? ["", "", "", "", ""] : nil,
                    isTex: item.isChoice,
                    // 그때 학생이 쓴 답 — 없으면 AI 진단이 무엇이 어긋났는지 못 짚는다
                    myAnswer: myInput.isEmpty ? nil : myInput
                ), at: 0)
                // 기출 오답도 서버 오답노트에 올린다. 여기만 배선이 빠져 있어서
                // 로그인 이후에 생긴 기출 오답은 기기를 바꾸면 통째로 사라졌다
                // (로그인 순간의 스냅샷 1회 업로드에만 얹혀 있었다 — 감사 적발).
                if let fresh = wrongNotes.first { SyncEngine.shared.enqueueWrongNote(fresh) }
            }
        }
        saveWrongNotes()
    }

    /// 결과 화면에서 고른 "틀린 이유"(7종) — 방금 적재된 오답 항목에 기록 (웹 errorType)
    func setErrorType(_ type: WrongErrorType) {
        guard isLearningAccountOperationActive(for: DataScope.slot),
              let p = currentProblem,
              let idx = wrongNotes.firstIndex(where: { $0.problemID == p.id && !$0.isMastered })
        else { return }
        wrongNotes[idx].errorType = type.rawValue
        saveWrongNotes()
        objectWillChange.send()
    }

    /// 복습 통과 직후 "같은 유형 새 수치" 확인 1문항 (웹 변형 재출제의 앱판).
    /// 기록 목적이 아니라 확인 목적 — 통계·오답노트·학습 이벤트를 남기지 않고,
    /// 끝나면 풀던 복습 세트로 그대로 돌아간다.
    func startVariationCheck(typeKey: String) {
        guard let type = ProblemType(rawValue: typeKey) else { return }
        // startExam 이 exam·복습 큐를 통째로 갈아치우므로 되돌릴 것을 먼저 손에 쥔다.
        // (예전에는 여기서 due 5문항짜리 복습 세트가 통째로 증발했다 — 감사 적발)
        let saved = reviewingNoteIDs.map {
            PendingReview(exam: exam, index: examIndex, noteIDs: $0,
                          results: examResults, startedAt: examStartedAt, seed: lastExamSeed)
        }
        startExam(types: [type], count: 1)
        // startExam 이 두 값을 지우므로 반드시 뒤에서 세운다
        pendingReview = saved
        isVariationCheck = true
    }

    /// 결과 화면에서 "갈라진 단계" 를 짚으면 방금 적재된 오답 항목에 기록한다.
    func setDivergence(_ step: Int) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        divergenceStep = step
        guard let p = currentProblem,
              let idx = wrongNotes.firstIndex(where: { $0.problemID == p.id && !$0.isMastered })
        else { return }
        wrongNotes[idx].divergenceStep = step
        saveWrongNotes()
    }

    init() {
        #if !DEBUG
        let persistedProvider = authProvider
        let sanitizedProvider = ServerTokenOwnership.sanitizedPersistedProvider(persistedProvider)
        if sanitizedProvider != persistedProvider {
            authProvider = sanitizedProvider
            UserDefaults.standard.removeObject(forKey: "matths.auth")
            NSLog("AUTH-RECONCILE 지원하지 않는 로그인 표식 폐기 (%@)",
                  persistedProvider ?? "nil")
        }
        #endif
        // 인증 진실원 화해 (S-02) — 로그인 상태의 진실원은 authProvider(UserDefaults)다.
        // iOS 키체인은 앱을 삭제해도 살아남고 UserDefaults 는 지워지므로, 재설치 후
        // "게스트로 둘러보기" 를 누른 기기에 이전 계정의 Bearer 토큰이 남을 수 있다.
        // 그대로 두면 게스트의 학습 op 가 이전 계정으로 올라가고, 이전 계정의 오답·진도가
        // 게스트 슬롯으로 내려온다 — 양방향 계정 간 오염. 서버 계정이 아닌데 토큰이
        // 있으면 잘못 남은 것이니 폐기한다 (SyncEngine 의 정체성 게이트와 짝).
        switch ServerTokenOwnership.restoredSessionAction(
            authProvider: authProvider,
            hasToken: ServerAPI.hasToken) {
        case .keep:
            break
        case .discardOrphanedToken:
            ServerAPI.logout()
            NSLog("AUTH-RECONCILE 잔존 키체인 토큰 폐기 (authProvider=%@, slot=%@)",
                  authProvider ?? "nil", DataScope.slot)
        case .requireSignIn:
            authProvider = nil
            UserDefaults.standard.removeObject(forKey: "matths.auth")
            _ = DataScope.switchTo(DataScope.slotName(forEmail: nil))
            authenticationNotice = "로그인이 만료되었습니다. 다시 로그인해주세요."
            NSLog("AUTH-RECONCILE 서버 로그인 표식에 대응하는 키체인 토큰 없음")
        }
        // 프로필 슬롯 전환 전 버전에서 남은 전역 값을 현재 서버 계정으로 무손실 이관한
        // 뒤, 아래 reload 가 모든 메모리 캐시를 한 슬롯의 값으로 맞춘다.
        Self.migrateLegacyProfileIfNeeded()
        reloadLocalData()

        authenticationExpiredObserver = NotificationCenter.default.addObserver(
            forName: .matthsServerAuthenticationExpired,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                guard let self, self.authProvider == "server" else { return }
                let serverMessage = String(
                    notification.userInfo?["message"] as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self.signOut()
                self.authenticationNotice = serverMessage.isEmpty
                    ? "로그인이 만료되었습니다. 다시 로그인해주세요."
                    : serverMessage
            }
        }

        // 학년 자동 승급 — 3월 1일(KST) 학년도 기준, 학년도당 1회 (웹 생애주기 규칙)
        let promotionKey = AppStore.slotKey("matths.gradePromoYear")
        let lastPromo = UserDefaults.standard.object(forKey: promotionKey) as? Int
        let promoted = AcademicYear.promote(grade: schoolGrade, lastPromotionYear: lastPromo)
        if promoted.grade != schoolGrade { schoolGrade = promoted.grade }
        UserDefaults.standard.set(promoted.year, forKey: promotionKey)

        #if DEBUG
        // 스크린샷 검증용 시작 화면 지정: -route assess
        // 릴리스 빌드에는 들어가지 않는다.
        let args = ProcessInfo.processInfo.arguments
        // 자동화 실행은 로그인 게이트를 게스트로 통과시킨다. 튜토리얼 픽스처가
        // AuthScreen 위에 떠 버리면 실제 홈/탭 spotlight를 전혀 검증하지 못한다.
        if args.contains("-route") || args.contains("-exam") || args.contains("-harness")
            || args.contains("-tutorialFixture") || args.contains("-firstRunFixture") {
            authProvider = authProvider ?? "guest"
        }
        // 데모 모드: 서버 계정으로 **로그인된 것처럼** 보이게 한다.
        //  - signIn(provider:) 를 쓰지 않는다 — UserDefaults("matths.auth")에 적으면
        //    데모를 끈 뒤에도 감독의 로그인 표식이 "server" 로 남는다.
        //  - switchDataSlot(email:) 도 쓰지 않는다 — 슬롯은 MatthsApp.init 이 이미
        //    데모 전용 슬롯으로 바꿔 두었다(실제 기록 보호).
        //  - init 안의 대입은 didSet 을 타지 않으므로 이 값들은 디스크에 남지 않는다.
        if DemoMode.isOn {
            authProvider = "server"
            let user = DemoMode.demoUser
            serverProfile = user
            if let name = user.name, !name.isEmpty { userName = name }
            userEmail = user.email ?? userEmail
            if let grade = user.schoolGrade { schoolGrade = grade }
            if let region = user.school?.region, let code = user.school?.code {
                schoolRegion = region
                schoolCode = code
            }
            serverStreak = user.currentStreak
            serverLongestStreak = user.longestStreak
            NSLog("DEMO-MODE 인증 상태 흉내 (slot=%@, role=%@)",
                  DataScope.slot, user.role ?? "student")
        }
        // 오답노트 연출: -seedWrong n — **실제 채점 경로**로 n개를 틀려서 적재한다.
        // (가짜 데이터 주입이 아니라 gradeCurrent → 오답 적재 → SRS 초기화까지
        //  실코드가 도는지 함께 검증된다. -route 보다 먼저 돌고 route 는 아래서 덮는다.)
        if let i = args.firstIndex(of: "-seedWrong"), i + 1 < args.count,
           let n = Int(args[i + 1]), wrongNotes.isEmpty {
            startExam(types: ProblemType.allCases, count: n, seed: 7)
            for _ in 0..<n {
                gradeCurrent(input: "DEBUG-WRONG")
                advanceExam()
            }
        }
        if let i = args.firstIndex(of: "-route"), i + 1 < args.count,
           let r = Route.allCases.first(where: { "\($0)" == args[i + 1] }) {
            route = r
        }
        // 동적 모의고사 바로 시작: -exam [시드]. 스크린샷·수동 검증용.
        if let i = args.firstIndex(of: "-exam") {
            let seed = i + 1 < args.count ? UInt64(args[i + 1]) : nil
            startExam(types: [.extremum, .logEq, .counting, .integral],
                      count: 4, seed: seed)
        }
        // 진도 연출: -complete n — 커리큘럼 순서대로 앞 n개를 완료 상태에 **병합**한다.
        // 교체(=)로 짰다가 사용자가 직접 딴 진도를 지워 먹은 사고가 있었다.
        // 디버그 인자는 사용자 데이터를 절대 파괴하면 안 된다.
        if let i = args.firstIndex(of: "-complete"), i + 1 < args.count,
           let n = Int(args[i + 1]) {
            let all = CurriculumV2.data.courses.flatMap(\.allConcepts).prefix(n)
            for concept in all {
                progressV2.mergeDebugCompletion(concept)
                if let appID = concept.legacy?.appId {
                    completedConceptIDs.insert(appID)
                }
            }
            saveProgressV2()
            Progress.save(completedConceptIDs)
        }
        // 계정 상태 초기화: -signOut — 키체인 토큰 + 로그인 상태만 지운다.
        // 학습 데이터(진도·오답)는 건드리지 않는다 (데이터 파괴 금지 원칙).
        if args.contains("-signOut") {
            signOut()
        }
        // 오답 AI 진단(thinking) 완주 검증: -diagnoseFirst — 첫 오답노트에 대해
        // 오답노트의 "AI 진단" 버튼과 동일한 실코드 경로를 탭 없이 실행한다.
        // (시뮬 런타임의 HID 주입이 막힌 환경에서 자동 검증용. 데이터 비파괴 —
        //  기존 노트를 읽기만 하고 결과는 채팅 스트림에만 출력된다.)
        if args.contains("-diagnoseFirst"), let note = wrongNotes.first {
            route = .chat
            AITutor.shared.discoverAndLoad()
            AITutor.shared.analyze(
                statement: note.statement,
                myAnswer: note.myAnswer,
                correctAnswer: note.answer,
                steps: note.steps,
                errorType: note.errorType,
                divergenceStep: note.divergenceStep,
                coachLevel: coach.level)
        }
        // 뱅크 시험 연출: -bankexam [시드] — 대수 지수로그 대단원 8문항
        if let i = args.firstIndex(of: "-bankexam") {
            let seed = (i + 1 < args.count ? UInt64(args[i + 1]) : nil) ?? 42
            let problems = JSBank.unitExam(course: "algebra", unit: "explog", seed: seed)
            startExam(problems: problems, seed: seed)
        }
        // 평가 시험지 직행(잠금 우회): -paper <과목 id> [subunit|unit|course]
        if let i = args.firstIndex(of: "-paper"), i + 1 < args.count,
           let course = AssessCatalog.course(args[i + 1]),
           let unit = course.units.first, let sub = unit.subunits.first {
            let scope = i + 2 < args.count ? PaperScope(rawValue: args[i + 2]) ?? .subunit : .subunit
            switch scope {
            case .subunit: startPaper(scope: .subunit, course: course, unit: unit, subunit: sub)
            case .unit:    startPaper(scope: .unit, course: course, unit: unit)
            case .course:  startPaper(scope: .course, course: course)
            }
        }
        // v2 개념 직행: -conceptv2 <웹 개념 id>  예) -conceptv2 calculus-1-01-01
        if let i = args.firstIndex(of: "-conceptv2"), i + 1 < args.count {
            openConceptV2(args[i + 1])
        }
        // 기출 직행: -kice [시험id]  예) -kice suneung-2026. id 생략 시 첫 시험.
        if let i = args.firstIndex(of: "-kice") {
            let id = i + 1 < args.count && !args[i + 1].hasPrefix("-") ? args[i + 1] : nil
            if let exam = KiceBank.exams.first(where: { $0.id == id }) ?? KiceBank.exams.first {
                startKice(exam)
            }
        }
        // 코치 상태 연출: -coach <수위>.<상황>  예) -coach hell.wrong2
        if let i = args.firstIndex(of: "-coach"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: ".")
            if parts.count == 2, let lv = SpiceLevel(rawValue: String(parts[0])) {
                coach.level = lv
                switch parts[1] {
                case "wrong1":       coachLine = coach.onWrong()
                case "wrong2":       _ = coach.onWrong(); coachLine = coach.onWrong()
                case "wrong3":       _ = coach.onWrong(); _ = coach.onWrong(); coachLine = coach.onWrong()
                case "correct":      coachLine = coach.onCorrect()
                case "correctRetry": _ = coach.onWrong(); coachLine = coach.onCorrect()
                default: break
                }
            }
        }
        #endif

        // 로그인 화면은 RootView보다 먼저 뜬다. RootView.onAppear에서만 콜백을 걸면
        // 첫 로그인 직후 guest 승계 큐를 적재할 때 session owner 공급자가 아직 nil이다.
        wireSyncCallbacks()
    }

    func recordStuckPoint(_ text: String) {
        guard isLearningAccountOperationActive(for: DataScope.slot) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let record = StuckPointRecord(text: String(trimmed.prefix(500)))
        stuckPoints.insert(record, at: 0)
        saveStuckPoints()
        SyncEngine.shared.enqueueStuckPoint(record)
    }

    /// 세션 모드 — 문제 푸는 동안은 상·하단 바를 모두 걷어낸다
    var isSessionMode: Bool {
        route == .solve || route == .result || route == .kice || route == .paper || route == .placement || route == .weeklyMock
    }

    /// 화면 보호(secure canvas 사전 차단 + 캡처 덮개 + 워터마크)를 켤 화면.
    ///
    /// `isSessionMode` 와 **일부러 분리한다.** isSessionMode 는 "상·하단 바를 걷어내는
    /// 레이아웃 모드"이고 RootView.sessionContent 의 switch 가 그 목록과 1:1로 묶여 있다.
    /// 빠른 연습은 문제를 푸는 화면이지만 RootView 의 sessionContent 에 분기가 없어서,
    /// 보호를 붙이려고 isSessionMode 에 .quickPractice 를 넣으면 그 화면이 통째로
    /// EmptyView 가 된다. 보호 범위만 넓히고 레이아웃 계약은 건드리지 않는다.
    /// 2026-08-17: 보호 범위를 **문제 푸는 동안으로 되돌린다.**
    ///
    /// 전 화면으로 넓혔더니 앱이 망가졌다. 제어센터를 내리기만 해도 화면 전체가
    /// 검게 덮였다 — secure canvas 가 켜진 상태에서 프라이버시 커버가 함께 작동하며
    /// 학습 화면을 통째로 가린 것이다. 그러면서 정작 **스크린샷은 못 막았다.**
    /// 얻은 것 없이 앱만 쓸 수 없게 만든 변경이라 되돌린다.
    ///
    /// 스크린샷을 실제로 막는 길은 secure canvas 우회가 아니라 AAC
    /// (AutomaticAssessmentConfiguration)다. Apple DTS 도 이 우회를 쓰지 말라고 했고,
    /// App Review 2.5.1 위험도 있다. AAC 는 개발자 계정 승인 후 entitlement 를 받아
    /// AssessmentSecurityCoordinator 로 붙인다.
    var isProblemSolvingRoute: Bool {
        isSessionMode || route == .quickPractice
    }

    /// 하단 탭바에서 어느 항목을 켜 둘지.
    /// 개념 화면은 탭이 아니지만 커리큘럼에서 들어온 곳이므로 그 탭을 켠다.
    /// (아무 탭도 안 켜져 있으면 학생은 자기가 어디 있는지 알 수 없다.)
    var selectedTab: Route {
        switch route {
        case .concept: return .curriculum
        case .placement, .arenaShop: return .rank
        // 이용권·상점은 들어온 곳의 탭을 그대로 켜 둔다. 홈에서 들어갔는데
        // GOAT Arena 에 불이 켜지면 학생은 자기가 어디 있는지 잘못 읽는다.
        case .commerce: return commerceOrigin.isTab ? commerceOrigin : .profile
        case .services, .academy, .coachSuggestions, .support, .archive, .studyHall, .storeCatalog, .faq, .hostedPortal:
            return serviceOrigin.isTab ? serviceOrigin : .home
        case .weeklyMock: return .assess
        default:       return route
        }
    }

    /// Arena의 하위 화면도 같은 독립 다크 셸과 선택 탭을 유지한다.
    var isArenaRoute: Bool {
        route == .rank || route == .arenaShop
    }
}

// MARK: - 복습 리마인더 (로컬 알림)

/// 프로필의 "복습 리마인더" 를 실제로 울리게 하는 곳.
///
/// APNs·서버 잡 없이 **기기 로컬 알림**만 쓴다 — 엔타이틀먼트도, 백그라운드 모드도,
/// 디바이스 토큰도 필요 없고 오프라인에서도 뜬다. 이 앱에 필요한 건 그게 전부다.
///
/// 매일 울리는 반복 알림 대신 오답의 nextReviewAt 이 실제로 걸린 날만 예약한다 —
/// 화면이 "복습 예정 문항이 있는 날 저녁" 이라고 약속했기 때문이다.
enum ReviewReminder {
    /// 우리가 건 예약만 골라 지우기 위한 식별자 접두사
    private static let prefix = "matths.review."
    /// 저녁 8시 — 화면 문구의 "저녁"
    private static let hour = 20
    /// 앞으로 며칠까지 미리 걸어 둘지 (복습 목록이 바뀔 때마다 다시 계산한다)
    private static let horizonDays = 7

    /// 예약을 현재 오답 목록에 맞춰 다시 건다.
    /// - Parameter onAuthorization: 권한 응답. 거부되면 호출부가 토글을 되돌린다
    ///   (알림이 오지 않는데 켜져 있는 토글은 거짓말이다).
    static func reschedule(_ notes: [WrongNoteEntry], onAuthorization: ((Bool) -> Void)? = nil) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            onAuthorization?(granted)
            guard granted else { return }
            clearMine(center) {
                for request in requests(for: notes) { center.add(request) }
            }
        }
    }

    /// 토글을 끄면 걸어 둔 예약을 모두 회수한다 (남의 알림은 건드리지 않는다)
    static func cancelAll() {
        clearMine(UNUserNotificationCenter.current())
    }

    private static func clearMine(_ center: UNUserNotificationCenter,
                                  then next: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { pending in
            let mine = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: mine)
            next?()
        }
    }

    /// 앞으로 horizonDays 일 중, 그날 저녁까지 복습이 걸린 오답이 있는 날만 예약한다.
    private static func requests(for notes: [WrongNoteEntry]) -> [UNNotificationRequest] {
        let calendar = Calendar.current
        var out: [UNNotificationRequest] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: Date()) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = 0
            // 이미 지난 오늘 저녁에는 걸지 않는다 (트리거가 조용히 버려진다)
            guard let fireAt = calendar.date(from: comps), fireAt > Date() else { continue }
            let due = notes.filter { note in
                guard let next = note.nextReviewAt else { return false }   // nil = 졸업
                return next <= fireAt
            }.count
            guard due > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = "오늘의 복습"
            content.body = "복습할 오답이 \(due)문항 있습니다."
            content.sound = .default
            // 식별자는 날짜 성분으로 직접 만든다 — 예약은 백그라운드 콜백에서 돌고,
            // 공용 DateFormatter 를 그 스레드로 끌고 가지 않는 편이 안전하다.
            let key = "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
            out.append(UNNotificationRequest(
                identifier: prefix + key,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        return out
    }
}

// MARK: - 주간 모의고사 예고 알림

/// 주간 모의고사가 열리기 전에 한 번 알려 주는 곳.
///
/// ReviewReminder 와 같은 방식으로 **기기 로컬 알림**만 쓴다. 서버가 이미 대시보드에
/// 다음 회차 시각(nextReleaseAt)과 대기실 열림 시각(lobbyOpensAt)을 주므로,
/// 그 값을 받은 시점에 기기가 스스로 예약을 건다. APNs·디바이스 토큰·서버 발송기가
/// 없어도 동작한다.
///
/// 랭크 방어 마감은 여기가 아니라 RankDefenseReminder(LocalNotifications.swift)가 건다 —
/// 서버 스냅샷의 마감 시각을 쓰므로 같은 방식(로컬 알림)으로 가능하다. 다만 앱을 한 번도
/// 열지 않은 사이에 배정된 방어는 어느 쪽으로도 알릴 수 없다(그건 APNs 가 필요하다).
enum WeeklyMockReminder {
    private static let prefix = "matths.weeklymock."
    /// 열리기 몇 분 전에 알릴지. 준비할 시간은 주되 잊어버릴 만큼 이르지는 않게.
    private static let leadMinutes = 30

    private static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// 대시보드를 받을 때마다 다시 건다. 회차가 바뀌면 옛 예약은 지운다.
    ///
    /// 권한은 LocalNotificationPermission 이 정한 시점에만 묻는다 — 예약할 회차가
    /// 실제로 잡혀 있을 때 한 번. 예전에는 "이미 허락한 사람에게만" 걸었는데, 권한을
    /// 묻는 곳이 복습 리마인더 토글뿐이라 그 토글을 켜지 않은 학생에게는 이 예고가
    /// 한 번도 걸리지 않았다(= 있으나 마나 한 기능이었다).
    static func reschedule(
        nextReleaseAt: String?,
        lobbyOpensAt: String?,
        allowPermissionPrompt: Bool = true
    ) {
        let center = UNUserNotificationCenter.current()
        let pending = requests(nextReleaseAt: nextReleaseAt, lobbyOpensAt: lobbyOpensAt)
        // 걸 것이 없으면 권한 창도 띄우지 않는다. 옛 예약만 회수한다 —
        // 회차가 취소·변경됐는데 예고가 남아 울리면 학생을 헛걸음시킨다.
        guard !pending.isEmpty else {
            clearMine(center)
            return
        }
        LocalNotificationPermission.whenSchedulable(
            allowPermissionPrompt: allowPermissionPrompt
        ) {
            clearMine(center) {
                for request in pending { center.add(request) }
            }
        }
    }

    static func cancelAll() { clearMine(UNUserNotificationCenter.current()) }

    private static func clearMine(_ center: UNUserNotificationCenter,
                                  then next: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { pending in
            let mine = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: mine)
            next?()
        }
    }

    private static func requests(nextReleaseAt: String?,
                                 lobbyOpensAt: String?) -> [UNNotificationRequest] {
        // 두 시각은 서로 다른 사건이다 — 지금 회차의 대기실이 열리는 때와, 다음 회차가
        // 공개되는 때. 예전에는 둘 중 가장 이른 하나만 걸어서, 대기실 예고를 받은 학생은
        // 다음 회차 공개를 통째로 못 받았다. 각각 걸고, 지난 것만 알아서 빠진다.
        [
            request(kind: "lobby",
                    anchor: parse(lobbyOpensAt),
                    title: "주간 모의고사 대기실이 곧 열립니다",
                    body: "\(leadMinutes)분 뒤에 열립니다. 준비되면 들어와 주세요."),
            request(kind: "release",
                    anchor: parse(nextReleaseAt),
                    title: "다음 주간 모의고사가 곧 공개됩니다",
                    body: "\(leadMinutes)분 뒤에 공개됩니다.")
        ].compactMap { $0 }
    }

    private static func request(kind: String,
                                anchor: Date?,
                                title: String,
                                body: String) -> UNNotificationRequest? {
        guard let anchor else { return nil }
        let fireAt = anchor.addingTimeInterval(-Double(leadMinutes) * 60)
        // 이미 지난 시각에는 걸지 않는다. 켜자마자 울리는 알림은 안내가 아니라 소음이고,
        // 지난 트리거는 iOS 가 조용히 버려 예약한 줄 알고 넘어가게 만든다.
        guard fireAt > Date().addingTimeInterval(60) else { return nil }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        // 회차 시각을 식별자에 넣어 같은 회차를 다시 받아도 같은 예약으로 덮이게 한다.
        // 종류(kind)까지 넣지 않으면 대기실과 공개 예약이 서로를 밀어낸다.
        let id = "\(prefix)\(kind).\(Int(anchor.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}

// MARK: - 막힌 지점 저장 (스크린샷 가드 입력)

/// 스크린샷 가드에서 학생이 직접 적은 "막힌 지점" 의 슬롯 파일 저장소.
/// WrongNoteDisk 와 같은 관례(슬롯 스코프 JSON)를 따르되, 손상 시 원본을 보존한다 —
/// 손상 1건이 전체 유실로 증폭되면 안 된다(빈 배열로 덮어쓰는 순간 복구 불능이 된다).
enum StuckPointsDisk {
    private static var fileURL: URL { DataScope.url("stuck-points.json") }

    static func load() -> [StuckPointRecord] {
        // 파일 없음 = 첫 실행/기록 없음 — 정상.
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        if let list = try? JSONDecoder().decode([StuckPointRecord].self, from: data) {
            return list
        }
        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            let migrated = legacy.map { StuckPointRecord(text: $0) }
            save(migrated)
            return migrated
        }
        do {
            // 파일은 있는데 못 읽는다(쓰기 중 강제종료·스키마 변경). 삼키고 빈 배열로
            // 시작하면 다음 save 가 원본을 덮어쓴다 — 원문을 옆으로 옮겨 증거와
            // 복구 여지를 남긴 뒤에만 빈 목록으로 시작한다.
            let stamp = ISO8601DateFormatter().string(from: Date())
            try? FileManager.default.moveItem(
                at: fileURL, to: DataScope.url("stuck-points.corrupt-\(stamp).json"))
            NSLog("STUCKPOINTS-CORRUPT 손상 파일 격리: stuck-points.corrupt-%@.json", stamp)
            return []
        }
    }

    @discardableResult
    static func save(_ points: [StuckPointRecord]) -> Bool {
        save(points, to: fileURL)
    }

    @discardableResult
    static func save(_ points: [StuckPointRecord], for slot: String) -> Bool {
        save(points, to: DataScope.url("stuck-points.json", for: slot))
    }

    @discardableResult
    private static func save(_ points: [StuckPointRecord], to destination: URL) -> Bool {
        do {
            let data = try JSONEncoder().encode(points)
            // 원자 쓰기 — 도중 강제종료로 반쪽 파일이 남지 않게.
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            // 저장 실패를 무음으로 흘리지 않는다 — 최소한 시스템 로그에 증거를 남긴다.
            NSLog("STUCKPOINTS-ERROR 저장 실패 (%d건): %@", points.count, error.localizedDescription)
            return false
        }
    }
}
