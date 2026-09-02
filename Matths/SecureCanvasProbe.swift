//  SecureCanvasProbe.swift
//  Matths
//
//  secure canvas 보호가 **지금 이 OS 에서 실제로 동작하는지** 앱 실행 시 한 번 계측한다.
//
//  이 기법을 쓸 때 가장 위험한 실패 모드는 "안 되는데 되는 줄 아는 것"이다.
//  iOS 메이저 업데이트에서 내부 구조가 바뀌면 재부모화는 성공하지만 캡처 제외는
//  풀려 버린다 — 화면은 멀쩡하고 크래시도 없어서 아무도 모른다
//  (Apple Developer Forums 767320: iOS 18 에서 깨졌다는 보고).
//
//  그래서 믿지 않고 잰다. 오프스크린에서
//    (a) secure canvas 를 찾고
//    (b) 알아볼 수 있는 마커 레이어를 그 아래에 넣고
//    (c) UIGraphicsImageRenderer + layer.render(in:) 로 스냅샷을 떠서
//    (d) 마커 픽셀이 결과에 남아 있는지 본다.
//  마커가 보이면 보호가 깨진 것이므로 `.degraded` 로 내리고 기존 방식으로 폴백한다.
//
//  거짓 양성 방지: 재부모화 **전에** 같은 방식으로 대조 스냅샷을 먼저 뜬다. 대조에서도
//  마커가 안 보이면 스냅샷 경로 자체가 아무것도 못 그린 것이므로 `.verified` 가 아니라
//  `.unavailable` 이다. "아무것도 안 그려졌다"를 "보호됐다"로 읽으면 안 된다.
//
//  시뮬레이터는 기기의 캡처 제외 동작을 재현하지 않는다. 여기서 나오는 값은 거짓
//  음성이므로 아예 재지 않고 `.unavailable(simulator)` 로 둔다. CI 는 이 값을
//  PASS 조건으로 요구하면 안 된다.

import UIKit

enum SecureCanvasProbeResult: Equatable {
    /// 마커가 스냅샷 픽셀에서 사라졌다. secure canvas 를 신뢰해도 된다.
    case verified
    /// 기법이 이 OS/빌드에서 깨졌다. 절대 의존하지 말고 기존 보호로 폴백한다.
    case degraded(reason: String)
    /// 이 환경에서는 측정 자체가 불가능하다(시뮬레이터, 렌더 경로 없음 등).
    /// 역시 의존하지 않는다 — 모르면 안 쓰는 쪽이 안전하다.
    case unavailable(reason: String)

    /// `.verified` 하나만 통과시킨다. `.degraded` 와 `.unavailable` 은 모두 폴백이다.
    var allowsSecureCanvas: Bool {
        if case .verified = self { return true }
        return false
    }

    var storageValue: String {
        switch self {
        case .verified: return "verified"
        case .degraded(let reason): return "degraded:\(reason)"
        case .unavailable(let reason): return "unavailable:\(reason)"
        }
    }

    init?(storageValue: String) {
        if storageValue == "verified" {
            self = .verified
        } else if storageValue.hasPrefix("degraded:") {
            self = .degraded(reason: String(storageValue.dropFirst("degraded:".count)))
        } else if storageValue.hasPrefix("unavailable:") {
            self = .unavailable(reason: String(storageValue.dropFirst("unavailable:".count)))
        } else {
            return nil
        }
    }
}

@MainActor
enum SecureCanvasProbe {
    /// 프로브 로직이 바뀌면 올린다. 옛 판정을 새 로직의 결과로 읽으면 안 된다.
    private static let schemaVersion = "v2"
    private static let defaultsKey = "matths.secureCanvasProbe.result"
    /// 현장에서 이 기능만 끄기 위한 탈출구. 화면이 이상하면 앱 전체를 되돌리는 대신
    /// 이 값을 켜서 보호만 끈다.
    private static let disableDefaultsKey = "MATTHS_DISABLE_SECURE_CANVAS"

    private static var cachedResult: SecureCanvasProbeResult?

    /// 프로브 결과. 프로세스 수명 동안 한 번만 계산하고, `.verified`/`.degraded` 는
    /// OS 버전 + 앱 빌드 키로 디스크에도 캐싱한다. 화면 진입마다 다시 재지 않는다.
    static var result: SecureCanvasProbeResult {
        if let cachedResult { return cachedResult }
        let value = evaluate()
        cachedResult = value
        return value
    }

    static var allowsSecureCanvas: Bool { result.allowsSecureCanvas }

    /// 앱이 뜬 직후 한 번 불러 첫 보호 화면에서 렌더가 밀리지 않게 한다.
    static func warmUp() { _ = result }

    /// 런타임에서 재부모화가 실패했거나 화면이 밀린 경우. 이번 실행 내내, 그리고
    /// 같은 OS/빌드에서는 다시 시도하지 않는다.
    static func reportRuntimeFailure(_ reason: String) {
        let value = SecureCanvasProbeResult.degraded(reason: reason)
        cachedResult = value
        persist(value)
    }

    // MARK: - 측정

    private static func evaluate() -> SecureCanvasProbeResult {
        if UserDefaults.standard.bool(forKey: disableDefaultsKey) {
            return .unavailable(reason: "disabled-by-setting")
        }
        #if DEBUG
        // 시뮬레이터는 캡처 제외를 재현하지 않아 이 경로가 아예 켜지지 않는다. 그래서
        // 재부모화가 화면을 깨뜨리지 않는지(레이아웃·좌표) 확인할 방법이 없다.
        // 이 인자는 **보호 여부가 아니라 렌더링만** 확인하기 위한 DEBUG 전용 강제이며,
        // 릴리스 빌드에는 존재하지 않는다.
        if ProcessInfo.processInfo.arguments.contains("-forceSecureCanvasVerified") {
            return .verified
        }
        #endif
        #if targetEnvironment(simulator)
        // 시뮬레이터는 캡처 제외를 재현하지 않는다. 재봐야 거짓 음성이다.
        return .unavailable(reason: "simulator")
        #else
        if let stored = storedResult() { return stored }
        let measured = measure()
        switch measured {
        case .verified, .degraded:
            persist(measured)
        case .unavailable:
            // 환경 탓일 수 있으므로 디스크에 굳히지 않는다. 다음 실행에서 다시 잰다.
            break
        }
        return measured
        #endif
    }

    /// 마커는 화면에 절대 쓰이지 않는 순수 마젠타다. 흐릿하게 섞여도 알아볼 수 있다.
    private static let markerColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)

    private static func measure() -> SecureCanvasProbeResult {
        let side: CGFloat = 64
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)

        // 사용자 화면 밖에 둔다. 윈도우 안에 있어야 secure canvas 가 실제로 만들어진다.
        let host = UIView(frame: CGRect(x: -20_000, y: -20_000, width: side, height: side))
        host.backgroundColor = .white
        host.isUserInteractionEnabled = false
        host.accessibilityElementsHidden = true

        let content = UIView(frame: bounds)
        content.backgroundColor = markerColor
        host.addSubview(content)

        let field = SecureCanvasBinder.makeSecureField()
        host.addSubview(field)

        hostWindow()?.addSubview(host)
        defer { host.removeFromSuperview() }
        host.setNeedsLayout()
        host.layoutIfNeeded()

        guard let controlImage = snapshot(of: host, size: bounds.size) else {
            return .unavailable(reason: "probe-render-failed")
        }
        guard containsMarker(controlImage) else {
            // 대조에서도 안 보인다 = 스냅샷 경로가 죽었다. 보호 성공으로 읽으면 안 된다.
            return .unavailable(reason: "probe-control-render-blank")
        }

        let reference = content.layer.convert(CGPoint.zero, to: host.layer)
        guard let attachment = SecureCanvasBinder.attach(content: content.layer, using: field) else {
            return .degraded(reason: "secure-canvas-not-found")
        }
        defer { SecureCanvasBinder.detach(attachment) }

        // 레이아웃이 한 번 더 돌아도 좌표가 유지되는지까지 본다 — 실제 화면에서
        // 매 레이아웃마다 겪는 조건이다.
        host.setNeedsLayout()
        host.layoutIfNeeded()
        SecureCanvasBinder.renormalize(attachment)

        let moved = content.layer.convert(CGPoint.zero, to: host.layer)
        guard abs(moved.x - reference.x) < 0.5, abs(moved.y - reference.y) < 0.5 else {
            return .degraded(reason: "secure-canvas-geometry-shift")
        }

        guard let securedImage = snapshot(of: host, size: bounds.size) else {
            return .unavailable(reason: "probe-render-failed")
        }
        if containsMarker(securedImage) {
            return .degraded(reason: "marker-visible-in-snapshot")
        }
        return .verified
    }

    /// 캡처 제외를 재는 스냅샷.
    ///
    /// **`layer.render(in:)` 을 쓰면 안 된다.** 그 API 는 레이어 트리를 직접 그리므로
    /// secure canvas 의 캡처 제외를 무시하고 마커를 그대로 그린다. 그래서 보호가
    /// 멀쩡히 동작하는 기기에서도 언제나 "marker-visible-in-snapshot" 이 나오고,
    /// 그 결과가 디스크에 굳어 기능이 영구히 꺼졌다. 사용자가 "여전히 정상 저장됨"
    /// 이라고 보고한 것이 이것이다.
    ///
    /// `drawHierarchy(in:afterScreenUpdates:true)` 는 시스템 렌더 경로를 타서
    /// 스크린샷과 같은 규칙(= secure canvas 제외)을 따른다. 이게 맞는 계측이다.
    private static func snapshot(of view: UIView, size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }

    /// 결과 픽셀에 마커가 한 점이라도 남아 있는지 본다.
    private static func containsMarker(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return false }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return false }
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[index]
            let green = pixels[index + 1]
            let blue = pixels[index + 2]
            let alpha = pixels[index + 3]
            if alpha > 200 && red > 200 && green < 60 && blue > 200 { return true }
        }
        return false
    }

    private static func hostWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let foreground = scenes.filter {
            $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive
        }
        return foreground.flatMap(\.windows).first(where: \.isKeyWindow)
            ?? foreground.flatMap(\.windows).first
            ?? scenes.flatMap(\.windows).first
    }

    // MARK: - 캐싱 (OS 버전 + 앱 빌드)

    private static var cacheKey: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(schemaVersion)|\(UIDevice.current.systemVersion)|\(version)(\(build))"
    }

    private static func storedResult() -> SecureCanvasProbeResult? {
        guard let stored = UserDefaults.standard.dictionary(forKey: defaultsKey),
              stored["key"] as? String == cacheKey,
              let raw = stored["result"] as? String else { return nil }
        return SecureCanvasProbeResult(storageValue: raw)
    }

    private static func persist(_ value: SecureCanvasProbeResult) {
        UserDefaults.standard.set(
            ["key": cacheKey, "result": value.storageValue],
            forKey: defaultsKey)
    }

    #if DEBUG
    /// 실기 자가진단용 — 캐시를 무시하고 지금 한 번 다시 잰다.
    static func measureForDeviceQA() -> SecureCanvasProbeResult {
        #if targetEnvironment(simulator)
        return .unavailable(reason: "simulator")
        #else
        return measure()
        #endif
    }

    /// `-secureCanvasProbeSelfTest` 로 실행하면 판정을 한 줄로 찍는다.
    /// 시뮬레이터에서는 반드시 `unavailable:simulator` 여야 한다 — 시뮬레이터는
    /// 캡처 제외를 재현하지 않으므로 CI 가 여기서 `verified` 를 요구하면 안 된다.
    static func runSelfTestIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-secureCanvasProbeSelfTest") else { return }
        print("MATTHS_SECURE_CANVAS_PROBE_V1 result=\(result.storageValue) "
              + "allowsSecureCanvas=\(allowsSecureCanvas)")
    }
    #endif
}
