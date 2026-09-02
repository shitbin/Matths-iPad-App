#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_manifest="$repo_root/Matths/PrivacyInfo.xcprivacy"
widget_manifest="$repo_root/MatthsWidget/PrivacyInfo.xcprivacy"
project="$repo_root/Matths.xcodeproj/project.pbxproj"

plutil -lint "$app_manifest" "$widget_manifest" >/dev/null

app_json=$(plutil -convert json -o - "$app_manifest")
widget_json=$(plutil -convert json -o - "$widget_manifest")

printf '%s' "$app_json" | grep -Fq 'NSPrivacyAccessedAPICategoryUserDefaults'
printf '%s' "$app_json" | grep -Fq '"CA92.1"'
printf '%s' "$app_json" | grep -Fq 'NSPrivacyAccessedAPICategoryFileTimestamp'
printf '%s' "$app_json" | grep -Fq '"C617.1"'
printf '%s' "$app_json" | grep -Fq 'NSPrivacyAccessedAPICategoryDiskSpace'
printf '%s' "$app_json" | grep -Fq '"E174.1"'

# 실제 서버 경계가 계정 식별자·StoreKit 구매 내역·Arena 경기 내용을 계정에
# 연결해 보관한다. App Store Connect 설문과 매니페스트에서 빠지면 안 된다.
for collected_type in \
  NSPrivacyCollectedDataTypeUserID \
  NSPrivacyCollectedDataTypePurchaseHistory \
  NSPrivacyCollectedDataTypeGameplayContent
do
  printf '%s' "$app_json" | grep -Fq "$collected_type"
done

printf '%s' "$widget_json" | grep -Fq 'NSPrivacyAccessedAPICategoryUserDefaults'
printf '%s' "$widget_json" | grep -Fq '"CA92.1"'

grep -Fq 'PrivacyInfo.xcprivacy in Resources' "$project"
test -f "$widget_manifest"

printf '%s\n' 'Privacy required-reason contract passed'
