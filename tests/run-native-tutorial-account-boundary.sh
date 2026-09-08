#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/matths-native-tutorial-owner.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
# Compile production control flow, not a reimplementation of its guards.
# Only SwiftUI state wrappers and the HTTP/profile dependencies are replaced by
# an in-memory main-actor harness, allowing deterministic account-switch races.
node - "$ROOT" "$TEST_DIR" <<'JS'
const fs=require('node:fs'); const [root,out]=process.argv.slice(2);
const source=fs.readFileSync(root+'/Matths/RootView.swift','utf8');
const native=source.slice(source.indexOf('struct NativeTutorialOverlay: View {'),source.indexOf('// MARK: - 하단 탭바'));
function between(text,a,b) { const i=text.indexOf(a),j=text.indexOf(b,i); if(i<0||j<i)throw Error('Production boundary changed: '+a); return text.slice(i,j); }
const owner=between(native,'    private struct RunOwner {','    @State private var runOwner:');
const ownership=between(native,'    private var normalizedRole:','    private var steps:');
const steps=between(native,'    private var steps:','    private func recordFocusDiagnostic(');
const focus=between(native,'    private func requestCurrentFocus() {','    @MainActor\n    private func startIfNeeded() async {');
const settle=between(native,'    @MainActor\n    private func settle(on route: AppStore.Route, owner: RunOwner) async {','    private func advance() {');
const start=between(native,'    @MainActor\n    private func startIfNeeded() async {','    #if DEBUG\n    private static func argumentValue');
const finish=between(native,'    private func finish(skipped: Bool) {','\n}\n');
const app=fs.readFileSync(root+'/Matths/MatthsApp.swift','utf8');
const lease=between(app,'    @Published var isTutorialPresentationActive = false {','    /// 마지막 라우트').replace('@Published ','');
fs.writeFileSync(out+'/lease.swift','import Foundation\n@MainActor class TutorialLeaseStore {\n'+lease+'}\n');
fs.writeFileSync(out+'/flow.swift',`import Foundation
@MainActor final class TutorialHarness {
let store: AppStore
init(_ store:AppStore){self.store=store}
var run: NativeTutorialRun?
var stepIndex=0, spotlightVisible=false, mutationInFlight=false, reduceMotion=true
var mutationError:String?
private var runOwner:RunOwner?
private var mutationTask:Task<Void,Never>?
// View diagnostic output is not part of the authorization model.
private func recordFocusDiagnostic(_ stage:String, owner:RunOwner? = nil) {}
static let dashboardSteps=[NativeTutorialStep(route:.home,target:.todayPrimaryAction)]
static let arenaSteps=["unranked":[NativeTutorialStep(route:.rank,target:.arenaMatchmaking)],"ranked":[NativeTutorialStep(route:.rank,target:.arenaMatchmaking)],"ranked_shop":[NativeTutorialStep(route:.arenaShop,target:.arenaShopWallet)]]
${owner}${ownership}${steps}${focus}${settle}${start}${finish}
func start()async {await startIfNeeded()}
func settleCurrent(on route:AppStore.Route)async {guard let owner=runOwner else{return};await settle(on:route,owner:owner)}
func begin(_ value:NativeTutorialRun){precondition(claimRun() != nil);run=value}
func stop(){clearRun()}
func save(skipped:Bool=false)->Task<Void,Never>?{finish(skipped:skipped);return mutationTask}
var visible:Bool{runOwner.map(owns) == true && run != nil}
var ownerID:UUID?{runOwner?.id}
}
`);
// Explicit restart callbacks must also freeze their owner before Task creation.
const profile=fs.readFileSync(root+'/Matths/ProfileScreen.swift','utf8');
const dashboard=between(profile,'        Button("대시보드 튜토리얼 다시 시작") {','        .buttonStyle(SecondaryButtonStyle())').replace('        Button("대시보드 튜토리얼 다시 시작") {','func restartDashboard() {');
const arena=between(profile,'                Button(arenaTutorialLabel(chapter)) {','            }\n        }\n        .buttonStyle(SecondaryButtonStyle())').replace('                Button(arenaTutorialLabel(chapter)) {','func restartArena(_ chapter:String) {');
fs.writeFileSync(out+'/restart.swift','import Foundation\nextension ProfileHarness {\n'+dashboard+arena+'\n}\n');
const legacy=fs.readFileSync(root+'/Matths/FirstRunOnboarding.swift','utf8');
const legacyOwner=between(legacy,'    private struct PresentationOwner {','    @State private var presentationOwner:');
const legacyFlow=between(legacy,'    private func owns(_ owner: PresentationOwner)','    private var accountRole:');
const legacyRole=between(legacy,'    private var accountRole:','    private var staffTitle:');
const legacyIntent=between(legacy,'    private enum StudyIntent:','    private var triggerKey:');
const legacyPresent=between(legacy,'    @MainActor\n    private func presentIfNeeded()','    private func finish(skipped: Bool)');
const legacyFinish=between(legacy,'    private func finish(skipped: Bool)','\n}\n');
fs.writeFileSync(out+'/legacy.swift',`import Foundation
@MainActor final class LegacyTutorialHarness {
let store:AppStore
init(_ store:AppStore){self.store=store}
private var presentationOwner:PresentationOwner?
private var saveTask:Task<Void,Never>?
var isPresented=false, saving=false, reduceMotion=true
var errorMessage:String?
private var selectedIntent:StudyIntent = .newConcept
var selectedCoach:SpiceLevel = .mild
${legacyOwner}${legacyFlow}${legacyRole}${legacyIntent}${legacyPresent}${legacyFinish}
func start(){presentIfNeeded()}
func stop(){clearPresentation()}
func save(skipped:Bool=false)->Task<Void,Never>?{finish(skipped:skipped);return saveTask}
var visible:Bool{presentationOwner.map(owns) == true && isPresented}
var ownerID:UUID?{presentationOwner?.id}
}
`);
if(!native.includes('if let owner = runOwner, owns(owner), run != nil, steps.indices.contains(stepIndex)'))throw Error('Stale run still visible');
if(!native.includes('.onDisappear { recordFocusDiagnostic("overlay_disappeared"); clearRun() }')||!native.includes('DataScope.didSwitchNotification'))throw Error('Missing lifecycle cleanup');
if(!native.includes('String(describing: store.captureAccountSessionBoundary())')||!native.includes('DataScope.slot, normalizedRole'))throw Error('Missing identity or role trigger');
if(!native.includes('guard owns(owner), run != nil, store.route == route else {'))throw Error('Stale route settlement can activate a tutorial');
if(!legacy.includes('if let owner = presentationOwner, owns(owner), isPresented'))throw Error('Stale legacy view remains visible');
if(!legacy.includes('DataScope.didSwitchNotification')||!legacy.includes('.onDisappear { clearPresentation() }'))throw Error('Legacy lifecycle cleanup missing');
JS
xcrun swiftc -swift-version 5 "$TEST_DIR/lease.swift" "$ROOT/Matths/AccountRequestOwner.swift" "$ROOT/Matths/TutorialFocus.swift" \
  "$TEST_DIR/flow.swift" "$TEST_DIR/restart.swift" "$TEST_DIR/legacy.swift" "$ROOT/tests/NativeTutorialAccountBoundaryCases.swift" -o "$TEST_DIR/cases"
"$TEST_DIR/cases"
