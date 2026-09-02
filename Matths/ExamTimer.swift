//  ExamTimer.swift
//  Matths
//
//  밀리초 타이머. 7/27 요구: 랭킹전에서 점수가 같으면 더 빨리 푼 사람이 위.
//  따라서 ms 단위 기록이 필요하다.
//
//  중요: Date() 로 재면 안 된다. 사용자가 기기 시각을 바꾸거나
//  NTP 동기화가 끼면 값이 튄다. 단조 시계(monotonic)를 써야 한다.
//
//  **기록 정밀도와 발행 빈도는 다른 문제다.** 한 프로퍼티로 묶으면 안 된다.
//
//  예전에는 `elapsedMs` 를 30fps 로 @Published 했다. 시험 화면 세 곳
//  (AssessmentScreen·AssessmentPaperScreen·KiceExamScreen)이 이 객체를
//  @StateObject 로 직접 들고 있어서, 화면 body 전체가 초당 30번 재평가됐다.
//  정작 화면에 나가는 값은 mm:ss 뿐이라 30틱 중 29틱은 같은 문자열을 다시
//  만드는 순수 낭비였다. 밀리초를 찍던 `displayMs` 는 사용처가 한 곳도 없었다.
//
//  측정(2026-08-21, iPad Pro 13" 시뮬, 20초): 응시 데이터도 없는 **빈** 시험
//  화면에서 9.0% CPU. 실제 시험 화면에는 PDF·OMR·답안 입력이 얹힌다.
//
//  그래서 이렇게 가른다.
//    · 발행 — 초 단위. 값이 실제로 바뀔 때만.
//    · 기록 — 제출 순간에 exactElapsedMs() 로 정확히. 발행하지 않는다.

import SwiftUI
import Combine

@MainActor
final class ExamTimer: ObservableObject {
    /// 화면이 쓰는 값. 초가 바뀔 때만 발행된다.
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isRunning = false

    private var startedAt: ContinuousClock.Instant?
    private var accumulated: Duration = .zero
    private var ticker: AnyCancellable?

    /// 내부 확인 주기. 발행 주기가 아니다 — 아래 refresh() 가 초 경계에서만 발행한다.
    /// 1Hz 로 확인하면 타이머가 초 경계와 어긋난 만큼(최대 1초) 표시가 늦는다.
    /// 시험 화면은 남은 시간이 곧 실격이라 그 지연을 받을 수 없다. 4Hz 로 확인하면
    /// 표시 오차는 250ms 이하로 줄면서, 화면 재평가는 여전히 초당 1회다.
    private static let checkInterval = 1.0 / 4.0

    var display: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    /// 제출·기록용 정밀 경과(ms). **@Published 가 아니다.**
    /// 읽어도 화면이 무효화되지 않으므로 뷰 body 안에서 부르지 말 것 —
    /// 제출·채점처럼 값을 확정하는 순간에만 부른다.
    func exactElapsedMs() -> Int {
        var total = accumulated
        if let startedAt { total += ContinuousClock.now - startedAt }
        return Int(total.components.seconds * 1000
                   + total.components.attoseconds / 1_000_000_000_000_000)
    }

    func start() {
        guard !isRunning else { return }
        startedAt = ContinuousClock.now
        isRunning = true
        refresh()
        ticker = Timer.publish(every: Self.checkInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    func pause() {
        guard isRunning, let startedAt else { return }
        accumulated += ContinuousClock.now - startedAt
        self.startedAt = nil
        isRunning = false
        ticker?.cancel(); ticker = nil
        refresh()
    }

    /// 시험 중도 이탈 후 복귀 대응 — 7/27 "문제 나가도 저장되게 하자"
    func restore(elapsedMs ms: Int) {
        accumulated = .milliseconds(ms)
        refresh()
    }

    /// 초가 실제로 바뀐 틱에서만 발행한다. 같은 값을 다시 넣어도
    /// @Published 는 objectWillChange 를 보내므로, 이 가드가 곧 성능이다.
    private func refresh() {
        let seconds = exactElapsedMs() / 1000
        if seconds != elapsedSeconds { elapsedSeconds = seconds }
    }
}
