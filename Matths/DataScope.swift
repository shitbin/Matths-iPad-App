//  DataScope.swift
//  Matths
//
//  계정별 로컬 데이터 슬롯.
//
//  문제: 진도·오답·이벤트가 Documents 바로 아래 평평하게 놓여 있어서, 로그아웃하고
//  다른 계정으로 들어오면 앞사람 기록이 그대로 보였다. 한 기기를 형제·친구가
//  같이 쓰는 상황에서 이건 사고다.
//
//  해결: 모든 로컬 파일을 Documents/slots/<슬롯>/ 아래로 넣는다.
//    - 게스트          → slots/guest
//    - 서버 계정        → slots/acct-<이메일 해시 12자>
//  이메일 원문을 경로에 쓰지 않는다(파일명으로 계정이 노출되지 않게).
//
//  기존 사용자 보호: 첫 실행에서 Documents 에 남아 있던 평평한 파일들을 현재
//  슬롯으로 **옮긴다**(복사 아님). 데이터 파괴 금지 원칙에 따라 덮어쓰지 않는다.

import Foundation
import CryptoKit

enum DataScope {
    /// 장시간 로컬 작업이 계정 경계를 넘지 않도록 슬롯 변경을 동기 통지한다.
    /// 알림의 object는 새 슬롯 이름이다. 변경 후 게시하므로 구독자는 즉시 새 경로를
    /// 읽을 수 있고, 이전 슬롯을 붙잡은 작업은 그 자리에서 취소할 수 있다.
    static let didSwitchNotification = Notification.Name("kr.matths.dataScopeDidSwitch")

    /// 슬롯을 옮기는 파일 목록 — 새 저장소를 추가하면 여기에도 넣는다.
    static let managedFiles = [
        "progress-v2.json", "wrongnotes.json", "events.jsonl",
        "assessments.json", "dailyplan.json", "sync-queue.jsonl",
        "goat-arena-v1-cache.json", "goat-arena-match-drafts.json",
        "goat-arena-rulebook-v1-cache.json",
        "goat-arena-local-review-contexts.json",
        "goat-arena-evidence-drafts.json",
        "goat-arena-client-review-outbox.json",
        "goat-arena-client-review-finalized.json",
        "goat-arena-command-keys.json",
        "goat-arena-defender-command-keys.json",
        "goat-arena-main-create-command.json",
        "arena-shop-purchase-intents.json",
        "tutor-conversation",
        "cheating-reviews",
        "local-ai-pending-sheet",
        "selftest.txt", "selftest-metrics.jsonl",
    ]

    private static let slotKey = "matths.dataSlot"

    /// Debug 데모를 켠 채 강제 종료한 뒤 같은 번들 ID의 TestFlight/App Store 빌드를
    /// 덮어 설치하면 `demo` 슬롯이 Release에서도 그대로 선택될 수 있다. 데모 코드는
    /// Release에 컴파일되지 않아 스스로 원래 슬롯으로 돌아갈 수도 없으므로, 제품 진입점이
    /// 레거시 이사와 AppStore 생성 전에 이 복구를 한 번 수행한다.
    static func restoreReleaseSlotIfNeeded() {
        guard slot == "demo" else { return }
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: "matths.demoMode.previousSlot")
        let target = releaseRecoveryTarget(currentSlot: slot, previousSlot: previous)
        defaults.removeObject(forKey: "matths.demoMode")
        defaults.removeObject(forKey: "matths.demoMode.previousSlot")
        _ = switchTo(target)
    }

    /// Release 복구가 임의의 UserDefaults 문자열을 디렉터리 이름으로 받아들이지 않도록
    /// 제품 슬롯 형식만 허용한다. `demo`가 아니면 호출자가 현재 슬롯을 유지할 수 있다.
    static func releaseRecoveryTarget(currentSlot: String, previousSlot: String?) -> String {
        guard currentSlot == "demo" else { return currentSlot }
        if previousSlot == "guest" { return "guest" }
        if let previousSlot,
           previousSlot.hasPrefix("acct-"),
           previousSlot.count == 17,
           previousSlot.dropFirst(5).allSatisfy({ $0.isHexDigit }) {
            return previousSlot.lowercased()
        }
        return "guest"
    }

    /// 현재 슬롯 이름. 기본은 게스트.
    private(set) static var slot: String =
        UserDefaults.standard.string(forKey: slotKey) ?? "guest"

    /// 계정 이메일로 슬롯 이름을 만든다 (원문 대신 해시 앞 12자)
    static func slotName(forEmail email: String?) -> String {
        guard let email, !email.isEmpty else { return "guest" }
        let norm = email.trimmingCharacters(in: .whitespaces).lowercased()
        let digest = SHA256.hash(data: Data(norm.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "acct-" + hex.prefix(12)
    }

    /// 보호 화면에 표시할 계정 단위 가명 코드. 이메일 원문과 슬롯 해시를 그대로
    /// 노출하지 않고 도메인을 분리해 한 번 더 해시한다. 같은 계정은 기기 사이에서
    /// 같은 코드가 나오고, 실행마다 바뀌는 세션 코드와 함께 유출 화면을 대조할 수 있다.
    static var screenProtectionAccountCode: String {
        screenProtectionAccountCode(for: slot)
    }

    static func screenProtectionAccountCode(for slot: String) -> String {
        guard slot != "guest" else { return "GUEST" }
        let material = "matths-screen-watermark-v1|" + slot
        let digest = SHA256.hash(data: Data(material.utf8))
        return digest.prefix(4).map { String(format: "%02X", $0) }.joined()
    }

    /// 슬롯 디렉터리 (없으면 만든다)
    static var directory: URL {
        directory(for: slot)
    }

    /// 장시간 작업이 시작될 때 캡처한 슬롯의 디렉터리. 응답 시점의 전역 슬롯을
    /// 다시 읽으면 계정 전환 뒤 이전 학생의 파일을 새 학생 슬롯에 쓰게 된다.
    static func directory(for capturedSlot: String) -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("slots", isDirectory: true)
            .appendingPathComponent(capturedSlot, isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    /// 저장소들이 부르는 유일한 경로 진입점
    static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    /// 네트워크/AI 작업 시작 때 캡처한 슬롯에 결과를 끝까지 귀속한다.
    static func url(_ name: String, for capturedSlot: String) -> URL {
        directory(for: capturedSlot).appendingPathComponent(name)
    }

    /// 특정 슬롯의 UserDefaults 키. 장시간 실행되는 시험·분석 작업은 응답을
    /// 기다리는 사이 현재 슬롯이 바뀔 수 있으므로 `AppStore.slotKey`처럼 현재값을
    /// 다시 읽어서는 안 된다. 작업 시작 때 캡처한 슬롯을 끝까지 사용한다.
    static func defaultsKey(_ base: String, for slot: String) -> String {
        slot == "guest" ? base : "\(base).\(slot)"
    }

    /// 슬롯 전환. 실제로 바뀌었을 때만 true 를 돌려준다(호출부가 그때만 다시 읽게).
    @discardableResult
    static func switchTo(_ newSlot: String) -> Bool {
        guard newSlot != slot else { return false }
        slot = newSlot
        UserDefaults.standard.set(newSlot, forKey: slotKey)
        NotificationCenter.default.post(name: didSwitchNotification, object: newSlot)
        return true
    }

    /// 앱 시작 시 1회 — Documents 에 평평하게 남아 있던 옛 파일을 현재 슬롯으로 옮긴다.
    /// 슬롯 쪽에 같은 이름이 이미 있으면 건드리지 않는다(덮어쓰기 금지).
    static func migrateLegacyIfNeeded() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for name in managedFiles {
            let old = docs.appendingPathComponent(name)
            guard fm.fileExists(atPath: old.path) else { continue }
            let new = url(name)
            if fm.fileExists(atPath: new.path) {
                // 이미 슬롯에 데이터가 있다 — 옛 파일은 백업 이름으로 물러나게만 한다
                try? fm.moveItem(at: old, to: docs.appendingPathComponent(name + ".legacy"))
            } else {
                try? fm.moveItem(at: old, to: new)
            }
        }
    }
}
