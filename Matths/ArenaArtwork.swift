//  ArenaArtwork.swift
//  Matths
//
//  GOAT Arena 전용 래스터 아트의 공통 렌더러.
//  생성 이미지는 정보나 브랜드 마크를 대신하지 않고 배경 깊이만 담당한다.
//  실제 제목·상태·티어·행동은 항상 SwiftUI 텍스트와 기존 RankBadge가 앞에 그린다.

import SwiftUI

struct ArenaArtworkBackground: View {
    let imageName: String
    var focalAlignment: Alignment = .center
    var darkening: Double = 0.18

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Tokens.brandNavy

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: focalAlignment)
                    .clipped()
                    .saturation(0.92)
                    // 30일 페이백 화면에서는 생성형 SF 금고가 주인공이 되면 안 된다.
                    // 실제 상태를 설명하는 좌표·함수·30칸 진행 흔적의 낮은 배경 질감만 남긴다.
                    .opacity(imageName == "ArenaVaultBackdrop" ? 0.16 : 0.72)

                // 범용 SF 배경으로 끝나지 않도록 Matths의 실제 소재인 좌표·함수
                // 궤적을 얹는다. 정보 텍스트가 아니라 낮은 대비의 배경 문법이며,
                // Canvas라 어떤 Split View 폭에서도 잘리거나 늘어나지 않는다.
                ArenaMathOverlay(showsThirtyDayTrace: imageName == "ArenaVaultBackdrop")

                Color.black.opacity(darkening)

                LinearGradient(
                    colors: [
                        Tokens.brandNavy.opacity(0.97),
                        Tokens.brandNavy.opacity(0.76),
                        Tokens.brandNavy.opacity(0.18),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct ArenaMathOverlay: View {
    let showsThirtyDayTrace: Bool

    var body: some View {
        Canvas { context, size in
            let region = CGRect(
                x: size.width * 0.48,
                y: size.height * 0.12,
                width: size.width * 0.46,
                height: size.height * 0.76)
            guard region.width > 1, region.height > 1 else { return }

            let grid = Color.white.opacity(0.11)
            let axis = Tokens.brandCyan.opacity(0.34)
            let curve = Tokens.brandCyan.opacity(0.72)

            for step in 0...6 {
                let x = region.minX + region.width * CGFloat(step) / 6
                var line = Path()
                line.move(to: CGPoint(x: x, y: region.minY))
                line.addLine(to: CGPoint(x: x, y: region.maxY))
                context.stroke(line, with: .color(grid), lineWidth: 0.5)
            }
            for step in 0...4 {
                let y = region.minY + region.height * CGFloat(step) / 4
                var line = Path()
                line.move(to: CGPoint(x: region.minX, y: y))
                line.addLine(to: CGPoint(x: region.maxX, y: y))
                context.stroke(line, with: .color(grid), lineWidth: 0.5)
            }

            var axes = Path()
            axes.move(to: CGPoint(x: region.midX, y: region.minY))
            axes.addLine(to: CGPoint(x: region.midX, y: region.maxY))
            axes.move(to: CGPoint(x: region.minX, y: region.midY))
            axes.addLine(to: CGPoint(x: region.maxX, y: region.midY))
            context.stroke(axes, with: .color(axis), lineWidth: 0.8)

            var function = Path()
            for sample in 0...80 {
                let t = CGFloat(sample) / 80
                let normalizedX = t * 2 - 1
                let normalizedY = 0.62 * normalizedX * normalizedX - 0.22
                let point = CGPoint(
                    x: region.minX + t * region.width,
                    y: region.midY - normalizedY * region.height * 0.54)
                if sample == 0 {
                    function.move(to: point)
                } else {
                    function.addLine(to: point)
                }
            }
            context.stroke(function, with: .color(curve), lineWidth: 1.35)

            if showsThirtyDayTrace {
                let gap = region.width / 30
                for day in 0..<30 {
                    let filled = day < 18
                    let rect = CGRect(
                        x: region.minX + CGFloat(day) * gap,
                        y: region.maxY + 7,
                        width: max(1, gap - 1.5),
                        height: 3)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color((filled ? Tokens.brandCyan : Color.white)
                            .opacity(filled ? 0.62 : 0.16)))
                }
            }
        }
        .mask {
            LinearGradient(
                colors: [.clear, .white.opacity(0.72), .white],
                startPoint: .leading,
                endPoint: .trailing)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct ArenaArtBanner: View {
    let imageName: String
    let eyebrow: String
    let title: String
    let detail: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var height: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 230 }
        return horizontalSizeClass == .compact ? 154 : 176
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ArenaArtworkBackground(
                imageName: imageName,
                focalAlignment: .trailing,
                darkening: 0.12)

            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text(eyebrow)
                    .font(.mMicro)
                    .foregroundStyle(Tokens.brandCyan)
                    .tracking(1.2)

                Text(title)
                    .font(.mHeading)
                    .foregroundStyle(Tokens.onNavy)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.mCaption)
                    .foregroundStyle(Tokens.onNavy.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 480, alignment: .leading)
            .padding(horizontalSizeClass == .compact ? Tokens.Space.s4 : Tokens.Space.s6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.brandCyan.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
