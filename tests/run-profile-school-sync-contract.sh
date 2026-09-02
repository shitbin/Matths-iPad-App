#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
API="$ROOT/Matths/ServerAPI.swift"
PROFILE="$ROOT/Matths/ProfileScreen.swift"

grep -Fq '"PATCH", "/api/v1/me/school"' "$API"
grep -Fq 'body: ["schoolRegion": region, "schoolCode": code]' "$API"

# 프로필은 가입 화면과 같은 서버 학교 목록을 사용하고, 서버 성공 전에는
# AppStore 학교 값을 바꾸지 않는다.
grep -Fq 'APISchoolPickerSheet { region, code, _ in' "$PROFILE"
grep -Fq '.compactHeightSheet(isPresented: $showPicker)' "$PROFILE"
grep -Fq '.compactHeightSheet(isPresented: $showProfilePhotoCropper)' "$PROFILE"
if grep -Fq '.sheet(isPresented: $showPicker)' "$PROFILE"; then
  echo "iPhone 가로 학교 목록이 draggable sheet에 남아 있습니다" >&2
  exit 1
fi
grep -Fq 'let user = try await ServerAPI.updateSchool(region: region, code: code)' "$PROFILE"
grep -Fq 'guard let school = user.school,' "$PROFILE"
grep -Fq 'let confirmedRegion = school.region,' "$PROFILE"
grep -Fq 'let confirmedCode = school.code,' "$PROFILE"
grep -Fq 'let confirmedName = school.name?.trimmingCharacters' "$PROFILE"
grep -Fq 'store.setServerVerifiedSchool(' "$PROFILE"

# 서버에만 존재하는 최신 학교도 앱 번들 Schools.find 재검증에서 탈락하지 않고,
# 계정별로 학교명까지 복원되어야 한다.
grep -Fq 'AppStore.slotKey("matths.serverVerifiedSchool")' "$PROFILE"
grep -Fq 'record.region == region' "$PROFILE"
grep -Fq 'record.code == code' "$PROFILE"
grep -Fq 'UserDefaults.standard.set(data, forKey: Self.serverVerifiedSchoolKey)' "$PROFILE"
grep -Fq 'let user = try await ServerAPI.me()' "$PROFILE"
grep -Fq 'store.profileSchoolName' "$PROFILE"

if grep -Fq '.sheet(isPresented: $showPicker) { SchoolPickerSheet() }' "$PROFILE"; then
  echo "프로필 학교 변경이 로컬 전용 피커에 남아 있습니다" >&2
  exit 1
fi

# 늦은 앞 계정 응답이 새 계정 프로필에 붙지 않아야 한다.
grep -Fq 'let accountSlot = DataScope.slot' "$PROFILE"
grep -Fq 'DataScope.slot == accountSlot' "$PROFILE"

echo "profile school sync contract passed"
