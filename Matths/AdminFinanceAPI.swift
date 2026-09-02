import Foundation

extension ServerAPI {
    struct AdminFinancePerson: Codable, Hashable {
        var id: String
        var name: String
        var email: String
    }

    struct AdminFinanceWithdrawal: Codable, Identifiable, Hashable {
        var id: String
        var amount: Int
        var status: String
        var operatorNote: String
        var balanceBefore: Int
        var balanceAfter: Int
        var completedAt: String?
        var completedBy: AdminFinancePerson?
    }

    struct AdminFinanceDashboard: Codable, Hashable {
        var currency: String
        var grossPayments: Int
        var netCollected: Int
        var refundedAndCancelled: Int
        var todayRevenue: Int
        var actualCashBalance: Int
        var cumulativePaybackPaid: Int
        var paybackReserve: Int
        var confirmedUnpaidPayback: Int
        var pgFeeReserve: Int
        var otherUnpaidCosts: Int
        var cumulativeConfirmedProfit: Int
        var cumulativeWithdrawals: Int
        var withdrawableAmount: Int
        var pgFeeReserveBps: Int
        var withdrawalsEnabled: Bool
        var lastReconciledAt: String?
        var recentWithdrawals: [AdminFinanceWithdrawal]
    }

    struct AdminRefundCalculation: Codable, Hashable {
        var policyVersion: String
        var approvedAmount: Int
        var paidFeatureUsed: Bool
        var usedDays: Int
        var calculationType: String
        var calculatedAmount: Int
        var formula: String
        var calculatedAt: String?
        var calculatedBy: AdminFinancePerson?
    }

    struct AdminRefundDecision: Codable, Hashable {
        var approvedAmount: Int
        var cancellationMode: String
        var providerCancellationTransactionKey: String
        var providerCancelledAt: String?
        var processedAt: String?
        var processedBy: AdminFinancePerson?
        var operatorNote: String
    }

    struct AdminRefund: Codable, Identifiable, Hashable {
        var id: String
        var user: AdminFinancePerson?
        var provider: String
        var providerMode: String
        var requestedByType: String
        var productCode: String
        var productName: String
        var orderReference: String
        var reasonType: String
        var reasonDetail: String
        var status: String
        var requestedAt: String?
        var processingDeadlineAt: String?
        var calculation: AdminRefundCalculation
        var decision: AdminRefundDecision
    }

    struct AdminFinancePagination: Codable, Hashable {
        var page: Int
        var total: Int
        var totalPages: Int
        var hasPrevious: Bool
        var hasNext: Bool
    }

    struct AdminRefundPage: Codable, Hashable {
        struct Filter: Codable, Hashable { var status: String }
        var items: [AdminRefund]
        var filter: Filter
        var pagination: AdminFinancePagination
    }

    struct AdminPaybackEligible: Codable, Hashable {
        var total: Int
        var linkedTotal: Int
        var payoutRate: Double
        var pendingAmount: Int
    }

    struct AdminPaybackMonthly: Codable, Hashable {
        var salesAmount: Int
        var salesCount: Int
        var payoutAmount: Int
        var payoutCount: Int
        var payoutToSalesRate: Double
    }

    struct AdminPaybackRow: Codable, Identifiable, Hashable {
        var cycleId: String
        var userId: String
        var userName: String
        var email: String
        var paybackRate: Double
        var paybackAmount: Int
        var evaluatedAt: String?
        var payoutDeadlineAt: String?
        var payoutOverdue: Bool
        var accountConfirmed: Bool
        var bankName: String
        var accountHolderName: String
        var accountNumber: String
        var accountNumberLast4: String
        var decryptError: Bool
        var id: String { cycleId }
    }

    struct AdminPaybackHistory: Codable, Identifiable, Hashable {
        var id: String
        var user: AdminFinancePerson?
        var completedBy: AdminFinancePerson?
        var amount: Int
        var paybackRate: Double
        var bankName: String
        var accountNumberLast4: String
        var status: String
        var completedAt: String?
        var emailStatus: String
        var operatorNote: String
    }

    struct AdminPaybackDashboard: Codable, Hashable {
        var periodKey: String
        var eligible: AdminPaybackEligible
        var monthly: AdminPaybackMonthly
        var rows: [AdminPaybackRow]
        var history: [AdminPaybackHistory]
        var pagination: AdminFinancePagination
    }

    private struct AdminFinanceEnvelope: Codable {
        var schemaVersion: String
        var finance: AdminFinanceDashboard
    }

    private struct AdminRefundEnvelope: Codable {
        var schemaVersion: String
        var refunds: AdminRefundPage
    }

    private struct AdminPaybackEnvelope: Codable {
        var schemaVersion: String
        var paybacks: AdminPaybackDashboard
    }

    private struct AdminFinanceMutationEnvelope: Codable {
        var schemaVersion: String
        var ok: Bool
        var emailDelivered: Bool?
        var finance: AdminFinanceDashboard?
        var refunds: AdminRefundPage?
    }

    static func adminFinance() async throws -> AdminFinanceDashboard {
        let value: AdminFinanceEnvelope = try await request(
            "GET", "/api/v1/admin/finance", body: nil, authed: true)
        try validateAdminFinanceSchema(value.schemaVersion)
        return value.finance
    }

    static func recordAdminWithdrawal(amount: Int, operatorNote: String) async throws -> AdminFinanceDashboard {
        let value: AdminFinanceMutationEnvelope = try await request(
            "POST", "/api/v1/admin/finance/withdrawals",
            body: ["amount": amount, "operatorNote": operatorNote], authed: true)
        try validateAdminFinanceMutation(value)
        guard let finance = value.finance else { throw financeResponseError() }
        return finance
    }

    static func updateAdminOtherUnpaidCosts(amount: Int, operatorNote: String) async throws -> AdminFinanceDashboard {
        let value: AdminFinanceMutationEnvelope = try await request(
            "POST", "/api/v1/admin/finance/other-unpaid-costs",
            body: ["amount": amount, "operatorNote": operatorNote], authed: true)
        try validateAdminFinanceMutation(value)
        guard let finance = value.finance else { throw financeResponseError() }
        return finance
    }

    static func adminRefunds(status: String = "", page: Int = 1) async throws -> AdminRefundPage {
        let value: AdminRefundEnvelope = try await request(
            "GET", "/api/v1/admin/refunds", body: nil, authed: true,
            query: ["status": status, "page": String(max(1, page))])
        try validateAdminFinanceSchema(value.schemaVersion)
        return value.refunds
    }

    static func calculateAdminRefund(id: String, paidFeatureUsed: Bool) async throws -> AdminRefundPage {
        try await refundMutation(
            path: "/api/v1/admin/refunds/\(id)/calculate",
            body: ["paidFeatureUsed": paidFeatureUsed])
    }

    static func completeAdminRefund(
        id: String, approvedAmount: Int, cancellationMode: String,
        transactionKey: String, cancelledAt: String, operatorNote: String
    ) async throws -> AdminRefundPage {
        try await refundMutation(
            path: "/api/v1/admin/refunds/\(id)/complete",
            body: [
                "approvedAmount": approvedAmount,
                "cancellationMode": cancellationMode,
                "providerCancellationTransactionKey": transactionKey,
                "providerCancelledAt": cancelledAt,
                "operatorNote": operatorNote,
            ])
    }

    static func rejectAdminRefund(id: String, operatorNote: String) async throws -> AdminRefundPage {
        try await refundMutation(
            path: "/api/v1/admin/refunds/\(id)/reject",
            body: ["operatorNote": operatorNote])
    }

    static func adminPaybacks(periodKey: String = "", page: Int = 1) async throws -> AdminPaybackDashboard {
        let value: AdminPaybackEnvelope = try await request(
            "GET", "/api/v1/admin/paybacks", body: nil, authed: true,
            query: ["periodKey": periodKey, "page": String(max(1, page))])
        try validateAdminFinanceSchema(value.schemaVersion)
        return value.paybacks
    }

    @discardableResult
    static func completeAdminPayback(cycleID: String, operatorNote: String) async throws -> Bool {
        let value: AdminFinanceMutationEnvelope = try await request(
            "POST", "/api/v1/admin/paybacks/\(cycleID)/complete",
            body: ["operatorNote": operatorNote], authed: true)
        try validateAdminFinanceMutation(value)
        return value.emailDelivered ?? false
    }

    @discardableResult
    static func resendAdminPaybackEmail(recordID: String) async throws -> Bool {
        let value: AdminFinanceMutationEnvelope = try await request(
            "POST", "/api/v1/admin/paybacks/history/\(recordID)/resend-email",
            body: [:], authed: true)
        try validateAdminFinanceMutation(value)
        return value.emailDelivered ?? false
    }

    private static func refundMutation(path: String, body: [String: Any]) async throws -> AdminRefundPage {
        let value: AdminFinanceMutationEnvelope = try await request(
            "POST", path, body: body, authed: true)
        try validateAdminFinanceMutation(value)
        guard let refunds = value.refunds else { throw financeResponseError() }
        return refunds
    }

    private static func validateAdminFinanceMutation(_ value: AdminFinanceMutationEnvelope) throws {
        try validateAdminFinanceSchema(value.schemaVersion)
        guard value.ok else { throw financeResponseError() }
    }

    private static func validateAdminFinanceSchema(_ value: String) throws {
        guard value == "ADMIN_FINANCE_NATIVE_V1" else { throw financeResponseError() }
    }

    private static func financeResponseError() -> ServerAPIError {
        ServerAPIError(message: "관리자 재무 응답이 앱과 맞지 않습니다.", code: "ADMIN_FINANCE_SCHEMA_UNSUPPORTED")
    }
}
