import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct NativeCommunityScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var board = "high-school"
    @State private var search = ""
    @State private var submittedSearch = ""
    @State private var sort = "latest"
    @State private var category = ""
    @State private var page = 1
    @State private var data: ServerAPI.CommunityPage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedPost: ServerAPI.CommunityPost?
    @State private var showsComposer = false
    @State private var showsBlockedUsers = false
    @State private var accountSlot = DataScope.slot

    private var visibleBoards: [(String, String)] {
        let publicBoards = [("high-school", "통합 게시판")]
        guard ServerAPI.hasToken else { return publicBoards + [("operations", "운영 공지")] }
        return publicBoards + [privateBoard] + [("operations", "운영 공지")]
    }

    private var privateBoard: (String, String) {
        switch store.schoolGrade {
        case 13: ("retaker", "N수생 게시판")
        case 14: ("university", "내 대학교")
        case 15: ("worker", "직장인 게시판")
        default: ("school", "내 학교")
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                Group {
                    if isLoading && data == nil {
                        ProgressView("게시글을 불러오는 중입니다")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage, data == nil {
                        ContentUnavailableView {
                            Label("게시판을 불러오지 못했습니다", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("다시 시도") { Task { await load(reset: false) } }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    } else {
                        postList
                    }
                }
            }
            .background(Tokens.paper)
            .navigationTitle("게시판")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(verticalSizeClass == .compact ? .hidden : .visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Tokens.paper, for: .navigationBar)
            .toolbar {
                if verticalSizeClass != .compact {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if ServerAPI.hasToken {
                            Button { showsBlockedUsers = true } label: {
                                Image(systemName: "person.crop.circle.badge.xmark")
                            }
                            .accessibilityLabel("차단한 사용자")
                        }
                        Button {
                            openComposerOrLogin()
                        } label: {
                            Label("글쓰기", systemImage: "square.and.pencil")
                        }
                        .accessibilityHint(ServerAPI.hasToken ? "새 게시글을 작성합니다" : "로그인 화면으로 이동합니다")
                    }
                }
            }
            .task { await load(reset: true) }
            .refreshable { await load(reset: false) }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
                guard let next = note.object as? String, next != accountSlot else { return }
                accountSlot = next
                data = nil
                page = 1
                Task { await load(reset: true) }
            }
            .compactHeightSheet(item: $selectedPost) { post in
                NativeCommunityDetailSheet(post: post) {
                    Task { await load(reset: false) }
                } onLogin: {
                    selectedPost = nil
                    store.route = .profile
                }
            }
            .compactHeightSheet(isPresented: $showsComposer) {
                NativeCommunityComposerSheet(initialBoard: board) { post in
                    showsComposer = false
                    page = 1
                    Task {
                        await load(reset: false)
                        selectedPost = post
                    }
                }
            }
            .compactHeightSheet(isPresented: $showsBlockedUsers) {
                NativeCommunityBlockedUsersSheet()
            }
        }
    }

    @ViewBuilder private var header: some View {
        if verticalSizeClass == .compact {
            compactHeader
        } else {
            regularHeader
        }
    }

    private var compactHeader: some View {
        HStack(spacing: Tokens.Space.s2) {
            boardMenu
            if board == "operations" { categoryPicker }
            else { sortPicker.frame(maxWidth: 170) }
            TextField("제목·내용·작성자 검색", text: $search)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { submitSearch() }
            Button { submitSearch() } label: { Image(systemName: "magnifyingglass") }
                .frame(width: 44, height: 44)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line) }
                .buttonStyle(.plain)
                .accessibilityLabel("게시글 검색")
            if !submittedSearch.isEmpty {
                Button {
                    search = ""; submittedSearch = ""; page = 1
                    Task { await load(reset: false) }
                } label: { Image(systemName: "xmark.circle.fill") }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("검색 해제")
            }
            if ServerAPI.hasToken {
                Button { showsBlockedUsers = true } label: {
                    Image(systemName: "person.crop.circle.badge.xmark")
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("차단한 사용자")
            }
            Button { openComposerOrLogin() } label: {
                Label("글쓰기", systemImage: "square.and.pencil")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.onBrand)
                    .padding(.horizontal, Tokens.Space.s3)
                    .frame(minHeight: 44)
                    .background(Tokens.actionPrimary,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("글쓰기")
            .accessibilityHint(ServerAPI.hasToken ? "새 게시글을 작성합니다" : "로그인 화면으로 이동합니다")
            if isLoading { ProgressView().controlSize(.small) }
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, Tokens.Space.s1)
        // 바깥 RootView의 compact 상단 크롬 아래에서 NavigationStack의 숨긴
        // navigation bar가 예약하던 높이가 사라진다. 한 줄 조작부가 크롬 뒤로
        // 미끄러지지 않도록 최소 터치 타깃 한 칸만 명시적으로 확보한다.
        .padding(.top, 44)
        .background(Tokens.surface)
    }

    private var regularHeader: some View {
        VStack(spacing: verticalSizeClass == .compact ? Tokens.Space.s2 : Tokens.Space.s3) {
            HStack(spacing: Tokens.Space.s3) {
                boardMenu
                if board == "operations" { categoryPicker }
                else { sortPicker.frame(maxWidth: 220) }
                Spacer(minLength: 0)
                if isLoading { ProgressView().controlSize(.small) }
            }
            HStack(spacing: Tokens.Space.s2) {
                TextField("제목·내용·작성자 검색", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onSubmit { submitSearch() }
                Button("검색") { submitSearch() }
                    .buttonStyle(SecondaryButtonStyle())
                if !submittedSearch.isEmpty {
                    Button("검색 해제") {
                        search = ""
                        submittedSearch = ""
                        page = 1
                        Task { await load(reset: false) }
                    }
                    .frame(minHeight: 44)
                }
            }
            if !ServerAPI.hasToken {
                Label("글과 운영 공지는 로그인 없이 읽을 수 있습니다. 작성·댓글·추천은 로그인이 필요합니다.", systemImage: "eye.fill")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Tokens.Space.s4)
        .padding(.vertical, verticalSizeClass == .compact ? Tokens.Space.s1 : Tokens.Space.s3)
        .background(Tokens.surface)
    }

    private var boardMenu: some View {
        Menu {
            ForEach(visibleBoards, id: \.0) { item in
                Button {
                    board = item.0
                    category = ""
                    if board == "operations" { sort = "latest" }
                    page = 1
                    Task { await load(reset: true) }
                } label: {
                    if board == item.0 { Label(item.1, systemImage: "checkmark") }
                    else { Text(item.1) }
                }
            }
        } label: {
            Label(boardLabel, systemImage: "rectangle.stack.fill")
                .font(.mBodyB)
                .lineLimit(1)
                .frame(minHeight: 44)
        }
    }

    private var categoryPicker: some View {
        Picker("공지 분류", selection: $category) {
            Text("전체").tag("")
            ForEach(data?.operationsCategories ?? []) { item in
                Text(item.label).tag(item.value)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 112)
        .onChange(of: category) { _, _ in
            page = 1
            Task { await load(reset: false) }
        }
    }

    private var sortPicker: some View {
        Picker("정렬", selection: $sort) {
            Text("최신순").tag("latest")
            Text("인기순").tag("popular")
        }
        .pickerStyle(.segmented)
        .onChange(of: sort) { _, _ in
            page = 1
            Task { await load(reset: false) }
        }
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: Tokens.Space.s3) {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.mCaption).foregroundStyle(Tokens.danger)
                        .padding(Tokens.Space.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Tokens.dangerSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                }
                if data?.board.schoolAccessRestricted == true {
                    ContentUnavailableView("소속 확인이 필요합니다", systemImage: "person.badge.key",
                        description: Text("프로필에서 현재 소속을 등록하면 전용 게시판을 이용할 수 있습니다."))
                } else if data?.posts.isEmpty != false {
                    ContentUnavailableView("표시할 게시글이 없습니다", systemImage: "text.bubble",
                        description: Text(submittedSearch.isEmpty ? "첫 글을 남겨보세요." : "다른 검색어로 다시 찾아보세요."))
                } else {
                    if sort == "latest", !(data?.popularPosts.isEmpty ?? true) {
                        popularStrip
                    }
                    ForEach(data?.posts ?? []) { post in
                        Button { selectedPost = post } label: { postRow(post) }
                            .buttonStyle(.plain)
                    }
                    pagination
                }
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Tokens.Space.s4)
            .padding(.vertical, Tokens.Space.s4)
        }
    }

    private func postRow(_ post: ServerAPI.CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s2) {
                if post.pinned { Label("고정", systemImage: "pin.fill").foregroundStyle(Tokens.warningInk) }
                if post.kind != "POST" { Text(post.kind == "NOTICE" ? "공지" : "운영").foregroundStyle(Tokens.actionPrimary) }
                Text(post.title).font(.mBodyB).foregroundStyle(Tokens.text1).lineLimit(2)
                Spacer(minLength: Tokens.Space.s2)
                Image(systemName: "chevron.right").foregroundStyle(Tokens.text3)
            }
            if !post.contentPreview.isEmpty {
                Text(post.contentPreview).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(2)
            }
            HStack(spacing: Tokens.Space.s3) {
                Text(post.authorName)
                if let date = CommunityDate.parse(post.createdAt) { Text(date.formatted(.relative(presentation: .named))) }
                Spacer()
                Label("\(post.upvoteCount)", systemImage: "hand.thumbsup")
                Label("\(post.viewCount)", systemImage: "eye")
                if post.attachmentCount > 0 { Label("\(post.attachmentCount)", systemImage: "paperclip") }
            }
            .font(.mMicro).foregroundStyle(Tokens.text3).monospacedDigit()
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line) }
        .accessibilityElement(children: .combine)
    }

    private var pagination: some View {
        HStack {
            Button("이전") {
                page = max(1, page - 1)
                Task { await load(reset: false) }
            }.disabled(data?.pagination.hasPrevious != true || isLoading)
            Spacer()
            Text("\(data?.pagination.page ?? 1) / \(data?.pagination.totalPages ?? 1)")
                .font(.mCaption).monospacedDigit()
            Spacer()
            Button("다음") {
                page += 1
                Task { await load(reset: false) }
            }.disabled(data?.pagination.hasNext != true || isLoading)
        }
        .frame(minHeight: 52)
    }

    private var popularStrip: some View {
        Group {
            if verticalSizeClass == .compact {
                HStack(spacing: Tokens.Space.s3) {
                    Label("인기 글", systemImage: "flame.fill")
                        .font(.mCaption).foregroundStyle(Tokens.warningInk)
                        .fixedSize()
                    popularScroller(compact: true)
                }
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Label("지금 인기 있는 글", systemImage: "flame.fill")
                        .font(.mBodyB).foregroundStyle(Tokens.warningInk)
                    popularScroller(compact: false)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func popularScroller(compact: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.s2) {
                ForEach(data?.popularPosts ?? []) { post in
                    Button { selectedPost = post } label: {
                        if compact {
                            HStack(spacing: Tokens.Space.s2) {
                                Text(post.title).font(.mCaption).lineLimit(1)
                                Label("\(post.upvoteCount)", systemImage: "hand.thumbsup.fill")
                                    .font(.mMicro).foregroundStyle(Tokens.text2)
                            }
                            .padding(.horizontal, Tokens.Space.s3)
                            .frame(width: 280, alignment: .leading)
                            .frame(minHeight: 48, alignment: .leading)
                            .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                        } else {
                            VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                                Text(post.title).font(.mCaption).lineLimit(2)
                                Label("추천 \(post.upvoteCount)", systemImage: "hand.thumbsup.fill")
                                    .font(.mMicro).foregroundStyle(Tokens.text2)
                            }
                            .frame(width: 220, alignment: .leading)
                            .frame(minHeight: 72, alignment: .leading)
                            .padding(Tokens.Space.s3)
                            .background(Tokens.warningSoft, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func openComposerOrLogin() {
        guard ServerAPI.hasToken else {
            store.route = .profile
            return
        }
        showsComposer = true
    }

    private var boardLabel: String {
        data?.board.label ?? visibleBoards.first(where: { $0.0 == board })?.1 ?? "게시판"
    }

    private func submitSearch() {
        submittedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        page = 1
        Task { await load(reset: false) }
    }

    @MainActor private func load(reset: Bool) async {
        if reset { data = nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            data = try await ServerAPI.communityPage(
                board: board, search: submittedSearch, sort: sort,
                category: category, page: page)
        } catch {
            errorMessage = (error as? ServerAPIError)?.errorDescription ?? "게시판을 불러오지 못했습니다."
        }
    }
}

private struct NativeCommunityDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let post: ServerAPI.CommunityPost
    let onChanged: () -> Void
    let onLogin: () -> Void

    @State private var detail: ServerAPI.CommunityDetail?
    @State private var comment = ""
    @State private var commentAnonymous = false
    @State private var reportReason = ""
    @State private var isLoading = true
    @State private var isActing = false
    @State private var errorMessage: String?
    @State private var showsReport = false
    @State private var confirmsDelete = false
    @State private var blockTarget: String?
    @State private var previewURL: URL?
    @State private var downloadingID: String?
    @State private var accountSlot = DataScope.slot

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                    if isLoading && detail == nil { ProgressView("게시글을 불러오는 중입니다") }
                    if let value = detail {
                        postBody(value.post)
                        if value.post.kind == "POST" {
                            voteBar(value)
                            comments(value)
                            commentComposer(value)
                        }
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.mCaption).foregroundStyle(Tokens.danger)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
                .adaptiveHPadding().adaptiveVPadding()
            }
            .background(Tokens.paper)
            .navigationTitle("게시글")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(isLoading || isActing)
                    if detail?.post.kind == "POST", ServerAPI.hasToken {
                        Menu {
                            if detail?.post.canDelete == true {
                                Button("게시글 삭제", role: .destructive) { confirmsDelete = true }
                            } else {
                                Button("작성자 차단", role: .destructive) { blockTarget = "post" }
                                Button("게시글 신고") { showsReport = true }
                                    .disabled(detail?.viewerReported == true)
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
                guard let next = note.object as? String, next != accountSlot else { return }
                accountSlot = next
                dismiss()
            }
            .compactHeightSheet(item: Binding(
                get: { previewURL.map(PreviewTarget.init) },
                set: { if $0 == nil { previewURL = nil } })) { target in
                    CommunityFilePreview(url: target.url) { previewURL = nil }.ignoresSafeArea()
            }
            .alert("게시글 신고", isPresented: $showsReport) {
                TextField("신고 사유 5자 이상", text: $reportReason)
                Button("신고", role: .destructive) { Task { await report() } }
                Button("취소", role: .cancel) {}
            } message: { Text("운영자가 게시글과 신고 사유를 검토합니다.") }
            .confirmationDialog("게시글을 삭제할까요?", isPresented: $confirmsDelete) {
                Button("삭제", role: .destructive) { Task { await deletePost() } }
                Button("취소", role: .cancel) {}
            } message: { Text("삭제된 글은 목록에서 숨겨지며 운영 기록은 보존됩니다.") }
            .confirmationDialog("이 사용자를 차단할까요?", isPresented: Binding(
                get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } })) {
                    Button("차단", role: .destructive) { Task { await block() } }
                    Button("취소", role: .cancel) { blockTarget = nil }
            } message: { Text("서로의 게시글과 댓글이 즉시 숨겨집니다.") }
        }
    }

    private func postBody(_ post: ServerAPI.CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(post.title).font(.mTitle).foregroundStyle(Tokens.text1)
            HStack { Text(post.authorName); Spacer(); Text(CommunityDate.label(post.createdAt)) }
                .font(.mCaption).foregroundStyle(Tokens.text2)
            Text(post.content ?? post.contentPreview).font(.mBody).foregroundStyle(Tokens.text1)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            ForEach(post.attachments ?? []) { attachment in
                Button { Task { await download(attachment) } } label: {
                    HStack {
                        Image(systemName: attachment.isImage ? "photo" : "doc.fill")
                        VStack(alignment: .leading) {
                            Text(attachment.originalName).lineLimit(1)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.sizeBytes), countStyle: .file))
                                .font(.mMicro).foregroundStyle(Tokens.text3)
                        }
                        Spacer()
                        if downloadingID == attachment.id { ProgressView() }
                        else { Image(systemName: "arrow.down.circle") }
                    }.frame(minHeight: 52)
                }.buttonStyle(SecondaryButtonStyle()).disabled(downloadingID != nil)
            }
        }
    }

    private func voteBar(_ value: ServerAPI.CommunityDetail) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Button { authenticated { Task { await vote(1) } } } label: {
                Label("추천 \(value.post.upvoteCount)", systemImage: value.viewerVote == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
            }.buttonStyle(SecondaryButtonStyle()).disabled(isActing)
            Button { authenticated { Task { await vote(-1) } } } label: {
                Label("비추천 \(value.post.downvoteCount)", systemImage: value.viewerVote == -1 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
            }.buttonStyle(SecondaryButtonStyle()).disabled(isActing)
            Spacer()
            Label("조회 \(value.post.viewCount)", systemImage: "eye").font(.mCaption).foregroundStyle(Tokens.text2)
        }
    }

    private func comments(_ value: ServerAPI.CommunityDetail) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "댓글 \(value.comments.count)")
            if value.comments.isEmpty { Text("아직 댓글이 없습니다.").font(.mCaption).foregroundStyle(Tokens.text2) }
            ForEach(value.comments) { item in
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    HStack {
                        Text(item.authorName).font(.mBodyB)
                        Spacer()
                        Text(CommunityDate.label(item.createdAt)).font(.mMicro).foregroundStyle(Tokens.text3)
                        if item.canBlock, ServerAPI.hasToken {
                            Button { blockTarget = item.id } label: { Image(systemName: "person.crop.circle.badge.xmark") }
                                .accessibilityLabel("댓글 작성자 차단")
                        }
                    }
                    Text(item.content).font(.mBody).textSelection(.enabled)
                }
                .padding(Tokens.Space.s3)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
            }
        }
    }

    private func commentComposer(_ value: ServerAPI.CommunityDetail) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "댓글 작성")
            if !value.signedIn {
                Button("로그인하고 댓글 쓰기") { onLogin() }.buttonStyle(PrimaryButtonStyle())
            } else {
                TextField("댓글을 입력하세요", text: $comment, axis: .vertical)
                    .lineLimit(2...6).textFieldStyle(.roundedBorder)
                Toggle("익명으로 작성", isOn: $commentAnonymous)
                Button("댓글 등록") { Task { await submitComment() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActing)
            }
        }
    }

    private func authenticated(_ action: () -> Void) {
        guard ServerAPI.hasToken else { onLogin(); return }
        action()
    }

    @MainActor private func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { detail = try await ServerAPI.communityDetail(post) }
        catch { errorMessage = message(error) }
    }

    @MainActor private func vote(_ value: Int) async {
        guard var detail else { return }
        isActing = true; defer { isActing = false }
        do {
            let receipt = try await ServerAPI.voteCommunityPost(postId: post.id, value: value)
            detail.viewerVote = receipt.viewerVote
            detail.post.upvoteCount = receipt.upvoteCount
            detail.post.downvoteCount = receipt.downvoteCount
            self.detail = detail
            onChanged()
        } catch { errorMessage = message(error) }
    }

    @MainActor private func submitComment() async {
        isActing = true; defer { isActing = false }
        do {
            _ = try await ServerAPI.createCommunityComment(postId: post.id, content: comment, anonymous: commentAnonymous)
            comment = ""; commentAnonymous = false
            await load(); onChanged()
        } catch { errorMessage = message(error) }
    }

    @MainActor private func report() async {
        guard reportReason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 else {
            errorMessage = "신고 사유를 5자 이상 입력해주세요."; return
        }
        isActing = true; defer { isActing = false }
        do {
            try await ServerAPI.reportCommunityPost(postId: post.id, reason: reportReason)
            reportReason = ""; detail?.viewerReported = true
        } catch { errorMessage = message(error) }
    }

    @MainActor private func deletePost() async {
        isActing = true; defer { isActing = false }
        do { try await ServerAPI.deleteCommunityPost(postId: post.id); onChanged(); dismiss() }
        catch { errorMessage = message(error) }
    }

    @MainActor private func block() async {
        let target = blockTarget; blockTarget = nil
        isActing = true; defer { isActing = false }
        do {
            try await ServerAPI.blockCommunityAuthor(postId: post.id, commentId: target == "post" ? nil : target)
            onChanged(); dismiss()
        } catch { errorMessage = message(error) }
    }

    @MainActor private func download(_ attachment: ServerAPI.CommunityPost.Attachment) async {
        downloadingID = attachment.id; defer { downloadingID = nil }
        do { previewURL = try await ServerAPI.downloadCommunityAttachment(attachment) }
        catch { errorMessage = message(error) }
    }

    private func message(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? "게시판 요청을 완료하지 못했습니다."
    }
}

private struct NativeCommunityComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let initialBoard: String
    let onCreated: (ServerAPI.CommunityPost) -> Void

    @State private var board: String
    @State private var title = ""
    @State private var content = ""
    @State private var anonymous = false
    @State private var access: ServerAPI.CommunityPostingAccess?
    @State private var files: [URL] = []
    @State private var photos: [PhotosPickerItem] = []
    @State private var showsFileImporter = false
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var accountSlot = DataScope.slot

    init(initialBoard: String, onCreated: @escaping (ServerAPI.CommunityPost) -> Void) {
        self.initialBoard = initialBoard
        self.onCreated = onCreated
        _board = State(initialValue: initialBoard == "operations" ? "high-school" : initialBoard)
    }

    private var composerBoards: [(String, String)] {
        let privateChoice: (String, String) = switch store.schoolGrade {
        case 13: ("retaker", "N수생 게시판")
        case 14: ("university", "내 대학교")
        case 15: ("worker", "직장인 게시판")
        default: ("school", "내 학교")
        }
        return [("high-school", "통합 게시판"), privateChoice]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                    if let access {
                        Label("오늘 \(access.remainingPosts)개 더 작성할 수 있습니다.", systemImage: "checkmark.circle")
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                    }
                    Picker("게시판", selection: $board) {
                        ForEach(composerBoards, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }.pickerStyle(.menu)
                    TextField("제목 2자 이상", text: $title).textFieldStyle(.roundedBorder)
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                        .padding(Tokens.Space.s2)
                        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
                        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.md).strokeBorder(Tokens.line) }
                    Toggle("익명으로 작성", isOn: $anonymous)
                    attachmentControls
                    if let errorMessage { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").font(.mCaption).foregroundStyle(Tokens.danger) }
                    Button {
                        Task { await save() }
                    } label: {
                        Label(isSaving ? "등록 중" : "게시글 등록", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!valid || isSaving || access?.remainingPosts == 0)
                }
                .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                .adaptiveHPadding().adaptiveVPadding()
            }
            .background(Tokens.paper)
            .navigationTitle("새 게시글")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.disabled(isSaving) } }
            .task { await loadAccess() }
            .onChange(of: photos) { _, items in Task { await importPhotos(items) } }
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
                importFiles(result)
            }
            .onDisappear { if !isSaving { cleanup() } }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
                guard let next = note.object as? String, next != accountSlot else { return }
                accountSlot = next
                cleanup()
                dismiss()
            }
        }
    }

    private var attachmentControls: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            SectionRule(title: "첨부파일 \(files.count)/5")
            ForEach(files, id: \.path) { file in
                HStack {
                    Image(systemName: "paperclip")
                    Text(file.lastPathComponent).lineLimit(1)
                    Spacer()
                    Button { remove(file) } label: { Image(systemName: "xmark.circle.fill") }
                        .accessibilityLabel("첨부 삭제")
                }.frame(minHeight: 44)
            }
            HStack {
                PhotosPicker(selection: $photos, maxSelectionCount: max(1, 5 - files.count), matching: .images) {
                    Label("사진", systemImage: "photo.on.rectangle")
                }.buttonStyle(SecondaryButtonStyle())
                Button { showsFileImporter = true } label: { Label("파일", systemImage: "doc.badge.plus") }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .disabled(files.count >= 5 || access?.canUploadFiles == false)
            if access?.canUploadFiles == false {
                Text("경고가 있는 계정은 첨부파일 없이 글을 작성할 수 있습니다.").font(.mCaption).foregroundStyle(Tokens.warningInk)
            }
        }
    }

    private var valid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 &&
        content.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !isLoading
    }

    @MainActor private func loadAccess() async {
        if !composerBoards.contains(where: { $0.0 == board }) {
            board = "high-school"
        }
        do { access = try await ServerAPI.communityPostingAccess() }
        catch { errorMessage = (error as? ServerAPIError)?.errorDescription ?? "작성 가능 여부를 확인하지 못했습니다." }
        isLoading = false
    }

    @MainActor private func save() async {
        isSaving = true; errorMessage = nil
        do {
            let post = try await ServerAPI.createCommunityPost(
                board: board, title: title, content: content, anonymous: anonymous, files: files)
            cleanup(); files = []; onCreated(post)
        } catch {
            errorMessage = (error as? ServerAPIError)?.errorDescription ?? "게시글을 등록하지 못했습니다."
            isSaving = false
        }
    }

    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        defer { photos = [] }
        for item in items.prefix(max(0, 5 - files.count)) {
            guard let source = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: source),
                  let data = image.jpegData(compressionQuality: 0.88),
                  data.count <= 10 * 1024 * 1024 else {
                errorMessage = "10MB 이하 사진만 첨부할 수 있습니다."; continue
            }
            let url = temporaryURL(extension: "jpg")
            do { try data.write(to: url, options: .atomic); files.append(url) }
            catch { errorMessage = "사진을 임시 보관하지 못했습니다." }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        do {
            for source in try result.get().prefix(max(0, 5 - files.count)) {
                let access = source.startAccessingSecurityScopedResource()
                defer { if access { source.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: source, options: [.mappedIfSafe])
                guard data.count <= 10 * 1024 * 1024 else { errorMessage = "10MB 이하 파일만 첨부할 수 있습니다."; continue }
                let url = temporaryURL(extension: source.pathExtension)
                try data.write(to: url, options: .atomic); files.append(url)
            }
        } catch { errorMessage = "선택한 파일을 읽지 못했습니다." }
    }

    private func temporaryURL(extension ext: String) -> URL {
        DataScope.url("community-draft-\(UUID().uuidString).\(ext.isEmpty ? "bin" : ext)")
    }
    private func remove(_ file: URL) { files.removeAll { $0 == file }; try? FileManager.default.removeItem(at: file) }
    private func cleanup() { files.forEach { try? FileManager.default.removeItem(at: $0) } }
}

private struct NativeCommunityBlockedUsersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var users: [ServerAPI.CommunityBlockedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var accountSlot = DataScope.slot
    var body: some View {
        NavigationStack {
            List {
                if let errorMessage { Text(errorMessage).foregroundStyle(Tokens.danger) }
                if !isLoading && users.isEmpty { Text("차단한 사용자가 없습니다.").foregroundStyle(Tokens.text2) }
                ForEach(users) { user in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(user.displayName).font(.mBodyB)
                            Text(user.anonymous ? "익명 사용자" : "커뮤니티 사용자").font(.mCaption).foregroundStyle(Tokens.text2)
                        }
                        Spacer()
                        Button("차단 해제") { Task { await unblock(user) } }
                    }.frame(minHeight: 52)
                }
            }
            .navigationTitle("차단한 사용자")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .task { await load() }
            .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { note in
                guard let next = note.object as? String, next != accountSlot else { return }
                accountSlot = next
                dismiss()
            }
        }
    }
    @MainActor private func load() async {
        isLoading = true; defer { isLoading = false }
        do { users = try await ServerAPI.communityBlockedUsers() }
        catch { errorMessage = (error as? ServerAPIError)?.errorDescription ?? "차단 목록을 불러오지 못했습니다." }
    }
    @MainActor private func unblock(_ user: ServerAPI.CommunityBlockedUser) async {
        do { try await ServerAPI.unblockCommunityUser(user.id); users.removeAll { $0.id == user.id } }
        catch { errorMessage = (error as? ServerAPIError)?.errorDescription ?? "차단을 해제하지 못했습니다." }
    }
}

private struct PreviewTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private enum CommunityDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
    static func label(_ value: String?) -> String {
        parse(value)?.formatted(date: .abbreviated, time: .shortened) ?? ""
    }
}
