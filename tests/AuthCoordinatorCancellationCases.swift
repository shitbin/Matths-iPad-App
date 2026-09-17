import Foundation

struct ServerAPIError: Error { var message: String; var code: String }
struct ASAuthorizationError: Error {
    enum Code { case canceled }
    let code: Code
    init(_ code: Code) { self.code = code }
}
struct ASWebAuthenticationSessionError: Error {
    enum Code { case canceledLogin }
    let code: Code
    init(_ code: Code) { self.code = code }
}
protocol ASAuthorizationControllerDelegate: AnyObject {}
class ASAuthorizationAppleIDCredential: NSObject { let fixtureID: Int; init(_ id:Int){fixtureID=id} }
class ASAuthorization: NSObject {
    enum Scope { case fullName, email }
    let credential: AnyObject
    init(_ value:AnyObject){credential=value}
}
class AuthorizationRequest {var requestedScopes:[ASAuthorization.Scope]=[];var nonce:String?}
class ASAuthorizationAppleIDProvider {func createRequest()->AuthorizationRequest{.init()}}
@MainActor class ASAuthorizationController: NSObject {
    static var all:[ASAuthorizationController]=[]
    static var reportsCancel=false
    weak var delegate:AnyObject?
    weak var presentationContextProvider:AnyObject?
    var cancelCount=0
    init(authorizationRequests:[AuthorizationRequest]){super.init()}
    func performRequests(){Self.all.append(self)}
    func cancel(){
        cancelCount += 1
        if Self.reportsCancel, let owner=delegate as? AppleSignInCoordinator {
            owner.authorizationController(controller:self,didCompleteWithError:ASAuthorizationError(.canceled))
        }
    }
}
@MainActor class ASWebAuthenticationSession: NSObject {
    static var all:[ASWebAuthenticationSession]=[]
    static var reportsCancel=false
    static var starts=true
    weak var presentationContextProvider:AnyObject?
    var prefersEphemeralWebBrowserSession=false
    let completion:(URL?,Error?)->Void
    var cancelCount=0
    init(url:URL,callbackURLScheme:String?,completionHandler:@escaping(URL?,Error?)->Void){
        precondition(callbackURLScheme=="matths")
        completion=completionHandler;super.init();Self.all.append(self)
    }
    func start()->Bool{Self.starts}
    func cancel(){cancelCount += 1;if Self.reportsCancel{completion(nil,ASWebAuthenticationSessionError(.canceledLogin))}}
}
struct DelayedOldError:Error{}

@main struct Cases {
    @MainActor static func until(_ test:()->Bool)async{for _ in 0..<20_000{if test(){return};await Task.yield()};fatalError("controlled boundary not reached")}
    @MainActor static func drain()async{for _ in 0..<40{await Task.yield()}}
    @MainActor static func main()async throws {
        var count=0
        // Drive the real coordinator's credential continuation through the
        // policy AuthScreen uses when native UI temporarily owns presentation.
        ASAuthorizationController.all=[];ASAuthorizationController.reportsCancel=true
        let presentedApple=AppleSignInCoordinator()
        let nativeTask=presentedApple.begin()
        await until{ASAuthorizationController.all.count==1}
        let presentedController=ASAuthorizationController.all[0]
        for _ in 0..<3 {
            if NativeAuthenticationPresentationPolicy.shouldCancelOnAuthScreenDisappear(
                isBusy:true, sessionPublished:false
            ) { nativeTask.cancel(); presentedApple.cancel() }
            await drain()
        }
        precondition(presentedController.cancelCount==0,
                     "transient disappearance cancelled Apple credential delivery")
        presentedApple.authorizationController(controller:presentedController,
            didCompleteWithAuthorization:ASAuthorization(ASAuthorizationAppleIDCredential(3)))
        let nativeResult=try await nativeTask.value
        precondition(nativeResult.fixtureID==3 && !nativeTask.isCancelled)
        count += 1
        for reportsCancel in [false,true] {
            for oldError in [false,true] {
                ASAuthorizationController.all=[];ASAuthorizationController.reportsCancel=reportsCancel
                let owner=AppleSignInCoordinator()
                let a=owner.begin();await until{ASAuthorizationController.all.count==1}
                let old=ASAuthorizationController.all[0]
                owner.cancel();_ = try? await a.value
                precondition(old.cancelCount==1)
                let b=owner.begin();await until{ASAuthorizationController.all.count==2}
                let current=ASAuthorizationController.all[1]
                if oldError {owner.authorizationController(controller:old,didCompleteWithError:DelayedOldError())}
                else {owner.authorizationController(controller:old,didCompleteWithAuthorization:ASAuthorization(ASAuthorizationAppleIDCredential(1)))}
                await drain();precondition(owner.activeController===current,"old Apple delegate displaced current operation")
                owner.authorizationController(controller:current,didCompleteWithAuthorization:ASAuthorization(ASAuthorizationAppleIDCredential(2)))
                let result=try await b.value;precondition(result.fixtureID==2 && owner.activeController==nil)
                owner.authorizationController(controller:current,didCompleteWithError:DelayedOldError())
                owner.authorizationController(controller:old,didCompleteWithAuthorization:ASAuthorization(ASAuthorizationAppleIDCredential(1)))
                await drain();precondition(owner.activeController==nil);count += 1
            }
        }
        for startsCanceled in [false,true] {
            ASAuthorizationController.all=[];ASAuthorizationController.reportsCancel=false
            let owner=AppleSignInCoordinator();let task=owner.begin()
            if !startsCanceled{await until{ASAuthorizationController.all.count==1}}
            task.cancel();_ = try? await task.value
            precondition(owner.activeController==nil)
            precondition(startsCanceled ? ASAuthorizationController.all.isEmpty : ASAuthorizationController.all[0].cancelCount==1)
            count += 1
        }
        for provider in ["Google","Kakao"] {
            for reportsCancel in [false,true] {
                ASWebAuthenticationSession.all=[];ASWebAuthenticationSession.reportsCancel=reportsCancel;ASWebAuthenticationSession.starts=true
                let google=GoogleHarness(),kakao=KakaoHarness()
                func begin()->Task<URL,Error>{provider=="Google" ? google.begin():kakao.begin()}
                func cancel(){if provider=="Google"{google.cancel()}else{kakao.cancel()}}
                func active()->ASWebAuthenticationSession?{provider=="Google" ? google.activeSession:kakao.activeSession}
                let a=begin();await until{ASWebAuthenticationSession.all.count==1}
                let old=ASWebAuthenticationSession.all[0];cancel();_ = try? await a.value
                precondition(old.cancelCount==1)
                let b=begin();await until{ASWebAuthenticationSession.all.count==2}
                let current=ASWebAuthenticationSession.all[1]
                old.completion(URL(string:"matths://oauth/ignored")!,nil)
                old.completion(nil,DelayedOldError())
                await drain();precondition(active()===current,"old web callback displaced current session")
                cancel();_ = try? await b.value;precondition(current.cancelCount==1 && active()==nil)
                let c=begin();await until{ASWebAuthenticationSession.all.count==3}
                let newest=ASWebAuthenticationSession.all[2]
                let url=URL(string:"matths://oauth/completed")!
                newest.completion(url,nil);let completedURL = try await c.value;precondition(completedURL==url)
                newest.completion(nil,DelayedOldError());old.completion(nil,DelayedOldError())
                await drain();precondition(active()==nil);count += 1
            }
            for startsCanceled in [false,true] {
                ASWebAuthenticationSession.all=[];ASWebAuthenticationSession.reportsCancel=false;ASWebAuthenticationSession.starts=true
                let google=GoogleHarness(),kakao=KakaoHarness()
                let task=provider=="Google" ? google.begin():kakao.begin()
                if !startsCanceled{await until{ASWebAuthenticationSession.all.count==1}}
                task.cancel();_ = try? await task.value
                precondition(startsCanceled ? ASWebAuthenticationSession.all.isEmpty : ASWebAuthenticationSession.all[0].cancelCount==1)
                count += 1
            }
            ASWebAuthenticationSession.all=[];ASWebAuthenticationSession.starts=false
            let google=GoogleHarness(),kakao=KakaoHarness()
            let failed=provider=="Google" ? google.begin():kakao.begin()
            do{_ = try await failed.value;fatalError("start failure returned success")}catch is ServerAPIError{}
            ASWebAuthenticationSession.all[0].completion(nil,DelayedOldError())
            await drain();precondition(provider=="Google" ? google.activeSession==nil:kakao.activeSession==nil);count += 1
        }
        print("Authentication coordinator production cancellation/identity cases: \(count) PASS; original four races, native cancel with/without callbacks, duplicate delivery, early/late Task cancellation, start failure")
        print("Controlled OS boundary only: no device, browser, authentication, provider token or nonce output")
    }
}
