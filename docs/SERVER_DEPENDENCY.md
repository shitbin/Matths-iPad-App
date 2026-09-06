# 서버 계약 의존성

웹 기준 `e3cc06360415a4c60460895b01f06a3248dae665`의 routes/controllers/services를 읽기 전용으로 확인했다.

## 공식 시험 일정

상태: BLOCKED_SERVER_CONTRACT_REQUIRED. 공개 교육청/평가원/수능 시험 일정의 endpoint 및 schema가 없다. 기존 WidgetBridge.applyServerExamSchedule 수신부에 임의 URL을 연결하지 않는다. 데이터가 없으면 `시험 일정 준비 중`을 유지한다.

필요한 계약: 공개/인증 여부, 일정 ID·이름·KST dayKey 또는 절대시각·source·version·갱신시각·유효기간, 비어 있음과 삭제의 의미. 실제 응답 fixture 제공 뒤 앱과 위젯의 동일 날짜를 검증한다.

## 실제 StoreKit 검증

상태: NOT_RUN. Sandbox Apple 계정, 테스트 Matths 계정 두 개, 서명된 기기 앱, 서버의 거래·갱신·환불 처리 결과가 필요하다. 로컬 StoreKit 구성과 코드 검사로 실거래 통과를 대신하지 않는다. JWS·인증 토큰 원문은 저장소에 넣지 않는다.

## 온보딩의 기기 간 중간 단계

기존 서버는 dashboard tutorial의 START/COMPLETE/SKIP 상태를 제공한다. 목표·샘플 답·세부 중간 단계는 이번 앱의 계정별 demo namespace에 보관한다. 완료/건너뛰기는 기존 API로 서버에 반영하지만, 기기 간 미완료 세부 단계의 동일 복원은 현재 API로 지원하지 못한다. 관련 DTO/저장 계약이 필요하다.

## 비밀번호 경계 대조

passwordResetService.js의 실제 reset 검증은 영문·숫자와 JS UTF-16 길이 8 이상을 요구한다. 이를 iOS에 반영했고, 요청서의 UTF-8 72바이트 상한도 적용했다. 해당 reset 서비스 자체에는 72바이트 검사가 없어 서버 팀의 동일 상한 검증이 필요하다. 이번 작업에서 서버 코드는 수정하지 않았다.

국가 시험 달력과 학원의 개인 수업 출석은 다르다. 기존 academy/student의 canCheckIn은 Today 후보로 연결했으며, 주간 모의와 Arena의 기존 일정 ingestion도 유지했다.
