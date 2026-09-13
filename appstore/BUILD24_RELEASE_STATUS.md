# Build 24 release status — 2026-09-14

이 문서는 코드·빌드·서버·StoreKit·TestFlight·App Store 심사를 서로 구분한다.
`PASS`는 적힌 층에서만 유효하며, 실제 거래나 심사 승인을 뜻하지 않는다.

## 이번 빌드의 사용자 영향

- 네이티브 App Store 구매 버튼을 웹 KG이니시스 활성화 설정과 분리했다.
- 앱은 App Store가 내려준 지역화 가격만 구매 버튼에 표시한다.
- Apple 거래는 기존처럼 계정 토큰을 먼저 귀속하고, 서버 권한 부여 뒤에만 finish한다.
- 실제 Today가 공통 과업 우선순위 정책을 사용하며 오늘 학습·복습·추가 과업을 함께 보여준다.
- 받은 Arena 공격은 최근 20경기 안에서만 찾지 않고 서버 역할 필터와 cursor를 사용한다.
- 구버전 서버가 필터를 무시하는 동안에도 모든 페이지를 끝까지 확인한 뒤 빈 상태를 표시한다.
- iPhone/iPad 가로 퀵 연습에서 답 입력 포커스가 풀이 메모를 제거하지 않는다.
- 다크 주 버튼 전경은 CI Navy를 사용해 계산 대비를 3.09:1에서 6.16:1로 높였다.
- Me 허브가 현재 계정의 프로필 사진 또는 프리셋 아바타를 표시한다.
- Arena 최근 결과는 로딩·빈 상태·이전 기록·조회 실패를 구분한다.
- 관리자 자료실은 일괄 휴지통 이동 전 대상 수와 일부 이름을 확인하고, 넓은 iPad에서 폭 기반 분할을 사용한다.

## 서버

- GitHub `main`: `bdfe793` — 네이티브 Apple checkout 분리, 받은 공격 역할/상태 필터.
- Apple account-token/redeem/notification, 소유권, 갱신·환불 통지, 앱 storefront 및 Arena 읽기 계약: PASS.
- 운영 도메인의 health, storefront 인증 경계, account-token/redeem 인증 경계, notification V2 입력 경계: 응답 확인.
- Cloudtype가 `bdfe793`을 실행 중인지 확인할 런타임 SHA 표면은 없음. Git push와 운영 배포를 같은 완료로 기록하지 않는다.

## 앱 정적·빌드 검증

- 프로젝트 버전: `1.0.1 (24)`.
- iPhone/iPad 대상 Debug device SDK 전체 컴파일: PASS.
- StoreKit 상품 ID·가격·App Apple ID 계약: PASS.
- GPT-6 피드백 P1 및 고위험 P2 회귀 계약: PASS.
- 앱 전체 `tests/run-*.sh`는 외부 Web exact-commit 검사를 제외한 실행 결과와 해당 exact-commit 별도 실행 결과를 함께 기록한다.
- App Store 배포 프로필 두 개와 Apple Distribution 인증서의 만료·bundle ID를 확인했다.
- App Store 배포 archive 검증과 IPA export를 완료했다. IPA SHA-256은
  `5ecec470633b5a231bdefc5b6f9234130fe02973babb67567544a85a4a4f85ff`다.
- Xcode가 Build 24 업로드를 완료했고 App Store Connect/TestFlight의 업로드 상태는
  `완료`, 빌드 상태는 `제출 준비 완료`다. 내부 그룹 `Test v1`의 테스터 3명에게
  제공 가능한 상태다.
- Build 24 소스로 iPhone 6.9인치 가로 7장과 iPad 13인치 가로 7장을 다시 캡처했다.
  자산 검사는 `APPSTORE-ASSET PASS: 14 screenshots`로 통과했다.
- 자동 갱신 구독 두 개의 대한민국 가격은 29일 학습권 `29,000원`, 주간 공식
  모의고사 `5,500원`으로 확인했다. 두 상품 모두 175개 국가·지역 판매 설정,
  한국어 현지화, 심사 스크린샷과 심사 메모가 있다.
- 유료 앱 계약, 대한민국·미국 세금 양식, 은행 계좌와 대한민국 전자상거래법 상태는
  App Store Connect에서 모두 `활성화됨`으로 확인했다.

## 아직 실제로 닫아야 하는 출시 게이트

- App Store 버전 1.0.1에 Build 24를 선택하고, 두 자동 갱신 구독을 이번 심사에 추가.
- Apple Sandbox에서 신규 구매, 취소, pending, 복원, 재로그인 후 권한, 다른 Matths 계정 귀속 거절 확인.
- 운영 서버 storefront가 `appleCheckoutEnabled=true`를 내려주는지 실제 로그인 계정으로 확인.
- Cloudtype 운영 서비스가 서버 `bdfe79363f8769cecefc1fdb9727bba32fb3dad3`을
  실제 실행하도록 최신 `main` 재배포 후 release ID와 health/readiness 결과 확인.
- App Store Connect의 새 버전은 심사 계정 비밀번호가 비어 있다. 유효한 전용 심사
  계정 비밀번호를 다시 입력하고, 연락처·업데이트 문안·새 스크린샷을 저장한 뒤 제출.

이 항목을 확인하지 않은 상태에서는 “오늘 사용자 결제 가능”이나 “심사 제출 완료”라고 보고하지 않는다.
