import SwiftUI

@MainActor
private final class AdminProblemBankModel: ObservableObject {
  @Published var value: ServerAPI.AdminProblemBankDashboard?
  @Published var loading = false
  @Published var action = false
  @Published var error: String?
  @Published var notice: String?
  func load(
    category: String? = nil, query: String? = nil, inspect: String? = nil, edit: String? = nil
  ) async {
    loading = value == nil
    error = nil
    do {
      value = try await ServerAPI.adminProblemBanks(
        category: category, query: query, inspect: inspect, edit: edit)
    } catch is CancellationError {} catch { self.error = readable(error) }
    loading = false
  }
  func perform(_ message: String, operation: () async throws -> Void) async -> Bool {
    guard !action else { return false }
    action = true
    error = nil
    notice = nil
    do {
      try await operation()
      notice = message
      action = false
      await load()
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

struct AdminProblemBankScreen: View {
  private enum Area: String, CaseIterable, Identifiable {
    case types = "유형 카탈로그"
    case data = "Arena 문제 데이터"
    case tiers = "T1~T9 카탈로그"
    var id: String { rawValue }
  }
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @StateObject private var model = AdminProblemBankModel()
  @State private var area: Area = .types
  @State private var selectedType: ServerAPI.AdminProblemTypeRecord?
  @State private var revisesType: ServerAPI.AdminProblemTypeRecord?
  @State private var editsData = false
  @State private var createsTierType = false
  @State private var activatesVersion: ServerAPI.AdminProblemVersion?
  @State private var query = ""
  let onClose: () -> Void
  private var landscape: Bool {
    verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
  }
  var body: some View {
    VStack(spacing: 0) {
      header
      if let error = model.error {
        banner(error, Tokens.dangerInk, "exclamationmark.triangle.fill")
      }
      if let notice = model.notice { banner(notice, Tokens.successInk, "checkmark.circle.fill") }
      if model.loading && model.value == nil {
        Spacer()
        ProgressView("문제 데이터 원장을 불러오는 중입니다")
        Spacer()
      } else if let value = model.value {
        switch area {
        case .types: types(value.types)
        case .data: data(value.problem)
        case .tiers: tiers(value.tiers)
        }
      } else {
        ContentUnavailableView("문제 데이터를 불러오지 못했습니다", systemImage: "square.stack.3d.up.slash")
      }
    }.background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge).task {
      await model.load()
    }
    .sheet(item: $revisesType) { value in
      AdminProblemTypeRevisionSheet(value: value) { enabled, weight, note in
        await model.perform("5회 검산 후 새 문제 유형 리비전을 적용했습니다.") {
          try await ServerAPI.reviseAdminProblemType(
            id: value.id, enabled: enabled, weight: weight, note: note)
        }
      }
    }
    .sheet(isPresented: $editsData) {
      if let value = model.value?.problem {
        AdminProblemDataEditor(value: value) { id, body in
          if let id, !id.isEmpty {
            return await model.perform("문제 데이터 초안 변경을 저장하고 1차 검산했습니다.") {
              try await ServerAPI.updateAdminProblemData(id: id, body: body)
            }
          } else {
            return await model.perform("새 문제 데이터 초안을 저장하고 1차 검산했습니다.") {
              _ = try await ServerAPI.createAdminProblemData(body)
            }
          }
        }
      }
    }
    .sheet(isPresented: $createsTierType) {
      if let value = model.value?.tiers {
        AdminTierTypeCreateSheet(value: value) { name, base, tiers, note in
          await model.perform("승인 생성기 검산 후 새 T 난이도 유형을 적용했습니다.") {
            try await ServerAPI.createAdminTierProblemType(
              name: name, baseTypeID: base, tiers: tiers, note: note)
          }
        }
      }
    }
    .confirmationDialog(
      "5회 자동 검산을 통과하면 이 버전을 신규 경기부터 적용합니다.",
      isPresented: Binding(
        get: { activatesVersion != nil }, set: { if !$0 { activatesVersion = nil } }),
      titleVisibility: .visible
    ) {
      if let value = activatesVersion {
        Button("검산 후 적용") {
          Task {
            let succeeded = await model.perform("문제 데이터 검산을 통과해 새 버전을 적용했습니다.") {
              try await ServerAPI.activateAdminProblemData(id: value.id)
            }
            if succeeded { activatesVersion = nil }
          }
        }
        Button("취소", role: .cancel) { activatesVersion = nil }
      }
    }
  }
  private var header: some View {
    VStack(spacing: 8) {
      HStack {
        Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
          .buttonStyle(.plain).foregroundStyle(Tokens.primary)
        VStack(alignment: .leading, spacing: 1) {
          Text("문제 유형·Arena 데이터").font(.mHeading)
          Text("코드 실행이 아닌 검산된 구성 버전 관리").font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Spacer()
        if model.action { ProgressView() }
        Button {
          Task { await model.load() }
        } label: {
          Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
        }.buttonStyle(.plain)
      }
      Picker("관리 영역", selection: $area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }
        .pickerStyle(.segmented)
    }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
  }
  private func types(_ value: ServerAPI.AdminProblemTypes) -> some View {
    let selected = selectedType ?? value.inspected ?? value.entries.first
    return VStack(spacing: 0) {
      HStack(spacing: 8) {
        Picker(
          "분류",
          selection: Binding(
            get: { value.selectedCategory },
            set: { category in Task { await model.load(category: category, query: query) } })
        ) { ForEach(value.categories) { Text("\($0.label) \($0.count)").tag($0.key) } }
        .labelsHidden()
        TextField("유형 이름·코드 찾기", text: $query).textFieldStyle(.roundedBorder).onSubmit {
          Task { await model.load(category: value.selectedCategory, query: query) }
        }
        Button("검색") { Task { await model.load(category: value.selectedCategory, query: query) } }
          .buttonStyle(.bordered)
        Button("서버 생성기 검산·동기화") {
          Task {
            _ = await model.perform("서버 생성기를 검산해 DB 리비전에 동기화했습니다.") {
              try await ServerAPI.syncAdminProblemTypes()
            }
          }
        }.buttonStyle(.borderedProminent)
      }.padding(10)
      Divider()
      Group {
        if landscape {
          HStack(spacing: 0) {
            typeList(value.entries, selected: selected).frame(width: 350)
            Divider()
            typeDetail(selected).frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        } else {
          VStack(spacing: 0) {
            typeList(value.entries, selected: selected).frame(maxHeight: 260)
            Divider()
            typeDetail(selected)
          }
        }
      }
    }
  }
  private func typeList(
    _ entries: [ServerAPI.AdminProblemTypeRecord], selected: ServerAPI.AdminProblemTypeRecord?
  ) -> some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(entries) { item in
          Button {
            selectedType = item
          } label: {
            VStack(alignment: .leading, spacing: 3) {
              HStack {
                Text(item.displayName).font(.mBodyB)
                Spacer()
                badge(item.enabled ? "사용" : "제외", danger: !item.enabled)
              }
              Text("\(item.engineKey) · r\(item.revision)").font(.mMicro).foregroundStyle(
                Tokens.text3)
              if item.codeChanged {
                Label("서버 소스 변경 감지", systemImage: "exclamationmark.triangle.fill").font(.mMicro)
                  .foregroundStyle(Tokens.warningInk)
              }
            }.padding(10).background(
              selected?.id == item.id ? Tokens.primary.opacity(0.1) : Tokens.surface,
              in: RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain)
        }
      }.padding(12)
    }
  }
  @ViewBuilder private func typeDetail(_ value: ServerAPI.AdminProblemTypeRecord?) -> some View {
    if let value {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            VStack(alignment: .leading) {
              Text(value.displayName).font(.mTitle)
              Text(value.engineKey).font(.mCaption).textSelection(.enabled)
            }
            Spacer()
            Button("설정 새 리비전") { revisesType = value }.buttonStyle(.borderedProminent)
          }
          HStack {
            metric("r\(value.revision)", "리비전")
            metric("\(value.selectionWeight)", "출제 가중치")
            metric("\(value.validation.sampleCount)", "검산 표본")
            metric(value.validation.passed ? "통과" : "차단", "검산")
          }
          Text(
            [value.courseId, value.unitId, value.conceptId].filter { !$0.isEmpty }.joined(
              separator: " · ")
          ).font(.mCaption)
          if !value.operatorNote.isEmpty {
            Text(value.operatorNote).font(.mCaption).foregroundStyle(Tokens.text2)
          }
          if value.codeChanged {
            Text("서버 코드가 DB 스냅샷 이후 변경되었습니다. 동기화 전까지 이전 검산 리비전이 유지됩니다.").font(.mCaption)
              .foregroundStyle(Tokens.warningInk).padding(9).background(
                Tokens.warningSoft, in: RoundedRectangle(cornerRadius: 9))
          }
          if !value.sourceSnapshot.isEmpty {
            Text("DB 보존 소스 · 실행하지 않는 감사 스냅샷").font(.mBodyB)
            ScrollView(.horizontal) {
              Text(value.sourceSnapshot).font(.system(.caption, design: .monospaced)).textSelection(
                .enabled
              ).padding(10)
            }.background(Tokens.paper2, in: RoundedRectangle(cornerRadius: 9))
          }
        }.padding(14)
      }
    } else {
      ContentUnavailableView("문제 유형을 선택하세요", systemImage: "function")
    }
  }
  private func data(_ value: ServerAPI.AdminProblemData) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          VStack(alignment: .leading) {
            Text("현재 적용 중인 Arena 문제 데이터").font(.mTitle)
            Text("서버 재시작 없이 최대 15초 안에 신규 경기로 반영").font(.mCaption).foregroundStyle(Tokens.text2)
          }
          Spacer()
          Button("새 초안 만들기") { editsData = true }.buttonStyle(.borderedProminent)
        }
        versionCard(value.active, active: true)
        Text("초안 및 버전 이력").font(.mBodyB).padding(.top, 4)
        ForEach(value.recent.filter { $0.id != value.active.id }) { version in
          VStack(alignment: .leading, spacing: 7) {
            versionCard(version, active: false)
            if version.status == "DRAFT" {
              HStack {
                Button("초안 수정") {
                  Task {
                    await model.load(edit: version.id)
                    editsData = true
                  }
                }.buttonStyle(.bordered)
                Button("검산 후 적용") { activatesVersion = version }.buttonStyle(.borderedProminent)
              }
            }
          }
        }
        Text("관리 화면은 JavaScript 코드를 저장·실행하지 않습니다. 검산된 유형 선택, 가중치와 정답 범위만 버전 데이터로 저장합니다.").font(
          .mCaption
        ).foregroundStyle(Tokens.warningInk).padding(10).background(
          Tokens.warningSoft, in: RoundedRectangle(cornerRadius: 10))
      }.readableWidth(880).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func versionCard(_ value: ServerAPI.AdminProblemVersion, active: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        VStack(alignment: .leading) {
          Text(value.displayName).font(.mBodyB)
          Text(value.code).font(.mMicro).foregroundStyle(Tokens.text3)
        }
        Spacer()
        badge(
          active ? "적용 중" : (value.status == "DRAFT" ? "초안" : "종료"),
          danger: !active && value.status != "DRAFT")
      }
      HStack {
        Text("검산 \(value.validation.passed ? "통과" : "확인 필요")")
        Text("표본 \(value.validation.sampleCount)회")
        Text(value.engineVersion)
      }.font(.mCaption)
      if !value.changeSummary.isEmpty {
        Text(value.changeSummary).font(.mCaption).foregroundStyle(Tokens.text2)
      }
      if !value.validation.failures.isEmpty {
        Text(value.validation.failures.joined(separator: "\n")).font(.mCaption).foregroundStyle(
          Tokens.dangerInk)
      }
    }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
  }
  private func tiers(_ value: ServerAPI.AdminTierCatalog) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          VStack(alignment: .leading) {
            Text("T1~T9 문제 카탈로그").font(.mTitle)
            Text("승인 생성기를 복제해 새 유형을 안전하게 추가").font(.mCaption).foregroundStyle(Tokens.text2)
          }
          Spacer()
          Button("새 유형 추가") { createsTierType = true }.buttonStyle(.borderedProminent).disabled(
            value.baseTypes.isEmpty)
        }
        if let active = value.active { versionCard(active, active: true) }
        ForEach(value.publicDifficultyCatalog) { tier in
          HStack {
            VStack(alignment: .leading) {
              Text("\(tier.difficultyCode) · \(tier.catalogTier)").font(.mBodyB)
              Text(tier.packComposition).font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Spacer()
            VStack(alignment: .trailing) {
              Text("\(tier.variantCount)개 변형").font(.mBodyB)
              Text("최소 \(tier.minimumTypeVariants)개").font(.mMicro).foregroundStyle(Tokens.text3)
            }
          }.padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
        }
      }.readableWidth(850).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func metric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading) {
      Text(value).font(.mBodyB.monospacedDigit())
      Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
    }.frame(maxWidth: .infinity, alignment: .leading)
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

private struct AdminProblemTypeRevisionSheet: View {
  let value: ServerAPI.AdminProblemTypeRecord
  let onSave: (Bool, Int, String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var enabled = true
  @State private var weight = 1
  @State private var note = ""
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Text(value.displayName).font(.mTitle)
        Toggle("신규 출제에 사용", isOn: $enabled)
        Stepper("출제 가중치 \(weight)", value: $weight, in: 1...100)
        TextField("변경 사유와 관찰 결과", text: $note, axis: .vertical).lineLimit(4...9)
        Text("현재 서버 생성기를 5회 자동 검산한 뒤 이전 리비전을 보존하고 새 리비전을 적용합니다.").font(.mCaption).foregroundStyle(
          Tokens.warningInk)
      }.navigationTitle("문제 유형 설정").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("검산 후 적용") {
            saving = true
            Task {
              if await onSave(enabled, weight, note) { dismiss() }
              saving = false
            }
          }.disabled(note.trimmingCharacters(in: .whitespaces).isEmpty || saving)
        }
      }.onAppear {
        enabled = value.enabled
        weight = value.selectionWeight
        note = value.operatorNote
      }
    }.presentationDetents([.medium, .large])
  }
}

private struct AdminProblemDataEditor: View {
  let value: ServerAPI.AdminProblemData
  let onSave: (String?, [String: Any]) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var code = ""
  @State private var name = ""
  @State private var note = ""
  @State private var settings: [ServerAPI.AdminArenaTypeSetting] = []
  @State private var tiers: [ServerAPI.AdminArenaTierConfiguration] = []
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Section("버전") {
          TextField("버전 코드", text: $code).textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
          TextField("버전 이름", text: $name)
          TextField("변경 사유", text: $note, axis: .vertical).lineLimit(3...7)
        }
        Section("유형별 출제 데이터") {
          ForEach($settings) { $item in
            DisclosureGroup {
              Toggle("사용", isOn: $item.enabled)
              Stepper("배정 가중치 \(item.selectionWeight)", value: $item.selectionWeight, in: 1...10)
              Stepper("정답 최솟값 \(item.answerMin)", value: $item.answerMin, in: 1...999)
              Stepper("정답 최댓값 \(item.answerMax)", value: $item.answerMax, in: 1...999)
              TextField("운영 메모", text: $item.difficultyNote)
            } label: {
              Text(label(item.typeId) + (item.enabled ? "" : " · 제외"))
            }
          }
        }
        Section("난이도별 유형 · 최소 5개") {
          ForEach($tiers) { $tier in
            DisclosureGroup {
              ForEach(value.availableTypes) { type in
                Toggle(
                  type.label,
                  isOn: Binding(
                    get: { tier.typeIds.contains(type.id) },
                    set: { selected in
                      if selected {
                        if !tier.typeIds.contains(type.id) { tier.typeIds.append(type.id) }
                      } else {
                        tier.typeIds.removeAll { $0 == type.id }
                      }
                    }))
              }
            } label: {
              Text("\(tier.difficultyTier) · \(tier.typeIds.count)개")
            }
          }
        }
      }.navigationTitle(value.editableId.isEmpty ? "새 문제 데이터 초안" : "문제 데이터 초안 수정").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("저장·1차 검산") { save() }.disabled(
            code.isEmpty || name.isEmpty || note.isEmpty
              || tiers.contains(where: { $0.typeIds.count < 5 }) || saving)
        }
      }.onAppear {
        code = value.form.code
        name = value.form.displayName
        note = value.form.changeSummary
        settings = value.form.typeSettings
        tiers = value.form.tierConfigurations
      }
    }.presentationDetents([.large])
  }
  private func label(_ id: String) -> String {
    value.availableTypes.first(where: { $0.id == id })?.label ?? id
  }
  private func save() {
    saving = true
    let body: [String: Any] = [
      "code": code, "displayName": name, "changeSummary": note,
      "typeSettings": settings.map {
        [
          "typeId": $0.typeId, "enabled": $0.enabled, "selectionWeight": $0.selectionWeight,
          "answerMin": $0.answerMin, "answerMax": $0.answerMax, "difficultyNote": $0.difficultyNote,
        ]
      },
      "tierConfigurations": tiers.map {
        ["difficultyTier": $0.difficultyTier, "typeIds": $0.typeIds]
      },
    ]
    Task {
      if await onSave(value.editableId.isEmpty ? nil : value.editableId, body) { dismiss() }
      saving = false
    }
  }
}

private struct AdminTierTypeCreateSheet: View {
  let value: ServerAPI.AdminTierCatalog
  let onSave: (String, String, [String], String) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var base = ""
  @State private var selected: Set<String> = []
  @State private var note = ""
  @State private var saving = false
  private let tiers = (1...9).map { "T\($0)" }
  var body: some View {
    NavigationStack {
      Form {
        TextField("새 문제 유형 이름", text: $name)
        Picker("연결할 승인 생성기", selection: $base) {
          ForEach(value.baseTypes) { Text($0.label).tag($0.id) }
        }
        Section("배정할 T 난이도") {
          ForEach(tiers, id: \.self) { tier in
            Toggle(
              tier,
              isOn: Binding(
                get: { selected.contains(tier) },
                set: { if $0 { selected.insert(tier) } else { selected.remove(tier) } }))
          }
        }
        TextField("운영 메모", text: $note, axis: .vertical).lineLimit(3...7)
        Text("기존 승인 생성기의 소스 해시와 독립 검산을 확인한 후 새 카탈로그 버전을 즉시 적용합니다.").font(.mCaption).foregroundStyle(
          Tokens.warningInk)
      }.navigationTitle("T 난이도 새 유형").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("검산 후 추가") {
            saving = true
            Task {
              if await onSave(name, base, Array(selected).sorted(), note) { dismiss() }
              saving = false
            }
          }.disabled(name.count < 2 || base.isEmpty || selected.isEmpty || note.isEmpty || saving)
        }
      }.onAppear { base = value.baseTypes.first?.id ?? "" }
    }.presentationDetents([.large])
  }
}
