#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
project="$root/Matths.xcodeproj/project.pbxproj"

python3 - "$project" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")


def configuration(identifier: str) -> str:
    match = re.search(
        rf"\b{re.escape(identifier)} /\* Release \*/ = \{{(?P<body>.*?)\n\t\t\}};",
        source,
        re.S,
    )
    if not match:
        raise SystemExit(f"FAIL: Release configuration {identifier} not found")
    return match.group("body")


expected = {
    # Matths app target
    "A10000F1000000000000001": "Matths App Store 2026-09-01",
    # MatthsWidget extension target
    "45DB579CE80E44F0065B468F": "Matths Widget App Store 2026-09-01",
}

for identifier, profile in expected.items():
    body = configuration(identifier)
    required = (
        'CODE_SIGN_IDENTITY = "Apple Distribution";',
        "CODE_SIGN_STYLE = Manual;",
        f'PROVISIONING_PROFILE_SPECIFIER = "{profile}";',
    )
    for setting in required:
        if setting not in body:
            raise SystemExit(
                f"FAIL: {identifier} is missing Release signing setting: {setting}"
            )

# Debug must remain convenient for simulator/device development. This also catches
# a broad search-and-replace that accidentally makes every configuration manual.
for identifier in ("A10000E1000000000000001", "C3A59918C7FFA852C7F3EE43"):
    match = re.search(
        rf"\b{re.escape(identifier)} /\* Debug \*/ = \{{(?P<body>.*?)\n\t\t\}};",
        source,
        re.S,
    )
    if not match or "CODE_SIGN_STYLE = Automatic;" not in match.group("body"):
        raise SystemExit(f"FAIL: Debug configuration {identifier} must stay automatic")

print("Release distribution signing contract passed")
PY
