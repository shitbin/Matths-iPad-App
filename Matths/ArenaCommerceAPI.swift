import Foundation

extension ServerAPI {
    struct ArenaShopResponse: Codable { var shop: ArenaShop }

    struct ArenaShop: Codable {
        struct Wallet: Codable {
            var availableLearningDays: Int
            var minimumBalanceAfterPurchase: Int
        }

        struct Policy: Codable {
            var versionCode: String
            var displayName: String
            var effectiveFrom: String?
            var sundayLocked: Bool
            var sundayLockMessage: String
            var demotionMessage: String
            var nonRefundableMessage: String
        }

        struct Item: Codable, Identifiable {
            struct Preview: Codable {
                var beforeAvailableDays: Int
                var afterAvailableDays: Int
                var purchaseEligible: Bool
                var expectedEffectEndsAt: String?
                var daysUntilAvailableBalanceExhaustion: Int
                var demotionRisk: String
            }

            var itemCode: String
            var displayName: String
            var priceDays: Int
            var releasePhase: Int
            var eyebrow: String
            var description: String
            var targetType: String
            var durationLabel: String
            var refundCondition: String
            var purchasePreview: Preview
            var id: String { itemCode }
        }

        struct Effect: Codable, Identifiable {
            var id: String
            var itemCode: String
            var status: String
            var startsAt: String?
            var endsAt: String?
            var appliedAt: String?
            var analysisState: String
            var relatedMatchId: String?
            var relatedInvitationId: String?
        }

        struct Purchase: Codable, Identifiable {
            var id: String
            var itemCode: String
            var displayName: String
            var policyVersionCode: String
            var priceDays: Int
            var beforeAvailableDays: Int
            var afterAvailableDays: Int
            var status: String
            var purchasedAt: String?
            var reversedAt: String?
            var reversalReason: String
            var relatedMatchId: String?
            var relatedInvitationId: String?
        }

        struct Invitation: Codable, Identifiable {
            var id: String
            var targetTier: String
            var stakeDays: Int
            var status: String
            var createdAt: String?
            var acceleratedAt: String?
            var accelerationEndsAt: String?
        }

        struct MatchTarget: Codable, Identifiable {
            var id: String
            var divisionLabel: String
            var matchTypeLabel: String
            var occurredAt: String?
        }

        var generatedAt: String
        var wallet: Wallet
        var policy: Policy
        var items: [Item]
        var effects: [Effect]
        var purchases: [Purchase]
        // 이전 서버 응답에는 이 필드가 없으므로 optional로 디코딩한다.
        // 새 서버에서는 학생에게 내부 경기 ID를 입력시키지 않고 선택지를 제공한다.
        var analysisTargets: [MatchTarget]? = nil
        var defenseProtectionTargets: [MatchTarget]? = nil
        var invitations: [Invitation]
    }

    struct ArenaShopPurchaseResponse: Codable {
        struct Receipt: Codable {
            var replayed: Bool
            var purchase: ArenaShop.Purchase
            var effect: ArenaShop.Effect?
            var matchId: String?
            var beforeAvailableDays: Int
            var afterAvailableDays: Int
            var expectedEffectEndsAt: String?
            var demotionRisk: String
        }

        var receipt: Receipt
        var shop: ArenaShop
    }

    struct ArenaShopAnalysisResponse: Codable { var analysis: ArenaShopAnalysis }

    struct ArenaShopAnalysis: Codable, Identifiable {
        struct SolutionStep: Codable, Identifiable {
            var step: Int
            var explanation: String
            var id: Int { step }
        }

        struct QuestionReview: Codable, Identifiable {
            var number: Int
            var questionKey: String
            var courseId: String
            var typeId: String
            var skillTags: [String]
            var prompt: String
            var submittedAnswer: String
            var correctAnswer: String
            var correct: Bool
            var pointsAwarded: Double
            var responseTimeMs: Int?
            var solution: String
            var referenceSolutionProcess: [SolutionStep]
            var referenceFinalCheck: String
            var id: String { questionKey }
        }

        var id: String
        var status: String
        var analysisState: String
        var relatedMatchId: String?
        var result: String?
        var score: Double?
        var correctCount: Int?
        var totalSolveTimeMs: Int?
        var incorrectQuestionKeys: [String]
        var weakSkills: [String]
        var reviewProblemCount: Int
        var checklist: [String]
        var questionReviews: [QuestionReview]
        var generatedAt: String?
        var purchasedAt: String?
    }

    static func getArenaShop() async throws -> ArenaShop {
        let response: ArenaShopResponse = try await request(
            "GET", "/api/v1/goat-arena/main/shop", body: nil, authed: true)
        return response.shop
    }

    static func purchaseArenaShopItem(
        itemCode: String,
        relatedMatchId: String? = nil,
        relatedInvitationId: String? = nil,
        operationID: String = "shop:\(UUID().uuidString)"
    ) async throws -> ArenaShopPurchaseResponse {
        var body: [String: Any] = [
            "itemCode": itemCode,
            "purchaseConfirmed": true,
        ]
        if let relatedMatchId, !relatedMatchId.isEmpty {
            body["relatedMatchId"] = relatedMatchId
        }
        if let relatedInvitationId, !relatedInvitationId.isEmpty {
            body["relatedInvitationId"] = relatedInvitationId
        }
        return try await request(
            "POST", "/api/v1/goat-arena/main/shop/purchases",
            body: body, authed: true,
            headers: ["Idempotency-Key": operationID])
    }

    static func getArenaShopAnalysis(effectId: String) async throws -> ArenaShopAnalysis {
        let response: ArenaShopAnalysisResponse = try await request(
            "GET", "/api/v1/goat-arena/main/shop/analyses/\(effectId)",
            body: nil, authed: true)
        return response.analysis
    }

}
