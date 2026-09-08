import SwiftUI

/// Compact tabs and the iPad sidebar identify the same actual destinations.
/// Legacy-only tools are deliberately not mislabeled as a current tab.
struct TutorialNavigationAnchor: ViewModifier {
    let route: AppStore.Route
    private var target: TutorialTargetID? {
        switch route {
        case .home: .tabToday
        case .learn, .curriculum: .tabLearning
        case .rank: .tabArena
        case .records, .wrongNotes: .tabRecords
        case .me, .profile: .tabMe
        default: nil
        }
    }
    @ViewBuilder func body(content: Content) -> some View {
        if let target { content.tutorialTarget(target) }
        else { content }
    }
}
