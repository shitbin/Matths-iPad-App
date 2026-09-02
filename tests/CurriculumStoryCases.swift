import Foundation

@main
struct CurriculumStoryCases {
    static func main() throws {
        let scenes = CurriculumStorySceneKind.allCases.enumerated().map { index, kind in
            CurriculumStudentStoryScene(
                id: "scene-\(index)",
                kind: kind,
                title: kind.label,
                subtitle: "학생 화면에 보이는 짧고 명확한 자막입니다.",
                narration: "첫 문장은 판단 기준을 설명합니다. 두 번째 문장은 다음 문제에서 꺼낼 질문을 남깁니다.",
            )
        }
        let story = CurriculumStudentStory(
            courseID: "course",
            unitID: "unit",
            conceptID: "concept",
            revision: 1,
            title: "테스트 기억선",
            openingQuestion: "무엇을 먼저 판단할까요?",
            estimatedSeconds: 300,
            scenes: scenes
        )
        let chunks = CurriculumNarrationChunker.chunks(for: story)
        precondition(chunks.count == 10)
        precondition(chunks.allSatisfy { !$0.text.isEmpty && $0.text.count <= 180 })
        precondition(chunks.first?.sceneID == "scene-0")
        precondition(story.narrationCheckpointID == "concept.r1")

        let longText = String(repeating: "가", count: 210) + ", " + String(repeating: "나", count: 60) + "."
        let longChunks = CurriculumNarrationChunker.sentences(in: longText)
        precondition(longChunks.count >= 2)
        precondition(longChunks.allSatisfy { $0.count <= 180 })

        let aliases = ["침착하게": "warmly", "궁금한 듯": "curious"]
        let narration = "조건을 먼저 읽고 분모가 무엇인지 질문합니다."
        let compiled = try CurriculumStudioScriptCompiler.compile(
            "[침착하게] \(narration)",
            aliases: aliases
        )
        precondition(compiled == "[warmly] \(narration)")
        precondition(CurriculumStudioScriptCompiler.stripTags(compiled) == narration)

        let studentProjectionFields = [
            story.title,
            story.openingQuestion,
            scenes[0].title,
            scenes[0].subtitle,
            scenes[0].narration,
        ]
        precondition(!CurriculumStudentProjectionTextGuard.containsStudioTag(
            in: studentProjectionFields
        ))
        for fieldIndex in studentProjectionFields.indices {
            var leakedFields = studentProjectionFields
            leakedFields[fieldIndex] = "[침착하게] \(leakedFields[fieldIndex])"
            precondition(CurriculumStudentProjectionTextGuard.containsStudioTag(in: leakedFields))
        }

        do {
            _ = try CurriculumStudioScriptCompiler.compile("[알 수 없음] 원고", aliases: aliases)
            preconditionFailure("unknown alias must fail closed")
        } catch {
            // expected
        }

        print("CurriculumStory Swift cases passed: sentence chunks and Korean studio aliases.")
    }
}
