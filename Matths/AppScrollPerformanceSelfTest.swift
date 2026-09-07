#if DEBUG
import SwiftUI
import UIKit
import WebKit
import CryptoKit
import Darwin

/// Passive, opt-in measurement of actual app screens. This observer never changes
/// a route, scroll offset or input. The operator performs the desired scroll through
/// the simulator UI. It is not a physical-device budget or Instruments GPU trace.
@MainActor enum AppScrollPerformanceSelfTest {
    private static var hasRun = false

    static func runIfRequested(store: AppStore) async {
        guard ProcessInfo.processInfo.arguments.contains("-scrollPerformanceSelfTest"),
              DemoMode.isOn, !hasRun else { return }
        hasRun = true
        _ = await RankPromotionPipelinePrewarmState.waitUntilReady()
        let args = ProcessInfo.processInfo.arguments
        let label = args.firstIndex(of: "-performanceScreen").flatMap { index in
            index + 1 < args.count ? args[index + 1] : nil
        } ?? String(describing: store.route)
        // Measurement-only preparation window; never drives product readiness.
        try? await Task.sleep(for: .seconds(5))
        guard !Task.isCancelled else { return }
        NSLog("MATTHS-PERFORMANCE observation start: %@ (30 seconds)", label)
        let sample = await Monitor().measure(screen: label, seconds: 30)
        let info = Bundle.main.infoDictionary ?? [:]
        let executableHash = Bundle.main.executableURL.flatMap { try? Data(contentsOf: $0) }
            .map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "unavailable"
        let report: [String: Any] = [
            "schema": "MATTHS_APP_SCROLL_PERFORMANCE_V1",
            "observedAt": ISO8601DateFormatter().string(from: Date()),
            "result": "MEASURED_NOT_RELEASE_VERDICT",
            "configuration": "DEBUG demo fixtures; passive observer; operator-controlled simulator UI",
            "appBuild": info["CFBundleVersion"] as? String ?? "unknown",
            "appExecutableSHA256": executableHash,
            "sourceCommit": info["MatthsSourceCommit"] as? String ?? "unknown",
            "sourceTrackedWorkingTreeClean": info["MatthsSourceTrackedWorkingTreeClean"] as? Bool ?? false,
            "hardware": ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? UIDevice.current.model,
            "os": UIDevice.current.systemVersion,
            "samples": [sample],
            "limitations": ["CADisplayLink gaps are main-runloop callback gaps, not GPU render hitch measurements",
                            "Offset changes are observed only; correlate with separately recorded operator/CUA actions",
                            "RSS and CPU exclude WebKit auxiliary and extension processes",
                            "No absolute timer/task/request counts are instrumented",
                            "Shared Mac simulator metrics are not minimum-device, thermal or energy budgets"]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app-scroll-performance.json")
        do {
            try data.write(to: url, options: .atomic)
            NSLog("MATTHS-PERFORMANCE observation saved: %@", url.path)
        }
        catch { NSLog("AppScrollPerformanceSelfTest report failed") }
    }

    private static func windows() -> [UIWindow] {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }.flatMap(\.windows)
            .filter { !$0.isHidden && $0.alpha > 0.05 }
    }

    private static func allViews(_ root: UIView) -> [UIView] {
        [root] + root.subviews.flatMap(allViews)
    }

    private static func scrollView() -> UIScrollView? {
        windows().flatMap(allViews).compactMap { $0 as? UIScrollView }
            .filter { view in
                guard let window = view.window else { return false }
                var ancestor: UIView? = view
                while let current = ancestor {
                    if current.isHidden || current.alpha < 0.05 { return false }
                    ancestor = current.superview
                }
                return view.isScrollEnabled && view.bounds.height > 100
                    && view.contentSize.height + view.adjustedContentInset.top + view.adjustedContentInset.bottom > view.bounds.height + 20
                    && view.convert(view.bounds, to: window).intersects(window.bounds)
            }
            .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }

    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.resident_size : 0
    }

    private static func cpuSeconds() -> Double {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    @MainActor private final class Monitor: NSObject {
        private var link: CADisplayLink?
        private weak var scrolling: UIScrollView?
        private var start = 0.0
        private var previous: Double?
        private var intervals: [Double] = []
        private var peakResident: UInt64 = 0
        private var changedOffsetFrames = 0
        private var previousOffset: CGPoint?
        private var maximumContentHeight: CGFloat = 0
        private var observedScrollViewTypes: Set<String> = []

        func measure(screen: String, seconds: Double) async -> [String: Any] {
            scrolling = AppScrollPerformanceSelfTest.scrollView()
            let initialResident = residentBytes()
            peakResident = initialResident
            let initialCPU = cpuSeconds()
            start = CACurrentMediaTime()
            let displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
            displayLink.preferredFrameRateRange = .init(minimum: 30, maximum: 120, preferred: 60)
            displayLink.add(to: .main, forMode: .common)
            link = displayLink
            try? await Task.sleep(for: .seconds(seconds))
            displayLink.invalidate(); link = nil
            let duration = CACurrentMediaTime() - start
            let sorted = intervals.sorted()
            func percentile(_ proportion: Double) -> Double {
                guard !sorted.isEmpty else { return 0 }
                return sorted[min(sorted.count - 1, max(0, Int(ceil(Double(sorted.count) * proportion)) - 1))]
            }
            let result: [String: Any] = [
                "screen": screen,
                "scrollStatus": changedOffsetFrames > 0 ? "OFFSET_CHANGES_OBSERVED" : "STATIC_OBSERVATION_NO_OFFSET_CHANGES",
                "durationSeconds": duration, "displayLinkCallbackCount": intervals.count,
                "callbackGapMs": ["p50": percentile(0.50) * 1_000, "p95": percentile(0.95) * 1_000,
                                  "max": (sorted.last ?? 0) * 1_000],
                "callbackGapsOver50ms": intervals.filter { $0 > 0.050 }.count,
                "callbackGapsOver100ms": intervals.filter { $0 > 0.100 }.count,
                "observedOffsetChangedFrames": changedOffsetFrames,
                "maximumObservedContentHeight": maximumContentHeight,
                "observedScrollViewTypes": observedScrollViewTypes.sorted(),
                "scrollViewportHeight": scrolling?.bounds.height ?? 0,
                "cpuSeconds": cpuSeconds() - initialCPU,
                "initialResidentBytes": initialResident, "peakSampledResidentBytes": peakResident,
                "finalResidentBytes": residentBytes()
            ]
            scrolling = nil
            return result
        }

        @objc private func tick(_ sender: CADisplayLink) {
            if let previous { intervals.append(max(0, sender.timestamp - previous)) }
            previous = sender.timestamp
            if intervals.count.isMultiple(of: 30) {
                peakResident = max(peakResident, residentBytes())
                // Passive discovery allows an operator to navigate during the run.
                let current = AppScrollPerformanceSelfTest.scrollView()
                if current !== scrolling { previousOffset = nil; scrolling = current }
            }
            guard let scrolling else { return }
            let offset = scrolling.contentOffset
            if let previousOffset, previousOffset != offset { changedOffsetFrames += 1 }
            previousOffset = offset
            maximumContentHeight = max(maximumContentHeight, scrolling.contentSize.height)
            observedScrollViewTypes.insert(String(describing: type(of: scrolling)))
        }
    }
}
#endif
