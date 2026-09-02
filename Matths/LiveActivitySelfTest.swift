#if DEBUG
import ActivityKit
import Foundation
import UIKit

// Live Activity 표현 자가진단 — **DEBUG 전용, 실행 인자로만 켜진다.**
//
// 왜 필요한가. 잠금화면 배너와 다이나믹 아일랜드는 시뮬레이터/기기에서 실제로 띄워 보기
// 전에는 잘림·겹침을 알 수 없다(SwiftUI 프리뷰는 다이나믹 아일랜드의 실제 폭·카메라
// 컷아웃을 재현하지 않는다). 그래서 사람이 로그인하고 문제를 풀지 않아도 네 가지 표현
// (compact leading/trailing · minimal · expanded · 잠금화면)을 한 번에 띄울 수 있어야 한다.
//
//   xcrun simctl launch <udid> kr.matths.app -liveActivitySelfTest study
//   xcrun simctl launch <udid> kr.matths.app -liveActivitySelfTest arena
//   xcrun simctl launch <udid> kr.matths.app -liveActivitySelfTest both   ← minimal 확인용
//   xcrun simctl launch <udid> kr.matths.app -liveActivitySelfTestEnd
//
// `both` 는 배너를 두 개 띄운다. 다이나믹 아일랜드의 **minimal 표현은 진행 중인 활동이
// 둘 이상일 때만** 나타나기 때문이다 — 하나만 띄우면 minimal 코드는 영원히 눈으로 확인할
// 수 없다. 평소 제품 동작은 "동시에 하나"(LiveActivityController 의 불변식)이고, 여기서만
// 컨트롤러를 우회해 두 번째를 직접 요청한다.
@MainActor
enum LiveActivitySelfTest {

    private static let argument = "-liveActivitySelfTest"
    private static let endArgument = "-liveActivitySelfTestEnd"
    private static var activeObserver: NSObjectProtocol?

    /// 실행 인자에 요청이 있으면 앱이 활성화된 직후 한 번 실행한다.
    ///
    /// Activity.request 는 **앱이 포그라운드일 때만** 성공한다. didFinishLaunching 시점은
    /// 아직 활성 상태가 아니라서, 여기서는 관찰만 걸어 두고 활성화 알림에서 실제로 띄운다.
    static func startIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains(argument) || args.contains(endArgument) else { return }
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                if let observer = activeObserver {
                    NotificationCenter.default.removeObserver(observer)
                    activeObserver = nil
                }
                run(args)
            }
        }
    }

    @MainActor
    private static func run(_ args: [String]) {
        if args.contains(endArgument) {
            LiveActivityController.endAll()
            NSLog("LIVE-ACTIVITY-SELFTEST 모든 배너 종료 요청")
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            NSLog("LIVE-ACTIVITY-SELFTEST 실패: 이 기기/설정에서 실시간 현황이 꺼져 있다")
            return
        }
        let mode = value(after: argument, in: args) ?? "study"
        // 지난 자가진단이 남긴 배너를 먼저 치운다 — 겹쳐 띄우면 무엇을 보고 있는지 모른다.
        LiveActivityController.endAll()

        // endAll 은 비동기로 끝난다. 정리가 끝난 뒤에 요청해야 상한에 걸리지 않는다.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            switch mode {
            case "arena":
                LiveActivityController.start(.arenaPreview)
            case "both":
                LiveActivityController.start(.studyPreview)
                requestSecondary(.arenaPreview)
            default:
                LiveActivityController.start(.studyPreview)
            }
            NSLog("LIVE-ACTIVITY-SELFTEST 시작 · mode=%@", mode)
        }
    }

    /// 컨트롤러를 거치지 않고 두 번째 배너를 직접 요청한다(minimal 표현 확인 전용).
    @MainActor
    private static func requestSecondary(
        _ state: MatthsLiveActivityAttributes.ContentState
    ) {
        do {
            _ = try Activity.request(
                attributes: MatthsLiveActivityAttributes(sessionID: "selftest-secondary"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil)
        } catch {
            NSLog("LIVE-ACTIVITY-SELFTEST 두 번째 배너 실패: %@", String(describing: error))
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        let next = args[i + 1]
        return next.hasPrefix("-") ? nil : next
    }
}

// MARK: - 시험 D-day 위젯 자가진단
//
// 왜 필요한가. 시험 일정 카탈로그는 **일부러 비어 있다**(확인된 수능 날짜가 없다 —
// WidgetSnapshot.swift 의 MatthsExamScheduleCatalog 주석). 그래서 제품 기본 상태로는
// "시험 일정 준비 중"만 그려지고, 잠금화면·홈에서 D-day 표현이 실제로 어떻게 잘리는지
// 사람이 눈으로 확인할 방법이 없다. 이 자가진단이 **견본 일정**을 앱 그룹에 심어
// 위젯 갤러리에서 바로 얹어 볼 수 있게 한다.
//
//   xcrun simctl launch <udid> kr.matths.app -examScheduleSelfTest seed
//   xcrun simctl launch <udid> kr.matths.app -examScheduleSelfTest clear
//
// 심는 날짜는 **오늘 기준 상대 날짜**다(고정 날짜를 박으면 그게 진짜 수능일로 읽힌다).
// note 에 "견본"을 남겨 저장된 값만 봐도 진단용인 것을 알 수 있게 한다.
// 파일 전체가 #if DEBUG 라 릴리스 빌드에는 남지 않는다.
@MainActor
enum ExamScheduleSelfTest {

    private static let argument = "-examScheduleSelfTest"
    private static var activeObserver: NSObjectProtocol?

    static func startIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: argument) else { return }
        let mode = (i + 1 < args.count && !args[i + 1].hasPrefix("-")) ? args[i + 1] : "seed"
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                if let observer = activeObserver {
                    NotificationCenter.default.removeObserver(observer)
                    activeObserver = nil
                }
                // 앱 자신의 첫 publish(scenePhase .active)가 끝난 뒤에 얹어야 한다.
                // 먼저 심으면 그 publish 가 견본 위에 덮어써서 아무 일도 없던 것처럼 보인다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    MainActor.assumeIsolated { run(mode) }
                }
            }
        }
    }

    @MainActor
    private static func run(_ mode: String) {
        guard mode != "clear" else {
            MatthsExamScheduleStore.clearServerOverride()
            WidgetBridge.ingestWeeklyMock(attemptedThisWeek: nil, closeAt: nil, nextReleaseAt: nil)
            WidgetBridge.ingestArena(cycleDay: nil, cycleLength: nil, defenseDeadline: nil)
            NSLog("EXAM-SCHEDULE-SELFTEST 견본 일정 제거")
            return
        }

        // 서버 응답과 **같은 경로**로 넣는다(applyServerExamSchedule). 진단이 제품 경로를
        // 우회하면, 진단이 통과해도 서버 연동이 되는지는 여전히 모른다.
        let json = """
        {
          "source": "server",
          "updatedAt": "\(ISO8601DateFormatter().string(from: Date()))",
          "events": [
            { "id": "selftest-csat", "kind": "csat",
              "title": "대학수학능력시험", "shortTitle": "수능",
              "dayKey": "\(MatthsExamClock.dayKey(daysFromNow: 89))", "note": "견본" },
            { "id": "selftest-mock-9", "kind": "nationalMock",
              "title": "9월 모의평가", "shortTitle": "9월 모평",
              "dayKey": "\(MatthsExamClock.dayKey(daysFromNow: 12))", "note": "견본" },
            { "id": "selftest-mock-10", "kind": "nationalMock",
              "title": "10월 전국연합", "shortTitle": "10월 학평",
              "dayKey": "\(MatthsExamClock.dayKey(daysFromNow: 47))", "note": "견본" }
          ]
        }
        """
        let applied = WidgetBridge.applyServerExamSchedule(Data(json.utf8))

        let iso = ISO8601DateFormatter()
        WidgetBridge.ingestWeeklyMock(
            attemptedThisWeek: false,
            closeAt: iso.string(from: Date().addingTimeInterval(2 * 24 * 3600)),
            nextReleaseAt: nil)
        WidgetBridge.ingestArena(
            cycleDay: 12,
            cycleLength: 29,
            defenseDeadline: iso.string(from: Date().addingTimeInterval(26 * 3600)))

        NSLog("EXAM-SCHEDULE-SELFTEST 견본 일정 적용 · applied=%@", applied ? "true" : "false")
    }
}

// MARK: - 실행 인자 훅
//
// 자가진단을 켤 자리가 필요한데, MatthsApp.swift 는 이 작업의 소유 밖 파일이다.
// UIApplicationDelegate 의 didFinishLaunching 은 **옵셔널 요구사항**이라 확장에서 채워도
// UIKit 이 respondsToSelector 로 찾아 호출한다. MatthsAppDelegate 는 이 메서드를 구현하고
// 있지 않으므로 여기서 안전하게 붙일 수 있고, 파일 전체가 #if DEBUG 라 릴리스에는 남지 않는다.
//
// ⚠️ MatthsApp.swift 쪽에서 같은 메서드를 구현하게 되면 중복 선언으로 빌드가 깨진다.
//    그때는 이 확장을 지우고 MatthsAppDelegate 본체에서 `LiveActivitySelfTest.startIfRequested()`
//    를 한 줄 부르면 된다(다른 자가진단들과 같은 모양).
extension MatthsAppDelegate {
    @objc func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LiveActivitySelfTest.startIfRequested()
        ExamScheduleSelfTest.startIfRequested()
        return true
    }
}
#endif
