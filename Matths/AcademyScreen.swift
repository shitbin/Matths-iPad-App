import SwiftUI

struct AcademyPreviewFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct AcademyAssignmentPresentation {
    let response: ServerAPI.AcademyWeekResponse
    let owner: AccountRequestOwner
}

@MainActor
final class AcademyScreenModel: ObservableObject {
    @Published var dashboard: ServerAPI.AcademyDashboard?
    @Published var selectedWeek: ServerAPI.AcademyWeekResponse?
    @Published var isLoading = false
    var actionInProgress: Bool { actionID != nil || weekRequestID != nil }
    @Published var downloadingFileID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?
    @Published var inviteCode = ""
    @Published var selectedAcademyID = ""
    @Published var consent = false
    @Published var attendanceCode = ""
    @Published var previewFile: AcademyPreviewFile?

    private var generation = UUID()
    private var isActive = true
    private var loadRequestID: UUID?
    private var downloadRequestID: UUID?
    @Published private var actionID: UUID?
    @Published private var weekRequestID: UUID?

    var inviteRequestDisabledReason: String? {
        if actionInProgress { return "승인 요청을 보내고 있습니다." }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code.isEmpty { return "선생님께 받은 초대 코드를 입력해 주세요." }
        if code.range(of: #"^MTH-[A-Z2-9]{6}$"#, options: .regularExpression) == nil {
            return "MTH- 뒤의 영문·숫자 6자리를 확인해 주세요."
        }
        if !consent { return "학습 현황 공유에 동의한 뒤 요청할 수 있습니다." }
        return nil
    }

    var academyRequestDisabledReason: String? {
        if actionInProgress { return "승인 요청을 보내고 있습니다." }
        guard let dashboard, !dashboard.academies.isEmpty else {
            return "선택할 수 있는 학원이 없습니다. 초대 코드를 이용해 주세요."
        }
        guard dashboard.academies.contains(where: { $0.id == selectedAcademyID }) else {
            return "연결할 학원을 선택해 주세요."
        }
        if !consent { return "학습 현황 공유에 동의한 뒤 요청할 수 있습니다." }
        return nil
    }

    func activate() { isActive = true }

    func retire() { reset(); isActive = false }

    func reset() {
        generation = UUID()
        loadRequestID = nil; downloadRequestID = nil; actionID = nil; weekRequestID = nil
        isLoading = false
        dashboard = nil
        selectedWeek = nil
        previewFile = nil; downloadingFileID = nil
        errorMessage = nil
        noticeMessage = nil
        inviteCode = ""; selectedAcademyID = ""; consent = false; attendanceCode = ""
    }

    func load(owner: AccountRequestOwner, store: AppStore) async {
        guard isActive, owner.isCurrent(in: store) else { return }
        let requestGeneration = generation
        let requestID = UUID(); loadRequestID = requestID
        isLoading = dashboard == nil
        errorMessage = nil
        defer { if requestGeneration == generation, loadRequestID == requestID { isLoading = false; loadRequestID = nil } }
        do {
            let value = try await ServerAPI.academyDashboard(authorization: owner.authorization)
            guard requestGeneration == generation, loadRequestID == requestID, owner.isCurrent(in: store) else { return }
            install(value)
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, loadRequestID == requestID, owner.isCurrent(in: store) else { return }
            errorMessage = readable(error)
        }
    }

    func requestWithInviteCode(owner: AccountRequestOwner, store: AppStore) async {
        guard isActive, owner.isCurrent(in: store) else { return }
        if let reason = inviteRequestDisabledReason {
            errorMessage = reason
            return
        }
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        await perform(success: "학원 승인 요청을 보냈습니다.", owner: owner, store: store) {
            try await ServerAPI.requestAcademy(inviteCode: code, authorization: owner.authorization)
        }
    }

    func requestSelectedAcademy(owner: AccountRequestOwner, store: AppStore) async {
        guard isActive, owner.isCurrent(in: store) else { return }
        if let reason = academyRequestDisabledReason {
            errorMessage = reason
            return
        }
        let academyID = selectedAcademyID
        await perform(success: "학원 승인 요청을 보냈습니다.", owner: owner, store: store) {
            try await ServerAPI.requestAcademy(academyID: academyID, authorization: owner.authorization)
        }
    }

    func leave(owner: AccountRequestOwner, store: AppStore) async {
        await perform(success: dashboard?.membership?.status == "PENDING"
                      ? "승인 요청을 취소했습니다."
                      : "학원 연결을 해제했습니다.", requiresConsent: false, owner: owner, store: store) {
            try await ServerAPI.leaveAcademy(authorization: owner.authorization)
        }
    }

    func checkIn(owner: AccountRequestOwner, store: AppStore) async {
        guard isActive, owner.isCurrent(in: store), actionID == nil,
              let sessionID = dashboard?.attendance?.session.id else { return }
        let code = attendanceCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code.range(of: #"^\d{6}$"#, options: .regularExpression) != nil else {
            errorMessage = "출석 코드 6자리를 입력해 주세요."
            return
        }
        let requestGeneration = generation
        let requestID = UUID(); actionID = requestID
        loadRequestID = nil; isLoading = false
        defer { if requestGeneration == generation, actionID == requestID { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let record = try await ServerAPI.checkInAcademyAttendance(
                sessionID: sessionID, code: code, authorization: owner.authorization)
            guard requestGeneration == generation, actionID == requestID, owner.isCurrent(in: store) else { return }
            attendanceCode = ""
            noticeMessage = record.status == "LATE" ? "지각으로 출석 처리됐습니다." : "출석이 확인됐습니다."
            await load(owner: owner, store: store)
        } catch {
            guard requestGeneration == generation, actionID == requestID, owner.isCurrent(in: store) else { return }
            errorMessage = readable(error)
        }
    }

    func openWeek(_ weekID: String, owner: AccountRequestOwner, store: AppStore) async {
        guard isActive, owner.isCurrent(in: store) else { return }
        let requestGeneration = generation
        let requestID = UUID(); weekRequestID = requestID
        defer { if requestGeneration == generation, weekRequestID == requestID { weekRequestID = nil } }
        errorMessage = nil
        do {
            let value = try await ServerAPI.academyWeek(weekID, authorization: owner.authorization)
            guard requestGeneration == generation, weekRequestID == requestID, owner.isCurrent(in: store) else { return }
            selectedWeek = value
        } catch {
            guard requestGeneration == generation, weekRequestID == requestID, owner.isCurrent(in: store) else { return }
            errorMessage = readable(error)
        }
    }

    func closeWeek() {
        weekRequestID = nil; downloadRequestID = nil; downloadingFileID = nil
        selectedWeek = nil; previewFile = nil
    }

    func download(weekID: String, file: ServerAPI.AcademyWeek.File, owner: AccountRequestOwner, store: AppStore) async {
        guard isActive, downloadingFileID == nil, owner.isCurrent(in: store) else { return }
        let requestGeneration = generation
        let requestID = UUID(); downloadRequestID = requestID
        downloadingFileID = file.id
        errorMessage = nil
        defer { if requestGeneration == generation, downloadRequestID == requestID { downloadingFileID = nil; downloadRequestID = nil } }
        do {
            let url = try await ServerAPI.downloadAcademyFile(weekID: weekID, file: file, account: owner.slot, authorization: owner.authorization)
            guard requestGeneration == generation, downloadRequestID == requestID, owner.isCurrent(in: store) else { return }
            previewFile = AcademyPreviewFile(url: url)
        } catch {
            guard requestGeneration == generation, downloadRequestID == requestID, owner.isCurrent(in: store) else { return }
            errorMessage = readable(error)
        }
    }

    private func perform(
        success: String,
        requiresConsent: Bool = true,
        owner: AccountRequestOwner,
        store: AppStore,
        operation: () async throws -> ServerAPI.AcademyDashboard
    ) async {
        guard isActive, owner.isCurrent(in: store), actionID == nil else { return }
        guard !requiresConsent || consent else {
            errorMessage = "학원과 학습 현황을 공유하는 데 동의해 주세요."
            return
        }
        let requestGeneration = generation
        let requestID = UUID(); actionID = requestID
        loadRequestID = nil; isLoading = false
        defer { if requestGeneration == generation, actionID == requestID { actionID = nil } }
        errorMessage = nil
        noticeMessage = nil
        do {
            let value = try await operation()
            guard requestGeneration == generation, actionID == requestID, owner.isCurrent(in: store) else { return }
            loadRequestID = nil; isLoading = false
            install(value)
            noticeMessage = success
        } catch {
            guard requestGeneration == generation, actionID == requestID, owner.isCurrent(in: store) else { return }
            errorMessage = readable(error)
        }
    }

    private func install(_ value: ServerAPI.AcademyDashboard) {
        dashboard = value
        if value.membership?.status != "APPROVED" { closeWeek(); attendanceCode = "" }
        // A list refresh must not silently select another academy. In particular,
        // an already consented student must choose again if their selection vanished.
        if !value.academies.contains(where: { $0.id == selectedAcademyID }) {
            selectedAcademyID = ""
        }
    }

    private func readable(_ error: Error) -> String {
        if (error as? ServerAPIError)?.statusCode == 403 { reset() }
        return (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 학생이 웹 로그인을 다시 하지 않고 학원 소속·출석·주차별 수업·과제를 처리하는 화면.
/// 교사와 운영자 관리 기능은 역할별 관리 포털로 남기되 학생의 반복 행동은 네이티브가 소유한다.
struct AcademyScreen: View {
    @EnvironmentObject private var store: AppStore
    var initialWeekID: String? = nil
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = AcademyScreenModel()
    @State private var confirmsLeaving = false
    @State private var owner: AccountRequestOwner?
    @State private var leavingOwner: AccountRequestOwner?
    @State private var appliedInitialWeek = false
    @State private var assignmentPresentation: AcademyAssignmentPresentation?

    private var compactLandscape: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        GeometryReader { viewport in
            Group {
                if let assignment = assignmentPresentation {
                    AcademyAssignmentStudentScreen(response: assignment.response, owner: assignment.owner, store: store) {
                        assignmentPresentation = nil
                        guard assignment.owner.isCurrent(in: store) else { return }
                        Task { await model.openWeek(assignment.response.week.id, owner: assignment.owner, store: store) }
                    }
                    .id(assignment.owner.id)
                } else if let detail = model.selectedWeek {
                    weekDetail(detail, viewport: viewport)
                } else if model.isLoading && model.dashboard == nil {
                    loadingState
                } else if let dashboard = model.dashboard {
                    dashboardView(dashboard, viewport: viewport)
                } else {
                    failureState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Tokens.paper)
        .onAppear {
            model.activate()
            owner = AccountRequestOwner(store: store)
            let weekID = appliedInitialWeek ? nil : initialWeekID
            appliedInitialWeek = true
            run { owner in
                if model.dashboard == nil { await model.load(owner: owner, store: store) }
                if let weekID, model.dashboard?.membership?.status == "APPROVED", model.selectedWeek == nil {
                    await model.openWeek(weekID, owner: owner, store: store)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            resetAccount()
        }
        .onChange(of: owner?.isCurrent(in: store) ?? true) { _, current in
            if !current { resetAccount() }
        }
        .onDisappear { model.retire(); owner = nil; leavingOwner = nil; confirmsLeaving = false; assignmentPresentation = nil }
        .alert("학원 연결을 해제할까요?", isPresented: $confirmsLeaving) {
            Button("취소", role: .cancel) {}
            Button(model.dashboard?.membership?.status == "PENDING" ? "요청 취소" : "연결 해제",
                   role: .destructive) {
                guard let owner = leavingOwner, owner.isCurrent(in: store) else { return }
                leavingOwner = nil
                Task { await model.leave(owner: owner, store: store) }
            }
        } message: {
            Text(model.dashboard?.membership?.status == "PENDING"
                 ? "보낸 승인 요청을 취소합니다."
                 : "학원에 학습 현황 공유를 중단하고 반·과제 접근을 해제합니다.")
        }
        .compactHeightSheet(item: $model.previewFile) { preview in
            CommunityFilePreview(url: preview.url) { model.previewFile = nil }
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func dashboardView(_ dashboard: ServerAPI.AcademyDashboard, viewport: GeometryProxy) -> some View {
        if dashboard.membership == nil {
            joinView(dashboard, viewport: viewport)
        } else if dashboard.membership?.status == "PENDING" {
            pendingView(dashboard)
        } else if dashboard.membership?.status == "APPROVED" {
            approvedView(dashboard, viewport: viewport)
        } else {
            joinView(dashboard, viewport: viewport)
        }
    }

    private func approvedView(
        _ dashboard: ServerAPI.AcademyDashboard,
        viewport: GeometryProxy
    ) -> some View {
        Group {
            if compactLandscape {
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    VStack(spacing: Tokens.Space.s3) {
                        academyIdentity(dashboard)
                        attendanceCard(dashboard.attendance)
                        managementRow
                    }
                    .frame(width: min(310, viewport.size.width * 0.34))

                    weekList(dashboard)
                }
                .padding(.horizontal, max(12, viewport.safeAreaInsets.leading + 12))
                .padding(.vertical, Tokens.Space.s2)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.s5) {
                        academyIdentity(dashboard)
                        attendanceCard(dashboard.attendance)
                        weekList(dashboard)
                        managementRow
                    }
                    .readableWidth(Tokens.readableWidth)
                    .adaptiveHPadding()
                    .adaptiveVPadding()
                }
                .refreshable {
                    if let owner, owner.isCurrent(in: store) { await model.load(owner: owner, store: store) }
                }
            }
        }
        .overlay(alignment: .top) { feedbackBanner }
    }

    private func academyIdentity(_ dashboard: ServerAPI.AcademyDashboard) -> some View {
        HStack(spacing: Tokens.Space.s3) {
            Text(dashboard.academy?.name.first.map(String.init) ?? "학")
                .font(.mHeading)
                .foregroundStyle(Tokens.onBrand)
                .frame(width: 48, height: 48)
                .background(Tokens.actionPrimary,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(dashboard.academy?.name ?? "내 학원")
                    .font(compactLandscape ? .mBodyB : .mTitle)
                    .foregroundStyle(Tokens.ink)
                    .lineLimit(compactLandscape ? 2 : 1)
                    .layoutPriority(1)
                Text(dashboard.academyClass.map { "\($0.name) · 주차별 수업과 과제" }
                     ?? "반 배정을 기다리고 있습니다")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text("\(dashboard.weeks.count)주")
                .font(.mBodyB)
                .foregroundStyle(Tokens.primary)
        }
        .padding(Tokens.Space.s4)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func attendanceCard(_ attendance: ServerAPI.AcademyAttendanceDashboard?) -> some View {
        if let attendance {
            VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                HStack {
                    Label("출석", systemImage: attendanceSymbol(attendance))
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                    Spacer()
                    Text(attendanceLabel(attendance))
                        .font(.mCaption)
                        .foregroundStyle(attendance.attendance == nil ? Tokens.text2 : Tokens.primary)
                }
                Text(sessionSchedule(attendance.session))
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
                if attendance.canCheckIn {
                    HStack(spacing: Tokens.Space.s2) {
                        TextField("6자리 코드", text: $model.attendanceCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                            .font(.mBodyB.monospacedDigit())
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: model.attendanceCode) { _, value in
                                model.attendanceCode = String(value.filter(\.isNumber).prefix(6))
                            }
                        Button("출석 확인") { run { await model.checkIn(owner: $0, store: store) } }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(model.attendanceCode.count != 6 || model.actionInProgress)
                    }
                }
            }
            .padding(Tokens.Space.s4)
            .background(Tokens.primarySoft,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        }
    }

    private func weekList(_ dashboard: ServerAPI.AcademyDashboard) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("주차별 수업")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                    Text("개념을 바로 열고 과제 자료를 확인하세요.")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                }
                Spacer()
                if model.actionInProgress { ProgressView().tint(Tokens.primary) }
            }
            if dashboard.academyClass == nil {
                inlineEmpty("아직 배정된 반이 없습니다", "선생님이 반을 배정하면 수업과 과제가 여기에 표시됩니다.")
            } else if dashboard.weeks.isEmpty {
                inlineEmpty("아직 공개된 주차가 없습니다", "첫 수업이 등록되면 이 화면에 바로 표시됩니다.")
            } else if compactLandscape {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(dashboard.weeks) { week in weekCard(week) }
                    }
                }
                .refreshable {
                    if let owner, owner.isCurrent(in: store) { await model.load(owner: owner, store: store) }
                }
            } else {
                LazyVStack(spacing: Tokens.Space.s2) {
                    ForEach(dashboard.weeks) { week in weekCard(week) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func weekCard(_ week: ServerAPI.AcademyWeek) -> some View {
        Button { run { await model.openWeek(week.id, owner: $0, store: store) } } label: {
            HStack(spacing: Tokens.Space.s3) {
                VStack(spacing: 0) {
                    Text("\(week.weekNumber)")
                        .font(.mHeading.monospacedDigit())
                    Text("주")
                        .font(.mMicro)
                }
                .foregroundStyle(Tokens.primary)
                .frame(width: 46, height: 46)
                .background(Tokens.primarySoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(week.title)
                        .font(.mBodyB)
                        .foregroundStyle(Tokens.ink)
                        .lineLimit(1)
                    Text("\(week.concepts.count)개 개념 · 파일 \(week.files.count)개 · \(dueLabel(week.dueAt))")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(Tokens.text3)
                    .accessibilityHidden(true)
            }
            .padding(Tokens.Space.s3)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(week.weekNumber)주차, \(week.title), \(week.concepts.count)개 개념")
    }

    private var managementRow: some View {
        HStack {
            Spacer(minLength: 0)
            Button("연결 해제", role: .destructive, action: confirmLeaving)
                .font(.mCaption)
                .foregroundStyle(Tokens.dangerInk)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
    }

    private func pendingView(_ dashboard: ServerAPI.AcademyDashboard) -> some View {
        stateShell {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Tokens.primary)
            Text("승인을 기다리고 있습니다")
                .font(.mTitle)
                .foregroundStyle(Tokens.ink)
            Text("\(dashboard.academy?.name ?? "학원")에서 승인하면 반·출석·주차별 수업이 자동으로 열립니다.")
                .font(.mBody)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Button("승인 요청 취소", role: .destructive, action: confirmLeaving)
                .buttonStyle(SecondaryButtonStyle())
                .disabled(model.actionInProgress)
            feedbackText
        }
    }

    private func joinView(
        _ dashboard: ServerAPI.AcademyDashboard,
        viewport: GeometryProxy
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    Text("내 학원 연결")
                        .font(compactLandscape ? .mHeading : .mTitle)
                        .foregroundStyle(Tokens.ink)
                    Text("초대 코드가 있으면 바로 요청하고, 없으면 등록된 학원을 선택하세요.")
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                }
                Toggle(isOn: $model.consent) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("학습 현황 공유 동의")
                            .font(.mBodyB)
                            .foregroundStyle(Tokens.ink)
                        Text("연결 승인 후 학원 선생님이 진도·시험·오답·출석 현황을 확인할 수 있습니다.")
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                    }
                }
                .tint(Tokens.actionPrimary)
                .disabled(model.actionInProgress)
                Group {
                    if compactLandscape {
                        HStack(alignment: .top, spacing: Tokens.Space.s3) {
                            inviteCodeCard
                            academyPickerCard(dashboard.academies)
                        }
                    } else {
                        VStack(spacing: Tokens.Space.s3) {
                            inviteCodeCard
                            academyPickerCard(dashboard.academies)
                        }
                    }
                }
                feedbackText
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 16))
            .padding(.vertical, compactLandscape ? Tokens.Space.s2 : Tokens.Space.s6)
        }
    }

    private var inviteCodeCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label("초대 코드", systemImage: "ticket.fill")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            TextField("MTH-XXXXXX", text: $model.inviteCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.mBodyB.monospaced())
                .textFieldStyle(.roundedBorder)
                .disabled(model.actionInProgress)
                .onChange(of: model.inviteCode) { _, value in
                    model.inviteCode = String(value.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }.prefix(10))
                }
            Button { run { await model.requestWithInviteCode(owner: $0, store: store) } } label: {
                Text("코드로 승인 요청").frame(maxWidth: .infinity)
            }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.inviteRequestDisabledReason != nil)
            requestRequirement(model.inviteRequestDisabledReason)
        }
        .academyCardSurface()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func academyPickerCard(_ academies: [ServerAPI.AcademySummary]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            Label("학원 선택", systemImage: "building.2.fill")
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            if academies.isEmpty {
                Text("현재 승인된 학원이 없습니다. 초대 코드를 이용해 주세요.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text2)
            } else {
                Picker("학원", selection: $model.selectedAcademyID) {
                    Text("학원을 선택해 주세요").tag("")
                    ForEach(academies) { academy in Text(academy.name).tag(academy.id) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .disabled(model.actionInProgress)
                Button { run { await model.requestSelectedAcademy(owner: $0, store: store) } } label: {
                    Text("선택한 학원에 요청").frame(maxWidth: .infinity)
                }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(model.academyRequestDisabledReason != nil)
                requestRequirement(model.academyRequestDisabledReason)
            }
        }
        .academyCardSurface()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func requestRequirement(_ message: String?) -> some View {
        if let message {
            Text(message)
                .font(.mCaption)
                .foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func weekDetail(
        _ response: ServerAPI.AcademyWeekResponse,
        viewport: GeometryProxy
    ) -> some View {
        let week = response.week
        return ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.s4) {
                HStack(spacing: Tokens.Space.s2) {
                    Button { model.closeWeek() } label: {
                        Label("주차 목록", systemImage: "chevron.left")
                            .frame(minHeight: 44)
                    }
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
                    .buttonStyle(.plain)
                    Spacer()
                    Text("\(response.academy.name) · \(response.academyClass.name)")
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                    Text(verbatim: "\(week.academicYear) · WEEK \(week.weekNumber)")
                        .font(.mMicro)
                        .foregroundStyle(Tokens.primary)
                    Text(week.title)
                        .font(compactLandscape ? .mHeading : .mTitle)
                        .foregroundStyle(Tokens.ink)
                    Text(week.lessonSummary.isEmpty
                         ? "이번 주에 배운 개념과 과제를 확인하세요."
                         : week.lessonSummary)
                        .font(.mBody)
                        .foregroundStyle(Tokens.text2)
                }
                if let omr = week.assignmentOmr, omr.enabled {
                    VStack(alignment: .leading, spacing: Tokens.Space.s2) {
                        Text("온라인 답안지 · \(omr.questionCount)문항").font(.mBodyB)
                        if let submission = response.submission, submission.isValid {
                            Text(submission.status == "MISSED" ? "마감 미제출 · 0점" : "제출 완료 · \(Int(submission.scorePercent))점")
                                .font(.mCaption).foregroundStyle(Tokens.text2)
                        }
                        Button(response.submission == nil ? "답안 작성·제출" : "제출 내역·답안 수정") {
                            guard let owner, owner.isCurrent(in: store) else { return }
                            assignmentPresentation = .init(response: response, owner: owner)
                        }.buttonStyle(PrimaryButtonStyle()).disabled(!omr.isValid)
                    }.academyCardSurface()
                }
                Group {
                    if compactLandscape {
                        HStack(alignment: .top, spacing: Tokens.Space.s3) {
                            conceptPanel(week).frame(maxWidth: .infinity)
                            assignmentPanel(week).frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: Tokens.Space.s4) {
                            conceptPanel(week)
                            assignmentPanel(week)
                        }
                    }
                }
                feedbackText
            }
            .frame(maxWidth: Tokens.readableWidth, alignment: .leading)
            .padding(.horizontal, max(16, viewport.safeAreaInsets.leading + 16))
            .padding(.vertical, compactLandscape ? Tokens.Space.s2 : Tokens.Space.s5)
        }
    }

    private func conceptPanel(_ week: ServerAPI.AcademyWeek) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("이번 주 개념")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            ForEach(week.concepts) { concept in
                Button {
                    store.openConceptV2(concept.conceptId)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(concept.courseTitle) · \(concept.unitTitle)")
                                .font(.mMicro)
                                .foregroundStyle(Tokens.text3)
                            Text(concept.conceptTitle)
                                .font(.mBodyB)
                                .foregroundStyle(Tokens.ink)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Tokens.primary)
                    }
                    .padding(Tokens.Space.s3)
                    .background(Tokens.paper,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(concept.conceptTitle) 개념 학습 열기")
            }
        }
        .academyCardSurface()
    }

    private func assignmentPanel(_ week: ServerAPI.AcademyWeek) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s3) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("과제")
                        .font(.mHeading)
                        .foregroundStyle(Tokens.ink)
                    Text(dueLabel(week.dueAt))
                        .font(.mCaption)
                        .foregroundStyle(Tokens.text2)
                }
                Spacer()
                Text("파일 \(week.files.count)개")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
            }
            Text(week.assignmentTitle)
                .font(.mBodyB)
                .foregroundStyle(Tokens.ink)
            if !week.assignmentInstructions.isEmpty {
                Text(week.assignmentInstructions)
                    .font(.mBody)
                    .foregroundStyle(Tokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if week.files.isEmpty {
                Text("첨부 파일이 없는 과제입니다.")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.text3)
            } else {
                ForEach(week.files) { file in
                    Button {
                        run { await model.download(weekID: week.id, file: file, owner: $0, store: store) }
                    } label: {
                        HStack(spacing: Tokens.Space.s2) {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundStyle(Tokens.primary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.originalName)
                                    .font(.mCaption)
                                    .foregroundStyle(Tokens.ink)
                                    .lineLimit(1)
                                Text(byteLabel(file.sizeBytes))
                                    .font(.mMicro)
                                    .foregroundStyle(Tokens.text3)
                            }
                            Spacer()
                            if model.downloadingFileID == file.id {
                                ProgressView().tint(Tokens.primary)
                            } else {
                                Text("열기").font(.mCaption).foregroundStyle(Tokens.primary)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.downloadingFileID != nil)
                }
            }
        }
        .academyCardSurface()
    }

    private var feedbackBanner: some View {
        feedbackText
            .padding(.horizontal, Tokens.Space.s3)
            .padding(.top, Tokens.Space.s2)
    }

    @ViewBuilder private var feedbackText: some View {
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.mCaption)
                .foregroundStyle(Tokens.dangerInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.dangerSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        } else if let notice = model.noticeMessage {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.mCaption)
                .foregroundStyle(Tokens.successInk)
                .padding(Tokens.Space.s2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.successSoft,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        }
    }

    private var loadingState: some View {
        stateShell {
            ProgressView().tint(Tokens.primary)
            Text("학원 정보를 불러오는 중입니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
        }
    }

    private var failureState: some View {
        stateShell {
            Image(systemName: "wifi.exclamationmark")
                .font(.mTitle)
                .foregroundStyle(Tokens.primary)
            Text("학원 정보를 불러오지 못했습니다")
                .font(.mHeading)
                .foregroundStyle(Tokens.ink)
            feedbackText
            Button("다시 시도") { run { await model.load(owner: $0, store: store) } }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func run(_ operation: @escaping (AccountRequestOwner) async -> Void) {
        guard let owner, owner.isCurrent(in: store) else { return }
        Task {
            guard owner.isCurrent(in: store) else { return }
            await operation(owner)
        }
    }

    private func resetAccount() {
        model.reset(); confirmsLeaving = false; leavingOwner = nil; assignmentPresentation = nil
        owner = AccountRequestOwner(store: store)
        run { await model.load(owner: $0, store: store) }
    }

    private func confirmLeaving() {
        guard let owner, owner.isCurrent(in: store) else { return }
        leavingOwner = owner
        confirmsLeaving = true
    }

    private func stateShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s4) { content() }
            .padding(Tokens.Space.s5)
            .frame(maxWidth: 560, alignment: .leading)
            .background(Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
            .padding(Tokens.Space.s4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func inlineEmpty(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text(title).font(.mBodyB).foregroundStyle(Tokens.ink)
            Text(message).font(.mCaption).foregroundStyle(Tokens.text2)
        }
        .padding(Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
    }

    private func attendanceLabel(_ dashboard: ServerAPI.AcademyAttendanceDashboard) -> String {
        guard let status = dashboard.attendance?.status else {
            switch dashboard.session.state {
            case "OPEN": return dashboard.canCheckIn ? "출석 가능" : "확인 중"
            case "SCHEDULED": return "예정"
            case "CLOSED": return "마감"
            default: return "수업 없음"
            }
        }
        return ["PRESENT": "출석", "LATE": "지각", "ABSENT": "결석", "EXCUSED": "인정결석"][status]
            ?? status
    }

    private func attendanceSymbol(_ dashboard: ServerAPI.AcademyAttendanceDashboard) -> String {
        dashboard.attendance == nil ? "person.badge.clock" : "checkmark.circle.fill"
    }

    private func sessionSchedule(_ session: ServerAPI.AcademyAttendanceDashboard.Session) -> String {
        let weekday = session.dateKey
        let start = timeLabel(session.startsAt)
        let end = timeLabel(session.endsAt)
        return "\(weekday) · \(start)–\(end)"
    }

    private func dueLabel(_ raw: String?) -> String {
        guard let raw, let date = parseDate(raw) else { return "마감일 없음" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일 (E) HH:mm 마감"
        return formatter.string(from: date)
    }

    private func timeLabel(_ raw: String) -> String {
        guard let date = parseDate(raw) else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func parseDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    private func byteLabel(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

private struct AcademyCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Expand before drawing the surface. Expanding after this modifier
            // only adds empty space around an intrinsic-width picker card.
            .frame(maxWidth: .infinity, alignment: .leading)
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
    func academyCardSurface() -> some View { modifier(AcademyCardSurface()) }
}
