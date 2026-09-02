import SwiftUI
import UIKit

@MainActor
final class StoreCatalogScreenModel: ObservableObject {
    @Published var catalog: ServerAPI.StoreCatalog?
    @Published var product: ServerAPI.StoreProduct?
    @Published var query = ""
    @Published var isLoading = false
    @Published var isLoadingProduct = false
    @Published var downloadingID: String?
    @Published var errorMessage: String?
    @Published var previewFile: AcademyPreviewFile?

    private var generation = UUID()

    func load(
        category: String? = nil,
        sort: String? = nil,
        reset: Bool = false
    ) async {
        if reset {
            generation = UUID()
            catalog = nil
            product = nil
        }
        let current = generation
        isLoading = catalog == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.storeCatalog(
                query: query,
                sort: sort ?? catalog?.sort ?? "popular",
                category: category ?? catalog?.category ?? "")
            guard current == generation else { return }
            catalog = value
        } catch is CancellationError {
            return
        } catch {
            guard current == generation else { return }
            errorMessage = readable(error)
        }
        if current == generation { isLoading = false }
    }

    func open(_ summary: ServerAPI.StoreProduct) async {
        await open(slug: summary.slug)
    }

    func open(slug: String) async {
        guard !slug.isEmpty else { return }
        isLoadingProduct = true
        errorMessage = nil
        do {
            product = try await ServerAPI.storeProduct(slug: slug)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
        isLoadingProduct = false
    }

    func closeProduct() {
        product = nil
        errorMessage = nil
    }

    func download(_ asset: ServerAPI.StoreAsset) async {
        guard let product, product.price == 0, downloadingID == nil else { return }
        downloadingID = asset.id
        errorMessage = nil
        do {
            previewFile = AcademyPreviewFile(
                url: try await ServerAPI.downloadStoreProductFile(slug: product.slug, asset: asset))
        } catch {
            errorMessage = readable(error)
        }
        downloadingID = nil
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 웹의 교재 상세와 무료 파일 기능을 Bearer API 기반 네이티브 화면으로 제공한다.
/// 유료 디지털 상품은 외부 결제로 보내지 않고 앱 내 판매 준비 상태만 표시한다.
struct StoreCatalogScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = StoreCatalogScreenModel()

    var body: some View {
        GeometryReader { viewport in
            let split = !dynamicTypeSize.isAccessibilitySize &&
                (viewport.size.width >= 900 || viewport.size.height < 500)
            Group {
                if model.isLoading && model.catalog == nil {
                    stateView("자료 카탈로그를 불러오는 중입니다", progress: true)
                } else if let catalog = model.catalog {
                    if split {
                        HStack(spacing: Tokens.Space.s3) {
                            catalogPanel(catalog, compact: true)
                                .frame(width: min(390, viewport.size.width * 0.42))
                            detailOrPrompt
                        }
                        .padding(.leading, max(12, viewport.safeAreaInsets.leading + 12))
                        .padding(.trailing, max(12, viewport.safeAreaInsets.trailing + 12))
                        .padding(.vertical, Tokens.Space.s2)
                    } else if model.product != nil || model.isLoadingProduct {
                        detailOrPrompt
                    } else {
                        catalogPanel(catalog, compact: false)
                    }
                } else {
                    stateView(model.errorMessage ?? "자료 카탈로그를 불러오지 못했습니다.")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                if model.catalog == nil { await model.load() }
                await consumeDeepLinkIfNeeded()
                if split, model.product == nil, let first = model.catalog?.products.first {
                    await model.open(first)
                }
            }
        }
        .background(Tokens.paper)
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.load(reset: true) }
        }
        .onChange(of: store.requestedStoreProductSlug) { _, slug in
            guard let slug, !slug.isEmpty else { return }
            store.requestedStoreProductSlug = nil
            Task { await model.open(slug: slug) }
        }
        .compactHeightSheet(item: $model.previewFile) { preview in
            CommunityFilePreview(url: preview.url) { model.previewFile = nil }
                .ignoresSafeArea()
        }
    }

    private func consumeDeepLinkIfNeeded() async {
        guard let slug = store.requestedStoreProductSlug else { return }
        store.requestedStoreProductSlug = nil
        await model.open(slug: slug)
    }

    private func catalogPanel(_ catalog: ServerAPI.StoreCatalog, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("무료 자료").font(.mTitle).foregroundStyle(Tokens.ink)
                    Text("교재 구성과 공개 자료를 확인하세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                }
                Spacer()
                Button { store.route = .studyHall } label: {
                    Label("수험관", systemImage: "books.vertical.fill")
                        .font(.mCaption).frame(minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Button { store.route = .services } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.text2)
                .accessibilityLabel("무료 자료 닫기")
            }

            HStack(spacing: Tokens.Space.s2) {
                TextField("자료 검색", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { Task { await model.load() } }
                Button { Task { await model.load() } } label: {
                    Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                .accessibilityLabel("검색")
                Menu {
                    sortButton("인기순", value: "popular")
                    sortButton("최신순", value: "newest")
                    sortButton("낮은 가격순", value: "price_asc")
                    sortButton("높은 가격순", value: "price_desc")
                } label: {
                    Label(sortLabel(catalog.sort), systemImage: "arrow.up.arrow.down")
                        .font(.mCaption).frame(minHeight: 44)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.s2) {
                    categoryButton("전체", value: "", selected: catalog.category.isEmpty)
                    ForEach(catalog.categories) { category in
                        categoryButton(category.name, value: category.name,
                                       selected: catalog.category == category.name)
                    }
                }
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if catalog.products.isEmpty {
                stateView(model.query.isEmpty
                          ? "이 분류에는 공개된 자료가 없습니다."
                          : "검색 결과가 없습니다.")
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(catalog.products) { product in productRow(product) }
                    }
                }
                .refreshable { await model.load() }
            }
        }
        .padding(compact ? 0 : Tokens.Space.s5)
    }

    private func sortButton(_ label: String, value: String) -> some View {
        Button(label) { Task { await model.load(sort: value) } }
    }

    private func categoryButton(_ label: String, value: String, selected: Bool) -> some View {
        Button { Task { await model.load(category: value) } } label: {
            Text(label).font(.mCaption).lineLimit(1)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(selected ? Tokens.onPrimary : Tokens.text2)
                .background(selected ? Tokens.actionPrimary : Tokens.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(Tokens.line, lineWidth: selected ? 0 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func productRow(_ product: ServerAPI.StoreProduct) -> some View {
        Button { Task { await model.open(product) } } label: {
            HStack(spacing: Tokens.Space.s3) {
                if let thumbnail = product.thumbnail {
                    StoreCatalogRemoteImage(productID: product.id, asset: thumbnail)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                } else {
                    Image(systemName: "doc.text.image.fill")
                        .font(.system(size: 25, weight: .semibold)).foregroundStyle(Tokens.primary)
                        .frame(width: 72, height: 72).background(Tokens.primary.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.badge.isEmpty ? product.category : product.badge)
                        .font(.mMicro).foregroundStyle(Tokens.primary).lineLimit(1)
                    Text(product.name).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                    Text(product.subtitle.isEmpty ? product.summary : product.subtitle)
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                    Text(priceLabel(product.price)).font(.mCaption).foregroundStyle(
                        product.price == 0 ? Tokens.success : Tokens.text1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").foregroundStyle(Tokens.text3)
            }
            .padding(Tokens.Space.s3).storeCatalogSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint("자료 상세를 엽니다")
    }

    @ViewBuilder private var detailOrPrompt: some View {
        if model.isLoadingProduct {
            stateView("자료 상세를 불러오는 중입니다", progress: true)
        } else if let product = model.product {
            productDetail(product)
        } else {
            stateView("왼쪽에서 자료를 선택하세요.", systemImage: "hand.tap")
        }
    }

    private func productDetail(_ product: ServerAPI.StoreProduct) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.closeProduct() } label: {
                    Label("목록", systemImage: "chevron.left").frame(minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Spacer()
                Text(priceLabel(product.price)).font(.mHeading)
                    .foregroundStyle(product.price == 0 ? Tokens.success : Tokens.ink)
            }
            .padding(.horizontal, Tokens.Space.s4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    productHero(product)
                    if product.price == 0 { downloadSection(product) }
                    else { paidProductNotice }
                    if !product.bundleItems.isEmpty { bundleSection(product) }
                    detailSection(product)
                }
                .padding(Tokens.Space.s4)
            }
        }
        .background(Tokens.paper)
    }

    private func productHero(_ product: ServerAPI.StoreProduct) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Tokens.Space.s4) {
                productHeroImage(product, width: 96, height: 120)
                productHeroCopy(product)
                    .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                productHeroCopy(product)
                productHeroImage(product, width: 88, height: 108)
            }
        }
        .storeCatalogSurface()
    }

    @ViewBuilder private func productHeroImage(
        _ product: ServerAPI.StoreProduct,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        if let thumbnail = product.thumbnail {
            StoreCatalogRemoteImage(productID: product.id, asset: thumbnail)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        }
    }

    private func productHeroCopy(_ product: ServerAPI.StoreProduct) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(product.badge.isEmpty ? product.category : product.badge)
                .font(.mMicro).foregroundStyle(Tokens.primary)
            Text(product.name).font(.mTitle).foregroundStyle(Tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !product.subtitle.isEmpty {
                Text(product.subtitle).font(.mHeading).foregroundStyle(Tokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !product.summary.isEmpty {
                Text(product.summary).font(.mBody).foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if product.originalPrice > product.price {
                Text(priceLabel(product.originalPrice)).font(.mCaption)
                    .foregroundStyle(Tokens.text3).strikethrough()
            }
            Text(priceLabel(product.price)).font(.mTitle)
                .foregroundStyle(product.price == 0 ? Tokens.success : Tokens.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func downloadSection(_ product: ServerAPI.StoreProduct) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("무료 자료 다운로드").font(.mHeading).foregroundStyle(Tokens.ink)
            Text("결제 없이 파일을 바로 열 수 있습니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            if product.freeDownloadFiles.isEmpty {
                Text("운영자가 다운로드 파일을 준비하고 있습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            } else {
                ForEach(product.freeDownloadFiles) { asset in
                    Button { Task { await model.download(asset) } } label: {
                        HStack(spacing: Tokens.Space.s3) {
                            Image(systemName: fileIcon(asset)).foregroundStyle(Tokens.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(asset.originalName).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                                Text(byteLabel(asset.sizeBytes)).font(.mMicro).foregroundStyle(Tokens.text3)
                            }
                            Spacer()
                            if model.downloadingID == asset.id { ProgressView() }
                            else { Image(systemName: "arrow.down.circle") }
                        }
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(.plain).disabled(model.downloadingID != nil)
                }
            }
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.mCaption).foregroundStyle(Tokens.danger)
            }
        }
        .storeCatalogSurface()
    }

    private var paidProductNotice: some View {
        Label("이 자료의 앱 내 판매는 준비 중입니다.", systemImage: "clock.badge")
            .font(.mBodyB).foregroundStyle(Tokens.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .storeCatalogSurface()
    }

    private func bundleSection(_ product: ServerAPI.StoreProduct) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text("자료 구성").font(.mHeading).foregroundStyle(Tokens.ink)
            ForEach(Array(product.bundleItems.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    Text(String(format: "%02d", index + 1)).font(.mMicro.monospacedDigit())
                        .foregroundStyle(Tokens.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.mBodyB).foregroundStyle(Tokens.ink)
                        if !item.description.isEmpty {
                            Text(item.description).font(.mCaption).foregroundStyle(Tokens.text2)
                        }
                    }
                }
            }
        }
        .storeCatalogSurface()
    }

    @ViewBuilder private func detailSection(_ product: ServerAPI.StoreProduct) -> some View {
        if !product.detailBlocks.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Text("상세 설명").font(.mHeading).foregroundStyle(Tokens.ink)
                ForEach(product.detailBlocks) { block in
                    if block.type == "TEXT" {
                        Text(block.text)
                            .font(detailFont(block.fontSize, bold: block.bold))
                            .underline(block.underline)
                            .foregroundStyle(Tokens.text1)
                            .frame(maxWidth: .infinity, alignment: blockAlignment(block.align))
                    } else if block.type == "IMAGE",
                              let assetID = block.assetId,
                              let asset = product.assets.first(where: { $0.id == assetID }) {
                        VStack(spacing: 4) {
                            StoreCatalogRemoteImage(productID: product.id, asset: asset)
                                .frame(maxWidth: .infinity).frame(minHeight: 160, maxHeight: 520)
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                            if !block.caption.isEmpty {
                                Text(block.caption).font(.mMicro).foregroundStyle(Tokens.text3)
                            }
                        }
                    }
                }
            }
            .storeCatalogSurface()
        }
    }

    private func stateView(
        _ message: String,
        progress: Bool = false,
        systemImage: String = "doc.text.magnifyingglass"
    ) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            if progress { ProgressView().tint(Tokens.primary) }
            else { Image(systemName: systemImage).font(.system(size: 30)).foregroundStyle(Tokens.text3) }
            Text(message).font(.mBody).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            if !progress, model.catalog == nil {
                Button("다시 시도") { Task { await model.load(reset: true) } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(Tokens.Space.s5).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sortLabel(_ value: String) -> String {
        ["popular": "인기순", "newest": "최신순", "price_asc": "낮은 가격순",
         "price_desc": "높은 가격순"][value] ?? "인기순"
    }

    private func priceLabel(_ price: Int) -> String {
        price == 0 ? "무료" : "\(price.formatted())원"
    }

    private func byteLabel(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func fileIcon(_ asset: ServerAPI.StoreAsset) -> String {
        asset.mimeType.lowercased().contains("pdf") ? "doc.richtext.fill" : "doc.fill"
    }

    private func detailFont(_ size: String, bold: Bool) -> Font {
        switch (size, bold) {
        case ("title", _): return .mTitle
        case ("large", _): return .mHeading
        case ("small", true): return .mMicro.weight(.bold)
        case ("small", false): return .mMicro
        case (_, true): return .mBodyB
        default: return .mBody
        }
    }

    private func blockAlignment(_ value: String) -> Alignment {
        value == "center" ? .center : value == "right" ? .trailing : .leading
    }
}

private struct StoreCatalogRemoteImage: View {
    let productID: String
    let asset: ServerAPI.StoreAsset
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Tokens.paper
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .foregroundStyle(Tokens.text3)
            } else {
                ProgressView().tint(Tokens.primary)
            }
        }
        .task(id: "\(productID)-\(asset.id)") {
            failed = false
            do {
                let url = try await ServerAPI.downloadStoreProductMedia(
                    productID: productID, asset: asset)
                guard !Task.isCancelled else { return }
                image = UIImage(contentsOfFile: url.path)
                failed = image == nil
            } catch is CancellationError {
                return
            } catch {
                failed = true
            }
        }
        .accessibilityLabel(asset.altText.isEmpty ? "자료 이미지" : asset.altText)
    }
}

private struct StoreCatalogSurface: ViewModifier {
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
    func storeCatalogSurface() -> some View { modifier(StoreCatalogSurface()) }
}
