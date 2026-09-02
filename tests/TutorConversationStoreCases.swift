import Foundation

@main
enum TutorConversationStoreCases {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("matths-tutor-store-\(UUID().uuidString)", isDirectory: true)
        let slotA = root.appendingPathComponent("slot-a", isDirectory: true)
        let slotB = root.appendingPathComponent("slot-b", isDirectory: true)
        let source = root.appendingPathComponent("picked.jpg")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data([0xff, 0xd8, 0xff, 0xd9]).write(to: source)
        defer { try? FileManager.default.removeItem(at: root) }

        let durable = try TutorConversationStore.importAttachment(
            from: source.path,
            in: slotA)
        let imageName = TutorConversationStore.ownedAttachmentName(
            for: durable,
            in: slotA)
        require(imageName != nil, "첨부 사진은 현재 슬롯 안으로 복사되어야 한다")

        let now = Date()
        TutorConversationStore.save([
            TutorConversationRecord(
                id: UUID(), role: "user", text: "사진 문제", imageFile: imageName,
                done: true, createdAt: now),
            TutorConversationRecord(
                id: UUID(), role: "assistant", text: "", imageFile: nil,
                done: false, createdAt: now),
        ], in: slotA)
        let recovered = TutorConversationStore.load(in: slotA, now: now)
        require(recovered.count == 2, "중단된 assistant를 포함한 대화 턴을 보존해야 한다")
        require(recovered.last?.done == true, "중단된 생성은 완료 상태로 복구해야 한다")
        require(recovered.last?.text.contains("앱이 종료") == true, "중단 이유를 사용자 언어로 남겨야 한다")
        require(TutorConversationStore.attachmentPath(for: imageName!, in: slotA) != nil,
                "복구 뒤 첨부 사진도 읽을 수 있어야 한다")

        TutorConversationStore.save([
            TutorConversationRecord(
                id: UUID(), role: "user", text: "답변 전 종료", imageFile: nil,
                done: true, createdAt: now),
        ], in: slotB)
        let recoveredB = TutorConversationStore.load(in: slotB, now: now)
        require(recoveredB.count == 2 && recoveredB.last?.role == "assistant",
                "마지막 사용자 질문만 저장된 crash gap도 닫아야 한다")
        require(recoveredB.first?.text == "답변 전 종료", "다른 슬롯 대화를 섞으면 안 된다")
        require(recovered.first?.text == "사진 문제", "슬롯 A 대화는 그대로여야 한다")
        require(TutorConversationStore.attachmentPath(for: "../picked.jpg", in: slotA) == nil,
                "첨부 경로 탈출을 허용하면 안 된다")

        print("Tutor conversation persistence, interruption recovery, and slot isolation passed")
    }
}
