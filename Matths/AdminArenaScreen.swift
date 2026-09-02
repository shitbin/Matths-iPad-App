import SwiftUI

@MainActor
private final class AdminArenaModel: ObservableObject {
  @Published var dashboard: ServerAPI.AdminArenaDashboard?
  @Published var isLoading = false
  @Published var actionID: String?
  @Published var errorMessage: String?
  @Published var noticeMessage: String?
  @Published var preview: AcademyPreviewFile?
  var query: [String: String] = [:]
  func load(quiet: Bool = false) async {
    if !quiet { isLoading = dashboard == nil }
    errorMessage = nil
    do {
      dashboard = try await ServerAPI.adminArenaDashboard(query: query)
    } catch is CancellationError {} catch { errorMessage = readable(error) }
    isLoading = false
  }
  func act(id: String, message: String, operation: () async throws -> Void) async -> Bool {
    guard actionID == nil else { return false }
    actionID = id
    errorMessage = nil
    noticeMessage = nil
    do {
      try await operation()
      noticeMessage = message
      actionID = nil
      await load(quiet: true)
      return true
    } catch {
      errorMessage = readable(error)
      actionID = nil
      return false
    }
  }
  func openEvidence(id: String, file: ServerAPI.AdminArenaEvidenceFile) async {
    guard actionID == nil else { return }
    actionID = "file:\(file.id)"
    do {
      preview = .init(url: try await ServerAPI.downloadAdminArenaEvidence(id: id, file: file))
    } catch { errorMessage = readable(error) }
    actionID = nil
  }
  func openCSV() async {
    guard actionID == nil else { return }
    actionID = "csv"
    do { preview = .init(url: try await ServerAPI.downloadAdminArenaRankingCSV()) } catch {
      errorMessage = readable(error)
    }
    actionID = nil
  }
  private func readable(_ error: Error) -> String {
    (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription
  }
}

struct AdminArenaScreen: View {
  private enum Area: String, CaseIterable, Identifiable {
    case live = "실시간"
    case history = "기록"
    case integrity = "검토"
    case audit = "감사"
    case ranking = "랭킹"
    var id: String { rawValue }
  }
  private enum ReviewTarget: Identifiable {
    case match(ServerAPI.AdminArenaHeldMatch)
    case risk(ServerAPI.AdminArenaRiskCase)
    var id: String {
      switch self {
      case .match(let v): "m:\(v.id)"
      case .risk(let v): "r:\(v.id)"
      }
    }
  }
  private struct EvidenceRequest: Identifiable {
    let matchID: String
    let attempt: ServerAPI.AdminArenaAttempt
    var id: String { "\(matchID):\(attempt.id)" }
  }
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @StateObject private var model = AdminArenaModel()
  @State private var area: Area = .live
  @State private var selectedID: String?
  @State private var review: ReviewTarget?
  @State private var evidenceRequest: EvidenceRequest?
  @State private var showsFilter = false
  let onClose: () -> Void
  private var compactLandscape: Bool {
    verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
  }
  var body: some View {
    VStack(spacing: 0) {
      header
      if let value = model.errorMessage {
        banner(value, Tokens.dangerInk, "exclamationmark.triangle.fill")
      }
      if let value = model.noticeMessage {
        banner(value, Tokens.successInk, "checkmark.circle.fill")
      }
      if model.isLoading && model.dashboard == nil {
        Spacer()
        ProgressView("Arena 운영 원장을 불러오는 중입니다")
        Spacer()
      } else if let value = model.dashboard {
        dashboard(value)
      } else {
        ContentUnavailableView(
          "Arena 운영 데이터를 불러오지 못했습니다", systemImage: "shield.lefthalf.filled.badge.checkmark")
      }
    }.background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge).task {
      await model.load()
    }.task(id: area) {
      guard area == .live else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(15))
        if !Task.isCancelled { await model.load(quiet: true) }
      }
    }.compactHeightSheet(item: $model.preview) { value in
      CommunityFilePreview(url: value.url) { model.preview = nil }.ignoresSafeArea()
    }.sheet(item: $review) { value in
      switch value {
      case .match(let match):
        AdminArenaMatchReviewSheet(match: match) { decision, note in
          await actMatch(match, decision, note)
        }
      case .risk(let risk):
        AdminArenaRiskReviewSheet(risk: risk) { decision, note in
          await actRisk(risk, decision, note)
        }
      }
    }.sheet(item: $evidenceRequest) { value in
      AdminArenaEvidenceRequestSheet(attempt: value.attempt) { message in
        await requestEvidence(value, message)
      }
    }.sheet(isPresented: $showsFilter) {
      AdminArenaHistoryFilterSheet(initial: model.query) { query in
        model.query = query
        Task { await model.load() }
        showsFilter = false
      }
    }
  }
  private var header: some View {
    VStack(spacing: 8) {
      HStack {
        Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
          .buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("관리자 홈")
        VStack(alignment: .leading, spacing: 1) {
          Text("GOAT Arena 운영").font(.mHeading)
          Text("실시간 경기·부정행위·원장·랭킹").font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Spacer()
        if area == .history {
          Button {
            showsFilter = true
          } label: {
            Image(systemName: "line.3.horizontal.decrease.circle").frame(width: 44, height: 44)
          }.buttonStyle(.plain)
        }
        Button {
          Task { await model.load() }
        } label: {
          Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
        }.buttonStyle(.plain)
      }
      Picker("운영 구역", selection: $area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }
        .pickerStyle(.segmented)
    }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
  }
  @ViewBuilder private func dashboard(_ value: ServerAPI.AdminArenaDashboard) -> some View {
    switch area {
    case .live: live(value.live)
    case .history: history(value.history)
    case .integrity: integrity(value.integrity, evidence: value.evidence)
    case .audit: audit(value.audit)
    case .ranking: ranking(value.ranking)
    }
  }

  private func live(_ value: ServerAPI.AdminArenaLive) -> some View {
    let selected = value.matches.first(where: { $0.id == selectedID }) ?? value.matches.first
    return split(
      list: {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            HStack {
              badge("풀이 \(value.stats.live)")
              badge("대기 \(value.stats.waiting)")
              badge("확인 \(value.stats.stale)")
            }
            if value.matches.isEmpty {
              ContentUnavailableView("진행 경기 없음", systemImage: "bolt.shield")
            }
            ForEach(value.matches) { match in
              Button {
                selectedID = match.id
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  HStack {
                    Text(match.tierPairLabel.isEmpty ? match.id : match.tierPairLabel).font(.mBodyB)
                    Spacer()
                    badge(match.stageLabel)
                  }
                  Text("\(division(match.division)) · \(type(match.matchType))").font(.mMicro)
                    .foregroundStyle(Tokens.text3)
                }.padding(10).background(
                  selected?.id == match.id ? Tokens.primary.opacity(0.09) : Tokens.surface,
                  in: RoundedRectangle(cornerRadius: 11))
              }.buttonStyle(.plain)
            }
          }.padding(12)
        }
      },
      detail: {
        ScrollView {
          if let match = selected {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                VStack(alignment: .leading) {
                  Text(match.tierPairLabel.isEmpty ? "경기 \(match.id)" : match.tierPairLabel).font(
                    .mTitle)
                  Text("\(division(match.division)) · \(type(match.matchType)) · \(match.status)")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                }
                Spacer()
                badge(match.stageLabel)
              }
              participantPair(match.challenger, match.defender)
              if let attempt = match.defenderAttempt {
                VStack(alignment: .leading, spacing: 6) {
                  Text("방어자 진행").font(.mBodyB)
                  Text(
                    "\(attempt.currentQuestion)/5번 · 답안 \(attempt.answeredCount)개 · \(attempt.focusState)"
                  ).font(.mBody)
                  Text("최근 활동 \(date(attempt.lastHeartbeatAt))").font(.mCaption).foregroundStyle(
                    Tokens.text2)
                }.card()
              }
              if match.deadlineOverdue {
                Label("현재 단계 기한이 지났습니다.", systemImage: "clock.badge.exclamationmark")
                  .foregroundStyle(Tokens.dangerInk)
              }
            }.padding(14)
          } else {
            ContentUnavailableView("경기를 선택하세요", systemImage: "figure.fencing")
          }
        }
      })
  }
  private func history(_ value: ServerAPI.AdminArenaHistory) -> some View {
    let selected = value.records.first(where: { $0.id == selectedID }) ?? value.records.first
    return split(
      list: {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            Text("검색 결과 \(value.total)건 · \(value.page)/\(value.totalPages) 페이지").font(.mBodyB)
            if value.records.isEmpty {
              ContentUnavailableView("조건에 맞는 경기 없음", systemImage: "magnifyingglass")
            }
            ForEach(value.records) { match in
              Button {
                selectedID = match.id
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  HStack {
                    Text(match.tierPairLabel.isEmpty ? match.matchKey : match.tierPairLabel).font(
                      .mBodyB)
                    Spacer()
                    badge(status(match.status))
                  }
                  Text(
                    "\(division(match.division)) · \(type(match.matchType)) · \(integrity(match.integrityStatus))"
                  ).font(.mMicro).foregroundStyle(Tokens.text3)
                }.padding(10).background(
                  selected?.id == match.id ? Tokens.primary.opacity(0.09) : Tokens.surface,
                  in: RoundedRectangle(cornerRadius: 11))
              }.buttonStyle(.plain)
            }
          }.padding(12)
        }
      },
      detail: {
        ScrollView {
          if let match = selected {
            VStack(alignment: .leading, spacing: 12) {
              Text(match.tierPairLabel.isEmpty ? match.matchKey : match.tierPairLabel).font(.mTitle)
              participantPair(match.challenger, match.defender)
              HStack {
                metric(status(match.status), "경기 상태")
                metric(integrity(match.integrityStatus), "무결성")
                metric(match.seasonKey, "시즌")
              }
              VStack(alignment: .leading, spacing: 5) {
                Text("성립 \(date(match.requestedAt))")
                Text("시작 \(date(match.startedAt))")
                Text("완료 \(date(match.completedAt))")
                Text("경기 ID \(match.id)").textSelection(.enabled)
              }.font(.mCaption).foregroundStyle(Tokens.text2)
            }.padding(14)
          } else {
            ContentUnavailableView("기록을 선택하세요", systemImage: "clock.arrow.circlepath")
          }
        }
      })
  }

  private func integrity(
    _ value: ServerAPI.AdminArenaIntegrity, evidence: [ServerAPI.AdminArenaEvidenceEntry]
  ) -> some View {
    let rows: [IntegrityRow] =
      value.heldMatches.map { .match($0) } + value.cases.map { .risk($0) }
      + evidence.map { .evidence($0) }
    let selected = rows.first(where: { $0.id == selectedID }) ?? rows.first
    return split(
      list: {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            HStack {
              badge("보류 \(value.heldCount)")
              badge("계정 \(value.openCount)")
              badge("완료 \(value.completedCount)")
            }
            if rows.isEmpty { ContentUnavailableView("검토 대기 없음", systemImage: "checkmark.shield") }
            ForEach(rows) { row in
              Button {
                selectedID = row.id
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  HStack {
                    Text(row.title).font(.mBodyB)
                    Spacer()
                    badge(row.kind)
                  }
                  Text(row.subtitle).font(.mMicro).foregroundStyle(Tokens.text3)
                }.padding(10).background(
                  selected?.id == row.id ? Tokens.primary.opacity(0.09) : Tokens.surface,
                  in: RoundedRectangle(cornerRadius: 11))
              }.buttonStyle(.plain)
            }
          }.padding(12)
        }
      },
      detail: {
        ScrollView {
          if let selected {
            integrityDetail(selected)
          } else {
            ContentUnavailableView("검토 항목을 선택하세요", systemImage: "shield.checkered")
          }
        }
      })
  }
  @ViewBuilder private func integrityDetail(_ row: IntegrityRow) -> some View {
    switch row {
    case .match(let match):
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading) {
            Text(match.tierPairLabel.isEmpty ? "보류 경기" : match.tierPairLabel).font(.mTitle)
            Text(
              "\(division(match.division)) · \(type(match.matchType)) · \(integrity(match.integrityStatus))"
            ).font(.mCaption).foregroundStyle(Tokens.text2)
          }
          Spacer()
          Button("최종 판정") { review = .match(match) }.buttonStyle(.borderedProminent)
        }
        participantPair(match.challenger.map(toParticipant), match.defender.map(toParticipant))
        Text("검토 목표 \(date(match.reviewDeadlineAt))").font(.mCaption)
        ForEach(match.attempts) { attempt in
          VStack(alignment: .leading, spacing: 7) {
            HStack {
              Text(role(attempt.role)).font(.mBodyB)
              Spacer()
              badge(attempt.status)
            }
            Text("\(attempt.correctCount ?? 0)/5 정답 · \(seconds(attempt.activeSolveTimeMs))").font(
              .mCaption)
            if let evidence = attempt.evidence {
              Text("증거 \(evidence.status) · 추가 소명 \(evidence.supplementalStatus)").font(.mCaption)
              ForEach(evidence.files) { file in
                Button("\(file.originalName) 열기") {
                  Task { await model.openEvidence(id: evidence.id, file: file) }
                }
              }
              ForEach(evidence.supplementalFiles) { file in
                Button("추가 소명 · \(file.originalName)") {
                  Task { await model.openEvidence(id: evidence.id, file: file) }
                }
              }
            }
            Button("\(role(attempt.role))에게 추가 소명 요청") {
              evidenceRequest = .init(matchID: match.id, attempt: attempt)
            }.buttonStyle(.bordered)
            if !attempt.questions.isEmpty {
              DisclosureGroup("문항별 답안·풀이시간") {
                ForEach(attempt.questions) { question in
                  VStack(alignment: .leading) {
                    Text("\(question.number)번 · \(question.correct ? "정답":"오답")").font(.mBodyB)
                    Text(question.prompt).font(.mCaption)
                    Text(
                      "제출 \(question.submittedAnswer) · 정답 \(question.correctAnswer) · \(seconds(question.responseTimeMs))"
                    ).font(.mMicro).foregroundStyle(Tokens.text3)
                    if !question.solution.isEmpty { Text(question.solution).font(.mCaption) }
                  }.padding(.vertical, 5)
                }
              }
            }
          }.card()
        }
      }.padding(14)
    case .risk(let risk):
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading) {
            Text(risk.user?.name ?? "계정 위험 검토").font(.mTitle)
            Text(risk.user?.email ?? "").font(.mCaption).foregroundStyle(Tokens.text2)
          }
          Spacer()
          badge("위험 \(risk.riskScore)")
        }
        ForEach(risk.reasons) { reason in
          VStack(alignment: .leading) {
            Text("\(reason.label) +\(reason.points)").font(.mBodyB)
            Text(reason.description).font(.mCaption)
          }.card()
        }
        Text("연관 계정 \(risk.linkedUsers.count)개 · 관련 경기 \(risk.relatedMatchCount)건").font(.mCaption)
        Button("계정 무결성 판정") { review = .risk(risk) }.buttonStyle(.borderedProminent)
      }.padding(14)
    case .evidence(let entry):
      VStack(alignment: .leading, spacing: 12) {
        Text("최근 풀이 증거").font(.mTitle)
        Text("\(entry.user?.name ?? "사용자") · \(role(entry.attemptRole)) · \(entry.status)").font(
          .mBody)
        Text("제출 \(date(entry.submittedAt)) · 경기 \(entry.matchId)").font(.mCaption).foregroundStyle(
          Tokens.text2)
        if entry.files.isEmpty { Text("보존 중인 파일 없음").font(.mCaption) }
        ForEach(entry.files) { file in
          Button {
            Task { await model.openEvidence(id: entry.id, file: file) }
          } label: {
            Label(file.originalName, systemImage: "doc.viewfinder")
          }.buttonStyle(.bordered)
        }
      }.padding(14)
    }
  }

  private func audit(_ value: ServerAPI.AdminArenaAudit) -> some View {
    let selected = value.issues.first(where: { $0.id == selectedID }) ?? value.issues.first
    return split(
      list: {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            HStack {
              badge("치명 \(value.summary.criticalCount)")
              badge("경고 \(value.summary.warningCount)")
              badge("대기 \(value.summary.pendingOutboxCount)")
            }
            if value.issues.isEmpty {
              ContentUnavailableView("원장 이상 없음", systemImage: "checkmark.seal")
            }
            ForEach(value.issues) { issue in
              Button {
                selectedID = issue.id
              } label: {
                VStack(alignment: .leading, spacing: 3) {
                  HStack {
                    Text(issue.title).font(.mBodyB)
                    Spacer()
                    badge(issue.severity.uppercased())
                  }
                  Text(issue.category).font(.mMicro).foregroundStyle(Tokens.text3)
                }.padding(10).background(
                  selected?.id == issue.id ? Tokens.primary.opacity(0.09) : Tokens.surface,
                  in: RoundedRectangle(cornerRadius: 11))
              }.buttonStyle(.plain)
            }
          }.padding(12)
        }
      },
      detail: {
        ScrollView {
          if let issue = selected {
            VStack(alignment: .leading, spacing: 12) {
              Text(issue.title).font(.mTitle)
              HStack {
                badge(issue.severity.uppercased())
                badge(issue.category)
              }
              Text(issue.detail).font(.mBody)
              Text("\(issue.entityType) · \(issue.entityId)").font(.mCaption).textSelection(
                .enabled)
              Text("관측 \(date(issue.observedAt))").font(.mCaption).foregroundStyle(Tokens.text2)
            }.padding(14)
          } else {
            VStack(spacing: 10) {
              Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(
                Tokens.successInk)
              Text("원장 상태 \(value.health)").font(.mHeading)
              Text(
                "경기 \(value.summary.checkedMatches)건 · 이용 주기 \(value.summary.checkedCycles)건 · 초대 \(value.summary.checkedInvitations)건 검사"
              ).font(.mCaption)
            }.frame(maxWidth: .infinity, minHeight: 220)
          }
        }
      })
  }

  private func ranking(_ value: ServerAPI.AdminArenaRanking) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading) {
            Text("최종 종합 랭킹").font(.mTitle)
            Text("최근 계산 \(date(value.health.latestCalculationAt))").font(.mCaption).foregroundStyle(
              Tokens.text2)
          }
          Spacer()
          badge(value.health.status)
        }
        HStack {
          metric("\(value.health.activeProfileCount)", "활성 프로필")
          metric("\(value.health.staleCount)", "지연")
          metric("\(value.health.pendingOutboxCount)", "대기 이벤트")
        }
        if !value.health.alerts.isEmpty {
          ForEach(value.health.alerts, id: \.self) {
            Label($0, systemImage: "exclamationmark.triangle.fill").font(.mCaption).foregroundStyle(
              Tokens.dangerInk)
          }
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("운영 준비 상태").font(.mBodyB)
          Text(
            "메일 \(value.operations.emailConfigured ? "정상":"미설정") · 스케줄러 \(value.operations.schedulerEnabled ? "가동":"중지") · 세션 \(value.operations.sharedSessionConfigured ? "정상":"확인")"
          ).font(.mCaption)
        }.card()
        HStack {
          Button("랭킹 재계산") {
            Task {
              _ = await model.act(id: "rebuild", message: "최종 종합 랭킹을 재계산했습니다.") {
                try await ServerAPI.rebuildAdminArenaRanking()
              }
            }
          }.buttonStyle(.borderedProminent)
          Menu("복구 작업") {
            ForEach(
              ["ACCESS_CYCLE_RETRY", "NOTIFICATION_RETRY", "SETTLEMENT_RETRY", "SEASON_RETRY"],
              id: \.self
            ) { task in
              Button(task) {
                Task {
                  _ = await model.act(id: task, message: "\(task) 작업을 실행했습니다.") {
                    try await ServerAPI.runAdminArenaMaintenance(task)
                  }
                }
              }
            }
          }
          Button("CSV 내보내기") { Task { await model.openCSV() } }.buttonStyle(.bordered)
        }
        Text("최근 순위 변경 \(value.history.count)건").font(.mBodyB)
        ForEach(value.history.prefix(30)) { entry in
          HStack {
            VStack(alignment: .leading) {
              Text(entry.user?.name ?? "사용자").font(.mBodyB)
              Text(entry.changeType).font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Spacer()
            Text(date(entry.occurredAt)).font(.mMicro)
          }
        }
      }.readableWidth(820).adaptiveHPadding().adaptiveVPadding()
    }
  }

  private func split<List: View, Detail: View>(
    @ViewBuilder list: () -> List, @ViewBuilder detail: () -> Detail
  ) -> some View {
    Group {
      if compactLandscape {
        HStack(spacing: 0) {
          list().frame(width: 355)
          Divider()
          detail().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        VStack(spacing: 0) {
          list().frame(maxHeight: 280)
          Divider()
          detail().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }
  private func participantPair(
    _ first: ServerAPI.AdminArenaParticipant?, _ second: ServerAPI.AdminArenaParticipant?
  ) -> some View {
    HStack {
      participant(first, "공격자")
      Text("VS").font(.mMicro).foregroundStyle(Tokens.text3)
      participant(second, "방어자")
    }
  }
  private func participant(_ value: ServerAPI.AdminArenaParticipant?, _ label: String) -> some View
  {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
      Text(value?.name.isEmpty == false ? value!.name : "확인 필요").font(.mBodyB)
      if let score = value?.score {
        Text("\(score.formatted())점 · \(value?.correctCount ?? 0)/5").font(.mCaption)
      }
    }.frame(maxWidth: .infinity, alignment: .leading).card()
  }
  private func toParticipant(_ value: ServerAPI.AdminArenaUser) -> ServerAPI.AdminArenaParticipant {
    .init(
      id: value.id, name: value.name, email: value.email, result: "", score: nil, correctCount: nil)
  }
  private func actMatch(_ match: ServerAPI.AdminArenaHeldMatch, _ decision: String, _ note: String)
    async -> Bool
  {
    await model.act(
      id: "review:\(match.id)",
      message: decision == "NOTE" ? "검토 메모를 저장했습니다." : "경기 판정을 저장하고 정산 상태를 갱신했습니다."
    ) { try await ServerAPI.reviewAdminArenaMatch(id: match.id, decision: decision, note: note) }
  }
  private func actRisk(_ risk: ServerAPI.AdminArenaRiskCase, _ decision: String, _ note: String)
    async -> Bool
  {
    await model.act(id: "risk:\(risk.id)", message: "계정 무결성 판정을 저장했습니다.") {
      try await ServerAPI.reviewAdminArenaCase(id: risk.id, decision: decision, note: note)
    }
  }
  private func requestEvidence(_ value: EvidenceRequest, _ message: String) async -> Bool {
    await model.act(id: value.id, message: "추가 소명 요청을 전송하고 24시간 기한을 시작했습니다.") {
      try await ServerAPI.requestAdminArenaEvidence(
        matchID: value.matchID, role: value.attempt.role, message: message)
    }
  }
  private func division(_ value: String) -> String { value == "MAIN" ? "Ranked" : "Unranked" }
  private func type(_ value: String) -> String {
    ["NORMAL": "일반전", "REVENGE": "복수전", "FRIENDLY": "친선전"][value] ?? value
  }
  private func role(_ value: String) -> String { value == "CHALLENGER" ? "공격자" : "방어자" }
  private func status(_ value: String) -> String {
    [
      "SUBMITTED": "제출", "RESOLVED": "확정", "HELD": "검토 보류", "SETTLED": "정산", "CANCELLED": "취소",
      "INVALID": "무효",
    ][value] ?? value
  }
  private func integrity(_ value: String) -> String {
    [
      "PENDING": "자동 검토", "CLEAR": "이상 없음", "SUSPICIOUS": "확인 필요", "CONFIRMED": "부정 확정",
      "INVALID": "무효",
    ][value] ?? value
  }
  private func seconds(_ value: Int?) -> String {
    guard let value else { return "기록 없음" }
    return String(format: "%.1f초", Double(value) / 1000)
  }
  private func date(_ value: String?) -> String {
    guard let value else { return "—" }
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return (parser.date(from: value) ?? ISO8601DateFormatter().date(from: value))?.formatted(
      date: .numeric, time: .shortened) ?? value
  }
  private func metric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading) {
      Text(value).font(.mBodyB.monospacedDigit())
      Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
    }.frame(maxWidth: .infinity, alignment: .leading).card()
  }
  private func badge(_ value: String) -> some View {
    Text(value).font(.mMicro.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3)
      .foregroundStyle(Tokens.primary).background(Tokens.primary.opacity(0.1), in: Capsule())
  }
  private func banner(_ value: String, _ color: Color, _ icon: String) -> some View {
    Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16)
      .padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(
        color.opacity(0.1))
  }
}

private enum IntegrityRow: Identifiable {
  case match(ServerAPI.AdminArenaHeldMatch)
  case risk(ServerAPI.AdminArenaRiskCase)
  case evidence(ServerAPI.AdminArenaEvidenceEntry)
  var id: String {
    switch self {
    case .match(let v): "m:\(v.id)"
    case .risk(let v): "r:\(v.id)"
    case .evidence(let v): "e:\(v.id)"
    }
  }
  var title: String {
    switch self {
    case .match(let v): v.tierPairLabel.isEmpty ? "보류 경기" : v.tierPairLabel
    case .risk(let v): v.user?.name ?? "계정 위험"
    case .evidence(let v): v.user?.name ?? "풀이 증거"
    }
  }
  var subtitle: String {
    switch self {
    case .match(let v): "\(v.division) · \(v.integrityStatus)"
    case .risk(let v): "위험 점수 \(v.riskScore) · 연관 계정 \(v.linkedUsers.count)"
    case .evidence(let v): "\(v.attemptRole) · 파일 \(v.files.count)개"
    }
  }
  var kind: String {
    switch self {
    case .match: "경기"
    case .risk: "계정"
    case .evidence: "증거"
    }
  }
}
extension View {
  fileprivate func card() -> some View {
    self.padding(10).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
  }
}

private struct AdminArenaMatchReviewSheet: View {
  let match: ServerAPI.AdminArenaHeldMatch
  let onSave: (String, String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var decision = "NOTE"
  @State private var note = ""
  @State private var confirm = false
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Picker("판정", selection: $decision) {
          Text("메모만 저장").tag("NOTE")
          Text("이상 없음·정산 재개").tag("CLEAR")
          Text("공격자 부정행위").tag("CHALLENGER_CHEATING")
          Text("방어자 부정행위").tag("DEFENDER_CHEATING")
          Text("양측 부정행위").tag("BOTH_CHEATING")
        }
        TextField("판단 근거·운영 메모", text: $note, axis: .vertical).lineLimit(4...10)
        if decision != "NOTE" {
          Text("판정 시 알림, 매치메이킹 제한, 예치 학습일과 보상 상태가 함께 갱신됩니다.").font(.mCaption).foregroundStyle(
            Tokens.dangerInk)
        }
      }.navigationTitle("경기 최종 판정").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("판정 검토") { confirm = true }.disabled(
            note.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }.confirmationDialog(
        "\(decision) 판정을 확정할까요?", isPresented: $confirm, titleVisibility: .visible
      ) {
        Button("확정", role: decision.contains("CHEATING") ? .destructive : nil) {
          saving = true
          Task {
            if await onSave(decision, note) { dismiss() }
            saving = false
          }
        }
        Button("취소", role: .cancel) {}
      }
    }.presentationDetents([.medium, .large])
  }
}
private struct AdminArenaRiskReviewSheet: View {
  let risk: ServerAPI.AdminArenaRiskCase
  let onSave: (String, String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var decision = "CLEAR"
  @State private var note = ""
  @State private var saving = false
  @State private var confirm = false
  var body: some View {
    NavigationStack {
      Form {
        Text("위험 점수 \(risk.riskScore) · \(risk.user?.name ?? "사용자")").font(.mBodyB)
        Picker("판정", selection: $decision) {
          Text("이상 없음·제한 해제").tag("CLEAR")
          Text("위험 확인·신규 경기 제한").tag("RESTRICT")
        }
        TextField("검토 근거", text: $note, axis: .vertical).lineLimit(4...8)
      }.navigationTitle("계정 무결성 판정").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("판정 검토") { confirm = true }.disabled(
            note.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }.confirmationDialog("판정을 확정할까요?", isPresented: $confirm, titleVisibility: .visible) {
        Button("확정", role: decision == "RESTRICT" ? .destructive : nil) {
          saving = true
          Task {
            if await onSave(decision, note) { dismiss() }
            saving = false
          }
        }
        Button("취소", role: .cancel) {}
      }
    }.presentationDetents([.medium])
  }
}
private struct AdminArenaEvidenceRequestSheet: View {
  let attempt: ServerAPI.AdminArenaAttempt
  let onSave: (String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var message = ""
  @State private var saving = false
  @State private var confirm = false
  var body: some View {
    NavigationStack {
      Form {
        Text("\(attempt.role == "CHALLENGER" ? "공격자":"방어자")에게 요청 시 즉시 24시간 제출 기한이 시작됩니다.").font(
          .mCaption)
        TextField("추가로 확인할 풀이 단계나 자료", text: $message, axis: .vertical).lineLimit(4...8)
      }.navigationTitle("추가 소명 요청").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("요청 검토") { confirm = true }.disabled(
            message.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }.confirmationDialog("추가 소명을 요청할까요?", isPresented: $confirm, titleVisibility: .visible) {
        Button("요청 전송") {
          saving = true
          Task {
            if await onSave(message) { dismiss() }
            saving = false
          }
        }
        Button("취소", role: .cancel) {}
      }
    }.presentationDetents([.medium])
  }
}
private struct AdminArenaHistoryFilterSheet: View {
  let initial: [String: String]
  let onApply: ([String: String]) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var division = ""
  @State private var matchType = ""
  @State private var status = ""
  @State private var integrityStatus = ""
  @State private var dateFrom = ""
  @State private var dateTo = ""
  var body: some View {
    NavigationStack {
      Form {
        TextField("닉네임·실명·이메일·경기 ID", text: $query)
        TextField("시작일 YYYY-MM-DD", text: $dateFrom)
        TextField("종료일 YYYY-MM-DD", text: $dateTo)
        Picker("Division", selection: $division) {
          Text("전체").tag("")
          Text("Unranked").tag("SUB")
          Text("Ranked").tag("MAIN")
        }
        Picker("경기 종류", selection: $matchType) {
          Text("전체").tag("")
          Text("일반전").tag("NORMAL")
          Text("복수전").tag("REVENGE")
          Text("친선전").tag("FRIENDLY")
        }
        TextField("경기 상태 코드 (선택)", text: $status)
        TextField("무결성 상태 코드 (선택)", text: $integrityStatus)
      }.navigationTitle("경기 기록 필터").toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("초기화") {
            onApply([:])
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("적용") {
            onApply(
              [
                "query": query, "dateFrom": dateFrom, "dateTo": dateTo, "division": division,
                "matchType": matchType, "status": status, "integrityStatus": integrityStatus,
              ].filter { !$0.value.isEmpty })
          }
        }
      }.onAppear {
        query = initial["query"] ?? ""
        dateFrom = initial["dateFrom"] ?? ""
        dateTo = initial["dateTo"] ?? ""
        division = initial["division"] ?? ""
        matchType = initial["matchType"] ?? ""
        status = initial["status"] ?? ""
        integrityStatus = initial["integrityStatus"] ?? ""
      }.presentationDetents([.large])
    }
  }
}
