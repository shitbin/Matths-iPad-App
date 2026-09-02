import SwiftUI

@MainActor
final class AdminOperationsScreenModel: ObservableObject {
    @Published var dashboard: ServerAPI.AdminOperationsDashboard?
    @Published var todos: ServerAPI.AdminOperationsTodoPage?
    @Published var inquiries: ServerAPI.AdminOperationsInquiryPage?
    @Published var announcements: ServerAPI.AdminOperationsAnnouncementList?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    func loadAll(todoStatus: String, todoCategory: String, inquiryStatus: String,
                 announcementStatus: String) async {
        isLoading = dashboard == nil
        errorMessage = nil
        do {
            async let dashboardValue = ServerAPI.adminOperationsDashboard()
            async let todoValue = ServerAPI.adminOperationsTodos(
                category: todoCategory, status: todoStatus)
            async let inquiryValue = ServerAPI.adminOperationsInquiries(status: inquiryStatus)
            async let announcementValue = ServerAPI.adminOperationsAnnouncements(status: announcementStatus)
            let values = try await (dashboardValue, todoValue, inquiryValue, announcementValue)
            dashboard = values.0
            todos = values.1
            inquiries = values.2
            announcements = values.3
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
        isLoading = false
    }

    func loadTodos(status: String, category: String, page: Int = 1) async {
        do {
            todos = try await ServerAPI.adminOperationsTodos(
                category: category, status: status, page: page)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
    }

    func loadInquiries(status: String, page: Int = 1) async {
        do {
            inquiries = try await ServerAPI.adminOperationsInquiries(status: status, page: page)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
    }

    func loadAnnouncements(status: String) async {
        do {
            announcements = try await ServerAPI.adminOperationsAnnouncements(status: status)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
    }

    func createAnnouncement(title: String, content: String, category: String,
                            publishNow: Bool, dashboardEndDate: String,
                            visibleStatus: String) async -> Bool {
        guard actionID == nil else { return false }
        actionID = "announcement:new"
        errorMessage = nil
        var succeeded = false
        do {
            _ = try await ServerAPI.createAdminAnnouncement(
                title: title, content: content, category: category,
                publishNow: publishNow, dashboardEndDate: dashboardEndDate)
            noticeMessage = publishNow ? "공지를 등록하고 공개했습니다." : "공지 초안을 저장했습니다."
            await loadAnnouncements(status: visibleStatus)
            dashboard = try? await ServerAPI.adminOperationsDashboard()
            succeeded = true
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
        return succeeded
    }

    func setAnnouncementPublished(_ announcement: ServerAPI.AdminOperationsAnnouncement,
                                  published: Bool, visibleStatus: String) async {
        guard actionID == nil else { return }
        actionID = announcement.id
        errorMessage = nil
        do {
            try await ServerAPI.setAdminAnnouncementPublished(id: announcement.id, published: published)
            noticeMessage = published ? "공지를 공개했습니다." : "공지를 비공개로 전환했습니다."
            await loadAnnouncements(status: visibleStatus)
            dashboard = try? await ServerAPI.adminOperationsDashboard()
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func setTodo(_ todo: ServerAPI.AdminOperationsTodo, completed: Bool,
                 status: String, category: String) async {
        guard actionID == nil else { return }
        actionID = todo.id
        errorMessage = nil
        do {
            try await ServerAPI.setAdminTodo(id: todo.id, completed: completed)
            noticeMessage = completed ? "운영 할 일을 완료했습니다." : "운영 할 일을 다시 열었습니다."
            await loadTodos(status: status, category: category)
            dashboard = try? await ServerAPI.adminOperationsDashboard()
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func setInquiryStatus(_ inquiry: ServerAPI.AdminOperationsInquiry, status: String,
                          visibleStatus: String) async {
        guard actionID == nil else { return }
        actionID = inquiry.id
        errorMessage = nil
        do {
            try await ServerAPI.updateAdminInquiryStatus(id: inquiry.id, status: status)
            noticeMessage = "문의 상태를 변경했습니다."
            await loadInquiries(status: visibleStatus)
            dashboard = try? await ServerAPI.adminOperationsDashboard()
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func reply(_ inquiry: ServerAPI.AdminOperationsInquiry, message: String,
               visibleStatus: String) async -> Bool {
        guard actionID == nil else { return false }
        actionID = inquiry.id
        errorMessage = nil
        var succeeded = false
        do {
            let delivered = try await ServerAPI.replyToAdminInquiry(id: inquiry.id, message: message)
            noticeMessage = delivered
                ? "답변 이메일을 전송했습니다."
                : "답변을 저장했지만 메일 전송 결과를 확인해야 합니다."
            await loadInquiries(status: visibleStatus)
            dashboard = try? await ServerAPI.adminOperationsDashboard()
            succeeded = true
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
        return succeeded
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

struct AdminOperationsScreen: View {
    private enum Section: String, CaseIterable, Identifiable {
        case todos = "할 일"
        case inquiries = "문의"
        case announcements = "공지"
        var id: String { rawValue }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminOperationsScreenModel()
    @State private var section: Section = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-adminAnnouncements") { return .announcements }
        if ProcessInfo.processInfo.arguments.contains("-adminInquiries") { return .inquiries }
        #endif
        return .todos
    }()
    @State private var todoStatus = "pending"
    @State private var todoCategory = ""
    @State private var inquiryStatus = "pending"
    @State private var announcementStatus = "all"
    @State private var selectedTodoID: String?
    @State private var selectedInquiryID: String?
    @State private var selectedAnnouncementID: String?
    @State private var replyTarget: ServerAPI.AdminOperationsInquiry?
    @State private var showsAnnouncementComposer = false

    let onClose: () -> Void

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    private var selectedTodo: ServerAPI.AdminOperationsTodo? {
        let values = model.todos?.items ?? []
        return values.first(where: { $0.id == selectedTodoID }) ?? values.first
    }

    private var selectedInquiry: ServerAPI.AdminOperationsInquiry? {
        let values = model.inquiries?.items ?? []
        return values.first(where: { $0.id == selectedInquiryID }) ?? values.first
    }

    private var selectedAnnouncement: ServerAPI.AdminOperationsAnnouncement? {
        let values = model.announcements?.items ?? []
        return values.first(where: { $0.id == selectedAnnouncementID }) ?? values.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            feedback
            if model.isLoading && model.dashboard == nil {
                Spacer()
                ProgressView("운영 업무를 불러오는 중입니다")
                    .tint(Tokens.primary)
                Spacer()
            } else if model.dashboard == nil, let error = model.errorMessage {
                failure(error)
            } else {
                content
            }
        }
        .background(Tokens.paper)
        .task {
            if model.dashboard == nil {
                await model.loadAll(
                    todoStatus: todoStatus,
                    todoCategory: todoCategory,
                    inquiryStatus: inquiryStatus,
                    announcementStatus: announcementStatus)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            model.dashboard = nil
            model.todos = nil
            model.inquiries = nil
            model.announcements = nil
            Task {
                await model.loadAll(
                    todoStatus: todoStatus,
                    todoCategory: todoCategory,
                    inquiryStatus: inquiryStatus,
                    announcementStatus: announcementStatus)
            }
        }
        .sheet(item: $replyTarget) { inquiry in
            AdminInquiryReplySheet(inquiry: inquiry) { message in
                await model.reply(inquiry, message: message, visibleStatus: inquiryStatus)
            }
        }
        .sheet(isPresented: $showsAnnouncementComposer) {
            AdminAnnouncementComposer { title, content, category, publishNow, endDate in
                await model.createAnnouncement(
                    title: title, content: content, category: category,
                    publishNow: publishNow, dashboardEndDate: endDate,
                    visibleStatus: announcementStatus)
            }
        }
    }

    private var header: some View {
        VStack(spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s3) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .accessibilityLabel("학원 승인함으로 돌아가기")

                VStack(alignment: .leading, spacing: 1) {
                    Text("운영 업무").font(.mHeading).foregroundStyle(Tokens.ink)
                    if let dashboard = model.dashboard {
                        Text("대기 \(dashboard.pendingTodoCount)건 · 문의 \(dashboard.stats.pendingInquiries ?? 0)건")
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                }
                Spacer()
                Button {
                    Task {
                        await model.loadAll(
                            todoStatus: todoStatus,
                            todoCategory: todoCategory,
                            inquiryStatus: inquiryStatus,
                            announcementStatus: announcementStatus)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.primary)
                .accessibilityLabel("운영 업무 새로고침")
            }

            Picker("운영 업무 종류", selection: $section) {
                ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, Tokens.Space.s3)
        .padding(.top, Tokens.Space.s2)
        .padding(.bottom, Tokens.Space.s3)
        .background(Tokens.surface)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder
    private var content: some View {
        if compactLandscape {
            HStack(spacing: 0) {
                listColumn
                    .frame(width: 350)
                Divider()
                detailColumn
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    listColumn
                    detailColumn
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding()
                .adaptiveVPadding()
            }
            .refreshable {
                await model.loadAll(
                    todoStatus: todoStatus,
                    todoCategory: todoCategory,
                    inquiryStatus: inquiryStatus,
                    announcementStatus: announcementStatus)
            }
        }
    }

    @ViewBuilder
    private var listColumn: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if section == .todos {
                todoFilters
            } else if section == .inquiries {
                inquiryFilters
            } else {
                announcementFilters
            }
            if currentItemsAreEmpty {
                emptyState
            } else if compactLandscape {
                ScrollView { itemRows }
            } else {
                itemRows
            }
            pagination
        }
        .padding(Tokens.Space.s3)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var itemRows: some View {
        LazyVStack(spacing: Tokens.Space.s2) {
            if section == .todos {
                ForEach(model.todos?.items ?? []) { todoRow($0) }
            } else if section == .inquiries {
                ForEach(model.inquiries?.items ?? []) { inquiryRow($0) }
            } else {
                ForEach(model.announcements?.items ?? []) { announcementRow($0) }
            }
        }
        .padding(.bottom, Tokens.Space.s3)
    }

    private var todoFilters: some View {
        HStack(spacing: Tokens.Space.s2) {
            Menu(todoStatus == "pending" ? "대기" : "완료") {
                Button("대기") { changeTodoFilter(status: "pending", category: todoCategory) }
                Button("완료") { changeTodoFilter(status: "completed", category: todoCategory) }
            }
            Menu(todoCategoryLabel) {
                Button("전체 종류") { changeTodoFilter(status: todoStatus, category: "") }
                Button("문의") { changeTodoFilter(status: todoStatus, category: "inquiry") }
                Button("신고") { changeTodoFilter(status: todoStatus, category: "community-report") }
                Button("무결성") { changeTodoFilter(status: todoStatus, category: "integrity") }
                Button("기타") { changeTodoFilter(status: todoStatus, category: "other") }
            }
            Spacer()
            Text("\(model.todos?.pagination.total ?? 0)건")
                .font(.mCaption.monospacedDigit()).foregroundStyle(Tokens.text2)
        }
        .buttonStyle(.bordered)
    }

    private var inquiryFilters: some View {
        HStack(spacing: Tokens.Space.s2) {
            Menu(inquiryStatusLabel(inquiryStatus)) {
                Button("대기") { changeInquiryFilter("pending") }
                Button("검토 중") { changeInquiryFilter("in_review") }
                Button("답변 완료") { changeInquiryFilter("replied") }
                Button("종료") { changeInquiryFilter("closed") }
                Button("전체") { changeInquiryFilter("all") }
            }
            .buttonStyle(.bordered)
            Spacer()
            Text("\(model.inquiries?.pagination.total ?? 0)건")
                .font(.mCaption.monospacedDigit()).foregroundStyle(Tokens.text2)
        }
    }

    private var announcementFilters: some View {
        HStack(spacing: Tokens.Space.s2) {
            Menu(announcementStatusLabel) {
                Button("전체") { changeAnnouncementFilter("all") }
                Button("공개") { changeAnnouncementFilter("published") }
                Button("초안") { changeAnnouncementFilter("draft") }
            }
            .buttonStyle(.bordered)
            Spacer()
            Text("\(model.announcements?.items.count ?? 0)건")
                .font(.mCaption.monospacedDigit()).foregroundStyle(Tokens.text2)
            Button("새 공지") { showsAnnouncementComposer = true }
                .buttonStyle(.borderedProminent)
                .disabled(model.actionID != nil)
        }
    }

    private func todoRow(_ todo: ServerAPI.AdminOperationsTodo) -> some View {
        Button {
            selectedTodoID = todo.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(categoryLabel(todo.category)).font(.mMicro).foregroundStyle(Tokens.primary)
                    Spacer()
                    Text(relativeDate(todo.createdAt)).font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Text(todo.title).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                if !todo.description.isEmpty {
                    Text(todo.description).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(2)
                }
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedTodo?.id == todo.id ? Tokens.primary.opacity(0.12) : Tokens.surface,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("세부 내용과 처리 버튼을 표시합니다")
    }

    private func inquiryRow(_ inquiry: ServerAPI.AdminOperationsInquiry) -> some View {
        Button {
            selectedInquiryID = inquiry.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(inquiryStatusLabel(inquiry.status)).font(.mMicro).foregroundStyle(Tokens.primary)
                    Spacer()
                    Text(relativeDate(inquiry.createdAt)).font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Text(inquiry.subject).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                Text(inquiry.contactEmail).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedInquiry?.id == inquiry.id ? Tokens.primary.opacity(0.12) : Tokens.surface,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("문의 내용과 답변 도구를 표시합니다")
    }

    private func announcementRow(_ announcement: ServerAPI.AdminOperationsAnnouncement) -> some View {
        Button {
            selectedAnnouncementID = announcement.id
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(announcement.isPublished ? "공개" : "초안")
                        .font(.mMicro).foregroundStyle(announcement.isPublished ? Tokens.successInk : Tokens.text2)
                    Spacer()
                    Text(relativeDate(announcement.createdAt)).font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Text(announcement.title).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(2)
                Text(announcementCategoryLabel(announcement.boardCategory))
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedAnnouncement?.id == announcement.id ? Tokens.primary.opacity(0.12) : Tokens.surface,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("공지 내용과 공개 설정을 표시합니다")
    }

    @ViewBuilder
    private var detailColumn: some View {
        if compactLandscape {
            VStack(spacing: 0) {
                ScrollView {
                    detailBody.padding(Tokens.Space.s3)
                }
                pinnedDetailAction
            }
        } else {
            VStack(spacing: 0) {
                detailBody.padding(Tokens.Space.s4)
                pinnedDetailAction
            }
        }
    }

    @ViewBuilder
    private var detailBody: some View {
        if section == .todos, let todo = selectedTodo {
            todoDetail(todo)
        } else if section == .inquiries, let inquiry = selectedInquiry {
            inquiryDetail(inquiry)
        } else if section == .announcements, let announcement = selectedAnnouncement {
            announcementDetail(announcement)
        } else {
            VStack(spacing: Tokens.Space.s2) {
                Image(systemName: "tray")
                Text("처리할 항목을 선택하세요").font(.mBodyB)
            }
            .foregroundStyle(Tokens.text2)
            .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    @ViewBuilder
    private var pinnedDetailAction: some View {
        if selectedTodo != nil || selectedInquiry != nil || selectedAnnouncement != nil {
            Divider()
            detailAction
                .padding(.horizontal, Tokens.Space.s3)
                .padding(.vertical, Tokens.Space.s2)
                .background(Tokens.surface)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    @ViewBuilder
    private var detailAction: some View {
        if section == .todos, let todo = selectedTodo {
            if todo.status == "pending" {
                Button("완료 처리") {
                    Task {
                        await model.setTodo(
                            todo, completed: true,
                            status: todoStatus, category: todoCategory)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.actionID != nil)
            } else {
                Button("다시 열기") {
                    Task {
                        await model.setTodo(
                            todo, completed: false,
                            status: todoStatus, category: todoCategory)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(model.actionID != nil)
            }
        } else if section == .inquiries, let inquiry = selectedInquiry {
            Button(inquiry.adminReply == nil ? "이메일 답변 작성" : "추가 답변 작성") {
                replyTarget = inquiry
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.actionID != nil || inquiry.contactEmail.isEmpty)
            .accessibilityHint("작성 후 최종 확인을 거쳐 문의자의 이메일로 전송합니다")
        } else if section == .announcements, let announcement = selectedAnnouncement {
            if announcement.isPublished {
                Button("비공개로 전환", role: .destructive) {
                    Task {
                        await model.setAnnouncementPublished(
                            announcement, published: false, visibleStatus: announcementStatus)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(model.actionID != nil)
                .accessibilityHint("사용자 알림함에 배달된 이 공지 알림도 제거합니다")
            } else {
                Button("공지 공개") {
                    Task {
                        await model.setAnnouncementPublished(
                            announcement, published: true, visibleStatus: announcementStatus)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.actionID != nil)
                .accessibilityHint("공지를 공개하고 사용자 알림함에 배달합니다")
            }
        }
    }

    private func todoDetail(_ todo: ServerAPI.AdminOperationsTodo) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label(categoryLabel(todo.category), systemImage: "checklist")
                .font(.mCaption).foregroundStyle(Tokens.primary)
            Text(todo.title).font(compactLandscape ? .mHeading : .mTitle).foregroundStyle(Tokens.ink)
            if !todo.description.isEmpty {
                Text(todo.description).font(.mBody).foregroundStyle(Tokens.text2)
            }
            personLine(label: "요청자", person: todo.actor)
            personLine(label: "대상", person: todo.target)
            Text("등록 \(absoluteDate(todo.createdAt))")
                .font(.mCaption).foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func inquiryDetail(_ inquiry: ServerAPI.AdminOperationsInquiry) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                Text(inquiryStatusLabel(inquiry.status)).font(.mCaption).foregroundStyle(Tokens.primary)
                Spacer()
                Menu("상태 변경") {
                    ForEach(["pending", "in_review", "replied", "closed"], id: \.self) { status in
                        Button(inquiryStatusLabel(status)) {
                            Task {
                                await model.setInquiryStatus(
                                    inquiry, status: status, visibleStatus: inquiryStatus)
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(model.actionID != nil)
            }
            Text(inquiry.subject).font(compactLandscape ? .mHeading : .mTitle).foregroundStyle(Tokens.ink)
            Label(inquiry.contactEmail, systemImage: "envelope")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Text(inquiry.content)
                .font(.mBody).foregroundStyle(Tokens.ink)
                .textSelection(.enabled)
                .padding(Tokens.Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            if let reply = inquiry.adminReply {
                VStack(alignment: .leading, spacing: 5) {
                    Text("보낸 답변").font(.mBodyB)
                    Text(reply.message).font(.mBody).textSelection(.enabled)
                    Text("\(reply.sentTo) · \(absoluteDate(reply.repliedAt))")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                .padding(Tokens.Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.successSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func announcementDetail(_ announcement: ServerAPI.AdminOperationsAnnouncement) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                Label(
                    announcement.isPublished ? "공개 중" : "초안",
                    systemImage: announcement.isPublished ? "megaphone.fill" : "doc")
                    .font(.mCaption)
                    .foregroundStyle(announcement.isPublished ? Tokens.successInk : Tokens.text2)
                Spacer()
                Text(announcementCategoryLabel(announcement.boardCategory))
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Text(announcement.title).font(compactLandscape ? .mHeading : .mTitle).foregroundStyle(Tokens.ink)
            Text(announcement.content)
                .font(.mBody).foregroundStyle(Tokens.ink).textSelection(.enabled)
                .padding(Tokens.Space.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.surface,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("작성 \(absoluteDate(announcement.createdAt))")
                if announcement.isPublished {
                    Text("공개 \(absoluteDate(announcement.publishedAt))")
                    if announcement.deliveredAt != nil { Text("알림함 배달 완료") }
                }
                if announcement.dashboardEndsAt != nil {
                    Text("대시보드 노출 종료 \(absoluteDate(announcement.dashboardEndsAt))")
                }
            }
            .font(.mCaption).foregroundStyle(Tokens.text3)

        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    @ViewBuilder
    private func personLine(label: String, person: ServerAPI.AdminOperationsPerson?) -> some View {
        if let person, !person.name.isEmpty || !person.email.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
                Text(person.name.isEmpty ? person.email : person.name).font(.mBodyB)
                if !person.name.isEmpty, !person.email.isEmpty {
                    Text(person.email).font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
        }
    }

    @ViewBuilder
    private var pagination: some View {
        let page = section == .todos
            ? model.todos?.pagination
            : section == .inquiries ? model.inquiries?.pagination : nil
        if let page, page.totalPages > 1 {
            HStack {
                Button("이전") { changePage(page.page - 1) }.disabled(!page.hasPrevious)
                Spacer()
                Text("\(page.page) / \(page.totalPages)").font(.mCaption.monospacedDigit())
                Spacer()
                Button("다음") { changePage(page.page + 1) }.disabled(!page.hasNext)
            }
            .buttonStyle(.bordered)
        }
    }

    private var feedback: some View {
        Group {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Tokens.dangerInk).background(Tokens.dangerSoft)
            } else if let notice = model.noticeMessage {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.successInk).background(Tokens.successSoft)
            }
        }
        .font(.mCaption)
        .padding(.horizontal, Tokens.Space.s3)
        .frame(maxWidth: .infinity, minHeight: model.errorMessage == nil && model.noticeMessage == nil ? 0 : 34,
               alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.mTitle).foregroundStyle(Tokens.dangerInk)
            Text("운영 업무를 열지 못했습니다").font(.mHeading)
            Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
            Button("다시 시도") {
                Task {
                    await model.loadAll(
                        todoStatus: todoStatus,
                        todoCategory: todoCategory,
                        inquiryStatus: inquiryStatus,
                        announcementStatus: announcementStatus)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Tokens.Space.s4)
    }

    private var emptyState: some View {
        VStack(spacing: Tokens.Space.s2) {
            Image(systemName: "checkmark.circle")
            Text(emptyStateTitle)
                .font(.mBodyB)
        }
        .foregroundStyle(Tokens.text2)
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var currentItemsAreEmpty: Bool {
        switch section {
        case .todos: return model.todos?.items.isEmpty ?? true
        case .inquiries: return model.inquiries?.items.isEmpty ?? true
        case .announcements: return model.announcements?.items.isEmpty ?? true
        }
    }

    private var emptyStateTitle: String {
        switch section {
        case .todos: return "이 조건의 할 일이 없습니다"
        case .inquiries: return "이 조건의 문의가 없습니다"
        case .announcements: return "이 조건의 공지가 없습니다"
        }
    }

    private var todoCategoryLabel: String {
        todoCategory.isEmpty ? "전체 종류" : categoryLabel(todoCategory)
    }

    private func changeTodoFilter(status: String, category: String) {
        todoStatus = status
        todoCategory = category
        selectedTodoID = nil
        Task { await model.loadTodos(status: status, category: category) }
    }

    private func changeInquiryFilter(_ status: String) {
        inquiryStatus = status
        selectedInquiryID = nil
        Task { await model.loadInquiries(status: status) }
    }

    private func changeAnnouncementFilter(_ status: String) {
        announcementStatus = status
        selectedAnnouncementID = nil
        Task { await model.loadAnnouncements(status: status) }
    }

    private func changePage(_ page: Int) {
        if section == .todos {
            Task { await model.loadTodos(status: todoStatus, category: todoCategory, page: page) }
        } else {
            Task { await model.loadInquiries(status: inquiryStatus, page: page) }
        }
    }

    private func categoryLabel(_ value: String) -> String {
        switch value {
        case "inquiry": return "문의"
        case "community-report": return "신고"
        case "integrity": return "무결성"
        default: return "기타"
        }
    }

    private func inquiryStatusLabel(_ value: String) -> String {
        switch value {
        case "pending": return "대기"
        case "in_review": return "검토 중"
        case "replied": return "답변 완료"
        case "closed": return "종료"
        default: return "전체"
        }
    }

    private var announcementStatusLabel: String {
        switch announcementStatus {
        case "published": return "공개"
        case "draft": return "초안"
        default: return "전체"
        }
    }

    private func announcementCategoryLabel(_ value: String) -> String {
        switch value {
        case "rules": return "이용 규칙"
        case "policies": return "운영 정책"
        case "manuals": return "이용 안내"
        case "inquiry-rules": return "문의 규칙"
        default: return "공지"
        }
    }

    private func relativeDate(_ value: String?) -> String {
        guard let date = parseDate(value) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }

    private func absoluteDate(_ value: String?) -> String {
        guard let date = parseDate(value) else { return "날짜 없음" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private struct AdminAnnouncementComposer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var category = "notice"
    @State private var publishNow = false
    @State private var usesEndDate = false
    @State private var endDate = Date().addingTimeInterval(7 * 86_400)
    @State private var confirmsSave = false
    @State private var isSaving = false

    let onSave: (String, String, String, Bool, String) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("공지 내용") {
                    TextField("제목", text: $title)
                    TextEditor(text: $content).frame(minHeight: 180)
                    Picker("분류", selection: $category) {
                        Text("공지").tag("notice")
                        Text("이용 규칙").tag("rules")
                        Text("운영 정책").tag("policies")
                        Text("이용 안내").tag("manuals")
                        Text("문의 규칙").tag("inquiry-rules")
                    }
                }
                Section("공개") {
                    Toggle("저장 즉시 공개", isOn: $publishNow)
                    Toggle("대시보드 노출 종료일 설정", isOn: $usesEndDate)
                    if usesEndDate {
                        DatePicker("종료일", selection: $endDate, in: Date()..., displayedComponents: .date)
                    }
                    Text(publishNow
                         ? "공개하면 사용자 알림함에도 즉시 배달됩니다."
                         : "초안은 관리자에게만 보이며 나중에 공개할 수 있습니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
            .navigationTitle("새 공지")
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { confirmsSave = true }
                        .disabled(cleanTitle.count < 2 || cleanContent.count < 5 || isSaving)
                }
            }
            .confirmationDialog(
                publishNow ? "공지를 공개할까요?" : "공지 초안을 저장할까요?",
                isPresented: $confirmsSave,
                titleVisibility: .visible
            ) {
                Button(publishNow ? "저장하고 공개" : "초안 저장") {
                    isSaving = true
                    Task {
                        let formatter = DateFormatter()
                        formatter.locale = Locale(identifier: "en_US_POSIX")
                        formatter.dateFormat = "yyyy-MM-dd"
                        let value = usesEndDate ? formatter.string(from: endDate) : ""
                        if await onSave(cleanTitle, cleanContent, category, publishNow, value) { dismiss() }
                        isSaving = false
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text(publishNow
                     ? "공개 후 알림이 배달됩니다. 제목과 내용을 마지막으로 확인하세요."
                     : "초안은 사용자에게 보이지 않습니다.")
            }
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AdminInquiryReplySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var confirmsSend = false
    @State private var isSending = false

    let inquiry: ServerAPI.AdminOperationsInquiry
    let onSend: (String) async -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("받는 사람") {
                    Text(inquiry.contactEmail).textSelection(.enabled)
                    Text(inquiry.subject).font(.mCaption).foregroundStyle(Tokens.text2)
                }
                Section("답변") {
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                        .accessibilityLabel("문의 답변")
                    Text("5자 이상 입력하세요. 전송하면 문의 상태가 답변 완료로 바뀝니다.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                }
            }
            .navigationTitle("문의 답변")
            .interactiveDismissDisabled(isSending)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }.disabled(isSending)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("전송") { confirmsSend = true }
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).count < 5 || isSending)
                }
            }
            .confirmationDialog(
                "답변 이메일을 실제로 전송할까요?",
                isPresented: $confirmsSend,
                titleVisibility: .visible
            ) {
                Button("이메일 전송") {
                    isSending = true
                    let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        if await onSend(cleanMessage) { dismiss() }
                        isSending = false
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("\(inquiry.contactEmail) 주소로 전송됩니다. 전송 전 내용과 수신자를 확인하세요.")
            }
        }
    }
}
