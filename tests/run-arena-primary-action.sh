#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-arena-entry.XXXXXX)
swiftc "$root/Matths/ArenaMatchEntryPolicy.swift" "$root/tests/ArenaMatchEntryCases.swift" -o "$scratch/cases"
"$scratch/cases"
node - "$root" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const root = process.argv[2];
const screen = fs.readFileSync(root+'/Matths/GoatArenaScreen.swift','utf8');
const play = fs.readFileSync(root+'/Matths/GoatArenaMatchPlayScreen.swift','utf8');
const fixtureSource = fs.readFileSync(root+'/Matths/DemoFixtures/DemoFixturesArena.swift','utf8');
const fixture = JSON.parse(fixtureSource.match(/static let snapshot = #"""([\s\S]*?)"""#/)[1]).arena;
assert.equal(fixture.activeMatch.role, 'DEFENDER');
assert.equal(fixture.activeMatch.status, 'MATCHED');
assert.deepEqual(fixture.activeMatch.availableActions, ['START']);
assert.equal(fixture.pendingInvitation, null);
assert(!screen.includes('defenderResponseRefreshButton'));
const compactBody=screen.slice(screen.indexOf('private var compactArenaBody:'),screen.indexOf('private func compactStatusCard('));
assert(compactBody.indexOf('compactActionStack(snapshot)') < compactBody.indexOf('compactStatusCard(snapshot)'));
assert(screen.includes('Unranked 공격 상대 찾기') && screen.includes('Ranked 공격 상대 찾기'));
const primary=screen.slice(screen.indexOf('private func compactPrimaryAction('), screen.indexOf('private func canInspectMatchedGame('));
assert(primary.includes('canPlay(match) || canInspectMatchedGame(match)'));
assert(primary.includes('MatchLaunch(id: matchId, briefing: matchBriefing(match))'));
assert(primary.includes('matchEntryTitle(match)'));
assert(screen.includes('guard let invitation = snapshot.pendingInvitation'));
assert(screen.includes('let matchId = invitation.id.trimmingCharacters('));
assert(screen.includes('timeLimitSeconds: match.timeLimitSeconds.flatMap'));
assert(screen.includes('defenderAcceptButton(label: "초대 수락")') && screen.includes('defenderDeclineButton(label: "초대 거절")'));
const load=play.slice(play.indexOf('private func loadPreStartContract()'),play.indexOf('private func preStartContractCard('));
assert(load.includes('ServerAPI.getGoatArenaMatch(matchId: matchId)'));
assert(load.includes('detail.capabilities?.availableActions'));
assert(load.includes('ArenaMatchEntryPolicy.permitsStart'));
assert(!load.includes('ServerAPI.startGoatArenaMatch'));
assert(play.includes('guard !lobbyPending else { return }'));
assert.equal((screen.match(/MatchLaunch\(id: matchId, briefing: \.newMatch\)/g)||[]).length,4);
assert(!screen.includes('MatchLaunch(id: matchId)'),'newly created games must not start their timer on presentation');
assert(play.includes('timeLimitSeconds: nil, startsByText: nil, skipsLobby: false'));
const timer=play.slice(play.indexOf('private var countdownLabel:'),play.indexOf('private func presentIntro('));
assert(timer.includes('.lineLimit(1)') && timer.includes('.fixedSize(horizontal: true, vertical: false)'));
console.log('Actual Arena UI priorities, matched/offer separation, fixture START and GET-only pre-start wiring PASS');
JS
