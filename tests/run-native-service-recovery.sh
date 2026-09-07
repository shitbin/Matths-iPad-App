#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-native-service.XXXXXX)
swiftc "$root/Matths/NativeServiceDraft.swift" "$root/Matths/NativeServicePhotoPreparation.swift" "$root/Matths/DataScope.swift" \
  "$root/tests/NativeServiceRecoveryCases.swift" -o "$scratch/cases"
"$scratch/cases"
