#!/usr/bin/env node
// Read-only process measurements of an already installed, isolated QA app.
// Launch-command latency is NOT first-frame/time-to-usable-UI. RSS/CPU are host
// process measures and exclude separate WebKit/model/extension processes.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const [device, output] = process.argv.slice(2);
if(!device || !output) throw new Error('Usage: node tools/measure-simulator-process.mjs SIMULATOR_UUID OUTPUT_JSON');
const bundle = 'kr.matths.app.uiqa';
const run=(tool,args)=>execFileSync(tool,args,{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const app=run('xcrun',['simctl','get_app_container',device,bundle,'app']);
const info=JSON.parse(run('plutil',['-convert','json','-o','-',path.join(app,'Info.plist')]));
const provenancePath=path.join(app,'MatthsBuildProvenance.plist');
const provenance=fs.existsSync(provenancePath)?JSON.parse(run('plutil',['-convert','json','-o','-',provenancePath])):null;
const sha256=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sample=pid=>{
  const values=run('ps',['-p',String(pid),'-o','pcpu=,rss=,time=']).split(/\s+/);
  if(values.length!==3) throw new Error(`Process sample unavailable for ${pid}`);
  const [minutes,seconds]=values[2].split(':').map(Number);
  return {hostPercentCPU:Number(values[0]),residentBytes:Number(values[1])*1024,
          cumulativeCPUSeconds:minutes*60+seconds};
};
const samples=[];
let lastPid;
for(let index=0;index<10;index++){
  const started=performance.now();
  const response=run('xcrun',['simctl','launch','--terminate-running-process',device,bundle,'-demo','-route','today']);
  const elapsed=performance.now()-started;
  const pid=Number(response.split(':').at(-1).trim()); lastPid=pid;
  const snapshots=[];
  for(let step=0;step<6;step++) { await sleep(500); snapshots.push({secondsAfterLaunchReturn:(step+1)*0.5,...sample(pid)}); }
  samples.push({iteration:index+1,pid,processLaunchCommandMs:elapsed,snapshots});
}
const idleStart=sample(lastPid);
const idle=[];
for(let index=0;index<30;index++){await sleep(1000);idle.push({seconds:index+1,...sample(lastPid)});}
const sorted=samples.map(s=>s.processLaunchCommandMs).sort((a,b)=>a-b);
const percentile=p=>sorted[Math.min(sorted.length-1,Math.ceil(p*sorted.length)-1)];
const report={schema:'MATTHS_SIMULATOR_PROCESS_BASELINE_V1',observedAt:new Date().toISOString(),
  bundleIdentifier:bundle,sourceProvenance:provenance,appVersion:info.CFBundleShortVersionString,build:info.CFBundleVersion,
  appExecutableSHA256:sha256(path.join(app,info.CFBundleExecutable)),simulatorUUID:device,
  xcode:run('xcodebuild',['-version']),configuration:'Debug isolated QA app; -demo -route today',
  launchIterations:samples.length,processLaunchCommandMs:{p50:percentile(.5),p95:percentile(.95)},
  sampledResidentPeakBytes:Math.max(...samples.flatMap(s=>s.snapshots.map(x=>x.residentBytes))),
  idle30Seconds:{cpuSeconds:idle.at(-1).cumulativeCPUSeconds-idleStart.cumulativeCPUSeconds,
    residentChangeBytes:idle.at(-1).residentBytes-idleStart.residentBytes,samples:idle},samples,
  limitations:['Command latency includes simctl/termination and is NOT first usable UI',
    'Process restart with warm OS caches is NOT physical cold launch',
    'CPU and RSS exclude WebKit/extension processes',
    'Simulator runs on shared Mac; concurrent builds introduce noise',
    'No scroll gesture/hitch, physical minimum-device, thermal, energy or network measurement']};
fs.mkdirSync(path.dirname(path.resolve(output)),{recursive:true});fs.writeFileSync(output,JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({output,launchIterations:report.launchIterations,processLaunchCommandMs:report.processLaunchCommandMs,
  sampledResidentPeakBytes:report.sampledResidentPeakBytes,idle30Seconds:{cpuSeconds:report.idle30Seconds.cpuSeconds,residentChangeBytes:report.idle30Seconds.residentChangeBytes}},null,2));
