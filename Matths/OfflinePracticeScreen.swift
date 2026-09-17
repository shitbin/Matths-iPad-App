import SwiftUI

/// No passed/unlock/server ID/official event fields exist in this record.
struct PracticeAssessmentRecord: Codable {
    let id: String
    let title: String
    let questions: [PaperQuestion]
    var answers: [String]
    var index: Int
    var score: Int?
    var completedAt: Date?
}

@MainActor
final class OfflinePracticeModel: ObservableObject {
    enum State { case ready, preparing, failure(String) }
    @Published private(set) var state: State = .ready
    @Published private(set) var session: PracticeAssessmentRecord?
    private let slot = DataScope.slot
    private var key: String { "matths.practice-assessments.v1." + slot }
    private var fileURL: URL { DataScope.url("practice-assessments-v1.json", for: slot) }
    init() {
        if let raw = (try? Data(contentsOf: fileURL)) ?? UserDefaults.standard.data(forKey: key),
           let restored = try? JSONDecoder().decode(PracticeAssessmentRecord.self, from: raw),
           restored.id.hasPrefix("practice-"), !restored.questions.isEmpty,
           restored.questions.count == restored.answers.count,
           restored.questions.indices.contains(restored.index) { session = restored }
    }
    func start(scope: PaperScope, course: AssessCourse, unit: AssessUnit?, subunit: AssessSubunit?) {
        guard DataScope.slot == slot, CurriculumPolicy.isAvailable(course.courseId) else { return }
        state = .preparing
        let questions = PaperFactory.make(scope: scope, course: course, unit: unit, subunit: subunit,
                                          seed: UInt64(Date().timeIntervalSince1970), avoid: [])
        guard let expected = AssessCatalog.data.paperPlans[scope.rawValue]?.count,
              questions.count == expected else {
            state = .failure("필요한 수만큼 연습 문제를 만들지 못했습니다. 다른 범위를 선택해 주세요.")
            return
        }
        session = PracticeAssessmentRecord(id: "practice-" + UUID().uuidString,
            title: subunit?.title ?? unit?.title ?? course.title,
            questions: questions, answers: Array(repeating: "", count: questions.count), index: 0)
        state = .ready
        save()
    }
    func answer(_ value: String) {
        guard DataScope.slot == slot, var valueSession = session, valueSession.completedAt == nil else { return }
        valueSession.answers[valueSession.index] = value
        session = valueSession
        save()
    }
    func move(_ amount: Int) {
        guard var value = session, value.questions.indices.contains(value.index + amount) else { return }
        value.index += amount; session = value; save()
    }
    func finish() {
        guard DataScope.slot == slot, var value = session, value.completedAt == nil else { return }
        value.score = PaperFactory.grade(questions: value.questions, answers: value.answers).scorePercent
        value.completedAt = Date(); session = value; save()
    }
    func reset() {
        guard DataScope.slot == slot else { return }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            UserDefaults.standard.removeObject(forKey: key)
            session = nil; state = .ready
        } catch { state = .failure("이전 연습을 보관 중입니다. 저장 공간을 확인하고 다시 시도해 주세요.") }
    }
    private func save() {
        guard DataScope.slot == slot, let session else { return }
        do {
            let raw = try JSONEncoder().encode(session)
            try raw.write(to: fileURL, options: .atomic)
        } catch { state = .failure("연습 답안을 저장하지 못했습니다. 앱을 닫기 전에 다시 시도해 주세요.") }
    }
}

struct OfflinePracticeScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = OfflinePracticeModel()
    @State private var courseID = "common-math-1"
    @State private var unitID = ""
    @State private var subunitID = ""
    @State private var scope: PaperScope = .subunit
    private var courses: [AssessCourse] { AssessCatalog.data.courses.filter { CurriculumPolicy.isAvailable($0.courseId) } }
    private var course: AssessCourse? { courses.first { $0.id == courseID } ?? courses.first }
    private var unit: AssessUnit? { course?.units.first { $0.id == unitID } ?? course?.units.first }
    private var subunit: AssessSubunit? { unit?.subunits.first { $0.id == subunitID } ?? unit?.subunits.first }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    Label("비공식 연습 · 이 기기에만 저장", systemImage: "wifi.slash")
                        .font(.mCallout).foregroundStyle(Tokens.text2)
                    Text("공식 평가 점수, 진도, 합격과 해금에는 반영되지 않습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    if case .failure(let message) = model.state {
                        Text(message).font(.mCallout).foregroundStyle(Tokens.dangerInk)
                    }
                    if let session = model.session { practice(session) }
                    else { configuration }
                }
                .padding(Tokens.Space.s5).frame(maxWidth: 760, alignment: .leading).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("오프라인 연습").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("나중에 계속") { dismiss() } } }
        }
        .onAppear { normalizeSelection() }
        .onChange(of: courseID) { _, _ in normalizeSelection() }
        .onChange(of: unitID) { _, _ in normalizeSelection() }
    }
    private func normalizeSelection() {
        guard let course else { return }
        if courseID != course.id { courseID = course.id }
        if !course.units.contains(where: { $0.id == unitID }) { unitID = course.units.first?.id ?? "" }
        if let unit, !unit.subunits.contains(where: { $0.id == subunitID }) { subunitID = unit.subunits.first?.id ?? "" }
    }
    private var configuration: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            if courses.isEmpty { Text("현재 공개된 연습 과목이 없습니다. 학습 화면에서 공개 상태를 다시 확인해 주세요.").font(.mCallout) }
            Picker("과목", selection: $courseID) { ForEach(courses) { Text($0.title).tag($0.id) } }
                .pickerStyle(.menu).frame(minHeight: 44)
            Picker("범위", selection: $scope) {
                Text("소단원 10문항").tag(PaperScope.subunit)
                Text("대단원 20문항").tag(PaperScope.unit)
                Text("과목 40문항").tag(PaperScope.course)
            }.pickerStyle(.menu).frame(minHeight: 44)
            if scope != .course, let course {
                Picker("단원", selection: $unitID) { ForEach(course.units) { Text($0.title).tag($0.id) } }
                    .pickerStyle(.menu).frame(minHeight: 44)
            }
            if scope == .subunit, let unit {
                Picker("소단원", selection: $subunitID) { ForEach(unit.subunits) { Text($0.title).tag($0.id) } }
                    .pickerStyle(.menu).frame(minHeight: 44)
            }
            Button("연습 시작") {
                guard let course else { return }
                model.start(scope: scope, course: course, unit: scope == .course ? nil : unit,
                            subunit: scope == .subunit ? subunit : nil)
            }.buttonStyle(PrimaryButtonStyle()).disabled(course == nil)
        }
    }
    private func practice(_ session: PracticeAssessmentRecord) -> some View {
        let question = session.questions[session.index]
        return VStack(alignment: .leading, spacing: Tokens.Space.s4) {
            Text("\(session.index + 1) / \(session.questions.count) · \(session.title)").font(.mCallout)
            if let score = session.score {
                Text("연습 결과 \(score)점").font(.mTitle)
            }
            PracticeMathText(text: question.prompt)
            if let choices = question.choices {
                ForEach(Array(choices.prefix(5).enumerated()), id: \.offset) { index, choice in
                    Button { model.answer(["a", "b", "c", "d", "e"][index]) } label: {
                        HStack { Text("\(index + 1)"); PracticeMathText(text: choice); Spacer() }
                            .padding(Tokens.Space.s3)
                            .background(session.answers[session.index] == ["a", "b", "c", "d", "e"][index] ? Tokens.actionPrimary.opacity(0.12) : Tokens.paper2,
                                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    }.buttonStyle(.plain).disabled(session.completedAt != nil)
                }
            } else {
                TextField("답 입력", text: Binding(get: { session.answers[session.index] }, set: { model.answer($0) }))
                    .textFieldStyle(.roundedBorder).disabled(session.completedAt != nil)
            }
            if session.completedAt != nil {
                Text("정답: \(question.answer)").font(.mBodyB)
                PracticeMathText(text: question.solution)
            }
            HStack {
                Button("이전") { model.move(-1) }.disabled(session.index == 0)
                Spacer()
                Button("다음") { model.move(1) }.disabled(session.index + 1 == session.questions.count)
            }.frame(minHeight: 44)
            if session.completedAt == nil {
                Button("연습 채점") { model.finish() }.buttonStyle(PrimaryButtonStyle())
            } else { Button("다른 연습하기") { model.reset() }.buttonStyle(PrimaryButtonStyle()) }
        }
    }
}

private struct PracticeMathText: View {
    let text: String
    @State private var height: CGFloat = 80
    @State private var ready = false
    private var requiresMathRenderer: Bool {
        text.range(of: #"\$|\\\(|\\\[|\\(?:frac|sqrt|sum|int|begin)\b"#, options: .regularExpression) != nil
    }
    var body: some View {
        Group {
            if requiresMathRenderer {
                KatexText(text: text, height: Binding(get: { height }, set: { height = $0; ready = true }))
                    .overlay { if !ready { ProgressView("수식 준비 중").font(.mCaption) } }
            } else {
                Text(text).font(.mBody).foregroundStyle(Tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: text) { _, _ in ready = false }
    }
}
