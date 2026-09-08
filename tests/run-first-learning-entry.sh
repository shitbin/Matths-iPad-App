#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-first-entry.XXXXXX)
node - "$root" "$scratch" <<'JS'
const fs = require('node:fs');
const [root, out] = process.argv.slice(2);
const source = fs.readFileSync(root + '/Matths/FirstLearningJourneyScreen.swift', 'utf8');
const start = source.indexOf('    private func browseCoursesWithoutGuide()');
const end = source.indexOf('    private func restartJourney()', start);
if (start < 0 || end < 0) throw Error('actual first-learning entry boundaries not found');
fs.writeFileSync(out + '/Entry.swift', 'import Foundation\nextension EntryHarness {\n' + source.slice(start, end) + '\nfunc exerciseBrowse() { browseCoursesWithoutGuide() }\n}\n');
JS
swiftc -swift-version 5 "$root/Matths/StudentFlowDomain.swift" "$root/tests/FirstLearningEntryCases.swift" "$scratch/Entry.swift" -o "$scratch/cases"
"$scratch/cases"
