import SwiftUI

@MainActor
final class AdminFinanceScreenModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case finance = "재무"
        case refunds = "환불"
        case paybacks = "페이백"
        var id: String { rawValue }
    }

    @Published var section: Section = .finance
    @Published var finance: ServerAPI.AdminFinanceDashboard?
    @Published var refunds: ServerAPI.AdminRefundPage?
    @Published var paybacks: ServerAPI.AdminPaybackDashboard?
    @Published var selectedRefundID: String?
    @Published var selectedPaybackID: String?
    @Published var refundStatus = ""
    @Published var periodKey = ""
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-adminRefunds") { section = .refunds }
        if ProcessInfo.processInfo.arguments.contains("-adminPaybacks") { section = .paybacks }
        #endif
    }

    var selectedRefund: ServerAPI.AdminRefund? {
        refunds?.items.first { $0.id == selectedRefundID } ?? refunds?.items.first
    }
    var selectedPayback: ServerAPI.AdminPaybackRow? {
        paybacks?.rows.first { $0.id == selectedPaybackID } ?? paybacks?.rows.first
    }

    func loadCurrent() async {
        isLoading = true
        errorMessage = nil
        do {
            switch section {
            case .finance: finance = try await ServerAPI.adminFinance()
            case .refunds:
                let value = try await ServerAPI.adminRefunds(status: refundStatus)
                refunds = value
                keepRefundSelection(value)
            case .paybacks:
                let value = try await ServerAPI.adminPaybacks(periodKey: periodKey)
                paybacks = value
                periodKey = value.periodKey
                keepPaybackSelection(value)
            }
        } catch is CancellationError {
        } catch { errorMessage = readable(error) }
        isLoading = false
    }

    func changeSection(_ value: Section) async {
        section = value
        noticeMessage = nil
        await loadCurrent()
    }

    func withdrawal(amount: Int, note: String) async {
        await act("withdrawal") {
            finance = try await ServerAPI.recordAdminWithdrawal(amount: amount, operatorNote: note)
            noticeMessage = "실제 출금 기록을 장부에 반영했습니다."
        }
    }

    func reserve(amount: Int, note: String) async {
        await act("reserve") {
            finance = try await ServerAPI.updateAdminOtherUnpaidCosts(amount: amount, operatorNote: note)
            noticeMessage = "기타 미지급 비용 준비금을 변경했습니다."
        }
    }

    func calculateRefund(_ item: ServerAPI.AdminRefund, paidFeatureUsed: Bool) async {
        await act(item.id) {
            let value = try await ServerAPI.calculateAdminRefund(id: item.id, paidFeatureUsed: paidFeatureUsed)
            refunds = value; keepRefundSelection(value)
            noticeMessage = "환불 가능액과 근거를 계산했습니다."
        }
    }

    func completeRefund(
        _ item: ServerAPI.AdminRefund, amount: Int, mode: String,
        transactionKey: String, cancelledAt: String, note: String
    ) async {
        await act(item.id) {
            let value = try await ServerAPI.completeAdminRefund(
                id: item.id, approvedAmount: amount, cancellationMode: mode,
                transactionKey: transactionKey, cancelledAt: cancelledAt, operatorNote: note)
            refunds = value; keepRefundSelection(value)
            noticeMessage = "결제사 취소와 환불 완료 상태를 저장했습니다."
        }
    }

    func rejectRefund(_ item: ServerAPI.AdminRefund, note: String) async {
        await act(item.id) {
            let value = try await ServerAPI.rejectAdminRefund(id: item.id, operatorNote: note)
            refunds = value; keepRefundSelection(value)
            noticeMessage = "환불 신청을 반려 또는 0원 종결했습니다."
        }
    }

    func completePayback(_ item: ServerAPI.AdminPaybackRow, note: String) async {
        await act(item.id) {
            let mailed = try await ServerAPI.completeAdminPayback(cycleID: item.id, operatorNote: note)
            let value = try await ServerAPI.adminPaybacks(periodKey: periodKey)
            paybacks = value; keepPaybackSelection(value)
            noticeMessage = mailed ? "지급 완료와 이메일 발송을 기록했습니다." : "지급 완료했습니다. 이메일 발송 상태는 실패로 기록됐습니다."
        }
    }

    func resend(_ item: ServerAPI.AdminPaybackHistory) async {
        await act(item.id) {
            let mailed = try await ServerAPI.resendAdminPaybackEmail(recordID: item.id)
            paybacks = try await ServerAPI.adminPaybacks(periodKey: periodKey)
            noticeMessage = mailed ? "지급 완료 이메일을 재발송했습니다." : "이메일 재발송에 실패했습니다. 감사 기록을 확인하세요."
        }
    }

    private func act(_ id: String, operation: () async throws -> Void) async {
        guard actionID == nil else { return }
        actionID = id; errorMessage = nil; noticeMessage = nil
        do { try await operation() } catch { errorMessage = readable(error) }
        actionID = nil
    }

    private func keepRefundSelection(_ value: ServerAPI.AdminRefundPage) {
        if !value.items.contains(where: { $0.id == selectedRefundID }) { selectedRefundID = value.items.first?.id }
    }
    private func keepPaybackSelection(_ value: ServerAPI.AdminPaybackDashboard) {
        if !value.rows.contains(where: { $0.id == selectedPaybackID }) { selectedPaybackID = value.rows.first?.id }
    }
    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription
    }
}

struct AdminFinanceScreen: View {
    fileprivate enum Action: Identifiable {
        case withdrawal, reserve
        case calculate(ServerAPI.AdminRefund)
        case completeRefund(ServerAPI.AdminRefund)
        case rejectRefund(ServerAPI.AdminRefund)
        case payout(ServerAPI.AdminPaybackRow)
        case resend(ServerAPI.AdminPaybackHistory)

        var id: String {
            switch self {
            case .withdrawal: "withdrawal"
            case .reserve: "reserve"
            case .calculate(let item): "calculate:\(item.id)"
            case .completeRefund(let item): "complete-refund:\(item.id)"
            case .rejectRefund(let item): "reject-refund:\(item.id)"
            case .payout(let item): "payout:\(item.id)"
            case .resend(let item): "resend:\(item.id)"
            }
        }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminFinanceScreenModel()
    @State private var action: Action?
    let onClose: () -> Void

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            feedback
            if model.isLoading && currentIsEmpty { loading }
            else if currentIsEmpty, let error = model.errorMessage { failure(error) }
            else { content }
        }
        .background(Tokens.paper)
        .task { await model.loadCurrent() }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.loadCurrent() }
        }
        .sheet(item: $action) { value in
            AdminFinanceActionSheet(action: value, model: model)
        }
    }

    private var currentIsEmpty: Bool {
        switch model.section {
        case .finance: model.finance == nil
        case .refunds: model.refunds == nil
        case .paybacks: model.paybacks == nil
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.s3) {
            Button(action: onClose) { Label("관리자 홈", systemImage: "chevron.left") }
                .buttonStyle(.bordered)
            Picker("업무", selection: Binding(
                get: { model.section },
                set: { value in Task { await model.changeSection(value) } })) {
                ForEach(AdminFinanceScreenModel.Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 410)
            Spacer()
            if model.isLoading { ProgressView().controlSize(.small) }
            Button { Task { await model.loadCurrent() } } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(model.isLoading || model.actionID != nil)
        }
        .font(.mBodyB)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Tokens.surface)
    }

    @ViewBuilder private var feedback: some View {
        if let message = model.errorMessage {
            banner(message, color: Tokens.danger, icon: "exclamationmark.triangle.fill")
        } else if let message = model.noticeMessage {
            banner(message, color: Tokens.success, icon: "checkmark.circle.fill")
        }
    }

    private func banner(_ text: String, color: Color, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.mCaption).foregroundStyle(color).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 7).background(color.opacity(0.1))
    }

    private var loading: some View {
        VStack(spacing: 12) { ProgressView(); Text("운영 원장을 불러오는 중입니다").font(.mBodyB) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(Tokens.danger)
            Text(message).font(.mBody).multilineTextAlignment(.center)
            Button("다시 시도") { Task { await model.loadCurrent() } }.buttonStyle(.borderedProminent)
        }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        switch model.section {
        case .finance: if let value = model.finance { financeView(value) }
        case .refunds: if let value = model.refunds { refundsView(value) }
        case .paybacks: if let value = model.paybacks { paybacksView(value) }
        }
    }

    private func financeView(_ value: ServerAPI.AdminFinanceDashboard) -> some View {
        Group {
            if compactLandscape {
                HStack(alignment: .top, spacing: 12) {
                    financeSummary(value).frame(width: 390)
                    financeHistory(value)
                }.padding(12)
            } else {
                ScrollView { VStack(spacing: 16) { financeSummary(value); financeHistory(value, ownsScroll: false) }.padding() }
            }
        }
    }

    private func financeSummary(_ value: ServerAPI.AdminFinanceDashboard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                title("재무 장부", subtitle: "실제 결제·환불·페이백·출금 원장 기준")
                if !value.withdrawalsEnabled {
                    banner("PG 수수료 준비금 설정 전이라 사업자 출금이 잠겨 있습니다.", color: Tokens.danger, icon: "lock.fill")
                }
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    metric("오늘 매출", value.todayRevenue)
                    metric("순수금", value.netCollected)
                    metric("실제 현금", value.actualCashBalance)
                    metric("확정 이익", value.cumulativeConfirmedProfit)
                    metric("페이백 준비금", value.paybackReserve + value.confirmedUnpaidPayback)
                    metric("PG 준비금", value.pgFeeReserve)
                    metric("기타 미지급", value.otherUnpaidCosts)
                    metric("출금 가능", value.withdrawableAmount, emphasized: true)
                }
            }.padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("출금 기록") { action = .withdrawal }
                    .buttonStyle(.borderedProminent)
                    .disabled(!value.withdrawalsEnabled || value.withdrawableAmount < 1 || model.actionID != nil)
                Button("미지급 비용") { action = .reserve }.buttonStyle(.bordered)
            }.padding(10).frame(maxWidth: .infinity).background(.ultraThinMaterial)
        }
    }

    private func financeHistory(_ value: ServerAPI.AdminFinanceDashboard, ownsScroll: Bool = true) -> some View {
        let rows = VStack(alignment: .leading, spacing: 10) {
            title("최근 출금", subtitle: "잔액 전후와 처리자를 함께 보관합니다")
            if value.recentWithdrawals.isEmpty { empty("아직 출금 기록이 없습니다.") }
            ForEach(value.recentWithdrawals) { item in
                card {
                    HStack { Text(won(item.amount)).font(.mHeading); Spacer(); status(item.status) }
                    Text(item.operatorNote).font(.mBody)
                    Text("\(won(item.balanceBefore)) → \(won(item.balanceAfter)) · \(item.completedBy?.name ?? "운영자")")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
        }
        return Group { if ownsScroll { ScrollView { rows } } else { rows } }
    }

    private func refundsView(_ value: ServerAPI.AdminRefundPage) -> some View {
        split(
            list: {
                VStack(spacing: 8) {
                    Picker("상태", selection: Binding(
                        get: { model.refundStatus },
                        set: { value in model.refundStatus = value; Task { await model.loadCurrent() } })) {
                        Text("전체").tag(""); Text("신청").tag("REQUESTED"); Text("산정").tag("CALCULATED")
                        Text("완료").tag("COMPLETED"); Text("반려").tag("REJECTED")
                    }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                    if value.items.isEmpty { empty("조건에 맞는 환불 신청이 없습니다.") }
                    ForEach(value.items) { item in
                        Button { model.selectedRefundID = item.id } label: {
                            card {
                                HStack { Text(item.user?.name ?? "사용자").font(.mBodyB); Spacer(); status(item.status) }
                                Text(item.productName).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                                Text(item.reasonDetail).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(2)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            },
            detail: { refundDetail(model.selectedRefund) })
    }

    @ViewBuilder private func refundDetail(_ item: ServerAPI.AdminRefund?) -> some View {
        if let item {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        title(item.productName, subtitle: item.orderReference)
                        HStack { status(item.status); Text(item.provider).font(.mCaption); Spacer(); Text(item.user?.email ?? "").font(.mCaption) }
                        detailBlock("환불 사유", item.reasonDetail)
                        detailBlock("처리 기한", shortDate(item.processingDeadlineAt))
                        if item.status != "REQUESTED" {
                            detailBlock("산정 결과", "\(won(item.calculation.calculatedAmount)) · \(item.calculation.calculationType)\n\(item.calculation.formula)")
                        }
                        if item.status == "COMPLETED" || item.status == "REJECTED" {
                            detailBlock("처리 결과", "\(won(item.decision.approvedAmount)) · \(item.decision.cancellationMode)\n\(item.decision.operatorNote)")
                        }
                    }.padding(.bottom, 12)
                }
                if item.status == "REQUESTED" {
                    primary("환불액 산정", icon: "function") { action = .calculate(item) }
                } else if item.status == "CALCULATED" {
                    HStack {
                        Button("반려·0원 종결", role: .destructive) { action = .rejectRefund(item) }.buttonStyle(.bordered)
                        Button("환불 완료 처리") { action = .completeRefund(item) }.buttonStyle(.borderedProminent)
                    }.disabled(model.actionID != nil).padding(10).frame(maxWidth: .infinity).background(.ultraThinMaterial)
                }
            }
        } else { empty("왼쪽에서 환불 신청을 선택하세요.") }
    }

    private func paybacksView(_ value: ServerAPI.AdminPaybackDashboard) -> some View {
        split(
            list: {
                VStack(spacing: 9) {
                    HStack {
                        TextField("YYYY-MM", text: $model.periodKey).textFieldStyle(.roundedBorder)
                        Button("조회") { Task { await model.loadCurrent() } }.buttonStyle(.bordered)
                    }
                    HStack { compactMetric("대상", "\(value.eligible.total)명"); compactMetric("미지급", won(value.eligible.pendingAmount)) }
                    if value.rows.isEmpty { empty("지급 대기 페이백이 없습니다.") }
                    ForEach(value.rows) { item in
                        Button { model.selectedPaybackID = item.id } label: {
                            card {
                                HStack { Text(item.userName).font(.mBodyB); Spacer(); if item.payoutOverdue { status("기한 초과") } }
                                Text("\(won(item.paybackAmount)) · \(item.paybackRate.formatted())%")
                                    .font(.mBody).foregroundStyle(Tokens.ink)
                                Text(item.accountConfirmed ? "\(item.bankName) · 끝 \(item.accountNumberLast4)" : "계좌 미확인")
                                    .font(.mCaption).foregroundStyle(item.accountConfirmed ? Tokens.text2 : Tokens.danger)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            },
            detail: { paybackDetail(value) })
    }

    private func paybackDetail(_ dashboard: ServerAPI.AdminPaybackDashboard) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { compactMetric("월 매출", won(dashboard.monthly.salesAmount)); compactMetric("월 지급", won(dashboard.monthly.payoutAmount)) }
                    if let item = model.selectedPayback {
                        title(item.userName, subtitle: item.email)
                        detailBlock("지급액", "\(won(item.paybackAmount)) (\(item.paybackRate.formatted())%)")
                        detailBlock("지급 기한", shortDate(item.payoutDeadlineAt))
                        detailBlock("확인 계좌", item.accountConfirmed ? "\(item.bankName) \(item.accountNumber)\n예금주 \(item.accountHolderName)" : "사용자가 확인한 계좌가 없습니다.")
                    } else { empty("왼쪽에서 지급 대상을 선택하세요.") }
                    Divider().padding(.vertical, 4)
                    Text("지급 이력").font(.mHeading)
                    ForEach(dashboard.history.prefix(20)) { history in
                        card {
                            HStack { Text(history.user?.name ?? "사용자").font(.mBodyB); Spacer(); Text(won(history.amount)).font(.mBodyB) }
                            Text("\(history.bankName) · 끝 \(history.accountNumberLast4) · 이메일 \(history.emailStatus)")
                                .font(.mCaption).foregroundStyle(Tokens.text2)
                            if history.emailStatus != "SENT" {
                                Button("이메일 재발송") { action = .resend(history) }.buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                    }
                }
            }
            if let item = model.selectedPayback {
                Button("실제 송금 완료 기록") { action = .payout(item) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!item.accountConfirmed || item.decryptError || model.actionID != nil)
                    .padding(10).frame(maxWidth: .infinity).background(.ultraThinMaterial)
            }
        }
    }

    private func split<ListContent: View, DetailContent: View>(
        @ViewBuilder list: () -> ListContent, @ViewBuilder detail: () -> DetailContent
    ) -> some View {
        Group {
            if compactLandscape {
                HStack(alignment: .top, spacing: 12) {
                    ScrollView { list() }.frame(width: 390)
                    detail().frame(maxWidth: .infinity, maxHeight: .infinity)
                }.padding(12)
            } else {
                ScrollView { VStack(spacing: 16) { list(); Divider(); detail() }.padding() }
            }
        }
    }

    private func title(_ value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(value).font(.mTitle); Text(subtitle).font(.mCaption).foregroundStyle(Tokens.text2) }
    }
    private func metric(_ label: String, _ value: Int, emphasized: Bool = false) -> some View {
        card {
            Text(label).font(.mCaption).foregroundStyle(Tokens.text2)
            Text(won(value)).font(.mHeading).foregroundStyle(emphasized ? Tokens.primary : Tokens.ink).minimumScaleFactor(0.75)
        }
    }
    private func compactMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.mCaption).foregroundStyle(Tokens.text2); Text(value).font(.mBodyB) }
            .padding(9).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 10))
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6, content: content)
            .padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
    }
    private func detailBlock(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(label).font(.mCaption).foregroundStyle(Tokens.text2); Text(value.isEmpty ? "—" : value).font(.mBody).textSelection(.enabled) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(11).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
    }
    private func empty(_ value: String) -> some View {
        Text(value).font(.mBody).foregroundStyle(Tokens.text2).frame(maxWidth: .infinity, minHeight: 90).multilineTextAlignment(.center)
    }
    private func status(_ value: String) -> some View {
        Text(value).font(.mCaption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(value == "COMPLETED" || value == "완료" ? Tokens.success : Tokens.primary)
            .background((value == "COMPLETED" || value == "완료" ? Tokens.success : Tokens.primary).opacity(0.1), in: Capsule())
    }
    private func primary(_ label: String, icon: String, action perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Label(label, systemImage: icon).frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent).disabled(model.actionID != nil).padding(10).background(.ultraThinMaterial)
    }
    private func won(_ value: Int) -> String { value.formatted(.currency(code: "KRW").precision(.fractionLength(0))) }
    private func shortDate(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value.replacingOccurrences(of: "T", with: " ").prefix(16).description
    }
}

private struct AdminFinanceActionSheet: View {
    let action: AdminFinanceScreen.Action
    @ObservedObject var model: AdminFinanceScreenModel
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @State private var transactionKey = ""
    @State private var cancelledAt = ""
    @State private var mode = "FULL"
    @State private var paidFeatureUsed = false
    @State private var confirms = false

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(explanation).font(.mBody) }
                fields
                Section {
                    Button("입력 내용 확인") { confirms = true }
                        .disabled(!valid || model.actionID != nil)
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
            .confirmationDialog("최종 처리할까요?", isPresented: $confirms, titleVisibility: .visible) {
                Button(confirmLabel, role: destructive ? .destructive : nil) {
                    Task { await submit(); if model.errorMessage == nil { dismiss() } }
                }
                Button("취소", role: .cancel) {}
            } message: { Text(confirmMessage) }
        }
        .presentationDetents([.medium, .large])
        .onAppear { seed() }
    }

    @ViewBuilder private var fields: some View {
        switch action {
        case .withdrawal, .reserve:
            TextField("금액 (원)", text: $amount).keyboardType(.numberPad)
            TextField("목적·변경 사유", text: $note, axis: .vertical).lineLimit(2...5)
        case .calculate:
            Toggle("유료 기능을 사용한 사실을 추가 확인함", isOn: $paidFeatureUsed)
        case .completeRefund(let item):
            TextField("승인 금액", text: $amount).keyboardType(.numberPad)
            Picker("취소 방식", selection: $mode) { Text("전체 취소").tag("FULL"); Text("부분 취소").tag("PARTIAL") }
            if item.provider.uppercased() != "TOSS" {
                TextField("결제사 취소 거래키", text: $transactionKey)
                TextField("결제사 취소 시각 (ISO 8601)", text: $cancelledAt)
            }
            TextField("처리 메모", text: $note, axis: .vertical).lineLimit(2...5)
        case .rejectRefund:
            TextField("반려 또는 0원 종결 사유 (5자 이상)", text: $note, axis: .vertical).lineLimit(3...6)
        case .payout:
            TextField("실제 송금 확인 메모·거래 기록", text: $note, axis: .vertical).lineLimit(3...6)
        case .resend(let item):
            LabeledContent("수신자", value: item.user?.email ?? "")
            LabeledContent("기존 상태", value: item.emailStatus)
        }
    }

    private var title: String {
        switch action {
        case .withdrawal: "사업자 출금 기록"
        case .reserve: "미지급 비용 준비금"
        case .calculate: "환불액 산정"
        case .completeRefund: "환불 완료"
        case .rejectRefund: "환불 종결"
        case .payout: "페이백 지급 완료"
        case .resend: "이메일 재발송"
        }
    }
    private var explanation: String {
        switch action {
        case .withdrawal: "실제 사업자 계좌 출금을 완료한 뒤에만 장부에 기록하세요."
        case .reserve: "출금 가능액에서 별도로 보존할 미지급 비용 총액을 입력하세요."
        case .calculate: "서버가 주문·사용 기록과 환불 정책을 다시 확인해 환불 가능액을 계산합니다."
        case .completeRefund: "결제사 취소가 확인된 금액만 입력하세요. 완료 후 이용권과 페이백 자격이 함께 정리됩니다."
        case .rejectRefund: "사용자에게 남을 수 있도록 구체적인 처리 사유를 적으세요."
        case .payout(let item): "\(item.bankName) \(item.accountNumber), 예금주 \(item.accountHolderName)로 실제 송금한 뒤 기록하세요."
        case .resend: "사이트 알림은 중복 생성하지 않고 지급 완료 이메일만 다시 보냅니다."
        }
    }
    private var destructive: Bool {
        switch action { case .withdrawal, .completeRefund, .rejectRefund, .payout: true; default: false }
    }
    private var confirmLabel: String {
        switch action {
        case .withdrawal: "실제 출금 기록"
        case .reserve: "준비금 변경"
        case .calculate: "산정 실행"
        case .completeRefund: "환불 완료 처리"
        case .rejectRefund: "반려·종결"
        case .payout: "송금 완료 기록"
        case .resend: "이메일 재발송"
        }
    }
    private var confirmMessage: String { "이 작업은 재무·감사 기록에 남습니다. 입력값과 실제 처리 내역이 일치하는지 다시 확인하세요." }
    private var valid: Bool {
        switch action {
        case .withdrawal: return (Int(amount) ?? 0) > 0 && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reserve: return Int(amount) != nil && (Int(amount) ?? -1) >= 0 && !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .calculate, .resend: return true
        case .completeRefund(let item):
            let providerFields = item.provider.uppercased() == "TOSS" || (transactionKey.count >= 6 && !cancelledAt.isEmpty)
            return (Int(amount) ?? 0) > 0 && providerFields
        case .rejectRefund: return note.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
        case .payout: return note.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        }
    }

    private func seed() {
        switch action {
        case .reserve: amount = String(model.finance?.otherUnpaidCosts ?? 0)
        case .completeRefund(let item):
            amount = String(item.calculation.calculatedAmount)
            mode = item.calculation.calculatedAmount == item.calculation.approvedAmount ? "FULL" : "PARTIAL"
            cancelledAt = ISO8601DateFormatter().string(from: Date())
        default: break
        }
    }

    private func submit() async {
        switch action {
        case .withdrawal: await model.withdrawal(amount: Int(amount) ?? 0, note: note)
        case .reserve: await model.reserve(amount: Int(amount) ?? 0, note: note)
        case .calculate(let item): await model.calculateRefund(item, paidFeatureUsed: paidFeatureUsed)
        case .completeRefund(let item):
            await model.completeRefund(item, amount: Int(amount) ?? 0, mode: mode, transactionKey: transactionKey, cancelledAt: cancelledAt, note: note)
        case .rejectRefund(let item): await model.rejectRefund(item, note: note)
        case .payout(let item): await model.completePayback(item, note: note)
        case .resend(let item): await model.resend(item)
        }
    }
}
