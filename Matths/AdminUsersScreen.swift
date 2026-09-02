import SwiftUI

private enum AdminUserActionKind: String, Identifiable {
    case notification, email, passwordReset, nickname, role, status, warnings, package, withdraw
    case parentStatus, parentNotifications, parentUnlink
    var id: String { rawValue }
}

private struct AdminUserActionRequest: Identifiable {
    let kind: AdminUserActionKind
    let user: ServerAPI.AdminUserSummary
    var child: ServerAPI.AdminParentChild?
    var id: String { "\(kind.rawValue):\(user.id):\(child?.id ?? "")" }
}

private struct AdminUserActivityRequest: Identifiable {
    let userID: String
    var attemptID: String?
    var id: String { "\(userID):\(attemptID ?? "activity")" }
}

private struct AdminUserActionForm {
    var title = ""
    var message = ""
    var href = "/main"
    var reason = ""
    var role = "student"
    var teacherExpiry = Date().addingTimeInterval(365 * 86_400)
    var status = "active"
    var suspensionDays = ""
    var warningCount = 0
    var packageType = "FREE"
    var dataRetention = "anonymous"
    var confirmation = ""
    var parentActive = true
    var emailEnabled = true
    var lowLearningEnabled = false
    var minimumMinutesPerDay = 20
    var lowLearningConsecutiveDays = 3
    var inactivityEnabled = false
    var inactivityDays = 7
}

@MainActor
final class AdminUsersScreenModel: ObservableObject {
    @Published var users: ServerAPI.AdminUserList?
    @Published var detail: ServerAPI.AdminUserDetail?
    @Published var sanctions: ServerAPI.AdminAuditPage?
    @Published var audit: ServerAPI.AdminFullAuditPage?
    @Published var isLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    func loadUsers(query: String, role: String, state: String, grade: String,
                   page: Int = 1, selectFirst: Bool = true) async {
        isLoading = users == nil
        errorMessage = nil
        do {
            let value = try await ServerAPI.adminUsers(
                query: query, grade: grade, state: state, role: role, page: page)
            users = value
            if selectFirst, let first = value.items.first {
                await loadDetail(first)
            } else if value.items.isEmpty {
                detail = nil
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
        isLoading = false
    }

    func loadDetail(_ user: ServerAPI.AdminUserSummary) async {
        actionID = "load:\(user.id)"
        errorMessage = nil
        do {
            detail = user.entityType == "PARENT"
                ? try await ServerAPI.adminParent(id: user.id)
                : try await ServerAPI.adminUser(id: user.id)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = readable(error)
        }
        actionID = nil
    }

    func loadSanctions(page: Int = 1) async {
        isLoading = sanctions == nil
        errorMessage = nil
        do { sanctions = try await ServerAPI.adminSanctions(page: page) }
        catch is CancellationError { return }
        catch { errorMessage = readable(error) }
        isLoading = false
    }

    func loadAudit(query: String, page: Int = 1) async {
        isLoading = audit == nil
        errorMessage = nil
        do { audit = try await ServerAPI.adminAudit(query: query, page: page) }
        catch is CancellationError { return }
        catch { errorMessage = readable(error) }
        isLoading = false
    }

    fileprivate func perform(_ request: AdminUserActionRequest, form: AdminUserActionForm,
                             query: String, role: String, state: String, grade: String) async -> Bool {
        guard actionID == nil else { return false }
        actionID = request.id
        errorMessage = nil
        noticeMessage = nil
        do {
            let updated: ServerAPI.AdminUserDetail?
            switch request.kind {
            case .notification:
                try await ServerAPI.sendAdminUserNotification(
                    userID: request.user.id, title: form.title,
                    message: form.message, href: form.href)
                updated = try await reload(request.user)
                noticeMessage = "앱 알림함에 메시지를 보냈습니다."
            case .email:
                let delivered = try await ServerAPI.sendAdminUserEmail(
                    userID: request.user.id, subject: form.title, message: form.message)
                updated = try await reload(request.user)
                noticeMessage = delivered ? "가입 이메일로 전송했습니다." : "이메일 요청을 접수했지만 배달 상태를 확인해야 합니다."
            case .passwordReset:
                try await ServerAPI.sendAdminPasswordReset(userID: request.user.id)
                updated = try await reload(request.user)
                noticeMessage = "10분짜리 비밀번호 재설정 링크를 보냈습니다."
            case .nickname:
                try await ServerAPI.requestAdminNicknameChange(
                    userID: request.user.id, reason: form.reason)
                updated = try await reload(request.user)
                noticeMessage = "닉네임 변경 요청 링크를 보냈습니다."
            case .role:
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd"
                updated = try await ServerAPI.updateAdminUserRole(
                    userID: request.user.id, role: form.role,
                    teacherAccessExpiresAt: form.role == "teacher" ? formatter.string(from: form.teacherExpiry) : "",
                    reason: form.reason)
                noticeMessage = "역할을 변경하고 기존 로그인 세션을 갱신했습니다."
            case .status:
                updated = try await ServerAPI.updateAdminUserAccountStatus(
                    userID: request.user.id, status: form.status,
                    suspensionDays: form.status == "suspended" ? form.suspensionDays : "",
                    reason: form.reason)
                noticeMessage = "계정 상태를 적용했습니다."
            case .warnings:
                updated = try await ServerAPI.updateAdminUserWarnings(
                    userID: request.user.id, warningCount: form.warningCount, reason: form.reason)
                noticeMessage = "경고 횟수를 저장했습니다."
            case .package:
                updated = try await ServerAPI.updateAdminUserPackage(
                    userID: request.user.id, packageType: form.packageType, reason: form.reason)
                noticeMessage = "패키지 권한을 적용했습니다."
            case .withdraw:
                let purged = try await ServerAPI.withdrawAdminUser(
                    userID: request.user.id, reason: form.reason,
                    dataRetention: form.dataRetention, confirmation: form.confirmation)
                updated = nil
                detail = nil
                noticeMessage = purged ? "계정과 활동 데이터를 영구 삭제했습니다." : "개인정보를 제거하고 익명 활동 데이터만 보존했습니다."
            case .parentStatus:
                updated = try await ServerAPI.updateAdminParentStatus(
                    parentID: request.user.id, isActive: form.parentActive, reason: form.reason)
                noticeMessage = "학부모 계정 상태를 저장했습니다."
            case .parentNotifications:
                guard let child = request.child else {
                    actionID = nil
                    errorMessage = "알림을 설정할 자녀 정보를 찾을 수 없습니다."
                    return false
                }
                updated = try await ServerAPI.updateAdminParentChildNotifications(
                    parentID: request.user.id, childID: child.id,
                    emailEnabled: form.emailEnabled,
                    lowLearningEnabled: form.lowLearningEnabled,
                    minimumMinutesPerDay: form.minimumMinutesPerDay,
                    lowLearningConsecutiveDays: form.lowLearningConsecutiveDays,
                    inactivityEnabled: form.inactivityEnabled,
                    inactivityDays: form.inactivityDays)
                noticeMessage = "자녀별 학습 알림 기준을 저장했습니다."
            case .parentUnlink:
                guard let child = request.child else {
                    actionID = nil
                    errorMessage = "연결을 해제할 자녀 정보를 찾을 수 없습니다."
                    return false
                }
                updated = try await ServerAPI.unlinkAdminParentChild(
                    parentID: request.user.id, childID: child.id, reason: form.reason)
                noticeMessage = "자녀 연결을 해제했습니다. 학생 데이터는 유지됩니다."
            }
            if let updated { detail = updated }
            let currentPage = users?.pagination.page ?? 1
            users = try? await ServerAPI.adminUsers(
                query: query, grade: grade, state: state, role: role, page: currentPage)
            actionID = nil
            return true
        } catch {
            errorMessage = readable(error)
            actionID = nil
            return false
        }
    }

    private func reload(_ user: ServerAPI.AdminUserSummary) async throws -> ServerAPI.AdminUserDetail {
        user.entityType == "PARENT"
            ? try await ServerAPI.adminParent(id: user.id)
            : try await ServerAPI.adminUser(id: user.id)
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription ?? (error as NSError).localizedDescription
    }
}

struct AdminUsersScreen: View {
    private enum Section: String, CaseIterable, Identifiable {
        case users = "사용자"
        case sanctions = "제재"
        case audit = "감사"
        var id: String { rawValue }
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AdminUsersScreenModel()
    @State private var section: Section = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-adminSanctions") { return .sanctions }
        if ProcessInfo.processInfo.arguments.contains("-adminAudit") { return .audit }
        #endif
        return .users
    }()
    @State private var query = ""
    @State private var role = ""
    @State private var state = ""
    @State private var grade = ""
    @State private var auditQuery = ""
    @State private var selectedUserID: String?
    @State private var selectedAuditID: String?
    @State private var actionRequest: AdminUserActionRequest?
    @State private var activityRequest: AdminUserActivityRequest? = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-adminUserAssessment") {
            return .init(userID: "demo-user-1", attemptID: "assessment-1")
        }
        if ProcessInfo.processInfo.arguments.contains("-adminUserActivity") {
            return .init(userID: "demo-user-1")
        }
        #endif
        return nil
    }()

    let onClose: () -> Void

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    private var selectedUser: ServerAPI.AdminUserSummary? {
        let items = model.users?.items ?? []
        return items.first(where: { $0.id == selectedUserID }) ?? items.first
    }

    private var auditItems: [ServerAPI.AdminAuditItem] {
        section == .sanctions ? model.sanctions?.items ?? [] : model.audit?.items ?? []
    }

    private var selectedAudit: ServerAPI.AdminAuditItem? {
        auditItems.first(where: { $0.id == selectedAuditID }) ?? auditItems.first
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            feedback
            if model.isLoading && activeDataMissing {
                Spacer()
                ProgressView("관리 정보를 불러오는 중입니다").tint(Tokens.primary)
                Spacer()
            } else if activeDataMissing, let error = model.errorMessage {
                failure(error)
            } else {
                content
            }
        }
        .background(Tokens.paper)
        .task { await loadCurrentSection() }
        .onChange(of: section) { _, _ in Task { await loadCurrentSection() } }
        .sheet(item: $actionRequest) { request in
            AdminUserActionSheet(request: request) { form in
                await model.perform(request, form: form, query: query,
                                    role: role, state: state, grade: grade)
            }
        }
        .fullScreenCover(item: $activityRequest) { request in
            AdminUserActivityScreen(
                userID: request.userID,
                initialAttemptID: request.attemptID,
                onClose: { activityRequest = nil })
        }
    }

    private var header: some View {
        VStack(spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s3) {
                Button(action: onClose) {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                .accessibilityLabel("학원 승인함으로 돌아가기")
                VStack(alignment: .leading, spacing: 1) {
                    Text("사용자 관리").font(.mHeading).foregroundStyle(Tokens.ink)
                    Text(headerSummary).font(.mCaption).foregroundStyle(Tokens.text2)
                }
                Spacer()
                Button { Task { await refreshCurrentSection() } } label: {
                    Image(systemName: "arrow.clockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(Tokens.primary)
                .accessibilityLabel("사용자 관리 새로고침")
            }
            Picker("사용자 관리 종류", selection: $section) {
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

    @ViewBuilder private var content: some View {
        if compactLandscape {
            HStack(spacing: 0) {
                listColumn.frame(width: 390)
                Divider()
                detailColumn.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    listColumn
                    detailColumn
                }
                .readableWidth(Tokens.readableWidth)
                .adaptiveHPadding().adaptiveVPadding()
            }
            .refreshable { await refreshCurrentSection() }
        }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            if section == .users { userFilters } else { auditFilters }
            if compactLandscape {
                ScrollView { listRows }
            } else {
                listRows
            }
            pagination
        }
        .padding(Tokens.Space.s3)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var listRows: some View {
        LazyVStack(spacing: Tokens.Space.s2) {
            if section == .users {
                if model.users?.items.isEmpty ?? true { empty("조건에 맞는 사용자가 없습니다") }
                ForEach(model.users?.items ?? []) { userRow($0) }
            } else {
                if auditItems.isEmpty { empty(section == .sanctions ? "제재 이력이 없습니다" : "감사 이력이 없습니다") }
                ForEach(auditItems) { auditRow($0) }
            }
        }
        .padding(.bottom, Tokens.Space.s2)
    }

    private var userFilters: some View {
        VStack(spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s2) {
                TextField("이름·이메일 검색", text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit { applyUserFilters() }
                Button("검색") { applyUserFilters() }.buttonStyle(.borderedProminent)
            }
            HStack(spacing: Tokens.Space.s2) {
                Menu(roleLabel) {
                    filterButton("전체 역할", value: "", binding: $role)
                    filterButton("학생", value: "student", binding: $role)
                    filterButton("교사", value: "teacher", binding: $role)
                    filterButton("학부모", value: "parent", binding: $role)
                    filterButton("관리자", value: "admin", binding: $role)
                    filterButton("테스트", value: "test", binding: $role)
                }
                Menu(stateLabel) {
                    filterButton("전체 상태", value: "", binding: $state)
                    filterButton("활성", value: "active", binding: $state)
                    filterButton("비활성", value: "inactive", binding: $state)
                    filterButton("정지", value: "suspended", binding: $state)
                    filterButton("탈퇴", value: "withdrawn", binding: $state)
                }
                Menu(gradeLabel) {
                    filterButton("전체 학년", value: "", binding: $grade)
                    ForEach([10, 11, 12, 13, 14, 15], id: \.self) { value in
                        filterButton(gradeName(value), value: String(value), binding: $grade)
                    }
                }
                Spacer()
                Text("\(model.users?.pagination.total ?? 0)명")
                    .font(.mMicro.monospacedDigit()).foregroundStyle(Tokens.text3)
            }
            .buttonStyle(.bordered)
        }
    }

    private var auditFilters: some View {
        VStack(spacing: Tokens.Space.s2) {
            if section == .audit {
                HStack(spacing: Tokens.Space.s2) {
                    TextField("작업·사용자 검색", text: $auditQuery)
                        .onSubmit { applyAuditFilter() }
                    Button("검색") { applyAuditFilter() }.buttonStyle(.borderedProminent)
                }
            }
            HStack {
                Text(section == .sanctions ? "최근 제재" : "전체 관리 작업")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                Spacer()
                Text("\(currentPagination?.total ?? 0)건")
                    .font(.mMicro.monospacedDigit()).foregroundStyle(Tokens.text3)
            }
        }
    }

    private func userRow(_ user: ServerAPI.AdminUserSummary) -> some View {
        Button {
            selectedUserID = user.id
            Task { await model.loadDetail(user) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(roleName(user.role)).font(.mMicro).foregroundStyle(Tokens.primary)
                    Spacer()
                    Text(statusName(user.accountStatus)).font(.mMicro)
                        .foregroundStyle(user.accountStatus == "active" ? Tokens.successInk : Tokens.dangerInk)
                }
                Text(user.name).font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                Text(user.email).font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(1)
                Text(userAffiliation(user)).font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedUser?.id == user.id ? Tokens.primary.opacity(0.12) : Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("사용자 상세와 관리 작업을 표시합니다")
    }

    private func auditRow(_ item: ServerAPI.AdminAuditItem) -> some View {
        Button { selectedAuditID = item.id } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.actionLabel).font(.mMicro).foregroundStyle(Tokens.primary).lineLimit(1)
                    Spacer()
                    Text(relativeDate(item.createdAt)).font(.mMicro).foregroundStyle(Tokens.text3)
                }
                Text(item.target?.name.isEmpty == false ? item.target!.name : "대상 없음")
                    .font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                Text(item.detail.isEmpty ? item.action : item.detail)
                    .font(.mCaption).foregroundStyle(Tokens.text2).lineLimit(2)
            }
            .padding(Tokens.Space.s3).frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedAudit?.id == item.id ? Tokens.primary.opacity(0.12) : Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var detailColumn: some View {
        if compactLandscape {
            VStack(spacing: 0) {
                ScrollView { detailBody.padding(Tokens.Space.s3) }
                if section == .users { userActionBar }
            }
        } else {
            VStack(spacing: 0) {
                detailBody.padding(Tokens.Space.s4)
                if section == .users { userActionBar }
            }
        }
    }

    @ViewBuilder private var detailBody: some View {
        if section == .users {
            if let detail = model.detail { userDetail(detail) }
            else { detailPlaceholder("왼쪽에서 사용자를 선택하세요") }
        } else if let item = selectedAudit {
            auditDetail(item)
        } else {
            detailPlaceholder("왼쪽에서 이력을 선택하세요")
        }
    }

    private func userDetail(_ detail: ServerAPI.AdminUserDetail) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(roleName(detail.user.role)).font(.mCaption).foregroundStyle(Tokens.primary)
                    Text(detail.user.name).font(compactLandscape ? .mHeading : .mTitle).foregroundStyle(Tokens.ink)
                    Text([detail.user.realName, detail.user.email].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.mCaption).foregroundStyle(Tokens.text2).textSelection(.enabled)
                }
                Spacer()
                Text(statusName(detail.user.accountStatus))
                    .font(.mCaption).padding(.horizontal, 12).frame(minHeight: 36)
                    .background(detail.user.accountStatus == "active" ? Tokens.successSoft : Tokens.dangerSoft,
                                in: Capsule())
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: Tokens.Space.s2)], spacing: Tokens.Space.s2) {
                metric("소속", userAffiliation(detail.user))
                if detail.user.entityType == "PARENT" {
                    metric("연결 자녀", "\(detail.parent?.children.count ?? 0)명")
                } else {
                    metric("학습", "\(detail.user.totalStudySeconds / 60)분")
                    metric("정답률", "\(detail.learning.correctRate)%")
                    metric("연속 학습", "\(detail.streak?.current ?? 0)일")
                    metric("Arena", "Lv.\(detail.arenaActivityLevel?.level ?? 1)")
                    metric("경고", "\(detail.user.warningCount)회")
                    metric("패키지", detail.packageAccess?.label ?? "기본학습 패키지")
                }
                metric("최근 로그인", absoluteDate(detail.user.lastLoginAt))
            }
            if detail.user.entityType == "PARENT" {
                parentChildren(detail)
            } else {
                Button {
                    activityRequest = .init(userID: detail.user.id)
                } label: {
                    Label("전체 활동 기록", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                learningSummary(detail)
                assessmentSummary(detail.assessments, userID: detail.user.id)
            }
            recordSummary(detail.records)
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func parentChildren(_ detail: ServerAPI.AdminUserDetail) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("연결 자녀").font(.mBodyB)
            if detail.parent?.children.isEmpty ?? true { Text("활성 연결이 없습니다.").font(.mCaption) }
            ForEach(detail.parent?.children ?? []) { child in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(child.name).font(.mBodyB)
                            Text("\(child.schoolName) · 오늘 \(child.todayStudyMinutes)분 · 정답률 \(child.correctRate)%")
                                .font(.mMicro).foregroundStyle(Tokens.text3)
                        }
                        Spacer()
                        Menu("자녀 관리") {
                            Button("알림 기준 편집") { actionRequest = .init(kind: .parentNotifications, user: detail.user, child: child) }
                            Button("연결 해제", role: .destructive) { actionRequest = .init(kind: .parentUnlink, user: detail.user, child: child) }
                        }
                    }
                }
                .padding(Tokens.Space.s3).background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            }
        }
    }

    private func learningSummary(_ detail: ServerAPI.AdminUserDetail) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("학습 현황").font(.mBodyB)
            if let current = detail.learning.currentConcept {
                Text("\(current.courseTitle) · \(current.unitTitle)").font(.mMicro).foregroundStyle(Tokens.text3)
                Text(current.conceptTitle).font(.mBodyB)
                ProgressView(value: Double(current.completionPercent), total: 100).tint(Tokens.primary)
            } else {
                Text("학습 중인 개념이 없습니다.").font(.mCaption).foregroundStyle(Tokens.text3)
            }
        }
        .padding(Tokens.Space.s3).background(Tokens.surface,
            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    @ViewBuilder private func assessmentSummary(_ items: [ServerAPI.AdminUserAssessment], userID: String) -> some View {
        if let latest = items.first {
            Button {
                activityRequest = .init(userID: userID, attemptID: latest.id)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("최근 평가").font(.mBodyB)
                        Spacer()
                        Image(systemName: "chevron.right").font(.mCaption)
                    }
                    Text(latest.title).font(.mCaption)
                    Text("\(latest.status) · \(latest.scorePercent.map { "\($0)점" } ?? "미채점") · 답안 \(latest.answeredCount)개")
                        .font(.mMicro).foregroundStyle(Tokens.text3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(Tokens.Space.s3).frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .accessibilityHint("평가 문항과 제출 답안을 표시합니다")
        }
    }

    @ViewBuilder private func recordSummary(_ items: [ServerAPI.AdminUserRecord]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                Text("최근 이력").font(.mBodyB)
                ForEach(items.prefix(6)) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text(recordKind(item.kind)); Spacer(); Text(relativeDate(item.createdAt)) }
                            .font(.mMicro).foregroundStyle(Tokens.text3)
                        Text(item.title).font(.mCaption).lineLimit(1)
                        if !item.detail.isEmpty { Text(item.detail).font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(2) }
                    }
                    Divider()
                }
            }
        }
    }

    private func auditDetail(_ item: ServerAPI.AdminAuditItem) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Text(item.actionLabel).font(compactLandscape ? .mHeading : .mTitle)
            if let target = item.target { personLine("대상", target) }
            if let actor = item.actor { personLine("처리자", actor) }
            Text(item.detail.isEmpty ? "상세 사유가 기록되지 않았습니다." : item.detail)
                .font(.mBody).textSelection(.enabled)
                .padding(Tokens.Space.s3).frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            Text(absoluteDate(item.createdAt)).font(.mCaption).foregroundStyle(Tokens.text3)
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private var userActionBar: some View {
        Group {
            if let user = model.detail?.user {
                Menu {
                    if user.entityType == "PARENT" {
                        Button("학부모 계정 상태") { request(.parentStatus, user) }
                    } else {
                        Button("앱 알림 보내기") { request(.notification, user) }
                        Button("가입 이메일 보내기") { request(.email, user) }
                        Button("비밀번호 재설정") { request(.passwordReset, user) }
                        if user.role != "admin" {
                            Divider()
                            Button("닉네임 변경 요청") { request(.nickname, user) }
                            Button("역할 변경") { request(.role, user) }
                            Button("계정 상태") { request(.status, user) }
                            Button("경고 횟수") { request(.warnings, user) }
                            Button("패키지 권한") { request(.package, user) }
                            Divider()
                            Button("계정 삭제", role: .destructive) { request(.withdraw, user) }
                        }
                    }
                } label: {
                    Label("관리 작업", systemImage: "wrench.and.screwdriver")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.actionID != nil)
                .padding(.horizontal, Tokens.Space.s3).padding(.vertical, Tokens.Space.s2)
                .background(Tokens.surface)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
        }
    }

    private var pagination: some View {
        Group {
            if let page = currentPagination, page.totalPages > 1 {
                HStack {
                    Button("이전") { changePage(page.page - 1) }.disabled(!page.hasPrevious)
                    Spacer()
                    Text("\(page.page) / \(page.totalPages)").font(.mCaption.monospacedDigit())
                    Spacer()
                    Button("다음") { changePage(page.page + 1) }.disabled(!page.hasNext)
                }.buttonStyle(.bordered)
            }
        }
    }

    private var currentPagination: ServerAPI.AdminUserPagination? {
        switch section {
        case .users: model.users?.pagination
        case .sanctions: model.sanctions?.pagination
        case .audit: model.audit?.pagination
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
        .font(.mCaption).padding(.horizontal, Tokens.Space.s3)
        .frame(maxWidth: .infinity, minHeight: model.errorMessage == nil && model.noticeMessage == nil ? 0 : 34,
               alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: Tokens.Space.s3) {
            Image(systemName: "exclamationmark.triangle.fill").font(.mTitle).foregroundStyle(Tokens.dangerInk)
            Text("사용자 관리를 열지 못했습니다").font(.mHeading)
            Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
            Button("다시 시도") { Task { await loadCurrentSection() } }.buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(Tokens.Space.s4)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            Text(value).font(.mCaption).foregroundStyle(Tokens.ink).lineLimit(2)
        }
        .padding(Tokens.Space.s2).frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    private func personLine(_ label: String, _ person: ServerAPI.AdminAuditPerson) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            Text(person.name.isEmpty ? person.nickname : person.name).font(.mBodyB)
            Text(person.email).font(.mCaption).foregroundStyle(Tokens.text2).textSelection(.enabled)
        }
    }

    private func detailPlaceholder(_ text: String) -> some View {
        ContentUnavailableView(text, systemImage: "person.crop.circle.badge.questionmark")
            .frame(maxWidth: .infinity, minHeight: 220)
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.mCaption).foregroundStyle(Tokens.text3)
            .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func filterButton(_ title: String, value: String, binding: Binding<String>) -> some View {
        Button(title) { binding.wrappedValue = value; applyUserFilters() }
    }

    private func request(_ kind: AdminUserActionKind, _ user: ServerAPI.AdminUserSummary) {
        actionRequest = .init(kind: kind, user: user)
    }

    private func applyUserFilters() {
        selectedUserID = nil
        model.detail = nil
        Task { await model.loadUsers(query: query, role: role, state: state, grade: grade) }
    }

    private func applyAuditFilter() {
        selectedAuditID = nil
        Task { await model.loadAudit(query: auditQuery) }
    }

    private func changePage(_ page: Int) {
        selectedAuditID = nil
        if section == .users {
            selectedUserID = nil
            model.detail = nil
            Task { await model.loadUsers(query: query, role: role, state: state, grade: grade, page: page) }
        } else if section == .sanctions {
            Task { await model.loadSanctions(page: page) }
        } else {
            Task { await model.loadAudit(query: auditQuery, page: page) }
        }
    }

    private func loadCurrentSection() async {
        if section == .users {
            if model.users == nil { await model.loadUsers(query: query, role: role, state: state, grade: grade) }
        } else if section == .sanctions {
            if model.sanctions == nil { await model.loadSanctions() }
        } else if model.audit == nil {
            await model.loadAudit(query: auditQuery)
        }
    }

    private func refreshCurrentSection() async {
        if section == .users {
            await model.loadUsers(query: query, role: role, state: state, grade: grade,
                                  page: model.users?.pagination.page ?? 1, selectFirst: false)
            if let selectedUser { await model.loadDetail(selectedUser) }
        } else if section == .sanctions {
            await model.loadSanctions(page: model.sanctions?.pagination.page ?? 1)
        } else {
            await model.loadAudit(query: auditQuery, page: model.audit?.pagination.page ?? 1)
        }
    }

    private var activeDataMissing: Bool {
        switch section {
        case .users: model.users == nil
        case .sanctions: model.sanctions == nil
        case .audit: model.audit == nil
        }
    }

    private var headerSummary: String {
        switch section {
        case .users: "전체 \(model.users?.pagination.total ?? 0)명"
        case .sanctions: "제재 \(model.sanctions?.pagination.total ?? 0)건"
        case .audit: "관리 작업 \(model.audit?.pagination.total ?? 0)건"
        }
    }

    private var roleLabel: String { role.isEmpty ? "전체 역할" : roleName(role) }
    private var stateLabel: String { state.isEmpty ? "전체 상태" : statusName(state) }
    private var gradeLabel: String { grade.isEmpty ? "전체 학년" : gradeName(Int(grade) ?? 0) }

    private func roleName(_ value: String) -> String {
        ["student": "학생", "teacher": "교사", "parent": "학부모", "admin": "관리자", "test": "운영 테스트"][value] ?? "역할 미설정"
    }
    private func statusName(_ value: String) -> String {
        ["active": "활성", "inactive": "비활성", "suspended": "정지", "withdrawn": "탈퇴"][value] ?? value
    }
    private func gradeName(_ value: Int) -> String {
        [10: "고1", 11: "고2", 12: "고3", 13: "N수생", 14: "대학생", 15: "직장인"][value] ?? "학년 미설정"
    }
    private func userAffiliation(_ user: ServerAPI.AdminUserSummary) -> String {
        if user.entityType == "PARENT" { return "연결 자녀 \(user.parentChildCount)명" }
        if user.schoolGrade == 14 { return user.university?.name ?? "대학교 미설정" }
        if user.schoolGrade == 13 { return "N수생" }
        if user.schoolGrade == 15 { return "직장인" }
        return user.school?.name ?? "소속 미설정"
    }
    private func recordKind(_ value: String) -> String {
        ["community": "게시판", "inquiry": "문의", "notification": "알림", "audit": "관리", "purchase": "결제", "parent-alert": "학부모 알림"][value] ?? "기록"
    }
    private func relativeDate(_ value: String?) -> String {
        parseDate(value)?.formatted(.relative(presentation: .named)) ?? ""
    }
    private func absoluteDate(_ value: String?) -> String {
        parseDate(value)?.formatted(date: .abbreviated, time: .shortened) ?? "기록 없음"
    }
    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private struct AdminUserActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form = AdminUserActionForm()
    @State private var confirms = false
    @State private var isSaving = false

    let request: AdminUserActionRequest
    let onSubmit: (AdminUserActionForm) async -> Bool

    var body: some View {
        NavigationStack {
            Form { fields }
                .navigationTitle(title)
                .interactiveDismissDisabled(isSaving)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }.disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(actionTitle) { confirms = true }.disabled(!isValid || isSaving)
                    }
                }
                .confirmationDialog(confirmTitle, isPresented: $confirms, titleVisibility: .visible) {
                    Button(actionTitle, role: request.kind == .withdraw || request.kind == .parentUnlink ? .destructive : nil) {
                        isSaving = true
                        Task {
                            if await onSubmit(form) { dismiss() }
                            isSaving = false
                        }
                    }
                    Button("취소", role: .cancel) {}
                } message: { Text(confirmMessage) }
        }
        .onAppear { seed() }
    }

    @ViewBuilder private var fields: some View {
        Section("대상") {
            Text(request.child?.name ?? request.user.name)
            Text(request.child?.email ?? request.user.email).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        switch request.kind {
        case .notification:
            Section("앱 알림") {
                TextField("제목", text: $form.title)
                TextEditor(text: $form.message).frame(minHeight: 150)
                TextField("이동 경로", text: $form.href).textInputAutocapitalization(.never)
            }
        case .email:
            Section("이메일") {
                TextField("제목", text: $form.title)
                TextEditor(text: $form.message).frame(minHeight: 180)
            }
        case .passwordReset:
            Section("비밀번호 원문은 확인하지 않습니다") {
                Text("가입 이메일로 10분 동안 한 번만 사용할 수 있는 재설정 링크를 보냅니다.")
            }
        case .nickname:
            reasonField("부적절한 닉네임 변경 요청 사유")
        case .role:
            Section("역할") {
                Picker("새 역할", selection: $form.role) {
                    Text("학생").tag("student"); Text("교사").tag("teacher"); Text("관리자").tag("admin")
                }
                if form.role == "teacher" {
                    DatePicker("학원 기능 만료일", selection: $form.teacherExpiry, in: Date()..., displayedComponents: .date)
                }
            }
            reasonField("역할 변경 사유")
        case .status:
            Section("계정 상태") {
                Picker("상태", selection: $form.status) {
                    Text("활성").tag("active"); Text("비활성").tag("inactive"); Text("정지").tag("suspended")
                }
                if form.status == "suspended" {
                    TextField("정지 기간(일, 비우면 무기한)", text: $form.suspensionDays).keyboardType(.numberPad)
                }
            }
            reasonField("계정 상태 변경 사유")
        case .warnings:
            Section("경고 횟수") {
                Stepper("\(form.warningCount)회", value: $form.warningCount, in: 0...999)
                Text("3회 이상이면 학생·교사 계정은 즉시 정지됩니다.").font(.mCaption)
            }
            reasonField("경고 횟수 수정 사유")
        case .package:
            Section("패키지 권한") {
                Picker("적용 권한", selection: $form.packageType) {
                    Text("기본학습 패키지").tag("FREE")
                    Text("주간 모의고사 이용권").tag("MOCK_EXAM_ONLY")
                    Text("29일 학습권 패키지").tag("LEARNING_PACKAGE")
                }
                Text("미정산 경기나 예치·예약 학습일수가 있으면 서버가 변경을 차단합니다.").font(.mCaption)
            }
            reasonField("패키지 변경 사유")
        case .withdraw:
            Section("데이터 처리") {
                Picker("삭제 방식", selection: $form.dataRetention) {
                    Text("개인정보 제거·익명 통계 보존").tag("anonymous")
                    Text("모든 활동 데이터 영구 삭제").tag("purged")
                }
                Text("삭제한 계정은 복구할 수 없습니다.").foregroundStyle(Tokens.dangerInk)
            }
            reasonField("계정 삭제 사유")
            Section("확인") { TextField("계정삭제 입력", text: $form.confirmation) }
        case .parentStatus:
            Section("학부모 계정") {
                Toggle("로그인·자녀 조회 허용", isOn: $form.parentActive)
                Text("비활성화해도 자녀 학습 데이터와 연결 기록은 유지됩니다.").font(.mCaption)
            }
            reasonField("상태 변경 사유")
        case .parentNotifications:
            Section("이메일") { Toggle("학부모 이메일 알림", isOn: $form.emailEnabled) }
            Section("학습 저조") {
                Toggle("학습 저조 알림", isOn: $form.lowLearningEnabled)
                if form.lowLearningEnabled {
                    Picker("하루 최소 학습", selection: $form.minimumMinutesPerDay) {
                        ForEach([10, 20, 30, 45, 60], id: \.self) { Text("\($0)분").tag($0) }
                    }
                    Picker("연속 기준", selection: $form.lowLearningConsecutiveDays) {
                        ForEach([2, 3, 5, 7], id: \.self) { Text("\($0)일").tag($0) }
                    }
                }
            }
            Section("장기 미접속") {
                Toggle("미접속 알림", isOn: $form.inactivityEnabled)
                if form.inactivityEnabled {
                    Picker("미접속 기준", selection: $form.inactivityDays) {
                        ForEach([3, 5, 7, 14, 30], id: \.self) { Text("\($0)일").tag($0) }
                    }
                }
            }
        case .parentUnlink:
            Section("연결 해제") {
                Text("이 학부모는 해당 학생의 학습·랭킹·결제·알림 정보를 더 이상 볼 수 없습니다. 학생 데이터는 삭제되지 않습니다.")
            }
            reasonField("연결 해제 사유")
        }
    }

    private func reasonField(_ label: String) -> some View {
        Section("사유") { TextEditor(text: $form.reason).frame(minHeight: 100).accessibilityLabel(label) }
    }

    private func seed() {
        form.role = request.user.role == "test" ? "student" : request.user.role
        form.status = ["active", "inactive", "suspended"].contains(request.user.accountStatus)
            ? request.user.accountStatus : "active"
        form.warningCount = request.user.warningCount
        form.parentActive = request.user.isActive
        if let child = request.child {
            form.emailEnabled = child.emailEnabled
            form.lowLearningEnabled = child.lowLearningEnabled
            form.minimumMinutesPerDay = child.minimumMinutesPerDay
            form.lowLearningConsecutiveDays = child.lowLearningConsecutiveDays
            form.inactivityEnabled = child.inactivityEnabled
            form.inactivityDays = child.inactivityDays
        }
    }

    private var isValid: Bool {
        let reason = form.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        switch request.kind {
        case .notification: return form.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !form.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && form.href.hasPrefix("/")
        case .email: return form.title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && form.message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
        case .passwordReset, .parentNotifications: return true
        case .withdraw: return !reason.isEmpty && form.confirmation == "계정삭제"
        default: return !reason.isEmpty
        }
    }

    private var title: String {
        switch request.kind {
        case .notification: "앱 알림 보내기"; case .email: "이메일 보내기"; case .passwordReset: "비밀번호 재설정"
        case .nickname: "닉네임 변경 요청"; case .role: "역할 변경"; case .status: "계정 상태"
        case .warnings: "경고 횟수"; case .package: "패키지 권한"; case .withdraw: "계정 삭제"
        case .parentStatus: "학부모 계정 상태"; case .parentNotifications: "학부모 알림 기준"; case .parentUnlink: "자녀 연결 해제"
        }
    }
    private var actionTitle: String {
        switch request.kind {
        case .notification: "알림 전송"; case .email: "이메일 전송"; case .passwordReset: "링크 전송"
        case .nickname: "요청 전송"; case .role, .status, .warnings, .package, .parentStatus, .parentNotifications: "저장"
        case .withdraw: "계정 삭제"; case .parentUnlink: "연결 해제"
        }
    }
    private var confirmTitle: String { "\(actionTitle)할까요?" }
    private var confirmMessage: String {
        request.kind == .withdraw ? "계정 삭제는 되돌릴 수 없습니다. 대상과 데이터 처리 방식을 다시 확인하세요."
            : "\(request.child?.name ?? request.user.name) 대상 작업입니다. 내용을 확인하세요."
    }
}
