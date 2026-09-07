import Foundation

@main enum WebHandoffOwnershipCases {
    static func main() {
        let oldView = NSObject(), newView = NSObject()
        var gate = WebHandoffOwnership()
        let old = gate.begin(slot: "account-a", viewIdentity: ObjectIdentifier(oldView))
        precondition(gate.owns(old, slot: "account-a", viewIdentity: ObjectIdentifier(oldView)))
        precondition(!gate.owns(old, slot: "account-b", viewIdentity: ObjectIdentifier(oldView)))
        precondition(!gate.owns(old, slot: "account-a", viewIdentity: ObjectIdentifier(newView)))
        let latest = gate.begin(slot: "account-a", viewIdentity: ObjectIdentifier(oldView))
        precondition(!gate.owns(old, slot: "account-a", viewIdentity: ObjectIdentifier(oldView)))
        precondition(gate.owns(latest, slot: "account-a", viewIdentity: ObjectIdentifier(oldView)))
        gate.invalidate()
        precondition(!gate.owns(latest, slot: "account-a", viewIdentity: ObjectIdentifier(oldView)))
        var tickets: [WebHandoffOwnership.Ticket] = []
        for _ in 0..<20 { tickets.append(gate.begin(slot: "account-a", viewIdentity: ObjectIdentifier(newView))) }
        precondition(tickets.filter { gate.owns($0, slot: "account-a", viewIdentity: ObjectIdentifier(newView)) }.count == 1)

        let base = URL(string: "https://matths.kr")!
        precondition(WebHandoffOwnership.validatedURL("https://matths.kr/app/commerce/synthetic", base: base) != nil)
        for bad in ["http://matths.kr/app/commerce/token", "https://evil.example/app/commerce/token",
                    "https://matths.kr.evil.example/app/commerce/token", "https://user@matths.kr/app/commerce/token",
                    "https://matths.kr:444/app/commerce/token", "https://matths.kr/app/commerce/",
                    "https://matths.kr/app/commerce/%2e%2e/account",
                    "https://matths.kr/account", "file:///app/commerce/token"] {
            precondition(WebHandoffOwnership.validatedURL(bad, base: base) == nil, bad)
        }
        print("Web handoff ownership: account/request/view generations, 20 superseded responses and strict same-origin grant URLs passed")
    }
}
