#!/usr/bin/env node
// Standalone simulator performance regression runner. Does not modify/install
// the production app; results explicitly distinguish this harness from app QA.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const [device, output] = process.argv.slice(2);
if (!device || !output) throw new Error('Usage: node tools/run-webview-performance.mjs SIMULATOR_UUID OUTPUT_JSON');
const root = path.resolve(import.meta.dirname, '..');
const baselineRef = process.env.MATTHS_WEBVIEW_BASELINE_REF;
const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'matths-webview-performance-'));
const app = path.join(temp, 'WebViewPerformance.app'); fs.mkdirSync(app);
const files = ['ProblemWebView.swift','LessonWebView.swift','HintWebView.swift','LottieWebView.swift','WebContentAccessibility.swift','WebMotion.swift'];
const hashes = {};
for (const file of files) {
  const src = baselineRef
    ? execFileSync('git', ['show', `${baselineRef}:Matths/${file}`], {cwd:root,encoding:'utf8'})
    : fs.readFileSync(path.join(root, 'Matths', file), 'utf8');
  hashes[file] = crypto.createHash('sha256').update(src).digest('hex');
  fs.writeFileSync(path.join(temp, file), src.replace(/\bWKWebView\b/g, 'InstrumentedWebView'));
}
fs.cpSync(path.join(root,'tests/WebViewPerformanceHarness.swift'), path.join(temp,'Harness.swift'));
fs.cpSync(path.join(root,'Matths/LessonWeb'),path.join(app,'LessonWeb'),{recursive:true});
fs.cpSync(path.join(root,'Matths/RankBadges'),path.join(app,'RankBadges'),{recursive:true});
const bundle = 'kr.matths.performance.webview';
fs.writeFileSync(path.join(app,'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>WebViewPerformance</string><key>CFBundleIdentifier</key><string>${bundle}</string><key>CFBundleName</key><string>Matths Web QA</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>1.0</string><key>CFBundlePackageType</key><string>APPL</string><key>MinimumOSVersion</key><string>18.0</string><key>LSRequiresIPhoneOS</key><true/><key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array><key>UILaunchScreen</key><dict/></dict></plist>`);
const run = (name,args,opts={}) => execFileSync(name,args,{encoding:'utf8',stdio:['ignore','pipe','pipe'],...opts});
const sdk = run('xcrun',['--sdk','iphonesimulator','--show-sdk-path']).trim();
run('xcrun',['swiftc','-sdk',sdk,'-target','arm64-apple-ios18.0-simulator','-default-isolation','MainActor','-D','DEBUG','-parse-as-library','-o',path.join(app,'WebViewPerformance'),...files.map(f=>path.join(temp,f)),path.join(temp,'Harness.swift')]);
run('codesign',['--force','--sign','-',app]);
run('xcrun',['simctl','install',device,app]);
const container = run('xcrun',['simctl','get_app_container',device,bundle,'data']).trim();
const reportPath=path.join(container,'Documents/webview-performance.json');
// Previous harness result only; never touches application/user files.
if(fs.existsSync(reportPath)) fs.renameSync(reportPath,path.join(temp,'prior-report.json'));
run('xcrun',['simctl','launch','--terminate-running-process',device,bundle]);
for(let attempt=0;attempt<120;attempt++) {
  if(fs.existsSync(reportPath)) {
    const report=JSON.parse(fs.readFileSync(reportPath,'utf8'));
    report.sourceSHA256=hashes;
    report.sourceReference=baselineRef || 'current-working-tree';
    report.appExecutableSHA256=crypto.createHash('sha256').update(fs.readFileSync(path.join(app,'WebViewPerformance'))).digest('hex');
    report.simulatorUUID=device; report.xcode=run('xcodebuild',['-version']).trim();
    const expectedPayload={problem:'$x+1$',lesson:'absolute-linear-inequalities',hint:'hint-1',lottie:'true'};
    report.failures=[];
    for(const entry of report.cases){
      const file=`${entry.kind}.html`;
      if(entry.loadsAfterMount[file]!==1) report.failures.push(`${entry.kind}: initial document was loaded ${entry.loadsAfterMount[file]} times`);
      if(entry.loadsAfter20ParentUpdates[file]!==entry.loadsAfterMount[file]) report.failures.push(`${entry.kind}: unchanged parent updates reloaded the document`);
      if(entry.changedPayload!==expectedPayload[entry.kind]) report.failures.push(`${entry.kind}: changed content was stale`);
      if(entry.jsAppearanceEventsDuring20Updates!==0) report.failures.push(`${entry.kind}: unchanged appearance emitted redundant resize events`);
      if(Math.abs(entry.changedAppearanceScale-1.12)>.001) report.failures.push(`${entry.kind}: actual appearance change was not applied`);
      if(entry.liveWebViewsAfterUnmount!==0) report.failures.push(`${entry.kind}: WebView retained after unmount`);
    }
    if(report.navigationLoops.some(entry=>entry.liveWebViewsAfterUnmount!==0)) report.failures.push('Navigation retained WebViews');
    report.result=report.failures.length===0?'PASS':'FAIL';
    fs.mkdirSync(path.dirname(path.resolve(output)),{recursive:true});
    fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
    console.log(JSON.stringify({report:output,cases:report.cases,navigationLoops:report.navigationLoops,wallSeconds:report.wallSeconds,processCPUSeconds:report.processCPUSeconds},null,2));
    process.exit(baselineRef || report.result==='PASS'?0:1);
  }
  await new Promise(resolve=>setTimeout(resolve,1000));
}
throw new Error(`Harness did not produce a report in 120s; ${temp}`);
