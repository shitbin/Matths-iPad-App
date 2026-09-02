import Foundation

extension ServerAPI {
    struct CommerceStorefrontResponse: Codable {
        var storefront: CommerceStorefront
    }

    struct CommerceStorefront: Codable {
        struct Access: Codable {
            var packageType: String?
            var learningPackageActive: Bool
            var mockExamPackageActive: Bool
            var arenaAllowed: Bool
            var rankedShopAvailable: Bool
            var mockExamEndsAt: String?
        }

        struct Product: Codable, Identifiable {
            var code: String
            var name: String
            var amount: Int
            var periodLabel: String
            var description: String
            var features: [String]
            var current: Bool

            var id: String { code }
        }

        var generatedAt: String
        var checkoutEnabled: Bool
        var currency: String
        var access: Access
        var products: [Product]
    }

    struct CommerceHandoffResponse: Codable {
        struct Handoff: Codable {
            var url: String
            var expiresAt: String
        }

        var handoff: Handoff
    }

    static func getCommerceStorefront() async throws -> CommerceStorefront {
        let response: CommerceStorefrontResponse = try await request(
            "GET", "/api/v1/commerce/storefront", body: nil, authed: true)
        return response.storefront
    }

    /// 앱의 Bearer 로그인을 2분짜리 일회용 브라우저 세션으로 바꾼다.
    /// 앱은 웹 세션 쿠키나 결제키를 직접 보관하지 않는다.
    static func createCommerceHandoff(
        productCode: String? = nil,
        mode: String = "pricing"
    ) async throws -> CommerceHandoffResponse.Handoff {
        var body: [String: Any] = ["mode": mode]
        if let productCode, !productCode.isEmpty {
            body["productCode"] = productCode
        }
        let response: CommerceHandoffResponse = try await request(
            "POST", "/api/v1/commerce/handoffs", body: body, authed: true)
        return response.handoff
    }
}
