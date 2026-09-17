import SwiftUI

struct AcademyAssignmentEditor: View {
    @Binding var configuration: AcademyAssignmentConfiguration?
    @State private var rangeStart = 1
    @State private var rangeEnd = 1
    @State private var answerType: AcademyAssignmentAnswerType = .multipleChoice
    @State private var choiceCount = 5
    @State private var pendingCount: Int?
    @State private var confirmsResize = false

    private var enabled: Binding<Bool> {
        Binding(get: { configuration?.enabled == true }, set: { value in
            if value {
                if configuration == nil { configuration = .blank }
                configuration?.enabled = true
            } else if configuration != nil { configuration?.enabled = false }
        })
    }
    private var safeCount: Int { min(100, max(1, configuration?.questionCount ?? 30)) }
    private var questionCount: Binding<Int> {
        Binding(get: { safeCount }, set: { count in
            if count < safeCount, configuration?.answerKey.dropFirst(count).contains(where: { !$0.isEmpty }) == true {
                pendingCount = count; confirmsResize = true
            } else { resize(count) }
        })
    }
    var body: some View {
        Section {
            Toggle("학생 온라인 답안 제출", isOn: enabled)
            if configuration?.enabled == true {
                Stepper("총 \(safeCount)문항", value: questionCount, in: 1...100)
                Text("학생은 모든 문항을 작성해 제출합니다. 제출된 답안은 자동 채점되며, 마감 뒤 미제출은 0점 처리됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                DisclosureGroup("문항 유형과 선택지 설정") {
                    Stepper("시작 \(rangeStart)번", value: $rangeStart, in: 1...safeCount)
                    Stepper("끝 \(rangeEnd)번", value: $rangeEnd, in: 1...safeCount)
                    Picker("입력 방식", selection: $answerType) {
                        ForEach(AcademyAssignmentAnswerType.allCases) { Text($0.title).tag($0) }
                    }
                    if answerType == .multipleChoice { Stepper("선택지 \(choiceCount)개", value: $choiceCount, in: 2...9) }
                    Button("\(rangeStart)~\(rangeEnd)번에 적용") {
                        configuration?.setSection(from: rangeStart, through: rangeEnd, type: answerType, choices: choiceCount)
                    }.disabled(rangeStart > rangeEnd)
                    ForEach(configuration?.sections ?? []) { section in
                        Text("\(section.startNumber)~\(section.endNumber)번 · \(section.answerType.title)" +
                             (section.answerType == .multipleChoice ? " · \(section.choiceCount)개 선택지" : ""))
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                }
                DisclosureGroup("교사 정답 입력 · \(enteredAnswers)/\(safeCount)") {
                    Text("단답형의 정답이 여러 개면 |로 구분하세요. 예: 2|2.0. 정답 변경 시 기존 제출도 다시 채점됩니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    ForEach(0..<safeCount, id: \.self) { index in
                        if let section = configuration?.sections.first(where: { $0.startNumber <= index + 1 && index + 1 <= $0.endNumber }) {
                            if section.answerType == .multipleChoice {
                                Picker("\(index + 1)번 정답", selection: answer(index)) {
                                    Text("선택").tag("")
                                    ForEach(1...min(9, max(2, section.choiceCount)), id: \.self) { Text("\($0)번").tag(String($0)) }
                                }
                            } else {
                                TextField("\(index + 1)번 정답", text: answer(index))
                                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                                    .accessibilityLabel("\(index + 1)번 단답형 정답")
                            }
                        }
                    }
                }
            }
        } header: { Text("과제 답안지 · 자동 채점") }
          footer: { Text(verbatim: "학생에게 교사 정답키를 보내지 않습니다. 답안지는 1~100문항, 객관식은 2~9개 선택지로 구성할 수 있습니다.") }
        .onChange(of: safeCount) { _, count in rangeStart = min(rangeStart, count); rangeEnd = min(rangeEnd, count) }
        .confirmationDialog("문항 수를 줄일까요?", isPresented: $confirmsResize, titleVisibility: .visible) {
            Button("문항 수 줄이기", role: .destructive) { if let pendingCount { resize(pendingCount) }; pendingCount = nil }
            Button("유지", role: .cancel) { pendingCount = nil }
        } message: { Text("줄어드는 문항의 교사 정답은 편집 초안에서 삭제됩니다. 저장하기 전까지 실제 과제에는 반영되지 않습니다.") }
    }
    private var enteredAnswers: Int { configuration?.answerKey.prefix(safeCount).filter { !AcademyAssignmentConfiguration.normalizedAnswer($0).isEmpty }.count ?? 0 }
    private func resize(_ count: Int) { configuration?.setQuestionCount(count) }
    private func answer(_ index: Int) -> Binding<String> {
        Binding(get: {
            guard let keys = configuration?.answerKey, keys.indices.contains(index) else { return "" }
            return keys[index]
        }, set: { value in
            guard var updated = configuration, index < safeCount else { return }
            while updated.answerKey.count < safeCount { updated.answerKey.append("") }
            updated.answerKey[index] = String(value.prefix(80))
            configuration = updated
        })
    }
}

struct AcademyAssignmentResults: View {
    let submissions: [AcademyAssignmentSubmission]
    let answerKey: [String]?
    var body: some View {
        DisclosureGroup("학생 제출 결과 · \(submissions.filter { $0.status == "SUBMITTED" }.count)건") {
            if submissions.isEmpty {
                Text("아직 제출된 답안이 없습니다.").font(.mCaption).foregroundStyle(Tokens.text2)
            }
            ForEach(submissions) { submission in
                if submission.isValid {
                    DisclosureGroup {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], alignment: .leading, spacing: Tokens.Space.s2) {
                            ForEach(0..<submission.questionCount, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("\(index + 1)번", systemImage: submission.correctByQuestion[index] ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(submission.correctByQuestion[index] ? Tokens.successInk : Tokens.dangerInk)
                                    MathInline(text: "제출: " + (submission.answers[index].isEmpty ? "미응답" : submission.answers[index]), font: .mCaption)
                                    if let answerKey, answerKey.indices.contains(index) {
                                        MathInline(text: "정답: " + answerKey[index], font: .mCaption)
                                    }
                                }.padding(Tokens.Space.s2).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                            }
                        }.padding(.top, Tokens.Space.s2)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(submission.student?.name ?? "학생").font(.mBodyB)
                            Text(submission.status == "MISSED" ? "마감 미제출 · 0점" : "\(Int(submission.scorePercent.rounded()))점 · 정답 \(submission.correctCount)/\(submission.questionCount)")
                                .font(.mCaption).foregroundStyle(Tokens.text2)
                        }.frame(minHeight: 44)
                    }
                } else {
                    Text("제출 결과 형식을 확인하지 못했습니다. 다시 불러와 주세요.").font(.mCaption).foregroundStyle(Tokens.dangerInk)
                }
            }
        }.font(.mBody)
    }
}
