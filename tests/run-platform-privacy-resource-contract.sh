#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
plist="$root/Info.plist"
privacy="$root/Matths/PrivacyInfo.xcprivacy"
project="$root/Matths.xcodeproj/project.pbxproj"
profile="$root/Matths/ProfileScreen.swift"
assessment="$root/Matths/Screens.swift"
sheet_analysis="$root/Matths/SheetAnalysis.swift"

camera='시험지와 풀이 증거를 촬영하는 데 사용합니다. 풀이 증거 제출을 선택하면 촬영한 사진이 검토를 위해 Matths 서버에 전송됩니다.'
photos='시험지·AI 튜터 질문·프로필·풀이 증거 사진을 선택하는 데 사용합니다. AI 튜터 질문은 기기 안에서 처리하며, 프로필 저장 또는 풀이 증거 제출을 선택하면 해당 사진이 Matths 서버에 전송됩니다.'

plutil -lint "$plist" >/dev/null
plutil -lint "$privacy" >/dev/null

actual_camera=$(/usr/libexec/PlistBuddy -c 'Print :NSCameraUsageDescription' "$plist")
actual_photos=$(/usr/libexec/PlistBuddy -c 'Print :NSPhotoLibraryUsageDescription' "$plist")
[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$plist")" = 'false' ]
[ "$actual_camera" = "$camera" ]
[ "$actual_photos" = "$photos" ]

# 운영 앱은 https://www.matths.kr만 사용한다. 실제 기능에 없는 로컬 네트워크
# 권한 문구나 ATS 평문 예외를 남겨 심사자와 사용자에게 과도한 접근을 요청하지 않는다.
if grep -qE 'NSLocalNetworkUsageDescription|NSAllowsLocalNetworking' "$plist" "$project"; then
  echo 'FAIL: 사용하지 않는 로컬 네트워크 권한 또는 ATS 예외가 남아 있습니다.' >&2
  exit 1
fi

# GENERATE_INFOPLIST_FILE의 빌드 설정 override도 Debug/Release 양쪽에서 같아야 한다.
[ "$(grep -F -c "INFOPLIST_KEY_NSCameraUsageDescription = \"$camera\";" "$project")" -eq 2 ]
[ "$(grep -F -c "INFOPLIST_KEY_NSPhotoLibraryUsageDescription = \"$photos\";" "$project")" -eq 2 ]
if grep -R -n -F '서버로 보내지 않습니다' "$plist" "$privacy" "$project"; then
  echo 'FAIL: 실제 업로드 경로와 충돌하는 권한 약속이 남아 있습니다.' >&2
  exit 1
fi

# Apple Privacy Manifest의 핵심 수집 항목이 계정 연결·비추적·앱 기능 목적으로
# 모두 선언됐는지 배열 순서에 기대지 않고 검사한다.
privacy_json=$(plutil -convert json -o - "$privacy")
for collected_type in \
  NSPrivacyCollectedDataTypePhotosorVideos \
  NSPrivacyCollectedDataTypeUserID \
  NSPrivacyCollectedDataTypePurchaseHistory \
  NSPrivacyCollectedDataTypeGameplayContent
do
  printf '%s' "$privacy_json" | grep -Fq "$collected_type"
done
linked_count=$(printf '%s' "$privacy_json" | grep -o '"NSPrivacyCollectedDataTypeLinked":true' | wc -l | tr -d ' ')
tracking_count=$(printf '%s' "$privacy_json" | grep -o '"NSPrivacyCollectedDataTypeTracking":false' | wc -l | tr -d ' ')
purpose_count=$(printf '%s' "$privacy_json" | grep -o '"NSPrivacyCollectedDataTypePurposeAppFunctionality"' | wc -l | tr -d ' ')
collected_count=$(printf '%s' "$privacy_json" | grep -o '"NSPrivacyCollectedDataType":' | wc -l | tr -d ' ')
[ "$linked_count" -eq "$collected_count" ]
[ "$tracking_count" -eq "$collected_count" ]
[ "$purpose_count" -eq "$collected_count" ]

# File System Synchronized Group가 KiceBank를 자동으로 Release에 싣지 못하게 하고,
# 별도 phase가 Debug에서만 복사하며 다른 구성에서는 번들 혼입을 실패 처리한다.
[ "$(find "$root/Matths/KiceBank" -maxdepth 1 -type f -name '*.pdf' | wc -l | tr -d ' ')" -eq 9 ]
grep -q 'PBXFileSystemSynchronizedBuildFileExceptionSet' "$project"
# 현재 KiceBank 파일 전부가 개별 membership exception에 있어야 한다. 동기화
# 그룹은 디렉터리 이름 하나만 예외로 두면 하위 리소스를 계속 복사한다.
for source_file in "$root/Matths/KiceBank"/*; do
  relative_path="KiceBank/$(basename "$source_file")"
  grep -Fq "\"$relative_path\"," "$project"
done
grep -q 'Debug KICE internal materials gate' "$project"
grep -Fq 'if [ \"${CONFIGURATION}\" = \"Debug\" ]' "$project"
grep -Fq '/bin/cp -X -f' "$project"
grep -q '권리 확인 전 KICE 내부 자료가' "$project"

# ‘학습·연구 목적’은 KICE 기출문항의 복제·배포 허락이 아니다.
# 정식 제품 전체가 데모로 읽히는 문구를 금지하고, Debug에 실제
# KICE 인덱스가 들어온 경우에만 소유권·배포 제한을 표시한다.
if grep -Fq '본 데모는 학습 연구 목적으로만 사용합니다.' "$profile"; then
  echo 'FAIL: 정식 제품을 데모로 오인하게 하는 KICE 고지가 남아 있습니다.' >&2
  exit 1
fi
if grep -Fq '데모 빌드에 한해 수록' "$assessment"; then
  echo 'FAIL: 내부 KICE 자료를 배포 허락된 데모로 오인하게 하는 고지가 남아 있습니다.' >&2
  exit 1
fi
grep -Fq 'if !KiceBank.exams.isEmpty {' "$profile"
grep -Fq '사용 허락을 확인하지 않은 기출 원문은 정식 배포 빌드에 포함하지 않습니다.' "$profile"
# 기출 원문은 Debug 리소스·기존 응시 route로만 남고, 평가센터의 긴 연도별
# 아카이브 목록에서는 노출하지 않는다.
if perl -0ne 'exit 0 if /var body:[\s\S]*?if !KiceBank\.exams\.isEmpty \{/; exit 1' "$assessment"; then
  echo 'FAIL: 평가센터 본문에 KICE 기출 아카이브 목록이 다시 노출되었습니다.' >&2
  exit 1
fi
grep -Fq '사용 허락 확인 전 내부 검증 빌드에만 포함됩니다.' "$assessment"

# 정식 바이너리에 도달 불가능한 플레이스홀더·남의 채점표가 문자열로 남지 않는다.
[ ! -e "$root/Matths/SampleData.swift" ]
if ! perl -0ne 'exit 0 if /#if DEBUG\s*\/\/\/ 내부 UI 회귀용[\s\S]*?enum SheetAnalysisDemo[\s\S]*?#endif/; exit 1' "$sheet_analysis"; then
  echo 'FAIL: 채점 골든 예시는 DEBUG 밖에서 컴파일되면 안 됩니다.' >&2
  exit 1
fi

echo 'platform permission, privacy manifest, and Debug-only KICE resource contracts passed'
