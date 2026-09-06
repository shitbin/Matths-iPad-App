# 2026-09-06 검수 재판정

## 기준선

- 수정 저장소: `shitbin/Matths-iPad-App`, 기존 `main`.
- 저장소 HEAD: `726762f7b13614932ccaac866752b5538ed0bba2`.
- 앱 소스 원본: `2cee63b217f6bdeaa51bdd5a2a8751a48b1f1f38`. 전달 저장소는 이 소스와 전체 자산을 가져오고 README 두 개만 갱신한 초기 커밋이다.
- 웹 원본: `/tmp/matths-server-parity-final`, HEAD `e3cc06360415a4c60460895b01f06a3248dae665`, clean. 원격 `is4553807/Matths-Official`. 이 작업에서 읽기만 한다.
- 검수 v2 ZIP SHA-256: `86ffcabc843d79d483110ce3402cd05cfcf698a79bf112e553612994a1904e1a`, 압축 무결성 및 첨부 체크섬 일치.
- Xcode: Matths 스킴, Matths/MatthsWidget 타깃, Debug/Release 구성, iOS 17+, iPhone+iPad. 프로젝트 버전 1.0 (16)은 소스 설정이며 현재 TestFlight 바이너리와의 동일성을 독립적으로 증명하지 않는다.
- 기존 122개 계약 검사 실행. 초기 실패 7개 중 1개는 MATTHS_WEB_REPO 미설정, 3개는 읽기 전용 ZIP 파일의 변조 테스트 쓰기 권한 문제. 환경 보정 뒤 남는 3개를 아래에 분류한다. 실거래·실기 검증은 별도 증거다.

## 협조문 항목별 재판정

| 요구 | 판정 | 실제 근거·사용자 영향 | 수정·검증·롤백 |
|---|---|---|---|
| PARITY-CURR-001 | CONFIRMED_ON_2CEE | CurriculumV2.swift의 CourseV2/overallScoped/continueConcept에 공개 정책이 없고, 지도·프로필·위젯이 13과목 전체를 소비한다. 웹 curriculumService.js는 developmentLocked를 생성하고 집계·이어학습에서 제외한다. | 단일 정책 저장소, 검증 캐시, 소비처·라우트·큐 공통 가드. 5/8·손상·423·환경·순서 테스트. 원본 기록 보존. |
| PARITY-NEXT-001 | CONFIRMED_ON_2CEE | 웹 buildLearningViewModel은 서버 percent와 Math.round를 사용하나 앱은 로컬 게이트 재계산 및 정수 나눗셈을 사용한다. 같은 계정의 숫자가 달라질 수 있다. | 기존 GET /api/v1/learning의 서버 projection을 사용. 서버 순서·next·percent 보존. 캐시를 계정별로 분리. |
| PARITY-ASMT-001 | CONFIRMED_ON_2CEE | AppStore.startPaper에서 tokenless startLocalPaper 호출. PaperFactory 마지막 문항 수 검증 누락. | 공식 시작은 서버 인증, 연습은 별도 저장소·namespace. 10/20/40 부족 시 실패. |
| ASMT-TOKEN-EXPIRY (추가) | CONFIRMED_ON_2CEE | submitPaper가 serverBacked && hasToken으로 분기하므로 서버 회차도 토큰 소실 시 로컬 채점한다. | 서버 회차는 토큰과 무관하게 로컬 채점을 금지하고 재로그인·복구 경로로 전환. 답안 보존 테스트. |
| PARITY-IAP-001 | RUNTIME_EVIDENCE_REQUIRED | 두 product ID와 서버 redeem 경로 존재. 실제 Sandbox JWS, 갱신·환불·계정 교차 재사용 증거는 첨부에 없다. | 구매/확인중/복구 전이 검토, 실거래는 별도 PASS/NOT_RUN 판정. |
| PARITY-AUTH-001 | CONFIRMED_ON_2CEE | 프로필 변경 진입 없음. PasswordResetSheet는 확인 입력·UTF-8 72바이트 검사·완료 후 세션 폐기 없음. | 기존 request/verify/complete 재사용, 민감값 소거 및 세션 종료. 입력 경계·오래된 응답 테스트. |
| PARITY-ASSET-001 | CONFIRMED_ON_2CEE | 웹 examBankSource와 앱 exam-bank.js 불일치. 원본 생성 스크립트 부재. 정확한 웹 커밋은 접근 가능. | 읽기 전용 exact-source 생성기, 입력/출력 hash, 두 번 생성 비교, CI. 생성 산출물 단위 롤백. |
| PARITY-WIDGET-001 | CONFIRMED_ON_2CEE | applyServerExamSchedule은 운영 수신부 없음. 웹 routes/controllers/services에 공식 시험 일정 계약 없음. | SERVER_DEPENDENCY 기록, 빈 상태 유지. 임의 endpoint·날짜 생성 금지. |
| PARITY-TEST-001/landscape | STALE_OR_RENAMED | showsArenaWebMenu 이름 고정 검사가 현재 showsArenaMoreMenu와 불일치. | 실제 presentation과 콘텐츠 연결 검사, rename 내성·삭제 mutation 테스트. |
| PARITY-TEST-001/brand | STALE_OR_RENAMED | API path의 division interpolation을 UI 영어로 오인. | 사용자 표시 표현 검사, URL 허용/실제 표시 위반 거절 테스트. |
| PARITY-TEST-001/public route | STALE_OR_RENAMED | 같은 내부 브리지의 문구 변경으로 실패. | destination·세션 handoff·외부 이탈 검사, 카피 독립. |

## 기존 정적 감사의 재판정 원칙

IA-001/002, ONB-001, ROLE-001: 현 셸의 6개 학생 탭·전역 프로필/AI 버튼·역할 혼합 확인. 새 5목적지 셸과 명시적 작업공간, 단일 오늘 행동, 비공식 체험을 적용한다.

LAY-001/003, A11Y-002: 기존 UniversalLayoutPolicy와 여러 시험별 2분할 존재. 컨테이너·큰 글자 정책을 공통 작업대로 수렴하고 일반 탐색 중 탭 숨김을 제거한다. 실제 VoiceOver/Pencil/Stage Manager 조작은 정적 존재로 PASS 처리하지 않는다.

ARC-001/002/003, STATE-001, DS-001/002: 변경하는 기능의 상태·네트워크 소유권·디자인 토큰을 먼저 정리한다. 파일 길이·Boolean 개수·고정 치수만으로 모든 후보를 확정 버그로 취급하지 않는다.

AI-001, PAY-001, SEC-001/002/003, ARC-004, CODE-001/002, A11Y-001, LAY-002: 기존 guard·actor·취소·TLS·메모리/다운로드 계약을 읽고 구체적 결함을 패치한다. 정규식 후보와 실제 데이터 흐름을 구분한다. 런타임·성능·실거래가 필요한 항목은 증거 없이 완료 처리하지 않는다.

## 첫 수직 변경과 보존 계약

availability + 서버 learning projection부터 적용한다. 공개 정책은 인증된 기존 API에서 읽고, 검증된 캐시→5과목 안전 기준 순으로 대체한다. 423은 즉시 차단하며 해당 기록은 삭제하지 않는다. 이후 공식/연습 평가·계정 보안·자산·탐색 흐름을 연결한다.

웹 API, Arena 점수/경제/정산, StoreKit product ID·거래 귀속, 공식 평가 서버 채점은 유지한다. 새 브랜치 없이 기존 main에서 작업하며 구현·검증을 묶어 한 번 푸시한다. 문서가 제안한 다중 PR/단계별 커밋은 사용자의 일괄 푸시 지시에 맞춰 적용하지 않는다.
