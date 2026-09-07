#if DEBUG
import Foundation
import PencilKit
import UIKit

@MainActor
enum PracticeWorkspaceDraftSelfTest {
    private static var started = false
    static func runIfRequested(store: AppStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard DemoMode.isOn, let index = arguments.firstIndex(of: "-practiceWorkspaceDraftSelfTest"),
              index + 1 < arguments.count else { return }
        let phase = arguments[index + 1]
        guard !started, phase == "prepare" || phase == "verify" else { return }
        started = true
        Task { @MainActor in await run(phase: phase, store: store) }
    }

    private static func run(phase: String, store: AppStore) async {
        let fingerprint = PracticeWorkspaceDraft.questionFingerprint(
            id: "workspace-device-qa-v1", typeKey: "fixture", statement: "x²=3", choices: ["sqrt(3)", "3"])
        let model = PracticeWorkspaceDraftModel()
        await model.open(fingerprint: fingerprint, allowedChoiceKeys: ["a", "b"], store: store)
        var report: [String: Any] = [
            "schemaVersion": "MATTHS_PRACTICE_WORKSPACE_QA_V1", "phase": phase,
            "bundleID": Bundle.main.bundleIdentifier ?? "", "slot": DataScope.slot,
            "inputType": "synthetic PKStroke; no physical Pencil or touch test",
            "recordedAt": ISO8601DateFormatter().string(from: Date()),
        ]
        if phase == "prepare" {
            model.answer = "sqrt(3)"; model.pickedKey = "a"; model.zoom = 1.75
            let points = [CGPoint(x: 20, y: 30), CGPoint(x: 80, y: 90), CGPoint(x: 140, y: 35)].enumerated().map { index, point in
                PKStrokePoint(location: point, timeOffset: Double(index) * 0.1, size: CGSize(width: 3, height: 3),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            model.drawing = PKDrawing(strokes: [PKStroke(ink: PKInk(.pen, color: .systemBlue),
                path: PKStrokePath(controlPoints: points, creationDate: Date(timeIntervalSince1970: 0)))])
            let persisted = await model.flush()
            report["persisted"] = persisted
            report["status"] = persisted ? "PREPARED" : "FAIL"
        } else {
            let restored = model.isWritable && model.answer == "sqrt(3)" && model.pickedKey == "a"
                && abs(model.zoom - 1.75) < 0.0001 && model.drawing.strokes.count == 1
                && model.drawing.strokes.first?.path.count == 3
            report["restoredAnswerChoiceZoomAndPKDrawing"] = restored

            let corruptFingerprint = PracticeWorkspaceDraft.questionFingerprint(
                id: "workspace-corrupt-pk-qa", typeKey: "fixture", statement: "fixture", choices: nil)
            var protected = false
            var recovered = false
            if let target = PracticeWorkspaceDraftRepository.handle(fingerprint: corruptFingerprint, slot: DataScope.slot),
               let corrupt = try? PracticeWorkspaceDraft(fingerprint: corruptFingerprint, answer: "saved answer",
                   pickedKey: nil, drawingData: Data([0xFF, 0x00, 0x01]), zoom: 1) {
                _ = await PracticeWorkspaceDraftRepository.save(corrupt, for: target)
                let before = try? Data(contentsOf: target.url)
                let recoveryModel = PracticeWorkspaceDraftModel()
                await recoveryModel.open(fingerprint: corruptFingerprint, store: store)
                let after = try? Data(contentsOf: target.url)
                protected = !recoveryModel.isWritable && before != nil && before == after
                recovered = await recoveryModel.resetPreservingOriginal()
                recovered = recovered && recoveryModel.isWritable && recoveryModel.answer.isEmpty
                    && recoveryModel.drawing.strokes.isEmpty
            }
            report["corruptPencilKitBytesPreserved"] = protected
            report["explicitRecoveryStartsBlankAfterBackup"] = recovered
            report["status"] = restored && protected && recovered ? "PASS" : "FAIL"
        }
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? data.write(to: documents.appendingPathComponent("practice-workspace-device-qa.json"), options: .atomic)
        }
    }
}
#endif
