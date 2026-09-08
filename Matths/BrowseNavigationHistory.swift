import Foundation

/// Ephemeral, bounded browse history. It stores only destinations, never user
/// data, and cannot return through another account's navigation context.
struct BrowseNavigationHistory<Destination: Hashable> {
    private(set) var path: [Destination] = []
    private var owner: String?
    let capacity: Int

    init(capacity: Int = 12) { self.capacity = max(1, capacity) }

    mutating func transition(owner: String, from previous: Destination,
                             to destination: Destination, isRoot: Bool) {
        guard self.owner == owner else {
            self.owner = owner
            path = []
            return
        }
        if isRoot { path = []; return }
        guard previous != destination else { return }
        if let index = path.lastIndex(of: destination) {
            path.removeSubrange(index...)
        } else {
            path.append(previous)
            if path.count > capacity { path.removeFirst(path.count - capacity) }
        }
    }

    func previous(owner: String) -> Destination? {
        self.owner == owner ? path.last : nil
    }
}
