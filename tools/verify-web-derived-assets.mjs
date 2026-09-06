import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const web=process.argv[2]||process.env.MATTHS_WEB_REPO;
if(!web)throw Error('MATTHS_WEB_REPO or first argument must point to exact Web source');
const stage=fs.mkdtempSync(path.join(os.tmpdir(),'matths-assets-parity-'));
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
for(const [name,tz] of [['first','UTC'],['second','America/Los_Angeles']]) {
 const dir=path.join(stage,name);fs.mkdirSync(dir);
 const result=spawnSync(process.execPath,[path.join(root,'tools/generate-web-derived-assets.mjs'),'--web-root',web,
  '--output-root',path.join(dir,'Matths'),'--manifest',path.join(dir,'manifest.json')],{env:{...process.env,TZ:tz,LANG:'C'},encoding:'utf8'});
 assert.equal(result.status,0,result.stderr);
}
const first=JSON.parse(fs.readFileSync(path.join(stage,'first/manifest.json')));
const second=JSON.parse(fs.readFileSync(path.join(stage,'second/manifest.json')));
assert.deepEqual(first,second,'Generation must be deterministic across timezone/path');
assert.deepEqual(first,JSON.parse(fs.readFileSync(path.join(root,'WEB_DERIVED_ASSET_MANIFEST.json'))),'Checked-in manifest drift');
for(const output of first.outputs) assert.equal(sha(fs.readFileSync(path.join(root,output.path))),output.sha256,output.path+' generated asset drift');
assert.equal(first.semanticCounts.courseCount,13);
assert.equal(first.semanticCounts.conceptCount,220);
assert.equal(first.semanticCounts.availableCourseIDs.length,5);
const bundle=fs.readFileSync(path.join(root,'Matths/LessonWeb/webgen-bundle.js'),'utf8');
assert(!bundle.includes('services/problemGenerators/commonMath1/'),'Retired generator modules remain');
assert(bundle.includes('services/problemGenerators/commonMath/generators.js'),'Current common-math generators missing');
console.log('Web source/manifest/output hashes and two deterministic generations PASS');
