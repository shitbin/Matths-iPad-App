import Foundation

@main
struct PurchaseAdmissionCases {
    static func main() {
        var gate = PurchaseAdmission()
        guard let first = gate.begin(productID: "pass") else { fatalError("First purchase must enter") }
        // Independent listener states and account resets have no authority over
        // the active system purchase sheet's admission ticket.
        for _ in 0..<20 { precondition(gate.begin(productID: "mock") == nil) }
        gate.finish(.init(id: UUID(), productID: "pass"))
        precondition(gate.active == first)
        gate.finish(first)
        guard let second = gate.begin(productID: "mock") else { fatalError("Closed sheet must release") }
        gate.finish(first)
        precondition(gate.active == second, "Late old completion released a newer sheet")
        gate.finish(second)
        precondition(gate.active == nil)
        print("StoreKit purchase admission: 20 duplicate attempts, unrelated/late completion and release: PASS (no Apple transaction executed)")
    }
}
