import Foundation
import PencilKit
import CryptoKit
import Combine

@MainActor
enum AssessmentScratchpadRepository {
    private static var revision: UInt64 = 0
    private static var keysBySlot: [String: Set<URL>] = [:]
    private static var latestData: [URL: Data] = [:]
    private static let writer = DebouncedSnapshotWriter<URL, Data>(debounceNanoseconds: 150_000_000) { url, data in
        do { try data.write(to: url, options: .atomic); return true } catch { return false }
    }
    static func url(attemptID: String, slot: String) -> URL {
        let id = SHA256.hash(data: Data(attemptID.utf8)).map { String(format: "%02x", $0) }.joined()
        let url = DataScope.url("paper-scratchpad-\(id).drawing", for: slot)
        keysBySlot[slot, default: []].insert(url)
        return url
    }
    static func schedule(_ data: Data, at url: URL) {
        latestData[url] = data
        revision &+= 1
        let captured = revision
        Task { await writer.schedule(data, for: url, revision: captured) }
    }
    static func save(_ data: Data, at url: URL) async -> Bool {
        latestData[url] = data
        revision &+= 1
        let result = await writer.writeImmediately(data, for: url, revision: revision)
        if result == .written, latestData[url] == data { latestData[url] = nil }
        return result == .written
    }
    static func invalidate(slot: String) async {
        revision &+= 1
        await writer.invalidate(keysBySlot[slot] ?? [], through: revision)
        for url in keysBySlot[slot] ?? [] { latestData[url] = nil }
        keysBySlot[slot] = nil
    }
    static func flush(slot: String) async -> Bool {
        var writes: [(key: URL, payload: Data, revision: UInt64)] = []
        for url in keysBySlot[slot] ?? [] {
            guard let data = latestData[url] else { continue }
            revision &+= 1
            writes.append((url, data, revision))
        }
        let result = await writer.writeImmediately(writes)
        for write in writes where result[write.key] == .written && latestData[write.key] == write.payload {
            latestData[write.key] = nil
        }
        return result.values.allSatisfy { $0 == .written }
    }
}

@MainActor
final class AssessmentScratchpadModel: ObservableObject {
    @Published var drawing = PKDrawing() {
        didSet {
            guard !hydrating, ownsSession(), let url else { return }
            if drawing.strokes.isEmpty && oldValue.strokes.isEmpty { return }
            let data = drawing.dataRepresentation()
            guard data != oldValue.dataRepresentation() else { return }
            undoStack.append(oldValue)
            if undoStack.count > 20 { undoStack.removeFirst() }
            AssessmentScratchpadRepository.schedule(data, at: url)
        }
    }
    @Published private(set) var error: String?
    @Published private(set) var undoStack: [PKDrawing] = []
    private var url: URL?
    private var hydrating = false
    private var ownsSession: () -> Bool = { false }
    private var loadID = UUID()

    func open(attemptID: String, store: AppStore) async {
        let generation = UUID(); loadID = generation
        guard await flush() else { return }
        let owner = store.captureAccountSessionBoundary()
        let target = AssessmentScratchpadRepository.url(attemptID: attemptID, slot: DataScope.slot)
        let loaded = await Task.detached { (FileManager.default.fileExists(atPath: target.path), try? Data(contentsOf: target)) }.value
        guard loadID == generation, store.ownsCurrentAccountSession(owner) else { return }
        hydrating = true
        defer { hydrating = false }
        ownsSession = { [weak store] in store?.ownsCurrentAccountSession(owner) == true }
        url = target
        undoStack = []
        if let raw = loaded.1 {
            do { drawing = try PKDrawing(data: raw); error = nil }
            catch { self.error = "메모를 열지 못했습니다. 원본은 이 기기에 보관되어 있습니다."; url = nil }
        } else {
            drawing = PKDrawing()
            if loaded.0 { error = "메모 원본을 읽지 못했습니다. 원본 파일은 보관되어 있습니다."; url = nil }
            else { error = nil }
        }
    }
    func undo() {
        guard ownsSession(), let previous = undoStack.popLast(), let url else { return }
        hydrating = true; drawing = previous; hydrating = false
        AssessmentScratchpadRepository.schedule(drawing.dataRepresentation(), at: url)
    }
    #if DEBUG
    func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-paperScratchpadFixture"), drawing.strokes.isEmpty else { return }
        let points = [CGPoint(x: 40, y: 60), CGPoint(x: 100, y: 120), CGPoint(x: 180, y: 70)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .systemBlue), path: path)])
    }
    #endif
    func flush() async -> Bool {
        guard ownsSession(), let url else { return true }
        let saved = await AssessmentScratchpadRepository.save(drawing.dataRepresentation(), at: url)
        if !saved { error = "풀이 메모를 저장하지 못했습니다. 저장 공간을 확인해 주세요." }
        return saved
    }
}
