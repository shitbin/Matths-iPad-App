//  ScreenshotGuard.swift
//  Matths
//
//  화면 보호. iOS 공개 API는 녹화·미러링 상태를 사전에 알려 주지만,
//  단발 스크린샷은 저장이 끝난 뒤에만 알린다. 따라서 녹화·미러링은 즉시
//  검정 덮개로 가리고, 스크린샷 알림은 비차단 감사 신호로만 기록한다.
//
//  ⚠️ 아래 "secure canvas" 단락은 **2026-08-17 에 폐기됐다.** 사실이 아니다 —
//  `.secureCaptureCanvas(isActive: false)` 로 꺼져 있고(이 파일 아래쪽 참고),
//  켜져 있던 동안에도 스크린샷을 막지 못했다. 대신 제어센터를 내리기만 해도
//  화면이 검게 덮였다. 판단 근거로 남겨 둔 기록이지 현재 동작 설명이 아니다.
//  지금 실제로 무엇이 막히는지는 이 머리말 맨 아래 "2026-08-18" 단락을 보라.
//
//  (폐기됨) 여기에 더해, 문제를 푸는 동안에는 `SecureCaptureCanvas` 로 화면 자체를
//  캡처 픽셀에서 제외한다 — 스크린샷은 찍히지만 저장된 파일은 검게 남는다.
//
//  (폐기됨) 이전 주석은 "isSecureTextEntry 편법은 심사에서 거절되고 VoiceOver 를
//  깨뜨린다"고 적어 이 경로를 금지했다. 두 주장 모두 재검증에서 근거가
//  확인되지 않아 정정한다.
//   - 심사: Apple 이 말한 것은 "There's no supported way to prevent screen
//     captures"(지원하지 않는다)이지 거절한다가 아니다. 해당 가이드라인
//     조항도 거절 사례도 확인되지 않았다.
//   - 접근성: 숨은 필드 자체는 접근성 요소가 아니고, 그 자손을 숨기지도
//     않는다. VoiceOver 가 화면을 잃는 구성은 만들지 않는다.
//  확인된 진짜 위험은 둘이며, 둘 다 주석이 아니라 계측으로 막는다.
//   1. **조용히 풀린다** (Apple Developer Forums 767320 — iOS 18 파손 보고).
//      → `SecureCanvasProbe` 가 마커 픽셀로 캡처 제외를 직접 잰다.
//   2. **앱을 망가뜨린다.** 레이어만 옮겨도 UIKit 은 `subviews` 를
//      `layer.sublayers` 에서 되읽으므로 터치·포커스 경로가 바뀐다.
//      → 재부모화 직후 좌표와 hit test 를 확인하고 어긋나면 즉시 되돌린다.
//  둘 중 하나라도 통과하지 못하면 아무것도 재부모화하지 않고 이 파일의 기존
//  보호(녹화 덮개 + 앱 전환 덮개 + 워터마크 + 감사 이벤트)로 폴백한다.
//
//  ## 2026-08-18: 스크린샷 차단의 정식 경로(AAC)를 여기서 켠다
//  `AssessmentSecurityCoordinator` 가 `AEAssessmentSession` 을 열고 닫는다.
//  **왜 이 파일에서 여느냐** — 시험 화면들이 이미 `beginProtection(_:surface:)` 로
//  자기 이름을 여기에 등록하고 있다. 화면마다 따로 세션을 열게 하면 판정점이
//  화면 수만큼 늘어나고, 언젠가 한 화면이 `end()` 를 빠뜨린다. AAC 에서 그 실수는
//  **기기가 앱에 갇히는 것**이다(단일 앱 모드가 안 풀린다). 등록/해제가 이미 짝을
//  이루는 이 한 곳에 붙여 그 실수를 구조적으로 없앤다.
//
//  범위는 `AssessmentLockScope.lockedSurfaces` 넷뿐이다 — 주간모의고사·배치고사·
//  KICE·아레나 경기. 나머지 보호 화면(빠른 연습·풀이·결과·시험지 분석)은 잠그지
//  않는다. 전 화면으로 넓혔다가 앱을 못 쓰게 만든 2026-08-17 사고를 반복하지 않는다.
//
//  entitlement 가 아직 없으므로 기기에서 `begin()` 은 실패한다. 그때 이 파일은
//  **아무것도 하지 않는다** — 덮개도, 검정 화면도, 모달도 없다. 기존 보호가 그대로
//  남고 시험은 계속된다(`AssessmentProtectionTier.bestEffort`). 실패가 화면을
//  가리게 만드는 것이 이 기능에서 가장 위험한 회귀다.

import SwiftUI
import UIKit

@MainActor
final class ScreenshotGuard: ObservableObject {
    typealias IntegrityEventRecorder = (_ type: String, _ sessionCode: String, _ surface: String) -> Void

    @Published var isShowing = false
    @Published var stuckPoint = ""
    @Published private(set) var isCaptureActive = false
    @Published private(set) var isPrivacyCoverActive = false
    @Published private(set) var protectionEnabled = false
    @Published private(set) var accountWatermarkCode: String

    /// 지금 화면이 실제로 어느 등급으로 보호되는가.
    ///
    /// `.systemLocked` 일 때만 스크린샷이 시스템에서 막힌다. `.bestEffort` 는
    /// "찍히긴 하지만 기록은 남는다" 다. **UI 문구를 쓸 때 이 둘을 절대 같은 말로
    /// 표현하지 마라** — 학생이 막힌 줄 알고 시험을 보게 된다.
    @Published private(set) var assessmentProtectionTier: AssessmentProtectionTier = .bestEffort

    /// 마지막 AAC 상태의 비식별 진단명(`failed:aac-unknown` 등). 로그·자가진단용.
    @Published private(set) var assessmentLockDiagnostic = AssessmentSecurityState.idle.diagnosticName

    /// 사용자 식별정보를 화면에 노출하지 않는 실행 단위 코드다. 계정 가명 코드는
    /// accountWatermarkCode로 분리하고, 이 값은 앱을 다시 열면 바뀐다.
    let watermarkCode = String(UUID().uuidString.prefix(8)).uppercased()

    private var baseProtection = false
    private var protectionIDs: [UUID: String] = [:]
    private var sceneIsActive = true
    private let integrityEventRecorder: IntegrityEventRecorder?
    var isProtected: Bool { baseProtection || !protectionIDs.isEmpty }

    /// AAC 세션. 화면마다 만들지 않고 하나를 재사용한다 — 코디네이터는
    /// `.ended`/`.failed` 에서 다시 시작할 수 있고, 세션 객체는 매 시작마다 새로 만든다.
    private let assessmentLock: AssessmentSecurityCoordinator
    /// 지금 잠금을 원하는 시험 화면이 떠 있는가. `protectionIDs` 에서 매번 다시
    /// 계산한다 — 별도 카운터를 두면 화면 전환 중 등록/해제 순서가 뒤집힐 때 새다.
    private var wantsSystemLock: Bool {
        protectionIDs.values.contains { AssessmentLockScope.locksSystem($0) }
    }

    private var activeSurface: String {
        let names = Set(protectionIDs.values).sorted()
        if !names.isEmpty { return names.joined(separator: ",") }
        return baseProtection ? "session" : "protected"
    }

    private var observers: [NSObjectProtocol] = []

    /// - Parameter assessmentLock: `nil` 이면 실물 `AEAssessmentSession` 을 쓴다.
    ///   **파라미터 순서 주의** — 이 인자가 뒤에 오면 기존 호출부의 후행 클로저
    ///   (`ScreenshotGuard { type, _, surface in … }`)가 이쪽에 붙어 컴파일이 깨진다.
    init(
        assessmentLock: AssessmentSecurityCoordinator? = nil,
        integrityEventRecorder: IntegrityEventRecorder? = nil
    ) {
        self.integrityEventRecorder = integrityEventRecorder
        self.assessmentLock = assessmentLock ?? AssessmentSecurityCoordinator()
        accountWatermarkCode = DataScope.screenProtectionAccountCode
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // queue: .main 으로 등록했으므로 이 블록은 반드시 메인에서 실행된다.
            // 컴파일러는 그걸 증명하지 못하므로 명시해 준다.
            MainActor.assumeIsolated {
                self?.handleScreenshotDetected()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCaptureState() }
        })
        // SwiftUI scenePhase보다 먼저 오는 UIKit 수명주기 신호에서도 덮개를 켠다.
        // 앱 전환기 스냅샷이 만들어질 때 문제 화면이 한 프레임 남지 않게 하는 이중 안전장치다.
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setSceneActive(false) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.setSceneActive(true) }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: DataScope.didSwitchNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                let slot = note.object as? String ?? DataScope.slot
                self?.accountWatermarkCode = DataScope.screenProtectionAccountCode(for: slot)
            }
        })
        // 앱이 종료될 때 잠금을 확실히 푼다. onDisappear 가 오지 않는 종료 경로
        // (사용자가 앱 전환기에서 밀어 끄는 등)에서도 세션이 남지 않게 하는 보험이다.
        // AAC 세션이 남으면 다음 실행에서 기기가 이상하게 잠겨 보인다.
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.assessmentLock.endSecuredSession() }
        })
        self.assessmentLock.onStateChange = { [weak self] state in
            self?.applyAssessmentLockState(state)
        }
        refreshCaptureState()
        #if DEBUG
        Self.runSelfTestsOnce()
        #endif
    }

    func setBaseProtection(_ enabled: Bool) {
        baseProtection = enabled
        refreshCaptureState()
    }

    func beginProtection(_ id: UUID, surface: String) {
        protectionIDs[id] = ScreenIntegrityEventContract.normalizedSurface(surface)
        refreshCaptureState()
        syncAssessmentLock()
    }

    func endProtection(_ id: UUID) {
        protectionIDs.removeValue(forKey: id)
        refreshCaptureState()
        syncAssessmentLock()
    }

    // MARK: - AAC 잠금

    /// 시험 화면이 떠 있으면 세션을 열고, 없으면 닫는다.
    ///
    /// 등록/해제 양쪽에서 같은 함수를 부르고 원하는 상태를 `protectionIDs` 에서
    /// 다시 계산한다. "열었으니 닫아야지" 를 호출부가 기억하게 하지 않는다 —
    /// 그 기억이 한 번 어긋나면 기기가 잠긴 채로 남는다.
    ///
    /// 중복 호출은 코디네이터가 흡수한다(진행 중이면 `beginSecuredSession` 은
    /// 곧바로 반환하고, 시작한 적 없으면 `endSecuredSession` 도 그렇다).
    private func syncAssessmentLock() {
        if wantsSystemLock {
            assessmentLock.beginSecuredSession()
        } else {
            assessmentLock.endSecuredSession()
        }
        traceAssessmentLock("sync wants=\(wantsSystemLock) surfaces=\(activeSurface)")
    }

    /// `-assessmentLockTrace` 로 실행할 때만 남긴다. 실제 시험 화면에서 세션이
    /// 언제 열리고 어떤 진단으로 닫히는지 화면 없이 확인하는 유일한 창구다.
    /// `@autoclosure` 라서 릴리스에서는 문자열을 만들지도 않는다.
    private func traceAssessmentLock(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-assessmentLockTrace") else { return }
        print("MATTHS_ASSESSMENT_LOCK_TRACE_V1 \(message()) "
              + "tier=\(assessmentProtectionTier) state=\(assessmentLockDiagnostic)")
        // console-pipe 로 받을 때 stdout 이 전량 버퍼링된다. 추적 로그는 화면 전환마다
        // 한 줄씩이라 버퍼가 차지 않고, 앱이 죽는 순간 통째로 사라진다.
        fflush(stdout)
        #endif
    }

    /// 코디네이터 상태를 표시용 값으로만 옮긴다.
    ///
    /// **여기서 화면을 가리지 않는다.** entitlement 승인 전에는 `.failed` 가 정상
    /// 경로이고, 그때 덮개를 올리면 시험 자체가 불가능해진다. 실패는 등급을
    /// `.bestEffort` 로 두는 것으로 끝이다 — 기존 보호는 이미 켜져 있다.
    private func applyAssessmentLockState(_ state: AssessmentSecurityState) {
        // 등급 판정은 코디네이터에만 둔다. 여기서 같은 규칙을 다시 쓰면 판정점이
        // 둘이 되고, 언젠가 한쪽만 고쳐진다.
        assessmentProtectionTier = assessmentLock.protectionTier
        assessmentLockDiagnostic = state.diagnosticName
        traceAssessmentLock("state")
    }

    func setSceneActive(_ active: Bool) {
        sceneIsActive = active
        isPrivacyCoverActive = !sceneIsActive && isProtected
    }

    /// iOS 17+의 scene 단위 정식 감지 신호를 표시 계층에서 전달받는다.
    /// `UIScreen.isCaptured`는 초기화·구형 알림 폴백으로만 남긴다.
    func setSceneCaptureState(_ captured: Bool) {
        applyCaptureState(captured)
    }

    private func refreshCaptureState() {
        // iPad의 외부 디스플레이/다중 scene도 포함한다. scene이 아직 연결되기 전인
        // 앱 초기화 구간만 UIScreen.main으로 폴백한다.
        let sceneScreens = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.screen }
        let captured = sceneScreens.isEmpty
            ? UIScreen.main.isCaptured
            : sceneScreens.contains { $0.isCaptured }
        applyCaptureState(captured)
    }

    private func applyCaptureState(_ captured: Bool) {
        let wasCaptureActive = isCaptureActive
        protectionEnabled = isProtected
        isPrivacyCoverActive = !sceneIsActive && protectionEnabled
        isCaptureActive = protectionEnabled && captured
        if isCaptureActive && !wasCaptureActive {
            recordIntegrityEvent("protected-screen-capture-started")
        } else if !isCaptureActive && wasCaptureActive {
            recordIntegrityEvent("protected-screen-capture-ended")
        }
    }

    private func recordIntegrityEvent(_ type: String) {
        guard let eventType = ScreenIntegrityEventContract.normalizedEventType(type) else { return }
        let surface = ScreenIntegrityEventContract.normalizedSurface(activeSurface)
        if let integrityEventRecorder {
            integrityEventRecorder(eventType, watermarkCode, surface)
            return
        }
        EventLog.append(eventType)
        SyncEngine.shared.enqueueIntegrityEvent(
            eventType,
            sessionCode: watermarkCode,
            surface: surface)
    }

    private func handleScreenshotDetected() {
        guard isProtected else { return }
        // 시스템 알림은 촬영 뒤에 오므로 캡처 자체를 취소할 수 없다. 학생의 풀이를
        // 가리는 사후 처벌형 모달은 띄우지 않고, 최소 감사 신호만 매번 기록한다.
        recordIntegrityEvent("protected-screen-screenshot")
    }

    #if DEBUG
    /// 실기 자가진단은 실제 서버 outbox 대신 주입된 recorder만 사용한다.
    /// 시스템 알림·UIScreen 연결은 별도 정적 계약으로 유지하고, 여기서는 실제 기기에서
    /// 동일 상태 전이와 overlay 조건을 결정론적으로 검증한다.
    func simulateScreenshotForDeviceQA() {
        handleScreenshotDetected()
    }

    func simulateCaptureStateForDeviceQA(_ captured: Bool) {
        applyCaptureState(captured)
    }

    /// 잠금 자가진단은 실행인자로 켜고, ScreenshotGuard 가 처음 만들어질 때 한 번만 돈다.
    ///
    /// **왜 `MatthsApp` 의 다른 self test 들 옆이 아닌가.** 이번 세션에서 그 파일은
    /// 다른 작업자가 동시에 고치고 있어 손대지 않았다. 이 파일이 AAC 를 소유하므로
    /// 진입점도 여기에 둔다. 나중에 안전할 때 `MatthsApp.init` 으로 옮기면 된다.
    private static var didRunSelfTests = false

    private static func runSelfTestsOnce() {
        guard !didRunSelfTests else { return }
        didRunSelfTests = true
        AssessmentSecuritySelfTest.runIfRequested()
        AssessmentSecurityLiveProbe.runIfRequested()
    }

    /// 시험 화면 등록/해제를 실제 화면 없이 재현한다(시뮬레이터 QA 용).
    func simulateAssessmentSurfaceForDeviceQA(_ surface: String) -> UUID {
        let id = UUID()
        beginProtection(id, surface: surface)
        return id
    }
    #endif

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}

private struct ProtectedAssessmentSurface: ViewModifier {
    @EnvironmentObject private var screenshotGuard: ScreenshotGuard
    let surface: String
    /// View 재계산마다 새 UUID를 만들면 onAppear에서 등록한 키와 onDisappear에서
    /// 해제하는 키가 달라져 보호 상태가 앱 전체에 영구 잔류할 수 있다.
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { screenshotGuard.beginProtection(id, surface: surface) }
            .onDisappear { screenshotGuard.endProtection(id) }
    }
}

/// 보호 화면의 실제 표시 계층. `fullScreenCover`는 앱 루트의 overlay보다 위에
/// 별도 presentation 계층으로 올라오므로, 루트와 보호 모달이 이 한 구현을 각각
/// 자기 최상단에 붙인다. 상태와 워터마크 코드는 같은 ScreenshotGuard를 공유한다.
struct ScreenProtectionLayer: View {
    @Environment(\.isSceneCaptured) private var isSceneCaptured
    @ObservedObject var guardModel: ScreenshotGuard
    var onCapture: (String) -> Void

    var body: some View {
        Group {
            if guardModel.isCaptureActive || guardModel.isPrivacyCoverActive {
                CapturePrivacyCover()
            } else {
                // 풀이를 가로질러 반복하던 워터마크를 제거한다. 화면 한 구역의 저대비
                // 가명 표식만 남겨 문제·수식·필기 가독성을 해치지 않는다.
                if guardModel.protectionEnabled {
                    ProtectedContentWatermark(
                        accountCode: guardModel.accountWatermarkCode,
                        sessionCode: guardModel.watermarkCode)
                }
            }
        }
        .onAppear {
            guardModel.setSceneCaptureState(isSceneCaptured)
        }
        .onChange(of: isSceneCaptured) { _, captured in
            guardModel.setSceneCaptureState(captured)
        }
    }
}

private struct ScreenProtectionLayerModifier: ViewModifier {
    @ObservedObject var guardModel: ScreenshotGuard
    var onCapture: (String) -> Void

    func body(content: Content) -> some View {
        content
            // 사전 차단. 보호 중일 때만 켜지므로 앱 전체에는 걸리지 않는다.
            // 프로브가 .verified 를 주지 않으면 이 modifier 는 아무 일도 하지 않고
            // 아래 overlay(사후·상태 기반 보호)만 남는다.
            // 2026-08-17: secure canvas 를 끈다(isActive: false).
            //
            // 이 우회는 스크린샷을 **막지 못했고**(사용자 실기 확인), 그러면서
            // 제어센터를 내리기만 해도 화면 전체가 검게 덮이는 부작용을 냈다.
            // 얻는 것 없이 앱을 못 쓰게 만드는 코드다.
            //
            // Apple DTS 도 isSecureTextEntry 컨테이너 트릭이 의도된 용도가 아니며
            // OS 업데이트에서 계속 동작한다는 보장이 없다고 명시했고,
            // 내부 레이어 재부모화까지 하므로 App Review 2.5.1 위험도 있다.
            //
            // 스크린샷 차단의 정식 경로는 AAC(AEAssessmentSession)다 —
            // AssessmentSecurityCoordinator 에 준비돼 있고, 개발자 계정 승인 후
            // entitlement 를 받으면 그때 배선한다. 그때까지는 화면 녹화·미러링
            // 차단(isCaptured 경로)과 워터마크만 남는다. 코드는 지우지 않고
            // 꺼 두어, AAC 가 붙기 전까지 되살릴 판단 근거를 남긴다.
            .secureCaptureCanvas(isActive: false)
            .overlay {
                ScreenProtectionLayer(guardModel: guardModel, onCapture: onCapture)
            }
            .animation(.easeOut(duration: 0.2), value: guardModel.isShowing)
    }
}

private struct ProtectedAssessmentPresentation: ViewModifier {
    let surface: String
    @ObservedObject var guardModel: ScreenshotGuard
    var onCapture: (String) -> Void

    func body(content: Content) -> some View {
        content
            .modifier(ProtectedAssessmentSurface(surface: surface))
            .modifier(ScreenProtectionLayerModifier(
                guardModel: guardModel,
                onCapture: onCapture))
    }
}

extension View {
    func protectedAssessmentSurface(_ surface: String = "assessment") -> some View {
        modifier(ProtectedAssessmentSurface(surface: surface))
    }

    /// 앱 루트처럼 이미 별도 보호 상태를 관리하는 계층에 공통 표시만 붙인다.
    func screenProtectionLayer(
        guardModel: ScreenshotGuard,
        onCapture: @escaping (String) -> Void
    ) -> some View {
        modifier(ScreenProtectionLayerModifier(
            guardModel: guardModel,
            onCapture: onCapture))
    }

    /// fullScreenCover 안에서 보호 등록과 표시 계층을 함께 붙인다. 둘을 따로
    /// 호출해 워터마크나 앱 전환 덮개 하나를 빠뜨리는 회귀를 막는다.
    func protectedAssessmentPresentation(
        _ surface: String = "assessment",
        guardModel: ScreenshotGuard,
        onCapture: @escaping (String) -> Void
    ) -> some View {
        modifier(ProtectedAssessmentPresentation(
            surface: surface,
            guardModel: guardModel,
            onCapture: onCapture))
    }
}

struct CapturePrivacyCover: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill").font(.system(size: 28))
                Text("보호된 평가 화면").font(.headline)
                Text("화면 녹화나 미러링 중에는 문제와 풀이를 표시하지 않습니다.")
                    .font(.callout).multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .accessibilityElement(children: .combine)
    }
}

/// secure canvas 가 `.degraded`/`.unavailable` 로 떨어진 기기에서는 스크린샷 결과가
/// 그대로 남는다. 그때의 마지막 방어선이 이 가명 표식이다 — 유출본의 출처를 되짚을 수
/// 있게만 하고, 풀이를 방해하지 않는 우하단 한 구역에만 아주 낮은 대비로 둔다.
struct ProtectedContentWatermark: View {
    let accountCode: String
    let sessionCode: String

    var body: some View {
        GeometryReader { proxy in
            Text("MATTHS \(accountCode) \(sessionCode)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.035))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: min(210, max(150, proxy.size.width * 0.42)))
                .background(.ultraThinMaterial.opacity(0.18), in: Capsule())
                .padding(.trailing, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ScreenshotGuardOverlay: View {
    @ObservedObject var guardModel: ScreenshotGuard
    /// 학생이 적은 "막힌 지점" 을 오답노트로 넘긴다 — 잔소리가 아니라 기능이 되게.
    var onCapture: (String) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("스크린샷이 감지되었습니다")
                    .font(.title2.weight(.heavy))

                Text("보호된 평가 화면의 캡처 기록은 시험 무결성 검토에 참고될 수 있습니다. "
                     + "학습을 위해 남길 내용은 오답노트에 저장되며, 로그인 계정에서는 다른 기기와 동기화됩니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("예: 증감표에서 부호가 왜 바뀌는지 모르겠음",
                          text: $guardModel.stuckPoint)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)

                HStack(spacing: 12) {
                    Button("막힌 지점 저장") {
                        onCapture(guardModel.stuckPoint)
                        guardModel.stuckPoint = ""
                        guardModel.isShowing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(guardModel.stuckPoint.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("계속 풀기") { guardModel.isShowing = false }
                        .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(maxWidth: 460)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(24)
        }
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }
}
