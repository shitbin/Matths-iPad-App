import SwiftUI

@MainActor private final class AdminOperationsGuideModel: ObservableObject {
  @Published var value: ServerAPI.AdminOperationsGuide?
  @Published var loading = false
  @Published var error: String?
  func load() async {
    loading = value == nil
    error = nil
    do { value = try await ServerAPI.adminOperationsGuide() } catch is CancellationError {} catch {
      self.error = (error as? ServerAPIError)?.errorDescription ?? error.localizedDescription
    }
    loading = false
  }
}

struct AdminOperationsGuideScreen: View {
  private enum Area: String, CaseIterable, Identifiable {
    case daily = "매일 확인"
    case workflow = "표준 절차"
    case storage = "저장·보존"
    case automation = "자동·장애"
    case schema = "DB 스키마"
    var id: String { rawValue }
  }
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @StateObject private var model = AdminOperationsGuideModel()
  @State private var area: Area = .daily
  @State private var selectedCategory: String?
  @State private var selectedModel: String?
  let onClose: () -> Void
  private var landscape: Bool {
    verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
  }
  var body: some View {
    VStack(spacing: 0) {
      header
      if let error = model.error {
        Label(error, systemImage: "exclamationmark.triangle.fill").font(.mCaption).foregroundStyle(
          Tokens.dangerInk
        ).padding(8)
      }
      if model.loading && model.value == nil {
        Spacer()
        ProgressView("현재 코드에서 운영 매뉴얼을 생성하는 중입니다")
        Spacer()
      } else if let value = model.value {
        content(value)
      } else {
        ContentUnavailableView("운영 매뉴얼을 불러오지 못했습니다", systemImage: "book.closed")
      }
    }.background(Tokens.paper).dynamicTypeSize(...DynamicTypeSize.xxxLarge).task {
      await model.load()
    }
  }
  private var header: some View {
    VStack(spacing: 8) {
      HStack {
        Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
          .buttonStyle(.plain).foregroundStyle(Tokens.primary)
        VStack(alignment: .leading, spacing: 1) {
          Text("관리자 운영 매뉴얼").font(.mHeading)
          Text("권한·저장·삭제·자동 작업·장애·DB 스키마").font(.mCaption).foregroundStyle(Tokens.text2)
        }
        Spacer()
        Button {
          Task { await model.load() }
        } label: {
          Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
        }.buttonStyle(.plain)
      }
      Picker("매뉴얼 영역", selection: $area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }
        .pickerStyle(.segmented)
    }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
  }
  @ViewBuilder private func content(_ value: ServerAPI.AdminOperationsGuide) -> some View {
    switch area {
    case .daily: daily(value)
    case .workflow: workflows(value.operatingWorkflows)
    case .storage: storage(value)
    case .automation: automation(value)
    case .schema: schema(value)
    }
  }
  private func daily(_ value: ServerAPI.AdminOperationsGuide) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          metric("\(value.database.modelCount)", "DB 모델")
          metric("\(value.database.fieldCount)", "스키마 필드")
          metric("\(value.database.categoryCount)", "업무 분류")
          metric(value.database.connectionState, "DB 연결")
        }
        HStack {
          stateCard("사용자 파일", "Cloudinary", value.environment.cloudinaryConfigured)
          stateCard("운영자 원본", "Cloudflare R2", value.environment.r2BackupConfigured)
          stateCard("비공개 전달", "5분 서명 URL", value.environment.r2BackupConfigured)
          stateCard(
            "로컬 디스크", capacity(value.environment.localCapacity),
            value.environment.localCapacity?.level != "BLOCKED")
        }
        Text("권장 점검 순서").font(.mTitle)
        checklist([
          "관리 알림에서 신고·신원 중복·증거 이상·미처리 문의 확인", "경기·정산 감사에서 원장 불일치와 재시도 작업 확인",
          "주간 모의고사 문제지·채점 JSON·공개 시간 대조", "R2·Cloudinary·로컬 디스크 용량과 삭제 대기 확인",
          "월별 운영 지표의 표본·전환·페이백 확인",
        ])
        Text("계정과 상품 권한").font(.mTitle)
        ForEach(Array(value.permissionMatrix.enumerated()), id: \.offset) { _, row in rowCard(row) }
        Text("비밀값 표시 원칙").font(.mBodyB)
        Text(
          "환경 변수 이름과 연결 여부만 확인합니다. DB 비밀번호, API Secret, 세션 secret, SMTP 비밀번호는 화면·로그·Git·고객지원 메모에 남기지 않습니다."
        ).font(.mCaption).foregroundStyle(Tokens.dangerInk).padding(10).background(
          Tokens.dangerInk.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      }.readableWidth(900).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func workflows(_ values: [ServerAPI.AdminGuideWorkflow]) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 10) {
        ForEach(values) { item in
          DisclosureGroup {
            Text(item.objective).font(.mCaption)
            checklist(item.steps)
            Text("중단 조건").font(.mBodyB).foregroundStyle(Tokens.dangerInk)
            Text(item.hardStops).font(.mCaption)
            Text("확인 기록 · \(item.audit)").font(.mMicro).foregroundStyle(Tokens.text3)
          } label: {
            VStack(alignment: .leading) {
              Text(item.title).font(.mBodyB)
              Text(item.cadence).font(.mMicro).foregroundStyle(Tokens.text3)
            }
          }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
        }
      }.readableWidth(900).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func storage(_ value: ServerAPI.AdminOperationsGuide) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text("파일 원본은 MongoDB에 넣지 않고 공급자·목적·MIME·크기·SHA-256·보존 기한·객체 키만 기록합니다.").font(.mCaption)
          .foregroundStyle(Tokens.warningInk).padding(10).background(
            Tokens.warningSoft, in: RoundedRectangle(cornerRadius: 10))
        ForEach(value.storageMatrix) { item in
          DisclosureGroup {
            row("목적", item.purpose)
            row("권위 원본", item.primary)
            row("백업", item.backup)
            row("보존", item.retention)
            row("열람", item.access)
          } label: {
            Text("\(item.owner) · \(item.fileType)").font(.mBodyB)
          }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
        }
        Text("보존·삭제 정책").font(.mTitle)
        ForEach(Array(value.retentionPolicies.enumerated()), id: \.offset) { _, item in
          rowCard(item)
        }
        Text("운영 환경 변수 지도").font(.mTitle)
        ForEach(Array(value.environmentConfiguration.enumerated()), id: \.offset) { _, item in
          rowCard(item)
        }
      }.readableWidth(900).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func automation(_ value: ServerAPI.AdminOperationsGuide) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text("서버 자동 작업").font(.mTitle)
        ForEach(Array(value.schedulers.enumerated()), id: \.offset) { _, item in rowCard(item) }
        Text("장애 대응 순서").font(.mTitle).padding(.top, 6)
        ForEach(value.incidentPlaybook) { item in
          DisclosureGroup {
            checklist(item.checks)
          } label: {
            Text(item.title).font(.mBodyB)
          }.padding(12).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
        }
        Text("자동 작업은 MongoDB 임대와 멱등 키를 사용합니다. 실패 작업을 DB 원본 수정으로 덮어쓰지 않습니다.").font(.mCaption)
          .foregroundStyle(Tokens.dangerInk).padding(10).background(
            Tokens.dangerInk.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      }.readableWidth(900).adaptiveHPadding().adaptiveVPadding()
    }
  }
  private func schema(_ value: ServerAPI.AdminOperationsGuide) -> some View {
    let category =
      value.schemaCategories.first(where: { $0.id == selectedCategory })
      ?? value.schemaCategories.first
    let model = category?.models.first(where: { $0.id == selectedModel }) ?? category?.models.first
    return Group {
      if landscape {
        HStack(spacing: 0) {
          schemaList(value.schemaCategories, selected: category, model: model).frame(width: 330)
          Divider()
          modelDetail(model).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        VStack(spacing: 0) {
          schemaList(value.schemaCategories, selected: category, model: model).frame(maxHeight: 260)
          Divider()
          modelDetail(model)
        }
      }
    }
  }
  private func schemaList(
    _ categories: [ServerAPI.AdminGuideSchemaCategory],
    selected: ServerAPI.AdminGuideSchemaCategory?, model: ServerAPI.AdminGuideModel?
  ) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 7) {
        ForEach(categories) { category in
          DisclosureGroup(
            isExpanded: Binding(
              get: { selected?.id == category.id },
              set: {
                if $0 {
                  selectedCategory = category.id
                  selectedModel = category.models.first?.id
                }
              })
          ) {
            ForEach(category.models) { item in
              Button {
                selectedCategory = category.id
                selectedModel = item.id
              } label: {
                HStack {
                  Text(item.modelName).font(.mCaption)
                  Spacer()
                  Text("\(item.fieldCount)").font(.mMicro).foregroundStyle(Tokens.text3)
                }.padding(8).background(
                  model?.id == item.id ? Tokens.primary.opacity(0.1) : Color.clear,
                  in: RoundedRectangle(cornerRadius: 8))
              }.buttonStyle(.plain)
            }
          } label: {
            Text("\(category.label) · \(category.models.count)").font(.mBodyB)
          }.padding(10).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
        }
      }.padding(12)
    }
  }
  @ViewBuilder private func modelDetail(_ value: ServerAPI.AdminGuideModel?) -> some View {
    if let value {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          Text(value.modelName).font(.mTitle)
          Text(
            "컬렉션 · \(value.collectionName) · \(value.timestamps ? "createdAt/updatedAt" : "타임스탬프 없음")"
          ).font(.mCaption).foregroundStyle(Tokens.text2)
          Text("필드 정의").font(.mBodyB)
          ForEach(value.fields) { field in
            VStack(alignment: .leading, spacing: 3) {
              HStack {
                Text(field.field).font(.system(.caption, design: .monospaced))
                Spacer()
                Text(field.type).font(.mMicro)
              }
              Text(field.rules).font(.mMicro).foregroundStyle(Tokens.text2)
              Text("기본값 · \(field.defaultValue)").font(.mMicro).foregroundStyle(Tokens.text3)
            }.padding(9).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 9))
          }
          if !value.indexes.isEmpty {
            Text("인덱스·TTL").font(.mBodyB)
            ForEach(value.indexes) { index in
              rowCard([index.keys, index.unique ? "고유" : "일반", "TTL \(index.ttl)", index.partial])
            }
          }
        }.padding(14)
      }
    } else {
      ContentUnavailableView("모델을 선택하세요", systemImage: "cylinder.split.1x2")
    }
  }
  private func stateCard(_ title: String, _ value: String, _ good: Bool) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title).font(.mMicro).foregroundStyle(Tokens.text3)
      Text(value).font(.mBodyB)
      Image(systemName: good ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .foregroundStyle(good ? Tokens.successInk : Tokens.warningInk)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(
      Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
  }
  private func metric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading) {
      Text(value).font(.mBodyB.monospacedDigit())
      Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private func checklist(_ values: [String]) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        HStack(alignment: .top) {
          Text("\(index + 1)").font(.mMicro).foregroundStyle(Tokens.primary).frame(width: 18)
          Text(value).font(.mCaption)
        }
      }
    }
  }
  private func rowCard(_ values: [String]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        Text(value).font(index == 0 ? .mBodyB : .mCaption).foregroundStyle(
          index < 2 ? Tokens.ink : Tokens.text2)
      }
    }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(
      Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
  }
  private func row(_ key: String, _ value: String) -> some View {
    HStack(alignment: .top) {
      Text(key).foregroundStyle(Tokens.text3).frame(width: 80, alignment: .leading)
      Text(value)
    }.font(.mCaption)
  }
  private func capacity(_ value: ServerAPI.AdminGuideCapacity?) -> String {
    guard let value, let percent = value.usedPercent else { return "확인 필요" }
    return "\(percent.formatted())% 사용"
  }
}
