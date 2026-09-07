// Standalone simulator app. Compiles the actual four representables with only
// WKWebView substituted by a counting subclass; no production accounts/network.
import SwiftUI
import WebKit
import Darwin

struct GeneratedProblem: Identifiable {
    let id: String
    let statement: String
    var choices: [String]? = ["1", "2", "3", "4", "5"]
}

@MainActor final class InstrumentedWebView: WKWebView {
    static var loads: [String: Int] = [:]
    static var evaluations = 0
    static var live = NSHashTable<InstrumentedWebView>.weakObjects()
    static var loadedAt: [String: Double] = [:]
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        Self.live.add(self)
    }
    required init?(coder: NSCoder) { nil }
    override func loadFileURL(_ URL: URL, allowingReadAccessTo readAccessURL: URL) -> WKNavigation? {
        Self.loads[URL.lastPathComponent, default: 0] += 1
        Self.loadedAt[URL.lastPathComponent] = ProcessInfo.processInfo.systemUptime
        return super.loadFileURL(URL, allowingReadAccessTo: readAccessURL)
    }
    override func evaluateJavaScript(_ javaScriptString: String,
                                    completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
        Self.evaluations += 1
        super.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
    }
}

@MainActor final class Driver: ObservableObject {
    @Published var kind = "none"
    @Published var version = 0
    @Published var height: CGFloat = 200
    @Published var picked: String? = nil
    @Published var passed = false
    @Published var tick = 0
    @Published var enlarged = false
    var done = false
    var cases: [[String: Any]] = []
    var residentSamples: [UInt64] = []

    func run() async {
        guard !done else { return }; done = true
        let started = ProcessInfo.processInfo.systemUptime
        let cpuStart = cpuSeconds()
        for viewKind in ["problem", "lesson", "hint", "lottie"] {
            kind = viewKind; version = 0; tick = 0; enlarged = false
            let appearStart = ProcessInfo.processInfo.systemUptime
            await settle()
            let initial = InstrumentedWebView.loads
            let initialEvaluations = InstrumentedWebView.evaluations
            var jsResizeBefore = 0
            if let web = InstrumentedWebView.live.allObjects.first {
                _ = try? await web.evaluateJavaScript("window.__perfResize = 0; window.addEventListener('resize', () => window.__perfResize++); window.__perfApply = 0; window.addEventListener('matthsAccessibilityChanged', () => window.__perfApply++);")
                jsResizeBefore = (try? await web.evaluateJavaScript("window.__perfResize")) as? Int ?? -1
            }
            for index in 1...20 {
                tick = index; height += 1
                try? await Task.sleep(for: .milliseconds(25))
            }
            await settle()
            let unchanged = InstrumentedWebView.loads
            let unchangedEvaluations = InstrumentedWebView.evaluations - initialEvaluations
            var unchangedJSApply = -1
            if let web = InstrumentedWebView.live.allObjects.first {
                unchangedJSApply = (try? await web.evaluateJavaScript("window.__perfApply")) as? Int ?? -1
            }
            enlarged = true
            await settle()
            var changedAppearanceScale = 0.0
            if let web = InstrumentedWebView.live.allObjects.first {
                changedAppearanceScale = (try? await web.evaluateJavaScript("window.MATTHS_ACCESSIBILITY.scale")) as? Double ?? 0
            }
            version = 1
            await settle()
            var payload = "missing"
            if let web = InstrumentedWebView.live.allObjects.first {
                let key = switch viewKind {
                case "problem": "window.MATTHS_PROBLEM.prompt"
                case "lesson": "window.MATTHS_CONCEPT"
                case "hint": "window.MATTHS_HINT.hintText"
                default: "String(window.MATTHS_LOTTIE.loop)"
                }
                payload = (try? await web.evaluateJavaScript(key)) as? String ?? "missing"
            }
            let changed = InstrumentedWebView.loads
            cases.append(["kind": viewKind, "loadsAfterMount": initial,
                          "loadsAfter20ParentUpdates": unchanged, "loadsAfterContentChange": changed,
                          "javaScriptCallsDuring20Updates": unchangedEvaluations,
                          "jsAppearanceEventsDuring20Updates": unchangedJSApply,
                          "changedAppearanceScale": changedAppearanceScale,
                          "jsResizeBefore": jsResizeBefore,
                          "changedPayload": payload,
                          "scenarioWallSeconds": ProcessInfo.processInfo.systemUptime - appearStart,
                          "residentBytes": residentBytes()])
            kind = "none"; await settle()
            cases[cases.count - 1]["liveWebViewsAfterUnmount"] = InstrumentedWebView.live.allObjects.count
        }
        var navigationCounts: [[String: Any]] = []
        for index in 0..<10 {
            kind = "problem"; version = 0; await settle()
            kind = "none"; await settle()
            residentSamples.append(residentBytes())
            navigationCounts.append(["iteration": index + 1,
                                     "liveWebViewsAfterUnmount": InstrumentedWebView.live.allObjects.count,
                                     "problemLoadCalls": InstrumentedWebView.loads["problem.html"] ?? 0,
                                     "residentBytes": residentBytes()])
        }
        let report: [String: Any] = [
            "schema": "MATTHS_WEBVIEW_RUNTIME_PERFORMANCE_V1",
            "observedAt": ISO8601DateFormatter().string(from: Date()),
            "device": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "unknown",
            "os": UIDevice.current.systemVersion, "configuration": "standalone Debug simulator harness",
            "scope": "actual bundled representables; instrumented WKWebView subclass; no host AppStore/network",
            "cases": cases, "navigationLoops": navigationCounts,
            "wallSeconds": ProcessInfo.processInfo.systemUptime - started,
            "processCPUSeconds": cpuSeconds() - cpuStart,
            "processPeakSampledResidentBytes": residentSamples.max() ?? 0,
            "limitations": ["CPU/RSS exclude WebKit auxiliary processes", "not physical-device performance", "not production launch or scroll hitch metrics"]
        ]
        let data = try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("webview-performance.json")
        try! data.write(to: url, options: .atomic)
        print("MATTHS_WEBVIEW_PERFORMANCE_DONE \(url.path)")
    }
    private func settle() async {
        try? await Task.sleep(for: .milliseconds(350))
        for _ in 0..<80 {
            if !InstrumentedWebView.live.allObjects.contains(where: \.isLoading) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        try? await Task.sleep(for: .milliseconds(150))
    }
    private func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    private func cpuSeconds() -> Double {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
}

struct HarnessRoot: View {
    @StateObject private var driver = Driver()
    var body: some View {
        VStack {
            Text("WebView runtime QA \(driver.kind) \(driver.tick)")
            switch driver.kind {
            case "problem":
                ProblemWebView(problem: .init(id: "fixture-problem", statement: "$x+\(driver.version)$"),
                               height: $driver.height, pickedKey: $driver.picked)
                    .frame(height: driver.height)
            case "lesson":
                LessonWebView(conceptID: driver.version == 0 ? "absolute-inequality" : "absolute-linear-inequalities",
                              height: $driver.height, quizPassed: $driver.passed).frame(height: driver.height)
            case "hint":
                HintWebView(hintText: "hint-\(driver.version)", visualizationJSON: nil,
                            height: $driver.height).frame(height: driver.height)
            case "lottie":
                LottieWebView(name: "rank-badge-fx", loop: driver.version == 1).frame(height: driver.height)
            default: Text("Unmounted")
            }
        }.environment(\.dynamicTypeSize, driver.enlarged ? .xLarge : .large)
            .task { await driver.run() }
    }
}

@main struct WebViewPerformanceApp: App {
    var body: some Scene { WindowGroup { HarnessRoot() } }
}
