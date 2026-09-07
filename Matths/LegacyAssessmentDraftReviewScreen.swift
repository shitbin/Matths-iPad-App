import SwiftUI

struct LegacyAssessmentDraftReviewScreen: View {
    let attemptID: String
    let owner: AccountRequestOwner
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var state: ReviewPhase = .loading
    private enum ReviewPhase { case loading, ready, saving, failed }
    private var attempt: AssessmentAttemptV2? { store.attemptsV2.attempts.first { $0.id == attemptID } }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("업데이트 전이나 저장 충돌 때 이 기기에 보관한 답안입니다. 최신 서버 기록과 비교한 뒤 사용할 답안을 선택해 주세요.")
                    if state == .loading { ProgressView("서버 답안 확인 중") }
                    if state == .failed {
                        Text("서버 답안 또는 저장 상태를 확인하지 못했습니다. 기존 기기 답안은 보관 중입니다.")
                        Button("다시 확인") { Task { await refresh() } }
                    }
                }
                if let attempt, state == .ready || state == .saving {
                    ForEach(Array(attempt.questions.enumerated()), id: \.element.id) { index, question in
                        if let id = question.serverQuestionId, let local = attempt.legacyDraftEvidence?[id] {
                            Section("\(question.no)번") {
                                MathInline(text: question.prompt)
                                Text("기기 보관 답안: \(local.isEmpty ? "미응답" : local)")
                                let server = attempt.answers.indices.contains(index) ? attempt.answers[index] : ""
                                Text("서버 답안: \(server.isEmpty ? "미응답" : server)")
                            }
                        }
                    }
                    Section {
                        if attempt.submittedAt == nil && !attempt.isServerCancelled {
                            Button("기기 답안을 적용하고 계속 풀기") { resolve(useLocal: true) }
                        } else {
                            Text("이미 종료된 평가입니다. 기기 답안으로 공식 결과를 변경할 수 없습니다.")
                        }
                        Button("서버 답안 유지") { resolve(useLocal: false) }
                    }.disabled(state == .saving)
                }
            }
            .navigationTitle("기기 답안 확인").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("나중에 확인") { dismiss() }.disabled(state == .saving) } }
            .task(id: attemptID) { await refresh() }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in dismiss() }
        }
    }
    private func refresh() async {
        guard owner.isCurrent(in: store) else { dismiss(); return }
        state = .loading
        let ready = await store.refreshLegacyAssessmentForReview(id: attemptID, expectedOwner: owner)
        guard owner.isCurrent(in: store) else { dismiss(); return }
        state = ready ? .ready : .failed
    }
    private func resolve(useLocal: Bool) {
        guard state == .ready, owner.isCurrent(in: store) else { return }
        state = .saving
        Task {
            let resolved = await store.resolveLegacyAssessmentDraft(id: attemptID, useLocalAnswers: useLocal, expectedOwner: owner)
            guard owner.isCurrent(in: store) else { dismiss(); return }
            if resolved { dismiss() } else { state = .failed }
        }
    }
}
