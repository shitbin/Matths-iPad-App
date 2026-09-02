import SwiftUI

@MainActor
final class FaqScreenModel: ObservableObject {
    @Published var dashboard: ServerAPI.FAQDashboard?
    @Published var query = ""
    @Published var selectedItem: ServerAPI.FAQItem?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var generation = UUID()

    func load(
        category: String? = nil,
        code: String? = nil,
        reset: Bool = false,
        selectFirst: Bool = false
    ) async {
        if reset {
            generation = UUID()
            dashboard = nil
            selectedItem = nil
        }
        let current = generation
        isLoading = dashboard == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.faq(
                query: code == nil ? query : "",
                category: category ?? (code == nil ? dashboard?.category ?? "" : ""),
                code: code ?? "")
            guard current == generation else { return }
            dashboard = value
            if let selectedItem,
               value.items.contains(where: { $0.id == selectedItem.id }) {
                self.selectedItem = value.items.first(where: { $0.id == selectedItem.id })
            } else if selectFirst || !(code ?? "").isEmpty {
                selectedItem = value.items.first
            } else {
                selectedItem = nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard current == generation else { return }
            errorMessage = (error as? ServerAPIError)?.errorDescription
                ?? (error as NSError).localizedDescription
        }
        if current == generation { isLoading = false }
    }

    func select(_ item: ServerAPI.FAQItem) {
        selectedItem = item
    }

    func closeDetail() {
        selectedItem = nil
    }
}

/// 웹 FAQ 원문과 오류 코드 안내를 같은 서버 정본에서 받아 네이티브로 검색·분류한다.
struct FaqScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = FaqScreenModel()

    var body: some View {
        GeometryReader { viewport in
            let split = !dynamicTypeSize.isAccessibilitySize &&
                (viewport.size.width >= 900 || viewport.size.height < 500)
            Group {
                if model.isLoading && model.dashboard == nil {
                    stateView("도움말을 불러오는 중입니다", progress: true)
                } else if let dashboard = model.dashboard {
                    if dynamicTypeSize.isAccessibilitySize {
                        if model.selectedItem != nil { detailOrPrompt }
                        else { accessibilityListPanel(dashboard) }
                    } else if split {
                        HStack(spacing: Tokens.Space.s3) {
                            listPanel(dashboard, compact: true)
                                .frame(width: min(410, viewport.size.width * 0.44))
                            detailOrPrompt
                        }
                        .padding(.leading, max(12, viewport.safeAreaInsets.leading + 12))
                        .padding(.trailing, max(12, viewport.safeAreaInsets.trailing + 12))
                        .padding(.vertical, Tokens.Space.s2)
                    } else if model.selectedItem != nil {
                        detailOrPrompt
                    } else {
                        listPanel(dashboard, compact: false)
                    }
                } else {
                    stateView(model.errorMessage ?? "도움말을 불러오지 못했습니다.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await initialLoad(selectFirst: split)
            }
        }
        .background(Tokens.paper)
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.load(reset: true) }
        }
        .onChange(of: store.requestedFAQCode) { _, code in
            guard let code, !code.isEmpty else { return }
            store.requestedFAQCode = nil
            Task { await model.load(code: code) }
        }
    }

    /// 접근성 크기에서는 고정 헤더+내부 목록 조합이 짧은 화면을 모두 차지한다.
    /// 모든 조작과 결과를 한 스크롤에 넣고 분류 칩을 메뉴로 바꿔 내용이 사라지지 않게 한다.
    private func accessibilityListPanel(_ dashboard: ServerAPI.FAQDashboard) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.s4) {
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("도움말").font(.mTitle).foregroundStyle(Tokens.ink)
                        Text("궁금한 내용을 검색하세요.")
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                    Spacer(minLength: 4)
                    Button { store.route = .support } label: {
                        Image(systemName: "questionmark.bubble")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("문의하기")
                    Button { store.route = .services } label: {
                        Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("도움말 닫기")
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)

                TextField("검색", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.load(category: "") } }

                HStack(spacing: Tokens.Space.s3) {
                    Menu {
                        Button("전체 \(dashboard.totalCount)") {
                            model.query = ""
                            Task { await model.load(category: "") }
                        }
                        ForEach(dashboard.categories) { category in
                            Button("\(category.label) \(category.count)") {
                                model.query = ""
                                Task { await model.load(category: category.value) }
                            }
                        }
                    } label: {
                        Label(categoryLabel(dashboard), systemImage: "line.3.horizontal.decrease.circle")
                            .frame(minHeight: 44)
                    }
                    Spacer()
                    Button { Task { await model.load(category: "") } } label: {
                        Label("검색", systemImage: "magnifyingglass").frame(minHeight: 44)
                    }
                }

                Text("답변 \(dashboard.resultCount)개")
                    .font(.mCaption).foregroundStyle(Tokens.text2)

                if dashboard.items.isEmpty {
                    Text("검색 결과가 없습니다. 다른 단어로 검색하거나 문의를 남겨주세요.")
                        .font(.mBody).foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(dashboard.items) { item in itemRow(item) }
                }
            }
            .padding(Tokens.Space.s4)
        }
    }

    private func categoryLabel(_ dashboard: ServerAPI.FAQDashboard) -> String {
        dashboard.categories.first(where: { $0.value == dashboard.category })?.label ?? "전체"
    }

    private func initialLoad(selectFirst: Bool) async {
        guard model.dashboard == nil else { return }
        if let code = store.requestedFAQCode, !code.isEmpty {
            store.requestedFAQCode = nil
            await model.load(code: code, selectFirst: true)
        } else {
            await model.load(selectFirst: selectFirst)
        }
    }

    private func listPanel(_ dashboard: ServerAPI.FAQDashboard, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("도움말").font(.mTitle).foregroundStyle(Tokens.ink)
                    Text("궁금한 내용을 검색하면 바로 답을 찾을 수 있어요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button { store.route = .support } label: {
                    Label("문의", systemImage: "questionmark.bubble")
                        .font(.mCaption).frame(minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Button { store.route = .services } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.text2)
                .accessibilityLabel("도움말 닫기")
            }

            HStack(spacing: Tokens.Space.s2) {
                TextField("예: 로그인이 안 돼요", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.load(category: "", selectFirst: compact) } }
                Button { Task { await model.load(category: "", selectFirst: compact) } } label: {
                    Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                .accessibilityLabel("도움말 검색")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.s2) {
                    categoryButton("전체", value: "", count: dashboard.totalCount,
                                   selected: dashboard.category.isEmpty)
                    ForEach(dashboard.categories) { category in
                        categoryButton(category.label, value: category.value, count: category.count,
                                       selected: dashboard.category == category.value)
                    }
                }
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("답변 \(dashboard.resultCount)개")
                .font(.mMicro).foregroundStyle(Tokens.text3)

            if dashboard.items.isEmpty {
                stateView("검색 결과가 없습니다. 다른 단어로 검색하거나 문의를 남겨주세요.",
                          systemImage: "magnifyingglass")
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(dashboard.items) { item in itemRow(item) }
                    }
                }
                .refreshable { await model.load(selectFirst: compact) }
            }
        }
        .padding(compact ? 0 : Tokens.Space.s5)
    }

    private func categoryButton(
        _ label: String,
        value: String,
        count: Int,
        selected: Bool
    ) -> some View {
        Button {
            model.query = ""
            Task { await model.load(category: value, selectFirst: selectedItemIsVisibleInSplit) }
        } label: {
            Text("\(label) \(count)").font(.mCaption).lineLimit(1)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(selected ? Tokens.onPrimary : Tokens.text2)
                .background(selected ? Tokens.actionPrimary : Tokens.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(Tokens.line, lineWidth: selected ? 0 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var selectedItemIsVisibleInSplit: Bool {
        !dynamicTypeSize.isAccessibilitySize && model.selectedItem != nil
    }

    private func itemRow(_ item: ServerAPI.FAQItem) -> some View {
        Button { model.select(item) } label: {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(item.categoryLabel).font(.mMicro).foregroundStyle(Tokens.primary)
                        if !item.ordinal.isEmpty {
                            Text(item.ordinal).font(.mMicro).foregroundStyle(Tokens.text3)
                        }
                    }
                    Text(item.question).font(.mBodyB).foregroundStyle(Tokens.ink)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").foregroundStyle(Tokens.text3)
            }
            .padding(Tokens.Space.s3)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line) }
        }
        .buttonStyle(.plain)
        .accessibilityHint("답변을 엽니다")
    }

    @ViewBuilder private var detailOrPrompt: some View {
        if let item = model.selectedItem {
            VStack(spacing: 0) {
                HStack {
                    Button { model.closeDetail() } label: { detailBackLabel }
                    .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                    Spacer()
                    Button { store.route = .support } label: {
                        detailSupportLabel
                    }
                    .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                }
                .padding(.horizontal, Tokens.Space.s4)

                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        Text(item.categoryLabel).font(.mCaption).foregroundStyle(Tokens.primary)
                        Text(item.question).font(.mTitle).foregroundStyle(Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text(item.answer).font(.mBody).foregroundStyle(Tokens.text1)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        Button { store.route = .support } label: {
                            Label("문의 남기기", systemImage: "questionmark.bubble.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(Tokens.Space.s5)
                }
            }
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        } else {
            stateView("왼쪽에서 질문을 선택하세요.", systemImage: "hand.tap")
        }
    }

    @ViewBuilder private var detailBackLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("질문 목록")
        } else {
            Label("목록", systemImage: "chevron.left").frame(minHeight: 44)
        }
    }

    @ViewBuilder private var detailSupportLabel: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Image(systemName: "square.and.pencil").frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("문의하기")
        } else {
            Label("해결 안 됐어요", systemImage: "square.and.pencil")
                .font(.mCaption).frame(minHeight: 44)
        }
    }

    private func stateView(
        _ message: String,
        systemImage: String = "questionmark.circle",
        progress: Bool = false
    ) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            if progress { ProgressView() }
            else { Image(systemName: systemImage).font(.system(size: 30)).foregroundStyle(Tokens.text3) }
            Text(message).font(.mBody).foregroundStyle(Tokens.text2)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Space.s5)
    }
}
