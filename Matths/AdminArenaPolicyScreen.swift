import SwiftUI

@MainActor
private final class AdminArenaPolicyModel: ObservableObject {
  @Published var value: ServerAPI.AdminArenaPolicyDashboard?
  @Published var loading = false
  @Published var action = false
  @Published var error: String?
  @Published var notice: String?
  func load() async {
    loading = value == nil
    error = nil
    do { value = try await ServerAPI.adminArenaPolicies() } catch is CancellationError {} catch {
      self.error = readable(error)
    }
    loading = false
  }
  func perform(message: String, _ operation: () async throws -> ServerAPI.AdminArenaPolicyDashboard)
    async -> Bool
  {
    guard !action else { return false }
    action = true
    error = nil
    notice = nil
    do {
      value = try await operation()
      notice = message
      action = false
      return true
    } catch {
      self.error = readable(error)
      action = false
      return false
    }
  }
  private func readable(_ error: Error) -> String {
    (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription
  }
}

struct AdminArenaPolicyScreen: View {
  private enum Area: String, CaseIterable, Identifiable {
    case products = "상품·가격"
    case shop = "Ranked 상점"
    case unranked = "Unranked"
    case ranked = "Ranked"
    var id: String { rawValue }
  }
  enum PriceTarget: Identifiable {
    case learning(Int)
    case mock(Int)
    var id: String {
      switch self {
      case .learning: "learning"
      case .mock: "mock"
      }
    }
  }
  private struct PolicyAction: Identifiable {
    let division: String
    let policy: ServerAPI.AdminArenaPolicyRecord
    let activate: Bool
    var id: String { "\(division):\(policy.id):\(activate)" }
  }
  @StateObject private var model = AdminArenaPolicyModel()
  @State private var area: Area = .products
  @State private var priceTarget: PriceTarget?
  @State private var editsShop = false
  @State private var createsUnranked = false
  @State private var createsRanked = false
  @State private var matchmakingReason = ""
  @State private var policyAction: PolicyAction?
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      header
      if let error = model.error {
        banner(error, Tokens.dangerInk, "exclamationmark.triangle.fill")
      }
      if let notice = model.notice { banner(notice, Tokens.successInk, "checkmark.circle.fill") }
      if model.loading && model.value == nil {
        Spacer()
        ProgressView("Arena 정책을 불러오는 중입니다")
        Spacer()
      } else if let value = model.value {
        dashboard(value)
      } else {
        ContentUnavailableView("Arena 정책을 불러오지 못했습니다", systemImage: "slider.horizontal.3")
      }
    }
    .background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge).task {
      await model.load()
    }
    .sheet(item: $priceTarget) { target in
      AdminArenaPriceSheet(target: target) { price, note in
        switch target {
        case .learning:
          return await model.perform(message: "29일 학습 패키지 가격을 30일 뒤 적용하도록 예약했습니다.") {
            try await ServerAPI.setAdminLearningPrice(price, note: note)
          }
        case .mock:
          return await model.perform(message: "주간 공식 모의고사 월 가격을 30일 뒤 적용하도록 예약했습니다.") {
            try await ServerAPI.setAdminMockPrice(price, note: note)
          }
        }
      }
    }
    .sheet(isPresented: $editsShop) {
      if let items = model.value?.shop.items {
        AdminArenaShopSheet(initial: items) { items, note in
          await model.perform(message: "Ranked 상점 가격과 판매 상태를 즉시 적용했습니다.") {
            try await ServerAPI.setAdminArenaShop(items: items, note: note)
          }
        }
      }
    }
    .sheet(isPresented: $createsUnranked) {
      AdminUnrankedPolicySheet { body in
        await model.perform(message: "새 Unranked 정책을 30일 뒤 적용하도록 예약했습니다.") {
          try await ServerAPI.createAdminUnrankedPolicy(body)
        }
      }
    }
    .sheet(isPresented: $createsRanked) {
      AdminRankedPolicySheet { body in
        await model.perform(message: "새 Ranked 정책을 30일 뒤 적용하도록 예약했습니다.") {
          try await ServerAPI.createAdminRankedPolicy(body)
        }
      }
    }
    .confirmationDialog(
      policyAction?.activate == true ? "이 정책을 적용 일정에 등록할까요?" : "이 정책을 취소·종료할까요?",
      isPresented: Binding(get: { policyAction != nil }, set: { if !$0 { policyAction = nil } }),
      titleVisibility: .visible
    ) {
      if let intent = policyAction {
        Button(intent.activate ? "적용 일정 등록" : "정책 종료", role: intent.activate ? nil : .destructive) {
          Task {
            let success = await model.perform(
              message: intent.activate ? "정책을 적용 일정에 등록했습니다." : "정책을 종료했습니다."
            ) {
              intent.activate
                ? try await ServerAPI.activateAdminArenaPolicy(
                  division: intent.division, id: intent.policy.id)
                : try await ServerAPI.retireAdminArenaPolicy(
                  division: intent.division, id: intent.policy.id)
            }
            if success { policyAction = nil }
          }
        }
        Button("취소", role: .cancel) { policyAction = nil }
      }
    }
  }
  private var header: some View {
    VStack(spacing: 8) {
      HStack {
        Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
          .buttonStyle(.plain).foregroundStyle(Tokens.primary)
        VStack(alignment: .leading, spacing: 1) {
          Text("Arena 정책·가격").font(.mHeading)
          Text("30일 사전 고지·전체 사용자 공지 포함").font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Spacer()
        if model.action { ProgressView() }
        Button {
          Task { await model.load() }
        } label: {
          Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
        }.buttonStyle(.plain)
      }
      Picker("정책 영역", selection: $area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }
        .pickerStyle(.segmented)
    }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
  }
  @ViewBuilder private func dashboard(_ value: ServerAPI.AdminArenaPolicyDashboard) -> some View {
    switch area {
    case .products: products(value)
    case .shop: shop(value.shop)
    case .unranked: division(value.unranked, division: "SUB")
    case .ranked: division(value.ranked, division: "MAIN")
    }
  }
  private func products(_ value: ServerAPI.AdminArenaPolicyDashboard) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        matchmaking(value.matchmaking)
        Text("가격 정책은 저장 시점부터 최소 30일 뒤 적용되며 전체 활성 사용자에게 공지됩니다.").font(.mCaption).foregroundStyle(
          Tokens.warningInk
        ).padding(10).background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: 10))
        productCard(
          title: "29일 학습 패키지", subtitle: "전체 학습·배치고사·모의고사·GOAT Arena",
          price: value.learningPackage.active.priceAmount ?? 0,
          detail:
            "\(value.learningPackage.active.initialLearningDays ?? 29)일 · 페이백 \(value.learningPackage.active.initialPaybackScoreDays ?? 29)점"
        ) { priceTarget = .learning(value.learningPackage.active.priceAmount ?? 0) }
        productCard(
          title: "주간 공식 모의고사 이용권", subtitle: "모의고사 전용 · 배치고사와 Arena 제한",
          price: value.mockExam.activePrice, detail: "\(value.mockExam.billingPeriodDays)일 이용"
        ) { priceTarget = .mock(value.mockExam.activePrice) }
      }.readableWidth(820).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func matchmaking(_ value: ServerAPI.AdminArenaPolicyMatchmaking) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading) {
          Text("신규 매치메이킹").font(.mTitle)
          Text(value.isPaused ? "전체 신규 경기 생성이 중지되었습니다." : "Unranked·Ranked 신규 경기 생성 가능").font(
            .mCaption
          ).foregroundStyle(Tokens.text2)
        }
        Spacer()
        badge(value.isPaused ? "일시정지" : "정상", danger: value.isPaused)
      }
      TextField("일시정지 사유", text: $matchmakingReason).textFieldStyle(.roundedBorder).disabled(
        value.isPaused)
      Button(
        value.isPaused ? "모든 신규 매치메이킹 재개" : "신규 매치메이킹 일시정지",
        role: value.isPaused ? nil : .destructive
      ) {
        Task {
          _ = await model.perform(
            message: value.isPaused ? "신규 매치메이킹을 재개했습니다." : "신규 매치메이킹을 일시정지했습니다."
          ) {
            try await ServerAPI.setAdminArenaMatchmaking(
              paused: !value.isPaused, reason: matchmakingReason)
          }
        }
      }.buttonStyle(.borderedProminent).disabled(
        !value.isPaused && matchmakingReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      )
    }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
  }
  private func productCard(
    title: String, subtitle: String, price: Int, detail: String, edit: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading) {
          Text(title).font(.mTitle)
          Text(subtitle).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Spacer()
        Text("\(price.formatted())원").font(.mHeading.monospacedDigit())
      }
      HStack {
        Text(detail).font(.mCaption)
        Spacer()
        Button("가격 변경", action: edit).buttonStyle(.borderedProminent)
      }
    }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
  }
  private func shop(_ value: ServerAPI.AdminArenaShopPolicy) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading) {
            Text("Ranked 상점").font(.mTitle)
            Text("가격·판매 상태는 저장 즉시 적용됩니다.").font(.mCaption).foregroundStyle(Tokens.text2)
          }
          Spacer()
          Button("상점 정책 편집") { editsShop = true }.buttonStyle(.borderedProminent)
        }
        ForEach(value.items) { item in
          HStack {
            VStack(alignment: .leading) {
              Text(item.name).font(.mBodyB)
              Text(item.code).font(.mMicro).foregroundStyle(Tokens.text3)
            }
            Spacer()
            Text("\(item.priceDays) 학습일").font(.mBodyB.monospacedDigit())
            badge(item.enabled ? "판매 중" : "중지", danger: !item.enabled)
          }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
        }
      }.readableWidth(820).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func division(_ value: ServerAPI.AdminArenaDivisionPolicy, division: String) -> some View
  {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          VStack(alignment: .leading) {
            Text(division == "MAIN" ? "Ranked 경기 정책" : "Unranked 학습권·페이백 정책").font(.mTitle)
            Text("최소 30일 사전 고지 후 적용").font(.mCaption).foregroundStyle(Tokens.text2)
          }
          Spacer()
          Button("새 정책 만들기") {
            if division == "MAIN" { createsRanked = true } else { createsUnranked = true }
          }.buttonStyle(.borderedProminent)
        }
        if let active = value.active { policyCard(active, division: division, current: true) }
        if let upcoming = value.upcoming {
          Text("적용 예정").font(.mBodyB)
          policyCard(upcoming, division: division, current: false)
        }
        Text("정책 이력 \(value.policies.count)개").font(.mBodyB).padding(.top, 5)
        ForEach(value.policies.filter { $0.id != value.active?.id && $0.id != value.upcoming?.id })
        { policy in policyCard(policy, division: division, current: false) }
      }.readableWidth(850).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func policyCard(
    _ value: ServerAPI.AdminArenaPolicyRecord, division: String, current: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        VStack(alignment: .leading) {
          Text(value.displayName.isEmpty ? value.code : value.displayName).font(.mBodyB)
          Text(
            "\(date(value.effectiveFrom))부터"
              + (value.effectiveUntil.map { " · \(date($0))까지" } ?? "")
          ).font(.mMicro).foregroundStyle(Tokens.text3)
        }
        Spacer()
        badge(
          current ? "적용 중" : status(value.status, from: value.effectiveFrom),
          danger: value.status == "RETIRED")
      }
      HStack {
        if let price = value.priceAmount { Text("\(price.formatted())원") }
        if let days = value.initialLearningDays { Text("\(days)일") }
        if let gap = value.maximumTargetTierGap { Text("최대 \(gap)단계") }
        if let multiple = value.revengeStakeMultiplier { Text("복수전 \(multiple)배") }
      }.font(.mCaption)
      if !value.changeSummary.isEmpty {
        Text(value.changeSummary).font(.mCaption).foregroundStyle(Tokens.text2)
      }
      if value.status == "DRAFT" {
        HStack {
          Button("적용 일정 등록") {
            policyAction = .init(division: division, policy: value, activate: true)
          }.buttonStyle(.bordered)
          Button("작성 취소", role: .destructive) {
            policyAction = .init(division: division, policy: value, activate: false)
          }.buttonStyle(.bordered)
        }
      } else if value.status == "ACTIVE" && !current {
        Button("적용 예정 취소", role: .destructive) {
          policyAction = .init(division: division, policy: value, activate: false)
        }.buttonStyle(.bordered)
      }
    }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
  }
  private func status(_ value: String, from: String?) -> String {
    value == "DRAFT"
      ? "작성 중"
      : value == "RETIRED"
        ? "종료" : ((from ?? "") > ISO8601DateFormatter().string(from: Date()) ? "적용 예정" : value)
  }
  private func date(_ value: String?) -> String {
    guard let value else { return "—" }
    return (ISO8601DateFormatter().date(from: value))?.formatted(date: .numeric, time: .shortened)
      ?? value
  }
  private func badge(_ value: String, danger: Bool) -> some View {
    Text(value).font(.mMicro.weight(.semibold)).foregroundStyle(
      danger ? Tokens.dangerInk : Tokens.successInk
    ).padding(.horizontal, 7).padding(.vertical, 3).background(
      (danger ? Tokens.dangerInk : Tokens.successInk).opacity(0.1), in: Capsule())
  }
  private func banner(_ value: String, _ color: Color, _ icon: String) -> some View {
    Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16)
      .padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(
        color.opacity(0.1))
  }
}

private struct AdminArenaPriceSheet: View {
  let target: AdminArenaPolicyScreen.PriceTarget
  let onSave: (Int, String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var price = ""
  @State private var note = ""
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Text(target.id == "learning" ? "29일 학습 패키지" : "주간 공식 모의고사 월 이용권").font(.mTitle)
        TextField("새 가격(원)", text: $price).keyboardType(.numberPad)
        TextField("변경 사유·운영 메모", text: $note, axis: .vertical).lineLimit(3...7)
        Text("저장하면 최소 30일 뒤 적용되고 전체 사용자에게 공지됩니다.").font(.mCaption).foregroundStyle(
          Tokens.warningInk)
      }.navigationTitle("가격 정책 변경").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("적용 예약") {
            saving = true
            Task {
              if await onSave(Int(price) ?? -1, note) { dismiss() }
              saving = false
            }
          }.disabled(
            Int(price) == nil || note.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }.onAppear {
        switch target {
        case .learning(let value), .mock(let value): price = String(value)
        }
      }
    }.presentationDetents([.medium])
  }
}

private struct AdminArenaShopSheet: View {
  let initial: [ServerAPI.AdminArenaShopItem]
  let onSave: ([ServerAPI.AdminArenaShopItem], String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var items: [ServerAPI.AdminArenaShopItem] = []
  @State private var note = ""
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        ForEach($items) { $item in
          Section(item.name) {
            Stepper("가격 \(item.priceDays) 학습일", value: $item.priceDays, in: 1...365)
            Toggle("현재 판매", isOn: $item.enabled)
          }
        }
        Section("전체 공지") {
          TextField("변경 사유·핵심 변경점", text: $note, axis: .vertical).lineLimit(3...7)
        }
      }.navigationTitle("Ranked 상점 정책").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("즉시 적용") {
            saving = true
            Task {
              if await onSave(items, note) { dismiss() }
              saving = false
            }
          }.disabled(
            !items.contains(where: \.enabled) || note.trimmingCharacters(in: .whitespaces).isEmpty
              || saving)
        }
      }.onAppear { items = initial }
    }.presentationDetents([.large])
  }
}

private struct DefenseLimit: Identifiable {
  let tier: String
  let label: String
  var value: Int
  var id: String { tier }
}
private struct PaybackBand: Identifiable {
  let id = UUID()
  var min: Int
  var max: Int?
  var rate: Int
}

private struct AdminUnrankedPolicySheet: View {
  let onSave: ([String: Any]) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var effective = Calendar.current.date(byAdding: .day, value: 31, to: Date())!
  @State private var price = 29_000
  @State private var score = 29
  @State private var grace = 72
  @State private var penalty = 1
  @State private var minimumScore = 30
  @State private var zeroBalance = true
  @State private var zeroLocked = true
  @State private var note = ""
  @State private var saving = false
  @State private var limits = [
    DefenseLimit(tier: "BRONZE", label: "Bronze", value: 1),
    .init(tier: "SILVER", label: "Silver", value: 1), .init(tier: "GOLD", label: "Gold", value: 2),
    .init(tier: "PLATINUM", label: "Platinum", value: 2),
    .init(tier: "EMERALD", label: "Emerald", value: 3),
    .init(tier: "DIAMOND", label: "Diamond", value: 3),
    .init(tier: "MASTER", label: "Master", value: 4),
    .init(tier: "GRANDMASTER", label: "Grandmaster", value: 4),
    .init(tier: "CHALLENGER", label: "Challenger", value: 4),
  ]
  @State private var bands = [
    PaybackBand(min: 0, max: 29, rate: 0), .init(min: 30, max: 39, rate: 25),
    .init(min: 40, max: 49, rate: 50), .init(min: 50, max: nil, rate: 100),
  ]
  var body: some View {
    NavigationStack {
      Form {
        Section("기본 정책") {
          TextField("정책 이름", text: $name)
          DatePicker("적용 시작", selection: $effective)
          Stepper("패키지 가격 \(price.formatted())원", value: $price, in: 0...1_000_000, step: 1_000)
          Stepper("페이백 점수 초깃값 \(score)", value: $score, in: 0...365)
          Stepper("재구매 유예 \(grace)시간", value: $grace, in: 0...720)
          Stepper("지연 재구매 티어 하향 \(penalty)단계", value: $penalty, in: 1...9)
          Toggle("학습일 잔액 0일 때만 구매", isOn: $zeroBalance)
          Toggle("예치 학습일 0일 때만 구매", isOn: $zeroLocked)
        }
        Section("티어별 일일 방어 상한 · 공격 3회 고정") {
          ForEach($limits) { $row in
            Stepper("\(row.label) \(row.value)회", value: $row.value, in: 0...20)
          }
        }
        Section("페이백 · 29일 중 공격 출석 15일 고정") {
          Stepper("최소 페이백 점수 \(minimumScore)", value: $minimumScore, in: 0...365)
          ForEach($bands) { $band in
            HStack {
              Text("\(band.min)~\(band.max.map(String.init) ?? "∞")점")
              Spacer()
              Stepper("\(band.rate)%", value: $band.rate, in: 0...100, step: 5).labelsHidden()
              Text("\(band.rate)%").frame(width: 42)
            }
          }
        }
        Section("공지") { TextField("변경 사유·운영 메모", text: $note, axis: .vertical).lineLimit(3...7) }
      }.navigationTitle("Unranked 정책 만들기").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("30일 후 적용 예약") { save() }.disabled(
            name.count < 2 || note.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }
    }.presentationDetents([.large])
  }
  private func save() {
    saving = true
    var body: [String: Any] = [
      "displayName": name, "effectiveFrom": Self.format(effective), "priceAmount": price,
      "initialLearningDays": 29, "initialPaybackScoreDays": score, "paymentDayCutoffKst": "00:00",
      "renewalGraceHours": grace, "lateRenewalTierPenalty": penalty,
      "minimumAttackParticipationDays": 15, "minimumScoreDays": minimumScore,
      "packagePurchaseRequiresZeroBalance": zeroBalance,
      "packagePurchaseRequiresZeroLockedBalance": zeroLocked,
      "payback": [
        "bands": bands.map {
          [
            "minScoreDays": $0.min, "maxScoreDays": $0.max.map { $0 as Any } ?? NSNull(),
            "ratePercent": $0.rate,
          ]
        }
      ],
      "dailyMatchLimitsByTier": limits.map {
        ["tier": $0.tier, "attackLimit": 3, "defenseLimit": $0.value]
      }, "changeSummary": note,
    ]
    if let nested = body["payback"] as? [String: Any] { body["payback"] = nested }
    Task {
      if await onSave(body) { dismiss() }
      saving = false
    }
  }
  static func format(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
    return formatter.string(from: value)
  }
}

private struct AdminRankedPolicySheet: View {
  let onSave: ([String: Any]) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var effective = Calendar.current.date(byAdding: .day, value: 31, to: Date())!
  @State private var bonus = 2
  @State private var carryover = 29
  @State private var maximumGap = 3
  @State private var batch = ""
  @State private var cancelFee = 1
  @State private var exclusion = 7
  @State private var revengeMultiplier = 2
  @State private var revengeFee = 1
  @State private var stakes = [1, 2, 3]
  @State private var note = ""
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Section("기본 정책") {
          TextField("정책 이름", text: $name)
          DatePicker("적용 시작", selection: $effective)
          Stepper("진입 보너스 \(bonus)일", value: $bonus, in: 0...365)
          Stepper("Unranked 이월 차감 기준 \(carryover)일", value: $carryover, in: 0...365)
          Stepper("최대 티어 차이 \(maximumGap)단계", value: $maximumGap, in: 1...3)
          TextField("초대 동시 발송 인원(비우면 전체)", text: $batch).keyboardType(.numberPad)
          Stepper("자동 취소 수수료 \(cancelFee)일", value: $cancelFee, in: 0...30)
          Stepper("최근 상대 제외 \(exclusion)일", value: $exclusion, in: 0...365)
        }
        Section("티어 차이별 최소 예치") {
          ForEach(0..<maximumGap, id: \.self) { index in
            Stepper("\(index + 1)단계 · \(stakes[index])일", value: $stakes[index], in: 1...365)
          }
        }
        Section("복수전") {
          Stepper("예치 배수 \(revengeMultiplier)배", value: $revengeMultiplier, in: 1...20)
          Stepper("기본 수수료 \(revengeFee)일", value: $revengeFee, in: 0...30)
        }
        Section("공지") { TextField("변경 사유·운영 메모", text: $note, axis: .vertical).lineLimit(3...7) }
      }.navigationTitle("Ranked 정책 만들기").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("30일 후 적용 예약") { save() }.disabled(
            name.count < 2 || note.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }
    }.presentationDetents([.large])
  }
  private func save() {
    saving = true
    var body: [String: Any] = [
      "displayName": name, "effectiveFrom": AdminUnrankedPolicySheet.format(effective),
      "mainEntryBonusDays": bonus, "mainCarryoverBaseDays": carryover,
      "maximumTargetTierGap": maximumGap, "mainTierGaps": Array(1...maximumGap),
      "mainMinimumStakeDays": Array(stakes.prefix(maximumGap)),
      "invitationCancellationFeeDays": cancelFee, "repeatOpponentExclusionDays": exclusion,
      "maximumActiveInvitationReservationsPerTargetTier": 1,
      "revengeStakeMultiplier": revengeMultiplier, "revengeFeeDays": revengeFee,
      "changeSummary": note,
    ]
    if let value = Int(batch), value > 0 { body["invitationOfferBatchSize"] = value }
    Task {
      if await onSave(body) { dismiss() }
      saving = false
    }
  }
}
