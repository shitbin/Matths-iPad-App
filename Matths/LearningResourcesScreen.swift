import SwiftUI

/// One directory for secondary resources. Academy, purchases and account
/// support remain on Me instead of being repeated here a second time.
struct LearningResourcesScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.matthsBrowseViewportSize) private var viewport
    @Environment(\.dynamicTypeSize) private var typeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Tokens.Space.s4),
              count: viewport.width >= 700 && !typeSize.isAccessibilitySize ? 2 : 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("학습 도구와 자료").font(.mTitle).accessibilityAddTraits(.isHeader)
                Text("필요한 자료를 찾거나, 막힌 문제를 함께 해결하세요.")
                    .font(.mCallout).foregroundStyle(Tokens.text2)
            }
            section("공부에 필요한 도구", items: [.coach, .archive, .studyHall, .catalog])
            section("소통과 연결", items: [.community, .feedback, .parent])
        }
    }

    private func section(_ title: String, items: [Resource]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.mCaption).foregroundStyle(Tokens.text3)
            LazyVGrid(columns: columns, alignment: .leading, spacing: Tokens.Space.s2) {
                ForEach(items) { item in resourceRow(item) }
            }
        }
    }

    @ViewBuilder private func resourceRow(_ item: Resource) -> some View {
        let row = FlowDestinationRow(item.title, detail: item.detail, icon: item.icon) {
            switch item {
            case .coach: store.route = .chat
            case .archive: store.route = .archive
            case .studyHall: store.route = .studyHall
            case .catalog: store.route = .storeCatalog
            case .community: store.route = .community
            case .feedback: store.route = .coachSuggestions
            case .parent: store.openHostedPortal(.parent)
            }
        }
        .padding(.horizontal, Tokens.Space.s3)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        switch item {
        case .coach: row.tutorialTarget(.topChat)
        case .community: row.tutorialTarget(.communityBrowse)
        default: row
        }
    }

    private enum Resource: String, Identifiable {
        case coach, archive, studyHall, catalog, community, feedback, parent
        var id: String { rawValue }
        var title: String {
            switch self {
            case .coach: "AI 코치"
            case .archive: "자료실"
            case .studyHall: "수험관"
            case .catalog: "학습 콘텐츠"
            case .community: "커뮤니티"
            case .feedback: "코치에게 의견 보내기"
            case .parent: "보호자 센터"
            }
        }
        var detail: String {
            switch self {
            case .coach: "질문 · 대화 기록 · 기기 내 모델"
            case .archive: "공개된 학습 자료와 파일"
            case .studyHall: "문제지 선택과 답안 작성"
            case .catalog: "학습에 필요한 콘텐츠 찾기"
            case .community: "질문과 학습 경험 나누기"
            case .feedback: "제안한 내용과 답변 확인"
            case .parent: "별도 보호자 계정으로 자녀 연결"
            }
        }
        var icon: String {
            switch self {
            case .coach: "bubble.left.and.text.bubble.right"
            case .archive: "folder"
            case .studyHall: "building.columns"
            case .catalog: "books.vertical"
            case .community: "person.2"
            case .feedback: "text.bubble"
            case .parent: "figure.and.child.holdinghands"
            }
        }
    }
}
