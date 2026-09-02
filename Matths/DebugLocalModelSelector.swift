#if DEBUG
import Foundation
import SwiftUI

/// 실험 빌드에서만 보이는 로컬 추론 모델 선택기.
/// 선택과 실제 로드 상태를 분리해, 메뉴만 바뀌고 이전 모델이 계속 도는 착시를 막는다.
///
/// 왜 다시 손봤나 (사용자 보고: "Ling 3.0 모델 불러오기가 안됨. 테스트마저 못하게 돼있잖아"):
/// 예전 메뉴는 기기에 가중치가 없는 체급도 그냥 고를 수 있었다. 고른 값은
/// UserDefaults(`matths.debugTier`)에 남고, 그 뒤 다운로드가 실패하거나 사용자가
/// 앱을 껐다 켜면 고른 파일도 없고 기존 안정 모델도 열리지 않는다. AITutor 는
/// 강제 티어가 걸려 있으면 옆에 있는 다른 gguf 로 넘어가지 않기 때문이다.
/// 그래서 로컬 AI 가 통째로 꺼진 채로 굳었고, 되돌릴 안내도 없었다.
///
/// 지금 규칙은 셋이다.
///  1. 바꿀 수 있는 목록에는 **확인이 끝난 모델만** 올린다.
///  2. 아직 없는 모델은 따로 보여 주고, 받는 것은 별도의 명시적 동작으로 만든다.
///     받는 동안에도 지금 돌던 모델은 그대로 둔다.
///  3. 받기가 실패하거나 고른 파일이 사라지면 자동으로 기기 권장 모델로 되돌리고
///     왜 그랬는지 화면에 남긴다.
struct DebugLocalModelSelector: View {
    @Binding var selection: String?
    var openModelLabel: String?

    @ObservedObject private var downloader = ModelDownloader.shared

    /// 언제나 되돌아갈 수 있는 자리. 강제 티어를 지우면 기기 권장 모델이 열린다.
    private static let stableID = "auto"

    @State private var availability: [String: ExperimentalLocalModelCatalog.Availability] = [:]
    /// 사용자가 직접 누른 받기의 대상. 실패를 이 항목 탓으로 정확히 돌리기 위해 둔다.
    @State private var pendingDownloadID: String?
    /// 되돌린 이유처럼 사용자가 알아야 하는 한 줄.
    @State private var notice: String?
    /// 해시 확인이 도는 중인 파일. 같은 파일을 두 번 읽지 않게 막는다.
    @State private var verifying: Set<String> = []

    private struct Option: Identifiable {
        let id: String
        let title: String
        let spec: ModelDownloader.ModelSpec?
        let availability: ExperimentalLocalModelCatalog.Availability

        var isExperimental: Bool { id == "ling3-q3" }
        /// 자동은 따로 받을 파일이 없다. 기기 권장 모델로 되돌리는 항목이다.
        var isAutomatic: Bool { spec == nil }
        var isSelectable: Bool { isAutomatic || availability.isSelectable }
    }

    private var options: [Option] {
        let rows: [(id: String, title: String, spec: ModelDownloader.ModelSpec?)] = [
            (Self.stableID, "자동 · 기기 권장", nil),
            ("deepseek7B", "DeepSeek R1 7B", ModelDownloader.specDeepSeek7B),
            ("ling3-q3", "Ling 3.0 tiny Q3", ModelDownloader.specLing3Q3),
            ("4B", "Qwen 4B", ModelDownloader.spec4B),
            ("9B-lite", "Qwen 9B 경량", ModelDownloader.spec9BLite),
            ("9B-lite-text", "Qwen 9B 3비트 텍스트", ModelDownloader.spec9BLiteText),
            ("9B", "Qwen 9B 풀", ModelDownloader.spec9B),
        ]
        return rows.map { row in
            Option(
                id: row.id,
                title: row.title,
                spec: row.spec,
                // 첫 프레임은 아직 조사 전이다. 확인 중으로 두어 없는 모델이
                // 잠깐이라도 고를 수 있게 보이지 않도록 한다.
                availability: availability[row.id] ?? .verifying)
        }
    }

    private var selectedID: String { selection ?? Self.stableID }
    private var selectedOption: Option {
        options.first(where: { $0.id == selectedID }) ?? options[0]
    }
    private var installedOptions: [Option] { options.filter(\.isSelectable) }
    private var missingOptions: [Option] { options.filter { !$0.isSelectable } }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            header
            picker

            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                Text("사진 판독은 Qwen VL 3B로 고정 · 두 모델은 순차 실행")
            }
            .font(.mMicro)
            .foregroundStyle(Tokens.text4)

            if selectedOption.isExperimental {
                Text("Ling은 미병합 bailingmoe3 런타임을 쓰는 DEBUG 전용 후보입니다. Release에는 노출되지 않습니다.")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.warningInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let notice {
                Label(notice, systemImage: "arrow.uturn.backward")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.warningInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            downloadProgressRow
            missingSection
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        )
        .task(id: refreshKey) { await refresh() }
    }

    // MARK: 화면 조각

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
            Label("AI 실험실", systemImage: "cpu")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            if selectedOption.isExperimental {
                Text("실험")
                    .font(.mMicro)
                    .foregroundStyle(Tokens.warningInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Tokens.warningSoft, in: Capsule())
            }
            Spacer(minLength: Tokens.Space.s2)
            if let openModelLabel {
                Text(openModelLabel)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                    .lineLimit(1)
            }
        }
    }

    private var picker: some View {
        HStack(spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("수학 추론")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                Text(selectedOption.title)
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(1)
                Text(statusText(for: selectedOption))
                    .font(.mMicro)
                    .foregroundStyle(statusColor(for: selectedOption))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.Space.s2)
            Menu {
                // 기기에서 확인이 끝난 모델만 올린다. 없는 모델을 고를 수 있게 두면
                // 강제 티어만 남고 아무 모델도 안 열리는 상태에 갇힌다.
                ForEach(installedOptions) { option in
                    Button {
                        apply(option)
                    } label: {
                        Label(option.title, systemImage:
                            option.id == selectedID ? "checkmark" : "circle")
                    }
                }
            } label: {
                Label("모델 변경", systemImage: "slider.horizontal.3")
                    .font(.mCaption.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("수학 추론 모델 변경")
            .accessibilityValue(selectedOption.title)
        }
    }

    @ViewBuilder
    private var downloadProgressRow: some View {
        switch downloader.state {
        case .downloading(let progress):
            ProgressView(value: progress) {
                Text("\(downloadingTitle) 내려받는 중 · \(Int(progress * 100))%")
                    .font(.mMicro)
            }
            .tint(Tokens.primary)
        case .failed(let message) where pendingDownloadID != nil:
            Text("내려받기 실패 · \(message)")
                .font(.mMicro)
                .foregroundStyle(Tokens.dangerInk)
                .fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
    }

    /// 아직 기기에 없는 후보를 상태별로 다르게 보여 준다.
    /// 여기서만 받기를 시작하므로, 목록을 여는 것과 수 GB 를 받는 것이 섞이지 않는다.
    @ViewBuilder
    private var missingSection: some View {
        if !missingOptions.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text("아직 없는 모델")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
                ForEach(missingOptions) { option in
                    HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s2) {
                        Image(systemName: icon(for: option.availability))
                            .font(.mMicro)
                            .foregroundStyle(statusColor(for: option))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option.title)
                                .font(.mMicro)
                                .foregroundStyle(Tokens.text3)
                            Text(statusText(for: option))
                                .font(.mMicro)
                                .foregroundStyle(statusColor(for: option))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Tokens.Space.s2)
                        if canDownload(option) {
                            Button(option.availability == .damaged ? "다시 받기" : "받기") {
                                startDownload(option)
                            }
                            .font(.mCaption.weight(.semibold))
                            .frame(minHeight: 44)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("\(option.title) 받기")
                        }
                    }
                }
            }
        }
    }

    // MARK: 문구

    private func statusText(for option: Option) -> String {
        if option.isAutomatic { return "이 기기에 권장되는 모델을 자동으로 씁니다" }
        switch option.availability {
        case .installed:
            return "설치됨"
        case .downloading:
            return "받는 중"
        case .verifying:
            return "파일 확인 중"
        case .notInstalled:
            return "아직 없습니다. 약 \(option.spec?.sizeLabel ?? "")를 받아야 합니다"
        case .insufficientStorage:
            return "저장 공간이 부족합니다. 약 \(option.spec?.sizeLabel ?? "")가 들어갈 자리를 비워 주세요"
        case .damaged:
            return "받아 둔 파일이 온전하지 않습니다. 다시 받아야 합니다"
        case .insufficientMemory(let requiredBytes):
            return "이 기기 메모리로는 열 수 없습니다. \(gibibytes(requiredBytes))GB 이상이 필요합니다"
        case .runtimeUnsupported:
            return "이 빌드의 추론 엔진이 이 모델 형식을 열지 못합니다"
        }
    }

    /// 되돌린 이유 한 줄에 이어 붙일 짧은 설명.
    /// 목록용 문구를 그대로 붙이면 "쓸 수 없어 되돌렸습니다. 아직 없습니다." 처럼
    /// 같은 말이 두 번 나와 문장이 끊긴다.
    private func reasonText(for option: Option) -> String {
        switch option.availability {
        case .notInstalled:
            return "이 기기에 파일이 없어서 약 \(option.spec?.sizeLabel ?? "")를 먼저 받아야 합니다."
        case .insufficientStorage:
            return "저장 공간이 부족해서 받을 수 없습니다."
        case .damaged:
            return "받아 둔 파일이 온전하지 않아 다시 받아야 합니다."
        case .insufficientMemory(let requiredBytes):
            return "이 기기 메모리로는 열 수 없고 \(gibibytes(requiredBytes))GB 이상이 필요합니다."
        case .runtimeUnsupported:
            return "이 빌드의 추론 엔진이 이 모델 형식을 열지 못합니다."
        case .installed, .downloading, .verifying:
            return statusText(for: option)
        }
    }

    private func statusColor(for option: Option) -> Color {
        if option.isAutomatic { return Tokens.text4 }
        switch option.availability {
        case .installed: return Tokens.successInk
        case .downloading, .verifying: return Tokens.text4
        case .notInstalled: return Tokens.text3
        case .insufficientStorage, .insufficientMemory, .runtimeUnsupported:
            return Tokens.warningInk
        case .damaged: return Tokens.dangerInk
        }
    }

    private func icon(for state: ExperimentalLocalModelCatalog.Availability) -> String {
        switch state {
        case .installed: return "checkmark.circle"
        case .downloading: return "arrow.down.circle"
        case .verifying: return "hourglass"
        case .notInstalled: return "circle.dashed"
        case .insufficientStorage: return "internaldrive"
        case .damaged: return "exclamationmark.triangle"
        case .insufficientMemory: return "memorychip"
        case .runtimeUnsupported: return "cpu"
        }
    }

    private var downloadingTitle: String {
        let id = pendingDownloadID ?? selectedID
        return options.first(where: { $0.id == id })?.title ?? selectedOption.title
    }

    private func gibibytes(_ bytes: UInt64) -> Int {
        Int((Double(bytes) / 1_073_741_824).rounded())
    }

    // MARK: 동작

    private func canDownload(_ option: Option) -> Bool {
        guard option.spec != nil else { return false }
        switch option.availability {
        case .notInstalled, .damaged: return true
        default: return false
        }
    }

    private func apply(_ option: Option) {
        // 목록에서 비활성 항목은 아예 뜨지 않지만, 판정이 바뀌는 순간과 탭이
        // 겹칠 수 있으므로 여기서 한 번 더 막는다.
        guard option.isSelectable else {
            notice = "\(option.title) 모델은 아직 쓸 수 없어서 바꾸지 않았습니다. \(reasonText(for: option))"
            return
        }
        notice = nil
        pendingDownloadID = nil
        setTier(option.isAutomatic ? nil : option.id)
        if !ModelDownloader.shared.startForTierSwitch() {
            AITutor.shared.loadRecommended()
        }
    }

    private func startDownload(_ option: Option) {
        guard canDownload(option) else { return }
        notice = nil
        pendingDownloadID = option.id
        setTier(option.id)
        // 받는 동안 지금 열려 있는 모델은 건드리지 않는다. 받기가 끝나야
        // 다운로더가 새 모델을 연다. 실패하면 아래 refresh 가 되돌린다.
        if !ModelDownloader.shared.startForTierSwitch() {
            pendingDownloadID = nil
            AITutor.shared.loadRecommended()
        }
    }

    private func setTier(_ tier: String?) {
        selection = tier
        ModelDownloader.debugForcedTier = tier
    }

    /// 강제 티어를 지우고 기기 권장 모델을 다시 연다.
    private func revertToStable(reason: String) {
        setTier(nil)
        pendingDownloadID = nil
        AITutor.shared.loadRecommended()
        notice = reason
    }

    // MARK: 상태 조사

    /// 진행률 한 칸마다 다시 조사하지 않도록 상태는 단계로만 묶는다.
    private var refreshKey: String {
        let phase: String
        switch downloader.state {
        case .idle: phase = "idle"
        case .downloading: phase = "downloading"
        case .done: phase = "done"
        case .failed: phase = "failed"
        }
        return "\(selection ?? Self.stableID)|\(phase)|\(pendingDownloadID ?? "-")"
    }

    private func refresh() async {
        var next: [String: ExperimentalLocalModelCatalog.Availability] = [:]
        for option in options {
            guard let spec = option.spec else { continue }
            next[option.id] = resolve(spec, isExperimental: option.isExperimental)
        }
        availability = next

        // 받아 두긴 했는데 해시 영수증이 없는 파일(사이드로드 포함)은 한 번만
        // 확인해 준다. 확인이 끝나야 목록에 올릴 수 있다.
        for option in options where next[option.id] == .verifying {
            guard let spec = option.spec, !verifying.contains(spec.file) else { continue }
            verifying.insert(spec.file)
            let ok = await LocalAIModelPack.verifyExistingArtifact(spec.file)
            verifying.remove(spec.file)
            // 해시를 읽는 동안 상태가 바뀌었으면 그 사이 조사한 결과를 덮어쓰지 않는다.
            guard !Task.isCancelled else { return }
            availability[option.id] = ok
                ? .installed
                : resolve(spec, isExperimental: option.isExperimental, treatUnverifiedAsDamaged: true)
        }

        reconcileSelection()
    }

    private func resolve(
        _ spec: ModelDownloader.ModelSpec,
        isExperimental: Bool,
        treatUnverifiedAsDamaged: Bool = false
    ) -> ExperimentalLocalModelCatalog.Availability {
        let url = AITutor.modelsDir.appendingPathComponent(spec.file)
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
        let expected = UInt64(max(0, LocalAIModelPack.expectedBytes(for: spec.file)))
        // 다운로더는 진행률만 알려 주고 어떤 파일인지는 알려 주지 않는다.
        // 받는 대상은 언제나 지금 티어의 본체이므로 그것으로 맞춘다.
        // (연달아 두 번 받기를 누르면 첫 파일이 끝날 때까지 이름만 앞서 보인다.
        //  다운로더가 끝에서 티어를 다시 확인해 두 번째 파일도 이어서 받는다.)
        let downloading: Bool = {
            if case .downloading = downloader.state {
                return spec.file == ModelDownloader.recommended.file
            }
            return false
        }()

        let evidence = ExperimentalLocalModelCatalog.InstallEvidence(
            fileExists: attributes != nil,
            fileByteCount: byteCount,
            expectedByteCount: expected,
            // 해시 확인이 이미 실패한 파일은 헤더가 맞아도 손상으로 본다.
            hasContainerHeader: !treatUnverifiedAsDamaged
                && LocalAIModelPack.hasGGUFHeader(at: url),
            integrityVerified: LocalAIModelPack.fileReady(spec.file),
            isDownloading: downloading,
            storageSufficientForDownload: storageSufficient(forDownloadBytes: Int64(expected)),
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            minimumPhysicalMemoryBytes: isExperimental ? ling3MinimumMemoryBytes : 0,
            runtimeSupportsArchitecture: isExperimental ? runtimeSupportsBailingMoE3 : true)
        return ExperimentalLocalModelCatalog.availability(evidence)
    }

    /// 저장 공간 계산은 제품 다운로드 경로와 같은 함수를 그대로 부른다.
    /// 여유율을 여기서 다시 적으면 두 숫자가 갈라진다.
    private func storageSufficient(forDownloadBytes bytes: Int64) -> Bool? {
        guard bytes > 0 else { return nil }
        let values = try? AITutor.modelsDir.deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let available = values?.volumeAvailableCapacityForImportantUsage else { return nil }
        return (try? LocalAIModelPack.requireStorage(
            availableBytes: available,
            downloadBytes: bytes)) != nil
    }

    /// 실험 후보에 걸린 기기 메모리 핀. 카탈로그에 핀이 없으면 0 을 돌려
    /// 확인하지 못한 조건을 통과시키지도, 임의로 막지도 않는다.
    private var ling3MinimumMemoryBytes: UInt64 {
        ExperimentalLocalModelCatalog.ling3TinyDebugArtifact?.minimumPhysicalMemoryBytes ?? 0
    }

    /// 이 빌드에 링크된 llama 런타임이 bailingmoe3 를 여는가.
    ///
    /// 실행 중에 런타임에 아키텍처 목록을 물어보는 API 가 없어서, 빌드 시점에
    /// 고정한 사실만 쓴다. Frameworks/llama.xcframework 는
    /// scripts/buildLing3DebugRuntime.sh 가 `bundledLlamaCommit` 에서 만들었고,
    /// tests/run-ling3-candidate-contract.sh 가 그 바이너리에 bailingmoe3 심볼이
    /// 실제로 있는지 매번 확인한다. 둘이 갈라지면 여기서 막힌다.
    private var runtimeSupportsBailingMoE3: Bool {
        ExperimentalLocalModelCatalog.bundledLlamaCommit
            == ExperimentalLocalModelCatalog.reviewedBailingMoE3RuntimeCommit
    }

    /// 고른 모델이 지금 쓸 수 없는 상태면 기기 권장 모델로 되돌린다.
    ///
    /// 이 한 조각이 없어서 사용자가 갇혔다. 강제 티어는 UserDefaults 에 남는데,
    /// 그 파일이 없으면 AITutor 는 다른 gguf 로 넘어가지 않고 그대로 멈춘다.
    private func reconcileSelection() {
        guard let current = selection, current != Self.stableID else { return }
        guard let option = options.first(where: { $0.id == current }) else {
            revertToStable(reason: "고른 모델을 더 이상 찾을 수 없어 기기 권장 모델로 되돌렸습니다.")
            return
        }
        if option.isSelectable {
            if case .done = downloader.state { pendingDownloadID = nil }
            return
        }
        switch option.availability {
        case .downloading, .verifying:
            return  // 아직 진행 중이다. 기다린다.
        default:
            break
        }
        if case .failed(let message) = downloader.state {
            revertToStable(
                reason: "\(option.title) 모델을 받지 못해 기기 권장 모델로 되돌렸습니다. \(message)")
            return
        }
        revertToStable(
            reason: "\(option.title) 모델을 쓸 수 없어 기기 권장 모델로 되돌렸습니다. \(reasonText(for: option))")
    }
}
#endif
