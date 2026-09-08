import Foundation

@main struct ArenaMatchEntryCases {
    static func main() {
        var count = 0
        func expect(_ value: Bool) { precondition(value); count += 1 }
        for role in ["DEFENDER", "CHALLENGER", "UNKNOWN"] {
            for status in ["MATCHED", "READY", "IN_PROGRESS", "SUBMITTED", "HELD", "SETTLED", "REQUESTED"] {
                for attempt in [nil, "READY", "IN_PROGRESS", "SUBMITTED", "EVIDENCE_REQUIRED"] as [String?] {
                    for integrity in ["PENDING", "CLEAR", "HELD", "REJECTED"] {
                        for fresh in [true, false] {
                            let expected = fresh && role != "UNKNOWN" && ["MATCHED", "READY"].contains(status)
                                && (attempt == nil || attempt == "READY") && ["PENDING", "CLEAR"].contains(integrity)
                            expect(ArenaMatchEntryPolicy.canInspectReadyMatch(id: "match-01", role: role,
                                status: status, attemptStatus: attempt, integrity: integrity, fresh: fresh) == expected)
                        }
                    }
                }
            }
        }
        for id in [nil, "", "a/b", "a?b", "a#b", "a%2fb", String(repeating: "a", count: 129)] as [String?] {
            expect(!ArenaMatchEntryPolicy.canInspectReadyMatch(id: id, role: "DEFENDER", status: "MATCHED",
                                                             attemptStatus: "READY", integrity: "CLEAR", fresh: true))
        }
        expect(ArenaMatchEntryPolicy.title(role: "DEFENDER", attemptStatus: "READY", evidenceRequired: false) == "방어전 열기")
        expect(ArenaMatchEntryPolicy.title(role: "DEFENDER", attemptStatus: "IN_PROGRESS", evidenceRequired: false) == "방어전 이어하기")
        expect(ArenaMatchEntryPolicy.title(role: "CHALLENGER", attemptStatus: nil, evidenceRequired: false) == "공격전 열기")
        expect(ArenaMatchEntryPolicy.title(role: "CHALLENGER", attemptStatus: "IN_PROGRESS", evidenceRequired: false) == "공격전 이어하기")
        expect(ArenaMatchEntryPolicy.title(role: "DEFENDER", attemptStatus: "EVIDENCE_REQUIRED", evidenceRequired: true) == "풀이 증거 제출하기")
        for actions in [nil, [], ["START"], ["ACCEPT", "DECLINE"], ["SUBMIT"], ["UNKNOWN"]] as [[String]?] {
            expect(!ArenaMatchEntryPolicy.permitsStart(actions: actions, hasContract: false))
            expect(ArenaMatchEntryPolicy.permitsStart(actions: actions, hasContract: true)
                   == (actions == nil || actions!.contains("START")))
        }
        print("Arena lobby entry and explicit start authority: \(count) checks PASS")
    }
}
