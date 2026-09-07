//  ServerAuthenticationOwnership.swift
//  Matths
//
//  여러 인증 요청의 응답 순서가 뒤집혀도 마지막으로 시작한 로그인만 세션을
//  소유하게 하는 작은 상태 기계. 키체인 접근은 ServerAPI.TokenBox가 맡는다.

import Foundation

struct ServerAuthenticationOwnership {
    private(set) var activeAttemptID: UUID?
    private(set) var generation = UUID()

    mutating func begin(id: UUID = UUID()) -> UUID {
        generation = UUID()
        activeAttemptID = id
        return id
    }

    func owns(_ id: UUID) -> Bool {
        activeAttemptID == id
    }

    mutating func complete(_ id: UUID) -> Bool {
        guard owns(id) else { return false }
        activeAttemptID = nil
        generation = UUID()
        return true
    }

    mutating func cancel(_ id: UUID) {
        guard owns(id) else { return }
        activeAttemptID = nil
        generation = UUID()
    }

    mutating func reset() {
        activeAttemptID = nil
        generation = UUID()
    }

    /// Log out invalidates the attempt which exists at the user's action, not
    /// a later login which starts while disk persistence is being flushed.
    mutating func beginSignOut() -> UUID {
        reset()
        return generation
    }

    func ownsSignOut(_ id: UUID) -> Bool {
        generation == id && activeAttemptID == nil
    }

    mutating func completeSignOut(_ id: UUID) -> Bool {
        guard ownsSignOut(id) else { return false }
        reset()
        return true
    }

    /// A credential-free, non-secret ticket for deferred UI cleanup. Matching
    /// an old request's token is insufficient: login may start or finish before
    /// the notification/MainActor task or its persistence flush is executed.
    func expirationTicket(hasCredential: Bool) -> UUID? {
        !hasCredential && activeAttemptID == nil ? generation : nil
    }

    func ownsExpiration(_ id: UUID, hasCredential: Bool) -> Bool {
        !hasCredential && ownsSignOut(id)
    }

    mutating func completeExpiration(_ id: UUID, hasCredential: Bool) -> Bool {
        guard ownsExpiration(id, hasCredential: hasCredential) else { return false }
        reset()
        return true
    }
}
