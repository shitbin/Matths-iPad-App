import Foundation

/// Canonical origins from web serviceUrlService/serviceHostRouting (9dd2484).
/// This policy is for web navigation only: it never authorizes Bearer API
/// redirects or widens the one-time commerce handoff issuer's exact origin.
enum MatthsServiceURLPolicy {
    enum Surface: String, CaseIterable { case publicSite, app, academy, admin, parents }
    private static let canonicalHosts: [Surface: String] = [
        .publicSite: "www.matths.kr", .app: "app.matths.kr",
        .academy: "academy.matths.kr", .admin: "admin.matths.kr",
        .parents: "parents.matths.kr"
    ]
    // The apex is an explicit 308 alias in canonicalHost.js, not a suffix rule.
    private static let productionHosts = Set(canonicalHosts.values).union(["matths.kr"])

    private static func cleanOrigin(_ url: URL) -> Bool {
        guard url.user == nil, url.password == nil,
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
    private static func isProductionBase(_ base: URL) -> Bool {
        cleanOrigin(base) && base.scheme?.lowercased() == "https"
            && (base.port ?? 443) == 443
            && productionHosts.contains(base.host?.lowercased() ?? "")
    }
    static func isTrustedNavigationURL(_ url: URL, base: URL) -> Bool {
        guard cleanOrigin(url), cleanOrigin(base),
              let host = url.host?.lowercased(), let baseHost = base.host?.lowercased() else { return false }
        if isProductionBase(base) {
            return url.scheme?.lowercased() == "https" && (url.port ?? 443) == 443
                && productionHosts.contains(host)
        }
        // A test/private deployment never inherits trust in production domains.
        guard host == baseHost, url.scheme?.lowercased() == base.scheme?.lowercased(),
              (url.port ?? 443) == (base.port ?? 443) else { return false }
        if url.scheme?.lowercased() == "https" { return true }
        #if DEBUG
        return url.scheme?.lowercased() == "http" && ["localhost", "127.0.0.1", "[::1]", "::1"].contains(host)
        #else
        return false
        #endif
    }
    /// Do not turn HTTP/user-info/nonstandard-port variants of our domains into
    /// external browser escapes around the authenticated navigation/purchase gate.
    static func isUnsafeServiceURL(_ url: URL, base: URL) -> Bool {
        guard let host = url.host?.lowercased(), let baseHost = base.host?.lowercased() else { return false }
        let related = isProductionBase(base) ? productionHosts.contains(host) : host == baseHost
        return related && !isTrustedNavigationURL(url, base: base)
    }
    static func serviceURL(for surface: Surface, path: String, base: URL) -> URL? {
        guard path.hasPrefix("/"), !path.hasPrefix("//"), !path.contains("\\"),
              !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return nil }
        var origin = URLComponents()
        if isProductionBase(base), let host = canonicalHosts[surface] {
            origin.scheme = "https"; origin.host = host
        } else {
            guard isTrustedNavigationURL(base, base: base) else { return nil }
            origin.scheme = base.scheme; origin.host = base.host; origin.port = base.port
        }
        guard let originURL = origin.url,
              let result = URL(string: path, relativeTo: originURL)?.absoluteURL,
              result.scheme?.lowercased() == originURL.scheme?.lowercased(),
              result.host?.lowercased() == originURL.host?.lowercased(),
              (result.port ?? 443) == (originURL.port ?? 443),
              result.user == nil, result.password == nil else { return nil }
        return result
    }
    static func isParentAccountPath(_ path: String) -> Bool {
        let normalized = path.lowercased()
        return normalized == "/parent" || normalized.hasPrefix("/parent/")
    }
    static func cookieResetKey(for host: String) -> String {
        let normalized = host.lowercased()
        return productionHosts.contains(normalized) ? "matths.kr" : normalized
    }
    static func ownsCookie(domain: String, baseHost: String) -> Bool {
        let domain = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let baseHost = baseHost.lowercased()
        guard !domain.isEmpty, !baseHost.isEmpty else { return false }
        if productionHosts.contains(baseHost) {
            // Shared .matths.kr and old host-only sessions must all be retired.
            // Unlisted sibling domains are not part of this app's cookie scope.
            return productionHosts.contains(domain)
        }
        return domain == baseHost || baseHost.hasSuffix("." + domain)
    }
}
