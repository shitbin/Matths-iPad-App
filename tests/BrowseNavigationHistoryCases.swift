import Foundation

@main struct BrowseNavigationHistoryCases {
    static func main() {
        var history = BrowseNavigationHistory<String>(capacity: 4)
        func move(_ from: String, _ to: String, root: Bool = false, owner: String = "A-session-1") {
            history.transition(owner: owner, from: from, to: to, isRoot: root)
        }
        move("home", "me", root: true)
        move("me", "resources")
        precondition(history.previous(owner: "A-session-1") == "me")
        move("resources", "archive")
        precondition(history.previous(owner: "A-session-1") == "resources")
        move("archive", "notifications")
        precondition(history.previous(owner: "A-session-1") == "archive")
        move("notifications", "archive")
        precondition(history.previous(owner: "A-session-1") == "resources", "return retains the original resource context")
        move("archive", "commerce")
        move("commerce", "archive")
        precondition(history.previous(owner: "A-session-1") == "resources")
        move("archive", "resources")
        precondition(history.previous(owner: "A-session-1") == "me")
        move("resources", "learn", root: true)
        precondition(history.path.isEmpty)
        move("learn", "course")
        move("course", "concept")
        move("concept", "concept")
        precondition(history.path == ["learn", "course"], "same route does not grow the stack")
        precondition(history.previous(owner: "B-session-1") == nil)
        move("concept", "profile", owner: "B-session-1")
        precondition(history.path.isEmpty, "new account cannot inherit the old route")
        move("profile", "resources", owner: "B-session-1")
        precondition(history.previous(owner: "B-session-2") == nil, "same account reauthentication has a new boundary")
        for i in 0..<20 { move("p\(i)", "p\(i+1)", owner: "B-session-1") }
        precondition(history.path.count == 4)
        move("p20", "p18", owner: "B-session-1")
        precondition(history.previous(owner: "B-session-1") == "p17", "jumping back removes the abandoned suffix")
        print("Browse navigation history: nested-return, cycle, capacity and account checks PASS")
    }
}
