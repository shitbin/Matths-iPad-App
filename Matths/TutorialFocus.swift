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
    static func placeCoachAbove(target: CGRect?, viewport: CGRect) -> Bool {
        guard let target, isFinite(target), isFinite(viewport) else { return false }
        return target.minY - viewport.minY > viewport.maxY - target.maxY
    }
    static func coachPlacement(target: CGRect?, viewport: CGRect) -> CoachPlacement {
        guard let target, isFinite(target), isFinite(viewport) else { return .bottom }
        let left = target.minX - viewport.minX
        let right = viewport.maxX - target.maxX
        if viewport.width > viewport.height, max(left, right) >= 356 {
            return left > right ? .left : .right
        }
        return placeCoachAbove(target: target, viewport: viewport) ? .top : .bottom
    }
}
