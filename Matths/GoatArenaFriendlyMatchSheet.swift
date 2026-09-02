import SwiftUI

extension ServerAPI {
    struct GoatArenaFriendlyOptions: Codable {
        struct Candidate: Codable, Identifiable, Hashable {
            var userId: String
            var nickname: String
            var tier: String
            var availableLearningDays: Int
            var id: String { userId }
        }

        struct Invitation: Codable, Identifiable, Hashable {
            var id: String
            var status: String
            var counterpartNickname: String
            var feeDays: Int
            var createdAt: String?
            var expiresAt: String?
        }

        var schemaVersion: String
        var query: String
        var eligible: Bool
        var eligibilityReason: String
        var feeDays: Int
        var hasActiveMatch: Bool
        var searchResults: [Candidate]
        var receivedInvitations: [Invitation]
        var sentInvitations: [Invitation]
    }

    struct GoatArenaFriendlyActionResponse: Codable {
        var kind: String
        var match: GoatArenaMatchCommandResponse.Match?
        var invitation: GoatArenaFriendlyOptions.Invitation?
    }

    static func getMainArenaFriendlyOptions(
        nickname: String = ""
    ) async throws -> GoatArenaFriendlyOptions {
        let response: GoatArenaFriendlyOptions = try await request(
            "GET",
            "/api/v1/goat-arena/matches/main/friendly",
            body: nil,
            authed: true,
            query: nickname.isEmpty ? [:] : ["nickname": nickname])
        guard response.schemaVersion == "GOAT_ARENA_MAIN_FRIENDLY_V1" else {
            throw ServerAPIError(
                message: "현재 앱에서 읽을 수 없는 친선 경기 정보입니다. 앱을 업데이트해주세요.",
                code: "GOAT_ARENA_MAIN_FRIENDLY_SCHEMA_UNSUPPORTED")
        }
        return response
    }

    static func createMainArenaFriendlyInvitation(
        inviteeUserId: String,
        commandId: String
    ) async throws -> GoatArenaFriendlyActionResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/main/friendly/invitations",
            body: ["inviteeUserId": inviteeUserId],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func respondMainArenaFriendlyInvitation(
        invitationId: String,
        response: String,
        commandId: String
    ) async throws -> GoatArenaFriendlyActionResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/main/friendly/invitations/\(invitationId)/respond",
            body: ["response": response],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func cancelMainArenaFriendlyInvitation(
        invitationId: String,
        commandId: String
    ) async throws -> GoatArenaFriendlyActionResponse {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/main/friendly/invitations/\(invitationId)/cancel",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }
}

struct GoatArenaFriendlyMatchSheet: View {
    private enum PendingAction: Identifiable {
        case invite(ServerAPI.GoatArenaFriendlyOptions.Candidate)
        case accept(ServerAPI.GoatArenaFriendlyOptions.Invitation)
        case decline(ServerAPI.GoatArenaFriendlyOptions.Invitation)
        case cancel(ServerAPI.GoatArenaFriendlyOptions.Invitation)

        var id: String {
            switch self {
            case .invite(let candidate): "invite:\(candidate.id)"
            case .accept(let invitation): "accept:\(invitation.id)"
            case .decline(let invitation): "decline:\(invitation.id)"
            case .cancel(let invitation): "cancel:\(invitation.id)"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onMatchCreated: (String) -> Void
    let onChanged: () -> Void

    @State private var options: ServerAPI.GoatArenaFriendlyOptions?
    @State private var nickname = ""
    @State private var isLoading = true
    @State private var isSearching = false
    @State private var actionID: String?
    @State private var pendingAction: PendingAction?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var accountSlot = DataScope.slot
    @State private var lifecycleID = UUID()
    @FocusState private var searchFocused: Bool

    private var compactHeight: Bool { verticalSizeClass == .compact }
    private var usesColumns: Bool {
        compactHeight && !dynamicTypeSize.isAccessibilitySize
    }
    private var cleanNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        searchSection
                        searchResults
                    }
                } trailing: {
                    invitationSections
                }
                .frame(maxWidth: 840, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Tokens.Space.s5)
                .padding(.vertical, compactHeight ? Tokens.Space.s3 : Tokens.Space.s6)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.paper)
            .navigationTitle("친선 경기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Tokens.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .disabled(actionID != nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load(nickname: cleanNickname, searching: false) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || actionID != nil)
                    .accessibilityLabel("친선 경기 초대 새로고침")
                }
            }
            .task { await load(nickname: "", searching: false) }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
                guard let nextSlot = $0.object as? String, nextSlot != accountSlot else { return }
                lifecycleID = UUID()
                pendingAction = nil
                dismiss()
            }
            .onDisappear { lifecycleID = UUID() }
            .confirmationDialog(
                confirmationTitle,
                isPresented: Binding(
                    get: { pendingAction != nil },
                    set: { if !$0 { pendingAction = nil } }),
                titleVisibility: .visible
            ) {
                confirmationButtons
                Button("돌아가기", role: .cancel) { pendingAction = nil }
            } message: {
                Text(confirmationMessage)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("순위 부담 없이 친구와 겨루세요")
                .font(.mHeading)
                .foregroundStyle(Tokens.text1)
                .accessibilityAddTraits(.isHeader)
            Text("활성 Ranked 사용자끼리 이용합니다. 초대 수락 시 양쪽에서 수수료 \(options?.feeDays ?? 1)일씩 차감되며, 승패로 티어·순위·학습일수는 이동하지 않습니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "닉네임으로 친구 찾기")
            HStack(spacing: Tokens.Space.s2) {
                TextField("닉네임 2글자 이상", text: $nickname)
                    .font(.mBody)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { search() }
                    .onChange(of: nickname) { _, next in
                        if next.count > 40 { nickname = String(next.prefix(40)) }
                    }
                    .padding(.horizontal, Tokens.Space.s3)
                    .frame(minHeight: 48)
                    .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.md)
                            .strokeBorder(Tokens.line, lineWidth: 1)
                    }
                Button {
                    search()
                } label: {
                    if isSearching {
                        ProgressView().frame(width: 44, height: 44)
                    } else {
                        Label("검색", systemImage: "magnifyingglass")
                            .frame(minWidth: 72)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isLoading || isSearching || actionID != nil)
            }
            if let options, !options.eligible || options.hasActiveMatch {
                notice(
                    options.hasActiveMatch
                        ? "진행 중인 경기를 마친 뒤 친선 초대를 이용할 수 있습니다."
                        : (options.eligibilityReason.isEmpty
                            ? "현재 친선 경기를 이용할 수 없습니다."
                            : options.eligibilityReason),
                    danger: true)
            }
            if let errorMessage { notice(errorMessage, danger: true) }
            if let statusMessage { notice(statusMessage, danger: false) }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if isLoading && options == nil {
            HStack(spacing: Tokens.Space.s3) {
                ProgressView()
                Text("친선 경기 상태 확인 중")
                    .font(.mBody)
                    .foregroundStyle(Tokens.text2)
            }
            .frame(minHeight: 44)
        } else if let options, !options.query.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "검색 결과")
                if options.searchResults.isEmpty {
                    emptyCard("지금 초대할 수 있는 사용자를 찾지 못했습니다. 닉네임이나 상대의 Ranked 이용 상태를 확인해주세요.")
                } else {
                    ForEach(options.searchResults) { candidate in
                        candidateRow(candidate, feeDays: options.feeDays)
                    }
                }
            }
        }
    }

    private var invitationSections: some View {
        VStack(alignment: .leading, spacing: usesColumns ? Tokens.Space.s4 : Tokens.Space.s6) {
            invitationList(
                title: "받은 친선 초대",
                empty: "현재 받은 친선 초대가 없습니다.",
                invitations: options?.receivedInvitations ?? [],
                received: true)
            invitationList(
                title: "보낸 친선 초대",
                empty: "현재 보낸 친선 초대가 없습니다.",
                invitations: options?.sentInvitations ?? [],
                received: false)
        }
    }

    private func candidateRow(
        _ candidate: ServerAPI.GoatArenaFriendlyOptions.Candidate,
        feeDays: Int
    ) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.s3) {
            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                Text(candidate.nickname)
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.text1)
                Text("\(ArenaDisplayTerms.tier(candidate.tier)) · 사용 가능 \(candidate.availableLearningDays)일")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .monospacedDigit()
            }
            Spacer(minLength: Tokens.Space.s2)
            Button("초대") { pendingAction = .invite(candidate) }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(actionID != nil || options?.hasActiveMatch == true)
                .accessibilityHint("상대가 수락하면 양쪽에서 \(feeDays)일씩 차감됩니다")
        }
        .padding(Tokens.Space.s3)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func invitationList(
        title: String,
        empty: String,
        invitations: [ServerAPI.GoatArenaFriendlyOptions.Invitation],
        received: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: title)
            if invitations.isEmpty {
                emptyCard(empty)
            } else {
                ForEach(invitations) { invitation in
                    invitationRow(invitation, received: received)
                }
            }
        }
    }

    private func invitationRow(
        _ invitation: ServerAPI.GoatArenaFriendlyOptions.Invitation,
        received: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(invitation.counterpartNickname)
                .font(.mBodyB)
                .foregroundStyle(Tokens.text1)
            Text(received
                ? "수락 시 양쪽 \(invitation.feeDays)일씩 차감 · 순위 이동 없음"
                : "상대 수락 대기 중 · 수락 전 무료 취소")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.s2) {
                if received {
                    Button("조건 확인 후 수락") { pendingAction = .accept(invitation) }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(actionID != nil || options?.hasActiveMatch == true)
                    Button("거절", role: .destructive) { pendingAction = .decline(invitation) }
                        .frame(minHeight: 44)
                        .disabled(actionID != nil)
                } else {
                    Button("초대 취소", role: .destructive) { pendingAction = .cancel(invitation) }
                        .frame(minHeight: 44)
                        .disabled(actionID != nil)
                }
                if actionID == invitation.id { ProgressView() }
            }
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.mCaption)
            .foregroundStyle(Tokens.text2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1)
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

    private var confirmationTitle: String {
        switch pendingAction {
        case .invite: "친선 초대를 보낼까요?"
        case .accept: "친선 초대를 수락할까요?"
        case .decline: "친선 초대를 거절할까요?"
        case .cancel: "보낸 친선 초대를 취소할까요?"
        case nil: "친선 경기 확인"
        }
    }

    private var confirmationMessage: String {
        switch pendingAction {
        case .invite(let candidate):
            "\(candidate.nickname)님이 수락할 때 양쪽에서 \(options?.feeDays ?? 1)일씩 차감됩니다. 초대 전에는 차감되지 않습니다."
        case .accept(let invitation):
            "수락 즉시 나와 \(invitation.counterpartNickname)님에게서 각각 \(invitation.feeDays)일이 이용 수수료로 차감됩니다. 승패에 따른 순위 이동은 없습니다."
        case .decline(let invitation):
            "\(invitation.counterpartNickname)님의 초대를 거절합니다. 학습일수는 차감되지 않습니다."
        case .cancel(let invitation):
            "\(invitation.counterpartNickname)님에게 보낸 초대를 취소합니다. 아직 학습일수는 차감되지 않았습니다."
        case nil:
            ""
        }
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        switch pendingAction {
        case .invite(let candidate):
            Button("초대 보내기") { Task { await invite(candidate) } }
        case .accept(let invitation):
            Button("양쪽 \(invitation.feeDays)일 차감에 동의하고 수락") {
                Task { await respond(invitation, response: "ACCEPT") }
            }
        case .decline(let invitation):
            Button("초대 거절", role: .destructive) {
                Task { await respond(invitation, response: "DECLINE") }
            }
        case .cancel(let invitation):
            Button("초대 취소", role: .destructive) {
                Task { await cancel(invitation) }
            }
        case nil:
            EmptyView()
        }
    }

    private func search() {
        errorMessage = nil
        statusMessage = nil
        guard (2...40).contains(cleanNickname.count) else {
            errorMessage = "닉네임을 2글자 이상 40자 이내로 입력해주세요."
            searchFocused = true
            return
        }
        searchFocused = false
        Task { await load(nickname: cleanNickname, searching: true) }
    }

    @MainActor
    private func load(nickname: String, searching: Bool) async {
        let owner = lifecycleID
        if options == nil { isLoading = true }
        isSearching = searching
        errorMessage = nil
        defer {
            if owner == lifecycleID {
                isLoading = false
                isSearching = false
            }
        }
        do {
            let value = try await ServerAPI.getMainArenaFriendlyOptions(nickname: nickname)
            guard owner == lifecycleID else { return }
            options = value
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = displayMessage(error)
        }
    }

    @MainActor
    private func invite(_ candidate: ServerAPI.GoatArenaFriendlyOptions.Candidate) async {
        await perform(id: candidate.id) {
            _ = try await ServerAPI.createMainArenaFriendlyInvitation(
                inviteeUserId: candidate.userId,
                commandId: UUID().uuidString)
            return "친선 초대를 보냈습니다. 상대가 수락하기 전에는 학습일수가 차감되지 않습니다."
        }
    }

    @MainActor
    private func respond(
        _ invitation: ServerAPI.GoatArenaFriendlyOptions.Invitation,
        response: String
    ) async {
        let owner = lifecycleID
        pendingAction = nil
        actionID = invitation.id
        errorMessage = nil
        statusMessage = nil
        defer { if owner == lifecycleID { actionID = nil } }
        do {
            let result = try await ServerAPI.respondMainArenaFriendlyInvitation(
                invitationId: invitation.id,
                response: response,
                commandId: UUID().uuidString)
            guard owner == lifecycleID else { return }
            if let match = result.match, response == "ACCEPT" {
                onChanged()
                onMatchCreated(match.id)
                return
            }
            statusMessage = "친선 초대를 거절했습니다. 학습일수는 차감되지 않았습니다."
            await load(nickname: cleanNickname, searching: false)
            onChanged()
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = displayMessage(error)
        }
    }

    @MainActor
    private func cancel(_ invitation: ServerAPI.GoatArenaFriendlyOptions.Invitation) async {
        await perform(id: invitation.id) {
            _ = try await ServerAPI.cancelMainArenaFriendlyInvitation(
                invitationId: invitation.id,
                commandId: UUID().uuidString)
            return "보낸 친선 초대를 취소했습니다. 학습일수는 차감되지 않았습니다."
        }
    }

    @MainActor
    private func perform(
        id: String,
        operation: () async throws -> String
    ) async {
        let owner = lifecycleID
        pendingAction = nil
        actionID = id
        errorMessage = nil
        statusMessage = nil
        defer { if owner == lifecycleID { actionID = nil } }
        do {
            let message = try await operation()
            guard owner == lifecycleID else { return }
            statusMessage = message
            await load(nickname: cleanNickname, searching: false)
            onChanged()
        } catch {
            guard owner == lifecycleID else { return }
            errorMessage = displayMessage(error)
        }
    }

    private func displayMessage(_ error: Error) -> String {
        if let api = error as? ServerAPIError {
            return api.errorDescription ?? "친선 경기 요청을 확인해주세요."
        }
        return "네트워크 연결을 확인한 뒤 다시 시도해주세요."
    }
}
