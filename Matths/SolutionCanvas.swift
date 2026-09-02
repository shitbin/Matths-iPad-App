//  SolutionCanvas.swift
//  Matths
//
//  PencilKit 필기 캔버스. 학생의 풀이 과정을 그대로 받아 AI 채점에 넘긴다.
//  웹(PWA)의 canvas 구현과 같은 역할이지만, 네이티브는 Apple Pencil 의
//  필압·기울기·팜리젝션을 시스템이 처리해 준다.

import SwiftUI
import PencilKit

/// 노트의 색. **외관(라이트·다크)을 따라가지 않는다.**
///
/// `PKInkingTool(.pen, color: .label)` 은 화면에서는 다크 모드에서 흰 잉크로 보이는데
/// 채점으로 넘기는 `PKDrawing.image()` 는 두 외관 모두 검게 나온다(실측). 그러면 학생이
/// 본 노트와 채점에 올라간 그림의 색이 달라진다. 종이와 잉크를 둘 다 고정색으로 두면
/// 보이는 그대로가 채점으로 간다. 형광펜의 노란색도 밝은 종이 위에서만 제 색이 난다.
enum NotePalette {
    static let paper = Color(red: 1.0, green: 0.996, blue: 0.988)
    static let grid = Color(red: 0.855, green: 0.878, blue: 0.925)
    static let penInk = UIColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1)
}

/// 형광펜 색. 겹쳐 그어도 아래 글씨가 읽히도록 알파를 낮게 잡는다.
enum NoteHighlighterColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case pink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow: return "노랑"
        case .green: return "초록"
        case .pink: return "분홍"
        }
    }

    var ink: UIColor {
        switch self {
        case .yellow: return UIColor(red: 1.00, green: 0.85, blue: 0.16, alpha: 0.36)
        case .green: return UIColor(red: 0.42, green: 0.89, blue: 0.55, alpha: 0.34)
        case .pink: return UIColor(red: 1.00, green: 0.52, blue: 0.72, alpha: 0.34)
        }
    }
}

enum SolutionCanvasTool: String, CaseIterable, Identifiable {
    case pen
    case highlighter
    case eraser
    case select

    var id: String { rawValue }
    var label: String {
        switch self {
        case .pen: return "펜"
        case .highlighter: return "형광펜"
        case .eraser: return "지우개"
        case .select: return "선택·이동"
        }
    }
    var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .select: return "lasso"
        }
    }
}

struct SolutionCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    /// 손가락으로도 쓸 수 있게 할지. 기본은 펜슬 전용(팜 리젝션).
    var allowsFingerDrawing: Bool = false
    var selectedTool: SolutionCanvasTool = .pen
    var inkWidth: CGFloat = 3
    var highlighterInk: UIColor = NoteHighlighterColor.yellow.ink
    var onStrokeCommitted: ((PKDrawing, PKDrawing) -> Void)?
    /// Apple Pencil 두 번 탭. 굿노트처럼 지우개와 직전 도구를 오간다.
    var onPencilDoubleTap: (() -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvas.tool = configuredTool
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // 격자 배경은 SwiftUI 쪽에서 깔고, 캔버스는 투명하게 얹는다
        canvas.alwaysBounceVertical = false
        // 캔버스 자체는 스크롤하지 않는다. 지면이 모자라면 노트 높이가 늘고
        // 화면 전체 스크롤이 그걸 받는다. 캔버스가 스크롤을 물고 있으면
        // 펜슬 모드에서 손가락으로 페이지를 넘기는 동작까지 캔버스가 먹는다.
        canvas.isScrollEnabled = false
        canvas.isAccessibilityElement = true
        canvas.accessibilityLabel = "풀이 필기 캔버스"
        canvas.accessibilityHint = inputAccessibilityHint
        canvas.accessibilityIdentifier = "solutionCanvas"
        canvas.accessibilityTraits.insert(.allowsDirectInteraction)

        let pencil = UIPencilInteraction()
        pencil.delegate = context.coordinator
        canvas.addInteraction(pencil)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing { canvas.drawing = drawing }
        canvas.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        canvas.tool = configuredTool
        canvas.accessibilityHint = inputAccessibilityHint
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private var configuredTool: PKTool {
        switch selectedTool {
        case .pen:
            return PKInkingTool(.pen, color: NotePalette.penInk, width: inkWidth)
        case .highlighter:
            // 마커는 선이 굵어야 형광펜처럼 읽힌다. 펜 굵기에 비례해 키운다.
            return PKInkingTool(.marker, color: highlighterInk, width: max(16, inkWidth * 6))
        case .eraser:
            return PKEraserTool(.vector)
        case .select:
            return PKLassoTool()
        }
    }

    private var inputAccessibilityHint: String {
        allowsFingerDrawing
            ? "손가락 또는 호환되는 펜으로 풀이를 씁니다"
            : "Apple Pencil로 풀이를 씁니다"
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
        var parent: SolutionCanvas
        private var drawingAtToolStart: PKDrawing?
        init(_ parent: SolutionCanvas) { self.parent = parent }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            drawingAtToolStart = canvasView.drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            guard let before = drawingAtToolStart else { return }
            drawingAtToolStart = nil
            let after = canvasView.drawing
            guard before.dataRepresentation() != after.dataRepresentation() else { return }
            parent.onStrokeCommitted?(before, after)
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            parent.onPencilDoubleTap?()
        }
    }
}

/// 격자 배경 — 그래프·표를 그리기 쉽게. 웹 데모의 24px 격자와 같은 간격.
struct GraphPaper: View {
    var spacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            let line = NotePalette.grid
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += spacing }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y)); y += spacing }
            context.stroke(path, with: .color(line), lineWidth: 0.7)
        }
        .allowsHitTesting(false)
    }
}

/// 풀이 노트 전체 (격자 + 캔버스 + 도구 + 확대·축소)
struct SolutionNote: View {
    @Binding var drawing: PKDrawing
    @Binding var allowsFinger: Bool
    @Binding var zoom: CGFloat
    @Binding var selectedTool: SolutionCanvasTool
    @Binding var inkWidth: CGFloat
    @Binding var undoStack: [PKDrawing]
    @Binding var redoStack: [PKDrawing]
    /// 경기 풀이 화면의 좌우 고정 작업대에서 받은 실제 가용 높이.
    /// 값이 있으면 노트 자체를 길게 늘리거나 바깥 스크롤에 의존하지 않고,
    /// 남은 높이를 캔버스가 정확히 채운다.
    var constrainedHeight: CGFloat? = nil
    var showsHeader: Bool = true
    /// 좌우 분할의 오른쪽 칸처럼 폭은 좁지만 높이는 넓은 경우,
    /// 스크롤 안쪽에 도구를 숨기지 않고 아이콘 1줄로 모두 보여 준다.
    var usesCompactToolbar: Bool = false
    /// 아주 낮은 iPhone 가로 작업대에서만 줄일 수 있는 캔버스 바닥값.
    /// 기본값은 기존 180pt를 보존하고, 문제와 노트를 동시에 보여 주는 전용 화면만
    /// 실제 남은 높이에 맞춰 더 작은 값을 명시한다.
    var minimumConstrainedCanvasHeight: CGFloat = 180
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("matths.note.highlighterColor") private var highlighterColor: NoteHighlighterColor = .yellow
    /// 아래로 늘려 둔 여백. 지면이 모자라면 커지고, 새 문항에서 원래대로 돌아간다.
    @State private var extraPageHeight: CGFloat = 0
    /// 펜슬 두 번 탭으로 지우개에 갔다가 돌아올 도구.
    @State private var previousTool: SolutionCanvasTool = .pen

    private let zoomRange: ClosedRange<CGFloat> = 1.0...3.0
    /// 한 번 누를 때마다 늘어나는 세로 여백과 그 상한.
    private let pageStep: CGFloat = 360
    private let extraPageLimit: CGFloat = 3600

    private var deviceClass: MatthsDeviceClass {
        UIDevice.current.userInterfaceIdiom == .phone ? .phone : .pad
    }

    private var horizontalLayoutClass: MatthsLayoutClass {
        switch horizontalSizeClass {
        case .compact: .compact
        case .regular: .regular
        default: .unspecified
        }
    }

    private var verticalLayoutClass: MatthsLayoutClass {
        switch verticalSizeClass {
        case .compact: .compact
        case .regular: .regular
        default: .unspecified
        }
    }

    private var usesFingerDrawing: Bool {
        deviceClass == .phone || allowsFinger
    }

    /// 올가미로 고른 필기를 옮길 때는 손가락도 통해야 한다. 펜슬 전용을 그대로 두면
    /// iPad 에서 선택 도구가 아무 반응 없는 도구처럼 보인다.
    private var canvasAllowsFinger: Bool {
        usesFingerDrawing || selectedTool == .select
    }

    /// 창 높이. Split View·Slide Over 까지 반영되도록 화면이 아니라 창을 잰다.
    private var windowHeight: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        if let window = active?.keyWindow?.bounds.height, window > 200 { return window }
        return active?.screen.bounds.height ?? 812
    }

    /// 여백을 늘리기 전의 기본 노트 높이.
    ///
    /// 정책 값(`solutionCanvasMinimumHeight`)은 "이보다 작으면 안 된다"는 바닥이고,
    /// 실제로는 창 높이의 상당 부분을 노트에 준다. 두 줄 쓰면 끝나는 노트가
    /// 학생들이 가장 크게 불편해한 지점이라, 처음부터 화면만큼 열어 둔다.
    private var baseCanvasHeight: CGFloat {
        let floorHeight = UniversalLayoutPolicy.solutionCanvasMinimumHeight(
            on: deviceClass,
            horizontal: horizontalLayoutClass,
            vertical: verticalLayoutClass)
        let share: CGFloat = deviceClass == .phone ? 0.66 : 0.82
        // 좁은 폭(iPhone·Slide Over)에서는 지나치게 긴 지면이 오히려 길을 잃게 한다.
        let cap: CGFloat = horizontalLayoutClass == .compact ? 760 : 900
        let generous = min((windowHeight * share).rounded(), cap)
        return max(floorHeight, generous)
    }

    private var canvasMinimumHeight: CGFloat {
        baseCanvasHeight + extraPageHeight
    }

    private var constrainedCanvasHeight: CGFloat? {
        guard let constrainedHeight else { return nil }
        // 도구막대 44pt + 간격. 헤더를 함께 그리는 일반 문맥만 44pt를 더 뺀다.
        let chromeHeight: CGFloat = showsHeader ? 108 : 58
        return max(minimumConstrainedCanvasHeight, constrainedHeight - chromeHeight)
    }

    /// 늘린 지면을 되돌릴 수 있는지. 아래쪽에 필기가 남아 있으면 접지 않는다.
    private var canShrinkPage: Bool {
        guard extraPageHeight > 0 else { return false }
        guard !drawing.strokes.isEmpty else { return true }
        return drawing.bounds.maxY < baseCanvasHeight - 24
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                HStack(spacing: Tokens.Space.s3) {
                    Text("풀이 노트").font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                    Spacer()

                    if deviceClass == .phone {
                        Label("손가락 필기", systemImage: "hand.draw")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Tokens.text3)
                            .accessibilityLabel("손가락 필기 사용 중")
                            .accessibilityHint("iPhone에서는 손가락으로 바로 풀이를 쓸 수 있습니다")
                    } else {
                        Toggle("손가락 필기", isOn: $allowsFinger)
                            .font(.caption)
                            .toggleStyle(.switch)
                            .fixedSize()
                            .accessibilityHint("끄면 Apple Pencil로만 필기합니다")
                    }
                }
            }

            pencilToolbar

            // 격자와 필기가 함께 확대·축소된다 (내용 좌표는 불변 — 채점 PNG 무영향)
            ZoomableNote(zoom: $zoom, zoomRange: zoomRange) {
                ZStack {
                    Rectangle().fill(NotePalette.paper)
                    GraphPaper()
                    SolutionCanvas(
                        drawing: $drawing,
                        allowsFingerDrawing: canvasAllowsFinger,
                        selectedTool: selectedTool,
                        inkWidth: inkWidth,
                        highlighterInk: highlighterColor.ink,
                        onStrokeCommitted: recordChange,
                        onPencilDoubleTap: togglePencilEraser)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(.separator), lineWidth: 1.5))
            // 필기 공간은 화면의 주인공이다 — 320pt 는 두 줄 쓰면 끝났다.
            // (ScrollView 안이라 maxHeight: .infinity 는 금지 — 무한 제안을 받는다)
            .frame(
                minHeight: constrainedCanvasHeight == nil ? canvasMinimumHeight : nil
            )
            .frame(height: constrainedCanvasHeight)
            // 노트가 화면보다 길어서 아래쪽에 붙이면 스크롤해야 보인다. 도구막대 바로
            // 옆인 위쪽 모서리에 둬야 노트를 펴자마자 눈에 들어온다.
            .overlay(alignment: .topTrailing) { zoomPill.padding(10) }

            if constrainedHeight == nil {
                pageSizeBar

                Text(inputHint)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(height: constrainedHeight, alignment: .top)
        // 새 문항으로 넘어오면 필기와 되돌리기 기록이 함께 비워진다(SolveScreen).
        // 그때만 늘려 둔 지면도 원래대로 접는다.
        .onChange(of: drawing.strokes.isEmpty) { _, isEmpty in
            if isEmpty && undoStack.isEmpty && redoStack.isEmpty { extraPageHeight = 0 }
        }
    }

    /// 입력 안내. **무엇으로 쓰는지**는 기기가 정하고(iPhone에는 Apple Pencil이 없다),
    /// **몇 줄로 말할지**는 세로 가용 높이가 정한다 — 가로모드에서 두 줄짜리 안내는
    /// 그만큼을 캔버스에서 빼앗는다.
    private var inputHint: String {
        let opener = deviceClass == .phone
            ? "손가락으로 바로 쓸 수 있습니다."
            : "Apple Pencil로 바로 쓸 수 있습니다."
        guard verticalLayoutClass != .compact else { return opener }
        return deviceClass == .phone
            ? opener + " 아래가 모자라면 쓸 공간을 늘리고, 두 손가락으로 벌리면 크게 볼 수 있습니다."
            : opener + " 아래가 모자라면 쓸 공간을 늘리고, 펜을 두 번 두드리면 지우개로 바뀝니다."
    }

    private func setZoom(_ v: CGFloat) {
        zoom = min(max(v, zoomRange.lowerBound), zoomRange.upperBound)
    }

    /// 320pt에서는 가로 스크롤 안쪽에 실행 취소·전체 지우기가 숨어 도구가 없는 것처럼
    /// 보였다. 좁은 폭은 기능군별 두 줄, 넓은 폭은 한 줄로 두되 같은 동작을 공유한다.
    ///
    /// 배율은 두 폭 모두 캔버스 위 떠 있는 조작판으로 옮겼다. 도구 전환이 굵기·배율보다
    /// 훨씬 잦아서 첫 줄은 통째로 도구가 차지해야 하고, 줄 수를 하나 줄인 만큼이
    /// 그대로 필기 공간이 된다.
    ///
    /// 다만 **좁고 낮은** 폭(iPhone 가로 — 폭 compact, 높이 compact)은 예외다.
    /// 거기서는 가로로 844pt가 남는 대신 세로 가용 높이가 390pt뿐이라, 여러 줄
    /// 도구막대를 세우면 캔버스가 설 자리를 잃는다. 폭이 남는 쪽이니
    /// 한 줄 도구막대로 돌려보내 높이를 캔버스에 준다.
    @ViewBuilder private var pencilToolbar: some View {
        if constrainedHeight != nil && usesCompactToolbar {
            constrainedPencilToolbar
        } else if horizontalSizeClass == .compact && verticalSizeClass != .compact {
            VStack(spacing: Tokens.Space.s2) {
                HStack(spacing: Tokens.Space.s2) {
                    ForEach(SolutionCanvasTool.allCases) { tool in
                        toolButton(tool, expands: true)
                    }
                }

                HStack(spacing: Tokens.Space.s2) {
                    inkWidthMenu(compact: true)
                    compactActionButton(
                        "실행 취소", icon: "arrow.uturn.backward",
                        disabled: undoStack.isEmpty, action: undo)
                        .accessibilityHint("마지막 필기 또는 지우기를 되돌립니다")
                    compactActionButton(
                        "다시 실행", icon: "arrow.uturn.forward",
                        disabled: redoStack.isEmpty, action: redo)
                    compactActionButton(
                        "전체 지우기", icon: "trash",
                        disabled: drawing.strokes.isEmpty, action: clearDrawing)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.s2) {
                    ForEach(SolutionCanvasTool.allCases) { tool in
                        toolButton(tool)
                    }
                    inkWidthMenu(compact: false)

                    Divider().frame(height: 26)

                    Button { undo() } label: {
                        Label("실행 취소", systemImage: "arrow.uturn.backward")
                    }
                    .frame(minHeight: 44)
                    .disabled(undoStack.isEmpty)
                    .accessibilityHint("마지막 필기 또는 지우기를 되돌립니다")

                    Button { redo() } label: {
                        Label("다시 실행", systemImage: "arrow.uturn.forward")
                    }
                    .frame(minHeight: 44)
                    .disabled(redoStack.isEmpty)

                    Button { clearDrawing() } label: {
                        Label("전체 지우기", systemImage: "trash")
                    }
                    .frame(minHeight: 44)
                    .disabled(drawing.strokes.isEmpty)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    /// iPad mini 세로나 Stage Manager의 절반 노트 칸에서도 44pt 터치 영역을 지킨다.
    /// 667pt iPhone 가로의 절반 노트 칸에서는 8개를 모두 늘어놓으면 마지막 지우기가
    /// 잘린다. 폭이 부족할 때만 되돌리기·다시 실행·전체 지우기를 편집 메뉴로 접는다.
    private var constrainedPencilToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                constrainedCoreControls
                constrainedActionButton(
                    "실행 취소", icon: "arrow.uturn.backward",
                    disabled: undoStack.isEmpty, action: undo)
                constrainedActionButton(
                    "다시 실행", icon: "arrow.uturn.forward",
                    disabled: redoStack.isEmpty, action: redo)
                constrainedActionButton(
                    "전체 지우기", icon: "trash",
                    disabled: drawing.strokes.isEmpty, action: clearDrawing)
            }

            HStack(spacing: 2) {
                constrainedCoreControls
                constrainedActionsMenu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var constrainedCoreControls: some View {
        ForEach(SolutionCanvasTool.allCases) { tool in
            Button { selectTool(tool) } label: {
                Image(systemName: tool.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(
                        selectedTool == tool ? Tokens.actionPrimary : Tokens.text2)
                    .frame(width: 44, height: 44)
                    .background(
                        selectedTool == tool ? Tokens.primarySoft : Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                            .strokeBorder(
                                selectedTool == tool ? Tokens.actionPrimary : Tokens.line,
                                lineWidth: selectedTool == tool ? 1.5 : 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tool.label)
            .accessibilityAddTraits(selectedTool == tool ? .isSelected : [])
        }

        Menu {
            Picker("선 굵기", selection: $inkWidth) {
                Text("얇게").tag(CGFloat(2))
                Text("보통").tag(CGFloat(3))
                Text("굵게").tag(CGFloat(5))
            }
            Picker("형광펜 색", selection: $highlighterColor) {
                ForEach(NoteHighlighterColor.allCases) { color in
                    Text(color.label).tag(color)
                }
            }
        } label: {
            constrainedToolbarIcon("lineweight")
        }
        .accessibilityLabel("선 굵기 \(Int(inkWidth))포인트")
    }

    private var constrainedActionsMenu: some View {
        Menu {
            Button(action: undo) { Label("실행 취소", systemImage: "arrow.uturn.backward") }
                .disabled(undoStack.isEmpty)
            Button(action: redo) { Label("다시 실행", systemImage: "arrow.uturn.forward") }
                .disabled(redoStack.isEmpty)
            Button(action: clearDrawing) { Label("전체 지우기", systemImage: "trash") }
                .disabled(drawing.strokes.isEmpty)
        } label: {
            constrainedToolbarIcon("ellipsis.circle")
        }
        .accessibilityLabel("편집 동작 더 보기")
    }

    private func constrainedToolbarIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Tokens.text2)
            .frame(width: 44, height: 44)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(Tokens.line, lineWidth: 1))
    }

    private func constrainedActionButton(
        _ label: String,
        icon: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Tokens.text2)
                .frame(width: 44, height: 44)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .accessibilityLabel(label)
    }

    private var isAtDefaultZoom: Bool { zoom <= zoomRange.lowerBound + 0.01 }

    /// 캔버스 위에 떠 있는 배율 조작판. 도구막대에서 한 줄을 걷어내고 여기로 옮겼다.
    /// 100% 일 때는 축소·초기화가 할 일이 없으므로 확대 하나로 접어 둔다 —
    /// 필기 자리를 가리는 넓이를 3분의 1로 줄인다.
    private var zoomPill: some View {
        HStack(spacing: 2) {
            if !isAtDefaultZoom {
                zoomButton("축소", icon: "minus.magnifyingglass",
                           disabled: false) { setZoom(zoom - 0.5) }
                Button("\(Int((zoom * 100).rounded()))%") { setZoom(1) }
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Tokens.text2)
                    .frame(minWidth: 44, minHeight: 44)
                    .buttonStyle(.plain)
                    .accessibilityLabel("배율 초기화")
            }
            zoomButton("확대", icon: "plus.magnifyingglass",
                       disabled: zoom >= zoomRange.upperBound - 0.01) { setZoom(zoom + 0.5) }
        }
        .padding(.horizontal, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Tokens.line, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("캔버스 배율"))
    }

    private func zoomButton(
        _ label: String,
        icon: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(disabled ? Tokens.text3 : Tokens.text2)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .accessibilityLabel(label)
    }

    /// 지면 늘리기 — 굿노트에서 아래로 계속 이어 쓰는 감각을 화면 스크롤로 옮긴 것.
    /// 캔버스 안에 스크롤을 하나 더 두면 화면 전체 스크롤과 싸우기 때문에
    /// 노트 자체를 키우고 바깥 스크롤이 따라오게 한다.
    private var pageSizeBar: some View {
        HStack(spacing: Tokens.Space.s2) {
            Button { extendPage() } label: {
                Label("쓸 공간 늘리기", systemImage: "rectangle.expand.vertical")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(extraPageHeight >= extraPageLimit ? Tokens.text3 : Tokens.text2)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                        .strokeBorder(Tokens.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(extraPageHeight >= extraPageLimit)
            .accessibilityHint("노트 아래쪽을 더 길게 만듭니다")

            if canShrinkPage {
                Button { shrinkPage() } label: {
                    Label("원래 크기로", systemImage: "rectangle.compress.vertical")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Tokens.text2)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                            .strokeBorder(Tokens.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func inkWidthMenu(compact: Bool) -> some View {
        Menu {
            Picker("선 굵기", selection: $inkWidth) {
                Text("얇게").tag(CGFloat(2))
                Text("보통").tag(CGFloat(3))
                Text("굵게").tag(CGFloat(5))
            }
            Picker("형광펜 색", selection: $highlighterColor) {
                ForEach(NoteHighlighterColor.allCases) { color in
                    Text(color.label).tag(color)
                }
            }
        } label: {
            Label(compact ? "\(Int(inkWidth))pt" : "선 \(Int(inkWidth))pt", systemImage: "lineweight")
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44)
                .frame(minWidth: compact ? 62 : nil)
                .padding(.horizontal, compact ? 8 : 10)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.line, lineWidth: 1))
        }
        .accessibilityLabel("선 굵기 \(Int(inkWidth))포인트")
    }

    private func compactActionButton(
        _ label: String,
        icon: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                    .strokeBorder(Tokens.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1)
        .accessibilityLabel(label)
    }

    /// 좁은 폭에서는 아이콘 위·이름 아래로 쌓는다. 도구가 넷이라 가로로 늘어놓으면
    /// 375pt 폭에서 이름이 잘린다.
    private func toolButton(_ tool: SolutionCanvasTool, expands: Bool = false) -> some View {
        Button { selectTool(tool) } label: {
            Group {
                if expands {
                    VStack(spacing: 1) {
                        Image(systemName: tool.icon).font(.footnote.weight(.semibold))
                        Text(tool.label).font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                } else {
                    Label(tool.label, systemImage: tool.icon)
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                        .padding(.horizontal, 10)
                }
            }
            .foregroundStyle(selectedTool == tool ? Tokens.actionPrimary : Tokens.text2)
            .background(selectedTool == tool ? Tokens.primarySoft : Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.sm)
                .strokeBorder(selectedTool == tool ? Tokens.actionPrimary : Tokens.line,
                              lineWidth: selectedTool == tool ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTool == tool ? .isSelected : [])
    }

    private func selectTool(_ tool: SolutionCanvasTool) {
        if tool != .eraser { previousTool = tool }
        selectedTool = tool
    }

    /// 펜슬 두 번 탭 — 지우개로 갔다가 같은 동작으로 쓰던 도구에 돌아온다.
    private func togglePencilEraser() {
        if selectedTool == .eraser {
            selectedTool = previousTool == .eraser ? .pen : previousTool
        } else {
            previousTool = selectedTool
            selectedTool = .eraser
        }
    }

    private func extendPage() {
        guard extraPageHeight < extraPageLimit else { return }
        let next = min(extraPageHeight + pageStep, extraPageLimit)
        if reduceMotion {
            extraPageHeight = next
        } else {
            withAnimation(.easeOut(duration: 0.22)) { extraPageHeight = next }
        }
    }

    private func shrinkPage() {
        if reduceMotion {
            extraPageHeight = 0
        } else {
            withAnimation(.easeOut(duration: 0.22)) { extraPageHeight = 0 }
        }
    }

    /// 마지막 획이 지면 끝에 닿으면 아래를 미리 열어 둔다. 버튼을 찾느라
    /// 풀이를 멈추지 않게 하는 쪽이 굿노트 감각에 가깝다.
    private func growIfWritingNearBottom(_ current: PKDrawing) {
        guard !current.strokes.isEmpty else { return }
        guard current.bounds.maxY > canvasMinimumHeight - 110 else { return }
        extendPage()
    }

    private func recordChange(_ before: PKDrawing, _ after: PKDrawing) {
        guard before.dataRepresentation() != after.dataRepresentation() else { return }
        undoStack.append(before)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
        growIfWritingNearBottom(after)
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(drawing)
        drawing = previous
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(drawing)
        drawing = next
    }

    private func clearDrawing() {
        guard !drawing.strokes.isEmpty else { return }
        undoStack.append(drawing)
        if undoStack.count > 30 { undoStack.removeFirst() }
        redoStack.removeAll()
        drawing = PKDrawing()
    }
}

/// 확대·축소 컨테이너 — UIScrollView 가 격자+캔버스를 함께 줌한다.
/// 캔버스 자체 스크롤은 끄고(펜은 그리기, 두 손가락은 팬·핀치), 더블탭은 100% 복귀.
struct ZoomableNote<Content: View>: UIViewRepresentable {
    @Binding var zoom: CGFloat
    let zoomRange: ClosedRange<CGFloat>
    @ViewBuilder let content: Content

    func makeCoordinator() -> Coordinator { Coordinator(zoom: $zoom) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = zoomRange.lowerBound
        scroll.maximumZoomScale = zoomRange.upperBound
        scroll.delegate = context.coordinator
        scroll.showsHorizontalScrollIndicator = false
        scroll.bouncesZoom = true
        scroll.backgroundColor = .clear
        // 100% 에서는 팬할 곳이 없다. 손가락 한 개짜리 드래그를 여기서 물지 않아야
        // 바깥 화면 스크롤이 그대로 움직인다(확대 상태에서는 두 손가락으로 민다).
        scroll.panGestureRecognizer.minimumNumberOfTouches = 2
        // 늘어질 곳이 없으면 바깥 스크롤로 넘긴다.
        scroll.bounces = false

        // 호스팅 컨트롤러는 코디네이터가 강참조로 보유한다. 로컬 변수만 두면
        // makeUIView 가 끝나는 순간 해제돼서 updateUIView 로 rootView 를 갱신할
        // 길이 사라진다 — "손가락 허용" 토글이 먹지 않던 원인.
        let host = UIHostingController(rootView: content)
        context.coordinator.host = host
        host.view.backgroundColor = .clear
        scroll.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            host.view.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.hostView = host.view

        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.resetZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 2   // 펜 두 번 탭(도구 전환)과 충돌하지 않게
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        // 내용물 갱신 — 손가락 허용 토글 같은 상태 변화가 실제 캔버스에 닿는 통로
        context.coordinator.host?.rootView = content
        if abs(scroll.zoomScale - zoom) > 0.01 {
            scroll.setZoomScale(zoom, animated: true)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var zoom: CGFloat
        weak var hostView: UIView?
        var host: UIHostingController<Content>?      // 강참조 (위 주석 참조)
        init(zoom: Binding<CGFloat>) { _zoom = zoom }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { hostView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let z = scrollView.zoomScale
            DispatchQueue.main.async { if abs(self.zoom - z) > 0.01 { self.zoom = z } }
        }

        @objc func resetZoom(_ g: UITapGestureRecognizer) {
            (g.view as? UIScrollView)?.setZoomScale(1, animated: true)
        }
    }
}

extension PKDrawing {
    /// 채점 서버로 보낼 PNG. 빈 필기면 nil.
    func pngForGrading(scale: CGFloat = 2) -> Data? {
        guard !strokes.isEmpty else { return nil }
        let rect = bounds.insetBy(dx: -16, dy: -16)
        guard rect.width > 0, rect.height > 0 else { return nil }
        return image(from: rect, scale: scale).pngData()
    }
}
