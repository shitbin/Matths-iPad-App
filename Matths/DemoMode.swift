//  DemoMode.swift
//  Matths
//
//  **DEBUG 전용 데모 모드** — 서버 없이 앱의 모든 화면을 눈으로 보기 위한 더미 전송계층.
//
//  왜 필요한가. 감독이 UI 를 검토하려면 로그인·네트워크가 살아 있어야 하는데,
//  운영 서버가 없거나 계정이 없으면 홈·평가센터·GOAT Arena 가 전부 빈 화면이다.
//  그래서 ServerAPI.request 의 **단 하나뿐인 choke point** 앞에 분기를 하나 넣고,
//  준비된 JSON 을 그대로 디코드해 돌려준다. 네트워크는 타지 않는다.
//
//  파일 전체가 `#if DEBUG` 안이다 — 릴리스 빌드에는 심볼조차 남지 않는다.
//
//  ## 슬롯을 왜 갈아끼우는가 (중요)
//  데모 응답은 화면에만 그려지고 끝나지 않는다. SyncEngine 의 pull 은 오답노트·진도를
//  **로컬 파일에 병합**하고, ServerAPI 는 GOAT Arena 스냅샷/룰북을 슬롯 파일에 캐시하며,
//  홈은 대시보드 응답을 슬롯에 적어 둔다. 현재 슬롯 그대로 데모를 돌리면 감독의 실제
//  기록에 데모 데이터가 영구히 섞인다 — 가리는 것보다 나쁘다.
//  그래서 데모는 전용 슬롯("demo")에서 돌고, 끄면 원래 슬롯으로 되돌린다.
//  원래 슬롯의 파일은 slots/<원래> 디렉터리에 그대로 남아 있으므로 손실이 없다.

#if DEBUG
import Foundation
import UIKit

enum DemoMode {
    // MARK: - 켜고 끄기 (다음 단계 디버그 바 칩이 쓰는 공개 API)

    /// UserDefaults 저장 키. 값이 true 면 다음 실행에서도 데모로 뜬다.
    static let defaultsKey = "matths.demoMode"

    /// 데모 전용 로컬 데이터 슬롯 이름. 감독의 실제 슬롯과 절대 겹치지 않는다.
    static let slotName = "demo"

    /// 데모의 **JSON 이외** 요청이 향하는 호스트.
    /// `.invalid` 는 RFC 2606 이 영구히 예약한 TLD 라 어떤 DNS 로도 풀리지 않는다.
    /// 아래 DemoURLProtocol 이 어떤 이유로든 안 걸려도 요청이 운영 서버로 새지 않는다.
    static let networkHost = "demo.matths.invalid"

    /// 토글 직후 화면이 다시 읽어야 할 때 쓰는 통지.
    static let didChangeNotification = Notification.Name("kr.matths.demoModeDidChange")

    private static let previousSlotKey = "matths.demoMode.previousSlot"

    /// 실행 인자 `-demo` 로 켜진 실행인지. 칩에 "인자로 켜짐" 표시를 붙이고 싶을 때 쓴다.
    static let isForcedByLaunchArgument =
        ProcessInfo.processInfo.arguments.contains("-demo")

    /// 홈·알림·Arena가 시작 직후 동시에 데모 API를 부른다. DEBUG 전용이라도 이
    /// 공유 상태를 잠그지 않으면 `Set.insert`의 내부 버퍼가 깨져 간헐 SIGSEGV가 난다.
    /// (2026-08-31 실측 크래시 7건: 모두 `missingFixture`의 동시 insert.)
    private static let stateLock = NSLock()

    private static var enabled: Bool =
        isForcedByLaunchArgument || UserDefaults.standard.bool(forKey: defaultsKey)

    /// 가로채기 여부의 유일한 진실원. 요청마다 읽히므로 계산은 없다.
    static var isOn: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return enabled
    }

    static func launchArgumentValue(after key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else {
            return nil
        }
        let value = arguments[index + 1]
        return value.hasPrefix("-") ? nil : value
    }

    /// 토글. 끄는 순간 가로채기가 멈추고(= 즉시 진짜 서버), 슬롯도 원래대로 돌아간다.
    static func setEnabled(_ on: Bool) {
        stateLock.lock()
        let changed = on != enabled
        if changed {
            enabled = on
            storedMissingRoutes.removeAll()
        }
        stateLock.unlock()
        guard changed else { return }
        UserDefaults.standard.set(on, forKey: defaultsKey)
        if on { enterDemoSlot() } else { restoreRealSlot() }
        // 응시 중이던 데모 회차도 처음(대기실)으로 — 같은 흐름을 다시 밟아 볼 수 있어야 한다.
        DemoWeeklyMockLive.reset()
        if on { DemoRouter.resetTutorialState() }
        NSLog("DEMO-MODE %@ · slot=%@", on ? "ON" : "OFF", DataScope.slot)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    // MARK: - 앱 시작 훅 (MatthsApp.init 이 부른다)

    /// `DataScope.migrateLegacyIfNeeded()` **앞**에서 부른다.
    /// 지난 실행이 데모 슬롯에서 강제 종료됐어도 여기서 원래 슬롯으로 되돌아간다.
    /// (평평한 레거시 파일이 데모 슬롯으로 이사 가는 것도 이 순서가 막는다.)
    static func restoreRealSlotBeforeLegacyMigration() {
        guard !isOn else { return }
        restoreRealSlot()
    }

    /// `DataScope.migrateLegacyIfNeeded()` **뒤**, AppStore 가 만들어지기 전에 부른다.
    static func enterDemoSlotAfterLegacyMigration() {
        guard isOn else { return }
        enterDemoSlot()
    }

    private static func enterDemoSlot() {
        // JSON choke point 를 지나지 않는 요청(PDF 다운로드·multipart 업로드)을 위한
        // 가로채기. 켜는 두 경로(앱 시작 훅·런타임 토글)가 모두 여기를 지난다.
        DemoURLProtocol.installOnce()
        if DataScope.slot != slotName {
            UserDefaults.standard.set(DataScope.slot, forKey: previousSlotKey)
        }
        // 데모는 매번 깨끗한 상태에서 시작한다 — 지난 실행의 캐시된 데모 응답이
        // 남아 이번 픽스처와 섞이면 무엇을 보고 있는지 알 수 없다.
        purgeDemoSlotFiles()
        DataScope.switchTo(slotName)
        NSLog("DEMO-MODE 슬롯 진입 · demo (원래 슬롯=%@ 보존)",
              UserDefaults.standard.string(forKey: previousSlotKey) ?? "guest")
    }

    private static func restoreRealSlot() {
        guard DataScope.slot == slotName else { return }
        let previous = UserDefaults.standard.string(forKey: previousSlotKey) ?? "guest"
        UserDefaults.standard.removeObject(forKey: previousSlotKey)
        DataScope.switchTo(previous)
        NSLog("DEMO-MODE 슬롯 복귀 · %@", previous)
    }

    private static func purgeDemoSlotFiles() {
        let manager = FileManager.default
        let directory = DataScope.directory(for: slotName)
        let contents = (try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        for item in contents { try? manager.removeItem(at: item) }
    }

    // MARK: - 데모 계정

    /// 데모에서 로그인된 사용자. `-demoRole teacher|admin`은 역할별 학원 작업대 실측용이며,
    /// 키체인 토큰은 만들지 않는다(감독의 실제 토큰 보호).
    static var demoUser: ServerUser {
        let args = ProcessInfo.processInfo.arguments
        let role: String = if let index = args.firstIndex(of: "-demoRole"), index + 1 < args.count {
            args[index + 1].lowercased()
        } else {
            "student"
        }
        let identity: (name: String, realName: String, email: String) = switch role {
        case "admin": ("운영자", "매쓰 운영자", "admin-demo@matths.kr")
        case "teacher": ("상윤", "이상윤", "teacher-demo@matths.kr")
        default: ("지우", "서지우", "demo@matths.kr")
        }
        return ServerUser(
            name: identity.name,
            realName: identity.realName,
            email: identity.email,
            role: role,
            schoolGrade: 11,
            school: ServerSchool(region: "서울", code: "7010084", name: "한영고등학교"),
            currentStreak: 12,
            longestStreak: 21,
            rankingDisplayMode: "nickname")
    }

    // MARK: - 가로채기

    /// 이번 실행에서 픽스처가 없어 실패시킨 경로. 디버그 바가 개수를 보여줄 수 있다.
    private static var storedMissingRoutes: Set<String> = []

    /// 디버그 바에는 복사본을 넘긴다. 뷰가 count를 읽는 동안 API 태스크가 insert해도
    /// 같은 Set 저장소를 함께 만지지 않는다.
    static var missingRoutes: Set<String> {
        stateLock.lock()
        defer { stateLock.unlock() }
        return storedMissingRoutes
    }

    /// 준비된 응답이 있으면 디코드해서 돌려준다. 없으면 nil (호출부가 실패시킨다).
    static func canned<T: Decodable>(
        method: String,
        path: String,
        query: [String: String] = [:],
        body: [String: Any]? = nil
    ) throws -> T? {
        guard let template = DemoRouter.json(
            method: method, path: path, query: query, body: body) else { return nil }
        let resolved = DemoTemplate.resolve(template)
        let data = Data(resolved.utf8)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // 디코드 실패는 화면이 비는 진짜 원인이다 — 조용히 넘기지 않는다.
            NSLog("DEMO-MODE 디코드 실패 %@ %@ → %@: %@",
                  method, path, String(describing: T.self), String(describing: error))
            throw ServerAPIError(
                message: "데모 픽스처 디코드 실패: \(path)",
                code: "DEMO_FIXTURE_DECODE_FAILED",
                statusCode: 500)
        }
    }

    /// 픽스처가 없는 경로 — 데모에서 조용히 네트워크로 새면 안 되므로 알아볼 수 있게 실패시킨다.
    static func missingFixture(method: String, path: String) -> ServerAPIError {
        let key = "\(method) \(path)"
        stateLock.lock()
        let inserted = storedMissingRoutes.insert(key).inserted
        stateLock.unlock()
        if inserted {
            NSLog("DEMO-MODE 픽스처 없음 ⚠️ %@", key)
        }
        return ServerAPIError(
            message: "데모 픽스처가 없는 경로입니다: \(key)",
            code: "DEMO_FIXTURE_MISSING",
            statusCode: 501)
    }
}

// MARK: - 시간 토큰 치환
//
// 픽스처에 절대 시각을 박아 두면 하루만 지나도 "마감 지남"·"지난주 기록"이 되어
// 화면이 빈다. 그래서 상대 시각 토큰을 쓰고 응답할 때 현재 시각으로 바꾼다.
//   @T+90m@ @T-3d@ @T+2h@ @T+0s@ → ISO8601 (밀리초 + Z, 서버와 같은 모양)
//   @D-6@                        → KST 날짜키 yyyy-MM-dd
//   @W-6@                        → KST 요일 한 글자 (월·화·…)
//   @WEEK@                       → KST ISO 주차 키 (2026-W34)
//   @SUN+1T15:00@                → KST 다음 주 일요일 15:00의 ISO 시각

enum DemoTemplate {
    /// DateFormatter·ISO8601DateFormatter와 정규식 인스턴스는 여러 데모 요청이 동시에
    /// 공유한다. 치환 한 건 전체를 직렬화해 내부 mutable 버퍼 경합을 막는다.
    private static let resolveLock = NSLock()

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    private static let pattern = try? NSRegularExpression(
        pattern: "@(T[+-][0-9]+[smhd]|D[+-][0-9]+|W[+-][0-9]+|WEEK|SUN[+-][0-9]+T[0-9]{2}:[0-9]{2})@")

    static func resolve(_ template: String, now: Date = Date()) -> String {
        resolveLock.lock()
        defer { resolveLock.unlock() }
        guard let pattern, template.contains("@") else { return template }
        let full = NSRange(template.startIndex..., in: template)
        var output = template
        // 뒤에서부터 바꿔야 앞쪽 range 가 밀리지 않는다.
        for match in pattern.matches(in: template, range: full).reversed() {
            guard let range = Range(match.range(at: 1), in: template),
                  let replaceRange = Range(match.range, in: output) else { continue }
            let token = String(template[range])
            output.replaceSubrange(replaceRange, with: value(for: token, now: now))
        }
        return output
    }

    private static func value(for token: String, now: Date) -> String {
        if token == "WEEK" {
            let week = calendar.component(.weekOfYear, from: now)
            let year = calendar.component(.yearForWeekOfYear, from: now)
            return String(format: "%04d-W%02d", year, week)
        }
        if token.hasPrefix("SUN") {
            return sundayISO(for: token, now: now)
        }
        let kind = token.prefix(1)
        let rest = token.dropFirst()
        let sign = rest.hasPrefix("-") ? -1 : 1
        let digits = rest.dropFirst()
        switch kind {
        case "T":
            let unit = digits.suffix(1)
            let amount = Int(digits.dropLast()) ?? 0
            let seconds: Int
            switch unit {
            case "s": seconds = amount
            case "m": seconds = amount * 60
            case "h": seconds = amount * 3600
            default:  seconds = amount * 86_400
            }
            return isoFormatter.string(from: now.addingTimeInterval(Double(sign * seconds)))
        case "D":
            let day = calendar.date(byAdding: .day, value: sign * (Int(digits) ?? 0), to: now) ?? now
            return dateKeyFormatter.string(from: day)
        default:
            let day = calendar.date(byAdding: .day, value: sign * (Int(digits) ?? 0), to: now) ?? now
            return weekdayFormatter.string(from: day)
        }
    }

    /// 실행한 요일과 무관하게 데모 시험 날짜를 일요일로 유지한다.
    /// `SUN+0`은 한국시간 기준 가장 최근 일요일, `SUN+1`은 그 다음 일요일이다.
    private static func sundayISO(for token: String, now: Date) -> String {
        let payload = token.dropFirst(3)
        let parts = payload.split(separator: "T", maxSplits: 1)
        guard parts.count == 2, let weekOffset = Int(parts[0]) else {
            return isoFormatter.string(from: now)
        }
        let clock = parts[1].split(separator: ":", maxSplits: 1)
        guard clock.count == 2,
              let hour = Int(clock[0]), let minute = Int(clock[1]) else {
            return isoFormatter.string(from: now)
        }

        let daysSinceSunday = calendar.component(.weekday, from: now) - 1
        let recentSunday = calendar.date(
            byAdding: .day,
            value: -daysSinceSunday,
            to: calendar.startOfDay(for: now)) ?? now
        let targetSunday = calendar.date(
            byAdding: .day,
            value: weekOffset * 7,
            to: recentSunday) ?? recentSunday
        let target = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetSunday) ?? targetSunday
        return isoFormatter.string(from: target)
    }
}

// MARK: - 경로 → 픽스처 라우터

enum DemoRouter {
    /// 튜토리얼 PATCH와 프로필 GET, 주간 모의고사 시작/조회가 서로 다른 Task에서
    /// 겹칠 수 있다. 라우팅 한 건을 원자적으로 처리해 상태 사전의 경합을 막는다.
    private static let routeLock = NSLock()

    /// 프로필에서 튜토리얼을 다시 시작하고 완료/건너뛰는 왕복을 실제 서버처럼
    /// 재현한다. 프로세스 수명 동안만 유지되는 DEBUG 상태라 사용자 데이터와 섞이지 않는다.
    private static var dashboardTutorialStatus = "COMPLETED"
    private static let arenaTutorialChapters = [
        "common", "unranked", "unranked_match", "ranked", "ranked_battle", "ranked_shop",
    ]
    private static var arenaTutorialStatuses = Dictionary(
        uniqueKeysWithValues: arenaTutorialChapters.map { ($0, "COMPLETED") })

    static func resetTutorialState() {
        routeLock.lock()
        defer { routeLock.unlock() }
        dashboardTutorialStatus = "COMPLETED"
        arenaTutorialStatuses = Dictionary(
            uniqueKeysWithValues: arenaTutorialChapters.map { ($0, "COMPLETED") })
    }

    /// 리터럴 경로 먼저, 그 다음 `{}` 와일드카드 패턴. 순서가 뒤바뀌면
    /// `/matches/main/options` 가 `/matches/{matchId}/options` 로 잘못 잡힌다.
    static func json(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?
    ) -> String? {
        routeLock.lock()
        defer { routeLock.unlock() }
        let method = method.uppercased()
        if let literal = literalRoute(method: method, path: path, query: query, body: body) {
            return literal
        }
        return patternRoute(method: method, path: path, query: query, body: body)
    }

    // MARK: 리터럴

    private static func literalRoute(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?
    ) -> String? {
        switch "\(method) \(path)" {
        // 인증
        case "POST /api/v1/auth/register",
             "POST /api/v1/auth/login",
             // Google·카카오는 같은 PKCE 교환 경로를 사용한다.
             "POST /api/v1/auth/social/exchange",
             // 구버전 앱의 Google 전용 경로도 데모 호환을 위해 남긴다.
             "POST /api/v1/auth/google/exchange",
             // Apple 네이티브 자격 증명도 로그인 이후에는 같은 AuthResponse다.
             "POST /api/v1/auth/apple/exchange":
            return DemoAccountFixtures.authResponse
        case "GET /api/v1/auth/providers":
            return DemoAccountFixtures.authProviders
        case "POST /api/v1/auth/password-reset/request":
            return DemoAccountFixtures.passwordResetRequest
        case "POST /api/v1/auth/password-reset/verify":
            return DemoAccountFixtures.passwordResetVerify
        case "POST /api/v1/auth/password-reset/complete":
            return #"{"reset":true}"#
        case "GET /api/v1/schools":
            return DemoAccountFixtures.schools

        // 내 계정
        case "GET /api/v1/me",
             "PATCH /api/v1/me/nickname",
             "PATCH /api/v1/me/school",
             "PATCH /api/v1/me/ranking-identity":
            return profileResponse()
        case "PATCH /api/v1/me/tutorials/dashboard":
            return updateDashboardTutorial(body)
        case "PATCH /api/v1/me/tutorials/arena":
            return updateArenaTutorial(body)
        case "GET /api/v1/me/withdrawal/options":
            return DemoAccountFixtures.withdrawalOptions
        case "POST /api/v1/me/withdrawal/google/start":
            return DemoAccountFixtures.withdrawalGoogleStart
        case "DELETE /api/v1/me":
            return DemoAccountFixtures.withdrawResult

        // 학습 동기화
        case "GET /api/v1/learning/progress":
            return DemoAccountFixtures.learningProgress
        case "POST /api/v1/learning/progress/reset":
            let id = string(body, "clientResetId")
            return #"{"reset":{"clientResetId":"\#(id)","deletedCount":0}}"#
        case "POST /api/v1/events":
            return #"{"accepted":1,"duplicates":0}"#

        // 알림함 — 운영 Bearer 경로와 같은 두 페이지 응답을 돌려, 첫 화면뿐 아니라
        // "이전 알림 더 보기"와 오래된 날짜 그룹까지 실제 UI에서 검증한다.
        case "GET /api/v1/notifications":
            return query["page"] == "2"
                ? DemoAccountFixtures.notificationInboxPage2
                : DemoAccountFixtures.notificationInbox
        case "POST /api/v1/notifications/read-all":
            return "{}"

        // 오답노트
        case "GET /api/v1/wrong-notes":
            return DemoAccountFixtures.wrongNotes
        case "POST /api/v1/wrong-notes/bulk":
            return syncedListEcho(body)
        case "GET /api/v1/wrong-notes/stuck-points":
            return DemoAccountFixtures.stuckPoints
        case "POST /api/v1/wrong-notes/stuck-points":
            let id = string(body, "id")
            let text = escaped(string(body, "text"))
            let createdAt = string(body, "createdAt")
            return #"{"stuckPoint":{"id":"\#(id)","text":"\#(text)","createdAt":"\#(createdAt)"}}"#

        // 홈 대시보드
        case "GET /api/v1/dashboard/activity":
            return DemoAccountFixtures.dashboardActivity

        // 학생 학원 교실 — 가입 이후의 반복 행동을 네이티브 화면에서 검토한다.
        case "GET /api/v1/academy/student",
             "POST /api/v1/academy/student/join-code",
             "POST /api/v1/academy/student/join",
             "POST /api/v1/academy/student/leave":
            return DemoAccountFixtures.academyDashboard
        case "POST /api/v1/academy/student/attendance/check-in":
            return DemoAccountFixtures.academyCheckIn
        case "GET /api/v1/academy/teacher",
             "POST /api/v1/academy/teacher/invites",
             "POST /api/v1/academy/teacher/classes":
            return DemoAccountFixtures.teacherAcademyDashboard
        case "GET /api/v1/academy/teacher/setup":
            switch DemoMode.launchArgumentValue(after: "-teacherSetupFixture") {
            case "pending-academy": return DemoAccountFixtures.teacherSetupPendingAcademy
            case "pending-join": return DemoAccountFixtures.teacherSetupPendingJoin
            case "rejected": return DemoAccountFixtures.teacherSetupRejected
            case "error": return nil
            default: return DemoAccountFixtures.teacherSetupChoice
            }
        case "POST /api/v1/academy/teacher/setup":
            return DemoAccountFixtures.teacherSetupPendingAcademy
        case "POST /api/v1/academy/teacher/setup/join":
            return DemoAccountFixtures.teacherSetupPendingJoin
        case "POST /api/v1/academy/teacher/setup/join/cancel":
            return DemoAccountFixtures.teacherSetupChoice
        case "POST /api/v1/academy/teacher/profile-image",
             "POST /api/v1/academy/teacher/profile-image/remove":
            return DemoAccountFixtures.teacherAcademyDashboard
        case "GET /api/v1/academy/teacher/forensics":
            if DemoMode.launchArgumentValue(after: "-teacherForensicsFixture") == "result" {
                return DemoAccountFixtures.teacherForensicsResult
            }
            if DemoMode.launchArgumentValue(after: "-teacherForensicsFixture") == "empty" {
                return DemoAccountFixtures.teacherForensicsEmpty
            }
            if DemoMode.launchArgumentValue(after: "-teacherForensicsFixture") == "error" { return nil }
            return DemoAccountFixtures.teacherForensics
        case "POST /api/v1/academy/teacher/forensics/code",
             "POST /api/v1/academy/teacher/forensics/file":
            return DemoAccountFixtures.teacherForensicsResult
        case "GET /api/v1/academy/teacher/analytics":
            if DemoMode.launchArgumentValue(after: "-teacherAnalyticsFixture") == "error" {
                return nil
            }
            if DemoMode.launchArgumentValue(after: "-teacherAnalyticsFixture") == "empty" {
                return DemoAccountFixtures.teacherAnalyticsEmpty
            }
            return DemoAccountFixtures.teacherAnalytics
        case "GET /api/v1/academy/teacher/students":
            if DemoMode.launchArgumentValue(after: "-teacherStudentsFixture") == "error" {
                return nil
            }
            if DemoMode.launchArgumentValue(after: "-teacherStudentsFixture") == "empty" {
                return DemoAccountFixtures.teacherStudentEmptyPage
            }
            return DemoAccountFixtures.teacherStudentPage
        case "POST /api/v1/academy/teacher/students/bulk":
            return #"{"action":"ASSIGN_CLASS","count":2,"modifiedCount":2}"#
        case "GET /api/v1/academy/teacher/attendance",
             "POST /api/v1/academy/teacher/attendance":
            if DemoMode.launchArgumentValue(after: "-teacherAttendanceFixture") == "error" {
                return nil
            }
            if DemoMode.launchArgumentValue(after: "-teacherAttendanceFixture") == "empty" {
                return DemoAccountFixtures.teacherAttendanceEmpty
            }
            return DemoAccountFixtures.teacherAttendanceRoster
        case "GET /api/v1/academy/admin/list":
            if DemoMode.launchArgumentValue(after: "-adminAcademyFixture") == "error" { return nil }
            if DemoMode.launchArgumentValue(after: "-adminAcademyFixture") == "empty" {
                return DemoAccountFixtures.adminAcademyListEmpty
            }
            return DemoAccountFixtures.adminAcademyList
        case "GET /api/v1/academy/admin":
            return DemoAccountFixtures.adminAcademyDashboard
        case "GET /api/v1/admin/operations":
            return DemoAdminOperationsFixtures.dashboard
        case "GET /api/v1/admin/todos":
            return DemoAdminOperationsFixtures.todos(
                status: query["status"] ?? "pending",
                category: query["category"] ?? "")
        case "GET /api/v1/admin/inquiries":
            return DemoAdminOperationsFixtures.inquiries(status: query["status"] ?? "pending")
        case "GET /api/v1/admin/announcements":
            return DemoAdminOperationsFixtures.announcements
        case "POST /api/v1/admin/announcements":
            return DemoAdminOperationsFixtures.createdAnnouncement
        case "GET /api/v1/admin/users":
            return DemoAdminUsersFixtures.users
        case "GET /api/v1/admin/sanctions":
            return DemoAdminUsersFixtures.sanctions
        case "GET /api/v1/admin/audit-log":
            return DemoAdminUsersFixtures.audit
        case "GET /api/v1/admin/finance":
            return DemoAdminFinanceFixtures.finance
        case "POST /api/v1/admin/finance/withdrawals",
             "POST /api/v1/admin/finance/other-unpaid-costs":
            return DemoAdminFinanceFixtures.financeMutation
        case "GET /api/v1/admin/refunds":
            return DemoAdminFinanceFixtures.refunds
        case "GET /api/v1/admin/paybacks":
            return DemoAdminFinanceFixtures.paybacks
        case "GET /api/v1/admin/community":
            return DemoAdminCommunityFixtures.dashboard
        case "POST /api/v1/admin/community/notices":
            return DemoAdminCommunityFixtures.mutation
        case "GET /api/v1/admin/weekly-mock-exams":
            return DemoAdminWeeklyMockFixtures.dashboard
        case "GET /api/v1/admin/archive":
            return DemoAdminArchiveFixtures.dashboard
        case "GET /api/v1/admin/store":
            return DemoAdminStoreFixtures.dashboard
        case "GET /api/v1/admin/arena":
            return DemoAdminArenaFixtures.dashboard
        case "GET /api/v1/admin/data-analysis":
            return DemoAdminDataAnalysisFixtures.dashboard
        case "GET /api/v1/admin/arena-policies":
            return DemoAdminArenaPolicyFixtures.dashboard
        case "GET /api/v1/admin/problem-banks":
            return DemoAdminProblemBankFixtures.dashboard
        case "GET /api/v1/admin/operations-guide":
            return DemoAdminOperationsGuideFixtures.dashboard
        case "POST /api/v1/admin/arena/ranking/rebuild",
             "POST /api/v1/admin/arena/maintenance":
            return DemoAdminArenaFixtures.mutation
        case "POST /api/v1/admin/data-analysis/rebuild":
            return DemoAdminDataAnalysisFixtures.mutation
        case "POST /api/v1/admin/pdf-forensics/analyze":
            return DemoAdminPdfForensicsFixtures.analysis
        case "POST /api/v1/admin/arena-policies/matchmaking",
             "POST /api/v1/admin/arena-policies/learning-package",
             "POST /api/v1/admin/arena-policies/mock-exam",
             "POST /api/v1/admin/arena-policies/shop",
             "POST /api/v1/admin/arena-policies/unranked",
             "POST /api/v1/admin/arena-policies/ranked":
            return DemoAdminArenaPolicyFixtures.mutation
        case "POST /api/v1/admin/problem-banks/types/sync",
             "POST /api/v1/admin/problem-banks/arena/types":
            return DemoAdminProblemBankFixtures.mutation
        case "POST /api/v1/admin/problem-banks/arena/data":
            return DemoAdminProblemBankFixtures.created
        case "POST /api/v1/admin/archive/folders",
             "POST /api/v1/admin/archive/upload",
             "POST /api/v1/admin/archive/items/bulk-delete",
             "POST /api/v1/admin/archive/items/bulk-move":
            return DemoAdminArchiveFixtures.mutation
        case "POST /api/v1/admin/store/study-hall",
             "POST /api/v1/admin/store/products",
             "POST /api/v1/admin/store/categories",
             "POST /api/v1/admin/store/categories/reorder":
            return DemoAdminStoreFixtures.mutation
        case "GET /api/v1/coach-suggestions":
            return DemoMode.demoUser.role?.lowercased() == "admin"
                ? DemoAccountFixtures.coachSuggestionBoardAdmin
                : DemoAccountFixtures.coachSuggestionBoard
        case "POST /api/v1/coach-suggestions":
            return DemoAccountFixtures.coachSuggestionMutation
        case "GET /api/v1/support/inquiries":
            return DemoAccountFixtures.supportDashboard
        case "POST /api/v1/support/inquiries":
            return DemoAccountFixtures.supportSubmission
        case "GET /api/v1/archive":
            return query["folderId"] == nil
                ? DemoAccountFixtures.archiveDashboard
                : DemoAccountFixtures.archiveFolderDashboard
        case "GET /api/v1/study-hall":
            let fixture = DemoMode.launchArgumentValue(after: "-studyHallFixture")
            if fixture == "error" { return nil }
            return DemoStudyHallFixtures.list(
                tab: query["tab"] ?? "NJE",
                empty: fixture == "empty",
                status: fixture == "submitted" ? "SUBMITTED" : "IN_PROGRESS"
            )
        case "GET /api/v1/store-products":
            return DemoStoreCatalogFixtures.catalog
        case "GET /api/v1/faq":
            return query["code"] == "409"
                ? DemoFaqFixtures.error409
                : DemoFaqFixtures.dashboard

        // 네이티브 커뮤니티 — 공개 읽기와 로그인 후 반복 작업을 모두 검수한다.
        case "GET /api/v1/community":
            return DemoCommunityFixtures.page
        case "GET /api/v1/community/posting-access":
            return DemoCommunityFixtures.postingAccess
        case "GET /api/v1/community/blocked-users":
            return DemoCommunityFixtures.blocks

        // 레거시 랭킹전 / 29일 패키지
        case "GET /api/v1/arena":
            return DemoArenaFixtures.legacyArena
        case "GET /api/v1/arena/leaderboard":
            return DemoArenaFixtures.legacyLeaderboard
        case "GET /api/v1/access":
            return DemoArenaFixtures.accessEconomy

        // 배치고사
        case "GET /api/v1/placement-exam/status":
            return DemoAccountFixtures.placementStatus
        case "POST /api/v1/placement-exam/start":
            return DemoAccountFixtures.placementAttempt

        // GOAT Arena
        case "GET /api/v1/goat-arena":
            return DemoArenaFixtures.snapshot
        case "GET /api/v1/goat-arena/rulebook":
            return DemoRulebookFixture.rulebook
        case "POST /api/v1/goat-arena/matches/sub":
            return DemoArenaFixtures.matchCommandReceipt
        case "GET /api/v1/goat-arena/matches/main/options":
            return DemoArenaFixtures.mainMatchOptions
        case "POST /api/v1/goat-arena/matches/main/upward":
            return DemoArenaFixtures.mainUpwardReceipt
        case "POST /api/v1/goat-arena/matches/main/invitations":
            return DemoArenaFixtures.mainInvitationReceipt
        case "GET /api/v1/goat-arena/matches/main/friendly":
            return DemoArenaFixtures.friendlyOptions(query: query["nickname"] ?? "")
        case "POST /api/v1/goat-arena/matches/main/friendly/invitations":
            return DemoArenaFixtures.friendlyInvitationCreated
        case "GET /api/v1/goat-arena/revenge-rights/pending":
            return DemoArenaFixtures.revengeRight
        case "GET /api/v1/goat-arena/profile/payback-account":
            return DemoArenaFixtures.paybackAccountStatus
        case "POST /api/v1/goat-arena/profile/payback-account/confirm":
            return DemoArenaFixtures.paybackAccountConfirmation(
                bankName: string(body, "bankName"),
                accountNumber: string(body, "accountNumber"))
        case "GET /api/v1/goat-arena/main/shop":
            return DemoArenaFixtures.shop
        case "POST /api/v1/goat-arena/main/shop/purchases":
            return DemoArenaFixtures.shopPurchase

        // 평가센터
        case "GET /api/v1/assessments":
            return DemoAssessmentFixtures.assessments
        case "POST /api/v1/assessments/start":
            return DemoAssessmentFixtures.startedAssessment(body: body)

        // 주간 공식 모의고사
        case "GET /api/v1/weekly-mock-exams":
            return DemoAssessmentFixtures.weeklyMockDashboard
        case "GET /api/v1/weekly-mock-exams/integrity-cases":
            return DemoAssessmentFixtures.weeklyMockIntegrityCases
        case "GET /api/v1/weekly-mock-exams/objections/options":
            return DemoAssessmentFixtures.weeklyMockObjectionOptions
        case "GET /api/v1/weekly-mock-exams/objections":
            return DemoAssessmentFixtures.weeklyMockObjections
        case "POST /api/v1/weekly-mock-exams/objections":
            return DemoAssessmentFixtures.weeklyMockObjectionCreated

        // 퀵 연습
        case "POST /api/v1/quick-practice/start":
            return DemoAccountFixtures.quickStart(pointValue: int(body, "pointValue") ?? 3)
        case "GET /api/v1/quick-practice/stats":
            return DemoAccountFixtures.quickStats

        // 이용권 상점
        case "GET /api/v1/commerce/storefront":
            return DemoAccountFixtures.storefront
        case "POST /api/v1/commerce/handoffs":
            return DemoAccountFixtures.commerceHandoff
        case "POST /api/v1/commerce/apple/account-token":
            let token = escaped(string(body, "proposedToken"))
            return #"{"token":"\#(token)"}"#
        case "POST /api/v1/commerce/apple/redeem":
            return #"{"granted":true,"duplicate":false,"expiresAt":"@T+29d@"}"#

        default:
            return nil
        }
    }

    private static func profileResponse() -> String {
        DemoAccountFixtures.meResponse
            .replacingOccurrences(
                of: "@DASHBOARD_TUTORIAL_STATUS@",
                with: dashboardTutorialStatus)
            .replacingOccurrences(
                of: "@DASHBOARD_TUTORIAL_AUTOSTART@",
                with: dashboardTutorialStatus == "PENDING" ? "true" : "false")
            .replacingOccurrences(of: "@ARENA_TUTORIAL@", with: arenaTutorialJSON())
    }

    private static func updateDashboardTutorial(_ body: [String: Any]?) -> String {
        dashboardTutorialStatus = tutorialStatus(for: string(body, "action"))
        return #"{"tutorial":{"status":"\#(dashboardTutorialStatus)","shouldAutoStart":\#(dashboardTutorialStatus == "PENDING" ? "true" : "false"),"completedAt":null,"skippedAt":null}}"#
    }

    private static func updateArenaTutorial(_ body: [String: Any]?) -> String {
        let chapter = string(body, "chapter")
        if arenaTutorialStatuses[chapter] != nil {
            arenaTutorialStatuses[chapter] = tutorialStatus(for: string(body, "action"))
        }
        return #"{"tutorial":\#(arenaTutorialJSON())}"#
    }

    private static func tutorialStatus(for action: String) -> String {
        switch action.uppercased() {
        case "RESTART": return "PENDING"
        case "SKIP": return "SKIPPED"
        default: return "COMPLETED"
        }
    }

    private static func arenaTutorialJSON() -> String {
        let chapters = arenaTutorialChapters.map { chapter in
            let status = arenaTutorialStatuses[chapter] ?? "COMPLETED"
            return #""\#(chapter)":{"status":"\#(status)","shouldAutoStart":false,"completedAt":null,"skippedAt":null}"#
        }.joined(separator: ",")
        let quoted = arenaTutorialChapters.map { #""\#($0)""# }.joined(separator: ",")
        return #"{"version":1,"activeDivision":"MAIN","eligibleChapters":[\#(quoted)],"availableChapters":[\#(quoted)],"chapters":{\#(chapters)},"autoChapter":null,"shouldAutoStart":false,"suspended":false}"#
    }

    // MARK: 패턴

    private static let patterns: [(method: String, template: String)] = [
        // 네이티브 커뮤니티
        ("GET", "/api/v1/community/posts/{postId}"),
        ("GET", "/api/v1/community/notices/{noticeId}"),
        ("GET", "/api/v1/community/announcements/{announcementId}"),
        ("POST", "/api/v1/community/posts/{postId}/comments"),
        ("POST", "/api/v1/community/posts/{postId}/vote"),
        ("POST", "/api/v1/community/posts/{postId}/report"),
        ("POST", "/api/v1/community/posts/{postId}/block"),
        ("DELETE", "/api/v1/community/posts/{postId}"),
        ("DELETE", "/api/v1/community/blocked-users/{userId}"),
        // 공개 자료 카탈로그
        ("GET", "/api/v1/store-products/{slug}"),
        // 관리자 운영함
        ("POST", "/api/v1/admin/todos/{todoId}/complete"),
        ("POST", "/api/v1/admin/todos/{todoId}/reopen"),
        ("POST", "/api/v1/admin/inquiries/{inquiryId}/reply"),
        ("POST", "/api/v1/admin/inquiries/{inquiryId}/status"),
        ("POST", "/api/v1/admin/announcements/{announcementId}/status"),
        // 관리자 사용자 관리
        ("GET", "/api/v1/admin/users/{userId}"),
        ("GET", "/api/v1/admin/users/{userId}/activity"),
        ("GET", "/api/v1/admin/users/{userId}/assessments/{attemptId}"),
        ("GET", "/api/v1/admin/parents/{parentId}"),
        ("POST", "/api/v1/admin/users/{userId}/nickname-request"),
        ("POST", "/api/v1/admin/users/{userId}/notification"),
        ("POST", "/api/v1/admin/users/{userId}/email"),
        ("POST", "/api/v1/admin/users/{userId}/password-reset"),
        ("POST", "/api/v1/admin/users/{userId}/role"),
        ("POST", "/api/v1/admin/users/{userId}/account-status"),
        ("POST", "/api/v1/admin/users/{userId}/withdraw"),
        ("POST", "/api/v1/admin/users/{userId}/warnings"),
        ("POST", "/api/v1/admin/users/{userId}/package-access"),
        ("POST", "/api/v1/admin/parents/{parentId}/account-status"),
        ("POST", "/api/v1/admin/parents/{parentId}/children/{childUserId}/notifications"),
        ("POST", "/api/v1/admin/parents/{parentId}/children/{childUserId}/unlink"),
        // 관리자 재무·환불·페이백
        ("POST", "/api/v1/admin/refunds/{refundRequestId}/calculate"),
        ("POST", "/api/v1/admin/refunds/{refundRequestId}/complete"),
        ("POST", "/api/v1/admin/refunds/{refundRequestId}/reject"),
        ("POST", "/api/v1/admin/paybacks/{cycleId}/complete"),
        ("POST", "/api/v1/admin/paybacks/history/{payoutRecordId}/resend-email"),
        // 관리자 주간 공식 모의고사
        ("GET", "/api/v1/admin/weekly-mock-exams/{examId}"),
        ("POST", "/api/v1/admin/weekly-mock-exams/{examId}/attempts/{attemptId}/integrity-request"),
        ("POST", "/api/v1/admin/weekly-mock-exams/{examId}/integrity/{caseId}/review"),
        ("POST", "/api/v1/admin/weekly-mock-exams/{examId}/answer-corrections"),
        ("POST", "/api/v1/admin/weekly-mock-exams/{examId}/delete"),
        ("GET", "/api/v1/admin/weekly-mock-objections/{objectionId}"),
        ("POST", "/api/v1/admin/weekly-mock-objections/{objectionId}/reject"),
        ("POST", "/api/v1/admin/weekly-mock-objections/{objectionId}/accept"),
        // 관리자 자료실
        ("POST", "/api/v1/admin/archive/folders/{folderId}"),
        ("POST", "/api/v1/admin/archive/folders/{folderId}/pin"),
        ("POST", "/api/v1/admin/archive/folders/{folderId}/delete"),
        ("POST", "/api/v1/admin/archive/items/{itemId}/delete"),
        ("POST", "/api/v1/admin/archive/trash/{itemId}/restore"),
        ("POST", "/api/v1/admin/archive/trash/{itemId}/purge"),
        // 관리자 수험관·상점
        ("POST", "/api/v1/admin/store/study-hall/{contentId}"),
        ("POST", "/api/v1/admin/store/study-hall/{contentId}/archive"),
        ("POST", "/api/v1/admin/store/products/{productId}"),
        ("POST", "/api/v1/admin/store/products/{productId}/delete"),
        ("POST", "/api/v1/admin/store/categories/{categoryId}"),
        ("POST", "/api/v1/admin/store/categories/{categoryId}/delete"),
        // 관리자 Arena 운영
        ("POST", "/api/v1/admin/arena/matches/{matchId}/review"),
        ("POST", "/api/v1/admin/arena/matches/{matchId}/supplemental-evidence/{role}/request"),
        ("POST", "/api/v1/admin/arena/integrity/{caseId}/review"),
        ("POST", "/api/v1/admin/arena-policies/{division}/{policyId}/activate"),
        ("POST", "/api/v1/admin/arena-policies/{division}/{policyId}/retire"),
        ("POST", "/api/v1/admin/problem-banks/types/{versionId}/revise"),
        ("POST", "/api/v1/admin/problem-banks/arena/data/{versionId}"),
        ("POST", "/api/v1/admin/problem-banks/arena/data/{versionId}/activate"),
        // 관리자 게시판 관리
        ("POST", "/api/v1/admin/community/notices/{noticeId}"),
        ("POST", "/api/v1/admin/community/notices/{noticeId}/pin"),
        ("POST", "/api/v1/admin/community/notices/{noticeId}/status"),
        ("POST", "/api/v1/admin/community/reports/{reportId}/review"),
        ("POST", "/api/v1/admin/community/posts/{postId}"),
        ("POST", "/api/v1/admin/community/posts/{postId}/pin"),
        ("POST", "/api/v1/admin/community/posts/{postId}/status"),
        ("POST", "/api/v1/admin/community/posts/{postId}/warn"),
        ("POST", "/api/v1/admin/community/comments/{commentId}/status"),
        ("POST", "/api/v1/admin/community/comments/{commentId}/warn"),
        // GOAT Arena 경기 명령 — main/* 리터럴은 위에서 이미 걸러졌다.
        ("POST", "/api/v1/goat-arena/matches/main/invitations/{id}/cancel"),
        ("POST", "/api/v1/goat-arena/matches/main/friendly/invitations/{id}/respond"),
        ("POST", "/api/v1/goat-arena/matches/main/friendly/invitations/{id}/cancel"),
        ("POST", "/api/v1/goat-arena/revenge-rights/{id}/claim"),
        ("POST", "/api/v1/goat-arena/revenge-rights/{id}/forfeit"),
        ("GET",  "/api/v1/goat-arena/matches/{matchId}/supplemental-evidence"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/accept"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/decline"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/start"),
        ("GET",  "/api/v1/goat-arena/matches/{matchId}/questions"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/advance"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/heartbeat"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/focus"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/answers"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/network-state"),
        ("GET",  "/api/v1/goat-arena/matches/{matchId}/solution-boards"),
        ("PUT",  "/api/v1/goat-arena/matches/{matchId}/solution-boards/current"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/solution-boards/finalize"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/submit"),
        ("POST", "/api/v1/goat-arena/matches/{matchId}/evidence/client-review"),
        ("GET",  "/api/v1/goat-arena/main/shop/analyses/{effectId}"),
        // 순위표 — 요청한 풀을 반드시 그대로 돌려줘야 한다.
        ("GET",  "/api/v1/access/rankings/{pool}/leaderboard"),
        // 배치고사
        ("GET",  "/api/v1/placement-exam/{attemptId}"),
        ("PATCH", "/api/v1/placement-exam/{attemptId}/draft"),
        ("POST", "/api/v1/placement-exam/{attemptId}/submit"),
        ("POST", "/api/v1/placement-exam/{attemptId}/expire"),
        // 평가센터
        ("GET",  "/api/v1/assessments/{id}"),
        ("PATCH", "/api/v1/assessments/{id}/draft"),
        ("POST", "/api/v1/assessments/{id}/submit"),
        ("POST", "/api/v1/assessments/{id}/expire"),
        // 주간 공식 모의고사
        ("GET",  "/api/v1/weekly-mock-exams/integrity-cases/{caseId}"),
        ("POST", "/api/v1/weekly-mock-exams/weeks/{weekKey}/selection"),
        ("GET",  "/api/v1/weekly-mock-exams/{examId}"),
        ("POST", "/api/v1/weekly-mock-exams/{examId}/start"),
        ("PATCH", "/api/v1/weekly-mock-exams/{examId}/draft"),
        ("POST", "/api/v1/weekly-mock-exams/{examId}/submit"),
        ("POST", "/api/v1/weekly-mock-exams/{examId}/expire"),
        // 학습 진도 PATCH 3종
        ("PATCH", "/api/v1/learning/{courseId}/{unitId}/{conceptId}/mastery"),
        ("PATCH", "/api/v1/learning/{courseId}/{unitId}/{conceptId}/snapshot"),
        ("PATCH", "/api/v1/learning/{courseId}/{unitId}/{conceptId}/topics/{topicIndex}"),
        // 오답노트 복습 결과
        ("POST", "/api/v1/wrong-notes/{attemptId}/review-result"),
        // 알림 1건 읽음
        ("POST", "/api/v1/notifications/{notificationId}/read"),
        // 학생 학원 주차 상세
        ("GET", "/api/v1/academy/student/weeks/{weekId}"),
        // 교사 학원 반복 작업
        ("GET", "/api/v1/academy/teacher/classes/{classId}/classwork"),
        ("GET", "/api/v1/academy/teacher/students/{membershipId}"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/classwork/weeks"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/classwork/weeks/{weekId}/files/{fileId}/remove"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/classwork/weeks/{weekId}/delete"),
        ("POST", "/api/v1/academy/teacher/requests/{membershipId}/approve"),
        ("POST", "/api/v1/academy/teacher/requests/{membershipId}/reject"),
        ("POST", "/api/v1/academy/teacher/students/{membershipId}/class"),
        ("POST", "/api/v1/academy/teacher/students/{membershipId}/remove"),
        ("POST", "/api/v1/academy/teacher/invites/{inviteId}/revoke"),
        ("POST", "/api/v1/academy/teacher/staff/{staffId}/approve"),
        ("POST", "/api/v1/academy/teacher/staff/{staffId}/reject"),
        ("POST", "/api/v1/academy/teacher/staff/{staffId}/revoke"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/settings"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/archive"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/restore"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/co-teachers"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/co-teachers/{teacherUserId}/remove"),
        ("POST", "/api/v1/academy/teacher/classes/{classId}/homeroom-transfer"),
        // 운영자 전체 학원 상세
        ("GET", "/api/v1/academy/admin/{academyId}"),
        ("POST", "/api/v1/academy/admin/{academyId}/profile"),
        ("POST", "/api/v1/academy/admin/{academyId}/profile-image"),
        ("POST", "/api/v1/academy/admin/{academyId}/contract"),
        ("POST", "/api/v1/academy/admin/{academyId}/staff/{staffId}"),
        ("POST", "/api/v1/academy/admin/{academyId}/owner"),
        ("POST", "/api/v1/academy/admin/{academyId}/students/{membershipId}"),
        ("POST", "/api/v1/academy/admin/{academyId}/students/{membershipId}/class"),
        ("POST", "/api/v1/academy/admin/{academyId}/classes/{classId}"),
        ("POST", "/api/v1/academy/admin/{academyId}/classes/{classId}/operations"),
        ("POST", "/api/v1/academy/admin/{academyId}/classes/{classId}/homeroom"),
        ("POST", "/api/v1/academy/admin/{academyId}/invites/{inviteId}"),
        ("POST", "/api/v1/academy/admin/{academyId}/attendance/sessions/{sessionId}/regenerate-code"),
        ("POST", "/api/v1/academy/admin/{academyId}/attendance/{attendanceId}"),
        // 퀵 연습
        ("POST", "/api/v1/quick-practice/{instanceId}/submit"),
        ("POST", "/api/v1/quick-practice/{instanceId}/expire"),
        // 수험관 상세·답안 저장·제출
        ("GET",  "/api/v1/study-hall/content/{contentId}"),
        ("PUT",  "/api/v1/study-hall/content/{contentId}/answers"),
        ("POST", "/api/v1/study-hall/content/{contentId}/submit"),
    ]

    private static func patternRoute(
        method: String, path: String, query: [String: String], body: [String: Any]?
    ) -> String? {
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        for entry in patterns where entry.method == method {
            guard let captures = match(template: entry.template, segments: segments) else { continue }
            return response(
                for: entry.template, method: method,
                captures: captures, query: query, body: body)
        }
        return nil
    }

    private static func match(template: String, segments: [String]) -> [String: String]? {
        let parts = template.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == segments.count else { return nil }
        var captures: [String: String] = [:]
        for (part, segment) in zip(parts, segments) {
            if part.hasPrefix("{"), part.hasSuffix("}") {
                captures[String(part.dropFirst().dropLast())] = segment
            } else if part != segment {
                return nil
            }
        }
        return captures
    }

    private static func response(
        for template: String, method: String, captures: [String: String],
        query: [String: String], body: [String: Any]?
    ) -> String? {
        switch template {
        // 네이티브 커뮤니티
        case "/api/v1/community/posts/{postId}":
            return method == "DELETE"
                ? DemoCommunityFixtures.deleted
                : DemoCommunityFixtures.detail(id: captures["postId"] ?? "")
        case "/api/v1/community/notices/{noticeId}":
            return DemoCommunityFixtures.detail(id: captures["noticeId"] ?? "", kind: "NOTICE")
        case "/api/v1/community/announcements/{announcementId}":
            return DemoCommunityFixtures.detail(id: captures["announcementId"] ?? "", kind: "ANNOUNCEMENT")
        case "/api/v1/community/posts/{postId}/comments":
            return DemoCommunityFixtures.comment
        case "/api/v1/community/posts/{postId}/vote":
            return DemoCommunityFixtures.vote
        case "/api/v1/community/posts/{postId}/report":
            return DemoCommunityFixtures.reported
        case "/api/v1/community/posts/{postId}/block":
            return DemoCommunityFixtures.blocked
        case "/api/v1/community/blocked-users/{userId}":
            return DemoCommunityFixtures.unblocked

        // 빈 객체로 충분한 것들 (Empty 구조체로 디코딩된다)
        case "/api/v1/learning/{courseId}/{unitId}/{conceptId}/mastery",
             "/api/v1/learning/{courseId}/{unitId}/{conceptId}/snapshot",
             "/api/v1/learning/{courseId}/{unitId}/{conceptId}/topics/{topicIndex}",
             "/api/v1/wrong-notes/{attemptId}/review-result",
             "/api/v1/notifications/{notificationId}/read":
            return "{}"

        case "/api/v1/access/rankings/{pool}/leaderboard":
            return DemoArenaFixtures.accessLeaderboard(pool: captures["pool"] ?? "SUB")

        case "/api/v1/academy/student/weeks/{weekId}":
            return DemoAccountFixtures.academyWeek

        case "/api/v1/study-hall/content/{contentId}":
            return DemoStudyHallFixtures.detail(
                status: DemoMode.launchArgumentValue(after: "-studyHallFixture") == "submitted"
                    ? "SUBMITTED" : "IN_PROGRESS"
            )
        case "/api/v1/study-hall/content/{contentId}/answers":
            return DemoStudyHallFixtures.detail(status: "IN_PROGRESS")
        case "/api/v1/study-hall/content/{contentId}/submit":
            return DemoStudyHallFixtures.detail(status: "SUBMITTED")
        case "/api/v1/store-products/{slug}":
            return DemoStoreCatalogFixtures.detail
        case "/api/v1/admin/inquiries/{inquiryId}/reply":
            return DemoAdminOperationsFixtures.delivered
        case "/api/v1/admin/todos/{todoId}/complete",
             "/api/v1/admin/todos/{todoId}/reopen",
             "/api/v1/admin/inquiries/{inquiryId}/status",
             "/api/v1/admin/announcements/{announcementId}/status":
            return DemoAdminOperationsFixtures.mutation
        case "/api/v1/admin/users/{userId}":
            return DemoAdminUsersFixtures.detail
        case "/api/v1/admin/users/{userId}/activity":
            return DemoAdminUsersFixtures.activity(kind: query["kind"] ?? "learning")
        case "/api/v1/admin/users/{userId}/assessments/{attemptId}":
            return DemoAdminUsersFixtures.assessment
        case "/api/v1/admin/parents/{parentId}":
            return DemoAdminUsersFixtures.parentDetail
        case "/api/v1/admin/users/{userId}/email":
            return DemoAdminUsersFixtures.delivered
        case "/api/v1/admin/users/{userId}/role",
             "/api/v1/admin/users/{userId}/account-status",
             "/api/v1/admin/users/{userId}/warnings",
             "/api/v1/admin/users/{userId}/package-access":
            return DemoAdminUsersFixtures.mutationWithDetail
        case "/api/v1/admin/users/{userId}/withdraw":
            return DemoAdminUsersFixtures.withdrawn
        case "/api/v1/admin/users/{userId}/nickname-request",
             "/api/v1/admin/users/{userId}/notification",
             "/api/v1/admin/users/{userId}/password-reset":
            return DemoAdminUsersFixtures.mutation
        case "/api/v1/admin/parents/{parentId}/account-status",
             "/api/v1/admin/parents/{parentId}/children/{childUserId}/notifications",
             "/api/v1/admin/parents/{parentId}/children/{childUserId}/unlink":
            return DemoAdminUsersFixtures.parentMutation
        case "/api/v1/admin/refunds/{refundRequestId}/calculate",
             "/api/v1/admin/refunds/{refundRequestId}/complete",
             "/api/v1/admin/refunds/{refundRequestId}/reject":
            return DemoAdminFinanceFixtures.refundMutation
        case "/api/v1/admin/paybacks/{cycleId}/complete",
             "/api/v1/admin/paybacks/history/{payoutRecordId}/resend-email":
            return DemoAdminFinanceFixtures.mutation
        case "/api/v1/admin/weekly-mock-exams/{examId}":
            return DemoAdminWeeklyMockFixtures.detail
        case "/api/v1/admin/weekly-mock-exams/{examId}/answer-corrections":
            return DemoAdminWeeklyMockFixtures.correction
        case "/api/v1/admin/weekly-mock-exams/{examId}/attempts/{attemptId}/integrity-request",
             "/api/v1/admin/weekly-mock-exams/{examId}/integrity/{caseId}/review",
             "/api/v1/admin/weekly-mock-exams/{examId}/delete",
             "/api/v1/admin/weekly-mock-objections/{objectionId}/reject",
             "/api/v1/admin/weekly-mock-objections/{objectionId}/accept":
            return DemoAdminWeeklyMockFixtures.mutation
        case "/api/v1/admin/weekly-mock-objections/{objectionId}":
            return DemoAdminWeeklyMockFixtures.objection
        case "/api/v1/admin/archive/folders/{folderId}",
             "/api/v1/admin/archive/folders/{folderId}/pin",
             "/api/v1/admin/archive/folders/{folderId}/delete",
             "/api/v1/admin/archive/items/{itemId}/delete",
             "/api/v1/admin/archive/trash/{itemId}/restore",
             "/api/v1/admin/archive/trash/{itemId}/purge":
            return DemoAdminArchiveFixtures.mutation
        case "/api/v1/admin/store/study-hall/{contentId}",
             "/api/v1/admin/store/study-hall/{contentId}/archive",
             "/api/v1/admin/store/products/{productId}",
             "/api/v1/admin/store/products/{productId}/delete",
             "/api/v1/admin/store/categories/{categoryId}",
             "/api/v1/admin/store/categories/{categoryId}/delete":
            return DemoAdminStoreFixtures.mutation
        case "/api/v1/admin/arena/matches/{matchId}/review",
             "/api/v1/admin/arena/matches/{matchId}/supplemental-evidence/{role}/request",
             "/api/v1/admin/arena/integrity/{caseId}/review":
            return DemoAdminArenaFixtures.mutation
        case "/api/v1/admin/arena-policies/{division}/{policyId}/activate",
             "/api/v1/admin/arena-policies/{division}/{policyId}/retire":
            return DemoAdminArenaPolicyFixtures.mutation
        case "/api/v1/admin/problem-banks/types/{versionId}/revise",
             "/api/v1/admin/problem-banks/arena/data/{versionId}",
             "/api/v1/admin/problem-banks/arena/data/{versionId}/activate":
            return DemoAdminProblemBankFixtures.mutation
        case "/api/v1/admin/community/notices/{noticeId}",
             "/api/v1/admin/community/notices/{noticeId}/pin",
             "/api/v1/admin/community/notices/{noticeId}/status",
             "/api/v1/admin/community/reports/{reportId}/review",
             "/api/v1/admin/community/posts/{postId}",
             "/api/v1/admin/community/posts/{postId}/pin",
             "/api/v1/admin/community/posts/{postId}/status",
             "/api/v1/admin/community/posts/{postId}/warn",
             "/api/v1/admin/community/comments/{commentId}/status",
             "/api/v1/admin/community/comments/{commentId}/warn":
            return DemoAdminCommunityFixtures.mutation

        case "/api/v1/academy/teacher/requests/{membershipId}/approve",
             "/api/v1/academy/teacher/requests/{membershipId}/reject",
             "/api/v1/academy/teacher/students/{membershipId}/class",
             "/api/v1/academy/teacher/students/{membershipId}/remove",
             "/api/v1/academy/teacher/invites/{inviteId}/revoke",
             "/api/v1/academy/teacher/staff/{staffId}/approve",
             "/api/v1/academy/teacher/staff/{staffId}/reject",
             "/api/v1/academy/teacher/staff/{staffId}/revoke",
             "/api/v1/academy/teacher/classes/{classId}/settings",
             "/api/v1/academy/teacher/classes/{classId}/archive",
             "/api/v1/academy/teacher/classes/{classId}/restore",
             "/api/v1/academy/teacher/classes/{classId}/co-teachers",
             "/api/v1/academy/teacher/classes/{classId}/co-teachers/{teacherUserId}/remove",
             "/api/v1/academy/teacher/classes/{classId}/homeroom-transfer":
            return DemoAccountFixtures.teacherAcademyDashboard

        case "/api/v1/academy/teacher/students/{membershipId}":
            return DemoAccountFixtures.teacherStudentDetail

        case "/api/v1/academy/teacher/classes/{classId}/classwork",
             "/api/v1/academy/teacher/classes/{classId}/classwork/weeks",
             "/api/v1/academy/teacher/classes/{classId}/classwork/weeks/{weekId}/files/{fileId}/remove",
             "/api/v1/academy/teacher/classes/{classId}/classwork/weeks/{weekId}/delete":
            return DemoAccountFixtures.teacherClasswork

        case "/api/v1/academy/teacher/attendance/sessions/{sessionId}/regenerate-code":
            return DemoAccountFixtures.teacherAttendanceSession

        case "/api/v1/academy/admin/applications/{academyId}/approve",
             "/api/v1/academy/admin/applications/{academyId}/reject":
            return DemoAccountFixtures.adminAcademyDashboard

        case "/api/v1/academy/admin/{academyId}":
            if DemoMode.launchArgumentValue(after: "-adminAcademyFixture") == "detail-error" {
                return nil
            }
            return DemoAccountFixtures.adminAcademyDetail

        case "/api/v1/academy/admin/{academyId}/profile",
             "/api/v1/academy/admin/{academyId}/profile-image",
             "/api/v1/academy/admin/{academyId}/contract",
             "/api/v1/academy/admin/{academyId}/staff/{staffId}",
             "/api/v1/academy/admin/{academyId}/owner",
             "/api/v1/academy/admin/{academyId}/students/{membershipId}",
             "/api/v1/academy/admin/{academyId}/students/{membershipId}/class",
             "/api/v1/academy/admin/{academyId}/classes/{classId}",
             "/api/v1/academy/admin/{academyId}/classes/{classId}/operations",
             "/api/v1/academy/admin/{academyId}/classes/{classId}/homeroom",
             "/api/v1/academy/admin/{academyId}/invites/{inviteId}",
             "/api/v1/academy/admin/{academyId}/attendance/sessions/{sessionId}/regenerate-code":
            return DemoAccountFixtures.adminAcademyDetail

        case "/api/v1/academy/admin/{academyId}/attendance/{attendanceId}":
            return DemoAccountFixtures.adminAcademyDetail

        case "/api/v1/coach-suggestions/{suggestionId}":
            return DemoAccountFixtures.coachSuggestionMutation

        case "/api/v1/placement-exam/{attemptId}":
            return DemoAccountFixtures.placementAttempt
        case "/api/v1/placement-exam/{attemptId}/draft":
            return DemoAccountFixtures.placementDraft
        case "/api/v1/placement-exam/{attemptId}/submit",
             "/api/v1/placement-exam/{attemptId}/expire":
            return DemoAccountFixtures.placementSubmission

        case "/api/v1/assessments/{id}":
            return DemoAssessmentFixtures.assessmentDetail(id: captures["id"] ?? "")
        case "/api/v1/assessments/{id}/draft":
            return DemoAssessmentFixtures.assessmentDraft
        case "/api/v1/assessments/{id}/submit",
             "/api/v1/assessments/{id}/expire":
            return DemoAssessmentFixtures.submittedAssessment(id: captures["id"] ?? "")

        // 2회차(demo-mock-02)만 **실제로 응시할 수 있는** 회차로 답한다.
        // DemoAssessmentFixtures 의 회차 픽스처는 회차 번호와 무관하게 항상
        // "제출 완료" 를 돌려줘서, 데모에서는 대기실도 응시 화면도 볼 수 없었고
        // 그래서 시험지 PDF 다운로드 경로 자체가 한 번도 실행되지 않았다(실측).
        case "/api/v1/weekly-mock-exams/{examId}":
            let examId = captures["examId"] ?? ""
            if examId == DemoWeeklyMockLive.examId {
                return DemoWeeklyMockLive.attempt(started: DemoWeeklyMockLive.isStarted)
            }
            return DemoAssessmentFixtures.weeklyMockAttempt(examId: examId)
        case "/api/v1/weekly-mock-exams/{examId}/start":
            let examId = captures["examId"] ?? ""
            if examId == DemoWeeklyMockLive.examId {
                DemoWeeklyMockLive.markStarted()
                return #"{"replayed":false,"attempt":\#(DemoWeeklyMockLive.attemptBody(started: true))}"#
            }
            return DemoAssessmentFixtures.weeklyMockStart(examId: examId)
        case "/api/v1/weekly-mock-exams/{examId}/draft":
            return DemoAssessmentFixtures.weeklyMockDraft
        case "/api/v1/weekly-mock-exams/{examId}/submit":
            return DemoAssessmentFixtures.weeklyMockSubmit
        case "/api/v1/weekly-mock-exams/{examId}/expire":
            return DemoAssessmentFixtures.weeklyMockExpire
        case "/api/v1/weekly-mock-exams/integrity-cases/{caseId}":
            return DemoAssessmentFixtures.weeklyMockIntegrityDetail
        case "/api/v1/weekly-mock-exams/weeks/{weekKey}/selection":
            let attempt = string(body, "attemptId")
            return #"{"selected":true,"selection":{"selectionState":"MANUAL","selectedAttemptId":"\#(attempt)"}}"#

        case "/api/v1/quick-practice/{instanceId}/submit":
            return DemoAccountFixtures.quickSubmit(answer: string(body, "answer"))
        case "/api/v1/quick-practice/{instanceId}/expire":
            return DemoAccountFixtures.quickExpire

        // GOAT Arena 경기 명령
        case "/api/v1/goat-arena/matches/{matchId}/accept",
             "/api/v1/goat-arena/matches/{matchId}/decline":
            return DemoArenaFixtures.matchCommandResponse(
                matchId: captures["matchId"] ?? "", accepted: template.hasSuffix("accept"))
        case "/api/v1/goat-arena/matches/{matchId}/start",
             "/api/v1/goat-arena/matches/{matchId}/advance":
            return DemoArenaFixtures.matchStart(
                matchId: captures["matchId"] ?? "",
                slot: (int(body, "questionSlot") ?? 0) + 1)
        case "/api/v1/goat-arena/matches/{matchId}/questions":
            return DemoArenaFixtures.questionPack(matchId: captures["matchId"] ?? "", slot: 1)
        case "/api/v1/goat-arena/matches/{matchId}/heartbeat",
             "/api/v1/goat-arena/matches/{matchId}/focus",
             "/api/v1/goat-arena/matches/{matchId}/answers",
             "/api/v1/goat-arena/matches/{matchId}/network-state":
            return DemoArenaFixtures.matchEvent(
                matchId: captures["matchId"] ?? "", template: template, body: body)
        case "/api/v1/goat-arena/matches/{matchId}/solution-boards":
            return #"{"boards":[]}"#
        case "/api/v1/goat-arena/matches/{matchId}/solution-boards/current":
            // multipart 본문은 JSON choke point처럼 필드를 꺼낼 수 없다. 각 문항의
            // 첫 강제 저장 revision은 1이고, 화면은 현재 slot에 이 receipt를 매핑한다.
            // 64자리 해시는 다음 문항 요청의 서버 계약을 그대로 통과시키기 위한 값이다.
            return #"{"board":{"questionSlot":1,"revision":1,"strokeCount":0,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","previewURL":null,"savedAt":"2026-08-31T00:00:00.000Z","finalizedAt":null,"drawingDataBase64":null}}"#
        case "/api/v1/goat-arena/matches/{matchId}/solution-boards/finalize":
            return #"{"finalized":true,"replayed":false}"#
        case "/api/v1/goat-arena/matches/{matchId}/submit":
            return DemoArenaFixtures.matchSubmission(matchId: captures["matchId"] ?? "")
        case "/api/v1/goat-arena/matches/{matchId}/evidence/client-review":
            return #"{"review":{"reviewId":"demo-review-1","replayed":false,"accepted":true}}"#
        case "/api/v1/goat-arena/matches/main/invitations/{id}/cancel":
            return DemoArenaFixtures.invitationCancelled(id: captures["id"] ?? "")
        case "/api/v1/goat-arena/matches/main/friendly/invitations/{id}/respond":
            return DemoArenaFixtures.friendlyInvitationResponded(
                id: captures["id"] ?? "",
                response: string(body, "response"))
        case "/api/v1/goat-arena/matches/main/friendly/invitations/{id}/cancel":
            return DemoArenaFixtures.friendlyInvitationCancelled(id: captures["id"] ?? "")
        case "/api/v1/goat-arena/revenge-rights/{id}/claim":
            return DemoArenaFixtures.revengeClaimed(id: captures["id"] ?? "")
        case "/api/v1/goat-arena/revenge-rights/{id}/forfeit":
            return DemoArenaFixtures.revengeForfeited(id: captures["id"] ?? "")
        case "/api/v1/goat-arena/matches/{matchId}/supplemental-evidence":
            return DemoArenaFixtures.supplementalRequest(matchId: captures["matchId"] ?? "")
        case "/api/v1/goat-arena/main/shop/analyses/{effectId}":
            return DemoArenaFixtures.shopAnalysis(effectId: captures["effectId"] ?? "")

        default:
            return nil
        }
    }

    // MARK: 요청 본문 되비추기 헬퍼

    static func string(_ body: [String: Any]?, _ key: String) -> String {
        escaped(String(describing: body?[key] ?? ""))
    }

    static func int(_ body: [String: Any]?, _ key: String) -> Int? {
        body?[key] as? Int
    }

    /// JSON 문자열 안에 그대로 넣어도 되게 최소한만 이스케이프한다.
    static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// 오답노트 bulk 업로드 응답 — clientAttemptId 매핑을 버리면 복습 결과를
    /// 올릴 주소를 영영 알 수 없다(ServerAPI.postWrongNotes 주석 참조).
    private static func syncedListEcho(_ body: [String: Any]?) -> String {
        let entries = (body?["entries"] as? [[String: Any]]) ?? []
        let rows = entries.enumerated().map { index, entry -> String in
            let client = escaped(String(describing: entry["clientAttemptId"] ?? "demo-\(index)"))
            return #"{"clientAttemptId":"\#(client)","attemptId":"demo-attempt-\#(index)","duplicate":false}"#
        }
        return #"{"synced":[\#(rows.joined(separator: ","))]}"#
    }
}

// MARK: - 응시 가능한 주간 모의고사 회차

/// 데모에서 대기실 → 응시 → 시험지 PDF 까지 실제로 밟아 볼 수 있는 회차.
///
/// 왜 필요한가(실측): DemoFixturesAssessment 의 회차 픽스처는 examId 를 무시하고
/// 언제나 `state: "submitted"` 를 돌려준다. 그래서 대시보드의 "응시 시작" 을 눌러도
/// 결과 화면이 떴고, `state == "in-progress"` 일 때만 도는 시험지 다운로드가
/// 데모에서 한 번도 실행되지 않았다. 대시보드가 이미 2회차(demo-mock-02)를
/// `canStart: true` 로 내고 있으므로 **그 회차만** 살아 있는 상태로 답한다.
/// (1회차·33주차는 그대로 제출 완료 — 결과 화면도 계속 볼 수 있어야 한다.)
enum DemoWeeklyMockLive {
    private static let stateLock = NSLock()

    /// 대시보드 픽스처(DemoFixturesAssessment.weeklyMockDashboard)의 2회차 id.
    static let examId = "demo-mock-02"

    /// 시작을 눌렀는지. 시작 뒤에도 GET 이 다시 오기 때문에(앱이 포그라운드로
    /// 돌아올 때마다 load 한다) 여기서 기억하지 않으면 응시 화면이 대기실로 되돌아간다.
    private static var started = false

    static var isStarted: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return started
    }

    static func markStarted() {
        stateLock.lock()
        started = true
        stateLock.unlock()
    }

    /// 데모를 껐다 켜면 다시 대기실부터 — 감독이 같은 흐름을 반복해 볼 수 있어야 한다.
    static func reset() {
        stateLock.lock()
        started = false
        stateLock.unlock()
    }

    static func attempt(started: Bool) -> String {
        #"{"attempt":\#(attemptBody(started: started))}"#
    }

    static func attemptBody(started: Bool) -> String {
        // deadline 은 상대 토큰으로 둔다 — 고정 시각을 박으면 하루 뒤에 열었을 때
        // 남은 시간이 0 이 되어 응시 화면이 곧바로 만료로 넘어간다.
        let state = started ? "in-progress" : "lobby"
        let deadline = started ? "@T+96m@" : "@T+5d@"
        let answers = (0..<30).map { _ in #""""# }.joined(separator: ",")
        return #"""
        {
          "state": "\#(state)",
          "submitted": false,
          "serverNow": "@T+0s@",
          "deadline": "\#(deadline)",
          "releaseAt": "@T-2d@",
          "canStart": \#(started ? "false" : "true"),
          "pendingAggregation": false,
          "resultsAvailableAt": "@T+5d@",
          "reviewAvailable": false,
          "reviewPublishesAt": "@T+5d@",
          "exam": {
            "id": "\#(examId)",
            "title": "2026학년도 주간 공식 모의고사 34주차 (2회차)",
            "weekKey": "@WEEK@",
            "formCode": "W34-B",
            "attemptNumber": 2,
            "isTest": false,
            "questionCount": 30,
            "questionModes": null,
            "durationMinutes": 100,
            "paperPath": "/api/v1/weekly-mock-exams/\#(examId)/paper"
          },
          "attempt": {
            "id": "demo-mock-attempt-02",
            "answers": [\#(answers)],
            "answeredCount": 0
          },
          "tools": { "formulaPath": null },
          "result": null,
          "selection": null,
          "integrityReview": null,
          "review": null
        }
        """#
    }
}

// MARK: - JSON 이외 경로 가로채기 (PDF 다운로드 · multipart 업로드)
//
// ## 왜 별도 장치가 필요한가
// `ServerAPI.request()` 는 앱의 JSON choke point 지만, **그 앞을 지나지 않는** 요청이
// 넷 있다. 모두 `ServerAPI.authorizedRequest` 로 URLRequest 를 만들고
// URLSession 의 download/upload 를 직접 부른다.
//
//   GET  /api/v1/weekly-mock-exams/{examId}/paper                      주간 모의고사 시험지 PDF
//   POST /api/v1/weekly-mock-exams/integrity-cases/{caseId}/evidence   무결성 소명 파일
//   POST /api/v1/goat-arena/matches/{matchId}/evidence                 아레나 풀이 증거 사진
//   PUT  /api/v1/goat-arena/matches/{matchId}/solution-boards/current  인앱 풀이판 원본
//
// 데모에는 키체인 토큰이 없어서 authorizedRequest 가 **401 로 먼저 막았다**.
// 그래서 감독이 "시험장 입장 → 시작" 을 누르면 시험지 PDF 다운로드에서 끝났다.
//
// ## 어떻게 막는가 — 두 겹
//   ① `ServerAPI.authorizedRequest` 가 데모에서는 토큰 검사를 건너뛰고 주소의 호스트를
//      `demo.matths.invalid` 로 바꾼다. 해석되지 않는 예약 TLD 라 ②가 어떤 이유로든
//      안 걸려도 감독의 요청이 운영 서버(www.matths.kr)로 새어 나갈 수 없다.
//   ② `DemoURLProtocol` 이 그 호스트만 가로채 준비된 바이트를 돌려준다.
//      URLProtocol 은 `URLSession.shared` 의 download·upload 태스크에도 걸리므로
//      호출부(WeeklyMockAPI · GoatArenaEvidencePanel)는 **한 줄도 바꾸지 않는다** —
//      그 파일들은 이 작업의 소유가 아니고, 실서버 경로를 데모가 오염시켜서도 안 된다.

/// 데모 전용 URL 로더. `DemoMode.networkHost` 로 간 요청만 가로챈다.
final class DemoURLProtocol: URLProtocol {
    private static let installLock = NSLock()
    private static var installed = false

    /// 두 번 불러도 안전하다. 데모 슬롯 진입(앱 시작·런타임 토글)에서 부른다.
    static func installOnce() {
        installLock.lock()
        defer { installLock.unlock() }
        guard !installed else { return }
        installed = true
        let registered = URLProtocol.registerClass(DemoURLProtocol.self)
        NSLog("DEMO-MODE URLProtocol 등록 %@ · host=%@",
              registered ? "성공" : "실패", DemoMode.networkHost)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        // 데모를 끄면 즉시 손을 뗀다. 등록 해제는 하지 않는다 —
        // 이미 진행 중인 태스크가 있는 상태에서의 unregister 는 경합이 된다.
        DemoMode.isOn && request.url?.host?.lowercased() == DemoMode.networkHost
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let method = (request.httpMethod ?? "GET").uppercased()
        let path = request.url?.path ?? ""
        let url = request.url ?? URL(string: "https://\(DemoMode.networkHost)/")!

        guard let payload = DemoBinaryRouter.payload(method: method, path: path) else {
            // 픽스처가 없는 경로는 JSON 쪽과 같은 규칙으로 알아볼 수 있게 실패시킨다.
            // (디버그 바의 "픽스처 없음" 개수에도 같이 잡힌다.)
            _ = DemoMode.missingFixture(method: method, path: path)
            let body = Data(#"{"message":"데모 픽스처가 없는 경로입니다: \#(method) \#(path)","code":"DEMO_FIXTURE_MISSING"}"#.utf8)
            deliver(url: url, status: 501, contentType: "application/json", data: body)
            return
        }
        deliver(url: url, status: 200, contentType: payload.contentType, data: payload.data)
    }

    override func stopLoading() {}

    private func deliver(url: URL, status: Int, contentType: String, data: Data) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": contentType,
                "Content-Length": String(data.count),
            ]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

// MARK: - 바이트 응답 라우터

enum DemoBinaryRouter {
    struct Payload {
        var contentType: String
        var data: Data
    }

    static func payload(method: String, path: String) -> Payload? {
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        // 첨부 게시글 등록은 multipart 전송계층을 실제로 통과한다.
        if method == "POST", segments == ["api", "v1", "community", "posts"] {
            return json(DemoCommunityFixtures.createdPost)
        }

        // 커뮤니티 첨부파일도 운영과 같은 다운로드·미리보기 경로를 거친다.
        if method == "GET",
           let captures = match(
            ["api", "v1", "community", "posts", "{postId}", "attachments", "{attachmentId}"],
            segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "community-\(captures["attachmentId"] ?? "file")"))
        }

        // 주간 모의고사 시험지 — 진짜 PDF 여야 한다.
        // WeeklyMockAPI 가 앞 5바이트가 "%PDF-" 인지 확인하고 아니면 INVALID_PDF 로 막는다.
        if method == "GET",
           let captures = match(["api", "v1", "weekly-mock-exams", "{examId}", "paper"], segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: captures["examId"] ?? "demo-exam"))
        }

        // 학원 과제 PDF도 실제 다운로드·QuickLook 경로를 거친다.
        if method == "GET",
           let captures = match(
            ["api", "v1", "academy", "student", "weeks", "{weekId}", "files", "{fileId}"],
            segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "academy-\(captures["weekId"] ?? "week")"))
        }

        if method == "GET",
           let captures = match(
            ["api", "v1", "academy", "teacher", "classes", "{classId}", "classwork", "weeks", "{weekId}", "files", "{fileId}"],
            segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "teacher-academy-\(captures["weekId"] ?? "week")"))
        }

        if method == "GET",
           let captures = match(
            ["api", "v1", "academy", "admin", "{academyId}", "weeks", "{weekId}", "files", "{fileId}"],
            segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "admin-academy-\(captures["weekId"] ?? "week")"))
        }

        if method == "POST",
           match(
            ["api", "v1", "academy", "admin", "{academyId}", "profile-image"],
            segments) != nil {
            return json(DemoAccountFixtures.adminAcademyDetail)
        }

        // 파일이 붙은 주차 저장은 JSON choke point가 아니라 multipart URLSession 경로다.
        // 데모에서도 실제 업로드 전송계층까지 통과한 뒤 같은 작업대 응답으로 돌아온다.
        if method == "POST",
           match(
            ["api", "v1", "academy", "teacher", "classes", "{classId}", "classwork", "weeks"],
            segments) != nil {
            return json(DemoAccountFixtures.teacherClasswork)
        }

        // 자료실 PDF도 목록과 동일한 Bearer 다운로드 경로를 실제로 통과한다.
        if method == "GET",
           let captures = match(
            ["api", "v1", "archive", "items", "{itemId}", "download"], segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "archive-\(captures["itemId"] ?? "item")"))
        }

        // 수험관 문제지·제출 후 해설도 실제 QuickLook 다운로드 경로로 검수한다.
        if method == "GET",
           let captures = match(
            ["api", "v1", "study-hall", "content", "{contentId}", "files", "{assetId}"],
            segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "study-hall-\(captures["assetId"] ?? "file")"))
        }

        // 무료 자료 PDF와 표지/상세 이미지는 JSON 응답과 다른 실제 바이트 경로다.
        if method == "GET",
           let captures = match(
            ["api", "v1", "store-products", "{slug}", "files", "{assetId}"], segments) {
            return Payload(
                contentType: "application/pdf",
                data: DemoExamPaper.pdf(examId: "store-\(captures["assetId"] ?? "file")"))
        }
        if method == "GET",
           let captures = match(
            ["api", "v1", "store-products", "{productId}", "media", "{assetId}"], segments) {
            return Payload(
                contentType: "image/png",
                data: DemoStoreArtwork.png(
                    title: captures["assetId"] == "demo-store-thumb" ? "미적분 핵심 유형" : "12문항 학습 구성"))
        }

        // 무결성 소명 파일 접수증
        if method == "POST",
           let captures = match(
               ["api", "v1", "weekly-mock-exams", "integrity-cases", "{caseId}", "evidence"],
               segments) {
            let id = DemoRouter.escaped(captures["caseId"] ?? "demo-case")
            return json(#"""
            {
              "evidence": {
                "submitted": true,
                "replayed": false,
                "receiptId": "DEMO-\#(id)-01",
                "submittedAt": "@T+0s@"
              }
            }
            """#)
        }

        // 운영자가 요청한 추가 소명 사진의 multipart 접수증.
        if method == "POST",
           match(
               ["api", "v1", "goat-arena", "matches", "{matchId}", "supplemental-evidence"],
               segments) != nil {
            return json(DemoArenaFixtures.supplementalSubmission)
        }

        // 아레나 풀이 증거 사진 접수증 — 60초 제출 창을 통과한 모습으로 돌려준다.
        if method == "POST",
           let captures = match(
               ["api", "v1", "goat-arena", "matches", "{matchId}", "evidence"], segments) {
            let id = DemoRouter.escaped(captures["matchId"] ?? "demo-match")
            return json(#"""
            {
              "evidence": {
                "evidenceId": "demo-evidence-01",
                "attemptId": "demo-attempt-01",
                "matchId": "\#(id)",
                "status": "ACCEPTED",
                "matchStatus": "SUBMITTED",
                "replayed": false,
                "submissionId": "demo-submission-id-01",
                "submittedAt": "@T+0s@",
                "deadlineAt": "@T+55s@",
                "anomalyFlags": []
              }
            }
            """#)
        }

        // 인앱 풀이판 저장. multipart를 직접 보내는 경로라 JSON router가 아니라
        // 여기서 receipt를 돌려줘야 다음 문항 전환까지 실제로 검수할 수 있다.
        if method == "PUT",
           match(
               ["api", "v1", "goat-arena", "matches", "{matchId}",
                "solution-boards", "current"], segments) != nil {
            return json(#"{"board":{"questionSlot":1,"revision":1,"strokeCount":0,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","previewURL":null,"savedAt":"@T+0s@","finalizedAt":null,"drawingDataBase64":null}}"#)
        }

        return nil
    }

    private static func json(_ template: String) -> Payload {
        Payload(
            contentType: "application/json",
            data: Data(DemoTemplate.resolve(template).utf8))
    }

    /// DemoRouter 와 같은 규칙의 최소 매처. `{name}` 은 아무 세그먼트나 잡는다.
    private static func match(_ template: [String], _ segments: [String]) -> [String: String]? {
        guard template.count == segments.count else { return nil }
        var captures: [String: String] = [:]
        for (part, segment) in zip(template, segments) {
            if part.hasPrefix("{"), part.hasSuffix("}") {
                captures[String(part.dropFirst().dropLast())] = segment
            } else if part != segment {
                return nil
            }
        }
        return captures
    }
}

// MARK: - 데모 자료 이미지

enum DemoStoreArtwork {
    private static let lock = NSLock()
    private static var cache: [String: Data] = [:]

    static func png(title: String) -> Data {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[title] { return cached }
        let size = CGSize(width: 720, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.18, green: 0.12, blue: 0.42, alpha: 1).setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.46, green: 0.25, blue: 1, alpha: 1).setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 22, height: size.height))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let heading: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 54, weight: .black),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
            NSString(string: "MATTHS\n\n\(title)").draw(
                in: CGRect(x: 64, y: 250, width: 592, height: 300),
                withAttributes: heading)
            let caption: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 25, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.72),
                .paragraphStyle: paragraph,
            ]
            NSString(string: "무료 공개 자료 · DEMO").draw(
                in: CGRect(x: 64, y: 720, width: 592, height: 80),
                withAttributes: caption)
        }
        let data = image.pngData() ?? Data()
        cache[title] = data
        return data
    }
}

// MARK: - 데모 시험지 PDF

/// 번들에 바이너리를 넣지 않고 **코드로** 그린다.
/// 이유가 둘이다. (1) 시험지 PDF 는 KICE 자료 게이트가 감시하는 종류의 파일이라
/// 데모용 더미라도 번들에 두면 그 게이트와 헷갈린다. (2) 코드로 그리면 회차·과목이
/// 픽스처와 어긋날 때 한 곳만 고치면 된다.
enum DemoExamPaper {
    /// 같은 회차를 다시 열 때 매번 다시 그리지 않는다(시험 중 재다운로드가 있다).
    private static let cacheLock = NSLock()
    private static var cache: [String: Data] = [:]

    static func pdf(examId: String) -> Data {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = cache[examId] { return cached }
        let data = render(examId: examId)
        cache[examId] = data
        return data
    }

    private static let questions: [(String, [String])] = [
        ("함수 f(x) = x³ − 3x² + 4 의 극댓값을 구하시오.",
         ["① 0", "② 2", "③ 4", "④ 6", "⑤ 8"]),
        ("등비수열 {aₙ} 에서 a₁ = 3, a₄ = 24 일 때 공비 r 의 값은?",
         ["① 1", "② 2", "③ 3", "④ 4", "⑤ 6"]),
        ("lim(x→0) (sin 5x) / (3x) 의 값을 구하시오.",
         ["① 0", "② 3/5", "③ 1", "④ 5/3", "⑤ 5"]),
        ("한 개의 주사위를 두 번 던져 나온 눈의 합이 7일 확률은?",
         ["① 1/12", "② 1/9", "③ 1/6", "④ 5/36", "⑤ 7/36"]),
        ("정적분 ∫₀¹ (3x² + 2x) dx 의 값을 구하시오.",
         ["① 1", "② 3/2", "③ 2", "④ 5/2", "⑤ 3"]),
        ("두 점 A(1, 2), B(5, −2) 를 지나는 직선의 기울기는?",
         ["① −2", "② −1", "③ 0", "④ 1", "⑤ 2"]),
    ]

    private static func render(examId: String) -> Data {
        // A4 72dpi. 앱의 PDF 뷰어가 한 쪽씩 넘겨 보는 모습까지 확인하려고 2쪽으로 만든다.
        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            for pageIndex in 0..<2 {
                context.beginPage()
                draw(pageIndex: pageIndex, examId: examId, in: page)
            }
        }
    }

    private static func draw(pageIndex: Int, examId: String, in page: CGRect) {
        let margin: CGFloat = 48
        var y: CGFloat = margin

        if pageIndex == 0 {
            y = drawHeader(examId: examId, page: page, margin: margin, y: y)
        } else {
            y = drawRunningHead(page: page, margin: margin, y: y)
        }

        let range = pageIndex == 0 ? 0..<3 : 3..<questions.count
        for index in range {
            let (text, choices) = questions[index]
            y = drawQuestion(number: index + 1, text: text, choices: choices,
                             page: page, margin: margin, y: y)
        }

        drawFooter(pageIndex: pageIndex, page: page, margin: margin)
    }

    private static func drawHeader(examId: String, page: CGRect,
                                   margin: CGFloat, y: CGFloat) -> CGFloat {
        var y = y
        "MATTHS WEEKLY MOCK EXAM".draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .heavy),
                .foregroundColor: UIColor(red: 0.19, green: 0.34, blue: 0.96, alpha: 1),
                .kern: 1.6,
            ])
        y += 20
        "주간 공식 모의고사 · 수학 영역".draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: UIFont.systemFont(ofSize: 24, weight: .bold)])
        y += 34
        "제한시간 100분 · 5지 선다형 6문항 · 배점 100점".draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray,
            ])
        y += 22

        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y))
        line.addLine(to: CGPoint(x: page.width - margin, y: y))
        line.lineWidth = 1.5
        UIColor(white: 0.75, alpha: 1).setStroke()
        line.stroke()
        y += 18

        // WHY 이모지를 쓰지 않는가(실측): PDF 렌더러가 쓰는 시스템 폰트에 컬러 이모지가
        // 없어서 ⚠️ 가 빈 네모(▯)로 찍혔다. 강조는 글자 대신 배경 띠로만 준다.
        let notice = """
        이 문서는 데모 모드가 만들어 낸 더미 시험지입니다. \
        실제 출제 문항이 아니며 채점·성적과 무관합니다. (회차 \(examId))
        """
        let noticeRect = CGRect(x: margin, y: y, width: page.width - margin * 2, height: 46)
        UIColor(red: 1, green: 0.96, blue: 0.86, alpha: 1).setFill()
        UIBezierPath(roundedRect: noticeRect.insetBy(dx: -8, dy: -6), cornerRadius: 8).fill()
        notice.draw(in: noticeRect, withAttributes: [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor(red: 0.45, green: 0.29, blue: 0.02, alpha: 1),
        ])
        return y + 52
    }

    private static func drawRunningHead(page: CGRect, margin: CGFloat, y: CGFloat) -> CGFloat {
        "주간 공식 모의고사 · 수학 영역 (데모)".draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.darkGray,
            ])
        return y + 30
    }

    private static func drawQuestion(number: Int, text: String, choices: [String],
                                     page: CGRect, margin: CGFloat, y: CGFloat) -> CGFloat {
        var y = y
        let width = page.width - margin * 2
        "\(number).".draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .bold)])
        let bodyRect = CGRect(x: margin + 24, y: y, width: width - 24, height: 60)
        text.draw(in: bodyRect, withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
        y += 44
        for choice in choices {
            choice.draw(
                at: CGPoint(x: margin + 30, y: y),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor(white: 0.2, alpha: 1),
                ])
            y += 20
        }
        return y + 22
    }

    private static func drawFooter(pageIndex: Int, page: CGRect, margin: CGFloat) {
        let text = "\(pageIndex + 1) / 2 · Matths 데모 시험지"
        text.draw(
            at: CGPoint(x: margin, y: page.height - margin),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.lightGray,
            ])
    }
}

#endif
