// One-time, explicit extraction of iOS-owned presentation content. This is not
// a Web policy source; catalog IDs/topics/order always come from exact Web YAML.
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
const sourceCommit = '726762f7b13614932ccaac866752b5538ed0bba2';
const source = JSON.parse(execFileSync('git', ['show', `${sourceCommit}:Matths/curriculum-v2.json`], { encoding: 'utf8' }));
const concepts = {};
for (const course of source.courses) for (const unit of course.units) for (const concept of unit.concepts) {
  concepts[concept.id] = { lesson: concept.lesson ?? null, legacy: concept.legacy ?? null };
}
const overlay = { schemaVersion: 1, nativeSourceCommit: sourceCommit, learningTracks: source.learningTracks, concepts };
fs.writeFileSync(new URL('native-curriculum-overlay.json', import.meta.url), JSON.stringify(overlay, null, 2) + '\n');
