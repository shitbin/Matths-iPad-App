import SwiftUI

private struct StaffWorkspaceActiveKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var staffWorkspaceActive: Bool {
        get { self[StaffWorkspaceActiveKey.self] }
        set { self[StaffWorkspaceActiveKey.self] = newValue }
    }
}

struct StaffWorkspaceDestination: Identifiable {
    let id: String
    let title: String
    let symbol: String
}

/// A task-focused staff shell. The content stays at the same identity when the
/// container crosses the sidebar threshold; only navigation chrome changes.
struct StaffWorkspaceContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let destinations: [StaffWorkspaceDestination]
    let selectedID: String
    let onSelect: (String) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { viewport in
            let wide = StaffWorkspaceMetrics.usesSidebar(width: viewport.size.width)
            HStack(spacing: 0) {
                if wide {
                    VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                            Text(title).font(.mHeading).foregroundStyle(Tokens.ink)
                            Text(subtitle).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(3)
                        }
                        ForEach(destinations) { destination in navigationButton(destination, sidebar: true) }
                        Spacer(minLength: 0)
                    }
                    .padding(Tokens.Space.s3)
                    .frame(width: 180, alignment: .leading)
                    .background(Tokens.surface)
                    Divider()
                }
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !wide {
                    HStack(spacing: 0) {
                        ForEach(destinations) { destination in navigationButton(destination, sidebar: false) }
                    }
                    .padding(.top, Tokens.Space.s1)
                    .background(Tokens.surface)
                    .overlay(alignment: .top) { Divider() }
                }
            }
        }
        .background(Tokens.paper)
    }

    private func navigationButton(_ destination: StaffWorkspaceDestination, sidebar: Bool) -> some View {
        Button { onSelect(destination.id) } label: {
            let layout = sidebar ? AnyLayout(HStackLayout(spacing: Tokens.Space.s2)) : AnyLayout(VStackLayout(spacing: 3))
            layout {
                Image(systemName: destination.symbol).font(.system(size: 18, weight: .medium))
                Text(destination.title).font(sidebar ? .mCaption : .mMicro).lineLimit(1).minimumScaleFactor(0.85)
                if sidebar { Spacer(minLength: 0) }
            }
            .foregroundStyle(destination.id == selectedID ? Tokens.primary : Tokens.text2)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, sidebar ? Tokens.Space.s2 : 2)
            .background(destination.id == selectedID ? Tokens.primarySoft : .clear,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(destination.id == selectedID ? .isSelected : [])
        .accessibilityIdentifier("staff.destination.\(destination.id)")
    }
}

struct StaffChangeValue: Identifiable {
    let label: String
    let before: String
    let after: String
    var id: String { label }
}

/// Review, not a pretend audit field: reason is shown only if the server actually
/// accepts it. Contract limitations are explicit and no local-only reason is sent.
struct StaffChangeReview: View {
    let title: String
    let changes: [StaffChangeValue]
    let impact: String
    var reason: String? = nil
    var reasonIsRecorded = false
    let actionTitle: String
    var destructive = false
    var isWorking = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("변경 내용") {
                    ForEach(changes) { change in
                        VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                            Text(change.label).font(.mCaption).foregroundStyle(Tokens.text2)
                            Text("현재: \(change.before)").font(.mBody)
                            Text("변경: \(change.after)").font(.mBodyB).foregroundStyle(Tokens.primary)
                        }
                    }
                }
                Section("적용 영향") { Text(impact).font(.mBody) }
                if let reason, !reason.isEmpty {
                    Section(reasonIsRecorded ? "서버에 기록할 사유" : "확인 메모") { Text(reason).font(.mBody) }
                } else if !reasonIsRecorded {
                    Section {
                        Text("이 작업에는 별도 사유가 저장되지 않습니다. 작업자와 변경 이력은 기존 기록 정책을 따릅니다.")
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isWorking)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("돌아가기", action: onCancel).disabled(isWorking) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "처리 중…" : actionTitle, role: destructive ? .destructive : nil, action: onConfirm)
                        .disabled(isWorking)
                }
            }
        }
    }
}
