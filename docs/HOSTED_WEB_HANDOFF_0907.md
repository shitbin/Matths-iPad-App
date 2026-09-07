# Hosted web 로그인 핸드오프의 계정·뷰 소유권

## 수정한 결함

`CommunityWebModel`(서비스 포털에서도 사용)과 `ArenaWebModel`은 이전 계정의 일회용 세션 URL 응답이 늦게 도착하면 현재 `self.webView`에 로드할 수 있었습니다. JSON 요청 직후의 토큰 확인만으로는 응답이 MainActor에 돌아오기 직전의 계정/뷰 교체를 막을 수 없습니다.

이번 변경은 다음을 적용합니다.

- Task를 만들기 전에 Bearer snapshot, account slot, 요청 세대, 구체적 WKWebView identity를 캡처합니다.
- `createCommerceHandoff`에 캡처한 authorization을 명시적으로 전달합니다.
- 쿠키 정리 뒤, 응답 뒤, 오류 fallback 전에 모두 소유권을 재검증합니다. 취소를 무시한 지연 callback도 새 페이지를 로드하거나 상태를 덮을 수 없습니다.
- 계정 변경 시 기존 문서/뒤로 가기 기록을 가진 WKWebView를 즉시 교체합니다. Community의 UIView host도 새 인스턴스를 실제로 다시 붙입니다.
- 여러 계정 알림이 겹쳐도 기존 표시 여부를 보존하면서 가장 최근 요청만 재연결합니다.
- 두 모델이 공유하는 WebKit cookie store의 purge는 동일 host별 single-flight로 연결합니다. 새 핸드오프는 이전 계정의 purge 완료를 기다립니다.
- 중지·뒤로/앞으로·다시 연결이 기존 핸드오프 Task를 무효화합니다.
- 퇴역한 WKWebView의 navigation/JavaScript dialog/download callback은 무시합니다. 다운로드는 현 세션에서 승인된 객체 ID에만 destination/preview 권한을 주고 파일명은 마지막 경로 구성요소로 제한합니다.
- 세션 URL은 HTTPS, 같은 host/port, userinfo 없음, `/app/commerce/` 경로와 정상 경로 구성요소를 요구합니다.

## 검증의 구분

`tests/run-web-handoff-ownership.sh`는 제품 `WebHandoffOwnership`을 실행해 계정/요청/뷰 identity 변경, 20개 대체 요청, 외부 host·port·userinfo·비TLS·경로 탈출을 검사합니다. 기존 commerce hub, public Arena route, hosted service parity 계약도 유지합니다.

DEBUG `WebHandoffSelfTest.runIfRequested()`는 `-demo -webHandoffSelfTest`에서 **실제 두 WebModel**을 생성합니다. 주입한 transport가 취소를 무시하고 옛 응답을 되돌리게 한 뒤 다음을 확인합니다.

1. 계정 변경이 실제 WKWebView 인스턴스를 교체하고 옛 URL을 거부함.
2. 중지 뒤 응답이 돌아와도 URL load가 없음.
3. 같은 계정의 20개 요청을 역순 완료해도 가장 최근 URL만 적용함.

이 진단의 URL load는 메모리에서 캡처하며 운영 HTTP 요청을 보내지 않습니다. 결과는 `Documents/web-handoff-device-qa.json`입니다. 실제 서버의 세션 쿠키 발급/만료 전체 E2E나 물리 기기 테스트를 대신하지 않습니다.

이후 iPhone 17 / iOS 26.3 시뮬레이터의 `kr.matths.app.uiqa`에서 실행해 두 실제 WebModel 모두 PASS를 확인했습니다. 각 모델의 retiredViewReplaced / oldAccountResponseRejected / stopRejectsLateURL / twentyResponsesLatestOnly가 true입니다. 구현 `Matths.debug.dylib` SHA-256은 `4b8d719bb7a8a6b63a31428841ed5933bcd729eacdec48b35429ade3f7400199`이며, 결과와 manifest/provenance는 workspace `outputs/matths-remaining-0907/ai-qa/web-handoff-*`에 보관했습니다. 이 PASS도 주입 transport의 소유권 검사이며 운영 서버 HTTP E2E는 아닙니다.
