//  ConceptMotionWebStage.swift
//  Matths
//
//  개념 220개의 **코드 애니메이션**(HTML 컴포지션)을 앱 안에서 그대로 재생하는 무대.
//
//  왜 mp4 가 아니라 HTML 인가:
//    제작 쪽(matths-concept-motion)은 장면을 GSAP 타임라인으로 갖고 있고, mp4 는
//    그걸 한 번 구운 사본일 뿐이다. HTML 을 직접 틀면 (1) 220개를 굽고 나르는
//    단계가 사라지고, (2) 라이트·다크와 글자 크기가 기기 설정을 따라가며,
//    (3) 대사를 고쳤을 때 자산 한 벌만 갈아끼우면 된다.
//
//  그런데 시계는 여전히 하나여야 한다:
//    ConceptMotionVideo.swift 가 적어 둔 사고 — 웹 애니메이션과 TTS 가 각자 흐르며
//    같은 순간에 서로 다른 데를 가리켰던 일 — 는 여기서도 똑같이 일어날 수 있다.
//    컴포지션은 그래서 스스로 흐르지 않는다. 나레이션 오디오의 currentTime 이
//    유일한 시계이고 타임라인은 매 프레임 그 값으로 seek 될 뿐이다(?live=1).
//    이 파일은 그 규칙을 앱 쪽에서도 깨지지 않게 지키는 것이 일이다.
//
//  ─────────────────────────────────────────────────────────────────────────
//  자산이 있는 두 자리 (번들 동봉 + 밀어넣기)
//  ─────────────────────────────────────────────────────────────────────────
//  ① <앱 번들>/ConceptMotion/                        — 설치본에 동봉된 한 벌
//  ② Library/Application Support/ConceptMotion/      — 개발 중 밀어넣는 자리(우선)
//
//  왜 이제 번들에 동봉하는가:
//    한때는 음성만 470MB 라 번들이 불가능했고, 그래서 ② 만 읽었다. 그런데 ② 를
//    채우는 것은 개발자 맥에 있는 스크립트뿐이라, TestFlight·App Store 설치본은
//    개념학습이 통째로 빈 화면이었다. 2026-08 음성 재인코딩(MP3 40k/22.05kHz 모노)이
//    458MB 를 144MB 로 줄여 자산 한 벌이 약 177MB 가 됐고, 그 크기면 동봉이 현실적이다.
//    (서버 증설 뒤에는 음성 패키지를 내려받는 길로 옮길 수 있다 — 그때도 ② 가 그 자리다)
//
//  왜 ② 가 여전히 이기는가:
//    자산을 고쳐 밀어넣어도 앱이 빌드 당시의 동봉본만 계속 틀면 제작 쪽 반복이 죽는다.
//    밀어넣은 것이 있으면 그것을, 없으면 동봉본으로 내려간다 — 개념 단위로.
//    Caches 가 아닌 이유는 iOS 가 Caches 를 임의로 비우기 때문이다.
//
//  번들 동봉본은 scripts/sync-concept-motion-bundle.sh 가 앱 저장소 안
//  `ConceptMotion/` 로 복사해 두고, Xcode 는 그 폴더를 **폴더 참조**로 통째로 담는다.
//  (앱 빌드가 제작 저장소를 필수 의존성으로 삼으면 다른 머신에서 빌드가 깨진다)
//
//  개발 중에는 scripts/push-concept-motion.sh 가 밀어넣는다:
//
//      # 시뮬레이터(부팅된 것)에 전부
//      scripts/push-concept-motion.sh
//      # 개념 하나만 (빠른 확인용)
//      scripts/push-concept-motion.sh --only algebra-01-01
//      # 실기기
//      scripts/push-concept-motion.sh --device 00008103-000XXXXXXXXXXXXX
//
//  두 자리 **모두** 제작 저장소와 같은 트리다. 컴포지션의 <base href="../"> 가 그
//  모양을 전제로 자산을 찾기 때문에 한 칸이라도 어긋나면 소리와 폰트가 빠진다.
//  그래서 번들 동봉본도 평탄화하지 않고 폴더째 담는다(폴더 참조):
//
//      <ConceptMotion 뿌리>/
//        compositions/<개념id>.html          남성 낭독으로 타이밍을 깐 무대
//        compositions/<개념id>.female.html   (있으면) 여성 낭독으로 다시 깐 무대
//        assets/fonts/*.woff2
//        assets/voice/<개념id>/full.mp3          남성
//        assets/voice-female/<개념id>/full.mp3   여성
//        vendor/gsap.min.js                      선택 — 아래 참조
//
//  컴포지션과 음성은 짝이다. 음성만 갈아끼우면 수업이 통째로 어긋난다 —
//  자세한 근거와 실측치는 ConceptMotionWebAsset.stage(conceptID:voice:) 주석에 있다.
//
//  vendor/gsap.min.js 를 두는 이유: 컴포지션 HTML 은 GSAP 을 CDN 에서 부른다.
//  교실 아이패드가 오프라인이면 그 <script> 가 실패할 때까지 화면이 하얗게 서 있고,
//  실패한 뒤에는 타임라인이 없어 수업이 통째로 비어 버린다. 로컬 사본이 있으면
//  문서 시작 시점에 먼저 심어 두고 바깥 요청을 전부 막는다 — 수업 화면이
//  네트워크를 건드릴 이유도 없다.

import AVFoundation
import SwiftUI
import WebKit

/// 코드 애니메이션 자산의 경로 해석.
///
/// 자산은 **두 자리**에 있을 수 있고, 앞이 이긴다:
///
///   1. Library/Application Support/ConceptMotion/  — push-concept-motion.sh 가 밀어넣은 것
///   2. <앱 번들>/ConceptMotion/                     — 설치본에 동봉된 한 벌
///
/// 순서를 이렇게 두는 이유는 파일 위 머리말에 적었다 — 요약하면, 동봉본이 없으면
/// 설치본의 개념학습이 통째로 비고, 밀어넣은 것이 이기지 않으면 자산을 고쳐도
/// 앱이 빌드 당시 사본만 계속 튼다.
///
/// 판단은 **개념 단위**다. 뿌리를 통째로 하나만 고르면 `--only <개념>` 로 하나만
/// 밀어넣는 흔한 개발 흐름에서 나머지 219개가 그 순간 사라진다.
///
/// mp4 자산(ConceptMotionAsset)과 **같은 트리 모양**을 쓴다. 두 모양이 갈리면
/// 한쪽은 반드시 틀리고, 그 틀림은 "왜 어떤 개념만 소리가 없지" 로 나타난다.
enum ConceptMotionWebAsset {
    /// 번들 폴더 이름. 폴더 참조라 번들 안에서도 제작 저장소와 같은 트리로 남는다.
    private static let bundleFolder = "ConceptMotion"

    /// 앱 번들에 동봉된 자산 뿌리. 번들 안은 실행 중 바뀌지 않으므로 한 번만 찾는다.
    static let bundled: URL? = Bundle.main.url(forResource: bundleFolder, withExtension: nil)

    /// 자산을 찾을 자리들. **앞이 이긴다.**
    static var roots: [URL] { [ConceptMotionAsset.directory, bundled].compactMap { $0 } }

    /// 이 개념의 컴포지션이 준비돼 있으면 그 URL과 **그 사본이 놓인 뿌리**.
    ///
    /// 뿌리를 함께 돌려주는 이유: 문서를 열 때 읽기 권한과 <base href="../"> 의
    /// 기준이 그 뿌리라야 한다. 밀어넣은 무대를 열면서 번들 뿌리로 권한을 주면
    /// 음성과 폰트가 통째로 빠진다.
    ///
    /// 파일명이 곧 개념 id 다(제작 쪽 빌드가 그렇게 쓴다). mp4 처럼 버전을 박지
    /// 않는 이유는 HTML 이 통째로 교체되는 텍스트라 옛 파일이 남을 자리가 없기 때문이다.
    static func composition(conceptID: String) -> (url: URL, root: URL)? {
        for root in roots {
            if let file = composition(conceptID: conceptID, in: root) {
                return (file, root)
            }
        }
        return nil
    }

    /// 지정한 뿌리 **안에서만** 찾는다. 짝(여성 무대)을 고를 때 뿌리를 섞지 않으려는 것이다.
    static func composition(conceptID: String, in root: URL) -> URL? {
        let file = root
            .appendingPathComponent("compositions", isDirectory: true)
            .appendingPathComponent("\(conceptID).html")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// 성우의 해설 음성을 **컴포지션 기준 상대 경로**로 준다.
    ///
    /// 절대 file: URL 을 넣지 않는다. 컴포지션은 <base href="../"> 로 자산을 찾고,
    /// 그 상대 관계가 유지되는 한 자산 트리를 통째로 옮겨도 문서가 그대로 산다 —
    /// Application Support 에서 번들로 자리를 바꿔도 이 한 줄이 그대로인 이유다.
    static func narrationRelativePath(conceptID: String,
                                      voice: ConceptNarrationVoice,
                                      in root: URL) -> String? {
        guard let folder = voice.assetFolder else { return nil }
        let relative = "assets/\(folder)/\(conceptID)/full.mp3"
        let file = root.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: file.path) ? relative : nil
    }

    /// 실제로 열 문서와, 그 문서와 **함께 구운** 음성.
    struct Stage {
        /// 이 무대의 자산이 실제로 놓인 뿌리(밀어넣은 자리 또는 번들).
        let root: URL
        let composition: URL
        /// 컴포지션이 갖고 있는 기본 트랙을 갈아끼울 때만 값이 있다.
        let narration: String?
        /// 실제로 들릴 성우. 고른 것과 다를 수 있다 — voice 주석 참조.
        let voice: ConceptNarrationVoice
    }

    /// 컴포지션과 음성은 **짝**이다. 짝을 깨면 안 된다.
    ///
    /// 컴포지션의 타임라인 길이는 그 음성의 실측 길이로 깔린 것이라, 음성만
    /// 갈아끼우면 자막과 그림이 목소리와 통째로 어긋난다. 추측이 아니라 실측이다 —
    /// 무작위 12개를 재 보니 여성 낭독이 무대보다 5~16초 길거나 짧았고,
    /// 제작 쪽이 스스로 정한 허용오차 0.2초를 하나도 지키지 못했다.
    /// (그래서 제작 저장소도 성우가 다르면 컴포지션을 따로 굽는다 — `01f` 처럼)
    ///
    /// 그래서 여성 해설은 **여성 타이밍으로 구운 컴포지션이 있을 때만** 나간다.
    /// 없으면 짝이 맞는 남성 쌍을 그대로 튼다. 고른 성우와 다른 소리가 나는 건
    /// 분명한 손해지만, 자막이 목소리보다 10초 앞서가는 화면은 수업 자체를 못 쓰게 만든다.
    /// (`compositions/<개념id>.female.html` 이 들어오는 날 이 분기가 저절로 켜진다)
    static func stage(conceptID: String, voice: ConceptNarrationVoice) -> Stage? {
        guard let base = composition(conceptID: conceptID) else { return nil }
        let root = base.root
        switch voice {
        case .off:
            // 소리를 내지 않으므로 트랙을 고를 일이 없다. 무대는 기본 짝을 쓴다.
            return Stage(root: root, composition: base.url, narration: nil, voice: .off)
        case .male:
            // HTML 이 이미 남성 트랙을 가리킨다. 갈아끼울 이유가 없다.
            return Stage(root: root, composition: base.url, narration: nil, voice: .male)
        case .female:
            // 여성 짝은 **남성 무대와 같은 뿌리**에서만 찾는다. 밀어넣어 고친 무대와
            // 번들에 굳은 음성을 섞으면 고친 타이밍이 조용히 사라진다.
            if let paired = composition(conceptID: "\(conceptID).female", in: root),
               let track = narrationRelativePath(conceptID: conceptID, voice: .female, in: root) {
                return Stage(root: root, composition: paired, narration: track, voice: .female)
            }
            return Stage(root: root, composition: base.url, narration: nil, voice: .male)
        }
    }

    /// 이 뿌리에 놓아 둔 GSAP 사본. 없으면 nil 이고 그때만 CDN 에 의존한다.
    static func vendoredGSAP(in root: URL) -> URL? {
        let file = root
            .appendingPathComponent("vendor", isDirectory: true)
            .appendingPathComponent("gsap.min.js")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    /// 이 개념을 코드 애니메이션으로 보여줄 수 있는가. 호출부가 이걸 보고 무대를 고른다.
    static func isReady(conceptID: String) -> Bool {
        composition(conceptID: conceptID) != nil
    }
}

/// 고정 좌표로 만든 1080×1920 수업을 기기 방향에 맞춰 보여 주는 **표시 전용** 규격.
///
/// 내부 SVG·수식·포인터 좌표는 바꾸지 않는다. 세로형은 네 개의 공통 band 사이에서
/// 실제로 비어 있는 위아래만 걷어 낸다. 가로형은 원본 1080×825.6 무대를 비균일하게
/// 늘이지 않고 1200×917.3으로 균등 확대해 왼쪽 1200pt 작업대 정중앙에 두고,
/// 오른쪽 960pt에 설명을 둔다. 같은 타임라인과 음성을 그대로 쓰면서도 수학 무대가
/// 가로 화면의 유효 영역을 더 크게 쓴다.
enum ConceptMotionPresentation: String {
    case portraitBoard = "portrait-board"
    case wideBoard = "wide-board"

    var canvasSize: CGSize {
        switch self {
        case .portraitBoard: CGSize(width: 1080, height: 1560)
        case .wideBoard: CGSize(width: 2160, height: 1080)
        }
    }

    var aspectRatio: CGFloat { canvasSize.width / canvasSize.height }

    /// 한 화면에서 읽을 수 있는 크기를 우선하되, 세로로 끝없이 늘어나는 것은 막는다.
    var maximumDisplayHeight: CGFloat {
        switch self {
        case .portraitBoard: 960
        case .wideBoard: 680
        }
    }
}

/// 개념 코드 애니메이션 무대.
///
/// 재생 컨트롤을 두지 않는다 — 영상에 재생 버튼을 따로 달지 않는 것과 같다.
/// 화면에 들어오면 시작하고 나가면 멈춘다(active).
struct ConceptMotionWebStage: UIViewRepresentable {
    let conceptID: String
    /// 세로 압축판 또는 가로 2열판. 수학 콘텐츠와 타이밍은 어느 쪽도 같다.
    let presentation: ConceptMotionPresentation
    /// 화면이 살아 있는가(앱 활성 + 이 화면이 보이는 중). 소리와 그림을 함께 멈춘다.
    let active: Bool
    /// 앱이 고른 외관. 컴포지션은 :root[data-theme] 를 이미 알고 있다.
    let colorScheme: ColorScheme
    let onFinished: () -> Void
    let onFailure: () -> Void

    /// 성우 선택은 전역 설정이라 뷰 인자로 흘리지 않는다. 값이 바뀌면 이 뷰가
    /// 다시 그려지고 updateUIView 가 문서를 새 짝으로 다시 연다.
    @AppStorage(ConceptNarrationPreference.key)
    private var storedVoice = ConceptNarrationPreference.appDefault.rawValue

    /// 저장값이 깨졌으면 preference 가 정한 기본값을 그대로 따른다.
    /// 기본값을 여기서 또 정하면 두 곳이 언젠가 갈라진다.
    private var preferredVoice: ConceptNarrationVoice {
        ConceptNarrationVoice(rawValue: storedVoice) ?? ConceptNarrationPreference.current
    }

    private var stage: ConceptMotionWebAsset.Stage? {
        ConceptMotionWebAsset.stage(conceptID: conceptID, voice: preferredVoice)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> Surface {
        context.coordinator.desiredPresentation = presentation
        context.coordinator.desiredActive = active

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // 해설은 학생이 누르지 않아도 시작한다. 이 화면에는 재생 버튼이 없다.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(context.coordinator, name: Coordinator.channel)

        let web = WKWebView(frame: CGRect(origin: .zero, size: presentation.canvasSize),
                            configuration: configuration)
        web.navigationDelegate = context.coordinator
        // 컴포지션이 제 바탕(--m-ground)을 칠한다. 투명하게 두면 무대 밖 종이색이
        // 비쳐 라이트/다크 경계에서 색이 두 겹으로 보인다.
        web.isOpaque = true

        // 저절로 나는 소리라 무음 스위치를 따른다(.ambient) — mp4 경로와 같은 규칙이다.
        // 수업 중에 화면만 열었는데 소리가 터지면 사고다.
        Self.configureAudioSession()

        load(into: web, context: context)
        return Surface(web: web, canvasSize: presentation.canvasSize)
    }

    func updateUIView(_ surface: Surface, context: Context) {
        context.coordinator.onFinished = onFinished
        context.coordinator.onFailure = onFailure
        context.coordinator.desiredPresentation = presentation
        context.coordinator.desiredActive = active
        surface.canvasSize = presentation.canvasSize

        // 개념·성우·외관 중 하나라도 바뀌면 문서를 다시 연다. 주입 스크립트는
        // 문서 시작 시점에만 걸 수 있어서, 값만 갈아끼우는 길이 없다.
        let key = documentKey
        if context.coordinator.loadedKey != key {
            load(into: surface.web, context: context)
            return
        }
        // 같은 문서면 되감지 않는다. 뷰가 갱신될 때마다 처음으로 돌아가면
        // 학생이 보던 자리를 잃는다.
        context.coordinator.applyDesiredRuntimeState(to: surface.web)
    }

    static func dismantleUIView(_ surface: Surface, coordinator: Coordinator) {
        // 빈 문서로 갈아치우기 전에 델리게이트를 뗀다. 안 떼면 그 로드의 결과가
        // 실패로 돌아왔을 때 이미 사라진 화면에 "무대가 서지 못했다" 를 보고한다.
        surface.web.navigationDelegate = nil
        // 소리를 확실히 끊는다. about:blank 로 갈아치우면 오디오 요소째 사라진다 —
        // pause 만 부르면 화면을 벗어난 뒤에도 재생이 되살아나는 경로가 남는다.
        surface.web.loadHTMLString("", baseURL: nil)
        // 메시지 핸들러는 컨트롤러가 강하게 붙든다. 떼지 않으면 코디네이터가
        // 웹뷰와 함께 살아남아 화면을 나가도 콜백이 계속 온다.
        let controller = surface.web.configuration.userContentController
        controller.removeScriptMessageHandler(forName: Coordinator.channel)
        controller.removeAllUserScripts()
    }

    // MARK: - 문서 열기

    /// 이 조합이 바뀌면 문서를 다시 열어야 한다.
    private var documentKey: String {
        let stage = stage
        return [stage?.composition.path ?? "-",
                stage?.narration ?? "-",
                stage?.voice.rawValue ?? "-",
                colorScheme == .dark ? "dark" : "light"].joined(separator: "|")
    }

    /// 무대 표면 — 선택된 고정 캔버스를 담아 레이어째 축소한다.
    ///
    /// 왜 웹뷰를 프레임에 그냥 맞추지 않는가:
    ///   컴포지션은 viewport 가 width=1080 으로 못박힌 고정 캔버스다. 웹뷰를 프레임
    ///   크기로 두면 WebKit 이 "폭에 맞추는 배율" 을 **첫 레이아웃 때 한 번** 정하고,
    ///   그 뒤 뷰가 줄거나 늘어도 다시 계산하지 않는다. SwiftUI 는 첫 레이아웃에서
    ///   중간 크기를 주는 일이 흔해서, 그 순간 정해진 배율이 그대로 남아 무대
    ///   오른쪽이 통째로 잘렸다 — 시뮬레이터에서 제목과 표의 절반이 화면 밖으로
    ///   나갔고, 최소 확대배율을 풀어 봐도 그대로였다.
    ///
    ///   그래서 배율 계산을 WebKit 에 맡기지 않는다. 웹뷰 크기는 표시 규격 그대로
    ///   고정해 배율을 항상 1 로 만들고, 화면에 맞추는 일은 레이어
    ///   변환이 한다. 회전하든 분할 화면이 바뀌든 매 레이아웃마다 다시 계산되고,
    ///   축소 방향이라 오히려 더 촘촘하게 그려진다(1080 을 405 로 줄이는 셈).
    final class Surface: UIView {
        let web: WKWebView
        /// 회전하면 세로 압축판과 가로 2열판 사이에서 바뀐다.
        var canvasSize: CGSize {
            didSet {
                guard canvasSize != oldValue else { return }
                setNeedsLayout()
            }
        }

        init(web: WKWebView, canvasSize: CGSize) {
            self.web = web
            self.canvasSize = canvasSize
            super.init(frame: .zero)
            clipsToBounds = true
            // 캔버스가 웹뷰를 정확히 채우므로 스크롤·확대할 여지가 없다.
            // 켜 두면 학생이 무대를 밀어 어긋나게 만들 수만 있다.
            web.scrollView.isScrollEnabled = false
            web.scrollView.bounces = false
            web.scrollView.pinchGestureRecognizer?.isEnabled = false
            addSubview(web)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, bounds.height > 0 else { return }
            let scale = min(bounds.width / canvasSize.width,
                            bounds.height / canvasSize.height)
            // transform 이 걸린 채로 frame 을 만지면 값이 두 번 곱해진다. 먼저 푼다.
            web.transform = .identity
            web.frame = CGRect(origin: .zero, size: canvasSize)
            web.transform = CGAffineTransform(scaleX: scale, y: scale)
            web.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    private func load(into web: WKWebView, context: Context) {
        guard let stage else {
            onFailure()
            return
        }
        // 읽기 권한과 <base href="../"> 의 기준은 **이 무대가 실제로 놓인 뿌리**다.
        // 밀어넣은 사본과 번들 동봉본이 섞이면 소리·폰트가 통째로 빠진다.
        let root = stage.root
        context.coordinator.loadedKey = documentKey

        let controller = web.configuration.userContentController
        controller.removeAllUserScripts()

        // GSAP 로컬 사본을 문서 시작 시점에 먼저 심는다. 페이지의 CDN <script> 가
        // 나중에 성공하면 같은 라이브러리로 덮어쓸 뿐이고, 실패하면 이 사본이 남는다.
        let vendored = ConceptMotionWebAsset.vendoredGSAP(in: root)
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        if let vendored {
            controller.addUserScript(WKUserScript(source: vendored,
                                                  injectionTime: .atDocumentStart,
                                                  forMainFrameOnly: true))
        }
        controller.addUserScript(WKUserScript(source: bootstrapConfigScript,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: Self.bootstrapScript,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))

        // 웹과 같은 계약으로 연다. 쿼리가 살아 있으면 컴포지션이 스스로 시계를 잡고,
        // 벗겨지면 주입 스크립트가 같은 규칙으로 대신 잡는다 — 어느 쪽이든 시계는 하나다.
        // (file: URL 의 쿼리가 환경에 따라 벗겨진다는 건 LessonWebView 주석의 실증이다.)
        var components = URLComponents(url: stage.composition, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "live", value: "1"),
            URLQueryItem(name: "voice", value: stage.voice.rawValue)
        ]
        let target = components?.url ?? stage.composition

        let start = { _ = web.loadFileURL(target, allowingReadAccessTo: root) }
        guard vendored != nil else {
            // 로컬 GSAP 이 없으면 CDN 이 유일한 공급처다. 막으면 안 된다.
            start()
            return
        }
        ConceptMotionOfflineRules.load { list in
            if let list { web.configuration.userContentController.add(list) }
            start()
        }
    }

    /// 문서가 스스로 알 수 없는 것들 — 들려줄 성우, 그 성우의 음성 파일, 앱 외관.
    private var bootstrapConfigScript: String {
        var payload: [String: Any] = [
            "conceptID": conceptID,
            "voice": stage?.voice.rawValue ?? ConceptNarrationVoice.off.rawValue,
            "theme": colorScheme == .dark ? "dark" : "light",
            "presentation": presentation.rawValue
        ]
        if let narration = stage?.narration {
            payload["narration"] = narration
        }
        let json = (try? JSONSerialization.data(withJSONObject: payload))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "window.MATTHS_CONCEPT_MOTION = \(json);"
    }

    private static func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .moviePlayback, options: [])
            try session.setActive(true, options: [])
        } catch {
            NSLog("[Matths] concept motion web audio session failed: %@", error.localizedDescription)
        }
        #endif
    }

    // MARK: - 주입 스크립트

    /// 문서 시작 시점에 심는 브리지.
    ///
    /// 하는 일은 넷이다:
    ///   1) 앱이 고른 외관을 문서에 박는다.
    ///   2) 성우 선택을 오디오 요소에 반영한다(끄기면 요소째 걷어낸다).
    ///   3) 시계가 없으면 세운다 — 있으면 절대 손대지 않는다.
    ///   4) 끝났다/서지 못했다를 네이티브에 알린다.
    private static let bootstrapScript = """
    (function () {
      "use strict";
      var cfg = window.MATTHS_CONCEPT_MOTION || {};
      var ready = false;
      var reportedEnd = false;

      function post(event, detail) {
        try {
          window.webkit.messageHandlers.conceptMotion.postMessage({
            event: event, detail: detail === undefined ? null : detail
          });
        } catch (e) {}
      }

      function applyTheme() {
        var root = document.documentElement;
        if (root) root.setAttribute("data-theme", cfg.theme === "dark" ? "dark" : "light");
      }
      applyTheme();
      document.addEventListener("DOMContentLoaded", applyTheme, { once: true });

      // 가로 설명판은 960px이지만 일부 긴 식은 원본에서도 1,200px을 넘는다.
      // 수식 조각의 GSAP transform을 덮지 않도록 panel-row의 CSS zoom만 줄이고,
      // 행과 절대 배치 태그를 합친 실제 경계가 좌우 40px 안전 여백 안에 들게 한다.
      // 세로로 돌아오면 zoom을 지워 원본 조판을 그대로 복원한다.
      function fitWidePanelRows(wide) {
        var rows = document.querySelectorAll(".band-panel .panel-row");
        rows.forEach(function (row) {
          row.style.removeProperty("zoom");
          if (!wide) return;

          var nodes = [row].concat(Array.prototype.slice.call(row.querySelectorAll("*")));
          var left = Infinity;
          var right = -Infinity;
          nodes.forEach(function (node) {
            var rect = node.getBoundingClientRect();
            if (rect.width < 0.1 || rect.height < 0.1) return;
            left = Math.min(left, rect.left);
            right = Math.max(right, rect.right);
          });

          var width = right - left;
          var available = 880; // 960px 설명판 - 좌우 40px
          if (Number.isFinite(width) && width > available) {
            row.style.setProperty("zoom", String(available / width));
          }
        });
      }

      function schedulePanelFit(wide) {
        requestAnimationFrame(function () { fitWidePanelRows(wide); });
        if (document.fonts && document.fonts.ready) {
          document.fonts.ready.then(function () {
            var current = document.documentElement
              .getAttribute("data-matths-motion-presentation");
            if ((current === "wide") === wide) fitWidePanelRows(wide);
          });
        }
      }

      // 원본 1080×1920 안의 수학 좌표는 절대 바꾸지 않는다. 네 개의 공통 band 부모만
      // 안전 구역으로 옮긴다. 가로에서는 1080×825.6 무대를 10/9로 균등 확대하고,
      // (1080 - 825.6×10/9) / 2 = 81.333px 만큼 내려 왼쪽 1200pt 작업대의
      // 가로·세로 중심을 모두 맞춘다. 오른쪽 960pt 설명판은 930px 자막도 보존한다.
      function applyPresentation(requested) {
        var wide = (requested || cfg.presentation) === "wide-board";
        var width = wide ? 2160 : 1080;
        var height = wide ? 1080 : 1560;
        var style = document.getElementById("matths-motion-presentation");
        if (!style) {
          style = document.createElement("style");
          style.id = "matths-motion-presentation";
          (document.head || document.documentElement).appendChild(style);
        }
        style.textContent = wide ? [
          "html,body,#root{width:2160px!important;height:1080px!important}",
          ".band{width:1080px!important}",
          ".band-title{left:1200px!important;top:96px!important;width:960px!important}",
          ".band-panel{left:1200px!important;top:342px!important;width:960px!important}",
          ".band-stage{left:0!important;top:81.333px!important;transform:scale(1.111111)!important;transform-origin:0 0!important}",
          ".band-caption{left:1200px!important;top:650px!important;width:960px!important}"
        ].join("") : [
          "html,body,#root{width:1080px!important;height:1560px!important}",
          ".band{left:0!important;width:1080px!important}",
          ".band-title{top:24px!important}",
          ".band-panel{top:235px!important}",
          ".band-stage{top:450px!important}",
          ".band-caption{top:1310px!important}"
        ].join("");

        document.documentElement.setAttribute("data-matths-motion-presentation",
                                               wide ? "wide" : "portrait");
        schedulePanelFit(wide);
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
          meta.setAttribute("content", "width=" + width + ", height=" + height
                            + ", initial-scale=1");
        }
        var root = document.getElementById("root");
        if (root) {
          root.setAttribute("data-width", String(width));
          root.setAttribute("data-height", String(height));
        }
      }
      window.MATTHS_MOTION_SET_PRESENTATION = applyPresentation;
      applyPresentation(cfg.presentation);
      document.addEventListener("DOMContentLoaded", function () {
        applyPresentation(cfg.presentation);
      }, { once: true });

      // 끝을 알리는 통로는 하나다. 컴포지션이 스스로 시계를 잡았든 아래 드라이버가
      // 잡았든 같은 이벤트를 쏘므로, 여기 한 곳만 들으면 중복이 없다.
      window.addEventListener("matths:lesson-finished", function () {
        if (reportedEnd) return;
        reportedEnd = true;
        post("finished");
      });

      document.addEventListener("DOMContentLoaded", function () {
        var audio = document.getElementById("voice");
        if (!audio) return;
        if (cfg.voice === "off") {
          // 해설을 끈 학생. 오디오 요소 자체를 걷어낸다.
          // src 만 비우면 컴포지션의 startLive 가 0 에 멈춘 시계를 붙들고 돌아
          // 그림이 첫 프레임에 얼어붙는다. 요소가 없으면 startLive 가 스스로 빠지고
          // (`if (!audio) return`), 아래 벽시계가 대신 무대를 흐르게 한다.
          if (audio.parentNode) audio.parentNode.removeChild(audio);
          return;
        }
        if (cfg.narration && audio.getAttribute("src") !== cfg.narration) {
          audio.setAttribute("src", cfg.narration);
          audio.load();
        }
      }, { once: true });

      // 오디오 시계 — 컴포지션이 쓰는 것과 같은 규칙을 그대로 옮겼다.
      // 옮긴 이유: file: URL 의 쿼리가 벗겨져 ?live=1 이 문서에 닿지 않는 환경이
      // 있고, 그때 시계를 잡는 쪽이 아무도 없으면 소리만 흐르고 그림이 선다.
      function audioClock(tl, audio, drive) {
        if (drive) {
          var last = -1;
          var sync = function () {
            var t = audio.currentTime;
            // seek 의 두 번째 인자는 suppressEvents 이고 기본값이 true 다.
            // 그대로 두면 onUpdate 가 안 불려 실시간 리드아웃이 0 에 얼어붙는다.
            if (t !== last) { tl.seek(t, false); last = t; }
          };
          (function raf() { sync(); requestAnimationFrame(raf); })();
          // rAF 는 화면이 가려지면 멈춘다. timeupdate 는 그때도 오므로 보조 시계로 둔다.
          audio.addEventListener("timeupdate", sync);
          audio.addEventListener("seeked", sync);
          audio.addEventListener("ended", function () {
            tl.seek(tl.duration(), false);
            window.dispatchEvent(new CustomEvent("matths:lesson-finished"));
          });
        }
        return {
          setActive: function (on) {
            if (on) { audio.play().catch(function () {}); } else { audio.pause(); }
          }
        };
      }

      // 벽시계 — 해설을 끈 경우에만 쓴다. rAF 델타로 재므로 화면이 가려지면
      // 저절로 멈추고, 돌아오면 멈춘 자리에서 이어진다(시간이 건너뛰지 않는다).
      function wallClock(tl) {
        var elapsed = 0, mark = null, running = true, done = false;
        function step(now) {
          if (!running) return;
          if (mark === null) mark = now;
          elapsed += (now - mark) / 1000;
          mark = now;
          var total = tl.duration();
          if (elapsed >= total) {
            tl.seek(total, false);
            if (!done) {
              done = true;
              window.dispatchEvent(new CustomEvent("matths:lesson-finished"));
            }
            return;
          }
          tl.seek(elapsed, false);
          requestAnimationFrame(step);
        }
        requestAnimationFrame(step);
        return {
          setActive: function (on) {
            if (on === running) return;
            running = on;
            mark = null;
            if (on && !done) requestAnimationFrame(step);
          }
        };
      }

      var clock = null;

      window.addEventListener("load", function () {
        var stage = document.querySelector("[data-composition-id]");
        // 타임라인 키는 문서가 갖고 있다. 파일명에서 넘겨받은 id 를 믿지 않는 이유는
        // 둘이 갈라진 컴포지션이 실제로 있기 때문이다(검증용 파일들).
        var id = (stage && stage.getAttribute("data-composition-id")) || cfg.conceptID;
        var tl = (window.__timelines || {})[id];
        if (!window.gsap || !tl) {
          post("failed", "timeline-missing:" + id);
          return;
        }
        var audio = document.getElementById("voice");
        var queryLive = new URLSearchParams(location.search).get("live") === "1";
        if (audio) {
          // 쿼리가 살아 있으면 컴포지션이 이미 시계를 잡는다. 여기서 또 몰면
          // 시계가 둘이 되어, 고치려던 문제가 그대로 돌아온다.
          clock = audioClock(tl, audio, !queryLive);
        } else {
          clock = wallClock(tl);
        }
        ready = true;
        post("ready", id);
      }, { once: true });

      // 문서가 서지 못하는 경우(예: GSAP 을 끝내 못 받음)를 스스로 신고한다.
      // 신고가 없으면 호출부는 빈 무대를 계속 보여줄 뿐 폴백할 근거가 없다.
      setTimeout(function () { if (!ready) post("failed", "timeout"); }, 10000);

      window.MATTHS_MOTION_SET_ACTIVE = function (on) {
        if (clock) clock.setActive(!!on);
      };
    })();
    """

    // MARK: - 브리지

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        static let channel = "conceptMotion"

        var onFinished: () -> Void
        var onFailure: () -> Void
        /// 지금 열려 있는 문서. 같은 값이면 다시 열지 않는다.
        var loadedKey: String?
        /// 회전이 문서 로딩과 겹쳐도 마지막 방향·활성 상태가 이긴다. bootstrap 설정은
        /// 로드를 시작한 순간의 값이라, didFinish에서 이 값을 한 번 더 적용해야 한다.
        var desiredPresentation: ConceptMotionPresentation = .portraitBoard
        var desiredActive = false
        /// 실패는 한 번만 말한다. 호출부가 그 한 번으로 무대를 갈아탄다.
        private var reportedFailure = false

        init(onFinished: @escaping () -> Void, onFailure: @escaping () -> Void) {
            self.onFinished = onFinished
            self.onFailure = onFailure
        }

        func applyDesiredRuntimeState(to webView: WKWebView) {
            webView.evaluateJavaScript(
                "window.MATTHS_MOTION_SET_PRESENTATION"
                + " && window.MATTHS_MOTION_SET_PRESENTATION('\(desiredPresentation.rawValue)');"
                + "window.MATTHS_MOTION_SET_ACTIVE"
                + " && window.MATTHS_MOTION_SET_ACTIVE(\(desiredActive));"
            )
        }

        nonisolated func userContentController(_ controller: WKUserContentController,
                                               didReceive message: WKScriptMessage) {
            // WebKit 은 이 콜백을 메인 스레드로 보낸다. 메시지 본문을 읽는 것 자체가
            // 메인 격리라, 다른 스레드로 넘긴 뒤 읽으면 컴파일러가 옳게 막는다.
            MainActor.assumeIsolated {
                let body = message.body as? [String: Any]
                let detail = body?["detail"] as? String
                switch body?["event"] as? String {
                case "finished": onFinished()
                case "failed": fail(detail ?? "unknown")
                case "ready": NSLog("[Matths] concept motion stage ready: %@", detail ?? "-")
                default: break
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView,
                                 didFailProvisionalNavigation navigation: WKNavigation!,
                                 withError error: Error) {
            let reason = error.localizedDescription
            Task { @MainActor [weak self] in self?.fail(reason) }
        }

        nonisolated func webView(_ webView: WKWebView,
                                 didFail navigation: WKNavigation!,
                                 withError error: Error) {
            let reason = error.localizedDescription
            Task { @MainActor [weak self] in self?.fail(reason) }
        }

        nonisolated func webView(_ webView: WKWebView,
                                 didFinish navigation: WKNavigation!) {
            // WKNavigationDelegate는 메인 큐에서 호출된다. 로드 중 방향이 바뀌었으면
            // bootstrap의 옛 규격을 마지막 SwiftUI 상태로 덮되 문서는 다시 열지 않는다.
            MainActor.assumeIsolated { [weak self] in
                self?.applyDesiredRuntimeState(to: webView)
            }
        }

        private func fail(_ reason: String) {
            guard !reportedFailure else { return }
            reportedFailure = true
            NSLog("[Matths] concept motion stage failed: %@", reason)
            onFailure()
        }
    }
}

/// 수업 화면이 바깥으로 나가지 못하게 막는 규칙.
///
/// GSAP 로컬 사본이 있을 때만 건다. 오프라인 교실에서 CDN 응답을 기다리다
/// 화면이 몇 초씩 하얗게 서 있는 일을 없애는 것이 목적이고, 덤으로 수업 화면이
/// 네트워크를 아예 건드리지 않게 된다.
private enum ConceptMotionOfflineRules {
    static let identifier = "matths.conceptmotion.offline"
    private static let source = """
    [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]
    """

    /// 컴파일된 규칙은 저장소가 갖고 있으므로 두 번째부터는 조회로 끝난다.
    /// 규칙이 준비된 뒤에 문서를 열어야 한다 — 나중에 붙이면 이미 나간 요청을
    /// 막지 못해 "어떤 때는 빠르고 어떤 때는 느린" 화면이 된다.
    static func load(_ completion: @escaping (WKContentRuleList?) -> Void) {
        guard let store = WKContentRuleListStore.default() else {
            completion(nil)
            return
        }
        store.lookUpContentRuleList(forIdentifier: identifier) { list, _ in
            if let list {
                completion(list)
                return
            }
            store.compileContentRuleList(forIdentifier: identifier,
                                         encodedContentRuleList: source) { compiled, error in
                if let error {
                    NSLog("[Matths] concept motion rule compile failed: %@",
                          error.localizedDescription)
                }
                completion(compiled)
            }
        }
    }
}
