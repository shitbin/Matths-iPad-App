import SwiftUI
import UniformTypeIdentifiers

@MainActor
private final class AdminArchiveModel: ObservableObject {
    @Published var dashboard: ServerAPI.AdminArchiveDashboard?
    @Published var selectedIDs = Set<String>()
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var preview: AcademyPreviewFile?

    func load(folderID: String? = nil) async {
        isLoading = dashboard == nil; errorMessage = nil
        do { dashboard = try await ServerAPI.adminArchive(folderID: folderID); selectedIDs.removeAll() }
        catch is CancellationError {} catch { errorMessage = readable(error) }
        isLoading = false
    }
    func apply(id: String, message: String, operation: () async throws -> ServerAPI.AdminArchiveDashboard) async -> Bool {
        guard actionID == nil else { return false }; actionID = id; errorMessage = nil; noticeMessage = nil
        do { dashboard = try await operation(); selectedIDs.removeAll(); noticeMessage = message; actionID = nil; return true }
        catch { errorMessage = readable(error); actionID = nil; return false }
    }
    func open(_ item: ServerAPI.AdminArchiveItem) async {
        guard actionID == nil else { return }; actionID = "open:\(item.id)"; errorMessage = nil
        do { preview = .init(url: try await ServerAPI.downloadAdminArchiveItem(item)) }
        catch { errorMessage = readable(error) }
        actionID = nil
    }
    private func readable(_ error: Error) -> String { (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription }
}

struct AdminArchiveScreen: View {
    private enum Section: String, CaseIterable, Identifiable { case files = "자료", trash = "휴지통"; var id: String { rawValue } }
    private struct FolderEdit: Identifiable { var folder: ServerAPI.AdminArchiveFolder?; var id: String { folder?.id ?? "new" } }
    private struct MoveRequest: Identifiable { let ids: [String]; var id: String { ids.joined(separator: ":") } }
    private enum Destructive: Identifiable {
        case folder(ServerAPI.AdminArchiveFolder), item(ServerAPI.AdminArchiveItem), purge(ServerAPI.AdminArchiveItem)
        var id: String { switch self { case .folder(let v): "folder:\(v.id)"; case .item(let v): "item:\(v.id)"; case .purge(let v): "purge:\(v.id)" } }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminArchiveModel()
    @State private var section: Section = .files
    @State private var folderEdit: FolderEdit?
    @State private var moveRequest: MoveRequest?
    @State private var destructive: Destructive?
    @State private var showsUpload = false
    let onClose: () -> Void

    private var compactLandscape: Bool { verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize }
    private var folderID: String? { model.dashboard?.selectedFolder?.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let value = model.errorMessage { banner(value, Tokens.dangerInk, "exclamationmark.triangle.fill") }
            if let value = model.noticeMessage { banner(value, Tokens.successInk, "checkmark.circle.fill") }
            if model.isLoading && model.dashboard == nil { Spacer(); ProgressView("자료실을 불러오는 중입니다"); Spacer() }
            else if let dashboard = model.dashboard {
                if section == .trash { trash(dashboard) }
                else if compactLandscape { HStack(spacing: 0) { folders(dashboard).frame(width: 340); Divider(); items(dashboard).frame(maxWidth: .infinity, maxHeight: .infinity) } }
                else { ScrollView { VStack(spacing: 12) { folders(dashboard, ownsScroll: false); items(dashboard, ownsScroll: false) }.readableWidth(Tokens.readableWidth).adaptiveHPadding().adaptiveVPadding() } }
            } else { ContentUnavailableView("자료실을 불러오지 못했습니다", systemImage: "externaldrive.badge.exclamationmark") }
        }
        .background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .task { await model.load() }
        .compactHeightSheet(item: $model.preview) { value in CommunityFilePreview(url: value.url) { model.preview = nil }.ignoresSafeArea() }
        .sheet(item: $folderEdit) { value in AdminArchiveFolderSheet(folder: value.folder, parentID: folderID) { folder in await saveFolder(value.folder, form: folder) } }
        .sheet(item: $moveRequest) { value in AdminArchiveMoveSheet(folders: model.dashboard?.folderOptions ?? [], selectedFolderID: folderID) { destination in await move(value.ids, destination: destination) } }
        .sheet(isPresented: $showsUpload) { AdminArchiveUploadSheet(categories: model.dashboard?.categories ?? [], folderID: folderID) { form in await upload(form) } }
        .confirmationDialog("이 작업을 실행할까요?", isPresented: Binding(get: { destructive != nil }, set: { if !$0 { destructive = nil } }), titleVisibility: .visible) {
            Button(destructiveLabel, role: .destructive) { if let value = destructive { Task { await performDestructive(value) } } }
            Button("취소", role: .cancel) { destructive = nil }
        } message: { Text(destructiveMessage) }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("관리자 홈")
                VStack(alignment: .leading, spacing: 1) { Text("자료실 관리").font(.mHeading); Text("폴더·업로드·공개 자료·휴지통").font(.mCaption).foregroundStyle(Tokens.text2) }
                Spacer()
                Menu {
                    Button("새 폴더") { folderEdit = .init(folder: nil) }
                    Button("자료 업로드") { showsUpload = true }
                } label: { Image(systemName: "plus.circle").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Button { Task { await model.load(folderID: folderID) } } label: { Image(systemName: "arrow.clockwise").frame(width: 44, height: 44) }.buttonStyle(.plain).foregroundStyle(Tokens.primary)
            }
            Picker("자료실 구역", selection: $section) { ForEach(Section.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
        }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
    }

    private func folders(_ dashboard: ServerAPI.AdminArchiveDashboard, ownsScroll: Bool = true) -> some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack { Text(dashboard.selectedFolder?.name ?? "루트 폴더").font(.mBodyB); Spacer(); if dashboard.selectedFolder != nil { Button("상위") { Task { await model.load(folderID: dashboard.breadcrumbs.dropLast().last?.id) } }.buttonStyle(.bordered) } }
            if let current = dashboard.selectedFolder { folderMenu(current).frame(maxWidth: .infinity, alignment: .trailing) }
            if dashboard.folders.isEmpty { Text("하위 폴더가 없습니다.").font(.mCaption).foregroundStyle(Tokens.text3).frame(maxWidth: .infinity, minHeight: 80) }
            ForEach(dashboard.folders) { folder in
                HStack(spacing: 8) {
                    Button { Task { await model.load(folderID: folder.id) } } label: {
                        HStack { Image(systemName: folder.isPinned ? "folder.fill.badge.plus" : "folder.fill").foregroundStyle(Tokens.primary); VStack(alignment: .leading) { Text(folder.name).font(.mBodyB); Text("\(folder.itemCount)개 · \(accessLabel(folder.requiredAccessLevel))").font(.mMicro).foregroundStyle(Tokens.text3) }; Spacer(); Image(systemName: "chevron.right") }
                    }.buttonStyle(.plain)
                    folderMenu(folder)
                }.padding(10).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
            }
        }.padding(12)
        return Group { if ownsScroll { ScrollView { content } } else { content } }
    }

    private func folderMenu(_ folder: ServerAPI.AdminArchiveFolder) -> some View {
        Menu {
            Button("이름·권한 편집") { folderEdit = .init(folder: folder) }
            Button(folder.isPinned ? "상단 고정 해제" : "상단 고정") { Task { await pin(folder) } }
            Button("빈 폴더 삭제", role: .destructive) { destructive = .folder(folder) }
        } label: { Image(systemName: "ellipsis.circle").frame(width: 38, height: 38) }.accessibilityLabel("\(folder.name) 관리")
    }

    private func items(_ dashboard: ServerAPI.AdminArchiveDashboard, ownsScroll: Bool = true) -> some View {
        let content = VStack(alignment: .leading, spacing: 9) {
            HStack { Text("자료 \(dashboard.items.count)개").font(.mBodyB); Spacer(); if !model.selectedIDs.isEmpty { Text("\(model.selectedIDs.count)개 선택").font(.mCaption).foregroundStyle(Tokens.primary) } }
            if !model.selectedIDs.isEmpty {
                HStack { Button("이동") { moveRequest = .init(ids: Array(model.selectedIDs)) }.buttonStyle(.bordered); Button("휴지통", role: .destructive) { Task { await bulkDelete() } }.buttonStyle(.bordered) }
            }
            if dashboard.items.isEmpty { ContentUnavailableView("자료 없음", systemImage: "doc.text.magnifyingglass").frame(maxWidth: .infinity, minHeight: 160) }
            ForEach(dashboard.items) { item in itemRow(item) }
        }.padding(12)
        return Group { if ownsScroll { ScrollView { content } } else { content } }
    }

    private func itemRow(_ item: ServerAPI.AdminArchiveItem) -> some View {
        HStack(spacing: 9) {
            Button { toggle(item.id) } label: { Image(systemName: model.selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Tokens.primary) }.buttonStyle(.plain).accessibilityLabel(model.selectedIDs.contains(item.id) ? "선택 해제" : "선택")
            Button { Task { await model.open(item) } } label: {
                VStack(alignment: .leading, spacing: 3) { HStack { Text(item.title).font(.mBodyB); if !item.isPublished { badge("비공개") } }; Text("\(item.category) · \(ByteCountFormatter.string(fromByteCount: Int64(item.sizeBytes), countStyle: .file)) · 다운로드 \(item.downloadCount)").font(.mMicro).foregroundStyle(Tokens.text3); if item.backupStatus != "READY" { Text("백업 \(item.backupStatus)").font(.mMicro).foregroundStyle(Tokens.warning) } }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            Menu { Button("열기") { Task { await model.open(item) } }; Button("다른 폴더로 이동") { moveRequest = .init(ids: [item.id]) }; Button("휴지통으로 이동", role: .destructive) { destructive = .item(item) } } label: { Image(systemName: "ellipsis.circle").frame(width: 38, height: 38) }
        }.padding(10).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
    }

    private func trash(_ dashboard: ServerAPI.AdminArchiveDashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
                Text("휴지통 \(dashboard.trashItems.count)개").font(.mHeading)
                Text("삭제 후 30일 동안 복구할 수 있습니다. 영구 삭제는 파일 원본까지 제거됩니다.").font(.mCaption).foregroundStyle(Tokens.text2)
                if dashboard.trashItems.isEmpty { ContentUnavailableView("휴지통이 비었습니다", systemImage: "trash") }
                ForEach(dashboard.trashItems) { item in
                    VStack(alignment: .leading, spacing: 7) { Text(item.title).font(.mBodyB); Text("삭제 \(date(item.deletedAt)) · 영구 삭제 예정 \(date(item.purgeAfter))").font(.mMicro).foregroundStyle(Tokens.text3); HStack { Button("복구") { Task { await restore(item) } }.buttonStyle(.borderedProminent); Button("영구 삭제", role: .destructive) { destructive = .purge(item) }.buttonStyle(.bordered) } }.padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
                }
            }.readableWidth(760).adaptiveHPadding().adaptiveVPadding()
        }
    }

    private func saveFolder(_ existing: ServerAPI.AdminArchiveFolder?, form: AdminArchiveFolderForm) async -> Bool {
        await model.apply(id: "folder:\(existing?.id ?? "new")", message: existing == nil ? "폴더를 만들었습니다." : "폴더 정보를 저장했습니다.") {
            if let existing { try await ServerAPI.updateAdminArchiveFolder(id: existing.id, name: form.name, description: form.description, accessLevel: form.accessLevel) }
            else { try await ServerAPI.createAdminArchiveFolder(name: form.name, description: form.description, parentID: folderID, accessLevel: form.accessLevel) }
        }
    }
    private func pin(_ folder: ServerAPI.AdminArchiveFolder) async { _ = await model.apply(id: "pin:\(folder.id)", message: folder.isPinned ? "상단 고정을 해제했습니다." : "상단에 고정했습니다.") { try await ServerAPI.pinAdminArchiveFolder(id: folder.id, pinned: !folder.isPinned) } }
    private func move(_ ids: [String], destination: String?) async -> Bool { await model.apply(id: "move", message: "선택 자료를 이동했습니다.") { try await ServerAPI.moveAdminArchiveItems(ids: ids, destinationFolderID: destination, folderID: folderID) } }
    private func bulkDelete() async { _ = await model.apply(id: "bulk-delete", message: "선택 자료를 휴지통으로 옮겼습니다.") { try await ServerAPI.deleteAdminArchiveItems(ids: Array(model.selectedIDs), folderID: folderID) } }
    private func restore(_ item: ServerAPI.AdminArchiveItem) async { _ = await model.apply(id: "restore:\(item.id)", message: "자료를 원래 위치로 복구했습니다.") { try await ServerAPI.restoreAdminArchiveItem(id: item.id) } }
    private func upload(_ form: AdminArchiveUploadForm) async -> Bool { await model.apply(id: "upload", message: form.notify ? "자료를 등록하고 회원에게 공지했습니다." : "자료를 등록했습니다.") { try await ServerAPI.uploadAdminArchive(files: form.files, description: form.description, category: form.category, folderID: folderID, notifyUsers: form.notify) } }
    private func performDestructive(_ value: Destructive) async {
        switch value {
        case .folder(let folder): _ = await model.apply(id: value.id, message: "빈 폴더를 삭제했습니다.") { try await ServerAPI.deleteAdminArchiveFolder(id: folder.id) }
        case .item(let item): _ = await model.apply(id: value.id, message: "자료를 휴지통으로 옮겼습니다.") { try await ServerAPI.deleteAdminArchiveItem(id: item.id, folderID: folderID) }
        case .purge(let item): _ = await model.apply(id: value.id, message: "자료 원본을 영구 삭제했습니다.") { try await ServerAPI.purgeAdminArchiveItem(id: item.id) }
        }
        destructive = nil
    }
    private func toggle(_ id: String) { if model.selectedIDs.contains(id) { model.selectedIDs.remove(id) } else { model.selectedIDs.insert(id) } }
    private var destructiveLabel: String { switch destructive { case .folder: "빈 폴더 삭제"; case .item: "휴지통으로 이동"; case .purge: "파일 원본 영구 삭제"; case nil: "삭제" } }
    private var destructiveMessage: String { switch destructive { case .folder: "폴더 안에 자료나 하위 폴더가 있으면 서버가 삭제를 거부합니다."; case .item: "30일 동안 휴지통에서 복구할 수 있습니다."; case .purge: "복구할 수 없으며 저장소 원본도 제거됩니다."; case nil: "" } }
    private func accessLabel(_ value: String) -> String { ["AUTHENTICATED":"로그인 회원", "MOCK_EXAM_PACKAGE":"주간 모의고사 이용권", "LEARNING_PACKAGE":"29일 학습권"][value] ?? value }
    private func badge(_ value: String) -> some View { Text(value).font(.mMicro.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3).foregroundStyle(Tokens.primary).background(Tokens.primary.opacity(0.1), in: Capsule()) }
    private func banner(_ value: String, _ color: Color, _ icon: String) -> some View { Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(color.opacity(0.1)) }
    private func date(_ value: String?) -> String { guard let value else { return "—" }; let parser = ISO8601DateFormatter(); parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return (parser.date(from: value) ?? ISO8601DateFormatter().date(from: value))?.formatted(date: .numeric, time: .shortened) ?? value }
}

private struct AdminArchiveFolderForm { var name = ""; var description = ""; var accessLevel = "AUTHENTICATED" }
private struct AdminArchiveFolderSheet: View {
    let folder: ServerAPI.AdminArchiveFolder?; let parentID: String?; let onSubmit: (AdminArchiveFolderForm) async -> Bool
    @Environment(\.dismiss) private var dismiss; @State private var form = AdminArchiveFolderForm(); @State private var saving = false
    var body: some View { NavigationStack { Form { TextField("폴더 이름", text: $form.name); TextField("설명", text: $form.description, axis: .vertical).lineLimit(3...6); Picker("접근 권한", selection: $form.accessLevel) { Text("로그인 회원").tag("AUTHENTICATED"); Text("주간 모의고사 이용권").tag("MOCK_EXAM_PACKAGE"); Text("29일 학습권").tag("LEARNING_PACKAGE") }; if parentID != nil && folder == nil { Text("현재 폴더 아래에 생성합니다.").font(.mCaption).foregroundStyle(Tokens.text2) } }.navigationTitle(folder == nil ? "새 폴더" : "폴더 편집").toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("저장") { saving = true; Task { if await onSubmit(form) { dismiss() }; saving = false } }.disabled(form.name.count < 2 || saving) } } }.onAppear { if let folder { form = .init(name: folder.name, description: folder.description, accessLevel: folder.accessLevel) } }.presentationDetents([.medium, .large]) }
}

private struct AdminArchiveMoveSheet: View {
    let folders: [ServerAPI.AdminArchiveFolder]; let selectedFolderID: String?; let onSubmit: (String?) async -> Bool
    @Environment(\.dismiss) private var dismiss; @State private var destination = ""; @State private var saving = false
    var body: some View { NavigationStack { Form { Picker("이동할 폴더", selection: $destination) { Text("루트").tag(""); ForEach(folders) { Text(String(repeating: "　", count: $0.depth ?? 0) + ($0.pathLabel ?? $0.name)).tag($0.id) } } }.navigationTitle("자료 이동").toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("이동") { saving = true; Task { if await onSubmit(destination.isEmpty ? nil : destination) { dismiss() }; saving = false } }.disabled(saving || destination == selectedFolderID) } } }.presentationDetents([.medium]) }
}

private struct AdminArchiveUploadForm { var files: [URL] = []; var description = ""; var category = "기타"; var notify = false }
private struct AdminArchiveUploadSheet: View {
    let categories: [String]; let folderID: String?; let onSubmit: (AdminArchiveUploadForm) async -> Bool
    @Environment(\.dismiss) private var dismiss; @State private var form = AdminArchiveUploadForm(); @State private var picking = false; @State private var saving = false; @State private var confirming = false
    var body: some View { NavigationStack { Form { Section("파일") { Button { picking = true } label: { Label("파일 선택 (최대 20개)", systemImage: "doc.badge.plus") }; ForEach(form.files, id: \.path) { Text($0.lastPathComponent).font(.mCaption) } }; Section("분류") { Picker("카테고리", selection: $form.category) { ForEach(categories.isEmpty ? ["기타"] : categories, id: \.self) { Text($0).tag($0) } }; TextField("공통 설명", text: $form.description, axis: .vertical).lineLimit(3...6); Toggle("등록 후 회원에게 공지", isOn: $form.notify) }; if folderID != nil { Section { Text("현재 폴더에 등록합니다.").font(.mCaption).foregroundStyle(Tokens.text2) } } }.navigationTitle("자료 업로드").toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("등록 검토") { confirming = true }.disabled(form.files.isEmpty || saving) } }.fileImporter(isPresented: $picking, allowedContentTypes: [.data], allowsMultipleSelection: true) { if case .success(let urls) = $0 { form.files = Array(urls.prefix(20)) } }.confirmationDialog("선택 자료를 등록할까요?", isPresented: $confirming, titleVisibility: .visible) { Button(form.notify ? "등록하고 회원 공지" : "자료 등록") { saving = true; Task { if await onSubmit(form) { dismiss() }; saving = false } }; Button("취소", role: .cancel) {} } message: { Text("서버에서 파일 실제 형식과 총 용량을 검증한 뒤 저장합니다.") } }.presentationDetents([.large]) }
}
