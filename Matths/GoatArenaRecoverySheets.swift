import PhotosUI
import SwiftUI
import UIKit

extension ServerAPI {
    struct GoatArenaRevengeRight: Codable, Identifiable {
        var id: String
        var division: String
        var stakeDays: Int
        var feeDays: Int
        var expiresAt: String?
        var createdAt: String?
    }

    struct GoatArenaRevengeRightStatus: Codable {
        var schemaVersion: String
        var right: GoatArenaRevengeRight?
    }

    struct GoatArenaRevengeClaimResponse: Codable {
        var kind: String
        var match: GoatArenaMatchCommandResponse.Match
        var replayed: Bool
    }

    struct GoatArenaRevengeForfeitResponse: Codable {
        var kind: String
        var rightId: String
        var sourceMatchId: String
        var replayed: Bool
    }

    static func getArenaRevengeRight() async throws -> GoatArenaRevengeRight? {
        let response: GoatArenaRevengeRightStatus = try await request(
            "GET", "/api/v1/goat-arena/revenge-rights/pending",
            body: nil, authed: true)
        guard response.schemaVersion == "GOAT_ARENA_REVENGE_RIGHT_V1" else {
            throw ServerAPIError(
                message: "현재 앱에서 읽을 수 없는 복수권 정보입니다. 앱을 업데이트해주세요.",
                code: "GOAT_ARENA_REVENGE_RIGHT_SCHEMA_UNSUPPORTED")
        }
        return response.right
    }

    static func claimArenaRevengeRight(
        rightId: String,
        commandId: String
    ) async throws -> GoatArenaRevengeClaimResponse {
        try await request(
            "POST", "/api/v1/goat-arena/revenge-rights/\(rightId)/claim",
            body: [:], authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func forfeitArenaRevengeRight(
        rightId: String,
        commandId: String
    ) async throws -> GoatArenaRevengeForfeitResponse {
        try await request(
            "POST", "/api/v1/goat-arena/revenge-rights/\(rightId)/forfeit",
            body: [:], authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    struct GoatArenaSupplementalEvidenceRequest: Codable {
        var matchId: String
        var division: String
        var matchType: String
        var role: String
        var status: String
        var requestedAt: String?
        var deadlineAt: String?
        var requestMessage: String
        var submittedAt: String?
        var submittedLate: Bool
        var lateByMs: Int
        var fileCount: Int
        var serverNow: String
    }

    struct GoatArenaSupplementalEvidenceStatus: Codable {
        var schemaVersion: String
        var request: GoatArenaSupplementalEvidenceRequest
    }

    struct GoatArenaSupplementalEvidenceSubmission: Codable {
        var replayed: Bool
        var status: String
        var submittedAt: String?
        var submittedLate: Bool
        var lateByMs: Int
        var fileCount: Int
    }

    private struct GoatArenaSupplementalEvidenceSubmissionResponse: Codable {
        var schemaVersion: String
        var submission: GoatArenaSupplementalEvidenceSubmission
    }

    static func getArenaSupplementalEvidence(
        matchId: String
    ) async throws -> GoatArenaSupplementalEvidenceRequest {
        let response: GoatArenaSupplementalEvidenceStatus = try await request(
            "GET", "/api/v1/goat-arena/matches/\(matchId)/supplemental-evidence",
            body: nil, authed: true)
        guard response.schemaVersion == "GOAT_ARENA_SUPPLEMENTAL_EVIDENCE_V1" else {
            throw ServerAPIError(
                message: "현재 앱에서 읽을 수 없는 추가 소명 정보입니다. 앱을 업데이트해주세요.",
                code: "GOAT_ARENA_SUPPLEMENTAL_EVIDENCE_SCHEMA_UNSUPPORTED")
        }
        return response.request
    }

    static func submitArenaSupplementalEvidence(
        matchId: String,
        files: [URL],
        commandId: String
    ) async throws -> GoatArenaSupplementalEvidenceSubmission {
        guard !files.isEmpty, files.count <= 5 else {
            throw ServerAPIError(
                message: "추가 소명 사진을 1장 이상 5장 이하로 선택해주세요.",
                code: "ARENA_SUPPLEMENTAL_FILE_COUNT_INVALID")
        }
        let boundary = "Matths-Supplemental-\(UUID().uuidString)"
        var request = try authorizedRequest(
            "POST",
            "/api/v1/goat-arena/matches/\(matchId)/supplemental-evidence",
            contentType: "multipart/form-data; boundary=\(boundary)",
            timeout: 90)
        request.setValue(commandId, forHTTPHeaderField: "Idempotency-Key")
        request.setValue(clientBuildVersion, forHTTPHeaderField: "X-Matths-Client-Version")
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        var totalBytes = 0
        for (index, file) in files.enumerated() {
            let data = try Data(contentsOf: file, options: [.mappedIfSafe])
            totalBytes += data.count
            guard data.count <= 10 * 1024 * 1024, totalBytes <= 30 * 1024 * 1024 else {
                throw ServerAPIError(
                    message: "사진은 한 장당 10MB, 전체 30MB까지 제출할 수 있습니다.",
                    code: "ARENA_SUPPLEMENTAL_FILE_TOO_LARGE")
            }
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"evidenceFiles\"; filename=\"supplemental-\(index + 1).jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateAuthorizedResponse(
            response,
            errorBody: data,
            requestToken: bearerToken(from: request))
        let decoded = try JSONDecoder().decode(
            GoatArenaSupplementalEvidenceSubmissionResponse.self,
            from: data)
        guard decoded.schemaVersion == "GOAT_ARENA_SUPPLEMENTAL_EVIDENCE_V1" else {
            throw ServerAPIError(
                message: "추가 소명 접수 결과를 확인할 수 없습니다.",
                code: "GOAT_ARENA_SUPPLEMENTAL_EVIDENCE_SCHEMA_UNSUPPORTED")
        }
        return decoded.submission
    }
}

struct GoatArenaRevengeRightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onMatchCreated: (String) -> Void
    let onChanged: () -> Void

    @State private var right: ServerAPI.GoatArenaRevengeRight?
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var confirmsClaim = false
    @State private var confirmsForfeit = false
    @State private var accountSlot = DataScope.slot
    @State private var lifecycleID = UUID()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    Text("정산된 경기에서 받은 복수권을 확인하고, 사용하거나 포기할 수 있습니다.")
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                    if isLoading {
                        HStack { ProgressView(); Text("복수권 확인 중") }
                            .frame(minHeight: 52)
                    } else if let right {
                        rightCard(right)
                    } else {
                        Label("현재 사용할 수 있는 복수권이 없습니다.", systemImage: "checkmark.circle")
                            .font(.mBody)
                            .foregroundStyle(Tokens.text2)
                            .padding(Tokens.Space.s5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.danger)
                            .padding(Tokens.Space.s4)
                            .background(Tokens.dangerSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .background(Tokens.paper)
            .navigationTitle("복수전 권리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }.disabled(isActing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(isLoading || isActing)
                }
            }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
                guard let next = $0.object as? String, next != accountSlot else { return }
                lifecycleID = UUID()
                dismiss()
            }
            .onDisappear { lifecycleID = UUID() }
            .confirmationDialog("복수전을 시작할까요?", isPresented: $confirmsClaim, titleVisibility: .visible) {
                Button("예치 조건에 동의하고 시작") { Task { await claim() } }
                Button("취소", role: .cancel) {}
            } message: {
                if let right { Text(costMessage(right)) }
            }
            .confirmationDialog("복수권을 포기할까요?", isPresented: $confirmsForfeit, titleVisibility: .visible) {
                Button("복수권 포기", role: .destructive) { Task { await forfeit() } }
                Button("유지", role: .cancel) {}
            } message: {
                Text("포기한 복수권은 다시 사용할 수 없습니다. 포기만으로 학습일수나 페이백 점수는 차감되지 않습니다.")
            }
        }
    }

    private func rightCard(_ right: ServerAPI.GoatArenaRevengeRight) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Label(right.division == "MAIN" ? "Ranked 복수권" : "Unranked 복수권", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.mHeading)
                .foregroundStyle(Tokens.text1)
            Text(costMessage(right))
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.s3) {
                Button("복수전 시작") { confirmsClaim = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isActing)
                Button("권리 포기", role: .destructive) { confirmsForfeit = true }
                    .frame(minHeight: 44)
                    .disabled(isActing)
            }
            if isActing { ProgressView("서버에서 확인 중") }
        }
        .padding(Tokens.Space.s5)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.lg).strokeBorder(Tokens.line) }
    }

    private func costMessage(_ right: ServerAPI.GoatArenaRevengeRight) -> String {
        let unit = right.division == "MAIN" ? "학습일" : "페이백 점수"
        let suffix = right.division == "MAIN" ? "일" : "점"
        return "시작하면 \(unit) \(right.stakeDays)\(suffix)을 예치하고 수수료 \(right.feeDays)\(suffix) 규정을 적용합니다. 정확한 승패별 정산은 현재 Arena 룰북을 따릅니다."
    }

    @MainActor private func load() async {
        let owner = lifecycleID
        isLoading = true
        errorMessage = nil
        defer { if owner == lifecycleID { isLoading = false } }
        do {
            let value = try await ServerAPI.getArenaRevengeRight()
            guard owner == lifecycleID else { return }
            right = value
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = message(error)
        }
    }

    @MainActor private func claim() async {
        guard let right else { return }
        let owner = lifecycleID
        isActing = true
        errorMessage = nil
        defer { if owner == lifecycleID { isActing = false } }
        do {
            let result = try await ServerAPI.claimArenaRevengeRight(
                rightId: right.id, commandId: UUID().uuidString)
            guard owner == lifecycleID else { return }
            onChanged()
            onMatchCreated(result.match.id)
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = message(error)
        }
    }

    @MainActor private func forfeit() async {
        guard let right else { return }
        let owner = lifecycleID
        isActing = true
        errorMessage = nil
        defer { if owner == lifecycleID { isActing = false } }
        do {
            _ = try await ServerAPI.forfeitArenaRevengeRight(
                rightId: right.id, commandId: UUID().uuidString)
            guard owner == lifecycleID else { return }
            self.right = nil
            onChanged()
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = message(error)
        }
    }

    private func message(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? "복수권 요청을 완료하지 못했습니다."
    }
}

struct GoatArenaSupplementalEvidenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let matchId: String
    let onSubmitted: () -> Void

    @State private var request: ServerAPI.GoatArenaSupplementalEvidenceRequest?
    @State private var files: [URL]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var confirmsUpload = false
    @State private var accountSlot = DataScope.slot
    @State private var lifecycleID = UUID()

    init(matchId: String, onSubmitted: @escaping () -> Void) {
        self.matchId = matchId
        self.onSubmitted = onSubmitted
        _files = State(initialValue: SupplementalDraftStore.load(matchId: matchId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    requestCard
                    imageGrid
                    sourceButtons
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.mCaption).foregroundStyle(Tokens.danger)
                    }
                    Button {
                        confirmsUpload = true
                    } label: {
                        Label(isUploading ? "추가 소명 접수 중" : "추가 소명 제출", systemImage: "lock.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(request?.status != "REQUESTED" || files.isEmpty || isUploading || isImporting)
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .background(Tokens.paper)
            .navigationTitle("추가 소명 자료")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }.disabled(isUploading)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || isUploading || isImporting)
                    .accessibilityLabel("추가 소명 상태 새로고침")
                }
            }
            .task { await load() }
            .onChange(of: pickerItems) { _, items in Task { await importPhotos(items) } }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
                guard let next = $0.object as? String, next != accountSlot else { return }
                lifecycleID = UUID()
                dismiss()
            }
            .onDisappear { lifecycleID = UUID() }
            .confirmationDialog(
                "선택한 사진을 추가 소명으로 제출할까요?",
                isPresented: $confirmsUpload,
                titleVisibility: .visible
            ) {
                Button("사진 \(files.count)장 제출") { Task { await upload() } }
                Button("다시 확인", role: .cancel) {}
            } message: {
                Text("제출이 완료되면 이 기기에 임시 보관한 추가 소명 사진을 삭제합니다.")
            }
        }
    }

    @ViewBuilder private var requestCard: some View {
        if isLoading {
            ProgressView("추가 소명 요청 확인 중").frame(minHeight: 64)
        } else if let request {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                Label(statusLabel(request.status), systemImage: request.status == "REQUESTED" ? "clock.badge.exclamationmark.fill" : "checkmark.seal.fill")
                    .font(.mHeading)
                    .foregroundStyle(request.status == "REQUESTED" ? Tokens.warningInk : Tokens.successInk)
                if !request.requestMessage.isEmpty {
                    Text(request.requestMessage).font(.mBody).foregroundStyle(Tokens.text1)
                }
                if let deadline = request.deadlineAt.flatMap(SupplementalServerDate.parse) {
                    Text("제출 기한 · \(deadline.formatted(date: .abbreviated, time: .shortened))")
                        .font(.mCaption).foregroundStyle(Tokens.text2).monospacedDigit()
                }
                Text("운영자가 요청한 자료만 제출하세요. 사진은 최대 5장, 한 장당 10MB입니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
            .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.lg).strokeBorder(Tokens.line) }
        }
    }

    @ViewBuilder private var imageGrid: some View {
        if files.isEmpty {
            Text("선택한 추가 소명 사진이 없습니다.")
                .font(.mBody).foregroundStyle(Tokens.text2)
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 12)], spacing: 12) {
                ForEach(files, id: \.path) { file in
                    ZStack(alignment: .topTrailing) {
                        if let image = UIImage(contentsOfFile: file.path) {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(height: 120).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
                        }
                        Button { remove(file) } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2)
                                .symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.7))
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("소명 사진 삭제")
                        .disabled(isUploading)
                    }
                }
            }
        }
    }

    private var sourceButtons: some View {
        PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, 5 - files.count), matching: .images) {
            Label("사진 보관함에서 선택", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(files.count >= 5 || isUploading || request?.status != "REQUESTED")
    }

    @MainActor private func load() async {
        let owner = lifecycleID
        isLoading = true
        defer { if owner == lifecycleID { isLoading = false } }
        do {
            let value = try await ServerAPI.getArenaSupplementalEvidence(matchId: matchId)
            guard owner == lifecycleID else { return }
            request = value
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = (error as? ServerAPIError)?.errorDescription ?? "추가 소명 요청을 확인하지 못했습니다."
        }
    }

    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty, files.count < 5 else { return }
        isImporting = true
        defer { isImporting = false; pickerItems = [] }
        for item in items.prefix(5 - files.count) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "일부 사진을 읽지 못했습니다."
                continue
            }
            let normalized = image.normalizedUp().resizedToPixelBudget(3_000_000)
            guard let jpeg = normalized.jpegData(compressionQuality: 0.88) else { continue }
            let url = DataScope.url("arena-supplemental-\(matchId.prefix(8))-\(UUID().uuidString).jpg", for: accountSlot)
            do {
                try jpeg.write(to: url, options: .atomic)
                files.append(url)
            } catch {
                errorMessage = "사진을 임시 보관하지 못했습니다. 저장 공간을 확인해주세요."
            }
        }
        SupplementalDraftStore.save(files, matchId: matchId)
    }

    private func remove(_ file: URL) {
        files.removeAll { $0 == file }
        try? FileManager.default.removeItem(at: file)
        SupplementalDraftStore.save(files, matchId: matchId)
    }

    @MainActor private func upload() async {
        guard request?.status == "REQUESTED", !files.isEmpty else { return }
        let owner = lifecycleID
        isUploading = true
        errorMessage = nil
        defer { if owner == lifecycleID { isUploading = false } }
        do {
            let result = try await ServerAPI.submitArenaSupplementalEvidence(
                matchId: matchId, files: files, commandId: UUID().uuidString)
            guard owner == lifecycleID else { return }
            SupplementalDraftStore.clear(files, matchId: matchId)
            files = []
            if var current = request {
                current.status = result.status
                current.submittedAt = result.submittedAt
                current.fileCount = result.fileCount
                request = current
            }
            onSubmitted()
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = (error as? ServerAPIError)?.errorDescription ?? "추가 소명 자료를 제출하지 못했습니다."
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "REQUESTED": "추가 소명 제출이 필요합니다"
        case "SUBMITTED": "추가 소명이 접수되었습니다"
        case "EXPIRED": "추가 소명 제출 기한이 끝났습니다"
        default: "추가 소명 상태를 확인해주세요"
        }
    }
}

private enum SupplementalServerDate {
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private enum SupplementalDraftStore {
    private static func url(matchId: String) -> URL {
        let safe = matchId.filter { $0.isLetter || $0.isNumber }
        return DataScope.url("arena-supplemental-draft-\(safe).json")
    }
    static func load(matchId: String) -> [URL] {
        guard let data = try? Data(contentsOf: url(matchId: matchId)),
              let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths.map(URL.init(fileURLWithPath:)).filter { FileManager.default.fileExists(atPath: $0.path) }
    }
    static func save(_ files: [URL], matchId: String) {
        guard let data = try? JSONEncoder().encode(files.map(\.path)) else { return }
        try? data.write(to: url(matchId: matchId), options: .atomic)
    }
    static func clear(_ files: [URL], matchId: String) {
        files.forEach { try? FileManager.default.removeItem(at: $0) }
        try? FileManager.default.removeItem(at: url(matchId: matchId))
    }
}
