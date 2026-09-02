# Matths iPad 실기 설치·검증

`device-qa.sh`는 기기 이름/UDID를 인자로 받지 않고 환경변수로만 받아 명령 기록에 학생 정보나
서버 비밀을 남기지 않는다. 운영 DB를 수정하는 테스트 계정은 사용하지 않는다.

```text
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh build-install
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh smoke
```

## 8GB 로컬 AI 측정

먼저 앱에서 테스트용 시험지 사진을 한 번 선택해 분석 기록을 만든다. 그 다음 판독기와 추론기를
각각 실행한다.

```text
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh vision vision3B
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh collect
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh vision deepseek7B
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh collect
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh vision ling3-q3
MATTHS_DEVICE="수빈의 iPad" ./device-qa.sh collect
```

ling3-q3는 DEBUG 전용 비교 후보다. 미병합 llama.cpp bailingmoe3 런타임과
고정 SHA의 Q3 가중치를 함께 검증하며, Release 선택지나 사진 판독기로 사용하지 않는다.

수집 파일에는 사진·OCR 결과·학생 계정·오류 경로가 없고 모델명, 로드 시간, 첫 토큰, 처리량,
최대 상주 메모리, 최소 여유 메모리만 들어간다.

`collect`는 복사 직후 JSONL을 다시 읽어 `launch → load-complete → vision-complete` 순서,
비전 준비 상태, 양수인 시간·토큰·메모리 계측을 확인한다. 실패·중단 기록은 통과시키지 않는다.
통과하면 원본 SHA-256과 요약 수치를 `vision-evidence.json`으로 함께 남긴다. 3B와 7B는
서로 다른 `MATTHS_EVIDENCE_DIR`에 수집해 파일이 덮어써지지 않게 한다.

## 수동 실기 증거

1. Google 기존 계정·신규 가입·취소·재시도·앱 복귀
2. 320pt 실제 Split View에서 로그인·홈·커리큘럼·평가·Arena·상점·문제풀이
3. Stage Manager 창 리사이즈와 소프트웨어 키보드·Pencil 도구막대
4. VoiceOver 읽기 순서와 AX5, 200% WebView 확대, Reduce Motion 전환
5. 배치고사 마지막 제출부터 랭크 확정·휘장 모션·사운드
6. 앱 전환, 화면 녹화·미러링 보호, 일반 캡처 워터마크·무결성 이벤트
7. 로컬 AI 분석 중 홈 전환, 메모리 종료 후 재실행·사진 복구, 명시 중단 시 삭제
8. 보호 화면의 막힌 지점을 저장한 뒤 같은 계정의 두 번째 iPad에서 내려받기
9. 서버 계정 진도 초기화 뒤 웹·두 번째 iPad에서 초기화 확인, 그 이후 새 학습은 유지

스크린샷만으로 VoiceOver 순서·프레임 드롭·사운드는 승인하지 않는다. 해당 항목은 짧은 화면 녹화와
비식별 로그를 함께 남긴다.

## 세션 전체 증거 검증

실기 시작 전에 템플릿을 만든다.

```text
MATTHS_EVIDENCE_DIR=/안전한/증거/폴더 ./device-qa.sh session-template
```

22개 시나리오를 수행한 뒤 각 행에 `PASS`, 관찰 기록, 실제 파일과 SHA-256을 채운다. 영상이
필수인 항목을 스크린샷으로 대체하거나, 배치/모션·Arena·복구처럼 로그가 함께 필요한 항목에서
로그를 빼면 통과하지 않는다. 학생 원본 사진·이름·이메일은 증거 폴더에 넣지 않는다.

```text
./device-qa.sh verify-session /안전한/증거/폴더/session.json
```

통과 결과 `device-evidence.json`은 22개 시나리오와 실제 파일 SHA를 고정하며 최종 출시 게이트의
iPad 실기 증거로 사용한다. 템플릿의 `PENDING`을 단순히 바꾸는 것만으로는 파일 검증을 통과할 수
없다.

## Release 감사 빌드

전체 자산·서명 아카이브가 가능한 환경에서는 `--assets compiled --signing signed`로 기록한다.
도구는 embedded provisioning profile을 해독해 development·ad-hoc·enterprise·App Store 배포를
구분하며, 전체 자산과 App Store 배포 프로비저닝이 함께 확인될 때만 `appStoreEligible: true`다.
이 경우 `--signed-archive /path/to/Matths.ipa`도 필수이며, 보고서에 IPA의 SHA-256을 고정한다.
샌드박스 때문에 자산 카탈로그를 제외하거나 서명하지 않은 빌드는 코드·번들 감사에는 쓸 수 있지만
App Store 제출 증거가 아니다.

```text
node scripts/createReleaseAuditEvidence.js \
  --app /Release-iphoneos/Matths.app \
  --build-log /release-build.log \
  --output /evidence/ipad-release-audit.json \
  --assets excluded \
  --signing unsigned
```

보고서는 arm64, 운영 URL, OAuth scheme, KICE 0건, Privacy manifest, 금칙 문자열, 실행 파일·빌드
로그 SHA를 확인하고 `appStoreEligible`과 남은 한계를 별도 기록한다. 또한 현재 iPad 로컬 Git의
commit/tree/추적 파일 clean 여부를 보고서에 고정한다. 다른 checkout에서 빌드할 때는
`--source-root /path/to/ipad-app`을 함께 지정한다.
