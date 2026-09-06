import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = new URL('../', import.meta.url);
const source = fs.readFileSync(new URL('Matths/GoatArenaScreen.swift', root), 'utf8');
function verify(value) {
  const sheets = [...value.matchAll(/\.compactHeightSheet\(isPresented:\s*\$\w+\)\s*\{\s*(\w+)\(/g)].map(x=>x[1]);
  for (const destination of ['GoatArenaRulebookScreen', 'GoatArenaLeaderboardSheet', 'GoatArenaMoreMenuSheet', 'GoatArenaMainMatchSheet']) {
    assert(sheets.includes(destination), destination + ' must use the compact-height presentation adapter');
  }
}
verify(source);
verify(source.replaceAll('showsArenaMoreMenu', 'renamedPresentationState'));
assert.throws(() => verify(source.replace(/\.compactHeightSheet\(isPresented:\s*\$showsArenaMoreMenu\)/, '.sheet(isPresented: $showsArenaMoreMenu)')));
console.log('Arena presentation behavior and mutation cases PASS');
