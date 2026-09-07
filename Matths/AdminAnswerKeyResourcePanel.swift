import SwiftUI

struct AdminAnswerKeyResourcePanel: View {
    @EnvironmentObject private var store: AppStore
    @State private var downloaded: [AdminAnswerKeyResource: URL] = [:]
    @State private var downloadOwner: AccountRequestOwner?
    @State private var loading: AdminAnswerKeyResource?
    @State private var task: Task<Void, Never>?
    @State private var errorMessage: String?
    private var trigger: String {
        String(describing: store.captureAccountSessionBoundary()) + "#" + DataScope.slot + "#" + (store.serverProfile?.role ?? "")
    }
    private var canDisplayDownload: Bool {
        downloadOwner?.isCurrent(in: store) == true && store.serverProfile?.role?.lowercased() == "admin"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("30문항 모의고사는 v3 questions 형식을 사용합니다. 번호 1–30을 빠짐없이 지정하고, 유형·정답·배점·개념·해설을 문항별로 작성해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Text("객관식·단답형 혼합 가능 · 문항별 2·3·4점, 총 100점. concept의 ID와 제목은 같은 카탈로그 레코드에서 복사하고 모든 자리표시자를 실제 내용으로 바꿔야 합니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            ForEach(AdminAnswerKeyResource.allCases) { resource in
                VStack(alignment: .leading, spacing: 4) {
                    Button { download(resource) } label: {
                        HStack { Label(resource.title, systemImage: "arrow.down.doc"); if loading == resource { ProgressView() } }
                            .frame(minHeight: 44)
                    }.disabled(loading != nil)
                    if canDisplayDownload, let url = downloaded[resource] {
                        ShareLink(item: url) { Label("파일에 저장·공유", systemImage: "square.and.arrow.up") }
                            .font(.mCaption).frame(minHeight: 44)
                    }
                }
            }
            if let errorMessage { Text(errorMessage).font(.mCaption).foregroundStyle(Tokens.dangerInk) }
        }
        .onChange(of: trigger) { _, _ in clear() }
        .onDisappear { clear() }
    }
    @MainActor private func clear() {
        task?.cancel(); task = nil; downloadOwner = nil; downloaded = [:]; loading = nil; errorMessage = nil
    }
    @MainActor private func download(_ resource: AdminAnswerKeyResource) {
        guard loading == nil, store.serverProfile?.role?.lowercased() == "admin", let owner = AccountRequestOwner(store: store) else { return }
        downloadOwner = owner; loading = resource; errorMessage = nil
        task = Task {
            guard owner.isCurrent(in: store), store.serverProfile?.role?.lowercased() == "admin" else { return }
            do {
                let data = try await ServerAPI.adminAnswerKeyResource(resource, authorization: owner.authorization)
                guard owner.isCurrent(in: store), downloadOwner?.id == owner.id, store.serverProfile?.role?.lowercased() == "admin" else { return }
                // Check and private atomic write are synchronous on the same
                // actor, so a suspended old-account write cannot recreate a
                // directory after logout/account deletion.
                let directory = owner.directory.appendingPathComponent("AdminAnswerKeyResources", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(resource.filename)")
                try ProtectedFileWriter.write(data, to: destination)
                downloaded[resource] = destination
            } catch {
                guard owner.isCurrent(in: store), downloadOwner?.id == owner.id else { return }
                errorMessage = (error as? ServerAPIError)?.errorDescription ?? "작성 자료를 내려받지 못했습니다. 다시 시도해 주세요."
            }
            if downloadOwner?.id == owner.id { loading = nil }
        }
    }
}
