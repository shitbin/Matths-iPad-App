import SwiftUI

/// Native answer controls share the app's selection, focus and submit model.
/// Only mathematical typesetting uses the existing local KaTeX renderer.
struct PracticeProblemContent: View {
    let problem: GeneratedProblem
    @Binding var pickedKey: String?
    var compact = false
    private static let keys = ["a", "b", "c", "d", "e"]

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Tokens.Space.s1 : Tokens.Space.s3) {
            MathInline(text: problem.statement, font: compact ? .mCallout : .mBody, color: Tokens.ink)
            if let choices = problem.choices {
                if choices.isEmpty || choices.count > Self.keys.count {
                    Text("선택지 정보를 확인하지 못했습니다. 문제를 다시 열어 주세요.")
                        .font(.mCallout).foregroundStyle(Tokens.dangerInk)
                } else {
                    ForEach(Array(choices.enumerated()), id: \.offset) { index, text in
                        choice(index: index, text: text)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func choice(index: Int, text: String) -> some View {
        let key = Self.keys[index]
        let selected = pickedKey == key
        return Button {
            pickedKey = selected ? nil : key
        } label: {
            HStack(alignment: .top, spacing: compact ? Tokens.Space.s1 : Tokens.Space.s2) {
                Text("\(index + 1)").font(.mCaption)
                    .frame(width: 24, height: 24)
                    .background(selected ? Tokens.primarySoft : Tokens.paper2, in: Circle())
                MathInline(text: text, font: compact ? .mCallout : .mBody, color: Tokens.ink)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected { Image(systemName: "checkmark").font(.mCaption).foregroundStyle(Tokens.primary) }
            }
            .foregroundStyle(Tokens.ink)
            .padding(compact ? Tokens.Space.s2 : Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: compact ? 44 : 48, alignment: .leading)
            .background(selected ? Tokens.primarySoft : Tokens.surface,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .stroke(selected ? Tokens.primary : Tokens.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index + 1)번, \(MathText.plain(text))")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("practice.choice.\(key)")
    }
}
