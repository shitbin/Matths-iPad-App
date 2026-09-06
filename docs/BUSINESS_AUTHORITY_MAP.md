# 비즈니스 정본과 네이티브 화면 경계

검수 수정 기준: iOS 원본 2cee63b / 전달 저장소 726762f. Web 읽기 기준: e3cc06360415a4c60460895b01f06a3248dae665.

| 영역 | 정본 | iOS 처리 |
|---|---|---|
| 과목 공개 | GET /api/v1/curriculum, developmentLocked | 엄격한 응답 검증, 환경별 검증 캐시, 공통 availability. 콘텐츠 보유와 공개 권한 분리. |
| 공식 진도·이어학습 | GET /api/v1/learning | 서버 projection을 사용. 정책 변경 중에는 같은 웹 함수의 순서·반올림·공통/활동 과목 범위를 적용. |
| 학습 원본·초안 | 계정별 로컬 저장 + 서버 수신 결과 | 미전송 초안 보존. 423/잠긴 과목 write는 재생 없는 격리. 쓰기 성공 후 공식 projection 재조회. |
| 공식 평가 | 기존 start/draft/submit/expire API | 토큰 없는 로컬 시작/채점 금지. 재로그인 intent, 원래 서버 회차·답안 보존. |
| 비공식 연습 | PracticeAssessmentRecord | 별도 ID·파일. 합격/해금 필드 없음. 공식 통계·서버 오답·진도 변경 없음. |
| 학원 출석 | academy/student의 canCheckIn | 출석 확인 후보 표시만 수행. 출석 시간·지각·마감 판정은 재계산하지 않음. |
| Today | 위 정본이 확인한 후보 | 진행 중 평가 → 출석 확인 → 복습 → 공식 이어학습 → 탐색 순서. 위젯도 같은 resolver 사용. |
| Arena | 기존 서버 경기·경제·정산 | 규칙·금액·MMR·판정 변경 없음. 배치 공통화와 세션 브리지 유지. |
| 구매 | Apple 검증 거래 + 서버 granted | 중복 거래 단일 처리, 확인 중/복구 상태, 서버 확인 뒤 finish·활성화. 가격은 displayPrice. |
| 계정 비밀번호 | 기존 이메일 reset API | 프로필 진입, 영문/숫자·길이·확인 검증, 완료 후 비밀값·세션 폐기. |
| 공식 시험 달력 | 해당 서버 계약 필요 | 국가 시험일을 추정하지 않음. 주간 모의/아레나 기존 일정 ingestion 유지. |

Web main/API/DB는 읽기 전용으로 대조했다. refresh-token API가 없는 상태에서 새 갱신 프로토콜을 만들지 않았으며 기존 Bearer 만료·재로그인 계약과 계정 generation 검사를 강화했다.
