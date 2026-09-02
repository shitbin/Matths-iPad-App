import Foundation

/// 서버가 소유하는 시험 상태를 화면 분기로 옮기는 순수 정책.
/// 네트워크 모델과 SwiftUI를 분리해 첫 응시/종결 상태 회귀를 독립 검증한다.
enum LearningEntryStatePolicy {
    static func isWeeklyMockLobby(_ state: String) -> Bool {
        state == "lobby" || state == "not-started"
    }

    static func canStartPlacement(_ status: String) -> Bool {
        status == "not-started" || status == "available"
    }
}
