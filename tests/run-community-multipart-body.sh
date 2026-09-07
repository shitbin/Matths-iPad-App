#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-community-multipart.XXXXXX)
swiftc "$root/Matths/CommunityMultipartBody.swift" "$root/tests/CommunityMultipartBodyCases.swift" -o "$scratch/cases"
"$scratch/cases"
