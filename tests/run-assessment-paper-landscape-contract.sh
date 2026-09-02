#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
paper="$root/Matths/LessonWeb/paper.html"
screen="$root/Matths/AssessmentPaperScreen.swift"

# iPhone 가로의 5지선다는 남는 폭을 사용해 2열로 보이고, 큰 글씨에서는
# 읽을 폭을 보존하려고 다시 한 열로 돌아간다.
grep -Fq '@Environment(\.verticalSizeClass) private var verticalSizeClass' "$screen"
grep -Fq 'compactHeight: verticalSizeClass == .compact' "$screen"
grep -Fq 'window.MATTHS_APPLY_PAPER_LAYOUT && window.MATTHS_APPLY_PAPER_LAYOUT' "$screen"
grep -Fq 'window.MATTHS_PAPER_COMPACT_HEIGHT' "$screen"
grep -Fq 'html.paper-compact-height .q-choices' "$paper"
grep -Fq 'grid-template-columns: repeat(2, minmax(0, 1fr));' "$paper"
grep -Fq 'html.paper-compact-height.paper-accessibility-text .q-choices' "$paper"
grep -Fq 'scale >= 1.5' "$paper"
grep -Fq 'choices.appendChild(btn);' "$paper"
grep -Fq 'box.appendChild(choices);' "$paper"

# 실제 시험지는 수십 문항으로 길어질 수 있으므로 iPhone 가로 고정 헤더에서
# 제출할 수 있어야 한다. WebKit 안의 답안 컨트롤도 VoiceOver에 역할과 선택
# 상태를 전달해야 하며, 화면에만 보이는 무명 버튼으로 남으면 안 된다.
grep -Fq 'if verticalSizeClass == .compact' "$screen"
grep -Fq 'Button(store.assessmentSubmitting ? "제출 중" : "제출")' "$screen"
grep -Fq 'requestSubmit(a)' "$screen"
grep -Fq 'choices.setAttribute("role", "radiogroup")' "$paper"
grep -Fq 'btn.setAttribute("role", "radio")' "$paper"
grep -Fq 'btn.setAttribute("aria-checked", q.picked === key ? "true" : "false")' "$paper"
grep -Fq 'b.setAttribute("aria-checked", "false")' "$paper"
grep -Fq 'btn.setAttribute("aria-checked", "true")' "$paper"
grep -Fq 'label.htmlFor = inputID' "$paper"
grep -Fq 'accessiblePrefix.className = "sr-only"' "$paper"

echo 'Assessment paper landscape choice contract passed'
