import Foundation

enum WKNavigationType {case linkActivated, other}
enum WKNavigationActionPolicy {case allow, cancel}
struct WKFrameInfo {var isMainFrame=true}
struct WKNavigationAction {
    var request:URLRequest
    var targetFrame:WKFrameInfo? = .init()
    var navigationType:WKNavigationType = .linkActivated
}
final class WKWebView {}
struct ExternalDestination {let url:URL}
struct LoadFailure {let message:String;let url:URL?}
struct SessionNotice {let message:String;let offersReconnect:Bool}
enum Block {case signedOut}
@MainActor final class UIApplication {
    static let shared=UIApplication()
    var opened:[URL]=[]
    func open(_ url:URL){opened.append(url)}
}
@MainActor class WebModelHarnessBase {
    let serverBase=URL(string:"https://www.matths.kr")!
    let webView=WKWebView()
    var handingOff=false,wantsNativeCommerce=false,signedIn=true,loginRequired=false,hasWebSession=true,wantsClose=false
    var pendingDestination:URL?,lastInternalURL:URL?,lastArenaURL:URL?,lastHandoffAt:Date?
    var entryPath="/community"
    var destination=ArenaWebDestination.home
    var externalDestination:ExternalDestination?,loadFailure:LoadFailure?,sessionNotice:SessionNotice?,block:Block?
    var loaded:[URL]=[],handoffs=0
    func load(_ url:URL){loaded.append(url)}
    func serverURL(_ path:String)->URL{URL(string:path,relativeTo:serverBase)!.absoluteURL}
    func arenaURL(_ path:String)->URL{serverURL(path)}
    func startHandoff(then destination:URL){handoffs += 1;pendingDestination=destination}
}
@MainActor protocol NavigationHarness:WebModelHarnessBase {
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,
                 decisionHandler:@escaping(WKNavigationActionPolicy)->Void)
}

@main struct ServiceOriginCases {
    @MainActor static func main() {
        var count=0
        func check(_ value:@autoclosure()->Bool,_ label:String){
            guard value() else {print("FAIL: "+label);exit(1)};count += 1
        }
        let base=URL(string:"https://www.matths.kr")!
        guard ProcessInfo.processInfo.arguments.count == 2 else {fatalError("Provide source root for entitlement validation")}
        let entitlementURL=URL(fileURLWithPath:ProcessInfo.processInfo.arguments[1]).appendingPathComponent("Matths/MatthsApp.entitlements")
        let entitlementData=try! Data(contentsOf:entitlementURL)
        let entitlements=try! PropertyListSerialization.propertyList(from:entitlementData,format:nil) as! [String:Any]
        let domains=entitlements["com.apple.developer.associated-domains"] as? [String] ?? []
        let expectedDomains=["www.matths.kr","matths.kr","app.matths.kr","academy.matths.kr","admin.matths.kr","parents.matths.kr"].map{"applinks:"+$0}
        check(domains.sorted()==expectedDomains.sorted(),"Associated Domains contains only five exact canonical origins plus existing apex alias")
        check(!domains.contains(where:{$0.contains("*")||$0.hasPrefix("webcredentials:")}),"No wildcard or extra credential sharing entitlement")
        let origins=["www","app","academy","admin","parents"].map{"https://"+$0+".matths.kr"}
        for origin in origins {
            check(MatthsServiceURLPolicy.isTrustedNavigationURL(URL(string:origin+"/main")!,base:base),"Canonical HTTPS service origin")
            check(MatthsServiceURLPolicy.isUnsafeServiceURL(URL(string:origin.replacingOccurrences(of:"https:",with:"http:")+"/pricing")!,base:base),"Insecure service variant blocked")
            check(!MatthsServiceURLPolicy.isTrustedNavigationURL(URL(string:origin+":444/main")!,base:base),"Nonstandard service port rejected")
            check(!MatthsServiceURLPolicy.isTrustedNavigationURL(URL(string:origin.replacingOccurrences(of:"https://",with:"https://user@")+"/main")!,base:base),"User-info rejected")
        }
        for raw in ["https://evil.matths.kr/","https://app.matths.kr.evil.example/","https://www.app.matths.kr/",
                    "https://app.matths.kr./","https://evil.example/","file:///academy","javascript:alert(1)"]{
            check(!MatthsServiceURLPolicy.isTrustedNavigationURL(URL(string:raw)!,base:base),"Unlisted origin does not inherit service trust")
        }
        let custom=URL(string:"https://preview.example:8443")!
        check(MatthsServiceURLPolicy.isTrustedNavigationURL(URL(string:"https://preview.example:8443/academy")!,base:custom),"Custom deployment exact origin retained")
        check(!MatthsServiceURLPolicy.isTrustedNavigationURL(base,base:custom),"Custom deployment does not inherit production origin trust")
        check(!MatthsServiceURLPolicy.isTrustedNavigationURL(URL(string:"https://preview.example/")!,base:custom),"Custom port remains exact")
        check(MatthsServiceURLPolicy.serviceURL(for:.academy,path:"/academy/join/synthetic-only",base:base)?.host == "academy.matths.kr","Invite factory uses canonical academy origin")
        check(MatthsServiceURLPolicy.serviceURL(for:.academy,path:"/academy/join/synthetic-only",base:custom)?.port == 8443,"Invite factory preserves test deployment")
        check(MatthsServiceURLPolicy.serviceURL(for:.parents,path:"/parent",base:base)?.host == "parents.matths.kr","Parent factory remains a separate surface")
        for path in ["//evil.example/path","/\\evil.example/path","/academy\njoin","https://evil.example/"]{
            check(MatthsServiceURLPolicy.serviceURL(for:.academy,path:path,base:base)==nil,"Unsafe factory path rejected")
        }
        for host in ["www.matths.kr","app.matths.kr","academy.matths.kr","admin.matths.kr","parents.matths.kr"] {
            check(MatthsServiceURLPolicy.cookieResetKey(for:host) == "matths.kr","Shared service cookie reset serialized")
            check(MatthsServiceURLPolicy.ownsCookie(domain:host,baseHost:"www.matths.kr"),"Old service host-only cookie retired")
        }
        check(MatthsServiceURLPolicy.ownsCookie(domain:".matths.kr",baseHost:"app.matths.kr"),"Shared domain session retired")
        check(!MatthsServiceURLPolicy.ownsCookie(domain:"evil.matths.kr",baseHost:"www.matths.kr"),"Unlisted sibling cookie untouched")
        check(!MatthsServiceURLPolicy.ownsCookie(domain:"evil.example",baseHost:"www.matths.kr"),"External cookie untouched")
        check(WebHandoffOwnership.validatedURL("https://www.matths.kr/app/commerce/synthetic",base:base) != nil,"Original issuer handoff accepted")
        check(WebHandoffOwnership.validatedURL("https://app.matths.kr/app/commerce/synthetic",base:base) == nil,"Navigation trust never widens grant issuer")
        check(HostedPortalDestination.fromDeepLink(URL(string:"https://academy.matths.kr/academy/join/synthetic-only")!)?.path == "/academy/join/synthetic-only","Academy invite path preserved")
        check(PublicServerWebDestination.fromDeepLink(URL(string:"https://parents.matths.kr/parent/invite/synthetic-only")!) != nil,"Parent invite stays public independent login")
        check(ArenaDeepLinkHarness.destination(for:URL(string:"https://app.matths.kr/goat-arena/matches/synthetic-only")!)?.isProtectedAssessmentSurface == true,"New domain match link retains screen protection")
        check(ArenaDeepLinkHarness.destination(for:URL(string:"https://evil.matths.kr/goat-arena/matches/synthetic-only")!) == nil,"Unknown sibling cannot launch protected bridge")

        func decision(_ model:any NavigationHarness,_ raw:String,_ type:WKNavigationType = .linkActivated,view:WKWebView?=nil)->WKNavigationActionPolicy{
            var result:WKNavigationActionPolicy?,callbacks=0
            model.webView(view ?? model.webView,decidePolicyFor:.init(request:URLRequest(url:URL(string:raw)!),navigationType:type)){
                result=$0;callbacks += 1
            }
            precondition(callbacks==1);return result!
        }
        for make in [{CommunityHarness() as any NavigationHarness},{ArenaHarness() as any NavigationHarness}] {
            for origin in origins {
                let m=make()
                check(decision(m,origin+"/pricing/learning-package/self") == .cancel && m.wantsNativeCommerce && m.externalDestination==nil,
                      "Actual navigation delegate blocks cross-service web checkout")
            }
            for raw in ["https://app.matths.kr/goat-arena/main/battle","https://academy.matths.kr/academy/classes/synthetic",
                        "https://admin.matths.kr/admin/users","https://www.matths.kr/community"] {
                let m=make()
                check(decision(m,raw) == .allow && m.externalDestination==nil,"Actual service link remains in authenticated WK context")
            }
            do {
                let m=make()
                check(decision(m,"https://parents.matths.kr/parent") == .cancel && m.externalDestination?.url.host=="parents.matths.kr" && m.handoffs==0,
                      "Parent link never reuses student handoff")
            }
            do {
                let m=make();m.handingOff=true
                check(decision(m,"https://www.matths.kr/app/commerce/synthetic") == .allow,"Only canonical issuer grant loads")
                check(decision(m,"https://app.matths.kr/app/commerce/synthetic") == .cancel && m.wantsNativeCommerce,"Sibling grant origin is not a handoff exception")
            }
            do {
                let m=make();m.handingOff=true;m.pendingDestination=URL(string:"https://academy.matths.kr/academy/classes/synthetic")!
                check(decision(m,"https://www.matths.kr/pricing",.other) == .cancel && m.loaded.last?.host=="academy.matths.kr" && !m.handingOff,
                      "Cookie handoff returns to requested canonical service")
            }
            for raw in ["http://app.matths.kr/pricing","https://app.matths.kr:444/pricing","https://user@app.matths.kr/academy"] {
                let m=make()
                check(decision(m,raw) == .cancel && m.externalDestination==nil && m.loadFailure != nil,"Unsafe service variant cannot escape to Safari")
            }
            do {
                let m=make()
                check(decision(m,"https://storage.example/attachment",.other) == .allow,"Existing attachment redirect behavior retained")
            }
            do {
                let m=make()
                check(decision(m,"https://external.example/page") == .cancel && m.externalDestination != nil,"User-selected external link still uses Safari")
            }
            do {
                let m=make()
                check(decision(m,"https://app.matths.kr/pricing",view:WKWebView()) == .cancel && !m.wantsNativeCommerce,"Retired webview cannot mutate new account navigation")
            }
        }
        print("Canonical service origin/purchase/parent/grant/cookie/deep-link policy and actual WK delegates: PASS (\(count) cases)")
    }
}
