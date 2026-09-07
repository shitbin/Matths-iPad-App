import Foundation

enum FirstLearningJourneyPersistence {
    static func load(from url: URL, slot: String) throws -> FirstLearningJourney {
        let metadata = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard metadata.isRegularFile == true, let bytes = metadata.fileSize, bytes <= 65_536 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let value = try JSONDecoder().decode(FirstLearningJourney.self, from: Data(contentsOf: url))
        guard value.slot == slot, value.isValid else { throw CocoaError(.fileReadCorruptFile) }
        return value
    }
    static func save(_ value: FirstLearningJourney, to url: URL) throws {
        guard value.isValid else { throw CocoaError(.coderInvalidValue) }
        let data = try JSONEncoder().encode(value)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: [.atomic])
        #endif
    }
}
