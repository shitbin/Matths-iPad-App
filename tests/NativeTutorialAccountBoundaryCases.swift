import Foundation

// Controlled HTTP boundary: synthetic credentials never leave this process.
@MainActor enum DataScope {
    static var slot = "A"
    static var directory: URL { URL(fileURLWithPath: "/unused-tutorial-test/" + slot) }
}
enum NativeTutorialRun { case dashboard, arena(String) }
struct NativeTutorialStep { var route: AppStore.Route; var target:TutorialTargetID }
struct TutorialStatus { var status = "PENDING"; var shouldAutoStart: Bool { status == "PENDING" } }
struct ArenaStatus {
    var suspended = false
    var availableChapters = ["unranked", "ranked", "ranked_shop"]
    var activeDivision: String? = "SUB"
    var chapters = ["unranked": TutorialStatus(), "ranked": TutorialStatus(), "ranked_shop": TutorialStatus()]
}
struct Profile {
    var role: String? = "student"
    var coachMode:String? = "MILD"
    var dashboardTutorial: TutorialStatus? = TutorialStatus()
    var arenaTutorial: ArenaStatus? = ArenaStatus()
}
enum ServerAPIError: Error { case failed
    var errorDescription: String? { "Synthetic failure" }
}
enum SpiceLevel {case mild, spicy
    var serverValue:String{self == .mild ? "MILD":"SPICY"}
    static func fromServer(_ value:String?)->Self{value=="SPICY" ? .spicy:.mild}
}
struct Coach {var level:SpiceLevel = .mild}
struct Animation {static func easeOut(duration:Double)->Self{.init()}}
enum AnimationCompletionCriteria {case logicallyComplete}
@MainActor enum AnimationHarness {
    static var afterBody:(()->Void)?
    static var droppedCompletions=0
    static func reset(){afterBody=nil;droppedCompletions=0}
}
@MainActor func withAnimation(_ animation:Animation?,_ body:()->Void){
    body();AnimationHarness.afterBody?()
}
@MainActor func withAnimation(_ animation:Animation?,completionCriteria:AnimationCompletionCriteria,
                             _ body:()->Void,completion:@escaping ()->Void){
    body();AnimationHarness.afterBody?()
    // Reproduce SwiftUI retiring a route animation without delivering completion.
    // A reintroduced callback-based correctness barrier must fail this harness.
    AnimationHarness.droppedCompletions += 1
}
@MainActor final class AppStore: TutorialLeaseStore {
    struct AccountSessionBoundary: Equatable { var slot: String; var generation: Int }
    enum Route { case home, rank, arenaShop, academy, curriculum, wrongNotes, assess }
    var generation = 0
    var authProvider: String? = "server"
    var serverProfile: Profile? = Profile()
    var requestedDashboardTutorial = true
    var requestedArenaTutorialChapter: String? = "ranked"
    var isSessionMode = false
    var route = Route.home
    var accepted = 0
    var coach=Coach()
    var motionOn=false
    func captureAccountSessionBoundary() -> AccountSessionBoundary { .init(slot:DataScope.slot,generation:generation) }
    func ownsCurrentAccountSession(_ owner: AccountSessionBoundary)->Bool { owner == captureAccountSessionBoundary() }
    func acceptServerProfile(_ profile:Profile,owner:AccountRequestOwner) {
        precondition(owner.isCurrent(in:self));serverProfile=profile;accepted += 1
    }
    func switchToB() {
        generation += 1;DataScope.slot="B";ServerAPI.token="token-B"
        serverProfile=Profile();requestedDashboardTutorial=true;requestedArenaTutorialChapter="ranked_shop"
        // Actual account cleanup/direct-cover assignment invalidates old lease.
        isTutorialPresentationActive=false
        isTutorialPresentationActive=true
    }
}
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot: Equatable { var token:String }
    struct Call: Equatable { var operation:String; var token:String }
    static var token:String?="token-A"
    static var calls:[Call]=[]
    static var holdAt:String?
    static var continuation:CheckedContinuation<Void,Never>?
    static var fail=false
    static func captureAuthorization()->AuthorizationSnapshot? {token.map{.init(token:$0)}}
    static func isCurrentAuthorization(_ value:AuthorizationSnapshot)->Bool {token==value.token}
    static func reset(){token="token-A";calls=[];holdAt=nil;continuation=nil;fail=false;DataScope.slot="A"}
    static func record(_ operation:String,_ authorization:AuthorizationSnapshot)async throws {
        calls.append(.init(operation:operation,token:authorization.token))
        if operation==holdAt {await withCheckedContinuation{continuation=$0}}
        if fail {throw ServerAPIError.failed}
    }
    static func updateDashboardTutorial(_ action:String,authorization:AuthorizationSnapshot)async throws->Bool {
        try await record("dashboard:"+action,authorization);return true
    }
    static func updateCoachMode(_ mode:String,authorization:AuthorizationSnapshot)async throws {
        try await record("coach:"+mode,authorization)
    }
    static func updateArenaTutorial(chapter:String,action:String,authorization:AuthorizationSnapshot)async throws->Bool {
        try await record("arena:"+chapter+":"+action,authorization);return true
    }
    static func me(authorization:AuthorizationSnapshot)async throws->Profile {
        try await record("me",authorization);return Profile(dashboardTutorial:TutorialStatus(status:"COMPLETED"))
    }
    static func release(){let value=continuation;continuation=nil;value?.resume()}
}
@MainActor final class ProfileHarness {
    let store:AppStore
    var serverProfileError:String?
    init(_ store:AppStore){self.store=store}
    func refreshServerProfile(force:Bool)async {
        guard let owner=AccountRequestOwner(store:store)else{return}
        if let profile=try? await ServerAPI.me(authorization:owner.authorization),owner.isCurrent(in:store){store.acceptServerProfile(profile,owner:owner)}
    }
}
@main struct Cases {
    @MainActor static func until(_ condition:()->Bool)async {
        for _ in 0..<20_000 {if condition(){return};await Task.yield()}
        fatalError("Controlled continuation not reached")
    }
    @MainActor static func main()async {
        var count=0
        func fixture()->(AppStore,TutorialHarness){
            ServerAPI.reset();AnimationHarness.reset()
            if let current=TutorialFocusRequestCenter.current {TutorialFocusRequestCenter.cancel(ownerID:current.ownerID)}
            let store=AppStore();return(store,TutorialHarness(store))
        }
        func assertB(_ store:AppStore){precondition(store.accepted==0);precondition(store.isTutorialPresentationActive);precondition(store.requestedDashboardTutorial);precondition(store.requestedArenaTutorialChapter=="ranked_shop")}
        for motion in [false,true] {
            let(store,flow)=fixture();flow.begin(.arena("unranked"));flow.reduceMotion = !motion;store.motionOn=motion
            await flow.settleCurrent(on:.rank)
            guard flow.spotlightVisible else {print("FAIL: missing animation completion left actual settle inactive");exit(1)}
            precondition(store.route == .rank && flow.visible)
            precondition(TutorialFocusRequestCenter.current?.ownerID == flow.ownerID)
            precondition(TutorialFocusRequestCenter.current?.target == .arenaMatchmaking)
            precondition(TutorialFocusRequestCenter.current?.animated == motion)
            count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("unranked"));store.route = .rank
            await flow.settleCurrent(on:.rank)
            precondition(flow.spotlightVisible && TutorialFocusRequestCenter.current?.target == .arenaMatchmaking)
            count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("unranked"));let replacement=UUID()
            AnimationHarness.afterBody={store.claimNativeTutorialPresentation(replacement)}
            await flow.settleCurrent(on:.rank)
            precondition(!flow.spotlightVisible && TutorialFocusRequestCenter.current == nil)
            precondition(store.nativeTutorialPresentationOwner == replacement && store.isTutorialPresentationActive)
            count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("unranked"))
            AnimationHarness.afterBody={store.switchToB()}
            await flow.settleCurrent(on:.rank)
            precondition(!flow.spotlightVisible && TutorialFocusRequestCenter.current == nil)
            assertB(store);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("unranked"))
            AnimationHarness.afterBody={store.route = .home}
            await flow.settleCurrent(on:.rank)
            precondition(!flow.spotlightVisible && TutorialFocusRequestCenter.current == nil)
            precondition(store.route == .home);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("unranked"))
            AnimationHarness.afterBody={store.serverProfile?.role="admin"}
            await flow.settleCurrent(on:.rank)
            precondition(!flow.spotlightVisible && TutorialFocusRequestCenter.current == nil);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("unranked"));let id=flow.ownerID
            let cancelledRender = Task { @MainActor in
                precondition(Task.isCancelled)
                guard flow.visible else { print("FAIL: cancelled SwiftUI task hid a valid native tutorial lease"); exit(1) }
                await flow.start()
                precondition(flow.visible && flow.ownerID == id)
            }
            cancelledRender.cancel();await cancelledRender.value
            precondition(store.nativeTutorialPresentationOwner == id && store.isTutorialPresentationActive)
            precondition(ServerAPI.calls.isEmpty);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard);let replacement=UUID()
            store.claimNativeTutorialPresentation(replacement)
            let cancelledRender = Task { @MainActor in
                precondition(Task.isCancelled && !flow.visible);await flow.start()
            }
            cancelledRender.cancel();await cancelledRender.value
            await flow.start()
            precondition(!flow.visible && flow.run == nil)
            precondition(store.nativeTutorialPresentationOwner == replacement && store.isTutorialPresentationActive)
            count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard);let mutation=flow.save()
            mutation?.cancel();await mutation?.value
            precondition(ServerAPI.calls.isEmpty && store.accepted == 0);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard);ServerAPI.holdAt="dashboard:COMPLETE"
            let mutation=flow.save();await until{ServerAPI.continuation != nil}
            mutation?.cancel();ServerAPI.release();await mutation?.value
            precondition(ServerAPI.calls.map(\.operation) == ["dashboard:COMPLETE"] && store.accepted == 0)
            count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard);let task=flow.save();store.switchToB()
            precondition(!flow.visible);await task?.value
            precondition(ServerAPI.calls.isEmpty);assertB(store);precondition(flow.run==nil);count += 1
        }
        for operation in ["dashboard:COMPLETE","me"] {
            let(store,flow)=fixture();flow.begin(.dashboard);ServerAPI.holdAt=operation;let task=flow.save()
            await until{ServerAPI.continuation != nil};store.switchToB();await flow.start();ServerAPI.release();await task?.value
            precondition(ServerAPI.calls.allSatisfy{$0.token=="token-A"});assertB(store);precondition(!flow.visible);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.arena("ranked"));store.serverProfile?.role="teacher"
            precondition(!flow.visible);await flow.start();precondition(flow.run==nil);precondition(flow.save()==nil)
            precondition(ServerAPI.calls.isEmpty);precondition(!store.isTutorialPresentationActive);count += 1
        }
        do {
            let(_,flow)=fixture();flow.begin(.dashboard);let task=flow.save();ServerAPI.token="new-token-same-account"
            await task?.value;precondition(ServerAPI.calls.isEmpty);precondition(!flow.visible);count += 1
        }
        for skipped in [false,true] {
            let(store,flow)=fixture();flow.begin(skipped ? .arena("ranked_shop") : .dashboard)
            await flow.save(skipped:skipped)?.value
            precondition(ServerAPI.calls.map(\.operation)==[skipped ? "arena:ranked_shop:SKIP":"dashboard:COMPLETE","me"])
            precondition(ServerAPI.calls.allSatisfy{$0.token=="token-A"});precondition(store.accepted==1)
            precondition(!store.isTutorialPresentationActive);precondition(store.nativeTutorialPresentationOwner==nil);precondition(!flow.visible);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard);ServerAPI.holdAt="dashboard:COMPLETE";let oldTask=flow.save()
            await until{ServerAPI.continuation != nil};flow.stop();flow.begin(.arena("ranked"));let newID=flow.ownerID
            ServerAPI.release();await oldTask?.value
            precondition(flow.visible);precondition(flow.ownerID==newID);precondition(store.nativeTutorialPresentationOwner==newID)
            precondition(store.isTutorialPresentationActive);precondition(store.accepted==0);flow.stop();count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard);ServerAPI.fail=true;await flow.save()?.value
            precondition(flow.visible);precondition(!flow.mutationInFlight);precondition(flow.mutationError != nil);precondition(store.accepted==0)
            ServerAPI.fail=false;await flow.save()?.value;precondition(!flow.visible);precondition(store.accepted==1);count += 1
        }
        // Both production RESTART callbacks capture A before queuing a Task.
        for arena in [false,true] {
            let(store,_)=fixture();let profile=ProfileHarness(store)
            if arena{profile.restartArena("ranked")}else{profile.restartDashboard()};store.switchToB()
            for _ in 0..<200 {await Task.yield()}
            precondition(ServerAPI.calls.isEmpty);assertB(store);count += 1
        }
        for arena in [false,true] {
            let(store,_)=fixture();let profile=ProfileHarness(store)
            ServerAPI.holdAt=arena ? "arena:ranked:RESTART":"dashboard:RESTART"
            if arena{profile.restartArena("ranked")}else{profile.restartDashboard()}
            await until{ServerAPI.continuation != nil};store.switchToB();ServerAPI.release()
            for _ in 0..<200 {await Task.yield()}
            precondition(ServerAPI.calls.count==1 && ServerAPI.calls[0].token=="token-A");assertB(store);count += 1
        }
        do {
            let(store,flow)=fixture();flow.begin(.dashboard)
            // A different overlay on the SAME account claimed the Boolean.
            store.isTutorialPresentationActive=true
            await flow.start();precondition(!flow.visible);precondition(store.isTutorialPresentationActive)
            precondition(store.requestedDashboardTutorial);precondition(ServerAPI.calls.isEmpty);count += 1
        }
        for operation in ["queued","coach:SPICY","dashboard:COMPLETE","me"] {
            ServerAPI.reset();let store=AppStore();store.requestedDashboardTutorial=false
            let flow=LegacyTutorialHarness(store);flow.start();precondition(flow.visible);flow.selectedCoach = .spicy
            if operation != "queued"{ServerAPI.holdAt=operation};let task=flow.save()
            if operation != "queued"{await until{ServerAPI.continuation != nil}}
            store.switchToB();store.coach.level = .mild
            precondition(!flow.visible);flow.start();ServerAPI.release();await task?.value
            precondition(ServerAPI.calls.allSatisfy{$0.token=="token-A"});precondition(store.coach.level == .mild)
            if operation=="queued"{precondition(ServerAPI.calls.isEmpty)}
            assertB(store);precondition(store.route == .home);count += 1
        }
        for skipped in [false,true] {
            ServerAPI.reset();let store=AppStore();store.requestedDashboardTutorial=false
            let flow=LegacyTutorialHarness(store);flow.start();flow.selectedCoach = .spicy;await flow.save(skipped:skipped)?.value
            precondition(ServerAPI.calls.map(\.operation)==(skipped ? ["dashboard:SKIP","me"]:["coach:SPICY","dashboard:COMPLETE","me"]))
            precondition(store.route == (skipped ? .home:.curriculum));precondition(store.accepted==1)
            precondition(!flow.visible);precondition(!store.isTutorialPresentationActive);count += 1
        }
        do {
            ServerAPI.reset();let store=AppStore();store.requestedDashboardTutorial=false
            let flow=LegacyTutorialHarness(store);flow.start();store.serverProfile?.role="admin"
            precondition(!flow.visible);flow.start();precondition(!flow.isPresented);precondition(flow.save()==nil)
            precondition(ServerAPI.calls.isEmpty);precondition(!store.isTutorialPresentationActive);count += 1
        }
        do {
            ServerAPI.reset();let store=AppStore();store.requestedDashboardTutorial=false
            let flow=LegacyTutorialHarness(store);flow.start();ServerAPI.holdAt="coach:MILD";let task=flow.save()
            await until{ServerAPI.continuation != nil}
            let native=TutorialHarness(store);native.begin(.arena("ranked"));let nativeID=native.ownerID
            flow.stop();ServerAPI.release();await task?.value
            precondition(native.visible && store.isTutorialPresentationActive);precondition(store.nativeTutorialPresentationOwner==nativeID)
            precondition(ServerAPI.calls.count==1);native.stop();count += 1
        }
        do {
            ServerAPI.reset();let store=AppStore();store.requestedDashboardTutorial=false
            let flow=LegacyTutorialHarness(store);flow.start();ServerAPI.fail=true;await flow.save()?.value
            precondition(flow.visible && !flow.saving && flow.errorMessage != nil);ServerAPI.fail=false
            await flow.save()?.value;precondition(!flow.visible && store.accepted==1);count += 1
        }
        print("Native tutorial production flow/AccountRequestOwner/presentation lease: PASS (\(count) deterministic cases; controlled HTTP, no device/network)")
    }
}
