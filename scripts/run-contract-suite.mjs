import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = process.argv[2];
if (!output) throw Error('Provide an output directory');
fs.mkdirSync(output, { recursive: true });
const rows = [];
for (const name of fs.readdirSync(path.join(root,'tests')).filter(x=>/^run-.*\.sh$/.test(x)).sort()) {
  const started=Date.now();
  const result=spawnSync('bash',[path.join(root,'tests',name)],{cwd:root,env:process.env,encoding:'utf8',timeout:180000,maxBuffer:8*1024*1024});
  const status=result.status===0?'PASS':'FAIL';
  fs.writeFileSync(path.join(output,name+'.log'),(result.stdout||'')+(result.stderr||'')+(result.error?.message||''));
  rows.push({name,status,exitCode:result.status,elapsedMs:Date.now()-started});
  console.log(status+' '+name);
}
const report={count:rows.length,passed:rows.filter(x=>x.status==='PASS').length,failed:rows.filter(x=>x.status==='FAIL').length,results:rows};
fs.writeFileSync(path.join(output,'results.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({count:report.count,passed:report.passed,failed:report.failed}));
if(report.failed)process.exit(1);
