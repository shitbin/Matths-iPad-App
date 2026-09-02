#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/Matths/PlacementExamScreen.swift"

grep -Fq 'applyDebugFixtureIfPresent()' "$SOURCE"
grep -Fq '"-placementFixture"' "$SOURCE"
grep -Fq 'case "intro"' "$SOURCE"
grep -Fq 'case "taking"' "$SOURCE"
grep -Fq 'case "result"' "$SOURCE"
grep -Fq '#if DEBUG' "$SOURCE"
grep -Fq 'placement-review-attempt' "$SOURCE"
grep -Fq 'questions.count' "$SOURCE"
grep -Fq 'reviewFixtureActive = true' "$SOURCE"
[[ "$(grep -Fc 'guard !reviewFixtureActive else { return }' "$SOURCE")" -eq 3 ]]
grep -Fq 'if reviewFixtureActive {' "$SOURCE"
grep -Fq 'font(shortHeight ? .mStat : .mStatLarge)' "$SOURCE"
grep -Fq '.minimumScaleFactor(0.68)' "$SOURCE"
grep -Fq '.accessibilityElement(children: .combine)' "$SOURCE"
[[ "$(grep -Fc '.minimumScaleFactor(0.68)' "$SOURCE")" -ge 2 ]]
grep -Fq 'LazyVGrid(' "$SOURCE"
grep -Fq 'columns: [GridItem(.flexible()), GridItem(.flexible())]' "$SOURCE"
grep -Fq 'shortHeight && !dynamicTypeSize.isAccessibilitySize' "$SOURCE"
grep -Fq 'size: shortHeight ? 112 : (compact ? 150 : 210)' "$SOURCE"
[[ "$(grep -Fc '.accessibilityElement(children: .contain)' "$SOURCE")" -ge 2 ]]
grep -Fq '.accessibilityLabel(MathText.plain(question.prompt))' "$SOURCE"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' "$SOURCE"

echo "Placement review fixture contract passed"
