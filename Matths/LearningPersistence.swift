//  LearningPersistence.swift
//  Matths
//
//  일반 학습 진행의 비동기 저장 경계. 결제·인증 토큰·아레나 명령/정산은 이 경계를
//  사용하지 않는다. 그 값들은 네트워크 요청 전/권한 부여 전 즉시 내구성이 필요하다.

import Foundation

enum LearningPersistenceResource: String, CaseIterable, Sendable {
    case progress
    case wrongNotes
    case assessments
    case stuckPoints
}

struct LearningPersistenceKey: Hashable, Sendable {
    let slot: String
    let resource: LearningPersistenceResource
}

enum LearningPersistenceSnapshot: Sendable {
    case progress([String: ConceptProgressV2])
    case wrongNotes([WrongNoteEntry])
    case assessments([AssessmentAttemptV2])
    case stuckPoints([StuckPointRecord])

    var resource: LearningPersistenceResource {
        switch self {
        case .progress: return .progress
        case .wrongNotes: return .wrongNotes
        case .assessments: return .assessments
        case .stuckPoints: return .stuckPoints
        }
    }
}

enum LearningPersistence {
    /// 150ms: 연속 토픽 탭·주관식 키 입력을 한 세대로 합치되, 앱 수명주기 flush가
    /// 놓치기 어려울 만큼 짧은 창이다.
    static let writer = DebouncedSnapshotWriter<LearningPersistenceKey, LearningPersistenceSnapshot>(
        debounceNanoseconds: 150_000_000
    ) { key, snapshot in
        switch (key.resource, snapshot) {
        case let (.progress, .progress(value)):
            return ProgressV2Store.persist(value, for: key.slot)
        case let (.wrongNotes, .wrongNotes(value)):
            return WrongNoteDisk.save(value, for: key.slot)
        case let (.assessments, .assessments(value)):
            return AttemptStoreV2.persist(value, for: key.slot)
        case let (.stuckPoints, .stuckPoints(value)):
            return StuckPointsDisk.save(value, for: key.slot)
        default:
            assertionFailure("학습 저장 key와 snapshot 종류가 다릅니다")
            return false
        }
    }

    static func key(for snapshot: LearningPersistenceSnapshot, slot: String) -> LearningPersistenceKey {
        LearningPersistenceKey(slot: slot, resource: snapshot.resource)
    }

    static func keys(for slot: String) -> Set<LearningPersistenceKey> {
        Set(LearningPersistenceResource.allCases.map {
            LearningPersistenceKey(slot: slot, resource: $0)
        })
    }
}
