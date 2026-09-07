#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-purchase-admission.XXXXXX)
swiftc "$root/Matths/PurchaseAdmission.swift" "$root/tests/PurchaseAdmissionCases.swift" -o "$scratch/cases"
"$scratch/cases"
