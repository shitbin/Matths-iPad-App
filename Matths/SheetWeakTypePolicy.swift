import Foundation

/// A recognized type alone is not evidence that a student is weak at it.
/// Summaries may order grounded findings, but may not invent new weaknesses.
enum SheetWeakTypePolicy {
    struct Evidence {
        let type: ProblemType?
        let status: String
        let topic: String
        let statement: String
        let statementUncertain: Bool
        let stuckAt: String?
        let errorWhy: String?
    }

    static func resolve(items: [Evidence], summaryTypes: [ProblemType]) -> [ProblemType] {
        let grounded = items.compactMap { item -> ProblemType? in
            guard let type = item.type, !item.statementUncertain,
                  ["calc-slip", "concept-error", "strategy-stuck"].contains(item.status),
                  !item.statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  hasMeaningfulEvidence(item.stuckAt) || hasMeaningfulEvidence(item.errorWhy),
                  !hasKnownTypeConflict(type, topic: item.topic) else { return nil }
            return type
        }
        let allowed = Set(grounded.map(\.rawValue))
        var seen = Set<String>()
        return (summaryTypes.filter { allowed.contains($0.rawValue) } + grounded)
            .filter { seen.insert($0.rawValue).inserted }
    }

    private static func hasMeaningfulEvidence(_ value: String?) -> Bool {
        guard let value else { return false }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 4 else { return false }
        let normalized = String(cleaned.lowercased().filter { !$0.isWhitespace })
            .trimmingCharacters(in: .punctuationCharacters)
        let absent: Set<String> = ["unknown", "null", "none", "n/a", "없음", "해당없음", "알수없음"]
        guard !absent.contains(normalized) else { return false }
        return !["판독불가", "판독불확실", "분석보류", "확인필요", "알수없"].contains { normalized.contains($0) }
    }

    /// Observed contradiction, not an invented replacement classification.
    /// A linear-equation topic paired with a quadratic-discriminant key cannot
    /// safely choose a new quiz. Other topic/type semantics remain unverified.
    private static func hasKnownTypeConflict(_ type: ProblemType, topic: String) -> Bool {
        guard type == .quadDisc else { return false }
        let compact = String(topic.filter { !$0.isWhitespace })
        let linear = compact.contains("일차") || (compact.contains("선형") && !compact.contains("비선형"))
        return linear && !compact.contains("이차")
    }
}
