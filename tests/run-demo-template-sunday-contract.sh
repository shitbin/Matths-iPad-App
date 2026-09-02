#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/matths-demo-sunday.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

{
  printf 'import Foundation\n'
  sed -n '/^enum DemoTemplate {/,/^\/\/ MARK: - 경로/p' \
    "$root/Matths/DemoMode.swift" | sed '$d'
  cat <<'SWIFT'

let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]
let wednesday = formatter.date(from: "2026-08-26T03:00:00Z")!

precondition(
    DemoTemplate.resolve("@SUN+0T15:00@", now: wednesday)
        == "2026-08-23T06:00:00.000Z")
precondition(
    DemoTemplate.resolve("@SUN+1T18:00@", now: wednesday)
        == "2026-08-30T09:00:00.000Z")
precondition(
    DemoTemplate.resolve("@SUN-1T21:00@", now: wednesday)
        == "2026-08-16T12:00:00.000Z")

print("Demo Sunday schedule tokens passed")
SWIFT
} > "$work/main.swift"

swiftc -module-cache-path "$work/ModuleCache" "$work/main.swift" -o "$work/test"
"$work/test"

grep -Fq '"scheduleLabel": "매주 일요일 오후 3시·6시·9시, 최대 3회 응시"' \
  "$root/Matths/DemoFixtures/DemoFixturesAssessment.swift"
if grep -Fq '매주 토요일 09:00 공개' \
  "$root/Matths/DemoFixtures/DemoFixturesAssessment.swift"; then
  echo 'stale Saturday weekly mock schedule remains' >&2
  exit 1
fi
