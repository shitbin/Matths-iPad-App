import SwiftUI

struct ArenaDefenseInbox: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let onSelect: (ServerAPI.GoatArenaParticipantMatch, AccountRequestOwner) -> Void
    @State private var matches: [ServerAPI.GoatArenaParticipantMatch] = []
    @State private var owner: AccountRequestOwner?
    @State private var loading = true
    @State private var error: String?
    @State private var requestID = UUID()

    var body: some View {
        NavigationStack {
            List {
                if loading { ProgressView("받은 공격을 확인하고 있습니다") }
                if let error {
                    Text(error).foregroundStyle(Tokens.dangerInk)
                    Button("다시 시도") { Task { await load() } }.disabled(loading)
                } else if !loading && matches.isEmpty {
                    Text("받은 공격이 없습니다.")
                }
                ForEach(matches) { match in
                    Button {
                        guard let owner, owner.isCurrent(in: store) else { return }
                        onSelect(match, owner)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(match.attempt?.status == "IN_PROGRESS" ? "방어전 이어하기" : "방어전 확인")
                                .font(.mBodyB)
                            Text(statusLabel(match)).font(.mCaption).foregroundStyle(Tokens.text2)
                        }
                    }
                    .disabled(loading || !canOpen(match))
                }
            }
            .navigationTitle("받은 공격")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func canOpen(_ match: ServerAPI.GoatArenaParticipantMatch) -> Bool {
        if let actions = match.capabilities?.availableActions {
            return !Set(actions).isDisjoint(with: ["START", "SAVE_ANSWER", "ADVANCE", "SUBMIT_EVIDENCE"])
        }
        return ["MATCHED", "READY"].contains(match.status) || match.attempt?.status == "IN_PROGRESS"
    }

    private func statusLabel(_ match: ServerAPI.GoatArenaParticipantMatch) -> String {
        if match.attempt?.status == "IN_PROGRESS" { return "진행 중" }
        if match.attempt?.status == "EVIDENCE_REQUIRED" { return "풀이 증거 제출 필요" }
        if ["MATCHED", "READY"].contains(match.status) { return "시작 가능" }
        if ["SETTLED", "RESOLVED", "COMPLETED"].contains(match.status) { return "종료된 경기" }
        if ["CANCELLED", "EXPIRED"].contains(match.status) { return "취소되거나 마감된 경기" }
        return "경기 상태 확인 중"
    }

    @MainActor private func load() async {
        guard let captured = AccountRequestOwner(store: store) else {
            loading = false; error = "다시 로그인해 주세요."; return
        }
        let id = UUID()
        requestID = id; owner = captured; loading = true; error = nil
        defer { if requestID == id { loading = false } }
        do {
            let result = try await ServerAPI.getGoatArenaActionableDefenses(authorization: captured.authorization)
            guard captured.isCurrent(in: store), requestID == id else { return }
            matches = result
        } catch {
            guard captured.isCurrent(in: store), requestID == id else { return }
            self.error = "받은 공격을 불러오지 못했습니다. 다시 시도해 주세요."
        }
    }
}
