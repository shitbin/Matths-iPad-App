import Foundation
import PencilKit
import UIKit

@MainActor enum DataScope {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("arena-pencil-runtime-\(UUID())")
    static let slot = "synthetic"
    static func directory(for slot: String) -> URL {
        let url = root.appendingPathComponent(slot)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func url(_ name: String, for slot: String) -> URL { directory(for: slot).appendingPathComponent(name) }
}

@MainActor final class BoardInstallHarness {
    struct Attempt { let status = "IN_PROGRESS" }
    struct Question { let slot = 1 }
    let matchId = "synthetic-match"
    let accountSlot = DataScope.slot
    var accountIsCurrent = true
    var attempt: Attempt? = .init()
    var currentQuestion: Question? = .init()
    var solutionBoardSaveTask: Task<Void, Never>?
    var isInstallingSolutionDrawing = false
    var installedDrawing: PKDrawing?
    var solutionDrawing = PKDrawing()
    var solutionBoardRevisions: [Int: Int] = [:]
    var solutionUndoStack: [PKDrawing] = []
    var solutionRedoStack: [PKDrawing] = []
    var solutionZoom: CGFloat = 1
    var boardRecoverySlots = Set<Int>()
    var solutionBoardSaveError: String?
    var currentBoardNeedsRecovery: Bool { boardRecoverySlots.contains(1) }
    func saveCurrentSolutionBoard(force: Bool) async -> Bool { true } // No server request in this isolated test.
}

@main enum ArenaPencilDrawingSimulatorCases {
    @MainActor static func main() async throws {
        #if !targetEnvironment(simulator)
        throw CocoaError(.featureUnsupported)
        #else
        defer { try? FileManager.default.removeItem(at: DataScope.root) }
        ArenaDraftPersistence.activate(slot: DataScope.slot)
        let points = [CGPoint(x: 12, y: 18), CGPoint(x: 88, y: 96), CGPoint(x: 140, y: 25)].enumerated().map { index, point in
            PKStrokePoint(location: point, timeOffset: Double(index) * 0.01, size: CGSize(width: 4, height: 4),
                          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0))
        let stroke = PKStroke(ink: PKInk(.pen, color: .systemBlue), path: path)
        let drawing = PKDrawing(strokes: [stroke])
        let valid = GoatArenaSolutionBoardDraft(revision: 3, drawingData: drawing.dataRepresentation())
        let harness = BoardInstallHarness()
        let url = try GoatArenaSolutionBoardDraftStore.url(matchId: harness.matchId, slot: 1, accountSlot: DataScope.slot)
        try GoatArenaSolutionBoardDraftStore.save(valid, matchId: harness.matchId, slot: 1, accountSlot: DataScope.slot)
        let saved = await ArenaDraftPersistence.flush(slot: DataScope.slot)
        precondition(saved)
        harness.exerciseInstall()
        precondition(harness.solutionDrawing.strokes.count == 1 && harness.solutionBoardRevisions[1] == 3)
        harness.exerciseChange(harness.solutionDrawing)
        precondition(harness.solutionBoardRevisions[1] == 3, "Programmatic load was written back as a user stroke")

        // Valid JSON/checksum, invalid actual PencilKit payload: the production
        // install function must preserve it and the visible drawing, not use empty.
        let corrupt = GoatArenaSolutionBoardDraft(revision: 9, drawingData: Data("not-a-PKDrawing".utf8))
        let original = try JSONEncoder().encode(corrupt)
        try original.write(to: url, options: .atomic)
        let visibleBefore = harness.solutionDrawing
        harness.exerciseInstall()
        precondition(harness.currentBoardNeedsRecovery && harness.solutionBoardSaveError != nil)
        precondition(harness.solutionDrawing == visibleBefore, "Corrupt decode replaced the visible original with a blank board")
        harness.exerciseChange(PKDrawing())
        let preserved = try Data(contentsOf: url)
        precondition(preserved == original, "Automatic change callback overwrote corrupt source")

        let recovered = await GoatArenaSolutionBoardDraftStore.recover(valid, matchId: harness.matchId, slot: 1, accountSlot: DataScope.slot)
        precondition(recovered)
        harness.exerciseInstall()
        precondition(!harness.currentBoardNeedsRecovery && harness.solutionDrawing.strokes.count == 1)
        let folder = url.deletingLastPathComponent().appendingPathComponent("arena-draft-preserved-originals")
        let backups = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let bytes = try backups.map { try Data(contentsOf: $0) }
        precondition(bytes.contains(original), "PencilKit recovery did not retain raw original JSON")
        harness.exerciseChange(harness.solutionDrawing)

        let next = PKDrawing(strokes: [stroke, stroke])
        harness.solutionDrawing = next
        harness.exerciseChange(next)
        let flushed = await ArenaDraftPersistence.flush(slot: DataScope.slot)
        precondition(flushed)
        harness.solutionBoardSaveTask?.cancel()
        let latest = try GoatArenaSolutionBoardDraftStore.load(matchId: harness.matchId, slot: 1, accountSlot: DataScope.slot)!
        let roundTrip = try PKDrawing(data: latest.drawingData)
        precondition(latest.revision == 4 && roundTrip.strokes.count == 2)
        print("MATTHS_ARENA_PENCIL_STORAGE_QA_V1 PASS: iOS Simulator \(UIDevice.current.systemVersion); actual production install/change bodies, PKDrawing roundtrip, corrupt decode preservation, no blank auto-save, raw backup and explicit recovery. Synthetic strokes, not physical Pencil/touch input.")
        #endif
    }
}
