#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-weekly-insights.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs');const [root,out]=process.argv.slice(2);
const source=fs.readFileSync(root+'/Matths/WeeklyMockInsightsPanel.swift','utf8');
function between(a,b){const i=source.indexOf(a),j=source.indexOf(b,i);if(i<0||j<i)throw Error('Review source boundaries');return source.slice(i,j)}
const properties=between('    private var role:','    var body: some View');
const load=between('    @MainActor private func load() async {','\n}\n');
fs.writeFileSync(out+'/flow.swift',`import Foundation
@MainActor final class InsightHarness {
var scope:WeeklyMockInsightScope
let store:AppStore
init(_ store:AppStore,scope:WeeklyMockInsightScope){self.store=store;self.scope=scope}
var response:ServerAPI.WeeklyMockInsightsResponse?
var owner:AccountRequestOwner?
var loadedScope:WeeklyMockInsightScope?
var loadedRole=""
var requestID=UUID()
var isLoading=false
var errorMessage:String?
${properties}${load}
func refresh()async{await load()}
var canDisplay:Bool{belongsToCurrentView}
}
`);
if(!source.includes('.task(id: trigger)')||!source.includes('requestID = UUID(); owner = nil; response = nil'))throw Error('Lifecycle guards missing');
for(const file of ['TeacherAnalyticsPanel.swift','AdminAcademyExplorer.swift','AdminWeeklyMockScreen.swift']) {
 if(!fs.readFileSync(root+'/Matths/'+file,'utf8').includes('WeeklyMockInsightsPanel(scope:'))throw Error('Missing existing-screen entry '+file);
}
if(!source.includes('insight.concepts.prefix(18)')||!source.includes('전체 \\(insight.concepts.count)개 개념 보기'))throw Error('All-concept expansion missing');
JS
xcrun swiftc -swift-version 5 "$ROOT/Matths/AccountRequestOwner.swift" "$ROOT/Matths/WeeklyMockInsightsAPI.swift" \
  "$TEST_DIR/flow.swift" "$ROOT/tests/WeeklyMockInsightsNativeCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
