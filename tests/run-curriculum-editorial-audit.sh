#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
node "$root/scripts/auditCurriculumEditorial.js" --check
grep -Fq '판정: **통과**' "$root/docs/CURRICULUM_EDITORIAL_AUDIT.md"
grep -Fq '개념 220개' "$root/docs/CURRICULUM_EDITORIAL_AUDIT.md"
