//  WrongNoteStore.swift
//  Matths
//
//  오답노트 — 보관함이 아니라 다시 풀 목록.
//
//  루프: 틀림 → 항목 적재(문항 전체 + 갈라진 단계 + 필기 스냅샷)
//        → 복습(그 문제를 그대로 재출제) → 맞히면 간격 전진, 틀리면 리셋
//        → 1·3·7·14일 네 번 연속 통과 = 졸업(mastered).
//
//  서버의 ai-grader/src/service.js applyReviewResult 와 같은 규칙.
//  단 하나 다른 점: 최초 복습은 당일(due 즉시)이다 — 틀린 직후 재도전이
//  가장 효과가 크고, 데모에서 루프를 그 자리에서 보여줄 수 있어야 한다.
//
//  저장: Documents/wrongnotes.json (필기 PNG 포함이라 UserDefaults 는 부적합).

import Foundation

struct WrongNoteEntry: Codable, Identifiable, Sendable {
    let id: String
    let problemID: String
    let typeKey: String
    let typeName: String
    let unit: String
    let statement: String
    let answer: String
    let steps: [String]
    let seed: UInt64             // 이 회차를 재현할 수 있는 시드
    var divergenceStep: Int?     // 학생이 짚은 갈라진 단계 (0 = 모르겠음)
    var drawingPNGBase64: String?
    var srsStage: Int            // 0~3. 통과할 때마다 +1, 4가 되면 졸업
    var nextReviewAt: Date?      // nil = 졸업
    var wrongCount: Int
    let createdAt: Date
    // 뱅크 문항용 (구버전 저장 파일과 호환되게 옵셔널)
    var choices: [String]?
    var isTex: Bool?
    /// 틀린 이유 — 웹 ERROR_LABELS 7종 (구파일 호환 옵셔널)
    var errorType: String?
    /// 그때 학생이 실제로 낸 답 — AI 진단의 핵심 재료 (구파일 호환 옵셔널).
    /// 이게 없으면 모델이 "학생 답이 없다"고만 답하고 진단을 못 한다.
    var myAnswer: String?
    /// 시각 힌트 (웹 로컬 생성기 문항 한정, 구파일 호환 옵셔널)
    var hintText: String?
    var visualizationJSON: String?
    /// 서버가 이 오답에 붙인 ObjectId. 복습 결과(POST …/:attemptId/review-result)는
    /// **이 값으로만** 찾을 수 있다 — 우리 UUID(clientAttemptId)로는 404 다.
    /// bulk 업로드 응답의 매핑을 받아 채운다. 없으면 아직 서버에 안 올라간 것.
    var serverAttemptId: String?
    /// 마지막으로 적용한 서버 오답 행의 갱신 시각. 다른 iPad·웹에서 복습한
    /// 결과를 다시 받을 때 로컬 필기/문제 스냅샷은 지키고 서버 상태만 최신으로
    /// 합치기 위한 커서다. 구버전 저장 파일에는 없어도 디코딩된다.
    var serverUpdatedAt: Date? = nil

    var isMastered: Bool { nextReviewAt == nil }
    var isDue: Bool {
        guard let next = nextReviewAt else { return false }
        return next <= Date()
    }

    /// 복습용으로 문항을 그대로 복원한다 — 수치가 바뀌지 않는 것이 핵심.
    /// 틀렸던 바로 그 문제를 다시 마주해야 복습이다.
    var asProblem: GeneratedProblem {
        GeneratedProblem(id: problemID, typeKey: typeKey, typeName: typeName,
                         unit: unit, statement: statement, answer: answer,
                         steps: steps, minutes: 4,
                         choices: choices, isTex: isTex ?? false,
                         hintText: hintText, visualizationJSON: visualizationJSON)
    }
}

/// 복습 결과 업로드 주소는 서버 ObjectId가 붙기 전에도 항상 존재해야 한다.
/// 초기 bulk 응답 전에는 clientAttemptId인 로컬 id를 쓰고, 응답 뒤에는 서버 id를 쓴다.
enum WrongNoteReviewSyncAddress {
    static func attemptIdentifier(for entry: WrongNoteEntry) -> String {
        entry.serverAttemptId ?? entry.id
    }
}

/// 서버 행을 기존 로컬 오답에 적용하는 작은 순수 함수. 네트워크·디스크와 분리해
/// 구 저장 파일 호환과 다기기 복습 상태 병합을 독립적으로 검증할 수 있게 한다.
enum WrongNoteSyncMerge {
    @discardableResult
    static func apply(remote: WrongNoteEntry, to local: inout WrongNoteEntry) -> Bool {
        var changed = false
        if local.serverAttemptId != remote.serverAttemptId,
           let serverID = remote.serverAttemptId {
            local.serverAttemptId = serverID
            changed = true
        }

        guard let remoteRevision = remote.serverUpdatedAt else { return changed }
        if let applied = local.serverUpdatedAt, remoteRevision <= applied { return changed }

        local.wrongCount = max(local.wrongCount, remote.wrongCount)
        local.srsStage = max(local.srsStage, remote.srsStage)
        local.nextReviewAt = remote.nextReviewAt
        if local.errorType == nil { local.errorType = remote.errorType }
        if local.myAnswer == nil { local.myAnswer = remote.myAnswer }
        if local.choices == nil { local.choices = remote.choices }
        if local.isTex == nil { local.isTex = remote.isTex }
        local.serverUpdatedAt = remoteRevision
        return true
    }
}

/// 틀린 이유 분류 — 웹 wrongNoteService ERROR_LABELS 와 동일 어휘
enum WrongErrorType: String, CaseIterable, Identifiable {
    case calculationError = "calculation-error"
    case formulaConfusion = "formula-confusion"
    case missingCondition = "missing-condition"
    case signError = "sign-error"
    case conceptNotUnderstood = "concept-not-understood"
    case prerequisiteMissing = "prerequisite-missing"
    case unknown = "unknown"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .calculationError: return "계산 과정에서 실수"
        case .formulaConfusion: return "공식 적용이 헷갈림"
        case .missingCondition: return "문제 조건을 놓침"
        case .signError: return "부호 계산에서 실수"
        case .conceptNotUnderstood: return "핵심 개념 이해가 부족함"
        case .prerequisiteMissing: return "선행 개념 복습이 필요함"
        case .unknown: return "풀이 과정을 다시 확인해야 함"
        }
    }
}

enum WrongNoteSRS {
    /// 통과 후 다음 복습까지 간격 (일).
    ///
    /// stage 0 통과 → 1일 뒤 · 1 통과 → 3일 · 2 통과 → 7일 · 3 통과 → 14일 ·
    /// 복습 규칙 — **레포(웹)와 같아야 한다.**
    ///
    /// 웹 규칙은 단순하다: **복습에서 맞히면 그 자리에서 완료**,
    /// 틀리면 **다음 날 00:00(KST)** 로 예약. 단계 사다리가 없다.
    ///
    /// 앱은 여기에 1·3·7·14일 4연속 통과라는 자체 SRS 를 얹고 있었다.
    /// 그래서 같은 계정을 웹에서 보면 이미 '복습 완료'인 오답이
    /// 앱에서는 "단계 2/4" 로 남아 있었다 — **개수도 상태도 서로 달랐다.**
    /// 학습 설계로서 간격 반복이 더 나은지와는 별개로, 두 화면이 다른 말을
    /// 하는 것이 먼저 문제다. 진실원은 레포다.

    /// 다음 한국 날짜 00:00. 레포의 `setDate(getDate() + 1)` 에 대응한다.
    static func nextKSTMidnight(from now: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now
    }

    static func afterCorrect(_ entry: inout WrongNoteEntry) {
        // 한 번 맞히면 끝. (srsStage 는 서버 동기화 호환용으로만 올린다)
        entry.srsStage += 1
        entry.nextReviewAt = nil
    }

    static func afterWrong(_ entry: inout WrongNoteEntry) {
        entry.wrongCount += 1
        entry.nextReviewAt = nextKSTMidnight()   // 오늘 다시가 아니라 **내일 00:00**
    }
}

// MARK: - 저장 사고 알림 통로

/// 오답노트 저장 계층의 사고(파일 손상·저장 실패)를 화면으로 끌어올리는 통로.
///
/// 왜 AppStore 프로퍼티가 아니라 별도 싱글턴인가:
///   1. WrongNoteDisk.load() 는 AppStore **init 의 프로퍼티 초기화** 중에 돈다 —
///      그 시점에는 AppStore 인스턴스 자체가 아직 없다.
///   2. AppStore 쪽 wrongNoteStorageAlert 프로퍼티는 다른 작업선이 붙이는 중이라
///      직접 참조하면 두 변경이 컴파일 결합된다. 여기는 프로퍼티가 없어도 컴파일된다.
/// 화면(WrongNotesScreen)은 이 싱글턴을 직접 구독하고, AppStore 미러링은 아래
/// WrongNoteStorageAlertSink 를 AppStore 가 채택하는 한 줄로 나중에 붙는다.
final class WrongNoteStorageAlertCenter: ObservableObject {
    static let shared = WrongNoteStorageAlertCenter()

    /// nil = 사고 없음. 값이 있으면 오답노트 화면 상단에 한 줄 배너로 보인다.
    @Published var message: String?

    func raise(_ text: String) {
        // 뷰 업데이트 도중(reloadLocalData 등) 불릴 수 있다 — 항상 다음 턴에 메인에서 게시.
        // AppStoreLocator 가 @MainActor 라 Task { @MainActor } 로 호핑한다.
        Task { @MainActor in
            self.message = text
            // AppStore 가 sink 를 채택하면(extension AppStore: WrongNoteStorageAlertSink {})
            // 같은 값이 그쪽 @Published 에도 미러링된다. 채택 전에는 조용히 건너뛴다.
            let anyStore: AnyObject? = AppStoreLocator.shared
            (anyStore as? WrongNoteStorageAlertSink)?.wrongNoteStorageAlert = text
        }
    }

    func dismiss() {
        Task { @MainActor in
            self.message = nil
            let anyStore: AnyObject? = AppStoreLocator.shared
            (anyStore as? WrongNoteStorageAlertSink)?.wrongNoteStorageAlert = nil
        }
    }
}

/// AppStore 가 채택하는 느슨한 계약. 통로(위 싱글턴)는 이 프로토콜 **캐스트**로만
/// 스토어에 닿으므로, 채택 줄이 없어도 이 파일은 홀로 컴파일된다 —
/// 저장 계층과 스토어의 변경이 서로를 볼모로 잡지 않게 하기 위한 경계다.
/// (AppStore 가 @MainActor 라 프로토콜도 같은 격리로 맞춘다)
@MainActor
protocol WrongNoteStorageAlertSink: AnyObject {
    var wrongNoteStorageAlert: String? { get set }
}

/// 배선 — AppStore.wrongNoteStorageAlert(@Published)가 위 통로의 미러가 된다.
/// 오답노트 화면 배너는 통로와 스토어 프로퍼티를 **둘 다** 읽으므로(coalesce)
/// 어느 쪽에 세팅해도 학생에게 보인다.
extension AppStore: WrongNoteStorageAlertSink {}

enum WrongNoteDisk {
    /// 저장 래퍼 v2 — {version, entries}. 스키마가 또 바뀔 때 "무슨 형식인지 모른 채
    /// 디코드 실패 → 전체 소실" 사고를 반복하지 않기 위한 최소 장치다.
    /// 구형 파일(래퍼 없는 [WrongNoteEntry] 배열)은 아래 decode() 가 계속 읽는다 —
    /// 기존 사용자 데이터를 읽지 못하게 되는 변경은 금지.
    struct Envelope: Codable {
        var version: Int
        var entries: [WrongNoteEntry]
    }
    static let currentVersion = 2

    static var fileURL: URL { DataScope.url("wrongnotes.json") }
    /// 마지막으로 save 가 성공한 직전 세대 — 본 파일이 손상됐을 때의 복구 경로.
    static var backupURL: URL { DataScope.url("wrongnotes.bak") }

    static func load() -> [WrongNoteEntry] {
        let fm = FileManager.default
        // '파일 없음'은 정상 초기 상태 — 손상과 절대 같은 취급을 하면 안 된다.
        guard fm.fileExists(atPath: fileURL.path) else {
            // 단, 본 파일만 사라지고 직전 세대(.bak)가 남은 이상 상태면 백업으로 잇는다.
            // (정상 초기 상태에는 .bak 도 없으므로 그대로 [] 가 된다)
            if let bak = try? Data(contentsOf: backupURL), let list = decode(bak), !list.isEmpty {
                EventLog.append("wrongnote-storage-restored-from-backup")
                WrongNoteStorageAlertCenter.shared.raise(
                    "오답노트 파일이 사라져 직전 백업으로 복원했습니다.")
                save(list)   // 본 파일을 즉시 재구성 — 다음 실행이 또 빈 상태로 보이지 않게
                return list
            }
            return []
        }

        if let data = try? Data(contentsOf: fileURL), let list = decode(data) {
            return list
        }

        // 파일은 있는데 못 읽거나 디코드가 안 된다 — 예전에는 여기서 조용히 [] 를
        // 돌려줬고, 다음 save() 가 그 빈 목록으로 원본을 덮어써 필기 PNG 포함
        // 오답 전체가 영구 소실됐다(감사 F-04). 원본을 지우지 말고 옆으로 치워 보존한다.
        let preserved = preserveCorruptFile()
        EventLog.append("wrongnote-storage-corrupt")

        // 복구 시도: 직전 save 성공 세대(.bak)가 읽히면 그걸로 잇는다.
        if let bak = try? Data(contentsOf: backupURL), let list = decode(bak) {
            WrongNoteStorageAlertCenter.shared.raise(
                "오답노트 파일이 손상돼 직전 백업으로 복원했습니다."
                + (preserved != nil ? " 손상된 원본은 이 기기에 별도로 보관했습니다." : ""))
            // 즉시 재저장 — 여기서 앱이 죽어도 복원 상태가 디스크에 남게.
            // (손상 원본은 이미 corrupt-* 로 옮겨졌고, save 의 .bak 승격은
            //  본 파일이 없을 때 건너뛰므로 복원 원천인 .bak 은 그대로 보존된다)
            save(list)
            return list
        }

        WrongNoteStorageAlertCenter.shared.raise(
            "오답노트 파일이 손상돼 읽을 수 없습니다."
            + (preserved != nil ? " 원본은 이 기기에 별도로 보관했습니다." : "")
            + " 서버 계정이면 다음 동기화 때 서버 보관본에서 복원됩니다.")
        return []
    }

    /// 실패를 삼키지 않는 저장. 반환값을 무시해도 컴파일되지만(기존 호출부 보존),
    /// 실패는 배너·이벤트로 반드시 표면화된다 — "저장됐다고 보였는데 재실행하면
    /// 사라지는" 무통보 유실 금지.
    @discardableResult
    static func save(_ list: [WrongNoteEntry]) -> Bool {
        save(
            list,
            fileURL: fileURL,
            backupURL: backupURL,
            recordFailureEvent: true)
    }

    /// actor writer용 슬롯 고정 저장. `DataScope.url(_:for:)`를 호출부에서 캡처한
    /// 슬롯과 함께 써서 계정 전환 뒤 다른 학생 파일로 흘러가지 않게 한다.
    @discardableResult
    static func save(_ list: [WrongNoteEntry], for slot: String) -> Bool {
        save(
            list,
            fileURL: DataScope.url("wrongnotes.json", for: slot),
            backupURL: DataScope.url("wrongnotes.bak", for: slot),
            // EventLog의 공유 encoder는 메인 액터 호출 경로용이다. actor writer 실패는
            // NSLog+화면 배너로 드러내고 그 encoder를 다른 executor에서 건드리지 않는다.
            recordFailureEvent: false)
    }

    @discardableResult
    private static func save(
        _ list: [WrongNoteEntry],
        fileURL: URL,
        backupURL: URL,
        recordFailureEvent: Bool
    ) -> Bool {
        let fm = FileManager.default
        do {
            let data = try JSONEncoder().encode(Envelope(version: currentVersion, entries: list))

            // 1세대 백업 — 지금 자리에 있는 파일은 '마지막으로 save 가 성공한 세대'다
            // (손상 파일은 load() 가 이미 corrupt-* 로 치웠으므로 여기 올 수 없다).
            // APFS 클론 복사라 PNG 포함 대용량이어도 싸다.
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: backupURL)
                try? fm.copyItem(at: fileURL, to: backupURL)
            }

            // 임시 파일에 다 쓴 뒤 원자 교체 — 쓰다 만 바이트가 본 파일 자리를
            // 차지하는 순간(강제종료·디스크 부족)이 손상 사고의 진원이었다.
            let tmp = fileURL.deletingLastPathComponent()
                .appendingPathComponent("wrongnotes.tmp-\(UUID().uuidString).json")
            try data.write(to: tmp, options: .atomic)
            if fm.fileExists(atPath: fileURL.path) {
                _ = try fm.replaceItemAt(fileURL, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: fileURL)
            }
            return true
        } catch {
            if recordFailureEvent {
                EventLog.append("wrongnote-storage-save-failed")
            } else {
                NSLog("WRONGNOTE-STORAGE-ERROR actor 저장 실패: %@", error.localizedDescription)
            }
            WrongNoteStorageAlertCenter.shared.raise(
                "오답노트를 저장하지 못했습니다. 기기의 저장 공간을 확인한 뒤 다시 시도해 주세요.")
            return false
        }
    }

    /// 래퍼(v2) 우선, 실패하면 구형 배열(v1) — 구형 파일 마이그레이션 경로.
    /// 날짜 전략은 양쪽 다 JSONDecoder 기본값 — 기존 파일과 같은 규약이어야 읽힌다.
    private static func decode(_ data: Data) -> [WrongNoteEntry]? {
        let dec = JSONDecoder()
        if let env = try? dec.decode(Envelope.self, from: data) { return env.entries }
        if let list = try? dec.decode([WrongNoteEntry].self, from: data) { return list }
        return nil
    }

    /// 손상 파일을 wrongnotes.corrupt-<타임스탬프>.json 으로 rename 해 증거를 보존한다.
    /// 성공하면 보관 파일명을 돌려준다 (사용자 안내·수동 복구용).
    private static func preserveCorruptFile() -> String? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        // 콜론은 파일명에 부적합 — ISO 유사형에서 시각 구분자만 뺐다
        f.dateFormat = "yyyy-MM-dd'T'HHmmss"
        let name = "wrongnotes.corrupt-\(f.string(from: Date())).json"
        let dest = fileURL.deletingLastPathComponent().appendingPathComponent(name)
        do {
            try FileManager.default.moveItem(at: fileURL, to: dest)
            return name
        } catch {
            // rename 조차 실패(권한·디스크) — 원본은 자리에 남는다. 최소한 지우지는 않는다.
            return nil
        }
    }
}

// MARK: - 학습일 기록 (연속 학습일 · 주간 점)

enum ActivityLog {
    /// 계정 슬롯별로 나눈다 — 형제가 한 기기를 쓰면 앞사람 연속 학습일이
    /// 그대로 이어져 보인다(2026-07-29 감사 적발). 게스트는 옛 평평한 키 유지.
    static var key: String { AppStore.slotKey("matths.activityDays") }

    /// 하루 경계는 **KST·그레고리력** 하나로 고정한다.
    /// - 같은 파일의 SRS(nextKSTMidnight)·EventLog 주간 집계·웹이 전부 KST 기준인데
    ///   여기만 기기 로컬이라, 시간대가 다른 기기에서 "오늘 복습할 것"과
    ///   "오늘 학습함" 도장의 날짜가 어긋났다 (감사 B-04).
    /// - locale/calendar 고정이 없으면 기기 달력이 불교력·일본력일 때 "yyyy"가
    ///   2569 같은 키를 만들어 기존 키와 영원히 어긋난다 (스트릭 영구 오염).
    private static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        cal.firstWeekday = 2                              // 월요일 시작 (주간 점 표시용)
        return cal
    }()

    private static var formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayString(_ date: Date = Date()) -> String { formatter.string(from: date) }

    static func load() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func recordToday() -> Set<String> {
        var set = load()
        set.insert(dayString())
        UserDefaults.standard.set(Array(set).sorted(), forKey: key)
        return set
    }

    /// 오늘(또는 오늘 활동이 아직 없으면 어제)에서 거꾸로 이어지는 연속 일수.
    /// 날짜 산술은 86,400초 뺄셈이 아니라 같은 달력의 date(byAdding:) —
    /// 초 뺄셈은 DST 있는 시간대에서 하루 경계를 비켜간다 (감사 B-04).
    static func streak(from set: Set<String>) -> Int {
        var count = 0
        var cursor = Date()
        if !set.contains(dayString(cursor)) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = prev                                 // 오늘 아직 안 했으면 어제부터
        }
        while set.contains(dayString(cursor)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// 이번 주(월~일) 각 요일의 활동 여부 — 주 경계도 KST 달력 하나로
    static func thisWeek(from set: Set<String>) -> [Bool] {
        let today = Date()
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return Array(repeating: false, count: 7)
        }
        return (0..<7).map { i in
            guard let day = calendar.date(byAdding: .day, value: i, to: interval.start) else {
                return false
            }
            return set.contains(dayString(day))
        }
    }

    /// 이번 주에서 오늘의 인덱스 (월=0)
    static func todayIndex() -> Int {
        let weekday = calendar.component(.weekday, from: Date())   // 일=1 … 토=7
        return (weekday + 5) % 7
    }
}
