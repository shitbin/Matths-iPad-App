# 출시 경계 감사 — 2026-09-08

대상: `2ecb921` 이후의 현재 작업 소스. 범위는 로그인·회원 탈퇴, StoreKit 구매·복원·가격,
개인정보 공개·심사 정보·로컬 AI 배포입니다. 과거 build 16/17/18의 완료 표시는 현재
운영 환경이나 다음 제출 빌드의 통과 증거로 재사용하지 않았습니다.

실제 구매·복원 거래, 계정 탈퇴, 계좌 조회·입력·지급, 운영 설정 변경, App Store Connect
게시, 모델 다운로드, 커밋·푸시는 수행하지 않았습니다. 합성 호스트 검사는 실제 앱 함수와
API 래퍼를 컴파일하되 인증·네트워크·파일 삭제 경계는 테스트 대역만 사용합니다.

## 판정 요약

| 우선도 | 항목 | 확인 수준 | 현재 상태 |
|---|---|---|---|
| P0 | 신규 서비스 원점의 웹 결제 링크가 외부 브라우저로 빠지는 경계 | 다른 담당자의 소스·회귀 재현 | integration_review가 공통 원점·구매 정책 수정 중. 이 감사에서 중복 편집하지 않음 |
| P0 | 저메모리 사진 분석의 Qwen2.5-VL-3B 상업 이용 조건 | Release 코드 도달 경로·공식 라이선스 확인 / 별도 계약 미확인 | 기능·다운로드 경로 그대로. 상업 권리 또는 검증된 대체안 결정 전 출시 승인 불가 |
| P1 | 탈퇴 후 비동기 정리가 새 계정을 로그아웃하거나 재사용 슬롯을 삭제 | 실제 `submit()` 함수의 합성 경합 재현 | 로컬 수정·회귀 통과. 운영 탈퇴 실행은 안 함 |
| P1 | 계좌 확인창 값 변경, 계정 전환 중 자격 혼합, 역순 조회 | 실제 뷰 함수·API 래퍼의 합성 경합 재현 | 로컬 수정·회귀 통과. 실제 계좌 요청은 안 함 |
| P1 | 계좌 수집과 개인정보 선언 불일치 | 실제 입력·전송 경로와 manifest 대조 | 로컬 PaymentInfo·문서 정정 완료. ASC 게시·운영 방침 일치 확인은 남음 |
| P1 | 실제 StoreKit 거래 수명주기·운영 가격 검증 | 코드·로컬 StoreKit 설정만 확인 | 실제 Sandbox 신규 구매/계정 귀속/복원/갱신/환불 미실행 |
| P1 | 카카오톡 네이티브 로그인 등록 정보 | 현재 SDK 미탑재 소스 / 기존 카카오 앱 접근 권한 부재 | 기존 운영 Kakao 앱의 Editor 초대 또는 키·플랫폼 확인 필요. 새 앱 생성 안 함 |
| P1 검토 | 탈퇴 게시글·댓글의 서버 보존 정책 | 로컬 서버에서 본문 숨김·보존 확인 / 운영 최신 상태 미확인 | 최신 서버·보존 근거와 Apple 삭제 요구 대조 필요. 서버 정책 임의 변경 안 함 |
| 제출 전 | 최신 심사 설명·스크린샷·실제 인증·상품 상태 | 과거 자료와 현재 화면이 다름 | 외부 확인·게시 전. 과거 보고서의 저장·제출 완료 주장을 현재 상태로 취급하지 않음 |

## 이번에 수정한 데이터 보호 경계

### 회원 탈퇴

`ProfileScreen.submit()`은 서버 성공 뒤 `stillOwnsSession`을 계산하고 writer 정리를
기다린 뒤에도 그 옛 Bool로 로그아웃했습니다. 해당 await 중 새 B 세션 또는 같은 A
슬롯의 새 세션을 넣었을 때 새 세션 로그아웃·현재 파일 purge가 호출되는 것을 재현했습니다.

이제 정리 직전의 현재 세션 세대를 따로 고정하고, writer 정리 후 그 세대가 유지되는지
검사합니다. A→B→A→B 왕복도 세대 변경으로 감지합니다. 로그아웃은 탈퇴한 세션이 아직
현재일 때만 호출하며, 최종 슬롯 재사용 검사와 purge는 같은 MainActor에서 동기로
이어집니다. 충돌하면 로컬 정리를 보류한다고 표시하며 새 기록을 삭제하지 않습니다.

검사: `tests/run-account-deletion-late-cleanup.sh`. 정상 탈퇴·실패 시 무정리·새 B·새 A·
A→B→A 및 A→B→A→B·안정적인 다른 계정에서 원래 탈퇴 슬롯만 정리하는 경우를 확인합니다.

### 페이백 계좌

`GoatArenaPaybackAccountSheet`는 화면 lifecycle만 비교하고 API 래퍼에서 현재 자격을
읽었습니다. 확인창을 연 뒤 필드를 바꾸거나, 요청 구성 대기 중 세션을 교체하고, 조회
응답을 역순으로 돌려 네 가지 회귀를 재현했습니다.

이제 mounted `AccountRequestOwner`, 확인창의 불변 입력·명령 ID, 필수
`AuthorizationSnapshot`, 최신 GET 요청 ID를 사용합니다. 저장 중 입력을 잠그고,
저장 이전 GET이 나중에 와도 새 저장 결과를 덮지 않습니다. 닫힌 화면·다른 계정의 확인창은
새 요청을 시작하지 못합니다.

검사: `tests/run-payback-account-ownership.sh`. 원본 함수·래퍼의 계정 전환·같은 슬롯
재로그인·확인 값·역순 GET·저장 뒤 오래된 GET·20중복 탭 1요청·이탈 뒤 요청 차단을 확인합니다.

### 개인정보 공개

앱의 `GOAT Arena → 페이백 계좌`에서 은행·예금주·계좌번호를 서버로 전송합니다.
이는 Apple이 처리하는 App Store 카드 정보와 별개입니다. 은행 계좌번호는 Apple의
Payment Info 분류에 해당하므로 기존의 “iOS 앱에서는 받지 않는다”는 설명을 정정했습니다.
[Apple 개인정보 데이터 분류](https://developer.apple.com/app-store/app-privacy-details/)

`PrivacyInfo.xcprivacy`에 PaymentInfo를 계정 연결·비추적·AppFunctionality로 추가했고,
`appstore/app-privacy-ko.md`에 실제 입력·전송 경로와 ASC 게시 미완료 상태를 기록했습니다.
추적·광고·제3자 제공 같은 새로운 용도는 추가하지 않았습니다.

검사: `tests/run-privacy-payment-info-contract.sh`, 기존 플랫폼·필수 사유 검사.

## 구매·가격 확인 결과와 남은 증거

- 로컬 `Matths.storekit`: `kr.matths.app.pass.29d` = 29,000원,
  `kr.matths.app.mock.30d` = 5,500원. 두 상품 모두 P1M 자동 갱신 설정입니다.
- `CommerceHubScreen`의 실제 구매 버튼은 `Product.displayPrice`를 사용합니다.
  학습권의 1개월 청구와 29일 학습 사이클을 구분해 표시합니다.
- `MatthsIAP`는 구매 전 appAccountToken 서버 귀속, 고정 자격, 서버 `granted` 확인 후
  finish, Transaction.updates·unfinished 처리와 복원 경로를 보유합니다.
- 구매 admission 20중복·commerce 경계 계약은 통과했으나 실제 Apple 거래·운영 서버
  권한 변화는 검증하지 않았습니다. `docs/STOREKIT_SANDBOX_EVIDENCE.md`를 PASS로 바꾸지 않습니다.

## AI 모델: 번들 미포함과 사용 허가는 별개

현재 추적 소스에 GGUF 파일은 없습니다. 그러나 `LocalLLM.swift`의 `specVision3B`와
`analysisVisionSpec`은 DEBUG 밖에 있고, 10GiB 미만 기기의 사진 분석은 이 3B 사양을
선택합니다. `ProScreen` → `LocalAIModelPack.prepareForSheetAnalysis()`가 본체·프로젝터를
다운로드하고 추론에 연결하므로, ZIP에서 가중치를 뺐다는 사실만으로 사용 권리 문제가
해결되지는 않습니다.

공식 Qwen2.5-VL-3B 라이선스는 연구·평가 목적의 비상업 사용으로 제한하고 상업 사용에는
별도 라이선스 요청을 명시합니다. 별도 계약의 존재는 확인하지 못했습니다.
[고정 revision의 공식 라이선스](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct/blob/37ce9f696340e294a5d3e0e806466addd1b22b3a/LICENSE)

가능한 다음 단계는 세 가지이며 이번 감사에서 실행하지 않았습니다.

1. 기존 3B 모델에 대한 별도 상업 라이선스·범위를 확인합니다.
2. 인터넷 여건이 나아진 뒤 Apache-2.0인 Qwen3.5-2B 등 후보의 실제 런타임·메모리·판독
   품질을 격리 검증합니다. 라이선스 확인은 품질 통과가 아닙니다.
   [Qwen3.5-2B 공식 라이선스](https://huggingface.co/Qwen/Qwen3.5-2B/blob/15852e8c16360a2fea060d615a32b45270f8a8fc/LICENSE)
3. 출시를 먼저 해야 한다면 해당 사진 분석 경로의 일시 제한과 설명·스크린샷 정정을
   소유자가 결정해야 합니다. 사용자 승인 없이 기능을 임의 삭제하거나 모델을 교체하지 않습니다.

## 심사 자료와 콘텐츠 권리

과거 로컬 반려 조치 보고의 직접 사유는 자동갱신 구독 앱 설명의 EULA 링크 누락입니다.
현재 `appstore/metadata/ko-KR.json` 설명에는 Apple 표준 EULA 링크가 있습니다. 다만
현재 ASC 게시값·실제 반려 원문 화면을 이 감사에서 재조회한 것은 아닙니다.

`appstore/review-notes-ko.md`는 여전히 build 16의 화면·최초 안내를 설명하므로 다음
제출 전에 현행 흐름으로 갱신해야 합니다. 권리 미확인 KICE 원문은 기존 DEBUG 게이트가
유지되며 관련 검사도 통과했습니다. 배포 권리가 확인됐다는 새 선언은 하지 않았습니다.

Apple은 심사 접근 계정, 가동 중인 서버, 정확한 메타데이터와 콘텐츠 사용 권리를
요구합니다. 코드 검사만으로 외부 준비를 완료 처리할 수 없습니다.
[현행 App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

또한 현행 계정 삭제 안내는 게시글 같은 사용자 생성 콘텐츠도 삭제 대상에 포함합니다.
읽은 로컬 서버의 `anonymizePublicActivity`는 본문을 숨겨 DB에 남기므로, 최신 운영
정책과 법적 보존 근거가 있는지 소유자의 별도 검토가 필요합니다. 이 감사를 근거로
기존 서버 데이터를 삭제하지 않았습니다.
[Apple 계정 삭제 FAQ](https://developer.apple.com/support/offering-account-deletion-in-your-app/)

## 새 Release 산출물

build 21의 컴파일·링크 후 마지막 `Embed build provenance` 단계가 미커밋 소스를
거부해 **exit 65로 실패**했습니다. 정상 보호 검사를 우회하지 않았습니다. 아래는
`/private/tmp/matths-polish-b21-release/Build/Products/Release-iphoneos/Matths.app`에
남은 **실패한 빌드의 부분 산출물**만 읽은 결과이며, Release 성공·제출 준비 완료가 아닙니다.

- Info.plist: 1.0 (21).
- 앱 바이너리: 91,031,600바이트.
- 바이너리 SHA-256:
  `89cc8bf7874c39a84fe6b0a53a23cec094f488c2a62b930c2d07ed52f954d1f1`.
- GGUF 파일 0개. 소스 KiceBank의 알려진 원문 PDF 9개 중 번들에서 발견된 파일 0개.
- 3B 모델 파일명은 바이너리에 남아 있습니다. 앞서 확인한 Release 다운로드·실행
  경로의 상업 사용 조건은 해결된 것이 아닙니다.
- 번들의 PaymentInfo 선언은 연결됨=true, 추적=false, 목적=AppFunctionality로
  포함됐고, manifest SHA-256은 현재 소스와 동일합니다:
  `c0a3eadb4689929b1ae4bdd0cc27c63d6a1076874700edc4afcf808ece08bbb1`.
- build provenance 파일 없음. 코드서명·App Store 업로드 검증은 수행하지 않았습니다.

DEBUG를 끈 개발 서명 build 20 설치본 역시 App Store용 Release 서명·제출 완료
증거로 사용하지 않습니다. 최종 소스 확정 후 전체 빌드·provenance·서명 검증을 다시
완료해야 하며, 이 부분 산출물을 그대로 제출 후보로 재사용하면 안 됩니다.
