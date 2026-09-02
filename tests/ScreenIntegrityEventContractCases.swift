import Foundation

@main
enum ScreenIntegrityEventContractCases {
    static func main() {
        require(
            ScreenIntegrityEventContract.normalizedEventType("protected-screen-screenshot")
                == "protected-screen-screenshot",
            "the documented screenshot event must pass"
        )
        require(
            ScreenIntegrityEventContract.normalizedEventType("problem-correct") == nil,
            "learning/economy events must not enter through the integrity recorder"
        )
        require(
            ScreenIntegrityEventContract.normalizedSessionCode("ab12cd34") == "AB12CD34",
            "the generated eight-character UUID prefix must pass"
        )
        require(
            ScreenIntegrityEventContract.normalizedSessionCode("student@example.com") == "UNKNOWN",
            "arbitrary user text must be discarded rather than cleaned into a payload"
        )
        require(
            ScreenIntegrityEventContract.normalizedSurface("weekly-mock,goat-arena,weekly-mock")
                == "goat-arena,weekly-mock",
            "known overlapping surfaces must be de-duplicated deterministically"
        )
        require(
            ScreenIntegrityEventContract.normalizedSurface("student@example.com/match/42")
                == "protected",
            "unknown surface text must be discarded instead of uploaded"
        )

        let accountSlot = "acct-0123456789ab"
        let first = DataScope.screenProtectionAccountCode(for: accountSlot)
        let second = DataScope.screenProtectionAccountCode(for: accountSlot)
        let other = DataScope.screenProtectionAccountCode(for: "acct-fedcba987654")
        require(first == second, "the same account must have a stable pseudonymous code")
        require(first.count == 8 && first != other, "account codes must be short and account-scoped")
        require(!first.lowercased().contains(accountSlot), "the slot hash must not be displayed verbatim")
        require(
            DataScope.screenProtectionAccountCode(for: "guest") == "GUEST",
            "guest mode must be explicit and must not imitate an account"
        )

        print("Screen integrity privacy contract cases passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
