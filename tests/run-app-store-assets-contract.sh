#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

node "$ROOT/scripts/verifyAppStoreAssets.js"

grep -q 'screenshots-iphone-6.9-landscape' "$ROOT/appstore/README.md"
grep -q 'App Store Connect의 로그인 정보 칸에만 입력' "$ROOT/appstore/review-notes-ko.md"
grep -q '비밀번호나 세션 토큰을 이 파일 또는 Git 기록에 넣지 않습니다' "$ROOT/appstore/review-notes-ko.md"
grep -q '사용자 ID' "$ROOT/appstore/app-privacy-ko.md"
grep -q '구입 내역' "$ROOT/appstore/app-privacy-ko.md"
grep -q '게임 플레이 콘텐츠' "$ROOT/appstore/app-privacy-ko.md"
grep -q 'Matths 서버로 전송하지 않는다' "$ROOT/appstore/app-privacy-ko.md"
grep -q '^# App Store Connect 손쉬운 사용 응답 — build 16$' "$ROOT/appstore/accessibility-ko.md"
for feature in 'VoiceOver' '더 큰 텍스트' '다크 모드 인터페이스' \
               '색상 사용 없이 구별' '충분한 대비' '동작 줄이기'; do
  grep -q "| $feature | 지원 |" "$ROOT/appstore/accessibility-ko.md"
done
grep -q '^| 음성 명령 | 표준' "$ROOT/appstore/accessibility-ko.md"
grep -q '^| 자막 | 개념' "$ROOT/appstore/accessibility-ko.md"
grep -q '^| 오디오 설명 | 시각' "$ROOT/appstore/accessibility-ko.md"
[ "$(grep -c 'CURRENT_PROJECT_VERSION = 16;' "$ROOT/Matths.xcodeproj/project.pbxproj")" -eq 4 ]
grep -q '^# App Review 메모 — build 16$' "$ROOT/appstore/review-notes-ko.md"
grep -q '^# App Store Connect 개인정보 응답 — build 16$' "$ROOT/appstore/app-privacy-ko.md"
grep -q '^# App Store Connect 입력 기준 — build 16$' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '6803570339' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '6803570684' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '₩29,000' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '₩5,500' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '개인정보처리방침 URL만 저장됐다' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '개인정보 설문의 마지막 저장과 게시' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '| 앱 가격 | 무료 다운로드' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '| Apple Silicon Mac |.*사용 가능 해제' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '계산 등급은 `13+`' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '시합: 빈번' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q '| 앱 이름 | `맵쓰`' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q 'ASC와 로컬 정본 일치' "$ROOT/appstore/app-store-connect-inputs-ko.md"
grep -q 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/' "$ROOT/appstore/metadata/ko-KR.json"
for safety in '게시글 신고' '댓글 작성자를' '차단 관리' '익명 이름'; do
  grep -q "$safety" "$ROOT/appstore/review-notes-ko.md"
done
grep -q '다음 제출 후보는 build 16' "$ROOT/appstore/RELEASE_READINESS.md"

echo "app-store-assets-contract: PASS"
