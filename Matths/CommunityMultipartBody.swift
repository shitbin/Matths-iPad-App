import Foundation

/// File-backed multipart staging for community uploads. The source attachments
/// are read-only; only the private staging directory is owned by this helper.
enum CommunityMultipartBody {
    static let chunkSize = 256 * 1024
    static let maximumTotalFileBytes = 50 * 1024 * 1024
    struct Field: Sendable { let name: String; let value: String }
    struct Attachment: Sendable {
        let url: URL
        let filename: String
        let mimeType: String
        let maximumBytes: Int
    }
    struct Prepared: Sendable {
        let fileURL: URL
        let contentLength: UInt64
        fileprivate let directory: URL
    }
    enum PreparationError: Error {
        case invalidBoundary, invalidField, invalidAttachment, sizeLimit, changedAttachment, cannotCreateFile
    }

    /// The operation cannot begin until staging has synchronized and closed the
    /// file. Its success, failure, or cancellation always crosses the same defer.
    static func withPreparedBody<T>(
        boundary: String,
        fields: [Field],
        attachments: [Attachment],
        temporaryRoot: URL = FileManager.default.temporaryDirectory,
        validateOwner: () throws -> Void = {},
        didReadChunk: ((Int) -> Void)? = nil,
        writeData: ((FileHandle, Data) throws -> Void)? = nil,
        operation: (Prepared) async throws -> T
    ) async throws -> T {
        let body = try prepare(boundary: boundary, fields: fields, attachments: attachments,
                               temporaryRoot: temporaryRoot, validateOwner: validateOwner, didReadChunk: didReadChunk, writeData: writeData)
        defer { try? FileManager.default.removeItem(at: body.directory) }
        try Task.checkCancellation()
        try validateOwner()
        return try await operation(body)
    }

    private static func prepare(
        boundary: String, fields: [Field], attachments: [Attachment], temporaryRoot: URL,
        validateOwner: () throws -> Void, didReadChunk: ((Int) -> Void)?, writeData: ((FileHandle, Data) throws -> Void)?
    ) throws -> Prepared {
        try Task.checkCancellation(); try validateOwner()
        let tokenCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        guard !boundary.isEmpty, boundary.utf8.count <= 70,
              boundary.unicodeScalars.allSatisfy(tokenCharacters.contains) else { throw PreparationError.invalidBoundary }
        guard fields.count <= 16, fields.allSatisfy({ !$0.name.isEmpty && $0.name.unicodeScalars.allSatisfy(tokenCharacters.contains) && $0.value.utf8.count <= 64 * 1024 }) else {
            throw PreparationError.invalidField
        }
        guard attachments.count <= 5 else { throw PreparationError.invalidAttachment }

        let manager = FileManager.default
        let directory = temporaryRoot.appendingPathComponent("MatthsCommunityMultipart-" + UUID().uuidString, isDirectory: true)
        var directoryAttributes: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        var fileAttributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        #if os(iOS)
        directoryAttributes[.protectionKey] = FileProtectionType.completeUntilFirstUserAuthentication
        fileAttributes[.protectionKey] = FileProtectionType.completeUntilFirstUserAuthentication
        #endif
        try manager.createDirectory(at: directory, withIntermediateDirectories: false, attributes: directoryAttributes)
        var prepared = false
        defer { if !prepared { try? manager.removeItem(at: directory) } }
        let fileURL = directory.appendingPathComponent("body.multipart")
        guard manager.createFile(atPath: fileURL.path, contents: nil, attributes: fileAttributes) else { throw PreparationError.cannotCreateFile }
        let output = try FileHandle(forWritingTo: fileURL)
        defer { try? output.close() }

        func writeBytes(_ data: Data) throws {
            if let writeData { try writeData(output, data) }
            else { try output.write(contentsOf: data) }
        }
        func write(_ text: String) throws { try writeBytes(Data(text.utf8)) }
        for field in fields {
            try Task.checkCancellation(); try validateOwner()
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            try write(field.value + "\r\n")
        }

        var totalFileBytes = 0
        for attachment in attachments {
            try Task.checkCancellation(); try validateOwner()
            guard attachment.maximumBytes > 0, attachment.maximumBytes <= 25 * 1024 * 1024,
                  !attachment.filename.isEmpty, attachment.filename.utf8.count <= 1024,
                  !attachment.mimeType.isEmpty, !attachment.mimeType.contains("\r"), !attachment.mimeType.contains("\n") else {
                throw PreparationError.invalidAttachment
            }
            let metadata = try attachment.url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
            guard metadata.isRegularFile == true, let expectedBytes = metadata.fileSize, expectedBytes >= 0,
                  expectedBytes <= attachment.maximumBytes,
                  totalFileBytes + expectedBytes <= maximumTotalFileBytes else { throw PreparationError.sizeLimit }
            let filename = attachment.filename.replacingOccurrences(of: "\"", with: "_")
                .replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_")
            try write("--\(boundary)\r\n")
            try write("Content-Disposition: form-data; name=\"communityFiles\"; filename=\"\(filename)\"\r\n")
            try write("Content-Type: \(attachment.mimeType)\r\n\r\n")
            let input = try FileHandle(forReadingFrom: attachment.url)
            defer { try? input.close() }
            var copiedBytes = 0
            while true {
                try Task.checkCancellation(); try validateOwner()
                guard let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty else { break }
                copiedBytes += chunk.count; totalFileBytes += chunk.count
                guard copiedBytes <= attachment.maximumBytes, totalFileBytes <= maximumTotalFileBytes else { throw PreparationError.sizeLimit }
                didReadChunk?(chunk.count)
                try writeBytes(chunk)
            }
            try input.close()
            let after = try attachment.url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            guard copiedBytes == expectedBytes, after.fileSize == expectedBytes,
                  after.contentModificationDate == metadata.contentModificationDate else { throw PreparationError.changedAttachment }
            try write("\r\n")
        }
        try Task.checkCancellation(); try validateOwner()
        try write("--\(boundary)--\r\n")
        try output.synchronize()
        let length = try output.offset()
        try output.close()
        prepared = true
        return Prepared(fileURL: fileURL, contentLength: length, directory: directory)
    }
}
