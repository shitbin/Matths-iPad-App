import Foundation
@MainActor enum DataScope {static var slot="A";static var directory:URL{URL(fileURLWithPath:"/unused-staff-owner/"+slot)}}
struct Profile{var role:String?}
@MainActor final class AppStore {
    struct AccountSessionBoundary:Equatable{var slot:String;var generation:Int}
    var generation=0
    var authProvider:String?="server"
    var serverProfile:Profile?
    init(role:String){serverProfile=Profile(role:role)}
    func captureAccountSessionBoundary()->AccountSessionBoundary{.init(slot:DataScope.slot,generation:generation)}
    func ownsCurrentAccountSession(_ value:AccountSessionBoundary)->Bool{value==captureAccountSessionBoundary()}
    func switchAccount(){generation += 1;DataScope.slot="B";ServerAPI.token="B"}
}
struct ServerAPIError:Error {var message:String;var code:String?=nil}
enum ServerAPI {
    struct AuthorizationSnapshot{var token:String}
    struct TeacherAcademySetup{}
    struct TeacherAcademyDashboard{}
    struct TeacherAcademyMembership{var id:String}
    struct AdminUserSummary{var id:String;var entityType:String="USER"}
    struct AdminParentChild{var id:String}
    struct AdminUserDetail:Decodable{var user:AdminUserSummary?}
    struct AdminUserPagination:Decodable{var page:Int}
    struct AdminUserList:Decodable{var pagination:AdminUserPagination}
    struct AdminUserMutationEnvelope:Decodable{var schemaVersion:String;var ok:Bool;var delivered:Bool?;var purged:Bool?;var detail:AdminUserDetail?}
    static var token:String?="A",calls:[String]=[]
    static var hold=false
    static var continuation:CheckedContinuation<Void,Never>?
    struct Recorded:Error{}
    @MainActor static func reset(){token="A";calls=[];hold=false;continuation=nil;DataScope.slot="A"}
    static func captureAuthorization()->AuthorizationSnapshot?{token.map{.init(token:$0)}}
    static func authorizationForCurrentRequest()->AuthorizationSnapshot{.init(token:token ?? "NONE")}
    static func isCurrentAuthorization(_ value:AuthorizationSnapshot)->Bool{token==value.token}
    @MainActor static func record(_ auth:AuthorizationSnapshot)async throws{
        calls.append(auth.token)
        if hold{await withCheckedContinuation{continuation=$0}}
        throw Recorded()
    }
    static func request<T:Decodable>(_ method:String,_ path:String,body:[String:Any]?,authed:Bool,authorization:AuthorizationSnapshot)async throws->T{
        try await record(authorization);throw Recorded()
    }
    static func createTeacherAcademy(name:String,authorization:AuthorizationSnapshot=authorizationForCurrentRequest())async throws->TeacherAcademySetup{
        try await record(authorization);throw Recorded()
    }
    static func reviewAcademyStudent(membershipID:String,approve:Bool,authorization:AuthorizationSnapshot=authorizationForCurrentRequest())async throws->TeacherAcademyDashboard{
        try await record(authorization);throw Recorded()
    }
    static func adminUsers(query:String,grade:String,state:String,role:String,page:Int,authorization:AuthorizationSnapshot)async throws->AdminUserList{try await record(authorization);throw Recorded()}
    static func adminUser(id:String,authorization:AuthorizationSnapshot)async throws->AdminUserDetail{try await record(authorization);throw Recorded()}
    static func adminParent(id:String,authorization:AuthorizationSnapshot)async throws->AdminUserDetail{try await record(authorization);throw Recorded()}
    static func release(){let value=continuation;continuation=nil;value?.resume()}
}
extension ServerAPI.AdminUserSummary:Decodable{}
@main struct StaffMutationOwnerCases {
    @MainActor static func main()async {
        let repro=ProcessInfo.processInfo.arguments.contains("--demonstrate-before-fix")
        for path in ["teacher-setup","teacher-review","admin-withdraw"] {
            ServerAPI.reset()
            let store=AppStore(role:path.hasPrefix("teacher") ? "teacher":"admin")
            let teacher=TeacherHarness(store:store),admin=AdminHarness(store:store)
            let request=AdminUserActionRequest(kind:.withdraw,user:.init(id:"target-a"))
            let tasks=(0..<20).map{_ in Task{ @MainActor in
                if path=="teacher-setup"{_ = await teacher.createAcademy(name:"Account A Academy")}
                else if path=="teacher-review"{await teacher.review(.init(id:"membership-a"),approve:true)}
                else{_ = await admin.perform(request,form:.init(),query:"",role:"",state:"",grade:"")}
            }}
            store.switchAccount()
            for task in tasks{await task.value}
            if repro{precondition(!ServerAPI.calls.isEmpty && ServerAPI.calls.allSatisfy{$0=="B"});print("REPRO \(path): queued A UI sent \(ServerAPI.calls.count) mutation(s) with B credential")}
            else{precondition(ServerAPI.calls.isEmpty,"queued \(path) crossed account boundary")}
        }
        if repro{return}
        for change in ["role","credential","A-B-A"] {
            ServerAPI.reset();let store=AppStore(role:"teacher"),adminStore=AppStore(role:"admin")
            let teacher=TeacherHarness(store:store),admin=AdminHarness(store:adminStore)
            if change=="role"{store.serverProfile?.role="student";adminStore.serverProfile?.role="student"}
            else if change=="credential"{ServerAPI.token="new-A-token"}
            else{store.generation += 2;adminStore.generation += 2}
            _ = await teacher.createAcademy(name:"Account A Academy")
            _ = await admin.perform(.init(kind:.withdraw,user:.init(id:"target-a")),form:.init(),query:"",role:"",state:"",grade:"")
            precondition(ServerAPI.calls.isEmpty,"stale mounted owner survived \(change)")
        }
        for kind in [AdminUserActionKind.notification,.email,.passwordReset,.nickname,.role,.status,.warnings,.package,.withdraw,.parentStatus,.parentNotifications,.parentUnlink] {
            ServerAPI.reset();let store=AppStore(role:"admin");let model=AdminHarness(store:store)
            let action=AdminUserActionRequest(kind:kind,user:.init(id:"target-a"),child:.init(id:"child-a"))
            _ = await model.perform(action,form:.init(),query:"",role:"",state:"",grade:"")
            precondition(ServerAPI.calls==["A"],"action \(kind) lost explicit mounted authorization")
        }
        for path in ["teacher","admin"] {
            ServerAPI.reset();let store=AppStore(role:path);let teacher=TeacherHarness(store:store),admin=AdminHarness(store:store)
            ServerAPI.hold=true
            let task=Task{@MainActor in
                if path=="teacher"{_ = await teacher.createAcademy(name:"Account A Academy")}
                else{_ = await admin.perform(.init(kind:.withdraw,user:.init(id:"target-a")),form:.init(),query:"",role:"",state:"",grade:"")}
            }
            for _ in 0..<20_000{if ServerAPI.continuation != nil{break};await Task.yield()}
            precondition(ServerAPI.continuation != nil);DataScope.slot="B";ServerAPI.token="B";ServerAPI.release();await task.value
            precondition(ServerAPI.calls==["A"]);precondition(teacher.noticeMessage==nil && admin.noticeMessage==nil)
            precondition(teacher.errorMessage==nil && admin.errorMessage==nil)
        }
        print("Staff production mutation flow: PASS 60 queued cross-account rejections, 12 admin API paths, stale in-flight result/error isolation")
    }
}
