import Foundation

@main
enum LearningEntryStateCases {
    static func main() {
        precondition(LearningEntryStatePolicy.isWeeklyMockLobby("lobby"))
        precondition(LearningEntryStatePolicy.isWeeklyMockLobby("not-started"))
        precondition(!LearningEntryStatePolicy.isWeeklyMockLobby("in-progress"))

        precondition(LearningEntryStatePolicy.canStartPlacement("not-started"))
        precondition(LearningEntryStatePolicy.canStartPlacement("available"))
        precondition(!LearningEntryStatePolicy.canStartPlacement("attempt-used"))
        precondition(!LearningEntryStatePolicy.canStartPlacement("submitted"))
        print("Learning entry state cases passed.")
    }
}
