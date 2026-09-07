import Foundation

@MainActor
enum NativeServiceActions {
    /// Capture in the button callback, not after an unstructured Task gets its
    /// first turn. This also closes the A → B → A same-slot login window.
    static func run(store: AppStore, operation: @escaping @MainActor () async -> Void) {
        guard let owner = AccountRequestOwner(store: store) else { return }
        Task { @MainActor in
            guard owner.isCurrent(in: store) else { return }
            await operation()
        }
    }
}
