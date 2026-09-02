import SwiftUI

extension ServerAPI {
    struct GoatArenaPaybackAccount: Codable, Equatable {
        var confirmed: Bool
        var bankName: String
        var last4: String
        var confirmedAt: String?
    }

    struct GoatArenaPaybackAccountStatus: Codable {
        var schemaVersion: String
        var account: GoatArenaPaybackAccount
        var payoutEligible: Bool
        var bankSuggestions: [String]
    }

    private struct GoatArenaPaybackAccountConfirmation: Codable {
        var schemaVersion: String
        var account: GoatArenaPaybackAccount
    }

    static func getGoatArenaPaybackAccount() async throws -> GoatArenaPaybackAccountStatus {
        let response: GoatArenaPaybackAccountStatus = try await request(
            "GET",
            "/api/v1/goat-arena/profile/payback-account",
            body: nil,
            authed: true)
        guard response.schemaVersion == "GOAT_ARENA_PAYBACK_ACCOUNT_V1" else {
            throw ServerAPIError(
                message: "현재 앱에서 읽을 수 없는 계좌 연결 정보입니다. 앱을 업데이트해주세요.",
                code: "GOAT_ARENA_PAYBACK_ACCOUNT_SCHEMA_UNSUPPORTED")
        }
        return response
    }

    static func confirmGoatArenaPaybackAccount(
        bankName: String,
        accountHolderName: String,
        accountNumber: String,
        commandId: String
    ) async throws -> GoatArenaPaybackAccount {
        let response: GoatArenaPaybackAccountConfirmation = try await request(
            "POST",
            "/api/v1/goat-arena/profile/payback-account/confirm",
            body: [
                "bankName": bankName,
                "accountHolderName": accountHolderName,
                "accountNumber": accountNumber,
                "accountConfirmed": true,
            ],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
        guard response.schemaVersion == "GOAT_ARENA_PAYBACK_ACCOUNT_V1" else {
            throw ServerAPIError(
                message: "계좌 저장 결과를 확인할 수 없습니다. 새로고침 후 확인해주세요.",
                code: "GOAT_ARENA_PAYBACK_ACCOUNT_SCHEMA_UNSUPPORTED")
        }
        return response.account
    }
}

/// 페이백 지급 계좌를 앱 안에서 확인·교체한다.
///
/// 계좌 원문과 예금주는 이 화면의 메모리에만 두며 UserDefaults·Keychain·진단 로그에
/// 저장하지 않는다. 서버도 저장 뒤에는 은행명과 끝 4자리만 돌려준다.
struct GoatArenaPaybackAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var status: ServerAPI.GoatArenaPaybackAccountStatus?
    @State private var bankName = ""
    @State private var accountHolderName = ""
    @State private var accountNumber = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showsFinalConfirmation = false
    @State private var accountSlot = DataScope.slot
    @State private var lifecycleID = UUID()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case bank, holder, number }

    private var compactHeight: Bool { verticalSizeClass == .compact }
    private var usesColumns: Bool {
        compactHeight && !dynamicTypeSize.isAccessibilitySize
    }
    private var cleanBankName: String {
        bankName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var cleanHolderName: String {
        accountHolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var cleanAccountNumber: String {
        accountNumber.filter(\.isNumber)
    }
    private var hasValidDraft: Bool {
        !cleanBankName.isEmpty && cleanHolderName.count >= 2 &&
        (8...20).contains(cleanAccountNumber.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                CompactHeightColumns(
                    spacing: Tokens.Space.s5,
                    stackedSpacing: Tokens.Space.s7
                ) {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        intro
                        accountStatus
                        securityNotice
                    }
                } trailing: {
                    form
                }
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, compactHeight ? Tokens.Space.s3 : Tokens.Space.s6)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.paper)
            .navigationTitle("페이백 계좌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Tokens.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || isSaving)
                    .accessibilityLabel("페이백 계좌 상태 새로고침")
                }
            }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
                guard let nextSlot = $0.object as? String, nextSlot != accountSlot else { return }
                lifecycleID = UUID()
                clearSensitiveDraft()
                dismiss()
            }
            .confirmationDialog(
                "입력한 계좌로 페이백을 받을까요?",
                isPresented: $showsFinalConfirmation,
                titleVisibility: .visible
            ) {
                Button("확인하고 암호화 저장") {
                    Task { await save() }
                }
                Button("다시 확인", role: .cancel) {}
            } message: {
                Text("\(cleanBankName) · \(cleanHolderName) · \(cleanAccountNumber)\n예금주와 계좌번호가 정확한지 마지막으로 확인해주세요.")
            }
            .onDisappear {
                lifecycleID = UUID()
                clearSensitiveDraft()
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("지급받을 계좌를 연결하세요")
                .font(.mHeading)
                .foregroundStyle(Tokens.text1)
                .accessibilityAddTraits(.isHeader)
            Text("계좌 연결은 선택 사항입니다. 페이백 지급 대상이라면 운영자가 확인한 계좌로 직접 송금합니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var accountStatus: some View {
        if isLoading {
            HStack(spacing: Tokens.Space.s3) {
                ProgressView()
                Text("연결 상태 확인 중")
                    .font(.mBody)
                    .foregroundStyle(Tokens.text2)
            }
            .frame(minHeight: 44)
        } else if let account = status?.account, account.confirmed {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Label("확인된 지급 계좌", systemImage: "checkmark.seal.fill")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.successInk)
                Text("\(account.bankName) · 끝 \(account.last4)")
                    .font(.mHeading)
                    .foregroundStyle(Tokens.text1)
                    .monospacedDigit()
                Text("계좌를 바꾸려면 오른쪽 양식에 새 정보를 입력하고 다시 확인하세요.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.successSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Label(
                    status?.payoutEligible == true ? "지급 전 계좌 확인 필요" : "연결된 계좌 없음",
                    systemImage: status?.payoutEligible == true ? "exclamationmark.circle.fill" : "creditcard"
                )
                .font(.mBodyB)
                .foregroundStyle(status?.payoutEligible == true ? Tokens.warningInk : Tokens.text1)
                Text(status?.payoutEligible == true
                    ? "페이백 지급 대상입니다. 지급을 위해 계좌를 확인해주세요."
                    : "지급 대상이 되기 전에도 미리 연결할 수 있습니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
        }
    }

    private var securityNotice: some View {
        Label {
            Text("계좌번호는 서버에서 AES-256-GCM으로 암호화하며, 앱에는 저장하지 않습니다. 저장 후에는 끝 4자리만 표시됩니다.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Tokens.primary)
        }
        .font(.mCaption)
        .foregroundStyle(Tokens.text2)
        .accessibilityElement(children: .combine)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: usesColumns ? Tokens.Space.s3 : Tokens.Space.s4) {
            SectionRule(title: status?.account.confirmed == true ? "새 계좌로 변경" : "계좌 정보 입력")

            field("은행") {
                HStack(spacing: Tokens.Space.s2) {
                    TextField("예: 토스뱅크", text: $bankName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .bank)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .holder }
                        .onChange(of: bankName) { _, next in
                            if next.count > 40 { bankName = String(next.prefix(40)) }
                        }
                    if let suggestions = status?.bankSuggestions, !suggestions.isEmpty {
                        Menu {
                            ForEach(suggestions, id: \.self) { bank in
                                Button(bank) { bankName = bank }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.mBody)
                                .foregroundStyle(Tokens.primary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("은행 목록에서 선택")
                    }
                }
            }

            field("예금주") {
                TextField("계좌의 예금주 이름", text: $accountHolderName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .holder)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .number }
                    .onChange(of: accountHolderName) { _, next in
                        if next.count > 40 { accountHolderName = String(next.prefix(40)) }
                    }
            }

            field("계좌번호") {
                SecureField("하이픈 없이 숫자 8~20자리", text: $accountNumber)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .focused($focusedField, equals: .number)
                    .onChange(of: accountNumber) { _, next in
                        let digits = String(next.filter(\.isNumber).prefix(20))
                        if digits != next { accountNumber = digits }
                    }
            }

            if let errorMessage {
                notice(errorMessage, danger: true)
            }
            if let successMessage {
                notice(successMessage, danger: false)
            }

            Button {
                reviewDraft()
            } label: {
                HStack(spacing: Tokens.Space.s2) {
                    if isSaving { ProgressView().tint(Tokens.onPrimary) }
                    Text(isSaving ? "암호화해 저장 중" : "입력 정보 확인")
                    Spacer(minLength: 0)
                    if !isSaving { Image(systemName: "arrow.right") }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading || isSaving)
            .accessibilityHint("입력한 예금주와 계좌번호를 마지막으로 확인합니다")
        }
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
            Text(title)
                .font(.mCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Tokens.text2)
            content()
                .font(.mBody)
                .padding(.horizontal, Tokens.Space.s3)
                .frame(minHeight: 48)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.md)
                        .strokeBorder(Tokens.line, lineWidth: 1)
                }
        }
    }

    private func notice(_ message: String, danger: Bool) -> some View {
        Label(message, systemImage: danger ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.mCaption)
            .foregroundStyle(danger ? Tokens.danger : Tokens.successInk)
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                danger ? Tokens.dangerSoft : Tokens.successSoft,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .accessibilityElement(children: .combine)
    }

    @MainActor
    private func load() async {
        let owner = lifecycleID
        isLoading = true
        errorMessage = nil
        defer { if owner == lifecycleID { isLoading = false } }
        do {
            let value = try await ServerAPI.getGoatArenaPaybackAccount()
            guard owner == lifecycleID else { return }
            status = value
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = displayMessage(error)
        }
    }

    @MainActor
    private func save() async {
        guard hasValidDraft else {
            reviewDraft()
            return
        }
        let owner = lifecycleID
        let submittedBank = cleanBankName
        let submittedHolder = cleanHolderName
        let submittedNumber = cleanAccountNumber
        isSaving = true
        errorMessage = nil
        successMessage = nil
        defer { if owner == lifecycleID { isSaving = false } }
        do {
            let account = try await ServerAPI.confirmGoatArenaPaybackAccount(
                bankName: submittedBank,
                accountHolderName: submittedHolder,
                accountNumber: submittedNumber,
                commandId: UUID().uuidString)
            guard owner == lifecycleID else { return }
            if var current = status {
                current.account = account
                status = current
            } else {
                status = ServerAPI.GoatArenaPaybackAccountStatus(
                    schemaVersion: "GOAT_ARENA_PAYBACK_ACCOUNT_V1",
                    account: account,
                    payoutEligible: false,
                    bankSuggestions: [])
            }
            clearSensitiveDraft()
            successMessage = "계좌 확인이 완료되었습니다. 이후 화면에는 끝 4자리만 표시됩니다."
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = displayMessage(error)
        }
    }

    private func clearSensitiveDraft() {
        bankName = ""
        accountHolderName = ""
        accountNumber = ""
        focusedField = nil
        showsFinalConfirmation = false
    }

    private func reviewDraft() {
        successMessage = nil
        if cleanBankName.isEmpty {
            errorMessage = "은행을 입력하거나 목록에서 선택해주세요."
            focusedField = .bank
            return
        }
        if cleanHolderName.count < 2 {
            errorMessage = "예금주 이름을 2자 이상 정확히 입력해주세요."
            focusedField = .holder
            return
        }
        guard (8...20).contains(cleanAccountNumber.count) else {
            errorMessage = "계좌번호를 하이픈 없이 숫자 8~20자리로 입력해주세요."
            focusedField = .number
            return
        }
        errorMessage = nil
        focusedField = nil
        showsFinalConfirmation = true
    }

    private func displayMessage(_ error: Error) -> String {
        if let api = error as? ServerAPIError {
            return api.errorDescription ?? "계좌 연결 요청을 확인해주세요."
        }
        return "네트워크 연결을 확인한 뒤 다시 시도해주세요."
    }
}
