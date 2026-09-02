#if DEBUG
import Foundation

extension DemoArenaFixtures {
    static let revengeRight = #"""
    {
      "schemaVersion":"GOAT_ARENA_REVENGE_RIGHT_V1",
      "right":{
        "id":"demo-revenge-right-01",
        "division":"MAIN",
        "stakeDays":3,
        "feeDays":1,
        "expiresAt":"@T+72h@",
        "createdAt":"@T-2h@"
      }
    }
    """#

    static func revengeClaimed(id: String) -> String {
        #"{"kind":"MATCH","match":{"id":"demo-revenge-match-01","status":"READY","integrityState":"PENDING"},"replayed":false}"#
    }

    static func revengeForfeited(id: String) -> String {
        let safeId = DemoRouter.escaped(id)
        return #"{"kind":"REVENGE_FORFEIT","rightId":"\#(safeId)","sourceMatchId":"demo-source-match-01","replayed":false}"#
    }

    static func supplementalRequest(matchId: String) -> String {
        let safeId = DemoRouter.escaped(matchId)
        return #"""
        {
          "schemaVersion":"GOAT_ARENA_SUPPLEMENTAL_EVIDENCE_V1",
          "request":{
            "matchId":"\#(safeId)",
            "division":"MAIN",
            "matchType":"RANKED",
            "role":"CHALLENGER",
            "status":"REQUESTED",
            "requestedAt":"@T-1h@",
            "deadlineAt":"@T+23h@",
            "requestMessage":"풀이 과정이 보이는 원본 사진을 추가로 제출해주세요.",
            "submittedAt":null,
            "submittedLate":false,
            "lateByMs":0,
            "fileCount":0,
            "serverNow":"@T+0s@"
          }
        }
        """#
    }

    static let supplementalSubmission = #"""
    {
      "schemaVersion":"GOAT_ARENA_SUPPLEMENTAL_EVIDENCE_V1",
      "submission":{
        "replayed":false,
        "status":"SUBMITTED",
        "submittedAt":"@T+0s@",
        "submittedLate":false,
        "lateByMs":0,
        "fileCount":1
      }
    }
    """#
}
#endif
