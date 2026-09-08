#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
node - "$root" <<'JS'
const fs = require('node:fs'), assert = require('node:assert/strict');
const root = process.argv[2];
const read = name => fs.readFileSync(`${root}/Matths/${name}.swift`, 'utf8');
const flow = read('LearningFlowScreens');
const me = flow.slice(flow.indexOf('struct MeHubScreen:'), flow.indexOf('struct FlowDestinationRow:'));
const resources = read('LearningResourcesScreen');
for (const route of ['chat', 'archive', 'studyHall', 'storeCatalog', 'community', 'coachSuggestions']) {
  assert(resources.includes(`store.route = .${route}`), `resource ${route} remains native and reachable`);
  assert(!me.includes(`store.route = .${route}`), `resource ${route} is not repeated in Me`);
}
assert(resources.includes('store.openHostedPortal(.parent)'), 'parent keeps separate account handling');
for (const route of ['profile', 'academy', 'commerce', 'services', 'faq', 'support']) {
  assert(me.includes(`store.route = .${route}`), `personal destination ${route} remains available`);
}
assert(!resources.includes('store.route = .commerce') && !resources.includes('store.route = .academy'));
assert(read('ServiceHubScreen').includes('LearningResourcesScreen()'));
assert(flow.includes('if let previous = store.previousBrowseRoute'));
assert(read('MatthsApp').includes('accountSessionGeneration.uuidString'));
const tutorial = read('RootView');
assert(/id: "ai-coach"[^\n]*route: \.services/.test(tutorial));
assert(/id: "community-entry"[^\n]*route: \.services/.test(tutorial));
assert(resources.includes('.tutorialTarget(.topChat)') && resources.includes('.tutorialTarget(.communityBrowse)'));
console.log('Single resource directory, preserved native destinations, personal actions, current tutorial targets and back context PASS');
JS
