import SwiftUI

@MainActor
final class SupportInquiryScreenModel: ObservableObject {
    @Published var dashboard: ServerAPI.SupportDashboard?
    @Published var subject = ""
    @Published var content = ""
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private var generation = UUID()

    func load(reset: Bool = false) async {
        if reset {
            generation = UUID()
            dashboard = nil
        }
        let requestGeneration = generation
        isLoading = dashboard == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.supportDashboard()
            guard requestGeneration == generation else { return }
            dashboard = value
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation { isLoading = false }
    }

    func submit() async {
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...120).contains(cleanSubject.count) else {
            errorMessage = "제목을 2~120자로 입력해 주세요."
            return
        }
        guard (10...5000).contains(cleanContent.count) else {
            errorMessage = "내용을 10~5000자로 입력해 주세요."
            return
        }
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        noticeMessage = nil
        do {
            let value = try await ServerAPI.createSupportInquiry(
                subject: cleanSubject, content: cleanContent)
            dashboard = value
            subject = ""
            content = ""
            noticeMessage = value.submission?.emailStatus == "failed"
                ? "문의는 저장됐습니다. 운영팀 이메일 알림은 재확인 중입니다."
                : "문의를 접수했습니다. 답변은 가입 이메일로 전달됩니다."
        } catch {
            errorMessage = readable(error)
        }
        isSubmitting = false
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

struct SupportInquiryScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = SupportInquiryScreenModel()

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { viewport in
            Group {
                if model.isLoading && model.dashboard == nil {
                    stateShell {
                        ProgressView().tint(Tokens.primary)
                        Text("문의 내역을 불러오는 중입니다").font(.mHeading)
                    }
                } else if let dashboard = model.dashboard {
                    content(dashboard, viewport: viewport)
                } else {
                    failureState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.paper)
        .task { if model.dashboard == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.load(reset: true) }
        }
    }

    @ViewBuilder
    private func content(_ dashboard: ServerAPI.SupportDashboard, viewport: GeometryProxy) -> some View {
        if compactLandscape {
            HStack(alignment: .top, spacing: Tokens.Space.s3) {
                composer(dashboard.contact)
                    .frame(width: min(340, viewport.size.width * 0.40))
                inquiryList(dashboard)
            }
            .padding(.horizontal, max(12, viewport.safeAreaInsets.leading + 12))
            .padding(.vertical, Tokens.Space.s2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    pageHeader
                    composer(dashboard.contact)
                    inquiryList(dashboard, ownsScroll: false)
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .refreshable { await model.load() }
        }
    }

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("문의하기").font(.mTitle).foregroundStyle(Tokens.ink)
                Text("접수 상태를 확인하고 답변은 가입 이메일로 받습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Spacer()
            closeButton
        }
    }

    private func composer(_ contact: ServerAPI.SupportContact) -> some View {
        VStack(alignment: .leading, spacing: compactLandscape ? 7 : Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("새 문의").font(.mHeading).foregroundStyle(Tokens.ink)
                    Text(contact.email.isEmpty ? "가입 이메일을 확인해 주세요." : contact.email)
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s2)
                if compactLandscape { closeButton }
            }

            TextField("제목", text: $model.subject)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("문의 제목")

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $model.content)
                    .font(.mBody)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(height: compactLandscape ? 72 : 150)
                    .background(Tokens.paper,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm,
                                                     style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                            .strokeBorder(model.content.count > 5000 ? Tokens.danger : Tokens.line,
                                          lineWidth: 1)
                    }
                    .accessibilityLabel("문의 내용")
                if model.content.isEmpty {
                    Text("문제를 재현한 순서와 원하는 도움을 적어 주세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                        .padding(.leading, 12).padding(.top, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .allowsHitTesting(false)
                }
                Text("\(model.content.count)/5000")
                    .font(.mMicro.monospacedDigit())
                    .foregroundStyle(model.content.count > 5000 ? Tokens.danger : Tokens.text3)
                    .padding(8).allowsHitTesting(false)
            }

            submitButton
            feedbackText
        }
        .supportInquirySurface()
    }

    @ViewBuilder private var submitButton: some View {
        let disabled = model.isSubmitting
            || !(2...120).contains(model.subject.trimmingCharacters(in: .whitespacesAndNewlines).count)
            || !(10...5000).contains(model.content.trimmingCharacters(in: .whitespacesAndNewlines).count)
        if compactLandscape {
            Button { Task { await model.submit() } } label: {
                if model.isSubmitting { ProgressView().tint(Tokens.onBrand) }
                else { Text("문의 접수") }
            }
            .buttonStyle(.borderedProminent).tint(Tokens.actionPrimary)
            .frame(maxWidth: .infinity, minHeight: 44).disabled(disabled)
        } else {
            Button { Task { await model.submit() } } label: {
                if model.isSubmitting { ProgressView().tint(Tokens.onBrand) }
                else { Text("문의 접수") }
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(disabled)
        }
    }

    @ViewBuilder
    private func inquiryList(_ dashboard: ServerAPI.SupportDashboard, ownsScroll: Bool = true) -> some View {
        let content = VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("접수 내역").font(.mHeading).foregroundStyle(Tokens.ink)
                    Text("답변 완료 시 \(dashboard.contact.email.isEmpty ? "가입 이메일" : dashboard.contact.email)로 발송")
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: Tokens.Space.s2)
                Menu {
                    Button("자주 묻는 질문") { store.openHostedPortal(.faq) }
                    Button("App Store 결제·환불") { store.route = .commerce }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                }
                .foregroundStyle(Tokens.primary)
                .accessibilityLabel("문의 도움말")
                Button { Task { await model.load() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                .accessibilityLabel("문의 내역 새로고침")
            }

            if dashboard.inquiries.isEmpty {
                VStack(spacing: Tokens.Space.s2) {
                    Image(systemName: "checkmark.bubble.fill")
                        .font(.system(size: 28, weight: .semibold)).foregroundStyle(Tokens.text3)
                    Text("접수한 문의가 없습니다.").font(.mBodyB).foregroundStyle(Tokens.ink)
                    Text("왼쪽 입력창에서 바로 운영팀에 문의할 수 있습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                LazyVStack(spacing: Tokens.Space.s2) {
                    ForEach(dashboard.inquiries) { inquiry in inquiryRow(inquiry) }
                }
            }
        }
        .supportInquirySurface()

        if ownsScroll {
            ScrollView { content }.refreshable { await model.load() }
        } else {
            content
        }
    }

    private func inquiryRow(_ inquiry: ServerAPI.SupportInquiry) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Image(systemName: statusIcon(inquiry.status))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(statusColor(inquiry.status))
                .frame(width: 36, height: 36)
                .background(statusColor(inquiry.status).opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(inquiry.subject).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                Text(inquiry.status == "replied" ? "가입 이메일로 답변을 보냈습니다." : statusDetail(inquiry.status))
                    .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
            }
            Spacer(minLength: Tokens.Space.s2)
            Text(statusLabel(inquiry.status))
                .font(.mMicro).foregroundStyle(statusColor(inquiry.status))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(statusColor(inquiry.status).opacity(0.10), in: Capsule())
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
    }

    private var closeButton: some View {
        Button { store.route = .services } label: {
            Image(systemName: "xmark").frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).foregroundStyle(Tokens.text3)
        .accessibilityLabel("문의 화면 닫기")
    }

    @ViewBuilder private var feedbackText: some View {
        if let message = model.errorMessage {
            Text(message).font(.mCaption).foregroundStyle(Tokens.danger)
                .fixedSize(horizontal: false, vertical: true)
        } else if let message = model.noticeMessage {
            Text(message).font(.mCaption).foregroundStyle(Tokens.success)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var failureState: some View {
        stateShell {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .semibold)).foregroundStyle(Tokens.danger)
            Text("문의 내역을 열지 못했습니다").font(.mHeading)
            Text(model.errorMessage ?? "잠시 후 다시 시도해 주세요.")
                .font(.mCaption).foregroundStyle(Tokens.text2).multilineTextAlignment(.center)
            Button("다시 시도") { Task { await model.load() } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func stateShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: Tokens.Space.s3) { content() }
            .padding(Tokens.Space.s5).frame(maxWidth: 460).supportInquirySurface()
    }

    private func statusLabel(_ status: String) -> String {
        switch status { case "in_review": "확인 중"; case "replied": "답변 완료"; case "closed": "종료"; default: "접수됨" }
    }

    private func statusDetail(_ status: String) -> String {
        switch status { case "in_review": "운영팀이 문의를 확인하고 있습니다."; case "closed": "처리가 종료된 문의입니다."; default: "운영팀 접수를 기다리고 있습니다." }
    }

    private func statusIcon(_ status: String) -> String {
        switch status { case "in_review": "eye.fill"; case "replied": "envelope.badge.fill"; case "closed": "checkmark.circle.fill"; default: "tray.full.fill" }
    }

    private func statusColor(_ status: String) -> Color {
        switch status { case "replied", "closed": Tokens.success; case "in_review": Tokens.primary; default: Tokens.text3 }
    }
}

private struct SupportInquirySurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s4)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func supportInquirySurface() -> some View { modifier(SupportInquirySurface()) }
}
