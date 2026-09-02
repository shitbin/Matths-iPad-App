import SwiftUI
import UniformTypeIdentifiers

@MainActor
private final class AdminStoreModel: ObservableObject {
    @Published var dashboard: ServerAPI.AdminStoreDashboard?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    func load() async {
        isLoading = dashboard == nil; errorMessage = nil
        do { dashboard = try await ServerAPI.adminStoreDashboard() }
        catch is CancellationError {} catch { errorMessage = readable(error) }
        isLoading = false
    }
    func apply(id: String, message: String, operation: () async throws -> ServerAPI.AdminStoreDashboard) async -> Bool {
        guard actionID == nil else { return false }; actionID = id; errorMessage = nil; noticeMessage = nil
        do { dashboard = try await operation(); noticeMessage = message; actionID = nil; return true }
        catch { errorMessage = readable(error); actionID = nil; return false }
    }
    private func readable(_ error: Error) -> String { (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription }
}

struct AdminStoreScreen: View {
    private enum Area: String, CaseIterable, Identifiable { case hall = "수험관", products = "상품", categories = "카테고리"; var id: String { rawValue } }
    private enum DeleteIntent: Identifiable { case hall(ServerAPI.StudyHallContent), product(ServerAPI.StoreProduct), category(ServerAPI.AdminStoreCategory); var id: String { switch self { case .hall(let v): "h:\(v.id)"; case .product(let v): "p:\(v.id)"; case .category(let v): "c:\(v.id)" } } }
    private struct CategoryEdit: Identifiable { var category: ServerAPI.AdminStoreCategory?; var id: String { category?.id ?? "new" } }
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminStoreModel()
    @State private var area: Area = .hall
    @State private var selectedHallID: String?
    @State private var selectedProductID: String?
    @State private var hallEditor: ServerAPI.StudyHallContent?
    @State private var productEditor: ServerAPI.StoreProduct?
    @State private var creatingHall = false
    @State private var creatingProduct = false
    @State private var categoryEdit: CategoryEdit?
    @State private var deletion: DeleteIntent?
    let onClose: () -> Void

    private var compactLandscape: Bool { verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize }
    var body: some View {
        VStack(spacing: 0) {
            header
            if let value = model.errorMessage { banner(value, Tokens.dangerInk, "exclamationmark.triangle.fill") }
            if let value = model.noticeMessage { banner(value, Tokens.successInk, "checkmark.circle.fill") }
            if model.isLoading && model.dashboard == nil { Spacer(); ProgressView("운영 데이터를 불러오는 중입니다"); Spacer() }
            else if let dashboard = model.dashboard { content(dashboard) }
            else { ContentUnavailableView("수험관 운영 데이터를 불러오지 못했습니다", systemImage: "cart.badge.questionmark") }
        }
        .background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .task { await model.load() }
        .sheet(isPresented: $creatingHall) { if let value = model.dashboard { AdminStudyHallEditor(content: nil, tabs: value.studyHall.tabs) { form in await saveHall(nil, form) } } }
        .sheet(item: $hallEditor) { content in if let value = model.dashboard { AdminStudyHallEditor(content: content, tabs: value.studyHall.tabs) { form in await saveHall(content, form) } } }
        .sheet(isPresented: $creatingProduct) { if let value = model.dashboard { AdminProductEditor(product: nil, categories: value.store.categories) { form in await saveProduct(nil, form) } } }
        .sheet(item: $productEditor) { product in if let value = model.dashboard { AdminProductEditor(product: product, categories: value.store.categories) { form in await saveProduct(product, form) } } }
        .sheet(item: $categoryEdit) { value in AdminCategoryEditor(category: value.category) { name, visible in await saveCategory(value.category, name: name, visible: visible) } }
        .confirmationDialog("운영 데이터를 변경할까요?", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }), titleVisibility: .visible) {
            Button(deleteLabel, role: .destructive) { if let deletion { Task { await performDelete(deletion) } } }
            Button("취소", role: .cancel) { deletion = nil }
        } message: { Text(deleteMessage) }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("관리자 홈")
                VStack(alignment: .leading, spacing: 1) { Text("수험관·상점 운영").font(.mHeading); Text("콘텐츠·자동채점·상품·카테고리").font(.mCaption).foregroundStyle(Tokens.text2) }
                Spacer()
                Button { createCurrent() } label: { Image(systemName: "plus.circle").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("새 \(area.rawValue)")
                Button { Task { await model.load() } } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary)
            }
            Picker("운영 구역", selection: $area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
    }

    @ViewBuilder private func content(_ dashboard: ServerAPI.AdminStoreDashboard) -> some View {
        switch area {
        case .hall: hall(dashboard.studyHall)
        case .products: products(dashboard.store)
        case .categories: categories(dashboard.store.categories)
        }
    }

    private func hall(_ hall: ServerAPI.AdminStoreStudyHall) -> some View {
        let selected = hall.items.first(where: { $0.id == selectedHallID }) ?? hall.items.first
        return Group {
            if compactLandscape { HStack(spacing: 0) { hallList(hall.items, selected: selected).frame(width: 355); Divider(); hallDetail(selected).frame(maxWidth: .infinity, maxHeight: .infinity) } }
            else { ScrollView { VStack(spacing: 12) { hallList(hall.items, selected: selected); hallDetail(selected) }.readableWidth(Tokens.readableWidth).adaptiveHPadding().adaptiveVPadding() } }
        }.onAppear { selectedHallID = selected?.id }
    }
    private func hallList(_ items: [ServerAPI.StudyHallContent], selected: ServerAPI.StudyHallContent?) -> some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 8) {
            Text("등록 콘텐츠 \(items.count)개").font(.mBodyB)
            if items.isEmpty { ContentUnavailableView("등록 콘텐츠 없음", systemImage: "book.closed") }
            ForEach(items) { item in Button { selectedHallID = item.id } label: { VStack(alignment: .leading, spacing: 3) { HStack { Text(item.title).font(.mBodyB); Spacer(); badge(status(item.status)) }; Text("\(item.tabLabel) · \(item.itemCount)문항 · \(item.series.isEmpty ? item.subject : item.series)").font(.mMicro).foregroundStyle(Tokens.text3) }.padding(10).background(selected?.id == item.id ? Tokens.primary.opacity(0.09) : Tokens.surface, in: RoundedRectangle(cornerRadius: 11)) }.buttonStyle(.plain) }
        }.padding(12) }
    }
    @ViewBuilder private func hallDetail(_ item: ServerAPI.StudyHallContent?) -> some View {
        ScrollView { if let item { VStack(alignment: .leading, spacing: 12) {
            HStack { VStack(alignment: .leading) { Text(item.title).font(.mTitle); Text("\(item.grade) · \(item.subject) · \(item.difficulty)").font(.mCaption).foregroundStyle(Tokens.text2) }; Spacer(); Menu { Button("수정") { hallEditor = item }; Button("비공개 보관", role: .destructive) { deletion = .hall(item) } } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) } }
            Text(item.description.isEmpty ? "설명 없음" : item.description).font(.mBody)
            HStack { metric("\(item.itemCount)", "문항"); metric("\(item.timeLimitMinutes)분", "제한 시간"); metric("\(item.assets.count)", "연결 파일") }
            if !item.assets.isEmpty { VStack(alignment: .leading, spacing: 6) { Text("연결 파일").font(.mBodyB); ForEach(item.assets) { Text("\($0.kind) · \($0.originalName)").font(.mCaption) } }.padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12)) }
            if !item.questions.isEmpty { Text("정답 데이터 \(item.questions.count)문항 등록됨").font(.mCaption).foregroundStyle(Tokens.successInk) }
        }.padding(14) } else { ContentUnavailableView("콘텐츠를 선택하세요", systemImage: "book.pages") } }
    }

    private func products(_ store: ServerAPI.AdminStoreCatalog) -> some View {
        let selected = store.products.first(where: { $0.id == selectedProductID }) ?? store.products.first
        return Group {
            if compactLandscape { HStack(spacing: 0) { productList(store.products, selected: selected).frame(width: 355); Divider(); productDetail(selected).frame(maxWidth: .infinity, maxHeight: .infinity) } }
            else { ScrollView { VStack(spacing: 12) { productList(store.products, selected: selected); productDetail(selected) }.readableWidth(Tokens.readableWidth).adaptiveHPadding().adaptiveVPadding() } }
        }.onAppear { selectedProductID = selected?.id }
    }
    private func productList(_ items: [ServerAPI.StoreProduct], selected: ServerAPI.StoreProduct?) -> some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 8) { Text("묶음 상품 \(items.count)개").font(.mBodyB); if items.isEmpty { ContentUnavailableView("등록 상품 없음", systemImage: "shippingbox") }; ForEach(items) { item in Button { selectedProductID = item.id } label: { VStack(alignment: .leading, spacing: 3) { HStack { Text(item.name).font(.mBodyB); Spacer(); badge(status(item.status)) }; Text("\(item.category) · \(item.price.formatted())원 · 판매 \(item.salesCount)").font(.mMicro).foregroundStyle(Tokens.text3) }.padding(10).background(selected?.id == item.id ? Tokens.primary.opacity(0.09) : Tokens.surface, in: RoundedRectangle(cornerRadius: 11)) }.buttonStyle(.plain) } }.padding(12) }
    }
    @ViewBuilder private func productDetail(_ item: ServerAPI.StoreProduct?) -> some View {
        ScrollView { if let item { VStack(alignment: .leading, spacing: 12) { HStack { VStack(alignment: .leading) { Text(item.name).font(.mTitle); Text(item.subtitle).font(.mCaption).foregroundStyle(Tokens.text2) }; Spacer(); Menu { Button("수정") { productEditor = item }; Button("상품·파일 영구 삭제", role: .destructive) { deletion = .product(item) } } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) } }; Text(item.summary).font(.mBody); HStack { metric("\(item.price.formatted())원", "판매가"); metric("\(item.viewCount)", "조회"); metric("\(item.salesCount)", "판매") }; Text("연결 자산 \(item.assets.count)개 · 상세 블록 \(item.detailBlocks.count)개").font(.mCaption) }.padding(14) } else { ContentUnavailableView("상품을 선택하세요", systemImage: "shippingbox") } }
    }

    private func categories(_ items: [ServerAPI.AdminStoreCategory]) -> some View {
        ScrollView { VStack(alignment: .leading, spacing: 9) { Text("노출 순서는 사용자 상점 상단 분류에 즉시 반영됩니다.").font(.mCaption).foregroundStyle(Tokens.text2); ForEach(Array(items.enumerated()), id: \.element.id) { index, item in HStack { VStack(alignment: .leading) { HStack { Text(item.name).font(.mBodyB); badge(item.isVisible ? "공개" : "숨김") }; Text("상품 \(item.productCount)개 · 순서 \(index + 1)").font(.mMicro).foregroundStyle(Tokens.text3) }; Spacer(); Button { Task { await moveCategory(index, -1, items) } } label: { Image(systemName: "arrow.up") }.disabled(index == 0); Button { Task { await moveCategory(index, 1, items) } } label: { Image(systemName: "arrow.down") }.disabled(index == items.count - 1); Menu { Button("이름·공개 상태 편집") { categoryEdit = .init(category: item) }; Button("카테고리 삭제", role: .destructive) { deletion = .category(item) } } label: { Image(systemName: "ellipsis.circle").frame(width: 40, height: 40) } }.padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12)) } }.readableWidth(760).adaptiveHPadding().adaptiveVPadding() }
    }

    private func createCurrent() { switch area { case .hall: creatingHall = true; case .products: creatingProduct = true; case .categories: categoryEdit = .init(category: nil) } }
    private func saveHall(_ existing: ServerAPI.StudyHallContent?, _ form: AdminStudyHallForm) async -> Bool { await model.apply(id: "hall-save", message: existing == nil ? "수험관 콘텐츠를 등록했습니다." : "수험관 콘텐츠를 수정했습니다.") { try await ServerAPI.saveAdminStudyHallContent(id: existing?.id, fields: form.fields, files: form.files, removeAssetIDs: Array(form.removeAssetIDs)) } }
    private func saveProduct(_ existing: ServerAPI.StoreProduct?, _ form: AdminProductForm) async -> Bool { await model.apply(id: "product-save", message: existing == nil ? "묶음 상품을 등록했습니다." : "묶음 상품을 수정했습니다.") { try await ServerAPI.saveAdminStoreProduct(id: existing?.id, fields: form.fields, files: form.files, removeAssetIDs: Array(form.removeAssetIDs)) } }
    private func saveCategory(_ existing: ServerAPI.AdminStoreCategory?, name: String, visible: Bool) async -> Bool { await model.apply(id: "category-save", message: "카테고리를 저장했습니다.") { if let existing { try await ServerAPI.updateAdminStoreCategory(id: existing.id, name: name, isVisible: visible) } else { try await ServerAPI.createAdminStoreCategory(name: name) } } }
    private func moveCategory(_ index: Int, _ offset: Int, _ items: [ServerAPI.AdminStoreCategory]) async { var ids = items.map(\.id); ids.swapAt(index, index + offset); _ = await model.apply(id: "category-order", message: "카테고리 노출 순서를 저장했습니다.") { try await ServerAPI.reorderAdminStoreCategories(ids: ids) } }
    private func performDelete(_ value: DeleteIntent) async { switch value { case .hall(let item): _ = await model.apply(id: value.id, message: "콘텐츠를 비공개 보관했습니다.") { try await ServerAPI.archiveAdminStudyHallContent(id: item.id) }; case .product(let item): _ = await model.apply(id: value.id, message: "상품과 연결 파일을 삭제했습니다.") { try await ServerAPI.deleteAdminStoreProduct(id: item.id) }; case .category(let item): _ = await model.apply(id: value.id, message: "카테고리를 삭제했습니다.") { try await ServerAPI.deleteAdminStoreCategory(id: item.id) } }; deletion = nil }
    private var deleteLabel: String { switch deletion { case .hall: "비공개 보관"; case .product: "상품·파일 영구 삭제"; case .category: "카테고리 삭제"; case nil: "삭제" } }
    private var deleteMessage: String { switch deletion { case .hall: "사용자에게 즉시 숨기고 데이터는 보관합니다."; case .product: "상품과 연결된 저장 파일을 복구할 수 없게 삭제합니다."; case .category: "연결 상품이 있으면 서버가 삭제를 거부합니다."; case nil: "" } }
    private func status(_ value: String) -> String { ["PUBLISHED":"공개", "DRAFT":"초안", "ARCHIVED":"보관"][value] ?? value }
    private func metric(_ value: String, _ label: String) -> some View { VStack(alignment: .leading) { Text(value).font(.mBodyB.monospacedDigit()); Text(label).font(.mMicro).foregroundStyle(Tokens.text3) }.frame(maxWidth: .infinity, alignment: .leading).padding(9).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 9)) }
    private func badge(_ value: String) -> some View { Text(value).font(.mMicro.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3).foregroundStyle(Tokens.primary).background(Tokens.primary.opacity(0.1), in: Capsule()) }
    private func banner(_ value: String, _ color: Color, _ icon: String) -> some View { Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(color.opacity(0.1)) }
}

struct AdminStudyHallForm {
    var contentType = "NJE", series = "", title = "", description = "", grade = "공통", subject = "", difficulty = "", phase = "", finalCategory = "", errorCategory = "", commonMistake = "", wrongApproach = "", correctApproach = "", relatedProblem = "", status = "DRAFT", publishAt = "", questionsJson = "[]"
    var itemCount = 0, timeLimitMinutes = 0, recommendedStudyDays = 0, estimatedMinutes = 0, year = Calendar.current.component(.year, from: Date()), month = Calendar.current.component(.month, from: Date()), week = 1, session = 1, sortOrder = 0
    var studyThumbnail: [URL] = [], questionPdf: [URL] = [], solutionPdf: [URL] = [], answerKeyJson: [URL] = [], contentFiles: [URL] = []; var removeAssetIDs = Set<String>()
    var fields: [String: String] { ["contentType":contentType,"series":series,"title":title,"description":description,"grade":grade,"subject":subject,"difficulty":difficulty,"phase":phase,"finalCategory":finalCategory,"errorCategory":errorCategory,"commonMistake":commonMistake,"wrongApproach":wrongApproach,"correctApproach":correctApproach,"relatedProblem":relatedProblem,"status":status,"publishAt":publishAt,"questionsJson":questionsJson,"itemCount":"\(itemCount)","timeLimitMinutes":"\(timeLimitMinutes)","recommendedStudyDays":"\(recommendedStudyDays)","estimatedMinutes":"\(estimatedMinutes)","year":"\(year)","month":"\(month)","week":"\(week)","session":"\(session)","sortOrder":"\(sortOrder)"] }
    var files: [String:[URL]] { ["studyThumbnail":studyThumbnail,"questionPdf":questionPdf,"solutionPdf":solutionPdf,"answerKeyJson":answerKeyJson,"contentFiles":contentFiles] }
}

private struct AdminStudyHallEditor: View {
    private enum FileKind: String, Identifiable { case thumbnail, question, solution, answers, attachments; var id: String { rawValue } }
    let content: ServerAPI.StudyHallContent?; let tabs: [ServerAPI.StudyHallTab]; let onSave: (AdminStudyHallForm) async -> Bool
    @Environment(\.dismiss) private var dismiss; @State private var form: AdminStudyHallForm; @State private var picking: FileKind?; @State private var saving = false; @State private var confirm = false
    init(content: ServerAPI.StudyHallContent?, tabs: [ServerAPI.StudyHallTab], onSave: @escaping (AdminStudyHallForm) async -> Bool) { self.content = content; self.tabs = tabs; self.onSave = onSave; _form = State(initialValue: Self.make(content)) }
    var body: some View { NavigationStack { Form {
        Section("기본 정보") { Picker("콘텐츠 종류", selection: $form.contentType) { ForEach(tabs) { Text($0.label).tag($0.code) } }; TextField("제목", text: $form.title); TextField("시리즈", text: $form.series); Picker("학년", selection: $form.grade) { ForEach(["공통","고2","고3"], id:\.self) { Text($0).tag($0) } }; TextField("과목", text: $form.subject); TextField("설명", text: $form.description, axis: .vertical).lineLimit(3...6) }
        Section("문항·운영") { Stepper("문항 수 \(form.itemCount)", value: $form.itemCount, in: 0...500); Stepper("제한 시간 \(form.timeLimitMinutes)분", value: $form.timeLimitMinutes, in: 0...600); Stepper("권장 기간 \(form.recommendedStudyDays)일", value: $form.recommendedStudyDays, in: 0...365); Stepper("예상 학습 \(form.estimatedMinutes)분", value: $form.estimatedMinutes, in: 0...10000); TextField("난이도", text: $form.difficulty); Stepper("노출 순서 \(form.sortOrder)", value: $form.sortOrder, in: 0...100000); Picker("상태", selection: $form.status) { Text("초안").tag("DRAFT"); Text("공개").tag("PUBLISHED"); Text("보관").tag("ARCHIVED") }; TextField("공개 시각 (ISO 8601, 선택)", text: $form.publishAt) }
        Section("분류 상세") { Stepper("연도 \(form.year)", value: $form.year, in: 0...2200); Stepper("월 \(form.month)", value: $form.month, in: 0...12); Stepper("주차 \(form.week)", value: $form.week, in: 0...6); Stepper("회차 \(form.session)", value: $form.session, in: 0...100); TextField("실전 시기", text: $form.phase); TextField("파이널 분류", text: $form.finalCategory); TextField("오답 유형 분류", text: $form.errorCategory) }
        Section("오답 유형 리포트") { TextField("자주 틀리는 이유", text: $form.commonMistake, axis:.vertical); TextField("잘못된 접근", text: $form.wrongApproach, axis:.vertical); TextField("올바른 풀이", text: $form.correctApproach, axis:.vertical); TextField("관련 대표 문제", text: $form.relatedProblem, axis:.vertical) }
        Section("자동 채점 데이터") { Button("답지 JSON 파일 선택") { picking = .answers }; if let file = form.answerKeyJson.first { Text(file.lastPathComponent).font(.mCaption) }; DisclosureGroup("문항 JSON 직접 확인·편집") { TextEditor(text: $form.questionsJson).font(.system(.caption, design:.monospaced)).frame(minHeight:180) } }
        Section("파일") { fileButton("표지·썸네일", .thumbnail, form.studyThumbnail); fileButton("문제지 PDF", .question, form.questionPdf); fileButton("해설 PDF", .solution, form.solutionPdf); fileButton("추가 연결 자료 (최대 20개)", .attachments, form.contentFiles); if let content { ForEach(content.assets) { asset in Toggle("삭제 · \(asset.kind) · \(asset.originalName)", isOn: Binding(get:{ form.removeAssetIDs.contains(asset.id) }, set:{ if $0 { form.removeAssetIDs.insert(asset.id) } else { form.removeAssetIDs.remove(asset.id) } })) } } }
    }.navigationTitle(content == nil ? "새 수험관 콘텐츠" : "콘텐츠 수정").toolbar { ToolbarItem(placement:.cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("저장 검토") { confirm = true }.disabled(form.title.trimmingCharacters(in:.whitespaces).isEmpty || saving) } }.fileImporter(isPresented: Binding(get:{ picking != nil }, set:{ if !$0 { picking = nil } }), allowedContentTypes:[.data], allowsMultipleSelection:true) { result in if case .success(let urls) = result, let kind = picking { assign(urls, kind) }; picking = nil }.confirmationDialog("콘텐츠를 저장할까요?", isPresented:$confirm, titleVisibility:.visible) { Button(form.status == "PUBLISHED" ? "검증 후 공개 저장" : "저장") { saving = true; Task { if await onSave(form) { dismiss() }; saving = false } }; Button("취소", role:.cancel) {} } message: { Text("서버가 답지 문항 수·배점과 파일 실제 형식을 다시 검증합니다.") } }.presentationDetents([.large]) }
    private func fileButton(_ label:String, _ kind:FileKind, _ files:[URL]) -> some View { Button { picking = kind } label: { VStack(alignment:.leading) { Text(label); if !files.isEmpty { Text(files.map(\.lastPathComponent).joined(separator:", ")).font(.mMicro).foregroundStyle(Tokens.text3) } } } }
    private func assign(_ urls:[URL], _ kind:FileKind) { switch kind { case .thumbnail: form.studyThumbnail = Array(urls.prefix(1)); case .question: form.questionPdf = Array(urls.prefix(1)); case .solution: form.solutionPdf = Array(urls.prefix(1)); case .answers: form.answerKeyJson = Array(urls.prefix(1)); case .attachments: form.contentFiles = Array(urls.prefix(20)) } }
    private static func make(_ value:ServerAPI.StudyHallContent?) -> AdminStudyHallForm { guard let value else { return .init() }; var form = AdminStudyHallForm(); form.contentType=value.contentType; form.series=value.series; form.title=value.title; form.description=value.description; form.grade=value.grade; form.subject=value.subject; form.itemCount=value.itemCount; form.difficulty=value.difficulty; form.timeLimitMinutes=value.timeLimitMinutes; form.recommendedStudyDays=value.recommendedStudyDays; form.estimatedMinutes=value.estimatedMinutes; form.year=value.year; form.month=value.month; form.week=value.week; form.session=value.session; form.phase=value.phase; form.finalCategory=value.finalCategory; form.errorCategory=value.errorCategory; form.commonMistake=value.commonMistake; form.wrongApproach=value.wrongApproach; form.correctApproach=value.correctApproach; form.relatedProblem=value.relatedProblem; form.status=value.status; form.sortOrder=value.sortOrder; form.publishAt=value.publishAt ?? ""; let rows:[[String:Any]] = value.questions.map { ["number":$0.number,"stem":$0.stem,"choices":$0.choices,"answerType":$0.answerType,"points":$0.points,"correctAnswer":$0.correctAnswer ?? "","explanation":$0.explanation ?? ""] }; if let data=try? JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted]), let text=String(data:data,encoding:.utf8) { form.questionsJson=text }; return form }
}

struct AdminProductForm { var name="", category="", badge="", subtitle="", summary="", bundleItems="", detailBlocksJson="[]", status="DRAFT"; var price=0, originalPrice=0, popularityScore=0; var thumbnail:[URL]=[], detailImages:[URL]=[], productFiles:[URL]=[]; var removeAssetIDs=Set<String>(); var fields:[String:String] { ["name":name,"category":category,"badge":badge,"subtitle":subtitle,"summary":summary,"bundleItems":bundleItems,"detailBlocksJson":detailBlocksJson,"status":status,"price":"\(price)","originalPrice":"\(originalPrice)","popularityScore":"\(popularityScore)"] }; var files:[String:[URL]] { ["thumbnail":thumbnail,"detailImages":detailImages,"productFiles":productFiles] } }

private struct AdminProductEditor: View {
    private enum FileKind:String,Identifiable { case thumbnail, images, files; var id:String{rawValue} }
    let product:ServerAPI.StoreProduct?; let categories:[ServerAPI.AdminStoreCategory]; let onSave:(AdminProductForm) async -> Bool
    @Environment(\.dismiss) private var dismiss; @State private var form:AdminProductForm; @State private var picking:FileKind?; @State private var saving=false; @State private var confirm=false
    init(product:ServerAPI.StoreProduct?,categories:[ServerAPI.AdminStoreCategory],onSave:@escaping(AdminProductForm) async->Bool){self.product=product;self.categories=categories;self.onSave=onSave;_form=State(initialValue:Self.make(product,categories))}
    var body:some View { NavigationStack { Form { Section("상품 정보") { TextField("상품 이름",text:$form.name); Picker("카테고리",selection:$form.category){ForEach(categories){Text($0.name).tag($0.name)}}; TextField("배지",text:$form.badge); TextField("부제",text:$form.subtitle); TextField("요약",text:$form.summary,axis:.vertical).lineLimit(3...6); Picker("상태",selection:$form.status){Text("초안").tag("DRAFT");Text("공개").tag("PUBLISHED");Text("보관").tag("ARCHIVED")} }; Section("가격·정렬") { Stepper("판매가 \(form.price.formatted())원",value:$form.price,in:0...100_000_000,step:500); Stepper("정가 \(form.originalPrice.formatted())원",value:$form.originalPrice,in:0...100_000_000,step:500); Stepper("인기 점수 \(form.popularityScore)",value:$form.popularityScore,in:0...1_000_000) }; Section("구성·상세") { TextField("구성품 (한 줄에 이름|설명)",text:$form.bundleItems,axis:.vertical).lineLimit(4...10); DisclosureGroup("상세 텍스트 블록 JSON") { TextEditor(text:$form.detailBlocksJson).font(.system(.caption,design:.monospaced)).frame(minHeight:150) } }; Section("파일") { fileButton("썸네일 1장",.thumbnail,form.thumbnail); fileButton("상세 이미지 최대 20장",.images,form.detailImages); fileButton("상품 파일 최대 20개",.files,form.productFiles); if let product { ForEach(product.assets) { asset in Toggle("삭제 · \(asset.kind) · \(asset.originalName)",isOn:Binding(get:{form.removeAssetIDs.contains(asset.id)},set:{if $0{form.removeAssetIDs.insert(asset.id)}else{form.removeAssetIDs.remove(asset.id)}})) } } } }.navigationTitle(product == nil ? "새 묶음 상품" : "상품 수정").toolbar { ToolbarItem(placement:.cancellationAction){Button("취소"){dismiss()}}; ToolbarItem(placement:.confirmationAction){Button("저장 검토"){confirm=true}.disabled(form.name.trimmingCharacters(in:.whitespaces).isEmpty || form.category.isEmpty || saving)} }.fileImporter(isPresented:Binding(get:{picking != nil},set:{if !$0{picking=nil}}),allowedContentTypes:[.data],allowsMultipleSelection:true){result in if case .success(let urls)=result,let kind=picking{assign(urls,kind)};picking=nil}.confirmationDialog("상품을 저장할까요?",isPresented:$confirm,titleVisibility:.visible){Button(form.status == "PUBLISHED" ? "검증 후 공개 저장":"저장"){saving=true;Task{if await onSave(form){dismiss()};saving=false}};Button("취소",role:.cancel){}} message:{Text("이미지 실제 형식과 상품 파일 용량을 서버에서 검증합니다.")} }.presentationDetents([.large]) }
    private func fileButton(_ label:String,_ kind:FileKind,_ files:[URL])->some View{Button{picking=kind}label:{VStack(alignment:.leading){Text(label);if !files.isEmpty{Text(files.map(\.lastPathComponent).joined(separator:", ")).font(.mMicro).foregroundStyle(Tokens.text3)}}}}
    private func assign(_ urls:[URL],_ kind:FileKind){switch kind{case .thumbnail:form.thumbnail=Array(urls.prefix(1));case .images:form.detailImages=Array(urls.prefix(20));case .files:form.productFiles=Array(urls.prefix(20))}}
    private static func make(_ value:ServerAPI.StoreProduct?,_ categories:[ServerAPI.AdminStoreCategory])->AdminProductForm{guard let value else{var f=AdminProductForm();f.category=categories.first?.name ?? "";return f};var f=AdminProductForm();f.name=value.name;f.category=value.category;f.badge=value.badge;f.subtitle=value.subtitle;f.summary=value.summary;f.price=value.price;f.originalPrice=value.originalPrice;f.popularityScore=value.popularityScore;f.bundleItems=value.bundleItems.map{"\($0.name)|\($0.description)"}.joined(separator:"\n");f.status=value.status;let blocks:[[String:Any]]=value.detailBlocks.filter{$0.type=="TEXT"}.map{["type":"TEXT","text":$0.text,"fontSize":$0.fontSize,"color":$0.color,"bold":$0.bold,"underline":$0.underline,"align":$0.align]};if let data=try?JSONSerialization.data(withJSONObject:blocks,options:[.prettyPrinted]),let text=String(data:data,encoding:.utf8){f.detailBlocksJson=text};return f}
}

private struct AdminCategoryEditor:View{let category:ServerAPI.AdminStoreCategory?;let onSave:(String,Bool)async->Bool;@Environment(\.dismiss)private var dismiss;@State private var name="";@State private var visible=true;@State private var saving=false;var body:some View{NavigationStack{Form{TextField("카테고리 이름",text:$name);Toggle("사용자 상점에 공개",isOn:$visible)}.navigationTitle(category == nil ? "새 카테고리":"카테고리 편집").toolbar{ToolbarItem(placement:.cancellationAction){Button("취소"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("저장"){saving=true;Task{if await onSave(name,visible){dismiss()};saving=false}}.disabled(name.trimmingCharacters(in:.whitespaces).isEmpty || saving)}}}.onAppear{if let category{name=category.name;visible=category.isVisible}}.presentationDetents([.medium])}}
