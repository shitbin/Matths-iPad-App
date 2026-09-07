#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-answer-key-resources.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs');const[root,out]=process.argv.slice(2);
const api=fs.readFileSync(root+'/Matths/AdminWeeklyMockAPI.swift','utf8');
function slice(source,a,b){const i=source.indexOf(a),j=source.indexOf(b,i);if(i<0||j<i)throw Error('Source boundary changed '+a);return source.slice(i,j)}
fs.writeFileSync(out+'/review.swift','import Foundation\nextension ServerAPI {\n'+slice(api,'    struct AdminMockExplanation:','    struct AdminMockEvent:')+'}\n');
const resource=fs.readFileSync(root+'/Matths/AdminAnswerKeyResources.swift','utf8');
fs.writeFileSync(out+'/resource.swift',resource.slice(0,resource.indexOf('private final class AnswerKeyResourceRedirectBlocker')));
const panel=fs.readFileSync(root+'/Matths/AdminAnswerKeyResourcePanel.swift','utf8');
fs.writeFileSync(out+'/panel.swift',`import Foundation
@MainActor final class ResourcePanelHarness {
let store:AppStore
init(_ store:AppStore){self.store=store}
var downloaded:[AdminAnswerKeyResource:URL]=[:]
var downloadOwner:AccountRequestOwner?
var loading:AdminAnswerKeyResource?
var task:Task<Void,Never>?
var errorMessage:String?
${slice(panel,'    @MainActor private func clear()','\n}\n')}
func start()->Task<Void,Never>?{download(.catalog);return task}
func stop(){clear()}
}
`);
for(const file of ['AdminStoreScreen.swift','AdminWeeklyMockScreen.swift'])if(!fs.readFileSync(root+'/Matths/'+file,'utf8').includes('AdminAnswerKeyResourcePanel()'))throw Error('Missing template entry point');
if(!resource.includes('completionHandler(nil)')||!resource.includes('data.count < AdminAnswerKeyResource.maximumBytes'))throw Error('Download redirect/size boundary missing');
if(!panel.includes('.onChange(of: trigger)')||!panel.includes('.onDisappear { clear() }')||!panel.includes('if canDisplayDownload, let url'))throw Error('Account display/lifecycle boundary missing');
JS
# Compile the production HTTP downloader, metadata DTO, MIME/hash/byte validators.
xcrun swiftc -swift-version 5 "$ROOT/Matths/AdminAnswerKeyResources.swift" "$TEST_DIR/review.swift" \
  "$ROOT/tests/AdminAnswerKeyResourceCases.swift" -o "$TEST_DIR/resource-cases"
"$TEST_DIR/resource-cases"
# Actual panel callback captures owner BEFORE Task. Controlled HTTP suspension
# permits a precise switch before/after the asynchronous fetch without devices.
xcrun swiftc -swift-version 5 -DRESOURCE_FLOW "$ROOT/Matths/ProtectedFileWriter.swift" "$ROOT/Matths/AccountRequestOwner.swift" \
  "$TEST_DIR/resource.swift" "$TEST_DIR/panel.swift" "$ROOT/tests/AdminAnswerKeyResourceCases.swift" -o "$TEST_DIR/flow-cases"
"$TEST_DIR/flow-cases"
