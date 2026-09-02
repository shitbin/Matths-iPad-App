//
//  GoatArenaEvidencePanel.swift
//  Matths
//
//  5문항 답안 제출 직후 서버가 준 60초 안에 풀이 사진 1~5장을 올리는 화면.
//  파일과 멱등키를 계정 슬롯에 보관해 연결 실패 뒤에도 같은 제출로 재시도한다.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct GoatArenaEvidencePanel: View {
    let matchId: String
    let attemptId: String
    let deadlineAt: Date?
    let clientBuildVersion: String
    let accountSlot: String
    let reviewContext: CheatingProblemContext
    var onUploaded: (ServerAPI.GoatArenaEvidenceReceipt) -> Void = { _ in }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var store: AppStore
    /// 웹 경기 페이지는 문항이 그대로 보이는 평가면이다. 네이티브 경기 화면과 같은
    /// 보호 계층을 웹뷰에도 건네야 "앱에서만 지키는 규칙"이 되지 않는다.
    @EnvironmentObject private var screenshotGuard: ScreenshotGuard

    @State private var files: [EvidenceFile]
    @State private var evidenceSubmissionId: String
    @State private var receipt: ServerAPI.GoatArenaEvidenceReceipt?
    @State private var isUploading = false
    @State private var pickerBusy = false
    @State private var errorMessage: String?
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var now = Date()
    @State private var scopeIsValid = true
    @State private var uploadOperationID: UUID?
    /// 이 서버의 `/api/v1` 에 증거 제출 라우트가 없을 때(HTTP_404) 선다.
    /// 재시도해도 같은 결과라 60초 카운트다운 동안 정체불명 오류 앞에 학생을
    /// 가두지 않고, 웹 경기 페이지의 같은 제출 자리로 바로 보낸다.
    @State private var routeMissing = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(
        matchId: String,
        attemptId: String,
        deadlineAt: Date?,
        clientBuildVersion: String,
        accountSlot: String,
        reviewContext: CheatingProblemContext,
        onUploaded: @escaping (ServerAPI.GoatArenaEvidenceReceipt) -> Void = { _ in }
    ) {
        self.matchId = matchId
        self.attemptId = attemptId
        self.deadlineAt = deadlineAt
        self.clientBuildVersion = clientBuildVersion
        self.accountSlot = accountSlot
        self.reviewContext = reviewContext
        self.onUploaded = onUploaded
        let draft = GoatArenaEvidenceDraftStore.load(
            matchId: matchId,
            attemptId: attemptId,
            accountSlot: accountSlot)
        _files = State(initialValue: draft?.existingFiles ?? [])
        _evidenceSubmissionId = State(
            initialValue: draft?.submissionId ?? UUID().uuidString)
    }

    private var remainingSeconds: Int? {
        guard let deadlineAt else { return nil }
        return max(0, Int(ceil(deadlineAt.timeIntervalSince(now))))
    }

    private var expired: Bool { remainingSeconds == 0 }
    private var canAdd: Bool {
        scopeIsValid && DataScope.slot == accountSlot &&
            files.count < 5 && !expired && !isUploading
    }
    private var canUpload: Bool {
        scopeIsValid && DataScope.slot == accountSlot &&
            !files.isEmpty && files.count <= 5 && !expired && !isUploading && !pickerBusy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s5) {
            header

            if let receipt {
                uploaded(receipt)
            } else {
                deadlineBanner
                evidenceGrid
                sourceButtons

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.warningInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if routeMissing {
                    webEvidenceHandoff
                } else {
                    Button {
                        Task { await upload() }
                    } label: {
                        HStack(spacing: Tokens.Space.s2) {
                            if isUploading { ProgressView().controlSize(.small) }
                            Label(
                                isUploading ? "서버에 고정하는 중" : "풀이 증거 제출",
                                systemImage: "lock.shield.fill")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 340)
                    .disabled(!canUpload)
                }

                Text("사진은 마감 전에 먼저 접수됩니다. 접수 뒤 이 기기의 로컬 비전 모델이 풀이 과정을 순서대로 검토하며, 결과는 자동 유죄·점수·정산이 아닌 별도 검토 후보 신호로만 첨부됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg)
                .strokeBorder(expired ? Tokens.warningInk.opacity(0.5) : Tokens.line, lineWidth: 1)
        }
        .onAppear { persistDraft() }
        .onReceive(timer) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
            guard let newSlot = note.object as? String,
                  newSlot != accountSlot else { return }
            scopeIsValid = false
            uploadOperationID = nil
            isUploading = false
            pickerBusy = false
            showPhotoPicker = false
            showFileImporter = false
            showCamera = false
        }
        .compactHeightSheet(isPresented: $showPhotoPicker) {
            SystemPhotoPicker { provider, assetID in
                showPhotoPicker = false
                guard let provider else { return }
                loadPhoto(provider: provider, assetID: assetID)
            }
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true,
            onCompletion: importFiles)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                guard let image else { return }
                add(image: image)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("풀이 증거 제출")
                .font(.mMicro)
                .foregroundStyle(Tokens.primary)
            Text("풀이 사진을 제출해 주세요")
                .font(.mTitle)
                .foregroundStyle(Tokens.ink)
            Text("문제지에 직접 작성한 풀이가 한 장 안에 잘 보이도록 촬영하세요. 1장 이상, 최대 5장까지 제출할 수 있습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 라우트가 없는 서버에서 "다시 시도"는 같은 404를 한 번 더 맞는 일이다.
    /// 학생이 실제로 사진을 낼 수 있는 유일한 자리(로그인이 이어진 웹 경기 페이지)로
    /// 바로 보낸다. 마감은 서버가 세는 같은 시각이라 문구로 그 사실을 남긴다.
    private var webEvidenceHandoff: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Button {
                ArenaWebPresenter.open(
                    .match(matchId: matchId),
                    guardModel: screenshotGuard,
                    onCapture: { store.recordStuckPoint($0) })
            } label: {
                Label("웹에서 풀이 사진 제출", systemImage: "arrow.up.forward.app.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 340)

            Text("같은 계정으로 이어진 웹 경기 화면이 앱 안에서 열립니다. 마감 시각은 서버가 세는 같은 시각입니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deadlineBanner: some View {
        HStack(alignment: .center, spacing: Tokens.Space.s3) {
            Image(systemName: expired ? "clock.badge.exclamationmark.fill" : "timer")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(expired ? Tokens.warningInk : Tokens.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(expired ? "제출 시간이 종료되었습니다" : "서버 제출 마감")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                Text(deadlineText)
                    .font(.mCaption)
                    .foregroundStyle(expired ? Tokens.warningInk : Tokens.text2)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            if let remainingSeconds, !expired {
                Text(String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60))
                    .font(.mTitle)
                    .foregroundStyle(remainingSeconds <= 15 ? Tokens.warningInk : Tokens.primary)
                    .monospacedDigit()
            }
        }
        .padding(Tokens.Space.s4)
        .background(expired ? Tokens.warningSoft : Tokens.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private var deadlineText: String {
        guard let deadlineAt else { return "서버 마감 시각을 확인하고 있습니다." }
        return deadlineAt.formatted(
            Date.FormatStyle(date: .omitted, time: .standard)
                .locale(Locale(identifier: "ko_KR")))
    }

    @ViewBuilder
    private var evidenceGrid: some View {
        if files.isEmpty {
            VStack(spacing: Tokens.Space.s3) {
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Tokens.text3)
                Text("선택한 풀이 사진이 없습니다")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.text2)
                Text("사진은 제출 전까지 이 계정으로 로그인한 기기에만 임시 저장됩니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(Tokens.paper)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 104 : 132), spacing: 12)],
                spacing: 12
            ) {
                ForEach(Array(files.enumerated()), id: \.element.id) { index, file in
                    evidenceTile(file, number: index + 1)
                }
            }
        }
    }

    private func evidenceTile(_ file: EvidenceFile, number: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(contentsOfFile: file.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.gray.opacity(0.12)
                        .overlay(Image(systemName: "photo.badge.exclamationmark"))
                }
            }
            .frame(height: 132)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))

            Text("\(number)")
                .font(.mMicro)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.black.opacity(0.62), in: Capsule())
                .padding(7)

            Button {
                remove(file)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.72))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: 2, y: 32)
            .disabled(isUploading)
            .accessibilityLabel("\(number)번 사진 삭제")
        }
    }

    @ViewBuilder
    private var sourceButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Space.s3) { sourceButtonContent }
            VStack(spacing: Tokens.Space.s3) { sourceButtonContent }
        }
    }

    @ViewBuilder
    private var sourceButtonContent: some View {
        Button {
            showPhotoPicker = true
        } label: {
            Label("사진 보관함", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(!canAdd)

        Button {
            showFileImporter = true
        } label: {
            Label("파일에서", systemImage: "folder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(!canAdd)

        if CameraPicker.isAvailable {
            Button {
                showCamera = true
            } label: {
                Label("촬영하기", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!canAdd)
        }
    }

    private func uploaded(_ receipt: ServerAPI.GoatArenaEvidenceReceipt) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Label("풀이 증거가 서버에 고정되었습니다", systemImage: "checkmark.seal.fill")
                .font(.mBodyB)
                .foregroundStyle(Tokens.successInk)
            Text(receipt.replayed
                 ? "이전에 접수된 동일 제출을 확인했습니다. 중복 파일은 만들지 않았습니다."
                 : "상대 제출과 검토가 끝날 때까지 점수나 승패를 미리 표시하지 않습니다.")
                .font(.mCallout)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Text("접수 번호 · \(receipt.evidenceId)")
                .font(.mCaption)
                .foregroundStyle(Tokens.text3)
                .textSelection(.enabled)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.successSoft)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func loadPhoto(provider: NSItemProvider, assetID: String?) {
        guard canAdd else { return }
        let ownerSlot = accountSlot
        pickerBusy = true
        errorMessage = nil
        Task {
            let result = await PhotoIntake.load(provider: provider, assetID: assetID)
            await MainActor.run {
                guard scopeIsValid, DataScope.slot == ownerSlot else { return }
                pickerBusy = false
                switch result {
                case .success(let image): add(image: image)
                case .failure(let failure): errorMessage = failure.message
                }
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard canAdd, DataScope.slot == accountSlot else { return }
        switch result {
        case .failure(let error):
            #if DEBUG
            print("Arena 증거 파일 열기 실패:", error)
            #endif
            errorMessage = "파일을 열지 못했습니다. 사진 접근 권한과 파일 상태를 확인해 주세요."
        case .success(let urls):
            let available = max(0, 5 - files.count)
            if urls.count > available {
                errorMessage = "최대 5장까지 제출할 수 있어 앞의 \(available)장만 추가했습니다."
            }
            for url in urls.prefix(available) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let image = PhotoIntake.downsample(fileURL: url) else {
                    errorMessage = "일부 파일을 이미지로 읽지 못했습니다."
                    continue
                }
                add(image: image)
            }
        }
    }

    private func add(image: UIImage) {
        guard canAdd, DataScope.slot == accountSlot else { return }
        let normalized = image.normalizedUp().resizedToPixelBudget(3_000_000)
        guard let data = normalized.jpegData(compressionQuality: 0.88) else {
            errorMessage = "사진을 제출용 파일로 만들지 못했습니다."
            return
        }
        let url = DataScope.url(
            "arena-evidence-\(attemptId.prefix(8))-\(UUID().uuidString).jpg",
            for: accountSlot)
        do {
            try data.write(to: url, options: .atomic)
            files.append(EvidenceFile(url: url))
            errorMessage = nil
            persistDraft()
        } catch {
            #if DEBUG
            print("Arena 증거 사진 저장 실패:", error)
            #endif
            errorMessage = "사진을 안전하게 보관하지 못했습니다. 기기의 저장 공간을 확인한 뒤 다시 시도해 주세요."
        }
    }

    private func remove(_ file: EvidenceFile) {
        guard scopeIsValid, DataScope.slot == accountSlot else { return }
        files.removeAll { $0.id == file.id }
        try? FileManager.default.removeItem(at: file.url)
        persistDraft()
    }

    @MainActor
    private func upload() async {
        guard canUpload else { return }
        let ownerSlot = accountSlot
        let operationID = UUID()
        uploadOperationID = operationID
        isUploading = true
        errorMessage = nil
        defer {
            if uploadOperationID == operationID {
                uploadOperationID = nil
                isUploading = false
            }
        }
        do {
            let value = try await ServerAPI.submitGoatArenaEvidence(
                matchId: matchId,
                files: files.map(\.url),
                submissionId: evidenceSubmissionId,
                clientBuildVersion: clientBuildVersion)
            // 요청은 이전 계정의 Authorization으로 이미 접수됐을 수 있다. 계정이
            // 바뀐 뒤 돌아온 응답은 새 계정의 검토 큐나 화면에 절대 반영하지 않는다.
            // 원래 슬롯의 초안과 파일을 남겨 두면 해당 계정으로 돌아왔을 때 같은
            // submissionId로 안전하게 재확인할 수 있다.
            guard scopeIsValid,
                  DataScope.slot == ownerSlot,
                  uploadOperationID == operationID else { return }
            let reviewFiles = files.map(\.url)
            store.enqueueGoatArenaEvidenceReviews(
                fileURLs: reviewFiles,
                matchId: matchId,
                evidenceId: value.evidenceId,
                clientBuildVersion: clientBuildVersion,
                context: reviewContext)
            GoatArenaLocalReviewContextStore.clear(
                matchId: matchId,
                attemptId: attemptId
            )
            receipt = value
            GoatArenaEvidenceDraftStore.clear(
                matchId: matchId,
                attemptId: attemptId,
                deleting: files,
                accountSlot: ownerSlot)
            files = []
            onUploaded(value)
        } catch {
            guard scopeIsValid,
                  DataScope.slot == ownerSlot,
                  uploadOperationID == operationID else { return }
            routeMissing = (error as? ServerAPIError)?.isRouteMissing == true
            errorMessage = Self.message(for: error)
            persistDraft()
        }
    }

    private func persistDraft() {
        guard scopeIsValid, DataScope.slot == accountSlot else { return }
        GoatArenaEvidenceDraftStore.save(
            .init(
                matchId: matchId,
                attemptId: attemptId,
                submissionId: evidenceSubmissionId,
                deadlineAt: deadlineAt,
                filePaths: files.map { $0.url.path }),
            accountSlot: accountSlot)
    }

    private static func message(for error: Error) -> String {
        if let api = error as? ServerAPIError {
            // 코드 없는 404 는 "이 경기의 증거가 없다"가 아니라 **라우트 자체가 없다**는
            // 뜻이다. 재시도 문구를 보이면 학생은 마감 안에 같은 실패를 반복한다.
            if api.isRouteMissing {
                return "현재 경기의 풀이 사진은 아래 버튼을 눌러 앱 안의 웹 경기 화면에서 제출해 주세요."
            }
            return api.message ?? "풀이 증거를 제출하지 못했습니다. 잠시 후 다시 시도해 주세요."
        }
        #if DEBUG
        print("Arena 증거 제출 실패:", error)
        #endif
        return "풀이 증거를 제출하지 못했습니다. 인터넷 연결을 확인한 뒤 같은 제출 버튼을 다시 눌러 주세요."
    }
}

private struct EvidenceFile: Identifiable, Hashable {
    let url: URL
    var id: String { url.path }
}

private struct GoatArenaEvidenceDraft: Codable {
    let matchId: String
    let attemptId: String
    let submissionId: String
    let deadlineAt: Date?
    let filePaths: [String]

    var existingFiles: [EvidenceFile] {
        filePaths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return EvidenceFile(url: URL(fileURLWithPath: path))
        }
    }
}

private enum GoatArenaEvidenceDraftStore {
    private static let fileName = "goat-arena-evidence-drafts.json"
    private static func fileURL(for accountSlot: String) -> URL {
        DataScope.url(fileName, for: accountSlot)
    }

    static func load(
        matchId: String,
        attemptId: String,
        accountSlot: String
    ) -> GoatArenaEvidenceDraft? {
        readAll(accountSlot: accountSlot).first {
            $0.matchId == matchId && $0.attemptId == attemptId
        }
    }

    static func save(_ draft: GoatArenaEvidenceDraft, accountSlot: String) {
        var values = readAll(accountSlot: accountSlot).filter {
            !($0.matchId == draft.matchId && $0.attemptId == draft.attemptId)
        }
        values.append(draft)
        write(values, accountSlot: accountSlot)
    }

    static func clear(
        matchId: String,
        attemptId: String,
        deleting files: [EvidenceFile],
        accountSlot: String
    ) {
        files.forEach { try? FileManager.default.removeItem(at: $0.url) }
        write(readAll(accountSlot: accountSlot).filter {
            !($0.matchId == matchId && $0.attemptId == attemptId)
        }, accountSlot: accountSlot)
    }

    private static func readAll(accountSlot: String) -> [GoatArenaEvidenceDraft] {
        guard let data = try? Data(contentsOf: fileURL(for: accountSlot)),
              let values = try? JSONDecoder().decode(
                [GoatArenaEvidenceDraft].self,
                from: data) else { return [] }
        return values
    }

    private static func write(
        _ values: [GoatArenaEvidenceDraft],
        accountSlot: String
    ) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: fileURL(for: accountSlot), options: .atomic)
    }
}
