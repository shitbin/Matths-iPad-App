# App Store 최종 외부 상태

아래는 코드·바이너리·스크린샷 자동검사로 끝낼 수 없는 항목만 기록한다.

## 현재 확인된 상태

- 2026-09-01 제품 소스 `e3e86a5`(tree
  `cb898398c5a928453c85165ed19f40efba8ea0e8`)에서 build 14를 새로 Archive하고,
  Apple Distribution 인증서와 명시적 App Store 프로비저닝 프로파일로 앱·Widget을
  재서명해 IPA를 만들었다. 앱·Widget 모두 `get-task-allow=false`, 올바른 App Group,
  앱의 Sign in with Apple·Automatic Assessment Configuration entitlement, arm64,
  Privacy manifest, dSYM UUID와 clean git provenance 검사를 통과했다. 제출 IPA는
  `work/archives/Matths-1.0-14-e3e86a5-AppStore.ipa`이고 SHA-256은
  `abb18e7a895b619496e4a616d9ef377f270228bca279409aeede9d75ea717944`다.
- 같은 IPA를 2026-09-01 09:23 KST에 Transporter로 업로드했다. App Store Connect의
  build upload `ba403a14-6a3e-43ea-b4dc-221cff7a975a`는 `완료`, TestFlight build 14는
  `제출 준비 완료`, 바이너리 상태는 `검증됨`이다. App Store Connect가 표시한
  비면제 암호화는 `아니요`, 기호 포함은 `예`, 대상 기기는 iPhone·iPad이며 업로드
  경고나 오류는 없다.
- App Store Connect 버전 1.0에는 iPhone 6.9인치와 iPad 13인치 가로 스크린샷 각
  7장, 설명·키워드·지원 URL·마케팅 URL·저작권이 저장돼 있다. build 15는 2026-09-01
  처리 완료 후 버전 1.0에 첨부했고, 실제 기능 기준 연령 등급 `13+`, 심사 계정·연락처,
  콘텐츠 권한, 개인정보·접근성 공개, 무료 앱 가격·판매 지역, 두 구독의 가격·지역·심사
  정보를 저장한 뒤 심사에 제출했다. 제출 ID는
  `7abdd8b7-fc87-4ca8-9b43-d2732695907c`이며 제출 시각은 2026-09-01 15:28 KST다.
- 2026-09-01 서버 Apple 웹 로그인 요청 제한, 결제 계정 귀속·알림 복구, PKCE와
  커뮤니티 게시 전 유해 콘텐츠 필터·신고·익명 보호 사용자 차단을 포함한 소스
  `915f6187`을 운영 저장소 `is4553807/Matths-Official`의 `main`에 fast-forward로
  반영했다. `launch:verify` 67개와 커뮤니티 안전·계정 탈퇴 격리 메모리 MongoDB,
  운영 공개 계약 스모크는 통과했다. 이후 Cloudtype 자동 배포가 반영돼 운영
  `/api/v1/auth/providers`의 Apple은 `configured=true`, `revocable=true`,
  `webConfigured=true`이고 콜백은 `https://www.matths.kr/auth/apple/callback`이다.
  `/auth/apple`은 Service ID `kr.matths.web`으로 Apple 인증 화면에 302 응답하며,
  2026-09-01 운영 검증의 상태·보안 헤더·Google/Kakao/Apple 인증·결제 경계·법률 문서
  연락처 검사가 1회차에 모두 통과했다.
- 후속 서버 소스 `312eb262`에서 첫 Apple 로그인 때 이메일이 전달되지 않아 생성된
  사용자별 `@appleid.invalid` 임시 주소를, 이후 검증된 Apple ID 토큰에 실제 이메일
  또는 Private Relay 주소가 포함되면 자동 복구하도록 했다. 다른 Matths 계정이나 활성
  보호자 계정과 이메일이 충돌하면 덮어쓰지 않고 계정 충돌로 거부하며, 일반 이메일은
  변경하지 않는다. Apple 인증 집중 검증을 통과했고 운영 저장소 `main`에 반영했다.
  Cloudtype 자동 배포 뒤 운영 검증 13개가 1회차에 모두 통과했다.
- 이상윤의 후속 `df1422d7` Apple 웹 가입 완성 흐름과 `12d85441` 한국어 전용 UI 변경을
  검토한 뒤, 작은 iPhone 가로 화면에서 커뮤니티의 큰 소개 영역을 압축해 게시판 내용이
  첫 화면에 더 빨리 보이게 한 `efa988e9`까지 운영 저장소 `main`에 반영했다. 최신 소스의
  한국어 전용·해외학교·Apple 웹/네이티브 로그인·UI·결제·보안·정책 검증을 포함한
  `launch:verify` 68개가 전부 통과했다. 로컬 Documents/iCloud의 의존성 파일 읽기
  시간 초과를 배제하기 위해 운영 `main`을 `/private/tmp`에 새로 clone하고 `npm ci`한
  환경에서도 탈퇴·환불·가격 권한·문의·iPad 알림·Arena 명령·페이백·관리자 사용자·
  커뮤니티 차단·스케줄러 임대까지 격리 MongoDB 감사 13개를 전부 통과했다. 다만 GitHub 수동 배포 워크플로에는
  `CLOUDTYPE_API_KEY`, `CLOUDTYPE_PROJECT`, `CLOUDTYPE_STAGE`가 비어 있어 실행
  `33463108341`이 배포 요청 전에 중단됐다. 운영은 기존 정상 버전을 유지하고 있으며,
  Cloudtype 자격 증명 또는 콘솔 로그인이 제공되기 전까지 `efa988e9` 운영 반영은 미완료다.
- Apple Developer의 Sign in with Apple for Email Communication에 발신원
  `lsbproduction00@gmail.com`을 등록했으며 Apple 화면에서 유형 `Email address`, 상태
  `SPF`를 확인했다. Apple Private Relay 주소로 보내는 현재 SMTP 발신 경로가 등록됐다.
- 운영 API에서 App Review 전용 이메일 계정을 생성하고 실제 로그인, 프로필, 커리큘럼,
  학습 진도, 오답노트, 배치고사, GOAT Arena, StoreKit 상품, 평가센터 응답을 확인했다.
  공통수학1 학습 진도 3개와 복습 예정 오답 3개를 넣었고 build 14 Debug 시뮬레이터의
  iPhone 17 Pro Max 가로 화면에서 홈, 오답노트와 문제·풀이 메모·답 입력·제출이 한
  화면에 보이는 퀵 연습까지 같은 운영 계정으로 로그인해 확인했다. 자격 증명은 저장소에
  넣지 않고 App Store Connect의 로그인 정보 칸에만 입력한다.
- 후속 제품 소스 `46a3177`에서 게시판과 Arena의 서버 WKWebView도 시스템 Dynamic Type을
  따라 AX5에서 2.1배 문서 배율을 적용하고, 최대 4배 확대·확대 후 이동과 기존 당겨
  새로고침을 함께 유지하도록 수정했다. 852×393 WebKit 창에서 2.1배 확대·반응형
  재배치를 확인했고 전체 Swift 소스를 경고 오류화해 타입체크했으며 97개 계약 테스트가
  전부 통과했다. 이 변경과 문서 커밋 `e3e86a5`를 포함한 새 build 14 Archive·업로드까지
  완료했으므로 과거 `8c38733` Archive는 제출 후보가 아니다.
- App Store Connect에는 한국어 부제, 교육 카테고리, 개인정보처리방침 URL과 최종
  가로 스크린샷 14장이 저장됐다. 개인정보와 접근성은 과거 선택 과정만 진행됐고 현재
  실제 계정에는 모두 `시작하기` 상태라 다시 입력하고 게시해야 한다. 콘텐츠 권한·7단계
  연령 등급, 앱 무료 가격·판매 지역, 두 구독의 가격·지역·심사 이미지와 메모, build 14
  첨부와 심사 계정·연락처는 여전히 필수다.

- 과거 build 9·10 업로드 뒤 가로 UI·튜토리얼·결제 복원·개인정보 공개와 권한 구성이 변경됨
- 다음 제출 후보는 build 16이며, build 15는 2026-09-01 제출본이다. build 16은 최초
  로그인 학습 목표 선택, 간소화된 정착 흐름, 역할별 학원·관리자 기능과 자료실·스토어·
  고객지원 포털, iPhone 가로 전용 한 화면 배치를 포함한다. build 14는 이후 발견된
  레거시 오답 수식 렌더링
  결함 때문에 제출에서 제외한다. build 12는 이후 발견된 대형 iPhone 가로
  Arena 레이아웃 분기, 퀵 연습 풀이 메모 공간, 배치고사 보기·이동 노출,
  31단계 튜토리얼, 데모 전송 상태의 동시성 크래시 및 릴리스 검사의 오탐 방지를
  포함하지 않아 심사 제출에 사용하지 않음
- 소스 커밋 `485ce16`의 build 12는 iPhone 가로 시뮬레이터 실기 검사, 전체 96개
  계약 테스트, Release 시뮬레이터·arm64 기기용 빌드와 정적 분석을 경고 0건으로 통과함
- build 12를 Archive한 뒤 Cloud Managed Apple Distribution으로 앱·위젯을 재서명했고,
  두 바이너리 모두 `get-task-allow=false`와 App Group을 확인함
- build 12 앱 배포 서명에 Sign in with Apple과 Automatic Assessment Configuration이
  모두 포함됐고, 앱·위젯의 Store 프로비저닝 프로파일은 2027-08-22까지 유효함
- 2026-08-31 09:22 KST에 build 10 업로드 성공. Apple build upload
  `c37fb7f0-7244-45d4-b12f-5b18e1778661`은 build 11로 대체함
- 2026-08-31 10:51 KST에 build 11 업로드 성공. Apple build upload
  `459be95b-85f3-4e70-afb8-f6adaaa35346`은 build 12로 대체함
- 2026-08-31 12:09 KST에 build 12 업로드 성공. Apple build upload
  `9d2deec5-aee2-4724-95d2-9ea0fbf3d9d6`은 build 14로 대체 예정
- build 12는 작은 iPhone 가로에서도 문제·풀이 메모·답안·제출을 한 화면에 유지하고,
  결제 첫 상품과 상태를 처음부터 보이며, 이메일·Google·Apple·카카오 계정 탈퇴를
  앱 안에서 완료하도록 수정함. 실제 가로 풀이 화면에서 전체 헤더와 여섯 탭 이름을
  함께 표시하고, 수식 문제를 VoiceOver가 읽는 것까지 확인함
- 데모 모드의 대시보드 재시작·완료·건너뛰기와 GOAT Arena 6개 챕터 상태/API를
  실제 앱 흐름에 연결했고, iPhone 가로에서 대시보드 31단계 및 Arena 튜토리얼 오버레이가
  열리고 닫히는 것을 실제 시뮬레이터 접근성 트리와 화면으로 확인함
- 탈퇴 서버 소스 `c04b3e46`은 후속 통합 소스 `915f6187`에 포함돼 Cloudtype 운영에
  반영됐다.
- Apple Developer에서 Service ID `kr.matths.web`를 등록하고 Sign in with Apple을
  기본 App ID `64U874RU4D.kr.matths.app`, 도메인 `www.matths.kr`, 콜백
  `https://www.matths.kr/auth/apple/callback`으로 2026-09-01 최종 저장함. 운영
  `/api/v1/auth/providers`의 `webConfigured=true`와 실제 Apple 302 리디렉션을 확인함
- 서버 소스 `915f6187`에서 게시글·댓글 작성 시 고신뢰 욕설·혐오·위해 조장 표현과
  전화번호·이메일을 게시 전에 거부하고, 게시글과 각 댓글에서 작성자를 즉시 차단하며
  차단 관리에서 해제할 수 있게 함. 차단 관계 양쪽의 목록·상세·댓글·추천을 숨기고,
  익명 콘텐츠에서 차단한 사용자의 실제 계정명은 노출하지 않으며 탈퇴 시 차단 관계도
  제거한다. iPhone 가로 852×393과 세로 390×844 화면, 격리 DB와 출시 검증 67개를 통과함
- 서버 소스 `76e7db20`에서 Apple 웹 인증 시작·콜백에 다중 인스턴스 공용 IP 요청
  제한을 적용하고 Apple 웹 전용 검증을 정식 출시 게이트에 편입함. Apple 웹 로그인,
  계정 탈퇴·재인증, 세션, 요청 보안과 배포 계약을 포함한 `launch:verify` 64개가 통과함.
  운영 `main`에는 합치지 않아 Cloudtype 배포는 발생하지 않았음
- 서버 소스 `4a0b5e7b`에서 Apple 결제의 `appAccountToken`을 Matths 계정에 영구
  귀속시키고, 같은 토큰의 다른 계정 재사용과 기존 원거래·중복 거래의 소유자 불일치를
  409로 거부하도록 함. 계정 삭제 때 귀속 레코드도 제거하며, 실제 격리 MongoDB에서
  두 계정이 같은 토큰을 동시에 선점해도 정확히 한 계정만 성공하는 것을 검증함. 앱이
  StoreKit 성공 직후 종료되거나 Ask to Buy 승인이 앱 종료 중 도착해도 Apple의 최초
  `SUBSCRIBED` 통지에서 사전 귀속 계정을 찾아 권한을 복구함. 미등록 토큰은 거부하고,
  재전송은 멱등 처리하며, 원거래·토큰 소유자 충돌은 권한 부여 전에 차단함. Apple
  결제 HTTP·서버 통지 복구·구독 수명주기·계정 삭제·런타임을 포함한 `launch:verify` 66개가
  통과했고, 후속 통합 소스 `915f6187`로 운영 `main`과 Cloudtype에 반영됐음
- iPhone 6.9인치 가로 7장과 iPad 13인치 가로 7장 규격 검증 통과
- 2026-09-01 App Store Connect의 iPhone 6.9인치 및 iPad 13인치 슬롯에
  최종 가로 스크린샷을 각각 7장 업로드하고, 두 슬롯 모두
  `홈 → 커리큘럼 → 퀵 연습 → 오답노트 → GOAT Arena → Pro 리포트 → 튜토리얼`
  순서로 영구 저장된 것을 재접속 후 확인함
- build 13 후보 스크린샷 14장을 현재 소스에서 재캡처했고, iPhone Pro Max
  가로에서도 Arena 상대 찾기 CTA가 스크롤 없이 노출되며 튜토리얼이
  `1/31`로 표시되는 것을 화면으로 확인함
- build 14 후보에서 iPad·iPhone 가로 튜토리얼 카드가 화면 높이를 불필요하게
  채우던 문제를 수정하고, 일반 글자 크기에서는 본문 높이만 감싸며 접근성 글자
  크기에서는 제한 높이와 세로 스크롤을 유지하는 것을 실기 확인함. 제출 세트의
  iPad·iPhone `07-tutorial.png`를 같은 데모 계정 상태로 다시 캡처해 교체함
- 제품 소스 `69983a3`에서 iPhone 가로 오답노트 빈 상태의 설명·CTA가 하단 탭 뒤로
  밀리던 문제, 알림함 빈 상태 문구가 헤더와 카드에서 중복되던 문제를 실제 화면으로
  확인해 수정함. App Store 상품이 일부만 반환될 때 성공으로 오인하던 로더도 닫고,
  가격을 못 받은 상품 카드 안에서 직접 다시 불러올 수 있게 함
- 제품 소스 `01e9363`에서 탈퇴 본인 확인 방법 조회의 일반 네트워크 실패를 조용히
  삼키던 문제를 수정함. 이메일 계정의 비밀번호 탈퇴는 계속 열어 두고, 소셜 계정에는
  실패 설명과 같은 화면의 재시도 동선을 제공함. iPad iOS 26.5에서 AX5 210% 글자,
  WebView 200% 이상 확대와 시스템·앱 동작 줄이기 자가검사를 모두 PASS했고, iPhone
  가로 홈·이용권의 다크 모드 렌더도 확인해 `accessibility-ko.md`의 지원 선언을 고정함
- 제품 소스 `44e6d08`에서 Google·Apple·카카오 로그인 시작 전 서버 확인 Task를
  전환·화면 이탈 때 취소하고, 한 소셜 로그인 중 다른 소셜 로그인과 이메일 전환이
  뒤늦게 이전 인증 UI를 여는 경쟁조건을 닫음. 인증 화면·가입 폼·31단계 튜토리얼을
  iPhone 17 Pro Max 가로에서 다시 확인했고, 전체 96개 계약 테스트와 Debug 시뮬레이터
  빌드, Release 기기용 빌드·정적 분석을 통과함. Pro 시험지 분석이 전용 판독 모델로
  정상 전환하기 전의 `visionReady=false`를 실패로 오인해 Release에 없는 디버그 메뉴를
  안내하던 문구도 제거하고, 실제 크래시 래치에만 같은 화면의 복구 버튼을 표시함
- 같은 제품 소스에서 GOAT Arena와 탈퇴 화면의 API·서버 구성 내부 문구, 서버가
  `message` 없이 보낸 기계 오류 code의 사용자 노출을 제거함. AI 튜터와 Arena 사진
  삭제 버튼 및 풀이 노트 도구를 44×44pt로 맞추고, 852×393pt와 667×375pt iPhone
  가로에서 문제·풀이 노트·답안과 도구막대가 스크롤 없이 한 화면에 유지되는 것을
  실기 확인함. 작은 폭에서는 되돌리기·다시 실행·전체 지우기만 44pt 편집 메뉴로 접힘
- 제품 소스 `fdb1da9`에서 667×375pt iPhone 가로의 회원가입·비밀번호 재설정·회원
  탈퇴 폼을 실제 소프트웨어 키보드로 다시 감사함. 탈퇴 확인 문구 입력칸이 키보드와
  고정 탈퇴 버튼 사이에 가려지던 문제를 수정해 입력 중 액션 바를 숨기고, 비밀번호의
  `다음`과 확인 문구의 `완료`가 포커스를 순서대로 이동·종료하도록 함. 수정본 실기
  확인과 전체 96개 계약 테스트, Release 기기용 빌드·정적 분석을 다시 통과함
- 제품 소스 `fdb1da9`의 build 14 개발 서명 Archive를 당시 후보로
  `work/archives/Matths-1.0-14-fdb1da9.xcarchive.zip`으로 봉인해 보존함. 앱·Widget
  코드서명과 App Group·Sign in with Apple·Automatic Assessment Configuration
  entitlement, 앱 바이너리와 dSYM UUID 일치, arm64 아키텍처, 빌드 provenance의
  clean 소스 커밋을 확인함. ZIP SHA-256은
  `6960323db1f9787083ec595e91dc9dbe842ade5734f979393e6f92834895aa09`임
- 제품 소스 `e97dfeb`에서 667×375pt iPhone 가로와 AX5 최대 접근성 글자 크기를
  함께 감사함. 프로필의 `홈` 탐색 라벨이 한 글자씩 세로로 깨지던 문제를 수정하고,
  퀵 연습 풀이 단계에서 반복 소개 헤더가 문제를 첫 화면 밖으로 미루던 문제를 닫음.
  AX5에서도 문제를 첫 화면에 표시하고, 답안 포커스 시 실제 소프트웨어 키보드 위로
  풀이 노트·답안·제출 버튼이 자동 이동하는 것을 접근성 트리와 실화면으로 확인함.
  전체 96개 계약 테스트, Release 기기용 빌드·정적 분석을 다시 통과함
- 제품 소스 `e97dfeb`의 build 14 개발 서명 Archive를 당시 후보로
  `work/archives/Matths-1.0-14-e97dfeb.xcarchive.zip`으로 봉인함. 앱·Widget의 엄격한
  코드서명 검증, App Group·Sign in with Apple·Automatic Assessment Configuration
  entitlement, 프로비저닝 식별자와 2027-08-21 만료일, 앱·Widget 바이너리와 dSYM
  UUID 일치, 양쪽 PrivacyInfo.xcprivacy, clean git provenance를 확인함. Release
  바이너리 감사는 운영 호스트만 검출했고 커리큘럼 220개·13 shard, 개념 컴포지션
  220개와 여성 음성 220개를 확인함. ZIP 무결성 검사 통과, SHA-256은
  `2bedac90212f31875cb1dff83169a26610d146a053be708456c041da42c2dac3`임
- 제품 소스 `3904b5b`에서 계정 탈퇴, Arena 상점·경기 요청·증거 제출, 주간 모의고사,
  StoreKit 거래 검증, Pro 시험지 분석, AI 튜터, 오답노트 저장·복구와 로컬 무결성
  검토의 실패 문구를 전역 감사함. 학생 화면에 NSError 영문 원문·샌드박스 파일 경로·
  모델 내부 오류가 노출되던 경로를 제거하고, 문맥별 한국어 복구 동선으로 교체함.
  진단 원문은 DEBUG 로그에만 남김. 전체 96개 계약 테스트, Debug 시뮬레이터 빌드,
  Release 기기용 빌드와 정적 분석을 다시 통과함
- 제품 소스 `3904b5b`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-3904b5b.xcarchive.zip`으로 봉인함. 앱·Widget의 엄격한
  코드서명 검증, App Group·Sign in with Apple·Automatic Assessment Configuration
  entitlement, 앱·Widget 바이너리와 dSYM UUID 일치, 양쪽 PrivacyInfo.xcprivacy,
  clean git provenance를 확인함. Release 바이너리 감사는 비밀정보·DEBUG 통로 0건,
  운영 호스트만 검출했고 커리큘럼 220개·13 shard, 개념 컴포지션 220개와 여성 음성
  220개를 확인함. ZIP 무결성 검사 통과, SHA-256은
  `508a07684bd7609ff1cb8d47b93af7beeed9862a4b8c59bd5a11b75106a1ff24`임
- 제품 소스 `cc52eb4`에서 로컬 StoreKit 설정의 앱 연결 ID가 첫 구독 상품 ID로
  잘못 들어간 문제를 수정해 실제 앱 Apple ID `6803569629`로 맞추고 계약 검사에
  고정함. 제품 소스 `1216a20`에서는 Apple의 `1개월` 자동 갱신 주기와 서비스의
  `29일` 학습 사이클을 구매 버튼 바로 아래에서 구분해 표시함. iPhone 가로 실기에서
  문구·구매 버튼·두 번째 상품·하단 탭이 함께 유지됨을 확인하고 전체 96개 테스트,
  Debug 시뮬레이터 빌드, Release 기기용 빌드와 정적 분석을 통과함
- 제품 소스 `1216a20`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-1216a20.xcarchive.zip`으로 봉인함. 소스 tree
  `b46de16a824985d5a5318b68707d9198e0f5223a`와 clean provenance, 앱·Widget의
  엄격 코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `29953384-9331-35E6-86D9-2D5850053BD3`와 Widget UUID
  `B5BCF1D6-0E8A-31CE-B1DC-87510EA68894`의 dSYM 일치, 양쪽 Privacy manifest,
  비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됨을 확인함. 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개와 ZIP 무결성 검사 통과,
  SHA-256은 `16b5f40da3fcdd7647fc5e66880cc64035d806ddea04033277c18cea7fb58067`임
- 제품 소스 `e0eaac4`에서 게시판·GOAT Arena의 로그인된 WKWebView가 같은 호스트의
  웹 가격·Toss 결제 경로로 이동할 수 있던 App Review 3.1.1 우회면을 닫음. 최초
  `/app/commerce/<token>` 로그인 핸드오프만 허용하고, 이후 `/pricing`, `/checkout`,
  `/payments`, 부모 결제와 핸드오프 경로는 모두 이동을 취소해 네이티브 StoreKit
  이용권 화면으로 보냄. 외부 호스트 `/register`까지 로그인 만료로 잘못 가로채던
  조건식도 서버 호스트 안으로 제한함. 전체 96개 테스트, Debug 시뮬레이터 빌드,
  Release 기기용 빌드와 정적 분석을 통과함
- 제품 소스 `e0eaac4`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-e0eaac4.xcarchive.zip`으로 봉인함. 소스 tree
  `abedf2a8f6a01af623c42af37793b4f00671d82c`와 clean provenance, 앱·Widget의
  엄격 코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `28D11B6C-1790-3C76-9081-901A4D94C65B`와 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개를 확인함. ZIP 무결성 검사 통과,
  SHA-256은 `9ce0843bc216205d59ebedbc93ba879139977644273bb01b4abf0dca255b848a`임
- 제품 소스 `56ba6d1`에서 GOAT Arena 순위표·Ranked 신청 실패·경기 시작 실패의
  보조 동선 세 곳이 로그인되지 않은 Safari를 직접 열던 불일치를 제거함. 모두 앱 안의
  로그인 핸드오프 브리지로 통일하고, 경기 fallback은 현재 match ID와 화면 보호·캡처
  기록을 그대로 전달함. 전체 96개 테스트, Debug 시뮬레이터 빌드, Release 기기용
  빌드와 정적 분석을 통과함
- 제품 소스 `56ba6d1`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-56ba6d1.xcarchive.zip`으로 봉인함. 소스 tree
  `26440294de888cf715d57e56057899c3137064b7`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `75C0B8DC-39FA-3E3F-A2CF-AF6949FF9A44`와 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개를 확인함. ZIP 무결성 검사 통과,
  SHA-256은 `00a0331bb64909e773313e34bb9b70f72b893502e6233b2a7f8100fe179c5eab`임
- 제품 소스 `5421e2c`에서 알림을 첫 20건만 보여 주던 누락을 닫고, 서버 전체 건수와
  미읽음·긴급 배지를 유지한 채 이전 페이지를 중복 없이 이어 붙이도록 함. 모두 읽음과
  다음 페이지 요청 순서가 뒤집혀도 미읽음 표시가 되살아나지 않으며, 모든 알림 GET·
  읽음 POST는 시작 계정의 Bearer 자격을 고정해 계정 전환 중 다른 사용자에게 적용되지
  않음. 취소된 이전 요청의 종료가 새 요청의 로딩 상태·응답을 덮는 세대 경합도 차단함.
  서버 알림 href는 GOAT Arena의 정확한 내부 화면과 실제 커리큘럼 개념으로 연결하고,
  결제 경로는 네이티브 StoreKit으로 유지함. 전체 96개 테스트, Debug 시뮬레이터 빌드,
  Release 기기용 빌드와 정적 분석을 통과함
- 제품 소스 `5421e2c`의 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-5421e2c.xcarchive.zip`으로 봉인함. 소스 tree
  `d29337b0810b32d059b9da17fb349c4b69d47ec7`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `8A22B661-32DD-3C84-ABAE-7F11A71C0B45`와 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개를 확인함. ZIP 무결성 검사 통과,
  SHA-256은 `b8baa4e41e140815e5577f3178aba8f13d214ce2088df8252ebb798241306f97`임
- 제품 소스 `f0f5368`에서 데모 알림도 운영과 같은 20건+6건 페이지 구성을 사용하게
  해 실제 iPhone 가로 접근성 트리로 2페이지 이동, 중복 없는 26건 유지와 마지막
  페이지의 더 보기 버튼 제거를 확인함
- 제품 소스 `e061ac9`에서 StoreKit 구매 시트를 열기 전에 현재 Matths 계정의 인증
  스냅샷과 전용 UUID를 서버에 귀속하고, 구매 완료·복원도 시작 계정의 고정 인증으로
  검증하도록 함. 구매 도중 로그아웃·계정 전환이 일어나거나 Ask to Buy 승인이 나중에
  도착해도 새로 로그인한 다른 계정에 이용권이 지급되지 않으며, 계정이 바뀐 경우에는
  시작 계정에 반영됐음을 명시하고 현재 계정의 상태를 잘못 새로고침하지 않음. 전체
  96개 계약 테스트, Debug 시뮬레이터 빌드, Release 기기용 빌드·정적 분석을 통과함.
  이 앱은 서버의 `/api/v1/commerce/apple/account-token`을 선행 호출하므로 서버
  `4a0b5e7b`를 운영 배포하기 전에는 build 14를 업로드·제출하면 안 됨
- 제품 소스 `e061ac9`의 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-e061ac9.xcarchive.zip`으로 봉인함. 소스 tree
  `36c4240c84e019667402b8ddc3c60c23e35b7173`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `9451F1FE-6FD1-33D1-8E6B-973F588EC2E2`와 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개·폰트 5개·GSAP 로컬 사본을
  확인함. ZIP 무결성 검사 통과, SHA-256은
  `3997899a566366f030458794641ef80748dc7025aa78d75ec9c659c1b39bace3`임
- 제품 소스 `ffd5b8b`에서 회원 탈퇴만으로 Apple 자동갱신 구독이 해지되지 않는다는
  사실, 다음 청구를 막으려면 별도 해지가 필요하다는 점과 남은 이용기간·결제 내역이
  새 Matths 계정으로 자동 이전되지 않는다는 점을 탈퇴 확정 화면에 명시함. 같은
  화면에서 App Store 구독 관리로 바로 이동할 수 있는 44pt 링크를 제공하며, 실제
  852×393pt iPhone 가로에서 경고·링크·Google/Apple/카카오 재확인·확인 문구·동의·
  탈퇴 버튼이 모두 한 화면에 노출되는 것을 확인함. 전체 96개 계약 테스트, Debug
  시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와 정적 분석을 통과함
- 제품 소스 `ffd5b8b`의 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-ffd5b8b.xcarchive.zip`으로 봉인함. 소스 tree
  `34d5768fd733e0705f9e9403fc247ae3bbfedf91`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `ECBF91CB-4804-3060-80B6-2A4A2A2971BD`와 Widget UUID
  `8295F529-41AB-3BCD-BF14-EB2CCE27630A`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개·폰트 5개·GSAP 로컬 사본을
  확인함. ZIP 무결성 검사 통과, SHA-256은
  `6639db4c1e147c2596e86052e78ff2dd05627d557a16345ee10082cfdafc6249`임
- 제품 소스 `3ffec91`에서 iPhone 가로의 학교 변경 목록과 Arena 경기 상세 분석이
  draggable sheet의 닫기 제스처와 내부 스크롤을 다투던 구조를 제거함. 프로필 사진
  편집과 풀이 이미지 확대도 같은 규칙으로 통일해 높이가 짧은 창에서만 전체 화면으로
  열고, 세로 iPhone과 iPad에서는 기존 sheet 표현을 유지함. 실제 852×393pt iPhone
  가로에서 학교의 지역·검색·목록과 Arena 분석의 네 지표·취약 개념·문항 목록을
  확인함. 전체 96개 계약 테스트, Debug 시뮬레이터 빌드, Release 기기용 빌드·
  바이너리 감사와 정적 분석을 통과함
- 제품 소스 `3ffec91`의 당시 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-3ffec91.xcarchive.zip`으로 봉인함. 소스 tree
  `73217b3f659889ddc718c3ce96ce8aff6b586631`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `A21427EB-7AE2-3E38-BF12-0E1A0363255F`와 Widget UUID
  `8295F529-41AB-3BCD-BF14-EB2CCE27630A`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개·폰트 5개·GSAP 로컬 사본을
  확인함. ZIP 무결성 검사 통과, SHA-256은
  `073112d52d4ca698697d6c23fc8504d1d898222cc68ef85be36b09e9e9f1322d`임
- 제품 소스 `6522330`에서 게시판·Arena 웹의 외부 Safari와 첨부파일 Quick Look을
  iPhone 가로에서 일반 page sheet가 아니라 전체 화면으로 열도록 함. 세로 iPhone과
  iPad의 sheet 표현은 유지하며, Quick Look에는 swipe-down에 의존하지 않는 명시적
  `닫기` 버튼을 추가함. 실제 852×393pt iPhone 가로에서 데모 게시판의 전체 문서를
  스크롤해 공식 YouTube 외부 링크를 열고, Safari가 화면 전체를 사용하며 좌상단 닫기로
  기존 게시판 위치에 복귀하는 것을 확인함. 전체 96개 계약 테스트, Debug 시뮬레이터
  빌드, Release 기기용 빌드·바이너리 감사와 정적 분석을 통과함
- 제품 소스 `6522330`의 당시 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-6522330.xcarchive.zip`으로 봉인함. 소스 tree
  `5204a08b6ff9ab392f2099e096ebc0795583e150`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `1D5AAC0B-0791-348B-8444-EF6DD81BE30F`와 Widget UUID
  `34E98657-4C06-3E21-A496-0A9B5BC82BC0`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 비밀정보·DEBUG 통로 0건과 운영 호스트만 포함됐고 커리큘럼 220개·13 shard,
  개념 컴포지션 220개·여성 음성 220개·남성 음성 0개·폰트 5개·GSAP 로컬 사본을
  확인함. ZIP 무결성 검사 통과, SHA-256은
  `fe95ef3bc4d523f2a6216d39e1852919d53450a61e9af2cc3faa4034138f5d7c`임
- 제품 소스 `9c4b9b8`에서 AI 모델 다운로드·분석 모델팩 준비·엔진 로드 실패가
  Foundation 오류 원문, 호스트명, 임시 파일 경로와 모델 내부 이름을 채팅·프로필·
  다운로드 버튼에 그대로 표시하던 잔여 경로를 닫음. 연결 끊김·시간 초과·저장공간·
  파일 검증 실패별로 학생이 바로 취할 복구 행동만 표시하고 원문은 DEBUG 로그에만
  남김. 전체 96개 계약 테스트, Debug 시뮬레이터 빌드, Release 기기용 빌드·바이너리
  감사와 정적 분석을 통과함
- 제품 소스 `9c4b9b8`의 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-9c4b9b8.xcarchive.zip`으로 봉인함. 소스 tree
  `96ae5787df28851c3abd11af0b3d52e6180bb698`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `CC7F87BB-1262-3E3D-9535-34B3C23E2672`와 Widget UUID
  `34E98657-4C06-3E21-A496-0A9B5BC82BC0`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. AI 오류 원문 로그·비밀정보·DEBUG 통로는 0건이고 안전한 모델 복구 문구와
  운영 호스트만 포함됐으며 커리큘럼 220개·13 shard, 개념 컴포지션 220개·여성 음성
  220개·남성 음성 0개·폰트 5개·GSAP 로컬 사본을 확인함. ZIP 무결성 검사 통과,
  SHA-256은 `d67b09a35ec67e943145ffcbf995c9c04d70abcfb51295a58d446a2450325ef4`임
- 제품 소스 `d67ec30`에서 프로필 동기화 카드가 Foundation/NSError 원문을 표시하던
  네 catch 경로를 닫음. 오프라인·연결 실패·시간 초과·로그인 만료·429·5xx를 학생이
  취할 복구 행동과 자동 재시도 여부로 분류하고, 원문은 DEBUG 로그에만 남김. 제품 소스
  `26aa5db`에서는 AI 튜터 답변 생성·교정 실패가 문자열 값으로 임시 상태에 남던 경로도
  Boolean 실패 상태로 바꾸고 Release에서는 원문을 완전히 제거함. 두 회귀 계약을 추가해
  전체 96개 계약 테스트, Debug 시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와
  정적 분석을 통과함
- 제품 소스 `26aa5db`의 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-26aa5db.xcarchive.zip`으로 봉인함. 소스 tree
  `abd6cddfbef911db1575de89dd8d9e9f5eb5ad94`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `AB49ADFE-F387-3B63-83C4-C9B4C302072B`와 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 동기화·튜터 생성·튜터 교정 실패 원문 DEBUG 접두사는 Release 바이너리에서
  0건이고 안전한 동기화 보존·오프라인 복구 문구와 운영 호스트는 실제 바이너리에 포함됨.
  커리큘럼 220개·13 shard, 개념 컴포지션 220개·여성 음성 220개·남성 음성 0개·폰트
  5개·GSAP 로컬 사본을 확인함. ZIP 무결성 검사 통과, SHA-256은
  `cff971f3c98ea5879dd4c1248457aa365334638bb3a9992b8e3864688c2b54c3`임
- 제품 소스 `985c3d0`에서 Pro 시험지 채점의 비전·추론 파이프라인이 전용
  `SheetError`가 아닌 예외를 `"\(error)"`로 화면 상태에 저장하던 경로를 닫음.
  메모리 부족·사진 읽기·한 페이지 용량·모델 준비 실패를 사용자가 취할 복구 행동으로
  분류하고, 나머지는 보존된 사진 재시도로 안내하며 원문은 DEBUG 로그에만 남김. 모델이
  출력한 `page_kind`와 `note`도 오류 카드에 재출력하지 않고 여러 페이지·타 과목·시험지
  아님·인식 실패별 앱 고정 문구로 바꿈. 표적 계약, 전체 96개 계약 테스트, Debug
  시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와 정적 분석을 통과함
- 제품 소스 `985c3d0`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-985c3d0.xcarchive.zip`으로 봉인함. 소스 tree
  `0fcd356e45fa063d2c815e148870583c02a4b2ac`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `C2C87A9F-5C1A-3C71-B92F-21D7462B2E78`와 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 시험지 분석·튜터 생성·동기화 실패 원문 DEBUG 접두사와 동적 시험지 오류
  문구는 Release 바이너리에서 0건이고, 안전한 시험지 재시도·여러 페이지 복구 문구와
  운영 호스트는 실제 바이너리에 포함됨. ZIP 무결성 검사 통과, SHA-256은
  `fefda14e14d53738ab57dce89b2668196b353a7f6e0cd2de22483ffab86ba7f4`임
- 제품 소스 `cee7a2c`에서 8GB 비교 실험에만 쓰던 Qwen 4B의 변경 가능한
  Hugging Face `main` revision URL을 DEBUG 전용으로 격리함. 사용자가 이미
  사이드로드한 4B 본체와 로컬 프로젝터의 짝은 Release에서도 유지하되 원격 URL은
  링크하지 않으며, 소스의 모든 `/resolve/main/`이 DEBUG 조건 안에 있는지와 최종
  Release 바이너리에 해당 문자열이 없는지를 각각 계약·릴리스 게이트로 고정함.
  전체 96개 계약 테스트, Debug 시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와
  정적 분석을 통과함
- 제품 소스 `cee7a2c`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-cee7a2c.xcarchive.zip`으로 봉인함. 소스 tree
  `6f03165ad8029db7614201bbe8b47c37a56ea5b6`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `3687C696-6318-3638-9566-C16C4CB3A300`과 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 변경 가능한 모델 URL·비밀정보·DEBUG 통로는 Release 바이너리에서 0건이고
  운영 호스트만 포함됨. Archive는 arm64 전용이며 ZIP SHA-256은
  `5efd8309e70fb4d656cba18a8fd53c6c5323e94d8dfed7ea2f9afeee53ed0e6d`임
- 제품 소스 `53c1660`에서 주간 공식 모의고사의 900pt 고정 분기 때문에 852×393pt
  iPhone 가로에서도 문제지와 답안지를 번갈아 보던 왕복을 제거함. 일반 글씨에서는
  문제지 왼쪽·답안지 오른쪽의 동시 2열 작업대를 쓰고, 667pt급 가로에서도 오른쪽
  선지 다섯 개의 44pt 조작 영역을 보장함. 실제 데모 시험에서 1번 선지를 선택해
  진행률이 0/30에서 1/30으로 즉시 바뀌는 것까지 확인함. 접근성 큰 글씨에서는
  좁은 2열을 강제하지 않고 문제지·답안지 전환형을 유지하며, 잘리던 긴 회차 제목은
  `W34-B형 2회차`로 온전히 표시하고 VoiceOver에는 서버의 전체 제목을 보존함. 전체
  96개 계약 테스트, Debug 시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와
  정적 분석을 통과함
- 제품 소스 `53c1660`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-53c1660.xcarchive.zip`으로 봉인함. 소스 tree
  `99cb7a649cc3fe16a9bfd185dfce1f02b72a5651`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `C12FC2D1-9BEE-3917-9A35-CB90F2911631`과 Widget UUID
  `812396BE-1F49-3C72-AF04-1903F8B00C0B`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 변경 가능한 모델 URL·비밀정보·DEBUG 통로는 Release 바이너리에서 0건이고
  운영 호스트만 포함됨. Archive는 arm64 전용이며 ZIP SHA-256은
  `b3bc133e290a8753a96065f57c093f11c4f7761c4121935e257d467703ff65f9`임
- 제품 소스 `733f0d7`에서 KICE 기출 응시 화면도 900pt 고정 분기를 제거함.
  852×393pt iPhone 가로에서 40쪽 PDF 문제지는 왼쪽, 30문항 OMR은 오른쪽에
  동시에 표시하고, 오른쪽 352pt 안에서 다섯 선지의 44pt 조작 영역을 보장함.
  실제 2026 수능 시험지로 1번 1번 선지를 눌러 선택 상태와 미응답 30→29 반영을
  확인함. 접근성 매우 큰 글씨에서는 좁은 2열을 강제하지 않고 문제지·답안지 전환형을
  유지해 제목·타이머·PDF가 잘리지 않음을 실기 확인함. 전체 97개 계약 테스트,
  Debug 시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와 정적 분석을 통과함
- 제품 소스 `733f0d7`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-733f0d7.xcarchive.zip`으로 봉인함. 소스 tree
  `48b79703e12dd1abaa6b931b87bbe2af50cf6f16`와 clean provenance, 앱·Widget의 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `D25B2364-3359-3986-B775-649E7D897A1B`와 Widget UUID
  `1566952F-028D-34A3-A315-84FC6731D357`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 변경 가능한 모델 URL·비밀정보·DEBUG 통로와 KICE PDF는 Release에서 0건이고
  운영 호스트만 포함됨. Archive는 arm64 전용이며 ZIP SHA-256은
  `3eb5549740d4f31185c6149cc16cc1eda7c75bc8a56c89b7d6e64f48e5ed0b1f`임
- 제품 소스 `6cb4bfd`에서 iPhone 가로 평가 시험지의 제출 버튼을 고정 헤더에도
  제공해 40문항 문서의 끝까지 다시 스크롤하지 않아도 제출할 수 있게 함. 미응답
  제출은 기존 확인 경고를 그대로 거치며 실제 852×393pt 화면에서 답안 선택,
  응답 0→1, 제출 활성화와 경고를 확인함. 시험지 WebKit에는 문항 heading/group,
  선지 radiogroup/radio와 `aria-checked`, 주관식 label을 추가해 VoiceOver 의미와
  선택 상태를 명시함. 접근성 큰 글씨에서는 선지가 한 열로 전환되고 제목·응답 수·
  타이머·제출 버튼이 겹치지 않음을 확인함
- 제품 소스 `da47e71`에서 iPhone 가로 회원가입의 큰 글씨 내부 필드 HStack을 제거함.
  바깥 컨테이너만 한 열로 바뀌고 생년월일·이메일·비밀번호는 반쪽 열에 남아 글자가
  찢어지던 문제를 고쳐, 접근성 글씨에서는 실명→닉네임→생년월일→이메일→비밀번호가
  완전한 한 열과 정상 VoiceOver 순서로 표시됨. 기본 글씨의 가로 2열은 유지하고 입력·
  날짜·학년 컨트롤의 조작 영역은 최소 44pt로 보장함. 전체 97개 계약 테스트,
  Debug 시뮬레이터 빌드, Release 기기용 빌드·바이너리 감사와 정적 분석을 통과함
- 제품 소스 `da47e71`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-da47e71.xcarchive.zip`으로 봉인함. 소스 tree
  `f0279034180af04e69e655c38011275251618d60`와 clean provenance, 앱·Widget 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `7F0DF6D3-8E67-3DF7-BE3A-D9680A7F9D58`과 Widget UUID
  `74B4375C-029C-3653-99AC-6A59D45AB265`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 변경 가능한 모델 URL·비밀정보·DEBUG 통로와 KICE PDF는 Release에서 0건이고
  운영 호스트만 포함됨. 커리큘럼 13 shard, 개념 기본/여성 컴포지션 각 220개,
  여성 음성 220개·남성 음성 0개를 확인했으며 ZIP 무결성 검사 통과, SHA-256은
  `b57827cd5c457800b48b9e3a78660a6500c18b73fd96e901cbba34ba4059befb`임
- 제품 소스 `253685f`에서 GOAT Arena의 활성 경기 상태가 수비자 `MATCHED`인데
  pending invitation이 전달되지 않은 경우, 내부 구현을 설명하는 문구만 보이고
  사용자가 진행할 수 없던 막힘을 제거함. `최신 경기 상태 다시 확인` 버튼을 iPhone
  가로 compact 화면과 iPad regular 화면 모두에 제공하고, 44pt 조작 영역·VoiceOver
  힌트와 재조회 동작을 실제 852×393pt iPhone 가로 화면에서 확인함. 전체 97개 계약
  테스트와 detached worktree의 Debug 시뮬레이터 빌드를 통과함. 이 수정 이후의
  build 14 Archive를 아래와 같이 다시 생성했으므로 `da47e71` Archive는 제출에 사용하지 않음
- 제품 소스 `253685f`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-253685f.xcarchive.zip`으로 봉인함. 소스 tree
  `ed5df3a0cd46b843796b1f63557c7e262784fb53`와 clean provenance, 앱·Widget 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `158265AB-5EE2-3CC6-943C-A3B6C48DE4CE`와 Widget UUID
  `624BBD03-5521-341D-8D1C-7E5C88AA614F`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 변경 가능한 모델 URL·비밀정보·DEBUG 통로는 Release에서 0건이고 운영
  호스트만 포함됨. 커리큘럼 220/220·13 shard, 개념 기본/여성 컴포지션 각 220개,
  여성 음성 220개·남성 음성 0개를 확인했으며 ZIP 무결성 검사 통과, SHA-256은
  `9dc87b23ab9d0db7adc96cde6208750eb713e5faa9d7c9233392fc5aa88ab9d2`임. 같은
  고정 소스의 Release 정적 분석도 통과함
- 제품 소스 `8c38733`에서 GOAT Arena 수락·거절 확인, 공식 룰북, 이전 요청 복구,
  풀이 증거 임시 보관, 오답 메모와 주간 모의고사 소명 안내에 남아 있던 `사유 코드`,
  `경기 원장`, `요청 번호`, `로컬 보관함`, `필기 스냅샷` 같은 내부 용어를 학생이
  알아야 할 행동·결과·보관 범위 중심 문구로 교체함. iPhone 17 Pro Max 852×393pt
  가로에서 GOAT Arena의 상태 요약·복구 안내·재확인 버튼·하단 탭을 함께 실기 확인했고,
  프로필·이용권·게시판·알림함 첫 화면도 추가 점검함. 전체 97개 계약 테스트와 최신
  Debug 시뮬레이터 빌드를 통과했으며, 빌드 중 발견한 미사용 소명 바인딩 경고도 제거함
- 제품 소스 `8c38733`의 최신 build 14 개발 서명 Archive를
  `work/archives/Matths-1.0-14-8c38733.xcarchive.zip`으로 봉인함. 소스 tree
  `4536ed997a097611246227f9581874b18e8a21fd`와 clean provenance, 앱·Widget 엄격
  코드서명, App Group·Sign in with Apple·Automatic Assessment Configuration,
  앱 UUID `9B3F3C2A-3507-3218-99E8-F2F156016347`과 Widget UUID
  `624BBD03-5521-341D-8D1C-7E5C88AA614F`의 dSYM 일치, 양쪽 Privacy manifest를
  확인함. 변경 가능한 모델 URL·비밀정보·DEBUG 통로는 Release에서 0건이고 운영
  호스트만 포함되며, DEBUG 데모 게시판 자산도 0건임. 커리큘럼 220/220·13 shard,
  개념 기본/여성 컴포지션 각 220개, 여성 음성 220개·남성 음성 0개를 확인했고 ZIP
  무결성 검사 통과, SHA-256은
  `a993b48a819abb27b64c975536209beadfd626a7e6606190221f4a4a88f3b63e`임. 같은
  고정 소스의 Release 정적 분석도 통과함
- 이전 로컬 Archive `Matths-1.0-14-44e6d08.xcarchive.zip`,
  `Matths-1.0-14-26342d0.xcarchive.zip`,
  `Matths-1.0-14-c08a424.xcarchive.zip`,
  `Matths-1.0-14-01e9363.xcarchive.zip`,
  `Matths-1.0-14-69983a3.xcarchive.zip`, `Matths-1.0-14-0e8f989.xcarchive`,
  `Matths-1.0-14-fdb1da9.xcarchive.zip`, `Matths-1.0-14-e97dfeb.xcarchive.zip`,
  `Matths-1.0-14-3904b5b.xcarchive.zip`, `Matths-1.0-14-1216a20.xcarchive.zip`,
  `Matths-1.0-14-e0eaac4.xcarchive.zip`, `Matths-1.0-14-56ba6d1.xcarchive.zip`,
  `Matths-1.0-14-5421e2c.xcarchive.zip`, `Matths-1.0-14-e061ac9.xcarchive.zip`,
  `Matths-1.0-14-ffd5b8b.xcarchive.zip`, `Matths-1.0-14-3ffec91.xcarchive.zip`은
  후속 수정 전 후보이며 `Matths-1.0-14-6522330.xcarchive.zip`,
  `Matths-1.0-14-9c4b9b8.xcarchive.zip`, `Matths-1.0-14-d67ec30.xcarchive`,
  `Matths-1.0-14-26aa5db.xcarchive.zip`, `Matths-1.0-14-985c3d0.xcarchive.zip`도
  같은 이유로 제출에 사용하지 않으며, `Matths-1.0-14-cee7a2c.xcarchive.zip`과
  `Matths-1.0-14-53c1660.xcarchive.zip`, `Matths-1.0-14-733f0d7.xcarchive.zip`,
  `Matths-1.0-14-da47e71.xcarchive.zip`, `Matths-1.0-14-253685f.xcarchive.zip`도
  각각 후속 제품 수정 전 후보라 제출에
  사용하지 않음.
  App Store Connect에는 어느 build 14도 아직 업로드하지 않음
- 제품 소스 `140735b`에서 Release 기기용 빌드·바이너리 감사를 통과했고,
  빌드 13 Archive `/private/tmp/Matths-build13-final.xcarchive`를 생성했으나 이후
  `UILaunchScreen` 중첩 생성과 고객지원 복구 경로 누락을 발견해 제출 후보에서 제외함
- build 13 Archive의 앱·위젯 코드서명이 유효하고, App Group·Sign in with Apple·
  Automatic Assessment Configuration entitlement가 실제 서명에 포함되며,
  앱·위젯 dSYM UUID가 각 바이너리와 일치함
- 개념 강의 웹 메시지의 `LESSON-DEBUG` 본문 로깅을 Release에서 제거했고,
  최종 Archive 바이너리에서 해당 문자열 0건을 확인함
- 한국어 버전 메타데이터와 심사 메모 작성 완료
- 운영 서버의 HTTPS, FAQ, 약관·개인정보처리방침, 새 고객지원 연락처와 Apple 결제
  HTTP 경계 응답을 확인했고 `node scripts/verifyAppStoreLiveMetadata.js`가 통과함
- App Store Connect 실계정에서 앱 기본 카테고리·콘텐츠 권한·연령 등급과 앱 개인정보
  설문이 모두 미설정임을 확인함. 첫 학습권은 175개 지역·한국 ₩29,000 가격이 있으나,
  모의고사 이용권은 시작 가격·판매 지역이 없어서 StoreKit 상품 조회에도 나타나지 않음.
  로컬 StoreKit의 상품 ID는 실제 상품 `6803570684`로 맞췄다. 단, 운영 storefront는
  당시 5,000원이었으나 2026-09-01 최종 가격을 5,500원으로 결정했다. App Store
  Connect와 로컬 StoreKit 검수 설정은 5,500원으로 통일했고 운영 서버 정책은 재기동 후
  같은 값으로 반영·검증해야 함
- 2026-09-01 App Store Connect 앱 정보에서 App Store 서버 알림의 프로덕션·Sandbox
  URL이 모두 `https://www.matths.kr/api/v1/commerce/apple/notifications`로 등록된 것을
  실계정에서 확인함. Apple 쪽 수신 경로는 준비됐으며 서버 `915f6187` 운영 배포 후
  Sandbox 구매·갱신·환불 통지의 실제 권한 변화를 완주해야 함
- 2026-09-01 App Store Connect를 다시 대조함. 버전 1.0의 iPhone 6.9인치와 iPad
  13인치 가로 스크린샷을 각각 7장 업로드하고 순서를 저장함. 심사용 빌드는 미선택,
  심사 로그인·연락처·메모는 비어 있고 최신 업로드는 build 12임.
  개인정보 아홉 유형과 iPhone·iPad 손쉬운 사용 기기 범위는 정확히 선택했으나 최종
  저장 전이며, 앱 무료 가격·판매 지역도 미설정임.
  Apple Silicon Mac과 Apple Vision Pro 호환 배포는 모두 켜져 있어 실제 검증 범위와
  맞게 제출 전 해제해야 함. 모의고사 구독은 가격·지역·한국어 현지화·심사 캡처가
  비어 있음을 재확인함
- 같은 실계정에서 무료 앱 계약·유료 앱 계약, 대한민국·미국 세금 양식과 케이뱅크
  지급 계좌가 모두 활성 상태임을 확인함. 유료 구독 심사를 막는 계약·세금·지급 계정
  문제는 없음. 반면 App Store Connect API는 조직 접근 요청 전이라 기존 배포 키가 없고,
  Xcode Apple ID 로그인 또는 API 접근 요청·승인과 새 키 발급 없이는 build 14 업로드 불가
- App Store Connect 미디어 관리에서 준비된 iPhone `2868×1320` 7장은 6.9인치 슬롯,
  iPad `2752×2064` 7장은 13인치 슬롯의 허용 규격임을 실계정 안내와 다시 대조함

## 제출 전에 외부 계정에서 끝낼 항목

- [x] build 11을 Archive하고 Cloud Managed Apple Distribution으로 배포 서명해 App Store Connect에 업로드
- [x] build 12를 Archive·배포 서명하고 App Store Connect에 업로드
- [x] build 13을 검증하고 Archive 생성(후속 결함 발견으로 제출 제외)
- [x] build 14를 최종 검증하고 Archive 생성
- [x] 서버 `915f6187`을 운영 저장소 `main`에 반영
- [x] 서버 `915f6187` 및 Apple 임시 이메일 복구 후속 `312eb262`을 Cloudtype에 배포하고,
  운영 인증 경계·통지 endpoint 응답과 로컬 소유권 거부·`SUBSCRIBED` 복구 계약 확인
- [ ] Sandbox 구매·갱신·복원·환불 통지 1건으로 실제 운영 권한 변화를 끝까지 확인
- [x] Xcode Apple ID 세션을 복구해 build 14를 Apple Distribution으로
  재서명·export한 뒤 App Store Connect에 업로드
- [x] Apple Developer에서 `kr.matths.web`의 Sign in with Apple을 활성화하고,
  기본 App ID `64U874RU4D.kr.matths.app`, 도메인 `www.matths.kr`,
  `https://www.matths.kr/auth/apple/callback`을 2026-09-01 최종 저장
- [x] App Store 서버 알림의 프로덕션·Sandbox URL을 운영 Apple 통지 endpoint로 등록
- [x] Apple Private Email Relay 발신원 `lsbproduction00@gmail.com`을 등록하고 SPF 상태 확인
- [ ] 처리 완료·검증됨·비면제 암호화 `아니요`인 build 14를 앱 버전에 연결
- [x] 앱 이름을 ASC와 로컬 모두 `맵쓰`로 통일하고 한국어 부제 입력
- [x] 기본 카테고리를 교육으로 설정
- [ ] 콘텐츠 권리 근거·연령 등급 설문을 사실대로 확정
- [ ] 개인정보처리방침 URL과 `app-privacy-ko.md`의 아홉 수집 유형을 App Store Connect에 게시
- [ ] 앱 가격을 무료로 두고 배포 지역을 확정하며, 검증하지 않은 Apple Silicon Mac 배포를 해제
- [x] iPhone·iPad 스크린샷 14장과 `metadata/ko-KR.json`의 문안을 업로드
- [ ] `accessibility-ko.md`의 검증된 여섯 항목만 App Store Connect 손쉬운 사용에 선언
- [ ] 생성·로그인 검증한 이메일 전용 심사 계정 자격 증명을 App Store Connect 로그인 정보 칸에만 입력
- [ ] 심사 계정의 공통수학 진도·오답 3개는 준비됨. 배치 결과와 활성 Arena 상태는 유료 권한 설정 뒤 확인
- [x] 모의고사 구독 가격을 ₩5,500으로 StoreKit·App Store에 통일하고,
  판매 지역·한국어 현지화·심사용 스크린샷을 저장한 뒤 두 구독을 build 15 앱 버전과
  함께 심사 제출
- [ ] 운영 서버 모의고사 정책을 ₩5,500으로 적용한 뒤 Sandbox
  구매→권한 부여→복원→환불 통지를 1회 완주
- [ ] 디지털 서비스법 거래자 상태와 대한민국·중국 본토·베트남 배포 범위를 사업자 기준으로 확정
- [x] 운영 공개 문안 배포 뒤 `node scripts/verifyAppStoreLiveMetadata.js` 통과

build 14 export에 필요한 Xcode 계정 목록은 현재 빈 상태다. 제품 소스
`26aa5db` Archive를 2026-09-01에 App Store Connect 방식으로 직접 export했지만
`No Accounts`/
`No signing certificate "iOS Distribution" found`로 중단됐다. 로컬의 두 `.p8`은
App Store Connect 배포 키가 아니라 Sign in with Apple·APNs 키라 대체 인증에
사용하지 않았다. 최신 제출 후보 제품 소스는 `8c38733`이지만 Xcode 계정·배포 인증서가
없는 조건은 동일하다. 인앱 브라우저의 App Store Connect 세션은 2026-09-01 다시
활성화해 스크린샷 14장 업로드까지 마쳤지만, 브라우저 세션은 Xcode의 배포
서명·업로드 세션으로 전용할 수 없다. 장기 보관을
위해서는 App Store Connect에서
배포 전용 API 키를 별도 발급해 안전한 비밀 저장소에 두는 방식도 가능하다.
