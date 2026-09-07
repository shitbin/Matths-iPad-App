import Foundation

private actor UploadStartProbe {
    private var value: URL?
    private var waiter: CheckedContinuation<URL, Never>?
    func started(_ url: URL) { value = url; waiter?.resume(returning: url); waiter = nil }
    func wait() async -> URL {
        if let value { return value }
        return await withCheckedContinuation { waiter = $0 }
    }
}

@main
enum CommunityMultipartBodyCases {
    static var checks = 0
    static func check(_ value: Bool, _ message: String) {
        precondition(value, message); checks += 1
    }
    static func main() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("multipart-tests-" + UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: root) }
        let source = root.appendingPathComponent("source.pdf")
        let sourceBytes = Data("alpha\r\nomega".utf8)
        try sourceBytes.write(to: source)
        let attachment = CommunityMultipartBody.Attachment(url: source, filename: "공부\"노트\r\n.pdf", mimeType: "application/pdf", maximumBytes: 25 * 1024 * 1024)
        let fields: [CommunityMultipartBody.Field] = [
            .init(name: "board", value: "high-school"), .init(name: "title", value: "질문 제목"),
            .init(name: "content", value: "첫 줄\n둘째 줄"), .init(name: "isAnonymous", value: "true")
        ]
        var staged: URL?
        let result = try await CommunityMultipartBody.withPreparedBody(boundary: "test-boundary", fields: fields, attachments: [attachment], temporaryRoot: root) { body in
            staged = body.fileURL
            check(manager.fileExists(atPath: body.fileURL.path), "staging file exists before transport")
            let raw = try Data(contentsOf: body.fileURL)
            let text = String(decoding: raw, as: UTF8.self)
            check(body.contentLength == UInt64(raw.count), "content length matches complete on-disk payload")
            for field in fields {
                check(text.contains("name=\"\(field.name)\"\r\n\r\n\(field.value)\r\n"), "server field names and UTF8 values preserved")
            }
            check(text.contains("name=\"communityFiles\"; filename=\"공부_노트__.pdf\""), "same multipart file field and sanitized original name")
            check(text.contains("Content-Type: application/pdf\r\n\r\nalpha\r\nomega\r\n"), "MIME and exact source bytes preserved")
            check(text.hasSuffix("--test-boundary--\r\n"), "terminal delimiter completed before transport")
            let mode = try manager.attributesOfItem(atPath: body.fileURL.path)[.posixPermissions] as? NSNumber
            check(mode?.intValue == 0o600, "temporary payload is owner-only")
            let directoryMode = try manager.attributesOfItem(atPath: body.fileURL.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber
            check(directoryMode?.intValue == 0o700, "temporary directory is owner-only")
            return "server receipt"
        }
        check(result == "server receipt", "transport result forwarded unchanged")
        check(!manager.fileExists(atPath: staged!.path), "success removes temporary payload")
        check(try Data(contentsOf: source) == sourceBytes, "success keeps original attachment unchanged")

        enum TransportFailure: Error { case lostResponse }
        var failedURL: URL?
        do {
            let _: Void = try await CommunityMultipartBody.withPreparedBody(boundary: "test-failure", fields: fields, attachments: [attachment], temporaryRoot: root) { body in
                failedURL = body.fileURL
                throw TransportFailure.lostResponse
            }
            preconditionFailure("transport error swallowed")
        } catch TransportFailure.lostResponse { checks += 1 }
        check(!manager.fileExists(atPath: failedURL!.path), "lost response removes temporary payload")
        check(try Data(contentsOf: source) == sourceBytes, "lost response keeps draft attachment")

        var networkCalls = 0, writes = 0
        do {
            let _: Void = try await CommunityMultipartBody.withPreparedBody(boundary: "test-full-disk", fields: fields, attachments: [attachment], temporaryRoot: root, writeData: { file, bytes in
                writes += 1
                if writes == 3 { throw CocoaError(.fileWriteOutOfSpace) }
                try file.write(contentsOf: bytes)
            }) { _ in networkCalls += 1 }
            preconditionFailure("write failure ignored")
        } catch { check((error as? CocoaError)?.code == .fileWriteOutOfSpace, "file write failure surfaces before upload") }
        check(networkCalls == 0, "write failure never invokes transport")
        check(try stagingDirectories(root).isEmpty, "write failure cleans partial staging directory")
        check(try Data(contentsOf: source) == sourceBytes, "write failure preserves original")

        for invalid in ["", "bad\r\nboundary", String(repeating: "a", count: 71)] {
            do {
                let _: Void = try await CommunityMultipartBody.withPreparedBody(boundary: invalid, fields: fields, attachments: [attachment], temporaryRoot: root) { _ in networkCalls += 1 }
                preconditionFailure("invalid boundary accepted")
            } catch { checks += 1 }
        }
        let tooSmall = CommunityMultipartBody.Attachment(url: source, filename: "source.pdf", mimeType: "application/pdf", maximumBytes: sourceBytes.count - 1)
        do {
            let _: Void = try await CommunityMultipartBody.withPreparedBody(boundary: "small-limit", fields: fields, attachments: [tooSmall], temporaryRoot: root) { _ in networkCalls += 1 }
            preconditionFailure("oversize source accepted")
        } catch { checks += 1 }
        check(networkCalls == 0, "invalid metadata never invokes transport")
        check(try stagingDirectories(root).isEmpty, "invalid input leaves no multipart artifacts")

        let largeA = root.appendingPathComponent("large-a.pdf"), largeB = root.appendingPathComponent("large-b.pdf")
        try makeFile(largeA, bytes: 24 * 1024 * 1024)
        try makeFile(largeB, bytes: 24 * 1024 * 1024)
        let large = [largeA, largeB].map { CommunityMultipartBody.Attachment(url: $0, filename: $0.lastPathComponent, mimeType: "application/pdf", maximumBytes: 25 * 1024 * 1024) }
        var maximumChunk = 0, readBytes = 0
        let largeLength = try await CommunityMultipartBody.withPreparedBody(boundary: "large-body", fields: fields, attachments: large, temporaryRoot: root, didReadChunk: {
            maximumChunk = max(maximumChunk, $0); readBytes += $0
        }) { body in body.contentLength }
        check(maximumChunk == CommunityMultipartBody.chunkSize, "large sources use at most 256KB chunks")
        check(readBytes == 48 * 1024 * 1024, "48MB source files fully streamed")
        check(largeLength > UInt64(readBytes), "headers added without an aggregate Data payload")
        check(try stagingDirectories(root).isEmpty, "large upload completion cleans staging")

        var ownerChecks = 0
        do {
            let _: Void = try await CommunityMultipartBody.withPreparedBody(boundary: "owner-changed", fields: fields, attachments: large, temporaryRoot: root, validateOwner: {
                ownerChecks += 1
                if ownerChecks >= 9 { throw CancellationError() }
            }) { _ in networkCalls += 1 }
            preconditionFailure("owner change accepted")
        } catch is CancellationError { checks += 1 }
        check(networkCalls == 0, "owner change during copy never invokes transport")
        check(try stagingDirectories(root).isEmpty, "owner change removes partial body")

        let probe = UploadStartProbe()
        let upload = Task {
            try await CommunityMultipartBody.withPreparedBody(boundary: "cancel-upload", fields: fields, attachments: [attachment], temporaryRoot: root) { body in
                await probe.started(body.fileURL)
                try await Task.sleep(nanoseconds: 30_000_000_000)
                return true
            }
        }
        let cancellationURL = await probe.wait()
        upload.cancel()
        do { _ = try await upload.value; preconditionFailure("cancellation swallowed") }
        catch is CancellationError { checks += 1 }
        check(!manager.fileExists(atPath: cancellationURL.path), "in-flight transport cancellation cleans body")
        check(try Data(contentsOf: source) == sourceBytes, "cancellation preserves original attachment")
        check(try stagingDirectories(root).isEmpty, "all success/failure/cancellation paths leave no staging directory")
        print("Community file-backed multipart: \(checks) checks passed; 48MB streamed in \(maximumChunk)-byte maximum chunks")
    }
    private static func stagingDirectories(_ root: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("MatthsCommunityMultipart-") }
    }
    private static func makeFile(_ url: URL, bytes: Int) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let output = try FileHandle(forWritingTo: url)
        defer { try? output.close() }
        let chunk = Data(repeating: 0x61, count: 128 * 1024)
        for _ in 0..<(bytes / chunk.count) { try output.write(contentsOf: chunk) }
    }
}
