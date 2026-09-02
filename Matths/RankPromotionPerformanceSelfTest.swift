#if DEBUG
import CryptoKit
import Foundation
import UIKit

/// 실제 승급 오버레이를 9티어 모두 재생하면서 화면 갱신 간격을 기록한다.
/// 서버 판정·계정·DB를 만들지 않고 AppStore의 presentation 값만 일시적으로 사용한다.
@MainActor
enum RankPromotionPerformanceSelfTest {
    private struct TierSample: Codable {
        let tierCode: String
        let prewarmMs: Double
        let durationSeconds: Double
        let callbackCount: Int
        let estimatedDroppedFrames: Int
        let hitchCount: Int
        let hitchOffsetsMs: [Double]
        let dropRatio: Double
        let p50FrameMs: Double
        let p95FrameMs: Double
        let maxFrameMs: Double
        let passed: Bool
    }

    private struct RankAssetSample: Codable {
        let tierCode: String
        let filename: String
        let sha256: String
        let sizeBytes: Int64
    }

    private struct Report: Codable {
        let schemaVersion: String
        let result: String
        let observedAt: String
        let deviceModel: String
        let hardwareIdentifier: String
        let osVersion: String
        let appVersion: String
        let appBuild: String
        let maximumFramesPerSecond: Int
        let lowPowerModeEnabled: Bool
        let reduceMotionEnabled: Bool
        let serverSyncSuppressed: Bool
        let sourceCommit: String
        let sourceTree: String
        let sourceIdentityKind: String
        let sourceTrackedWorkingTreeClean: Bool
        let sourceExternalAttestationRequired: Bool
        let appExecutableSHA256: String
        let rankAssetManifestSHA256: String
        let rankAssetSourceStatus: String
        let rankAssetApprovedSource: Bool
        let rankAssetExternalAttestationRequired: Bool
        let rankAssets: [RankAssetSample]
        let provenanceVerified: Bool
        let releaseEvidenceEligible: Bool
        let provenanceError: String?
        let tiers: [TierSample]
    }

    private struct AssetManifest: Decodable {
        struct SourceProvenance: Decodable {
            let status: String
            let approvedSource: Bool
            let externalAttestationRequired: Bool
            let repository: String
            let commit: String
            let path: String
        }

        struct Asset: Decodable {
            let tierCode: String
            let filename: String
            let sha256: String
            let sizeBytes: Int64
        }

        let schemaVersion: String
        let sourceProvenance: SourceProvenance
        let assets: [Asset]
    }

    private struct BuildProvenance: Decodable {
        let schemaVersion: String
        let sourceCommit: String
        let sourceTree: String
        let sourceIdentityKind: String
        let sourceTrackedWorkingTreeClean: Bool
        let sourceExternalAttestationRequired: Bool
        let rankAssetManifestSHA256: String

        private enum CodingKeys: String, CodingKey {
            case schemaVersion = "SchemaVersion"
            case sourceCommit = "SourceCommit"
            case sourceTree = "SourceTree"
            case sourceIdentityKind = "SourceIdentityKind"
            case sourceTrackedWorkingTreeClean = "SourceTrackedWorkingTreeClean"
            case sourceExternalAttestationRequired = "SourceExternalAttestationRequired"
            case rankAssetManifestSHA256 = "RankAssetManifestSHA256"
        }
    }

    private struct ProvenanceSnapshot {
        let sourceCommit: String
        let sourceTree: String
        let sourceIdentityKind: String
        let sourceTrackedWorkingTreeClean: Bool
        let sourceExternalAttestationRequired: Bool
        let appExecutableSHA256: String
        let rankAssetManifestSHA256: String
        let rankAssetSourceStatus: String
        let rankAssetApprovedSource: Bool
        let rankAssetExternalAttestationRequired: Bool
        let rankAssets: [RankAssetSample]
        let verified: Bool
        let releaseEvidenceEligible: Bool
        let error: String?

        static func failed(_ error: Error) -> ProvenanceSnapshot {
            ProvenanceSnapshot(
                sourceCommit: "unknown",
                sourceTree: "unknown",
                sourceIdentityKind: "unknown",
                sourceTrackedWorkingTreeClean: false,
                sourceExternalAttestationRequired: true,
                appExecutableSHA256: "unknown",
                rankAssetManifestSHA256: "unknown",
                rankAssetSourceStatus: "unknown",
                rankAssetApprovedSource: false,
                rankAssetExternalAttestationRequired: true,
                rankAssets: [],
                verified: false,
                releaseEvidenceEligible: false,
                error: error.localizedDescription)
        }
    }

    private enum ProvenanceValidationError: LocalizedError {
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .invalid(let message): message
            }
        }
    }

    static func runIfRequested(store: AppStore) async {
        guard ProcessInfo.processInfo.arguments.contains("-rankPromotionPerformanceSelfTest") else {
            return
        }

        // 앱 root의 9티어 합성 prewarm이 끝난 뒤 계측한다. 고정 1초만 기다리면
        // 느린 기기에서 prewarm과 첫 티어 재생이 겹쳐 둘 다의 수치를 오염시킨다.
        guard await RankPromotionPipelinePrewarmState.waitUntilReady() else {
            NSLog("RankPromotionPerformanceSelfTest pipeline prewarm timed out")
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        let previousMotion = store.motionOn
        store.motionOn = true
        defer {
            store.rankPromotionPresentation = nil
            store.motionOn = previousMotion
        }

        var samples: [TierSample] = []
        for tier in RankTier.allCases {
            let prewarmStarted = CACurrentMediaTime()
            await withCheckedContinuation { continuation in
                RankBadgeAssets.prewarmPromotion(tier: tier) {
                    continuation.resume()
                }
            }
            let prewarmMs = (CACurrentMediaTime() - prewarmStarted) * 1_000
            let monitor = DisplayLinkMonitor()
            monitor.start()
            store.rankPromotionPresentation = .init(
                id: "performance-self-test:\(tier.rawValue)",
                tierCode: tier.rawValue)
            // 1.4초 조립 시작과 5.7초 카피 등장, 마감 반동까지 포함한다.
            try? await Task.sleep(for: .milliseconds(7_400))
            samples.append(monitor.stop(tierCode: tier.rawValue, prewarmMs: prewarmMs))
            store.rankPromotionPresentation = nil
            try? await Task.sleep(for: .milliseconds(550))
        }

        let info = Bundle.main.infoDictionary ?? [:]
        let provenance: ProvenanceSnapshot
        do {
            provenance = try provenanceSnapshot(info: info)
        } catch {
            provenance = .failed(error)
        }
        let passed = provenance.verified
            && !UIAccessibility.isReduceMotionEnabled
            && samples.count == RankTier.allCases.count
            && samples.allSatisfy(\.passed)
        let report = Report(
            schemaVersion: "MATTHS_RANK_PROMOTION_PERFORMANCE_V2",
            result: passed ? "PASS" : "FAIL",
            observedAt: ISO8601DateFormatter().string(from: Date()),
            deviceModel: UIDevice.current.model,
            hardwareIdentifier: hardwareIdentifier(),
            osVersion: UIDevice.current.systemVersion,
            appVersion: String(info["CFBundleShortVersionString"] as? String ?? "unknown"),
            appBuild: String(info["CFBundleVersion"] as? String ?? "unknown"),
            maximumFramesPerSecond: UIScreen.main.maximumFramesPerSecond,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            reduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            serverSyncSuppressed: true,
            sourceCommit: provenance.sourceCommit,
            sourceTree: provenance.sourceTree,
            sourceIdentityKind: provenance.sourceIdentityKind,
            sourceTrackedWorkingTreeClean: provenance.sourceTrackedWorkingTreeClean,
            sourceExternalAttestationRequired: provenance.sourceExternalAttestationRequired,
            appExecutableSHA256: provenance.appExecutableSHA256,
            rankAssetManifestSHA256: provenance.rankAssetManifestSHA256,
            rankAssetSourceStatus: provenance.rankAssetSourceStatus,
            rankAssetApprovedSource: provenance.rankAssetApprovedSource,
            rankAssetExternalAttestationRequired: provenance.rankAssetExternalAttestationRequired,
            rankAssets: provenance.rankAssets,
            provenanceVerified: provenance.verified,
            releaseEvidenceEligible: provenance.releaseEvidenceEligible,
            provenanceError: provenance.error,
            tiers: samples)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("rank-promotion-performance.json")
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("RankPromotionPerformanceSelfTest report write failed: %@", String(describing: error))
        }
    }

    private static func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    private static func provenanceSnapshot(info: [String: Any]) throws -> ProvenanceSnapshot {
        guard let provenanceURL = Bundle.main.url(
            forResource: "MatthsBuildProvenance", withExtension: "plist") else {
            throw ProvenanceValidationError.invalid("MatthsBuildProvenance.plist가 없습니다.")
        }
        guard let manifestURL = Bundle.main.url(
            forResource: "rank-promotion-assets",
            withExtension: "json",
            subdirectory: "RankMotion")
                ?? Bundle.main.url(
                    forResource: "rank-promotion-assets", withExtension: "json") else {
            throw ProvenanceValidationError.invalid("rank-promotion-assets.json이 없습니다.")
        }
        guard let executableURL = Bundle.main.executableURL else {
            throw ProvenanceValidationError.invalid("앱 executable URL이 없습니다.")
        }

        let provenance = try PropertyListDecoder().decode(
            BuildProvenance.self, from: Data(contentsOf: provenanceURL))
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(AssetManifest.self, from: manifestData)
        let manifestSHA256 = sha256(manifestData)

        guard provenance.schemaVersion == "MATTHS_BUILD_PROVENANCE_V1",
              info["MatthsBuildProvenanceSchema"] as? String == provenance.schemaVersion else {
            throw ProvenanceValidationError.invalid("build provenance schema가 Info.plist와 다릅니다.")
        }
        guard isSourceOID(provenance.sourceCommit), isSourceOID(provenance.sourceTree) else {
            throw ProvenanceValidationError.invalid("source commit/tree가 Git object id 형식이 아닙니다.")
        }
        guard provenance.sourceIdentityKind == "git",
              provenance.sourceTrackedWorkingTreeClean,
              !provenance.sourceExternalAttestationRequired else {
            throw ProvenanceValidationError.invalid(
                "self-test provenance는 clean Git source에서 직접 빌드된 경우에만 유효합니다.")
        }
        guard info["MatthsSourceCommit"] as? String == provenance.sourceCommit,
              info["MatthsSourceTree"] as? String == provenance.sourceTree,
              info["MatthsSourceIdentityKind"] as? String == provenance.sourceIdentityKind,
              info["MatthsSourceTrackedWorkingTreeClean"] as? Bool
                == provenance.sourceTrackedWorkingTreeClean,
              info["MatthsSourceExternalAttestationRequired"] as? Bool
                == provenance.sourceExternalAttestationRequired else {
            throw ProvenanceValidationError.invalid(
                "Info.plist source identity가 build provenance와 다릅니다.")
        }
        guard manifest.schemaVersion == "MATTHS_RANK_PROMOTION_ASSETS_V1",
              manifest.sourceProvenance.status == "verified-git-origin",
              manifest.sourceProvenance.approvedSource,
              !manifest.sourceProvenance.externalAttestationRequired,
              manifest.sourceProvenance.repository
                == "https://github.com/is4553807/Matths-Official.git",
              manifest.sourceProvenance.commit
                == "2b4e518f670d96e5c85128504faedb38456874ef",
              manifest.sourceProvenance.path == "public/media/rank-motion" else {
            throw ProvenanceValidationError.invalid(
                "rank 원본 provenance가 검증된 Git 원본과 다릅니다.")
        }
        guard provenance.rankAssetManifestSHA256 == manifestSHA256,
              info["MatthsRankAssetManifestSHA256"] as? String == manifestSHA256 else {
            throw ProvenanceValidationError.invalid(
                "rank asset manifest SHA-256이 build provenance와 다릅니다.")
        }

        let tiers = RankTier.allCases
        guard manifest.assets.count == tiers.count else {
            throw ProvenanceValidationError.invalid("rank asset manifest가 9티어가 아닙니다.")
        }
        let bundledVideoCount = try bundledRankVideoCount()
        guard bundledVideoCount == tiers.count else {
            throw ProvenanceValidationError.invalid(
                "번들 rank MP4가 정확히 9개가 아닙니다: \(bundledVideoCount)")
        }

        var rankAssets: [RankAssetSample] = []
        for (index, tier) in tiers.enumerated() {
            let declared = manifest.assets[index]
            guard declared.tierCode == tier.rawValue,
                  let url = RankPromotionVideoAssets.url(for: tier),
                  url.lastPathComponent == declared.filename else {
                throw ProvenanceValidationError.invalid(
                    "\(tier.rawValue): 티어 mapping이 manifest와 다릅니다.")
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let sizeBytes = Int64(values.fileSize ?? -1)
            let digest = try sha256(of: url)
            guard sizeBytes == declared.sizeBytes, digest == declared.sha256 else {
                throw ProvenanceValidationError.invalid(
                    "\(tier.rawValue): 번들 MP4 SHA-256/크기가 manifest와 다릅니다.")
            }
            rankAssets.append(RankAssetSample(
                tierCode: tier.rawValue,
                filename: declared.filename,
                sha256: digest,
                sizeBytes: sizeBytes))
        }

        let executableSHA256 = try sha256(of: executableURL)
        let releaseEligible = manifest.sourceProvenance.approvedSource
            && !manifest.sourceProvenance.externalAttestationRequired
        return ProvenanceSnapshot(
            sourceCommit: provenance.sourceCommit,
            sourceTree: provenance.sourceTree,
            sourceIdentityKind: provenance.sourceIdentityKind,
            sourceTrackedWorkingTreeClean: provenance.sourceTrackedWorkingTreeClean,
            sourceExternalAttestationRequired: provenance.sourceExternalAttestationRequired,
            appExecutableSHA256: executableSHA256,
            rankAssetManifestSHA256: manifestSHA256,
            rankAssetSourceStatus: manifest.sourceProvenance.status,
            rankAssetApprovedSource: manifest.sourceProvenance.approvedSource,
            rankAssetExternalAttestationRequired:
                manifest.sourceProvenance.externalAttestationRequired,
            rankAssets: rankAssets,
            verified: true,
            releaseEvidenceEligible: releaseEligible,
            error: nil)
    }

    private static func bundledRankVideoCount() throws -> Int {
        guard let root = Bundle.main.resourceURL,
              let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]) else {
            throw ProvenanceValidationError.invalid("앱 번들 리소스를 열거할 수 없습니다.")
        }
        var count = 0
        for case let url as URL in enumerator {
            if url.lastPathComponent.range(
                of: "-rank-up[.]v[0-9]+[.]mp4$",
                options: .regularExpression) != nil {
                count += 1
            }
        }
        return count
    }

    private static func isSourceOID(_ value: String) -> Bool {
        guard value.count == 40 || value.count == 64 else { return false }
        return value.range(of: "^[a-f0-9]+$", options: .regularExpression) != nil
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    private final class DisplayLinkMonitor: NSObject {
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval?
        private var startedAt = CACurrentMediaTime()
        private var intervals: [Double] = []
        private var droppedFrames = 0
        private var hitches = 0
        private var hitchOffsetsMs: [Double] = []

        func start() {
            startedAt = CACurrentMediaTime()
            let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
            let maximum = Float(max(60, UIScreen.main.maximumFramesPerSecond))
            link.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: maximum,
                preferred: maximum)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func stop(tierCode: String, prewarmMs: Double) -> TierSample {
            displayLink?.invalidate()
            displayLink = nil
            let duration = CACurrentMediaTime() - startedAt
            let sorted = intervals.sorted()
            let p50 = percentile(sorted, 0.50)
            let p95 = percentile(sorted, 0.95)
            let maximum = sorted.last ?? 0
            let totalFrames = intervals.count + droppedFrames
            let dropRatio = totalFrames > 0 ? Double(droppedFrames) / Double(totalFrames) : 1
            let enoughSamples = intervals.count >= 180 && duration >= 7
            let passed = enoughSamples && dropRatio <= 0.05 && maximum <= 0.100
            return TierSample(
                tierCode: tierCode,
                prewarmMs: rounded(prewarmMs),
                durationSeconds: rounded(duration),
                callbackCount: intervals.count,
                estimatedDroppedFrames: droppedFrames,
                hitchCount: hitches,
                hitchOffsetsMs: hitchOffsetsMs.map(rounded),
                dropRatio: rounded(dropRatio),
                p50FrameMs: rounded(p50 * 1_000),
                p95FrameMs: rounded(p95 * 1_000),
                maxFrameMs: rounded(maximum * 1_000),
                passed: passed)
        }

        @objc private func tick(_ link: CADisplayLink) {
            defer { lastTimestamp = link.timestamp }
            guard let lastTimestamp else { return }
            let actual = max(0, link.timestamp - lastTimestamp)
            let expected = max(1.0 / 120.0, link.targetTimestamp - link.timestamp)
            intervals.append(actual)
            let representedFrames = max(1, Int((actual / expected).rounded()))
            droppedFrames += max(0, representedFrames - 1)
            if actual > expected * 1.5 {
                hitches += 1
                if hitchOffsetsMs.count < 24 {
                    hitchOffsetsMs.append((link.timestamp - startedAt) * 1_000)
                }
            }
        }

        private func percentile(_ sorted: [Double], _ percentile: Double) -> Double {
            guard !sorted.isEmpty else { return 0 }
            let index = min(sorted.count - 1, max(0, Int((Double(sorted.count - 1) * percentile).rounded())))
            return sorted[index]
        }

        private func rounded(_ value: Double) -> Double {
            (value * 10_000).rounded() / 10_000
        }
    }
}
#endif
