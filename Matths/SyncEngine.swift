//  SyncEngine.swift
//  Matths
//
//  로컬 우선 동기화 — 앱은 언제나 로컬에 먼저 쓰고, 서버 전송은 큐에 쌓아
//  온라인일 때 순차로 올린다. 비행기 모드에서도 학습이 멈추지 않아야 한다.
//
//  규약
//   - 멱등: 모든 작업에 클라이언트가 만든 id 를 실어 보낸다. 같은 큐를 두 번
//     올려도 서버가 걸러낸다(서버 ipadSyncController 와 짝).
//   - 단조: 진도·유형 게이트는 더하기만 한다. 어느 쪽도 상대의 성과를 지우지 않는다.
//   - 게이트는 둘로 갈라 본다 (S-02·B-09 감사 반영):
//       적재(enqueue) = 계정 정체성(isServerAccountSlot) — 게스트는 아무것도 쌓지 않는다.
//       전송(flush/pull) = 정체성 + 키체인 토큰(canReachServer).
//     토큰 존재만으로 게이트하면 안 된다: 키체인은 앱 삭제 후에도 살아남아
//     재설치한 게스트가 이전 계정 토큰으로 오르내리는 계정 간 오염이 생기고,
//     반대로 401 만료 구간에는 기록이 큐에도 못 쌓여 영구 유실된다.
//   - 계정 격리: 큐는 슬롯(계정)별 파일이고, 메모리 큐도 슬롯이 바뀌면 갈아끼운다.
//     앞 계정의 op 를 뒷 계정 토큰으로 올리면 남의 기록이 된다.
//   - 큐는 Documents/slots/<슬롯>/sync-queue.jsonl (append-only). 앱을 꺼도 남는다.
//   - 독성 op 는 sync-deadletter.jsonl 로 격리한다(버리지 않는다 — 증거·수동 재생 여지).
//   - 서버→로컬 pull 은 onRemoteWrongNotes 수신부가 걸려 있을 때만 돈다
//     (받아 줄 곳 없이 커서만 밀면 그 구간 오답을 영영 못 받는다).

import Foundation
import Network
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 큐 항목

struct SyncOp: Codable, Identifiable, Sendable {
    enum Kind: String, Codable {
        case mastery        // 유형 게이트 적립
        case topic          // 토픽 체크/해제
        case progressSnapshot // 게스트→계정 진도 무이벤트 병합
        case event          // 학습 이벤트
        case gradingBatch   // 평가·기출 여러 문항의 정오 이벤트
        case wrongNote      // 오답 적재
        case reviewResult   // 복습 결과(SRS)
        case stuckPoint     // 보호 화면 캡처 뒤 학생이 적은 막힌 지점
        case progressReset  // 계정 진도 초기화(요청 시각 이전만)
    }
    var id: String = UUID().uuidString
    var kind: Kind
    var payload: [String: SyncValue]
    var createdAt: Date = Date()
    /// 이 op 를 만든 계정 슬롯(DataScope.slot). 계정이 바뀐 뒤 남아 있던 op 가
    /// 뒷사람 토큰으로 올라가지 않게 하는 표식이다. 슬롯 이름이 acct-<이메일 해시>라
    /// 사실상 계정 식별자다 — flush 직전 belongsToCurrentAccount 가 대조한다.
    /// 옵셔널인 이유: 이 필드가 없던 시절의 큐 파일도 그대로 읽혀야 한다.
    var slot: String?
    /// 서버가 영구 거부(4xx)한 횟수. 상한을 넘으면 deadletter 로 격리된다 —
    /// 독성 op 하나가 FIFO 맨 앞에서 뒤의 모든 기록 전송을 영원히 막지 않게 (B-09).
    /// 옵셔널인 이유: slot 과 같다(구 큐 파일 호환).
    var attemptCount: Int?
}

/// JSON 한 겹만 담으면 되므로 최소 타입만 지원한다 (Codable 을 위해 필요)
enum SyncValue: Codable, Sendable {
    case s(String), i(Int), b(Bool), sa([String]), ia([Int])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .s(v); return }
        if let v = try? c.decode(Int.self) { self = .i(v); return }
        if let v = try? c.decode(Bool.self) { self = .b(v); return }
        if let v = try? c.decode([String].self) { self = .sa(v); return }
        if let v = try? c.decode([Int].self) { self = .ia(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "지원하지 않는 값")
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .s(let v): try c.encode(v)
        case .i(let v): try c.encode(v)
        case .b(let v): try c.encode(v)
        case .sa(let v): try c.encode(v)
        case .ia(let v): try c.encode(v)
        }
    }
    var any: Any {
        switch self {
        case .s(let v): return v
        case .i(let v): return v
        case .b(let v): return v
        case .sa(let v): return v
        case .ia(let v): return v
        }
    }
}

private struct SyncQueueLoadResult: Sendable {
    let ops: [SyncOp]
    let badLines: [String]

    var quarantined: Int { badLines.count }
}

private struct SyncDeadLetterRecord: Codable, Sendable {
    var statusCode: Int
    var quarantinedAt: Date
    var op: SyncOp
}

private struct SyncJournalSnapshot: Sendable {
    let operations: [SyncOp]
    let quarantinedLines: Int
    let deadLettered: Int
}

/// JSONL codec 자체는 상태를 갖지 않는다. 제품 쓰기는 반드시 `SyncQueueJournal` actor가
/// 호출하며, DEBUG 실기 probe만 임시 URL에 동기로 사용한다.
private enum SyncQueueDiskCodec {
    static func loadQueue(at url: URL) -> SyncQueueLoadResult {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return SyncQueueLoadResult(ops: [], badLines: [])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var ops: [SyncOp] = []
        var badLines: [String] = []
        for line in text.split(separator: "\n") {
            if let data = line.data(using: .utf8),
               let op = try? decoder.decode(SyncOp.self, from: data) {
                ops.append(op)
            } else {
                badLines.append(String(line))
            }
        }
        return SyncQueueLoadResult(ops: ops, badLines: badLines)
    }

    static func append(_ operations: [SyncOp], to url: URL) -> Bool {
        guard !operations.isEmpty else { return true }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var blob = Data()
        for operation in operations {
            guard let line = try? encoder.encode(operation) else { return false }
            blob.append(line)
            blob.append(0x0A)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: blob)
                return true
            } catch {
                return false
            }
        }
        return (try? blob.write(to: url)) != nil
    }

    static func rewrite(_ operations: [SyncOp], at url: URL) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var blob = Data()
        for operation in operations {
            guard let line = try? encoder.encode(operation) else { return false }
            blob.append(line)
            blob.append(0x0A)
        }
        return (try? blob.write(to: url, options: .atomic)) != nil
    }

    static func appendRawLines(_ lines: [String], to url: URL) -> Bool {
        guard !lines.isEmpty else { return true }
        let blob = Data((lines.joined(separator: "\n") + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: blob)
                return true
            } catch {
                return false
            }
        }
        return (try? blob.write(to: url)) != nil
    }

    static func appendDeadLetter(_ operation: SyncOp, statusCode: Int, to url: URL) -> Bool {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let record = SyncDeadLetterRecord(
            statusCode: statusCode, quarantinedAt: Date(), op: operation)
        guard let line = try? encoder.encode(record),
              let text = String(data: line, encoding: .utf8) else { return false }
        return appendRawLines([text], to: url)
    }

    static func lineCount(at url: URL) -> Int {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return 0 }
        return text.split(separator: "\n").count
    }
}

/// 계정별 sync journal의 유일한 쓰기 실행자.
///
/// 호출부는 owner slot에서 URL과 메모리 FIFO snapshot을 먼저 캡처한다. append가 일부만
/// 쓰고 실패했을 가능성이 있으면 다음 호출은 append를 반복하지 않고 전체 snapshot을
/// atomic rewrite해 중복/구멍을 함께 복구한다.
private actor SyncQueueJournal {
    static let shared = SyncQueueJournal()

    private struct State {
        var durableQueue: [SyncOp]
        /// append/rewrite 실패 뒤 actor가 재시도할 완전한 논리 FIFO.
        var pendingQueue: [SyncOp]?
        var quarantinedLines: Int
        var deadLettered: Int
    }

    /// Foundation URL은 대상이 디렉터리인지에 따라 같은 path도 trailing slash가 붙어
    /// hash identity가 달라질 수 있다. 실패 주입/복구 사이에도 변하지 않는 owner slot을
    /// actor cache key로 써 pendingQueue가 새 빈 state로 갈아끼워지지 않게 한다.
    private var states: [String: State] = [:]
    private var invalidatedSlots: Set<String> = []

    func append(_ operations: [SyncOp], for slot: String) -> Bool {
        guard !invalidatedSlots.contains(slot) else { return false }
        let queueURL = Self.queueURL(for: slot)
        var state = loadIfNeeded(slot: slot, queueURL: queueURL)
        let base = state.pendingQueue ?? state.durableQueue
        var existingIDs = Set(base.map(\.id))
        let additions = operations.filter { existingIDs.insert($0.id).inserted }
        let candidate = base + additions

        // 앞 write가 실패했으면 부분 append 여부를 추측하지 않고 완전한 FIFO를 atomic
        // rewrite한다. 정상 경로는 새 batch 한 번만 append한다.
        let succeeded: Bool
        if state.pendingQueue != nil {
            succeeded = SyncQueueDiskCodec.rewrite(candidate, at: queueURL)
        } else {
            succeeded = SyncQueueDiskCodec.append(additions, to: queueURL)
        }
        if succeeded {
            state.durableQueue = candidate
            state.pendingQueue = nil
        } else {
            state.pendingQueue = candidate
        }
        states[slot] = state
        return succeeded
    }

    func replace(with operations: [SyncOp], for slot: String) -> Bool {
        guard !invalidatedSlots.contains(slot) else { return false }
        let queueURL = Self.queueURL(for: slot)
        var state = loadIfNeeded(slot: slot, queueURL: queueURL)
        let succeeded = SyncQueueDiskCodec.rewrite(operations, at: queueURL)
        if succeeded {
            state.durableQueue = operations
            state.pendingQueue = nil
        }
        states[slot] = state
        return succeeded
    }

    func flushPending(for slot: String) -> Bool {
        guard !invalidatedSlots.contains(slot) else { return false }
        let queueURL = Self.queueURL(for: slot)
        var state = loadIfNeeded(slot: slot, queueURL: queueURL)
        guard let pending = state.pendingQueue else { return true }
        let succeeded = SyncQueueDiskCodec.rewrite(pending, at: queueURL)
        if succeeded {
            state.durableQueue = pending
            state.pendingQueue = nil
            states[slot] = state
        }
        return succeeded
    }

    func snapshot(for slot: String) -> SyncJournalSnapshot? {
        guard !invalidatedSlots.contains(slot) else { return nil }
        let queueURL = Self.queueURL(for: slot)
        let state = loadIfNeeded(slot: slot, queueURL: queueURL)
        return SyncJournalSnapshot(
            operations: state.durableQueue,
            quarantinedLines: state.quarantinedLines,
            deadLettered: state.deadLettered)
    }

    /// deadletter가 실제로 남고 queue rewrite도 끝난 경우에만 true다. 어느 쪽이든
    /// 실패하면 MainActor 메모리 FIFO는 원래 head를 유지해 다음 sync에서 재시도한다.
    func quarantine(_ operation: SyncOp,
                    statusCode: Int,
                    remainingQueue: [SyncOp],
                    for slot: String) -> Bool {
        guard !invalidatedSlots.contains(slot) else { return false }
        let queueURL = Self.queueURL(for: slot)
        let deadLetterURL = Self.deadLetterURL(for: slot)
        var state = loadIfNeeded(slot: slot, queueURL: queueURL)
        guard SyncQueueDiskCodec.appendDeadLetter(
            operation, statusCode: statusCode, to: deadLetterURL) else { return false }
        let succeeded = SyncQueueDiskCodec.rewrite(remainingQueue, at: queueURL)
        if succeeded {
            state.durableQueue = remainingQueue
            state.pendingQueue = nil
            state.deadLettered += 1
            states[slot] = state
        }
        return succeeded
    }

    func invalidate(slot: String) {
        invalidatedSlots.insert(slot)
        states.removeValue(forKey: slot)
    }

    func activate(slot: String) {
        invalidatedSlots.remove(slot)
        states.removeValue(forKey: slot)
        // 명시적 재가입/활성화만 새 슬롯 디렉터리를 만들 수 있다. invalidate는 이
        // 경로를 호출하지 않아 purge 뒤 늦은 작업이 디렉터리를 되살리지 않는다.
        _ = Self.queueURL(for: slot)
    }

    /// `DataScope.url(_:for:)`는 디렉터리 존재 검사·생성을 포함한다. 이 actor 안에서만
    /// 호출해 첫 채점/계정 전환에도 MainActor 파일 시스템 I/O가 남지 않게 한다.
    private static func queueURL(for slot: String) -> URL {
        DataScope.url("sync-queue.jsonl", for: slot)
    }

    private static func deadLetterURL(for slot: String) -> URL {
        DataScope.url("sync-deadletter.jsonl", for: slot)
    }

    private func loadIfNeeded(slot: String, queueURL: URL) -> State {
        if let state = states[slot] { return state }
        let loaded = SyncQueueDiskCodec.loadQueue(at: queueURL)
        let quarantineURL = queueURL.deletingLastPathComponent()
            .appendingPathComponent("sync-queue.quarantine.jsonl")
        if !loaded.badLines.isEmpty,
           !SyncQueueDiskCodec.appendRawLines(loaded.badLines, to: quarantineURL) {
            NSLog("SYNC-QUARANTINE-ERROR 격리 파일 쓰기 실패: %@",
                  quarantineURL.lastPathComponent)
        }
        let deadLetterURL = queueURL.deletingLastPathComponent()
            .appendingPathComponent("sync-deadletter.jsonl")
        let state = State(
            durableQueue: loaded.ops,
            pendingQueue: nil,
            quarantinedLines: loaded.quarantined,
            deadLettered: SyncQueueDiskCodec.lineCount(at: deadLetterURL))
        states[slot] = state
        return state
    }
}

// MARK: - 엔진

/// 같은 이메일은 같은 물리 슬롯을 다시 쓰므로 slot 문자열만으로는 네트워크 응답의
/// 세션 소유권을 증명할 수 없다. AppStore가 성공한 로그인/로그아웃마다 새 generation을
/// 발급하고, SyncEngine은 요청 시작부터 callback 완료까지 이 값도 함께 검증한다.
struct SyncAccountOwner: Equatable, Sendable {
    let slot: String
    let sessionGeneration: UUID
}

@MainActor
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published private(set) var pending = 0
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastError: String?
    /// deadletter 로 격리된 op 수 — pending 과 분리해 노출한다.
    /// "대기 N건" 에 섞으면 영영 안 올라갈 건수가 곧 올라갈 것처럼 보인다.
    @Published private(set) var deadLettered = 0
    /// 큐 파일에서 디코딩에 실패해 격리 보존된 줄 수 — 0 이 아니면 학습 기록
    /// 일부가 서버에 못 올라간 상태라는 뜻이다(관찰 가능해야 복구도 한다).
    @Published private(set) var quarantinedLines = 0

    private var queue: [SyncOp] = []
    private var flushing = false
    private var pulling = false
    private var progressPulling = false
    private var stuckPointPulling = false
    private var lastPullAt: Date?

    /// 같은 실행 안의 A→B→A에서 A의 actor append가 끝나기 전에 메모리 큐를 버리지
    /// 않는다. 물리 슬롯별 상태를 보관했다가 돌아오면 그대로 이어 쓴다.
    private struct CachedQueueState {
        var queue: [SyncOp]
        var quarantinedLines: Int
        var deadLettered: Int
    }
    private var cachedQueueStates: [String: CachedQueueState] = [:]
    private var hydratedJournalSlots: Set<String> = []
    private var invalidatedJournalSlots: Set<String> = []

    /// 슬롯별 journal tail. 각 Task는 직전 tail을 먼저 기다리므로 독립 Task들의 actor
    /// mailbox 도착 순서에 기대지 않는다. 실제 encode/write는 SyncQueueJournal actor다.
    private struct JournalBoundary {
        let id: UUID
        let task: Task<Bool, Never>
    }
    private var journalBoundaries: [String: JournalBoundary] = [:]

    /// 지금 메모리에 들고 있는 큐의 주인 슬롯. DataScope.slot 과 어긋나면
    /// 로그아웃·계정 전환이 있었다는 뜻이라 큐를 통째로 갈아끼운다.
    private var loadedSlot: String = DataScope.slot
    /// A→guest→A처럼 같은 물리 슬롯으로 돌아와도 새 세션이면 큐 메모리를 다시 읽는다.
    private var loadedSessionGeneration: UUID?

    /// 깨우기 타이머·경로 감시 — 오프라인에 쌓인 큐가 "다음 채점" 까지 잠들지 않게 한다.
    /// 둘 다 프로퍼티로 붙들어 둔다(지역 변수로 두면 감시가 곧바로 사라진다).
    private var wakeTimer: Timer?
    private let pathMonitor = NWPathMonitor()

    /// (clientAttemptId, serverAttemptId) — AppStore 가 오답노트에 적어 넣는다.
    /// SyncEngine 이 오답노트 배열을 직접 만지지 않게 하려고 콜백으로 뺐다.
    var onServerID: ((String, String, SyncAccountOwner) -> Void)?

    /// 서버에서 내려온 오답을 로컬 오답노트에 합쳐 넣는 수신부(AppStore 가 건다).
    /// 오답노트 배열의 주인은 AppStore 다 — SyncEngine 이 디스크에 직접 쓰면
    /// AppStore 가 들고 있던 옛 배열을 다음 저장 때 덮어써 pull 한 것이 사라진다.
    /// Bool 은 캡처한 owner 슬롯 파일까지 실제 저장됐다는 ack다. 이 ack 전에 pull
    /// cursor를 전진시키면 앱 종료 때 해당 구간 오답을 영구히 건너뛸 수 있다.
    var onRemoteWrongNotes: (([WrongNoteEntry], SyncAccountOwner) async -> Bool)?
    /// 서버 진도 수신부 — AppStore 가 합친다(덮지 않는다).
    /// 오답과 같은 규약: 받는 쪽이 걸려 있을 때만 pull 한다.
    var onRemoteProgress: (([ServerAPI.RemoteConceptProgress], SyncAccountOwner) -> Void)?
    var onRemoteStuckPoints: (([ServerAPI.RemoteStuckPoint], SyncAccountOwner) -> Void)?

    /// AppStore가 가진 성공 세션 generation의 단일 진실 공급자. SyncEngine init 시점에는
    /// AppStore가 아직 없을 수 있어 optional이며, wire 완료 전에는 네트워크를 시작하지 않는다.
    var captureAccountOwner: (() -> SyncAccountOwner?)?

    // MARK: 게이트 (모든 guard 는 이 두 프로퍼티만 본다 — S-02 단일화)

    /// 적재 게이트 — **계정 정체성**. 지금 슬롯이 서버 계정인가.
    /// ServerAPI.hasToken 으로 게이트하면 안 되는 이유:
    ///  - 키체인 토큰은 앱 삭제 후에도 살아남는다. 재설치 후 게스트로 들어온 기기에서
    ///    토큰만 보고 통과시키면 게스트 기록이 이전 계정으로 올라가고, 이전 계정의
    ///    오답·진도가 게스트 슬롯으로 내려온다 — 양방향 계정 오염 (S-02).
    ///  - 401 로 토큰이 지워진 만료 구간에는 계정은 그대로인데 기록이 큐에도 못 쌓여
    ///    영구 유실된다 (B-09). 만료 중에도 쌓고, 보내는 것만 멈추면 된다.
    private var isServerAccountSlot: Bool { DataScope.slot != "guest" }

    /// 전송 게이트 — 정체성 + 토큰. 토큰이 없으면(만료) 큐를 지키며 기다린다.
    private var canReachServer: Bool { isServerAccountSlot && ServerAPI.hasToken }

    private func currentAccountOwner() -> SyncAccountOwner? {
        guard let owner = captureAccountOwner?(), owner.slot == DataScope.slot else { return nil }
        return owner
    }

    private func isCurrentAccountOwner(_ owner: SyncAccountOwner) -> Bool {
        currentAccountOwner() == owner
    }

    /// 동기화 실패는 프로필 화면에 그대로 노출된다. Foundation/NSError 원문에는
    /// 샌드박스 경로, 내부 도메인, 기계 오류 코드가 섞일 수 있으므로 UI 상태에는
    /// 복구 행동만 저장하고 원문은 개발 빌드 로그에만 남긴다.
    private func userFacingSyncFailure(_ error: Error) -> String {
        #if DEBUG
        print("학습 기록 동기화 실패:", error)
        #endif

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .dataNotAllowed,
                 .internationalRoamingOff:
                return "인터넷 연결을 확인하면 학습 기록을 자동으로 다시 동기화합니다."
            case .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .secureConnectionFailed:
                return "서버에 연결하지 못했습니다. 잠시 후 자동으로 다시 시도합니다."
            default:
                break
            }
        }

        if let serverError = error as? ServerAPIError {
            switch serverError.statusCode {
            case 401:
                return "로그인이 만료되었습니다. 다시 로그인하면 학습 기록을 동기화합니다."
            case 408:
                return "동기화 시간이 초과되었습니다. 잠시 후 자동으로 다시 시도합니다."
            case 429:
                return "요청이 많아 동기화를 잠시 미뤘습니다. 자동으로 다시 시도합니다."
            case let status? where (500...599).contains(status):
                return "서버가 잠시 응답하지 않습니다. 학습 기록은 보관되며 자동으로 다시 시도합니다."
            default:
                return serverError.errorDescription
                    ?? "학습 기록을 동기화하지 못했습니다. 잠시 후 자동으로 다시 시도합니다."
            }
        }

        return "학습 기록을 동기화하지 못했습니다. 잠시 후 자동으로 다시 시도합니다."
    }

    /// 독성 4xx 허용 재시도 상한 — 이 횟수를 **초과**하면 deadletter 로 격리한다.
    private static let maxToxicAttempts = 3

    private init() {
        // actor init에서는 await할 수 없다. 디스크 load/decode도 MainActor에서 하지 않고,
        // owner callback이 연결된 뒤 첫 syncNow/flush가 actor snapshot을 병합한다.
        queue = []
        pending = 0
        quarantinedLines = 0
        deadLettered = 0
        cachedQueueStates[loadedSlot] = CachedQueueState(
            queue: queue,
            quarantinedLines: quarantinedLines,
            deadLettered: deadLettered)
        startWakeups()
        // 앱을 껐다 켠 경우 — 세션은 UserDefaults 에서 곧장 복원되므로 로그인 경로를
        // 다시 타지 않는다. 여기서 한 번 밀어 올리지 않으면 어제 오프라인에서 쌓인
        // 큐가 다음 채점 전까지 그대로 잠들어 있다.
        Task { await syncNow() }
    }

    // MARK: 깨우기 (전송 기회)

    /// 큐는 "쌓일 때" 말고도 올라갈 기회가 있어야 한다.
    ///  - 포그라운드 복귀: 비행기 모드로 공부하다 나갔다 돌아온 순간
    ///  - 네트워크 복구: 온라인이 되는 즉시
    ///  - 60초 타이머: 앱을 켠 채 로그인만 한 경우(계정 전환 직후 pull 포함)
    private func startWakeups() {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in await SyncEngine.shared.syncNow() }
        }
        #endif

        pathMonitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await SyncEngine.shared.syncNow() }
        }
        pathMonitor.start(queue: DispatchQueue(label: "kr.matths.sync.path"))

        // 화면이 떠 있는 동안만 도는 런루프 타이머다(백그라운드에서는 멈춘다).
        // 큐가 비어 있으면 flush 가 즉시 되돌아오고 pull 은 간격 제한에 걸려,
        // 평소에는 사실상 아무 일도 하지 않는다.
        wakeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in await SyncEngine.shared.syncNow() }
        }
    }

    /// 올릴 것을 올리고, 내려받을 것을 내려받는다.
    func syncNow() async {
        await flush()
        await pullWrongNotes()
        await pullProgress()
        await pullStuckPoints()
    }

    /// 네트워크 왕복 없이, 호출 시점까지의 현재 owner FIFO가 actor disk ack를 받을
    /// 때까지만 기다린다. background assertion·계정 전환·파괴적 reset의 내구 경계다.
    @discardableResult
    func flushLocalQueuePersistence() async -> Bool {
        if DataScope.slot == "guest" { return true }
        syncSlotIfNeeded()
        guard let owner = currentAccountOwner(),
              loadedSessionGeneration == owner.sessionGeneration else { return false }
        return await ensureJournalDurable(for: owner)
    }

    /// 탈퇴 purge 전에 source slot ingress를 먼저 닫고, 이미 발행된 tail을 drain한 뒤
    /// actor URL을 tombstone한다. 반환 뒤 늦은 append/rewrite가 삭제 디렉터리를 부활시키지 못한다.
    func invalidateLocalQueuePersistence(for slot: String) async {
        invalidatedJournalSlots.insert(slot)
        // gate를 닫기 직전에 이미 예약된 tail까지 모두 drain한다. 모든 schedule helper도
        // invalidated gate를 확인하므로 이 loop가 안정된 뒤에는 새 I/O가 붙을 수 없다.
        while let capturedBoundary = journalBoundaries[slot] {
            _ = await capturedBoundary.task.value
            guard journalBoundaries[slot]?.id == capturedBoundary.id else { continue }
            journalBoundaries.removeValue(forKey: slot)
        }
        await SyncQueueJournal.shared.invalidate(slot: slot)
        cachedQueueStates.removeValue(forKey: slot)
        hydratedJournalSlots.remove(slot)
        if loadedSlot == slot {
            queue = []
            pending = 0
            quarantinedLines = 0
            deadLettered = 0
        }
    }

    /// 탈퇴한 이메일로 새 계정을 만든 경우에만 명시적으로 다시 연다. actor가 기존
    /// 메모리 snapshot을 버리고 새 디렉터리를 처음부터 load하게 한 뒤 ingress를 연다.
    func activateLocalQueuePersistence(for slot: String) async {
        await SyncQueueJournal.shared.activate(slot: slot)
        invalidatedJournalSlots.remove(slot)
        cachedQueueStates.removeValue(forKey: slot)
        hydratedJournalSlots.remove(slot)
    }

    func pullStuckPoints() async {
        guard let handler = onRemoteStuckPoints else { return }
        guard canReachServer, !stuckPointPulling else { return }
        guard let owner = currentAccountOwner(),
              let authorization = ServerAPI.captureAuthorization() else { return }
        stuckPointPulling = true
        defer { stuckPointPulling = false }
        do {
            let rows = try await ServerAPI.getStuckPoints(authorization: authorization)
            guard isCurrentAccountOwner(owner) else { return }
            handler(rows, owner)
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            guard isCurrentAccountOwner(owner) else { return }
            lastError = userFacingSyncFailure(error)
        }
    }

    /// 서버가 가진 진도를 받아 온다 — 올리기만 하던 단방향을 닫는다.
    /// 합치는 일은 AppStore(onRemoteProgress)가 한다.
    func pullProgress() async {
        guard let handler = onRemoteProgress else { return }
        // canReachServer: 게스트 슬롯 + 잔존 토큰 조합으로 이전 계정의 진도를
        // 게스트 슬롯에 붓는 경로를 막는다 (S-02).
        guard canReachServer, !progressPulling else { return }
        guard let owner = currentAccountOwner(),
              let authorization = ServerAPI.captureAuthorization() else { return }
        progressPulling = true
        defer { progressPulling = false }
        do {
            let rows = try await ServerAPI.getLearning(authorization: authorization)
            // 응답을 기다리는 사이 계정이 바뀌었으면 다른 사람 진도를 합치지 않는다.
            guard isCurrentAccountOwner(owner) else { return }
            if !rows.isEmpty { handler(rows, owner) }
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            guard isCurrentAccountOwner(owner) else { return }
            lastError = userFacingSyncFailure(error)
        }
    }

    /// 메모리 큐의 주인이 현재 계정이 아니면 현재 슬롯 파일로 갈아끼운다.
    /// 앞 계정 op 는 그쪽 슬롯 파일에 그대로 남아, 다시 로그인하면 이어서 올라간다.
    private func syncSlotIfNeeded() {
        guard let owner = currentAccountOwner() else { return }
        guard loadedSlot != owner.slot
                || loadedSessionGeneration != owner.sessionGeneration else { return }

        // 같은 물리 슬롯의 새 세션이면 현재 메모리 FIFO가 이미 가장 최신이다. 디스크
        // append tail을 기다리지 않고 옛 파일을 다시 읽으면 방금 enqueue한 항목이 사라진다.
        if loadedSlot == owner.slot {
            loadedSessionGeneration = owner.sessionGeneration
            lastPullAt = nil
            return
        }

        cachedQueueStates[loadedSlot] = CachedQueueState(
            queue: queue,
            quarantinedLines: quarantinedLines,
            deadLettered: deadLettered)
        loadedSlot = owner.slot
        loadedSessionGeneration = owner.sessionGeneration
        if let cached = cachedQueueStates[owner.slot] {
            queue = cached.queue
            quarantinedLines = cached.quarantinedLines
            deadLettered = cached.deadLettered
        } else {
            // 첫 enqueue 버튼에서 disk read/decode를 하지 않는다. actor snapshot은 아래
            // flushLocalQueuePersistence/flush의 첫 await에서 ID 병합한다.
            queue = []
            quarantinedLines = 0
            deadLettered = 0
            cachedQueueStates[owner.slot] = CachedQueueState(
                queue: queue,
                quarantinedLines: quarantinedLines,
                deadLettered: deadLettered)
        }
        pending = queue.count
        lastPullAt = nil        // 새 계정이니 pull 간격 제한을 처음부터 다시 센다
    }

    /// 이 op 가 지금 로그인된 계정의 것인가 (아니면 보내지 않는다)
    private func belongsToCurrentAccount(_ op: SyncOp) -> Bool {
        guard let owner = currentAccountOwner() else { return false }
        return loadedSlot == owner.slot
            && loadedSessionGeneration == owner.sessionGeneration
            && (op.slot ?? loadedSlot) == owner.slot
    }

    // MARK: 적재 (호출부는 이것만 쓴다)

    /// 유형 게이트 — 개념 연습에서 새 유형을 맞혔을 때
    func enqueueMastery(courseId: String, unitId: String, conceptId: String, typeKey: String) {
        enqueueMasteryUpdate(courseId: courseId, unitId: unitId, conceptId: conceptId,
                             addTypeIds: [typeKey], userCompleted: false)
    }

    /// 학생이 유형 게이트를 채운 뒤 누른 최종 완료 체크(90% → 100%).
    func enqueueConceptCompletion(courseId: String, unitId: String, conceptId: String) {
        enqueueMasteryUpdate(courseId: courseId, unitId: unitId, conceptId: conceptId,
                             addTypeIds: [], userCompleted: true)
    }

    private func enqueueMasteryUpdate(courseId: String, unitId: String, conceptId: String,
                                      addTypeIds: [String], userCompleted: Bool) {
        var payload: [String: SyncValue] = [
            "courseId": .s(courseId), "unitId": .s(unitId),
            "conceptId": .s(conceptId),
        ]
        if !addTypeIds.isEmpty { payload["addTypeIds"] = .sa(addTypeIds) }
        if userCompleted { payload["userCompleted"] = .b(true) }
        enqueue(.init(kind: .mastery, payload: payload))
    }

    /// 토픽 체크 — 로컬에 먼저 반영한 뒤 이 큐가 웹의 공식 진도 문서에 저장한다.
    func enqueueTopic(courseId: String, unitId: String, conceptId: String,
                      topicIndex: Int, completed: Bool) {
        enqueue(.init(kind: .topic, payload: [
            "courseId": .s(courseId), "unitId": .s(unitId),
            "conceptId": .s(conceptId), "topicIndex": .i(topicIndex),
            "completed": .b(completed),
        ]))
    }

    /// 학습 이벤트 — EventLog 와 같은 어휘(서버 enum 과 일치하는 것만 보낸다)
    func enqueueEvent(_ type: String, conceptId: String?, correct: Bool?, durationMs: Int?) {
        var p: [String: SyncValue] = ["eventType": .s(type), "clientEventId": .s(UUID().uuidString)]
        if let c = conceptId { p["conceptId"] = .s(c) }
        if let ok = correct { p["correct"] = .b(ok) }
        if let d = durationMs { p["durationMs"] = .i(d) }
        enqueue(.init(kind: .event, payload: p))
    }

    /// 보호 화면에서 발생한 캡처 신호를 일반 학습 KPI와 섞지 않고 같은 내구성 큐로
    /// 전송한다. 게스트는 로컬 EventLog에만 남고, 서버 계정은 오프라인이어도 계정별
    /// 큐에 보존되어 재로그인·네트워크 복구 뒤 올라간다. 화면 이름과 실행 코드는
    /// 여기서도 다시 정제해 계정명·이메일·경기 ID가 payload에 섞이지 않게 한다.
    func enqueueIntegrityEvent(_ type: String, sessionCode: String, surface: String) {
        guard let eventType = ScreenIntegrityEventContract.normalizedEventType(type) else { return }
        enqueue(.init(kind: .event, payload: [
            "eventType": .s(eventType),
            "clientEventId": .s(UUID().uuidString),
            "integritySessionCode": .s(
                ScreenIntegrityEventContract.normalizedSessionCode(sessionCode)),
            "protectedSurface": .s(
                ScreenIntegrityEventContract.normalizedSurface(surface)),
        ]))
    }

    /// 평가·기출의 여러 문항을 HTTP 한 번으로 올린다. 한 문항당 큐/요청 하나를
    /// 만들지 않으면서 서버 대시보드에는 일반 연습과 같은 정오 이벤트로 남긴다.
    func enqueueGradingEvents(correct: Int, total: Int, durationMs: Int? = nil) {
        let safeTotal = max(0, total)
        guard safeTotal > 0 else { return }
        var payload: [String: SyncValue] = [
            "correctCount": .i(min(max(0, correct), safeTotal)),
            "totalCount": .i(safeTotal),
        ]
        if let durationMs { payload["durationMs"] = .i(max(0, durationMs)) }
        enqueue(.init(kind: .gradingBatch, payload: payload))
    }

    /// 오답 적재 — 로컬 오답노트에 새로 들어온 항목
    func enqueueWrongNote(_ note: WrongNoteEntry) {
        enqueue(wrongNoteOp(note))
    }

    private func wrongNoteOp(_ note: WrongNoteEntry) -> SyncOp {
        var p: [String: SyncValue] = [
            "clientAttemptId": .s(note.id),
            "typeKey": .s(note.typeKey),
            "seed": .s(String(note.seed)),
            "statement": .s(note.statement),
            "answer": .s(note.answer),
            "steps": .sa(note.steps),
            "wrongCount": .i(note.wrongCount),
            "srsStage": .i(note.srsStage),
            "hasDrawing": .b(note.drawingPNGBase64 != nil),
            "createdAt": .s(ISO8601DateFormatter().string(from: note.createdAt)),
        ]
        // 선지와 KaTeX 플래그를 함께 올린다.
        // 이게 없으면 다른 기기에서 받은 5지선다가 choices=nil 로 복원돼
        // **주관식으로 둔갑**한다 — 11차에 로컬 경로에서 고쳤던 바로 그 증상이
        // 동기화 경로에만 그대로 남아 있었다(2026-07-29 감사 적발).
        if let c = note.choices, !c.isEmpty { p["choices"] = .sa(c) }
        if let t = note.isTex { p["isTex"] = .b(t) }
        if let m = note.myAnswer { p["myAnswer"] = .s(m) }
        if let d = note.divergenceStep { p["divergenceStep"] = .i(d) }
        if let e = note.errorType { p["errorType"] = .s(e) }
        if let n = note.nextReviewAt {
            p["nextReviewAt"] = .s(ISO8601DateFormatter().string(from: n))
        }
        return .init(kind: .wrongNote, payload: p)
    }

    /// 재오답을 서버에 알린다 — 서버 id 가 있으면 복습 결과로, 없으면 bulk 재전송으로.
    ///
    /// 왜 두 갈래인가: `enqueueReviewResult` 는 서버가 붙여 준 attemptId 가 있어야
    /// 주소를 만든다. 아직 bulk 가 안 올라간 새 오답은 그 id 가 없어서, 예전에는
    /// 재오답이 통째로 버려졌다(다음 복습부터나 반영). 이제 서버 bulk 가 같은
    /// clientAttemptId 를 중복으로 보되 wrongCount·srsStage·예정일은 갱신하므로
    /// (2026-07-29 서버 규약 수정) id 가 없을 때는 그쪽으로 우회한다.
    func enqueueWrongAgain(_ note: WrongNoteEntry) {
        if note.serverAttemptId != nil {
            enqueueReviewResult(note, correct: false)
        } else {
            enqueueWrongNote(note)
        }
    }

    /// 복습 결과 — SRS 단계가 전진/리셋된 사실을 서버에 올린다.
    /// 복습 화면에서 맞힌 경우처럼 "정답으로 졸업/전진" 은 이 엔드포인트만 표현할 수 있다
    /// (bulk 는 오답 적재용이라 correct 를 받지 않는다).
    func enqueueReviewResult(_ note: WrongNoteEntry, correct: Bool) {
        // 첫 bulk 응답을 받기 전에도 복습할 수 있다. 그 구간에는 서버 ObjectId가
        // 없으므로 clientAttemptId(UUID)를 주소로 쓰고, 서버가 둘 다 해석한다.
        // 예전 guard는 사용자에게 성공으로 보인 복습 결과를 조용히 버렸고,
        // 새 기기에서 같은 오답이 '미복습'으로 되감겼다.
        let attemptID = WrongNoteReviewSyncAddress.attemptIdentifier(for: note)
        var p: [String: SyncValue] = [
            "attemptId": .s(attemptID),
            "correct": .b(correct),
            // 서버 review-result 는 srsStage 를 0…4 로 엄격 검증해 밖의 값은 400
            // (INVALID_REVIEW_RESULT)으로 거절한다 — 3회 실패 뒤 데드레터가 되므로
            // 클라이언트에서 미리 자른다(bulk 경로는 서버가 알아서 클램프한다).
            "srsStage": .i(min(max(note.srsStage, 0), 4)),
            "wrongCount": .i(note.wrongCount),
        ]
        if let n = note.nextReviewAt {
            p["nextReviewAt"] = .s(ISO8601DateFormatter().string(from: n))
        }
        enqueue(.init(kind: .reviewResult, payload: p))
    }

    func enqueueStuckPoint(_ point: StuckPointRecord) {
        enqueue(.init(id: point.id, kind: .stuckPoint, payload: [
            "id": .s(point.id),
            "text": .s(point.text),
            "createdAt": .s(ISO8601DateFormatter().string(from: point.createdAt)),
        ], createdAt: point.createdAt))
    }

    func enqueueProgressReset() {
        enqueue(.init(kind: .progressReset, payload: [:]))
    }

    /// 빈 progress snapshot과 서버 reset journal을 한 트랜잭션으로 닫는 호출부용.
    /// true 전에 reset op가 반드시 캡처 owner 슬롯의 sync-queue.jsonl에 남는다.
    func enqueueProgressResetDurably() async -> Bool {
        guard isServerAccountSlot, currentAccountOwner() != nil else { return false }
        enqueue(.init(kind: .progressReset, payload: [:]))
        return await flushLocalQueuePersistence()
    }

    private func enqueue(_ op: SyncOp) {
        // 게이트는 토큰이 아니라 **계정 정체성**이다 (S-02·B-09).
        // 토큰이 만료로 지워진 구간에도 서버 계정의 기록은 큐에 쌓여야 한다 —
        // 재로그인하면 flush 가 이어서 올린다. 로컬 우선 큐의 존재 이유가 이것이다.
        guard isServerAccountSlot, currentAccountOwner() != nil,
              !invalidatedJournalSlots.contains(DataScope.slot) else { return }
        // 게스트는 큐에 쌓지 않고, AppStore owner가 연결되기 전에도 전송 주인을 추측하지 않는다.
        syncSlotIfNeeded()                          // 계정이 바뀌었으면 여기서 갈아끼운다
        var op = op
        op.slot = loadedSlot                        // 누구 것인지 새겨 둔다
        queue.append(op)
        pending = queue.count
        scheduleJournalAppend([op], for: loadedSlot)
        Task { await flush() }
    }

    @discardableResult
    private func scheduleJournalAppend(
        _ operations: [SyncOp],
        for slot: String
    ) -> JournalBoundary {
        guard !invalidatedJournalSlots.contains(slot) else {
            return rejectedJournalBoundary()
        }
        let previous = journalBoundaries[slot]?.task
        let task = Task.detached(priority: .utility) {
            _ = await previous?.value
            return await SyncQueueJournal.shared.append(operations, for: slot)
        }
        let boundary = JournalBoundary(id: UUID(), task: task)
        journalBoundaries[slot] = boundary
        return boundary
    }

    @discardableResult
    private func scheduleJournalReplacement(
        _ snapshot: [SyncOp],
        for slot: String
    ) -> JournalBoundary {
        guard !invalidatedJournalSlots.contains(slot) else {
            return rejectedJournalBoundary()
        }
        let previous = journalBoundaries[slot]?.task
        let task = Task.detached(priority: .utility) {
            _ = await previous?.value
            return await SyncQueueJournal.shared.replace(with: snapshot, for: slot)
        }
        let boundary = JournalBoundary(id: UUID(), task: task)
        journalBoundaries[slot] = boundary
        return boundary
    }

    @discardableResult
    private func scheduleJournalRetry(for slot: String) -> JournalBoundary {
        guard !invalidatedJournalSlots.contains(slot) else {
            return rejectedJournalBoundary()
        }
        let previous = journalBoundaries[slot]?.task
        let task = Task.detached(priority: .utility) {
            _ = await previous?.value
            return await SyncQueueJournal.shared.flushPending(for: slot)
        }
        let boundary = JournalBoundary(id: UUID(), task: task)
        journalBoundaries[slot] = boundary
        return boundary
    }

    @discardableResult
    private func scheduleJournalQuarantine(
        _ operation: SyncOp,
        statusCode: Int,
        remainingQueue: [SyncOp],
        for slot: String
    ) -> JournalBoundary {
        guard !invalidatedJournalSlots.contains(slot) else {
            return rejectedJournalBoundary()
        }
        let previous = journalBoundaries[slot]?.task
        let task = Task.detached(priority: .utility) {
            _ = await previous?.value
            return await SyncQueueJournal.shared.quarantine(
                operation,
                statusCode: statusCode,
                remainingQueue: remainingQueue,
                for: slot)
        }
        let boundary = JournalBoundary(id: UUID(), task: task)
        journalBoundaries[slot] = boundary
        return boundary
    }

    /// 탈퇴 gate가 닫힌 뒤 도착한 network continuation에는 disk task를 발행하지 않는다.
    /// 호출부는 일반 I/O 실패와 같은 false 경로로 빠지고 메모리 head도 제거하지 않는다.
    private func rejectedJournalBoundary() -> JournalBoundary {
        JournalBoundary(id: UUID(), task: Task.detached { false })
    }

    /// 현재 슬롯에 지금까지 들어온 enqueue가 모두 disk ack를 받은 뒤에만 true다.
    /// append 실패는 최신 메모리 FIFO 전체 atomic rewrite로 한 번 복구한다.
    private func ensureJournalDurable(for owner: SyncAccountOwner) async -> Bool {
        var recoveryAttempts = 0
        while true {
            guard isCurrentAccountOwner(owner), loadedSlot == owner.slot,
                  !invalidatedJournalSlots.contains(owner.slot) else { return false }

            if let boundary = journalBoundaries[owner.slot] {
                let succeeded = await boundary.task.value
                guard isCurrentAccountOwner(owner), loadedSlot == owner.slot,
                      !invalidatedJournalSlots.contains(owner.slot) else { return false }

                // await 중 enqueue가 하나라도 더 들어왔으면 그 새 tail까지 기다린다.
                guard journalBoundaries[owner.slot]?.id == boundary.id else { continue }
                if succeeded {
                    journalBoundaries.removeValue(forKey: owner.slot)
                } else {
                    guard recoveryAttempts == 0 else { return false }
                    recoveryAttempts += 1
                    scheduleJournalRetry(for: owner.slot)
                    continue
                }
            }

            // 신규 슬롯 load/decode도 actor에서 한다. 같은 물리 슬롯의 새 세션이면
            // actor durable FIFO와 메모리-only FIFO를 ID로 병합해 어느 쪽도 버리지 않는다.
            guard let snapshot = await SyncQueueJournal.shared.snapshot(for: owner.slot) else {
                return false
            }
            guard isCurrentAccountOwner(owner), loadedSlot == owner.slot,
                  !invalidatedJournalSlots.contains(owner.slot) else { return false }
            // snapshot await 중 새 append tail이 생겼으면 그 ack까지 본 뒤 다시 병합한다.
            guard journalBoundaries[owner.slot] == nil else { continue }
            mergeDurableSnapshot(snapshot.operations)
            quarantinedLines = snapshot.quarantinedLines
            deadLettered = snapshot.deadLettered
            hydratedJournalSlots.insert(owner.slot)
            cachedQueueStates[owner.slot] = CachedQueueState(
                queue: queue,
                quarantinedLines: quarantinedLines,
                deadLettered: deadLettered)
            return true
        }
    }

    private func mergeDurableSnapshot(_ durable: [SyncOp]) {
        let memoryByID = Dictionary(queue.map { ($0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        var seen = Set<String>()
        var merged: [SyncOp] = []
        merged.reserveCapacity(durable.count + queue.count)
        for operation in durable where seen.insert(operation.id).inserted {
            merged.append(memoryByID[operation.id] ?? operation)
        }
        for operation in queue where seen.insert(operation.id).inserted {
            merged.append(operation)
        }
        queue = merged
        pending = queue.count
    }

    // MARK: 전송

    /// 큐를 앞에서부터 비운다. 실패는 3분류다 (B-09 — 독성 메시지 격리):
    ///  ① 일시 오류 — 401(만료)·URLError(네트워크)·5xx·408·429:
    ///     큐를 보존하고 그 자리에서 멈춘다(다음 기회에 재시도, 현행 유지).
    ///  ② 독성 오류 — 그 외 4xx(서버가 영구 거부: 잘못된 payload, 삭제된 conceptId 등):
    ///     op 별 attemptCount 를 올리고, 상한 초과 시 sync-deadletter.jsonl 로 격리한 뒤
    ///     다음 op 로 진행한다 — 독성 op 하나가 FIFO 맨 앞에서 뒤의 모든 진도·오답
    ///     전송을 영원히 막지 않게.
    ///  ③ 분류 불가(상태코드 없음) — 보수적으로 ① 취급한다. 기록 보존이 우선이다.
    func flush() async {
        guard !flushing else { return }
        syncSlotIfNeeded()          // 계정이 바뀌었으면 여기서 큐를 갈아끼운다
        guard let owner = currentAccountOwner(),
              loadedSessionGeneration == owner.sessionGeneration else { return }
        flushing = true
        defer { flushing = false }

        // 오프라인·토큰 만료여도 로컬 journal ack는 끝낸다. background/계정 전환이
        // 네트워크 가능 여부 때문에 메모리-only op를 남기면 안 된다.
        guard await ensureJournalDurable(for: owner) else {
            if isCurrentAccountOwner(owner) {
                lastError = "로컬 큐 저장 실패 — 저장 공간을 확인해 주세요"
            }
            return
        }
        guard canReachServer,
              let authorization = ServerAPI.captureAuthorization(),
              isCurrentAccountOwner(owner) else { return }

        while true {
            // network await 중 들어온 tail도 actor disk ack를 받은 뒤에만 head 후보가 된다.
            guard await ensureJournalDurable(for: owner) else {
                if isCurrentAccountOwner(owner) {
                    lastError = "로컬 큐 저장 실패 — 저장 공간을 확인해 주세요"
                }
                return
            }
            guard let op = queue.first else { return }
            // 앞 계정 op 를 뒷 계정 토큰으로 올리면 남의 기록이 된다 — 어긋나면 멈춘다
            guard belongsToCurrentAccount(op) else { return }
            do {
                try await send(op, owner: owner, authorization: authorization)
                // 응답을 기다리는 사이 로그아웃·계정 전환이 있었을 수 있다. 그러면
                // 큐를 건드리지 않고 물러난다(뒷 계정 슬롯 파일에 앞 계정 큐를 적지 않게).
                // 방금 보낸 그 op 가 여전히 맨 앞일 때만 지운다 — 큐가 갈아끼워졌는데
                // 앞에서부터 지우면 아직 보내지도 않은 남의 op 가 사라진다.
                // 이미 보낸 op 가 큐에 남더라도 모든 전송이 멱등이라 서버가 중복을 거른다.
                guard isCurrentAccountOwner(owner),
                      !invalidatedJournalSlots.contains(owner.slot),
                      belongsToCurrentAccount(op), queue.first?.id == op.id else { return }
                // actor tail에 이 replacement를 먼저 끼워 넣는다. await 중 새 enqueue는
                // 그 뒤에 append되므로 여기서 캡처한 stale snapshot이 새 tail을 지우지 않는다.
                let remaining = Array(queue.dropFirst())
                let persisted = await scheduleJournalReplacement(
                    remaining, for: owner.slot).task.value
                guard isCurrentAccountOwner(owner),
                      !invalidatedJournalSlots.contains(owner.slot),
                      belongsToCurrentAccount(op), queue.first?.id == op.id else { return }
                guard persisted else {
                    lastError = "전송 확인 후 로컬 큐 갱신에 실패했습니다. 멱등 재시도합니다."
                    return
                }
                queue.removeFirst()
                pending = queue.count
                lastSyncedAt = Date()
                lastError = nil
            } catch {
                // 전송 성공 경로와 같은 이유로, 응답 대기 중 계정이 바뀌었으면
                // 큐를 건드리지 않는다.
                guard isCurrentAccountOwner(owner),
                      !invalidatedJournalSlots.contains(owner.slot),
                      belongsToCurrentAccount(op), queue.first?.id == op.id else { return }
                lastError = userFacingSyncFailure(error)
                // ①·③ — 401(재로그인 후 재개)·408·429·5xx·네트워크·미분류는 보존·중단.
                guard let status = (error as? ServerAPIError)?.statusCode,
                      (400..<500).contains(status),
                      status != 401, status != 408, status != 429 else { return }
                // ② — 독성 4xx. 횟수를 큐 파일에도 남겨 재시작 후에도 이어 센다.
                var poisoned = op
                let attempts = (op.attemptCount ?? 0) + 1
                poisoned.attemptCount = attempts
                if attempts > Self.maxToxicAttempts {
                    // 격리 = 큐에서 빼되 지우지 않는다. 학생 학습 기록의 마지막
                    // 사본일 수 있다 — 증거 보존 + 수동 재생 여지 (되돌리기 경로).
                    let remaining = Array(queue.dropFirst())
                    let persisted = await scheduleJournalQuarantine(
                        poisoned,
                        statusCode: status,
                        remainingQueue: remaining,
                        for: owner.slot).task.value
                    guard isCurrentAccountOwner(owner),
                          !invalidatedJournalSlots.contains(owner.slot),
                          belongsToCurrentAccount(op), queue.first?.id == op.id else { return }
                    guard persisted else {
                        lastError = "거부된 기록을 로컬 격리 파일에 보존하지 못했습니다."
                        return
                    }
                    deadLettered += 1
                    queue.removeFirst()
                    lastError = "서버가 거부한 기록 1건을 격리했습니다 (\(status))"
                } else {
                    var rewritten = queue
                    rewritten[0] = poisoned
                    let persisted = await scheduleJournalReplacement(
                        rewritten, for: owner.slot).task.value
                    guard isCurrentAccountOwner(owner),
                          !invalidatedJournalSlots.contains(owner.slot),
                          belongsToCurrentAccount(op), queue.first?.id == op.id else { return }
                    guard persisted else {
                        lastError = "서버 거부 횟수를 로컬 큐에 저장하지 못했습니다."
                        return
                    }
                    queue[0] = poisoned
                }
                pending = queue.count
                // 아직 격리 전이면 같은 op 가 맨 앞에 남아 있다 — 다음 기회에 재시도.
                // (연속 즉시 재시도는 서버만 두드린다. 60초 타이머가 간격을 만든다)
                if queue.first?.id == op.id { return }
            }
        }
    }

    private func send(
        _ op: SyncOp,
        owner: SyncAccountOwner,
        authorization: ServerAPI.AuthorizationSnapshot
    ) async throws {
        switch op.kind {
        case .mastery:
            let course = str(op, "courseId"), unit = str(op, "unitId"), concept = str(op, "conceptId")
            let typeIDs: [String]
            if case .sa(let values)? = op.payload["addTypeIds"] {
                typeIDs = values
            } else {
                // 이 필드만 있던 구 큐 파일도 계속 보낸다.
                let legacyType = str(op, "typeKey")
                typeIDs = legacyType.isEmpty ? [] : [legacyType]
            }
            try await ServerAPI.patchMastery(courseId: course, unitId: unit, conceptId: concept,
                                             addTypeIds: typeIDs,
                                             userCompleted: bool(op, "userCompleted"),
                                             authorization: authorization)
        case .topic:
            try await ServerAPI.patchTopic(
                courseId: str(op, "courseId"),
                unitId: str(op, "unitId"),
                conceptId: str(op, "conceptId"),
                topicIndex: int(op, "topicIndex"),
                completed: bool(op, "completed"),
                clientEventId: op.id,
                occurredAt: op.createdAt,
                authorization: authorization)
        case .progressSnapshot:
            var topicIndexes: [Int] = []
            if case .ia(let values)? = op.payload["completedTopicIndexes"] {
                topicIndexes = values
            }
            var typeIDs: [String] = []
            if case .sa(let values)? = op.payload["correctTypeIds"] {
                typeIDs = values
            }
            try await ServerAPI.patchProgressSnapshot(
                courseId: str(op, "courseId"),
                unitId: str(op, "unitId"),
                conceptId: str(op, "conceptId"),
                completedTopicIndexes: topicIndexes,
                correctTypeIds: typeIDs,
                userCompleted: bool(op, "userCompleted"),
                lastStudiedAt: {
                    let value = str(op, "lastStudiedAt")
                    return value.isEmpty ? nil : value
                }(),
                authorization: authorization)
        case .event:
            // 이벤트가 "언제 일어났는지" 를 아는 건 op.createdAt 뿐이다. 이걸 빼고 보내면
            // 서버가 수신 시각으로 대체해(ipadSyncController postEvents), 오프라인에 사흘치를
            // 쌓았다가 한 번에 올린 순간 전부 오늘 하루로 뭉친다 — 대시보드 주간 그래프는
            // 바로 이 occurredAt 으로 날짜를 가른다.
            var payload = op.payload.mapValues(\.any)
            payload["occurredAt"] = ISO8601DateFormatter().string(from: op.createdAt)
            try await ServerAPI.postEvents([payload], authorization: authorization)
        case .gradingBatch:
            let total = max(0, int(op, "totalCount"))
            let correct = min(max(0, int(op, "correctCount")), total)
            guard total > 0 else { return }
            let duration: Int? = op.payload["durationMs"].map { value in
                if case .i(let milliseconds) = value { return milliseconds }
                return 0
            }
            let perItem = (duration ?? 0) / total
            let remainder = (duration ?? 0) % total
            let occurredAt = ISO8601DateFormatter().string(from: op.createdAt)
            let events: [[String: Any]] = (0..<total).map { index in
                let isCorrect = index < correct
                var event: [String: Any] = [
                    "clientEventId": "\(op.id)-\(index)",
                    "eventType": isCorrect ? "problem-correct" : "problem-wrong",
                    "correct": isCorrect,
                    "occurredAt": occurredAt,
                ]
                if duration != nil {
                    event["durationMs"] = perItem + (index < remainder ? 1 : 0)
                }
                return event
            }
            try await ServerAPI.postEvents(events, authorization: authorization)
        case .wrongNote:
            let map = try await ServerAPI.postWrongNotes(
                [op.payload.mapValues(\.any)], authorization: authorization)
            // 서버가 붙인 id 를 오답노트에 적어 둔다 — 복습 결과는 이 값으로만 올릴 수 있다
            guard isCurrentAccountOwner(owner) else { return }
            if let client = op.payload["clientAttemptId"], case .s(let cid) = client,
               let sid = map[cid] {
                onServerID?(cid, sid, owner)
            }
        case .reviewResult:
            var correct = true
            if case .b(let v)? = op.payload["correct"] { correct = v }
            try await ServerAPI.postReviewResult(attemptId: str(op, "attemptId"),
                                                 correct: correct,
                                                 srsStage: int(op, "srsStage"),
                                                 wrongCount: int(op, "wrongCount"),
                                                 nextReviewAt: op.payload["nextReviewAt"].map { "\($0.any)" },
                                                 clientEventId: op.id,
                                                 authorization: authorization)
        case .stuckPoint:
            try await ServerAPI.postStuckPoint(
                id: str(op, "id"),
                text: str(op, "text"),
                createdAt: str(op, "createdAt"),
                authorization: authorization)
        case .progressReset:
            try await ServerAPI.resetLearningProgress(
                clientResetId: op.id,
                occurredAt: ISO8601DateFormatter().string(from: op.createdAt),
                authorization: authorization)
        }
    }

    private func str(_ op: SyncOp, _ k: String) -> String {
        if case .s(let v)? = op.payload[k] { return v }
        return ""
    }
    private func int(_ op: SyncOp, _ k: String) -> Int {
        if case .i(let v)? = op.payload[k] { return v }
        return 0
    }
    private func bool(_ op: SyncOp, _ k: String) -> Bool {
        if case .b(let v)? = op.payload[k] { return v }
        return false
    }

    // MARK: 로그인 직후 초기 동기화

    /// 서버 계정으로 들어온 순간: 로컬에 있던 것을 한 번 밀어 올리고, 반대로
    /// 다른 기기에서 쌓인 것을 내려받는다. 한쪽만 하면 기기를 바꾼 사람의 오답노트가
    /// 비어 보인다(밀어 올리기만 하던 것이 감사에서 적발된 지점).
    func uploadLocalSnapshot(wrongNotes: [WrongNoteEntry],
                             progress: ProgressV2Store? = nil) {
        // 정체성 게이트 — 로그인 직후 토큰 저장이 어긋나는 드문 경합에도
        // 큐에는 쌓인다(전송은 flush 가 토큰 확보 후 이어서 한다).
        guard isServerAccountSlot else { return }
        var operations: [SyncOp] = []
        operations.reserveCapacity(wrongNotes.prefix(100).count + (progress?.byConcept.count ?? 0))
        for note in wrongNotes.prefix(100) {
            operations.append(wrongNoteOp(note))
        }
        if let progress {
            for conceptID in progress.byConcept.keys.sorted() {
                guard let local = progress.byConcept[conceptID],
                      let (course, unit, concept) = CurriculumV2.concept(conceptID) else { continue }
                let validTopics = local.completedTopicIndexes.sorted()
                    .filter { concept.topics.indices.contains($0) }
                guard !validTopics.isEmpty || !local.correctTypeIds.isEmpty ||
                        local.userCompleted else { continue }
                var payload: [String: SyncValue] = [
                    "courseId": .s(course.id),
                    "unitId": .s(unit.id),
                    "conceptId": .s(concept.id),
                    "completedTopicIndexes": .ia(validTopics),
                    "correctTypeIds": .sa(local.correctTypeIds.sorted()),
                    "userCompleted": .b(local.userCompleted),
                ]
                if let date = local.lastStudiedAt {
                    payload["lastStudiedAt"] = .s(ISO8601DateFormatter().string(from: date))
                }
                operations.append(.init(kind: .progressSnapshot, payload: payload))
            }
        }
        enqueueBatch(operations)
        Task { await syncNow() }
    }

    /// 로그인 승계는 여러 건을 한 번에 큐에 넣고 파일도 한 번만 쓴다.
    /// 각 항목마다 flush Task 를 만들면 pull 이 업로드보다 먼저 달릴 수 있다.
    private func enqueueBatch(_ operations: [SyncOp]) {
        guard isServerAccountSlot, currentAccountOwner() != nil,
              !invalidatedJournalSlots.contains(DataScope.slot),
              !operations.isEmpty else { return }   // enqueue 와 같은 게이트
        syncSlotIfNeeded()
        let stamped = operations.map { source -> SyncOp in
            var op = source
            op.slot = loadedSlot
            return op
        }
        queue.append(contentsOf: stamped)
        pending = queue.count
        scheduleJournalAppend(stamped, for: loadedSlot)
    }

    // MARK: 서버 → 로컬 (pull)

    /// 증분 pull — 마지막으로 받은 시각 이후에 서버에 쌓인 오답만 가져온다.
    /// 합치는 일은 AppStore(onRemoteWrongNotes)가 한다. 같은 id 는 그쪽에서 걸러진다.
    func pullWrongNotes() async {
        // 받아 줄 곳이 없으면 요청 자체를 하지 않는다 — 커서만 밀어 두면
        // 수신부가 붙는 날 그 구간 오답을 영영 못 받는다.
        guard let handler = onRemoteWrongNotes else { return }
        // canReachServer: 재설치 후 게스트 슬롯 + 잔존 토큰으로 이전 계정의 오답을
        // 게스트 슬롯에 내려받는 경로를 막는다 (S-02).
        guard canReachServer, !pulling else { return }
        guard let owner = currentAccountOwner() else { return }
        // 같은 이메일 A→guest→A도 새 세션이다. 물리 슬롯이 같다는 이유로 앞 세션의
        // 5분 throttle을 물려받지 않도록 큐 owner를 먼저 동기화한다.
        syncSlotIfNeeded()
        guard loadedSlot == owner.slot,
              loadedSessionGeneration == owner.sessionGeneration,
              let authorization = ServerAPI.captureAuthorization() else { return }
        // 깨우기 경로가 여럿이라 간격을 둔다(계정이 바뀌면 syncSlotIfNeeded 가 풀어 준다)
        if let last = lastPullAt, Date().timeIntervalSince(last) < 300 { return }
        pulling = true
        defer { pulling = false }
        lastPullAt = Date()         // 실패해도 간격을 지킨다(깨우기마다 두드리지 않게)

        let cursorKey = "matths.sync.lastPull." + owner.slot
        let since = UserDefaults.standard.string(forKey: cursorKey)
        do {
            // 서버는 300건씩 페이지를 나눈다(hasMore/nextCursor). 첫 페이지만 받고 끝내면
            // 300건 넘는 계정은 5분 간격 pull 을 여러 번 돌아야 하고, 경계 updatedAt 을
            // 공유하는 행이 빠질 수 있다 — 같은 조회 안에서 커서를 따라 끝까지 받는다.
            // 페이지 수 상한은 서버 이상(항상 hasMore=true) 시 무한 루프를 막는 안전장치다.
            var rows: [ServerAPI.RemoteWrongNote] = []
            var cursor: String? = nil
            var pagesLeft = 50
            repeat {
                let page = try await ServerAPI.getWrongNotes(
                    since: since, cursor: cursor, authorization: authorization)
                // 페이지 사이에도 계정이 바뀔 수 있다. 마지막에 한 번만 확인하면 다음
                // cursor 요청이 새 세션에서 계속 진행될 수 있으므로 매 await 뒤 닫는다.
                guard isCurrentAccountOwner(owner) else { return }
                rows.append(contentsOf: page.entries)
                cursor = page.hasMore == true ? page.nextCursor : nil
                pagesLeft -= 1
            } while cursor?.isEmpty == false && pagesLeft > 0
            // 응답을 기다리는 사이 계정이 바뀌었으면 남의 계정 오답을 붓지 않는다
            guard isCurrentAccountOwner(owner) else { return }
            let notes = rows.compactMap { Self.entry(from: $0) }
            if !notes.isEmpty {
                guard await handler(notes, owner) else {
                    if isCurrentAccountOwner(owner) {
                        lastError = "받은 오답을 이 기기에 저장하지 못했습니다."
                    }
                    return
                }
            }
            // handler가 actor 파일 쓰기를 기다리는 동안 계정이 바뀔 수 있다. 이 guard가
            // 없으면 캡처한 A 응답의 cursor를 현재 B 슬롯 키에 기록하게 된다.
            guard isCurrentAccountOwner(owner) else { return }
            // 커서는 "받은 것 중 가장 최근" 으로 잡는다 — 기기·서버 시계 차이를 타지 않고,
            // 초 이하가 잘려 같은 항목을 한 번 더 받아도 병합에서 걸러지므로 안전한 쪽이다.
            if let newest = rows.compactMap({ Self.date(from: $0.updatedAt) }).max() {
                UserDefaults.standard.set(ISO8601DateFormatter().string(from: newest),
                                          forKey: cursorKey)
            }
            lastSyncedAt = Date()
            lastError = nil
        } catch {
            guard isCurrentAccountOwner(owner) else { return }
            lastError = userFacingSyncFailure(error)
        }
    }

    /// 서버 행 → 로컬 오답 항목. 서버는 단원명·필기·선지를 보관하지 않으므로
    /// 그 자리는 비워 둔다(없는 것을 지어내지 않는다).
    private static func entry(from r: ServerAPI.RemoteWrongNote) -> WrongNoteEntry? {
        guard !r.statement.isEmpty else { return nil }
        let type = r.typeKey ?? "unknown"
        return WrongNoteEntry(
            // 이 기기에서 만든 오답이면 clientAttemptId 가 로컬 id 와 같은 값이라
            // 병합에서 자기 자신과 겹쳐 중복이 생기지 않는다.
            id: r.clientAttemptId ?? r.attemptId,
            problemID: r.attemptId,
            typeKey: type,
            typeName: type,
            unit: "",
            statement: r.statement,
            answer: r.answer ?? "",
            steps: r.steps ?? [],
            seed: UInt64(r.seed ?? "") ?? 0,
            divergenceStep: r.divergenceStep,
            drawingPNGBase64: nil,
            srsStage: r.srsStage ?? 0,
            // 서버 상태를 그대로 해석한다.
            //   completed → nil (복습 완료)
            //   scheduled → 예약 시각
            //   pending   → **오늘** (아직 한 번도 복습하지 않았다)
            // 예전엔 nextReviewAt 만 보고 매핑해서, pending 이 nil 로 들어와
            // '복습 완료'가 되고 다시는 출제되지 않았다.
            nextReviewAt: {
                switch r.reviewStatus ?? "pending" {
                case "completed": return nil
                case "scheduled": return date(from: r.nextReviewAt) ?? Date()
                default:          return date(from: r.nextReviewAt) ?? Date()
                }
            }(),
            wrongCount: r.wrongCount ?? 1,
            createdAt: date(from: r.createdAt) ?? Date(),
            // 선지·KaTeX 플래그 복원 — 없으면 복습 때 주관식으로 둔갑한다
            choices: r.choices.flatMap { $0.isEmpty ? nil : $0 },
            isTex: r.isTex,
            errorType: r.errorType,
            myAnswer: r.myAnswer,
            serverAttemptId: r.attemptId,
            serverUpdatedAt: date(from: r.updatedAt) ?? date(from: r.createdAt)
        )
    }

    /// 서버 날짜는 밀리초가 붙어 오기도 한다 — 둘 다 받아 준다.
    private static func date(from s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let withMillis = ISO8601DateFormatter()
        withMillis.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withMillis.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    #if DEBUG
    /// 제품 actor와 같은 codec을 임시 URL에 적용하는 DEBUG 실기 probe 호환 wrapper.
    private static func loadQueue(
        at url: URL,
        quarantineURL: URL?
    ) -> (ops: [SyncOp], quarantined: Int) {
        let loaded = SyncQueueDiskCodec.loadQueue(at: url)
        if let quarantineURL, !loaded.badLines.isEmpty {
            _ = SyncQueueDiskCodec.appendRawLines(loaded.badLines, to: quarantineURL)
        }
        return (loaded.ops, loaded.quarantined)
    }

    private static func appendToDisk(_ op: SyncOp, at url: URL) -> Bool {
        SyncQueueDiskCodec.append([op], to: url)
    }

    private static func rewrite(_ ops: [SyncOp], at url: URL) {
        _ = SyncQueueDiskCodec.rewrite(ops, at: url)
    }

    struct IntegrityQueueDeviceQAResult {
        let persisted: Bool
        let reloaded: Bool
        let payloadPreserved: Bool
        let cleared: Bool
    }

    /// 네트워크를 끈 상태의 핵심 계약(append→앱 재시작 reload→성공 뒤 rewrite)을
    /// 제품과 같은 JSONL codec으로 실행한다. 실제 계정 슬롯 파일 대신 전달받은 전용
    /// 파일만 사용하며 종료 전에 삭제한다.
    static func runIntegrityQueueDeviceQA(at url: URL) -> IntegrityQueueDeviceQAResult {
        try? FileManager.default.removeItem(at: url)
        let op = SyncOp(
            id: "screen-integrity-device-qa",
            kind: .event,
            payload: [
                "eventType": .s("protected-screen-screenshot"),
                "clientEventId": .s("screen-integrity-device-qa"),
                "integritySessionCode": .s("QA123456"),
                "protectedSurface": .s("placement-exam"),
            ],
            createdAt: Date(timeIntervalSince1970: 1_786_420_800),
            slot: "acct-device-qa",
            attemptCount: nil
        )
        let persisted = appendToDisk(op, at: url)
        let loaded = loadQueue(at: url, quarantineURL: nil)
        let restored = loaded.ops.first
        let reloaded = loaded.ops.count == 1
            && loaded.quarantined == 0
            && restored?.id == op.id
            && restored?.slot == op.slot
        let payloadPreserved: Bool = {
            guard case .s(let type)? = restored?.payload["eventType"],
                  case .s(let code)? = restored?.payload["integritySessionCode"],
                  case .s(let surface)? = restored?.payload["protectedSurface"] else {
                return false
            }
            return type == "protected-screen-screenshot"
                && code == "QA123456"
                && surface == "placement-exam"
        }()
        rewrite([], at: url)
        let cleared = loadQueue(at: url, quarantineURL: nil).ops.isEmpty
            && (try? Data(contentsOf: url).isEmpty) == true
        try? FileManager.default.removeItem(at: url)
        return IntegrityQueueDeviceQAResult(
            persisted: persisted,
            reloaded: reloaded,
            payloadPreserved: payloadPreserved,
            cleared: cleared
        )
    }
    #endif
}
