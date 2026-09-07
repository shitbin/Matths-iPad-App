import SwiftUI

struct AcademyAssignmentStudentScreen: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: AcademyAssignmentStudentModel
    @State private var confirmsSubmit = false
    @State private var confirmsReplace = false
    @State private var confirmsLeavingUnstored = false
    @State private var showsOnlyMissing = false
    @FocusState private var focusedQuestion: Int?
    let onClose: () -> Void
    private var compact: Bool { verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize }

    init(response: ServerAPI.AcademyWeekResponse, owner: AccountRequestOwner, store: AppStore, onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: AcademyAssignmentStudentModel(response: response, owner: owner, store: store))
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Space.s2) {
                Button {
                    if model.hasUnstoredChanges { confirmsLeavingUnstored = true }
                    else { onClose() }
                } label: { Label("과제", systemImage: "chevron.left").frame(minHeight: 44) }
                    .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                Spacer(minLength: 4)
                Text("과제 답안지").font(.mBodyB).foregroundStyle(Tokens.ink)
                Spacer(minLength: 4)
                Button { focusedQuestion = nil; Task { await model.refresh() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("과제 최신 내용 확인").disabled(model.busy)
            }.padding(.horizontal, Tokens.Space.s3)
            Divider()
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: compact ? Tokens.Space.s2 : Tokens.Space.s3) {
                        if model.denied { messages }
                        else {
                            header
                            messages
                            if model.configurationChanged { configurationResolution }
                            else if let omr = model.omr, model.loaded {
                                if let receipt = model.receipt { result(receipt) }
                                if !model.deadlinePassed {
                                    HStack {
                                        Text("답 입력 \(model.answeredCount)/\(omr.questionCount)").font(compact ? .mCaption : .mBodyB)
                                        Spacer()
                                        Button { showsOnlyMissing.toggle() } label: {
                                            Label("빈 문항만", systemImage: showsOnlyMissing ? "checkmark.circle.fill" : "circle")
                                                .font(.mCaption).frame(minHeight: 44)
                                        }.buttonStyle(.plain).accessibilityAddTraits(showsOnlyMissing ? .isSelected : [])
                                    }
                                    ForEach(0..<omr.questionCount, id: \.self) { index in
                                        if !showsOnlyMissing || answer(at: index).isEmpty || focusedQuestion == index {
                                            question(index, omr: omr).id(index)
                                        }
                                    }
                                    if showsOnlyMissing && model.firstMissing == nil {
                                        Text("모든 문항을 작성했습니다. 하단에서 제출할 수 있습니다.")
                                            .font(.mBody).foregroundStyle(Tokens.text2)
                                    }
                                } else {
                                    Text("제출이 마감됐습니다. 마감 여부와 점수는 서버에서 확인합니다.")
                                        .font(.mBody).foregroundStyle(Tokens.text2)
                                }
                            } else if !model.loaded { ProgressView("답안지 확인 중") }
                        }
                    }
                    .frame(maxWidth: 820, alignment: .leading)
                    .padding(Tokens.Space.s3)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !model.denied && model.omr != nil {
                        footer {
                            if let index = model.firstMissing {
                                withAnimation { scroll.scrollTo(index, anchor: .top) }
                            }
                        }
                    }
                }
            }
        }
        .background(Tokens.paper)
        .task { await model.start() }
        .onDisappear { model.retire() }
        .confirmationDialog(model.receipt == nil ? "답안을 제출할까요?" : "답안을 다시 제출할까요?",
                            isPresented: $confirmsSubmit, titleVisibility: .visible) {
            Button(model.receipt == nil ? "제출하기" : "수정한 답안 제출") {
                focusedQuestion = nil
                Task { await model.submit() }
            }
            Button("계속 작성", role: .cancel) {}
        } message: {
            Text("서버에서 채점하고 제출 결과를 확인합니다. 마감 전에는 답안을 수정해 다시 제출할 수 있습니다.")
        }
        .confirmationDialog("현재 답안지로 새로 작성할까요?", isPresented: $confirmsReplace, titleVisibility: .visible) {
            Button("원본 백업 후 새로 작성", role: .destructive) { model.useCurrentConfiguration(reuseAnswers: false) }
            Button("취소", role: .cancel) {}
        } message: { Text("이전에 저장된 답안 파일을 별도로 백업한 뒤 현재 답안지를 비웁니다.") }
        .confirmationDialog("아직 저장하지 못한 답이 있습니다", isPresented: $confirmsLeavingUnstored, titleVisibility: .visible) {
            Button("저장 재시도") { model.retryDraft() }
            Button("저장하지 못한 입력을 버리고 나가기", role: .destructive, action: onClose)
            Button("화면에 머무르기", role: .cancel) {}
        } message: { Text("지금 나가면 마지막으로 저장에 성공한 답만 남습니다. 먼저 저장을 재시도해 주세요.") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if compact {
                DisclosureGroup {
                    instruction
                } label: {
                    Text(model.response.week.assignmentTitle).font(.mBodyB).foregroundStyle(Tokens.ink)
                }
            } else {
                Text(model.response.week.assignmentTitle).font(.mHeading).foregroundStyle(Tokens.ink)
                instruction
            }
        }
    }

    @ViewBuilder private var instruction: some View {
        if let due = AcademyAssignmentStudentModel.date(model.response.week.dueAt) {
            Text("마감 \(due.formatted(date: .abbreviated, time: .shortened))").font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Text("답은 이 기기에 자동 보관됩니다. 제출을 눌러야 선생님께 전달됩니다.")
            .font(.mCaption).foregroundStyle(Tokens.text2)
    }

    @ViewBuilder private var messages: some View {
        if let error = model.errorMessage { Text(error).font(.mBody).foregroundStyle(Tokens.dangerInk) }
        if let notice = model.notice { Text(notice).font(.mBody).foregroundStyle(Tokens.successInk) }
        if let error = model.draftError {
            VStack(alignment: .leading, spacing: 8) {
                Text(error).font(.mBody).foregroundStyle(Tokens.dangerInk)
                Button("저장 재시도") { model.retryDraft() }.buttonStyle(SecondaryButtonStyle())
                Button("원본 백업 후 새로 작성") { confirmsReplace = true }
                    .font(.mCaption).frame(minHeight: 44).disabled(model.busy)
            }
        }
    }

    private var configurationResolution: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("선생님이 과제를 변경했습니다").font(.mHeading)
            Text("이전에 작성한 답은 유지했습니다. 문항 순서나 선택지가 달라졌을 수 있으므로 자동으로 제출하지 않습니다.")
                .font(.mBody).foregroundStyle(Tokens.text2)
            DisclosureGroup("이전 답안 확인") {
                ForEach(Array(model.answers.enumerated()), id: \.offset) { index, answer in
                    Text("\(index + 1)번 · \(answer.isEmpty ? "미응답" : answer)").font(.mCaption)
                }
            }
            Button("현재 답안지로 새로 작성") { confirmsReplace = true }.buttonStyle(PrimaryButtonStyle())
            Button("이전 답을 옮긴 뒤 직접 확인") { model.useCurrentConfiguration(reuseAnswers: true) }
                .buttonStyle(SecondaryButtonStyle())
        }.disabled(model.busy)
    }

    private func question(_ index: Int, omr: AcademyAssignmentOMR) -> some View {
        let layout = compact ? AnyLayout(HStackLayout(alignment: .center, spacing: 12)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        return layout {
            if let section = omr.section(for: index + 1) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(index + 1)번").font(.mBodyB.monospacedDigit())
                    Text(section.answerType.title).font(.mCaption).foregroundStyle(Tokens.text2)
                }.frame(minWidth: compact ? 55 : nil, alignment: .leading)
                if section.answerType == .multipleChoice {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 68))], alignment: .leading, spacing: 8) {
                        ForEach(1...section.choiceCount, id: \.self) { choice in
                            let selected = answer(at: index) == String(choice)
                            Button { model.setAnswer(selected ? "" : String(choice), at: index) } label: {
                                Text(String(choice)).font(.mBodyB).frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(selected ? Tokens.paper : Tokens.ink)
                                    .background(selected ? Tokens.actionPrimary : Tokens.paper2,
                                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
                            }.buttonStyle(.plain)
                                .accessibilityLabel("\(index + 1)번 문항 \(choice)번 선택지")
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                } else {
                    TextField("답 입력 (80자 이내)", text: Binding(get: { answer(at: index) }, set: { model.setAnswer($0, at: index) }))
                        .textFieldStyle(.roundedBorder).font(.mBody).autocorrectionDisabled()
                        .textInputAutocapitalization(.never).focused($focusedQuestion, equals: index)
                        .accessibilityLabel("\(index + 1)번 단답형 답")
                }
            }
        }
        .padding(compact ? Tokens.Space.s2 : Tokens.Space.s3).frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .disabled(!model.canEdit)
    }

    private func result(_ receipt: AcademyAssignmentSubmission) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Label(receipt.status == "MISSED" ? "마감 미제출" : "서버 제출 내역", systemImage: "checkmark.shield")
                    .font(.mBodyB)
                Spacer()
                Text("\(Int(receipt.scorePercent))점").font(.mHeading.monospacedDigit())
            }
            Text("정답 \(receipt.correctCount)/\(receipt.questionCount) · 작성 중인 수정 답안과는 별도입니다.")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            DisclosureGroup("제출 답안과 문항별 결과") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170))], alignment: .leading, spacing: 12) {
                    ForEach(0..<receipt.questionCount, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Label("\(index + 1)번 · \(receipt.correctByQuestion[index] ? "정답" : "오답")",
                                  systemImage: receipt.correctByQuestion[index] ? "checkmark.circle" : "xmark.circle")
                                .foregroundStyle(receipt.correctByQuestion[index] ? Tokens.successInk : Tokens.dangerInk)
                            Text(receipt.answers[index].isEmpty ? "미응답" : receipt.answers[index])
                                .foregroundStyle(Tokens.ink).textSelection(.enabled)
                        }.font(.mCaption).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(.top, 8)
            }
        }.padding(Tokens.Space.s3).background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
    }

    private func footer(showMissing: @escaping () -> Void) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                if model.busy { ProgressView("서버 확인 중").font(.mCaption) }
                else if model.deadlinePassed { Text("제출 마감").font(.mBodyB) }
                else if let first = model.firstMissing {
                    Button("빈 문항 \(first + 1)번으로") { focusedQuestion = nil; showMissing() }
                        .font(.mCaption).frame(minHeight: 44)
                } else { Text("\(model.answeredCount)문항 작성").font(.mBodyB) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button(model.receipt == nil ? "답안 제출" : "수정 답안 제출") { confirmsSubmit = true }
                .buttonStyle(PrimaryButtonStyle()).disabled(!model.canSubmit)
                .frame(maxWidth: 260)
        }
        .padding(.horizontal, Tokens.Space.s3).padding(.vertical, Tokens.Space.s2)
        .background(Tokens.paper)
        .overlay(alignment: .top) { Divider() }
    }

    private func answer(at index: Int) -> String { model.answers.indices.contains(index) ? model.answers[index] : "" }
}
