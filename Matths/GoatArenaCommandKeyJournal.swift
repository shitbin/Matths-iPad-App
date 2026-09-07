import Foundation

struct GoatArenaCommandKeys: Codable, Equatable, Sendable {
    let matchId: String
    let startCommandId: String
    let submissionId: String
    let clientBuildVersion: String
    private enum CodingKeys: String, CodingKey { case matchId, startCommandId, submissionId, clientBuildVersion }
    init(matchId: String, startCommandId: String, submissionId: String, clientBuildVersion: String) {
        self.matchId = matchId; self.startCommandId = startCommandId
        self.submissionId = submissionId; self.clientBuildVersion = clientBuildVersion
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        matchId = try values.decode(String.self, forKey: .matchId)
        startCommandId = try values.decode(String.self, forKey: .startCommandId)
        submissionId = try values.decode(String.self, forKey: .submissionId)
        clientBuildVersion = try values.decodeIfPresent(String.self, forKey: .clientBuildVersion) ?? ""
    }
}

/// Serial, bounded journal. Only a missing file means an empty history; unreadable
/// or corrupt history must never silently mint replacement official command IDs.
@MainActor enum GoatArenaCommandKeyStore {
    static let fileName = "goat-arena-command-keys.json"
    static func canDiscard(attemptStatus: String?, evidenceRequired: Bool?) -> Bool {
        attemptStatus == "SUBMITTED" || evidenceRequired == false
    }
    static func existing(matchId: String, directory: URL) throws -> GoatArenaCommandKeys? {
        try read(directory.appendingPathComponent(fileName)).first { $0.matchId == matchId }
    }
    static func loadOrCreate(matchId: String, directory: URL, buildVersion: String) throws -> GoatArenaCommandKeys {
        guard valid(matchId), valid(buildVersion) else { throw CocoaError(.coderInvalidValue) }
        let file = directory.appendingPathComponent(fileName)
        var values = try read(file)
        if let index = values.firstIndex(where: { $0.matchId == matchId }) {
            let existing = values[index]
            if !existing.clientBuildVersion.isEmpty { return existing }
            let upgraded = GoatArenaCommandKeys(matchId: existing.matchId, startCommandId: existing.startCommandId,
                submissionId: existing.submissionId, clientBuildVersion: buildVersion)
            values[index] = upgraded
            try write(values, file)
            return upgraded
        }
        let created = GoatArenaCommandKeys(matchId: matchId, startCommandId: UUID().uuidString,
            submissionId: UUID().uuidString, clientBuildVersion: buildVersion)
        values.append(created)
        try write(values, file)
        return created
    }
    static func clear(matchId: String, directory: URL) throws {
        let file = directory.appendingPathComponent(fileName)
        let values = try read(file)
        guard values.contains(where: { $0.matchId == matchId }) else { return }
        try write(values.filter { $0.matchId != matchId }, file)
    }
    static func backUpOriginal(directory: URL) throws {
        let file = directory.appendingPathComponent(fileName)
        try validateParent(file)
        let metadata = try FileManager.default.attributesOfItem(atPath: file.path)
        guard metadata[.type] as? FileAttributeType == .typeRegular,
              let size = metadata[.size] as? NSNumber, size.int64Value <= 4_194_304 else { throw CocoaError(.fileReadCorruptFile) }
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        let backup = directory.appendingPathComponent("goat-arena-command-keys.backup-\(UUID().uuidString).json")
        try ProtectedFileWriter.write(data, to: backup)
        guard try Data(contentsOf: backup) == data else { throw CocoaError(.fileWriteUnknown) }
        // Keep the original in place: backup is not permission to rotate keys.
    }
    private static func read(_ file: URL) throws -> [GoatArenaCommandKeys] {
        let metadata: [FileAttributeKey: Any]
        do { metadata = try FileManager.default.attributesOfItem(atPath: file.path) }
        catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { return [] }
            throw error
        }
        try validateParent(file)
        guard metadata[.type] as? FileAttributeType == .typeRegular,
              let size = metadata[.size] as? NSNumber, size.int64Value <= 4_194_304 else { throw CocoaError(.fileReadCorruptFile) }
        let values = try JSONDecoder().decode([GoatArenaCommandKeys].self, from: Data(contentsOf: file))
        guard values.count <= 10_000, Set(values.map(\.matchId)).count == values.count,
              Set(values.map(\.startCommandId)).count == values.count,
              Set(values.map(\.submissionId)).count == values.count,
              values.allSatisfy({ valid($0.matchId) && valid($0.startCommandId) && valid($0.submissionId)
                  && ($0.clientBuildVersion.isEmpty || valid($0.clientBuildVersion)) }) else { throw CocoaError(.fileReadCorruptFile) }
        return values
    }
    private static func valid(_ value: String) -> Bool { !value.isEmpty && value.utf8.count <= 256 }
    private static func write(_ values: [GoatArenaCommandKeys], _ file: URL) throws {
        guard values.count <= 10_000 else { throw CocoaError(.fileWriteOutOfSpace) }
        let data = try JSONEncoder().encode(values)
        guard data.count <= 4_194_304 else { throw CocoaError(.fileWriteOutOfSpace) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try validateParent(file)
        try ProtectedFileWriter.write(data, to: file)
    }
    private static func validateParent(_ file: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: file.deletingLastPathComponent().path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory else { throw CocoaError(.fileReadCorruptFile) }
    }
}
