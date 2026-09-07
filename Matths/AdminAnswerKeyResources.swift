import Foundation
import CryptoKit

enum AdminAnswerKeyResource: String, CaseIterable, Identifiable {
    case skeleton, catalog
    var id: String { rawValue }
    var title: String { self == .skeleton ? "v3 답지 스켈레톤 JSON" : "AI 개념 카탈로그 MD" }
    var filename: String { self == .skeleton ? "matths-answer-key-skeleton.json" : "matths-ai-concept-catalog.md" }
    var mime: String { self == .skeleton ? "application/json" : "text/markdown" }
    static let maximumBytes = 2 * 1024 * 1024

    func validate(_ data: Data, mime: String?, checksum: String?) throws {
        guard !data.isEmpty, data.count <= Self.maximumBytes, mime?.lowercased() == self.mime,
              let checksum, checksum.lowercased() == SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() else {
            throw ServerAPIError(message: "서버 원본 자료의 형식 또는 무결성을 확인하지 못했습니다. 다시 내려받아 주세요.")
        }
        if self == .skeleton {
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  value["schemaVersion"] as? String == "matths-answer-key-v3",
                  (value["questions"] as? [[String: Any]])?.count == 30 else {
                throw ServerAPIError(message: "최신 v3 답지 스켈레톤이 아닙니다. 서버 원본을 확인해 주세요.")
            }
        } else {
            guard let text = String(data: data, encoding: .utf8), text.contains("# AI 주간 모의고사 개념 카탈로그") else {
                throw ServerAPIError(message: "개념 카탈로그 원본을 확인할 수 없습니다.")
            }
        }
    }
}

private final class AnswerKeyResourceRedirectBlocker: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Fixed authenticated API endpoints never redirect to an external file host.
        completionHandler(nil)
    }
}

extension ServerAPI {
    static func adminAnswerKeyResource(_ resource: AdminAnswerKeyResource, authorization: AuthorizationSnapshot) async throws -> Data {
        let request = try authorizedRequest("GET", "/api/v1/admin/answer-key-resources/\(resource.rawValue)", timeout: 45, authorization: authorization)
        let session = URLSession(configuration: .ephemeral, delegate: AnswerKeyResourceRedirectBlocker(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard response.expectedContentLength <= Int64(AdminAnswerKeyResource.maximumBytes) else {
            throw ServerAPIError(message: "답지 작성 자료가 허용 용량을 초과했습니다.")
        }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < AdminAnswerKeyResource.maximumBytes else {
                throw ServerAPIError(message: "답지 작성 자료가 허용 용량을 초과했습니다.")
            }
            data.append(byte)
        }
        try validateAuthorizedResponse(response, errorBody: data, requestToken: bearerToken(from: request))
        try resource.validate(data, mime: response.mimeType, checksum: (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Content-SHA256"))
        return data
    }
}
