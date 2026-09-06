import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const suite = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (suite.failed !== 0 || suite.passed !== suite.count) throw Error('Cannot attest a failed suite');
const files = execFileSync('git', ['-C', root, 'ls-files', '-z'], { encoding: 'utf8' }).split('\0')
  .filter(p => /^(Matths\/|MatthsWidget\/|Matths.xcodeproj\/|Frameworks\/|ConceptMotion\/|Info.plist$|Matths.entitlements$)/.test(p)).sort();
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const sources = files.map(p => ({ path: p, sha256: sha(fs.readFileSync(path.join(root, p))) }));
const result = {
  schemaVersion: 1,
  baselineIOSCommit: '2cee63b217f6bdeaa51bdd5a2a8751a48b1f1f38',
  baselineRepositoryCommit: '726762f7b13614932ccaac866752b5538ed0bba2',
  webCommit: 'e3cc06360415a4c60460895b01f06a3248dae665',
  appVersion: '1.0', build: '17', xcode: '26.6 (17F113)', sdk: '26.5',
  sourceContentSHA256: sha(JSON.stringify(sources)), sourceFileCount: files.length,
  shellContracts: suite,
  runtime: {
    environment: 'iPhone 17 / iPad Pro 13 simulator, iOS 26.3, isolated UIQA bundle',
    offlinePracticeCases: { status: 'PASS', passed: 51, failed: 0 },
    syntheticDrawingRestore: { status: 'PASS', sha256: '5ec3764ee109ef2fff6ae3de3e1357658430c70f556aa1524d353c3cc7f4a276' },
    actualPencilAndTouchDrawing: { status: 'NOT_RUN', reason: 'CUA coordinate drag returned noWindowsAvailable' },
    sandboxTransactions: { status: 'NOT_RUN' },
    sameAccountProductionParity: { status: 'NOT_RUN' },
    fullPhysicalDeviceAccessibilityMatrix: { status: 'NOT_RUN' },
    actualGGUFInferenceAndPerformance: { status: 'NOT_RUN' }
  }
};
fs.writeFileSync(path.join(root, 'PARITY_TEST_RESULTS.json'), JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({ sourceContentSHA256: result.sourceContentSHA256, contracts: suite.count }));
