import SwiftUI

/// Uses the existing native features and their fresh server checks. No browser
/// handoff and no automatic start/submit command is introduced by Today.
struct TodayActivityDestination: View {
    let action: TodayActionCandidate
    let close: () -> Void
    @EnvironmentObject private var store: AppStore
    @State private var slot = DataScope.slot
    var body: some View {
        Group {
            switch action.destination {
            case .weeklyMock(let id): WeeklyMockScreen(initialExamID: id)
            case .arena(let id): GoatArenaMatchPlayScreen(matchId: id)
            case .academyWeek(let id): AcademyScreen(initialWeekID: id)
            default: Text("이 학습을 열 수 없습니다.").font(.mBody)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button("오늘로 돌아가기", action: close).font(.mCallout).frame(minHeight: 44)
                Spacer()
            }.padding(.horizontal, Tokens.Space.s4).background(Tokens.surface)
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            if DataScope.slot != slot { close() }
        }
    }
}
