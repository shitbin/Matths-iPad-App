#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-service-origin.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT HUP INT TERM
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs');const [root,out]=process.argv.slice(2);
function between(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);if(i<0||j<i)throw Error('Production boundary changed: '+a);return s.slice(i,j);}
const api=fs.readFileSync(root+'/Matths/ServerAPI.swift','utf8');
if(!api.includes('static let defaultURL = "https://www.matths.kr"'))
  throw Error('Review OAuth and exact handoff issuer before changing the API origin');
const purchase=between(api,'    static func isWebPurchaseSurface(','    // MARK: 계정');
const hub=fs.readFileSync(root+'/Matths/ServiceHubScreen.swift','utf8');
const destinations=between(hub,'struct PublicServerWebDestination:','/// 홈의 여러 보조 기능을');
let generated='import Foundation\nenum ServerAPI {static let baseURL=URL(string:"https://www.matths.kr")!\n'+purchase+'}\n'+destinations+'\n';
for(const [file,name] of [['CommunityScreen.swift','CommunityHarness'],['ArenaWeb/ArenaWebModel.swift','ArenaHarness']]){
 const source=fs.readFileSync(root+'/Matths/'+file,'utf8');
 const host=between(source,'    private func isServerHost(_ url: URL) -> Bool {','\n    }')+'\n    }\n';
 const navigation=between(source,'    func webView(_ webView: WKWebView,\n                 decidePolicyFor navigationAction: WKNavigationAction,','    func webView(_ webView: WKWebView,\n                 decidePolicyFor navigationResponse: WKNavigationResponse,');
 const handoff=between(source,'    private func validatedHandoffURL(_ value: String) -> URL? {','\n    }')+'\n    }\n';
 const back=name==='ArenaHarness'?between(source,'    private func isReturnToAppLink(_ url: URL) -> Bool {','\n    }')+'\n    }\n':'';
 generated+='@MainActor final class '+name+': WebModelHarnessBase, NavigationHarness {\n'+host+handoff+back+navigation+'}\n';
}
const presenter=fs.readFileSync(root+'/Matths/ArenaWeb/ArenaWebPresenter.swift','utf8');
generated+='@MainActor enum ArenaDeepLinkHarness {\n'+between(presenter,'    static func destination(for url: URL) -> ArenaWebDestination? {','\n}\n\n#if DEBUG')+'\n}\n';
fs.writeFileSync(out+'/flow.swift',generated);
JS
xcrun swiftc -swift-version 5 "$ROOT/Matths/MatthsServiceURLPolicy.swift" "$ROOT/Matths/WebHandoffOwnership.swift" \
  "$ROOT/Matths/ArenaWeb/ArenaWebDestination.swift" "$TEST_DIR/flow.swift" \
  "$ROOT/tests/ServiceOriginCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases" "$ROOT"
