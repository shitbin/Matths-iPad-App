//  VisionSelfTest.swift
//  Matths
//
//  **사용자 손을 빌리지 않고** 비전 로드를 실기기에서 재는 경로.
//
//  왜 필요한가: 9B + 비전이 기기에서 죽는 원인을 세 번 추측으로 건드렸고 세 번 다
//  틀렸다(n_ctx 3072, 사진 0.48MP, 4B/9B 하이브리드). 죽는 자리는 llama.cpp 의
//  malloc 실패이고, 필요한 숫자는 단 두 개다 — **그 순간 남은 메모리**와
//  **요구한 크기**. 그런데 그걸 보려면 매번 사람이 앱을 열고 사진을 골라야 했다.
//
//  그래서 실행 인자 하나로 같은 경로를 태운다:
//
//    xcrun devicectl device process launch --device <UDID> \
//      kr.matths.app -visionSelfTest 9B-lite
//
//  결과는 Documents/selftest.txt 와 llama.log 에 같이 남는다. 티어를 바꿔 가며
//  세 번 돌리면 "어느 조합까지 들어가는가" 가 표로 나온다 — 추측이 끼어들 자리가 없다.
//
//  DEBUG 전용이다. 배포 빌드에는 통째로 들어가지 않는다.

#if DEBUG
import Foundation
import os
import Darwin
import UIKit

enum VisionSelfTest {
    private static let tierRestoreMarker = "matths.visionSelfTest.previousTier"
    private static let tierRestoreWasNil = "__MATTHS_NIL__"

    /// 실행 인자에 -visionSelfTest 가 있으면 그 뒤의 티어 이름을 돌려준다.
    /// 없으면 nil — 평소 실행은 아무 영향도 받지 않는다.
    static var requestedTier: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-visionSelfTest") else { return nil }
        let next = a.index(after: i)
        // 티어를 생략하면 지금 강제된 티어(없으면 자동 권장)를 그대로 쓴다
        guard next < a.endIndex, !a[next].hasPrefix("-") else { return "" }
        return a[next]
    }

    static var resultURL: URL {
        DataScope.url("selftest.txt")
    }

    static var metricsURL: URL {
        DataScope.url("selftest-metrics.jsonl")
    }

    /// 실기 자동 수집용 비식별 성능 파일. DEBUG 진단에서만 생성하며 사진·모델 출력은 넣지 않는다.
    static var diagnosticExportURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MatthsDiagnostics", isDirectory: true)
            .appendingPathComponent("vision-selftest.jsonl")
    }

    private static func mb(_ b: Int) -> String { String(format: "%.0fMB", Double(b) / 1_048_576) }

    private static func say(_ s: String) {
        LlamaLogSink.note("자가진단: \(s)")
        let line = s + "\n"
        if let h = try? FileHandle(forWritingTo: resultURL) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: resultURL, options: .atomic)
        }
    }

    private static func metric(_ event: String, _ values: [String: Any]) {
        var row = values
        row["event"] = event
        row["recordedAt"] = ISO8601DateFormatter().string(from: Date())
        guard JSONSerialization.isValidJSONObject(row),
              let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else {
            return
        }
        let line = data + Data("\n".utf8)
        if let handle = try? FileHandle(forWritingTo: metricsURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: metricsURL, options: .atomic)
        }
        appendDiagnosticMetric(row)
    }

    private static func appendDiagnosticMetric(_ row: [String: Any]) {
        let allowedKeys: Set<String> = [
            "event", "recordedAt", "tier", "model", "projector", "projectorBytes",
            "availableBytes", "residentBytes", "elapsedMs", "visionReady",
            "minimumAvailableBytes", "maximumResidentBytes", "firstTokenMs",
            "generatedTokens", "tokensPerSecond", "koreanOutputClean",
        ]
        let redacted = row.filter { allowedKeys.contains($0.key) }
        guard JSONSerialization.isValidJSONObject(redacted),
              let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys]) else {
            return
        }
        let directory = diagnosticExportURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let line = data + Data("\n".utf8)
        if let handle = try? FileHandle(forWritingTo: diagnosticExportURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: diagnosticExportURL, options: .atomic)
        }
    }

    private static func residentBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    private final class MemoryProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var running = false
        private var minimumAvailable = Int.max
        private var maximumResident = 0

        func start() {
            lock.lock()
            running = true
            lock.unlock()
            DispatchQueue.global(qos: .utility).async { [self] in
                while isRunning {
                    sample()
                    Thread.sleep(forTimeInterval: 0.05)
                }
                sample()
            }
        }

        func stop() -> (minimumAvailable: Int, maximumResident: Int) {
            lock.lock()
            running = false
            let available = minimumAvailable == Int.max ? 0 : minimumAvailable
            let resident = maximumResident
            lock.unlock()
            return (available, resident)
        }

        private var isRunning: Bool {
            lock.lock(); defer { lock.unlock() }
            return running
        }

        private func sample() {
            let available = Int(os_proc_available_memory())
            let resident = VisionSelfTest.residentBytes()
            lock.lock()
            if available > 0 { minimumAvailable = min(minimumAvailable, available) }
            maximumResident = max(maximumResident, resident)
            lock.unlock()
        }
    }

    /// 지금 이 순간 큰 덩어리를 잡을 수 있는가. 잡아 보고 바로 놓는다.
    private static func probe(_ label: String) {
        let sizes = [592, 300, 128, 64]     // MB — 실패한 크기들 순서대로
        var got: [String] = []
        for mb in sizes {
            let bytes = mb * 1_048_576
            if let p = malloc(bytes) {
                // 실제로 만지지 않으면 커밋되지 않아 "잡혔다" 가 거짓이 된다.
                memset(p, 0, min(bytes, 1 << 20))
                free(p)
                got.append("\(mb)MB ○")
            } else {
                got.append("\(mb)MB ✗")
            }
        }
        say("덩어리 확보 시험(\(label)) · 남음 \(mb(Int(os_proc_available_memory()))) · "
            + got.joined(separator: " "))
    }

    /// 기기에 남아 있는 채점 사진 중 가장 최근 것. 진단은 **실물**로 해야 한다.
    private static func latestGraderImage() -> String? {
        // 부정행위 검토 저장소는 PencilKit 풀이를 흰 배경 JPEG로 정규화한 입력이다.
        // grader-runs에는 카메라 권한·촬영 테스트 사진도 섞일 수 있으므로 먼저 합쳐
        // 최신 한 장을 고르면 시험지 아닌 셀피를 벤치마크하는 회귀가 생긴다.
        let dirs = [
            DataScope.url("cheating-reviews/images"),
            DataScope.url("grader-runs"),
        ]
        for dir in dirs.map(\.standardizedFileURL) {
            let items = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            if let newest = items
                .filter({ $0.pathExtension.lowercased() == "jpg" })
                .max(by: { a, b in
                    let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate) ?? .distantPast
                    let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey])
                        .contentModificationDate) ?? .distantPast
                    return da < db
                }) {
                return newest.path
            }
        }
        return nil
    }

    /// 저장된 소형 PencilKit 표본을 실제 부정행위 판독기와 같은 최소 해상도로 만든다.
    /// 임시 파일은 진단 스레드가 끝날 때 지우며 원본 사용자 파일은 건드리지 않는다.
    private static func normalizedBenchmarkImage(_ path: String) -> String {
        guard let source = UIImage(contentsOfFile: path) else { return path }
        let longest = max(source.size.width, source.size.height)
        guard longest > 0, longest < 1_024 else { return path }
        let contentScale = min(4, 1_024 / longest)
        let contentSize = CGSize(
            width: source.size.width * contentScale,
            height: source.size.height * contentScale)
        let padding: CGFloat = 40
        let target = CGSize(
            width: contentSize.width + padding * 2,
            height: contentSize.height + padding * 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            context.cgContext.interpolationQuality = .high
            source.draw(in: CGRect(
                origin: CGPoint(x: padding, y: padding),
                size: contentSize))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.94) else { return path }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("matths-vision-selftest-input.jpg")
        do {
            try data.write(to: url, options: .atomic)
            return url.path
        } catch {
            return path
        }
    }

    /// 앱이 뜨자마자 부른다. 요청이 없으면 즉시 돌아간다.
    static func runIfRequested() {
        guard let tier = requestedTier else { return }
        let previousTier = ModelDownloader.debugForcedTier ?? tierRestoreWasNil
        UserDefaults.standard.set(previousTier, forKey: tierRestoreMarker)
        UserDefaults.standard.synchronize()
        try? FileManager.default.removeItem(at: resultURL)   // 판마다 새로 쓴다
        try? FileManager.default.removeItem(at: metricsURL)
        try? FileManager.default.removeItem(at: diagnosticExportURL)

        if !tier.isEmpty { ModelDownloader.debugForcedTier = tier }
        let spec = ModelDownloader.recommended
        let mmName = ModelDownloader.mmprojFile(for: spec.file)
        let startedAt = Date()

        // 수동으로 옮겨 둔 기존 모델은 내용이 정상이더라도 무결성 영수증이 없을 수 있다.
        // discoverAndLoad는 영수증 없는 파일을 후보에서 제외하므로, 진단 타이머를 시작하기
        // 전에 실제 SHA-256을 확인하고 영수증을 만든다. 이 시간을 모델 로드 시간에 섞지 않는다.
        Task { @MainActor in
            let bodyReady = await LocalAIModelPack.verifyExistingArtifact(spec.file)
            let projectorReady: Bool
            if mmName.isEmpty {
                projectorReady = true
            } else {
                projectorReady = await LocalAIModelPack.verifyExistingArtifact(mmName)
            }
            guard bodyReady, projectorReady else {
                metric("preflight-failed", [
                    "tier": tier.isEmpty ? "current" : tier,
                    "model": spec.file,
                    "projector": mmName,
                    "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000),
                ])
                say("중단 — 모델 또는 비전 모듈 무결성 검증 실패")
                restoreForcedTierIfNeeded()
                return
            }
            metric("preflight-complete", [
                "tier": tier.isEmpty ? "current" : tier,
                "model": spec.file,
                "projector": mmName,
                "elapsedMs": Int(Date().timeIntervalSince(startedAt) * 1000),
            ])
            runVerified(tier: tier, spec: spec, mmName: mmName)
        }
    }

    @MainActor
    private static func runVerified(tier: String, spec: ModelDownloader.ModelSpec, mmName: String) {

        // 화면을 그리기 전에 재야 의미가 있다 — UI 가 잡은 메모리가 섞이면
        // "모델 때문에 모자란 것" 인지 구분이 안 된다.
        let atLaunch = Int(os_proc_available_memory())
        let residentAtLaunch = residentBytes()

        // 지난 판이 프로젝터를 열다 죽었으면 래치가 걸려 비전이 조용히 꺼진다.
        // 진단은 **그 래치를 풀고** 재야 한다 — 안 그러면 "왜 꺼졌는지" 가 아니라
        // "지난번에 죽었다" 만 반복해서 읽게 된다(7/29 첫 판이 정확히 그랬다).
        ModelDownloader.clearVisionDisabled()
        let path = AITutor.modelsDir.appendingPathComponent(spec.file).path
        let mmPath = AITutor.modelsDir.appendingPathComponent(mmName).path
        let mmBytes = ((try? FileManager.default
            .attributesOfItem(atPath: mmPath)[.size]) as? NSNumber)?.intValue ?? 0

        say("=== \(Date())")
        say("티어 \(tier.isEmpty ? "(현재)" : tier) · 본체 \(spec.file) · 프로젝터 \(mmName) \(mb(mmBytes))")
        say("기동 직후 남은 메모리 \(mb(atLaunch))")
        metric("launch", [
            "tier": tier.isEmpty ? "current" : tier,
            "model": spec.file,
            "projector": mmName,
            "projectorBytes": mmBytes,
            "availableBytes": atLaunch,
            "residentBytes": residentAtLaunch,
        ])
        guard FileManager.default.fileExists(atPath: path) else {
            say("중단 — 본체 파일이 없다: \(path)")
            restoreForcedTierIfNeeded()
            return
        }

        // **앱이 쓰는 엔진 하나만** 태운다. 여기서 LlamaEngine() 을 새로 만들면
        // 같은 프로세스에 3GB 모델이 둘 올라가 서로의 할당을 밀어낸다 —
        // 7/29 에 그렇게 나온 숫자를 원인이라고 두 번 잘못 읽었다.
        // 큰 덩어리를 **지금** 잡을 수 있는지 직접 찔러 본다.
        // 남은 메모리(os_proc_available_memory)는 5000MB 라고 말하는데 592MB
        // malloc 이 실패하는 일이 있었다. 그 둘이 어긋나면 원인은 총량이 아니라
        // **주소공간 단편화**다. 재 보지 않으면 또 추측이 된다.
        probe("기동 직후")

        // UI 가 다 올라온 뒤에 한 번 더 — 같은 크기가 그때도 잡히는지가 핵심이다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { probe("UI 구성 후") }

        // **init 안에서 곧바로** 로드한다. main.async 로 미루면 SwiftUI 가 화면을
        // 다 만든 다음에 로드가 돌아, 측정 조건이 실사용과도 달라지고 힙 상태도 달라진다.
        let loadProbe = MemoryProbe()
        loadProbe.start()
        MainActor.assumeIsolated { AITutor.shared.loadRecommended() }

        Thread.detachNewThread {
            defer { restoreForcedTierIfNeeded() }
            let t0 = Date()

            // 로드가 끝날 때까지 기다린다(최대 3분). 폴링이 투박하지만 진단 코드다.
            var ready = false
            for _ in 0..<180 {
                Thread.sleep(forTimeInterval: 1)
                var done = false
                DispatchQueue.main.sync {
                    if case .ready = AITutor.shared.modelState { ready = true; done = true }
                    if case .failed(let m) = AITutor.shared.modelState {
                        say("로드 실패: \(m)"); done = true
                    }
                }
                if done { break }
            }
            guard ready else {
                let peak = loadProbe.stop()
                metric("load-failed", [
                    "tier": tier.isEmpty ? "current" : tier,
                    "model": spec.file,
                    "elapsedMs": Int(Date().timeIntervalSince(t0) * 1000),
                    "minimumAvailableBytes": peak.minimumAvailable,
                    "maximumResidentBytes": peak.maximumResident,
                ])
                say("=== 끝"); return
            }

            // AITutor는 MainActor 소유지만 엔진 프로토콜 자체는 Sendable이다.
            // 메인 큐에서 참조만 꺼낸 뒤 무거운 자가진단 추론은 이 진단 스레드에서 한다.
            var engine: LLMEngine!
            DispatchQueue.main.sync { engine = AITutor.shared.debugEngine }
            let after = Int(os_proc_available_memory())
            let loadSeconds = Date().timeIntervalSince(t0)
            let loadPeak = loadProbe.stop()
            say("로드 성공 \(String(format: "%.1f초", loadSeconds))"
                + " · 비전 \(engine.visionReady ? "켜짐" : "꺼짐")"
                + " · 로드 후 남은 메모리 \(mb(after))"
                + " · 최대 상주 \(mb(loadPeak.maximumResident))")
            metric("load-complete", [
                "tier": tier.isEmpty ? "current" : tier,
                "model": spec.file,
                "elapsedMs": Int(loadSeconds * 1000),
                "visionReady": engine.visionReady,
                "availableBytes": after,
                "minimumAvailableBytes": loadPeak.minimumAvailable,
                "maximumResidentBytes": loadPeak.maximumResident,
            ])
            if let why = UserDefaults.standard.string(forKey: "matths.visionSkipReason"),
               !why.isEmpty { say("비전 꺼진 이유: \(why)") }

            // 8GB 기기의 실제 파이프라인은 3B VLM 판독 뒤 7B 수학 추론을 순차
            // 실행한다. deepseek7B 티어를 직접 요청한 판은 고정된 오답 진단으로
            // 텍스트 후단의 첫 출력·처리량·메모리를 같은 형식으로 잰다.
            if spec.mmprojFile.isEmpty {
                let prompt = LocalModelPrompt.oneShot(
                    modelIdentifier: engine.modelIdentifier,
                    system: "너는 수학 풀이 검증기다. 계산을 확인한 뒤 마지막에 JSON 객체 하나를 출력한다.",
                    user: "문제: (x-2)(x-3)=0. 학생 풀이: x=2 또는 x=-3. 풀이 전체가 모두 맞을 때만 valid=true이고, 제시한 해 중 하나라도 틀리면 반드시 valid=false다. 각 해를 원래 식에 대입해 판정하고 틀린 부호를 짚어라. JSON 키는 valid(boolean), reason(string)이며 reason에는 실제 오류 이유를 자연스러운 한국어로만 쓴다. JSON 키와 수학 변수 외의 외국어를 섞지 마라.",
                    // SheetGrader의 구조화 채점 경로와 동일하게 닫힌 think 뒤에서
                    // JSON만 생성한다. 진단에서만 Qwen 사고 모드를 열면 속도와 출력
                    // 품질을 실제 제품보다 나쁘게 측정하는 거짓 비교가 된다.
                    thinking: false)
                var params = LLMGenParams(
                    maxTokens: 320,
                    temperature: 0.6,
                    topP: 0.95,
                    topK: 20,
                    minP: 0,
                    presencePenalty: 0)
                LocalModelPrompt.applyRecommendedSampling(
                    &params,
                    modelIdentifier: engine.modelIdentifier)
                let t1 = Date()
                var got = 0
                var firstTokenAt: Date?
                let reasoningProbe = MemoryProbe()
                reasoningProbe.start()
                do {
                    let out = try engine.generate(prompt: prompt, params: params) { _ in
                        if firstTokenAt == nil { firstTokenAt = Date() }
                        got += 1
                        return true
                    }
                    let elapsed = Date().timeIntervalSince(t1)
                    let firstTokenSeconds = firstTokenAt?.timeIntervalSince(t1) ?? elapsed
                    let peak = reasoningProbe.stop()
                    let tokensPerSecond = elapsed > 0 ? Double(got) / elapsed : 0
                    metric("reasoning-complete", [
                        "tier": tier.isEmpty ? "current" : tier,
                        "model": spec.file,
                        "elapsedMs": Int(elapsed * 1000),
                        "firstTokenMs": Int(firstTokenSeconds * 1000),
                        "generatedTokens": got,
                        "tokensPerSecond": tokensPerSecond,
                        "minimumAvailableBytes": peak.minimumAvailable,
                        "maximumResidentBytes": peak.maximumResident,
                    ])
                    say("수학 추론 성공 \(String(format: "%.1f초", elapsed))"
                        + " · 첫 출력 \(String(format: "%.1f초", firstTokenSeconds))"
                        + " · \(String(format: "%.1f tok/s", tokensPerSecond))"
                        + " · 토큰 \(got) · 최대 상주 \(mb(peak.maximumResident))")
                    say("--- 모델이 판정한 것 ---")
                    say(out.trimmingCharacters(in: .whitespacesAndNewlines))
                    var finalObject = SheetGrader.parseJSON(out)
                    var languageClean = finalObject.map {
                        LocalModelOutputPolicy.isStudentFacingObjectAcceptable($0)
                    } ?? false
                    if let dirty = finalObject, !languageClean,
                       JSONSerialization.isValidJSONObject(dirty),
                       let data = try? JSONSerialization.data(withJSONObject: dirty, options: [.sortedKeys]),
                       let json = String(data: data, encoding: .utf8) {
                        let repairPrompt = LocalModelPrompt.jsonRewrite(
                            modelIdentifier: engine.modelIdentifier,
                            system: "너는 JSON 교정기다. 수학 판단도 확인한다. valid는 풀이 전체가 모두 맞을 때만 true이고 한 값이라도 틀리면 false다. 설명 문자열은 자연스러운 한국어로 고친다. 수학 기호와 JSON 키 외의 외국어는 쓰지 않는다. JSON 객체 하나만 출력한다.",
                            json: json)
                        var repairParams = LLMGenParams(
                            maxTokens: 320, temperature: 0.6, topP: 0.95,
                            topK: 20, minP: 0, presencePenalty: 0)
                        LocalModelPrompt.applyRecommendedSampling(
                            &repairParams, modelIdentifier: engine.modelIdentifier)
                        if let repaired = try? engine.generate(
                            prompt: repairPrompt, params: repairParams, onToken: { _ in true }),
                           let repairedObject = SheetGrader.parseJSON(repaired) {
                            finalObject = repairedObject
                            languageClean = LocalModelOutputPolicy.isStudentFacingObjectAcceptable(repairedObject)
                            say("--- 한국어 교정 결과 ---")
                            say(repaired.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    metric("reasoning-language", ["koreanOutputClean": languageClean])
                    say(languageClean ? "언어 품질 검사 통과" : "언어 품질 검사 실패 — 학생 화면 노출 금지")
                    say("-------------------------")
                } catch {
                    let peak = reasoningProbe.stop()
                    metric("reasoning-failed", [
                        "tier": tier.isEmpty ? "current" : tier,
                        "model": spec.file,
                        "elapsedMs": Int(Date().timeIntervalSince(t1) * 1000),
                        "generatedTokens": got,
                        "minimumAvailableBytes": peak.minimumAvailable,
                        "maximumResidentBytes": peak.maximumResident,
                    ])
                    say("수학 추론 실패: \(error)")
                }
                say("=== 끝")
                return
            }

            guard engine.visionReady, let shot = latestGraderImage() else {
                say(engine.visionReady ? "추론 생략 — 저장된 채점 사진이 없다" : "추론 생략 — 비전 꺼짐")
                say("=== 끝"); return
            }
            say("사진 추론 시작: \((shot as NSString).lastPathComponent)")
            let inferenceImage = normalizedBenchmarkImage(shot)
            defer {
                if inferenceImage != shot {
                    try? FileManager.default.removeItem(atPath: inferenceImage)
                }
            }
            let t1 = Date()
            var got = 0
            var firstTokenAt: Date?
            let inferenceProbe = MemoryProbe()
            inferenceProbe.start()
            do {
                let prompt = LocalModelPrompt.oneShot(
                    modelIdentifier: engine.modelIdentifier,
                    system: "너는 수학 풀이 사진 판독기다. 사진에 실제로 보이는 내용만 읽고 추측하지 마라.",
                    user: "<__media__>\n사진에 보이는 수학 식을 위에서 아래 순서로 그대로 옮겨 적어라. 같은 식·항·숫자가 반복되어도 합치거나 생략하지 말고, 보이는 줄마다 한 줄씩 출력하라. 추측하거나 식을 정리하지 마라. 글자가 없으면 '수학 식 없음'만 출력하라.",
                    thinking: false)
                let out = try engine.generateVision(
                    prompt: prompt,
                    imagePath: inferenceImage,
                    params: LLMGenParams(maxTokens: 160, temperature: 0.2)
                ) { _ in
                    if firstTokenAt == nil { firstTokenAt = Date() }
                    got += 1
                    return true
                }
                let elapsed = Date().timeIntervalSince(t1)
                let firstTokenSeconds = firstTokenAt?.timeIntervalSince(t1) ?? elapsed
                let inferencePeak = inferenceProbe.stop()
                let tokensPerSecond = elapsed > 0 ? Double(got) / elapsed : 0
                say("사진 추론 성공 \(String(format: "%.1f초", elapsed))"
                    + " · 첫 출력 \(String(format: "%.1f초", firstTokenSeconds))"
                    + " · \(String(format: "%.1f tok/s", tokensPerSecond))"
                    + " · 토큰 \(got) · 최대 상주 \(mb(inferencePeak.maximumResident))"
                    + " · 최소 여유 \(mb(inferencePeak.minimumAvailable))")
                metric("vision-complete", [
                    "tier": tier.isEmpty ? "current" : tier,
                    "model": spec.file,
                    "image": (shot as NSString).lastPathComponent,
                    "elapsedMs": Int(elapsed * 1000),
                    "firstTokenMs": Int(firstTokenSeconds * 1000),
                    "generatedTokens": got,
                    "tokensPerSecond": tokensPerSecond,
                    "minimumAvailableBytes": inferencePeak.minimumAvailable,
                    "maximumResidentBytes": inferencePeak.maximumResident,
                ])
                say("--- 모델이 읽은 것 ---")
                say(out.trimmingCharacters(in: .whitespacesAndNewlines))
                say("---------------------")
            } catch {
                let elapsed = Date().timeIntervalSince(t1)
                let inferencePeak = inferenceProbe.stop()
                var failure: [String: Any] = [
                    "elapsedMs": Int(elapsed * 1000),
                    "generatedTokens": got,
                    "minimumAvailableBytes": inferencePeak.minimumAvailable,
                    "maximumResidentBytes": inferencePeak.maximumResident,
                    "error": String(describing: error),
                ]
                if let firstTokenAt {
                    failure["firstTokenMs"] = Int(firstTokenAt.timeIntervalSince(t1) * 1000)
                }
                metric("vision-failed", failure)
                say("사진 추론 실패: \(error) · 최대 상주 \(mb(inferencePeak.maximumResident))"
                    + " · 최소 여유 \(mb(inferencePeak.minimumAvailable))")
            }
            say("=== 끝")
        }
    }

    /// 진단 성공뿐 아니라 jetsam 뒤 다음 정상 실행에서도 원래 디버그 선택을 복원한다.
    static func restoreForcedTierIfNeeded() {
        guard let previous = UserDefaults.standard.string(forKey: tierRestoreMarker) else { return }
        ModelDownloader.debugForcedTier = previous == tierRestoreWasNil ? nil : previous
        UserDefaults.standard.removeObject(forKey: tierRestoreMarker)
    }
}
#endif
