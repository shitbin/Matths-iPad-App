import SwiftUI

@MainActor
final class ArchiveLibraryScreenModel: ObservableObject {
    @Published var dashboard: ServerAPI.ArchiveDashboard?
    @Published var isLoading = false
    @Published var downloadingItemID: String?
    @Published var errorMessage: String?
    @Published var previewFile: AcademyPreviewFile?
    @Published var lockedFolder: ServerAPI.ArchiveFolder?

    private var generation = UUID()

    func load(folderID: String? = nil, reset: Bool = false) async {
        if reset {
            generation = UUID()
            dashboard = nil
        }
        let requestGeneration = generation
        isLoading = dashboard == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.archiveDashboard(folderID: folderID)
            guard requestGeneration == generation else { return }
            dashboard = value
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation { isLoading = false }
    }

    func open(_ folder: ServerAPI.ArchiveFolder) async {
        guard !folder.isLocked else {
            lockedFolder = folder
            return
        }
        await load(folderID: folder.id)
    }

    func goBack() async {
        let parentID = dashboard?.breadcrumbs.dropLast().last?.id
        await load(folderID: parentID)
    }

    func download(_ item: ServerAPI.ArchiveItem) async {
        guard downloadingItemID == nil else { return }
        downloadingItemID = item.id
        errorMessage = nil
        do {
            previewFile = AcademyPreviewFile(url: try await ServerAPI.downloadArchiveItem(item))
        } catch {
            errorMessage = readable(error)
        }
        downloadingItemID = nil
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 운영 자료를 폴더 단위로 탐색하고, 앱 Bearer 권한으로 바로 내려받는 자료실.
/// iPhone 가로에서는 폴더와 파일을 좌우에 고정해 탐색 왕복과 바깥 스크롤을 없앤다.
struct ArchiveLibraryScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = ArchiveLibraryScreenModel()

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { viewport in
            Group {
                if model.isLoading && model.dashboard == nil {
                    loadingState
                } else if let dashboard = model.dashboard {
                    library(dashboard, viewport: viewport)
                } else {
                    failureState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.paper)
        .task { if model.dashboard == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.load(reset: true) }
        }
        .compactHeightSheet(item: $model.previewFile) { preview in
            CommunityFilePreview(url: preview.url) { model.previewFile = nil }
                .ignoresSafeArea()
        }
        .alert("이용권이 필요한 폴더입니다", isPresented: Binding(
            get: { model.lockedFolder != nil },
            set: { if !$0 { model.lockedFolder = nil } }
        )) {
            Button("나중에", role: .cancel) { model.lockedFolder = nil }
            Button("이용권 보기") {
                model.lockedFolder = nil
                store.route = .commerce
            }
        } message: {
            Text("\(model.lockedFolder?.name ?? "이 자료")는 활성 이용권이 있어야 열 수 있습니다.")
        }
    }

    @ViewBuilder
    private func library(_ dashboard: ServerAPI.ArchiveDashboard, viewport: GeometryProxy) -> some View {
        if compactLandscape {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                folderPanel(dashboard)
                    .frame(width: min(360, viewport.size.width * 0.40))
                itemPanel(dashboard)
            }
            .padding(.horizontal, max(12, viewport.safeAreaInsets.leading + 12))
            .padding(.vertical, Tokens.Space.s2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    pageHeader
                    folderPanel(dashboard, ownsScroll: false)
                    itemPanel(dashboard, ownsScroll: false)
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .refreshable { await model.load(folderID: dashboard.selectedFolder?.id) }
        }
    }

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("자료실").font(.mTitle).foregroundStyle(Tokens.ink)
                Text("폴더를 고르고 필요한 파일을 바로 엽니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Spacer()
            closeButton
        }
    }

    @ViewBuilder
    private func folderPanel(
        _ dashboard: ServerAPI.ArchiveDashboard,
        ownsScroll: Bool = true
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dashboard.selectedFolder == nil ? "자료 폴더" : "현재 폴더")
                        .font(.mHeading).foregroundStyle(Tokens.ink)
                    Text(pathLabel(dashboard))
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s2)
                if compactLandscape { closeButton }
            }

            if dashboard.selectedFolder != nil {
                Button { Task { await model.goBack() } } label: {
                    Label("상위 폴더", systemImage: "arrow.up.left")
                        .font(.mBodyB).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
            }

            if dashboard.folders.isEmpty {
                Text("이 폴더에는 하위 폴더가 없습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVStack(spacing: Tokens.Space.s2) {
                    ForEach(dashboard.folders) { folder in folderRow(folder) }
                }
            }
        }
        .archiveSurface()

        if ownsScroll {
            ScrollView { content }
                .refreshable { await model.load(folderID: dashboard.selectedFolder?.id) }
        } else {
            content
        }
    }

    private func folderRow(_ folder: ServerAPI.ArchiveFolder) -> some View {
        Button { Task { await model.open(folder) } } label: {
            HStack(spacing: Tokens.Space.s3) {
                Image(systemName: folder.isLocked ? "lock.fill" : "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(folder.isLocked ? Tokens.text3 : Tokens.primary)
                    .frame(width: 38, height: 38)
                    .background((folder.isLocked ? Tokens.text3 : Tokens.primary).opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(folder.name).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                        if folder.isPinned {
                            Image(systemName: "pin.fill").font(.mMicro).foregroundStyle(Tokens.warning)
                        }
                    }
                    Text(folder.description.isEmpty ? "\(folder.itemCount)개 자료" : folder.description)
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("\(folder.itemCount)").font(.mMicro.monospacedDigit()).foregroundStyle(Tokens.text3)
                Image(systemName: "chevron.right").font(.mMicro).foregroundStyle(Tokens.text3)
            }
            .padding(Tokens.Space.s3)
            .background(Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(folder.isLocked ? "이용권 화면을 엽니다" : "폴더를 엽니다")
    }

    @ViewBuilder
    private func itemPanel(
        _ dashboard: ServerAPI.ArchiveDashboard,
        ownsScroll: Bool = true
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dashboard.selectedFolder?.name ?? "루트 자료")
                        .font(.mHeading).foregroundStyle(Tokens.ink)
                    Text("\(dashboard.items.count)개 파일 · PDF는 개인 식별 워터마크 적용")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Spacer(minLength: Tokens.Space.s2)
                Button { Task { await model.load(folderID: dashboard.selectedFolder?.id) } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                .accessibilityLabel("자료 새로고침")
            }

            if let error = model.errorMessage {
                Text(error).font(.mCaption).foregroundStyle(Tokens.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if dashboard.items.isEmpty {
                VStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28, weight: .semibold)).foregroundStyle(Tokens.text3)
                    Text("이 폴더에는 파일이 없습니다.").font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text("왼쪽에서 다른 폴더를 선택해 보세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                LazyVStack(spacing: Tokens.Space.s2) {
                    ForEach(dashboard.items) { item in itemRow(item) }
                }
            }
        }
        .archiveSurface()

        if ownsScroll {
            ScrollView { content }
                .refreshable { await model.load(folderID: dashboard.selectedFolder?.id) }
        } else {
            content
        }
    }

    private func itemRow(_ item: ServerAPI.ArchiveItem) -> some View {
        Button { Task { await model.download(item) } } label: {
            HStack(spacing: Tokens.Space.s3) {
                Image(systemName: fileIcon(item))
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Tokens.primary)
                    .frame(width: 40, height: 40)
                    .background(Tokens.primary.opacity(0.10), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(item.category)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes),
                                                       countStyle: .file))
                        if item.downloadCount > 0 { Text("\(item.downloadCount)회") }
                    }
                    .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s2)
                if model.downloadingItemID == item.id {
                    ProgressView().tint(Tokens.primary)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 23)).foregroundStyle(Tokens.primary)
                }
            }
            .padding(Tokens.Space.s3)
            .background(Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.downloadingItemID != nil)
        .accessibilityHint("파일을 내려받아 미리 봅니다")
    }

    private var closeButton: some View {
        Button { store.route = .services } label: {
            Image(systemName: "xmark").frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).foregroundStyle(Tokens.text3)
        .accessibilityLabel("자료실 닫기")
    }

    private var loadingState: some View {
        stateShell {
            ProgressView().tint(Tokens.primary)
            Text("자료실을 불러오는 중입니다").font(.mHeading)
        }
    }

    private var failureState: some View {
        stateShell {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Tokens.danger)
            Text("자료실을 열지 못했습니다").font(.mHeading)
            Text(model.errorMessage ?? "잠시 후 다시 시도해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            Button("다시 시도") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func stateShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Tokens.Space.s3) { content() }
            .padding(Tokens.Space.s5).frame(maxWidth: 460).archiveSurface()
    }

    private func pathLabel(_ dashboard: ServerAPI.ArchiveDashboard) -> String {
        dashboard.breadcrumbs.isEmpty
            ? "전체 공개 자료"
            : dashboard.breadcrumbs.map(\.name).joined(separator: " / ")
    }

    private func fileIcon(_ item: ServerAPI.ArchiveItem) -> String {
        if item.mimeType.lowercased().contains("pdf") { return "doc.richtext.fill" }
        if item.mimeType.lowercased().hasPrefix("image/") { return "photo.fill" }
        if item.mimeType.lowercased().contains("zip") { return "doc.zipper" }
        return "doc.fill"
    }
}

private struct ArchiveSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s4)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func archiveSurface() -> some View { modifier(ArchiveSurface()) }
}
