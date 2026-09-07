import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
const root=process.argv[2];
const source=fs.readFileSync(path.join(root,'Matths/WebContentAccessibility.swift'),'utf8');
const block=source.match(/return """\n([\s\S]*?)\n\s*"""/);
assert.ok(block,'Actual bootstrap source must be present');
const script=block[1].replaceAll('\\(scale)','1.000').replaceAll('\\(motion)','false').replaceAll('\\(userMotion)','true');
const events=[]; const listeners={}; let pauses=0; let animations=0; let assignedScale;
const document={
  documentElement:{style:{setProperty:(_name,value)=>assignedScale=value},classList:{toggle:()=>{}}},
  addEventListener:(event,callback)=>listeners[event]=callback,
  getAnimations:()=>[{finish:()=>animations++,cancel:()=>{}}],
  querySelectorAll:()=>[{pause:()=>pauses++}]
};
const window={dispatchEvent:e=>events.push(e.type),requestAnimationFrame:callback=>callback()};
const context=vm.createContext({window,document,Event:class{constructor(type){this.type=type}},CustomEvent:class{constructor(type){this.type=type}}});
vm.runInContext(script,context);
assert.equal(events.filter(e=>e==='matthsAccessibilityChanged').length,1);
const apply=window.MATTHS_APPLY_ACCESSIBILITY;
for(let i=0;i<20;i++)apply({scale:1,reduceMotion:false,userMotionEnabled:true});
assert.equal(events.filter(e=>e==='matthsAccessibilityChanged').length,1,'20 unchanged updates are true no-ops');
apply({scale:1.12,reduceMotion:false,userMotionEnabled:true});
assert.equal(assignedScale,'1.12');
assert.equal(events.filter(e=>e==='matthsAccessibilityChanged').length,2,'Actual text scale applies once');
apply({scale:1.12,reduceMotion:true,userMotionEnabled:true});
assert.equal(pauses,1); assert.equal(animations,1); assert.equal(window.MATTHS_MOTION,false);
for(let i=0;i<20;i++)apply({scale:1.12,reduceMotion:true,userMotionEnabled:true});
assert.equal(pauses,1,'Repeated parent updates cannot repeatedly pause media');
listeners.DOMContentLoaded();
assert.equal(events.filter(e=>e==='matthsAccessibilityChanged').length,4,'New DOM applies even without changed settings');
apply({scale:1.12,reduceMotion:false,userMotionEnabled:true});
assert.equal(window.MATTHS_MOTION,true,'Real motion reenable still propagates');
console.log('WebView appearance: 20 unchanged updates, scale, motion, media, new DOM and recovery passed');
