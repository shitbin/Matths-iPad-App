#if DEBUG
import CryptoKit
import Darwin
import Foundation
import UIKit

/// Explicit isolated simulator evaluation of existing registered profiles.
/// Never downloads models or changes product preferences.
@MainActor
enum ProNativeRuntimeSelfTest {
    private static var started = false
    private enum Profile: String {
        case smallPair = "qwen35-2b-deepseek7b"
        case highMemory9B = "high-memory-9b"
    }
    private static var profile: Profile = .smallPair
    private static var vision: ModelDownloader.ModelSpec {
        profile == .highMemory9B ? ModelDownloader.spec9B : ModelDownloader.specVision2B
    }
    private static var reasoning: ModelDownloader.ModelSpec {
        profile == .highMemory9B ? ModelDownloader.spec9B : ModelDownloader.specDeepSeek7B
    }

    private struct Call: Codable {
        let stage: String
        let vision: Bool
        let model: String
        let utf8Bytes: Int
        let elapsedMs: Double
    }
    private struct Checkpoint: Codable {
        let stage: String
        let reused: Bool
    }
    private struct ModelSwitch: Codable {
        let from: String
        let to: String
        let elapsedMs: Double
        let residentBefore: UInt64
        let residentAfter: UInt64
        let visionEnabledAfter: Bool
        let contextTokensAfter: Int
        let performedSwitch: Bool
    }
    private struct Report: Codable {
        var schemaVersion = "MATTHS_PRO_NATIVE_SIMULATOR_QA_V3"
        var mode: String
        var status = "PREFLIGHT"
        var recordedAt = Date()
        var platform = "iPad13 iOS Simulator, host RAM policy and CPU backend; not physical-device, Metal or thermal evidence"
        var runtimeOS: String?
        var hostPhysicalMemoryBytes: UInt64?
        var fixtureKind = "One native-rendered synthetic linear-equation sheet; not a handwriting/accuracy benchmark"
        var licenseScope = "Qwen3.5-2B original and quantization Apache-2.0; DeepSeek7B MIT; runtime QA is not full release approval"
        var modelProfile = "Qwen3.5-2B + matching F16 projector to DeepSeek7B sequential pair"
        var profileID = Profile.smallPair.rawValue
        var expectedModelSwitch = true
        var maximumResidentBytes: UInt64 = 8 * 1_024 * 1_024 * 1_024
        var maximumRuntimeSeconds = 720
        var timeBudgetAppliesTo = "Native model load, pipeline and cleanup; artifact SHA preflight excluded"
        var productionPromptTokenLimitsChanged = false
        var visionContextTokens: Int?
        var artifactSHA256: [String: String] = [:]
        var sourceSHA256: String?
        var lastStage: String?
        var elapsedMs: Double?
        var calls: [Call] = []
        var checkpoints: [Checkpoint] = []
        var rejectedCheckpointStages: [String] = []
        var stageSchemaValidation = "Eight production stage schemas; includes restored and repaired objects"
        var modelSwitches: [ModelSwitch] = []
        var pausedAfterActualReasoningCheckpoint = false
        var resumedCheckpointCount = 0
        var finalItemCount: Int?
        var finalStatuses: [String]?
        var weakTypeKeys: [String] = []
        var syntheticSemanticCheck: Bool?
        var runtimeContractPassed: Bool?
        var engineUnloaded: Bool?
        var leaseReturned: Bool?
        var residentBeforeModelLoad: UInt64?
        var sampledResidentPeak: UInt64?
        var residentAfterUnload: UInt64?
        var budgetStopped = false
        var error: String?
    }
    @MainActor private final class Collector {
        var report: Report
        init(mode: String) {
            report = Report(mode: mode)
            report.runtimeOS = UIDevice.current.systemVersion
            report.hostPhysicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
            report.profileID = profile.rawValue
            if profile == .highMemory9B {
                report.modelProfile = "Existing high-memory Qwen3.5-9B vision and reasoning on the same model/projector; no product preference change"
                report.licenseScope = "Pinned original and quantization Apache-2.0; isolated QA is not a device or app release approval"
                report.expectedModelSwitch = false
                report.maximumResidentBytes = 10 * 1_024 * 1_024 * 1_024
            }
        }
        func persist() { ProNativeRuntimeSelfTest.write(report) }
    }

    static func runIfRequested() {
        #if targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        guard !started, DemoMode.isOn, Bundle.main.bundleIdentifier == "kr.matths.app.uiqa",
              let index = args.firstIndex(of: "-proNativeRuntimeSelfTest"), index + 1 < args.count,
              ["prepare", "verify", "revalidate"].contains(args[index + 1]),
              (args.contains("-isolatedVisionQA") || args.contains("-researchOnlyVisionQA")) else { return }
        if let profileIndex = args.firstIndex(of: "-proNativeRuntimeProfile") {
            guard profileIndex + 1 < args.count else { return }
            let name = args[profileIndex + 1] == "research-small-pair"
                ? Profile.smallPair.rawValue : args[profileIndex + 1]
            guard let requested = Profile(rawValue: name) else { return }
            profile = requested
        }
        started = true
        Task { @MainActor in await run(mode: args[index + 1]) }
        #endif
    }

    private static var baseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProNativeRuntimeQA", isDirectory: true)
    }
    private static var directory: URL {
        baseDirectory.appendingPathComponent(profile.rawValue, isDirectory: true)
    }
    private static var jobDirectory: URL { directory.appendingPathComponent(LocalAIJobRecovery.directoryName, isDirectory: true) }

    private static func run(mode: String) async {
        let collector = Collector(mode: mode)
        collector.persist()
        var handedToGrader = false
        var lease: LocalAIWorkCoordinator.Lease?
        let grader = SheetGrader()
        let tutor = AITutor.shared
        let engine = tutor.debugEngine
        let probe = ResidentBudgetProbe()
        let visionSpec = vision
        let reasoningSpec = reasoning
        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            let requiredHostMemory: UInt64 = (profile == .highMemory9B ? 32 : 16) * 1_024 * 1_024 * 1_024
            guard ProcessInfo.processInfo.physicalMemory >= requiredHostMemory,
                  LocalAIBackgroundExecution.shared.admissionFailureMessage == nil,
                  !LocalAIResourceStopSignal.shared.isRequested else { throw Failure.resourcePreflight }
            let available = await LocalAIWorkCoordinator.shared.snapshot()
            guard available.active == nil, available.waiting.isEmpty else { throw Failure.engineInUse }

            let artifactFiles = [vision.file, vision.mmprojFile, reasoning.file].reduce(into: [String]()) {
                if !$0.contains($1) { $0.append($1) }
            }
            for file in artifactFiles {
                let url = AITutor.modelsDir.appendingPathComponent(file)
                let bytes = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
                guard bytes == LocalAIModelPack.expectedBytes(for: file),
                      let expected = LocalAIModelPack.expectedSHA256(for: file),
                      LocalAIModelPack.hasGGUFHeader(at: url) else { throw Failure.invalidModel }
                let actual = try await Task.detached(priority: .utility) { try LocalAIModelPack.sha256(of: url) }.value
                guard actual == expected, await LocalAIModelPack.verifyExistingArtifact(file) else { throw Failure.invalidModel }
                collector.report.artifactSHA256[file] = actual
                collector.persist()
            }

            let imagePath: String
            if mode == "prepare" {
                guard !FileManager.default.fileExists(atPath: jobDirectory.path) else { throw Failure.existingPrepare }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if profile == .highMemory9B {
                    // Reuse the exact original fixture bytes, never replace a
                    // failing picture with an easier one for the next profile.
                    let original = baseDirectory.appendingPathComponent(LocalAIJobRecovery.directoryName)
                        .appendingPathComponent(LocalAIJobRecovery.imageFileName)
                    guard LocalAIAnalysisJournal.imageDigest(at: original.path)
                        == "d4929ee6a944475d6001a2be51049f9d2af9071bc4ff7ff85fd8c1983c6a9817" else { throw Failure.noCheckpointSource }
                    imagePath = try LocalAIJobRecovery.begin(sourcePath: original.path, stageLabel: "native QA same fixture", in: jobDirectory)
                } else {
                    let fixture = directory.appendingPathComponent("synthetic-linear-equation.jpg")
                    try fixtureData().write(to: fixture, options: [.atomic, .completeFileProtection])
                    imagePath = try LocalAIJobRecovery.begin(sourcePath: fixture.path, stageLabel: "native QA", in: jobDirectory)
                }
            } else {
                guard let recovered = LocalAIJobRecovery.restore(in: jobDirectory) else { throw Failure.noCheckpointSource }
                imagePath = recovered.imagePath
            }
            collector.report.sourceSHA256 = LocalAIAnalysisJournal.imageDigest(at: imagePath)
            await tutor.releaseForMemory()
            collector.report.residentBeforeModelLoad = residentBytes()
            collector.report.status = "LOADING_VISION_MODEL"
            collector.persist()
            probe.start(maximumBytes: collector.report.maximumResidentBytes,
                        seconds: collector.report.maximumRuntimeSeconds)
            let acquired = try await LocalAIWorkCoordinator.shared.acquire(.sheetGrading)
            lease = acquired
            guard await tutor.switchModel(toFile: vision.file), engine.visionReady else { throw Failure.visionLoad }
            collector.report.visionContextTokens = engine.contextTokens

            grader.debugNativeCallObserver = { stage, vision, model, bytes, elapsed in
                collector.report.calls.append(Call(stage: stage.label, vision: vision, model: model, utf8Bytes: bytes, elapsedMs: elapsed))
                collector.persist()
            }
            grader.debugCheckpointObserver = { stage, reused in
                collector.report.checkpoints.append(Checkpoint(stage: stage.label, reused: reused))
                if mode == "prepare", stage == .solve, !reused {
                    collector.report.pausedAfterActualReasoningCheckpoint = true
                    LocalAIJobRecovery.update(stageLabel: "native QA reasoning checkpoint", in: jobDirectory)
                    grader.stop()
                }
                collector.persist()
            }
            grader.debugRejectedCheckpointObserver = { stage in
                collector.report.rejectedCheckpointStages.append(stage.label)
                collector.persist()
            }
            collector.report.status = "RUNNING_ACTUAL_SHEET_GRADER"
            collector.persist()
            grader.run(imagePath: imagePath, engine: engine, beforeReasoning: {
                let before = residentBytes()
                let begun = ProcessInfo.processInfo.systemUptime
                let from = engine.modelIdentifier
                guard !LocalAIResourceStopSignal.shared.isRequested else { throw Failure.reasoningLoad }
                let needsSwitch = from != reasoningSpec.file
                if needsSwitch {
                    guard await AITutor.shared.switchModel(toFile: reasoningSpec.file) else { throw Failure.reasoningLoad }
                }
                await MainActor.run {
                    collector.report.modelSwitches.append(ModelSwitch(from: from, to: engine.modelIdentifier,
                        elapsedMs: (ProcessInfo.processInfo.systemUptime - begun) * 1_000,
                        residentBefore: before, residentAfter: residentBytes(), visionEnabledAfter: engine.visionReady,
                        contextTokensAfter: engine.contextTokens, performedSwitch: needsSwitch))
                    collector.persist()
                }
            }, workLease: acquired)
            handedToGrader = true

            while grader.running {
                collector.report.lastStage = grader.stage?.label
                collector.report.elapsedMs = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
                collector.persist()
                if probe.hasStopped { grader.stop() }
                try await Task.sleep(for: .milliseconds(500))
            }
            collector.report.resumedCheckpointCount = grader.resumedCheckpointCount
            collector.report.weakTypeKeys = grader.weakTypes.map(\.rawValue)
            collector.report.error = grader.error
            if let result = grader.result {
                collector.report.finalItemCount = result.items.count
                collector.report.finalStatuses = result.items.map { $0.status.rawValue }
                collector.report.syntheticSemanticCheck = result.items.count == 1
                    && result.items[0].no == 1 && result.items[0].status == .correct
                    && MathAnswer.answersEquivalent("2", result.items[0].studentAnswer)
            }
            let expectsSwitch = visionSpec.file != reasoningSpec.file
            let switched = collector.report.modelSwitches.contains {
                $0.from == visionSpec.file && $0.to == reasoningSpec.file
                    && $0.performedSwitch == expectsSwitch && $0.visionEnabledAfter != expectsSwitch
            }
            if mode == "prepare" {
                let passed = collector.report.pausedAfterActualReasoningCheckpoint
                    && collector.report.calls.contains(where: { $0.vision && $0.utf8Bytes > 0 })
                    && collector.report.calls.contains(where: { !$0.vision && $0.model == reasoning.file && $0.utf8Bytes > 0 })
                    && switched
                collector.report.runtimeContractPassed = passed
                collector.report.status = passed ? "PASS_CHECKPOINT_PAUSE" : "FAIL"
            } else if mode == "verify" {
                let passed = grader.result != nil && grader.resumedCheckpointCount >= 3
                    && !collector.report.calls.contains(where: \.vision)
                    && switched
                collector.report.runtimeContractPassed = passed
                collector.report.status = passed
                    ? (collector.report.syntheticSemanticCheck == true ? "PASS_SINGLE_SYNTHETIC_FIXTURE" : "SEMANTIC_REVIEW_REQUIRED")
                    : "FAIL"
            } else {
                // A prompt/schema change must invalidate affected checkpoints.
                // This is deliberately separate from verify's no-vision replay
                // contract rather than weakening that original assertion.
                let passed = grader.result != nil && grader.resumedCheckpointCount >= 1
                    && collector.report.calls.contains(where: { $0.vision && $0.utf8Bytes > 0 })
                    && collector.report.calls.contains(where: { !$0.vision && $0.utf8Bytes > 0 })
                    && switched
                collector.report.runtimeContractPassed = passed
                collector.report.status = passed
                    ? (collector.report.syntheticSemanticCheck == true ? "PASS_SINGLE_SYNTHETIC_REVALIDATION" : "SEMANTIC_REVIEW_REQUIRED")
                    : "FAIL"
            }
        } catch {
            collector.report.status = handedToGrader ? "FAIL" : "BLOCKED"
            collector.report.error = String(describing: error)
            grader.stop()
        }
        if let lease, !handedToGrader { await LocalAIWorkCoordinator.shared.release(lease) }
        // This acquires the resource-recovery lease only after the grader returns
        // its exact lease, then resets the real tutor state as well as the engine.
        if lease != nil { await tutor.releaseForMemory(waitForActiveWork: true) }
        let budget = probe.stop()
        collector.report.sampledResidentPeak = budget.peak
        collector.report.budgetStopped = budget.stopped
        collector.report.engineUnloaded = !engine.isLoaded
        collector.report.residentAfterUnload = residentBytes()
        collector.report.leaseReturned = await LocalAIWorkCoordinator.shared.snapshot().active == nil
        collector.report.elapsedMs = (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000
        if budget.stopped || (lease != nil && (engine.isLoaded || collector.report.leaseReturned != true)) {
            collector.report.status = "FAIL"; collector.report.runtimeContractPassed = false
        }
        collector.persist()
    }

    private enum Failure: Error {
        case resourcePreflight, engineInUse, invalidModel, existingPrepare, noCheckpointSource, visionLoad, reasoningLoad
    }

    private static func fixtureData() throws -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1_024, height: 800), format: format)
        let image = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1_024, height: 800))
            let black: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.black]
            let blue: [NSAttributedString.Key: Any] = [.font: UIFont.italicSystemFont(ofSize: 46), .foregroundColor: UIColor.systemBlue]
            ("수학 확인 문제" as NSString).draw(at: CGPoint(x: 60, y: 45), withAttributes: black)
            ("1. 방정식 2x + 3 = 7을 만족하는\nx의 값을 구하시오. [3점]" as NSString)
                .draw(in: CGRect(x: 60, y: 120, width: 900, height: 145), withAttributes: black)
            ("2x = 7 - 3\n2x = 4\nx = 2" as NSString)
                .draw(in: CGRect(x: 120, y: 350, width: 700, height: 270), withAttributes: blue)
        }
        guard let data = image.jpegData(compressionQuality: 0.96) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    private nonisolated static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? info.resident_size : 0
    }

    private final class ResidentBudgetProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var timer: DispatchSourceTimer?
        private var active = false
        private var peak: UInt64 = 0
        private var stopped = false
        var hasStopped: Bool { lock.withLock { stopped } }
        func start(maximumBytes: UInt64, seconds: Int) {
            lock.withLock { active = true }
            let deadline = ProcessInfo.processInfo.systemUptime + Double(seconds)
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now(), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let bytes = residentBytes()
                self.lock.withLock {
                    guard self.active else { return }
                    self.peak = max(self.peak, bytes)
                    if bytes == 0 || bytes > maximumBytes || ProcessInfo.processInfo.systemUptime > deadline {
                        self.stopped = true
                        LocalAIResourceStopSignal.shared.set(true)
                    }
                }
            }
            self.timer = timer; timer.resume()
        }
        func stop() -> (peak: UInt64, stopped: Bool) {
            let result = lock.withLock { active = false; return (peak, stopped) }
            timer?.cancel(); timer = nil
            return result
        }
    }

    private static func write(_ report: Report) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) {
            try? data.write(to: directory.appendingPathComponent("\(report.mode)-report.json"), options: [.atomic, .completeFileProtection])
        }
    }
}
#endif
