//  BrandMark.swift
//  Matths
//
//  공식 브랜드 마크 — CI 가이드북(MATTHS_CI_가이드북_스무딩_최종본, 2026.08)의
//  스무딩 최종 심볼 에셋을 그대로 렌더한다.
//
//  예전 구현은 SVG 좌표를 손으로 옮긴 Canvas 패스였는데, 그 지오메트리는
//  스무딩 최종 심볼과 다른 시안이었다. CI 사용금지 규정이 "서로 다른 시안의
//  M·별 혼용" 을 명시적으로 금지하므로(가이드북 p.16), 도형을 직접 그리지 않고
//  제공 원본 에셋(Assets.xcassets 의 MatthsSymbol/MatthsSymbolWhite —
//  MATTHS_smooth_assets PNG 원본)을 쓴다. 별 모티프는 심볼의 일부다 —
//  삭제·이동·색 변경 금지(p.6).
//
//  두 가지 형태:
//    BrandMark()            풀컬러 심볼 단독 (투명 배경) — 다크 면 위 권장(p.14)
//    BrandMark(tile: true)  다크 타일 위 화이트 심볼 — 네이비 브랜드 면 전용.
//                           라이트 표면에서는 반드시 무타일 풀컬러 마크를 쓴다.

import SwiftUI

struct BrandMark: View {
    var tile: Bool = false

    /// 앱 아이콘 마스터(p.7)의 다크 베이스. 로고 원판 근검정 — Tokens.paper(다크)와
    /// 다른 브랜드 고정색이므로 외관을 따라가지 않는다.
    private let tileBg = Color(hex: 0x0A0A0E)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            if tile {
                ZStack {
                    // 플랫폼 라운드 마스크 관례(약 22.5%)를 따른 다크 타일
                    RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                        .fill(tileBg)
                    // 심볼 비율·별 위치·내부 안전 여백 유지(p.7) — 콘텐츠 62%
                    Image("MatthsSymbolWhite")
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * 0.62, height: side * 0.62)
                        .offset(y: side * 0.025)   // 별 포함 시각 중심 보정
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Image("MatthsSymbol")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 인증·브랜드 식별 화면에서 사용하는 공식 Primary Identity 전체 락업.
/// 심볼 옆 워드마크를 Text로 재조립하지 않고 CI 원본 벡터를 그대로 렌더한다.
///
/// 워드마크 획은 원본이 근검정 네이비(#0C0F1A)라 다크 배경(Tokens.paper 다크
/// = #090C1B)에서 대비 1.02:1 — 심볼만 보이고 글자가 통째로 사라졌다.
/// 그래서 에셋(MatthsPrimaryIdentity.imageset)이 luminosity=dark 변형을 갖는다:
/// 글자 획만 #F4F6FF 로 바꾼 사본이고 심볼(그라디언트·별·보라)은 동일하다.
/// 즉 여기서 외관 분기를 하지 않는다 — 분기는 에셋 카탈로그가 한다.
/// (CI 가이드북의 "Color Versions 배경색상 활용" 범위. 재조합·비율 변경은 금지.)
struct PrimaryBrandIdentity: View {
    var body: some View {
        Image("MatthsPrimaryIdentity")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
