import Foundation
import CryptoKit

struct ServerAPIError:Error {var message:String;var errorDescription:String?{message}}
#if RESOURCE_FLOW
@MainActor enum DataScope {static var slot="A";static var base=FileManager.default.temporaryDirectory
    static var directory:URL{base.appendingPathComponent(slot,isDirectory:true)}
}
struct Profile{var role:String?="admin"}
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
    static var calls:[String]=[]
    static var hold=false
    static var continuation:CheckedContinuation<Void,Never>?
    static func captureAuthorization()->AuthorizationSnapshot?{token.map{.init(token:$0)}}
    static func isCurrentAuthorization(_ snapshot:AuthorizationSnapshot)->Bool{snapshot.token==token}
    static func adminAnswerKeyResource(_ resource:AdminAnswerKeyResource,authorization:AuthorizationSnapshot)async throws->Data {
        calls.append(authorization.token)
        if hold{await withCheckedContinuation{continuation=$0}}
        return Data("controlled-download-bytes".utf8)
    }
    static func release(){let value=continuation;continuation=nil;value?.resume()}
}
@main struct FlowCases {
    @MainActor static func main()async throws {
        for phase in ["queued","waiting","role","success","closed"] {
            let directory=FileManager.default.temporaryDirectory.appendingPathComponent("matths-resource-case-"+UUID().uuidString,isDirectory:true)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
            defer {try? FileManager.default.removeItem(at:directory)}
            DataScope.base=directory;DataScope.slot="A";ServerAPI.token="A";ServerAPI.calls=[];ServerAPI.hold=phase != "queued" && phase != "success"
            let store=AppStore(),flow=ResourcePanelHarness(AppStore());_ = store
            let task=flow.start()
            if ServerAPI.hold {
                for _ in 0..<20_000{if ServerAPI.continuation != nil{break};await Task.yield()}
                precondition(ServerAPI.continuation != nil)
            }
            if phase=="queued" || phase=="waiting" {flow.store.switchToB()}
            if phase=="role"{flow.store.serverProfile?.role="student"}
            if phase=="closed"{flow.stop()}
            ServerAPI.release();await task?.value
            if phase=="success" {
                let file=flow.downloaded[.catalog]!
                let saved = try Data(contentsOf:file)
                precondition(saved==Data("controlled-download-bytes".utf8))
                precondition(file.path.hasPrefix(directory.appendingPathComponent("A").path+"/"))
                let permissions=try FileManager.default.attributesOfItem(atPath:file.path)[.posixPermissions] as! NSNumber
                precondition(permissions.intValue==0o600)
            } else {
                precondition(flow.downloaded.isEmpty)
                let contents = try FileManager.default.contentsOfDirectory(atPath:directory.path)
                precondition(contents.isEmpty,"stale download recreated account directory")
            }
            precondition(ServerAPI.calls.allSatisfy{$0=="A"})
            if phase=="queued"{precondition(ServerAPI.calls.isEmpty)}
        }
        print("Admin template production UI download flow: PASS queued/waiting/role/closed ownership and private 0600 byte-preserving save")
    }
}
#else
enum ServerAPI {
    struct AuthorizationSnapshot {var token:String}
    static func authorizedRequest(_ method:String,_ path:String,timeout:TimeInterval,authorization:AuthorizationSnapshot) throws->URLRequest {
        var request=URLRequest(url:URL(string:"http://127.0.0.1:1"+path)!);request.httpMethod=method
        request.setValue("Bearer "+authorization.token,forHTTPHeaderField:"Authorization");return request
    }
    static func bearerToken(from request:URLRequest)->String?{request.value(forHTTPHeaderField:"Authorization")}
    static func validateAuthorizedResponse(_ response:URLResponse,errorBody:Data,requestToken:String?) throws {
        guard let http=response as? HTTPURLResponse,http.statusCode==200 else{throw ServerAPIError(message:"HTTP failure")}
    }
}
@main struct ValidationCases {
    static func main() throws {
        func checksum(_ data:Data)->String{SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
        func rejects(_ operation:()throws->Void){do{try operation();fatalError("bad resource accepted")}catch{}}
        // Structural unit fixtures only: these contain no operational answers or
        // fabricated curriculum. Real tracked template bytes are verified in the
        // backend HTTP/Mongo integration test, not replaced by these fixtures.
        let skeleton=try JSONSerialization.data(withJSONObject:["schemaVersion":"matths-answer-key-v3","questions":Array(repeating:["number":1],count:30)])
        let catalog=Data("# AI 주간 모의고사 개념 카탈로그\nunit-validation-only".utf8)
        try AdminAnswerKeyResource.skeleton.validate(skeleton,mime:"application/json",checksum:checksum(skeleton))
        try AdminAnswerKeyResource.catalog.validate(catalog,mime:"text/markdown",checksum:checksum(catalog))
        rejects{try AdminAnswerKeyResource.skeleton.validate(skeleton,mime:"text/html",checksum:checksum(skeleton))}
        rejects{try AdminAnswerKeyResource.catalog.validate(catalog,mime:"text/markdown",checksum:"changed")}
        rejects{try AdminAnswerKeyResource.catalog.validate(Data(),mime:"text/markdown",checksum:checksum(Data()))}
        let large=Data(repeating:1,count:AdminAnswerKeyResource.maximumBytes+1)
        rejects{try AdminAnswerKeyResource.catalog.validate(large,mime:"text/markdown",checksum:checksum(large))}
        let old=Data("{\"schemaVersion\":\"matths-answer-key-v1\",\"questions\":[]}".utf8)
        rejects{try AdminAnswerKeyResource.skeleton.validate(old,mime:"application/json",checksum:checksum(old))}
        let legacy=Data("{\"number\":1,\"mode\":\"multiple-choice\",\"submittedAnswer\":\"1\",\"correctAnswer\":\"1\",\"isCorrect\":true,\"points\":2}".utf8)
        let previous=try JSONDecoder().decode(ServerAPI.AdminMockQuestionReview.self,from:legacy)
        precondition(previous.concept==nil)
        var row=try JSONSerialization.jsonObject(with:legacy) as! [String:Any]
        row["concept"]=["curriculumId":"source-curriculum","courseId":"source-course","courseTitle":"source-course-title","unitId":"source-unit","unitTitle":"source-unit-title","conceptId":"source-concept","conceptTitle":"source-title","conceptKey":"source/key"]
        let current=try JSONDecoder().decode(ServerAPI.AdminMockQuestionReview.self,from:JSONSerialization.data(withJSONObject:row))
        precondition(current.concept?.conceptKey=="source/key" && current.concept?.conceptTitle=="source-title")
        print("Admin templates production downloader compile + validator: PASS MIME/SHA256/byte/version bounds; review canonical metadata + legacy nil decode")
    }
}
#endif
