#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
host="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host"
scratch=$(mktemp -d /tmp/matths-copy-ast.XXXXXX)
trap 'rm -f "$scratch/check"; rmdir "$scratch"' EXIT
swiftc -I "$host" -L "$host" -lSwiftSyntax -lSwiftParser -Xlinker -rpath -Xlinker "$host" \
  "$root/tools/VerifyUserFacingCopy.swift" -o "$scratch/check"
"$scratch/check" --self-test
"$scratch/check" "$root/Matths"
