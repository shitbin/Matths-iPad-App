import SwiftUI

struct SampleLessonScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var answer: Int?
    @State private var storageKey = "matths.demo.sample.function.v1." + DataScope.slot
    var onContinue: (() -> Void)?
    var onSkip: (() -> Void)?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    Text("함수는 입력을 바꾸는 규칙이에요").font(.mTitle).accessibilityAddTraits(.isHeader)
                    Text("어떤 수를 넣으면 두 배로 만든 뒤 1을 더합니다.").font(.mBody)
                    Text("3 → × 2 → + 1 → ?").font(.mTitle).accessibilityLabel("3을 두 배로 만들고 1을 더하면 얼마일까요?")
                    if let answer {
                        Text(answer == 7 ? "맞아요. 3 × 2 + 1 = 7이에요." : "먼저 3을 두 배로 만들면 6, 여기에 1을 더하면 7이에요.")
                            .font(.mBodyB).fixedSize(horizontal: false, vertical: true)
                        Text("함숫값을 구할 때는 입력한 수에 규칙을 순서대로 적용하면 돼요.")
                            .font(.mBody).foregroundStyle(Tokens.text2)
                        Button(onContinue == nil ? "로그인 화면으로" : "다음 학습 보기") {
                            if let onContinue { onContinue() } else { dismiss() }
                        }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        ForEach([6, 7, 8], id: \.self) { option in
                            Button("\(option)") { answer = option }
                                .buttonStyle(SecondaryButtonStyle())
                                .accessibilityLabel("정답 \(option) 선택")
                        }
                    }
                    Text("비공식 체험입니다. 점수나 공식 진도에 반영되지 않습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }.padding(Tokens.Space.s5).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .navigationTitle("30초 수학 체험").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("건너뛰기") {
                if let onSkip { onSkip() } else { dismiss() }
            } } }
        }
        .onAppear {
            if let value = UserDefaults.standard.object(forKey: storageKey) as? Int, [6, 7, 8].contains(value) { answer = value }
        }
        .onChange(of: answer) { _, value in if let value { UserDefaults.standard.set(value, forKey: storageKey) } }
    }
}
