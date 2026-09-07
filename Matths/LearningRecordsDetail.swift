import SwiftUI

struct LearningReviewSchedule: View {
    @EnvironmentObject private var store: AppStore
    private var upcoming: [WrongNoteEntry] {
        store.wrongNotes.filter { !$0.isMastered && ($0.nextReviewAt ?? .distantPast) > Date() }
            .sorted { ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture) }
    }
    var body: some View {
        if !upcoming.isEmpty {
            DisclosureGroup("다음 복습 예정 · \(upcoming.count)개") {
                ForEach(Array(upcoming.prefix(5))) { note in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.typeName).font(.mCallout)
                            if let date = note.nextReviewAt { Text(date, style: .date).font(.mCaption).foregroundStyle(Tokens.text2) }
                        }
                        Spacer()
                        Button("미리 복습") { store.startReview(ids: [note.id]) }.font(.mCallout).frame(minHeight: 44)
                    }.padding(.vertical, Tokens.Space.s2)
                }
            }.font(.mBodyB)
        }
    }
}

struct WeeklyLearningReportScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var report = EventLog.dashboardSnapshot()
    @State private var days = EventLog.minutesByWeekday()
    @State private var labels = EventLog.recentDayLabels()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    Text("최근 7일의 공부").font(.mTitle)
                    Text("현재 계정으로 이 기기에 기록된 활동입니다. 공식 개념 진도와 평가 결과는 별도로 서버 기준을 따릅니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                    VStack(spacing: Tokens.Space.s3) {
                        reportRow("공부한 날", "\(report.activeStudyDays)일")
                        reportRow("학습 시간", EventLog.formatStudyTime(report.weeklyStudyMinutes))
                        reportRow("푼 문제", "\(report.weeklySolvedProblems)개")
                        if report.weeklySolvedProblems > 0 { reportRow("정답률", "\(report.correctRate)%") }
                    }.card()
                    Text("날짜별 학습 시간").font(.mHeading)
                    if days.allSatisfy({ $0 == 0 }) {
                        Text("아직 기록된 학습 시간이 없어요. 첫 수업부터 시작해 볼까요?").font(.mBody).foregroundStyle(Tokens.text2)
                        Button("학습 시작") { store.route = .learn; dismiss() }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        ForEach(Array(days.enumerated()), id: \.offset) { index, minutes in
                            HStack(spacing: Tokens.Space.s3) {
                                Text(labels.indices.contains(index) ? labels[index] : "").font(.mCaption).frame(width: 40, alignment: .leading)
                                ProgressView(value: Double(minutes), total: Double(max(days.max() ?? 1, 1))).tint(Tokens.actionPrimary)
                                Text("\(minutes)분").font(.mCaption).monospacedDigit().frame(minWidth: 46, alignment: .trailing)
                            }
                        }
                    }
                    let delta = report.weeklySolvedProblems - report.previousSolvedProblems
                    if report.previousSolvedProblems > 0 {
                        Text(delta >= 0 ? "직전 7일보다 \(delta)문제를 더 풀었어요." : "직전 7일보다 \(-delta)문제를 적게 풀었어요. 오늘 한 가지부터 이어가세요.")
                            .font(.mCallout).foregroundStyle(Tokens.text2)
                    }
                    Button("오늘의 복습 보기") { store.route = .records; dismiss() }.frame(minHeight: 44)
                }.padding(Tokens.Space.s5).frame(maxWidth: 700, alignment: .leading).frame(maxWidth: .infinity)
            }
            .navigationTitle("학습 리포트").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in dismiss() }
    }
    private func reportRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label).font(.mBody); Spacer(); Text(value).font(.mBodyB).monospacedDigit() }
    }
}
