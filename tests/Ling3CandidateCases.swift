import Foundation

@main
struct Ling3CandidateCases {
    private static func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let candidate = ExperimentalLocalModelCatalog.ling3Tiny
        let q3 = candidate.artifacts.first { $0.quantization == "Q3_K_M" }!
        let q4 = candidate.artifacts.first { $0.quantization == "Q4_K_M" }!
        let supported = Set([candidate.ggufArchitecture])
        let reviewedRuntime = ExperimentalLocalModelCatalog.reviewedBailingMoE3RuntimeCommit
        let eightGiB = UInt64(8 * 1_024 * 1_024 * 1_024)
        let sixteenGiB = UInt64(16 * 1_024 * 1_024 * 1_024)

        require(candidate.source.declaredLicenseSPDX == "MIT", "official source license pin")
        require(candidate.source.isPublic && !candidate.source.isGated, "source access pin")
        require(!candidate.source.hasStandaloneLicenseFile, "standalone license gap must stay explicit")
        require(candidate.modality == "text-only", "Ling must not replace the vision reader")
        require(candidate.debugUserSelectable, "experimental model must be selectable in DEBUG")
        require(!candidate.shippingEligible, "experimental model must stay out of Release")

        let release = ExperimentalLocalModelCatalog.benchmarkDecision(
            buildIsDebug: false,
            runtimeCommit: reviewedRuntime,
            runtimeArchitectures: supported,
            physicalMemoryBytes: sixteenGiB,
            artifactID: q4.id,
            artifactByteCount: q4.byteCount,
            artifactSHA256: q4.sha256
        )
        require(release == .blocked(.releaseBuild), "Release build must be blocked")

        let bundled = ExperimentalLocalModelCatalog.benchmarkDecision(
            buildIsDebug: true,
            runtimeCommit: ExperimentalLocalModelCatalog.bundledLlamaCommit,
            runtimeArchitectures: supported,
            physicalMemoryBytes: eightGiB,
            artifactID: q3.id,
            artifactByteCount: q3.byteCount,
            artifactSHA256: q3.sha256
        )
        require(
            bundled == .eligibleForControlledBenchmark(artifactID: q3.id),
            "the pinned DEBUG bailingmoe3 runtime must admit the Q3 benchmark")

        let wrongHash = ExperimentalLocalModelCatalog.benchmarkDecision(
            buildIsDebug: true,
            runtimeCommit: reviewedRuntime,
            runtimeArchitectures: supported,
            physicalMemoryBytes: eightGiB,
            artifactID: q3.id,
            artifactByteCount: q3.byteCount,
            artifactSHA256: String(repeating: "0", count: 64)
        )
        require(wrongHash == .blocked(.artifactIntegrityMismatch), "artifact pin must be enforced")

        let q3OnEight = ExperimentalLocalModelCatalog.benchmarkDecision(
            buildIsDebug: true,
            runtimeCommit: reviewedRuntime,
            runtimeArchitectures: supported,
            physicalMemoryBytes: eightGiB,
            artifactID: q3.id,
            artifactByteCount: q3.byteCount,
            artifactSHA256: q3.sha256
        )
        require(
            q3OnEight == .eligibleForControlledBenchmark(artifactID: q3.id),
            "Q3 should be eligible only for controlled 8 GiB benchmark"
        )

        let q4OnEight = ExperimentalLocalModelCatalog.benchmarkDecision(
            buildIsDebug: true,
            runtimeCommit: reviewedRuntime,
            runtimeArchitectures: supported,
            physicalMemoryBytes: eightGiB,
            artifactID: q4.id,
            artifactByteCount: q4.byteCount,
            artifactSHA256: q4.sha256
        )
        require(q4OnEight == .blocked(.insufficientPhysicalMemory), "Q4 must be blocked on 8 GiB")

        let q4OnSixteen = ExperimentalLocalModelCatalog.benchmarkDecision(
            buildIsDebug: true,
            runtimeCommit: reviewedRuntime,
            runtimeArchitectures: supported,
            physicalMemoryBytes: sixteenGiB,
            artifactID: q4.id,
            artifactByteCount: q4.byteCount,
            artifactSHA256: q4.sha256
        )
        require(
            q4OnSixteen == .eligibleForControlledBenchmark(artifactID: q4.id),
            "Q4 controlled benchmark should require 16 GiB"
        )

        print("Ling 3.0 tiny experimental candidate contracts passed")
    }
}
