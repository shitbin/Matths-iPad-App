import Foundation

@main enum ProtectedFileWriterCases {
    static func main() async throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("matths-private-write-tests-\(UUID())", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("record.json")
        let original = Data(repeating: 65, count: 8_192)
        try ProtectedFileWriter.write(original, to: destination)
        let first = try Data(contentsOf: destination)
        precondition(first == original)
        try assertPrivate(destination)

        // Replacing an older permissive file must not inherit its 0644 mode.
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destination.path)
        let replacement = Data(repeating: 66, count: 16_384)
        try ProtectedFileWriter.write(replacement, to: destination)
        let replaced = try Data(contentsOf: destination)
        precondition(replaced == replacement)
        try assertPrivate(destination)

        let payloads = (0..<20).map { Data(repeating: UInt8($0), count: 64 * 1_024) }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for payload in payloads { group.addTask { try ProtectedFileWriter.write(payload, to: destination) } }
            try await group.waitForAll()
        }
        let concurrent = try Data(contentsOf: destination)
        precondition(payloads.contains(concurrent), "Concurrent replacement produced partial/interleaved data")
        try assertPrivate(destination)

        // Atomic replacement replaces the symlink itself, not its external target.
        let untouched = directory.appendingPathComponent("untouched.json")
        try original.write(to: untouched)
        let link = directory.appendingPathComponent("link.json")
        try fm.createSymbolicLink(at: link, withDestinationURL: untouched)
        try ProtectedFileWriter.write(replacement, to: link)
        let externalBytes = try Data(contentsOf: untouched)
        let linkBytes = try Data(contentsOf: link)
        precondition(externalBytes == original && linkBytes == replacement)
        try assertPrivate(link)

        let blocked = directory.appendingPathComponent("existing-directory", isDirectory: true)
        try fm.createDirectory(at: blocked, withIntermediateDirectories: false)
        let sentinel = blocked.appendingPathComponent("must-remain")
        try original.write(to: sentinel)
        var failed = false
        do { try ProtectedFileWriter.write(replacement, to: blocked) }
        catch { failed = true }
        precondition(failed, "An invalid replacement target was silently accepted")
        let preserved = try Data(contentsOf: sentinel)
        precondition(preserved == original)
        let entries = try fm.contentsOfDirectory(atPath: directory.path)
        precondition(!entries.contains(where: { $0.hasPrefix(".matths-private-") }), "A failed write leaked private staging bytes")
        print("Protected writer: atomic roundtrip/replacement, owner-only 0600, 20 concurrent writes, symlink confinement, failure preservation and staging cleanup: PASS")
    }

    private static func assertPrivate(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        precondition(attributes[.type] as? FileAttributeType == .typeRegular)
        let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue
        precondition(mode == 0o600, "Host private file must be 0600, got \(String(describing: mode))")
    }
}
