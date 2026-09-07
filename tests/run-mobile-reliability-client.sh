#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-mobile-reliability.XXXXXX)
swiftc -D MOBILE_SYNC_TEST "$root/Matths/StudentFlowDomain.swift" "$root/Matths/DataScope.swift" \
  "$root/Matths/FirstLearningJourneyPersistence.swift" "$root/Matths/FirstLearningJourneyStore.swift" \
  "$root/Matths/FirstLearningJourneyRemoteSync.swift" \
  "$root/Matths/MobileFeatureContract.swift" "$root/Matths/MobileFeatureAPI.swift" \
  "$root/Matths/CommunityMultipartBody.swift" "$root/Matths/CommunityRequestIdentity.swift" \
  "$root/Matths/NativeServiceDraft.swift" "$root/Matths/NativeCommunityAPI.swift" \
  "$root/tests/MobileReliabilityClientCases.swift" -o "$scratch/cases"
"$scratch/cases" "$@"
