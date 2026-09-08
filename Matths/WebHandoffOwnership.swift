import Foundation

final class WebAccountObserverBag: @unchecked Sendable {
    // Installed by one main-actor owner; NotificationCenter removal is safe on
    // deinit's thread and does not leave dead weak-self closures registered.
    var tokens: [NSObjectProtocol] = []
    deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
}

/// Value-level authority shared by hosted web models. A URL response belongs to
/// one account slot, one request generation and one concrete WKWebView object.
struct WebHandoffOwnership {
    struct Ticket: Sendable {
        let generation: UUID
        let requestID: UUID
        let slot: String
        let viewIdentity: ObjectIdentifier
    }
    private var generation = UUID()
    private var requestID: UUID?

    mutating func begin(slot: String, viewIdentity: ObjectIdentifier) -> Ticket {
        let id = UUID()
        requestID = id
        return Ticket(generation: generation, requestID: id, slot: slot, viewIdentity: viewIdentity)
    }

    mutating func invalidate() { generation = UUID(); requestID = nil }

    func owns(_ ticket: Ticket, slot: String, viewIdentity: ObjectIdentifier) -> Bool {
        generation == ticket.generation && requestID == ticket.requestID
            && slot == ticket.slot && viewIdentity == ticket.viewIdentity
    }

    static func validatedURL(_ raw: String, base: URL) -> URL? {
        guard let allowedHost = base.host?.lowercased(), !allowedHost.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              url.host?.lowercased() == allowedHost,
              (url.port ?? 443) == (base.port ?? 443),
              url.path.hasPrefix("/app/commerce/"), url.path != "/app/commerce/" else { return nil }
        guard !url.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        return url
    }
}

#if canImport(WebKit)
import WebKit

/// Both web models share WebKit's cookie store. A newer handoff must not race an
/// older account's asynchronous cookie purge and lose its newly minted session.
@MainActor
enum HostedWebCookieReset {
    private static var flights: [String: (id: UUID, task: Task<Void, Never>)] = [:]
    static func reset(host: String) async {
        await beginReset(host: host).value
    }
    static func beginReset(host: String) -> Task<Void, Never> {
        let key = MatthsServiceURLPolicy.cookieResetKey(for: host)
        if let running = flights[key] { return running.task }
        let id = UUID()
        let task = Task { @MainActor in
            let store = WKWebsiteDataStore.default().httpCookieStore
            let cookies = await store.allCookies()
            for cookie in cookies {
                if MatthsServiceURLPolicy.ownsCookie(domain: cookie.domain, baseHost: host) {
                    await store.deleteCookie(cookie)
                }
            }
            if flights[key]?.id == id { flights[key] = nil }
        }
        flights[key] = (id, task)
        return task
    }
}
#endif
