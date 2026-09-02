import SwiftUI

@MainActor
final class AdminCommunityScreenModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case reports = "신고"
        case posts = "게시글"
        case comments = "댓글"
        case notices = "공지"
        var id: String { rawValue }
    }
    @Published var section: Section = .reports
    @Published var dashboard: ServerAPI.AdminCommunityDashboard?
    @Published var selectedID: String?
    @Published var search = ""
    @Published var board = ""
    @Published var status = ""
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    func load() async {
        isLoading = dashboard == nil; errorMessage = nil
        do { dashboard = try await ServerAPI.adminCommunity(board: board, status: status, search: search); keepSelection() }
        catch is CancellationError {} catch { errorMessage = readable(error) }
        isLoading = false
    }
    func apply(_ message: String, id: String, operation: () async throws -> ServerAPI.AdminCommunityDashboard) async {
        guard actionID == nil else { return }
        actionID = id; errorMessage = nil; noticeMessage = nil
        do { dashboard = try await operation(); noticeMessage = message; keepSelection() }
        catch { errorMessage = readable(error) }
        actionID = nil
    }
    func selectDefault() { selectedID = items.first?.id }
    private var items: [AnyIdentifiable] {
        guard let dashboard else { return [] }
        switch section {
        case .reports: return dashboard.reports.map { AnyIdentifiable(id: $0.id) }
        case .posts: return dashboard.posts.map { AnyIdentifiable(id: $0.id) }
        case .comments: return dashboard.comments.map { AnyIdentifiable(id: $0.id) }
        case .notices: return dashboard.notices.map { AnyIdentifiable(id: $0.id) }
        }
    }
    private func keepSelection() { if !items.contains(where: { $0.id == selectedID }) { selectDefault() } }
    private struct AnyIdentifiable { let id: String }
    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription
    }
}

struct AdminCommunityScreen: View {
    fileprivate enum Action: Identifiable {
        case createNotice
        case editNotice(ServerAPI.AdminCommunityNotice)
        case noticeStatus(ServerAPI.AdminCommunityNotice, String)
        case review(ServerAPI.AdminCommunityReport)
        case editPost(ServerAPI.AdminCommunityPost, String)
        case postStatus(ServerAPI.AdminCommunityPost, String, String)
        case commentStatus(ServerAPI.AdminCommunityComment, String)
        var id: String {
            switch self {
            case .createNotice: "create-notice"
            case .editNotice(let i): "edit-notice:\(i.id)"
            case .noticeStatus(let i, let a): "notice:\(i.id):\(a)"
            case .review(let i): "review:\(i.id)"
            case .editPost(let i, _): "edit-post:\(i.id)"
            case .postStatus(let i, let a, _): "post:\(i.id):\(a)"
            case .commentStatus(let i, let a): "comment:\(i.id):\(a)"
            }
        }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminCommunityScreenModel()
    @State private var action: Action?
    let onClose: () -> Void

    private var compactLandscape: Bool { verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = model.errorMessage { banner(error, Tokens.danger, "exclamationmark.triangle.fill") }
            else if let notice = model.noticeMessage { banner(notice, Tokens.success, "checkmark.circle.fill") }
            if model.isLoading && model.dashboard == nil { ProgressView("게시판 운영 데이터를 불러오는 중입니다").frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let dashboard = model.dashboard { dashboardView(dashboard) }
            else { failure }
        }
        .background(Tokens.paper)
        .task { await model.load() }
        .sheet(item: $action) { AdminCommunityActionSheet(action: $0, model: model) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) { Label("관리자 홈", systemImage: "chevron.left") }.buttonStyle(.bordered)
            Picker("관리 구역", selection: Binding(get: { model.section }, set: { value in model.section = value; model.selectDefault() })) {
                ForEach(AdminCommunityScreenModel.Section.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 500)
            Spacer()
            Button { Task { await model.load() } } label: { Label("새로고침", systemImage: "arrow.clockwise") }
                .buttonStyle(.bordered).disabled(model.isLoading || model.actionID != nil)
        }.font(.mBodyB).padding(.horizontal, 14).padding(.vertical, 9).background(Tokens.surface)
    }

    private func dashboardView(_ value: ServerAPI.AdminCommunityDashboard) -> some View {
        Group {
            if compactLandscape {
                HStack(alignment: .top, spacing: 12) {
                    ScrollView { list(value) }.frame(width: 400)
                    detail(value).frame(maxWidth: .infinity, maxHeight: .infinity)
                }.padding(12)
            } else {
                ScrollView { VStack(spacing: 16) { list(value); Divider(); detail(value) }.padding() }
            }
        }
    }

    @ViewBuilder private func list(_ value: ServerAPI.AdminCommunityDashboard) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            summary(value)
            if model.section == .posts {
                HStack {
                    TextField("제목·내용·작성자 검색", text: $model.search).textFieldStyle(.roundedBorder)
                    Button("검색") { Task { await model.load() } }.buttonStyle(.bordered)
                }
            }
            switch model.section {
            case .reports:
                if value.reports.isEmpty { empty("처리할 신고가 없습니다.") }
                ForEach(value.reports) { report in row(report.id) {
                    HStack { Text(report.post?.title ?? "삭제된 게시글").font(.mBodyB); Spacer(); badge(report.status) }
                    Text(report.reason).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(2)
                } }
            case .posts:
                if value.posts.isEmpty { empty("조건에 맞는 게시글이 없습니다.") }
                ForEach(value.posts) { post in row(post.id) {
                    HStack { Text(post.title).font(.mBodyB).lineLimit(1); Spacer(); badge(post.status) }
                    Text("\(post.author.name) · 경고 \(post.author.warningCount)회 · 조회 \(post.viewCount)").font(.mCaption).foregroundStyle(Tokens.text2)
                    Text(post.content).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(2)
                } }
            case .comments:
                if value.comments.isEmpty { empty("관리할 댓글이 없습니다.") }
                ForEach(value.comments) { comment in row(comment.id) {
                    HStack { Text(comment.author.name).font(.mBodyB); Spacer(); badge(comment.status) }
                    Text(comment.postTitle).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                    Text(comment.content).font(.mCaption).lineLimit(2)
                } }
            case .notices:
                Button { action = .createNotice } label: { Label("새 게시판 공지", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                ForEach(value.notices) { notice in row(notice.id) {
                    HStack { Text(notice.title).font(.mBodyB).lineLimit(1); Spacer(); badge(notice.status) }
                    Text("\(value.boardLabels[notice.boardType] ?? notice.boardType)\(notice.isPinned ? " · 상단 고정" : "")").font(.mCaption).foregroundStyle(Tokens.text2)
                } }
            }
        }
    }

    @ViewBuilder private func detail(_ value: ServerAPI.AdminCommunityDashboard) -> some View {
        switch model.section {
        case .reports: reportDetail(value.reports.first { $0.id == model.selectedID } ?? value.reports.first)
        case .posts: postDetail(value.posts.first { $0.id == model.selectedID } ?? value.posts.first)
        case .comments: commentDetail(value.comments.first { $0.id == model.selectedID } ?? value.comments.first)
        case .notices: noticeDetail(value.notices.first { $0.id == model.selectedID } ?? value.notices.first)
        }
    }

    @ViewBuilder private func reportDetail(_ report: ServerAPI.AdminCommunityReport?) -> some View {
        if let report {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 11) {
                        title(report.post?.title ?? "삭제된 게시글", "신고자 \(report.reporter.name) · 대상 \(report.reportedUser.name)")
                        field("신고 사유", report.reason)
                        if let post = report.post {
                            field("신고된 내용", post.content)
                            field("작성자 상태", "\(post.author.name) · \(post.author.role) · 경고 \(post.author.warningCount)회")
                        } else { field("원문 상태", "이미 삭제되어 게시글 조치를 실행할 수 없습니다.") }
                    }
                }
                Menu {
                    Button("신고 상태·판단 저장") { action = .review(report) }
                    if let post = report.post {
                        Button("게시글 수정") { action = .editPost(post, report.id) }
                        Button(post.isPinned ? "고정 해제" : "상단 고정") {
                            Task { await mutate("고정 상태를 변경했습니다.", id: post.id) { try await ServerAPI.pinAdminCommunityPost(id: post.id, pinned: !post.isPinned) } }
                        }
                        Button(post.status == "published" ? "게시글 숨기기" : "게시글 복구") {
                            action = .postStatus(post, post.status == "published" ? "hide" : "restore", report.id)
                        }
                        Button("글 숨김 + 작성자 경고") { action = .postStatus(post, "warn", report.id) }
                            .disabled(post.warningIssued || post.author.role == "admin")
                        Button("DB에서 게시글 삭제", role: .destructive) { action = .postStatus(post, "delete", report.id) }
                    }
                } label: { Label("신고 처리 작업", systemImage: "shield.lefthalf.filled").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).padding(10).background(.ultraThinMaterial)
            }
        } else { empty("왼쪽에서 신고를 선택하세요.") }
    }

    @ViewBuilder private func postDetail(_ post: ServerAPI.AdminCommunityPost?) -> some View {
        if let post {
            VStack(spacing: 0) {
                ScrollView { VStack(alignment: .leading, spacing: 11) {
                    title(post.title, "\(post.author.name) · 경고 \(post.author.warningCount)회")
                    HStack { badge(post.status); if post.isPinned { badge("상단 고정") }; if post.warningIssued { badge("경고 처리됨") } }
                    field("게시글 내용", post.content)
                    if !post.moderationReason.isEmpty { field("최근 처리 사유", post.moderationReason) }
                } }
                Menu {
                    Button("게시글 수정") { action = .editPost(post, "") }
                    Button(post.isPinned ? "고정 해제" : "상단 고정") {
                        Task { await mutate("고정 상태를 변경했습니다.", id: post.id) { try await ServerAPI.pinAdminCommunityPost(id: post.id, pinned: !post.isPinned) } }
                    }
                    Button(post.status == "published" ? "게시글 숨기기" : "게시글 복구") { action = .postStatus(post, post.status == "published" ? "hide" : "restore", "") }
                    Button("글 숨김 + 경고", role: .destructive) { action = .postStatus(post, "warn", "") }
                        .disabled(post.warningIssued || post.author.role == "admin")
                    Button("DB에서 삭제", role: .destructive) { action = .postStatus(post, "delete", "") }
                } label: { Label("게시글 관리", systemImage: "ellipsis.circle").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).padding(10).background(.ultraThinMaterial)
            }
        } else { empty("왼쪽에서 게시글을 선택하세요.") }
    }

    @ViewBuilder private func commentDetail(_ comment: ServerAPI.AdminCommunityComment?) -> some View {
        if let comment {
            VStack(spacing: 0) {
                ScrollView { VStack(alignment: .leading, spacing: 11) {
                    title(comment.author.name, comment.postTitle)
                    HStack { badge(comment.status); if comment.warningIssued { badge("경고 처리됨") } }
                    field("댓글", comment.content)
                    if !comment.moderationReason.isEmpty { field("최근 처리 사유", comment.moderationReason) }
                } }
                Menu {
                    Button(comment.status == "published" ? "댓글 숨기기" : "댓글 복구") { action = .commentStatus(comment, comment.status == "published" ? "hide" : "restore") }
                    Button("숨김 + 작성자 경고", role: .destructive) { action = .commentStatus(comment, "warn") }
                        .disabled(comment.warningIssued || comment.author.role == "admin")
                    Button("DB에서 댓글 삭제", role: .destructive) { action = .commentStatus(comment, "delete") }
                } label: { Label("댓글 관리", systemImage: "ellipsis.circle").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).padding(10).background(.ultraThinMaterial)
            }
        } else { empty("왼쪽에서 댓글을 선택하세요.") }
    }

    @ViewBuilder private func noticeDetail(_ notice: ServerAPI.AdminCommunityNotice?) -> some View {
        if let notice {
            VStack(spacing: 0) {
                ScrollView { VStack(alignment: .leading, spacing: 11) {
                    title(notice.title, notice.schoolName.isEmpty ? notice.boardType : notice.schoolName)
                    HStack { badge(notice.status); if notice.isPinned { badge("상단 고정") }; if notice.isSystem { badge("기본 운영 공지") } }
                    field("공지 내용", notice.content)
                } }
                Menu {
                    Button("공지 수정") { action = .editNotice(notice) }
                    Button(notice.isPinned ? "고정 해제" : "상단 고정") {
                        Task { await mutate("공지 고정 상태를 변경했습니다.", id: notice.id) { try await ServerAPI.pinAdminCommunityNotice(id: notice.id, pinned: !notice.isPinned) } }
                    }.disabled(notice.status != "published")
                    Button(notice.status == "published" ? "공지 숨기기" : "공지 복구") { action = .noticeStatus(notice, notice.status == "published" ? "hide" : "restore") }
                    Button("공지 삭제", role: .destructive) { action = .noticeStatus(notice, "delete") }.disabled(notice.status == "deleted")
                } label: { Label("공지 관리", systemImage: "ellipsis.circle").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).padding(10).background(.ultraThinMaterial)
            }
        } else { empty("왼쪽에서 공지를 선택하거나 새 공지를 작성하세요.") }
    }

    private func mutate(_ message: String, id: String, operation: @escaping () async throws -> ServerAPI.AdminCommunityDashboard) async {
        await model.apply(message, id: id, operation: operation)
    }
    private func summary(_ value: ServerAPI.AdminCommunityDashboard) -> some View {
        HStack { mini("신고", value.reports.count); mini("공개", value.stats.published); mini("숨김", value.stats.hidden); mini("삭제", value.stats.deleted) }
    }
    private func mini(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) { Text("\(value)").font(.mBodyB); Text(label).font(.mMicro).foregroundStyle(Tokens.text2) }
            .padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 9))
    }
    private func row<Content: View>(_ id: String, @ViewBuilder content: () -> Content) -> some View {
        Button { model.selectedID = id } label: {
            VStack(alignment: .leading, spacing: 5, content: content).padding(11).frame(maxWidth: .infinity, alignment: .leading)
                .background(model.selectedID == id ? Tokens.primary.opacity(0.1) : Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
    private func title(_ value: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) { Text(value).font(.mTitle); Text(subtitle).font(.mCaption).foregroundStyle(Tokens.text2) }
    }
    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(label).font(.mCaption).foregroundStyle(Tokens.text2); Text(value.isEmpty ? "—" : value).font(.mBody).textSelection(.enabled) }
            .padding(11).frame(maxWidth: .infinity, alignment: .leading).background(Tokens.surface, in: RoundedRectangle(cornerRadius: 12))
    }
    private func badge(_ value: String) -> some View {
        Text(value).font(.mCaption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4).foregroundStyle(Tokens.primary).background(Tokens.primary.opacity(0.1), in: Capsule())
    }
    private func empty(_ value: String) -> some View { Text(value).font(.mBody).foregroundStyle(Tokens.text2).frame(maxWidth: .infinity, minHeight: 100).multilineTextAlignment(.center) }
    private func banner(_ value: String, _ color: Color, _ icon: String) -> some View {
        Label(value, systemImage: icon).font(.mCaption).foregroundStyle(color).padding(.horizontal, 16).padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading).background(color.opacity(0.1))
    }
    private var failure: some View { VStack { Text(model.errorMessage ?? "게시판 데이터를 불러오지 못했습니다."); Button("다시 시도") { Task { await model.load() } } }.frame(maxWidth: .infinity, maxHeight: .infinity) }
}

private struct AdminCommunityActionSheet: View {
    let action: AdminCommunityScreen.Action
    @ObservedObject var model: AdminCommunityScreenModel
    @Environment(\.dismiss) private var dismiss
    @State private var board = "high-school"
    @State private var schoolCode = ""
    @State private var schoolName = ""
    @State private var universityCode = ""
    @State private var universityName = ""
    @State private var title = ""
    @State private var content = ""
    @State private var reason = ""
    @State private var reportStatus = "reviewing"
    @State private var confirms = false

    var body: some View {
        NavigationStack {
            Form { fields; Section { Button("입력 내용 확인") { confirms = true }.disabled(!valid) } }
                .navigationTitle(sheetTitle)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
                .confirmationDialog("최종 처리할까요?", isPresented: $confirms, titleVisibility: .visible) {
                    Button(confirmLabel, role: destructive ? .destructive : nil) { Task { await submit(); if model.errorMessage == nil { dismiss() } } }
                    Button("취소", role: .cancel) {}
                } message: { Text("조치 내용은 작성자 알림과 관리자 감사 기록에 남을 수 있습니다.") }
        }.presentationDetents([.medium, .large]).onAppear { seed() }
    }
    @ViewBuilder private var fields: some View {
        switch action {
        case .createNotice, .editNotice:
            Picker("대상 게시판", selection: $board) {
                Text("통합 게시판").tag("high-school"); Text("학교 게시판").tag("school"); Text("N수생 게시판").tag("retaker"); Text("대학교 게시판").tag("university"); Text("직장인 게시판").tag("worker")
            }
            if board == "school" { TextField("학교 코드 (전체면 비움)", text: $schoolCode); TextField("학교 이름", text: $schoolName) }
            if board == "university" { TextField("대학교 코드 (전체면 비움)", text: $universityCode); TextField("대학교 이름", text: $universityName) }
            TextField("제목", text: $title)
            TextField("내용", text: $content, axis: .vertical).lineLimit(5...12)
        case .review:
            Picker("처리 상태", selection: $reportStatus) { Text("검토 중").tag("reviewing"); Text("처리 완료").tag("resolved"); Text("신고 반려").tag("rejected") }
            TextField("판단 근거", text: $reason, axis: .vertical).lineLimit(3...8)
        case .editPost:
            TextField("제목", text: $title)
            TextField("내용", text: $content, axis: .vertical).lineLimit(5...12)
            TextField("수정 사유", text: $reason, axis: .vertical).lineLimit(2...5)
        case .noticeStatus(_, let status):
            Text(status == "delete" ? "공지와 공개 링크가 삭제 상태로 전환됩니다." : "공지 공개 상태를 변경합니다.")
        case .postStatus(let post, let status, _):
            Text(status == "warn" ? "글을 숨기고 \(post.author.name)의 경고를 1회 올립니다. 3회 누적이면 계정도 정지됩니다." : status == "delete" ? "게시글을 DB 삭제 상태로 전환합니다." : "게시글 공개 상태를 변경합니다.")
            TextField("처리 사유", text: $reason, axis: .vertical).lineLimit(3...7)
        case .commentStatus(let comment, let status):
            Text(status == "warn" ? "댓글을 숨기고 \(comment.author.name)의 경고를 1회 올립니다." : "댓글 상태를 변경합니다.")
            TextField("처리 사유", text: $reason, axis: .vertical).lineLimit(3...7)
        }
    }
    private var sheetTitle: String {
        switch action { case .createNotice: "새 공지"; case .editNotice: "공지 수정"; case .noticeStatus: "공지 상태"; case .review: "신고 판단"; case .editPost: "게시글 수정"; case .postStatus: "게시글 조치"; case .commentStatus: "댓글 조치" }
    }
    private var destructive: Bool {
        switch action {
        case .noticeStatus(_, let a), .postStatus(_, let a, _), .commentStatus(_, let a): ["delete", "warn"].contains(a)
        default: false
        }
    }
    private var confirmLabel: String { destructive ? "조치 실행" : "저장" }
    private var valid: Bool {
        switch action {
        case .createNotice, .editNotice: return title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        case .review: return reportStatus == "reviewing" || !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .editPost: return title.count >= 2 && content.count >= 2 && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .noticeStatus: return true
        case .postStatus, .commentStatus: return !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    private func seed() {
        switch action {
        case .editNotice(let i): board = i.boardType; schoolCode = i.schoolCode; schoolName = i.schoolName; universityCode = i.universityCode; universityName = i.universityName; title = i.title; content = i.content
        case .editPost(let i, _): title = i.title; content = i.content
        case .review(let i): reportStatus = i.status; reason = i.resolution
        default: break
        }
    }
    private func submit() async {
        switch action {
        case .createNotice:
            await model.apply("게시판 공지를 만들고 상단 고정했습니다.", id: "new-notice") { try await ServerAPI.createAdminCommunityNotice(board: board, schoolCode: schoolCode, schoolName: schoolName, universityCode: universityCode, universityName: universityName, title: title, content: content) }
        case .editNotice(let i):
            await model.apply("공지 내용을 저장했습니다.", id: i.id) { try await ServerAPI.updateAdminCommunityNotice(i, board: board, schoolCode: schoolCode, schoolName: schoolName, universityCode: universityCode, universityName: universityName, title: title, content: content) }
        case .noticeStatus(let i, let a):
            await model.apply("공지 상태를 변경했습니다.", id: i.id) { try await ServerAPI.moderateAdminCommunityNotice(id: i.id, action: a) }
        case .review(let i):
            await model.apply("신고 판단을 저장했습니다.", id: i.id) { try await ServerAPI.reviewAdminCommunityReport(id: i.id, status: reportStatus, resolution: reason) }
        case .editPost(let i, _):
            await model.apply("게시글을 관리자 수정했습니다.", id: i.id) { try await ServerAPI.editAdminCommunityPost(id: i.id, title: title, content: content, reason: reason) }
        case .postStatus(let i, let a, let reportID):
            if a == "warn" { await model.apply("게시글 숨김과 작성자 경고를 처리했습니다.", id: i.id) { try await ServerAPI.warnAdminCommunityPost(id: i.id, reason: reason, reportID: reportID) } }
            else { await model.apply("게시글 상태를 변경했습니다.", id: i.id) { try await ServerAPI.moderateAdminCommunityPost(id: i.id, action: a, reason: reason, reportID: reportID) } }
        case .commentStatus(let i, let a):
            if a == "warn" { await model.apply("댓글 숨김과 작성자 경고를 처리했습니다.", id: i.id) { try await ServerAPI.warnAdminCommunityComment(id: i.id, reason: reason) } }
            else { await model.apply("댓글 상태를 변경했습니다.", id: i.id) { try await ServerAPI.moderateAdminCommunityComment(id: i.id, action: a, reason: reason) } }
        }
    }
}
