//  LocalNotifications.swift
//  Matths — 기기 로컬 알림의 공용 부품
//
//  왜 로컬 알림만 쓰는가:
//  서버 푸시(APNs)는 디바이스 토큰을 받아 둘 자리가 지금 서버 계약에 없다. 반면
//  로컬 알림은 엔타이틀먼트·토큰·백그라운드 모드 없이 지금 동작하고 오프라인에서도
//  뜬다. 그래서 "서버가 이미 내려준 시각"만 골라 기기가 스스로 예약한다.
//
//  넘지 않는 선: 서버가 주지 않은 시각은 만들지 않는다. 추정한 마감으로 학생을
//  부르면 그 알림은 안내가 아니라 거짓말이고, 한 번 거짓말한 알림은 다음부터
//  꺼진다(= 진짜 마감도 못 알린다).
//
//  이 파일이 가진 것:
//   - LocalNotificationPermission : 권한을 "알릴 것이 생겼을 때 한 번만" 묻는 게이트
//   - RankDefenseReminder         : 랭크 방어 마감 임박 알림 (서버 값이 있을 때만)
//   - MatthsNotificationPresenter : 앱이 열려 있는 동안 도착한 알림도 보이게 하는 델리게이트
//
//  주간 모의고사 예고는 WeeklyMockReminder(MatthsApp.swift)가 계속 소유한다 —
//  같은 사건을 두 곳에서 예약하면 취소·갱신이 어긋나 중복 알림이 된다.

import Foundation
import UserNotifications

// MARK: - 권한 게이트

/// 알림 권한을 언제 물을지 한 곳에서 정한다.
///
/// 첫 실행에 묻지 않는 이유: 아직 알릴 것이 하나도 없는 사람에게 물으면 대부분
/// 거절하고, iOS 의 거절은 앱이 되돌릴 수 없다(설정 앱으로 가야 한다). 그래서
/// **예약할 실제 사건이 생긴 순간**에만 묻는다 — 주간 모의고사 다음 회차가 잡혔거나,
/// 내 자리에 방어 마감이 걸렸을 때.
enum LocalNotificationPermission {
    /// 기기 단위 권한이라 계정 슬롯으로 나누지 않는다 (묻는 주체는 앱 하나다).
    private static let askedKey = "matths.notificationPromptShown"

    /// 예약 가능한 상태일 때만 `schedule` 을 실행한다.
    /// 미결정이면 이때 한 번 권한을 묻고, 허락한 경우에만 이어서 예약한다.
    /// - Note: 반드시 "걸 예약이 실제로 있을 때" 호출한다. 빈 손으로 부르면
    ///   근거 없는 권한 창이 된다.
    static func whenSchedulable(
        allowPermissionPrompt: Bool = true,
        _ schedule: @escaping () -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule()
            case .notDetermined:
                // 튜토리얼의 자동 라우트 전환 중 시스템 권한창이 끼어들면 설명과
                // 다음 버튼이 통째로 가려진다. 이미 허용된 예약은 위 분기에서 계속
                // 처리하되, 신규 권한 요청만 다음 정상 화면 갱신까지 미룬다.
                guard allowPermissionPrompt else { return }
                // 주간 모의고사와 랭크 방어가 거의 동시에 도착할 수 있다. 응답을
                // 기다리기 전에 먼저 잠가야 권한 창이 두 번 뜨지 않는다.
                guard !UserDefaults.standard.bool(forKey: askedKey) else { return }
                UserDefaults.standard.set(true, forKey: askedKey)
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    schedule()
                }
            case .denied:
                // 거절한 사람에게 예약을 걸어 두면 조용히 쌓이기만 한다.
                return
            @unknown default:
                return
            }
        }
    }
}

// MARK: - 시각 해석 (서버 ISO 문자열)

/// 서버 시각 문자열 → Date. 소수점 초가 있는 응답과 없는 응답이 모두 온다.
private enum LocalNotificationTime {
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// 알림 본문에 넣는 마감 시각. GOAT Arena 화면과 같은 표기를 쓴다 —
    /// 알림에서 본 시각과 화면에서 본 시각이 달라 보이면 학생은 둘 다 못 믿는다.
    static func text(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened)
                .locale(Locale(identifier: "ko_KR")))
    }
}

// MARK: - 랭크 방어 마감 알림

/// GOAT Arena 에서 **내가 방어자일 때** 놓치면 안 되는 마감을 기기에 예약한다.
///
/// 방어자만 거는 이유: 도전자는 자기가 시작한 경기라 앱을 열어 진행 상황을 본다.
/// 방어자는 반대로 "가만히 있는" 것이 기본 상태라, 앱을 열지 않으면 마감이 그냥
/// 지나간다. 알림이 메워야 하는 구멍은 정확히 거기다.
///
/// 한계(정직하게): 이 예약은 앱이 한 번 열려 서버 스냅샷을 받아야 걸린다. 앱을
/// 한 번도 열지 않은 사이에 배정된 방어는 알릴 방법이 없다 — 그건 APNs 가 필요하다.
enum RankDefenseReminder {
    /// 우리가 건 예약만 골라 지우기 위한 식별자 접두사
    private static let prefix = "matths.rankdefense."
    /// 마감 몇 분 전에 알릴지. 두 번만 건다 — 준비할 시간 한 번, 마지막 확인 한 번.
    /// 더 자주 걸면 잔소리가 되고, 잔소리는 학생이 알림 자체를 끄게 만든다.
    private static let leadMinutes = [120, 20]

    /// 서버 스냅샷을 받을 때마다 다시 건다. 경기가 끝났거나 마감이 바뀌면 옛 예약은 지운다.
    /// - Parameter accountSlot: 응답을 요청한 계정 슬롯. 기다리는 사이 로그아웃·계정
    ///   전환이 있었으면 앞 계정의 마감을 이 기기에 걸지 않는다.
    static func reschedule(
        match: ServerAPI.GoatArenaSnapshot.ActiveMatch?,
        accountSlot: String,
        allowPermissionPrompt: Bool = true
    ) {
        guard DataScope.slot == accountSlot else { return }
        let center = UNUserNotificationCenter.current()
        let pending = requests(for: match)
        // 걸 것이 없으면 권한도 묻지 않는다. 다만 옛 예약은 회수한다 —
        // 이미 끝난 경기의 마감 알림이 뒤늦게 울리면 학생을 헛걸음시킨다.
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

    /// 로그아웃·계정 전환에서 부른다 (앞 계정의 마감을 다음 학생이 보면 안 된다).
    static func cancelAll() { clearMine(UNUserNotificationCenter.current()) }

    private static func clearMine(_ center: UNUserNotificationCenter,
                                  then next: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { pending in
            let mine = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: mine)
            next?()
        }
    }

    /// 서버가 실제로 내려준 마감 하나. 없으면 nil — 지어내지 않는다.
    private struct Deadline {
        var kind: String
        var at: Date
        var title: String
        var body: String
    }

    private static func deadline(
        for match: ServerAPI.GoatArenaSnapshot.ActiveMatch?
    ) -> Deadline? {
        guard let match, match.role == "DEFENDER" else { return nil }

        // 1) 풀이 사진(증거) 제출 마감이 가장 놓치기 쉽다 — 답안을 내고 앱을 닫은 뒤에도
        //    남아 있는 마감이라, 학생 입장에서는 "이미 끝난 경기"로 보인다.
        //    판정은 GoatArenaScreen.needsEvidenceSubmission 과 같은 규칙을 쓴다
        //    (evidenceRequired 가 곧 "아직 제출하지 않았다"는 서버의 표현이다).
        if match.attempt?.evidenceRequired == true,
           let at = LocalNotificationTime.parse(match.attempt?.evidenceDeadlineAt) {
            return Deadline(
                kind: "evidence",
                at: at,
                title: "풀이 사진을 제출해 주세요",
                body: "서버 제출 마감은 \(LocalNotificationTime.text(at))입니다. "
                    + "GOAT Arena 경기 화면에서 제출할 수 있습니다.")
        }

        // 2) 자리 도전에 대한 응답·시작 마감. 상태 이름은 서버 계약 그대로 읽고,
        //    앱이 임의로 해석하지 않는다.
        guard match.status == "MATCHED" || match.status == "READY",
              let at = LocalNotificationTime.parse(match.startsBy) else { return nil }
        return Deadline(
            kind: "start",
            at: at,
            title: "자리 방어 마감이 다가옵니다",
            body: "서버 시작 마감은 \(LocalNotificationTime.text(at))입니다. "
                + "GOAT Arena 에서 응답과 경기 시작을 확인해 주세요.")
    }

    private static func requests(
        for match: ServerAPI.GoatArenaSnapshot.ActiveMatch?
    ) -> [UNNotificationRequest] {
        guard let deadline = deadline(for: match) else { return [] }
        let now = Date()
        return leadMinutes.compactMap { lead -> UNNotificationRequest? in
            let fireAt = deadline.at.addingTimeInterval(-Double(lead) * 60)
            // 이미 지난 시각에는 걸지 않는다. 켜자마자 울리는 알림은 안내가 아니라 소음이고,
            // 지난 트리거는 iOS 가 조용히 버려 예약한 줄 알고 넘어가게 만든다.
            guard fireAt > now.addingTimeInterval(60) else { return nil }

            let content = UNMutableNotificationContent()
            content.title = deadline.title
            content.body = deadline.body
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: fireAt)
            // 마감 시각을 식별자에 넣어, 같은 마감을 다시 받아도 같은 예약으로 덮인다.
            // (서버가 마감을 옮기면 접두사 청소로 옛 예약이 사라진다)
            let id = "\(prefix)\(deadline.kind).\(Int(deadline.at.timeIntervalSince1970)).m\(lead)"
            return UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        }
    }
}

// MARK: - 계정 경계

/// 로컬 알림 전체의 계정 경계. 로그아웃·계정 전환에서 한 번 부른다.
///
/// 알림 본문에는 앞 학생의 상태가 들어 있다(복습할 오답 수, 방어 마감). 한 대의
/// iPad 를 형제가 나눠 쓰는 것이 이 앱의 실제 사용 환경이므로, 슬롯이 바뀌는
/// 순간 예약도 함께 넘어가면 안 된다.
enum MatthsLocalNotifications {
    static func cancelAccountScoped() {
        ReviewReminder.cancelAll()
        WeeklyMockReminder.cancelAll()
        RankDefenseReminder.cancelAll()
    }
}

// MARK: - 앞면(foreground) 표시

/// 앱이 열려 있는 동안 도착한 알림도 보이게 한다.
///
/// 델리게이트가 없으면 iOS 는 앞면 알림을 조용히 버린다. 그러면 "앱에서 공부하는
/// 중에 대기실이 열렸다"는 가장 흔한 경우에 알림이 통째로 사라진다.
final class MatthsNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    /// UNUserNotificationCenter.delegate 는 weak 이다. 어딘가 강한 참조가 없으면
    /// install() 직후 해제되어 델리게이트가 조용히 nil 이 된다.
    private static let shared = MatthsNotificationPresenter()

    /// 앱 진입점에서 한 번 부른다.
    static func install() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 우리가 건 예약만 앞면에 띄운다. 남이 건 알림의 표시 방식까지 대신 정하지 않는다.
        guard notification.request.identifier.hasPrefix("matths.") else {
            completionHandler([])
            return
        }
        // 소리는 빼고 배너·목록만. 시험이나 풀이 중일 수 있어서, 알리되 소리로 끊지 않는다.
        completionHandler([.banner, .list])
    }
}
