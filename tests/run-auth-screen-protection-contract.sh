#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODULE_CACHE="${TMPDIR:-/tmp}/matths-screen-integrity-module-cache"
CASES_BIN="${TMPDIR:-/tmp}/matths-screen-integrity-contract-cases"

mkdir -p "$MODULE_CACHE"
xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT/Matths/ScreenIntegrityEventContract.swift" \
  "$ROOT/Matths/DataScope.swift" \
  "$ROOT/tests/ScreenIntegrityEventContractCases.swift" \
  -o "$CASES_BIN"
"$CASES_BIN"

grep -q 'static let defaultURL = "https://www.matths.kr"' "$ROOT/Matths/ServerAPI.swift"
! grep -q 'static let defaultURL = "https://matths.kr"' "$ROOT/Matths/ServerAPI.swift"
! grep -q 'trycloudflare.com' "$ROOT/Matths/ServerAPI.swift"
grep -q 'ASWebAuthenticationSession' "$ROOT/Matths/GoogleSignInCoordinator.swift"
# 소셜 코드 교환은 **서버를 지나야 한다** — 앱이 provider 토큰을 직접 다루면
# 그 순간 기기에 장기 자격증명이 남는다. 주소는 provider 중립으로 바뀌었지만
# (2026-08-22, 카카오가 같은 경로를 씀) 지키는 계약은 그대로다.
grep -q '/api/v1/auth/social/exchange' "$ROOT/Matths/ServerAPI.swift"
grep -q '<string>matths</string>' "$ROOT/Info.plist"
grep -q 'UIScreen.capturedDidChangeNotification' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'UIScreen.main.isCaptured' "$ROOT/Matths/ScreenshotGuard.swift"
grep -Fq '@Environment(\.isSceneCaptured)' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'setSceneCaptureState(isSceneCaptured)' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'setSceneCaptureState(captured)' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'UIApplication.willResignActiveNotification' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'UIApplication.didBecomeActiveNotification' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'protected-screen-screenshot' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'protected-screen-capture-started' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'enqueueIntegrityEvent' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'integritySessionCode' "$ROOT/Matths/SyncEngine.swift"
grep -q 'protectedSurface' "$ROOT/Matths/SyncEngine.swift"
grep -q 'ProtectedContentWatermark' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'accountWatermarkCode' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'screenProtectionAccountCode' "$ROOT/Matths/DataScope.swift"
grep -q '@State private var id = UUID()' "$ROOT/Matths/ScreenshotGuard.swift"
! grep -q 'private let id = UUID()' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'screenProtectionLayer(guardModel: screenshotGuard)' "$ROOT/Matths/MatthsApp.swift"
grep -q 'protectedAssessmentPresentation' "$ROOT/Matths/GoatArenaScreen.swift"
grep -q 'guardModel: screenshotGuard' "$ROOT/Matths/GoatArenaScreen.swift"
grep -q 'ScreenProtectionSelfTest.runIfRequested' "$ROOT/Matths/MatthsApp.swift"
grep -q 'serverSyncSuppressed: true' "$ROOT/Matths/ScreenProtectionSelfTest.swift"
grep -q 'MATTHS_SCREEN_PROTECTION_DEVICE_QA_V1' "$ROOT/Matths/ScreenProtectionSelfTest.swift"
grep -q 'runIntegrityQueueDeviceQA' "$ROOT/Matths/ScreenProtectionSelfTest.swift"
grep -q 'queuePayloadPreserved' "$ROOT/Matths/ScreenProtectionSelfTest.swift"
grep -q 'repeatedScreenshotRecorded' "$ROOT/Matths/ScreenProtectionSelfTest.swift"
grep -q 'accountWatermarkPseudonymous' "$ROOT/Matths/ScreenProtectionSelfTest.swift"
grep -q 'loadQueue(at: url, quarantineURL: nil)' "$ROOT/Matths/SyncEngine.swift"
grep -q 'simulateScreenshotForDeviceQA' "$ROOT/Matths/ScreenshotGuard.swift"
if grep -q '답을 찾으러 갈 시간' "$ROOT/Matths/ScreenshotGuard.swift"; then
  echo "student-blaming screenshot copy must not return" >&2
  exit 1
fi
grep -q 'guardModel.isPrivacyCoverActive' "$ROOT/Matths/ScreenshotGuard.swift"
grep -q 'protectedAssessmentPresentation' "$ROOT/Matths/GoatArenaScreen.swift"
for screen in KiceExamScreen AssessmentPaperScreen PlacementExamScreen WeeklyMockScreen; do
  if ! perl -0ne "exit 0 if /${screen}\\(\\)[\\s\\S]{0,140}\\.protectedAssessmentSurface\\([^)]*\\)/; exit 1" \
      "$ROOT/Matths/RootView.swift"; then
    echo "$screen must use the shared protected assessment surface" >&2
    exit 1
  fi
done
# ── 사전 차단(secure canvas) ────────────────────────────────────────────────
#
# 이 자리에는 원래 다음 금지가 있었다:
#     ! grep -R -q 'isSecureTextEntry.*screenshot\|screenshot.*isSecureTextEntry' "$ROOT/Matths"
#
# 근거는 ScreenshotGuard.swift 주석의 두 주장이었다 — "심사에서 거절된다",
# "VoiceOver 를 깨뜨린다". 재검증 결과 둘 다 근거가 확인되지 않아 금지를 뒤집는다.
#   - 심사: Apple 의 문장은 "There's no supported way to prevent screen captures"
#     (지원하지 않는다)이지 거절한다가 아니다. 해당 가이드라인 조항도 거절 사례도 없다.
#   - 접근성: 뷰가 아니라 레이어만 재부모화하면 UIView 트리가 그대로 남아
#     VoiceOver 순서와 hit testing 이 보존된다.
#
# 반면 확인된 진짜 위험은 "iOS 메이저 업데이트에서 조용히 풀린다"이다
# (Apple Developer Forums 767320 — iOS 18 파손 보고). 조용한 파손은 금지로 막히지
# 않고 계측으로만 막힌다. 그래서 금지 대신 아래 셋을 단언한다.
#   (a) 런타임 프로브가 존재하고 실제 픽셀을 검사할 것
#   (b) .degraded 폴백 경로가 존재하고 .verified 만 통과시킬 것
#   (c) 보호 범위가 문제 푸는 화면으로 한정될 것

SECURE_CANVAS_FILE="$ROOT/Matths/SecureCaptureCanvas.swift"
SECURE_PROBE_FILE="$ROOT/Matths/SecureCanvasProbe.swift"

# 기법은 전용 파일 한 곳에만 둔다. 앱 곳곳에 흩어지면 프로브 게이트를 우회하는
# 경로가 생기고, 다음 iOS 에서 어디가 풀렸는지 추적할 수 없다.
secure_users="$(grep -Rl 'isSecureTextEntry *=' "$ROOT/Matths" | sort | tr '\n' ' ' || true)"
if [ "$secure_users" != "$SECURE_CANVAS_FILE " ]; then
  echo "isSecureTextEntry must live only in SecureCaptureCanvas.swift (found: $secure_users)" >&2
  exit 1
fi

# (a) 프로브 — 마커를 넣고 스냅샷 픽셀에서 사라지는지 실제로 잰다.
#
# 2026-08-17: 스냅샷을 layer.render(in:) 로 뜨던 것을 drawHierarchy 로 바꿨다.
# layer.render(in:) 는 레이어 트리를 직접 그려 secure canvas 의 캡처 제외를
# **무시하고** 마커를 그대로 찍는다. 그래서 보호가 멀쩡한 기기에서도 언제나
# "marker-visible-in-snapshot" 이 나왔고, 그 판정이 디스크에 굳어 기능이 영구히
# 꺼졌다. 사용자가 "여전히 정상 저장됨" 이라고 보고한 것이 이것이다.
#
# 종전 검사는 그 잘못된 API 를 리터럴로 못박고 있었다. 지켜야 할 것은
# "시스템 렌더 경로로 잰다" 이지 특정 API 이름이 아니다.
grep -q 'UIGraphicsImageRenderer' "$SECURE_PROBE_FILE"
grep -q 'drawHierarchy(in:' "$SECURE_PROBE_FILE"
if grep -q 'layer.render(in: context.cgContext)' "$SECURE_PROBE_FILE"; then
  echo "프로브가 layer.render(in:) 로 되돌아갔습니다 — 캡처 제외를 무시해 항상 degraded 로 떨어집니다" >&2
  exit 1
fi
grep -q 'containsMarker' "$SECURE_PROBE_FILE"
grep -q 'case verified' "$SECURE_PROBE_FILE"
grep -q 'case degraded(reason: String)' "$SECURE_PROBE_FILE"
grep -q 'case unavailable(reason: String)' "$SECURE_PROBE_FILE"
# 대조 렌더가 비어 있으면 "보호됨"이 아니라 "측정 불가"다. 거짓 양성 차단.
grep -q 'probe-control-render-blank' "$SECURE_PROBE_FILE"
# 시뮬레이터는 캡처 제외를 재현하지 않는다. .unavailable 이 정상이므로 CI 는
# 여기에서 PASS 를 요구하지 않는다.
grep -q 'targetEnvironment(simulator)' "$SECURE_PROBE_FILE"
grep -q 'unavailable(reason: "simulator")' "$SECURE_PROBE_FILE"
# 결과 캐시 키는 OS 버전 + 앱 빌드. 화면 진입마다 다시 재면 안 된다.
grep -q 'UIDevice.current.systemVersion' "$SECURE_PROBE_FILE"
grep -q 'CFBundleVersion' "$SECURE_PROBE_FILE"
grep -q 'SecureCanvasProbe.warmUp()' "$ROOT/Matths/MatthsApp.swift"

# (b) 폴백 — 프로브가 통과시키지 않으면 아무것도 재부모화하지 않는다.
grep -q 'SecureCanvasProbe.allowsSecureCanvas' "$SECURE_CANVAS_FILE"
grep -q 'reportRuntimeFailure' "$SECURE_CANVAS_FILE"
grep -q 'reportRuntimeFailure' "$SECURE_PROBE_FILE"
# 재부모화는 UIKit 이 보는 뷰 트리도 바꾼다(subviews 는 layer.sublayers 에서 되읽힌다).
# 그래서 화면이 여전히 만져지는지 런타임에서 확인하고, 깨졌으면 즉시 되돌린다.
# 이 단언이 없으면 "보호는 되는데 시험 화면을 터치할 수 없는" 빌드가 나갈 수 있다.
grep -q 'runtime-input-tree-broken' "$SECURE_CANVAS_FILE"
grep -q 'window.hitTest' "$SECURE_CANVAS_FILE"
grep -q 'override func hitTest' "$SECURE_CANVAS_FILE"
grep -q 'isAccessibilityElement = false' "$SECURE_CANVAS_FILE"

# (c) 범위 — 보호 중일 때만 켜진다. 앱 전체 상시 적용은 금지.
# 2026-08-17(2차): secure canvas 를 껐다. 스크린샷을 막지 못하면서 제어센터만
# 내려도 화면을 통째로 덮는 사고를 냈고, Apple DTS 도 이 우회를 쓰지 말라고 했다.
# 배선이 살아 있는지가 아니라 **꺼져 있는지** 를 본다.
# 다시 켜지는 것을 막는 검사는 run-screenshot-protection-scope-contract.sh 가 맡는다.
grep -q 'secureCaptureCanvas(isActive: false)' "$ROOT/Matths/ScreenshotGuard.swift"
! grep -R -q 'secureCaptureCanvas(isActive: true)' "$ROOT/Matths"
grep -q 'store.isProblemSolvingRoute, initial: true' "$ROOT/Matths/MatthsApp.swift"
grep -q 'route == .quickPractice' "$ROOT/Matths/MatthsApp.swift"

python3 - "$SECURE_CANVAS_FILE" "$SECURE_PROBE_FILE" "$ROOT/Matths/MatthsApp.swift" <<'PY'
from pathlib import Path
import re
import sys

canvas = Path(sys.argv[1]).read_text(encoding="utf-8")
probe = Path(sys.argv[2]).read_text(encoding="utf-8")
app = Path(sys.argv[3]).read_text(encoding="utf-8")

# 레이어만 재부모화한다. 보호 대상을 canvas 의 subview 로 넣으면 접근성 트리와
# SwiftUI 레이아웃이 함께 끌려간다 — 금지를 뒤집은 전제 자체가 무너진다.
attach_start = canvas.index("static func attach(content: CALayer")
attach_end = canvas.index("static func renormalize(", attach_start)
attach = canvas[attach_start:attach_end]
if "addSublayer(content)" not in attach:
    raise SystemExit("protected content must be reparented as a layer, not a view")
if "addSubview" in attach:
    raise SystemExit("secure canvas attach must not touch the view hierarchy")

# 되돌리는 경로가 없으면 화면을 떠난 뒤 레이어가 남의 canvas 안에 남는다.
for required in ("static func detach(", "willMove(toWindow", "dismantleUIView"):
    if required not in canvas:
        raise SystemExit(f"secure canvas teardown is missing {required}")

# 숨은 필드에 accessibilityElementsHidden 을 걸면 안 된다. 재부모화 뒤 앱 콘텐츠가
# 이 필드의 자손으로 읽히므로, 그 값을 켜는 순간 화면 전체가 VoiceOver 에서 사라진다.
field_start = canvas.index("static func makeSecureField()")
field_end = canvas.index("static func canvasLayer(", field_start)
field = canvas[field_start:field_end]
if "isAccessibilityElement = false" not in field:
    raise SystemExit("the hidden secure field must not be an accessibility element itself")
if "accessibilityElementsHidden =" in field:
    raise SystemExit("hiding the secure field's descendants would hide the whole screen from VoiceOver")

# .verified 하나만 통과시킨다. .degraded / .unavailable 은 모두 폴백이다.
allows_start = probe.index("var allowsSecureCanvas: Bool")
allows_end = probe.index("}", probe.index("return false", allows_start))
allows = probe[allows_start:allows_end]
if "case .verified" not in allows or "return false" not in allows:
    raise SystemExit("only a verified probe result may enable the secure canvas")
for forbidden in ("case .degraded", "case .unavailable"):
    if forbidden in allows:
        raise SystemExit("degraded/unavailable probe results must never enable the secure canvas")

# 보호 범위는 isSessionMode 와 분리된 판정으로 정한다. isSessionMode 는 RootView 의
# sessionContent switch 와 1:1로 묶여 있어서 .quickPractice 를 넣으면 그 화면이
# EmptyView 로 사라진다(RootView.swift 의 sessionContent 에 분기가 없다).
session_start = app.index("var isSessionMode: Bool")
session_end = app.index("\n    }", session_start)
if ".quickPractice" in app[session_start:session_end]:
    raise SystemExit("isSessionMode drives RootView.sessionContent; add protection scope separately")
# 2026-08-17(2차): 보호 범위를 문제 푸는 동안으로 되돌렸다.
# 전 화면 확장은 제어센터만 내려도 화면이 검게 덮이는 사고를 냈고 스크린샷은
# 못 막았다. 원래 판정으로 복귀했으므로 검사도 원래 보장으로 되돌린다.
solving_start = app.index("var isProblemSolvingRoute: Bool")
solving_end = app.index("\n    }", solving_start)
solving_body = app[solving_start:solving_end]
if "isSessionMode" not in solving_body or ".quickPractice" not in solving_body:
    raise SystemExit("problem-solving protection scope must keep every session screen")
if not re.search(r"onChange\(of: store\.isProblemSolvingRoute", app):
    raise SystemExit("base screen protection must follow the problem-solving scope")
PY

# ── surface 라벨 계약 ───────────────────────────────────────────────────────
# 화면이 넘기는 라벨이 화이트리스트에 없으면 조용히 "protected" 로 뭉개져서
# 어느 화면에서 찍혔는지 서버가 알 수 없다. 실제로 goat-arena-match 가 그랬다.
python3 - "$ROOT/Matths" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
contract = (root / "ScreenIntegrityEventContract.swift").read_text(encoding="utf-8")
block = contract[contract.index("allowedSurfaces"):contract.index("static func normalizedEventType")]
allowed = set(re.findall(r'"([a-z0-9-]+)"', block))

# rglob 인 이유 — 예전에는 glob("*.swift") 로 **최상위만** 훑었다. 그래서
# ArenaWeb/ 하위의 goat-arena-web 라벨이 검사에서 통째로 빠졌고, 그 라벨이
# 화이트리스트에 없어 아레나 웹 경기의 캡처 신호가 protected 로 뭉개졌다.
# 이 테스트가 잡으라고 있는 바로 그 결함을 이 테스트의 사각지대가 숨긴 것이다.
used = set()
for path in sorted(root.rglob("*.swift")):
    source = path.read_text(encoding="utf-8")
    for pattern in (
        r'protectedAssessmentSurface\(\s*"([^"]+)"',
        r'protectedAssessmentPresentation\(\s*"([^"]+)"',
        r'beginProtection\([^,]+,\s*surface:\s*"([^"]+)"',
        # 화면이 리터럴 대신 이름 붙은 상수로 넘기는 경우(ArenaWebDestination).
        # 리터럴만 보면 변수 한 겹에 가려 영영 안 잡힌다.
        r'protectionSurfaceName[^"\n]*"([^"]+)"',
    ):
        used.update(re.findall(pattern, source))

missing = sorted(used - allowed)
if missing:
    raise SystemExit(f"surface labels passed by screens but not whitelisted: {missing}")
if "goat-arena-match" not in allowed:
    raise SystemExit("GoatArenaScreen passes goat-arena-match; the whitelist must accept it")
PY

python3 - "$ROOT/Matths/ScreenshotGuard.swift" "$ROOT/Matths/SyncEngine.swift" <<'PY'
from pathlib import Path
import sys

guard_source = Path(sys.argv[1]).read_text(encoding="utf-8")
sync_source = Path(sys.argv[2]).read_text(encoding="utf-8")

screenshot_start = guard_source.index("private func handleScreenshotDetected()")
screenshot_end = guard_source.index("#if DEBUG", screenshot_start)
screenshot_body = guard_source[screenshot_start:screenshot_end]
if "recordIntegrityEvent" not in screenshot_body:
    raise SystemExit("every protected screenshot notification must be recorded, including repeats")
for forbidden in ("isShowing = true", "UINotificationFeedbackGenerator"):
    if forbidden in screenshot_body:
        raise SystemExit("post-screenshot notification must not interrupt or punish the student")

enqueue_start = sync_source.index("func enqueueIntegrityEvent(")
enqueue_end = sync_source.index("/// 평가·기출", enqueue_start)
enqueue_body = sync_source[enqueue_start:enqueue_end]
for forbidden in ("email", "school", "accountWatermarkCode", "DataScope.slot", "matchId", "questionId"):
    if forbidden in enqueue_body:
        raise SystemExit(f"integrity payload must not include {forbidden}")
PY

python3 - "$ROOT/Matths/ScreenshotGuard.swift" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
layer_start = source.index("struct ScreenProtectionLayer: View")
layer_end = source.index("private struct ScreenProtectionLayerModifier", layer_start)
layer = source[layer_start:layer_end]
if "ScreenshotGuardOverlay" in layer or "guardModel.isShowing" in layer:
    raise SystemExit("post-screenshot punitive modal must not cover the student's work")
for required in (
    "@Environment(\\.isSceneCaptured)",
    "guardModel.isCaptureActive",
    "guardModel.isPrivacyCoverActive",
    "CapturePrivacyCover()",
    "guardModel.accountWatermarkCode",
    "guardModel.watermarkCode",
    "setSceneCaptureState(isSceneCaptured)",
    "setSceneCaptureState(captured)",
):
    if required not in layer:
        raise SystemExit(f"shared screen protection layer is missing {required}")

watermark_start = source.index("struct ProtectedContentWatermark")
watermark_end = source.index("struct ScreenshotGuardOverlay", watermark_start)
watermark = source[watermark_start:watermark_end]
if "ForEach" in watermark or "rotationEffect" in watermark:
    raise SystemExit("watermark must stay in one quiet region instead of repeating over problems")
for required in ("bottomTrailing", "opacity(0.035)"):
    if required not in watermark:
        raise SystemExit(f"quiet regional watermark is missing {required}")

presentation_start = source.index("private struct ProtectedAssessmentPresentation")
presentation_end = source.index("extension View", presentation_start)
presentation = source[presentation_start:presentation_end]
for required in ("ProtectedAssessmentSurface", "ScreenProtectionLayerModifier"):
    if required not in presentation:
        raise SystemExit(f"protected full-screen presentation is missing {required}")
PY

echo "Google auth and supported screen protection contract passed"
