import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import yaml from 'js-yaml';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
const root=path.resolve(process.argv[2]||'');
const expected='e3cc06360415a4c60460895b01f06a3248dae665';
if(execFileSync('git',['-C',root,'rev-parse','HEAD'],{encoding:'utf8'}).trim()!==expected)throw Error('Exact Web source required');
const source=fs.readFileSync(path.join(root,'services/curriculumService.js'),'utf8');
const module={exports:{}};
vm.runInNewContext(source,{module,exports:module.exports,__dirname:path.join(root,'services'),require:n=>({fs,path,'js-yaml':yaml})[n],process:{env:{NODE_ENV:'production'}}});
const catalog=JSON.parse(JSON.stringify(module.exports.loadCurriculum()));
const all=catalog.courses.flatMap(c=>c.units.flatMap(u=>u.concepts.map(x=>({c,u,x,key:[c.id,u.id,x.id].join('/')}))));
const open=all.filter(r=>!r.c.developmentLocked),closed=all.filter(r=>r.c.developmentLocked);
const cases=[['new',{}],['locked-only',Object.fromEntries(closed.map(r=>[r.key,{percent:100}]))],
 ['in-progress-elective',{[open.find(r=>r.c.category!=='common').key]:{percent:30}}],
 ['rounding',{[open[0].key]:{percent:1},[open[1].key]:{percent:100}}],
 ['all-open-complete',Object.fromEntries(open.map(r=>[r.key,{percent:100}]))],
 ['mixed',Object.fromEntries(all.map((r,i)=>[r.key,{percent:(i*17)%101}]))]];
const vectors=cases.map(([name,concepts])=>{
 const oldCatalog={...catalog,courses:catalog.courses.map(c=>({...c,developmentLocked:false}))};
 const previous=module.exports.buildLearningViewModel(oldCatalog,{concepts});
 const official=module.exports.buildLearningViewModel(catalog,{concepts});
 const snapshot={overallProgress:previous.overallProgress,completedConcepts:previous.completedConcepts,totalConcepts:previous.totalConcepts,
  continueConcept:previous.continueConcept?{id:previous.continueConcept.id,href:previous.continueConcept.href}:null,
  courses:previous.courses.map(c=>({id:c.id,category:c.category,developmentLocked:c.developmentLocked,hasActivity:c.hasActivity,
   units:c.units.map(u=>({id:u.id,concepts:u.concepts.map(x=>({id:x.id,progress:x.progress}))}))}))};
 return {name,snapshot,expected:{percent:official.overallProgress,done:official.completedConcepts,total:official.totalConcepts,nextConceptID:official.continueConcept?.id??null}};
});
const output={webCommit:expected,sourceSHA256:crypto.createHash('sha256').update(source).digest('hex'),vectors};
fs.mkdirSync(new URL('../tests/fixtures/',import.meta.url),{recursive:true});
fs.writeFileSync(new URL('../tests/fixtures/web-learning-parity.json',import.meta.url),JSON.stringify(output,null,2)+'\n');
console.log('Generated '+vectors.length+' exact-Web parity vectors');
