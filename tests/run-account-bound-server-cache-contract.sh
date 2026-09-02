#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$ROOT/Matths/ServerAPI.swift"
scope="$ROOT/Matths/DataScope.swift"

# 비동기 응답의 캐시는 응답 시점 전역 슬롯이 아니라 요청 시작 슬롯에 귀속한다.
snapshot_start=$(grep -n 'static func getGoatArenaSnapshot' "$api" | head -1 | cut -d: -f1)
rulebook_start=$(grep -n 'static func getGoatArenaRulebook' "$api" | head -1 | cut -d: -f1)
snapshot_slice=$(sed -n "${snapshot_start},$((snapshot_start + 24))p" "$api")
rulebook_slice=$(sed -n "${rulebook_start},$((rulebook_start + 24))p" "$api")

printf '%s' "$snapshot_slice" | grep -Fq 'let accountSlot = DataScope.slot'
printf '%s' "$snapshot_slice" | grep -Fq 'accountSlot: accountSlot'
printf '%s' "$rulebook_slice" | grep -Fq 'let accountSlot = DataScope.slot'
printf '%s' "$rulebook_slice" | grep -Fq 'accountSlot: accountSlot'

cache_write_count=$(grep -Fc 'DataScope.url(goatArena' "$api")
explicit_write_count=$(grep -Fc 'for: accountSlot)' "$api")
test "$cache_write_count" -ge 4
test "$explicit_write_count" -ge 2

grep -Fq '"goat-arena-v1-cache.json"' "$scope"
grep -Fq '"goat-arena-rulebook-v1-cache.json"' "$scope"

echo 'Account-bound server cache contracts passed.'
