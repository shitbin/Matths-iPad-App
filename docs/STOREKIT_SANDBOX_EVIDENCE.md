# StoreKit 증거 상태

실제 Sandbox 거래: **NOT_RUN**. 이 파일은 구매·갱신·환불 통과 증명서가 아니다.

상품 ID는 `kr.matths.app.pass.29d`, `kr.matths.app.mock.30d`를 유지했다. 표시 가격은 Product.displayPrice, Matths 권한은 서버 redeem의 granted가 정본이다.

이번 코드 변경:

- purchasing/pendingApproval/redeeming/entitled/recovery를 배타적 상태로 표현.
- 같은 계정·거래의 겹친 redeem을 하나의 Task로 합침.
- Apple 성공 후 서버 미확인은 구매 확인 중으로 표시하고 finish하지 않음.
- 서버 권한 확인 후 finish하고 성공 표시.
- 구매 시트 전·응답 후 계정 자격 재확인, 계정 전환 후 옛 결과 표시 억제.
- 앱 복귀·로그인 때 미완료 거래 재처리 및 entitlement 화면 재조회.
- 상품 재조회 실패 시 기존 localized 가격 보존.

아래는 실제 Apple Sandbox 및 두 Matths 테스트 계정으로 별도 수행해야 한다.

| 항목 | 상태 |
|---|---|
| 두 상품 신규 구매/JWS productId/서버 권한 | NOT_RUN |
| 거래 재사용·다른 계정 귀속 거절 | NOT_RUN |
| pending/사용자 취소/구매 중 계정 전환 | NOT_RUN |
| 응답 유실/종료 후 복구 | NOT_RUN |
| 갱신·만료·환불/revocation | NOT_RUN |
| 재설치·재로그인·복원 | NOT_RUN |
| 운영 Web/App Store Connect/displayPrice 대조 | NOT_RUN |

JWS·비밀번호·Bearer 원문을 이 저장소에 저장하지 않는다. Local StoreKit 구성과 코드 계약 통과로 이 표를 PASS 처리하지 않는다.
