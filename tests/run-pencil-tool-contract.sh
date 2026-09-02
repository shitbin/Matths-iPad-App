#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
canvas="$root/Matths/SolutionCanvas.swift"
solve="$root/Matths/Screens.swift"

grep -Fq 'case pen' "$canvas"
grep -Fq 'case eraser' "$canvas"
grep -Fq 'case select' "$canvas"
grep -Fq 'return PKEraserTool(.vector)' "$canvas"
grep -Fq 'return PKLassoTool()' "$canvas"
grep -Fq 'Picker("선 굵기"' "$canvas"
grep -Fq 'Text("얇게").tag(CGFloat(2))' "$canvas"
grep -Fq 'Text("보통").tag(CGFloat(3))' "$canvas"
grep -Fq 'Text("굵게").tag(CGFloat(5))' "$canvas"
grep -Fq 'Label("실행 취소"' "$canvas"
grep -Fq 'Label("다시 실행"' "$canvas"
grep -Fq 'Label("전체 지우기"' "$canvas"
grep -Fq '.accessibilityAddTraits(selectedTool == tool ? .isSelected : [])' "$canvas"
grep -Fq 'if horizontalSizeClass == .compact' "$canvas"
grep -Fq 'Text("캔버스 배율")' "$canvas"
grep -Fq 'toolButton(tool, expands: true)' "$canvas"
grep -Fq '.accessibilityLabel("선 굵기 \(Int(inkWidth))포인트")' "$canvas"
grep -Fq 'private let zoomRange: ClosedRange<CGFloat> = 1.0...3.0' "$canvas"
grep -Fq 'SolutionNote(' "$solve"
grep -Fq 'undoStack: $noteUndoStack' "$solve"
grep -Fq '@Binding var undoStack: [PKDrawing]' "$canvas"
grep -Fq '@Binding var zoom: CGFloat' "$canvas"
grep -Fq 'drawing.pngForGrading(scale: 1)' "$solve"

touch_targets=$(grep -Ec '\.frame\(minHeight: 44\)|\.frame\(minWidth: 44, minHeight: 44\)' "$canvas")
if [ "$touch_targets" -lt 7 ]; then
  echo "Pencil 도구막대의 44pt 조작 영역이 빠졌습니다." >&2
  exit 1
fi

echo "Pencil tool, selection, history, zoom, and grading handoff contracts passed"
