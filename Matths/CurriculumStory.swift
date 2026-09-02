//  CurriculumStory.swift
//  Matths
//
//  5분 개념 해설 정본. 기존 curriculum-v2.json의 짧은 lesson을 늘려 쓰지 않는다.
//  검수된 published story만 학생 projection으로 내리고, studioScript와 감정 태그는
//  이 파일의 private raw model 밖으로 나가지 않는다.

import CryptoKit
import Foundation

enum CurriculumStorySceneKind: String, Codable, CaseIterable {
    case intuition
    case question
    case misconception
    case solution
    case recall

    var label: String {
        switch self {
        case .intuition: "직관"
        case .question: "질문"
        case .misconception: "오개념"
        case .solution: "풀이 리듬"
        case .recall: "회상"
        }
    }

    var symbol: String {
        switch self {
        case .intuition: "circle.fill"
        case .question: "questionmark"
        case .misconception: "exclamationmark"
        case .solution: "arrow.right"
        case .recall: "arrow.counterclockwise"
        }
    }
}

/// 학생 화면과 시스템 TTS가 받는 유일한 story 모델.
/// `studioScript`를 의도적으로 정의하지 않아 SwiftUI가 태그 원문에 접근할 수 없다.
struct CurriculumStudentStory: Identifiable, Equatable {
    let courseID: String
    let unitID: String
    let conceptID: String
    let revision: Int
    let title: String
    let openingQuestion: String
    let estimatedSeconds: Int
    let scenes: [CurriculumStudentStoryScene]

    var id: String { conceptID }
    var narrationCheckpointID: String { "\(conceptID).r\(revision)" }
}

struct CurriculumStudentStoryScene: Identifiable, Equatable {
    let id: String
    let kind: CurriculumStorySceneKind
    let title: String
    let subtitle: String
    let narration: String
    let motion: CurriculumMotionDirective?

    init(
        id: String,
        kind: CurriculumStorySceneKind,
        title: String,
        subtitle: String,
        narration: String,
        motion: CurriculumMotionDirective? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.narration = narration
        self.motion = motion
    }
}

struct CurriculumMotionDirective: Codable, Equatable {
    let version: Int
    let mode: String
    let focus: String
    let instruction: String
    let beats: [CurriculumMotionBeat]
    let mild: CurriculumMotionExplanation
    let spicy: CurriculumMotionExplanation
    let check: CurriculumMotionCheck
}

struct CurriculumMotionBeat: Codable, Equatable, Identifiable {
    let id: String
    let action: String
    let target: String
    let expression: String
    let result: String?
    let caption: String
    let durationMs: Int
}

struct CurriculumMotionExplanation: Codable, Equatable {
    let explanation: String
}

struct CurriculumMotionCheck: Codable, Equatable {
    let prompt: String
    let choices: [String]
    let answerIndex: Int
    let correctFeedback: String
    let retryFeedback: String
}

enum CurriculumStoryAvailability: String, Equatable {
    case published
    case missing
    case draft
    case invalid
    case unavailable
}

struct CurriculumStoryResolution: Equatable {
    let story: CurriculumStudentStory?
    let availability: CurriculumStoryAvailability
}

struct CurriculumNarrationChunk: Identifiable, Equatable {
    let id: String
    let sceneID: String
    let sceneTitle: String
    let sceneIndex: Int
    let text: String
}

enum CurriculumNarrationChunker {
    static let maximumCharacters = 180

    static func chunks(for story: CurriculumStudentStory) -> [CurriculumNarrationChunk] {
        story.scenes.enumerated().flatMap { sceneIndex, scene in
            sentences(in: scene.narration).enumerated().map { sentenceIndex, text in
                CurriculumNarrationChunk(
                    id: "\(scene.id)-\(sentenceIndex)",
                    sceneID: scene.id,
                    sceneTitle: scene.title,
                    sceneIndex: sceneIndex,
                    text: text
                )
            }
        }
    }

    static func sentences(in text: String, maximumCharacters: Int = maximumCharacters) -> [String] {
        let normalized = normalizeWhitespace(text)
        guard !normalized.isEmpty else { return [] }
        let pattern = #"[^.!?。！？…]+(?:[.!?。！？]+|…+|$)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = regex?.matches(in: normalized, range: range) ?? []
        let sentenceCandidates = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: normalized) else { return nil }
            return normalizeWhitespace(String(normalized[range]))
        }
        return (sentenceCandidates.isEmpty ? [normalized] : sentenceCandidates)
            .flatMap { splitOversize($0, maximumCharacters: maximumCharacters) }
    }

    private static func splitOversize(_ text: String, maximumCharacters: Int) -> [String] {
        var remaining = normalizeWhitespace(text)
        var output: [String] = []

        while remaining.count > maximumCharacters {
            let upper = remaining.index(remaining.startIndex, offsetBy: maximumCharacters)
            let window = remaining[remaining.startIndex...upper]
            let preferredBreak = window.lastIndex(where: { $0 == "," || $0 == ";" || $0 == " " })
            let minimum = remaining.index(
                remaining.startIndex,
                offsetBy: Int(Double(maximumCharacters) * 0.55)
            )
            let splitIndex = preferredBreak.map { $0 >= minimum ? remaining.index(after: $0) : upper } ?? upper
            output.append(normalizeWhitespace(String(remaining[..<splitIndex])))
            remaining = normalizeWhitespace(String(remaining[splitIndex...]))
        }
        if !remaining.isEmpty { output.append(remaining) }
        return output
    }
}

enum CurriculumNarrationTimingPolicy {
    // AVSpeechUtterance는 Web Speech와 rate 스케일이 다르다. 220개 실제 Yuna
    // ko-KR 문장-chunk 합성에서 234.9~346.7초, 평균 274.6초를 기록한 값이다.
    static let systemSpeechRateFactor: Float = 0.55
    static let approximateMinimumSeconds = 230.0
    static let approximateMaximumSeconds = 360.0
}

enum CurriculumStudioScriptCompiler {
    static func compile(_ script: String, aliases: [String: String]) throws -> String {
        let regex = try NSRegularExpression(pattern: #"\[([^\]\n]{1,40})\]"#)
        var compiled = script
        let matches = regex.matches(
            in: script,
            range: NSRange(script.startIndex..<script.endIndex, in: script)
        )
        for match in matches.reversed() {
            guard let aliasRange = Range(match.range(at: 1), in: script),
                  let wholeRange = Range(match.range, in: compiled) else { continue }
            let alias = String(script[aliasRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let providerTag = aliases[alias] else {
                throw CurriculumStoryError.invalid("지원하지 않는 studio 편집 태그입니다: [\(alias)]")
            }
            compiled.replaceSubrange(wholeRange, with: "[\(providerTag)]")
        }
        return compiled
    }

    static func stripTags(_ script: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[[^\]\n]{1,40}\]"#) else {
            return normalizeWhitespace(script)
        }
        let range = NSRange(script.startIndex..<script.endIndex, in: script)
        return normalizeWhitespace(regex.stringByReplacingMatches(
            in: script,
            range: range,
            withTemplate: " "
        ))
    }
}

enum CurriculumStudentProjectionTextGuard {
    static func containsStudioTag(in values: [String]) -> Bool {
        values.contains(where: containsTag)
    }
}

enum CurriculumStoryCatalog {
    private static let loaded: LoadedCatalog = load()

    static var loadError: String? { loaded.loadError }

    static func resolve(courseID: String, unitID: String, conceptID: String) -> CurriculumStoryResolution {
        let key = storyKey(courseID: courseID, unitID: unitID, conceptID: conceptID)
        if let story = loaded.published[key] {
            return CurriculumStoryResolution(story: story, availability: .published)
        }
        if let availability = loaded.availability[key] {
            return CurriculumStoryResolution(story: nil, availability: availability)
        }
        return CurriculumStoryResolution(
            story: nil,
            availability: loaded.loadError == nil ? .missing : .unavailable
        )
    }

    static var publishedCount: Int { loaded.published.count }

    private struct LoadedCatalog {
        let published: [String: CurriculumStudentStory]
        let availability: [String: CurriculumStoryAvailability]
        let loadError: String?
    }

    private static func load() -> LoadedCatalog {
        do {
            let policy: RawPolicy = try decodeResource(
                name: "curriculum-story-policy",
                subdirectory: nil
            )
            let index: RawIndex = try decodeResource(
                name: "curriculum-stories-index",
                subdirectory: nil
            )
            let curriculum: RawCurriculumAuthority = try decodeResource(
                name: "curriculum-v2",
                subdirectory: nil
            )
            guard policy.schemaVersion == RawPolicy.expectedSchema,
                  index.schemaVersion == policy.schemaVersion,
                  index.curriculumId == policy.curriculumId,
                  curriculum.curriculumId == policy.curriculumId,
                  index.providerPolicy == policy.providerPolicy else {
                throw CurriculumStoryError.invalid("policy와 generated index 버전이 다릅니다.")
            }

            let indexedCourses = Set(index.shards.map(\.courseId))
            guard indexedCourses == Set(policy.courseIds) else {
                throw CurriculumStoryError.invalid("13과목 shard index가 완전하지 않습니다.")
            }

            var published: [String: CurriculumStudentStory] = [:]
            var availability: [String: CurriculumStoryAvailability] = [:]
            var seenConceptIDs = Set<String>()
            let authorityByKey = Dictionary(
                uniqueKeysWithValues: curriculum.courses.flatMap { course in
                    course.units.flatMap { unit in
                        unit.concepts.map { concept in
                            (
                                storyKey(
                                    courseID: course.id,
                                    unitID: unit.id,
                                    conceptID: concept.id
                                ),
                                concept
                            )
                        }
                    }
                }
            )

            for shardIndex in index.shards {
                let fileName = URL(fileURLWithPath: shardIndex.file)
                    .deletingPathExtension().lastPathComponent
                let resource = try resourceURL(
                    name: fileName,
                    extension: "json",
                    subdirectory: "curriculum-stories"
                )
                let rawData = try Data(contentsOf: resource)
                guard sha256(rawData) == shardIndex.sha256 else {
                    throw CurriculumStoryError.invalid("\(shardIndex.courseId) shard SHA-256이 index와 다릅니다.")
                }
                let shard = try JSONDecoder().decode(RawShard.self, from: rawData)
                guard shard.schemaVersion == policy.schemaVersion,
                      shard.curriculumId == policy.curriculumId,
                      shard.courseId == shardIndex.courseId,
                      shard.stories.count == shardIndex.storyCount,
                      shard.stories.map(\.conceptId) == shardIndex.conceptIds else {
                    throw CurriculumStoryError.invalid("\(shardIndex.courseId) shard 메타데이터가 index와 다릅니다.")
                }

                for rawStory in shard.stories {
                    let key = storyKey(
                        courseID: rawStory.courseId,
                        unitID: rawStory.unitId,
                        conceptID: rawStory.conceptId
                    )
                    guard rawStory.courseId == shard.courseId,
                          seenConceptIDs.insert(rawStory.conceptId).inserted else {
                        availability[key] = .invalid
                        continue
                    }

                    guard let authority = authorityByKey[key],
                          normalizeWhitespace(rawStory.source.standardCode)
                            == normalizeWhitespace(authority.standardCode) else {
                        NSLog("[Matths] curriculum story authority mismatch: %@", key)
                        availability[key] = .invalid
                        continue
                    }

                    let issues = validate(rawStory, policy: policy)
                    if !issues.isEmpty {
                        NSLog("[Matths] invalid curriculum story %@: %@", key, issues.joined(separator: " | "))
                        availability[key] = .invalid
                    } else if rawStory.status == "draft" {
                        availability[key] = .draft
                    } else if rawStory.status == "published" {
                        published[key] = rawStory.studentProjection
                        availability[key] = .published
                    } else {
                        availability[key] = .invalid
                    }
                }
            }
            return LoadedCatalog(published: published, availability: availability, loadError: nil)
        } catch {
            NSLog("[Matths] curriculum story catalog unavailable: %@", error.localizedDescription)
            return LoadedCatalog(
                published: [:],
                availability: [:],
                loadError: "5분 해설 데이터를 열지 못했습니다. 기존 개념 학습은 계속 이용할 수 있습니다."
            )
        }
    }

    private static func validate(_ story: RawStory, policy: RawPolicy) -> [String] {
        var issues: [String] = []
        let quality = policy.qualityPolicy
        let requiredKinds = Set(quality.requiredSceneKinds)
        let sceneKinds = Set(story.scenes.map(\.kind))
        let narrationCount = story.scenes.reduce(0) { $0 + $1.narration.count }
        let studentProjectionText = [story.title, story.openingQuestion] + story.scenes.flatMap {
            [$0.title, $0.subtitle, $0.narration]
        }

        if !(quality.minimumScenes...quality.maximumScenes).contains(story.scenes.count) {
            issues.append("scene 개수")
        }
        if !requiredKinds.isSubset(of: sceneKinds) { issues.append("필수 scene kind") }
        if !(quality.minimumNarrationCharacters...quality.maximumNarrationCharacters).contains(narrationCount) {
            issues.append("narration 분량")
        }
        if !(quality.minimumEstimatedSeconds...quality.maximumEstimatedSeconds).contains(story.estimatedSeconds) {
            issues.append("estimatedSeconds")
        }
        if !story.openingQuestion.hasSuffix("?") { issues.append("openingQuestion") }
        if CurriculumStudentProjectionTextGuard.containsStudioTag(in: studentProjectionText) {
            issues.append("학생 projection tag")
        }

        let aliases = policy.providerPolicy.studioTagAliases
        for scene in story.scenes {
            if scene.narration.count < 240 || scene.subtitle.count < 15 || scene.subtitle.count > 100 {
                issues.append("scene 편집 분량")
            }
            if CurriculumStudioScriptCompiler.stripTags(scene.studioScript) != normalizeWhitespace(scene.narration) {
                issues.append("studioScript/narration 불일치")
            }
            do {
                _ = try CurriculumStudioScriptCompiler.compile(scene.studioScript, aliases: aliases)
            } catch {
                issues.append("studio tag alias")
            }
            let chunks = CurriculumNarrationChunker.sentences(in: scene.narration)
            if chunks.isEmpty || chunks.contains(where: { $0.count > quality.maximumSpeechChunkCharacters }) {
                issues.append("speech chunk")
            }
            issues.append(contentsOf: validateMotion(scene.motion))
        }
        return Array(Set(issues)).sorted()
    }

    private static func validateMotion(_ motion: CurriculumMotionDirective?) -> [String] {
        guard let motion else { return [] }
        var issues: [String] = []
        let modes = Set(["equation", "blocks", "graph", "geometry", "plot"])
        let actions = Set(["place", "group", "point", "highlight", "transform", "verify"])
        let studentCopy = [
            motion.focus,
            motion.instruction,
            motion.mild.explanation,
            motion.spicy.explanation,
            motion.check.prompt,
            motion.check.correctFeedback,
            motion.check.retryFeedback,
        ] + motion.check.choices + motion.beats.flatMap {
            [$0.target, $0.expression, $0.result ?? "", $0.caption]
        }

        if motion.version != 1 { issues.append("motion version") }
        if !modes.contains(motion.mode) { issues.append("motion mode") }
        if !(3...5).contains(motion.beats.count) { issues.append("motion beat 개수") }
        if Set(motion.beats.map(\.id)).count != motion.beats.count { issues.append("motion beat id") }
        if motion.beats.contains(where: {
            !actions.contains($0.action)
                || !(650...5_000).contains($0.durationMs)
                || $0.target.isEmpty
                || $0.expression.isEmpty
                || $0.caption.count < 12
        }) { issues.append("motion beat") }
        if motion.focus.count < 2 || motion.focus.count > 48
            || motion.instruction.count < 15 || motion.instruction.count > 140 {
            issues.append("motion focus/instruction")
        }
        if motion.check.choices.count != 3
            || !motion.check.choices.indices.contains(motion.check.answerIndex) {
            issues.append("motion check")
        }
        if CurriculumStudentProjectionTextGuard.containsStudioTag(in: studentCopy) {
            issues.append("motion 학생 projection tag")
        }
        return issues
    }

    private static func decodeResource<T: Decodable>(name: String, subdirectory: String?) throws -> T {
        let url = try resourceURL(name: name, extension: "json", subdirectory: subdirectory)
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private static func resourceURL(
        name: String,
        extension fileExtension: String,
        subdirectory: String?
    ) throws -> URL {
        if let subdirectory,
           let url = Bundle.main.url(
               forResource: name,
               withExtension: fileExtension,
               subdirectory: subdirectory
           ) {
            return url
        }
        if let url = Bundle.main.url(forResource: name, withExtension: fileExtension) {
            return url
        }
        throw CurriculumStoryError.missing("\(name).\(fileExtension)")
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private enum CurriculumStoryError: LocalizedError {
    case missing(String)
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .missing(let value): "리소스를 찾을 수 없습니다: \(value)"
        case .invalid(let value): value
        }
    }
}

private struct RawPolicy: Decodable {
    static let expectedSchema = "MATTHS_CURRICULUM_STORY_V1"
    let schemaVersion: String
    let curriculumId: String
    let courseIds: [String]
    let providerPolicy: RawProviderPolicy
    let qualityPolicy: RawQualityPolicy
}

private struct RawProviderPolicy: Codable, Equatable {
    let defaultProvider: String
    let defaultLocale: String
    let defaultVoiceGender: String
    let studioProvider: String
    let studioTagAliases: [String: String]
}

private struct RawQualityPolicy: Decodable {
    let minimumScenes: Int
    let maximumScenes: Int
    let minimumNarrationCharacters: Int
    let maximumNarrationCharacters: Int
    let minimumEstimatedSeconds: Int
    let maximumEstimatedSeconds: Int
    let requiredSceneKinds: [CurriculumStorySceneKind]
    let maximumSpeechChunkCharacters: Int
}

private struct RawIndex: Decodable {
    let schemaVersion: String
    let curriculumId: String
    let providerPolicy: RawProviderPolicy
    let shards: [RawIndexShard]
}

private struct RawIndexShard: Decodable {
    let courseId: String
    let file: String
    let storyCount: Int
    let conceptIds: [String]
    let sha256: String
}

private struct RawCurriculumAuthority: Decodable {
    let curriculumId: String
    let courses: [RawCurriculumAuthorityCourse]
}

private struct RawCurriculumAuthorityCourse: Decodable {
    let id: String
    let units: [RawCurriculumAuthorityUnit]
}

private struct RawCurriculumAuthorityUnit: Decodable {
    let id: String
    let concepts: [RawCurriculumAuthorityConcept]
}

private struct RawCurriculumAuthorityConcept: Decodable {
    let id: String
    let standardCode: String
}

private struct RawShard: Decodable {
    let schemaVersion: String
    let curriculumId: String
    let courseId: String
    let stories: [RawStory]
}

private struct RawStory: Decodable {
    let courseId: String
    let unitId: String
    let conceptId: String
    let status: String
    let revision: Int
    let estimatedSeconds: Int
    let title: String
    let openingQuestion: String
    let source: RawSource
    let scenes: [RawScene]

    var studentProjection: CurriculumStudentStory {
        CurriculumStudentStory(
            courseID: courseId,
            unitID: unitId,
            conceptID: conceptId,
            revision: revision,
            title: title,
            openingQuestion: openingQuestion,
            estimatedSeconds: estimatedSeconds,
            scenes: scenes.map { scene in
                CurriculumStudentStoryScene(
                    id: scene.id,
                    kind: scene.kind,
                    title: scene.title,
                    subtitle: scene.subtitle,
                    narration: scene.narration,
                    motion: scene.motion
                )
            }
        )
    }
}

private struct RawSource: Decodable {
    let standardCode: String
    let basis: String
}

private struct RawScene: Decodable {
    let id: String
    let kind: CurriculumStorySceneKind
    let title: String
    let subtitle: String
    let narration: String
    let studioScript: String
    let motion: CurriculumMotionDirective?
}

private func storyKey(courseID: String, unitID: String, conceptID: String) -> String {
    [courseID, unitID, conceptID].map(normalizeWhitespace).joined(separator: "/")
}

private func containsTag(_ text: String) -> Bool {
    text.range(of: #"\[[^\]\n]{1,40}\]"#, options: .regularExpression) != nil
}

private func normalizeWhitespace(_ text: String) -> String {
    text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
