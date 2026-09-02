# Matths iOS current source package

## 기준 상태

- 생성일: 2026-09-02 (Asia/Seoul)
- iOS source commit: `2cee63b217f6bdeaa51bdd5a2a8751a48b1f1f38`
- commit subject: `chore: restore focused diffs after formatting audit`
- app version/build: `1.0 (16)`
- bundle ID: `kr.matths.app`
- widget bundle ID: `kr.matths.app.widget`
- deployment target: iOS/iPadOS 17.0+
- target device family: iPhone + iPad

## 포함 범위

- 현재 커밋의 Git 추적 파일 663개 전부
- 앱/위젯 Swift 코드 246개
- 앱·위젯·ConceptMotion 자산 파일 1,121개
- Xcode 프로젝트, 공유 스킴, Info.plist, entitlements, StoreKit 구성
- App Store 제출 자산·메타데이터, 문서, 검증·계약 테스트 스크립트
- `Frameworks/llama.xcframework/ios-arm64/llama.framework`
- `PACKAGE-FEATURE-INVENTORY.md`: 전체 화면·기능·통신 목록

패키지 생성 직전 파일 합계는 1,356개, 파일 논리 크기 합계는 약 236.5MB다. 아래 ZIP 검증값은 압축 후 별도로 제공한다.

## llama 프레임워크 범위

전체 개발용 `llama.xcframework`는 넣지 않았다. App Store의 iPhone/iPad Release 앱에 필요한 아래 한 슬라이스만 넣었다.

- library identifier: `ios-arm64`
- architecture: `arm64`
- binary: `llama.framework/llama` (6,430,456 bytes)
- 최소 XCFramework `Info.plist`도 실제 포함 슬라이스 하나만 선언한다.

시뮬레이터, macOS, tvOS, visionOS 슬라이스와 dSYM은 앱 번들에 들어가는 실행 코드가 아니므로 제외했다.

## 의도적으로 제외한 항목

- 모든 `.gguf` 모델 가중치: 0개 포함
- `.git`, DerivedData, `.xcarchive`, `.ipa`, 빌드 캐시
- Xcode 개인 사용자 상태
- 인증서, provisioning profile, Keychain 토큰, 운영 비밀번호
- 서버 저장소 전체

GGUF는 코드에 고정된 HTTPS 주소에서 사용자가 기능을 처음 준비할 때 다운로드되며, 파일 크기·헤더·SHA-256 검증을 거친다.

## 용량 해석

ZIP은 소스·PNG·JSON·음성·동영상과 Mach-O를 압축한 전달 파일이다. TestFlight에 표시되는 값은 서명·최적화된 앱 번들을 기기에 설치하거나 전송하는 기준이므로 ZIP 크기와 같을 필요가 없다. 이 패키지는 압축 전 약 236.5MB의 파일을 가지며, 특히 `ConceptMotion` 약 116MB와 `Matths` 약 98MB를 생략하지 않았다.

## 검증 항목

- 현재 Git 추적 파일 누락 및 byte mismatch: 0
- `.gguf`: 0
- 금지된 `.p12`, `.mobileprovision`, `.xcarchive`, `.ipa`, `.pem`, `.env`: 0
- llama binary: Mach-O arm64
- XCFramework 선언 슬라이스: ios-arm64 한 개
- 패키지 자체 Release/iphoneos Swift 컴파일·링크·앱 번들·llama embed: 통과
- Git 없는 전달 사본용 build provenance·rank 자산 검증: commit/tree/clean 외부 증명값으로 통과

Git 없는 ZIP을 푼 뒤 Release 빌드할 때는 아래 세 값을 함께 제공해야 한다.

```bash
MATTHS_SOURCE_COMMIT=2cee63b217f6bdeaa51bdd5a2a8751a48b1f1f38 \
MATTHS_SOURCE_TREE=d72b0991ff8da8569bcd6529cfd3384fbc15766a \
MATTHS_SOURCE_CLEAN=true \
xcodebuild -project Matths.xcodeproj -scheme Matths -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS'
```
