//  AssessmentSecurityCoordinator.swift
//  Matths
//
//  "스크린샷이 아예 저장되지 않게" 를 Apple 이 지원하는 방식으로 하는 준비 코드.
//
//  ## 왜 별도 파일인가 — 기존 보호와 성격이 다르다
//  `SecureCaptureCanvas` 는 비공개 내부 구조(secure canvas)에 기대는 우회다. 화면은
//  멀쩡한데 보호만 조용히 풀릴 수 있어서 `SecureCanvasProbe` 로 매번 계측해야 한다.
//  `ScreenshotGuard` 는 그보다 더 뒤, 이미 찍힌 뒤의 감사 신호다.
//  AutomaticAssessmentConfiguration(이하 AAC)은 그 둘과 달리 **정식 경로**다.
//  세션이 켜져 있는 동안 iPadOS 가 시스템 수준에서 캡처·전환·알림을 막으므로
//  사진 앱에 파일 자체가 생기지 않는다. 대신 Apple 승인 entitlement
//  (`com.apple.developer.automatic-assessment-configuration`)가 필요하다.
//
//  그래서 지금은 **켜지지 않는 상태로** 만들어 둔다. entitlement 가 없으면
//  `begin()` 이 실패하는데, 이 파일에서 중요한 건 그 실패 경로가 "정상 동작"
//  이라는 것이다 — 실패하면 민감 콘텐츠를 그리지 않고 조용히 내려온다.
//
//  ## fail closed 가 이 파일의 전부다
//  `assessmentSessionDidBegin` 이 오기 **전에는** 문제·풀이를 한 프레임도 그리지
//  않는다. 판정점은 `allowsSensitiveContent` 하나뿐이고, 그 값이 참인 상태는
//  `.secured` 밖에 없다. 나머지 전부(준비 중·실패·중단·종료·idle)는 가려진다.
//  "실패했으니 그냥 평소처럼 보여 주자" 가 이 기능에서 제일 위험한 회귀다 —
//  보호가 안 켜졌는데 학생은 켜진 줄 알고 시험을 본다.
//
//  ## 기존 보호는 건드리지 않는다
//  `ScreenshotGuard` · `SecureCaptureCanvas` 와 나란히 두기만 한다. AAC 가 승인되면
//  그때 무엇을 대체할지 판단한다. 지금 섣불리 겹쳐 두면 어느 쪽이 실제로 막고
//  있는지 알 수 없게 되고, 그건 보호가 아니라 착각이다.
//
//  ## 2026-08-18: 배선했다. 그리고 **콘텐츠 게이팅은 아직 켜지 않았다**
//  `ScreenshotGuard` 가 시험 화면(주간모의고사·배치고사·KICE·아레나 경기)이 뜰 때
//  `beginSecuredSession()`, 사라질 때 `endSecuredSession()` 을 부른다.
//  `AssessmentLockScope` 가 그 목록의 유일한 진실원이다.
//
//  **중요 — 위의 fail closed 설명과 실제 배선이 다른 지점이 하나 있다.**
//  entitlement 가 아직 없으므로 기기에서 `begin()` 은 거의 확실히 실패한다.
//  그때 `allowsSensitiveContent` 로 문제를 가려 버리면 **시험을 못 본다** — 보호가
//  아니라 서비스 중단이다. 그래서 지금 호출부가 보는 값은 `allowsSensitiveContent`
//  가 아니라 `protectionTier` 이고, 실패는 `.bestEffort` (녹화·미러링 덮개 +
//  앱 전환 덮개 + 워터마크 + 스크린샷 사후 기록)로 **조용히 폴백**한다.
//
//  `allowsSensitiveContent` / `isShieldRaised` 는 지우지 않고 남긴다. entitlement 가
//  승인되어 "AAC 가 안 걸리면 시험을 시작하지 않는다" 로 정책이 바뀌는 날, 화면들이
//  이 값 하나만 보면 되도록. 그날까지 이 두 값을 읽는 화면은 없다 —
//  **감독 확인 요망**: 승인 후 그 정책으로 전환할지.
//
//  ## entitlement 승인 시 함께 정해야 하는 것 — 감독 확인 요망
//   - 접근성 예외(`allowsAccessibilitySpeech` 등)를 시험 중 열어 줄지.
//     지금 기본값은 전부 잠금이다. VoiceOver 자체는 AAC 가 끄지 않지만
//     "화면 읽기/선택 항목 말하기" 는 막힌다.
//   - `ScreenIntegrityEventContract` 에 AAC 상태 이벤트를 추가할지. 그 파일의
//     화이트리스트는 서버와의 계약이라 클라이언트 혼자 늘릴 수 없어서 지금은
//     아무 이벤트도 보내지 않는다.

import Foundation
import AutomaticAssessmentConfiguration
import SwiftUI

// MARK: - 상태

/// 잠금 세션의 수명. `.secured` 하나만 민감 콘텐츠를 허용한다.
enum AssessmentSecurityState: Equatable {
    case idle
    /// 설정을 만들고 세션 객체를 준비하는 구간.
    case preparing
    /// `begin()` 은 불렀고 `assessmentSessionDidBegin` 은 아직 안 왔다.
    /// **여기서 콘텐츠를 그리면 fail closed 가 깨진다.**
    case securing
    /// 시스템이 잠금을 실제로 걸었다. 유일하게 콘텐츠를 그려도 되는 상태.
    case secured
    /// 세션이 중간에 풀렸다(전화, 시스템 사정 등). 즉시 가리고 정리한다.
    case interrupted(reason: String)
    /// `end()` 를 부르고 `assessmentSessionDidEnd` 를 기다리는 중.
    case ending
    case ended
    /// `begin()` 자체가 실패했다. entitlement 미승인이 여기로 온다 — 정상 경로다.
    case failed(reason: String)

    /// 민감 콘텐츠(문제·풀이·정답)를 그려도 되는가. 화이트리스트 한 줄로 둔다.
    /// 상태가 늘어날 때 `!= .idle` 같은 블랙리스트로 쓰면 새 상태가 자동으로
    /// "허용" 쪽에 떨어진다 — 그 방향의 실수는 곧 유출이다.
    var allowsSensitiveContent: Bool {
        if case .secured = self { return true }
        return false
    }

    var isTerminal: Bool {
        switch self {
        case .ended, .failed: return true
        case .idle, .preparing, .securing, .secured, .interrupted, .ending: return false
        }
    }

    /// 로그·자가진단용 비식별 이름. 학생 정보는 절대 담지 않는다.
    var diagnosticName: String {
        switch self {
        case .idle: return "idle"
        case .preparing: return "preparing"
        case .securing: return "securing"
        case .secured: return "secured"
        case .interrupted(let reason): return "interrupted:\(reason)"
        case .ending: return "ending"
        case .ended: return "ended"
        case .failed(let reason): return "failed:\(reason)"
        }
    }
}

// MARK: - 보호 등급

/// 지금 이 순간 화면이 실제로 어느 등급으로 보호되고 있는가.
///
/// **이 타입이 존재하는 이유가 이 기능의 핵심이다.** "스크린샷이 검게 저장된다"는
/// 오직 `.systemLocked` 에서만 참이다. entitlement 가 없으면 `.bestEffort` 이고,
/// 그 등급에서 스크린샷은 **그대로 찍힌다** — 찍힌 뒤 기록될 뿐이다.
/// 두 등급을 한 개의 불리언("보호 중")으로 뭉개면 감독도 학생도 막히지 않는 것을
/// 막힌다고 읽게 된다. 그게 이 프로젝트에서 이미 한 번 일어난 사고다.
enum AssessmentProtectionTier: Equatable, Sendable {
    /// AAC 세션이 실제로 걸렸다. iPadOS 가 스크린샷·녹화·앱 전환을 시스템에서 막는다.
    case systemLocked
    /// AAC 가 없거나 실패했다. 녹화·미러링 덮개 + 앱 전환 덮개 + 워터마크 +
    /// 스크린샷 사후 기록만 남는다. **스크린샷 자체는 막지 못한다.**
    case bestEffort

    var blocksScreenshots: Bool { self == .systemLocked }
}

/// AAC 잠금을 걸 화면 목록. `ScreenIntegrityEventContract.allowedSurfaces` 의 부분집합이다.
///
/// **왜 화면 이름으로 판정하는가.** `ScreenshotGuard` 는 이미 화면마다
/// `beginProtection(_:surface:)` 로 자기 이름을 등록한다. 라우트 열거형을 다시
/// 들여다보면 판정점이 둘이 되고, 언젠가 한쪽에만 화면이 추가된다. 등록된 이름
/// 하나만 본다.
///
/// **왜 전부가 아니라 이 넷인가.** AAC 는 기기를 단일 앱 모드로 잠근다 — 학생이
/// 홈으로도 못 나간다. 그건 "시험 중" 에만 정당하다. 빠른 연습·풀이·결과 화면
/// (`isProblemSolvingRoute` 의 나머지)까지 잠그면 공부하다 기기에 갇힌다.
/// 보호 범위를 전 화면으로 넓혔다가 앱을 못 쓰게 만든 2026-08-17 사고와 같은 실수다.
///
/// `assessment-paper`(시험지 사진 분석)는 뺀다 — 감독이 지정한 시험 넷에 없고,
/// 자기 시험지를 찍어 올려 분석하는 화면이라 기기를 잠글 이유가 없다.
enum AssessmentLockScope {
    /// 감독 지정: 주간모의고사 · 배치고사 · KICE · 아레나 경기.
    static let lockedSurfaces: Set<String> = [
        "weekly-mock",
        "placement-exam",
        "kice-exam",
        "goat-arena-match",
    ]

    /// `ScreenshotGuard` 는 겹친 화면 이름을 쉼표로 합쳐 들고 있으므로 쪼개서 본다.
    static func locksSystem(_ surface: String) -> Bool {
        surface
            .split(separator: ",")
            .contains { lockedSurfaces.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }
    }
}

// MARK: - 실패 표현

/// 콜백으로 받은 `Error` 를 경계에서 곧바로 값으로 바꿔 둔다.
///
/// `Error` 를 그대로 상태에 들고 다니면 (1) 비교·테스트가 불가능해지고
/// (2) `userInfo` 에 뭐가 들었는지 모르는 채로 로그에 흘릴 위험이 생긴다.
/// 여기서 도메인·코드와 **고정 문자열 진단명**만 남기고 나머지는 버린다.
struct AssessmentSecurityFailure: Equatable, Sendable {
    let domain: String
    let code: Int
    let diagnosis: String

    init(domain: String, code: Int, diagnosis: String) {
        self.domain = domain
        self.code = code
        self.diagnosis = diagnosis
    }

    init(_ error: Error) {
        let nsError = error as NSError
        self.init(
            domain: nsError.domain,
            code: nsError.code,
            diagnosis: Self.diagnosis(domain: nsError.domain, code: nsError.code))
    }

    /// AAC 오류 코드를 고정 문자열로 접는다.
    ///
    /// **왜 심볼 대신 raw 값인가.** `AEAssessmentError.Code` 의 케이스들은
    /// `.multipleParticipantsNotSupported` 가 iOS 17.5, `.requiredParticipantsNotAvailable`
    /// 가 iOS 26.0 부터라 배포 타깃(17.0)에서 심볼을 쓰면 진단 문자열 하나 만들자고
    /// `if #available` 사다리를 쌓아야 한다. 값은 `AEErrors.h` 에 고정된 ABI 이므로
    /// 여기서는 숫자로 읽고, 매핑을 주석으로 못 박는다.
    ///
    /// 그리고 **어떤 코드도 "entitlement 없음" 을 뜻하지 않는다.** 미승인 상태의
    /// begin 실패는 보통 `unknown(1)` 로 온다 — 다른 원인과 구분되지 않는다.
    /// 따라서 코드로 분기해 완화하지 않고, begin 실패는 전부 똑같이 닫는다.
    private static func diagnosis(domain: String, code: Int) -> String {
        guard domain == AEAssessmentErrorDomain else {
            return "foreign-domain"
        }
        switch code {
        case 1: return "aac-unknown"                            // AEAssessmentErrorUnknown
        case 2: return "aac-unsupported-platform"               // …UnsupportedPlatform (iOS 16+)
        case 3: return "aac-multiple-participants-unsupported"  // …MultipleParticipantsNotSupported (iOS 17.5+)
        case 4: return "aac-configuration-updates-unsupported"  // …ConfigurationUpdatesNotSupported (iOS 17.5+)
        case 5: return "aac-required-participants-unavailable"  // …RequiredParticipantsNotAvailable (iOS 26+)
        default: return "aac-code-\(code)"
        }
    }

    /// 워치독이 만드는 실패. 시스템에서 온 오류가 아니므로 도메인을 따로 둔다.
    static func timeout(_ phase: String) -> AssessmentSecurityFailure {
        AssessmentSecurityFailure(
            domain: "matths.assessment-security",
            code: -1,
            diagnosis: "timeout-\(phase)")
    }
}

// MARK: - 정책

/// 시험 중 열어 줄 예외. AAC 는 기본이 전부 잠금이고, 여기서 켜는 것만 풀린다.
///
/// 기본값을 전부 `false` 로 둔 것은 취향이 아니라 fail closed 다. 필요한 예외는
/// 감독이 명시적으로 켜야 하고, 그 결정이 코드에 남는다.
struct AssessmentSecurityPolicy: Equatable, Sendable {
    var allowsSpellCheck = false
    var allowsPredictiveKeyboard = false
    var allowsKeyboardShortcuts = false
    var allowsContinuousPathKeyboard = false
    var allowsPasswordAutoFill = false
    var allowsDictation = false
    /// Handoff. 켜면 옆 기기에서 같은 화면을 이어받을 수 있다 — 시험에서는 잠근다.
    var allowsActivityContinuation = false
    /// 화면 읽기·선택 항목 말하기. VoiceOver 자체는 AAC 가 끄지 않는다.
    /// 켤지 말지는 접근성과 무결성이 정면으로 부딪히는 지점이라 감독 판단이다.
    var allowsAccessibilitySpeech = false
    /// 자동 수정. `[]` 는 전부 끔.
    var autocorrect: AEAssessmentConfiguration.AutocorrectMode = []
    /// 우리 앱 자신의 네트워크. 채점·동기화가 서버를 타므로 기본은 허용이다.
    /// (iOS 17.5+ 에서만 실제로 적용된다.)
    var allowsNetworkAccess = true

    func makeConfiguration() -> AEAssessmentConfiguration {
        let configuration = AEAssessmentConfiguration()
        configuration.allowsSpellCheck = allowsSpellCheck
        configuration.allowsPredictiveKeyboard = allowsPredictiveKeyboard
        configuration.allowsKeyboardShortcuts = allowsKeyboardShortcuts
        configuration.allowsContinuousPathKeyboard = allowsContinuousPathKeyboard
        configuration.allowsPasswordAutoFill = allowsPasswordAutoFill
        configuration.allowsDictation = allowsDictation
        configuration.allowsActivityContinuation = allowsActivityContinuation
        configuration.allowsAccessibilitySpeech = allowsAccessibilitySpeech
        configuration.autocorrectMode = autocorrect
        if #available(iOS 17.5, *) {
            configuration.mainParticipantConfiguration.allowsNetworkAccess = allowsNetworkAccess
        }
        return configuration
    }
}

// MARK: - 세션 추상화

/// 상태머신이 받는 신호. `Error` 대신 값 타입으로 바꿔 넘긴다(위 `AssessmentSecurityFailure` 참고).
enum AssessmentSessionSignal: Equatable, Sendable {
    case didBegin
    case failedToBegin(AssessmentSecurityFailure)
    case wasInterrupted(AssessmentSecurityFailure)
    case didEnd
}

/// 코디네이터가 보는 세션. 실제 `AEAssessmentSession` 과 mock 을 갈아끼우는 이음매다.
///
/// 시뮬레이터에는 entitlement 도 없고 AAC 의 잠금 동작 자체도 없다. 그래서
/// 실물 세션으로는 "성공 경로" 를 한 번도 밟아 볼 수 없다 — mock 이 없으면
/// `.secured` 로 가는 전이가 기기 승인 전까지 통째로 미검증으로 남는다.
@MainActor
protocol AssessmentSessionDriving: AnyObject {
    var signals: ((AssessmentSessionSignal) -> Void)? { get set }
    var isActive: Bool { get }
    func begin()
    func end()
}

/// AAC 델리게이트는 `@objc` 프로토콜이라 `NSObject` 가 필요하고, 콜백 스레드도
/// 문서로 보장되지 않는다. 그 두 가지 지저분함을 이 작은 클래스 안에 가둔다.
private final class AEAssessmentSessionDelegateProxy: NSObject, AEAssessmentSessionDelegate {
    /// 세션 → 드라이버 방향 전달구.
    ///
    /// `let` 이 아니라 `var` 인 이유: 드라이버가 자기 자신을 **약하게** 꽂아 넣어야
    /// 하는데(드라이버 → 프록시는 strong 이므로 반대 방향이 strong 이면 순환이다),
    /// `self` 는 드라이버의 저장 프로퍼티가 전부 채워진 뒤에야 캡처할 수 있다.
    /// 그래서 프록시를 먼저 만들고 init 끝에서 채운다.
    var forward: ((AssessmentSessionSignal) -> Void)?

    func assessmentSessionDidBegin(_ session: AEAssessmentSession) {
        forward?(.didBegin)
    }

    func assessmentSession(_ session: AEAssessmentSession, failedToBeginWithError error: Error) {
        forward?(.failedToBegin(AssessmentSecurityFailure(error)))
    }

    func assessmentSession(_ session: AEAssessmentSession, wasInterruptedWithError error: Error) {
        forward?(.wasInterrupted(AssessmentSecurityFailure(error)))
    }

    func assessmentSessionDidEnd(_ session: AEAssessmentSession) {
        forward?(.didEnd)
    }
}

/// 실물 `AEAssessmentSession` 구동부.
@MainActor
final class SystemAssessmentSessionDriver: AssessmentSessionDriving {
    var signals: ((AssessmentSessionSignal) -> Void)?

    /// **세션과 프록시 둘 다 strong 으로 붙든다.**
    /// `AEAssessmentSession.delegate` 는 weak 이므로 프록시를 여기서 붙들지 않으면
    /// begin 콜백이 오기 전에 해제되어 아무 신호도 안 온다. 세션 자체도 마찬가지로
    /// 놓치면 잠금이 언제 풀렸는지 알 수 없다. 둘 중 하나만 빠져도 상태머신은
    /// `.securing` 에서 굳고, fail closed 라 화면은 가려진 채 영원히 안 열린다.
    private let session: AEAssessmentSession
    private let delegateProxy: AEAssessmentSessionDelegateProxy

    init(configuration: AEAssessmentConfiguration) {
        let proxy = AEAssessmentSessionDelegateProxy()
        session = AEAssessmentSession(configuration: configuration)
        delegateProxy = proxy
        session.delegate = proxy
        proxy.forward = { [weak self] signal in
            AssessmentSecurityMainActorHop.run { self?.signals?(signal) }
        }
    }

    var isActive: Bool { session.isActive }

    func begin() { session.begin() }

    func end() { session.end() }
}

/// 시뮬레이터·유닛 검증용 세션. AAC 를 전혀 건드리지 않는다.
@MainActor
final class MockAssessmentSessionDriver: AssessmentSessionDriving {
    /// `begin()` 을 부른 뒤 시스템이 어떻게 답하는지.
    enum Behavior: Equatable, Sendable {
        /// 승인된 기기.
        case beginsSuccessfully
        /// entitlement 미승인·미지원 기기. **지금 시뮬레이터의 실제 모습이다.**
        case failsToBegin(AssessmentSecurityFailure)
        /// 아무 콜백도 오지 않는다. 워치독이 없으면 `.securing` 에 영원히 갇히는 경로.
        case silent
    }

    /// 세션 수명. `isActive` 하나로는 종료 신호를 흉내 낼 수 없어서 따로 둔다 —
    /// 중단된 세션은 `isActive == false` 이지만 `end()` 에 여전히 `didEnd` 로 답한다.
    /// 이걸 `isActive` 로 갈음하면 중단 → 종료 경로가 mock 에서만 영원히 안 닫히고,
    /// 그 차이를 코디네이터 버그로 오독하게 된다.
    private enum Lifecycle {
        case notStarted
        case running
        case interrupted
        case finished
    }

    var signals: ((AssessmentSessionSignal) -> Void)?
    private(set) var beginCallCount = 0
    private(set) var endCallCount = 0
    private let behavior: Behavior
    private var lifecycle: Lifecycle = .notStarted

    var isActive: Bool { lifecycle == .running }

    init(behavior: Behavior = .beginsSuccessfully) {
        self.behavior = behavior
    }

    func begin() {
        beginCallCount += 1
        switch behavior {
        case .beginsSuccessfully:
            simulateBegin()
        case .failsToBegin(let failure):
            lifecycle = .finished
            signals?(.failedToBegin(failure))
        case .silent:
            // 시스템이 아무 답도 주지 않는 기기. 수명도 시작되지 않는다.
            break
        }
    }

    func end() {
        endCallCount += 1
        switch lifecycle {
        case .notStarted, .finished:
            // 시작한 적 없거나 이미 끝난 세션에는 시스템도 답하지 않는다.
            break
        case .running, .interrupted:
            lifecycle = .finished
            signals?(.didEnd)
        }
    }

    /// 잠금 확인이 늦게 오는 기기를 재현한다(`.silent` 과 짝으로 쓴다).
    func simulateBegin() {
        guard lifecycle == .notStarted else { return }
        lifecycle = .running
        signals?(.didBegin)
    }

    /// 시스템이 세션을 중간에 푼 상황(전화 수신 등)을 재현한다.
    func simulateInterruption(_ failure: AssessmentSecurityFailure) {
        guard lifecycle == .running else { return }
        lifecycle = .interrupted
        signals?(.wasInterrupted(failure))
    }
}

/// 콜백이 어느 스레드로 올지 AAC 가 보장하지 않아서 두는 경계.
/// 메인이면 그대로 실행하고(불필요한 한 프레임 지연이 곧 민감 콘텐츠 노출 시간이다),
/// 아니면 메인으로 넘긴다.
enum AssessmentSecurityMainActorHop {
    static func run(_ body: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { body() }
        } else {
            Task { @MainActor in body() }
        }
    }
}

// MARK: - 코디네이터

/// AAC 잠금 세션의 상태머신.
///
/// idle → preparing → securing → secured → interrupted/ending → ended/failed
///
/// 화면은 `state` 를 직접 해석하지 말고 `allowsSensitiveContent` / `isShieldRaised`
/// 두 값만 본다. 상태가 늘어날 때마다 화면들이 각자 분기를 늘리면 언젠가 한 곳이
/// 빠지고, 그 한 곳이 유출이 된다.
@MainActor
final class AssessmentSecurityCoordinator: ObservableObject {
    typealias DriverFactory = @MainActor (AEAssessmentConfiguration) -> AssessmentSessionDriving

    @Published private(set) var state: AssessmentSecurityState = .idle

    /// 민감 콘텐츠를 그려도 되는 유일한 판정점.
    var allowsSensitiveContent: Bool { state.allowsSensitiveContent }

    /// 가림막을 세워야 하는가. `allowsSensitiveContent` 의 정확한 여집합이다 —
    /// 두 값을 따로 계산하면 언젠가 둘 다 false 인 순간이 생긴다(= 맨 화면).
    var isShieldRaised: Bool { !state.allowsSensitiveContent }

    /// **호출부가 실제로 읽는 값.** 지금은 실패해도 시험을 계속 볼 수 있어야 하므로
    /// (파일 머리말의 "콘텐츠 게이팅은 아직 켜지 않았다" 참고) 상태를 가림막이 아니라
    /// 보호 등급으로 번역해 넘긴다.
    var protectionTier: AssessmentProtectionTier {
        state.allowsSensitiveContent ? .systemLocked : .bestEffort
    }

    /// 상태가 바뀔 때마다 호출된다. 지금 값도 함께 넘겨서, 받는 쪽이 코디네이터를
    /// 다시 캡처해 들여다보지 않아도 되게 한다(그 캡처가 곧 참조 순환이 된다).
    var onStateChange: ((AssessmentSecurityState) -> Void)?

    let policy: AssessmentSecurityPolicy

    private let makeDriver: DriverFactory
    private let beginTimeout: Duration
    private let endTimeout: Duration
    private var driver: AssessmentSessionDriving?
    private var watchdog: Task<Void, Never>?

    #if DEBUG
    /// 자가진단이 전이 순서를 통째로 확인할 수 있게 남긴다.
    private(set) var stateHistory: [String] = [AssessmentSecurityState.idle.diagnosticName]
    #endif

    /// - Parameter makeDriver: `nil` 이면 실물 `AEAssessmentSession` 을 쓴다.
    ///   기본값 표현식 안에서 MainActor 격리 멤버를 부르지 않으려고 옵셔널로 받는다.
    init(
        policy: AssessmentSecurityPolicy = AssessmentSecurityPolicy(),
        beginTimeout: Duration = .seconds(6),
        endTimeout: Duration = .seconds(4),
        makeDriver: DriverFactory? = nil
    ) {
        self.policy = policy
        self.beginTimeout = beginTimeout
        self.endTimeout = endTimeout
        self.makeDriver = makeDriver ?? { configuration in
            SystemAssessmentSessionDriver(configuration: configuration)
        }
    }

    // MARK: 외부 진입점

    /// 잠금을 요청한다. 성공하든 실패하든 이 호출 직후부터 화면은 가려진 상태다.
    func beginSecuredSession() {
        switch state {
        case .idle, .ended, .failed:
            break
        case .preparing, .securing, .secured, .interrupted, .ending:
            // 이미 진행 중이다. 세션을 두 번 만들면 앞의 것이 delegate 를 잃는다.
            return
        }

        transition(to: .preparing)
        let driver = makeDriver(policy.makeConfiguration())
        self.driver = driver
        driver.signals = { [weak self] signal in
            self?.handle(signal)
        }
        // mock 은 `begin()` 안에서 곧바로 콜백을 준다. 그래서 `.securing` 은
        // 반드시 `begin()` **전에** 찍어야 전이 순서가 뒤집히지 않는다.
        transition(to: .securing)
        armWatchdog(beginTimeout, phase: "begin")
        driver.begin()
    }

    /// 잠금을 정상 종료한다.
    ///
    /// 화면이 사라질 때 반드시 불러야 한다. 부르지 않으면 iPadOS 는 세션을 계속
    /// 유지하고, 사용자는 홈으로도 못 나가는 기기에 갇힌다. `deinit` 에 기대지
    /// 않는 이유는 그 시점이 MainActor 밖이라 여기서 상태를 정리할 수 없어서다.
    func endSecuredSession() {
        switch state {
        case .idle, .ended, .failed, .ending:
            return
        case .preparing:
            // 아직 begin 전이다. 시스템에 알릴 것이 없으니 바로 닫는다.
            finish(with: .ended)
        case .securing, .secured, .interrupted:
            transition(to: .ending)
            armWatchdog(endTimeout, phase: "end")
            driver?.end()
        }
    }

    // MARK: 신호 처리

    private func handle(_ signal: AssessmentSessionSignal) {
        switch signal {
        case .didBegin:
            // `.securing` 이 아닌 곳에서 온 didBegin 은 이전 세션의 잔향이다.
            // 그걸 받아 `.secured` 로 올리면 잠기지도 않은 화면이 열린다.
            guard case .securing = state else { return }
            cancelWatchdog()
            transition(to: .secured)

        case .failedToBegin(let failure):
            cancelWatchdog()
            // 잠금이 안 걸렸다. 완화하지 않는다 — 그대로 닫는다.
            releaseDriver(endingIfActive: true)
            transition(to: .failed(reason: failure.diagnosis))

        case .wasInterrupted(let failure):
            cancelWatchdog()
            // 먼저 가리고(= 상태 전이 자체가 가림막이다) 그다음 정리한다.
            transition(to: .interrupted(reason: failure.diagnosis))
            transition(to: .ending)
            armWatchdog(endTimeout, phase: "end")
            driver?.end()

        case .didEnd:
            cancelWatchdog()
            finish(with: .ended)
        }
    }

    private func handleWatchdogExpiry(phase: String) {
        let failure = AssessmentSecurityFailure.timeout(phase)
        switch state {
        case .securing:
            // 콜백이 끝내 오지 않았다. 잠겼는지 알 수 없으면 안 잠긴 것으로 친다.
            releaseDriver(endingIfActive: true)
            transition(to: .failed(reason: failure.diagnosis))
        case .ending:
            // 종료 확인이 안 왔다. 더 기다려 봐야 화면만 잠겨 있으므로 닫고 놓아준다.
            finish(with: .failed(reason: failure.diagnosis))
        case .idle, .preparing, .secured, .interrupted, .ended, .failed:
            break
        }
    }

    // MARK: 내부

    private func finish(with terminal: AssessmentSecurityState) {
        releaseDriver(endingIfActive: false)
        transition(to: terminal)
    }

    private func releaseDriver(endingIfActive: Bool) {
        if endingIfActive, let driver, driver.isActive {
            driver.end()
        }
        // 신호 경로를 먼저 끊는다. 끊지 않으면 해제 중인 드라이버의 늦은 콜백이
        // 다음 세션의 상태를 덮어쓴다.
        driver?.signals = nil
        driver = nil
        cancelWatchdog()
    }

    private func transition(to next: AssessmentSecurityState) {
        guard state != next else { return }
        state = next
        #if DEBUG
        stateHistory.append(next.diagnosticName)
        #endif
        onStateChange?(next)
    }

    private func armWatchdog(_ timeout: Duration, phase: String) {
        watchdog?.cancel()
        watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.handleWatchdogExpiry(phase: phase)
        }
    }

    private func cancelWatchdog() {
        watchdog?.cancel()
        watchdog = nil
    }
}

// MARK: - 자가진단 (DEBUG)

#if DEBUG
/// `ScreenshotGuard` 가 만들어질 때 실행된다(`-assessmentSecuritySelfTest`).
/// **왜 `MatthsApp` 의 다른 self test 들 옆이 아닌가**: 이번 세션에서 그 파일은
/// 다른 작업자가 동시에 고치고 있어 손대지 않았다. 배선 위치를 옮기는 건 나중에
/// 안전할 때 한다(needsOtherFiles 참고).
///
/// 여기서 확인하는 건 AAC 가 실제로 잠그는지가 **아니다** — 그건 시뮬레이터에서
/// 잴 수 없다(그건 아래 `AssessmentSecurityLiveProbe` 가 실물로 잰다).
/// 확인하는 건 상태머신이 fail closed 인지, 즉 어떤 경로로도
/// `.secured` 를 거치지 않고 콘텐츠가 열리지 않는지다.
@MainActor
enum AssessmentSecuritySelfTest {
    struct Report: Codable {
        let schemaVersion: String
        let result: String
        let contentHiddenBeforeDidBegin: Bool
        let contentShownOnlyWhenSecured: Bool
        let normalSessionClosesToEnded: Bool
        let beginFailureStaysHidden: Bool
        let interruptionHidesImmediately: Bool
        let interruptionClosesToEnded: Bool
        let silentSessionTimesOutClosed: Bool
        let doubleBeginIgnored: Bool
        /// begin 실패가 **시험을 막지 않고** 차선책 등급으로 내려앉는가.
        /// 이 줄이 FAIL 이면 entitlement 없는 기기에서 학생이 시험을 못 본다.
        let failureFallsBackToBestEffort: Bool
        /// 반대로, 잠기지 않았는데 `.systemLocked` 이라고 말하지 않는가.
        let securedReportsSystemLock: Bool
        /// 잠금 대상이 감독이 지정한 시험 넷과 정확히 같은가.
        let lockScopeMatchesExamSurfaces: Bool
        /// 시험 화면 등록이 실제로 세션을 여는가(`ScreenshotGuard` 배선까지 포함).
        let examSurfaceOpensLock: Bool
        /// 시험 화면을 떠나면 세션이 닫히는가. **닫히지 않으면 기기가 앱에 갇힌다.**
        let leavingExamClosesLock: Bool
        /// 시험이 아닌 보호 화면은 세션을 열지 않는가(2026-08-17 사고 재발 방지).
        let nonExamSurfaceStaysUnlocked: Bool
        let histories: [String]
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-assessmentSecuritySelfTest") else { return }
        Task { @MainActor in
            let report = await run()
            guard let data = try? JSONEncoder().encode(report),
                  let text = String(data: data, encoding: .utf8) else { return }
            print("MATTHS_ASSESSMENT_SECURITY_SELF_TEST_V1 \(text)")
            // `simctl launch --console-pipe` 로 받으면 stdout 이 TTY 가 아니라
            // 전량 버퍼링된다. 리포트(1KB 미만)는 버퍼에 갇힌 채 앱이 종료되고,
            // QA 는 "self test 가 안 돈다" 로 오독한다 — 실제로는 돌았는데 안 보인 것뿐이다.
            fflush(stdout)
        }
    }

    static func run() async -> Report {
        var histories: [String] = []

        // 1. 정상 경로 — didBegin 이 늦게 오는 기기(`.silent` + 수동 확인)로 잡는다.
        //    begin() 이 곧바로 답해 버리면 "didBegin 전" 이라는 구간이 없어져
        //    fail closed 를 확인할 틈 자체가 사라진다.
        let happyDriver = MockAssessmentSessionDriver(behavior: .silent)
        let happy = AssessmentSecurityCoordinator(makeDriver: { _ in happyDriver })
        happy.beginSecuredSession()
        let contentHiddenBeforeDidBegin = !happy.allowsSensitiveContent && happy.isShieldRaised
        happyDriver.simulateBegin()
        let contentShownOnlyWhenSecured = happy.allowsSensitiveContent && happy.state == .secured
        let securedReportsSystemLock = happy.protectionTier == .systemLocked
        happy.endSecuredSession()
        // 워치독이 아니라 시스템의 didEnd 로 닫혀야 한다. `.ending` 에 머무르면
        // 잠금은 이미 풀렸는데 화면만 계속 가려진 채로 남는다.
        let normalSessionClosesToEnded = happy.state == .ended && !happy.allowsSensitiveContent
        histories.append(happy.stateHistory.joined(separator: ">"))

        // 2. entitlement 미승인 — 실패해도 절대 열리지 않는다.
        let denial = AssessmentSecurityFailure(
            domain: AEAssessmentErrorDomain, code: 1, diagnosis: "aac-unknown")
        let denied = AssessmentSecurityCoordinator(
            makeDriver: { _ in MockAssessmentSessionDriver(behavior: .failsToBegin(denial)) })
        denied.beginSecuredSession()
        let beginFailureStaysHidden = !denied.allowsSensitiveContent
            && denied.state == .failed(reason: "aac-unknown")
        // 그리고 그 실패가 **차선책으로 내려앉는지**. 위 한 줄과 반대 방향의 확인이다 —
        // `allowsSensitiveContent` 는 여전히 false 여야 하지만(그게 fail closed 계약),
        // 호출부가 읽는 `protectionTier` 는 `.bestEffort` 여야 시험이 계속된다.
        let failureFallsBackToBestEffort = denied.protectionTier == .bestEffort
        histories.append(denied.stateHistory.joined(separator: ">"))

        // 3. 중단 — 신호를 받는 즉시 닫힌다.
        let interruptedDriver = MockAssessmentSessionDriver(behavior: .beginsSuccessfully)
        let interrupted = AssessmentSecurityCoordinator(makeDriver: { _ in interruptedDriver })
        interrupted.beginSecuredSession()
        interruptedDriver.simulateInterruption(
            AssessmentSecurityFailure(domain: AEAssessmentErrorDomain, code: 1, diagnosis: "aac-unknown"))
        let interruptionHidesImmediately = !interrupted.allowsSensitiveContent
        // 중단된 세션도 끝까지 닫혀야 한다 — 호출부가 아무것도 안 해도.
        let interruptionClosesToEnded = interrupted.state == .ended
        histories.append(interrupted.stateHistory.joined(separator: ">"))

        // 4. 콜백이 아예 안 오는 기기 — 워치독이 닫는다.
        let silent = AssessmentSecurityCoordinator(
            beginTimeout: .milliseconds(40),
            makeDriver: { _ in MockAssessmentSessionDriver(behavior: .silent) })
        silent.beginSecuredSession()
        try? await Task.sleep(for: .milliseconds(300))
        let silentSessionTimesOutClosed = !silent.allowsSensitiveContent && silent.state.isTerminal
        histories.append(silent.stateHistory.joined(separator: ">"))

        // 5. 중복 시작 — 두 번째 호출은 세션을 새로 만들지 않는다.
        let doubleDriver = MockAssessmentSessionDriver(behavior: .beginsSuccessfully)
        let double = AssessmentSecurityCoordinator(makeDriver: { _ in doubleDriver })
        double.beginSecuredSession()
        double.beginSecuredSession()
        let doubleBeginIgnored = doubleDriver.beginCallCount == 1
        double.endSecuredSession()
        histories.append(double.stateHistory.joined(separator: ">"))

        // 6. 잠금 범위 — 시험 넷만 잠그고, 나머지 보호 화면은 잠그지 않는다.
        //    "제어센터만 열어도 화면이 검게 덮이던" 2026-08-17 사고의 재발 방지선이다.
        let mustLock = ["weekly-mock", "placement-exam", "kice-exam", "goat-arena-match"]
        let mustNotLock = ["session", "assessment", "assessment-paper", "goat-arena", "protected"]
        let lockScopeMatchesExamSurfaces =
            mustLock.allSatisfy { AssessmentLockScope.locksSystem($0) }
            && mustNotLock.allSatisfy { !AssessmentLockScope.locksSystem($0) }
            // 화면이 겹쳐 이름이 합쳐져 들어와도 시험 하나가 섞여 있으면 잠근다.
            && AssessmentLockScope.locksSystem("assessment,kice-exam")

        // 7. **배선 자체**를 확인한다 — 상태머신이 아니라 `ScreenshotGuard` 와의 접합부.
        //    여기가 이 기능에서 가장 조용히 깨지는 곳이다. 코디네이터는 완벽한데
        //    아무도 부르지 않아 시험 화면이 그냥 안 잠기는 상태가 되고, 상태머신
        //    테스트는 여전히 전부 PASS 라 아무도 눈치채지 못한다.
        let wiringDriver = MockAssessmentSessionDriver(behavior: .beginsSuccessfully)
        let wiredGuard = ScreenshotGuard(
            assessmentLock: AssessmentSecurityCoordinator(makeDriver: { _ in wiringDriver }))
        let examSurface = wiredGuard.simulateAssessmentSurfaceForDeviceQA("kice-exam")
        let examSurfaceOpensLock = wiringDriver.beginCallCount == 1
            && wiredGuard.assessmentProtectionTier == .systemLocked
        wiredGuard.endProtection(examSurface)
        let leavingExamClosesLock = wiringDriver.endCallCount == 1
            && wiredGuard.assessmentProtectionTier == .bestEffort

        // 8. 시험이 아닌 보호 화면은 잠그지 않는다. 빠른 연습·시험지 분석까지 잠그면
        //    학생이 공부하다 기기에 갇힌다 — 보호 범위를 넓혔다가 앱을 못 쓰게 만든
        //    2026-08-17 사고와 같은 실수다.
        let idleDriver = MockAssessmentSessionDriver(behavior: .beginsSuccessfully)
        let unlockedGuard = ScreenshotGuard(
            assessmentLock: AssessmentSecurityCoordinator(makeDriver: { _ in idleDriver }))
        unlockedGuard.setBaseProtection(true)
        _ = unlockedGuard.simulateAssessmentSurfaceForDeviceQA("assessment-paper")
        let nonExamSurfaceStaysUnlocked = idleDriver.beginCallCount == 0
            && unlockedGuard.assessmentProtectionTier == .bestEffort

        let passed = contentHiddenBeforeDidBegin
            && contentShownOnlyWhenSecured
            && normalSessionClosesToEnded
            && beginFailureStaysHidden
            && interruptionHidesImmediately
            && interruptionClosesToEnded
            && silentSessionTimesOutClosed
            && doubleBeginIgnored
            && failureFallsBackToBestEffort
            && securedReportsSystemLock
            && lockScopeMatchesExamSurfaces
            && examSurfaceOpensLock
            && leavingExamClosesLock
            && nonExamSurfaceStaysUnlocked

        return Report(
            schemaVersion: "MATTHS_ASSESSMENT_SECURITY_SELF_TEST_V1",
            result: passed ? "PASS" : "FAIL",
            contentHiddenBeforeDidBegin: contentHiddenBeforeDidBegin,
            contentShownOnlyWhenSecured: contentShownOnlyWhenSecured,
            normalSessionClosesToEnded: normalSessionClosesToEnded,
            beginFailureStaysHidden: beginFailureStaysHidden,
            interruptionHidesImmediately: interruptionHidesImmediately,
            interruptionClosesToEnded: interruptionClosesToEnded,
            silentSessionTimesOutClosed: silentSessionTimesOutClosed,
            doubleBeginIgnored: doubleBeginIgnored,
            failureFallsBackToBestEffort: failureFallsBackToBestEffort,
            securedReportsSystemLock: securedReportsSystemLock,
            lockScopeMatchesExamSurfaces: lockScopeMatchesExamSurfaces,
            examSurfaceOpensLock: examSurfaceOpensLock,
            leavingExamClosesLock: leavingExamClosesLock,
            nonExamSurfaceStaysUnlocked: nonExamSurfaceStaysUnlocked,
            histories: histories)
    }
}

/// **실물** `AEAssessmentSession` 을 한 번 열어 보고 결과만 적고 닫는다.
/// `-assessmentLockLiveProbe` 로 실행할 때만 돈다.
///
/// 위 self test 는 mock 으로 상태머신만 본다. 그것만으로는 "이 기기에서 AAC 가
/// 실제로 켜지는가" 라는 유일하게 중요한 질문에 답할 수 없다 — entitlement 승인
/// 여부는 코드로 알 수 없고, 물어볼 공개 API 도 없다. 그래서 **직접 열어 본다.**
///
/// 결과를 신뢰해도 되는 이유: 이 프로브는 `SystemAssessmentSessionDriver` 를 쓰므로
/// 시험 화면이 실제로 밟는 경로와 같다. 다른 점은 4초 뒤 무조건 닫는다는 것뿐이다.
/// 만약 이 기기에 entitlement 가 있어 잠금이 실제로 걸리면, 그 4초 동안 기기가
/// 단일 앱 모드에 들어갔다가 스스로 풀린다.
@MainActor
enum AssessmentSecurityLiveProbe {
    struct Report: Codable {
        let schemaVersion: String
        /// "simulator" | "device"
        let environment: String
        /// 실제로 잠겼는가. 이 한 값이 entitlement 승인 여부의 유일한 실측이다.
        let systemLockAchieved: Bool
        let tier: String
        let finalState: String
        let history: [String]
    }

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-assessmentLockLiveProbe") else { return }
        Task { @MainActor in
            let report = await run()
            guard let data = try? JSONEncoder().encode(report),
                  let text = String(data: data, encoding: .utf8) else { return }
            print("MATTHS_ASSESSMENT_LOCK_LIVE_PROBE_V1 \(text)")
            fflush(stdout)   // 위와 같은 이유. 이 한 줄이 승인 확인의 유일한 실측이라 더 중요하다.
        }
    }

    static func run() async -> Report {
        // 실물 드라이버(makeDriver 기본값)로 연다. 시험 화면과 같은 경로여야 결과가 의미 있다.
        let coordinator = AssessmentSecurityCoordinator()
        coordinator.beginSecuredSession()
        // begin 은 비동기다. 델리게이트가 답할 시간을 준 뒤에 읽는다.
        try? await Task.sleep(for: .seconds(4))
        let locked = coordinator.protectionTier == .systemLocked
        let finalState = coordinator.state.diagnosticName
        coordinator.endSecuredSession()
        // 잠겼다면 반드시 풀고 나가야 한다 — 안 풀면 기기가 앱에 갇힌다.
        try? await Task.sleep(for: .seconds(1))

        #if targetEnvironment(simulator)
        let environment = "simulator"
        #else
        let environment = "device"
        #endif

        return Report(
            schemaVersion: "MATTHS_ASSESSMENT_LOCK_LIVE_PROBE_V1",
            environment: environment,
            systemLockAchieved: locked,
            tier: locked ? "system-locked" : "best-effort",
            finalState: finalState,
            history: coordinator.stateHistory)
    }
}
#endif
