#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
node - "$root" <<'JS'
const fs = require('node:fs');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = process.argv[2];
const read = name => fs.readFileSync(path.join(root, 'Matths', name), 'utf8');
const flow = read('LearningFlowScreens.swift');
const rootView = read('RootView.swift');
const app = read('MatthsApp.swift');
const section = (from, to) => flow.slice(flow.indexOf(from), flow.indexOf(to));
const top = section('struct LearningFlowTopBar:', 'struct LearningFlowSidebar:');
assert(top.includes('PrimaryBrandIdentity()'));
assert(!top.includes('Text(title)'), 'screen headings must not replace the top-left logo');
assert(top.includes('case .concept: store.route = .curriculum'), 'concept back returns to its course, not past it to the hub');
assert(read('ConceptScreenV2.swift').includes('if !ProductExperience.enabled {\n                Button { store.route = .curriculum }'), 'new shell owns the single course-back control');
assert(read('ProductNavigation.swift').includes('.placement, .pro, .solve, .result: .learn'), 'learning tools remain in the learning tab');
assert(read('MatthsApp.swift').includes('notificationOrigin = oldValue'), 'notifications must retain their canonical origin tracking');
const today = section('struct TodayLearningScreen:', 'struct LearningHubScreen:');
assert(today.includes('TodayLearningOverview'));
assert(today.includes('TodayDashboardPolicy.agenda'));
assert(!today.includes('Button("다른 학습 보기")') && !today.includes('Button("학습 기록")'));
const shortcutStart = rootView.indexOf('private struct HomeShortcutRow:');
const shortcutEnd = rootView.indexOf('private struct HomeNotice:', shortcutStart);
assert(shortcutStart >= 0 && shortcutEnd > shortcutStart, 'today shortcut section must exist');
const shortcuts = rootView.slice(shortcutStart, shortcutEnd);
assert(shortcuts.includes('entry(title: "게시판"'), 'today needs a direct community shortcut');
assert(shortcuts.includes('store.route = .community'), 'community shortcut must open the native board');
assert(shortcuts.includes('today-community-shortcut'), 'community shortcut needs a stable accessibility id');
assert(app.includes('communityOrigin = oldValue'), 'community entry must preserve its navigation origin');
assert(app.includes('StudentDestination.containing(communityOrigin).route'), 'community must keep the originating tab selected');
assert(top.includes('case .community: store.route = store.communityOrigin'), 'community back fallback must return to its origin');
const twoColumnStart = rootView.indexOf('private var twoColumnBody:');
const twoColumnEnd = rootView.indexOf('private var todayAgenda:', twoColumnStart);
assert(twoColumnStart >= 0 && twoColumnEnd > twoColumnStart, 'two-column today layout must exist');
const twoColumn = rootView.slice(twoColumnStart, twoColumnEnd);
assert(twoColumn.includes('missionLead'), 'left column must keep the primary mission and progress');
assert(twoColumn.includes('missionUtilities'), 'right column must receive agenda and shortcuts');
assert(twoColumn.indexOf('missionUtilities') < twoColumn.indexOf('weeklySection'), 'weekly status must follow the right-column actions');
assert(twoColumn.lastIndexOf('arenaTeaser') > twoColumn.indexOf('weeklySection'), 'Arena must follow the balanced columns without an empty row');
const learn = section('struct LearningHubScreen:', 'struct LearningRecordsScreen:');
assert(!learn.includes('LearningPathBrowser()'), 'only one canonical course browser');
for (const route of ['curriculum', 'assess', 'quickPractice', 'pro']) {
  assert(learn.includes(`store.route = .${route}`), `learning destination ${route} remains accessible`);
}
assert(!learn.includes('store.route = .weeklyMock'), 'official mock exams are owned by the assessment center');
assert(!learn.includes('OfflinePracticeScreen()'), 'user-requested offline entry removal');
assert(learn.includes('KiceLibrarySheet()'), 'past papers require explicit selection');
const overview = read('TodayLearningOverview.swift');
assert(overview.includes('ServerAPI.getDashboardActivity()'));
assert(overview.includes('store.ownsCurrentAccountSession(owner)'));
assert(overview.includes('DataScope.slot == slot'));
assert(overview.includes('weeklySolvedProblems > 0'));
assert(overview.includes('DashboardActivityCache.save(value, slot: slot)'));
assert(overview.includes('Text("\\(store.learningSummary.done) / \\(store.learningSummary.total)개 완료")'));
console.log('Home/navigation clarity: logo, actual context, distinct destinations and account ownership PASS');
JS
