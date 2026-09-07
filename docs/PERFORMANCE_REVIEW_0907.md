# 성능 재현·수정·계측 — 2026-09-07

## 판정

**ARC-004 전체 완료가 아니라, 재현 가능한 WebView 결함 4종 수정 + 시뮬레이터 프로세스 기준선 확보입니다.** 전 화면 30초 수동 스크롤·최소 지원 실기·에너지·20장 분석 성능은 이 문서의 완료 범위가 아닙니다. 사용자의 최신 지시에 따라 실기는 사용하지 않았습니다.

소스 변경은 `ProblemWebView.swift`, `LessonWebView.swift`, `HintWebView.swift`, `LottieWebView.swift`, `WebContentAccessibility.swift`와 테스트·수동 관찰 도구뿐입니다. 웹·서버, 구매, 평가, AI 엔진은 변경하지 않았습니다.

## 1. 재현한 결함과 수정

| 경로 | 64d9055 기준선에서 실제 재현 | 현재 수정 및 실험 결과 |
|---|---|---|
| 문제·강의 첫 표시 | makeUIView에서 로드한 문서를 초기 updateUIView가 다시 로드. 두 화면 각각 loadFileURL 2회 | 첫 문서 identity를 생성 시 저장. 각각 1회로 감소 |
| 같은 ID 문제의 내용 갱신 | ID가 같으면 발문이 `$x+0$`에서 `$x+1$`로 바뀌어도 옛 발문 유지 | ID·발문·선지·compact 배치의 실제 identity 비교. 새 발문 반영 |
| 힌트·Lottie 내용 교체 | hint-1 요청 후 hint-0 유지, loop=true 요청 후 false 유지 | coordinator가 내용 변경을 감지하여 새 주입 스크립트와 문서를 한 번 교체 |
| 무관한 부모 갱신 | 20회 부모 갱신에 appearance/resize 사건 20~21회 발생 | 같은 배율·모션 값은 문서에서 즉시 반환. 0회. 실제 배율 변경 1.12는 정상 적용 |

SwiftUI의 생성/갱신 수명주기와 업데이트가 초래하는 하위 작업을 분리하는 방향은 [Apple UIViewRepresentable 문서](https://developer.apple.com/documentation/swiftui/uiviewrepresentable), [SwiftUI 성능 분석 문서](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)를 참고했습니다. 결함 판정은 문서 설명이나 정적 패턴만이 아니라 아래 실제 시뮬레이터 실행 결과에 근거합니다.

부가적으로 coordinator의 최신 바인딩을 다시 연결하고 Lottie의 해제 시 로드 중지를 추가했습니다. 기존 메시지 핸들러 제거 계약을 유지했습니다. MathInline/KaTeXLabel은 중복 첫 로드를 확인하지 않았고 기존 평문 fallback이 있어 변경하지 않았습니다.

## 2. 실제 WKWebView 전후 실험

- 기기: iPhone 17 시뮬레이터, iOS 26.3.
- 컴파일러: Xcode 26.6 / iPhoneSimulator 26.5 SDK.
- 앱: 별도 `kr.matths.performance.webview` 테스트 앱. 운영 앱·사용자 슬롯과 분리.
- 실제 네 개 representable 소스를 컴파일하고 WKWebView만 계수용 subclass로 치환합니다. UI actor 검사를 위해 standalone harness의 기본 격리는 MainActor입니다.
- 실제 번들 LessonWeb·RankBadges 파일을 사용합니다. GeneratedProblem은 이 렌더러에서 읽는 ID·발문·선지만 포함한 테스트 값입니다.
- 각 화면의 첫 표시→부모 갱신 20회→실제 글자 크기 변경→내용 변경→제거. 이후 문제 화면 삽입·제거 10회.
- 서버 계정·네트워크·공식 진도는 사용하지 않습니다.

| 관측 | 기준선 | 현재 |
|---|---:|---:|
| 불변식 실패 | 9 | 0 |
| 문제 첫 로드 | 2 | 1 |
| 강의 첫 로드 | 2 | 1 |
| 부모 20회 갱신에 불필요한 appearance 사건 | 화면별 20~21 | 모든 화면 0 |
| 10회 문제 재진입의 추가 문서 로드 | 20 | 10 |
| 매번 제거 후 남은 WKWebView | 0 | 0 |
| 전체 harness CPU 시간 | 1.654416초 | 1.718303초 |
| 전체 harness wall 시간 | 26.250367초 | 26.622589초 |

**CPU나 전체 속도가 개선됐다는 결론은 내리지 않습니다.** 현재 버전은 기존에 누락되던 힌트·Lottie·같은 ID 문제 내용 교체도 실제 수행합니다. 총 실행 작업량이 다르고 공유 Mac 부하도 존재합니다. 성공 근거는 중복 작업 감소·내용 정합성·해제 불변식이며, 한 번의 시간 차이는 성능 개선 통계가 아닙니다.

측정 중 프로세스 RSS는 WebKit 별도 프로세스를 포함하지 않습니다. 현재 10회 루프의 마지막 RSS는 첫 루프보다 작았지만 이를 전체 앱 무누수 판정으로 확장하지 않습니다.

원본 증거(작업 산출물의 `performance/`):

- `webview-baseline-v2.json`: source `64d9055`, FAIL 9개, 테스트 바이너리 SHA-256 `bd1bc7a41e1fe80e7cda1ab414c3fc09ef17e1cef2a4b0395beb405d53dd722c`.
- `webview-current-v2.json`: 파일별 소스 SHA 포함, PASS, 테스트 바이너리 SHA-256 `047f635b08450aff1a4092bca1b684bf4e984ae0ffc12f8ce2881d295df5c910`.
- 이전 `webview-baseline.json`/`webview-current.json`은 ID 교체 중심의 1차 실험입니다. 최종 판정은 같은 ID의 내용 교체와 배율 변경까지 포함한 v2를 사용합니다.

재현:

```sh
MATTHS_WEBVIEW_BASELINE_REF=64d9055 node tools/run-webview-performance.mjs SIMULATOR_UUID /tmp/webview-baseline.json
node tools/run-webview-performance.mjs SIMULATOR_UUID /tmp/webview-current.json
sh tests/run-webview-appearance-contract.sh
sh tests/run-webview-lifecycle-contract.sh
sh tests/run-webcontent-accessibility.sh
```

현재 테스트는 불변식 실패 시 0이 아닌 상태로 종료합니다. 기준선은 실패를 증거로 남기기 위해 결과 FAIL을 저장하되 runner 자체는 정상 종료합니다.

## 3. 실제 앱 프로세스 기준선

별도 검증용 `kr.matths.app.uiqa` 앱을 `-demo -route today`로 10회 재실행했습니다. 각 실행 뒤 0.5초 간격으로 3초간 CPU/RSS를 읽고, 마지막 실행에서 30초 정지 관찰을 추가했습니다.

- build 17 Debug, 소스 provenance `64d9055`, **working tree clean=false**. 원본 커밋 그대로인 바이너리라고 주장하지 않습니다.
- 실제 측정 바이너리 SHA-256: `bb9c24c203bf68d3032a9ec2118303bed1eb25a6c69d192ec6ebd9f5b58cb3f7`.
- 재실행 명령 완료 시간: P50 **478.740ms**, P95 **676.047ms** (표본 10회, nearest-rank).
- 프로세스 RSS 관측 최대: **438,730,752 bytes (418.4MiB)**.
- 마지막 30초 정지 관찰: 누적 CPU **1.50초**, RSS 변화 **-23,019,520 bytes**.
- 전체 표본: `performance/app-process-baseline.json`.

이 시간은 **simctl 명령·기존 프로세스 종료를 포함하는 프로세스 실행 명령 완료 시간**입니다. 첫 사용 가능 UI, 첫 프레임, fresh dashboard, OS 캐시가 비어 있는 실기 cold launch 시간이 아닙니다. 유저에게 “앱 실행 0.48초”로 보고하면 잘못입니다. RSS/CPU는 확장 및 WebKit 보조 프로세스를 제외합니다. 전후 같은 조건의 앱 바이너리 비교는 아직 없습니다.

재현:

```sh
node tools/measure-simulator-process.mjs SIMULATOR_UUID /tmp/app-process.json
```

## 4. Instruments 시도와 한계

- `xctrace record --template 'Time Profiler' --device <iPhone17 simulator> --attach <pid> --time-limit 10s`는 시작 메시지 이후 지정 시간을 넘겨 종료되지 않았습니다. 2분 이상 대기 뒤 SIGINT, 이어 SIGTERM으로 해당 계측 프로세스만 중단했습니다.
- 부분 trace의 export는 `Document Missing Template Error`로 실패했습니다.
- 시뮬레이터 프로세스에 host attach하는 대안도 `Cannot find process for provided pid`로 실패했습니다. 이때 `ps`에는 해당 프로세스가 존재했으므로 host의 대상 해석과 시뮬레이터 대상이 일치하지 않았습니다.
- 따라서 Instruments Time Profiler/Allocations/Hitches/Energy 완료로 계산하지 않습니다. 부분 trace를 성능 증거로 쓰지 않습니다.

## 5. 실제 화면 수동 관찰 도구

`AppScrollPerformanceSelfTest.swift`는 DEBUG·데모·명시 플래그 세 조건에서만 작동합니다. **route, scroll offset, 입력을 변경하지 않습니다.** CUA나 사람이 시뮬레이터에서 직접 수행한 동작을 수동 관찰합니다.

루트 DEBUG task의 훅:

```swift
await AppScrollPerformanceSelfTest.runIfRequested(store: store)
```

실행 예:

```sh
xcrun simctl launch --terminate-running-process SIMULATOR_UUID kr.matths.app.uiqa -demo -route today -scrollPerformanceSelfTest -performanceScreen today
```

rank prewarm 대기 후 준비 시간 5초, 관찰 30초이며 `Documents/app-scroll-performance.json`에 저장합니다. 운영자는 그동안 해당 화면을 CUA로 스크롤하고 별도 동작·스크린샷 기록을 남겨야 합니다. 다음 화면을 검사하기 전 결과 파일을 화면명별로 복사해 보존합니다.

- 기록: CADisplayLink callback gap P50/P95/max, 50/100ms 이상 gap, 실제 관측한 offset 변화 수, 콘텐츠/뷰포트 높이, 프로세스 CPU/RSS.
- offset 변화가 없다면 `STATIC_OBSERVATION_NO_OFFSET_CHANGES`이며 스크롤 검수로 세지 않습니다.
- callback gap은 메인 run-loop 관찰이며 GPU 렌더 완료/hitch와 같지 않습니다.
- 스크롤 뷰 탐색과 RSS 표본 자체에 소량 관측 오버헤드가 있습니다.
- 도구의 Swift 5 시뮬레이터 typecheck는 통과했습니다. 화면별 수동 실행 결과가 만들어지기 전에는 30초 스크롤 완료 판정을 하지 않습니다.

## 6. 미완료·후속 후보

1. 홈·커리큘럼·오답·Arena의 CUA 수동 30초 관찰과 동일 빌드/환경의 반복 분포.
2. 첫 사용 가능 UI·fresh dashboard의 실제 준비 사건 및 Network 요청 계수. 프로세스 명령 시간으로 대체하지 않음.
3. 전체 앱 10회 화면 왕복에서 Task/Timer/요청의 수명 계수. 현재 완료한 것은 네 개 번들 WebView와 문제 10회 재진입의 인스턴스 해제만임.
4. 20장 AI 분석·취소·재시작·모델 교체 메모리. 이번 범위에서 실행하지 않음.
5. 실기 성능·열·에너지 및 최소 기기 예산. 사용자의 시뮬레이터 전용 지시로 미실행.
6. 시작 시 모든 rank 9티어의 합성 prewarm과 최대 220MiB 이미지 캐시가 존재함. 첫 승급 hitch 방지를 위한 기존 구현이므로 측정 없이 제거하지 않았음. 해당 비용과 사용자 첫 행동 지연의 상관을 확인해 지연 시작/범위 축소를 결정해야 함.
7. 루트 첫 task와 scene active 양쪽의 `refreshServerProfile()` 요청은 전용 single-flight가 없었음. 계정 경계 보호와 별도로 중복 요청 측정/병합을 검토하도록 root 담당자에게 전달함.

이번 변경의 되돌림 단위는 다섯 WebView 관련 파일입니다. 테스트·관찰 도구는 DEBUG/독립 harness 경계이므로 프로덕션에서 자동 실행되지 않습니다.
