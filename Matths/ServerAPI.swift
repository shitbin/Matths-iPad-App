//  ServerAPI.swift
//  Matths
//
//  웹 서버(Express + MongoDB) 의 /api/v1 Bearer 토큰 트랙 클라이언트.
//  세션판 /api/* 는 미인증 시 302→HTML 이라 앱은 쓰지 않는다 (동기화 설계서 전제).
//
//  회원가입/로그인 → accessToken(30일) 을 키체인에 보관, 이후 요청에 Bearer 첨부.
//  401 UNAUTHORIZED = 만료, 401 TOKEN_REVOKED = 비번 변경으로 무효화 — 둘 다
//  토큰을 지우고 재로그인으로 보낸다.
//
//  서버 주소는 빌드 환경이 고른다. 학생이 로그인 화면에서 바꾸지 않으며,
//  개발 빌드는 맥의 Bonjour 이름, 출시 빌드는 운영 HTTPS 주소로 자동 연결한다.

import Foundation
import Security
import UniformTypeIdentifiers

extension Notification.Name {
    /// 현재 Keychain 토큰을 실제로 사용한 요청이 401을 받은 경우에만 보낸다.
    /// 로그인 전 Google grant 교환의 401은 기존 계정 세션을 끊지 않는다.
    static let matthsServerAuthenticationExpired = Notification.Name(
        "kr.matths.server-authentication-expired")
}

// MARK: - 응답 모델 (서버 user shape — 미지 필드는 무시되도록 전부 옵셔널 위주)

struct ServerUser: Codable {
    var name: String?
    var realName: String?
    var email: String?
    /// 서버의 실제 계정 역할. 학생·교사·운영자에게 같은 관리 메뉴를 노출하지 않고
    /// 역할에 맞는 학원/운영 포털 진입점만 보여 주는 데 사용한다.
    var role: String? = nil
    var schoolGrade: Int?
    var school: ServerSchool?
    var currentStreak: Int?
    var longestStreak: Int?
    var rankingDisplayMode: String?
    var coachMode: String?
    var reducedMotion: Bool?
    var profileAvatar: ServerProfileAvatar?
    var arenaActivityLevel: ServerArenaActivityLevel?
    var dashboardTutorial: ServerTutorialStatus?
    var arenaTutorial: ServerArenaTutorialStatus?
}

struct ServerProfileAvatar: Codable, Equatable {
    var code: String
    var label: String
    var description: String?
    var imageSrc: String?
    var isCustom: Bool
}

struct ServerArenaActivityLevel: Codable, Equatable {
    var level: Int
    var maxLevel: Int
    var totalMatches: Int
    var currentLevelStart: Int
    var nextLevelThreshold: Int?
    var matchesToNext: Int
    var levelProgress: Int
    var isMaxLevel: Bool
}

struct ServerTutorialStatus: Codable, Equatable {
    var status: String
    var shouldAutoStart: Bool?
    var completedAt: String?
    var skippedAt: String?
}

struct ServerArenaTutorialStatus: Codable, Equatable {
    var version: Int
    var activeDivision: String?
    var eligibleChapters: [String]
    var availableChapters: [String]
    var chapters: [String: ServerTutorialStatus]
    var autoChapter: String?
    var shouldAutoStart: Bool
    var suspended: Bool
}

struct ServerSchool: Codable {
    var region: String?
    var code: String?
    var name: String?
}

struct AuthResponse: Codable {
    var tokenType: String?
    var accessToken: String
    var expiresIn: Int?
    var user: ServerUser
}

struct MeResponse: Codable { var user: ServerUser }

struct ServerAPIError: LocalizedError, Decodable {
    var message: String?
    var code: String?
    /// 응답 본문에 없어도 요청 계층이 실제 HTTP 상태를 채운다.
    /// 404(구버전 서버)와 401(세션 만료)을 네트워크 오류로 뭉개지 않기 위한 값.
    var statusCode: Int? = nil
    var errorDescription: String? {
        let readable = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        // code는 클라이언트 분기용 기계 값이다. message가 없는 응답에서 이를 그대로
        // LocalizedError로 내보내면 여러 화면에 GOAT_ARENA_* 같은 문자열이 노출된다.
        guard let readable, !readable.isEmpty else {
            return "요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
        return readable
    }

    private enum CodingKeys: String, CodingKey {
        case message, code
    }
}

extension ServerAPIError {
    /// 서버가 라우트 자체를 모를 때(HTTP_404). 경기 명령 라우트가 없는 서버(웹 세션 전용)를
    /// "도전 없음"(404 GOAT_ARENA_MATCH_NOT_FOUND 등 코드 있는 404)과 구분하기 위해 code 까지 본다.
    var isRouteMissing: Bool { statusCode == 404 && (code == nil || code == "HTTP_404") }
}

// MARK: - 클라이언트

enum ServerAPI {
    /// Cafe24 운영 도메인. 학생에게 서버 주소 입력을 노출하지 않는다.
    static let defaultURL = "https://www.matths.kr"

    static let baseURL: URL = {
        // 구버전에서 사용자가 입력했던 주소가 업그레이드 뒤 인증 경로를 가로막지 않게
        // 폐기한다. 키체인의 로그인 토큰과 계정 데이터는 건드리지 않는다.
        UserDefaults.standard.removeObject(forKey: "matths.serverURL")

        #if DEBUG
        if let marker = ProcessInfo.processInfo.arguments.firstIndex(of: "-serverURL"),
           ProcessInfo.processInfo.arguments.indices.contains(marker + 1),
           let override = URL(string: ProcessInfo.processInfo.arguments[marker + 1]) {
            return override
        }
        #endif
        return URL(string: Self.defaultURL)!
    }()

    /// iOS 웹뷰 안에서 열면 안 되는 웹 결제 표면.
    ///
    /// 디지털 이용권은 네이티브 StoreKit 화면에서만 판매한다. 게시판·Arena처럼
    /// 로그인 쿠키가 이어진 웹뷰는 같은 호스트 이동을 허용하므로, 서버 페이지에
    /// `/pricing` 링크가 하나만 생겨도 Toss 결제까지 앱 안에서 열릴 수 있다.
    /// 호출부가 서버 호스트인지 먼저 확인한 뒤 이 판별로 네이티브 구매 화면에 보낸다.
    static func isWebPurchaseSurface(_ url: URL) -> Bool {
        isWebPurchasePath(url.path)
    }

    /// 알림처럼 URL이 아니라 서버 내부 경로만 받은 곳에서도 같은 결제 경계를 쓴다.
    static func isWebPurchasePath(_ rawPath: String) -> Bool {
        let path = rawPath.split(separator: "?", maxSplits: 1).first
            .map(String.init)?.lowercased() ?? rawPath.lowercased()
        let roots = [
            "/pricing",
            "/checkout",
            "/payments",
            "/parent/pricing",
            "/parent/checkout",
            "/parent/payments",
            "/app/commerce",
        ]
        return roots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    // MARK: 계정

    static func register(realName: String, name: String, email: String, password: String,
                         birthDate: String, schoolGrade: Int,
                         schoolRegion: String?, schoolCode: String?)
    async throws -> AuthResponse {
        var body: [String: Any] = [
            "realName": realName, "name": name, "email": email, "password": password,
            "birthDate": birthDate, "schoolGrade": schoolGrade, "termsAccepted": true,
        ]
        if schoolGrade != 13, let r = schoolRegion, let c = schoolCode {
            body["schoolRegion"] = r
            body["schoolCode"] = c
        }
        return try await request(
            "POST", "/api/v1/auth/register", body: body, authed: false)
    }

    static func login(email: String, password: String) async throws -> AuthResponse {
        return try await request(
            "POST", "/api/v1/auth/login",
            body: ["email": email, "password": password], authed: false)
    }

    struct SocialAuthProvider: Codable {
        var key: String
        var label: String
        var configured: Bool
    }
    private struct SocialAuthProvidersResponse: Codable {
        var providers: [SocialAuthProvider]
    }

    /// 인증 브라우저를 열기 전에 운영 서버가 Google의 ID·secret·callback을
    /// 모두 갖췄는지 확인한다. 반쪽 설정을 Google 왕복 뒤의 토큰 오류로 보이지 않게 한다.
    static func socialAuthProviders() async throws -> [SocialAuthProvider] {
        let response: SocialAuthProvidersResponse = try await request(
            "GET", "/api/v1/auth/providers", body: nil, authed: false)
        return response.providers
    }

    /// 소셜 왕복이 끝나고 받은 1회용 코드를 토큰으로 바꾼다.
    ///
    /// **provider 를 보내지 않는다.** 서버의 그랜트에 이미 어느 사용자인지 들어
    /// 있어서, 여기서는 code + codeVerifier(PKCE) 만 필요하다. 구글과 카카오가
    /// 같은 주소를 쓰는 이유다. 예전 이름은 exchangeGoogleAuthCode 였고 주소도
    /// `/auth/google/exchange` 였는데, 카카오가 붙으면서 둘 다 거짓말이 됐다.
    /// 서버는 옛 주소도 당분간 살려 둔다 — 이미 TestFlight 에 나간 1.0(1) 이 그걸 쓴다.
    static func exchangeSocialAuthCode(
        _ code: String,
        codeVerifier: String
    ) async throws -> AuthResponse {
        return try await request(
            "POST", "/api/v1/auth/social/exchange",
            body: ["code": code, "codeVerifier": codeVerifier], authed: false)
    }

    /// Sign in with Apple — 네이티브 시트가 받아 온 신원 토큰을 서버에 넘겨 계정으로 바꾼다.
    ///
    /// 서버의 네이티브 Apple 교환 경로다. 앱은 `/auth/providers`가 Apple을
    /// configured로 내려준 경우에만 버튼을 보여 운영 키가 빠진 반쪽 설정을 시작하지 않는다.
    ///
    /// 응답은 **구글과 같은 AuthResponse** 다. 새 타입을 만들지 않는다 — 로그인 이후의
    /// 슬롯 전환·게스트 승계·동기화가 전부 그 타입 하나에 매달려 있다.
    ///
    /// fullName·email 은 애플이 **최초 승인 1회만** 준다. 두 번째 로그인부터는 nil 이라
    /// 서버가 그때 저장하지 않으면 영영 못 받는다. 앱이 캐시해 뒀다가 나중에 보내는
    /// 방식은 쓰지 않는다 — 기기를 바꾸면 사라지고 그 사실을 아무도 모른다.
    static func exchangeAppleIdentity(
        identityToken: String,
        authorizationCode: String?,
        nonce: String,
        fullName: String?,
        email: String?
    ) async throws -> AuthResponse {
        var body: [String: Any] = [
            "identityToken": identityToken,
            "nonce": nonce,
        ]
        if let authorizationCode { body["authorizationCode"] = authorizationCode }
        if let fullName { body["fullName"] = fullName }
        if let email { body["email"] = email }
        return try await request(
            "POST", "/api/v1/auth/apple/exchange", body: body, authed: false)
    }

    /// 네트워크 응답은 도착 즉시 세션이 되지 않는다. 화면이 소유한 최신 인증 시도만
    /// 키체인 토큰으로 승격해, 늦은 이메일/Google 응답이 새 로그인을 덮지 못하게 한다.
    static func beginAuthenticationAttempt() -> UUID {
        TokenBox.beginAuthenticationAttempt()
    }

    @discardableResult
    static func acceptAuthentication(_ auth: AuthResponse, attemptID: UUID) throws -> Bool {
        try TokenBox.save(auth.accessToken, for: attemptID)
    }

    static func cancelAuthenticationAttempt(_ id: UUID?) {
        guard let id else { return }
        TokenBox.cancelAuthenticationAttempt(id)
    }

    /// 비동기 요청을 시작한 계정의 Bearer 자격을 고정한다. 요청 본문이 실제로
    /// URLRequest를 만드는 시점에 전역 Keychain을 다시 읽으면, 그 사이 로그인한
    /// 다음 사람의 토큰으로 앞 계정 작업을 보낼 수 있다. 값은 비교·헤더 구성에만
    /// 쓰며 로그나 저장소에는 남기지 않는다.
    struct AuthorizationSnapshot: Sendable {
        fileprivate let token: String?
    }

    static func captureAuthorization() -> AuthorizationSnapshot? {
        #if DEBUG
        if DemoMode.isOn { return AuthorizationSnapshot(token: nil) }
        #endif
        guard let token = TokenBox.load(), !token.isEmpty else { return nil }
        return AuthorizationSnapshot(token: token)
    }

    static func me() async throws -> ServerUser {
        let res: MeResponse = try await request("GET", "/api/v1/me", body: nil, authed: true)
        return res.user
    }

    static func updateNickname(_ nickname: String) async throws -> ServerUser {
        let response: MeResponse = try await request(
            "PATCH", "/api/v1/me/nickname",
            body: ["nickname": nickname], authed: true)
        return response.user
    }

    private struct ProfileAvatarResponse: Codable { var profileAvatar: ServerProfileAvatar }
    private struct DashboardTutorialResponse: Codable { var tutorial: ServerTutorialStatus }
    private struct ArenaTutorialResponse: Codable { var tutorial: ServerArenaTutorialStatus }

    static func updateProfileAvatarPreset(_ avatarCode: String) async throws -> ServerProfileAvatar {
        let response: ProfileAvatarResponse = try await request(
            "PATCH", "/api/v1/me/avatar/preset",
            body: ["avatarCode": avatarCode], authed: true)
        return response.profileAvatar
    }

    static func updateProfileAvatarCustom(jpegData: Data) async throws -> ServerProfileAvatar {
        guard !jpegData.isEmpty, jpegData.count <= 5 * 1024 * 1024 else {
            throw ServerAPIError(
                message: "프로필 사진은 5MB 이하로 선택해 주세요.",
                code: "PROFILE_AVATAR_TOO_LARGE")
        }
        let boundary = "Matths-Profile-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST",
            "/api/v1/me/avatar/custom",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 90)
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"profileImage\"; filename=\"profile.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpegData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(ProfileAvatarResponse.self, from: data).profileAvatar
    }

    static func updateCoachMode(_ mode: String) async throws {
        struct CoachResponse: Codable {
            struct Coach: Codable { var mode: String }
            var coach: Coach
        }
        let _: CoachResponse = try await request(
            "PATCH", "/api/v1/me/coach-mode",
            body: ["mode": mode], authed: true)
    }

    static func updateDashboardTutorial(_ action: String) async throws -> ServerTutorialStatus {
        let response: DashboardTutorialResponse = try await request(
            "PATCH", "/api/v1/me/tutorials/dashboard",
            body: ["action": action], authed: true)
        return response.tutorial
    }

    static func updateArenaTutorial(
        chapter: String,
        action: String
    ) async throws -> ServerArenaTutorialStatus {
        let response: ArenaTutorialResponse = try await request(
            "PATCH", "/api/v1/me/tutorials/arena",
            body: ["chapter": chapter, "action": action], authed: true)
        return response.tutorial
    }

    static func logout() { TokenBox.clear() }
    static var hasToken: Bool {
        #if DEBUG
        // 데모 모드는 키체인에 가짜 토큰을 심지 않는다(감독의 실제 로그인 토큰 보호).
        // 대신 서버 화면들의 진입 게이트(hasToken)만 통과시킨다 — 요청 자체는
        // request(_:_:body:authed:) 앞단에서 픽스처로 가로채므로 네트워크로 나가지 않는다.
        if DemoMode.isOn { return true }
        #endif
        return TokenBox.load() != nil
    }

    /// 29일 패키지가 지정하는 실제 경쟁 풀. 문자열을 화면 곳곳에서 직접 비교하지 않는다.
    enum RankingPool: String, Codable, Equatable {
        case sub = "SUB"
        case main = "MAIN"
    }

    // MARK: 학교 목록 (IPAD_API.md — 가입 폼은 서버 목록을 우선 사용)

    struct APISchool: Codable, Identifiable {
        var code: String
        var name: String
        var highSchoolType: String?
        var id: String { code }
    }
    struct SchoolsResponse: Codable { var regions: [String: [APISchool]] }

    static func schools() async throws -> [String: [APISchool]] {
        let res: SchoolsResponse = try await request("GET", "/api/v1/schools", body: nil, authed: false)
        return res.regions
    }

    /// 프로필의 학교 변경은 학교 리그 정본을 바꾸는 서버 작업이다.
    /// 로컬 표시부터 바꾸면 실패·오프라인 때 앱과 웹의 학교가 갈리므로,
    /// 서버가 검증해 돌려준 사용자만 호출부가 로컬 상태에 반영한다.
    static func updateSchool(region: String, code: String) async throws -> ServerUser {
        let res: MeResponse = try await request(
            "PATCH", "/api/v1/me/school",
            body: ["schoolRegion": region, "schoolCode": code],
            authed: true)
        return res.user
    }

    // MARK: 비밀번호 재설정 3단계 (IPAD_API.md)

    struct ResetRequestResponse: Codable {
        var message: String?
        var previewCode: String?      // 메일 키 없는 개발 서버는 코드를 그대로 알려준다
    }
    struct ResetAuthorization: Codable { var resetId: String; var userId: String }
    private struct ResetVerifyResponse: Codable { var resetAuthorization: ResetAuthorization }

    static func passwordResetRequest(email: String) async throws -> ResetRequestResponse {
        try await request("POST", "/api/v1/auth/password-reset/request",
                          body: ["email": email], authed: false)
    }

    static func passwordResetVerify(email: String, code: String) async throws -> ResetAuthorization {
        let res: ResetVerifyResponse = try await request(
            "POST", "/api/v1/auth/password-reset/verify",
            body: ["email": email, "code": code], authed: false)
        return res.resetAuthorization
    }

    static func passwordResetComplete(auth: ResetAuthorization, newPassword: String) async throws {
        struct Done: Codable { var reset: Bool? }
        let _: Done = try await request(
            "POST", "/api/v1/auth/password-reset/complete",
            body: ["resetId": auth.resetId, "userId": auth.userId,
                   "password": newPassword, "passwordConfirm": newPassword], authed: false)
    }

    // MARK: 동기화 (P1) — 진도 게이트·학습 이벤트·오답노트

    private struct Ack: Codable { var accepted: Int?; var duplicates: Int? }
    private struct SyncedList: Codable {
        struct Row: Codable { var clientAttemptId: String?; var attemptId: String?; var duplicate: Bool? }
        var synced: [Row]
    }

    static func patchMastery(courseId: String, unitId: String, conceptId: String,
                             addTypeIds: [String], userCompleted: Bool = false,
                             authorization: AuthorizationSnapshot? = nil) async throws {
        struct Empty: Codable {}
        var body: [String: Any] = ["addCorrectTypeIds": addTypeIds]
        if userCompleted { body["userCompleted"] = true }
        let _: Empty = try await request(
            "PATCH", "/api/v1/learning/\(courseId)/\(unitId)/\(conceptId)/mastery",
            body: body, authed: true, authorization: authorization)
    }

    /// 토픽 체크 상태 — 웹과 같은 공식 진도 엔드포인트를 사용한다.
    ///
    /// `clientEventId` 와 `occurredAt` 은 오프라인 큐 재전송용이다. 응답을 받기 전에
    /// 연결이 끊겨 같은 PATCH 가 다시 가도 서버 행동 로그가 두 번 쌓이지 않는다.
    static func patchTopic(courseId: String, unitId: String, conceptId: String,
                           topicIndex: Int, completed: Bool,
                           clientEventId: String, occurredAt: Date,
                           authorization: AuthorizationSnapshot? = nil) async throws {
        struct Empty: Codable {}
        let _: Empty = try await request(
            "PATCH",
            "/api/v1/learning/\(courseId)/\(unitId)/\(conceptId)/topics/\(topicIndex)",
            body: [
                "completed": completed,
                "clientEventId": clientEventId,
                "occurredAt": ISO8601DateFormatter().string(from: occurredAt),
            ],
            authed: true,
            authorization: authorization)
    }

    /// 게스트→계정 승계용 무이벤트 병합. 과거 토픽 수만큼 오늘의 학습 이벤트를
    /// 만들지 않고, 서버 진도 문서에 성과만 단조롭게 합친다.
    static func patchProgressSnapshot(courseId: String, unitId: String, conceptId: String,
                                      completedTopicIndexes: [Int],
                                      correctTypeIds: [String],
                                      userCompleted: Bool,
                                      lastStudiedAt: String?,
                                      authorization: AuthorizationSnapshot? = nil) async throws {
        struct Empty: Codable {}
        var body: [String: Any] = [
            "completedTopicIndexes": completedTopicIndexes,
            "correctTypeIds": correctTypeIds,
            "userCompleted": userCompleted,
        ]
        if let lastStudiedAt { body["lastStudiedAt"] = lastStudiedAt }
        let _: Empty = try await request(
            "PATCH",
            "/api/v1/learning/\(courseId)/\(unitId)/\(conceptId)/snapshot",
            body: body,
            authed: true,
            authorization: authorization)
    }

    /// 서버가 가진 개념별 진도 — 동기화의 **내려받는 쪽**.
    /// 올리기만 하던 시절엔 기기를 바꾸거나 게스트로 공부하다 가입하면
    /// 서버에 기록이 멀쩡한데도 학습 허브가 0% 로 보였다(2026-07-29 감사 적발).
    struct RemoteConceptProgress: Codable {
        struct Gate: Codable {
            var requiredDistinctTypes: Int?
            var correctTypeIds: [String]?
            var userCompleted: Bool?
        }
        var courseId: String
        var unitId: String
        var conceptId: String
        var completedTopicIndexes: [Int]?
        var completionPercent: Int?
        var masteryGate: Gate?
        var lastStudiedAt: String?
    }
    private struct RemoteLearning: Codable { var progress: [RemoteConceptProgress] }

    static func getLearning(
        authorization: AuthorizationSnapshot? = nil
    ) async throws -> [RemoteConceptProgress] {
        let r: RemoteLearning = try await request(
            "GET", "/api/v1/learning/progress", body: nil, authed: true,
            authorization: authorization)
        return r.progress
    }

    // MARK: 홈 대시보드 — 웹 WEEKLY ACTIVITY와 같은 정본

    /// 웹 홈의 단일 학습 기록 모듈이 사용하는 축약 응답.
    ///
    /// 앱에서 서버 통계를 다시 계산하면 이벤트 반영 시점이나 KST 경계 때문에 웹과
    /// 숫자가 갈릴 수 있다. 서버 계정은 이 값을 그대로 그리고, 게스트·오프라인은
    /// 같은 형태의 로컬 EventLog 스냅샷을 그린다.
    struct DashboardActivityResponse: Codable {
        var dashboard: DashboardActivity
    }

    struct DashboardActivity: Codable {
        struct Stats: Codable {
            var weeklyStudyMinutes: Int
            var weeklyStudyDetail: String
            var todayStudyMinutes: Int
            var activeStudyDays: Int
            var averageStudyMinutes: Int
            var weeklySolvedProblems: Int
            var weeklySolvedDetail: String
            var correctRate: Int
            var correctRateDetail: String
        }

        struct WeeklyActivity: Codable {
            struct Day: Codable {
                var dateKey: String
                var label: String
                var minutes: Int
                var isToday: Bool
            }

            var days: [Day]
            var maxMinutes: Int
        }

        var generatedAt: String
        var stats: Stats
        var weeklyActivity: WeeklyActivity
    }

    static func getDashboardActivity() async throws -> DashboardActivity {
        let response: DashboardActivityResponse = try await request(
            "GET", "/api/v1/dashboard/activity", body: nil, authed: true)
        return response.dashboard
    }

    // MARK: 학생 학원 교실

    struct AcademySummary: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var status: String?
        var profileImageURL: String?
    }

    struct AcademyMembership: Codable, Equatable {
        var id: String
        var status: String
        var joinSource: String?
        var requestedAt: String?
        var approvedAt: String?
    }

    struct AcademyClassSummary: Codable, Identifiable, Equatable {
        struct Schedule: Codable, Equatable {
            var weekdays: [Int]?
            var startTime: String?
            var endTime: String?
            var effectiveFrom: String?
            var timezone: String?
        }
        struct AttendancePolicy: Codable, Equatable {
            var mode: String?
            var opensBeforeMinutes: Int?
            var lateAfterMinutes: Int?
            var closesAfterMinutes: Int?
        }
        struct TeacherHistory: Codable, Identifiable, Equatable {
            var id: String?
            var previousTeacher: TeacherAcademyStaffUser?
            var nextTeacher: TeacherAcademyStaffUser?
            var changedBy: TeacherAcademyStaffUser?
            var changedAt: String?
            var stableID: String {
                id ?? [previousTeacher?.id, nextTeacher?.id, changedAt]
                    .compactMap { $0 }.joined(separator: "|")
            }
        }
        struct LifecycleHistory: Codable, Identifiable, Equatable {
            var id: String?
            var action: String
            var actor: TeacherAcademyStaffUser?
            var actorType: String
            var occurredAt: String?
            var unassignedStudentCount: Int
            var canceledSessionCount: Int
            var revokedInviteCount: Int
            var stableID: String { id ?? "\(action)|\(occurredAt ?? "")" }
        }
        var id: String
        var name: String
        var schedule: Schedule?
        var attendancePolicy: AttendancePolicy?
        var isActive: Bool?
        var studentCount: Int?
        var canManage: Bool?
        var homeroomTeacher: TeacherAcademyStaffUser?
        var coTeachers: [TeacherAcademyStaffUser]?
        var createdBy: TeacherAcademyStaffUser? = nil
        var createdAt: String? = nil
        var archivedBy: TeacherAcademyStaffUser? = nil
        var archivedAt: String? = nil
        var teacherHistory: [TeacherHistory]? = nil
        var lifecycleHistory: [LifecycleHistory]? = nil
    }

    struct AcademyWeek: Codable, Identifiable, Equatable {
        struct Concept: Codable, Identifiable, Equatable {
            var curriculumId: String
            var courseId: String
            var courseTitle: String
            var unitId: String
            var unitTitle: String
            var conceptId: String
            var conceptTitle: String
            var href: String?
            var id: String { "\(courseId)|\(unitId)|\(conceptId)" }
        }
        struct File: Codable, Identifiable, Equatable {
            var id: String
            var originalName: String
            var mimeType: String
            var sizeBytes: Int
        }
        var id: String
        var academicYear: Int
        var weekNumber: Int
        var title: String
        var lessonSummary: String
        var concepts: [Concept]
        var assignmentTitle: String
        var assignmentInstructions: String
        var dueAt: String?
        var files: [File]
    }

    struct AcademyAttendanceDashboard: Codable, Equatable {
        struct Session: Codable, Equatable {
            var id: String
            var dateKey: String
            var startsAt: String
            var endsAt: String
            var checkInOpensAt: String
            var lateAfterAt: String
            var checkInClosesAt: String
            var attendanceMode: String
            var state: String
            var isLateWindow: Bool
            var codeVersion: Int?
        }
        struct Record: Codable, Equatable {
            var status: String
            var checkedInAt: String?
            var source: String?
        }
        var session: Session
        var attendance: Record?
        var canCheckIn: Bool
        var serverNow: String
    }

    struct AcademyDashboard: Codable, Equatable {
        var membership: AcademyMembership?
        var academy: AcademySummary?
        var academyClass: AcademyClassSummary?
        var weeks: [AcademyWeek]
        var attendance: AcademyAttendanceDashboard?
        var academies: [AcademySummary]
    }

    struct AcademyWeekResponse: Codable, Equatable {
        var academy: AcademySummary
        var academyClass: AcademyClassSummary
        var week: AcademyWeek
    }

    struct AcademyPerson: Codable, Identifiable, Equatable {
        struct School: Codable, Equatable {
            var name: String
            var region: String
        }
        var id: String
        var name: String
        var nickname: String?
        var schoolGrade: Int?
        var school: School?
    }

    struct TeacherAcademyMembership: Codable, Identifiable, Equatable {
        var id: String
        var student: AcademyPerson
        var academyClass: AcademyClassSummary?
        var requestedAt: String?
        var approvedAt: String?
    }

    struct TeacherAcademyInvite: Codable, Identifiable, Equatable {
        var id: String
        var label: String
        var code: String
        var academyClass: AcademyClassSummary?
        var displayState: String
        var useCount: Int
        var maxUses: Int
        var expiresAt: String?
        var token: String? = nil
        var status: String? = nil
        var createdBy: TeacherAcademyStaffUser? = nil
        var createdAt: String? = nil
    }

    struct TeacherAcademyStaffUser: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var email: String
        var accountStatus: String? = nil
    }

    struct TeacherAcademyStaff: Codable, Identifiable, Equatable {
        var id: String
        var user: TeacherAcademyStaffUser?
        var role: String
        var status: String
        var requestedAt: String?
        var joinedAt: String?
        var reviewedAt: String? = nil
        var rejectedAt: String? = nil
        var revokedAt: String? = nil
        var reviewedBy: TeacherAcademyStaffUser? = nil
    }

    struct TeacherAcademyDashboard: Codable, Equatable {
        var academy: AcademySummary
        var staffRole: String
        var isOwner: Bool
        var pendingCount: Int
        var studentCount: Int
        var classes: [AcademyClassSummary]
        var archivedClasses: [AcademyClassSummary]?
        var requests: [TeacherAcademyMembership]
        var students: [TeacherAcademyMembership]
        var invites: [TeacherAcademyInvite]
        // Optional for a rolling deploy: an older server can still render the existing teacher desk.
        var staffPendingCount: Int?
        var activeStaff: [TeacherAcademyStaff]?
        var staffRequests: [TeacherAcademyStaff]?
    }

    struct TeacherAcademySetup: Codable, Equatable {
        struct PendingRequest: Codable, Equatable {
            var id: String
            var academy: AcademySummary
            var requestedAt: String?
        }
        var isReady: Bool
        var pendingAcademy: AcademySummary?
        var pendingRequest: PendingRequest?
        var rejectedAcademy: AcademySummary?
        var academies: [AcademySummary]
    }

    struct TeacherAcademyForensics: Codable, Equatable {
        struct Scope: Codable, Equatable {
            var approvedStudents: Int
            var issuedCopies: Int
            var distinctDownloaders: Int
            var firstIssuedAt: String?
        }
        struct Analysis: Codable, Equatable {
            struct Match: Codable, Identifiable, Equatable {
                var displayName: String
                var className: String
                var userRole: String?
                var downloadedAt: String?
                var traceCode: String
                var documentIssueId: String
                var originalName: String?
                var signatureVerified: Bool
                var recognitionMethod: String?
                var ocrConfidence: Double?
                var matchedCandidate: String?
                var id: String { "\(documentIssueId)|\(traceCode)" }
            }
            var inputType: String?
            var traceCodes: [String]
            var matches: [Match]
        }
        var academy: AcademySummary
        var isOwner: Bool
        var classes: [AcademyClassSummary]
        var selectedClass: AcademyClassSummary?
        var scope: Scope
        var analysis: Analysis?
    }

    struct TeacherStudentPage: Codable, Equatable {
        var academy: AcademySummary
        var classes: [AcademyClassSummary]
        var students: [TeacherAcademyMembership]
        var page: Int
        var pageSize: Int
        var total: Int
        var totalPages: Int
    }

    struct TeacherStudentStatistics: Codable, Equatable {
        struct PeriodOption: Codable, Identifiable, Equatable {
            var key: String
            var label: String
            var id: String { key }
        }
        struct Period: Codable, Equatable {
            var key: String
            var label: String
            var isCurrent: Bool
            var options: [PeriodOption]
        }
        struct Card: Codable, Identifiable, Equatable {
            var label: String
            var value: String
            var detail: String
            var id: String { label }
        }
        struct Bullet: Codable, Identifiable, Equatable {
            var label: String
            var text: String
            var id: String { label }
        }
        struct Summary: Codable, Equatable {
            var bullets: [Bullet]
        }
        var period: Period
        var hasActivity: Bool
        var cards: [Card]
        var summary: Summary
    }

    struct TeacherStudentMathMap: Codable, Equatable {
        struct Evidence: Codable, Equatable {
            var attemptCount: Int
            var correctCount: Int
            var retryAttemptedCount: Int
            var retryRecoveredCount: Int
            var averageResponseTimeMs: Double?
            var lastStudiedAt: String?
        }
        struct Concept: Codable, Identifiable, Equatable {
            var id: String
            var title: String
            var courseTitle: String
            var unitTitle: String
            var mastery: Double?
            var status: String
            var statusLabel: String
            var confidenceLabel: String
            var evidence: Evidence
        }
        struct Bottleneck: Codable, Identifiable, Equatable {
            var conceptId: String
            var conceptTitle: String
            var affectedConceptCount: Int
            var id: String { conceptId }
        }
        var graphVersion: String
        var modelVersion: String
        var overallMastery: Double?
        var analyzedConceptCount: Int
        var unknownConceptCount: Int
        var topStrength: Concept?
        var topPriority: Concept?
        var bottlenecks: [Bottleneck]
        var concepts: [Concept]
    }

    struct TeacherStudentDetail: Codable, Equatable {
        var academy: AcademySummary
        var membership: TeacherAcademyMembership
        var statistics: TeacherStudentStatistics
        var mathMap: TeacherStudentMathMap
    }

    struct TeacherStudentBulkResult: Codable, Equatable {
        var action: String
        var count: Int
        var modifiedCount: Int
    }

    struct TeacherAcademyAnalytics: Codable, Equatable {
        struct Scope: Codable, Equatable {
            var type: String
            var academyClass: AcademyClassSummary?
        }
        struct Values: Codable, Equatable {
            var totalStudents: Int
            var activeStudents: Int
            var participationRate: Double?
            var averageLearningDays: Double?
            var averageCompletedConcepts: Double?
            var averageUniqueProblems: Double?
            var firstAttemptAccuracy: Double?
            var wrongAnswerReviewRate: Double?
            var retrySuccessRate: Double?
        }
        struct Health: Codable, Equatable {
            struct Distribution: Codable, Equatable {
                var healthy: Int
                var watch: Int
                var risk: Int
            }
            struct Components: Codable, Equatable {
                var engagement: Double?
                var accuracy: Double?
                var review: Double?
                var recovery: Double?
            }
            var score: Double?
            var key: String
            var label: String
            var dataCoverage: Double
            var targetLearningDays: Int
            var distribution: Distribution
            var components: Components
        }
        struct GrowthPoint: Codable, Identifiable, Equatable {
            var week: Int
            var label: String
            var attempts: Int
            var uniqueProblems: Int
            var activeStudents: Int
            var accuracy: Double?
            var id: Int { week }
        }
        struct AttentionStudent: Codable, Identifiable, Equatable {
            var membership: TeacherAcademyMembership
            var reasons: [String]
            var priority: Int
            var id: String { membership.id }
        }
        struct MathMap: Codable, Equatable {
            struct HeatmapItem: Codable, Identifiable, Equatable {
                var conceptId: String
                var conceptTitle: String
                var courseTitle: String
                var unitTitle: String
                var mastery: Double?
                var analyzedCount: Int
                var totalStudents: Int
                var status: String
                var statusLabel: String
                var id: String { conceptId }
            }
            struct Bottleneck: Codable, Identifiable, Equatable {
                var conceptId: String
                var conceptTitle: String
                var mastery: Double?
                var analyzedCount: Int
                var weakCount: Int
                var affectedConceptCount: Int
                var id: String { conceptId }
            }
            struct Recommendation: Codable, Equatable {
                var conceptId: String
                var conceptTitle: String
                var mastery: Double?
                var reason: String
                var problemCount: Int
            }
            var graphVersion: String
            var modelVersion: String
            var overallMastery: Double?
            var analyzedConceptCount: Int
            var totalStudents: Int
            var heatmap: [HeatmapItem]
            var bottlenecks: [Bottleneck]
            var recommendation: Recommendation?
        }
        var academy: AcademySummary
        var scope: Scope
        var period: TeacherStudentStatistics.Period
        var hasActivity: Bool
        var cards: [TeacherStudentStatistics.Card]
        var values: Values
        var health: Health
        var growth: [GrowthPoint]
        var summary: [TeacherStudentStatistics.Bullet]
        var attentionStudents: [AttentionStudent]
        var mathMap: MathMap
    }

    struct TeacherAcademyClassDraft: Equatable {
        var name: String
        var weekdays: [Int]
        var startTime: String
        var endTime: String
        var effectiveFrom: String
        var attendanceMode: String
        var opensBeforeMinutes: Int
        var lateAfterMinutes: Int
        var closesAfterMinutes: Int
    }

    struct TeacherAttendanceSession: Codable, Equatable {
        var id: String
        var dateKey: String
        var startsAt: String
        var endsAt: String
        var checkInOpensAt: String
        var lateAfterAt: String
        var checkInClosesAt: String
        var attendanceMode: String
        var state: String
        var isLateWindow: Bool
        var codeVersion: Int?
        var code: String?
    }

    struct TeacherAttendanceEntry: Codable, Identifiable, Equatable {
        struct Attendance: Codable, Equatable {
            var status: String
            var checkedInAt: String?
            var source: String?
            var note: String?
        }

        var id: String
        var student: AcademyPerson
        var attendance: Attendance?
    }

    struct TeacherAttendanceCounts: Codable, Equatable {
        var TOTAL: Int
        var PRESENT: Int
        var LATE: Int
        var ABSENT: Int
        var EXCUSED: Int
        var UNRECORDED: Int
    }

    struct TeacherAttendanceRoster: Codable, Equatable {
        var dateKey: String
        var todayKey: String
        var classes: [AcademyClassSummary]
        var selectedClass: AcademyClassSummary?
        var session: TeacherAttendanceSession?
        var roster: [TeacherAttendanceEntry]
        var counts: TeacherAttendanceCounts
        var truncated: Bool
    }

    struct TeacherAttendanceRecord: Equatable {
        var studentUserID: String
        var status: String
        var note: String
    }

    private struct TeacherAttendanceSessionResponse: Codable {
        var session: TeacherAttendanceSession
    }

    struct TeacherClassworkCatalogConcept: Codable, Identifiable, Equatable {
        var key: String
        var curriculumId: String
        var courseId: String
        var courseTitle: String
        var unitId: String
        var unitTitle: String
        var conceptId: String
        var conceptTitle: String
        var id: String { key }
    }

    struct TeacherClassworkCatalogUnit: Codable, Identifiable, Equatable {
        var id: String
        var title: String
        var concepts: [TeacherClassworkCatalogConcept]
    }

    struct TeacherClassworkCatalogCourse: Codable, Identifiable, Equatable {
        var id: String
        var title: String
        var units: [TeacherClassworkCatalogUnit]
    }

    struct TeacherClasswork: Codable, Equatable {
        var academyClass: AcademyClassSummary
        var currentAcademicYear: Int
        var weeks: [AcademyWeek]
        var catalog: [TeacherClassworkCatalogCourse]
    }

    struct TeacherClassWeekDraft: Equatable {
        var weekID: String?
        var academicYear: Int
        var weekNumber: Int
        var title: String
        var lessonSummary: String
        var conceptKeys: [String]
        var assignmentTitle: String
        var assignmentInstructions: String
        var dueAt: String
    }

    struct AdminAcademyApplicant: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var email: String
        var accountStatus: String
    }

    struct AdminAcademyApplication: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var status: String
        var createdAt: String?
        var contractStartsAt: String?
        var contractEndsAt: String?
        var includesMockExam: Bool
        var applicant: AdminAcademyApplicant?
    }

    struct AdminAcademyDashboard: Codable, Equatable {
        var pendingCount: Int
        var activeCount: Int
        var applications: [AdminAcademyApplication]
    }

    struct AdminAcademyCounts: Codable, Equatable {
        var activeStaff: Int
        var pendingStaff: Int
        var approvedStudents: Int
        var pendingStudents: Int
        var activeClasses: Int
        var activeInvites: Int?
    }

    struct AdminAcademyListItem: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var status: String
        var createdAt: String?
        var contractStartsAt: String?
        var contractEndsAt: String?
        var includesMockExam: Bool
        var applicant: AdminAcademyApplicant?
        var profileImageURL: String?
        var planCode: String?
        var counts: AdminAcademyCounts?
    }

    struct AdminAcademyListResponse: Codable, Equatable {
        struct Filters: Codable, Equatable {
            var search: String
            var status: String
        }
        struct Pagination: Codable, Equatable {
            var page: Int
            var pageSize: Int
            var total: Int
            var totalPages: Int
        }
        var academies: [AdminAcademyListItem]
        var filters: Filters
        var pagination: Pagination
        var statusCounts: [String: Int]
    }

    struct AdminAcademyStudent: Codable, Identifiable, Equatable {
        var id: String
        var student: AcademyPerson
        var academyClass: AcademyClassSummary?
        var status: String
        var requestedAt: String?
        var approvedAt: String?
        var joinSource: String? = nil
        var dataConsentAt: String? = nil
        var reviewedAt: String? = nil
        var rejectedAt: String? = nil
        var leftAt: String? = nil
        var reviewedBy: TeacherAcademyStaffUser? = nil
        var inviteID: String? = nil
    }

    struct AdminAcademyAttendanceSession: Codable, Identifiable, Equatable {
        var id: String
        var academyClass: AcademyClassSummary?
        var dateKey: String?
        var startsAt: String?
        var endsAt: String? = nil
        var attendanceMode: String?
        var state: String?
        var code: String?
        var rosterCount: Int? = nil
        var createdBy: TeacherAcademyStaffUser? = nil
    }

    struct AdminAcademyWeek: Codable, Identifiable, Equatable {
        var id: String
        var academicYear: Int
        var weekNumber: Int
        var title: String
        var lessonSummary: String
        var concepts: [AcademyWeek.Concept]
        var assignmentTitle: String
        var assignmentInstructions: String
        var dueAt: String?
        var files: [AcademyWeek.File]
        var academyClass: AcademyClassSummary?
        var status: String
        var createdBy: TeacherAcademyStaffUser?
        var updatedBy: TeacherAcademyStaffUser?
        var createdAt: String?
        var updatedAt: String?
    }

    struct AdminAcademyAttendanceRecord: Codable, Identifiable, Equatable {
        var id: String
        var student: TeacherAcademyStaffUser?
        var academyClass: AcademyClassSummary?
        var sessionStartsAt: String?
        var dateKey: String?
        var status: String
        var source: String?
        var checkedInAt: String?
        var note: String
        var recordedBy: TeacherAcademyStaffUser?
        var updatedAt: String?
    }

    struct AdminAcademyAttendanceAudit: Codable, Identifiable, Equatable {
        var id: String
        var student: TeacherAcademyStaffUser?
        var academyClass: AcademyClassSummary?
        var previousStatus: String?
        var nextStatus: String?
        var action: String?
        var actor: TeacherAcademyStaffUser?
        var actorType: String?
        var note: String
        var occurredAt: String?
    }

    struct AdminAcademyDetail: Codable, Equatable {
        var academy: AdminAcademyListItem
        var counts: AdminAcademyCounts
        var staff: [TeacherAcademyStaff]
        var students: [AdminAcademyStudent]
        var classes: [AcademyClassSummary]
        var classWeeks: [AdminAcademyWeek]? = nil
        var invites: [TeacherAcademyInvite]
        var attendanceSessions: [AdminAcademyAttendanceSession]
        var attendanceRecords: [AdminAcademyAttendanceRecord]?
        var attendanceAudits: [AdminAcademyAttendanceAudit]?
        var analytics: TeacherAcademyAnalytics? = nil
    }

    private struct AcademyCheckInResponse: Codable {
        var attendance: AcademyAttendanceDashboard.Record
    }

    static func academyDashboard() async throws -> AcademyDashboard {
        try await request("GET", "/api/v1/academy/student", body: nil, authed: true)
    }

    static func academyWeek(_ weekID: String) async throws -> AcademyWeekResponse {
        try await request(
            "GET", "/api/v1/academy/student/weeks/\(weekID)", body: nil, authed: true)
    }

    static func requestAcademy(inviteCode: String) async throws -> AcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/student/join-code",
            body: ["code": inviteCode, "consent": true], authed: true)
    }

    static func requestAcademy(academyID: String) async throws -> AcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/student/join",
            body: ["academyId": academyID, "consent": true], authed: true)
    }

    static func leaveAcademy() async throws -> AcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/student/leave", body: [:], authed: true)
    }

    static func checkInAcademyAttendance(sessionID: String, code: String)
    async throws -> AcademyAttendanceDashboard.Record {
        let response: AcademyCheckInResponse = try await request(
            "POST", "/api/v1/academy/student/attendance/check-in",
            body: ["sessionId": sessionID, "code": code], authed: true)
        return response.attendance
    }

    static func teacherAcademyDashboard() async throws -> TeacherAcademyDashboard {
        try await request("GET", "/api/v1/academy/teacher", body: nil, authed: true)
    }

    static func teacherAcademySetup() async throws -> TeacherAcademySetup {
        try await request("GET", "/api/v1/academy/teacher/setup", body: nil, authed: true)
    }

    static func createTeacherAcademy(name: String) async throws -> TeacherAcademySetup {
        try await request(
            "POST", "/api/v1/academy/teacher/setup",
            body: ["academyName": name], authed: true)
    }

    static func requestTeacherAcademyJoin(academyID: String)
    async throws -> TeacherAcademySetup {
        try await request(
            "POST", "/api/v1/academy/teacher/setup/join",
            body: ["academyId": academyID], authed: true)
    }

    static func cancelTeacherAcademyJoin() async throws -> TeacherAcademySetup {
        try await request(
            "POST", "/api/v1/academy/teacher/setup/join/cancel",
            body: [:], authed: true)
    }

    static func updateTeacherAcademyProfileImage(jpegData: Data)
    async throws -> TeacherAcademyDashboard {
        guard !jpegData.isEmpty, jpegData.count <= 5 * 1024 * 1024 else {
            throw ServerAPIError(
                message: "학원 프로필 사진은 5MB 이하로 선택해 주세요.",
                code: "PROFILE_AVATAR_TOO_LARGE")
        }
        let boundary = "Matths-Academy-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST",
            "/api/v1/academy/teacher/profile-image",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 90)
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"profileImage\"; filename=\"academy-profile.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpegData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(TeacherAcademyDashboard.self, from: data)
    }

    static func removeTeacherAcademyProfileImage() async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/profile-image/remove",
            body: [:], authed: true)
    }

    static func teacherAcademyForensics(classID: String?) async throws -> TeacherAcademyForensics {
        var query: [String: String] = [:]
        if let classID, !classID.isEmpty { query["classId"] = classID }
        return try await request(
            "GET", "/api/v1/academy/teacher/forensics",
            body: nil, authed: true, query: query)
    }

    static func analyzeTeacherAcademyForensicsCode(classID: String, traceCode: String)
    async throws -> TeacherAcademyForensics {
        try await request(
            "POST", "/api/v1/academy/teacher/forensics/code",
            body: ["classId": classID, "traceCode": traceCode], authed: true)
    }

    static func analyzeTeacherAcademyForensicsFile(
        classID: String,
        data: Data,
        filename: String,
        mimeType: String
    ) async throws -> TeacherAcademyForensics {
        guard !data.isEmpty, data.count <= 50 * 1024 * 1024 else {
            throw ServerAPIError(
                message: "유출 추적 파일은 50MB 이하로 선택해 주세요.",
                code: "FORENSICS_FILE_TOO_LARGE")
        }
        let boundary = "Matths-Forensics-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST", "/api/v1/academy/teacher/forensics/file",
            contentType: "multipart/form-data; boundary=\(boundary)", timeout: 180)
        var body = Data()
        for (name, value) in [("classId", classID)] {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        let safeFilename = filename.replacingOccurrences(of: "\"", with: "")
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"forensicFile\"; filename=\"\(safeFilename)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(
            response,
            errorBody: responseData,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(TeacherAcademyForensics.self, from: responseData)
    }

    static func teacherAcademyAnalytics(period: String?, classID: String?)
    async throws -> TeacherAcademyAnalytics {
        var query: [String: String] = [:]
        if let period, !period.isEmpty { query["period"] = period }
        if let classID, !classID.isEmpty { query["classId"] = classID }
        return try await request(
            "GET", "/api/v1/academy/teacher/analytics",
            body: nil, authed: true, query: query)
    }

    static func reviewAcademyStudent(membershipID: String, approve: Bool)
    async throws -> TeacherAcademyDashboard {
        let action = approve ? "approve" : "reject"
        return try await request(
            "POST", "/api/v1/academy/teacher/requests/\(membershipID)/\(action)",
            body: [:], authed: true)
    }

    static func assignAcademyStudent(membershipID: String, classID: String?)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/students/\(membershipID)/class",
            body: ["classId": classID ?? ""], authed: true)
    }

    static func removeAcademyStudent(membershipID: String)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/students/\(membershipID)/remove",
            body: [:], authed: true)
    }

    static func teacherAcademyStudents(page: Int) async throws -> TeacherStudentPage {
        try await request(
            "GET", "/api/v1/academy/teacher/students",
            body: nil, authed: true, query: ["page": String(max(1, page))])
    }

    static func teacherAcademyStudentDetail(membershipID: String, period: String?)
    async throws -> TeacherStudentDetail {
        var query: [String: String] = [:]
        if let period, !period.isEmpty { query["period"] = period }
        return try await request(
            "GET", "/api/v1/academy/teacher/students/\(membershipID)",
            body: nil, authed: true, query: query)
    }

    static func bulkManageAcademyStudents(
        membershipIDs: [String], action: String, classID: String?
    ) async throws -> TeacherStudentBulkResult {
        try await request(
            "POST", "/api/v1/academy/teacher/students/bulk",
            body: [
                "membershipIds": membershipIDs,
                "action": action,
                "classId": classID ?? "",
            ], authed: true)
    }

    static func createAcademyInvite(label: String, classID: String?)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/invites",
            body: [
                "label": label,
                "classId": classID ?? "",
                "expiryDays": 14,
                "maxUses": 30,
            ], authed: true)
    }

    static func revokeAcademyInvite(_ inviteID: String) async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/invites/\(inviteID)/revoke",
            body: [:], authed: true)
    }

    static func reviewAcademyStaff(staffID: String, approve: Bool)
    async throws -> TeacherAcademyDashboard {
        let action = approve ? "approve" : "reject"
        return try await request(
            "POST", "/api/v1/academy/teacher/staff/\(staffID)/\(action)",
            body: [:], authed: true)
    }

    static func revokeAcademyStaff(_ staffID: String) async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/staff/\(staffID)/revoke",
            body: [:], authed: true)
    }

    static func createTeacherAcademyClass(_ draft: TeacherAcademyClassDraft)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes",
            body: teacherClassBody(draft), authed: true)
    }

    static func updateTeacherAcademyClass(
        classID: String, draft: TeacherAcademyClassDraft
    ) async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes/\(classID)/settings",
            body: teacherClassBody(draft), authed: true)
    }

    static func archiveTeacherAcademyClass(_ classID: String)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes/\(classID)/archive",
            body: [:], authed: true)
    }

    static func restoreTeacherAcademyClass(_ classID: String)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes/\(classID)/restore",
            body: [:], authed: true)
    }

    static func addTeacherAcademyClassCoTeacher(classID: String, teacherUserID: String)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes/\(classID)/co-teachers",
            body: ["teacherUserId": teacherUserID], authed: true)
    }

    static func removeTeacherAcademyClassCoTeacher(classID: String, teacherUserID: String)
    async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes/\(classID)/co-teachers/\(teacherUserID)/remove",
            body: [:], authed: true)
    }

    static func transferTeacherAcademyClassHomeroom(
        classID: String, teacherUserID: String, keepPreviousAsCoTeacher: Bool
    ) async throws -> TeacherAcademyDashboard {
        try await request(
            "POST", "/api/v1/academy/teacher/classes/\(classID)/homeroom-transfer",
            body: [
                "nextTeacherUserId": teacherUserID,
                "keepPreviousAsCoTeacher": keepPreviousAsCoTeacher,
            ], authed: true)
    }

    private static func teacherClassBody(_ draft: TeacherAcademyClassDraft) -> [String: Any] {
        [
            "name": draft.name,
            "weekdays": draft.weekdays,
            "startTime": draft.startTime,
            "endTime": draft.endTime,
            "effectiveFrom": draft.effectiveFrom,
            "attendanceMode": draft.attendanceMode,
            "opensBeforeMinutes": draft.opensBeforeMinutes,
            "lateAfterMinutes": draft.lateAfterMinutes,
            "closesAfterMinutes": draft.closesAfterMinutes,
        ]
    }

    static func teacherAcademyAttendance(dateKey: String, classID: String?)
    async throws -> TeacherAttendanceRoster {
        var query = ["dateKey": dateKey]
        if let classID, !classID.isEmpty { query["classId"] = classID }
        return try await request(
            "GET", "/api/v1/academy/teacher/attendance",
            body: nil, authed: true, query: query)
    }

    static func saveTeacherAcademyAttendance(
        dateKey: String,
        classID: String?,
        sessionID: String?,
        records: [TeacherAttendanceRecord]
    ) async throws -> TeacherAttendanceRoster {
        try await request(
            "POST", "/api/v1/academy/teacher/attendance",
            body: [
                "dateKey": dateKey,
                "classId": classID ?? "",
                "sessionId": sessionID ?? "",
                "records": records.map {
                    [
                        "studentUserId": $0.studentUserID,
                        "status": $0.status,
                        "note": $0.note,
                    ]
                },
            ], authed: true)
    }

    static func regenerateTeacherAttendanceCode(_ sessionID: String)
    async throws -> TeacherAttendanceSession {
        let response: TeacherAttendanceSessionResponse = try await request(
            "POST",
            "/api/v1/academy/teacher/attendance/sessions/\(sessionID)/regenerate-code",
            body: [:], authed: true)
        return response.session
    }

    static func teacherAcademyClasswork(classID: String) async throws -> TeacherClasswork {
        try await request(
            "GET", "/api/v1/academy/teacher/classes/\(classID)/classwork",
            body: nil, authed: true)
    }

    static func saveTeacherAcademyClassWeek(
        classID: String,
        draft: TeacherClassWeekDraft,
        files: [URL] = []
    ) async throws -> TeacherClasswork {
        if files.isEmpty {
            return try await request(
                "POST", "/api/v1/academy/teacher/classes/\(classID)/classwork/weeks",
                body: [
                    "weekId": draft.weekID ?? "",
                    "academicYear": draft.academicYear,
                    "weekNumber": draft.weekNumber,
                    "title": draft.title,
                    "lessonSummary": draft.lessonSummary,
                    "conceptKeys": draft.conceptKeys,
                    "assignmentTitle": draft.assignmentTitle,
                    "assignmentInstructions": draft.assignmentInstructions,
                    "dueAt": draft.dueAt,
                ], authed: true)
        }
        return try await uploadTeacherAcademyClassWeek(
            classID: classID, draft: draft, files: files)
    }

    static func removeTeacherAcademyClassWeekFile(
        classID: String, weekID: String, fileID: String
    ) async throws -> TeacherClasswork {
        try await request(
            "POST",
            "/api/v1/academy/teacher/classes/\(classID)/classwork/weeks/\(weekID)/files/\(fileID)/remove",
            body: [:], authed: true)
    }

    static func deleteTeacherAcademyClassWeek(
        classID: String, weekID: String
    ) async throws -> TeacherClasswork {
        try await request(
            "POST",
            "/api/v1/academy/teacher/classes/\(classID)/classwork/weeks/\(weekID)/delete",
            body: [:], authed: true)
    }

    static func adminAcademyDashboard() async throws -> AdminAcademyDashboard {
        try await request("GET", "/api/v1/academy/admin", body: nil, authed: true)
    }

    static func adminAcademyList(
        search: String = "", status: String = "ALL", page: Int = 1
    ) async throws -> AdminAcademyListResponse {
        try await request(
            "GET", "/api/v1/academy/admin/list", body: nil, authed: true,
            query: [
                "search": search,
                "status": status,
                "page": String(max(1, page)),
            ])
    }

    static func adminAcademyDetail(
        academyID: String, period: String? = nil
    ) async throws -> AdminAcademyDetail {
        var query: [String: String] = [:]
        if let period, !period.isEmpty { query["period"] = period }
        return try await request(
            "GET", "/api/v1/academy/admin/\(academyID)", body: nil, authed: true,
            query: query)
    }

    static func updateAdminAcademyProfile(
        academyID: String, action: String, name: String? = nil
    ) async throws -> AdminAcademyDetail {
        var body: [String: Any] = ["action": action]
        if let name { body["name"] = name }
        return try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/profile",
            body: body, authed: true)
    }

    static func updateAdminAcademyProfileImage(
        academyID: String, jpegData: Data
    ) async throws -> AdminAcademyDetail {
        guard !jpegData.isEmpty, jpegData.count <= 5 * 1024 * 1024 else {
            throw ServerAPIError(
                message: "학원 프로필 사진은 5MB 이하로 선택해 주세요.",
                code: "PROFILE_AVATAR_TOO_LARGE")
        }
        let boundary = "Matths-Admin-Academy-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST", "/api/v1/academy/admin/\(academyID)/profile-image",
            contentType: "multipart/form-data; boundary=\(boundary)", timeout: 90)
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"action\"\r\n\r\nUPDATE\r\n".utf8))
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"profileImage\"; filename=\"academy-profile.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpegData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(
            response, errorBody: data, requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(AdminAcademyDetail.self, from: data)
    }

    static func removeAdminAcademyProfileImage(
        academyID: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/profile-image",
            body: ["action": "REMOVE"], authed: true)
    }

    static func updateAdminAcademyContract(
        academyID: String, contractEndsAt: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/contract",
            body: ["contractEndsAt": contractEndsAt], authed: true)
    }

    static func updateAdminAcademyStaff(
        academyID: String, staffID: String, action: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/staff/\(staffID)",
            body: ["action": action], authed: true)
    }

    static func transferAdminAcademyOwner(
        academyID: String, newOwnerStaffID: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/owner",
            body: ["newOwnerStaffId": newOwnerStaffID], authed: true)
    }

    static func updateAdminAcademyStudent(
        academyID: String, membershipID: String, action: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/students/\(membershipID)",
            body: ["action": action], authed: true)
    }

    static func assignAdminAcademyStudentClass(
        academyID: String, membershipID: String, classID: String?
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/students/\(membershipID)/class",
            body: ["classId": classID ?? ""], authed: true)
    }

    static func updateAdminAcademyClass(
        academyID: String, classID: String, action: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/classes/\(classID)",
            body: ["action": action], authed: true)
    }

    static func updateAdminAcademyClassOperations(
        academyID: String, classID: String, weekdays: [Int],
        startTime: String, endTime: String, effectiveFrom: String,
        attendanceMode: String, opensBeforeMinutes: Int,
        lateAfterMinutes: Int, closesAfterMinutes: Int
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/classes/\(classID)/operations",
            body: [
                "weekdays": weekdays,
                "startTime": startTime,
                "endTime": endTime,
                "effectiveFrom": effectiveFrom,
                "attendanceMode": attendanceMode,
                "opensBeforeMinutes": opensBeforeMinutes,
                "lateAfterMinutes": lateAfterMinutes,
                "closesAfterMinutes": closesAfterMinutes,
            ], authed: true)
    }

    static func transferAdminAcademyClassHomeroom(
        academyID: String, classID: String, nextTeacherUserID: String,
        retainPreviousAsCoTeacher: Bool
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/classes/\(classID)/homeroom",
            body: [
                "nextTeacherUserId": nextTeacherUserID,
                "retainPreviousAsCoTeacher": retainPreviousAsCoTeacher,
            ], authed: true)
    }

    static func updateAdminAcademyInvite(
        academyID: String, inviteID: String, action: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/invites/\(inviteID)",
            body: ["action": action], authed: true)
    }

    static func regenerateAdminAcademyAttendanceCode(
        academyID: String, sessionID: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST",
            "/api/v1/academy/admin/\(academyID)/attendance/sessions/\(sessionID)/regenerate-code",
            body: [:], authed: true)
    }

    static func updateAdminAcademyAttendance(
        academyID: String, attendanceID: String, status: String, note: String
    ) async throws -> AdminAcademyDetail {
        try await request(
            "POST", "/api/v1/academy/admin/\(academyID)/attendance/\(attendanceID)",
            body: ["status": status, "note": note], authed: true)
    }

    static func reviewAcademyApplication(academyID: String, approve: Bool)
    async throws -> AdminAcademyDashboard {
        let action = approve ? "approve" : "reject"
        return try await request(
            "POST", "/api/v1/academy/admin/applications/\(academyID)/\(action)",
            body: [:], authed: true)
    }

    struct CoachSuggestion: Codable, Identifiable, Equatable {
        var id: String
        var authorName: String
        var mode: String
        var situation: String
        var message: String
        var status: String
        var rejectionReason: String
        var createdAt: String?
        var moderatedAt: String?
    }

    struct CoachSuggestionBoard: Codable, Equatable {
        var isAdmin: Bool
        var approved: [CoachSuggestion]
        var mine: [CoachSuggestion]
        var pending: [CoachSuggestion]
    }

    private struct CoachSuggestionBoardResponse: Codable {
        var board: CoachSuggestionBoard
    }

    private struct CoachSuggestionMutationResponse: Codable {
        var suggestion: CoachSuggestion
    }

    static func coachSuggestionBoard() async throws -> CoachSuggestionBoard {
        let response: CoachSuggestionBoardResponse = try await request(
            "GET", "/api/v1/coach-suggestions", body: nil, authed: true)
        return response.board
    }

    static func createCoachSuggestion(mode: String, situation: String, message: String)
    async throws -> CoachSuggestion {
        let response: CoachSuggestionMutationResponse = try await request(
            "POST", "/api/v1/coach-suggestions",
            body: [
                "mode": mode,
                "situation": situation,
                "message": message,
                "requestId": UUID().uuidString,
            ], authed: true)
        return response.suggestion
    }

    static func moderateCoachSuggestion(
        suggestionID: String,
        approve: Bool,
        rejectionReason: String = ""
    ) async throws -> CoachSuggestion {
        let response: CoachSuggestionMutationResponse = try await request(
            "PATCH", "/api/v1/coach-suggestions/\(suggestionID)",
            body: [
                "action": approve ? "approve" : "reject",
                "rejectionReason": rejectionReason,
            ], authed: true)
        return response.suggestion
    }

    struct SupportContact: Codable, Equatable {
        var nickname: String
        var realName: String
        var email: String
    }

    struct SupportInquiry: Codable, Identifiable, Equatable {
        var id: String
        var subject: String
        var status: String
        var notificationStatus: String
        var createdAt: String?
        var repliedAt: String?
    }

    struct SupportSubmission: Codable, Equatable {
        var emailStatus: String
        var emailDelivered: Bool
    }

    struct SupportDashboard: Codable, Equatable {
        var contact: SupportContact
        var inquiries: [SupportInquiry]
        var submission: SupportSubmission?
    }

    static func supportDashboard() async throws -> SupportDashboard {
        try await request("GET", "/api/v1/support/inquiries", body: nil, authed: true)
    }

    static func createSupportInquiry(subject: String, content: String)
    async throws -> SupportDashboard {
        try await request(
            "POST", "/api/v1/support/inquiries",
            body: [
                "requestId": UUID().uuidString,
                "subject": subject,
                "content": content,
            ], authed: true)
    }

    struct ArchiveFolder: Codable, Identifiable, Equatable {
        var id: String
        var parentFolderId: String?
        var name: String
        var description: String
        var isPinned: Bool
        var itemCount: Int
        var isLocked: Bool
        var requiredAccessLevel: String
    }

    struct ArchiveBreadcrumb: Codable, Identifiable, Equatable {
        var id: String
        var name: String
    }

    struct ArchiveItem: Codable, Identifiable, Equatable {
        var id: String
        var folderId: String?
        var title: String
        var description: String
        var category: String
        var originalName: String
        var mimeType: String
        var sizeBytes: Int
        var downloadCount: Int
        var createdAt: String?
    }

    struct ArchiveDashboard: Codable, Equatable {
        var isAdmin: Bool
        var folders: [ArchiveFolder]
        var selectedFolder: ArchiveFolder?
        var breadcrumbs: [ArchiveBreadcrumb]
        var items: [ArchiveItem]
    }

    private struct ArchiveDashboardEnvelope: Codable {
        var archive: ArchiveDashboard
    }

    static func archiveDashboard(folderID: String? = nil) async throws -> ArchiveDashboard {
        let query = folderID.map { ["folderId": $0] } ?? [:]
        let response: ArchiveDashboardEnvelope = try await request(
            "GET", "/api/v1/archive", body: nil, authed: true, query: query)
        return response.archive
    }

    /// 자료함 파일은 서버가 폴더 이용권을 다시 검사한다. PDF는 개인 워터마크가
    /// 적용된 응답을 받고, 그 외 파일은 서버의 짧은 서명 URL 리디렉션을 따라간다.
    static func downloadArchiveItem(_ item: ArchiveItem) async throws -> URL {
        let request = try authorizedRequest(
            "GET", "/api/v1/archive/items/\(item.id)/download", timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        let http = try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))

        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ArchiveDownloads", isDirectory: true)
            .appendingPathComponent(DataScope.slot, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var resource = URLResourceValues()
        resource.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(resource)

        let suggested = (http.suggestedFilename ?? item.originalName)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let safeName = suggested.isEmpty ? "Matths-자료" : suggested
        let destination = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(safeName)", isDirectory: false)
        try manager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    /// 학원 과제 파일은 Bearer 소유권 검사 후 내려받는다. PDF라면 서버가 개인
    /// 워터마크를 넣어 응답하고, 다른 파일은 짧은 서명 URL로 리디렉션한다.
    static func downloadAcademyFile(weekID: String, file: AcademyWeek.File) async throws -> URL {
        let request = try authorizedRequest(
            "GET", "/api/v1/academy/student/weeks/\(weekID)/files/\(file.id)", timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        let http = try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))

        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AcademyAssignments", isDirectory: true)
            .appendingPathComponent(DataScope.slot, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var resource = URLResourceValues()
        resource.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(resource)

        let suggested = (http.suggestedFilename ?? file.originalName)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let safeName = suggested.isEmpty ? "학원-과제" : suggested
        let destination = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(safeName)", isDirectory: false)
        try manager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func downloadTeacherAcademyFile(
        classID: String,
        weekID: String,
        file: AcademyWeek.File
    ) async throws -> URL {
        let request = try authorizedRequest(
            "GET",
            "/api/v1/academy/teacher/classes/\(classID)/classwork/weeks/\(weekID)/files/\(file.id)",
            timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        let http = try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))

        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TeacherAcademyAssignments", isDirectory: true)
            .appendingPathComponent(DataScope.slot, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var resource = URLResourceValues()
        resource.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(resource)
        let safeName = (http.suggestedFilename ?? file.originalName)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(safeName.isEmpty ? "학원-과제" : safeName)")
        try manager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    static func downloadAdminAcademyFile(
        academyID: String,
        weekID: String,
        file: AcademyWeek.File
    ) async throws -> URL {
        let request = try authorizedRequest(
            "GET",
            "/api/v1/academy/admin/\(academyID)/weeks/\(weekID)/files/\(file.id)",
            timeout: 120)
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        let errorBody = (try? Data(contentsOf: temporaryURL)) ?? Data()
        let http = try validateAuthorizedResponse(
            response,
            errorBody: errorBody,
            requestToken: bearerToken(from: request))
        let manager = FileManager.default
        let directory = manager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AdminAcademyAssignments", isDirectory: true)
            .appendingPathComponent(DataScope.slot, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var resource = URLResourceValues()
        resource.isExcludedFromBackup = true
        var mutableDirectory = directory
        try? mutableDirectory.setResourceValues(resource)
        let safeName = (http.suggestedFilename ?? file.originalName)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = directory.appendingPathComponent(
            "\(UUID().uuidString)-\(safeName.isEmpty ? "학원-과제" : safeName)")
        try manager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private static func uploadTeacherAcademyClassWeek(
        classID: String,
        draft: TeacherClassWeekDraft,
        files: [URL]
    ) async throws -> TeacherClasswork {
        guard files.count <= 10 else {
            throw ServerAPIError(
                message: "한 주차에는 과제 파일을 최대 10개까지 올릴 수 있습니다.",
                code: "ACADEMY_ASSIGNMENT_FILE_COUNT")
        }
        let boundary = "Matths-Academy-\(UUID().uuidString)"
        let request = try authorizedRequest(
            "POST",
            "/api/v1/academy/teacher/classes/\(classID)/classwork/weeks",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 240)
        let multipart = FileManager.default.temporaryDirectory
            .appendingPathComponent("academy-classwork-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: multipart.path, contents: nil)
        let output = try FileHandle(forWritingTo: multipart)
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: multipart)
        }
        func write(_ text: String) throws {
            try output.write(contentsOf: Data(text.utf8))
        }
        func writeField(_ name: String, _ value: String) throws {
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            try write(value + "\r\n")
        }
        try writeField("weekId", draft.weekID ?? "")
        try writeField("academicYear", String(draft.academicYear))
        try writeField("weekNumber", String(draft.weekNumber))
        try writeField("title", draft.title)
        try writeField("lessonSummary", draft.lessonSummary)
        for key in draft.conceptKeys { try writeField("conceptKeys", key) }
        try writeField("assignmentTitle", draft.assignmentTitle)
        try writeField("assignmentInstructions", draft.assignmentInstructions)
        try writeField("dueAt", draft.dueAt)

        let allowedExtensions: Set<String> = [
            "pdf", "doc", "docx", "hwp", "hwpx", "xls", "xlsx", "ppt", "pptx",
            "zip", "png", "jpg", "jpeg", "webp",
        ]
        var totalSize = 0
        for file in files {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            guard let size = values.fileSize, size > 0, size <= 30 * 1024 * 1024 else {
                throw ServerAPIError(
                    message: "과제 파일은 각각 30MB 이하여야 합니다.",
                    code: "ACADEMY_ASSIGNMENT_TOO_LARGE")
            }
            totalSize += size
            guard totalSize <= 100 * 1024 * 1024 else {
                throw ServerAPIError(
                    message: "과제 파일 합계는 100MB 이하여야 합니다.",
                    code: "ACADEMY_ASSIGNMENT_TOTAL_SIZE")
            }
            let fileExtension = file.pathExtension.lowercased()
            guard allowedExtensions.contains(fileExtension) else {
                throw ServerAPIError(
                    message: "PDF, 문서, 스프레드시트, 프레젠테이션, ZIP 또는 이미지만 올릴 수 있습니다.",
                    code: "ACADEMY_ASSIGNMENT_TYPE")
            }
            let safeName = file.lastPathComponent
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
            let mime = values.contentType?.preferredMIMEType ?? "application/octet-stream"
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"assignmentFiles\"; filename=\"\(safeName)\"\r\n")
            try write("Content-Type: \(mime)\r\n\r\n")
            let input = try FileHandle(forReadingFrom: file)
            defer { try? input.close() }
            while let chunk = try input.read(upToCount: 256 * 1024), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            try input.close()
            try write("\r\n")
        }
        try write("--\(boundary)--\r\n")
        try output.synchronize()
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: multipart)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(TeacherClasswork.self, from: data)
    }

    // MARK: 랭킹전(War of Masters) — 웹과 **같은 숫자**를 받아온다
    //
    // 계산은 앱에도, 이 앱을 위한 별도 서비스에도 없다. 웹의 주간 처리
    // (`services/mmrService.js` 의 processWeeklyMmr)가 `RankingProfile` 에 써 둔 값을
    // 서버가 그대로 읽어 내려주고, 앱은 그것을 그리기만 한다.
    //
    // 한때 앱 전용 `arenaService` 가 자체 레이팅을 계산했다. 초기 MMR·강등·결석
    // 감점·provisional 이 없었고 티어 경계도 달라서(실버 1000 vs 800), 같은 학생에게
    // 웹과 앱이 **다른 티어**를 말했다. 그래서 산식을 통째로 버렸다.
    // 명세 9.3: "신규 기능은 레거시 rating 기준과 혼합하면 안 된다."

    /// 사다리 한 칸. `maxMmr` 은 최상위 티어에서 nil 이다(서버가 Infinity 대신 null 로 보낸다).
    struct ArenaTier: Codable, Identifiable {
        var name: String            // BRONZE · SILVER · … · CHALLENGER
        var label: String           // 브론즈 · 실버 · … · 챌린저
        var minMmr: Int
        var maxMmr: Int?
        var maxTopPercentile: Double?
        var id: String { name }
    }

    /// 내 랭킹 상태. 배치고사 전에는 `locked == true` 이고 `mmr` 은 nil 이다(0 이 아니다).
    struct Arena: Codable {
        var locked: Bool
        var mmr: Int?
        /// 티어 코드(BRONZE…). 잠금 상태에서는 nil
        var tier: String?
        var tierLabel: String?
        /// 티어 안에서의 상대 위치 0~99
        var rankPoint: Int
        /// 1~4. 숫자가 작을수록 위(웹 표기와 같다)
        var division: Int?
        /// PROVISIONAL: 주간 공식 시험 2회 전 — 아직 확정 전이라는 뜻
        var status: String
        var weeklyExamsUntilConfirmed: Int?
        var overallRank: Int?
        var percentile: Double?
        var recentPerformances: [Double]

        var isProvisional: Bool { status == "PROVISIONAL" }
        /// "에메랄드 II" 처럼 사람이 읽는 한 줄
        var display: String {
            guard let label = tierLabel else { return "미등재" }
            guard let d = division else { return label }
            return "\(label) \(["", "I", "II", "III", "IV"][min(max(d, 1), 4)])"
        }
    }

    struct ArenaIdentity: Codable {
        var displayName: String
        var schoolName: String
        var displayMode: String
    }
    struct ArenaResponse: Codable {
        var arena: Arena
        var ladder: [ArenaTier]
        var identity: ArenaIdentity
    }

    struct ArenaRow: Codable, Identifiable {
        var userId: String
        var name: String
        var profileAvatar: ServerProfileAvatar? = nil
        var arenaActivityLevel: ServerArenaActivityLevel? = nil
        var rank: Int
        var mmr: Int
        var tier: String?
        var tierLabel: String?
        var rankPoint: Int
        var division: Int?
        var status: String
        var isMe: Bool?
        var id: String { userId }
    }
    struct ArenaBoard: Codable {
        var total: Int
        var top: [ArenaRow]
        var me: ArenaRow?
    }

    /// SUB/MAIN 응답은 요청한 풀 이름을 반드시 되돌려준다.
    /// 이를 버리면 계정 전환 중 늦게 도착한 SUB 응답이 MAIN 화면에 붙을 수 있다.
    struct AccessLeaderboard: Codable {
        var ranking: RankingPool
        var total: Int
        var top: [ArenaRow]
        var me: ArenaRow?

        var board: ArenaBoard {
            ArenaBoard(total: total, top: top, me: me)
        }
    }

    /// 랭킹 순위표. 참가자가 없으면 `total == 0` 으로 온다 — **비었으면 빈 대로 보여 준다.**
    static func getArenaLeaderboard() async throws -> ArenaBoard {
        try await request("GET", "/api/v1/arena/leaderboard", body: nil, authed: true)
    }

    // MARK: 회원 탈퇴 (명세 2.12 · DELETE /api/v1/me)
    //
    // **익명 보존 탈퇴다.** 계정을 물리적으로 지우는 것이 아니라 PII 를 무효값으로
    // 치환하고 학습 데이터는 익명으로 남긴다. 랭킹 프로필은 datasetOnly 로 바뀌어
    // 순위에서 빠지고, 토큰 버전이 올라가 기존 토큰이 전부 무효가 된다.
    //
    // 서버가 요구하는 세 가지를 그대로 보낸다 — 하나라도 빠지면 400 이다:
    //   password / confirmation("탈퇴") / acknowledgeAnonymousRetention(true)
    struct WithdrawResult: Codable {
        var withdrawn: Bool
        var dataRetention: String     // "anonymous"
        var message: String
    }

    /// 확인 문구는 서버가 **정확히 "탈퇴"** 를 요구한다. 앱이 임의로 바꾸지 않는다.
    static let withdrawConfirmationPhrase = "탈퇴"

    struct WithdrawalOptions: Codable {
        struct GoogleReauthentication: Codable {
            var linked: Bool
            var available: Bool
        }
        struct AppleReauthentication: Codable {
            var linked: Bool
            var available: Bool
        }
        struct KakaoReauthentication: Codable {
            var linked: Bool
            var available: Bool
        }
        var passwordAccepted: Bool
        var googleReauthentication: GoogleReauthentication
        var kakaoReauthentication: KakaoReauthentication
        var appleReauthentication: AppleReauthentication
    }

    struct GoogleWithdrawalStart: Codable {
        var authorizationUrl: String
        var expiresAt: String
    }

    struct GoogleWithdrawalReauthentication {
        var proof: String
        var codeVerifier: String
    }

    struct AppleWithdrawalReauthentication {
        var identityToken: String
        var nonce: String
    }

    struct KakaoWithdrawalReauthentication {
        var proof: String
        var codeVerifier: String
    }

    static func withdrawalOptions() async throws -> WithdrawalOptions {
        try await request(
            "GET", "/api/v1/me/withdrawal/options", body: nil, authed: true)
    }

    static func startGoogleWithdrawalReauthentication(
        codeChallenge: String
    ) async throws -> GoogleWithdrawalStart {
        try await request(
            "POST", "/api/v1/me/withdrawal/google/start",
            body: ["codeChallenge": codeChallenge], authed: true)
    }

    static func startKakaoWithdrawalReauthentication(
        codeChallenge: String
    ) async throws -> GoogleWithdrawalStart {
        try await request(
            "POST", "/api/v1/me/withdrawal/kakao/start",
            body: ["codeChallenge": codeChallenge], authed: true)
    }

    static func withdrawMe(password: String,
                           acknowledgeAnonymousRetention: Bool) async throws -> WithdrawResult {
        try await request("DELETE", "/api/v1/me", body: [
            "password": password,
            "confirmation": withdrawConfirmationPhrase,
            "acknowledgeAnonymousRetention": acknowledgeAnonymousRetention,
        ], authed: true)
    }

    static func withdrawMe(
        reauthentication: GoogleWithdrawalReauthentication,
        acknowledgeAnonymousRetention: Bool
    ) async throws -> WithdrawResult {
        try await request("DELETE", "/api/v1/me", body: [
            "reauthenticationProof": reauthentication.proof,
            "codeVerifier": reauthentication.codeVerifier,
            "reauthenticationProvider": "google",
            "confirmation": withdrawConfirmationPhrase,
            "acknowledgeAnonymousRetention": acknowledgeAnonymousRetention,
        ], authed: true)
    }

    static func withdrawMe(
        reauthentication: AppleWithdrawalReauthentication,
        acknowledgeAnonymousRetention: Bool
    ) async throws -> WithdrawResult {
        try await request("DELETE", "/api/v1/me", body: [
            "appleIdentityToken": reauthentication.identityToken,
            "appleNonce": reauthentication.nonce,
            "confirmation": withdrawConfirmationPhrase,
            "acknowledgeAnonymousRetention": acknowledgeAnonymousRetention,
        ], authed: true)
    }

    static func withdrawMe(
        reauthentication: KakaoWithdrawalReauthentication,
        acknowledgeAnonymousRetention: Bool
    ) async throws -> WithdrawResult {
        try await request("DELETE", "/api/v1/me", body: [
            "reauthenticationProof": reauthentication.proof,
            "codeVerifier": reauthentication.codeVerifier,
            "reauthenticationProvider": "kakao",
            "confirmation": withdrawConfirmationPhrase,
            "acknowledgeAnonymousRetention": acknowledgeAnonymousRetention,
        ], authed: true)
    }

    static func getArena() async throws -> ArenaResponse {
        try await request("GET", "/api/v1/arena", body: nil, authed: true)
    }

    // MARK: 입단·시즌 배치고사 — 웹 placementExamService의 Bearer API

    struct PlacementPresentation: Codable, Identifiable, Equatable {
        var id: String
        var kind: String
        var tierCode: String
        var tierLabel: String
    }

    struct PlacementResult: Codable, Equatable {
        var attemptId: String
        var status: String
        var totalCorrect: Int
        var placementScore: Double
        var initialMmr: Int?
        var tierCode: String
        var tierLabel: String
        var rankPoint: Int?
        var rankingStatus: String
        var percentile: Double?
        var verificationRequired: Bool
        var presentationId: String?
    }

    struct PlacementQuestion: Codable, Identifiable, Equatable {
        struct Choice: Codable, Identifiable, Equatable {
            var key: String
            var text: String
            var id: String { key }
        }

        var id: String
        var number: Int
        var prompt: String
        var inputMode: String
        var choices: [Choice]
        var points: Double
        var submittedAnswer: String
        var responseTimeMs: Int
        var visitCount: Int
    }

    struct PlacementAttempt: Codable, Identifiable, Equatable {
        var id: String
        var phase: String
        var status: String
        var purpose: String
        var title: String
        var subtitle: String
        var timeLimitMs: Int
        var startedAt: String?
        var deadlineAt: String?
        var submittedAt: String?
        var elapsedTimeMs: Int
        var currentQuestionIndex: Int
        var answeredCount: Int
        var questionCount: Int
        var questions: [PlacementQuestion]
        var result: PlacementResult?
        var presentation: PlacementPresentation?
    }

    struct PlacementStatus: Codable, Equatable {
        var status: String
        var attemptId: String?
        var answeredCount: Int
        var ctaLabel: String
        var result: PlacementResult?
        var presentation: PlacementPresentation?
    }

    struct PlacementStatusResponse: Codable { var placement: PlacementStatus }
    struct PlacementAttemptResponse: Codable { var attempt: PlacementAttempt }
    struct PlacementDraftResponse: Codable {
        struct Draft: Codable {
            var savedAt: String?
            var elapsedTimeMs: Int
            var answeredCount: Int
            var currentQuestionIndex: Int
            var status: String?
            var expired: Bool?
        }
        var draft: Draft
    }
    struct PlacementSubmissionResponse: Codable {
        var attempt: PlacementAttempt
        var result: PlacementResult?
        var presentation: PlacementPresentation?
    }

    static func getPlacementStatus() async throws -> PlacementStatus {
        let response: PlacementStatusResponse = try await request(
            "GET", "/api/v1/placement-exam/status", body: nil, authed: true)
        return response.placement
    }

    static func startPlacementExam() async throws -> PlacementAttempt {
        let response: PlacementAttemptResponse = try await request(
            "POST", "/api/v1/placement-exam/start", body: nil, authed: true)
        return response.attempt
    }

    static func getPlacementAttempt(_ attemptId: String) async throws -> PlacementAttempt {
        let response: PlacementAttemptResponse = try await request(
            "GET", "/api/v1/placement-exam/\(attemptId)", body: nil, authed: true)
        return response.attempt
    }

    static func savePlacementDraft(
        attemptId: String,
        answers: [String: String],
        activeQuestionId: String,
        currentQuestionIndex: Int,
        closeQuestionTiming: Bool = false
    ) async throws -> PlacementDraftResponse.Draft {
        let response: PlacementDraftResponse = try await request(
            "PATCH", "/api/v1/placement-exam/\(attemptId)/draft",
            body: [
                "answers": answers,
                "activeQuestionId": activeQuestionId,
                "currentQuestionIndex": currentQuestionIndex,
                "closeQuestionTiming": closeQuestionTiming,
            ], authed: true)
        return response.draft
    }

    static func expirePlacementExam(
        attemptId: String,
        answers: [String: String],
        activeQuestionId: String,
        currentQuestionIndex: Int
    ) async throws -> PlacementSubmissionResponse {
        try await mutatePlacementAttempt(
            action: "expire", attemptId: attemptId, answers: answers,
            activeQuestionId: activeQuestionId, currentQuestionIndex: currentQuestionIndex)
    }

    static func submitPlacementExam(
        attemptId: String,
        answers: [String: String],
        activeQuestionId: String,
        currentQuestionIndex: Int
    ) async throws -> PlacementSubmissionResponse {
        try await mutatePlacementAttempt(
            action: "submit", attemptId: attemptId, answers: answers,
            activeQuestionId: activeQuestionId, currentQuestionIndex: currentQuestionIndex)
    }

    private static func mutatePlacementAttempt(
        action: String,
        attemptId: String,
        answers: [String: String],
        activeQuestionId: String,
        currentQuestionIndex: Int
    ) async throws -> PlacementSubmissionResponse {
        try await request(
            "POST", "/api/v1/placement-exam/\(attemptId)/\(action)",
            body: [
                "answers": answers,
                "activeQuestionId": activeQuestionId,
                "currentQuestionIndex": currentQuestionIndex,
            ], authed: true)
    }

    // MARK: 29일 패키지 · 30일 페이백 · Unranked/Ranked

    struct AccessEconomyResponse: Codable {
        var economy: AccessEconomy
    }

    struct AccessEconomy: Codable {
        struct Access: Codable {
            var paidAccessDays: Int
            var refundChallengeDays: Int
            var bonusAccessDays: Int
            var lockedDays: Int
            var paidAccessStartsAt: String?
            var paidAccessEndsAt: String?
        }
        struct Refund: Codable {
            var status: String?
            var eligible: Bool
            var day30CompletionPassAvailable: Bool
            var streakDays: Int
            var targetStreakDays: Int
            var targetChallengeDays: Int
            var paybackAmountKRW: Int
            var completedAt: String?
        }
        struct Ranking: Codable {
            /// SUB · MAIN. 패키지 구매 전에는 nil.
            var activeRanking: String?
            /// 기존 서버 RankingProfile.mmr의 화면용 이름.
            var skillMMR: Int?
            var rankTier: String?
            var ladderPosition: Int?
            var mainRankingEnteredAt: String?
            var rankShieldUntil: String?

            /// 서버가 미래에 새 풀을 추가해도 전체 `/access` 응답 디코딩은 살려 둔다.
            /// 지금 앱이 이해하는 SUB/MAIN일 때만 타입으로 승격한다.
            var activePool: RankingPool? {
                activeRanking.flatMap { RankingPool(rawValue: $0.uppercased()) }
            }
        }
        struct PurchaseBlocker: Codable, Identifiable {
            var code: String
            var message: String
            var id: String { code }
        }
        struct Purchase: Codable {
            var allowed: Bool
            var blockers: [PurchaseBlocker]
        }

        var state: String
        var cycleId: String?
        var access: Access
        var refund: Refund
        var ranking: Ranking
        var purchase: Purchase
    }

    /// 네 종류의 일수와 활성 랭킹을 서버 판정 그대로 받는다.
    /// 앱에서 잔액을 합치거나 페이백 가능 여부를 다시 계산하지 않는다.
    static func getAccessEconomy() async throws -> AccessEconomy {
        let response: AccessEconomyResponse = try await request(
            "GET", "/api/v1/access", body: nil, authed: true)
        return response.economy
    }

    /// Sub와 Main은 서로 다른 사용자 풀이다. 전역 Arena 순위표를 재사용하면
    /// 한쪽 사용자가 다른 쪽 순위에 섞이므로 활성 풀 전용 경로를 호출한다.
    static func getAccessLeaderboard(ranking: RankingPool) async throws -> AccessLeaderboard {
        let response: AccessLeaderboard = try await request(
            "GET", "/api/v1/access/rankings/\(ranking.rawValue)/leaderboard",
            body: nil, authed: true)
        guard response.ranking == ranking else {
            throw ServerAPIError(
                message: "요청한 경쟁 풀과 다른 순위표를 받았습니다.",
                code: "RANKING_POOL_MISMATCH")
        }
        return response
    }

    // MARK: GOAT Arena v1 — 30일 사이클·페이백·자리 순위 단일 정본

    /// 기존 `/access`는 이전 LearningAccessAccount를 읽는 호환 경로다.
    /// 새 화면은 AccessCycle·ArenaProfile과 공식 ArenaMatch를 묶은 이 읽기 모델만 쓴다.
    struct GoatArenaResponse: Codable {
        var arena: GoatArenaSnapshot
    }

    struct GoatArenaSnapshot: Codable {
        struct RankUpPresentation: Codable, Identifiable, Equatable {
            var id: String
            var fromTier: String
            var toTier: String
            var tierCode: String
            var occurredAt: String
            var source: String
        }

        struct Identity: Codable {
            var displayName: String
            var schoolName: String?
            var displayMode: String?
        }

        struct Cycle: Codable {
            struct Access: Codable {
                var paidAccessActive: Bool
                var completionPassActive: Bool
                var learningAccessActive: Bool
                var paidAccessDaysRemaining: Int
            }

            struct Balances: Codable {
                var refundAvailableDays: Int
                var refundLockedDays: Int
                var bonusAvailableDays: Int
                var bonusLockedDays: Int
                var source: String
            }

            struct Attendance: Codable {
                var cycleStreakDays: Int
                var lastRecognizedDate: String?
            }

            struct Challenges: Codable {
                var completed: Int
                var completedNormal: Int
                var completedRevenge: Int
                var requestCount: Int
                var minimumRequired: Int?
                var requestLimit: Int?
                var newRequestCutoffDay: Int?
            }

            var id: String?
            var status: String
            var activeRanking: String?
            var cycleDay: Int?
            var phase: String
            var startsOn: String?
            var paidAccessEndsOn: String?
            var day30ReviewOn: String?
            var access: Access
            var balances: Balances
            var attendance: Attendance
            var challenges: Challenges
            var integrityState: String
            var autoRenewEnabled: Bool
        }

        struct Payback: Codable {
            struct Condition: Codable, Identifiable {
                var key: String
                var current: Int
                var required: Int?
                var met: Bool
                var id: String { key }
            }

            struct Blocker: Codable, Identifiable {
                var code: String
                var fields: [String]?
                var id: String { code }
            }

            var state: String
            var canEvaluate: Bool
            var eligible: Bool?
            var refundStatus: String?
            var conditions: [Condition]
            var blockers: [Blocker]
        }

        struct Ranking: Codable {
            struct Skill: Codable {
                var status: String
                var mmr: Int?
                var tier: String?
                var rankPoint: Int?
                var overallRank: Int?
                var weeklyExamsUntilConfirmed: Int?
            }

            struct Seat: Codable {
                var status: String
                var arenaPosition: Int?
                var mmrAtLastSeed: Int?
                var seededAt: String?
                var seedWeekKey: String?
                var protectionUntil: String?
                var rankShieldUntil: String?
            }

            var activeRanking: String?
            var skill: Skill
            var seat: Seat
            var contract: String
        }

        struct Season: Codable {
            var id: String
            var title: String?
            var status: String
            var currentWeekKey: String?
            var startsAt: String?
            var endsAt: String?
        }

        struct ActiveMatch: Codable {
            struct Stake: Codable {
                var assetType: String?
                var days: Int?
            }

            /// 현재 로그인한 참가자 자신의 시도만 내려온다. 구버전 서버는 이 필드가
            /// 없으므로 optional로 유지하되, 있으면 공유 match 상태보다 우선한다.
            struct ParticipantAttempt: Codable {
                var status: String
                var startedAt: String?
                var endsAt: String?
                var submittedAt: String?
                var evidenceDeadlineAt: String? = nil
                var evidenceRequired: Bool? = nil
            }

            var id: String?
            var status: String
            var role: String
            var matchType: String
            /// 서버 룰북 표시 계층이 내려주는 정산 설명. 구버전 서버와 저장된
            /// 스냅샷은 이 필드가 없으므로 optional 기본값을 유지한다.
            var settlementRule: String? = nil
            var activeRanking: String
            var myPositionBefore: Int?
            var opponentPositionBefore: Int?
            var stake: Stake
            var startsBy: String?
            var submitsBy: String?
            var integrityState: String
            /// 서버가 현재 참가자에게 허용한 명령. 있으면 클라이언트의 status
            /// 추정보다 우선하며, 구버전 캐시를 위해 optional로 유지한다.
            var availableActions: [String]? = nil
            var attempt: ParticipantAttempt?
        }

        /// Ranked 하위 티어 초대는 수락 전에는 ArenaMatch가 아니다. 서버의
        /// MainInvitationOffer를 별도 action item으로 받아 매치처럼 위장하지 않는다.
        struct PendingInvitation: Codable, Identifiable {
            var id: String
            var status: String
            var activeRanking: String
            var targetTier: String
            var initiatorTier: String
            var stakeDays: Int
            var offeredAt: String?
            var policyVersionCode: String?
        }

        struct Capabilities: Codable {
            var paybackEvaluation: String
            var mainArena: String
            var challengeCommands: String
        }

        var readModelVersion: String
        var generatedAt: String
        var state: String
        var identity: Identity
        var cycle: Cycle?
        var payback: Payback
        var ranking: Ranking
        var season: Season?
        var activeMatch: ActiveMatch?
        var pendingInvitation: PendingInvitation? = nil
        var rankUpPresentation: RankUpPresentation? = nil
        var capabilities: Capabilities
    }

    struct CachedGoatArenaSnapshot {
        var snapshot: GoatArenaSnapshot
        var savedAt: Date
    }

    private struct GoatArenaCacheEnvelope: Codable {
        var savedAt: Date
        var snapshot: GoatArenaSnapshot
    }

    private static let goatArenaCacheFile = "goat-arena-v1-cache.json"
    private static let goatArenaMaximumCacheAge: TimeInterval = 7 * 24 * 60 * 60

    /// 네트워크가 끊겼을 때 마지막으로 검증된 읽기 정본을 보여주기 위한 계정별 캐시.
    /// DataScope가 이메일 해시 슬롯을 분리하므로 공용 iPad에서 다른 학생의 순위가
    /// 섞이지 않는다. 7일이 지난 값은 현재 상태로 오해할 위험이 커 사용하지 않는다.
    static func cachedGoatArenaSnapshot(
        now: Date = Date()
    ) -> CachedGoatArenaSnapshot? {
        let url = DataScope.url(goatArenaCacheFile)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(
                GoatArenaCacheEnvelope.self,
                from: data),
              envelope.snapshot.readModelVersion == "GOAT_ARENA_V1" else {
            return nil
        }

        let age = max(0, now.timeIntervalSince(envelope.savedAt))
        guard age <= goatArenaMaximumCacheAge else { return nil }
        return CachedGoatArenaSnapshot(
            snapshot: envelope.snapshot,
            savedAt: envelope.savedAt)
    }

    private static func cacheGoatArenaSnapshot(
        _ snapshot: GoatArenaSnapshot,
        accountSlot: String,
        savedAt: Date = Date()
    ) {
        let envelope = GoatArenaCacheEnvelope(savedAt: savedAt, snapshot: snapshot)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(
            to: DataScope.url(goatArenaCacheFile, for: accountSlot),
            options: .atomic)
    }

    static func getGoatArenaSnapshot() async throws -> GoatArenaSnapshot {
        let accountSlot = DataScope.slot
        let response: GoatArenaResponse = try await request(
            "GET", "/api/v1/goat-arena", body: nil, authed: true)
        guard response.arena.readModelVersion == "GOAT_ARENA_V1" else {
            throw ServerAPIError(
                message: "GOAT Arena 응답 버전을 확인할 수 없습니다.",
                code: "GOAT_ARENA_VERSION_MISMATCH")
        }
        cacheGoatArenaSnapshot(
            response.arena,
            accountSlot: accountSlot)
        // 방어 마감 로컬 알림은 여기서 걸지 않는다 — 이 파일은 계약 테스트가
        // DataScope·소유권 파일 3개와만 묶어 단독 컴파일하는 순수 계층이라,
        // UserNotifications 를 쓰는 타입을 참조하는 순간 테스트가 컴파일되지 않는다.
        // 예약은 유일한 호출부(GoatArenaScreen.load)의 신선한 응답 분기가 건다.
        return response.arena
    }

    // MARK: GOAT Arena 경기 목록 (읽기 전용)
    //
    // WHY. 앱은 지금까지 `GET /api/v1/goat-arena/matches` 를 한 번도 부르지 않았다.
    // 그 결과 "제출 뒤 승패는 정산이 끝난 GOAT Arena 화면에서 확인" 이라고 안내하면서
    // 정작 그 화면에 결과가 없었다 — 학생은 웹 우편함까지 가야 승패를 알 수 있었다.
    //
    // 이 어댑터는 **읽기만** 한다. 정산·점수·승패 판정은 전부 서버가 이미 끝낸 값이고
    // 앱은 그중 서버가 내려준 필드만 그대로 표시한다. 점수·정답 수·소요 시간은 이
    // 읽기 모델에 없으므로 앱에서도 만들지 않는다.
    struct GoatArenaParticipantMatch: Codable, Identifiable {
        struct PreStartContract: Codable, Equatable {
            var title: String
            var description: String
            var stake: String
            var win: String
            var loss: String
            var deadlineLabel: String
            var deadlineAt: String?
            var deadlineNotice: String
            var rulesHref: String
        }
        struct Stake: Codable {
            var assetType: String?
            var days: Int?
        }

        struct Timeline: Codable {
            var matchedAt: String?
            var startsBy: String?
            var startedAt: String?
            var endsAt: String?
            var submittedAt: String?
            var submitsBy: String?
            var hardDeadlineAt: String?
            var resolvedAt: String?
            var settledAt: String?
            var updatedAt: String?
        }

        struct Attempt: Codable {
            var id: String?
            var status: String?
            var startedAt: String?
            var endsAt: String?
            var submittedAt: String?
            var evidenceDeadlineAt: String? = nil
            var evidenceRequired: Bool? = nil
            var currentQuestionIndex: Int? = nil
        }

        var id: String
        var status: String
        var role: String
        var activeRanking: String?
        var matchType: String?
        var preStartContract: PreStartContract?
        var myPositionBefore: Int?
        var opponentPositionBefore: Int?
        var myPositionAfter: Int?
        var opponentPositionAfter: Int?
        var stake: Stake?
        /// 서버가 확정한 승패. "WON" | "LOST" | nil(아직 승자 없음).
        var outcome: String?
        var settlementReason: String?
        var positionOutcome: String?
        var integrityState: String?
        var timeLimitSeconds: Int?
        var timeline: Timeline?
        var attempt: Attempt?
    }

    private struct GoatArenaMatchesResponse: Codable {
        var matches: [GoatArenaParticipantMatch?]
        var nextCursor: String? = nil
    }

    private struct GoatArenaMatchResponse: Codable {
        var match: GoatArenaParticipantMatch
    }

    /// 최근 경기부터(서버 정렬: updatedAt 내림차순) 한 페이지를 읽는다.
    static func getGoatArenaMatches(
        limit: Int = 5
    ) async throws -> [GoatArenaParticipantMatch] {
        let response: GoatArenaMatchesResponse = try await request(
            "GET",
            "/api/v1/goat-arena/matches",
            body: nil,
            authed: true,
            query: ["limit": String(max(1, min(limit, 20)))])
        return response.matches.compactMap { $0 }
    }

    static func getGoatArenaMatch(
        matchId: String
    ) async throws -> GoatArenaParticipantMatch {
        let response: GoatArenaMatchResponse = try await request(
            "GET",
            "/api/v1/goat-arena/matches/\(matchId)",
            body: nil,
            authed: true)
        return response.match
    }

    // MARK: GOAT Arena 공식 룰북

    struct GoatArenaRulebookDocument: Codable {
        struct Divisions: Codable {
            var sub: Rulebook
            var main: Rulebook
        }

        struct Rulebook: Codable {
            struct UpcomingPolicy: Codable {
                var displayName: String
                var effectiveFrom: String?
                var policyVersionCode: String?
            }

            struct PaybackPolicy: Codable {
                struct MatchLimit: Codable, Identifiable {
                    var tier: String
                    var tierLabel: String
                    var attackLimit: Int
                    var defenseLimit: Int
                    var id: String { tier }
                }

                struct Band: Codable, Identifiable {
                    var minScoreDays: Int
                    var maxScoreDays: Int?
                    var ratePercent: Int
                    var expectedPaybackAmount: Int
                    var id: String { "\(minScoreDays)-\(maxScoreDays ?? Int.max)" }
                }

                var displayName: String
                var priceAmount: Int
                var initialLearningDays: Int
                var initialPaybackScoreDays: Int
                var dailyMatchLimitsByTier: [MatchLimit]
                var minimumStreakDays: Int
                /// 신 서버 룰북 뷰(paybackPolicyView)는 이 값을 내려주지 않는다 — 필수로 두면
                /// keyNotFound 로 룰북 전체 디코드가 실패하므로 optional 로 받는다.
                var minimumPaidNormalAttacks: Int? = nil
                var minimumScoreDays: Int
                var bands: [Band]
                var isFallback: Bool
            }

            struct MainPolicy: Codable {
                struct StakeBand: Codable, Identifiable {
                    var tierGap: Int
                    var stakeDays: Int
                    var id: Int { tierGap }
                }

                var displayName: String
                var policyVersionCode: String
                var maximumTargetTierGap: Int
                var stakeDaysByTierGap: [StakeBand]
                /// 신 서버 룰북 뷰(mainPolicyView)는 이 값을 내려주지 않는다 — optional 로 받고
                /// 화면에서는 `?? false` 로 다룬다.
                var requiresOpponentDaysGreaterThanStake: Bool? = nil
                var repeatOpponentExclusionDays: Int
                var revengeStakeMultiplier: Int
                var revengeFeeDays: Int
            }

            struct Rule: Codable, Identifiable {
                struct Section: Codable, Identifiable {
                    var title: String
                    var body: [String]
                    var id: String { title }
                }

                var number: Int
                var title: String
                var sections: [Section]
                var id: Int { number }
            }

            var division: String
            var title: String
            var eyebrow: String
            var intro: String
            var summary: [String]
            var rules: [Rule]
            var paybackPolicy: PaybackPolicy?
            var mainPolicy: MainPolicy?
            /// V1 스키마를 유지한 채 추가한 선택 필드다. 구 캐시는 nil로
            /// 디코딩되고, 신규 서버는 30일 사전 고지를 함께 내려준다.
            var upcomingPolicy: UpcomingPolicy? = nil
        }

        var schemaVersion: String
        var revision: String
        var generatedAt: String
        var source: String
        var divisions: Divisions
    }

    struct CachedGoatArenaRulebook {
        var document: GoatArenaRulebookDocument
        var savedAt: Date
    }

    private struct GoatArenaRulebookResponse: Codable {
        var rulebook: GoatArenaRulebookDocument
    }

    private struct GoatArenaRulebookCacheEnvelope: Codable {
        var savedAt: Date
        var document: GoatArenaRulebookDocument
    }

    private static let goatArenaRulebookCacheFile = "goat-arena-rulebook-v1-cache.json"
    private static let goatArenaRulebookMaximumCacheAge: TimeInterval = 30 * 24 * 60 * 60

    static func cachedGoatArenaRulebook(
        now: Date = Date()
    ) -> CachedGoatArenaRulebook? {
        let url = DataScope.url(goatArenaRulebookCacheFile)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(
                GoatArenaRulebookCacheEnvelope.self,
                from: data),
              envelope.document.schemaVersion == "GOAT_ARENA_RULEBOOK_V1" else {
            return nil
        }
        let age = max(0, now.timeIntervalSince(envelope.savedAt))
        guard age <= goatArenaRulebookMaximumCacheAge else { return nil }
        return CachedGoatArenaRulebook(
            document: envelope.document,
            savedAt: envelope.savedAt)
    }

    private static func cacheGoatArenaRulebook(
        _ document: GoatArenaRulebookDocument,
        accountSlot: String,
        savedAt: Date = Date()
    ) {
        let envelope = GoatArenaRulebookCacheEnvelope(
            savedAt: savedAt,
            document: document)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(
            to: DataScope.url(goatArenaRulebookCacheFile, for: accountSlot),
            options: .atomic)
    }

    static func getGoatArenaRulebook() async throws -> GoatArenaRulebookDocument {
        let accountSlot = DataScope.slot
        let response: GoatArenaRulebookResponse = try await request(
            "GET", "/api/v1/goat-arena/rulebook", body: nil, authed: true)
        guard response.rulebook.schemaVersion == "GOAT_ARENA_RULEBOOK_V1" else {
            throw ServerAPIError(
                message: "GOAT Arena 룰북 응답 버전을 확인할 수 없습니다.",
                code: "GOAT_ARENA_RULEBOOK_VERSION_MISMATCH")
        }
        cacheGoatArenaRulebook(
            response.rulebook,
            accountSlot: accountSlot)
        return response.rulebook
    }

    // MARK: GOAT Arena 경기 명령

    struct GoatArenaAttempt: Codable {
        var attemptId: String
        var matchId: String
        var participantRole: String
        var questionPackId: String
        var questionPackVersion: String
        var scoringPolicyVersion: String
        var timingPolicyVersion: String
        var status: String
        var questionCount: Int
        /// 최신 공식 경기는 현재 문항 하나만 공개한다. 전체 5문항 중 현재 번호다.
        var currentQuestionNumber: Int? = nil
        var timeLimitSeconds: Int
        var startedAt: String
        var endsAt: String
        var commonSubmitsBy: String
        var networkReconnectGraceMs: Int?
        var recognizedHeartbeatActiveMs: Int
        var submittedAt: String?
        var evidenceDeadlineAt: String? = nil
        var evidenceRequired: Bool? = nil
    }

    struct GoatArenaQuestionPack: Codable {
        struct IntegrityWatermark: Codable, Equatable {
            var traceCode: String
            var matchReference: String
            var role: String
            var title: String
            var shortText: String
            var englishText: String
            var notice: String
        }
        struct Choice: Codable, Identifiable {
            var key: String
            var text: String
            var id: String { key }
        }

        struct Question: Codable, Identifiable {
            var slot: Int
            var questionVersionId: String
            var stem: String
            var choices: [Choice]?
            var inputMode: String
            var scoreWeight: Double
            var targetDifficulty: Double
            var calibratedDifficulty: Double
            var advanced: Bool
            /// 서버가 검증·봉인한 문제용 그래프/도형 JSON. 정답과 풀이를 포함하지 않는다.
            var visualizationJSON: String? = nil
            var savedAnswer: String? = nil
            var id: Int { slot }
        }

        var questionPackId: String
        var matchId: String
        var participantRole: String
        var packVersion: String
        var curriculumVersion: String
        var questionVersion: String
        var scoringPolicyVersion: String
        var questionCount: Int
        /// questions에는 이 번호의 문항 하나만 들어온다.
        var currentQuestionNumber: Int? = nil
        var timeLimitSeconds: Int
        var integrityWatermark: IntegrityWatermark? = nil
        var questions: [Question]
        var sealedAt: String
    }

    struct GoatArenaStartResponse: Codable {
        var attempt: GoatArenaAttempt
        var questionPack: GoatArenaQuestionPack
    }

    struct GoatArenaSolutionBoard: Codable, Equatable {
        var questionSlot: Int
        var revision: Int
        var strokeCount: Int?
        var sha256: String
        var previewURL: String?
        var savedAt: String?
        var finalizedAt: String?
        var drawingDataBase64: String?
    }

    private struct GoatArenaSolutionBoardResponse: Codable {
        var board: GoatArenaSolutionBoard
    }

    private struct GoatArenaSolutionBoardsResponse: Codable {
        var boards: [GoatArenaSolutionBoard]
    }

    private struct GoatArenaSolutionBoardFinalizeResponse: Codable {
        var finalized: Bool
        var replayed: Bool
    }

    /// 멱등 명령의 fingerprint에 포함되는 값이다. 경기 도중 앱이 업데이트되어도
    /// 최초 명령과 같은 값을 재전송할 수 있도록 경기 키 저장소가 이 값을 함께 고정한다.
    static var clientBuildVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version)(\(build))"
    }

    struct GoatArenaEvent: Codable {
        var eventId: String
        var attemptId: String
        var matchId: String
        var eventType: String
        var clientEventId: String
        var serverSequence: Int
        var serverOccurredAt: String
        var questionSlot: Int?
        var networkState: String?
        var recognizedActiveIntervalMs: Int
        var answerStored: Bool
    }

    struct GoatArenaSubmission: Codable {
        var submissionRecordId: String
        var attemptId: String
        var matchId: String
        var participantRole: String
        var questionPackId: String
        var submissionId: String
        var submittedAt: String
        var evidenceDeadlineAt: String? = nil
        var evidenceRequired: Bool? = nil
        var lastAcceptedServerSequence: Int
        var recognizedHeartbeatActiveMs: Int
        var answerCount: Int
    }

    enum GoatArenaDeclineReasonCode: String, Codable, CaseIterable, Equatable {
        case scheduleConflict = "SCHEDULE_CONFLICT"
        case technicalIssue = "TECHNICAL_ISSUE"
        case other = "OTHER"
    }

    struct GoatArenaMatchCommandResponse: Codable {
        struct Match: Codable {
            var id: String
            var status: String
            var integrityState: String
        }

        var match: Match
        /// 초대 수락은 offer와 새 ArenaMatch의 식별자가 다르다.
        var invitationId: String? = nil
    }

    private struct GoatArenaEventResponse: Codable {
        var event: GoatArenaEvent
    }

    private struct GoatArenaQuestionResponse: Codable {
        var questionPack: GoatArenaQuestionPack
    }

    private struct GoatArenaSubmissionResponse: Codable {
        var attempt: GoatArenaSubmission
    }

    struct GoatArenaEvidenceReceipt: Codable, Equatable {
        var evidenceId: String
        var attemptId: String
        var status: String
        var matchStatus: String
        var replayed: Bool
        var submissionId: String?
        var submittedAt: String?
        var deadlineAt: String?
        var anomalyFlags: [String]
    }

    struct GoatArenaClientReviewMetadata: Codable, Equatable {
        var model: String
        var modelVersion: String
        /// 로컬 결과는 확정 판정이 아니라 운영 검토 후보 메타데이터다.
        var reviewState: String
        var signals: [String]
    }

    struct GoatArenaClientReviewReceipt: Codable, Equatable {
        var reviewId: String
        var replayed: Bool
        var accepted: Bool
    }

    private struct GoatArenaClientReviewResponse: Codable {
        var review: GoatArenaClientReviewReceipt
    }

    private struct GoatArenaEvidenceResponse: Codable {
        var evidence: GoatArenaEvidenceReceipt
    }

    /// Unranked 자동 상대 배정은 웹 세션으로 넘기지 않고 같은 Bearer 인증과
    /// 공식 ArenaMatch 생성 서비스를 사용한다.
    static func createUnrankedArenaMatch(
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaMatchCommandResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/sub",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func acceptGoatArenaChallenge(
        matchId: String,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaMatchCommandResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/accept",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func declineGoatArenaChallenge(
        matchId: String,
        reasonCode: GoatArenaDeclineReasonCode,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaMatchCommandResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/decline",
            body: ["reasonCode": reasonCode.rawValue],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func startGoatArenaMatch(
        matchId: String,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaStartResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/start",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func getGoatArenaQuestions(
        matchId: String,
        requestId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaQuestionPack {
        let response: GoatArenaQuestionResponse = try await request(
            "GET",
            "/api/v1/goat-arena/matches/\(matchId)/questions",
            body: nil,
            authed: true,
            headers: [
                "Idempotency-Key": requestId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return response.questionPack
    }

    /// 현재 문항을 서버에서 확정하고 이전 문항을 봉인한 뒤 다음 한 문항만 받는다.
    static func advanceGoatArenaQuestion(
        matchId: String,
        questionSlot: Int,
        answer: String,
        boardRevision: Int,
        boardSha256: String,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaStartResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/advance",
            body: [
                "questionSlot": questionSlot,
                "answer": answer,
                "boardRevision": boardRevision,
                "boardSha256": boardSha256,
            ],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
                "X-Matths-Evidence-Mode": "INLINE_BOARD_V1",
            ])
    }

    static func getGoatArenaSolutionBoards(
        matchId: String
    ) async throws -> [GoatArenaSolutionBoard] {
        let response: GoatArenaSolutionBoardsResponse = try await request(
            "GET",
            "/api/v1/goat-arena/matches/\(matchId)/solution-boards",
            body: nil,
            authed: true)
        return response.boards
    }

    static func saveGoatArenaSolutionBoard(
        matchId: String,
        questionSlot: Int,
        revision: Int,
        strokeCount: Int,
        drawingData: Data,
        previewPNG: Data,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaSolutionBoard {
        guard !drawingData.isEmpty, drawingData.count <= 750 * 1024,
              !previewPNG.isEmpty, previewPNG.count <= 10 * 1024 * 1024 else {
            throw ServerAPIError(
                message: "풀이판 저장 크기를 확인해주세요.",
                code: "ARENA_INLINE_BOARD_TOO_LARGE")
        }
        #if DEBUG
        // 이 업로드는 공용 JSON request()를 지나지 않는 multipart 경로다.
        // URLProtocol 등록 전에 URLSession.shared가 만들어진 실행에서도 데모가
        // 운영 서버로 새거나 첫 문항에서 멈추지 않도록 여기서 receipt를 확정한다.
        if DemoMode.isOn {
            return GoatArenaSolutionBoard(
                questionSlot: questionSlot,
                revision: revision,
                strokeCount: strokeCount,
                sha256: String(repeating: "a", count: 64),
                previewURL: nil,
                savedAt: ISO8601DateFormatter().string(from: Date()),
                finalizedAt: nil,
                drawingDataBase64: drawingData.base64EncodedString())
        }
        #endif
        let boundary = "Matths-Inline-Board-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "PUT",
            "/api/v1/goat-arena/matches/\(matchId)/solution-boards/current",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 90)
        request.setValue(commandId, forHTTPHeaderField: "Idempotency-Key")
        request.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")

        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        for (name, value) in [
            ("questionSlot", String(questionSlot)),
            ("revision", String(revision)),
            ("strokeCount", String(strokeCount)),
            ("drawingDataBase64", drawingData.base64EncodedString()),
        ] {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"solutionBoard\"; filename=\"arena-question-\(questionSlot).png\"\r\n")
        append("Content-Type: image/png\r\n\r\n")
        body.append(previewPNG)
        append("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(
            GoatArenaSolutionBoardResponse.self,
            from: data).board
    }

    static func finalizeGoatArenaSolutionBoards(
        matchId: String,
        commandId: String,
        clientBuildVersion: String
    ) async throws {
        let response: GoatArenaSolutionBoardFinalizeResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/solution-boards/finalize",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        guard response.finalized else {
            throw ServerAPIError(
                message: "풀이판 원본을 확정하지 못했습니다.",
                code: "ARENA_INLINE_BOARD_FINALIZE_FAILED")
        }
    }

    static func postGoatArenaHeartbeat(
        matchId: String,
        eventId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaEvent {
        let response: GoatArenaEventResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/heartbeat",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": eventId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return response.event
    }

    static func postGoatArenaFocus(
        matchId: String,
        questionSlot: Int,
        eventId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaEvent {
        let response: GoatArenaEventResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/focus",
            body: ["questionSlot": questionSlot],
            authed: true,
            headers: [
                "Idempotency-Key": eventId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return response.event
    }

    static func saveGoatArenaAnswer(
        matchId: String,
        questionSlot: Int,
        answer: String,
        eventId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaEvent {
        let response: GoatArenaEventResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/answers",
            body: ["questionSlot": questionSlot, "answer": answer],
            authed: true,
            headers: [
                "Idempotency-Key": eventId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return response.event
    }

    static func postGoatArenaNetworkState(
        matchId: String,
        state: String,
        eventId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaEvent {
        let response: GoatArenaEventResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/network-state",
            body: ["networkState": state],
            authed: true,
            headers: [
                "Idempotency-Key": eventId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return response.event
    }

    static func submitGoatArenaAttempt(
        matchId: String,
        submissionId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaSubmission {
        let response: GoatArenaSubmissionResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/submit",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": submissionId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return response.attempt
    }

    static func submitGoatArenaEvidence(
        matchId: String,
        files: [URL],
        submissionId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaEvidenceReceipt {
        guard !files.isEmpty, files.count <= 5 else {
            throw ServerAPIError(
                message: "풀이 증거 사진을 1장 이상 5장 이하로 선택해주세요.",
                code: "INVALID_ARENA_EVIDENCE_FILES")
        }

        let boundary = "Matths-Arena-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/evidence",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 180)
        request.setValue(submissionId, forHTTPHeaderField: "Idempotency-Key")
        request.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")

        let multipart = FileManager.default.temporaryDirectory
            .appendingPathComponent("arena-evidence-\(UUID().uuidString).body")
        FileManager.default.createFile(atPath: multipart.path, contents: nil)
        let output = try FileHandle(forWritingTo: multipart)
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: multipart)
        }

        func write(_ text: String) throws {
            try output.write(contentsOf: Data(text.utf8))
        }

        var totalSize = 0
        for file in files {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
            guard let size = values.fileSize, size > 0, size <= 10 * 1024 * 1024 else {
                throw ServerAPIError(
                    message: "풀이 증거 사진은 각각 10MB 이하여야 합니다.",
                    code: "ARENA_EVIDENCE_FILE_TOO_LARGE")
            }
            totalSize += size
            guard totalSize <= 30 * 1024 * 1024 else {
                throw ServerAPIError(
                    message: "풀이 증거 사진은 합계 30MB 이하여야 합니다.",
                    code: "ARENA_EVIDENCE_TOTAL_SIZE")
            }
            let type = values.contentType
            guard type?.conforms(to: .image) == true else {
                throw ServerAPIError(
                    message: "풀이 증거는 이미지 파일만 제출할 수 있습니다.",
                    code: "INVALID_ARENA_EVIDENCE_TYPE")
            }
            let mime = type?.preferredMIMEType ?? "image/jpeg"
            let safeName = file.lastPathComponent
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"evidenceFiles\"; filename=\"\(safeName)\"\r\n")
            try write("Content-Type: \(mime)\r\n\r\n")
            let input = try FileHandle(forReadingFrom: file)
            while let chunk = try input.read(upToCount: 256 * 1024), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            try input.close()
            try write("\r\n")
        }
        try write("--\(boundary)--\r\n")
        try output.synchronize()

        let (data, response) = try await URLSession.shared.upload(
            for: request,
            fromFile: multipart)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        return try JSONDecoder().decode(
            GoatArenaEvidenceResponse.self,
            from: data).evidence
    }

    /// 사진 제출 60초 제한을 로컬 모델이 막지 않도록 증거 접수 뒤 별도로 보낸다.
    /// 이 값은 서버 판정·점수·정산을 바꾸지 않는 검토 후보 메타데이터다.
    static func submitGoatArenaClientReview(
        matchId: String,
        evidenceId: String,
        reviewId: String,
        metadata: GoatArenaClientReviewMetadata,
        completedAt: Date,
        clientBuildVersion: String
    ) async throws -> GoatArenaClientReviewReceipt {
        let value: GoatArenaClientReviewResponse = try await request(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/evidence/client-review",
            body: [
                "evidenceId": evidenceId,
                "model": metadata.model,
                "modelVersion": metadata.modelVersion,
                "reviewState": metadata.reviewState,
                "signals": metadata.signals,
                "completedAt": ISO8601DateFormatter().string(from: completedAt),
            ],
            authed: true,
            headers: [
                "Idempotency-Key": reviewId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        return value.review
    }

    static func postEvents(
        _ events: [[String: Any]],
        authorization: AuthorizationSnapshot? = nil
    ) async throws {
        let _: Ack = try await request(
            "POST", "/api/v1/events",
            body: ["sessionId": "ipad", "events": events], authed: true,
            authorization: authorization)
    }

    /// 반환: clientAttemptId → 서버 attemptId 매핑.
    /// 이걸 버리면 복습 결과를 올릴 주소를 영영 알 수 없다(서버는 _id 로만 찾는다).
    @discardableResult
    static func postWrongNotes(
        _ entries: [[String: Any]],
        authorization: AuthorizationSnapshot? = nil
    ) async throws -> [String: String] {
        let res: SyncedList = try await request(
            "POST", "/api/v1/wrong-notes/bulk", body: ["entries": entries], authed: true,
            authorization: authorization)
        var map: [String: String] = [:]
        for row in res.synced {
            if let c = row.clientAttemptId, let a = row.attemptId { map[c] = a }
        }
        return map
    }

    /// 서버가 돌려주는 오답 한 줄 (GET /wrong-notes 응답 entries 의 원소).
    /// 서버에 없는 것(단원명·필기·선지)은 여기에도 없다.
    struct RemoteWrongNote: Codable {
        var attemptId: String
        var clientAttemptId: String?
        var statement: String
        var answer: String?
        var steps: [String]?
        var typeKey: String?
        var seed: String?
        var myAnswer: String?
        var divergenceStep: Int?
        var errorType: String?
        var srsStage: Int?
        var wrongCount: Int?
        var nextReviewAt: String?
        /// pending(아직 복습 전) · scheduled(예약됨) · completed(완료).
        /// **nextReviewAt 만 보면 pending 과 completed 를 구분할 수 없다** —
        /// 둘 다 null 이라 한 번도 안 푼 오답이 완료로 둔갑한다.
        var reviewStatus: String?
        var createdAt: String?
        /// 증분 정본. 최초 제출(createdAt)과 달리 복습 결과 변경마다 전진한다.
        var updatedAt: String?
        /// 5지선다 복원용 — 없으면 주관식으로 둔갑한다
        var choices: [String]?
        var isTex: Bool?
    }
    /// 서버는 300건 단위로 페이지를 나눠 `hasMore` / `nextCursor` 를 붙인다.
    /// 첫 페이지만 읽으면 오답이 300건을 넘는 계정은 5분 간격 pull 을 여러 번 돌아야
    /// 다 받고, 경계 updatedAt 을 공유하는 행은 빠질 수 있어 커서를 그대로 노출한다.
    struct RemoteWrongNotes: Codable {
        var entries: [RemoteWrongNote]
        var hasMore: Bool?
        var nextCursor: String?
    }

    /// 다른 기기에서 쌓인 오답을 내려받는다(증분, since 이후만).
    /// 올리기만 하고 내려받지 않으면 기기를 바꾼 사람에게 오답노트는 빈 화면이다.
    /// `cursor` 가 있으면 서버 페이지 커서가 우선한다(같은 조회의 다음 페이지).
    static func getWrongNotes(
        since: String?,
        cursor: String? = nil,
        authorization: AuthorizationSnapshot? = nil
    ) async throws -> RemoteWrongNotes {
        var query: [String: String] = [:]
        if let since, !since.isEmpty { query["since"] = since }
        if let cursor, !cursor.isEmpty { query["cursor"] = cursor }
        return try await request(
            "GET", "/api/v1/wrong-notes", body: nil, authed: true, query: query,
            authorization: authorization)
    }

    /// 복습 결과. `correct` 를 하드코딩하면 틀린 복습이 맞은 것으로 서버에 남는다.
    static func reviewResultBody(correct: Bool, srsStage: Int, wrongCount: Int,
                                 nextReviewAt: String?, clientEventId: String) -> [String: Any] {
        var body: [String: Any] = [
            "correct": correct,
            "srsStage": srsStage,
            "wrongCount": wrongCount,
            "clientEventId": clientEventId,
        ]
        if let nextReviewAt { body["nextReviewAt"] = nextReviewAt }
        return body
    }

    static func postReviewResult(attemptId: String, correct: Bool,
                                 srsStage: Int, wrongCount: Int,
                                 nextReviewAt: String?,
                                 clientEventId: String,
                                 authorization: AuthorizationSnapshot? = nil) async throws {
        struct Empty: Codable {}
        let body = reviewResultBody(
            correct: correct, srsStage: srsStage, wrongCount: wrongCount,
            nextReviewAt: nextReviewAt, clientEventId: clientEventId)
        let _: Empty = try await request(
            "POST", "/api/v1/wrong-notes/\(attemptId)/review-result", body: body, authed: true,
            authorization: authorization)
    }

    struct RemoteStuckPoint: Codable, Identifiable {
        var id: String
        var text: String
        var createdAt: String
    }
    private struct RemoteStuckPoints: Codable { var stuckPoints: [RemoteStuckPoint] }
    private struct RemoteStuckPointEnvelope: Codable { var stuckPoint: RemoteStuckPoint }

    static func postStuckPoint(
        id: String,
        text: String,
        createdAt: String,
        authorization: AuthorizationSnapshot? = nil
    ) async throws {
        let _: RemoteStuckPointEnvelope = try await request(
            "POST", "/api/v1/wrong-notes/stuck-points",
            body: ["id": id, "text": text, "createdAt": createdAt], authed: true,
            authorization: authorization)
    }

    static func getStuckPoints(
        authorization: AuthorizationSnapshot? = nil
    ) async throws -> [RemoteStuckPoint] {
        let response: RemoteStuckPoints = try await request(
            "GET", "/api/v1/wrong-notes/stuck-points", body: nil, authed: true,
            authorization: authorization)
        return response.stuckPoints
    }

    private struct ProgressResetResponse: Codable {
        struct Reset: Codable { var clientResetId: String; var deletedCount: Int }
        var reset: Reset
    }

    static func resetLearningProgress(
        clientResetId: String,
        occurredAt: String,
        authorization: AuthorizationSnapshot? = nil
    ) async throws {
        let _: ProgressResetResponse = try await request(
            "POST", "/api/v1/learning/progress/reset",
            body: ["clientResetId": clientResetId, "occurredAt": occurredAt], authed: true,
            authorization: authorization)
    }

    // MARK: 퀵 연습 (웹 quick-practice — 수능 첫 페이지 유형 40초 타이머)

    struct QuickAttempt: Codable, Identifiable {
        var instanceId: String
        var pointValue: Int?
        var topicKey: String?
        var topicLabel: String?
        var variantLabel: String?
        var sourceScope: String?
        var prompt: String
        var deadlineAt: String?
        var id: String { instanceId }
    }
    struct QuickStart: Codable { var timeLimitMs: Int?; var attempt: QuickAttempt }
    struct QuickResult: Decodable {
        var expired: Bool?
        var correct: Bool?
        var solution: String?
        /// 정답 표시용 문자열.
        ///
        /// **서버는 숫자와 문자열을 섞어 보낸다.** 스키마가 Mixed 라서
        /// 삼각비 유형은 기약분수 `"3/5"` 처럼 문자열로 나가고, 정수 정답도
        /// `fraction()` 을 거치며 `"4"` 라는 문자열이 된다.
        /// 이걸 `Double?` 로 못 박아 두었더니 typeMismatch 로 **구조체 전체가
        /// 디코딩 실패**했고, 학생에게는 "채점에 실패했습니다" 만 보였다.
        /// expire 응답도 같은 구조체를 쓰므로 40초 타임아웃 경로까지 같이 죽었다.
        var answerText: String?
        var responseTimeMs: Int?
        /// expire 폴링 응답 — 아직 시간이 남았으면 true
        var pending: Bool?

        private enum CodingKeys: String, CodingKey {
            case expired, correct, solution, answer, responseTimeMs, pending
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            expired = try c.decodeIfPresent(Bool.self, forKey: .expired)
            correct = try c.decodeIfPresent(Bool.self, forKey: .correct)
            solution = try c.decodeIfPresent(String.self, forKey: .solution)
            responseTimeMs = try c.decodeIfPresent(Int.self, forKey: .responseTimeMs)
            pending = try c.decodeIfPresent(Bool.self, forKey: .pending)
            // 숫자로 오면 소수점 없는 값은 정수처럼 적는다 — "4.0" 이 아니라 "4"
            if let v = try? c.decode(Double.self, forKey: .answer) {
                answerText = v == v.rounded() ? String(Int(v)) : String(v)
            } else {
                answerText = try? c.decode(String.self, forKey: .answer)
            }
        }
    }
    struct QuickStats: Codable {
        struct Row: Codable { var total: Int?; var correct: Int?; var accuracy: Double?; var averageMs: Int? }
        var stats: Row
    }

    /// 새 문항 뽑기. pointValue 는 **2·3점만** (서버 allowedPoints=[2,3]).
    /// 그 외 값을 보내면 서버가 2·3 중 하나를 무작위로 골라 버려,
    /// 학생이 고른 것과 다른 배점이 출제된다.
    static func quickPracticeStart(pointValue: Int) async throws -> QuickStart {
        try await request("POST", "/api/v1/quick-practice/start",
                          body: ["pointValue": pointValue], authed: true)
    }

    static func quickPracticeSubmit(instanceId: String, answer: String,
                                    elapsedMs: Int) async throws -> QuickResult {
        struct Wrap: Decodable { var result: QuickResult }
        let w: Wrap = try await request(
            "POST", "/api/v1/quick-practice/\(instanceId)/submit",
            body: ["answer": answer, "elapsedMs": elapsedMs], authed: true)
        return w.result
    }

    /// 시간 초과 처리 — 서버가 마감 시각을 최종 판정한다(클라 시계를 믿지 않는다).
    static func quickPracticeExpire(instanceId: String) async throws -> QuickResult {
        // 서버는 활성 시도가 없으면(이미 제출·만료됐거나 새 문항이 대체) `result: null` 을
        // 돌려준다. 필수로 두면 valueNotFound 디코드 실패가 "시간 초과 처리 실패" 로 보이므로
        // optional 로 받고, nil 이면 화면이 그대로 보여줄 수 있는 typed 오류로 바꾼다.
        struct Wrap: Decodable { var result: QuickResult? }
        let w: Wrap = try await request(
            "POST", "/api/v1/quick-practice/\(instanceId)/expire", body: [:], authed: true)
        guard let result = w.result else {
            throw ServerAPIError(
                message: "이미 처리된 문항입니다. 새 문항을 시작해 주세요.",
                code: "QUICK_PRACTICE_ALREADY_FINISHED")
        }
        return result
    }

    static func quickPracticeStats() async throws -> QuickStats.Row {
        let s: QuickStats = try await request("GET", "/api/v1/quick-practice/stats",
                                              body: nil, authed: true)
        return s.stats
    }

    // MARK: 랭킹 표시 설정 (IPAD_API.md — nickname 전용)

    /// 구버전 앱과의 호환을 위해 남긴 공개 이름 PATCH다. 현재 정본은 nickname
    /// 하나뿐이며, 서버도 다른 값은 INVALID_RANKING_DISPLAY_MODE로 거절한다.
    static func updateRankingIdentity(mode: String) async throws -> ServerUser {
        let body: [String: Any] = ["rankingDisplayMode": mode]
        let res: MeResponse = try await request(
            "PATCH", "/api/v1/me/ranking-identity", body: body, authed: true)
        return res.user
    }

    // MARK: 공통 요청

    /// JSON 이외의 Bearer 요청(PDF 다운로드·multipart 소명 제출)도 로그인과 동일한
    /// 키체인 토큰/클라이언트 버전 규칙을 사용하게 하는 공통 빌더입니다.
    static func authorizedRequest(
        _ method: String,
        _ path: String,
        contentType: String? = nil,
        timeout: TimeInterval = 60
    ) throws -> URLRequest {
        #if DEBUG
        // 데모 모드는 여기서도 끝낸다. request() 와 같은 이유로 **토큰 검사보다 먼저**다 —
        // 데모에는 키체인 토큰이 없어서 시험지 PDF 다운로드·소명 업로드가 401 로 막혔다.
        // 주소는 해석되지 않는 데모 호스트로 바꾼다. DemoURLProtocol 이 가로채 준비된
        // 바이트를 돌려주고, 혹시 가로채기가 안 걸려도 운영 서버로는 못 나간다.
        // 자세한 근거는 DemoMode.swift 의 "JSON 이외 경로 가로채기" 주석.
        if DemoMode.isOn {
            var request = URLRequest(url: demoURL(path))
            request.httpMethod = method
            request.timeoutInterval = timeout
            request.setValue("Bearer demo", forHTTPHeaderField: "Authorization")
            request.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            return request
        }
        #endif
        guard let token = TokenBox.load(), !token.isEmpty else {
            notifyAuthenticationExpired(
                message: "로그인이 만료되었습니다. 다시 로그인해주세요.")
            throw ServerAPIError(
                message: "로그인이 필요합니다.",
                code: "UNAUTHORIZED",
                statusCode: 401)
        }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    #if DEBUG
    /// 데모 전용 주소. 스킴·경로는 운영과 같은 모양을 유지하고 호스트만 바꾼다 —
    /// 로그에 찍힌 주소만 보고도 데모 요청인지 바로 알 수 있어야 한다.
    private static func demoURL(_ path: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = DemoMode.networkHost
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        return components.url ?? URL(string: "https://\(DemoMode.networkHost)/")!
    }
    #endif

    /// download/upload 응답의 401도 그 요청이 실제 사용한 토큰만 폐기한다.
    /// 토큰은 로그·오류·디스크에 남기지 않고 키체인 소유권 비교에만 사용한다.
    static func bearerToken(from request: URLRequest) -> String? {
        guard let value = request.value(forHTTPHeaderField: "Authorization"),
              value.hasPrefix("Bearer ") else { return nil }
        return String(value.dropFirst("Bearer ".count))
    }

    /// URLSession.download/upload 경로도 JSON 요청과 같은 오류 계약을 사용합니다.
    @discardableResult
    static func validateAuthorizedResponse(
        _ response: URLResponse,
        errorBody: Data = Data(),
        requestToken: String?
    ) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw ServerAPIError(message: "서버 응답을 확인할 수 없습니다.", code: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let decoded = try? JSONDecoder().decode(ServerAPIError.self, from: errorBody)
            // 401 이라도 세션 만료가 아닌 경우가 있다(탈퇴 비밀번호 오류 = HTTP_401).
            // 세션을 끝내는 코드일 때만 토큰을 지운다.
            if http.statusCode == 401, isSessionEnding(code: decoded?.code) {
                if TokenBox.clear(ifMatches: requestToken) {
                    notifyAuthenticationExpired(message: decoded?.message)
                }
            }
            if var error = decoded {
                error.statusCode = http.statusCode
                throw error
            }
            throw ServerAPIError(
                message: "서버 응답 \(http.statusCode)",
                code: nil,
                statusCode: http.statusCode)
        }
        return http
    }

    static func request<T: Decodable>(_ method: String, _ path: String,
                                              body: [String: Any]?, authed: Bool,
                                              query: [String: String] = [:],
                                              headers: [String: String] = [:],
                                              authorization: AuthorizationSnapshot? = nil)
    async throws -> T {
        #if DEBUG
        // 데모 모드(서버 없이 UI 검토)는 여기서 끝낸다. 토큰 검사보다 **먼저** 걸어야
        // 로그인 없이도 서버 화면이 열린다. 준비 안 된 경로는 조용히 네트워크로 새지
        // 않고 알아볼 수 있는 오류로 실패한다(커버리지 구멍이 로그에 남는다).
        if DemoMode.isOn {
            if let canned: T = try DemoMode.canned(
                method: method, path: path, query: query, body: body) {
                return canned
            }
            throw DemoMode.missingFixture(method: method, path: path)
        }
        #endif
        // 질의 문자열은 URLComponents 로 붙인다 — path 에 "?" 를 끼워 넣으면
        // appendingPathComponent 가 %3F 로 이스케이프해 서버가 못 알아본다.
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty, var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = comps.url ?? url
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")
        for (name, value) in headers {
            req.setValue(value, forHTTPHeaderField: name)
        }
        let requestToken: String?
        if authed, let authorization {
            // 캡처 뒤 토큰이 바뀌었다면 네트워크를 시작하지 않는다. 여기서 최신 토큰을
            // 다시 채택하면 앞 계정의 큐가 새 계정 Bearer로 전송된다. 반대로 검사 뒤
            // 토큰이 바뀌어도 URLRequest에는 캡처한 옛 토큰만 들어가 교차 전송은 없다.
            guard let token = authorization.token,
                  TokenBox.load() == token else { throw CancellationError() }
            requestToken = token
        } else {
            requestToken = authed ? TokenBox.load() : nil
        }
        if authed, requestToken?.isEmpty != false {
            notifyAuthenticationExpired(
                message: "로그인이 만료되었습니다. 다시 로그인해주세요.")
            throw ServerAPIError(
                message: "로그인이 필요합니다.",
                code: "UNAUTHORIZED",
                statusCode: 401)
        }
        if let requestToken {
            req.setValue("Bearer \(requestToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let decoded = try? JSONDecoder().decode(ServerAPIError.self, from: data)
            // 401 이라도 세션 만료가 아닌 경우가 있다 — 탈퇴 비밀번호 오류는 서버가
            // HTTP_401 로 돌려준다. 미들웨어가 내는 UNAUTHORIZED / TOKEN_REVOKED
            // (또는 본문 없음)만 토큰을 지우고 로그아웃한다.
            if status == 401, isSessionEnding(code: decoded?.code) {
                if TokenBox.clear(ifMatches: requestToken) {
                    notifyAuthenticationExpired(message: decoded?.message)
                }
            }
            if var e = decoded {
                e.statusCode = status
                throw e
            }
            throw ServerAPIError(message: "서버 응답 \(status)", code: nil, statusCode: status)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// 401 중 실제로 세션을 끝내야 하는 코드만 고른다. requireApiAuth 미들웨어는
    /// UNAUTHORIZED / TOKEN_REVOKED 만 내고, 본문이 없는 401 은 프록시·구버전 서버로
    /// 간주해 종전처럼 만료로 다룬다. 그 외(HTTP_401 등)는 요청별 오류로 화면에 남긴다.
    private static func isSessionEnding(code: String?) -> Bool {
        code == nil || code == "UNAUTHORIZED" || code == "TOKEN_REVOKED"
    }

    private static func notifyAuthenticationExpired(message: String?) {
        let providerMessage = String(message ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // 서명키 회전·구형 토큰·키체인 유실은 학생이 구분하거나 복구할 수 없다.
        // 서버의 기계적인 "유효한 접근 토큰" 문구를 그대로 반복하지 않고 다음
        // 행동을 안내한다. 정지/철회처럼 서버가 준 구체적 이유는 보존한다.
        let userMessage = providerMessage.isEmpty
            || providerMessage == "로그인이 필요합니다."
            || providerMessage == "유효한 접근 토큰이 필요합니다."
            ? "로그인이 만료되었습니다. 다시 로그인해주세요."
            : providerMessage
        NotificationCenter.default.post(
            name: .matthsServerAuthenticationExpired,
            object: nil,
            userInfo: [
                "message": userMessage
            ])
    }
}

// MARK: - 키체인 토큰 보관 (UserDefaults 금지 — 설계서 규약)

private enum TokenBox {
    private static let account = "matths.apiToken"
    private static let lock = NSLock()
    private static var authenticationOwnership = ServerAuthenticationOwnership()

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrAccount as String: account,
         kSecAttrService as String: "kr.matths.app"]
    }

    static func beginAuthenticationAttempt() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        return authenticationOwnership.begin()
    }

    static func cancelAuthenticationAttempt(_ id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        authenticationOwnership.cancel(id)
    }

    static func save(_ token: String, for attemptID: UUID) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard authenticationOwnership.owns(attemptID) else { return false }

        let attributes = [kSecValueData as String: Data(token.utf8)]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = Data(token.utf8)
            insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(insertion as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            authenticationOwnership.cancel(attemptID)
            throw ServerAPIError(
                message: "로그인 정보를 안전하게 저장하지 못했습니다. 다시 시도해주세요.",
                code: "AUTH_TOKEN_STORAGE_FAILED")
        }
        return authenticationOwnership.complete(attemptID)
    }

    static func load() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnlocked()
    }

    private static func loadUnlocked() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        authenticationOwnership.reset()
        SecItemDelete(query as CFDictionary)
    }

    @discardableResult
    static func clear(ifMatches requestToken: String?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard ServerTokenOwnership.shouldClear(
            requestToken: requestToken,
            currentToken: loadUnlocked()) else { return false }
        SecItemDelete(query as CFDictionary)
        return true
    }
}
