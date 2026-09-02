import SwiftUI

@MainActor
private final class AdminDataAnalysisModel: ObservableObject {
  @Published var value: ServerAPI.AdminDataAnalysis?
  @Published var loading = false
  @Published var rebuilding = false
  @Published var error: String?
  @Published var notice: String?

  func load(period: String? = nil) async {
    loading = value == nil
    error = nil
    do { value = try await ServerAPI.adminDataAnalysis(period: period) } catch is CancellationError
    {} catch { self.error = readable(error) }
    loading = false
  }
  func rebuild() async {
    guard let period = value?.period.periodKey, !rebuilding else { return }
    rebuilding = true
    error = nil
    notice = nil
    do {
      try await ServerAPI.rebuildAdminDataAnalysis(period: period)
      notice = "\(period) 권위 원장을 다시 집계했습니다."
      value = try await ServerAPI.adminDataAnalysis(period: period)
    } catch { self.error = readable(error) }
    rebuilding = false
  }
  private func readable(_ error: Error) -> String {
    (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription
  }
}

struct AdminDataAnalysisScreen: View {
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @StateObject private var model = AdminDataAnalysisModel()
  @State private var selectedCategory: String?
  @State private var confirmsRebuild = false
  let onClose: () -> Void
  private var landscape: Bool {
    verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      if let error = model.error {
        banner(error, color: Tokens.dangerInk, icon: "exclamationmark.triangle.fill")
      }
      if let notice = model.notice {
        banner(notice, color: Tokens.successInk, icon: "checkmark.circle.fill")
      }
      if model.loading && model.value == nil {
        Spacer()
        ProgressView("운영 지표를 불러오는 중입니다")
        Spacer()
      } else if let value = model.value {
        content(value)
      } else {
        ContentUnavailableView("운영 지표를 불러오지 못했습니다", systemImage: "chart.bar.xaxis")
      }
    }
    .background(Tokens.paper)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    .task { await model.load() }
    .confirmationDialog(
      "선택한 월의 전체 권위 원장을 다시 집계할까요?", isPresented: $confirmsRebuild, titleVisibility: .visible
    ) {
      Button("다시 집계") { Task { await model.rebuild() } }
      Button("취소", role: .cancel) {}
    } message: {
      Text("집계 중 조회 부하가 발생할 수 있지만 원본 결제·경기·페이백 데이터는 변경하지 않습니다.")
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Button(action: onClose) { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
        .buttonStyle(.plain).foregroundStyle(Tokens.primary).accessibilityLabel("관리자 홈")
      VStack(alignment: .leading, spacing: 1) {
        Text("운영 지표").font(.mHeading)
        Text("결제·학습권·경기·페이백 월별 관측").font(.mCaption).foregroundStyle(Tokens.text2)
      }
      Spacer()
      if let value = model.value {
        Picker(
          "조회 월",
          selection: Binding(
            get: { value.period.periodKey },
            set: { period in Task { await model.load(period: period) } })
        ) {
          ForEach(value.periodOptions) { Text($0.label).tag($0.key) }
        }.labelsHidden().frame(maxWidth: 150)
      }
      Button {
        confirmsRebuild = true
      } label: {
        if model.rebuilding {
          ProgressView().frame(width: 44, height: 44)
        } else {
          Image(systemName: "arrow.triangle.2.circlepath").frame(width: 44, height: 44)
        }
      }.buttonStyle(.plain).disabled(model.rebuilding || model.value == nil).accessibilityLabel(
        "원장에서 다시 집계")
    }.padding(.horizontal, 14).padding(.vertical, 8).background(Tokens.surface)
  }

  @ViewBuilder private func content(_ value: ServerAPI.AdminDataAnalysis) -> some View {
    let selected =
      value.categories.first(where: { $0.key == selectedCategory }) ?? value.categories.first
    VStack(spacing: 0) {
      summary(value)
      Divider()
      if landscape {
        HStack(spacing: 0) {
          categoryList(value, selected: selected).frame(width: 340)
          Divider()
          metricDetail(selected).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        VStack(spacing: 0) {
          categoryList(value, selected: selected).frame(maxHeight: 230)
          Divider()
          metricDetail(selected).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
  }

  private func summary(_ value: ServerAPI.AdminDataAnalysis) -> some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(value.period.label).font(.mBodyB)
        Text(value.periodClosed ? "집계 종료 월" : "수집 중인 월").font(.mMicro).foregroundStyle(
          value.periodClosed ? Tokens.text2 : Tokens.successInk)
      }.frame(maxWidth: .infinity, alignment: .leading)
      metric("\(value.summary.catalogMetricCount)", "전체")
      metric("\(value.summary.observedMetricCount)", "연결")
      metric("\(value.summary.waitingMetricCount)", "미실행")
      metric("\(value.summary.reliableMetricCount)", "판단 가능")
    }.padding(.horizontal, 14).padding(.vertical, 9).background(Tokens.paper)
  }

  private func categoryList(
    _ value: ServerAPI.AdminDataAnalysis, selected: ServerAPI.AdminAnalysisCategory?
  ) -> some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        if !value.assumptions.isEmpty {
          Text("출시 전 가정 비교").font(.mCaption).foregroundStyle(Tokens.text2)
          ForEach(value.assumptions) { item in
            HStack {
              VStack(alignment: .leading) {
                Text(item.label).font(.mBodyB)
                Text("\(item.assumptionLabel) → \(item.actualLabel)").font(.mMicro)
              }
              Spacer()
              badge(item.ready ? "판단 가능" : "수집 중", good: item.ready)
            }.padding(9).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
          }
        }
        Text("지표 분류").font(.mCaption).foregroundStyle(Tokens.text2).padding(.top, 5)
        ForEach(value.categories) { category in
          Button {
            selectedCategory = category.key
          } label: {
            HStack {
              VStack(alignment: .leading) {
                Text(category.label).font(.mBodyB)
                Text("\(category.metrics.count)개 지표").font(.mMicro).foregroundStyle(Tokens.text3)
              }
              Spacer()
              Image(systemName: "chevron.right")
            }.padding(11).background(
              selected?.key == category.key ? Tokens.primary.opacity(0.1) : Tokens.surface,
              in: RoundedRectangle(cornerRadius: 11))
          }.buttonStyle(.plain)
        }
      }.padding(12)
    }
  }

  private func metricDetail(_ category: ServerAPI.AdminAnalysisCategory?) -> some View {
    ScrollView {
      if let category {
        LazyVStack(alignment: .leading, spacing: 10) {
          Text(category.label).font(.mTitle)
          ForEach(category.metrics) { item in
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                VStack(alignment: .leading) {
                  Text(item.label).font(.mBodyB)
                  Text("최소 판단 표본 \(item.minimumSampleSize)건").font(.mMicro).foregroundStyle(
                    Tokens.text3)
                }
                Spacer()
                badge(item.statusLabel, good: item.status == "reliable")
              }
              if item.observations.isEmpty {
                Text("집계 행이 아직 없습니다.").font(.mCaption).foregroundStyle(Tokens.text2)
              } else {
                ForEach(item.observations) { row in
                  VStack(alignment: .leading, spacing: 2) {
                    HStack {
                      Text(row.dimensionsLabel.isEmpty ? "전체" : row.dimensionsLabel).font(.mCaption)
                      Spacer()
                      Text(row.valueLabel).font(.mBodyB.monospacedDigit())
                    }
                    Text("표본 \(row.sampleSize)건" + fraction(row)).font(.mMicro).foregroundStyle(
                      Tokens.text3)
                    if !row.note.isEmpty {
                      Text(row.note).font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                  }.padding(.vertical, 3)
                }
              }
            }.padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 11))
          }
        }.padding(14)
      } else {
        ContentUnavailableView("지표 분류가 없습니다", systemImage: "chart.bar")
      }
    }
  }
  private func fraction(_ row: ServerAPI.AdminAnalysisObservation) -> String {
    guard let n = row.numerator, let d = row.denominator else { return "" }
    return " · 분자 \(n.formatted()) / 분모 \(d.formatted())"
  }
  private func metric(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(value).font(.mBodyB.monospacedDigit())
      Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
  private func badge(_ value: String, good: Bool) -> some View {
    Text(value).font(.mMicro.weight(.semibold)).foregroundStyle(
      good ? Tokens.successInk : Tokens.primary
    ).padding(.horizontal, 7).padding(.vertical, 3).background(
      (good ? Tokens.successInk : Tokens.primary).opacity(0.1), in: Capsule())
  }
  private func banner(_ value: String, color: Color, icon: String) -> some View {
    Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16)
      .padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(
        color.opacity(0.1))
  }
}
