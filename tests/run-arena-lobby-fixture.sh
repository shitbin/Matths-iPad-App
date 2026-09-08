#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-arena-lobby.XXXXXX)
node - "$root" "$scratch" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const [root, out] = process.argv.slice(2);
const api = fs.readFileSync(root+'/Matths/ServerAPI.swift','utf8');
const a = api.indexOf('    struct GoatArenaParticipantMatch:'), b = api.indexOf('    private struct GoatArenaMatchesResponse:',a);
assert(a >= 0 && b > a);
fs.writeFileSync(out+'/DTO.swift','import Foundation\nenum ServerAPI {\n'+api.slice(a,b)+'\n}');
const demo=fs.readFileSync(root+'/Matths/DemoMode.swift','utf8');
const start=demo.indexOf('enum DemoTemplate {'), end=demo.indexOf('// MARK: - 경로 → 픽스처 라우터',start);
const escapeStart=demo.indexOf('    static func int('), escapeEnd=demo.indexOf('    private static func syncedListEcho(',escapeStart);
assert(start>=0 && end>start && escapeStart>=0 && escapeEnd>escapeStart);
fs.writeFileSync(out+'/Demo.swift','import Foundation\n'+demo.slice(start,end)+'\nenum DemoRouter {\n'+demo.slice(escapeStart,escapeEnd)+'\n}');
assert(demo.includes('("GET",  "/api/v1/goat-arena/matches/{matchId}")'));
assert(demo.includes('return DemoArenaFixtures.matchDetail(matchId: captures["matchId"]'));
JS
swiftc -D DEBUG "$scratch/DTO.swift" "$scratch/Demo.swift" "$root/Matths/ArenaMatchEntryPolicy.swift" \
  "$root/Matths/DemoFixtures/DemoFixturesArena.swift" "$root/tests/ArenaLobbyFixtureCases.swift" -o "$scratch/cases"
"$scratch/cases"
