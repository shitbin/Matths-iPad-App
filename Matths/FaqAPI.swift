import Foundation

extension ServerAPI {
    struct FAQCategory: Codable, Identifiable, Hashable {
        var value: String
        var label: String
        var count: Int

        var id: String { value }
    }

    struct FAQItem: Codable, Identifiable, Hashable {
        var id: String
        var category: String
        var categoryLabel: String
        var ordinal: String
        var question: String
        var answer: String
        var searchText: String
    }

    struct FAQDashboard: Codable, Hashable {
        var query: String
        var category: String
        var code: String
        var totalCount: Int
        var resultCount: Int
        var categories: [FAQCategory]
        var items: [FAQItem]
    }

    private struct FAQEnvelope: Codable {
        var schemaVersion: String
        var faq: FAQDashboard
    }

    /// 로그인 실패·401 안내에서도 열려야 하므로 FAQ 읽기는 공개 API다.
    static func faq(
        query: String = "",
        category: String = "",
        code: String = ""
    ) async throws -> FAQDashboard {
        let value: FAQEnvelope = try await request(
            "GET", "/api/v1/faq", body: nil, authed: false,
            query: ["query": query, "category": category, "code": code])
        guard value.schemaVersion == "FAQ_NATIVE_V1" else {
            throw ServerAPIError(
                message: "도움말 응답 버전이 앱과 맞지 않습니다.",
                code: "FAQ_SCHEMA_UNSUPPORTED")
        }
        return value.faq
    }
}
