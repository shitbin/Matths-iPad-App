import Foundation

@main
struct AsyncCompletionSignalCases {
    @MainActor static func main() async {
        let signal = AsyncCompletionSignal()
        let first = signal.begin()
        let tasks = (0..<20).map { _ in Task { await signal.wait(for: first) } }
        while signal.waiterCount < 20 { await Task.yield() }
        tasks[0].cancel()
        while signal.waiterCount == 20 { await Task.yield() }
        signal.finish(first)
        for (index, task) in tasks.enumerated() {
            let completed = await task.value
            precondition(completed == (index != 0))
        }
        let late = await signal.wait(for: first)
        precondition(late)
        let second = signal.begin()
        let waiting = Task { await signal.wait(for: second) }
        while signal.waiterCount < 1 { await Task.yield() }
        signal.finish(first)
        precondition(signal.current == second && signal.waiterCount == 1)
        signal.finish(second)
        let finished = await waiting.value
        precondition(finished)
        print("20 completion waiters, cancellation, completion-before-registration and stale epoch isolation: PASS")
    }
}
