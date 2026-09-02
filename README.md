# Matths iOS / iPadOS 앱 — TestFlight Build 16 기준

이 저장소는 App Store Connect/TestFlight에 제출한 Matths 네이티브 앱의 현재 소스 스냅샷입니다.
별도 iPad 검토용 저장소이지만, 실제 배포 앱과 동작 조건을 맞추기 위해 iPad 전용으로 타깃을
변형하지 않고 iPhone+iPad 유니버설 설정(`TARGETED_DEVICE_FAMILY = "1,2"`)을 그대로 보존했습니다.

## 기준 상태

- 원본 소스 커밋: `2cee63b217f6bdeaa51bdd5a2a8751a48b1f1f38`
- 앱 버전: `1.0 (16)`
- 앱 번들 ID: `kr.matths.app`
- 위젯 번들 ID: `kr.matths.app.widget`
- 지원 OS: iOS/iPadOS 17.0 이상
- 운영 서버: `https://www.matths.kr`
- 포함 타깃: `Matths`, `MatthsWidget`

전체 화면·기능·서버 통신·로컬 AI 구성은
[`PACKAGE-FEATURE-INVENTORY.md`](PACKAGE-FEATURE-INVENTORY.md)에 정리되어 있습니다.
포함/제외 파일과 검증 내역은 [`PACKAGE-MANIFEST.md`](PACKAGE-MANIFEST.md)를 보세요.

## 바로 컴파일하기

1. 저장소를 clone합니다.
2. Xcode에서 `Matths.xcodeproj`를 엽니다.
3. `Matths` 스킴을 선택합니다.
4. 실제 iPhone/iPad 또는 `Any iOS Device (arm64)`를 선택합니다.
5. 로컬 실행은 Run, 배포 검증은 Product > Archive를 실행합니다.

서명 없이 컴파일·링크만 확인하려면 저장소 루트에서 실행합니다.

```bash
xcodebuild \
  -project Matths.xcodeproj \
  -scheme Matths \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

실기기 설치나 Archive 업로드에는 Apple Developer 팀 권한과 해당 번들 ID의 서명 자산이
필요합니다. 프로젝트에는 현재 배포 설정이 보존돼 있으므로, 같은 Apple 팀 권한이 있는
개발자는 Automatic Signing으로 빌드할 수 있습니다.

## 로컬 AI와 llama 프레임워크

`Frameworks/llama.xcframework`에는 실제 iPhone/iPad 배포 앱에 필요한 `ios-arm64` 슬라이스만
포함되어 있습니다. 전체 개발용 857MB XCFramework를 넣지 않았고, 앱이 사용하지 않는
시뮬레이터·macOS·tvOS·visionOS 슬라이스와 dSYM도 제외했습니다.

GGUF 모델 가중치는 저장소와 앱 번들에 포함하지 않습니다. 앱에서 로컬 AI 기능을 처음
준비할 때 지정된 HTTPS 주소에서 내려받고 크기·헤더·SHA-256을 검증합니다.

따라서 이 저장소 상태 그대로 실제 arm64 iPhone/iPad 및 App Store/TestFlight용 빌드가
가능합니다. Apple Silicon/Xcode 시뮬레이터용 llama 슬라이스는 의도적으로 없으므로 로컬 AI가
링크되는 전체 앱을 시뮬레이터 대상으로 빌드하려면 별도 시뮬레이터 프레임워크가 필요합니다.

## 검증

```bash
for test in tests/run-*.sh; do bash "$test"; done
```

패키징 시점에 Release/iphoneos Swift 컴파일, 링크, 앱 번들 생성, llama 임베드가 통과했습니다.
원본 Git 추적 파일 663개와 패키지 파일의 byte 비교도 일치했고, 인증서·프로비저닝 프로필·
운영 비밀번호·`.env`·GGUF·DerivedData·IPA는 포함하지 않았습니다.

## 동일성 범위

소스, 프로젝트 설정, 앱 자산, 위젯, StoreKit 구성, App Store 자료, 검증 스크립트 및 실제
배포용 llama arm64 코드를 기준 스냅샷과 동일하게 제공합니다. 다만 각 개발자가 새로 만든
아카이브는 Apple 서명, 빌드 시각, 새 Git 커밋 정보 때문에 기존 TestFlight 바이너리와
바이트 단위로 동일하지는 않습니다. 사용자에게 보이는 기능과 실행 코드는 같은 기준입니다.
