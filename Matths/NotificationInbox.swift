//  NotificationInbox.swift
//  Matths
//
//  알림함 — 게시판 답글 알림·전체 공지·관리자 개별 안내·경고를 한 곳에 모은다.
//
//  왜 앱이 자기 모델을 갖는가. 서버에는 알림함이 **이미 있다**(UserNotification 컬렉션,
//  services/notificationService.js, /notifications 웹 페이지). 그런데 앱용 Bearer API
//  (routes/api-routes.js)에는 알림 경로가 **하나도 없다** — 아레나 조작과 같은 상황이다.
//  서버는 우리가 고치지 않으므로, 앱은
//    ① 서버 스키마를 그대로 옮긴 모델을 갖고
//    ② JSON 경로가 생기는 즉시 붙도록 요청 모양을 미리 맞춰 두고
//    ③ 그때까지는 마지막으로 받은 목록을 디스크에서 되살려 보여 준다
//  로 간다. 화면·배지·읽음 규칙을 서버가 준비될 때까지 미뤄 두면, 경로가 생긴 날
//  다시 처음부터 만들게 된다.
//
//  **문구 규칙**: 종류 이름(공지·경고·계정…)은 서버 kind 열거형과 1:1 이다.
//  앱에서 새 이름을 지어내면 같은 알림이 웹과 앱에서 다른 이름으로 읽힌다.

import Foundation
import SwiftUI

// MARK: - 종류

/// 서버 `userNotificationSchema.kind` 와 같은 집합.
///
/// `unknown` 은 서버에만 있는 안전장치다 — 서버가 종류를 하나 추가하는 순간
/// 앱의 디코딩이 통째로 실패해 **알림함이 빈 화면이 되는** 것을 막는다.
/// 모르는 종류는 일반 알림처럼 그리고 내용은 그대로 보여 준다.
enum MatthsNotificationKind: String, Codable, CaseIterable {
    case admin
    case system
    case warning
    case account
    case nickname
    case announcement
    case integrity
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MatthsNotificationKind(rawValue: raw) ?? .unknown
    }

    /// 화면에 뜨는 이름. 웹 알림함(views/notifications.ejs)의 어휘를 따른다.
    var label: String {
        switch self {
        case .admin:        return "관리자 안내"
        case .system:       return "시스템"
        case .warning:      return "경고"
        case .account:      return "계정"
        case .nickname:     return "닉네임"
        case .announcement: return "공지"
        case .integrity:    return "무결성"
        case .unknown:      return "알림"
        }
    }

    var icon: String {
        switch self {
        case .admin:        return "person.badge.shield.checkmark"
        case .system:       return "gearshape"
        case .warning:      return "exclamationmark.triangle.fill"
        case .account:      return "person.crop.circle.badge.exclamationmark"
        case .nickname:     return "textformat"
        case .announcement: return "megaphone.fill"
        case .integrity:    return "shield.lefthalf.filled"
        case .unknown:      return "bell"
        }
    }

    /// 놓치면 계정이 걸리는 종류. 서버가 `urgentUnread` 를 세는 집합과 **같아야 한다**
    /// (services/notificationService.js). 여기서 한 종류라도 어긋나면 앱 배지와
    /// 웹 배지가 다른 수를 말한다.
    var isUrgent: Bool {
        switch self {
        case .warning, .account, .nickname, .integrity: return true
        case .admin, .system, .announcement, .unknown:  return false
        }
    }

    var tint: Color {
        switch self {
        case .warning, .integrity: return Tokens.danger
        case .account, .nickname:  return Tokens.warning
        case .announcement:        return Tokens.actionPrimary
        case .admin:               return Tokens.primary
        case .system, .unknown:    return Tokens.text3
        }
    }
}

// MARK: - 알림 1건

struct MatthsNotification: Identifiable, Equatable, Codable {
    let id: String
    var title: String
    var message: String
    /// 서버가 정한 이동 경로(`/community/posts/…` 같은 앱-내 경로). 항상 `/` 로 시작한다.
    var href: String
    var kind: MatthsNotificationKind
    /// 아레나 우편함의 시각 우선순위. 일반 알림은 빈 값이다 — 앱은 표시에 쓰지 않고
    /// 서버가 붙인 값을 잃지 않기 위해서만 들고 있는다.
    var tone: String?
    var sourceType: String?
    var createdAt: Date
    var readAt: Date?

    var isRead: Bool { readAt != nil }
    var isUrgent: Bool { kind.isUrgent }

    // 서버는 createdAt/readAt 을 ISO8601 문자열로 준다. 밀리초가 붙기도 하고 안 붙기도
    // 해서 `.iso8601` 전략 하나로는 한쪽이 통째로 실패한다 — 문자열로 받아 직접 푼다.
    private enum CodingKeys: String, CodingKey {
        case id, title, message, href, kind, tone, sourceType, createdAt, readAt
    }

    init(id: String, title: String, message: String, href: String,
         kind: MatthsNotificationKind, tone: String? = nil, sourceType: String? = nil,
         createdAt: Date, readAt: Date? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.href = href
        self.kind = kind
        self.tone = tone
        self.sourceType = sourceType
        self.createdAt = createdAt
        self.readAt = readAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        message = try c.decode(String.self, forKey: .message)
        href = (try? c.decode(String.self, forKey: .href)) ?? "/main"
        kind = (try? c.decode(MatthsNotificationKind.self, forKey: .kind)) ?? .unknown
        tone = try? c.decode(String.self, forKey: .tone)
        sourceType = try? c.decode(String.self, forKey: .sourceType)
        createdAt = MatthsNotification.date(try? c.decode(String.self, forKey: .createdAt))
            ?? Date(timeIntervalSince1970: 0)
        readAt = MatthsNotification.date(try? c.decode(String.self, forKey: .readAt))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(message, forKey: .message)
        try c.encode(href, forKey: .href)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encodeIfPresent(tone, forKey: .tone)
        try c.encodeIfPresent(sourceType, forKey: .sourceType)
        try c.encode(MatthsNotification.stamp.string(from: createdAt), forKey: .createdAt)
        try c.encodeIfPresent(readAt.map(MatthsNotification.stamp.string(from:)), forKey: .readAt)
    }

    private static let stamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// 밀리초가 붙은 것과 안 붙은 것을 모두 받는다 (SyncEngine 과 같은 규칙).
    private static func date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return stamp.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

// MARK: - 서버 응답

struct MatthsNotificationInbox: Codable, Equatable {
    struct Stats: Codable, Equatable {
        var total: Int = 0
        var unread: Int = 0
        var urgentUnread: Int = 0
    }

    struct Pagination: Codable, Equatable {
        var page: Int = 1
        var totalPages: Int = 1
        var hasNext: Bool = false
    }

    var notifications: [MatthsNotification] = []
    var stats: Stats = .init()
    var pagination: Pagination = .init()
}

// MARK: - 저장소

/// 알림함의 유일한 상태 소유자.
///
/// 화면이 여럿(상단 종 배지, 알림함 목록, 상세)이라 각자 불러오면 배지와 목록이
/// 서로 다른 수를 말한다. 하나만 두고 화면들이 구독한다.
@MainActor
final class NotificationInboxStore: ObservableObject {
    static let shared = NotificationInboxStore()

    /// 서버에 알림 JSON 경로가 아직 없을 때의 상태. 오류 벽을 세우지 않고
    /// **무슨 일인지 한 줄로 말하는** 데 쓴다 — 학생에게는 "준비 중" 이지 고장이 아니다.
    enum Availability: Equatable {
        case unknown
        case ready
        /// 서버가 이 경로를 모른다(404/501). 앱 잘못이 아니다.
        case serverRouteMissing
        /// 그 밖의 실패(네트워크·인증). 메시지를 그대로 보여 준다.
        case failed(String)
    }

    @Published private(set) var notifications: [MatthsNotification] = []
    @Published private(set) var stats = MatthsNotificationInbox.Stats()
    @Published private(set) var pagination = MatthsNotificationInbox.Pagination()
    @Published private(set) var availability: Availability = .unknown
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    /// 마지막으로 서버와 맞춘 시각. nil 이면 이번 실행에서 한 번도 못 맞췄다는 뜻이고,
    /// 화면은 그때 "저장된 목록" 이라고 밝힌다 — 오래된 목록을 새 것처럼 보이지 않게.
    @Published private(set) var syncedAt: Date?

    private var loadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
    /// Task.cancel() 직후 새 요청을 시작하면 이전 Task의 defer가 나중에 돌아와 새
    /// 로딩 표시를 끌 수 있다. 세대가 같은 작업만 상태를 끝내고 응답을 반영한다.
    private var loadGeneration = UUID()
    private var loadMoreGeneration = UUID()
    /// 모두 읽음 POST와 뒤따르는 GET의 도착 순서가 뒤집혀도, 사용자가 방금 읽은
    /// 알림을 다음 페이지가 다시 미읽음으로 만들지 않게 하는 낙관적 기준 시각이다.
    /// 서버가 unread=0을 확인해 주면 없애고, 계정 전환 때는 즉시 폐기한다.
    private var optimisticReadAllAt: Date?

    private init() {
        notifications = NotificationInboxDisk.load()
        stats = NotificationInboxStore.recount(notifications)
    }

    var unreadCount: Int { stats.unread }
    var urgentUnreadCount: Int { stats.urgentUnread }
    var totalCount: Int { max(stats.total, notifications.count) }
    var hasMore: Bool { pagination.hasNext }

    /// 배지에 찍을 수. 세 자리가 넘으면 배지가 탭바를 밀어내므로 상한을 둔다.
    var badgeText: String? {
        guard unreadCount > 0 else { return nil }
        return unreadCount > 99 ? "99+" : "\(unreadCount)"
    }

    // MARK: 불러오기

    func refresh(force: Bool = false) {
        guard ServerAPI.hasToken,
              let authorization = ServerAPI.captureAuthorization() else {
            loadTask?.cancel()
            loadMoreTask?.cancel()
            loadGeneration = UUID()
            loadMoreGeneration = UUID()
            notifications = []
            stats = .init()
            pagination = .init()
            availability = .unknown
            isLoading = false
            isLoadingMore = false
            optimisticReadAllAt = nil
            return
        }
        if !force, isLoading { return }
        loadTask?.cancel()
        loadMoreTask?.cancel()
        let generation = UUID()
        loadGeneration = generation
        loadMoreGeneration = UUID()
        isLoadingMore = false
        loadTask = Task { [weak self] in
            await self?.load(authorization: authorization, generation: generation)
        }
    }

    private func load(
        authorization: ServerAPI.AuthorizationSnapshot,
        generation: UUID
    ) async {
        isLoading = true
        defer {
            if loadGeneration == generation { isLoading = false }
        }
        do {
            let inbox = try await ServerAPI.notificationInbox(authorization: authorization)
            guard !Task.isCancelled, loadGeneration == generation else { return }
            var received = inbox.notifications
            if let readAt = optimisticReadAllAt, inbox.stats.unread > 0 {
                for index in received.indices where received[index].readAt == nil {
                    received[index].readAt = readAt
                }
            } else if inbox.stats.unread == 0 {
                optimisticReadAllAt = nil
            }
            notifications = received
            // 서버가 준 stats 를 그대로 믿되, 빈 값으로 오면 목록에서 다시 센다 —
            // 배지가 0 인데 안 읽은 알림이 보이는 모순을 만들지 않는다.
            if optimisticReadAllAt != nil {
                stats = .init(total: max(inbox.stats.total, received.count), unread: 0, urgentUnread: 0)
            } else {
                stats = inbox.stats.total > 0 ? inbox.stats : NotificationInboxStore.recount(received)
            }
            pagination = inbox.pagination
            availability = .ready
            syncedAt = Date()
            NotificationInboxDisk.save(notifications)
        } catch let error as ServerAPIError {
            guard !Task.isCancelled else { return }
            // 404/501 = 서버에 아직 그 경로가 없다. 학생 잘못도 앱 고장도 아니므로
            // 저장된 목록을 지우지 않고 그대로 둔다.
            if error.statusCode == 404 || error.statusCode == 501 {
                availability = .serverRouteMissing
            } else {
                availability = .failed(error.errorDescription ?? "알림을 불러오지 못했습니다.")
            }
        } catch {
            guard !Task.isCancelled else { return }
            availability = .failed("알림을 불러오지 못했습니다.")
        }
    }

    /// 다음 페이지를 현재 목록 뒤에 붙인다. 서버가 같은 알림을 경계 페이지에 다시
    /// 포함해도 id로 한 번만 남기고, 전체 미읽음 통계는 서버 값을 유지한다.
    func loadMore() {
        guard ServerAPI.hasToken, pagination.hasNext,
              !isLoading, !isLoadingMore,
              let authorization = ServerAPI.captureAuthorization() else { return }
        isLoadingMore = true
        let nextPage = pagination.page + 1
        loadMoreTask?.cancel()
        let generation = UUID()
        loadMoreGeneration = generation
        loadMoreTask = Task { [weak self] in
            await self?.loadMore(
                page: nextPage,
                authorization: authorization,
                generation: generation)
        }
    }

    private func loadMore(
        page: Int,
        authorization: ServerAPI.AuthorizationSnapshot,
        generation: UUID
    ) async {
        defer {
            if loadMoreGeneration == generation { isLoadingMore = false }
        }
        do {
            let inbox = try await ServerAPI.notificationInbox(
                page: page,
                authorization: authorization)
            guard !Task.isCancelled, loadMoreGeneration == generation else { return }
            var known = Set(notifications.map(\.id))
            var received = inbox.notifications
            if let readAt = optimisticReadAllAt {
                for index in received.indices where received[index].readAt == nil {
                    received[index].readAt = readAt
                }
            }
            notifications.append(contentsOf: received.filter { known.insert($0.id).inserted })
            pagination = inbox.pagination
            // 전체 stats는 첫 페이지에서 받은 값이다. 한 건 읽음 요청과 다음 페이지
            // 요청이 겹칠 때 오래된 서버 응답으로 낙관적 차감값을 되돌리지 않는다.
            availability = .ready
            syncedAt = Date()
            NotificationInboxDisk.save(notifications)
        } catch let error as ServerAPIError {
            guard !Task.isCancelled else { return }
            availability = .failed(error.errorDescription ?? "알림을 더 불러오지 못했습니다.")
        } catch {
            guard !Task.isCancelled else { return }
            availability = .failed("알림을 더 불러오지 못했습니다.")
        }
    }

    // MARK: 읽음

    /// 한 건 읽음. 화면을 먼저 바꾸고 서버에 알린다 — 왕복을 기다리면 탭이 굼떠 보인다.
    /// 서버가 실패해도 되돌리지 않는다: 읽음은 학생이 실제로 열었다는 사실이고,
    /// 다음 동기화에서 서버 값이 이긴다.
    func markRead(_ id: String) {
        guard let index = notifications.firstIndex(where: { $0.id == id }),
              notifications[index].readAt == nil else { return }
        let wasUrgent = notifications[index].isUrgent
        notifications[index].readAt = Date()
        // stats는 아직 내려받지 않은 페이지까지 포함한다. 현재 배열만 다시 세면
        // 21번째 이후 미읽음이 배지에서 사라지므로 실제 읽은 한 건만 차감한다.
        stats.unread = max(0, stats.unread - 1)
        if wasUrgent { stats.urgentUnread = max(0, stats.urgentUnread - 1) }
        NotificationInboxDisk.save(notifications)
        if let authorization = ServerAPI.captureAuthorization() {
            Task {
                try? await ServerAPI.markNotificationRead(
                    id: id,
                    authorization: authorization)
            }
        }
    }

    func markAllRead() {
        let now = Date()
        var changed = false
        let hadServerUnread = stats.unread > 0
        for index in notifications.indices where notifications[index].readAt == nil {
            notifications[index].readAt = now
            changed = true
        }
        // 현재 받은 페이지가 전부 읽음이어도 더 오래된 페이지에 미읽음이 있으면
        // 서버의 전체 읽음 API는 호출해야 한다.
        guard changed || hadServerUnread else { return }
        optimisticReadAllAt = now
        stats.unread = 0
        stats.urgentUnread = 0
        NotificationInboxDisk.save(notifications)
        if let authorization = ServerAPI.captureAuthorization() {
            Task {
                try? await ServerAPI.markAllNotificationsRead(
                    authorization: authorization)
            }
        }
    }

    /// 로그아웃·계정 전환. 남겨 두면 다음 사람이 남의 알림을 본다.
    func clear() {
        clear(slot: DataScope.slot)
    }

    /// DataScope가 바뀌기 전 붙잡은 owner slot을 지운다. 알림 파일은 Documents가
    /// 아닌 Application Support에 있어 계정 디렉터리 purge만으로는 없어지지 않는다.
    func clear(slot: String) {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        loadGeneration = UUID()
        loadMoreGeneration = UUID()
        if slot == DataScope.slot {
            notifications = []
            stats = .init()
            pagination = .init()
            availability = .unknown
            isLoading = false
            isLoadingMore = false
            optimisticReadAllAt = nil
            syncedAt = nil
        }
        NotificationInboxDisk.clear(slot: slot)
    }

    /// 슬롯 전환 직후 새 계정의 캐시만 다시 읽는다. 서버 refresh 전 짧은 순간에도
    /// 앞 계정 알림이 화면·배지에 남지 않게 한다.
    func reloadForCurrentSlot() {
        loadTask?.cancel()
        loadMoreTask?.cancel()
        loadGeneration = UUID()
        loadMoreGeneration = UUID()
        notifications = NotificationInboxDisk.load()
        stats = NotificationInboxStore.recount(notifications)
        pagination = .init()
        availability = .unknown
        isLoading = false
        isLoadingMore = false
        optimisticReadAllAt = nil
        syncedAt = nil
    }

    private static func recount(_ list: [MatthsNotification]) -> MatthsNotificationInbox.Stats {
        MatthsNotificationInbox.Stats(
            total: list.count,
            unread: list.filter { !$0.isRead }.count,
            urgentUnread: list.filter { !$0.isRead && $0.isUrgent }.count)
    }
}

// MARK: - 디스크

/// 마지막으로 본 알림 목록.
///
/// 왜 저장하나 — 경고나 계정 안내는 **놓치면 안 되는 글**이다. 앱을 껐다 켤 때마다
/// 목록이 비어 있고 네트워크가 끊겨 있으면, 학생은 경고를 받은 사실 자체를 모른다.
/// 계정별로 나눠 담는다(DataScope.slot) — 한 기기를 형제가 같이 쓰는 경우가 있다.
enum NotificationInboxDisk {
    private static let limit = 200

    private static func url(for slot: String) -> URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("notifications-\(slot).json")
    }

    static func load() -> [MatthsNotification] {
        guard let url = url(for: DataScope.slot),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([MatthsNotification].self, from: data)) ?? []
    }

    static func save(_ list: [MatthsNotification]) {
        guard let url = url(for: DataScope.slot) else { return }
        let trimmed = Array(list.prefix(limit))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        clear(slot: DataScope.slot)
    }

    static func clear(slot: String) {
        guard let url = url(for: slot) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - 서버 경로
//
// 왜 ServerAPI.swift 가 아니라 여기인가 — 계약 테스트(run-sync-contract.sh 등)는
// ServerAPI.swift 를 **일부 파일만 골라 swiftc 로 실제 컴파일**한다. 알림함 타입을
// ServerAPI.swift 안에서 참조하면 그 테스트가 "타입을 찾을 수 없다" 로 죽는다.
// 기능을 쓰는 쪽이 자기 경로를 들고 있으면 그 결합이 생기지 않는다.

extension ServerAPI {
    // MARK: 알림함 (NotificationInbox.swift)
    //
    // 서버 routes/api-routes.js의 Bearer 경로가 웹 알림함과 같은
    // notificationService를 감싼다. 페이지·읽음·긴급 통계의 정본은 서버 한 벌이다.

    static func notificationInbox(
        page: Int = 1,
        authorization: AuthorizationSnapshot
    ) async throws -> MatthsNotificationInbox {
        try await request("GET", "/api/v1/notifications", body: nil, authed: true,
                          query: page > 1 ? ["page": "\(page)"] : [:],
                          authorization: authorization)
    }

    static func markNotificationRead(
        id: String,
        authorization: AuthorizationSnapshot
    ) async throws {
        struct Empty: Codable {}
        let escaped = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let _: Empty = try await request("POST", "/api/v1/notifications/\(escaped)/read",
                                         body: nil, authed: true,
                                         authorization: authorization)
    }

    static func markAllNotificationsRead(
        authorization: AuthorizationSnapshot
    ) async throws {
        struct Empty: Codable {}
        let _: Empty = try await request("POST", "/api/v1/notifications/read-all",
                                         body: nil, authed: true,
                                         authorization: authorization)
    }
}
