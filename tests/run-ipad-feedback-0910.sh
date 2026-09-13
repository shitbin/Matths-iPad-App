#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
node - "$root" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict'),root=process.argv[2];
const read=n=>fs.readFileSync(root+'/Matths/'+n,'utf8');
const shell=read('RootView.swift'), learn=read('LearningFlowScreens.swift');
assert(shell.includes('false // Student navigation stays in the bottom bar on iPhone and iPad.'));
assert(shell.includes('case .home:\n                        HomeScreen()'));
assert(shell.includes('private var showsWeeklySection: Bool { !isStaffHome }'));
assert(shell.includes('.tutorialTarget(.todayPrimaryAction)') && shell.includes('.tutorialTarget(.todayProgress)'));
assert(!read('ProfileScreen.swift').includes('settingRow("화면 모션"'));
const hub=learn.slice(learn.indexOf('struct LearningHubScreen:'),learn.indexOf('struct LearningRecordsScreen:'));
assert(!hub.includes('store.route = .kice'));
assert(hub.includes('KiceLibrarySheet()') && !hub.includes('오프라인 연습'));
const library=read('KiceLibrarySheet.swift');
assert(library.includes('ForEach(KiceBank.exams)') && library.includes('store.startKice(exam)'));
assert(library.includes('.disabled(KiceBank.pdfURL(for: exam) == nil)'));
const exam=read('KiceExamScreen.swift');
assert(exam.includes('guard exam != nil, let owner = displayedOwner,'));
assert(exam.includes('store.ownsCurrentAccountSession(owner) else {\n                        timer.pause()\n                        store.route = .learn'));
assert(exam.includes('.disabled(store.kiceBusy && exam != nil)'));
assert(exam.includes('if showsExamSubtitle && exam != nil'));
const arena=read('GoatArenaScreen.swift'), inbox=read('ArenaDefenseInbox.swift');
assert(!arena.includes('Text("실력과 자리는 다른 숫자입니다")'));
assert(!arena.includes('알 수 없는 상태를 임의의 순위로'));
assert(arena.includes('if let message = subMatchCreateError'));
assert(arena.includes('Label("받은 공격 확인"'));
assert(inbox.includes('getGoatArenaActionableDefenses(authorization: captured.authorization)'));
assert(inbox.includes('matches = result'));
assert(arena.includes('owner.isCurrent(in: store) else { return }'));
console.log('PASS eight iPad feedback images: bottom navigation, restored home, KICE selection/exit, motion/offline removal, actual attack/defense entry and concise copy');
JS
