import Foundation
#if os(macOS)
import Darwin
#endif

/// Atomic private storage on both the app's iOS runtime and macOS host tests.
/// Complete Data Protection is retained on iOS. macOS can reject protection
/// class A with EPERM even in a writable directory; its native counterpart is
/// an owner-only staging file atomically renamed over the destination.
enum ProtectedFileWriter {
    static func write(_ data: Data, to destination: URL) throws {
        #if os(macOS)
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".matths-private-\(UUID().uuidString).tmp")
        let descriptor = Darwin.open(staging.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw posixError(path: staging.path) }
        let output = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var closed = false
        defer {
            if !closed { try? output.close() }
            try? FileManager.default.removeItem(at: staging)
        }
        guard Darwin.fchmod(descriptor, mode_t(0o600)) == 0 else { throw posixError(path: staging.path) }
        try output.write(contentsOf: data)
        try output.synchronize()
        try output.close()
        closed = true
        guard Darwin.rename(staging.path, destination.path) == 0 else { throw posixError(path: destination.path) }
        #else
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        #endif
    }

    #if os(macOS)
    private static func posixError(path: String) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: path])
    }
    #endif
}
