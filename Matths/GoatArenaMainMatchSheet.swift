import SwiftUI

extension ServerAPI {
    struct GoatArenaMainTarget: Codable, Identifiable, Hashable {
        var tier: String
        var gap: Int
        var minimumStakeDays: Int
        var maximumStakeDays: Int
        var available: Bool

        var id: String { "\(tier):\(gap)" }
    }

    struct GoatArenaMainActionOptions: Codable {
        struct SentInvitation: Codable, Identifiable, Hashable {
            var id: String
            var status: String
            var targetTier: String
            var stakeDays: Int
            var reservedLearningDays: Int
            var createdAt: String?
            var canCancel: Bool
        }

        var schemaVersion: String
        var eligible: Bool
        var reasonCodes: [String]
        var currentTier: String?
        var availableLearningDays: Int
        var matchmakingRestrictedUntil: String?
        var hasActiveMatch: Bool
        var requestLocked: Bool?
        var sentInvitations: [SentInvitation]? = nil
        var upwardTargets: [GoatArenaMainTarget]
        var lowerTargets: [GoatArenaMainTarget]
    }

    struct GoatArenaMainCreationReceipt: Codable {
        struct Invitation: Codable {
            var id: String
            var status: String
            var targetTier: String
            var stakeDays: Int
        }

        var kind: String
        var match: GoatArenaMatchCommandResponse.Match?
        var invitation: Invitation?
    }

    struct GoatArenaMainCancellationReceipt: Codable {
        struct Invitation: Codable {
            var id: String
            var status: String
            var releasedLearningDays: Int
            var burnedLearningDays: Int
        }

        var kind: String
        var invitation: Invitation
    }

    static func getMainArenaMatchOptions() async throws -> GoatArenaMainActionOptions {
        let response: GoatArenaMainActionOptions = try await request(
            "GET",
            "/api/v1/goat-arena/matches/main/options",
            body: nil,
            authed: true)
        guard response.schemaVersion == "GOAT_ARENA_MAIN_ACTIONS_V1" else {
            throw ServerAPIError(
                message: "현재 앱에서 읽을 수 없는 Ranked 신청 정보입니다. 앱을 업데이트해주세요.",
                code: "GOAT_ARENA_MAIN_ACTIONS_SCHEMA_UNSUPPORTED")
        }
        return response
    }

    static func createMainUpwardArenaMatch(
        targetTier: String,
        stakeDays: Int,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaMainCreationReceipt {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/main/upward",
            body: ["targetTier": targetTier, "stakeDays": stakeDays],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func createMainArenaInvitation(
        targetTier: String,
        stakeDays: Int,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaMainCreationReceipt {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/main/invitations",
            body: ["targetTier": targetTier, "stakeDays": stakeDays],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }

    static func cancelMainArenaInvitation(
        invitationId: String,
        commandId: String,
        clientBuildVersion: String
    ) async throws -> GoatArenaMainCancellationReceipt {
        try await request(
            "POST",
            "/api/v1/goat-arena/matches/main/invitations/\(invitationId)/cancel",
            body: [:],
            authed: true,
            headers: [
                "Idempotency-Key": commandId,
                "X-Matths-Client-Version": clientBuildVersion,
            ])
    }
}

struct GoatArenaMainMatchSheet: View {
    enum Mode: String, Codable, CaseIterable, Identifiable {
        case upward = "UPWARD"
        case invitation = "INVITATION"

        var id: String { rawValue }
        var title: String {
            switch self {
            case .upward: "상위 티어 도전"
            case .invitation: "하위 티어 초대"
            }
        }
        var detail: String {
            switch self {
            case .upward: "서버가 참가 가능한 상위 티어 상대를 자동 배정합니다."
            case .invitation: "선택한 하위 티어 참가자에게 수락 가능한 초대를 보냅니다."
            }
        }
        var icon: String {
            switch self {
            case .upward: "arrow.up.right"
            case .invitation: "paperplane.fill"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onMatchCreated: (String) -> Void
    let onInvitationCreated: () -> Void

    @State private var options: ServerAPI.GoatArenaMainActionOptions?
    @State private var mode: Mode = .upward
    @State private var selectedTargetID: String?
    @State private var stakeDays = 1
    @State private var pendingCommand: GoatArenaMainPendingCommand?
    @State private var cancellationCandidate: ServerAPI.GoatArenaMainActionOptions.SentInvitation?
    @State private var cancellingInvitationID: String?
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var accountSlot = DataScope.slot
    @State private var lifecycleID = UUID()
    @State private var loadID = UUID()

    /// iPhone 가로는 horizontalSizeClass도 compact지만 실제 가용 폭은 800pt가 넘는다.
    /// 그 값을 그대로 "좁은 폭"으로 읽으면 모든 카드가 한 열로 늘어진다.
    private var compactHeight: Bool { verticalSizeClass == .compact }
    private var narrowWidth: Bool {
        horizontalSizeClass == .compact && !compactHeight
    }
    private var usesStickySubmit: Bool {
        compactHeight && !dynamicTypeSize.isAccessibilitySize
    }
    private var targets: [ServerAPI.GoatArenaMainTarget] {
        guard let options else { return [] }
        return (mode == .upward ? options.upwardTargets : options.lowerTargets)
            .filter(\.available)
    }
    private var selectedTarget: ServerAPI.GoatArenaMainTarget? {
        if let selected = targets.first(where: { $0.id == selectedTargetID }) {
            return selected
        }
        guard let pendingCommand else { return nil }
        return ServerAPI.GoatArenaMainTarget(
            tier: pendingCommand.targetTier,
            gap: 0,
            minimumStakeDays: pendingCommand.stakeDays,
            maximumStakeDays: pendingCommand.stakeDays,
            available: true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                        CompactHeightColumns(
                            spacing: Tokens.Space.s5,
                            stackedSpacing: Tokens.Space.s7
                        ) {
                            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                                intro
                                statusColumn
                            }
                        } trailing: {
                            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                                actionColumn
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: Tokens.Space.s7) {
                            intro
                            statusColumn
                            actionColumn
                        }
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, narrowWidth ? Tokens.Space.s4 : Tokens.Space.s8)
                .padding(.vertical, compactHeight ? Tokens.Space.s3 : Tokens.Space.s6)
            }
            .background(Tokens.paper)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if usesStickySubmit, let selectedTarget {
                    HStack {
                        Spacer(minLength: 0)
                        submitButton(selectedTarget).frame(maxWidth: 360)
                        Spacer(minLength: 0)
                    }
                    .safeAreaPadding(.horizontal, Tokens.Space.s5)
                    .padding(.vertical, Tokens.Space.s2)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider().overlay(Tokens.line) }
                }
            }
            .navigationTitle("Ranked 상대 찾기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || isSubmitting)
                    .accessibilityLabel("Ranked 신청 정보 새로고침")
                }
            }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) {
                guard let newSlot = $0.object as? String, newSlot != accountSlot else { return }
                lifecycleID = UUID()
                loadID = UUID()
                accountSlot = newSlot
                options = nil
                pendingCommand = nil
                cancellationCandidate = nil
                cancellingInvitationID = nil
                isLoading = false
                isSubmitting = false
                errorMessage = nil
                statusMessage = nil
                // 예치·초대 화면을 다른 학생 계정으로 이어 쓰지 않는다.
                dismiss()
            }
            .onDisappear {
                lifecycleID = UUID()
                loadID = UUID()
                isLoading = false
                isSubmitting = false
            }
            .confirmationDialog(
                "초대 예약을 취소할까요?",
                isPresented: Binding(
                    get: { cancellationCandidate != nil },
                    set: { if !$0 { cancellationCandidate = nil } }),
                titleVisibility: .visible
            ) {
                Button("예약 취소", role: .destructive) {
                    guard let invitation = cancellationCandidate else { return }
                    Task { await cancel(invitation) }
                }
                Button("계속 대기", role: .cancel) {
                    cancellationCandidate = nil
                }
            } message: {
                if let invitation = cancellationCandidate {
                    Text("\(ArenaDisplayTerms.tier(invitation.targetTier)) 초대를 취소하면 예약한 \(invitation.reservedLearningDays)일이 모두 사용 가능 학습일로 돌아옵니다.")
                }
            }
        }
    }

    @ViewBuilder
    private var statusColumn: some View {
        if isLoading && pendingCommand == nil { loadingView }
        if let pendingCommand {
            pendingNotice(pendingCommand)
        } else if let options {
            summary(options)
            sentInvitationSection(options.sentInvitations ?? [])
        }
    }

    @ViewBuilder
    private var actionColumn: some View {
        if pendingCommand != nil {
            if let selectedTarget, !usesStickySubmit { submitButton(selectedTarget) }
        } else if let options {
            if !options.eligible || options.hasActiveMatch {
                unavailable(options)
            } else {
                modePicker(options)
                targetPicker
                if let selectedTarget {
                    stakePicker(selectedTarget, options: options)
                    if !usesStickySubmit { submitButton(selectedTarget) }
                }
            }
        }
        if let errorMessage {
            errorNotice(errorMessage)
            if errorMessage == Self.routeMissingNotice { webArenaLink }
        }
        if let statusMessage { statusNotice(statusMessage) }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("경기 방식과 예치 일수를 선택하세요")
                .font(.mHeading)
                .foregroundStyle(Tokens.text1)
                .accessibilityAddTraits(.isHeader)
            Text("가능한 티어와 범위는 현재 서버 정책·내 잔여 학습일을 기준으로 표시됩니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loadingView: some View {
        HStack(spacing: Tokens.Space.s3) {
            ProgressView()
            Text("신청 가능한 경기를 확인하는 중입니다")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
    }

    private func summary(_ options: ServerAPI.GoatArenaMainActionOptions) -> some View {
        Group {
            if narrowWidth || dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Tokens.Space.s3) {
                    summaryItem("현재 티어", ArenaDisplayTerms.tier(options.currentTier))
                    summaryItem("사용 가능", "\(options.availableLearningDays)일")
                    summaryItem("예치 뒤 유지", "최소 1일")
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s3) {
                        summaryItem("현재 티어", ArenaDisplayTerms.tier(options.currentTier))
                        summaryItem("사용 가능", "\(options.availableLearningDays)일")
                        summaryItem("예치 뒤 유지", "최소 1일")
                    }
                    VStack(spacing: Tokens.Space.s3) {
                        summaryItem("현재 티어", ArenaDisplayTerms.tier(options.currentTier))
                        summaryItem("사용 가능", "\(options.availableLearningDays)일")
                        summaryItem("예치 뒤 유지", "최소 1일")
                    }
                }
            }
        }
    }

    private func summaryItem(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
            Spacer(minLength: Tokens.Space.s3)
            Text(value)
                .font(.mBodyB)
                .foregroundStyle(Tokens.text1)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func sentInvitationSection(
        _ invitations: [ServerAPI.GoatArenaMainActionOptions.SentInvitation]
    ) -> some View {
        if !invitations.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                SectionRule(title: "보낸 초대 예약")
                ForEach(invitations) { invitation in
                    HStack(alignment: .center, spacing: Tokens.Space.s3) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                            Text("\(ArenaDisplayTerms.tier(invitation.targetTier)) · \(invitation.stakeDays)일 예약")
                                .font(.mBodyB)
                                .foregroundStyle(Tokens.text1)
                            Text(invitationStatus(invitation.status))
                                .font(.mCaption)
                                .foregroundStyle(Tokens.text2)
                        }
                        Spacer(minLength: Tokens.Space.s3)
                        if invitation.canCancel {
                            Button("예약 취소") {
                                cancellationCandidate = invitation
                            }
                            .buttonStyle(.bordered)
                            .tint(Tokens.actionPrimary)
                            .disabled(cancellingInvitationID != nil || isSubmitting)
                            .frame(minHeight: 44)
                            .accessibilityHint("예약한 \(invitation.reservedLearningDays)일을 사용 가능 학습일로 돌려받습니다")
                        }
                    }
                    .padding(Tokens.Space.s4)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.md)
                            .strokeBorder(Tokens.line, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func invitationStatus(_ status: String) -> String {
        switch status {
        case "SEARCHING": return "상대 찾는 중"
        case "OFFERED": return "상대 수락 대기 중"
        case "PAUSED": return "일요일 매칭 보류"
        case "MATCH_FORMING": return "경기 확정 중"
        default: return "서버 상태 확인 중"
        }
    }

    private func modePicker(_ options: ServerAPI.GoatArenaMainActionOptions) -> some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
            SectionRule(title: "경기 방식")
            if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: Tokens.Space.s2) {
                    compactModeButton(.upward,
                        enabled: options.upwardTargets.contains(where: \.available))
                    compactModeButton(.invitation,
                        enabled: options.lowerTargets.contains(where: \.available))
                }
            } else if narrowWidth || dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: Tokens.Space.s3) {
                    modeButton(.upward, enabled: options.upwardTargets.contains(where: \.available))
                    modeButton(.invitation, enabled: options.lowerTargets.contains(where: \.available))
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Tokens.Space.s3) {
                        modeButton(.upward, enabled: options.upwardTargets.contains(where: \.available))
                        modeButton(.invitation, enabled: options.lowerTargets.contains(where: \.available))
                    }
                    VStack(spacing: Tokens.Space.s3) {
                        modeButton(.upward, enabled: options.upwardTargets.contains(where: \.available))
                        modeButton(.invitation, enabled: options.lowerTargets.contains(where: \.available))
                    }
                }
            }
        }
    }

    private func compactModeButton(_ candidate: Mode, enabled: Bool) -> some View {
        Button {
            guard pendingCommand == nil else { return }
            mode = candidate
            selectFirstTarget()
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: candidate.icon)
                    .accessibilityHidden(true)
                Text(candidate.title)
                    .font(.mBodyB)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 0)
                Image(systemName: mode == candidate ? "checkmark.circle.fill" : "circle")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(mode == candidate ? Tokens.actionPrimary : Tokens.text2)
            .padding(.horizontal, Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(mode == candidate ? Tokens.actionPrimary : Tokens.line,
                                  lineWidth: mode == candidate ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled || pendingCommand != nil)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(candidate.title)
        .accessibilityValue(mode == candidate ? "선택됨" : "선택 안 됨")
        .accessibilityHint(candidate.detail)
    }

    private func modeButton(_ candidate: Mode, enabled: Bool) -> some View {
        Button {
            guard pendingCommand == nil else { return }
            mode = candidate
            selectFirstTarget()
        } label: {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                Image(systemName: candidate.icon)
                    .font(.mBodyB)
                    .foregroundStyle(mode == candidate ? Tokens.actionPrimary : Tokens.text2)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(candidate.title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.text1)
                    Text(candidate.detail)
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Tokens.Space.s2)
                Image(systemName: mode == candidate ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(mode == candidate ? Tokens.actionPrimary : Tokens.lineStrong)
                    .accessibilityHidden(true)
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(
                        mode == candidate ? Tokens.actionPrimary : Tokens.line,
                        lineWidth: mode == candidate ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled || pendingCommand != nil)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(candidate.title)
        .accessibilityValue(mode == candidate ? "선택됨" : "선택 안 됨")
        .accessibilityHint(candidate.detail)
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
            SectionRule(title: "상대 티어")
            if targets.isEmpty {
                Text("현재 선택할 수 있는 상대 티어가 없습니다.")
                    .font(.mBody)
                    .foregroundStyle(Tokens.text2)
                    .padding(Tokens.Space.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            } else if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: Tokens.Space.s2) {
                    ForEach(targets) { target in targetButton(target, compact: true) }
                }
            } else {
                ForEach(targets) { target in
                    targetButton(target, compact: false)
                }
            }
        }
    }

    private func targetButton(_ target: ServerAPI.GoatArenaMainTarget,
                              compact: Bool) -> some View {
        Button {
            guard pendingCommand == nil else { return }
            select(target)
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text(ArenaDisplayTerms.tier(target.tier))
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.text1)
                    Text(compact
                         ? "\(target.gap)단계 · \(target.minimumStakeDays)~\(target.maximumStakeDays)일"
                         : "\(target.gap)단계 차이 · \(target.minimumStakeDays)~\(target.maximumStakeDays)일")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .lineLimit(compact ? 1 : nil)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
                Image(systemName: selectedTargetID == target.id
                    ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTargetID == target.id
                        ? Tokens.actionPrimary : Tokens.lineStrong)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, compact ? Tokens.Space.s3 : Tokens.Space.s4)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 60, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(
                        selectedTargetID == target.id ? Tokens.actionPrimary : Tokens.line,
                        lineWidth: selectedTargetID == target.id ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(pendingCommand != nil)
        .accessibilityLabel("\(ArenaDisplayTerms.tier(target.tier)), \(target.gap)단계 차이")
        .accessibilityValue(selectedTargetID == target.id ? "선택됨" : "선택 안 됨")
        .accessibilityHint("예치 가능 범위 \(target.minimumStakeDays)일부터 \(target.maximumStakeDays)일")
    }

    private func stakePicker(
        _ target: ServerAPI.GoatArenaMainTarget,
        options: ServerAPI.GoatArenaMainActionOptions
    ) -> some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
            SectionRule(title: "예치 학습일")
            Stepper(
                value: $stakeDays,
                in: target.minimumStakeDays...target.maximumStakeDays
            ) {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text("\(stakeDays)일 예치")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.text1)
                        .monospacedDigit()
                    Text("경기 생성 뒤 사용 가능 \(max(0, options.availableLearningDays - stakeDays))일")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .monospacedDigit()
                }
            }
            .padding(Tokens.Space.s4)
            .frame(minHeight: 68)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
            .disabled(pendingCommand != nil)
            .accessibilityHint("최소 \(target.minimumStakeDays)일, 최대 \(target.maximumStakeDays)일")

            Text(mode == .upward
                ? "상위 티어 도전은 내 학습일만 예치하며, 서버가 참가 가능한 방어자를 배정합니다."
                : "초대가 성사될 때까지 선택한 학습일이 예약됩니다. 취소·정산은 활성 정책을 따릅니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func submitButton(_ target: ServerAPI.GoatArenaMainTarget) -> some View {
        Button {
            Task { await submit(target) }
        } label: {
            HStack(spacing: Tokens.Space.s3) {
                if isSubmitting {
                    ProgressView().tint(Tokens.onPrimary)
                } else {
                    Image(systemName: mode.icon)
                }
                Text(isSubmitting
                    ? "서버에서 확인 중"
                    : (pendingCommand == nil ? mode.title : "이전 요청 결과 다시 확인"))
                Spacer(minLength: Tokens.Space.s2)
                if !isSubmitting { Image(systemName: "arrow.right") }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isSubmitting || isLoading)
        .accessibilityHint("\(ArenaDisplayTerms.tier(target.tier))에 \(stakeDays)일을 예치하는 요청을 서버에서 확인합니다")
    }

    private func pendingNotice(_ pending: GoatArenaMainPendingCommand) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s2) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Tokens.warningInk)
                    .accessibilityHidden(true)
                Text("확인이 필요한 이전 요청")
                    .font(.mBodyB)
                    .foregroundStyle(Tokens.text1)
            }
            Text("\(pending.mode.title) · \(ArenaDisplayTerms.tier(pending.targetTier)) · \(pending.stakeDays)일. 이미 보낸 요청의 결과를 다시 확인하므로 경기가 중복으로 만들어지지 않습니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Text("서버 결과가 확인될 때까지 선택은 바뀌지 않습니다.")
                .font(.mCaption)
                .foregroundStyle(Tokens.warningInk)
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .accessibilityElement(children: .contain)
    }

    private func unavailable(_ options: ServerAPI.GoatArenaMainActionOptions) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(options.hasActiveMatch ? "진행 중인 경기가 있습니다" : "지금은 새 경기를 만들 수 없습니다")
                .font(.mBodyB)
                .foregroundStyle(Tokens.text1)
            Text(options.hasActiveMatch
                ? "현재 경기를 마치고 Arena를 새로고침한 뒤 다시 시도해주세요."
                : reasonText(options.reasonCodes.first))
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private func errorNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("요청을 완료하지 못했습니다")
                .font(.mBodyB)
                .foregroundStyle(Tokens.danger)
            Text(message)
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.dangerSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .accessibilityElement(children: .combine)
    }

    /// 라우트 없음 안내(routeMissingNotice) 아래에만 붙는 웹 GOAT Arena 링크.
    /// errorNotice 는 접근성 요소를 합치므로 링크는 별도 요소로 둔다(VoiceOver 로 탭 가능).
    private var webArenaLink: some View {
        Button("웹 GOAT Arena에서 진행") {
            ArenaWebPresenter.open(.rankedBattle)
        }
            .font(.mBodyB)
            .foregroundStyle(Tokens.primary)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .accessibilityHint("앱 안에서 로그인 상태를 유지한 채 Ranked 대전 화면을 엽니다")
    }

    private func statusNotice(_ message: String) -> some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.mBody)
            .foregroundStyle(Tokens.successInk)
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.successSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            .accessibilityElement(children: .combine)
    }

    @MainActor
    private func load() async {
        let ownerSlot = accountSlot
        let ownerLifecycleID = lifecycleID
        let nextLoadID = UUID()
        loadID = nextLoadID
        guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
        isLoading = true
        errorMessage = nil
        let saved: GoatArenaMainPendingCommand?
        do {
            saved = try GoatArenaMainCommandStore.load(accountSlot: ownerSlot)
            guard owns(ownerLifecycleID, slot: ownerSlot), loadID == nextLoadID else { return }
            pendingCommand = saved
            if let saved {
                mode = saved.mode
                selectedTargetID = "\(saved.targetTier):pending"
                stakeDays = saved.stakeDays
            }
        } catch {
            guard owns(ownerLifecycleID, slot: ownerSlot), loadID == nextLoadID else { return }
            errorMessage = userMessage(error)
            isLoading = false
            return
        }
        do {
            let value = try await ServerAPI.getMainArenaMatchOptions()
            guard owns(ownerLifecycleID, slot: ownerSlot), loadID == nextLoadID else { return }
            options = value
            if let saved {
                selectedTargetID = targetID(
                    tier: saved.targetTier,
                    in: saved.mode,
                    options: value) ?? selectedTargetID
            } else {
                chooseInitialMode(value)
                selectFirstTarget()
            }
        } catch {
            guard owns(ownerLifecycleID, slot: ownerSlot), loadID == nextLoadID else { return }
            errorMessage = userMessage(error)
        }
        guard owns(ownerLifecycleID, slot: ownerSlot), loadID == nextLoadID else { return }
        isLoading = false
    }

    private func chooseInitialMode(_ value: ServerAPI.GoatArenaMainActionOptions) {
        if value.upwardTargets.contains(where: \.available) {
            mode = .upward
        } else if value.lowerTargets.contains(where: \.available) {
            mode = .invitation
        }
    }

    private func targetID(
        tier: String,
        in mode: Mode,
        options: ServerAPI.GoatArenaMainActionOptions
    ) -> String? {
        let rows = mode == .upward ? options.upwardTargets : options.lowerTargets
        return rows.first { $0.tier == tier }?.id
    }

    private func selectFirstTarget() {
        guard let target = targets.first else {
            selectedTargetID = nil
            return
        }
        select(target)
    }

    private func select(_ target: ServerAPI.GoatArenaMainTarget) {
        selectedTargetID = target.id
        stakeDays = min(
            max(stakeDays, target.minimumStakeDays),
            target.maximumStakeDays)
    }

    @MainActor
    private func cancel(
        _ invitation: ServerAPI.GoatArenaMainActionOptions.SentInvitation
    ) async {
        guard cancellingInvitationID == nil else { return }
        let ownerSlot = accountSlot
        let ownerLifecycleID = lifecycleID
        guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
        cancellingInvitationID = invitation.id
        cancellationCandidate = nil
        errorMessage = nil
        statusMessage = nil
        do {
            let receipt = try await ServerAPI.cancelMainArenaInvitation(
                invitationId: invitation.id,
                commandId: UUID().uuidString,
                clientBuildVersion: ServerAPI.clientBuildVersion)
            guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
            guard receipt.kind == "INVITATION_CANCELLATION",
                  receipt.invitation.id == invitation.id,
                  receipt.invitation.status == "CANCELLED" else {
                throw GoatArenaMainSheetError.invalidReceipt
            }
            statusMessage = receipt.invitation.burnedLearningDays == 0
                ? "예약을 취소하고 \(receipt.invitation.releasedLearningDays)일을 돌려받았습니다."
                : "예약을 취소했습니다. \(receipt.invitation.releasedLearningDays)일 반환 · \(receipt.invitation.burnedLearningDays)일 차감"
            await load()
        } catch {
            guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
            errorMessage = userMessage(error)
        }
        guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
        cancellingInvitationID = nil
    }

    @MainActor
    private func submit(_ target: ServerAPI.GoatArenaMainTarget) async {
        guard !isSubmitting else { return }
        let ownerSlot = accountSlot
        let ownerLifecycleID = lifecycleID
        guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
        isSubmitting = true
        errorMessage = nil
        statusMessage = nil
        do {
            let command: GoatArenaMainPendingCommand
            if let pendingCommand {
                command = pendingCommand
            } else {
                command = GoatArenaMainPendingCommand(
                    mode: mode,
                    targetTier: target.tier,
                    stakeDays: stakeDays,
                    commandId: UUID().uuidString,
                    clientBuildVersion: ServerAPI.clientBuildVersion)
                try GoatArenaMainCommandStore.save(command, accountSlot: ownerSlot)
                pendingCommand = command
            }

            let receipt: ServerAPI.GoatArenaMainCreationReceipt
            switch command.mode {
            case .upward:
                receipt = try await ServerAPI.createMainUpwardArenaMatch(
                    targetTier: command.targetTier,
                    stakeDays: command.stakeDays,
                    commandId: command.commandId,
                    clientBuildVersion: command.clientBuildVersion)
            case .invitation:
                receipt = try await ServerAPI.createMainArenaInvitation(
                    targetTier: command.targetTier,
                    stakeDays: command.stakeDays,
                    commandId: command.commandId,
                    clientBuildVersion: command.clientBuildVersion)
            }

            switch (command.mode, receipt.kind) {
            case (.upward, "MATCH"):
                guard let id = receipt.match?.id, !id.isEmpty else {
                    throw GoatArenaMainSheetError.invalidReceipt
                }
                // 성공은 원래 계정에서 확정됐을 수 있다. 재시도 키는 원래 슬롯에서
                // 정리하고, 화면 전환은 아직 같은 계정일 때만 수행한다.
                try GoatArenaMainCommandStore.clear(accountSlot: ownerSlot)
                guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
                pendingCommand = nil
                onMatchCreated(id)
            case (.invitation, "INVITATION"):
                guard let invitation = receipt.invitation,
                      !invitation.id.isEmpty else {
                    throw GoatArenaMainSheetError.invalidReceipt
                }
                try GoatArenaMainCommandStore.clear(accountSlot: ownerSlot)
                guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
                pendingCommand = nil
                statusMessage = "\(ArenaDisplayTerms.tier(invitation.targetTier)) 초대를 보냈습니다. 상대가 수락하기 전까지 아래에서 예약을 취소할 수 있습니다."
                await load()
                onInvitationCreated()
            default:
                throw GoatArenaMainSheetError.invalidReceipt
            }
        } catch {
            releaseRejectedCommandIfSafe(error, accountSlot: ownerSlot)
            guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
            errorMessage = userMessage(error)
        }
        guard owns(ownerLifecycleID, slot: ownerSlot) else { return }
        isSubmitting = false
    }

    private func releaseRejectedCommandIfSafe(_ error: Error, accountSlot: String) {
        guard let server = error as? ServerAPIError,
              let status = server.statusCode,
              (400..<500).contains(status),
              status != 401,
              server.code != "GOAT_ARENA_IDEMPOTENCY_KEY_CONFLICT" else {
            return
        }
        // HTTP 오류 본문을 정상적으로 받은 경우 서버 명령은 실패로 확정됐다.
        // 타임아웃·연결 끊김·디코딩 오류는 결과가 불명확하므로 키를 계속 보존한다.
        guard (try? GoatArenaMainCommandStore.clear(accountSlot: accountSlot)) != nil else { return }
        if self.accountSlot == accountSlot, DataScope.slot == accountSlot {
            pendingCommand = nil
        }
    }

    private func owns(_ id: UUID, slot: String) -> Bool {
        lifecycleID == id && accountSlot == slot && DataScope.slot == slot
    }

    private func reasonText(_ code: String?) -> String {
        if code?.contains("SUNDAY") == true {
            return "일요일 14시 이후에는 새 Ranked 경기를 만들 수 없습니다."
        }
        switch code {
        case "ACTIVE_MATCH_EXISTS":
            return "현재 경기를 마친 뒤 새 경기를 만들 수 있습니다."
        case "INSUFFICIENT_AVAILABLE_DAYS":
            return "예치 후에도 사용할 학습일 1일이 남아야 합니다."
        case "MATCHMAKING_RESTRICTED":
            return "현재 상대 찾기 제한이 적용되어 있습니다. 제한 종료 뒤 다시 시도해주세요."
        default:
            return "Arena 참가 상태와 이용 기간을 확인한 뒤 다시 시도해주세요."
        }
    }

    /// 경기 명령 라우트가 없는 서버(웹 세션 전용)에서 load/submit/cancel 이 받는 안내.
    /// 서버의 기계적인 "페이지가 없습니다" 문구 대신 다음 행동(웹)을 알려준다.
    static let routeMissingNotice =
        "Ranked 도전·초대는 앱 안의 웹 GOAT Arena 화면에서 이어집니다."

    private func userMessage(_ error: Error) -> String {
        if let server = error as? ServerAPIError {
            // HTTP_404(라우트 없음)는 도전 없음·자격 없음과 다른 문제 — 웹으로 안내한다.
            if server.isRouteMissing { return Self.routeMissingNotice }
            return ArenaDisplayTerms.apply(
                server.message ?? "요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.")
        }
        if error is GoatArenaMainCommandStoreError {
            return "요청을 안전하게 저장하지 못했습니다. 기기 저장 공간을 확인하고 다시 시도해 주세요."
        }
        if error is GoatArenaMainSheetError {
            return "서버 응답을 확인하지 못했습니다. 같은 요청으로 다시 확인해주세요."
        }
        #if DEBUG
        print("GOAT Arena 경기 요청 실패:", error)
        #endif
        return "요청을 완료하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요."
    }
}

private struct GoatArenaMainPendingCommand: Codable, Equatable {
    let mode: GoatArenaMainMatchSheet.Mode
    let targetTier: String
    let stakeDays: Int
    let commandId: String
    let clientBuildVersion: String
}

private enum GoatArenaMainCommandStoreError: Error {
    case unreadable
    case unwritable
}

private enum GoatArenaMainSheetError: Error {
    case invalidReceipt
}

private enum GoatArenaMainCommandStore {
    private static func fileURL(for accountSlot: String) -> URL {
        DataScope.url("goat-arena-main-create-command.json", for: accountSlot)
    }

    static func load(accountSlot: String) throws -> GoatArenaMainPendingCommand? {
        let fileURL = fileURL(for: accountSlot)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(
                GoatArenaMainPendingCommand.self,
                from: Data(contentsOf: fileURL))
        } catch {
            throw GoatArenaMainCommandStoreError.unreadable
        }
    }

    static func save(_ command: GoatArenaMainPendingCommand, accountSlot: String) throws {
        do {
            let data = try JSONEncoder().encode(command)
            try data.write(to: fileURL(for: accountSlot), options: .atomic)
        } catch {
            throw GoatArenaMainCommandStoreError.unwritable
        }
    }

    static func clear(accountSlot: String) throws {
        let fileURL = fileURL(for: accountSlot)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw GoatArenaMainCommandStoreError.unwritable
        }
    }
}
