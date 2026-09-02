//  ServerAuthenticationOwnership.swift
//  Matths
//
//  여러 인증 요청의 응답 순서가 뒤집혀도 마지막으로 시작한 로그인만 세션을
//  소유하게 하는 작은 상태 기계. 키체인 접근은 ServerAPI.TokenBox가 맡는다.

import Foundation

struct ServerAuthenticationOwnership {
    private(set) var activeAttemptID: UUID?

    mutating func begin(id: UUID = UUID()) -> UUID {
        activeAttemptID = id
        return id
    }

    func owns(_ id: UUID) -> Bool {
        activeAttemptID == id
    }

    mutating func complete(_ id: UUID) -> Bool {
        guard owns(id) else { return false }
        activeAttemptID = nil
        return true
    }

    mutating func cancel(_ id: UUID) {
        guard owns(id) else { return }
        activeAttemptID = nil
    }

    mutating func reset() {
        activeAttemptID = nil
    }
}
