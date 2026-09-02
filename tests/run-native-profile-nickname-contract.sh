#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/ServerAPI.swift"
profile="$root/Matths/ProfileScreen.swift"
demo="$root/Matths/DemoMode.swift"

for file in "$api" "$profile" "$demo"; do
  [ -f "$file" ] || { echo "FAIL missing $file" >&2; exit 1; }
done

grep -Fq 'static func updateNickname' "$api"
grep -Fq '"PATCH", "/api/v1/me/nickname"' "$api"
grep -Fq 'Label("닉네임 변경", systemImage: "pencil")' "$profile"
grep -Fq 'TextField("새 닉네임", text: $nicknameDraft)' "$profile"
grep -Fq '2–30자 · 꺾쇠 문자(< >) 제외' "$profile"
grep -Fq 'nicknameDraftIsValid' "$profile"
grep -Fq 'PATCH /api/v1/me/nickname' "$demo"

if grep -Fq '이름은 웹 프로필에서 변경할 수 있습니다' "$profile"; then
  echo "FAIL profile still sends nickname changes to the web" >&2
  exit 1
fi

echo "native profile nickname contract passed"
