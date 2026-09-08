import Foundation

@MainActor final class AppStore {
    enum Route { case home, learn, records, academy, assess, paper, concept, solve }
    struct Attempt {
        let id: String
        var serverBacked: Bool? = true
        var isServerCancelled = false
        var submittedAt: Date?
    }
    struct Attempts { var attempts: [Attempt] = [] }
    var generation = UUID()
    var route: Route = .home
    var assessmentReturnRoute: Route = .learn
    var currentAttemptID: String?
    var attemptsV2 = Attempts()
    var pending: [CheckedContinuation<Void, Never>] = []
    var requests = 0
    var todayReviewIDs = ["review-a"]
    func captureAccountSessionBoundary() -> UUID { generation }
    func ownsCurrentAccountSession(_ value: UUID) -> Bool { generation == value }
    func pullServerAssessments() async {
        requests += 1
        await withCheckedContinuation { pending.append($0) }
    }
    func finish(_ index: Int = 0) { pending.remove(at: index).resume() }
    func startReview(ids: [String]) { route = .solve }
    func openConceptV2(_ id: String) { route = .concept }
}

@MainActor final class TodayNavigationHarness {
    let store = AppStore()
    var selectedActivity: TodayActionCandidate?
    var navigationID = UUID()
    var actionBusy = false
    func move(to route: AppStore.Route) {
        store.route = route
        exerciseRouteChange()
    }
}

@main enum TodayAssessmentNavigationCases {
    @MainActor static var checks = 0
    @MainActor static var failures: [String] = []
    @MainActor static func expect(_ value: Bool, _ description: String) {
        checks += 1
        if !value { failures.append(description) }
    }
    static func candidate(_ destination: TodayActionCandidate.Destination) -> TodayActionCandidate {
        .init(id: "synthetic", kind: .timedWork, title: "Fixture", reason: "Fixture", action: "Open",
              minutes: nil, destination: destination, source: .serverAssessment)
    }
    @MainActor static func wait(_ predicate: () -> Bool) async {
        for _ in 0..<10_000 {
            if predicate() { return }
            await Task.yield()
        }
        fatalError("actual navigation action did not reach expected suspension boundary")
    }
    @MainActor static func settle() async { for _ in 0..<300 { await Task.yield() } }
    @MainActor static func start(_ harness: TodayNavigationHarness, id: String = "a") async {
        harness.exercisePerform(candidate(.officialAssessment(id)))
        await wait { !harness.store.pending.isEmpty }
        expect(harness.actionBusy, "request must report busy while awaiting its snapshot")
    }

    @MainActor static func main() async throws {
        let current = TodayNavigationHarness()
        current.store.attemptsV2.attempts = [.init(id: "a")]
        await start(current)
        current.store.finish(); await settle()
        expect(current.store.route == .paper && current.store.currentAttemptID == "a", "current official attempt opens paper")
        expect(current.store.assessmentReturnRoute == .assess, "direct Today entry resets the previous return origin")
        expect(!current.actionBusy, "success releases busy")

        let noLongerActive: [[AppStore.Attempt]] = [
            [], [.init(id: "different")], [.init(id: "a", serverBacked: false)],
            [.init(id: "a", serverBacked: nil)], [.init(id: "a", isServerCancelled: true)],
            [.init(id: "a", submittedAt: Date())]
        ]
        for (index, values) in noLongerActive.enumerated() {
            let harness = TodayNavigationHarness()
            harness.store.attemptsV2.attempts = values
            await start(harness)
            harness.store.finish(); await settle()
            expect(harness.store.route == .assess && harness.store.currentAttemptID == nil,
                   "missing/cancelled/submitted/local-only attempt returns to assessment center (case \(index))")
            expect(!harness.actionBusy, "fallback releases busy (case \(index))")
        }

        for backHome in [false, true] {
            let harness = TodayNavigationHarness()
            harness.store.attemptsV2.attempts = [.init(id: "a")]
            await start(harness)
            harness.move(to: .learn)
            expect(!harness.actionBusy, "actual route-change handler retires busy")
            if backHome { harness.move(to: .home) }
            let destination = harness.store.route
            harness.store.finish(); await settle()
            expect(harness.store.route == destination && harness.store.currentAttemptID == nil,
                   "late response cannot steal a changed tab, including home→learn→home")
            expect(!harness.actionBusy, "tab change keeps busy clear")
        }

        let changedAccount = TodayNavigationHarness()
        changedAccount.store.attemptsV2.attempts = [.init(id: "a")]
        await start(changedAccount)
        changedAccount.store.generation = UUID()
        changedAccount.store.finish(); await settle()
        expect(changedAccount.store.route == .home && changedAccount.store.currentAttemptID == nil,
               "same-screen account replacement rejects old response")
        expect(!changedAccount.actionBusy, "account replacement completes old wait without leaving busy")

        for newerFirst in [false, true] {
            let harness = TodayNavigationHarness()
            harness.store.attemptsV2.attempts = [.init(id: "a"), .init(id: "b")]
            await start(harness)
            harness.exercisePerform(candidate(.officialAssessment("b")))
            await wait { harness.store.pending.count == 2 }
            harness.store.finish(newerFirst ? 1 : 0); await settle()
            if newerFirst {
                expect(harness.store.currentAttemptID == "b" && !harness.actionBusy, "newest response wins when returned first")
            } else {
                expect(harness.store.route == .home && harness.store.currentAttemptID == nil && harness.actionBusy,
                       "older completion cannot navigate or release the newer request's busy")
            }
            harness.store.finish(); await settle()
            expect(harness.store.currentAttemptID == "b" && harness.store.route == .paper && !harness.actionBusy,
                   "newest request owns final navigation in either completion order")
        }

        for destination in [TodayActionCandidate.Destination.weeklyMock("weekly"), .arena("arena"), .academyWeek("week")] {
            let harness = TodayNavigationHarness()
            harness.store.attemptsV2.attempts = [.init(id: "a")]
            await start(harness)
            harness.exercisePerform(candidate(destination))
            expect(harness.selectedActivity?.destination == destination, "chosen modal opens")
            harness.store.finish(); await settle()
            expect(harness.store.route == .home && harness.store.currentAttemptID == nil,
                   "a newly opened \(destination) modal must not be replaced by the previous assessment response")
            expect(harness.selectedActivity?.destination == destination && !harness.actionBusy,
                   "modal selection remains owned and obsolete busy is released")
        }
        if !failures.isEmpty {
            for failure in failures { print("FAIL: \(failure)") }
            print("\(failures.count)/\(checks) checks failed")
            exit(1)
        }
        print("PASS: actual Today perform/route-change functions, \(checks) checks: valid/fallback receipt, tab/return/account races, reversed responses, three modal interruptions and busy ownership")
    }
}
