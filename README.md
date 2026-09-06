# Matths iPhone·iPad — 2026-09-07 검수 개선본

현재 main은 기존 전달 소스 2cee63b를 수정한 **1.0 (17)** 개발본입니다. 기존 TestFlight 빌드와 코드가 달라졌으며, 이 개선본을 TestFlight/App Store에 업로드한 상태는 아닙니다.

공개 과목·공식 평가·진도 정합성, 학생의 오늘/학습/Arena/기록/나 흐름, 적응형 문제·메모 작업대, 비밀번호 변경 및 웹 파생 자산 생성 도구를 포함합니다.

## 먼저 읽기

- [검증 결과와 남은 출시 조건](docs/RELEASE_PARITY_VERDICT.md)
- [화면·학습 흐름 변경](docs/UX_CHANGES_0907.md)
- [웹 정본과 iOS 소유권](docs/BUSINESS_AUTHORITY_MAP.md)
- [공개 과목 계약](docs/COURSE_AVAILABILITY_CONTRACT.md)
- [공식 평가·연습·메모 경계](docs/ASSESSMENT_OFFICIAL_PRACTICE_BOUNDARY.md)
- [실제 StoreKit 거래 증거 상태](docs/STOREKIT_SANDBOX_EVIDENCE.md)
- [웹 생성 자산 manifest](WEB_DERIVED_ASSET_MANIFEST.json)
- [기존 전체 기능 목록](PACKAGE-FEATURE-INVENTORY.md)

## 실기기용 컴파일

Xcode와 Node.js 24 이상이 필요합니다. 계약 검사를 실행하려면 ripgrep(`rg`)도 설치되어 있어야 합니다. Xcode 빌드 단계에서도 Node 경로를 찾을 수 있어야 하며, 필요한 경우 `NODE_BINARY` 빌드 설정으로 지정할 수 있습니다.

Xcode에서 Matths.xcodeproj를 열고 Matths 스킴, 실제 iPhone/iPad 또는 Any iOS Device (arm64)를 선택합니다. 배포 타깃은 iOS/iPadOS 17+, 번들 ID는 kr.matths.app, 위젯은 kr.matths.app.widget, 서버는 https://www.matths.kr입니다.

```bash
xcodebuild -project Matths.xcodeproj -scheme Matths -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Release는 clean Git checkout을 요구합니다. 실제 설치·Archive 업로드에는 원래 Apple Developer 팀의 서명 권한이 필요합니다. 서명·거래·서버·실기 검증은 컴파일 성공과 별개입니다.

## llama와 모델

저장소에는 배포용 ios-arm64 llama 프레임워크만 포함합니다. 전체 개발용 XCFramework, GGUF, 인증서, 프로비저닝 프로필, 운영 비밀번호는 포함하지 않습니다. GGUF는 앱의 모델 준비 흐름에서 검증 후 내려받습니다.

배포 바이너리에서 확인된 llama 원본은 db4480bc802dda303627830833e0e6c2a7c47297입니다. 시뮬레이터 QA는 해당 원본에서 별도로 빌드한 arm64-simulator 프레임워크와 tools/prepare-uiqa-project.mjs로 생성하는 무시된 QA 프로젝트를 사용합니다. 배포 프로젝트의 라이브러리와 번들 ID를 변경하지 않습니다.

## 검증·웹 자산 재생성

웹 원본은 is4553807/Matths-Official의 e3cc06360415a4c60460895b01f06a3248dae665를 읽기 전용으로 사용합니다.

```bash
npm ci --prefix tools --ignore-scripts --no-audit --no-fund
node tools/verify-web-derived-assets.mjs /path/to/exact-web-checkout
MATTHS_WEB_REPO=/path/to/exact-web-checkout node scripts/run-contract-suite.mjs /tmp/matths-test-results
```

원본에서 자산을 갱신할 때:

```bash
node tools/generate-web-derived-assets.mjs --web-root /path/to/exact-web-checkout
node scripts/auditCurriculumEditorial.js
```

생성기는 실제 Web YAML·정책·문제 생성기를 입력으로 쓰고, 앱의 강의 설명·레거시 연결은 별도 native-curriculum-overlay.json으로 보존합니다. 동일 입력의 두 번 생성 결과와 hash를 검증하며 웹 저장소에는 쓰지 않습니다.

## 이전 전달본

원본 소스 기준은 2cee63b217f6bdeaa51bdd5a2a8751a48b1f1f38이고, 최초 GitHub 전달 커밋은 726762f7b13614932ccaac866752b5538ed0bba2입니다. PACKAGE-MANIFEST.md는 그 원본 ZIP의 역사적 기록입니다. 현재 소스의 출시 판단에는 위 최신 검증 문서를 사용하세요.
