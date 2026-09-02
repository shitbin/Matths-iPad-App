#if DEBUG
import Foundation

extension DemoArenaFixtures {
    static func friendlyOptions(query: String) -> String {
        let safeQuery = DemoRouter.escaped(query)
        let results = query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
            ? #"[{"userId":"demo-friendly-user-01","nickname":"민서수학","tier":"PLATINUM","availableLearningDays":11}]"#
            : "[]"
        return #"""
        {
          "schemaVersion":"GOAT_ARENA_MAIN_FRIENDLY_V1",
          "query":"\#(safeQuery)",
          "eligible":true,
          "eligibilityReason":"",
          "feeDays":1,
          "hasActiveMatch":false,
          "searchResults":\#(results),
          "receivedInvitations":[{"id":"demo-friendly-received-01","status":"PENDING","counterpartNickname":"도현","feeDays":1,"createdAt":"@T-2h@","expiresAt":"@T+22h@"}],
          "sentInvitations":[{"id":"demo-friendly-sent-01","status":"PENDING","counterpartNickname":"서연","feeDays":1,"createdAt":"@T-1h@","expiresAt":"@T+23h@"}]
        }
        """#
    }

    static let friendlyInvitationCreated = #"""
    {"kind":"INVITATION","match":null,"invitation":{"id":"demo-friendly-created-01","status":"PENDING","counterpartNickname":"민서수학","feeDays":1,"createdAt":"@T+0s@","expiresAt":"@T+24h@"}}
    """#

    static func friendlyInvitationResponded(id: String, response: String) -> String {
        let safeId = DemoRouter.escaped(id)
        if response.uppercased() == "ACCEPT" {
            return #"{"kind":"MATCH","match":{"id":"demo-friendly-match-01","status":"READY","integrityState":"PENDING"},"invitation":null}"#
        }
        return #"{"kind":"INVITATION","match":null,"invitation":{"id":"\#(safeId)","status":"DECLINED","counterpartNickname":"도현","feeDays":1,"createdAt":"@T-2h@","expiresAt":"@T+22h@"}}"#
    }

    static func friendlyInvitationCancelled(id: String) -> String {
        let safeId = DemoRouter.escaped(id)
        return #"{"kind":"INVITATION","match":null,"invitation":{"id":"\#(safeId)","status":"CANCELLED","counterpartNickname":"서연","feeDays":1,"createdAt":"@T-1h@","expiresAt":"@T+23h@"}}"#
    }
}
#endif
