import SwiftUI
import UniformTypeIdentifiers

@MainActor
private final class TeacherAcademyForensicsModel: ObservableObject {
    @Published var payload: ServerAPI.TeacherAcademyForensics?
    @Published var selectedClassID = ""
    @Published var traceCode = ""
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    func load(classID: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let value = try await ServerAPI.teacherAcademyForensics(classID: classID)
            payload = value
            selectedClassID = value.selectedClass?.id ?? value.classes.first?.id ?? ""
        } catch {
            errorMessage = readable(error)
        }
    }

    func changeClass(_ classID: String) async {
        guard !classID.isEmpty, classID != payload?.selectedClass?.id else { return }
        await load(classID: classID)
    }

    func analyzeCode() async {
        let normalized = traceCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !selectedClassID.isEmpty else {
            errorMessage = "추적 범위로 사용할 반을 선택해 주세요."
            return
        }
        guard !normalized.isEmpty else {
            errorMessage = "PDF에 표시된 MTH 추적 코드를 입력해 주세요."
            return
        }
        await analyze {
            try await ServerAPI.analyzeTeacherAcademyForensicsCode(
                classID: selectedClassID, traceCode: normalized)
        }
    }

    func analyzeFile(_ url: URL) async {
        guard !selectedClassID.isEmpty else {
            errorMessage = "추적 범위로 사용할 반을 선택해 주세요."
            return
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize, size > 50 * 1024 * 1024 {
                throw ServerAPIError(message: "유출 추적 파일은 50MB 이하로 선택해 주세요.", code: "FORENSICS_FILE_TOO_LARGE")
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let type = UTType(filenameExtension: url.pathExtension)
            let mime = type?.preferredMIMEType ?? "application/octet-stream"
            await analyze {
                try await ServerAPI.analyzeTeacherAcademyForensicsFile(
                    classID: selectedClassID,
                    data: data,
                    filename: url.lastPathComponent,
                    mimeType: mime)
            }
        } catch {
            errorMessage = readable(error)
        }
    }

    private func analyze(
        _ operation: () async throws -> ServerAPI.TeacherAcademyForensics
    ) async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            payload = try await operation()
            if payload?.analysis?.matches.isEmpty == true {
                errorMessage = "선택한 반의 개인 발급 기록에서 일치하는 결과를 찾지 못했습니다."
            }
        } catch {
            errorMessage = readable(error)
        }
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription
    }
}

struct TeacherAcademyForensicsPanel: View {
    @StateObject private var model = TeacherAcademyForensicsModel()
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsFileImporter = false

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if model.isLoading && model.payload == nil {
                stateView("발급 기록 범위를 불러오는 중입니다", systemImage: "magnifyingglass")
            } else if let payload = model.payload {
                content(payload)
            } else {
                stateView(model.errorMessage ?? "유출 자료 추적 정보를 불러오지 못했습니다", systemImage: "exclamationmark.triangle")
            }
        }
        .task { if model.payload == nil { await model.load() } }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { Task { await model.analyzeFile(url) } }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func content(_ payload: ServerAPI.TeacherAcademyForensics) -> some View {
        if payload.classes.isEmpty {
            stateView("추적할 수 있는 담당 반이 없습니다", systemImage: "person.2.slash")
        } else if compactLandscape {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                scopeHeader(payload)
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    inputPanel(payload).frame(maxWidth: .infinity)
                    resultPanel(payload).frame(maxWidth: .infinity)
                }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    scopeHeader(payload)
                    inputPanel(payload)
                    resultPanel(payload)
                }
            }
        }
    }

    private func scopeHeader(_ payload: ServerAPI.TeacherAcademyForensics) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Picker("추적할 반", selection: $model.selectedClassID) {
                ForEach(payload.classes) { academyClass in
                    Text(academyClass.name + (academyClass.isActive == false ? " · 보관됨" : ""))
                        .tag(academyClass.id)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: model.selectedClassID) { _, value in
                Task { await model.changeClass(value) }
            }
            scopeMetric(payload.scope.approvedStudents, "승인 학생")
            scopeMetric(payload.scope.issuedCopies, "발급 PDF")
            scopeMetric(payload.scope.distinctDownloaders, "발급 사용자")
            if model.isLoading || model.isAnalyzing { ProgressView().tint(Tokens.primary) }
        }
        .padding(Tokens.Space.s2)
        .background(Tokens.primarySoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    private func scopeMetric(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)").font(.mBodyB.monospacedDigit()).foregroundStyle(Tokens.ink)
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inputPanel(_ payload: ServerAPI.TeacherAcademyForensics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("유출 의심 자료 입력")
                    .font(compactLandscape ? .mBodyB : .mHeading).foregroundStyle(Tokens.ink)
                Text("PDF·스크린샷을 올리거나 문서에 보이는 MTH 코드를 입력하세요. 두 방식은 한 번에 하나씩 분석합니다.")
                    .font(compactLandscape ? .mMicro : .mCaption).foregroundStyle(Tokens.text2)
                    .lineLimit(compactLandscape ? 1 : nil)
                if compactLandscape {
                    HStack(alignment: .top, spacing: Tokens.Space.s2) {
                        fileChoice
                        Text("또는").font(.mMicro).foregroundStyle(Tokens.text3).padding(.top, 16)
                        codeChoice
                    }
                } else {
                    fileChoice
                    HStack {
                        Rectangle().frame(height: 1)
                        Text("또는").font(.mMicro)
                        Rectangle().frame(height: 1)
                    }
                    .foregroundStyle(Tokens.lineStrong)
                    codeChoice
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.mCaption).foregroundStyle(Tokens.dangerInk)
                }
            }
            .padding(Tokens.Space.s3)
        }
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line) }
    }

    private var fileChoice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { showsFileImporter = true } label: {
                Label(compactLandscape ? "파일 선택" : "PDF·스크린샷 선택",
                      systemImage: "doc.viewfinder")
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(model.isAnalyzing)
            Text(compactLandscape
                 ? "PDF·이미지 · 최대 50MB · 분석 후 삭제"
                 : "PDF, PNG, JPG, WEBP, HEIC · 최대 50MB · 분석 직후 서버 임시 파일 삭제")
                .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(compactLandscape ? 2 : nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codeChoice: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            TextField("MTH-0123ABCD4567EF89", text: $model.traceCode)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(.horizontal, Tokens.Space.s2).frame(minHeight: 44)
                .background(Tokens.paper2,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            Button(compactLandscape ? "코드 분석" : "추적 코드 분석") {
                Task { await model.analyzeCode() }
            }
                .buttonStyle(SecondaryButtonStyle()).disabled(model.isAnalyzing)
                .accessibilityLabel("추적 코드 분석")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultPanel(_ payload: ServerAPI.TeacherAcademyForensics) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("반 범위 추적 결과").font(.mHeading).foregroundStyle(Tokens.ink)
                if let analysis = payload.analysis, !analysis.matches.isEmpty {
                    ForEach(analysis.matches) { match in matchCard(match) }
                } else {
                    Label("분석 전입니다", systemImage: "shield.lefthalf.filled")
                        .font(.mBodyB).foregroundStyle(Tokens.text2)
                    Text("전체 회원이나 다른 학원·반은 검색하지 않습니다. 결과는 선택한 반에서 실제 발급된 개인 PDF 기록으로 제한됩니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
                Text("OCR 유사 일치만으로 유출자를 확정하지 말고 서명 검증, 발급 시각, 자료 전달 경로를 함께 확인하세요.")
                    .font(.mMicro).foregroundStyle(Tokens.warningInk)
                    .padding(Tokens.Space.s2)
                    .background(Tokens.warningSoft,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
            }
            .padding(Tokens.Space.s3)
        }
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line) }
    }

    private func matchCard(_ match: ServerAPI.TeacherAcademyForensics.Analysis.Match) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(match.displayName).font(.mBodyB).foregroundStyle(Tokens.ink)
                Spacer()
                Label(match.signatureVerified ? "서명 검증" : "코드 일치",
                      systemImage: match.signatureVerified ? "checkmark.seal.fill" : "number")
                    .font(.mMicro).foregroundStyle(match.signatureVerified ? Tokens.successInk : Tokens.text2)
            }
            Text("\(match.className) · \(roleLabel(match.userRole))")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Text(match.traceCode).font(.mMicro.monospaced()).foregroundStyle(Tokens.text3)
            if let originalName = match.originalName {
                Text(originalName).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
            }
        }
        .padding(Tokens.Space.s2)
        .background(Tokens.primarySoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    private func stateView(_ text: String, systemImage: String) -> some View {
        VStack(spacing: Tokens.Space.s2) {
            Image(systemName: systemImage).font(.system(size: 28)).foregroundStyle(Tokens.primary)
            Text(text)
                .font(.mBodyB).foregroundStyle(Tokens.ink).multilineTextAlignment(.center)
                .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            if model.payload == nil && !model.isLoading {
                Button("다시 시도") { Task { await model.load() } }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Space.s4)
    }

    private var allowedTypes: [UTType] {
        ["pdf", "png", "jpg", "jpeg", "webp", "heic", "heif"]
            .compactMap { UTType(filenameExtension: $0) }
    }

    private func roleLabel(_ role: String?) -> String {
        switch role {
        case "student": "학생"
        case "test": "테스트 학생"
        case "teacher": "선생님"
        default: "학원 자료 사용자"
        }
    }
}
