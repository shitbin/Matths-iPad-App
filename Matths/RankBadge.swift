//
//  RankBadge.swift
//  Matths
//
//  GOAT Arena 티어 휘장. 서버의 티어 코드는 그대로 받아 표현만 담당한다.
//  챌린저는 배경 광륜·중경 장식·전경 보석을 독립 레이어로 조립한다.
//

import SwiftUI
import UIKit
import AVFoundation
import ImageIO
import Darwin

enum RankTier: String, CaseIterable {
    case bronze = "BRONZE"
    case silver = "SILVER"
    case gold = "GOLD"
    case platinum = "PLATINUM"
    case emerald = "EMERALD"
    case diamond = "DIAMOND"
    case master = "MASTER"
    case grandmaster = "GRANDMASTER"
    case challenger = "CHALLENGER"

    init?(serverCode: String?) {
        guard let code = serverCode?.uppercased() else { return nil }
        self.init(rawValue: code)
    }

    var label: String {
        switch self {
        case .bronze: return "브론즈"
        case .silver: return "실버"
        case .gold: return "골드"
        case .platinum: return "플래티넘"
        case .emerald: return "에메랄드"
        case .diamond: return "다이아몬드"
        case .master: return "마스터"
        case .grandmaster: return "그랜드마스터"
        case .challenger: return "챌린저"
        }
    }

    var assetName: String { "rank-\(rawValue.lowercased())" }

    var accentColor: Color {
        switch self {
        case .bronze: return Color(hex: 0xC17442)
        case .silver: return Color(hex: 0xC8D2E4)
        case .gold: return Color(hex: 0xF2B81D)
        case .platinum: return Color(hex: 0x33D5D1)
        case .emerald: return Color(hex: 0x1ED760)
        case .diamond: return Color(hex: 0x3396FF)
        case .master: return Color(hex: 0xA855F7)
        case .grandmaster: return Color(hex: 0xFF315C)
        case .challenger: return Color(hex: 0x59D7FF)
        }
    }

    var promotionSecondary: Color {
        switch self {
        case .bronze: return Color(hex: 0x6B2E18)
        case .silver: return Color(hex: 0x74869E)
        case .gold: return Color(hex: 0xFF7A00)
        case .platinum: return Color(hex: 0x177E89)
        case .emerald: return Color(hex: 0x08783E)
        case .diamond: return Color(hex: 0x174EA6)
        case .master: return Color(hex: 0x5B21B6)
        case .grandmaster: return Color(hex: 0x790D36)
        case .challenger: return Color(hex: 0x175CA8)
        }
    }

    var promotionHighlight: Color {
        switch self {
        case .bronze: return Color(hex: 0xFFD09A)
        case .silver: return Color(hex: 0xF5FAFF)
        case .gold: return Color(hex: 0xFFF3A0)
        case .platinum: return Color(hex: 0xB7FFFF)
        case .emerald: return Color(hex: 0xC8FFD7)
        case .diamond: return Color(hex: 0xBCE9FF)
        case .master: return Color(hex: 0xF1C7FF)
        case .grandmaster: return Color(hex: 0xFFC0D2)
        case .challenger: return Color(hex: 0xFFF7D2)
        }
    }

    var promotionRayCount: Int {
        switch self {
        case .bronze: return 6
        case .silver: return 8
        case .gold: return 10
        case .platinum: return 12
        case .emerald: return 14
        case .diamond: return 16
        case .master: return 18
        case .grandmaster: return 20
        case .challenger: return 22
        }
    }

    var promotionLevel: Int {
        switch self {
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .platinum: return 4
        case .emerald: return 5
        case .diamond: return 6
        case .master: return 7
        case .grandmaster: return 8
        case .challenger: return 9
        }
    }

    var promotionParticleCount: Int {
        6 + promotionLevel * 2
    }

    var promotionRingCount: Int {
        switch promotionLevel {
        case 1...3: return 1
        case 4...5: return 2
        case 6...7: return 3
        default: return 4
        }
    }
}

struct RankBadgeView: View {
    let tierCode: String?
    var size: CGFloat = 104
    var animated = true

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var sheenPassed = false
    @State private var playbackID = UUID()

    private var tier: RankTier? { RankTier(serverCode: tierCode) }
    private var motionActive: Bool { animated && store.motionOn && !reduceMotion }

    var body: some View {
        Group {
            if let tier {
                if tier == .challenger {
                    ChallengerLayeredBadge(
                        size: size,
                        motionActive: motionActive,
                        playbackID: playbackID)
                } else {
                    standardBadge(tier)
                }
            } else {
                Image(systemName: "shield.slash")
                    .font(.system(size: size * 0.34, weight: .light))
                    .foregroundStyle(Tokens.text3)
                    .frame(width: size, height: size)
                    .accessibilityLabel("티어 미발급")
            }
        }
        .frame(width: size * 1.42, height: size * 1.42)
        .onAppear { playReveal() }
        .onChange(of: tier?.rawValue) { _, _ in playReveal() }
        .onChange(of: motionActive) { _, _ in playReveal() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tier.map { "\($0.label) 랭크 휘장" } ?? "티어 미발급")
        .allowsHitTesting(false)
    }

    private func standardBadge(_ tier: RankTier) -> some View {
        ZStack {
            Circle()
                .fill(tier.accentColor.opacity(0.16))
                .frame(width: size * 0.78, height: size * 0.78)
                .blur(radius: size * 0.18)

            if motionActive {
                LottieWebView(name: "rank-badge-fx")
                    .id(playbackID)
                    .colorMultiply(tier.accentColor)
                    .frame(width: size * 1.42, height: size * 1.42)
                    .accessibilityHidden(true)
            }

            badgeArtwork(tier)
                .overlay {
                    if motionActive {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.92), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing))
                            .frame(width: size * 0.24, height: size * 1.35)
                            .rotationEffect(.degrees(18))
                            .offset(x: sheenPassed ? size * 0.92 : -size * 0.92)
                            .frame(width: size, height: size)
                            .mask(badgeArtwork(tier))
                            .blendMode(.screen)
                            .accessibilityHidden(true)
                    }
                }
                .scaleEffect(!motionActive || revealed ? 1 : 0.72)
                .rotation3DEffect(
                    .degrees(!motionActive || revealed ? 0 : -24),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.65)
                .opacity(!motionActive || revealed ? 1 : 0)
                .shadow(
                    color: tier.accentColor.opacity(0.34),
                    radius: size * 0.08,
                    y: size * 0.035)
        }
    }

    @ViewBuilder
    private func badgeArtwork(_ tier: RankTier) -> some View {
        if let image = RankBadgeAssets.image(named: tier.assetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: size * 0.56, weight: .light))
                .foregroundStyle(tier.accentColor)
                .frame(width: size, height: size)
        }
    }

    private func playReveal() {
        playbackID = UUID()
        guard motionActive else {
            revealed = true
            sheenPassed = true
            return
        }

        revealed = false
        sheenPassed = false
        withAnimation(.spring(response: 0.56, dampingFraction: 0.78)) {
            revealed = true
        }
        withAnimation(.easeInOut(duration: 0.72).delay(0.2)) {
            sheenPassed = true
        }
    }
}

// MARK: - Challenger three-plane assembly

/// Remotion 원본과 같은 순서로 재생한다.
/// 1) 배경 광륜이 중심에서 확장, 2) 좌우 날개와 왕관이 바깥으로 전개,
/// 3) 전경 보석이 점화되며 잠긴다.
private struct ChallengerLayeredBadge: View {
    let size: CGFloat
    let motionActive: Bool
    let playbackID: UUID
    var startDelay: TimeInterval = 0

    @State private var phase = 5
    @State private var backReveal: CGFloat = 1
    @State private var leftArmorReveal: CGFloat = 1
    @State private var rightArmorReveal: CGFloat = 1
    @State private var crownReveal: CGFloat = 1
    @State private var coreReveal: CGFloat = 1
    @State private var lockRingReveal: CGFloat = 1
    @State private var cameraPitch = 0.0
    @State private var cameraYaw = 0.0
    @State private var cameraRoll = 0.0
    @State private var cameraOffset = CGSize.zero
    @State private var cameraZoom: CGFloat = 1
    @State private var impactFlash: CGFloat = 0
    @State private var shockwave: CGFloat = 1
    @State private var whiteout: CGFloat = 0
    @State private var runID = UUID()

    private var hasV5Assets: Bool {
        RankBadgeAssets.image(
            named: "challenger-back-frame",
            subdirectory: "RankBadges/MechanicalV5/challenger") != nil
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x20C9FF).opacity(phase >= 1 ? 0.22 : 0))
                .frame(width: size * 0.92, height: size * 0.92)
                .blur(radius: size * 0.22)
                .scaleEffect(phase >= 1 ? 1 : 0.08)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(hex: 0x4AD8FF), .white, Color(hex: 0xD7A83C), .clear],
                        center: .center),
                    lineWidth: size * 0.012)
                .frame(width: size * 1.12, height: size * 1.12)
                .scaleEffect(phase >= 1 ? 1 : 0.08)
                .rotationEffect(.degrees(phase >= 1 ? 0 : -38))
                .opacity(phase >= 1 ? 0.72 : 0)
                .shadow(color: Color(hex: 0x4AD8FF), radius: size * 0.045)
                .blendMode(.screen)

            if !hasV5Assets {
                layerArtwork("challenger-back")
                    .scaleEffect(0.08 + backReveal * 0.92)
                    .rotationEffect(.degrees(-32 * Double(1 - backReveal)))
                    .opacity(backReveal)
                    .shadow(color: Color(hex: 0x32D9FF).opacity(0.58), radius: size * 0.12)
            }

            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? Color.white : Color(hex: 0x58DCFF))
                    .frame(width: size * 0.012, height: size * 0.24)
                    .offset(y: -size * 0.62)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .scaleEffect(phase >= 2 ? 1 : 0.12, anchor: .bottom)
                    .opacity(phase >= 2 ? 0.62 : 0)
                    .shadow(color: Color(hex: 0x58DCFF), radius: size * 0.025)
                    .blendMode(.screen)
            }

            middleArtwork

            if hasV5Assets {
                mechanicalArtwork("lock-ring", fallback: "challenger-back")
                    .scaleEffect(0.1 + lockRingReveal * 0.9)
                    .rotation3DEffect(
                        .degrees(88 * Double(1 - lockRingReveal)),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.72)
                    .opacity(lockRingReveal)
                    .shadow(color: Color(hex: 0x59D7FF).opacity(0.9), radius: size * 0.12)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.9), Color(hex: 0x64E5FF).opacity(0.48), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.34))
                .frame(width: size * 0.7, height: size * 0.7)
                .scaleEffect(0.04 + coreReveal * 1.38)
                .opacity(coreReveal * (phase == 4 ? 0.74 : phase >= 5 ? 0.16 : 0))
                .blendMode(.screen)

            layerArtwork("challenger-front")
                .scaleEffect(0.08 + coreReveal * 0.92)
                .offset(y: size * 0.2 * (1 - coreReveal))
                .opacity(coreReveal)
                .shadow(color: .white.opacity(0.72), radius: coreReveal * size * 0.035)
                .overlay { frontSheen }

            ForEach(0..<28, id: \.self) { index in
                let angle = Double(index) * 2.399963
                let distance = size * (0.04 + shockwave * (0.42 + CGFloat(index % 5) * 0.03))
                TriangleSpark()
                    .fill(index.isMultiple(of: 3) ? Color.white : Color(hex: 0x9BEBFF))
                    .frame(width: index.isMultiple(of: 4) ? size * 0.018 : size * 0.009,
                           height: size * (0.05 + CGFloat(index % 6) * 0.012))
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: cos(angle) * distance, y: sin(angle) * distance)
                    .opacity(impactFlash * (1 - shockwave * 0.7))
                    .shadow(color: .white, radius: size * 0.02)
                    .blendMode(.screen)
            }

            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.94), Color(hex: 0x68E4FF).opacity(0.5),
                             Color(hex: 0x665BFF).opacity(0.14), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.72))
                .frame(width: size * 1.72, height: size * 1.72)
                .scaleEffect(0.18 + shockwave * 1.28)
                .opacity(whiteout * 0.88)
                .blur(radius: size * 0.008)
                .blendMode(.screen)

            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, Color(hex: 0x68E4FF).opacity(0.18), .white.opacity(0.88),
                             Color(hex: 0xFFE2A6).opacity(0.2), .clear],
                    startPoint: .leading,
                    endPoint: .trailing))
                .frame(width: size * 1.9, height: size * 0.09)
                .scaleEffect(x: 0.08 + shockwave * 0.92, y: 1)
                .opacity(whiteout * 0.78)
                .blur(radius: size * 0.012)
                .blendMode(.screen)
        }
        .frame(width: size * 1.42, height: size * 1.42)
        .scaleEffect(cameraZoom)
        .offset(cameraOffset)
        .rotation3DEffect(.degrees(cameraPitch), axis: (x: 1, y: 0, z: 0), perspective: 0.72)
        .rotation3DEffect(.degrees(cameraYaw), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
        .rotationEffect(.degrees(cameraRoll))
        .onAppear { play() }
        .onChange(of: playbackID) { _, _ in play() }
    }

    private var middleArtwork: some View {
        ZStack {
            if hasV5Assets {
                mechanicalArtwork("armor-left", fallback: "challenger-mid")
                    .offset(x: size * 0.3 * (1 - leftArmorReveal))
                    .rotation3DEffect(
                        .degrees(-72 * Double(1 - leftArmorReveal)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .trailing,
                        perspective: 0.72)
                    .rotationEffect(.degrees(17 * Double(1 - leftArmorReveal)), anchor: .bottom)
                    .opacity(leftArmorReveal)

                mechanicalArtwork("armor-right", fallback: "challenger-mid")
                    .offset(x: -size * 0.3 * (1 - rightArmorReveal))
                    .rotation3DEffect(
                        .degrees(72 * Double(1 - rightArmorReveal)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.72)
                    .rotationEffect(.degrees(-17 * Double(1 - rightArmorReveal)), anchor: .bottom)
                    .opacity(rightArmorReveal)

                mechanicalArtwork("crown", fallback: "challenger-mid")
                    .offset(y: -size * 0.42 * (1 - crownReveal))
                    .rotation3DEffect(
                        .degrees(-76 * Double(1 - crownReveal)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.72)
                    .scaleEffect(0.18 + crownReveal * 0.82, anchor: .bottom)
                    .opacity(crownReveal)
            } else {
                mechanicalArtwork("armor-left", fallback: "challenger-mid")
                    .mask { wingMask(side: .left) }
                    .offset(x: phase >= 2 ? 0 : size * 0.3)
                    .rotationEffect(.degrees(phase >= 2 ? 0 : 17), anchor: .bottom)

                mechanicalArtwork("armor-right", fallback: "challenger-mid")
                    .mask { wingMask(side: .right) }
                    .offset(x: phase >= 2 ? 0 : -size * 0.3)
                    .rotationEffect(.degrees(phase >= 2 ? 0 : -17), anchor: .bottom)

                mechanicalArtwork("crown", fallback: "challenger-mid")
                    .mask { crownMask }
                    .offset(y: phase >= 3 ? 0 : -size * 0.42)
                    .scaleEffect(phase >= 3 ? 1 : 0.18, anchor: .bottom)
                    .opacity(phase >= 3 ? 1 : 0)
            }
        }
        .opacity(max(leftArmorReveal, rightArmorReveal, crownReveal))
        .shadow(color: Color(hex: 0x73E5FF).opacity(0.42), radius: size * 0.045)
    }

    private enum WingSide { case left, right }

    private func wingMask(side: WingSide) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: size * 0.3)
            HStack(spacing: 0) {
                if side == .right { Color.clear }
                Rectangle()
                if side == .left { Color.clear }
            }
        }
        .frame(width: size, height: size)
    }

    private var crownMask: some View {
        VStack(spacing: 0) {
            Rectangle().frame(height: size * 0.36)
            Color.clear
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func layerArtwork(_ name: String) -> some View {
        let mechanicalName: String? = switch name {
        case "challenger-back": "back-frame"
        case "challenger-front": "core"
        default: nil
        }
        if let mechanicalName, hasV5Assets {
            if let image = RankBadgeAssets.image(
                named: "challenger-\(mechanicalName)",
                subdirectory: "RankBadges/MechanicalV5/challenger") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        } else if let image = RankBadgeAssets.image(
            named: name,
            subdirectory: "RankBadges/ChallengerLayers") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func mechanicalArtwork(_ name: String, fallback: String) -> some View {
        if let image = RankBadgeAssets.image(
            named: "challenger-\(name)",
            subdirectory: "RankBadges/MechanicalV5/challenger") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if hasV5Assets {
            EmptyView()
        } else {
            layerArtwork(fallback)
        }
    }

    @ViewBuilder
    private var frontSheen: some View {
        if motionActive {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.96), .clear],
                        startPoint: .leading,
                        endPoint: .trailing))
                .frame(width: size * 0.18, height: size * 1.2)
                .rotationEffect(.degrees(16))
                .offset(x: phase >= 5 ? size * 0.78 : -size * 0.78)
                .frame(width: size, height: size)
                .mask(layerArtwork("challenger-front"))
                .blendMode(.screen)
                .accessibilityHidden(true)
        }
    }

    private func play() {
        runID = UUID()
        guard motionActive else {
            phase = 5
            backReveal = 1
            leftArmorReveal = 1
            rightArmorReveal = 1
            crownReveal = 1
            coreReveal = 1
            cameraPitch = 0
            cameraYaw = 0
            cameraRoll = 0
            cameraOffset = .zero
            cameraZoom = 1
            impactFlash = 0
            shockwave = 1
            whiteout = 0
            lockRingReveal = 1
            return
        }

        let currentRun = runID
        phase = 0
        backReveal = 0
        leftArmorReveal = 0
        rightArmorReveal = 0
        crownReveal = 0
        coreReveal = 0
        cameraPitch = 0
        cameraYaw = 0
        cameraRoll = 0
        cameraOffset = .zero
        cameraZoom = 1
        impactFlash = 0
        shockwave = 0
        whiteout = 0
        lockRingReveal = 0
        animate(after: startDelay + 0.70, run: currentRun, phase: 1,
                animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.28))
        animate(after: startDelay + 1.73, run: currentRun, phase: 2,
                animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.28))
        animate(after: startDelay + 3.20, run: currentRun, phase: 3,
                animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.24))
        animate(after: startDelay + 3.77, run: currentRun, phase: 4,
                animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.22))
        animate(after: startDelay + 4.20, run: currentRun, phase: 5,
                animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.4))
        weightedLock(arrival: startDelay + 0.70, run: currentRun) { backReveal = $0 }
        weightedLock(arrival: startDelay + 0.70, run: currentRun) { leftArmorReveal = $0 }
        weightedLock(arrival: startDelay + 2.17, run: currentRun) { rightArmorReveal = $0 }
        weightedLock(arrival: startDelay + 2.83, run: currentRun) { lockRingReveal = $0 }
        weightedLock(arrival: startDelay + 3.20, run: currentRun) { crownReveal = $0 }
        weightedLock(arrival: startDelay + 3.77, run: currentRun) { coreReveal = $0 }
        cameraImpact(at: startDelay + 0.70, run: currentRun, direction: 1, strength: 0.48)
        cameraImpact(at: startDelay + 2.17, run: currentRun, direction: -1, strength: 0.72)
        finalImpact(at: startDelay + 3.77, run: currentRun)
    }

    private func animate(
        after delay: TimeInterval,
        run: UUID,
        phase nextPhase: Int,
        animation: Animation
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard runID == run else { return }
            withAnimation(animation) { phase = nextPhase }
        }
    }

    private func cameraImpact(
        at arrival: TimeInterval,
        run: UUID,
        direction: Double,
        strength: Double
    ) {
        let scalar = CGFloat(strength)
        let horizontal = CGFloat(direction * strength)
        schedule(after: arrival - 0.06, run: run,
                 animation: .timingCurve(0.18, 0.7, 0.24, 1, duration: 0.1)) {
            cameraPitch = -0.9 * strength
            cameraYaw = 1.35 * direction * strength
            cameraRoll = 0.42 * direction * strength
            cameraOffset = CGSize(width: size * 0.011 * horizontal, height: -size * 0.007 * scalar)
            cameraZoom = 1 + 0.014 * scalar
            impactFlash = min(0.42, 0.12 + scalar * 0.14)
            shockwave = 0.12
        }
        schedule(after: arrival + 0.08, run: run, animation: .easeOut(duration: 0.2)) {
            cameraPitch = 0.18 * strength
            cameraYaw = -0.28 * direction * strength
            cameraRoll = -0.1 * direction * strength
            cameraOffset = CGSize(width: -size * 0.0025 * horizontal, height: size * 0.002 * scalar)
            cameraZoom = 0.997
            shockwave = 0.56
        }
        schedule(after: arrival + 0.3, run: run, animation: .easeOut(duration: 0.28)) {
            cameraPitch = 0
            cameraYaw = 0
            cameraRoll = 0
            cameraOffset = .zero
            cameraZoom = 1
            impactFlash = 0
            shockwave = 1
        }
    }

    private func weightedLock(
        arrival: TimeInterval,
        run: UUID,
        setter: @escaping (CGFloat) -> Void
    ) {
        schedule(after: arrival - 0.54, run: run,
                 animation: .timingCurve(0.55, 0, 0.92, 0.55, duration: 0.54)) {
            setter(0.992)
        }
        schedule(after: arrival, run: run,
                 animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.2)) {
            setter(1)
        }
    }

    private func finalImpact(at arrival: TimeInterval, run: UUID) {
        schedule(after: arrival - 0.08, run: run,
                 animation: .timingCurve(0.18, 0.7, 0.24, 1, duration: 0.12)) {
            cameraPitch = -2.1
            cameraYaw = 3.0
            cameraRoll = 0.58
            cameraOffset = CGSize(width: size * 0.018, height: -size * 0.021)
            cameraZoom = 1.075
            impactFlash = 0.86
            shockwave = 0.1
            whiteout = 0.72
        }
        schedule(after: arrival + 0.1, run: run, animation: .easeOut(duration: 0.2)) {
            cameraPitch = 0.46
            cameraYaw = -0.7
            cameraRoll = -0.14
            cameraOffset = CGSize(width: -size * 0.004, height: size * 0.005)
            cameraZoom = 0.993
            shockwave = 0.58
            whiteout = 0.22
        }
        schedule(after: arrival + 0.34, run: run, animation: .easeOut(duration: 0.3)) {
            cameraPitch = 0
            cameraYaw = 0
            cameraRoll = 0
            cameraOffset = .zero
            cameraZoom = 1
            impactFlash = 0
            shockwave = 1
            whiteout = 0
        }
    }

    private func schedule(
        after delay: TimeInterval,
        run: UUID,
        animation: Animation,
        action: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard runID == run else { return }
            withAnimation(animation) { action() }
        }
    }
}

// MARK: - Full-screen promotion

/// 승급 장면 가장 아래에서만 움직이는 전체 화면 상승판.
/// 선을 그리는 대신 청백색 금속·사파이어·금색 면을 채워 아래에서 위로 통과시킨다.
private struct ChallengerAscensionUnderlay: View {
    let playbackID: UUID
    let motionActive: Bool

    @State private var baseReveal: CGFloat = 0.03
    @State private var outerReveal: CGFloat = 0
    @State private var silverReveal: CGFloat = 0
    @State private var sapphireReveal: CGFloat = 0
    @State private var goldReveal: CGFloat = 0
    @State private var beamReveal: CGFloat = 0
    @State private var waveReveal: CGFloat = 0
    @State private var sparkReveal: CGFloat = 0
    @State private var sweepReveal: CGFloat = 0
    @State private var plateOpacity = 0.0
    @State private var underlayOpacity = 1.0
    @State private var runID = UUID()

    var body: some View {
        GeometryReader { proxy in
            let planeSize = CGSize(
                width: proxy.size.width + 100,
                height: proxy.size.height * 1.25)

            ZStack {
                Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(hex: 0x030918),
                            Color(hex: 0x09295A),
                            Color(hex: 0x087CB8),
                            Color(hex: 0x11376E),
                            Color(hex: 0x030815),
                        ]),
                        startPoint: CGPoint(x: size.width * 0.16, y: 0),
                        endPoint: CGPoint(x: size.width * 0.84, y: size.height)))

                context.fill(
                    polygon([(0, 0), (0.34, 0), (0.49, 1), (0, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0x071731), Color(hex: 0x2F8FC7), Color(hex: 0xD9F8FF)]),
                        startPoint: CGPoint(x: 0, y: size.height * 0.5),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.5)))

                context.fill(
                    polygon([(0.66, 0), (1, 0), (1, 1), (0.51, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xD9F8FF), Color(hex: 0x2F8FC7), Color(hex: 0x071731)]),
                        startPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                        endPoint: CGPoint(x: size.width, y: size.height * 0.5)))

                context.fill(
                    polygon([(0.27, 0), (0.73, 0), (0.57, 1), (0.43, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xDFF9FF), Color(hex: 0x45CFFF), Color(hex: 0x116FB8), Color(hex: 0x132D74)]),
                        startPoint: CGPoint(x: size.width * 0.5, y: 0),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height)))

                context.fill(
                    polygon([(0.17, 0), (0.39, 0), (0.45, 1), (0.24, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [.white.opacity(0.94), Color(hex: 0x93E7FF).opacity(0.52), Color(hex: 0x1A5A97).opacity(0.36)]),
                        startPoint: CGPoint(x: size.width * 0.17, y: 0),
                        endPoint: CGPoint(x: size.width * 0.45, y: size.height)))

                context.fill(
                    polygon([(0.61, 0), (0.83, 0), (0.76, 1), (0.55, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [.white.opacity(0.94), Color(hex: 0x93E7FF).opacity(0.52), Color(hex: 0x1A5A97).opacity(0.36)]),
                        startPoint: CGPoint(x: size.width * 0.83, y: 0),
                        endPoint: CGPoint(x: size.width * 0.55, y: size.height)))

                context.fill(
                    polygon([(0.41, 0), (0.45, 0), (0.43, 1), (0.37, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFF7D2), Color(hex: 0xD7A83C), Color(hex: 0x6AAEE1)]),
                        startPoint: CGPoint(x: size.width * 0.42, y: 0),
                        endPoint: CGPoint(x: size.width * 0.4, y: size.height)))

                context.fill(
                    polygon([(0.55, 0), (0.59, 0), (0.63, 1), (0.57, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFF7D2), Color(hex: 0xD7A83C), Color(hex: 0x6AAEE1)]),
                        startPoint: CGPoint(x: size.width * 0.58, y: 0),
                        endPoint: CGPoint(x: size.width * 0.6, y: size.height)))

                var lightContext = context
                lightContext.blendMode = .screen
                lightContext.fill(
                    polygon([(0.46, 0), (0.54, 0), (0.53, 1), (0.47, 1)], size),
                    with: .linearGradient(
                        Gradient(colors: [.white, Color(hex: 0xB8F3FF), Color(hex: 0x4BD4FF), .white]),
                        startPoint: CGPoint(x: size.width * 0.5, y: 0),
                        endPoint: CGPoint(x: size.width * 0.5, y: size.height)))

                let facets: [[(CGFloat, CGFloat)]] = [
                    [(0, 0.07), (0.38, 0.14), (0.46, 0.31), (0.08, 0.24)],
                    [(1, 0.07), (0.62, 0.14), (0.54, 0.31), (0.92, 0.24)],
                    [(0.02, 0.35), (0.35, 0.3), (0.45, 0.49), (0.07, 0.57)],
                    [(0.98, 0.35), (0.65, 0.3), (0.55, 0.49), (0.93, 0.57)],
                    [(0, 0.65), (0.34, 0.57), (0.44, 0.76), (0.1, 0.86)],
                    [(1, 0.65), (0.66, 0.57), (0.56, 0.76), (0.9, 0.86)],
                    [(0.09, 0.91), (0.39, 0.75), (0.46, 1), (0.21, 1)],
                    [(0.91, 0.91), (0.61, 0.75), (0.54, 1), (0.79, 1)],
                ]
                let facetColors = [
                    Color(hex: 0xDAFAFF).opacity(0.28),
                    Color(hex: 0xDAFAFF).opacity(0.28),
                    Color(hex: 0x40CAFF).opacity(0.24),
                    Color(hex: 0x40CAFF).opacity(0.24),
                    Color(hex: 0xFFDE8B).opacity(0.18),
                    Color(hex: 0xFFDE8B).opacity(0.18),
                    Color(hex: 0xDFFBFF).opacity(0.22),
                    Color(hex: 0xDFFBFF).opacity(0.22),
                ]
                for index in facets.indices {
                    lightContext.fill(polygon(facets[index], size), with: .color(facetColors[index]))
                }

                lightContext.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width * 0.12,
                        y: size.height * 0.24,
                        width: size.width * 0.76,
                        height: size.height * 0.52)),
                    with: .radialGradient(
                        Gradient(colors: [.white.opacity(0.3), Color(hex: 0x53D9FF).opacity(0.12), .clear]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                        startRadius: 0,
                        endRadius: size.width * 0.48))
                }
                .opacity(plateOpacity * 0.34)

                RelativePolygon(points: [
                    CGPoint(x: 0, y: 0), CGPoint(x: 0.34, y: 0),
                    CGPoint(x: 0.49, y: 1), CGPoint(x: 0, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [Color(hex: 0x071731), Color(hex: 0x2F8FC7), Color(hex: 0xD9F8FF)],
                    startPoint: .leading, endPoint: .trailing))
                .offset(
                    x: -90 * (1 - outerReveal),
                    y: planeSize.height * 0.58 * (1 - outerReveal))
                .rotationEffect(.degrees(-7 * (1 - outerReveal)))
                .opacity(0.54 * outerReveal)

                RelativePolygon(points: [
                    CGPoint(x: 0.66, y: 0), CGPoint(x: 1, y: 0),
                    CGPoint(x: 1, y: 1), CGPoint(x: 0.51, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [Color(hex: 0xD9F8FF), Color(hex: 0x2F8FC7), Color(hex: 0x071731)],
                    startPoint: .leading, endPoint: .trailing))
                .offset(
                    x: 90 * (1 - outerReveal),
                    y: planeSize.height * 0.58 * (1 - outerReveal))
                .rotationEffect(.degrees(7 * (1 - outerReveal)))
                .opacity(0.54 * outerReveal)

                RelativePolygon(points: [
                    CGPoint(x: 0.17, y: 0), CGPoint(x: 0.39, y: 0),
                    CGPoint(x: 0.45, y: 1), CGPoint(x: 0.24, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [.white.opacity(0.9), Color(hex: 0x93E7FF).opacity(0.52), Color(hex: 0x1A5A97).opacity(0.2)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .offset(
                    x: -54 * (1 - silverReveal),
                    y: planeSize.height * 0.48 * (1 - silverReveal))
                .opacity(0.5 * silverReveal)

                RelativePolygon(points: [
                    CGPoint(x: 0.61, y: 0), CGPoint(x: 0.83, y: 0),
                    CGPoint(x: 0.76, y: 1), CGPoint(x: 0.55, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [.white.opacity(0.9), Color(hex: 0x93E7FF).opacity(0.52), Color(hex: 0x1A5A97).opacity(0.2)],
                    startPoint: .topTrailing, endPoint: .bottomLeading))
                .offset(
                    x: 54 * (1 - silverReveal),
                    y: planeSize.height * 0.48 * (1 - silverReveal))
                .opacity(0.5 * silverReveal)

                RelativePolygon(points: [
                    CGPoint(x: 0.27, y: 0), CGPoint(x: 0.73, y: 0),
                    CGPoint(x: 0.57, y: 1), CGPoint(x: 0.43, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [Color(hex: 0xDFF9FF), Color(hex: 0x45CFFF), Color(hex: 0x116FB8), Color(hex: 0x132D74)],
                    startPoint: .top, endPoint: .bottom))
                .scaleEffect(x: 0.68 + 0.32 * sapphireReveal, y: 1)
                .offset(y: planeSize.height * 0.4 * (1 - sapphireReveal))
                .opacity(0.62 * sapphireReveal)
                .shadow(color: Color(hex: 0x43D3FF).opacity(0.45), radius: 36)

                RelativePolygon(points: [
                    CGPoint(x: 0.41, y: 0), CGPoint(x: 0.45, y: 0),
                    CGPoint(x: 0.43, y: 1), CGPoint(x: 0.37, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [Color(hex: 0xFFF7D2), Color(hex: 0xD7A83C), Color(hex: 0x6AAEE1)],
                    startPoint: .top, endPoint: .bottom))
                .offset(y: planeSize.height * 0.3 * (1 - goldReveal))
                .opacity(0.58 * goldReveal)
                .shadow(color: Color(hex: 0xFFD773).opacity(0.52), radius: 20)

                RelativePolygon(points: [
                    CGPoint(x: 0.55, y: 0), CGPoint(x: 0.59, y: 0),
                    CGPoint(x: 0.63, y: 1), CGPoint(x: 0.57, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [Color(hex: 0xFFF7D2), Color(hex: 0xD7A83C), Color(hex: 0x6AAEE1)],
                    startPoint: .top, endPoint: .bottom))
                .offset(y: planeSize.height * 0.3 * (1 - goldReveal))
                .opacity(0.58 * goldReveal)
                .shadow(color: Color(hex: 0xFFD773).opacity(0.52), radius: 20)

                RelativePolygon(points: [
                    CGPoint(x: 0.46, y: 0), CGPoint(x: 0.54, y: 0),
                    CGPoint(x: 0.53, y: 1), CGPoint(x: 0.47, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [.white, Color(hex: 0xB8F3FF), Color(hex: 0x4BD4FF), .white],
                    startPoint: .top, endPoint: .bottom))
                .scaleEffect(x: 0.15 + 0.85 * beamReveal, y: 1)
                .offset(y: planeSize.height * 0.2 * (1 - beamReveal))
                .opacity(0.7 * beamReveal)
                .shadow(color: Color(hex: 0x76EBFF).opacity(0.8), radius: 30)

                ForEach(0..<3, id: \.self) { index in
                    let delayed = max(0, min(1, (waveReveal - CGFloat(index) * 0.16) / 0.68))
                    Ellipse()
                        .stroke(
                            index == 1 ? Color(hex: 0xFFDE8B).opacity(0.65) : Color(hex: 0x70E7FF).opacity(0.72),
                            lineWidth: CGFloat(4 - index))
                        .frame(width: planeSize.width * 0.82, height: planeSize.height * 0.13)
                        .scaleEffect(0.15 + delayed * (1.55 + CGFloat(index) * 0.18))
                        .offset(y: planeSize.height * (0.42 - delayed * 0.48))
                        .opacity((1 - delayed) * delayed * 2.6)
                        .blendMode(.screen)
                }

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, .white.opacity(0.5), Color(hex: 0x4ADBFF).opacity(0.7), .clear],
                        startPoint: .top, endPoint: .bottom))
                    .frame(height: 130)
                    .blur(radius: 16)
                    .offset(y: planeSize.height * (1.15 - sweepReveal * 1.35))
                    .opacity(sin(Double(sweepReveal) * .pi) * 0.75)
                    .blendMode(.screen)

                ForEach(0..<22, id: \.self) { index in
                    let x = CGFloat((index * 173) % 960) - planeSize.width * 0.4
                    let lift = planeSize.height * (0.72 + CGFloat(index % 5) * 0.04)
                    Capsule()
                        .fill(index % 6 == 0 ? Color(hex: 0xFFE39A) : index % 3 == 0 ? .white : Color(hex: 0x66E3FF))
                        .frame(width: index % 5 == 0 ? 7 : 4, height: index % 5 == 0 ? 32 : 18)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -18 : 18))
                        .offset(x: x, y: lift * (1 - sparkReveal) - planeSize.height * 0.28 * sparkReveal)
                        .opacity(sin(Double(sparkReveal) * .pi) * (index % 4 == 0 ? 0.9 : 0.54))
                        .shadow(color: Color(hex: 0x66E3FF), radius: 9)
                        .blendMode(.screen)
                }
            }
            .frame(width: planeSize.width, height: planeSize.height)
            .offset(
                x: -50,
                y: (proxy.size.height - planeSize.height) * 0.5)
            .scaleEffect(x: 1, y: baseReveal, anchor: .bottom)
            .saturation(0.82)
            .brightness(-0.08)
            .opacity(underlayOpacity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { play() }
        .onChange(of: playbackID) { _, _ in play() }
    }

    private func polygon(
        _ points: [(CGFloat, CGFloat)],
        _ size: CGSize
    ) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0 * size.width, y: first.1 * size.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0 * size.width, y: point.1 * size.height))
        }
        path.closeSubpath()
        return path
    }

    private func play() {
        runID = UUID()
        guard motionActive else {
            baseReveal = 1
            plateOpacity = 0
            underlayOpacity = 0
            return
        }

        let currentRun = runID
        baseReveal = 0.03
        outerReveal = 0
        silverReveal = 0
        sapphireReveal = 0
        goldReveal = 0
        beamReveal = 0
        waveReveal = 0
        sparkReveal = 0
        sweepReveal = 0
        plateOpacity = 0
        underlayOpacity = 1
        DispatchQueue.main.async {
            guard runID == currentRun else { return }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.05)) {
                baseReveal = 1
                outerReveal = 1
                waveReveal = 1
                sparkReveal = 1
                sweepReveal = 1
                plateOpacity = 0.58
            }
        }
        animateValue(after: 0.1, run: currentRun, duration: 0.82) { silverReveal = 1 }
        animateValue(after: 0.2, run: currentRun, duration: 0.8) { sapphireReveal = 1 }
        animateValue(after: 0.34, run: currentRun, duration: 0.68) { goldReveal = 1 }
        animateValue(after: 0.48, run: currentRun, duration: 0.58) { beamReveal = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.84) {
            guard runID == currentRun else { return }
            withAnimation(.timingCurve(0.45, 0, 0.55, 1, duration: 1.02)) {
                underlayOpacity = 0
            }
        }
    }

    private func animateValue(
        after delay: TimeInterval,
        run: UUID,
        duration: TimeInterval,
        changes: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard runID == run else { return }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: duration)) {
                changes()
            }
        }
    }
}

private struct RelativePolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(
            x: rect.minX + first.x * rect.width,
            y: rect.minY + first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(
                x: rect.minX + point.x * rect.width,
                y: rect.minY + point.y * rect.height))
        }
        path.closeSubpath()
        return path
    }
}

private struct TriangleSpark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY * 0.76))
        path.closeSubpath()
        return path
    }
}

/// 챌린저를 제외한 8개 티어가 공유하는 전체 화면 3단 배경.
/// 색만 바꾸는 것이 아니라 광선 수와 원형 장식의 비율을 티어마다 달리한다.
private struct StandardTierPromotionUnderlay: View {
    let tier: RankTier
    let playbackID: UUID
    let motionActive: Bool

    @State private var baseReveal: CGFloat = 0.03
    @State private var sideReveal: CGFloat = 0
    @State private var coreReveal: CGFloat = 0
    @State private var ringReveal: CGFloat = 0
    @State private var sparkReveal: CGFloat = 0
    @State private var sweepReveal: CGFloat = 0
    @State private var underlayOpacity: CGFloat = 1
    @State private var runID = UUID()

    var body: some View {
        GeometryReader { proxy in
            let plane = CGSize(width: proxy.size.width + 140, height: proxy.size.height * 1.24)

            ZStack {
                RelativePolygon(points: [
                    CGPoint(x: 0.02, y: 0), CGPoint(x: 0.33, y: 0),
                    CGPoint(x: 0.47, y: 1), CGPoint(x: 0.12, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [tier.promotionSecondary.opacity(0.22), tier.accentColor.opacity(0.56), tier.promotionSecondary.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .offset(x: -80 * (1 - sideReveal), y: plane.height * 0.5 * (1 - sideReveal))
                .rotationEffect(.degrees(-8 * (1 - sideReveal)))

                RelativePolygon(points: [
                    CGPoint(x: 0.67, y: 0), CGPoint(x: 0.98, y: 0),
                    CGPoint(x: 0.88, y: 1), CGPoint(x: 0.53, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [tier.promotionSecondary.opacity(0.08), tier.accentColor.opacity(0.56), tier.promotionSecondary.opacity(0.22)],
                    startPoint: .topTrailing, endPoint: .bottomLeading))
                .offset(x: 80 * (1 - sideReveal), y: plane.height * 0.5 * (1 - sideReveal))
                .rotationEffect(.degrees(8 * (1 - sideReveal)))

                ForEach(0..<tier.promotionRayCount, id: \.self) { index in
                    let count = max(1, tier.promotionRayCount - 1)
                    let progress = CGFloat(index) / CGFloat(count)
                    let centerDistance = abs(progress - 0.5) * 2
                    RelativePolygon(points: [
                        CGPoint(x: 0.43, y: 0), CGPoint(x: 0.57, y: 0),
                        CGPoint(x: 0.51, y: 1), CGPoint(x: 0.49, y: 1),
                    ])
                    .fill(LinearGradient(
                        colors: [
                            tier.promotionHighlight.opacity(0.34 - centerDistance * 0.12),
                            tier.accentColor.opacity(0.18),
                            .clear,
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(Double(progress - 0.5) * (tier == .gold ? 62 : 44)), anchor: .bottom)
                    .scaleEffect(x: 0.18 + coreReveal * 0.82, y: 1, anchor: .bottom)
                    .offset(y: plane.height * 0.34 * (1 - coreReveal))
                    .blendMode(.screen)
                }

                RelativePolygon(points: [
                    CGPoint(x: 0.34, y: 0), CGPoint(x: 0.66, y: 0),
                    CGPoint(x: 0.55, y: 1), CGPoint(x: 0.45, y: 1),
                ])
                .fill(LinearGradient(
                    colors: [tier.promotionHighlight.opacity(0.64), tier.accentColor.opacity(0.5), tier.promotionSecondary.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom))
                .scaleEffect(x: 0.28 + coreReveal * 0.72, y: 1)
                .offset(y: plane.height * 0.4 * (1 - coreReveal))
                .shadow(color: tier.accentColor.opacity(0.7), radius: 38)
                .blendMode(.screen)

                ForEach(0..<tier.promotionRingCount, id: \.self) { index in
                    let delayed = max(0, min(1, (ringReveal - CGFloat(index) * 0.16) / 0.68))
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [.clear, tier.accentColor.opacity(0.16), .clear],
                                center: .center,
                                startRadius: plane.width * 0.23,
                                endRadius: plane.width * 0.44))
                        .overlay {
                            Ellipse()
                                .stroke(index == 1 ? tier.promotionHighlight.opacity(0.62) : tier.accentColor.opacity(0.66), lineWidth: CGFloat(4 - index))
                        }
                        .frame(
                            width: plane.width * (tier == .master || tier == .grandmaster ? 0.74 : 0.88),
                            height: plane.height * (tier == .master || tier == .grandmaster ? 0.22 : 0.12))
                        .scaleEffect(0.12 + delayed * (1.42 + CGFloat(index) * 0.16))
                        .offset(y: plane.height * (0.43 - delayed * 0.48))
                        .opacity((1 - delayed) * delayed * 2.8)
                        .blendMode(.screen)
                }

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, tier.promotionHighlight.opacity(0.5), tier.accentColor.opacity(0.74), .clear],
                        startPoint: .top, endPoint: .bottom))
                    .frame(height: 150)
                    .blur(radius: 18)
                    .offset(y: plane.height * (1.12 - sweepReveal * 1.32))
                    .opacity(sin(Double(sweepReveal) * .pi) * 0.72)
                    .blendMode(.screen)

                ForEach(0..<tier.promotionParticleCount, id: \.self) { index in
                    let x = CGFloat((index * 191) % 1040) - plane.width * 0.43
                    let lift = plane.height * (0.7 + CGFloat(index % 5) * 0.045)
                    Capsule()
                        .fill(index % 5 == 0 ? tier.promotionHighlight : index % 3 == 0 ? .white : tier.accentColor)
                        .frame(width: index % 6 == 0 ? 8 : 4, height: index % 6 == 0 ? 34 : 18)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -20 : 20))
                        .offset(x: x, y: lift * (1 - sparkReveal) - plane.height * 0.3 * sparkReveal)
                        .opacity(sin(Double(sparkReveal) * .pi) * (index % 4 == 0 ? 0.92 : 0.56))
                        .shadow(color: tier.accentColor, radius: 10)
                        .blendMode(.screen)
                }
            }
            // 광선·링·입자 각각을 별도 SwiftUI 합성 노드로 올리면 120Hz iPad에서
            // 첫 1.3초에 규칙적인 main-thread hitch가 생긴다. 모양은 유지하고
            // 전체 배경을 한 Metal 오프스크린 레이어로 합성해 변환 비용을 줄인다.
            .drawingGroup(opaque: false, colorMode: .linear)
            .frame(width: plane.width, height: plane.height)
            .offset(x: -70, y: (proxy.size.height - plane.height) * 0.5)
            .scaleEffect(x: 1, y: baseReveal, anchor: .bottom)
            .opacity(underlayOpacity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { play() }
        .onChange(of: playbackID) { _, _ in play() }
    }

    private func play() {
        runID = UUID()
        guard motionActive else {
            baseReveal = 1
            sideReveal = 1
            coreReveal = 1
            ringReveal = 0
            sparkReveal = 0
            sweepReveal = 0
            underlayOpacity = 0.28
            return
        }

        let currentRun = runID
        baseReveal = 0.03
        sideReveal = 0
        coreReveal = 0
        ringReveal = 0
        sparkReveal = 0
        sweepReveal = 0
        underlayOpacity = 1
        DispatchQueue.main.async {
            guard runID == currentRun else { return }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.08)) {
                baseReveal = 1
                sideReveal = 1
                ringReveal = 1
                sparkReveal = 1
                sweepReveal = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard runID == currentRun else { return }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.82)) {
                coreReveal = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.84) {
            guard runID == currentRun else { return }
            withAnimation(.timingCurve(0.45, 0, 0.55, 1, duration: 1.02)) {
                underlayOpacity = 0
            }
        }
    }
}

/// Imagen으로 별도 제작한 후경·중경·전경 PNG를 순서대로 조립한다.
private struct StandardTierPromotionBadge: View {
    let tier: RankTier
    let size: CGFloat
    let motionActive: Bool
    let playbackID: UUID
    var startDelay: TimeInterval = 1.4

    @State private var backReveal: CGFloat = 0
    @State private var spineReveal: CGFloat = 0
    @State private var leftProngReveal: CGFloat = 0
    @State private var rightProngReveal: CGFloat = 0
    @State private var leftWingReveal: CGFloat = 0
    @State private var rightWingReveal: CGFloat = 0
    @State private var rearWingReveal: CGFloat = 0
    @State private var lockRingReveal: CGFloat = 0
    @State private var crownReveal: CGFloat = 0
    @State private var coreReveal: CGFloat = 0
    @State private var finalCompression: CGFloat = 1
    @State private var cameraPitch = 0.0
    @State private var cameraYaw = 0.0
    @State private var cameraRoll = 0.0
    @State private var cameraOffset = CGSize.zero
    @State private var cameraZoom: CGFloat = 1
    @State private var impactFlash: CGFloat = 0
    @State private var shockwave: CGFloat = 0
    @State private var whiteout: CGFloat = 0
    @State private var sheenPassed = false
    @State private var runID = UUID()

    private var hasV5Assets: Bool {
        RankBadgeAssets.image(
            named: "\(tier.rawValue.lowercased())-back-frame",
            subdirectory: "RankBadges/MechanicalV5/\(tier.rawValue.lowercased())") != nil
    }

    private var hasSegmentedFrame: Bool {
        guard hasV5Assets else { return false }
        let directory = "RankBadges/MechanicalV5/\(tier.rawValue.lowercased())"
        return RankBadgeAssets.image(
            named: "\(tier.rawValue.lowercased())-armor-left",
            subdirectory: directory) != nil
            && RankBadgeAssets.image(
                named: "\(tier.rawValue.lowercased())-armor-right",
                subdirectory: directory) != nil
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tier.accentColor.opacity(0.24))
                .frame(width: size * 0.78, height: size * 0.78)
                .blur(radius: size * 0.17)
                .scaleEffect(0.3 + coreReveal * 0.9)

            if !hasSegmentedFrame {
                mechanicalArtwork("back-frame", fallbackLayer: "back")
                    .scaleEffect(0.16 + backReveal * 0.84)
                    .rotationEffect(.degrees(Double(tier.promotionLevel * 18) * (1 - backReveal)))
                    .opacity(backReveal * (hasV5Assets ? 1 : (1 - rearWingReveal)))
                    .shadow(
                        color: tier.accentColor.opacity(0.38 + Double(tier.promotionLevel) * 0.035),
                        radius: size * (0.035 + CGFloat(tier.promotionLevel) * 0.006))
            }

            if !hasV5Assets {
                rearWing(left: true)
                rearWing(left: false)
            }

            if !hasV5Assets {
                pieceArtwork("spine", fallbackLayer: "mid", fallbackPiece: .spine)
                .offset(y: size * 0.48 * (1 - spineReveal))
                .scaleEffect(x: 0.68 + spineReveal * 0.32, y: 0.24 + spineReveal * 0.76)
                .opacity(spineReveal)
                    .shadow(color: tier.accentColor.opacity(0.46), radius: size * 0.055)

                pieceArtwork("prong-left", fallbackLayer: "mid", fallbackPiece: .leftProng)
                .offset(
                    x: -size * 0.18 * (1 - leftProngReveal),
                    y: size * 0.32 * (1 - leftProngReveal))
                .rotationEffect(.degrees(-24 * (1 - leftProngReveal)), anchor: .bottom)
                .scaleEffect(0.76 + leftProngReveal * 0.24)
                    .opacity(leftProngReveal)

                pieceArtwork("prong-right", fallbackLayer: "mid", fallbackPiece: .rightProng)
                .offset(
                    x: size * 0.18 * (1 - rightProngReveal),
                    y: size * 0.32 * (1 - rightProngReveal))
                .rotationEffect(.degrees(24 * (1 - rightProngReveal)), anchor: .bottom)
                .scaleEffect(0.76 + rightProngReveal * 0.24)
                    .opacity(rightProngReveal)
            }

            if !hasV5Assets || tier.promotionLevel >= 4 {
                pieceArtwork("armor-left", fallbackLayer: "mid", fallbackPiece: .leftWing)
                .offset(
                    x: -size * 0.54 * (1 - leftWingReveal),
                    y: size * 0.1 * (1 - leftWingReveal))
                .rotationEffect(
                    .degrees(Double(-38 - tier.promotionLevel * 2) * (1 - leftWingReveal)),
                    anchor: .bottom)
                .scaleEffect(0.78 + leftWingReveal * 0.22)
                .opacity(leftWingReveal)
                    .shadow(color: tier.accentColor.opacity(0.46), radius: size * 0.055)

                pieceArtwork("armor-right", fallbackLayer: "mid", fallbackPiece: .rightWing)
                .offset(
                    x: size * 0.54 * (1 - rightWingReveal),
                    y: size * 0.1 * (1 - rightWingReveal))
                .rotationEffect(
                    .degrees(Double(38 + tier.promotionLevel * 2) * (1 - rightWingReveal)),
                    anchor: .bottom)
                .scaleEffect(0.78 + rightWingReveal * 0.22)
                .opacity(rightWingReveal)
                    .shadow(color: tier.accentColor.opacity(0.46), radius: size * 0.055)
            }

            if !hasV5Assets || tier.promotionLevel >= 7 {
                pieceArtwork("crown", fallbackLayer: "mid", fallbackPiece: .crown)
                .offset(y: -size * 0.42 * (1 - crownReveal))
                .rotationEffect(.degrees(Double(tier.promotionLevel * 8) * (1 - crownReveal)))
                .scaleEffect(x: 0.42 + crownReveal * 0.58, y: 0.72 + crownReveal * 0.28)
                .opacity(crownReveal)
                    .shadow(color: tier.promotionHighlight.opacity(0.56), radius: size * 0.06)
            }

            if hasV5Assets && tier.promotionLevel >= 7 {
                mechanicalArtwork("lock-ring", fallbackLayer: "back")
                    .scaleEffect(0.1 + lockRingReveal * 0.9)
                    .rotation3DEffect(
                        .degrees(88 * Double(1 - lockRingReveal)),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.72)
                    .opacity(lockRingReveal)
                    .shadow(color: tier.accentColor.opacity(0.86), radius: size * 0.12)
            }

            mechanicalArtwork("core", fallbackLayer: "front")
                .offset(y: size * 0.28 * (1 - coreReveal))
                .scaleEffect(0.06 + coreReveal * 0.94)
                .rotationEffect(.degrees(Double(-tier.promotionLevel * 5) * (1 - coreReveal)))
                .opacity(coreReveal)
                .shadow(color: tier.accentColor.opacity(0.9), radius: size * 0.08)

            if tier.promotionLevel >= 4 {
                ForEach(0..<(tier.promotionLevel == 8 ? 2 : 1), id: \.self) { index in
                    Ellipse()
                        .stroke(
                            index == 0 ? tier.accentColor.opacity(0.68) : tier.promotionHighlight.opacity(0.72),
                            lineWidth: index == 0 ? 4 : 2)
                        .frame(
                            width: size * (0.72 + CGFloat(index) * 0.12),
                            height: tier.promotionLevel >= 7 ? size * (0.72 + CGFloat(index) * 0.12) : size * 0.3)
                        .scaleEffect(0.08 + coreReveal * (1.52 + CGFloat(index) * 0.2))
                        .opacity((1 - coreReveal) * coreReveal * 3.2)
                        .shadow(color: tier.accentColor, radius: 12)
                        .blendMode(.screen)
                }
            }

            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.95), tier.promotionHighlight.opacity(0.76), .clear],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.2, height: size * 1.16)
                .rotationEffect(.degrees(18))
                .offset(x: sheenPassed ? size * 0.8 : -size * 0.8)
                .mask(mechanicalArtwork("core", fallbackLayer: "front"))
                .blendMode(.screen)

            ForEach(0..<(7 + tier.promotionLevel * 2), id: \.self) { index in
                let angle = Double(index) * 2.399963 + Double(tier.promotionLevel) * 0.17
                let distance = size * (0.04 + shockwave * (0.38 + CGFloat(index % 4) * 0.035))
                TriangleSpark()
                    .fill(index.isMultiple(of: 3) ? Color.white : tier.promotionHighlight)
                    .frame(
                        width: index.isMultiple(of: 4) ? size * 0.018 : size * 0.009,
                        height: size * (0.05 + CGFloat(index % 5) * 0.012))
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance)
                    .opacity(impactFlash * (1 - shockwave * 0.72))
                    .shadow(color: .white, radius: size * 0.018)
                    .blendMode(.screen)
            }

            Circle()
                .fill(RadialGradient(
                    colors: [.white, .white, tier.promotionHighlight, tier.accentColor.opacity(0.25), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.42))
                .frame(width: size * 0.78, height: size * 0.78)
                .scaleEffect(0.04 + shockwave * 2.7)
                .opacity(impactFlash)
                .blendMode(.screen)

            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.92), tier.promotionHighlight.opacity(0.64),
                             tier.accentColor.opacity(0.22), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.7))
                .frame(width: size * 1.68, height: size * 1.68)
                .scaleEffect(0.18 + shockwave * 1.24)
                .opacity(whiteout * 0.82)
                .blur(radius: size * 0.008)
                .blendMode(.screen)

            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, tier.accentColor.opacity(0.2), .white.opacity(0.84),
                             tier.promotionHighlight.opacity(0.22), .clear],
                    startPoint: .leading,
                    endPoint: .trailing))
                .frame(width: size * 1.82, height: size * 0.08)
                .scaleEffect(x: 0.08 + shockwave * 0.92, y: 1)
                .opacity(whiteout * 0.7)
                .blur(radius: size * 0.011)
                .blendMode(.screen)
        }
        .frame(width: size, height: size)
        .scaleEffect(finalCompression * cameraZoom)
        .offset(cameraOffset)
        .rotation3DEffect(
            .degrees(cameraPitch),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.72)
        .rotation3DEffect(
            .degrees(cameraYaw),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72)
        .rotationEffect(.degrees(cameraRoll))
        .shadow(color: tier.accentColor.opacity(0.45), radius: size * 0.1, y: size * 0.035)
        .onAppear { play() }
        .onChange(of: playbackID) { _, _ in play() }
    }

    private enum Piece {
        case spine, leftProng, rightProng, leftWing, rightWing, crown
    }

    private func rearWing(left: Bool) -> some View {
        let direction = left ? -1.0 : 1.0
        let foldedAngle = direction * (22.0 + Double(tier.promotionLevel))
        let revealScale = 0.06 + rearWingReveal * 0.94
        let revealHeight = 0.76 + rearWingReveal * 0.24

        return mechanicalArtwork("back-frame", fallbackLayer: "back")
            .mask(pieceMask(left ? .leftWing : .rightWing))
            .scaleEffect(
                x: revealScale,
                y: revealHeight,
                anchor: .center)
            .rotationEffect(.degrees(foldedAngle * (1 - rearWingReveal)))
            .opacity(rearWingReveal)
            .shadow(color: tier.accentColor.opacity(0.66), radius: size * 0.1)
    }

    private func pieceMask(_ piece: Piece) -> some View {
        GeometryReader { proxy in
            let rect = pieceRect(piece, in: proxy.size)
            Rectangle()
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func pieceRect(_ piece: Piece, in canvas: CGSize) -> CGRect {
        switch piece {
        case .spine:
            return CGRect(x: canvas.width * 0.44, y: canvas.height * 0.38,
                          width: canvas.width * 0.12, height: canvas.height * 0.62)
        case .leftProng:
            return CGRect(x: canvas.width * 0.28, y: canvas.height * 0.5,
                          width: canvas.width * 0.22, height: canvas.height * 0.5)
        case .rightProng:
            return CGRect(x: canvas.width * 0.5, y: canvas.height * 0.5,
                          width: canvas.width * 0.22, height: canvas.height * 0.5)
        case .leftWing:
            return CGRect(x: 0, y: 0, width: canvas.width * 0.49, height: canvas.height * 0.84)
        case .rightWing:
            return CGRect(x: canvas.width * 0.51, y: 0,
                          width: canvas.width * 0.49, height: canvas.height * 0.84)
        case .crown:
            return CGRect(x: canvas.width * 0.34, y: 0,
                          width: canvas.width * 0.32, height: canvas.height * 0.52)
        }
    }

    private func layerArtwork(_ layer: String) -> some View {
        Group {
            if let image = RankBadgeAssets.image(
                named: "rank-\(tier.rawValue.lowercased())-\(layer)",
                subdirectory: "RankBadges/GeneratedLayers") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(registration(for: layer).scale)
        .offset(
            x: registration(for: layer).x / 1254 * size,
            y: registration(for: layer).y / 1254 * size)
    }

    @ViewBuilder
    private func mechanicalArtwork(_ name: String, fallbackLayer: String) -> some View {
        if let image = RankBadgeAssets.image(
            named: "\(tier.rawValue.lowercased())-\(name)",
            subdirectory: "RankBadges/MechanicalV5/\(tier.rawValue.lowercased())") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if hasV5Assets {
            EmptyView()
        } else {
            layerArtwork(fallbackLayer)
        }
    }

    @ViewBuilder
    private func pieceArtwork(
        _ name: String,
        fallbackLayer: String,
        fallbackPiece: Piece
    ) -> some View {
        if let image = RankBadgeAssets.image(
            named: "\(tier.rawValue.lowercased())-\(name)",
            subdirectory: "RankBadges/MechanicalV5/\(tier.rawValue.lowercased())") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else if hasV5Assets {
            EmptyView()
        } else {
            layerArtwork(fallbackLayer)
                .mask(pieceMask(fallbackPiece))
        }
    }

    private func registration(for layer: String) -> (x: CGFloat, y: CGFloat, scale: CGFloat) {
        switch (tier, layer) {
        case (.bronze, "front"): return (2, -24, 1)
        case (.silver, "front"): return (0, 36, 0.8)
        case (.gold, "front"): return (0, -43, 0.62)
        case (.platinum, "front"): return (0, 56, 1)
        case (.emerald, "mid"): return (-170, -45, 1)
        case (.emerald, "front"): return (0, -4, 2.35)
        case (.diamond, "front"): return (0, -10, 0.92)
        case (.master, "mid"): return (-50, 0, 1)
        case (.master, "front"): return (0, 6, 0.75)
        case (.grandmaster, "front"): return (0, -30, 0.82)
        default: return (0, 0, 1)
        }
    }

    private func play() {
        runID = UUID()
        guard motionActive else {
            backReveal = 1
            spineReveal = 1
            leftProngReveal = 1
            rightProngReveal = 1
            leftWingReveal = 1
            rightWingReveal = 1
            rearWingReveal = 1
            lockRingReveal = 1
            crownReveal = 1
            coreReveal = 1
            finalCompression = 1
            cameraPitch = 0
            cameraYaw = 0
            cameraRoll = 0
            cameraOffset = .zero
            cameraZoom = 1
            impactFlash = 0
            shockwave = 1
            whiteout = 0
            sheenPassed = true
            return
        }

        let currentRun = runID
        backReveal = 0
        spineReveal = 0
        leftProngReveal = 0
        rightProngReveal = 0
        leftWingReveal = 0
        rightWingReveal = 0
        rearWingReveal = 0
        lockRingReveal = 0
        crownReveal = 0
        coreReveal = 0
        finalCompression = 1
        cameraPitch = 0
        cameraYaw = 0
        cameraRoll = 0
        cameraOffset = .zero
        cameraZoom = 1
        impactFlash = 0
        shockwave = 0
        whiteout = 0
        sheenPassed = false
        weightedLock(arrival: startDelay + 0.70, run: currentRun) { backReveal = $0 }
        weightedLock(arrival: startDelay + 1.17, run: currentRun) { spineReveal = $0 }
        weightedLock(arrival: startDelay + 1.50, run: currentRun) { leftProngReveal = $0 }
        weightedLock(arrival: startDelay + 1.87, run: currentRun) { rightProngReveal = $0 }
        weightedLock(
            arrival: startDelay + (hasSegmentedFrame ? 0.70 : 1.73),
            run: currentRun) { leftWingReveal = $0 }
        weightedLock(arrival: startDelay + 2.17, run: currentRun) { rightWingReveal = $0 }
        weightedLock(arrival: startDelay + 2.83, run: currentRun) { rearWingReveal = $0 }
        if hasV5Assets && tier.promotionLevel >= 7 {
            weightedLock(arrival: startDelay + 2.83, run: currentRun) { lockRingReveal = $0 }
        }
        weightedLock(arrival: startDelay + 3.20, run: currentRun) { crownReveal = $0 }
        weightedLock(arrival: startDelay + 3.77, run: currentRun) { coreReveal = $0 }

        cameraImpact(at: startDelay + 0.70, run: currentRun, direction: 1, strength: 0.34)
        if tier.promotionLevel >= 4 {
            cameraImpact(at: startDelay + 2.17, run: currentRun, direction: -1, strength: 0.52)
        }
        finalImpact(at: startDelay + 3.77, run: currentRun)
        schedule(
            after: startDelay + 4.20,
            run: currentRun,
            animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.72)) {
            sheenPassed = true
        }
    }

    private func weightedLock(
        arrival: TimeInterval,
        run: UUID,
        setter: @escaping (CGFloat) -> Void
    ) {
        schedule(
            after: max(0, arrival - 0.54),
            run: run,
            animation: .timingCurve(0.5, 0, 0.82, 0.32, duration: 0.54)) {
            setter(0.992)
        }
        schedule(
            after: arrival,
            run: run,
            animation: .timingCurve(0.16, 1, 0.3, 1, duration: 0.20)) {
            setter(1)
        }
    }

    private func cameraImpact(
        at arrival: TimeInterval,
        run: UUID,
        direction: Double,
        strength: Double
    ) {
        let scalar = CGFloat(strength)
        let horizontal = CGFloat(direction * strength)
        schedule(after: arrival - 0.04, run: run, animation: .easeIn(duration: 0.10)) {
            cameraPitch = -0.72 * strength
            cameraYaw = 0.9 * direction * strength
            cameraRoll = 0.32 * direction * strength
            cameraOffset = CGSize(width: size * 0.008 * horizontal, height: -size * 0.005 * scalar)
            cameraZoom = 1 + 0.011 * scalar
            impactFlash = min(0.3, 0.08 + scalar * 0.12)
            shockwave = 0.18
        }
        schedule(after: arrival + 0.06, run: run, animation: .timingCurve(0.12, 0.84, 0.24, 1, duration: 0.20)) {
            cameraPitch = 0.16 * strength
            cameraYaw = -0.2 * direction * strength
            cameraRoll = -0.07 * direction * strength
            cameraOffset = CGSize(width: -size * 0.002 * horizontal, height: size * 0.0015 * scalar)
            cameraZoom = 0.998
            shockwave = 0.68
        }
        schedule(after: arrival + 0.26, run: run, animation: .easeOut(duration: 0.28)) {
            cameraPitch = 0
            cameraYaw = 0
            cameraRoll = 0
            cameraOffset = .zero
            cameraZoom = 1
            impactFlash = 0
            shockwave = 1
        }
    }

    private func finalImpact(at arrival: TimeInterval, run: UUID) {
        let levelScale = min(1.0, 0.42 + Double(tier.promotionLevel) * 0.065)
        schedule(after: arrival - 0.05, run: run, animation: .easeIn(duration: 0.12)) {
            finalCompression = 1.055 + 0.018 * levelScale
            cameraPitch = -1.2 * levelScale
            cameraYaw = 1.5 * levelScale
            cameraRoll = 0.34 * levelScale
            cameraOffset = CGSize(width: size * 0.01 * levelScale, height: -size * 0.012 * levelScale)
            cameraZoom = 1.035 + 0.026 * levelScale
            impactFlash = 0.35 + 0.28 * levelScale
            shockwave = 0.16
            whiteout = 0.34 + 0.30 * levelScale
        }
        schedule(after: arrival + 0.07, run: run, animation: .timingCurve(0.12, 0.84, 0.24, 1, duration: 0.20)) {
            finalCompression = 0.992
            cameraPitch = 0.32 * levelScale
            cameraYaw = -0.4 * levelScale
            cameraRoll = -0.1 * levelScale
            cameraOffset = CGSize(width: -size * 0.003 * levelScale, height: size * 0.004 * levelScale)
            cameraZoom = 0.997
            shockwave = 0.72
            whiteout = 0.16
        }
        schedule(after: arrival + 0.27, run: run, animation: .easeOut(duration: 0.30)) {
            finalCompression = 1
            cameraPitch = 0
            cameraYaw = 0
            cameraRoll = 0
            cameraOffset = .zero
            cameraZoom = 1
            impactFlash = 0
            shockwave = 1
            whiteout = 0
        }
    }

    private func schedule(
        after delay: TimeInterval,
        run: UUID,
        animation: Animation = .linear(duration: 3.0 / 60.0),
        action: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard runID == run else { return }
            withAnimation(animation) { action() }
        }
    }
}

/// 첫 실제 승급 때 SwiftUI/Metal 합성 파이프라인을 만들며 한 프레임을 170ms 이상
/// 막지 않도록 앱 root 위의 비가시 표면에서 9개 표현 그래프를 순차로 붙인다.
/// 모션·소리·서버 상태는 전혀 실행하지 않고, 접근성과 입력 계층에서도 제외된다.
struct RankPromotionPipelinePrewarmView: View {
    private let playbackID = UUID()
    @State private var finished = false
    @State private var tierIndex = 0

    var body: some View {
        if !finished {
            GeometryReader { proxy in
                let badgeSize = min(proxy.size.width * 0.62, proxy.size.height * 0.56, 560)
                let tier = RankTier.allCases[tierIndex]
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: 0x050A1A), Color(hex: 0x071A36), Color(hex: 0x02050E)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                    if tier == .challenger {
                        ChallengerAscensionUnderlay(
                            playbackID: playbackID,
                            motionActive: false)
                        ChallengerLayeredBadge(
                            size: badgeSize,
                            motionActive: false,
                            playbackID: playbackID,
                            startDelay: 0)
                    } else {
                        StandardTierPromotionUnderlay(
                            tier: tier,
                            playbackID: playbackID,
                            motionActive: false)
                        StandardTierPromotionBadge(
                            tier: tier,
                            size: badgeSize,
                            motionActive: false,
                            playbackID: playbackID,
                            startDelay: 0)
                    }
                    VStack {
                        Text("RANK ASCENDED")
                            .font(.custom("AkiraExpanded-Outline", size: 18))
                        Text(tier.rawValue)
                            .font(.custom("AkiraExpanded-Bold", size: 48))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .id("rank-pipeline-prewarm-\(tier.rawValue)")
            }
            // opacity 0은 Core Animation이 서브트리를 렌더하지 않는다. 실제 화면과
            // 같은 크기의 비영(非零) 표면을 한 번 합성한 뒤 즉시 제거해 상시 GPU·
            // 메모리 비용은 남기지 않는다.
            .opacity(0.001)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                let started = CACurrentMediaTime()
                let initialResident = Self.residentBytes()
                var peakResident = initialResident
                var rendered: [String] = []
                for (index, tier) in RankTier.allCases.enumerated() {
                    guard !Task.isCancelled else { return }
                    await RankBadgeAssets.prewarmPromotionVisuals(tier: tier)
                    tierIndex = index
                    // 실제 window에 attach된 그래프가 최소 두 번의 120Hz frame commit을
                    // 거치게 한다. Task.yield만 쓰면 한 run-loop 안에서 9개 상태가 합쳐져
                    // 마지막 티어만 합성되는 최적화가 발생한다.
                    try? await Task.sleep(for: .milliseconds(50))
                    peakResident = max(peakResident, Self.residentBytes())
                    rendered.append(tier.rawValue)
                }
                finished = true
                let finalResident = Self.residentBytes()
                RankPromotionPipelinePrewarmState.complete(
                    durationMs: (CACurrentMediaTime() - started) * 1_000,
                    initialResidentBytes: initialResident,
                    peakResidentBytes: peakResident,
                    finalResidentBytes: finalResident,
                    renderedTiers: rendered)
            }
        }
    }

    private static func residentBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}

/// 성능 자가진단이 startup prewarm과 겹쳐 첫 티어를 다시 컴파일하지 않게 하는 동기점.
/// 제품 판정이나 Arena 상태를 보유하지 않으며, 진단 실행일 때만 비식별 JSON을 쓴다.
@MainActor
enum RankPromotionPipelinePrewarmState {
    private(set) static var isReady = false

    static func waitUntilReady(timeoutSeconds: Double = 12) async -> Bool {
        let deadline = CACurrentMediaTime() + timeoutSeconds
        while !isReady, CACurrentMediaTime() < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }
        return isReady
    }

    static func complete(
        durationMs: Double,
        initialResidentBytes: Int,
        peakResidentBytes: Int,
        finalResidentBytes: Int,
        renderedTiers: [String]
    ) {
        isReady = renderedTiers == RankTier.allCases.map(\.rawValue)
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-rankPromotionPerformanceSelfTest") else {
            return
        }
        let report: [String: Any] = [
            "schemaVersion": "MATTHS_RANK_PROMOTION_PIPELINE_PREWARM_V1",
            "result": isReady ? "PASS" : "FAIL",
            "durationMs": durationMs,
            "initialResidentBytes": initialResidentBytes,
            "peakResidentBytes": peakResidentBytes,
            "finalResidentBytes": finalResidentBytes,
            "peakResidentDeltaBytes": max(0, peakResidentBytes - initialResidentBytes),
            "renderedTiers": renderedTiers,
            "audioPlaybackSuppressed": true,
            "accessibilityHidden": true,
            "hitTestingDisabled": true,
        ]
        guard JSONSerialization.isValidJSONObject(report),
              let data = try? JSONSerialization.data(
                withJSONObject: report,
                options: [.prettyPrinted, .sortedKeys]) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("rank-promotion-pipeline-prewarm.json")
        try? data.write(to: url, options: .atomic)
        #endif
    }
}

/// 실제 승급 이벤트와 디버그 미리보기에서 함께 쓰는 전체 화면 장식이다.
/// 서버 판정을 만들지 않고, 이미 결정된 티어를 받아 재생만 한다.
struct RankPromotionOverlay: View {
    let tierCode: String?

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var playbackID = UUID()
    @State private var copyShown = false
    @State private var displayedTierCode: String
    @State private var audioPlayer: AVAudioPlayer?
    @State private var assetsReady = false
    @State private var assetLoadID = UUID()
    @State private var videoFailed = false

    init(tierCode: String?) {
        self.tierCode = tierCode
        _displayedTierCode = State(initialValue: tierCode ?? RankTier.bronze.rawValue)
    }

    private var tier: RankTier { RankTier(serverCode: displayedTierCode) ?? .challenger }
    private var isPresented: Bool { tierCode != nil }
    private var motionActive: Bool { isPresented && store.motionOn && !reduceMotion }
    private var videoURL: URL? { RankPromotionVideoAssets.url(for: tier) }
    private var forceSwiftUIFallback: Bool {
        ProcessInfo.processInfo.arguments.contains("-rankPromotionSwiftUIFallback")
    }
    private var useVideo: Bool { isPresented && !forceSwiftUIFallback && !videoFailed && videoURL != nil }
    private var useSwiftUIFallback: Bool { isPresented && !useVideo }

    var body: some View {
        Group {
            // 호스트와 @State는 scene에 계속 남겨 재생 준비를 보존하되, 승급이 없을
            // 때는 투명한 전체 화면 GeometryReader 자체를 만들지 않는다. 이전의
            // opacity(0.001)+accessibilityHidden(true) 표면은 눈에는 안 보여도 iOS 26
            // 접근성 탐색에서 아래 홈·탭 전체를 가로막았다.
            if isPresented {
                GeometryReader { proxy in
                    let badgeSize = min(proxy.size.width * 0.62, proxy.size.height * 0.56, 560)

                    ZStack {
                        LinearGradient(
                            colors: [Color(hex: 0x050A1A), Color(hex: 0x071A36), Color(hex: 0x02050E)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                            .ignoresSafeArea()

                if useVideo, let videoURL {
                    RankPromotionVideoPlayer(
                        url: videoURL,
                        playbackID: playbackID,
                        motionActive: motionActive,
                        onComplete: close,
                        onFailure: activateSwiftUIFallback)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                }

                if useSwiftUIFallback {
                    ZStack {
                        if assetsReady {
                            if tier == .challenger {
                                ChallengerAscensionUnderlay(
                                    playbackID: playbackID,
                                    motionActive: motionActive)
                            } else {
                                StandardTierPromotionUnderlay(
                                    tier: tier,
                                    playbackID: playbackID,
                                    motionActive: motionActive)
                            }
                        }
                    }
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                    RadialGradient(
                        colors: [tier.accentColor.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: badgeSize * 0.9)
                        .frame(width: badgeSize * 1.8, height: badgeSize * 1.8)
                        .blendMode(.screen)

                    VStack(spacing: 0) {
                        Spacer(minLength: 56)

                        Group {
                            if assetsReady {
                                if tier == .challenger {
                                    ChallengerLayeredBadge(
                                        size: badgeSize,
                                        motionActive: motionActive,
                                        playbackID: playbackID,
                                        startDelay: motionActive ? 1.4 : 0)
                                } else {
                                    StandardTierPromotionBadge(
                                        tier: tier,
                                        size: badgeSize,
                                        motionActive: motionActive,
                                        playbackID: playbackID,
                                        startDelay: motionActive ? 1.4 : 0)
                                }
                            }
                        }
                        .frame(width: badgeSize * 1.42, height: badgeSize * 1.42)

                        VStack(spacing: 10) {
                            Text("RANK ASCENDED")
                                .font(.custom("AkiraExpanded-Outline", size: 18))
                                .tracking(3.2)
                                .foregroundStyle(tier.accentColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(tier.rawValue)
                                .font(.custom("AkiraExpanded-Bold", size: min(48, badgeSize * 0.105)))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                                .shadow(color: tier.accentColor.opacity(0.6), radius: 14)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, tier.accentColor, .white, tier.accentColor, .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing))
                                .frame(width: min(280, badgeSize * 0.62), height: 2)
                                .shadow(color: tier.accentColor, radius: 8)
                        }
                        .opacity(!motionActive || copyShown ? 1 : 0)
                        .offset(y: !motionActive || copyShown ? 0 : 18)

                        Spacer(minLength: 74)
                    }
                }

                        VStack {
                    HStack {
                        Spacer()
                        // 꾸밈을 Button 바깥에 걸면 캡슐은 44pt 로 보이는데 실제로
                        // 눌리는 곳은 글자 높이뿐이다(약 18pt). 눌러도 안 눌리는 버튼이
                        // 된다. 라벨 안으로 옮기고 contentShape 으로 캡슐 전체를 받는다.
                        Button { close() } label: {
                            Text("건너뛰기")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(.black.opacity(0.46), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("승급 모션 건너뛰기")
                        Button { close() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("닫기")
                    }
                    Spacer()
                    HStack(spacing: 12) {
#if DEBUG
                        if !RuntimeMode.isReviewCapture {
                            Button { moveTier(by: -1) } label: {
                                Image(systemName: "chevron.left")
                                    .frame(width: 44, height: 44)
                                    .background(.white.opacity(0.1), in: Circle())
                            }
                            .accessibilityLabel("이전 티어")
                        }
#endif

                        Button { play() } label: {
                            Label("다시 보기", systemImage: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 18)
                                .frame(minHeight: 44)
                                .background(.white.opacity(0.1), in: Capsule())
                        }
                        .disabled(!assetsReady)
                        .accessibilityLabel("승급 모션 다시 보기")

#if DEBUG
                        if !RuntimeMode.isReviewCapture {
                            Button { moveTier(by: 1) } label: {
                                Image(systemName: "chevron.right")
                                    .frame(width: 44, height: 44)
                                    .background(.white.opacity(0.1), in: Circle())
                            }
                            .accessibilityLabel("다음 티어")
                        }
#endif
                    }
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                        .padding(26)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .onAppear { prepareTierAndPlay() }
                .onDisappear { audioPlayer?.stop() }
            }
        }
        .onChange(of: tierCode) { _, code in
            handlePresentationChange(code)
        }
    }

    private func play() {
        guard isPresented, assetsReady else { return }
        playbackID = UUID()
        if useVideo { return }
        playTierSound()
        guard motionActive else {
            copyShown = true
            return
        }
        copyShown = false
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.42).delay(5.70)) {
            copyShown = true
        }
    }

    private func close() {
        // 실제 앱은 같은 scene overlay를 내리고, DebugBar 미리보기처럼 이 뷰가
        // sheet/fullScreenCover 안에 있을 때는 환경 dismiss도 함께 처리한다.
        store.dismissRankPromotion()
        dismiss()
    }

    private func playTierSound() {
        audioPlayer?.stop()
        guard isPresented else { return }
        guard let player = RankBadgeAssets.preparedSoundPlayer(for: tier) else {
            audioPlayer = nil
            return
        }
        player.stop()
        player.currentTime = 0
        player.volume = 0.9
        player.prepareToPlay()
        player.play()
        audioPlayer = player
    }

    /// PNG 2~6장을 첫 애니메이션 프레임에서 동기 디코딩하면 실기에서 조립 모션이
    /// 끊긴다. 화면에는 배경만 먼저 올리고 현재 티어 자산을 백그라운드에서 강제
    /// 디코딩한 뒤 영상과 소리를 같은 시점에 시작한다.
    private func prepareTierAndPlay() {
        guard isPresented else { return }
        videoFailed = false
        if !forceSwiftUIFallback, videoURL != nil {
            assetsReady = true
            copyShown = true
            playbackID = UUID()
            return
        }
        prepareSwiftUIFallbackAndPlay()
    }

    private func prepareSwiftUIFallbackAndPlay() {
        guard isPresented else { return }
        let loadID = UUID()
        let requestedTier = tier
        assetLoadID = loadID
        copyShown = false
        audioPlayer?.stop()
        // 승급을 띄우기 직전 호출부가 같은 티어의 PNG와 player를 모두 준비한 경우
        // background queue를 한 번 더 왕복하지 않는다. 이 왕복의 callback에서 조건부
        // 그래프가 170~200ms 뒤 붙으며 첫 조립 프레임을 막는 것이 실기에서 재현됐다.
        // 소리까지 준비되지 않은 실제 cold path는 아래 기존 흐름을 그대로 사용한다.
        if RankBadgeAssets.isPromotionPrepared(tier: requestedTier) {
            assetsReady = true
            play()
            return
        }
        assetsReady = false
        RankBadgeAssets.prewarmPromotion(tier: requestedTier) {
            guard assetLoadID == loadID, tier == requestedTier else { return }
            assetsReady = true
            play()
        }
    }

    private func activateSwiftUIFallback() {
        guard isPresented else { return }
        videoFailed = true
        prepareSwiftUIFallbackAndPlay()
    }

    private func handlePresentationChange(_ code: String?) {
        guard let code else {
            assetLoadID = UUID()
            assetsReady = false
            audioPlayer?.stop()
            audioPlayer = nil
            copyShown = false
            videoFailed = false
            // 이미 예약된 하위 graph animation의 runID를 교체해 이후 예약을 무효화한다.
            // motionActive=false 상태의 onChange이므로 새 animation은 예약하지 않는다.
            playbackID = UUID()
            return
        }
        displayedTierCode = code
        DispatchQueue.main.async {
            guard tierCode == code, displayedTierCode == code else { return }
            prepareTierAndPlay()
        }
    }

#if DEBUG
    private func moveTier(by offset: Int) {
        let tiers = RankTier.allCases
        guard let currentIndex = tiers.firstIndex(of: tier) else { return }
        let nextIndex = (currentIndex + offset + tiers.count) % tiers.count
        displayedTierCode = tiers[nextIndex].rawValue
        prepareTierAndPlay()
    }
#endif
}

enum RankBadgeAssets {
    private final class PromotionVisualReadiness: @unchecked Sendable {
        private let lock = NSLock()
        private var tiers: Set<RankTier> = []

        func markReady(_ tier: RankTier) {
            lock.lock()
            tiers.insert(tier)
            lock.unlock()
        }

        func contains(_ tier: RankTier) -> Bool {
            lock.lock()
            let result = tiers.contains(tier)
            lock.unlock()
            return result
        }
    }

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 64
        cache.totalCostLimit = 220 * 1_024 * 1_024
        return cache
    }()
    private static let soundCache: NSCache<NSString, NSData> = {
        let cache = NSCache<NSString, NSData>()
        cache.countLimit = RankTier.allCases.count
        cache.totalCostLimit = 8 * 1_024 * 1_024
        return cache
    }()
    @MainActor private static var preparedPlayers: [RankTier: AVAudioPlayer] = [:]
    @MainActor private static var audioSessionWarmed = false
    private static let promotionVisualReadiness = PromotionVisualReadiness()

    static func image(named name: String, subdirectory: String = "RankBadges") -> UIImage? {
        let cacheKey = "\(subdirectory)/\(name)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        if subdirectory == "RankBadges", let image = UIImage(named: name) {
            cache.setObject(image, forKey: cacheKey, cost: decodedCost(of: image))
            return image
        }
        let url = Bundle.main.url(
            forResource: name,
            withExtension: "png",
            subdirectory: subdirectory)
            ?? Bundle.main.url(forResource: name, withExtension: "png")
        guard let url, let image = decodedImage(at: url) else { return nil }
        cache.setObject(image, forKey: cacheKey, cost: decodedCost(of: image))
        return image
    }

    static func prewarmPromotion(tier: RankTier, completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            loadPromotionVisuals(tier: tier)
            _ = soundData(for: tier)
            DispatchQueue.main.async {
                _ = preparedSoundPlayer(for: tier)
                completion()
            }
        }
    }

    /// 늦은 조건부 view 삽입을 건너뛸 수 있는 것은 PNG 디코딩과 오디오 player가
    /// 모두 끝난 경우뿐이다. player 사전 생성 여부는 main actor에서만 읽는다.
    @MainActor
    static func isPromotionPrepared(tier: RankTier) -> Bool {
        promotionVisualReadiness.contains(tier) && preparedPlayers[tier] != nil
    }

    /// 앱 기동 prewarm은 오디오 세션을 열거나 player를 재생하지 않는다. PNG 디코딩만
    /// 백그라운드에서 끝낸 뒤 SwiftUI 그래프의 실제 attach를 main actor에 맡긴다.
    static func prewarmPromotionVisuals(tier: RankTier) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                loadPromotionVisuals(tier: tier)
                continuation.resume()
            }
        }
    }

    private static func loadPromotionVisuals(tier: RankTier) {
        let code = tier.rawValue.lowercased()
        let directory = "RankBadges/MechanicalV5/\(code)"
        let names = ["back-frame", "armor-left", "armor-right", "crown", "lock-ring", "core"]
            .map { "\(code)-\($0)" }
        for name in names {
            _ = image(named: name, subdirectory: directory)
        }
        promotionVisualReadiness.markReady(tier)
    }

    /// 첫 효과음의 AudioSession/decoder 초기화가 애니메이션 시작 뒤 150ms 이상
    /// main run loop를 막지 않도록, 표시 전에 실제 player까지 만들어 준비한다.
    /// 최초 한 번은 volume 0으로 즉시 play/stop해 하드웨어 경로도 열어 둔다.
    @MainActor
    static func preparedSoundPlayer(for tier: RankTier) -> AVAudioPlayer? {
        if let player = preparedPlayers[tier] { return player }
        guard let data = soundData(for: tier),
              let player = try? AVAudioPlayer(data: data) else { return nil }
        if !audioSessionWarmed {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            player.volume = 0
            player.prepareToPlay()
            player.play()
            player.stop()
            audioSessionWarmed = true
        }
        player.currentTime = 0
        player.volume = 0.9
        player.prepareToPlay()
        preparedPlayers[tier] = player
        return player
    }

    static func soundData(for tier: RankTier) -> Data? {
        let name = "rank-sfx-\(tier.rawValue.lowercased())"
        let key = name as NSString
        if let cached = soundCache.object(forKey: key) { return cached as Data }
        let url = Bundle.main.url(
            forResource: name,
            withExtension: "m4a",
            subdirectory: "RankSounds")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a")
        guard let url, let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return nil
        }
        soundCache.setObject(data as NSData, forKey: key, cost: data.count)
        return data
    }

    /// ImageIO가 픽셀 버퍼를 여기서 만들도록 해 SwiftUI 첫 렌더의 PNG 압축 해제를
    /// 없앤다. 승급 화면 최대 표시 크기(560pt, iPad 2x)를 보존하면서 1254px 원본은
    /// 1152px로만 낮춰 메모리 대역폭도 줄인다.
    private static func decodedImage(at url: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1152,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary)
        else { return nil }
        // SwiftUI가 최종 크기를 직접 지정하므로 화면 배율을 읽을 필요가 없다.
        // 백그라운드 prewarm 중 UIKit의 main-screen API를 건드리지 않게 한다.
        return UIImage(cgImage: cgImage)
    }

    private static func decodedCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
