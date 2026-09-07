import Foundation

/// A StoreKit sheet is process-wide, not the same thing as transaction recovery
/// presentation. Listener events and account changes must not reopen this gate.
struct PurchaseAdmission {
    struct Ticket: Equatable { let id: UUID; let productID: String }
    private(set) var active: Ticket?

    mutating func begin(productID: String) -> Ticket? {
        guard active == nil else { return nil }
        let ticket = Ticket(id: UUID(), productID: productID)
        active = ticket
        return ticket
    }
    mutating func finish(_ ticket: Ticket) {
        guard active == ticket else { return }
        active = nil
    }
}
