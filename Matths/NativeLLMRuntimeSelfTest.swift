#if DEBUG
import CryptoKit
import Darwin
import Foundation

/// Explicit simulator-only smoke test for the existing production text model.
/// It never downloads files, changes a model preference, reads student inputs,
/// or instantiates a second engine. The caller must sideload the pinned artifact.
@MainActor
enum NativeLLMRuntimeSelfTest {
    private static var started = false

    private struct Generation: Codable, Sendable {
        var utf8Bytes: Int
        var tokenCallbacks: Int
        var elapsedMs: Double
        var firstUTF8ChunkMs: Double?
        var outputSHA256: String
        var cancellationObserved: Bool
        var cancellationLatencyMs: Double?
    }
    private struct NativeResult: Codable, Sendable {
        var loadMs: Double
        var contextTokens: Int
        var visionEnabled: Bool
        var shortGeneration: Generation
        var cancelledGeneration: Generation
        var generationAfterCancellation: Generation
        var engineUnloaded: Bool
        var residentBeforeBytes: UInt64
        var residentPeakBytes: UInt64
        var residentAfterUnloadBytes: UInt64
        var resourceBudgetStopped: Bool
    }
    private struct Report: Codable {
        var schemaVersion = "MATTHS_NATIVE_LLM_SIMULATOR_QA_V1"
        var status: String
        var recordedAt = Date()
        var platform = "iOS Simulator product backend settings; not physical-device or Metal/thermal evidence"
        var simulatorGPUOffloadLayers = 0
        var model = ModelDownloader.specDeepSeek7B.file
        var modelSHA256: String?
        var modelBytes: Int64?
        var promptKind = "synthetic arithmetic prompts only; outputs recorded as counts and hashes"
        var productionModelSelectionChanged = false
        var native: NativeResult?
        var leaseReturned: Bool?
        var error: String?
    }

    static func runIfRequested() {
        #if targetEnvironment(simulator)
        guard !started, DemoMode.isOn, Bundle.main.bundleIdentifier == "kr.matths.app.uiqa",
              ProcessInfo.processInfo.arguments.contains("-nativeLLMRuntimeSelfTest") else { return }
        started = true
        Task { @MainActor in await run() }
        #endif
    }

    private static func run() async {
        var report = Report(status: "VERIFYING_MODEL")
        write(report)
        let spec = ModelDownloader.specDeepSeek7B
        let url = AITutor.modelsDir.appendingPathComponent(spec.file)
        guard ProcessInfo.processInfo.physicalMemory >= 16 * 1_024 * 1_024 * 1_024,
              LocalAIBackgroundExecution.shared.admissionFailureMessage == nil,
              !LocalAIResourceStopSignal.shared.isRequested else {
            report.status = "BLOCKED"; report.error = "Host RAM or current resource safety state does not permit the bounded test."
            write(report); return
        }
        do {
            let bytes = ((try FileManager.default.attributesOfItem(atPath: url.path))[.size] as? NSNumber)?.int64Value ?? 0
            guard bytes == LocalAIModelPack.expectedBytes(for: spec.file),
                  LocalAIModelPack.hasGGUFHeader(at: url),
                  let expected = LocalAIModelPack.expectedSHA256(for: spec.file) else {
                throw TestFailure.invalidArtifact
            }
            let actual = try await Task.detached(priority: .utility) { try LocalAIModelPack.sha256(of: url) }.value
            guard actual == expected else { throw TestFailure.invalidArtifact }
            report.modelBytes = bytes; report.modelSHA256 = actual
            let before = await LocalAIWorkCoordinator.shared.snapshot()
            guard before.active == nil, before.waiting.isEmpty else { throw TestFailure.engineAlreadyInUse }
            let lease = try await LocalAIWorkCoordinator.shared.acquire(.modelMaintenance)
            report.status = "RUNNING_NATIVE_ENGINE"; write(report)
            let engine = AITutor.shared.debugEngine
            do {
                let native = try await Task.detached(priority: .userInitiated) {
                    try exercise(engine: engine, modelURL: url)
                }.value
                report.native = native
                report.status = native.shortGeneration.tokenCallbacks > 0
                    && native.cancelledGeneration.cancellationObserved
                    && native.cancelledGeneration.tokenCallbacks == 4
                    && native.generationAfterCancellation.tokenCallbacks > 0
                    && native.engineUnloaded && !native.visionEnabled && !native.resourceBudgetStopped ? "PASS" : "FAIL"
            } catch {
                await Task.detached(priority: .utility) { engine.unload() }.value
                report.status = "FAIL"
                report.error = String(describing: error)
            }
            await LocalAIWorkCoordinator.shared.release(lease)
            let after = await LocalAIWorkCoordinator.shared.snapshot()
            report.leaseReturned = after.active == nil
            if report.leaseReturned != true { report.status = "FAIL" }
        } catch {
            report.status = "BLOCKED"
            report.error = String(describing: error)
        }
        write(report)
    }

    private enum TestFailure: Error { case invalidArtifact, engineAlreadyInUse, memoryMeasurementUnavailable }

    private nonisolated static func exercise(engine: LLMEngine, modelURL: URL) throws -> NativeResult {
        engine.unload()
        let before = residentBytes()
        guard before > 0 else { throw TestFailure.memoryMeasurementUnavailable }
        let probe = ResidentBudgetProbe()
        probe.start()
        defer { _ = probe.stop() }
        defer { engine.unload() }
        let started = ProcessInfo.processInfo.systemUptime
        try engine.load(modelPath: modelURL.path)
        let loadMs = (ProcessInfo.processInfo.systemUptime - started) * 1_000
        let context = engine.contextTokens
        let vision = engine.visionReady
        let first = try generate(engine: engine, user: "Compute 1 + 1. Answer with the number only.", cancelAfterChunks: nil)
        let cancelled = try generate(engine: engine, user: "Count upward from one and explain each number briefly.", cancelAfterChunks: 4)
        let recovered = try generate(engine: engine, user: "Compute 2 + 2. Answer with the number only.", cancelAfterChunks: nil)
        engine.unload()
        let peak = probe.stop()
        return NativeResult(loadMs: loadMs, contextTokens: context, visionEnabled: vision,
                            shortGeneration: first, cancelledGeneration: cancelled,
                            generationAfterCancellation: recovered, engineUnloaded: !engine.isLoaded,
                            residentBeforeBytes: before, residentPeakBytes: peak.bytes,
                            residentAfterUnloadBytes: residentBytes(), resourceBudgetStopped: peak.stopped)
    }

    private nonisolated static func generate(engine: LLMEngine, user: String, cancelAfterChunks: Int?) throws -> Generation {
        let flag = AITutor.CancelFlag()
        var parameters = LLMGenParams()
        parameters.maxTokens = 48
        parameters.temperature = 0
        parameters.topP = 1
        parameters.shouldCancel = { flag.isSet }
        let prompt = LocalModelPrompt.oneShot(modelIdentifier: ModelDownloader.specDeepSeek7B.file,
                                             system: "", user: user, thinking: false)
        let start = ProcessInfo.processInfo.systemUptime
        var firstChunk: Double?
        var requestedCancellationAt: Double?
        var chunks = 0
        var raw = ""
        var observedCancellation = false
        do {
            _ = try engine.generate(prompt: prompt, params: parameters) { text in
                if firstChunk == nil { firstChunk = (ProcessInfo.processInfo.systemUptime - start) * 1_000 }
                chunks += 1; raw += text
                if chunks == cancelAfterChunks {
                    requestedCancellationAt = ProcessInfo.processInfo.systemUptime
                    flag.set(true)
                }
                // Continue into the native decode/abort boundary so this checks
                // shouldCancel, not merely the legacy onToken(false) early break.
                return true
            }
        } catch is CancellationError {
            observedCancellation = flag.isSet
            if !observedCancellation { throw CancellationError() }
        }
        let end = ProcessInfo.processInfo.systemUptime
        return Generation(utf8Bytes: raw.utf8.count, tokenCallbacks: chunks, elapsedMs: (end - start) * 1_000,
                          firstUTF8ChunkMs: firstChunk,
                          outputSHA256: SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined(),
                          cancellationObserved: observedCancellation,
                          cancellationLatencyMs: requestedCancellationAt.map { (end - $0) * 1_000 })
    }

    private nonisolated static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let code = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return code == KERN_SUCCESS ? info.resident_size : 0
    }

    private final class ResidentBudgetProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var active = false
        private var peak: UInt64 = 0
        private var requestedStop = false
        private var timer: DispatchSourceTimer?
        func start() {
            lock.withLock { active = true }
            let deadline = ProcessInfo.processInfo.systemUptime + 90
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
            timer.schedule(deadline: .now(), repeating: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                let memory = NativeLLMRuntimeSelfTest.residentBytes()
                self.lock.withLock {
                    guard self.active else { return }
                    self.peak = max(self.peak, memory)
                    if memory > 8 * 1_024 * 1_024 * 1_024 || ProcessInfo.processInfo.systemUptime > deadline {
                        self.requestedStop = true
                        LocalAIResourceStopSignal.shared.set(true)
                    }
                }
            }
            self.timer = timer
            timer.resume()
        }
        func stop() -> (bytes: UInt64, stopped: Bool) {
            let result = lock.withLock { active = false; return (peak, requestedStop) }
            timer?.cancel(); timer = nil
            // A QA budget stop stays latched for this process. Relaunch UIQA
            // after inspecting the failure; never clear a concurrent OS warning.
            return result
        }
    }

    private static func write(_ report: Report) {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? encoder.encode(report) {
            try? data.write(to: documents.appendingPathComponent("native-llm-runtime-qa.json"), options: .atomic)
        }
    }
}
#endif
