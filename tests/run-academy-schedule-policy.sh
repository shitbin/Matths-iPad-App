#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-academy-schedule.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
xcrun swiftc "$root/Matths/AcademySchedulePolicy.swift" "$root/tests/AcademySchedulePolicyCases.swift" -o "$work/check"
"$work/check"
grep -Fq 'ForEach(AcademySchedulePolicy.weekdayLabels.indices' "$root/Matths/TeacherClassManagementPanel.swift"
grep -Fq 'private let weekdayLabels = AcademySchedulePolicy.weekdayLabels' "$root/Matths/AdminAcademyExplorer.swift"
for screen in TeacherClassManagementPanel AdminAcademyExplorer; do
  grep -Fq 'AcademySchedulePolicy.validWeekdays' "$root/Matths/$screen.swift"
  grep -Fq 'AcademySchedulePolicy.attendanceWindowIsValid' "$root/Matths/$screen.swift"
done
