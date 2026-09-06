import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';
import { parse } from 'acorn';
import { build } from 'esbuild';

const toolsRoot = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.dirname(toolsRoot);
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, arg, i, all) => {
  if (arg.startsWith('--')) pairs.push([arg.slice(2), all[i + 1]]); return pairs;
}, []));
const expected = args['web-commit'] || 'e3cc06360415a4c60460895b01f06a3248dae665';
if (!args['web-root']) throw Error('BLOCKED_WEB_SOURCE_REQUIRED: --web-root must identify the exact Web checkout');
const webRoot = path.resolve(args['web-root']);
const outputRoot = path.resolve(args['output-root'] || path.join(appRoot, 'Matths'));
const git = (...a) => execFileSync('git', ['-C', webRoot, ...a], { encoding: 'utf8' }).trim();
if (git('rev-parse', 'HEAD') !== expected || git('status', '--porcelain', '--untracked-files=no')) throw Error('Exact clean Web commit required');
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const read = p => fs.readFileSync(path.join(webRoot, p), 'utf8');
const inputs = new Set(['services/curriculumService.js', 'services/assessmentService.js', 'services/examBankSource.js']);
for (const f of fs.readdirSync(path.join(webRoot, 'curriculum_folder')).sort()) if (/^kr-2022-.*\.ya?ml$/.test(f)) inputs.add('curriculum_folder/' + f);
const curriculumModule = { exports: {} };
vm.runInNewContext(read('services/curriculumService.js'), {
  module: curriculumModule, exports: curriculumModule.exports, __dirname: path.join(webRoot, 'services'),
  require: name => ({ fs, path, 'js-yaml': yaml })[name] ?? (() => { throw Error('Unexpected curriculum dependency ' + name); })(),
  process: { env: { NODE_ENV: 'production' } }
});
const catalog = JSON.parse(JSON.stringify(curriculumModule.exports.loadCurriculum()));
const overlayPath = path.join(toolsRoot, 'native-curriculum-overlay.json');
const overlay = JSON.parse(fs.readFileSync(overlayPath, 'utf8'));
const curriculum = {
  version: 2, curriculumId: catalog.curriculum.id,
  source: `Web ${expected}; iOS presentation overlay ${overlay.nativeSourceCommit}`,
  categories: catalog.categories.map(c => ({ id: c.id, title: c.title, order: c.order })),
  learningTracks: overlay.learningTracks,
  courses: catalog.courses.map((c, ci) => ({ id: c.id, title: c.officialTitle || c.title, category: c.category, order: ci + 1,
    prerequisites: c.prerequisites || [], recommendedGrades: c.recommendedGrades,
    units: c.units.map((u, ui) => ({ id: u.id, title: u.title, order: u.order || ui + 1,
      concepts: u.concepts.map((x, xi) => ({ id: x.id, order: x.order || xi + 1, title: x.title,
        standardCode: x.standardCode ?? null, achievementStandard: x.achievementStandard ?? null,
        topics: x.topics || [], scopeNotes: x.scopeNotes || [], visualizationIdeas: x.visualizationIdeas || [],
        ...(overlay.concepts[x.id] || { lesson: null, legacy: null }) })) })) }))
};
const conceptIDs = new Set(curriculum.courses.flatMap(c => c.units.flatMap(u => u.concepts.map(x => x.id))));
for (const c of curriculum.courses) {
  if (typeof c.title !== 'string' || !c.title.trim()) throw Error('Missing course title: ' + c.id);
  for (const u of c.units) {
    if (typeof u.title !== 'string' || !u.title.trim()) throw Error('Missing unit title: ' + u.id);
    for (const x of u.concepts) if (typeof x.title !== 'string' || !x.title.trim() || !Array.isArray(x.topics)) throw Error('Invalid concept: ' + x.id);
  }
}
for (const id of Object.keys(overlay.concepts)) if (!conceptIDs.has(id)) throw Error('Orphaned native overlay concept: ' + id);
for (const track of curriculum.learningTracks) for (const id of track.conceptIds) if (!conceptIDs.has(id)) throw Error('Orphaned learning track');

function constant(file, name) {
  const source = read(file), ast = parse(source, { ecmaVersion: 'latest' });
  let initializer;
  function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'VariableDeclarator' && node.id?.name === name) initializer = source.slice(node.init.start, node.init.end);
    for (const v of Object.values(node)) if (Array.isArray(v)) v.forEach(visit); else if (v && typeof v === 'object') visit(v);
  }
  visit(ast);
  if (!initializer) throw Error('Missing Web constant: ' + name);
  return vm.runInNewContext('(' + initializer + ')', {}, { timeout: 1000 });
}
const examModule = { exports: {} };
vm.runInNewContext(read('services/examBankSource.js'), { module: examModule, exports: examModule.exports });
const bank = examModule.exports.EXAM_COURSES;
const plans = constant('services/assessmentService.js', 'PAPER_PLANS');
const assessments = {
  version: 2, passScore: constant('services/assessmentService.js', 'PASS_SCORE'),
  paperPlans: Object.fromEntries(Object.entries(plans).map(([id, p]) => [id, { count: p.questionCount,
    mix: { midHigh: p.counts['mid-high'], applied: p.counts.applied, advanced: p.counts.advanced } }])),
  advancedApproximation: 'bank-4pt',
  gradeBands: constant('services/examBankSource.js', 'GRADE_BANDS').map(g => ({ grade: Number.parseInt(g.grade), min: g.min })),
  courses: constant('services/assessmentService.js', 'ASSESSMENT_CATALOG').map(c => {
    const b = bank.find(x => x.id === c.bankCourseId);
    if (!b) throw Error('Missing bank course ' + c.courseId);
    return { ...c, title: b.label, units: c.units.map(u => {
      const bu = b.units.find(x => x.id === u.bankUnitId);
      if (!bu) throw Error('Missing bank unit ' + u.unitId);
      return { ...u, title: bu.label, numeral: bu.numeral || '', subunits: u.subunits.map(s => {
        const bs = bu.subs.find(x => x.id === s.id);
        if (!bs) throw Error('Missing bank subunit ' + s.id);
        return { ...s, title: bs.label, gens: bs.gens.map(g => ({ id: g.id, points: g.points })) };
      }) };
    }) };
  })
};
const entry = fs.readFileSync(path.join(toolsRoot, 'webgen-entry.cjs'), 'utf8');
const bundle = await build({ stdin: { contents: entry, resolveDir: webRoot, sourcefile: 'ios-webgen-entry.cjs', loader: 'js' },
  absWorkingDir: webRoot, bundle: true, write: false, format: 'iife', platform: 'browser', target: 'es2020',
  charset: 'utf8', legalComments: 'inline', metafile: true,
  plugins: [{ name: 'verified-curriculum', setup(b) {
    b.onResolve({ filter: /curriculumService$/ }, () => ({ path: 'catalog', namespace: 'verified-curriculum' }));
    b.onLoad({ filter: /.*/, namespace: 'verified-curriculum' }, () => ({ contents: 'module.exports = {loadCurriculum: () => (' + JSON.stringify(catalog) + ')};', loader: 'js' }));
  } }] });
for (const p of Object.keys(bundle.metafile.inputs)) {
  if (!p.includes(':') && path.basename(p) !== 'ios-webgen-entry.cjs') inputs.add(p);
}
const header = '// GENERATED; do not edit. Web ' + expected + '; tools/generate-web-derived-assets.mjs\n';
const outputs = {
  'curriculum-v2.json': JSON.stringify(curriculum, null, 1) + '\n',
  'assessment-catalog.json': JSON.stringify(assessments, null, 1) + '\n',
  'LessonWeb/exam-bank.js': header + read('services/examBankSource.js'),
  'LessonWeb/webgen-bundle.js': header + bundle.outputFiles[0].text
};
const manifest = {
  schemaVersion: 1, webCommit: expected, sourceDateEpoch: git('show', '-s', '--format=%ct', 'HEAD'),
  generatorVersion: hash(fs.readFileSync(fileURLToPath(import.meta.url))),
  inputs: [...inputs].sort().map(p => ({ path: p, sha256: hash(fs.readFileSync(path.join(webRoot, p))) })),
  nativeInputs: ['native-curriculum-overlay.json', 'webgen-entry.cjs', 'package-lock.json'].map(p => ({ path: 'tools/' + p, sha256: hash(fs.readFileSync(path.join(toolsRoot, p))) })),
  outputs: Object.entries(outputs).map(([p, data]) => ({ path: 'Matths/' + p, bytes: Buffer.byteLength(data), sha256: hash(data) })),
  semanticCounts: { courseIDs: curriculum.courses.map(c => c.id), courseCount: curriculum.courses.length,
    unitCount: curriculum.courses.reduce((n,c) => n+c.units.length,0), conceptCount: conceptIDs.size,
    availableCourseIDs: catalog.courses.filter(c => !c.developmentLocked).map(c => c.id),
    bankProblemTypeCount: bank.reduce((n,c) => n+c.units.reduce((n,u)=>n+u.subs.reduce((n,s)=>n+s.gens.length,0),0),0) }
};
// All inputs and all output shapes are verified before replacing generated files.
for (const [p, data] of Object.entries(outputs)) {
  const target = path.join(outputRoot, p); fs.mkdirSync(path.dirname(target), { recursive: true });
  const temporary = target + '.generating'; fs.writeFileSync(temporary, data); fs.renameSync(temporary, target);
}
const manifestPath = args.manifest || path.join(appRoot, 'WEB_DERIVED_ASSET_MANIFEST.json');
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify({ webCommit: expected, ...manifest.semanticCounts, outputHashes: manifest.outputs.map(x => x.sha256) }));
