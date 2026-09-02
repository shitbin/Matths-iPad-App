#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/GoatArenaFriendlyMatchSheet.swift"
router="$root/Matths/DemoMode.swift"
fixture="$root/Matths/DemoArenaFriendlyFixtures.swift"

for route in \
  '"/api/v1/goat-arena/matches/main/friendly"' \
  '"/api/v1/goat-arena/matches/main/friendly/invitations"' \
  '"/api/v1/goat-arena/matches/main/friendly/invitations/\(invitationId)/respond"' \
  '"/api/v1/goat-arena/matches/main/friendly/invitations/\(invitationId)/cancel"'
do
  grep -Fq "$route" "$screen"
done

grep -Fq 'CompactHeightColumns(' "$screen"
grep -Fq '수락 즉시 나와' "$screen"
grep -Fq '학습일수는 차감되지 않았습니다' "$screen"
grep -Fq 'onMatchCreated(match.id)' "$screen"

for route in \
  'GET /api/v1/goat-arena/matches/main/friendly' \
  'POST /api/v1/goat-arena/matches/main/friendly/invitations' \
  '/api/v1/goat-arena/matches/main/friendly/invitations/{id}/respond' \
  '/api/v1/goat-arena/matches/main/friendly/invitations/{id}/cancel'
do
  grep -Fq "$route" "$router"
done
grep -Fq 'static func friendlyOptions' "$fixture"
grep -Fq 'static func friendlyInvitationResponded' "$fixture"

echo 'Native Arena friendly invitation and demo transport contracts passed.'
