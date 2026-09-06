# 2026-09-07 검수 개선본 판정

대상은 **Matths 1.0 (17)**. 이번 수정본은 아직 TestFlight/App Store에 업로드하지 않았다. 아래 코드·시뮬레이터 통과를 출시 완료나 심사 통과 보장으로 해석하지 않는다.

| 구분 | 상태 | 근거 |
|---|---|---|
| 원본 finding 재판정 | PASS | PARITY_FINDING_ADJUDICATION.md. 실제 iOS 소스와 exact Web e3cc063 대조. |
| 공개 5과목/잠금 8과목 | PASS (코드·fixture·부분 UI) | 단일 provider, strict schema, cache/423, route·집계·write 가드. |
| 공식 진도·이어학습 | PASS (교차 fixture) | 서버 projection 및 Web 원본 함수가 만든 6개 입력/결과 비교. 실제 동일 계정 E2E는 NOT_RUN. |
| 공식 평가/로컬 연습 분리 | PASS (코드·테스트) | tokenless local fallback 제거, 기존 로컬 기록 보존·분리, 계정 자격 고정, 별도 연습 저장소. |
| 오프라인 문항 수 | PASS | 계획 수 강제, 실제 시뮬레이터 51개 생성/실패 경계 통과. |
| 프로필 비밀번호 변경 | PASS (코드·입력 경계) | 기존 이메일 API, 영문/숫자·UTF-16 길이·UTF-8 상한·확인, 완료 후 세션 폐기. 실제 이메일 E2E는 NOT_RUN. |
| 웹 파생 자산 | PASS | exact commit 생성, native overlay 분리, 입력/출력 hash, 두 번 생성 일치, 생성 자산 drift 검사. |
| 학생 셸·온보딩·작업공간 | PASS (구현·부분 UI) | UX_CHANGES_0907.md, UI flag rollback, demo/official 분리. 기기 간 미완료 단계 API는 BLOCKED. |
| 문제·메모 작업대 | PASS (구현·부분 UI) | 공통 배치, 평가별 저장/복원·회전, AX 단일 흐름. 실제 Pencil 제스처는 NOT_RUN. |
| 계약 검사 | PASS | 최종 전체 실행 126/126 통과. 서버 진도/완료 조건 override 독립 검사 포함. 기계 판독 결과는 PARITY_TEST_RESULTS.json과 CI에서 확인. |
| Debug iphoneos/시뮬레이터 | PASS | Xcode 26.6 컴파일·링크·앱 번들 생성. |
| Release iphoneos | PASS | clean Git 상태에서 Xcode 26.6 Release/iphoneos 컴파일·링크·번들·위젯·llama 임베드 통과. CODE_SIGNING_ALLOWED=NO이며 배포 서명/업로드 검증은 아님. |
| 실제 StoreKit Sandbox | NOT_RUN | STOREKIT_SANDBOX_EVIDENCE.md. 신규 구매·귀속·갱신·만료·환불·복원 필요. |
| 공식 국가 시험 일정 | BLOCKED | 기존 서버 endpoint/schema 없음. 날짜나 endpoint를 추정하지 않음. |
| 실기기 전체 행렬·성능 | NOT_RUN | DEVICE_STATE_MATRIX.md의 범위를 초과한 통과 주장은 하지 않음. |

## 변경 보존

웹·서버는 읽기 전용이었다. Arena 경기 규칙·금액·MMR·정산, StoreKit product ID·서버 granted 권한, 기존 학원·관리자 API 의미를 변경하지 않았다. Build 16 제출 자료는 역사적 자료로 유지했다.

## 롤백

화면 구조만 되돌릴 때는 `matths.productFlow.v2.enabled=false` 후 재실행한다. 서버 정합성·평가 경계 수정은 계속 적용된다. 전체 코드 롤백은 이 변경 커밋을 기준으로 판단한다. 새로운 progress 필드는 optional Codable이고 legacy practice 원본을 보존하므로 이전 데이터를 삭제하는 migration은 없다. 잠금 격리 기록은 과목 공개만으로 자동 replay하지 않는다.

## 남은 출시 조건

실제 Sandbox 거래와 두 Matths 계정의 소유권 검증, 같은 운영 계정의 Web/iOS 진도 대조, 실제 기기 입력·접근성·회전·성능, 새 제출 스크린샷·App Store Connect 메타데이터 확인이 필요하다. 상세 요구는 SERVER_DEPENDENCY.md와 개별 증거 파일에 기록했다.
