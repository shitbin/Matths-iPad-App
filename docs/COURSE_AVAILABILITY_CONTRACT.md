# 공개 과목·진도 계약

`CurriculumAvailabilityResponse`는 실제 서버의 curriculum → schemaVersion/curriculum/courses envelope를 읽는다. course ID와 developmentLocked Boolean은 필수이며 문자열 Boolean, 중복·빈 ID, 잘못된 schema는 거절한다.

`CurriculumAvailabilityStore`가 네트워크·캐시·single-flight·423 반영을 소유한다. `CurriculumPolicy`는 불변 snapshot을 동기 소비처와 공유한다. UI별 5과목 상수는 없다. 우선순위는 검증된 live → 같은 환경의 검증 cache → 공개 5과목 baseline이다. 요청 중 들어온 423은 이전 요청 identity를 폐기한다. HTTP 캐시로 공식 상태를 되돌리지 않으며 재조회 간격은 시스템 시계 변경에 영향받지 않는 uptime을 쓴다.

준비 중인 8과목은 제목을 보존하고 진입을 비활성화한다. 직접 개념 진입, 개념 mutation, 집계, 취약 개념, 프로필, Today, 위젯과 sync journal에 같은 필터를 적용한다. 새 공개 과목이 번들에 없다면 학습 허브에 업데이트 안내를 제공한다.

기존 잠긴 과목의 로컬 기록은 삭제하지 않는다. 해당 write는 `heldCourseLocked`로 기록하고 status 423의 기존 내구 격리 journal에 보관한다. 과목 공개 후 자동 재생하지 않는다. 서버 snapshot과 비교한 수동 재처리가 필요하다.

공식 진도는 서버 `GET /learning`의 총량과 다음 대상을 우선한다. Web buildLearningViewModel의 Math.round, 공통+활동 선택과목 스코핑, 진행 중→공통→기타 순서를 6개 동일 fixture로 교차 검증한다. 개인 cache는 환경과 계정 슬롯별로 분리한다. 초기화 시 canonical cache도 지우고 reset epoch로 늦은 조회가 옛 기록을 되살리지 않게 한다.

실제 동일 계정의 운영 웹/앱 화면 대조는 별도 실행 증거가 필요하다. synthetic fixture 통과와 구분한다.
