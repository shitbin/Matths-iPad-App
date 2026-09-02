//
//  ExperimentalLocalModelCatalog.swift
//  Matths
//
//  검증되지 않은 로컬 모델을 Release 제품 설정에서 격리하는 장벽이다.
//  후보는 DEBUG 실기 선택기에만 연결하며, 런타임·가중치·기기 메모리 핀이 모두
//  맞아야 실험을 시작할 수 있다.
//

import Foundation

enum ExperimentalLocalModelCatalog {
    struct SourcePin: Equatable, Sendable {
        let repository: String
        let revision: String
        let declaredLicenseSPDX: String
        let isPublic: Bool
        let isGated: Bool
        let hasStandaloneLicenseFile: Bool
    }

    struct ArtifactPin: Equatable, Sendable {
        let id: String
        let repository: String
        let revision: String
        let file: String
        let byteCount: UInt64
        let sha256: String
        let quantization: String
        let minimumPhysicalMemoryBytes: UInt64
    }

    struct Candidate: Equatable, Sendable {
        let id: String
        let displayName: String
        let totalParametersBillions: Double
        let activeParametersBillions: Double
        let modality: String
        let ggufArchitecture: String
        let source: SourcePin
        let artifacts: [ArtifactPin]
        let debugUserSelectable: Bool
        let shippingEligible: Bool
    }

    enum BenchmarkBlockReason: String, Equatable, Sendable {
        case releaseBuild
        case unreviewedRuntime
        case unsupportedRuntimeArchitecture
        case unknownArtifact
        case artifactIntegrityMismatch
        case insufficientPhysicalMemory
    }

    enum BenchmarkDecision: Equatable, Sendable {
        case blocked(BenchmarkBlockReason)
        case eligibleForControlledBenchmark(artifactID: String)
    }

    // DEBUG 실기 배포에만 사용하는 llama.cpp PR #26608 런타임.
    // upstream에 병합되지 않았으므로 Release 선택지가 되어서는 안 된다.
    static let bundledLlamaCommit = "db4480bc802dda303627830833e0e6c2a7c47297"

    // ggml-org/llama.cpp PR #26608에서 Ling-3.0-tiny Q-LoRA 경로까지 포함해
    // 검토한 정확한 실험 commit. upstream release가 나오면 새 commit으로 다시
    // 검증하고 이 핀을 갱신해야 한다.
    static let reviewedBailingMoE3RuntimeCommit =
        "db4480bc802dda303627830833e0e6c2a7c47297"

    static let ling3Tiny = Candidate(
        id: "ling-3.0-tiny",
        displayName: "Ling 3.0 tiny (실험 후보)",
        totalParametersBillions: 7.9,
        activeParametersBillions: 1.3,
        modality: "text-only",
        ggufArchitecture: "bailingmoe3",
        source: SourcePin(
            repository: "inclusionAI/Ling-3.0-tiny",
            revision: "a2ee06c0f2de5b171701aee7f73f70a1da75483b",
            declaredLicenseSPDX: "MIT",
            isPublic: true,
            isGated: false,
            // 해당 revision은 README front matter로 MIT를 선언하지만 LICENSE라는
            // 독립 파일은 없다. 배포 전에는 MIT 본문·저작권 고지를 패키지에 넣고
            // 최종 라이선스 검토를 받아야 한다.
            hasStandaloneLicenseFile: false
        ),
        artifacts: [
            ArtifactPin(
                id: "ling3-tiny-q3-k-m-debug",
                repository: "bloomer010/Ling-3.0-tiny-GGUF",
                revision: "f2948e0af86d3f2c52a549dadd327b838a909482",
                file: "Ling-3.0-tiny-Q3_K_M.gguf",
                byteCount: 3_841_570_656,
                sha256: "3481953f64fa2dad7e22a254faba1681ab5b83061ac378ea144704fe6019bba2",
                quantization: "Q3_K_M",
                minimumPhysicalMemoryBytes: 8 * 1_024 * 1_024 * 1_024
            ),
            ArtifactPin(
                id: "ling3-tiny-q4-k-m-debug",
                repository: "bloomer010/Ling-3.0-tiny-GGUF",
                revision: "f2948e0af86d3f2c52a549dadd327b838a909482",
                file: "Ling-3.0-tiny-Q4_K_M.gguf",
                byteCount: 4_823_894_880,
                sha256: "9842cce7c1a07ad4adefd2b79a1035710ff196576d89128eade29351b79c8e68",
                quantization: "Q4_K_M",
                minimumPhysicalMemoryBytes: 16 * 1_024 * 1_024 * 1_024
            )
        ],
        // 사용자가 요청한 비교 실험을 위해 DEBUG 빌드에서만 선택한다.
        debugUserSelectable: true,
        // upstream runtime release, 실기 안정성, 한국 고교 수학 품질, MIT notice가
        // 모두 닫히기 전에는 Release 선택지가 될 수 없다.
        shippingEligible: false
    )

    /// DEBUG 선택기가 실제로 여는 Ling 가중치. 8 GiB 핀 안에서 실험할 수 있는
    /// 것은 Q3 하나뿐이라 선택기는 이 하나만 본다.
    static var ling3TinyDebugArtifact: ArtifactPin? {
        ling3Tiny.artifacts.first { $0.quantization == "Q3_K_M" }
    }

    // MARK: - 설치 상태 판정
    //
    // 왜 필요한가: 선택기는 "목록에 이름이 있다" 만 보고 후보를 고를 수 있었다.
    // 가중치가 기기에 없어도 골라졌고, 고른 값은 UserDefaults 에 남는다.
    // 그 상태에서 다운로드가 실패하면 다음 실행에서 고른 파일도 없고 기존
    // 안정 모델도 열리지 않아(AITutor 는 강제 티어가 있으면 대체 후보로
    // 넘어가지 않는다) 로컬 AI 가 통째로 꺼진 채로 굳었다.
    // 고를 수 있는 조건을 여기 한곳에서 정하고, 화면은 판정만 따른다.
    //
    // 파일 조회·저장공간 조회는 화면 쪽이 한다. 이 파일은 테스트에서 Foundation
    // 하나로 단독 컴파일되므로 앱 타입을 참조하지 않는다.

    struct InstallEvidence: Equatable, Sendable {
        /// 모델 폴더에 같은 이름의 파일이 있는가.
        let fileExists: Bool
        let fileByteCount: UInt64
        /// 핀에 적힌 정상 크기.
        let expectedByteCount: UInt64
        /// 앞 4바이트가 GGUF 매직인가. 오류 페이지를 모델로 받아 둔 경우를 거른다.
        let hasContainerHeader: Bool
        /// 크기와 해시 확인까지 끝났는가.
        let integrityVerified: Bool
        let isDownloading: Bool
        /// 남은 저장 공간이 이 파일을 받기에 충분한가. nil 은 확인하지 못했다는 뜻이고,
        /// 확인하지 못한 것을 부족하다고도 충분하다고도 말하지 않는다.
        let storageSufficientForDownload: Bool?
        let physicalMemoryBytes: UInt64
        /// 이 후보에 걸린 최소 기기 메모리. 핀이 없는 모델은 0 을 넣는다.
        let minimumPhysicalMemoryBytes: UInt64
        /// 이 빌드에 링크된 런타임이 이 가중치의 아키텍처를 여는가.
        let runtimeSupportsArchitecture: Bool
    }

    enum Availability: Equatable, Sendable {
        /// 확인이 끝나 지금 바로 열 수 있다.
        case installed
        case downloading
        /// 파일은 있는데 무결성 확인이 아직 안 끝났다.
        case verifying
        case notInstalled(downloadBytes: UInt64)
        case insufficientStorage(downloadBytes: UInt64)
        /// 크기·헤더·해시가 핀과 다르다. 받다 말았거나 원격 파일이 바뀐 것이다.
        case damaged
        case insufficientMemory(requiredBytes: UInt64)
        case runtimeUnsupported

        /// 지금 이 모델로 바꾸어도 되는가. 확인이 끝난 파일만 허용한다.
        var isSelectable: Bool { self == .installed }
    }

    static func availability(_ evidence: InstallEvidence) -> Availability {
        guard evidence.runtimeSupportsArchitecture else { return .runtimeUnsupported }
        if evidence.minimumPhysicalMemoryBytes > 0,
           evidence.physicalMemoryBytes < evidence.minimumPhysicalMemoryBytes {
            return .insufficientMemory(requiredBytes: evidence.minimumPhysicalMemoryBytes)
        }
        if evidence.integrityVerified { return .installed }
        if evidence.isDownloading { return .downloading }
        if evidence.fileExists {
            // 설치 검사와 같은 하한(97%)을 쓴다. 그보다 작으면 받다 만 파일이라
            // 이어받기가 아니라 다시 받아야 한다.
            let minimum = UInt64(Double(evidence.expectedByteCount) * 0.97)
            guard evidence.hasContainerHeader, evidence.fileByteCount >= minimum else {
                return .damaged
            }
            return .verifying
        }
        if evidence.storageSufficientForDownload == false {
            return .insufficientStorage(downloadBytes: evidence.expectedByteCount)
        }
        return .notInstalled(downloadBytes: evidence.expectedByteCount)
    }

    static func benchmarkDecision(
        buildIsDebug: Bool,
        runtimeCommit: String,
        runtimeArchitectures: Set<String>,
        physicalMemoryBytes: UInt64,
        artifactID: String,
        artifactByteCount: UInt64,
        artifactSHA256: String
    ) -> BenchmarkDecision {
        guard buildIsDebug else { return .blocked(.releaseBuild) }
        guard runtimeCommit == reviewedBailingMoE3RuntimeCommit else {
            return .blocked(.unreviewedRuntime)
        }
        guard runtimeArchitectures.contains(ling3Tiny.ggufArchitecture) else {
            return .blocked(.unsupportedRuntimeArchitecture)
        }
        guard let artifact = ling3Tiny.artifacts.first(where: { $0.id == artifactID }) else {
            return .blocked(.unknownArtifact)
        }
        guard artifact.byteCount == artifactByteCount,
              artifact.sha256.caseInsensitiveCompare(artifactSHA256) == .orderedSame else {
            return .blocked(.artifactIntegrityMismatch)
        }
        guard physicalMemoryBytes >= artifact.minimumPhysicalMemoryBytes else {
            return .blocked(.insufficientPhysicalMemory)
        }
        return .eligibleForControlledBenchmark(artifactID: artifact.id)
    }
}
