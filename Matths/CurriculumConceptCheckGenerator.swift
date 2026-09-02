//  CurriculumConceptCheckGenerator.swift
//  Matths
//
//  계산형 생성기가 없는 개념의 STEP 04를 비워 두지 않는다.
//  정답의 근거는 curriculum-v2.json에 이미 편집·검수된 강의 원고,
//  성취기준, 학습 단계뿐이다. 이 문제는 계산 숙련도를 가장하지 않고
//  화면에도 "개념 확인"으로 표시한다.

import Foundation

enum CurriculumConceptCheckGenerator {
    static let typeIds = [
        "curriculum-summary",
        "curriculum-key-takeaway",
        "curriculum-step-purpose",
        "curriculum-achievement-standard",
        "curriculum-step-sequence",
    ]

    private enum Kind: String, CaseIterable {
        case summary = "curriculum-summary"
        case keyTakeaway = "curriculum-key-takeaway"
        case stepPurpose = "curriculum-step-purpose"
        case achievementStandard = "curriculum-achievement-standard"
        case stepSequence = "curriculum-step-sequence"

        var title: String {
            switch self {
            case .summary: return "개념 확인 1 · 설명과 개념 연결"
            case .keyTakeaway: return "개념 확인 2 · 핵심 원리"
            case .stepPurpose: return "개념 확인 3 · 단계의 목적"
            case .achievementStandard: return "개념 확인 4 · 성취기준"
            case .stepSequence: return "개념 확인 5 · 학습 순서"
            }
        }
    }

    private struct Record {
        let course: CourseV2
        let unit: UnitV2
        let concept: ConceptV2
    }

    static func supports(courseId: String, unitId: String, conceptId: String) -> Bool {
        guard let (_, _, concept) = CurriculumV2.concept(conceptId),
              concept.lesson != nil,
              concept.achievementStandard?.isEmpty == false else { return false }
        return CurriculumV2.course(courseId)?.units.contains {
            $0.id == unitId && $0.concepts.contains { $0.id == conceptId }
        } == true
    }

    static func generate(courseId: String, unitId: String, conceptId: String,
                         count: Int, seed: UInt64) -> [GeneratedProblem] {
        guard count > 0,
              let (course, unit, concept) = CurriculumV2.concept(conceptId),
              course.id == courseId,
              unit.id == unitId,
              let lesson = concept.lesson,
              let standard = concept.achievementStandard,
              let firstStep = lesson.steps.first else { return [] }

        let target = Record(course: course, unit: unit, concept: concept)
        let peers = orderedPeers(for: target)
        var rng = SeededRNG(seed: seed)
        var kinds = Kind.allCases
        kinds.shuffle(using: &rng)

        return (0..<count).compactMap { index in
            let kind = kinds[index % kinds.count]
            return makeProblem(
                kind: kind,
                target: target,
                peers: peers,
                lesson: lesson,
                standard: standard,
                firstStep: firstStep,
                index: index,
                seed: seed,
                rng: &rng)
        }
    }

    private static func allRecords() -> [Record] {
        CurriculumV2.data.courses.flatMap { course in
            course.units.flatMap { unit in
                unit.concepts.map { Record(course: course, unit: unit, concept: $0) }
            }
        }
    }

    private static func orderedPeers(for target: Record) -> [Record] {
        let others = allRecords().filter { $0.concept.id != target.concept.id }
        return others.filter {
            $0.course.id == target.course.id && $0.unit.id == target.unit.id
        } + others.filter {
            $0.course.id == target.course.id && $0.unit.id != target.unit.id
        } + others.filter {
            $0.course.id != target.course.id
        }
    }

    private static func clean(_ value: String?) -> String {
        (value ?? "")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func distinct(_ values: [String?], excluding correct: String) -> [String] {
        let correctKey = clean(correct).replacingOccurrences(of: " ", with: "")
        var seen = Set<String>()
        var result: [String] = []
        for candidate in values.map(clean) {
            let key = candidate.replacingOccurrences(of: " ", with: "")
            guard !candidate.isEmpty, key != correctKey, seen.insert(key).inserted else { continue }
            result.append(candidate)
        }
        return result
    }

    private static func choices(correct: String, distractors: [String?],
                                rng: inout SeededRNG) -> (texts: [String], answer: String)? {
        let alternatives = distinct(distractors, excluding: correct)
        guard alternatives.count >= 3 else { return nil }
        var items = [(text: clean(correct), correct: true)]
        items += alternatives.prefix(3).map { (text: $0, correct: false) }
        items.shuffle(using: &rng)
        let keys = ["a", "b", "c", "d"]
        guard let correctIndex = items.firstIndex(where: \.correct) else { return nil }
        return (
            texts: items.map { MathText.normalizeDelimiters($0.text) },
            answer: keys[correctIndex]
        )
    }

    private static func stepValues(_ peers: [Record],
                                   _ value: (LessonStepV2) -> String) -> [String?] {
        peers.flatMap { record in
            (record.concept.lesson?.steps ?? []).map { value($0) }
        }
    }

    private static func makeProblem(kind: Kind, target: Record, peers: [Record],
                                    lesson: LessonV2, standard: String,
                                    firstStep: LessonStepV2, index: Int, seed: UInt64,
                                    rng: inout SeededRNG) -> GeneratedProblem? {
        let prompt: String
        let correct: String
        let distractors: [String?]
        let solution: [String]
        let hint: String

        switch kind {
        case .summary:
            prompt = "다음 설명이 가리키는 수학 개념을 고르세요. “\(lesson.summary)”"
            correct = target.concept.title
            distractors = peers.map { $0.concept.title }
            solution = [
                "설명에서 반복되는 대상과 수학적 행동을 찾습니다.",
                "이 설명은 \(target.concept.title)의 핵심 맥락을 요약합니다.",
            ]
            hint = "설명에서 반복되는 대상과 수학적 행동을 먼저 찾으세요."
        case .keyTakeaway:
            prompt = "\(target.concept.title)의 핵심 원리로 가장 알맞은 것을 고르세요."
            correct = lesson.keyTakeaway
            distractors = peers.map { $0.concept.lesson?.keyTakeaway }
            solution = [
                "강의의 핵심 정리에서 조건과 결론을 함께 확인합니다.",
                "\(target.concept.title)의 핵심은 다음과 같습니다. \(lesson.keyTakeaway)",
            ]
            hint = "강의의 핵심 정리에서 조건과 결론을 함께 확인하세요."
        case .stepPurpose:
            prompt = "\(target.concept.title) 학습의 ‘\(firstStep.title)’ 단계에서 해야 할 일은 무엇인가요?"
            correct = firstStep.description
            distractors = lesson.steps.dropFirst().map(\.description)
                + stepValues(peers) { $0.description }
            solution = [
                "단계 이름이 요구하는 첫 행동을 확인합니다.",
                "‘\(firstStep.title)’ 단계에서는 \(firstStep.description)",
            ]
            hint = "단계 이름이 요구하는 첫 행동이 무엇인지 생각하세요."
        case .achievementStandard:
            prompt = "\(target.concept.title)을 학습한 뒤 할 수 있어야 하는 일은 무엇인가요?"
            correct = standard
            distractors = peers.map { $0.concept.achievementStandard }
            solution = [
                "정의만 아는 것과 실제로 설명하거나 해결하는 것을 구분합니다.",
                "이 개념의 성취기준은 ‘\(standard)’입니다.",
            ]
            hint = "개념의 정의만이 아니라 실제로 설명하거나 해결해야 하는 일을 고르세요."
        case .stepSequence:
            prompt = "\(target.concept.title)의 학습 흐름에서 가장 먼저 확인할 단계를 고르세요."
            correct = firstStep.title
            distractors = lesson.steps.dropFirst().map(\.title)
                + stepValues(peers) { $0.title }
            solution = [
                "계산이나 적용보다 먼저 정해야 하는 기준·대상·조건을 찾습니다.",
                "첫 단계는 ‘\(firstStep.title)’이며, 여기서 \(firstStep.description)",
            ]
            hint = "계산이나 적용보다 먼저 정해야 하는 기준·대상·조건을 찾으세요."
        }

        guard let choiceSet = choices(correct: correct, distractors: distractors, rng: &rng) else {
            return nil
        }
        let problemSeed = String(seed, radix: 16)
        return GeneratedProblem(
            id: "curriculum-\(target.concept.id)-\(kind.rawValue)-\(problemSeed)-\(index)",
            typeKey: kind.rawValue,
            typeName: kind.title,
            unit: "\(target.course.title) · \(target.unit.title)",
            statement: MathText.normalizeDelimiters(prompt),
            answer: choiceSet.answer,
            steps: solution.map(MathText.normalizeDelimiters),
            minutes: 2,
            choices: choiceSet.texts,
            isTex: true,
            hintText: MathText.normalizeDelimiters(hint))
    }
}
