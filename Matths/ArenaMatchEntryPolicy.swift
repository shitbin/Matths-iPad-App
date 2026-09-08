import Foundation

/// Opening a pre-start lobby is a read, not accepting an invitation or starting
/// the clock. The detail response remains the authority for the actual start.
enum ArenaMatchEntryPolicy {
    static func canInspectReadyMatch(id: String?, role: String, status: String,
                                    attemptStatus: String?, integrity: String, fresh: Bool) -> Bool {
        guard fresh, let id, !id.isEmpty, id.utf8.count <= 128,
              id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).contains($0) }),
              ["CHALLENGER", "DEFENDER"].contains(role),
              ["MATCHED", "READY"].contains(status),
              ["PENDING", "CLEAR"].contains(integrity) else { return false }
        return attemptStatus == nil || attemptStatus == "READY"
    }

    static func title(role: String, attemptStatus: String?, evidenceRequired: Bool) -> String {
        if evidenceRequired { return "풀이 증거 제출하기" }
        let game = role == "DEFENDER" ? "방어전" : role == "CHALLENGER" ? "공격전" : "경기"
        return attemptStatus == "IN_PROGRESS" ? "\(game) 이어하기" : "\(game) 열기"
    }

    static func permitsStart(actions: [String]?, hasContract: Bool) -> Bool {
        // Older contracts did not expose capabilities. Preserve their existing
        // explicit confirmation flow; an explicit empty/new denial never falls back.
        hasContract && (actions.map { $0.contains("START") } ?? true)
    }
}
