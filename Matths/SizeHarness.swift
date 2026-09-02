//  SizeHarness.swift
//  Matths
//
//  Split View / Slide Over 폭에서 레이아웃이 견디는지 보는 DEBUG 전용 하네스.
//
//  왜 필요한가:
//  시뮬레이터에서 Split View 를 손으로 만들려면 창을 끌어야 하고, 그건 자동화가 안 된다.
//  그런데 정작 확인해야 할 것은 "폭이 320pt 일 때 안 깨지는가" 하나다.
//  그래서 폭과 사이즈 클래스를 직접 지정해 RootView 를 그려 본다.
//
//  한계를 분명히 해둔다. 이 하네스가 확인해 주는 것은 레이아웃뿐이다.
//  실제 Split View 의 키보드 동작, 드래그앤드롭, Stage Manager 창 리사이즈는
//  실기기에서 한 번 더 봐야 한다.
//
//  실행:
//    xcrun simctl launch <udid> kr.matths.app -harness 320x1000-compact
//    xcrun simctl launch <udid> kr.matths.app -harness 320x1000-compact -route assess
//    xcrun simctl launch <udid> kr.matths.app -harness 320x1000-compact -harness-auth
//    xcrun simctl launch <udid> kr.matths.app -harness 852x393-compact -route pro   ← 가로 iPhone
//    xcrun simctl launch <udid> kr.matths.app -harness 1366x1024-regular -route match -goatMatchFixture
//
//  릴리스 빌드에는 들어가지 않는다.

#if DEBUG
import SwiftUI

struct SizeHarness: View {
    let width: CGFloat
    let height: CGFloat
    let compact: Bool

    private var showsAuth: Bool {
        ProcessInfo.processInfo.arguments.contains("-harness-auth")
    }

    private var screenLabel: String {
        if showsAuth { return "auth" }
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-route"), index + 1 < args.count else {
            return "home"
        }
        return args[index + 1]
    }

    /// "320x1000-compact" 또는 "507x1200-regular" 를 파싱한다.
    /// 형식이 틀리면 nil 을 돌려주고, 앱은 평소대로 뜬다.
    static func parse(_ raw: String) -> SizeHarness? {
        let parts = raw.split(separator: "-", maxSplits: 1)
        guard let size = parts.first else { return nil }

        let dims = size.split(separator: "x")
        guard dims.count == 2,
              let w = Double(dims[0]), let h = Double(dims[1]),
              w > 0, h > 0 else { return nil }

        let compact = parts.count > 1 ? parts[1] == "compact" : false
        return SizeHarness(width: w, height: h, compact: compact)
    }

    /// 세로 사이즈 클래스도 흉내 낸다. 가로 iPhone 을 보려고 만든 창에서
    /// verticalSizeClass 만 regular 로 남으면, 정작 그 축으로 갈라지는 레이아웃
    /// (2열 전환·여백 축소)이 하네스에서는 절대 나타나지 않는다.
    /// iOS 가 vertical compact 를 주는 문맥은 가로로 든 iPhone 뿐이라,
    /// 폭이 compact 이면서 높이가 500pt 아래인 창을 같은 문맥으로 본다.
    private var verticalCompact: Bool { compact && height < 500 }

    var body: some View {
        GeometryReader { geo in
            // 화면(세로 1032pt)보다 넓은 폭도 봐야 한다 — 가로모드는 1366pt 다.
            // scaleEffect 는 그리기만 줄이고 레이아웃은 지정한 폭 그대로 계산한다.
            // 즉 "1366pt 에서 어떻게 배치되는가" 는 진짜로 확인된다.
            let scale = min(1, (geo.size.width - 24) / width,
                               (geo.size.height - 56) / height)

            ZStack {
                Color(hex: 0x30343F).ignoresSafeArea()

                VStack(spacing: 10) {
                    Text("\(screenLabel) · \(Int(width)) × \(Int(height)) pt · \(compact ? "compact" : "regular")"
                         + (verticalCompact ? " · V:compact" : "")
                         + (scale < 1 ? String(format: " · %.0f%% 축소", scale * 100) : ""))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    auditedContent
                        .environment(\.horizontalSizeClass, compact ? .compact : .regular)
                        .environment(\.verticalSizeClass, verticalCompact ? .compact : .regular)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        )
                        .scaleEffect(scale)
                        .frame(width: width * scale, height: height * scale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder private var auditedContent: some View {
        if showsAuth { AuthScreen() }
        else if screenLabel == "match" {
            GoatArenaMatchPlayScreen(
                matchId: "fixture-match",
                briefing: GoatArenaMatchBriefing(skipsLobby: true)
            )
        }
        else { RootView() }
    }
}
#endif
