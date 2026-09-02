//  CurriculumV2.swift
//  Matths
//
//  2022 개정 교육과정 전체(13과목 220개념) — 웹 레포가 진실원이다.
//  curriculum-v2.json 은 curriculum-v2/build.mjs 가 웹 YAML(성취기준)·레슨 시드 54개·
//  기존 앱 콘텐츠 65개를 병합해 만든다. 앱에서 손으로 고치지 말 것 (재생성 대상).
//
//  진도 모델(웹 ConceptProgress 공식 그대로):
//    topic 체크     = 최대 30%
//    서로 다른 유형 정답 = 최대 60%  (기본 5유형 — 가용 유형이 적으면 그 수)
//    합산 캡 90% → 게이트 해금 후 학생이 직접 "완료" 체크해야 100%
//  개념 잠금 없음 — 웹 정책(자유 진입, 잠기는 것은 평가뿐)을 따른다.

import Foundation

// MARK: - 데이터 모델

struct CategoryV2: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int
}

struct CourseV2: Codable, Identifiable {
    let id: String
    let title: String
    let category: String
    let order: Int
    let prerequisites: [String]
    let recommendedGrades: [Int]
    let units: [UnitV2]

    var allConcepts: [ConceptV2] { units.flatMap(\.concepts) }
}

struct UnitV2: Codable, Identifiable {
    let id: String
    let title: String
    let order: Int
    let concepts: [ConceptV2]
}

struct ConceptV2: Codable, Identifiable {
    let id: String
    let order: Int
    let title: String
    let standardCode: String?
    let achievementStandard: String?
    let topics: [String]
    let scopeNotes: [String]
    let visualizationIdeas: [String]
    let lesson: LessonV2?
    let legacy: LegacyV2?

    /// 연습 유형 풀 — 레거시 생성기 유형. 게이트 요구 수는 min(5, 가용 유형).
    var practiceTypes: [String] { legacy?.generatorTypes ?? [] }
}

struct LessonV2: Codable {
    let estimatedMinutes: Int
    let summary: String
    let keyTakeaway: String
    let steps: [LessonStepV2]
    let playgroundKey: String?
}

struct LessonStepV2: Codable {
    let order: Int
    let title: String
    let description: String
}

struct LegacyV2: Codable {
    let appId: String
    let tag: String?
    let oneLiner: String?
    let scene: String?
    let hasPlayground: Bool
    let web: Bool?              // 구 curriculum.json 의 웹 모듈 존재 플래그 (Bool!)
    let generatorTypes: [String]
    let lessonText: String?
}

struct CurriculumV2Data: Codable {
    let version: Int
    let curriculumId: String
    let categories: [CategoryV2]
    let learningTracks: [LearningTrackV2]
    let courses: [CourseV2]
}

struct LearningTrackV2: Codable, Identifiable {
    let id: String
    let order: Int
    let eyebrow: String
    let title: String
    let summary: String
    let courseId: String
    let conceptIds: [String]
}

enum CurriculumV2 {
    private static let loaded: (data: CurriculumV2Data, error: String?) = {
        do {
            guard let url = Bundle.main.url(
                forResource: "curriculum-v2",
                withExtension: "json"
            ) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let raw = try Data(contentsOf: url)
            let parsed = try JSONDecoder().decode(CurriculumV2Data.self, from: raw)
            guard !parsed.courses.isEmpty else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return (parsed, nil)
        } catch {
            // 리소스 누락은 배포 검증에서 실패시킨다. 그래도 이미 설치된 앱이
            // 업데이트 도중 손상됐을 때 프로세스 전체를 종료하지 않고, 해당
            // 화면만 안전한 복구 안내로 남긴다.
            NSLog("[Matths] curriculum-v2 catalog unavailable: %@", error.localizedDescription)
            return (
                CurriculumV2Data(
                    version: 0,
                    curriculumId: "unavailable",
                    categories: [],
                    learningTracks: [],
                    courses: []
                ),
                "커리큘럼 데이터를 열지 못했습니다. 앱을 완전히 종료한 뒤 다시 열고, 계속되면 최신 버전으로 다시 설치해 주세요."
            )
        }
    }()

    static let data = loaded.data
    static let loadError = loaded.error

    static func course(_ id: String) -> CourseV2? {
        data.courses.first { $0.id == id }
    }

    static func concept(_ id: String) -> (CourseV2, UnitV2, ConceptV2)? {
        for c in data.courses {
            for u in c.units {
                if let con = u.concepts.first(where: { $0.id == id }) { return (c, u, con) }
            }
        }
        return nil
    }

    static func coursesByCategory() -> [(CategoryV2, [CourseV2])] {
        data.categories.sorted { $0.order < $1.order }.compactMap { cat in
            let cs = data.courses.filter { $0.category == cat.id }.sorted { $0.order < $1.order }
            return cs.isEmpty ? nil : (cat, cs)
        }
    }

    static func concepts(in track: LearningTrackV2) -> [ConceptV2] {
        track.conceptIds.compactMap { concept($0)?.2 }
    }
}

// MARK: - 진도 v2

struct ConceptProgressV2: Codable, Sendable {
    var completedTopicIndexes: Set<Int> = []
    var correctTypeIds: Set<String> = []
    var userCompleted: Bool = false
    var lastStudiedAt: Date?
    // 개념별 정오 신호 (웹 signals) — 취약 개념 랭킹의 근거. 구파일 호환 옵셔널.
    var totalAttempts: Int?
    var correctAttempts: Int?
}

enum ConceptStatusV2: String {
    case notStarted, inProgress, completed
}

struct ProgressV2Store {
    private(set) var byConcept: [String: ConceptProgressV2] = [:]

    // ── 웹 공식 그대로 ──────────────────────────────────────────
    func percent(for concept: ConceptV2) -> Int {
        let p = byConcept[concept.id] ?? ConceptProgressV2()
        if p.userCompleted && masteryUnlocked(for: concept) { return 100 }
        let topicPart: Double = concept.topics.isEmpty ? 0
            : Double(p.completedTopicIndexes.count) / Double(concept.topics.count) * 30
        let required = requiredDistinctTypes(for: concept)
        let typePart: Double = required == 0 ? 0
            : min(1, Double(p.correctTypeIds.count) / Double(required)) * 60
        return min(90, Int((topicPart + typePart).rounded()))
    }

    func status(for concept: ConceptV2) -> ConceptStatusV2 {
        let pct = percent(for: concept)
        if pct >= 100 { return .completed }
        return pct > 0 ? .inProgress : .notStarted
    }

    /// 웹 requiredDistinctTypes=5. 가용 유형이 5개 미만인 개념(또는 생성기 없음)은
    /// 그 수만큼만 요구한다 — 채울 수 없는 게이트는 게이트가 아니라 벽이다.
    /// 네이티브 유형이 없으면 웹 로컬 생성기(WebGen)의 유형 수를 쓴다.
    /// 요구 유형 수 — **웹 생성기가 있으면 그쪽이 진실원이다.**
    ///
    /// 예전엔 네이티브 유형(1~2개)을 먼저 봐서, 웹에 10유형·요구 5 생성기가 있는
    /// 개념까지 요구 수가 1~2로 내려갔다. 같은 개념을 웹에서는 5유형을 채워야
    /// 열리는데 앱에서는 한 유형만 맞히면 열렸다.
    ///
    /// 반대로 요구 수만 5로 올리면 **채울 수 없는 벽**이 된다 —
    /// 네이티브 경로는 typeKey 를 1~2개밖에 만들지 못하기 때문이다.
    /// 그래서 웹 생성기 정보를 **먼저** 보고, 그 개념은 출제도 웹 경로로 보낸다
    /// (`usesWebGenerator`). 둘의 근거를 같은 곳에 둔다.
    func requiredDistinctTypes(for concept: ConceptV2) -> Int {
        if let info = webGenInfo(for: concept) {
            return min(info.requiredDistinctTypes, info.typeIds.count)
        }
        if !concept.practiceTypes.isEmpty { return min(5, concept.practiceTypes.count) }
        return 0
    }

    /// 이 개념을 웹 생성기로 출제하는가. 요구 유형 수와 **같은 근거**를 쓴다 —
    /// 갈라지면 "요구 5인데 출제는 2유형" 같은 벽이 생긴다.
    func usesWebGenerator(_ concept: ConceptV2) -> Bool { webGenInfo(for: concept) != nil }

    private func webGenInfo(for concept: ConceptV2) -> WebGen.ConceptGenInfo? {
        guard let (course, unit, _) = CurriculumV2.concept(concept.id) else { return nil }
        return WebGen.conceptInfo(
            courseId: course.id,
            unitId: unit.id,
            conceptId: concept.id,
            includeCurriculumChecks: concept.practiceTypes.isEmpty)
    }

    func masteryUnlocked(for concept: ConceptV2) -> Bool {
        let required = requiredDistinctTypes(for: concept)
        // **토픽 체크가 게이트를 대신하지 않는다.**
        //
        // 예전엔 연습 유형이 없는 개념에서 "토픽 전부 체크 = 완료"로 쳤다.
        // 그래서 생성기가 없는 152개 개념이 앱에서는 100%·완료로 뜨는데
        // 웹에서는 진행 중으로 남았다. 레포 스키마(matthsModel 진도 훅)는
        // 토픽 몫을 최대 30%로 두고 게이트를 따로 요구한다.
        // 생성기가 없으면 그 개념은 아직 완료할 수 없는 것이 맞다.
        guard required > 0 else { return false }
        return (byConcept[concept.id]?.correctTypeIds.count ?? 0) >= required
    }

    // ── 변경 ────────────────────────────────────────────────────
    mutating func toggleTopic(_ index: Int, concept: ConceptV2) {
        var p = byConcept[concept.id] ?? ConceptProgressV2()
        guard index >= 0 && index < concept.topics.count else { return }
        if p.completedTopicIndexes.contains(index) { p.completedTopicIndexes.remove(index) }
        else { p.completedTopicIndexes.insert(index) }
        p.lastStudiedAt = Date()
        byConcept[concept.id] = p
    }

    mutating func recordCorrectType(_ typeKey: String, conceptID: String) {
        var p = byConcept[conceptID] ?? ConceptProgressV2()
        p.correctTypeIds.insert(Self.canonicalTypeId(typeKey))
        p.lastStudiedAt = Date()
        byConcept[conceptID] = p
    }

    /// 정오 신호 누적 (웹 signals) — 취약 개념 top3 의 근거
    mutating func recordAttempt(correct: Bool, conceptID: String) {
        var p = byConcept[conceptID] ?? ConceptProgressV2()
        p.totalAttempts = (p.totalAttempts ?? 0) + 1
        if correct { p.correctAttempts = (p.correctAttempts ?? 0) + 1 }
        p.lastStudiedAt = Date()
        byConcept[conceptID] = p
    }

    /// 취약 개념 — 정확도 낮은 순 (웹: accuracy<50 urgent, <70 복습 필요)
    func weakConcepts(top: Int) -> [(concept: ConceptV2, accuracy: Int, attempts: Int)] {
        var rows: [(ConceptV2, Int, Int)] = []
        for course in CurriculumV2.data.courses {
            for unit in course.units {
                for con in unit.concepts {
                    guard let p = byConcept[con.id],
                          let total = p.totalAttempts, total >= 2 else { continue }
                    let acc = Int(Double(p.correctAttempts ?? 0) / Double(total) * 100)
                    guard acc < 100 else { continue }
                    rows.append((con, acc, total))
                }
            }
        }
        return Array(rows.sorted { $0.1 < $1.1 }.prefix(top))
    }

    mutating func setUserCompleted(_ done: Bool, concept: ConceptV2) {
        var p = byConcept[concept.id] ?? ConceptProgressV2()
        p.userCompleted = done
        p.lastStudiedAt = Date()
        byConcept[concept.id] = p
    }

    // ── 과목/전체 집계 (웹 스코핑 규칙: 공통 + 활동 있는 선택과목) ──
    func coursePercent(_ course: CourseV2) -> Int {
        let all = course.allConcepts
        guard !all.isEmpty else { return 0 }
        let sum = all.reduce(0) { $0 + percent(for: $1) }
        return sum / all.count
    }

    func hasActivity(_ course: CourseV2) -> Bool {
        course.allConcepts.contains { byConcept[$0.id] != nil }
    }

    func overallScoped() -> (percent: Int, done: Int, total: Int) {
        let scoped = CurriculumV2.data.courses.filter {
            $0.category == "common" || hasActivity($0)
        }
        let concepts = scoped.flatMap(\.allConcepts)
        guard !concepts.isEmpty else { return (0, 0, 0) }
        let sum = concepts.reduce(0) { $0 + percent(for: $1) }
        let done = concepts.filter { percent(for: $0) >= 100 }.count
        return (sum / concepts.count, done, concepts.count)
    }

    /// 이어서 학습 — 웹 우선순위: ①진행 중 → ②공통 과목 첫 미완료 → ③아무 미완료
    func continueConcept() -> (CourseV2, UnitV2, ConceptV2)? {
        var firstCommonIncomplete: (CourseV2, UnitV2, ConceptV2)?
        var anyIncomplete: (CourseV2, UnitV2, ConceptV2)?
        for course in CurriculumV2.data.courses {
            for unit in course.units {
                for con in unit.concepts {
                    switch status(for: con) {
                    case .inProgress: return (course, unit, con)
                    case .notStarted:
                        if course.category == "common", firstCommonIncomplete == nil {
                            firstCommonIncomplete = (course, unit, con)
                        }
                        if anyIncomplete == nil { anyIncomplete = (course, unit, con) }
                    case .completed: break
                    }
                }
            }
        }
        return firstCommonIncomplete ?? anyIncomplete
    }

    // ── 저장 (Documents/progress-v2.json) ───────────────────────
    static var fileURL: URL {
        DataScope.url("progress-v2.json")
    }

    static func load() -> ProgressV2Store {
        var store = ProgressV2Store()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: ConceptProgressV2].self, from: data) {
            store.byConcept = decoded
            // 구 앱이 저장한 web-<typeId>를 서버 정본 <typeId>로 1회 정규화한다.
            for conceptId in Array(store.byConcept.keys) {
                guard var progress = store.byConcept[conceptId] else { continue }
                progress.correctTypeIds = Set(progress.correctTypeIds.map(Self.canonicalTypeId))
                store.byConcept[conceptId] = progress
            }
        }
        return store
    }

    func save() {
        _ = Self.persist(byConcept, for: DataScope.slot)
    }

    /// actor writer가 호출 시점에 붙잡은 슬롯으로 저장한다. 실행 시점의
    /// `DataScope.slot`을 다시 읽으면 로그아웃 직전 값이 다음 계정에 섞일 수 있다.
    @discardableResult
    static func persist(_ snapshot: [String: ConceptProgressV2], for slot: String) -> Bool {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: DataScope.url("progress-v2.json", for: slot), options: .atomic)
            return true
        } catch {
            NSLog("PROGRESS-STORAGE-ERROR 저장 실패 (slot=%@): %@", slot, error.localizedDescription)
            return false
        }
    }

    /// 1회 마이그레이션 — 구 진도(완료 개념 id 집합, cm1-poly 식)를
    /// legacy.appId 역매핑으로 v2 에 옮긴다. 이미 v2 기록이 있는 개념은 건드리지 않는다
    /// (마이그레이션이 사용자 데이터를 덮으면 안 된다).
    /// 서버에서 받은 진도를 **합친다(덮지 않는다).**
    ///
    /// 덮어쓰면 오프라인에서 방금 푼 것이 사라진다. 유형·토픽은 합집합,
    /// 완료 플래그는 어느 쪽이든 true 면 true — 진도는 되돌아가지 않는 값이다.
    /// 반대로 서버에만 있던 개념은 새로 만든다(기기를 바꾼 경우가 이것이다).
    mutating func mergeRemote(conceptId: String,
                              topicIndexes: [Int],
                              correctTypeIds: [String],
                              userCompleted: Bool,
                              lastStudiedAt: Date?) {
        var p = byConcept[conceptId] ?? ConceptProgressV2()
        p.completedTopicIndexes.formUnion(topicIndexes)
        p.correctTypeIds.formUnion(correctTypeIds.map(Self.canonicalTypeId))
        if userCompleted { p.userCompleted = true }
        if let remote = lastStudiedAt {
            p.lastStudiedAt = max(p.lastStudiedAt ?? remote, remote)
        }
        byConcept[conceptId] = p
    }

    mutating func migrate(fromLegacyCompleted old: Set<String>) {
        guard !old.isEmpty else { return }
        for course in CurriculumV2.data.courses {
            for unit in course.units {
                for con in unit.concepts {
                    guard let appId = con.legacy?.appId, old.contains(appId),
                          byConcept[con.id] == nil else { continue }
                    var p = ConceptProgressV2()
                    p.userCompleted = true
                    p.completedTopicIndexes = Set(con.topics.indices)
                    p.correctTypeIds = Set(migratedTypeIds(for: con))
                    byConcept[con.id] = p
                }
            }
        }
    }

    /// 이관이 채워 줄 유형 키 — 게이트 요구 수만큼.
    ///
    /// 네이티브 유형(legacy.generatorTypes)만 보면 안 된다. 구 진도에 있으면서
    /// 네이티브 유형은 없고 WebGen 이 5유형을 주는 개념이 10개 있는데(대수·미적분Ⅰ),
    /// 그 경우 빈 집합이 들어가 게이트가 0/5 로 잠기고 — 이미 끝낸 개념인데 —
    /// 허브에 100% 대신 30% 로 표시된다. 요구 수를 세는 근거(requiredDistinctTypes)와
    /// 채우는 근거가 같아야 한다.
    ///
    /// 키 형식은 웹·iPad가 함께 쓰는 서버 정본 typeId와 같아야 한다.
    /// 구 앱의 "web-<typeId>" 값은 load/merge/record 경계에서 정규화한다.
    private func migratedTypeIds(for concept: ConceptV2) -> [String] {
        let required = requiredDistinctTypes(for: concept)
        guard required > 0 else { return [] }
        if let info = webGenInfo(for: concept) {
            return Array(info.typeIds.prefix(required))
        }
        if !concept.practiceTypes.isEmpty {
            return Array(concept.practiceTypes.prefix(required))
        }
        return []
    }

    private static func canonicalTypeId(_ typeId: String) -> String {
        typeId.hasPrefix("web-") ? String(typeId.dropFirst(4)) : typeId
    }

    #if DEBUG
    /// 스크린샷·레이아웃 검증의 `-complete n` 전용. 기존 진도와 합치기만 한다.
    mutating func mergeDebugCompletion(_ concept: ConceptV2) {
        var progress = byConcept[concept.id] ?? ConceptProgressV2()
        progress.completedTopicIndexes.formUnion(concept.topics.indices)
        progress.correctTypeIds.formUnion(migratedTypeIds(for: concept))
        progress.userCompleted = true
        progress.lastStudiedAt = progress.lastStudiedAt ?? Date()
        byConcept[concept.id] = progress
    }
    #endif
}
