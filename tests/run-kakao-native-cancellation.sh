#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-kakao-cancel.XXXXXX)
node - "$root" "$scratch" <<'JS'
const fs=require('node:fs');
const [root,out]=process.argv.slice(2);
const code=fs.readFileSync(root+'/Matths/KakaoNativeSignIn.swift','utf8').replace(/^import .*\n/gm,'');
fs.writeFileSync(out+'/Native.swift','import Foundation\n'+code);
JS
swiftc -parse-as-library "$scratch/Native.swift" "$root/Matths/NativeAuthenticationPresentationPolicy.swift" "$root/tests/KakaoNativeCancellationCases.swift" -o "$scratch/cases"
"$scratch/cases"
