import SwiftUI
import UniformTypeIdentifiers

@MainActor
private final class AdminPdfForensicsModel: ObservableObject {
  @Published var analysis: ServerAPI.AdminPdfForensicAnalysis?
  @Published var filename = ""
  @Published var analyzing = false
  @Published var error: String?
  func analyze(_ url: URL) async {
    guard !analyzing else { return }
    analyzing = true
    error = nil
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
      analyzing = false
    }
    do {
      if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
        size > 50 * 1024 * 1024
      {
        throw ServerAPIError(
          message: "유출 추적 파일은 50MB 이하로 선택해 주세요.", code: "FORENSICS_FILE_TOO_LARGE")
      }
      let data = try Data(contentsOf: url, options: .mappedIfSafe)
      let mime =
        UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
        ?? "application/octet-stream"
      analysis = try await ServerAPI.analyzeAdminPdfForensics(
        data: data, filename: url.lastPathComponent, mimeType: mime)
      filename = url.lastPathComponent
    } catch {
      self.error = (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription
    }
  }
}

struct AdminPdfForensicsScreen: View {
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @StateObject private var model = AdminPdfForensicsModel()
  @State private var importsFile = false
  let onClose: () -> Void
  private var landscape: Bool {
    verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
  }
  private let types = ["pdf", "png", "jpg", "jpeg", "webp", "heic", "heif"].compactMap {
    UTType(filenameExtension: $0)
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      if let error = model.error {
        Label(error, systemImage: "exclamationmark.triangle.fill").font(.mCaption).foregroundStyle(
          Tokens.dangerInk
        ).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(
          Tokens.dangerInk.opacity(0.1))
      }
      if landscape {
        HStack(spacing: 0) {
          input.frame(width: 345)
          Divider()
          results.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        VStack(spacing: 0) {
          input
          Divider()
          results
        }
      }
    }.background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .fileImporter(
        isPresented: $importsFile, allowedContentTypes: types, allowsMultipleSelection: false
      ) { result in
        switch result {
        case .success(let urls): if let url = urls.first { Task { await model.analyze(url) } }
        case .failure(let error): model.error = error.localizedDescription
        }
      }
  }
  private var header: some View {
    HStack {
      Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
        .buttonStyle(.plain).foregroundStyle(Tokens.primary)
      VStack(alignment: .leading, spacing: 1) {
        Text("PDF·스크린샷 유출 추적").font(.mHeading)
        Text("서명·페이지 코드·OCR 3중 식별").font(.mCaption).foregroundStyle(Tokens.text2)
      }
      Spacer()
      if model.analyzing { ProgressView().tint(Tokens.primary) }
    }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
  }
  private var input: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Label("유출 의심 자료 입력", systemImage: "doc.viewfinder").font(.mTitle)
        Text("PDF 내부 서명과 스크린샷 반복 추적 코드를 외부 API 전송 없이 서버에서 분석합니다.").font(.mCaption).foregroundStyle(
          Tokens.text2)
        Button {
          importsFile = true
        } label: {
          Label(model.analyzing ? "분석 중…" : "PDF·스크린샷 선택", systemImage: "folder")
        }.buttonStyle(PrimaryButtonStyle()).disabled(model.analyzing)
        Text("PDF, PNG, JPG, WEBP, HEIC · 최대 50MB\n서버 임시 파일은 결과 생성 직후 삭제됩니다.").font(.mMicro)
          .foregroundStyle(Tokens.text3)
        if !model.filename.isEmpty {
          Label(model.filename, systemImage: "checkmark.circle.fill").font(.mCaption)
            .foregroundStyle(Tokens.successInk)
        }
        Divider()
        Text("판정 원칙").font(.mBodyB)
        Text("OCR 유사 일치만으로 제재를 확정하지 말고, 서명 검증·발급 시각·자료 전달 경로를 함께 확인하세요.").font(.mCaption)
          .foregroundStyle(Tokens.warningInk).padding(9).background(
            Tokens.warningSoft, in: RoundedRectangle(cornerRadius: 9))
      }.padding(14)
    }
  }
  @ViewBuilder private var results: some View {
    if let value = model.analysis {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            summary(
              value.inputType == "IMAGE" ? value.imageCount : value.pageCount,
              value.inputType == "IMAGE" ? "이미지" : "페이지")
            summary(value.traceCodes.count, "추적 코드")
            summary(
              value.inputType == "IMAGE" ? value.ocrCandidateCount : value.pageTraceCount,
              value.inputType == "IMAGE" ? "OCR 후보" : "페이지 코드")
            summary(value.matches.count, "발급 기록")
          }
          if let image = value.imageMetadata {
            Text(
              "\(image.format) · \(image.width)×\(image.height)px · OCR 보정 \(image.ocrAttempts)회"
            ).font(.mCaption).foregroundStyle(Tokens.text2)
          }
          if value.matches.isEmpty && value.validPayloads.isEmpty {
            ContentUnavailableView(
              "일치 발급 기록 없음", systemImage: "magnifyingglass",
              description: Text("추적 코드가 지워졌거나 현재 DB 원장과 연결되지 않았습니다."))
          }
          ForEach(value.matches) { match in matchCard(match) }
          ForEach(
            value.validPayloads.filter { payload in
              !value.matches.contains(where: { $0.documentIssueId == payload.documentIssueId })
            }
          ) { payload in payloadCard(payload) }
        }.padding(14)
      }
    } else {
      ContentUnavailableView(
        "분석 전입니다", systemImage: "shield.lefthalf.filled",
        description: Text("왼쪽에서 PDF 또는 스크린샷을 선택하세요."))
    }
  }
  private func matchCard(_ value: ServerAPI.AdminForensicMatch) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        VStack(alignment: .leading) {
          Text(
            value.username.isEmpty
              ? (value.email.isEmpty ? value.userId : value.email) : value.username
          ).font(.mTitle)
          Text(
            source(value.sourceType) + " · "
              + (value.recognitionMethod == "IMAGE_OCR" ? "이미지 OCR" : "PDF 서명")
          ).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Spacer()
        badge(
          value.signatureVerified ? "서명 검증" : "OCR \(Int((value.ocrConfidence ?? 0) * 100))%",
          good: value.signatureVerified)
      }
      row("가입 이메일", value.email)
      row("시험·상품", value.examId)
      row("추적 코드", value.traceCode)
      row("문서 발급 ID", value.documentIssueId)
      row("원본 파일", value.originalName)
      row("발급 시각", value.downloadedAt ?? "—")
    }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
  }
  private func payloadCard(_ value: ServerAPI.AdminForensicPayload) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text("파일 자체 서명").font(.mTitle)
        Spacer()
        badge("DB 계정 매핑 없음", good: false)
      }
      row("내부 사용자 ID", value.userId)
      row("시험·상품", value.examId)
      row("추적 코드", value.traceCode)
      row("문서 발급 ID", value.documentIssueId)
    }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
  }
  private func summary(_ value: Int, _ label: String) -> some View {
    VStack(alignment: .leading) {
      Text("\(value)").font(.mHeading.monospacedDigit())
      Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private func row(_ key: String, _ value: String) -> some View {
    HStack(alignment: .top) {
      Text(key).foregroundStyle(Tokens.text3).frame(width: 85, alignment: .leading)
      Text(value.isEmpty ? "—" : value).textSelection(.enabled)
    }.font(.mCaption)
  }
  private func badge(_ value: String, good: Bool) -> some View {
    Text(value).font(.mMicro.weight(.semibold)).foregroundStyle(
      good ? Tokens.successInk : Tokens.primary
    ).padding(.horizontal, 7).padding(.vertical, 3).background(
      (good ? Tokens.successInk : Tokens.primary).opacity(0.1), in: Capsule())
  }
  private func source(_ value: String) -> String {
    ["ARCHIVE": "자료실", "WEEKLY_MOCK": "주간 공식 모의고사", "STORE": "상점"][value] ?? value
  }
}
