import Foundation

@MainActor enum DataScope {
    static var slot = "A"
    static var directory:URL{URL(fileURLWithPath:"/unused-weekly-insight-test/"+slot)}
}
struct ServerAPIError:Error {var message:String;var errorDescription:String?{message}}
struct Profile{var role:String?="teacher"}
@MainActor final class AppStore {
    struct AccountSessionBoundary:Equatable {var slot:String;var generation:Int}
    var generation=0
    var serverProfile:Profile?=Profile()
    func captureAccountSessionBoundary()->AccountSessionBoundary{.init(slot:DataScope.slot,generation:generation)}
    func ownsCurrentAccountSession(_ value:AccountSessionBoundary)->Bool{value==captureAccountSessionBoundary()}
    func switchToB(){generation += 1;DataScope.slot="B";ServerAPI.token="B"}
}
@MainActor enum ServerAPI {
    struct AuthorizationSnapshot {var token:String}
    static var token:String?="A"
    static var expectedPath=""
    static var authorizationUsed=""
    static var payload=Data()
    static var hold=false
    static var continuation:CheckedContinuation<Void,Never>?
    static func captureAuthorization()->AuthorizationSnapshot?{token.map{.init(token:$0)}}
    static func isCurrentAuthorization(_ snapshot:AuthorizationSnapshot)->Bool{snapshot.token==token}
    static func request<T:Decodable>(_ method:String,_ path:String,body:[String:String]?,authed:Bool,authorization:AuthorizationSnapshot)async throws->T {
        precondition(method=="GET" && authed && body==nil);precondition(path==expectedPath)
        authorizationUsed=authorization.token
        let captured=payload
        if hold{await withCheckedContinuation{continuation=$0}}
        return try JSONDecoder().decode(T.self,from:captured)
    }
    static func release(){let value=continuation;continuation=nil;value?.resume()}
}
@main struct Cases {
    @MainActor static func until(_ condition:()->Bool)async {
        for _ in 0..<20_000{if condition(){return};await Task.yield()};fatalError("Boundary not reached")
    }
    @MainActor static func main()async throws {
        let classID="0123456789abcdef01234567",academyID="1123456789abcdef01234567"
        func fixture(_ kind:String="academy",_ id:String="1123456789abcdef01234567")throws->Data {
            try JSONSerialization.data(withJSONObject:["schemaVersion":"WEEKLY_MOCK_INSIGHTS_NATIVE_V1",
                "scope":["kind":kind,"id":id,"label":"검증 범위"],"classes":[],"overall":[
                    "scopeLabel":"학원 전체","examCount":0,"participantCount":0,"submissionCount":0,
                    "averageScore":NSNull(),"conceptCount":0,"concepts":[],"hardestConcept":NSNull(),"generatedAt":"2026-09-07T00:00:00.000Z"]])
        }
        func reset(){DataScope.slot="A";ServerAPI.token="A";ServerAPI.hold=false;ServerAPI.continuation=nil}
        let scopeCases:[(WeeklyMockInsightScope,String,String,String)] = [
            (.teacher(classID:nil),"/api/v1/academy/teacher/weekly-mock-insights","academy",academyID),
            (.teacher(classID:classID),"/api/v1/academy/teacher/weekly-mock-insights?classId="+classID,"class",classID),
            (.admin(academyID:nil),"/api/v1/admin/weekly-mock-insights","global","global"),
            (.admin(academyID:academyID),"/api/v1/academy/admin/"+academyID+"/weekly-mock-insights","academy",academyID)]
        for(scope,path,kind,id)in scopeCases {
            reset();ServerAPI.expectedPath=path;ServerAPI.payload=try fixture(kind,id)
            let value=try await ServerAPI.weeklyMockInsights(scope:scope,authorization:.init(token:"A"))
            precondition(value.overall.averageScore==nil && value.overall.concepts.isEmpty)
            precondition(ServerAPI.authorizationUsed=="A")
        }
        do{_ = try WeeklyMockInsightScope.teacher(classID:"?userId=B").path();fatalError("invalid ID accepted")}catch{}
        ServerAPI.expectedPath=try WeeklyMockInsightScope.teacher(classID:classID).path()
        ServerAPI.payload=try fixture("class",academyID)
        do{_ = try await ServerAPI.weeklyMockInsights(scope:.teacher(classID:classID),authorization:.init(token:"A"));fatalError("wrong scope accepted")}catch{}
        let data=try fixture();var unknown=try JSONSerialization.jsonObject(with:data) as! [String:Any];unknown["schemaVersion"]="UNKNOWN"
        ServerAPI.payload=try JSONSerialization.data(withJSONObject:unknown);ServerAPI.expectedPath=try WeeklyMockInsightScope.teacher(classID:nil).path()
        do{_ = try await ServerAPI.weeklyMockInsights(scope:.teacher(classID:nil),authorization:.init(token:"A"));fatalError("wrong version accepted")}catch{}
        for change in ["account","role","scope","credential"] {
            reset();ServerAPI.expectedPath=try WeeklyMockInsightScope.teacher(classID:nil).path();ServerAPI.payload=data;ServerAPI.hold=true
            let store=AppStore(),flow=InsightHarness(AppStore(),scope:.teacher(classID:nil))
            // Keep the store owned by this flow; the separate instance proves no
            // global request owner is accidentally used in production control flow.
            _=store
            let task=Task{await flow.refresh()};await until{ServerAPI.continuation != nil}
            switch change{
            case "account":flow.store.switchToB()
            case "role":flow.store.serverProfile?.role="student"
            case "scope":flow.scope = .teacher(classID:classID)
            default:ServerAPI.token="rotated-A"
            }
            precondition(!flow.canDisplay);ServerAPI.release();await task.value
            precondition(flow.response==nil && flow.errorMessage==nil && !flow.isLoading)
            precondition(ServerAPI.authorizationUsed=="A")
        }
        reset();ServerAPI.expectedPath=try WeeklyMockInsightScope.teacher(classID:nil).path();ServerAPI.payload=data
        let flow=InsightHarness(AppStore(),scope:.teacher(classID:nil));await flow.refresh()
        precondition(flow.canDisplay && flow.response?.overall.averageScore==nil && !flow.isLoading)
        print("Weekly mock insights native DTO/API + actual panel load flow: PASS (4 scopes, nil/empty, invalid ID/schema/scope, 4 account/role/scope/token races; controlled HTTP)")
    }
}
