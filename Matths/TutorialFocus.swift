import Foundation
import CoreGraphics

/// Explicit simulator tutorial fixtures only. Boolean state checkpoints contain
/// no account ID, credential, question, response, URL or free-form error text.
@MainActor enum TutorialFocusDiagnostics {
    static func record(_ stage: String, flags: [String: Bool]) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-tutorialFixture"),
              stages.contains(stage), Set(flags.keys).isSubset(of: allowedFlags) else { return }
        events.append(Event(stage: stage, flags: flags))
        if events.count > 60 { events.removeFirst(events.count - 60) }
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(events) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("tutorial-focus-diagnostics.json"),
                        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #endif
    }
    #if DEBUG
    private struct Event: Encodable { let stage: String; let flags: [String: Bool] }
    private static var events: [Event] = []
    private static let stages: Set<String> = [
        "overlay_appeared", "overlay_disappeared", "run_appeared", "run_disappeared",
        "start_entered", "owner_invalid", "claim_entered", "claimed", "clear_requested",
        "settle_entered", "settle_completed", "settle_rejected", "focus_requested"
    ]
    private static let allowedFlags: Set<String> = [
        "hasRun", "hasOwner", "leaseMatches", "runOwnerMatches", "accountCurrent",
        "authorizationCurrent", "roleMatches", "taskCancelled", "authServer"
    ]
    #endif
}

/// Stable meanings shared by real views and their tutorial steps. These are
/// element identities, never fractions of a device screen.
enum TutorialTargetID: String, Hashable, CaseIterable {
    case todayPrimaryAction, todayProgress, learningCourses, courseConcepts, courseAssessments
    case quickPracticeStart, weeklyMockEntry, placementEntry, wrongNotes, communityBrowse, communityWrite
    case proEntry, proWorkspace, profileSettings, profileTutorials
    case tabToday, tabLearning, tabArena, tabRecords, tabMe, topChat, topNotifications
    case arenaOverview, arenaProfile, arenaEligibility, arenaMatchmaking, arenaRecords, arenaProgress
    case arenaWallet, arenaOperations, arenaShopEntry, arenaUpward, arenaInvites, arenaFriendly, arenaInvitationList
    case arenaShopWallet, arenaShopCatalog
}

@MainActor
enum TutorialFocusRequestCenter {
    struct Request {
        let id: UUID
        let ownerID: UUID
        let target: TutorialTargetID
        let animated: Bool
    }
    static let notification = Notification.Name("matths.nativeTutorialFocusRequest")
    private(set) static var current: Request?
    static func request(_ target: TutorialTargetID, ownerID: UUID, animated: Bool) {
        current = Request(id: UUID(), ownerID: ownerID, target: target, animated: animated)
        NotificationCenter.default.post(name: notification, object: nil)
    }
    static func cancel(ownerID: UUID) {
        guard current?.ownerID == ownerID else { return }
        current = nil
    }
    static func accepts(_ id: UUID, target: TutorialTargetID) -> Bool {
        current?.id == id && current?.target == target
    }
}

enum TutorialFocusGeometry {
    enum CoachPlacement { case top, bottom, left, right }
    enum Resolution: Equatable {
        case visible(CGRect)
        case missing
        case ambiguous
        case offscreen
        case obscured

        var frame: CGRect? { if case .visible(let frame) = self { return frame }; return nil }
    }
    static func isFinite(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && !rect.isEmpty
            && [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite)
    }
    static func resolve(targets: [CGRect], clippingRects: [CGRect], viewport: CGRect, coach: CGRect?) -> Resolution {
        guard !targets.isEmpty else { return .missing }
        guard targets.count == 1 else { return .ambiguous }
        let target = targets[0]
        guard isFinite(target), isFinite(viewport) else { return .offscreen }
        var visibleRegion = viewport
        for clip in clippingRects {
            guard isFinite(clip) else { return .offscreen }
            visibleRegion = visibleRegion.intersection(clip)
        }
        let visible = target.intersection(visibleRegion)
        // Never draw a viewport-sized slice of a larger/offscreen card as if
        // that slice were the intended control. Small rounding tolerance only.
        guard isFinite(visible), visible.width >= target.width - 1,
              visible.height >= target.height - 1 else { return .offscreen }
        if let coach, isFinite(coach) {
            let overlap = target.intersection(coach)
            if !overlap.isNull && overlap.width > 1 && overlap.height > 1 { return .obscured }
        }
        return .visible(target.insetBy(dx: -6, dy: -6).intersection(visibleRegion))
    }
    /// 튜토리얼 카드 위치는 강조 대상이 아니라 현재 창의 방향으로만 정한다.
    /// 대상마다 빈 공간을 다시 계산하면 다음을 누를 때 카드가 좌우·상하로 왕복해
    /// 사용자가 설명이 아니라 카드 위치를 다시 찾게 된다. 회전이나 창 크기 변경
    /// 때만 위치가 바뀌고, 같은 화면 방향에서는 투어가 끝날 때까지 고정된다.
    static func coachPlacement(viewport: CGRect) -> CoachPlacement {
        guard isFinite(viewport) else { return .bottom }
        return viewport.width > viewport.height ? .right : .bottom
    }

    /// 고정된 카드가 실제 조작 대상 위를 덮지 않도록 앱 본문이 비워 둘 공간.
    /// 작은 가로 창에서도 본문 폭 320pt, 작은 세로 창에서도 본문 높이 360pt는
    /// 남긴다. 따라서 Split View와 iPhone 가로에서도 화면을 카드 뒤로 숨기지 않는다.
    static func contentReserve(viewport: CGRect) -> CGSize {
        guard isFinite(viewport) else { return .zero }
        switch coachPlacement(viewport: viewport) {
        case .right:
            return CGSize(width: max(0, min(356, viewport.width - 320)), height: 0)
        case .bottom:
            return CGSize(width: 0, height: max(0, min(300, viewport.height - 360)))
        case .top, .left:
            return .zero
        }
    }

    /// 본문을 읽을 수 있게 유지하면서 현재 대상에는 충분한 대비를 주는 강도.
    /// 대상 탐색/라우트 전환 중에는 더 옅게 유지해 순간적인 전체 암전을 막는다.
    static let focusedDimOpacity = 0.38
    static let transitionalDimOpacity = 0.18
}
