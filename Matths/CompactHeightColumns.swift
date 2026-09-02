//  CompactHeightColumns.swift
//  Matths
//
//  가로로 든 iPhone 한 대에서 화면을 쓰는 학생을 위한 레이아웃 규칙이다.
//
//  왜 필요한가. iPhone 가로의 가용 높이는 약 390pt 이고, 상단바·탭바·홈 인디케이터를
//  빼면 본문 뷰포트가 300pt 를 넘지 못한다. 세로로만 쌓은 화면은 이 높이에서
//  "설명 한 문단 → 스크롤 → 카드 → 스크롤 → 버튼" 이 되어, 주 행동 버튼이 처음부터
//  화면 밖에 있다. 반대로 폭은 800pt 를 넘게 남아돈다. 남는 축(가로)으로 옮기면
//  같은 내용이 스크롤 없이 한 화면에 들어온다.
//
//  판정은 verticalSizeClass 다. 기기 이름으로 가르면 Stage Manager 로 납작해진
//  iPad 를 놓치고, 세로로 되돌린 iPhone 까지 좁은 규칙에 묶인다
//  (RootView 의 AdaptiveVPadding 과 같은 축).
//
//  접근성 글씨 크기에서는 2열을 만들지 않는다. 폭이 반으로 줄면 한 줄에 두세 글자만
//  들어가 세로 스크롤이 오히려 더 길어진다 — 큰 글씨 사용자에게는 한 열이 정답이다.

import SwiftUI

/// 세로가 짧을 때만 좌우 2열이 되고, 그 외에는 원래대로 세로로 쌓는 컨테이너.
///
/// 두 열은 각자 자기 높이를 가진다. 안에서 다시 스크롤을 만들지 않으므로
/// 바깥 ScrollView 안에 그대로 넣어도 스크롤이 이중으로 잡히지 않는다.
struct CompactHeightColumns<Leading: View, Trailing: View>: View {
    /// 2열일 때 왼쪽 열의 고정 폭. nil 이면 두 열이 같은 폭을 나눠 가진다.
    /// 왼쪽이 목록·내비게이션처럼 폭이 정해진 도구일 때만 값을 준다.
    var leadingWidth: CGFloat?
    var spacing: CGFloat = Tokens.Space.s5
    /// 세로로 쌓일 때의 간격. 원래 화면 간격을 그대로 유지하려고 따로 받는다.
    var stackedSpacing: CGFloat?
    var alignment: HorizontalAlignment = .leading
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 좌우로 나눠도 각 열이 읽을 만한 폭을 가지는 문맥인지.
    private var splits: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        if splits {
            HStack(alignment: .top, spacing: spacing) {
                if let leadingWidth {
                    leading().frame(width: leadingWidth, alignment: .topLeading)
                } else {
                    leading().frame(maxWidth: .infinity, alignment: .topLeading)
                }
                trailing().frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            VStack(alignment: alignment, spacing: stackedSpacing ?? spacing) {
                leading()
                trailing()
            }
        }
    }
}

// MARK: - 세로가 짧은 창의 스크롤 가능한 시트

/// iPhone 가로의 page sheet는 아래로 닫는 제스처가 시트 안 `ScrollView`의 세로
/// 스크롤과 같은 축을 쓴다. 긴 문서·목록은 첫 화면에서 손가락을 움직여도 시트만
/// 끌리거나 아무 일도 일어나지 않을 수 있다. 이 modifier는 그 문맥에서만 전체
/// 화면을 쓰고, iPhone 세로와 iPad에서는 익숙한 sheet 표현을 그대로 보존한다.
private struct CompactHeightBooleanSheet<SheetContent: View>: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    let sheetContent: () -> SheetContent

    @ViewBuilder
    func body(content: Content) -> some View {
        if verticalSizeClass == .compact {
            content.fullScreenCover(
                isPresented: $isPresented,
                onDismiss: onDismiss,
                content: sheetContent)
        } else {
            content.sheet(
                isPresented: $isPresented,
                onDismiss: onDismiss,
                content: sheetContent)
        }
    }
}

private struct CompactHeightItemSheet<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let sheetContent: (Item) -> SheetContent

    @ViewBuilder
    func body(content: Content) -> some View {
        if verticalSizeClass == .compact {
            content.fullScreenCover(
                item: $item,
                onDismiss: onDismiss,
                content: sheetContent)
        } else {
            content.sheet(
                item: $item,
                onDismiss: onDismiss,
                content: sheetContent)
        }
    }
}

extension View {
    func compactHeightSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        modifier(CompactHeightBooleanSheet(
            isPresented: isPresented,
            onDismiss: onDismiss,
            sheetContent: content))
    }

    func compactHeightSheet<Item: Identifiable, SheetContent: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> SheetContent
    ) -> some View {
        modifier(CompactHeightItemSheet(
            item: item,
            onDismiss: onDismiss,
            sheetContent: content))
    }
}
