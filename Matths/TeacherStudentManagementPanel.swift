import SwiftUI

@MainActor
private final class TeacherStudentManagementModel: ObservableObject {
    @Published var listing: ServerAPI.TeacherStudentPage?
    @Published var detail: ServerAPI.TeacherStudentDetail?
    @Published var selectedMembershipID: String?
    @Published var selectedIDs: Set<String> = []
    @Published var query = ""
    @Published var isLoading = false
    @Published var isDetailLoading = false
    @Published var actionID: String?
    @Published var errorMessage: String?
    @Published var noticeMessage: String?

    private var generation = UUID()
    private var listingRequestID = UUID()
    private var detailRequestID = UUID()

    func load(page: Int = 1, selectFirst: Bool = true) async {
        let requestGeneration = generation
        let requestID = UUID()
        listingRequestID = requestID
        // 기존 목록은 유지한 채 페이지 버튼만 잠근다. 연속 탭으로 서로 다른 페이지
        // 요청이 겹쳐 늦게 온 응답이 현재 페이지를 되돌리는 일을 막는다.
        isLoading = true
        errorMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyStudents(page: page)
            guard requestGeneration == generation, requestID == listingRequestID else { return }
            listing = value
            selectedIDs = []
            if let selectedMembershipID,
               value.students.contains(where: { $0.id == selectedMembershipID }) {
                await select(selectedMembershipID)
            } else if selectFirst, let first = value.students.first {
                await select(first.id)
            } else {
                selectedMembershipID = nil
                detail = nil
            }
        } catch is CancellationError {
            return
        } catch {
            guard requestGeneration == generation, requestID == listingRequestID else { return }
            errorMessage = readable(error)
        }
        if requestGeneration == generation, requestID == listingRequestID { isLoading = false }
    }

    func reloadForScopeChange() async {
        generation = UUID()
        listing = nil
        detail = nil
        selectedMembershipID = nil
        selectedIDs = []
        isDetailLoading = false
        await load()
    }

    func select(_ membershipID: String, period: String? = nil) async {
        let requestID = UUID()
        detailRequestID = requestID
        selectedMembershipID = membershipID
        isDetailLoading = true
        errorMessage = nil
        do {
            let value = try await ServerAPI.teacherAcademyStudentDetail(
                membershipID: membershipID,
                period: period)
            guard selectedMembershipID == membershipID, requestID == detailRequestID else { return }
            detail = value
        } catch is CancellationError {
            return
        } catch {
            guard selectedMembershipID == membershipID, requestID == detailRequestID else { return }
            errorMessage = readable(error)
        }
        if selectedMembershipID == membershipID, requestID == detailRequestID {
            isDetailLoading = false
        }
    }

    func toggle(_ membershipID: String) {
        if selectedIDs.contains(membershipID) {
            selectedIDs.remove(membershipID)
        } else if selectedIDs.count < 20 {
            selectedIDs.insert(membershipID)
        } else {
            errorMessage = "학생은 한 번에 최대 20명까지 관리할 수 있습니다."
        }
    }

    func selectAll(_ memberships: [ServerAPI.TeacherAcademyMembership]) {
        let ids = Set(memberships.prefix(20).map(\.id))
        selectedIDs = selectedIDs == ids ? [] : ids
    }

    func apply(action: String, classID: String? = nil) async -> Bool {
        let ids = Array(selectedIDs).sorted()
        guard !ids.isEmpty, actionID == nil else { return false }
        actionID = "bulk-\(action)"
        errorMessage = nil
        noticeMessage = nil
        do {
            let result = try await ServerAPI.bulkManageAcademyStudents(
                membershipIDs: ids,
                action: action,
                classID: classID)
            let label = switch result.action {
            case "ASSIGN_CLASS": "반 배정"
            case "UNASSIGN_CLASS": "반 배정 해제"
            default: "학원 소속 해제"
            }
            noticeMessage = "학생 \(result.count)명의 \(label) 작업을 완료했습니다."
            let currentPage = listing?.page ?? 1
            await load(page: currentPage)
            actionID = nil
            return true
        } catch {
            errorMessage = readable(error)
            actionID = nil
            return false
        }
    }

    private func readable(_ error: Error) -> String {
        (error as? ServerAPIError)?.errorDescription
            ?? (error as NSError).localizedDescription
    }
}

/// 웹 학생 관리의 페이지형 명단·월간 통계·수학 지도를 가로 화면용 좌우 작업대로 묶는다.
/// 왼쪽 명단과 오른쪽 상세는 각각 스크롤해, iPhone 가로에서 상단 탭과 핵심 작업 버튼이
/// 화면 밖으로 밀려나지 않는다.
struct TeacherStudentManagementPanel: View {
    let initialMembershipID: String?
    let onChanged: @MainActor () async -> Void

    init(
        initialMembershipID: String? = nil,
        onChanged: @escaping @MainActor () async -> Void
    ) {
        self.initialMembershipID = initialMembershipID
        self.onChanged = onChanged
    }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = TeacherStudentManagementModel()
    @State private var selectionMode = false
    @State private var removingSelection = false

    private var splitLayout: Bool {
        verticalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }

    private var filteredStudents: [ServerAPI.TeacherAcademyMembership] {
        guard let students = model.listing?.students else { return [] }
        let needle = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedLowercase
        guard !needle.isEmpty else { return students }
        return students.filter { membership in
            let values = [
                membership.student.name,
                membership.student.nickname ?? "",
                membership.student.school?.name ?? "",
                membership.academyClass?.name ?? "미배정",
            ]
            return values.contains { $0.localizedLowercase.contains(needle) }
        }
    }

    var body: some View {
        Group {
            if model.isLoading && model.listing == nil {
                ProgressView("학생 명단을 불러오는 중입니다")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let listing = model.listing {
                if splitLayout {
                    HStack(alignment: .top, spacing: Tokens.Space.s3) {
                        rosterColumn(listing)
                            .frame(width: 320)
                        detailColumn
                    }
                } else {
                    VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                        rosterColumn(listing)
                        detailColumn
                    }
                }
            } else {
                VStack(spacing: Tokens.Space.s3) {
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 32)).foregroundStyle(Tokens.text3)
                    Text("학생 명단을 열지 못했습니다").font(.mHeading)
                    Text(model.errorMessage ?? "네트워크 연결을 확인한 뒤 다시 시도해 주세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text2)
                        .multilineTextAlignment(.center)
                    Button("다시 불러오기") { Task { await model.load() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if model.listing == nil {
                await model.load(selectFirst: initialMembershipID == nil)
            }
            if let initialMembershipID,
               model.selectedMembershipID != initialMembershipID {
                await model.select(initialMembershipID)
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-teacherStudentsSelectionFixture"),
               let students = model.listing?.students {
                selectionMode = true
                model.selectedIDs = Set(students.prefix(2).map(\.id))
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: DataScope.didSwitchNotification)) { _ in
            Task { await model.reloadForScopeChange() }
        }
        .confirmationDialog(
            "선택한 학생을 학원에서 제외할까요?",
            isPresented: $removingSelection,
            titleVisibility: .visible
        ) {
            Button("\(model.selectedIDs.count)명 제외", role: .destructive) {
                Task {
                    if await model.apply(action: "REMOVE") { await onChanged() }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("반 배정이 해제되고 선택한 학생은 더 이상 학원 수업과 과제를 볼 수 없습니다.")
        }
    }

    private func rosterColumn(_ listing: ServerAPI.TeacherStudentPage) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack(spacing: Tokens.Space.s2) {
                TextField("이름·학교·반 검색", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.mCaption)
                    .padding(.horizontal, Tokens.Space.s2)
                    .frame(minHeight: 44)
                    .background(Tokens.paper2,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                    .accessibilityLabel("현재 페이지 학생 검색")
                Button(selectionMode ? "완료" : "선택") {
                    selectionMode.toggle()
                    if !selectionMode { model.selectedIDs = [] }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }

            HStack {
                Text("승인 학생 \(listing.total)명")
                    .font(.mCaption).foregroundStyle(Tokens.text2)
                Spacer(minLength: 0)
                if selectionMode {
                    Button(model.selectedIDs.count == filteredStudents.count && !filteredStudents.isEmpty
                           ? "전체 해제" : "현재 페이지 전체") {
                        model.selectAll(filteredStudents)
                    }
                    .font(.mMicro)
                }
            }

            if filteredStudents.isEmpty {
                VStack(spacing: Tokens.Space.s2) {
                    Image(systemName: model.query.isEmpty ? "person.crop.circle.badge.plus" : "magnifyingglass")
                    Text(model.query.isEmpty ? "승인된 학생이 없습니다" : "검색 결과가 없습니다")
                        .font(.mBodyB)
                    Text(model.query.isEmpty
                         ? "초대 코드를 보내거나 승인 요청을 처리해 주세요."
                         : "이름·학교·반 이름을 다시 확인해 주세요.")
                        .font(.mCaption).foregroundStyle(Tokens.text3)
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.s2) {
                        ForEach(filteredStudents) { membership in
                            studentRow(membership)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .refreshable { await model.load(page: listing.page, selectFirst: false) }
                .frame(maxHeight: splitLayout ? .infinity : 360)
            }

            if selectionMode && !model.selectedIDs.isEmpty {
                bulkToolbar(listing)
            } else {
                pageControls(listing)
            }
            feedback
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.paper,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.line, lineWidth: 1)
        }
        .frame(maxHeight: splitLayout ? .infinity : nil)
    }

    private func studentRow(_ membership: ServerAPI.TeacherAcademyMembership) -> some View {
        Button {
            if selectionMode {
                model.toggle(membership.id)
            } else {
                Task { await model.select(membership.id) }
            }
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                if selectionMode {
                    Image(systemName: model.selectedIDs.contains(membership.id)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.selectedIDs.contains(membership.id)
                                         ? Tokens.primary : Tokens.text3)
                }
                Text(membership.student.name.first.map(String.init) ?? "학")
                    .font(.mCaption)
                    .foregroundStyle(Tokens.onBrand)
                    .frame(width: 34, height: 34)
                    .background(Tokens.actionPrimary,
                                in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(membership.student.name)
                        .font(.mBodyB).foregroundStyle(Tokens.ink).lineLimit(1)
                    Text(studentSubtitle(membership))
                        .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                }
                Spacer(minLength: 0)
                if !selectionMode {
                    Image(systemName: model.selectedMembershipID == membership.id
                          ? "chevron.right.circle.fill" : "chevron.right")
                        .foregroundStyle(model.selectedMembershipID == membership.id
                                         ? Tokens.primary : Tokens.text3)
                }
            }
            .padding(.horizontal, Tokens.Space.s2)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(model.selectedMembershipID == membership.id && !selectionMode
                        ? Tokens.primarySoft : Tokens.surface,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(membership.student.name), \(studentSubtitle(membership))")
        .accessibilityValue(selectionMode && model.selectedIDs.contains(membership.id) ? "선택됨" : "")
    }

    private func pageControls(_ listing: ServerAPI.TeacherStudentPage) -> some View {
        HStack(spacing: Tokens.Space.s2) {
            Button {
                Task { await model.load(page: listing.page - 1) }
            } label: {
                Label("이전", systemImage: "chevron.left")
            }
            .disabled(listing.page <= 1 || model.isLoading)
            Spacer(minLength: 0)
            Text("\(listing.page) / \(listing.totalPages)")
                .font(.mCaption.monospacedDigit()).foregroundStyle(Tokens.text2)
                .accessibilityLabel("전체 \(listing.totalPages)페이지 중 \(listing.page)페이지")
            Spacer(minLength: 0)
            Button {
                Task { await model.load(page: listing.page + 1) }
            } label: {
                Label("다음", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(listing.page >= listing.totalPages || model.isLoading)
        }
        .font(.mCaption)
        .frame(minHeight: 44)
    }

    private func bulkToolbar(_ listing: ServerAPI.TeacherStudentPage) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("\(model.selectedIDs.count)명 선택")
                .font(.mCaption).foregroundStyle(Tokens.text2)
            HStack(spacing: Tokens.Space.s2) {
                Menu("반 배정") {
                    ForEach(listing.classes) { academyClass in
                        Button(academyClass.name) {
                            Task {
                                if await model.apply(action: "ASSIGN_CLASS", classID: academyClass.id) {
                                    await onChanged()
                                }
                            }
                        }
                    }
                    Divider()
                    Button("반 배정 해제") {
                        Task {
                            if await model.apply(action: "UNASSIGN_CLASS") { await onChanged() }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Tokens.actionPrimary)
                Button("학원에서 제외", role: .destructive) { removingSelection = true }
                    .buttonStyle(.bordered)
                    .tint(Tokens.dangerInk)
            }
            .disabled(model.actionID != nil)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if model.isDetailLoading && model.detail == nil {
            ProgressView("학생 학습 기록을 불러오는 중입니다")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .teacherStudentSurface()
        } else if let detail = model.detail {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    detailHeader(detail)
                    statisticsGrid(detail.statistics)
                    learningHighlights(detail.mathMap)
                    conceptList(detail.mathMap)
                    summary(detail.statistics)
                }
                .padding(Tokens.Space.s3)
            }
            .frame(maxWidth: .infinity, maxHeight: splitLayout ? .infinity : nil, alignment: .topLeading)
            .background(Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
        } else {
            VStack(spacing: Tokens.Space.s2) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 32)).foregroundStyle(Tokens.text3)
                Text("학생을 선택하면 학습 현황이 표시됩니다").font(.mBodyB)
                Text("이메일·연락처·결제·커뮤니티 활동은 선생님에게 공개하지 않습니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .teacherStudentSurface()
        }
    }

    private func detailHeader(_ detail: ServerAPI.TeacherStudentDetail) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s3) {
            Text(detail.membership.student.name.first.map(String.init) ?? "학")
                .font(.mHeading).foregroundStyle(Tokens.onBrand)
                .frame(width: 48, height: 48)
                .background(Tokens.actionPrimary,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.membership.student.name).font(.mHeading).foregroundStyle(Tokens.ink)
                Text(studentSubtitle(detail.membership))
                    .font(.mCaption).foregroundStyle(Tokens.text2)
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(detail.statistics.period.options) { option in
                    Button {
                        Task { await model.select(detail.membership.id, period: option.key) }
                    } label: {
                        if option.key == detail.statistics.period.key {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                Label(shortPeriod(detail.statistics.period.key), systemImage: "calendar")
                    .font(.mCaption)
                    .frame(minHeight: 44)
            }
            .disabled(model.isDetailLoading)
        }
    }

    private func statisticsGrid(_ statistics: ServerAPI.TeacherStudentStatistics) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: splitLayout ? 104 : 132), spacing: Tokens.Space.s2)],
            spacing: Tokens.Space.s2
        ) {
            ForEach(statistics.cards) { card in
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.label).font(.mMicro).foregroundStyle(Tokens.text3)
                    Text(card.value).font(.mBodyB.monospacedDigit()).foregroundStyle(Tokens.ink)
                    Text(card.detail).font(.mMicro).foregroundStyle(Tokens.text2).lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                .padding(Tokens.Space.s2)
                .background(Tokens.paper2,
                            in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func learningHighlights(_ map: ServerAPI.TeacherStudentMathMap) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Text("학습 지도 요약").font(.mBodyB)
                Spacer(minLength: 0)
                Text(map.overallMastery.map { "평균 \(Int($0.rounded()))%" } ?? "분석 전")
                    .font(.mCaption).foregroundStyle(Tokens.primary)
            }
            HStack(spacing: Tokens.Space.s2) {
                highlight("강점", map.topStrength, color: Tokens.successInk)
                highlight("우선 보완", map.topPriority, color: Tokens.dangerInk)
            }
            if let bottleneck = map.bottlenecks.first {
                Label(
                    "잠재 병목: \(bottleneck.conceptTitle) · 후속 \(bottleneck.affectedConceptCount)개",
                    systemImage: "point.3.filled.connected.trianglepath.dotted")
                    .font(.mCaption).foregroundStyle(Tokens.warningInk)
            }
        }
    }

    private func highlight(
        _ label: String, _ concept: ServerAPI.TeacherStudentMathMap.Concept?, color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.mMicro).foregroundStyle(Tokens.text3)
            Text(concept?.title ?? "데이터 없음")
                .font(.mCaption).foregroundStyle(Tokens.ink).lineLimit(2)
            Text(concept?.mastery.map { "숙달도 \(Int($0.rounded()))%" } ?? "풀이 5개 이상 필요")
                .font(.mMicro).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(Tokens.Space.s2)
        .background(Tokens.surface,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        }
    }

    private func conceptList(_ map: ServerAPI.TeacherStudentMathMap) -> some View {
        let concepts = map.concepts
            .filter { $0.status != "UNKNOWN" }
            .sorted { ($0.mastery ?? 101) < ($1.mastery ?? 101) }
        return VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            HStack {
                Text("개념별 근거").font(.mBodyB)
                Spacer(minLength: 0)
                Text("분석 \(map.analyzedConceptCount) · 부족 \(map.unknownConceptCount)")
                    .font(.mMicro).foregroundStyle(Tokens.text3)
            }
            if concepts.isEmpty {
                Text("개념별 풀이가 5개 이상 쌓이면 보완 우선순위가 표시됩니다.")
                    .font(.mCaption).foregroundStyle(Tokens.text3)
            } else {
                ForEach(concepts.prefix(12)) { concept in
                    HStack(spacing: Tokens.Space.s2) {
                        Circle().fill(statusColor(concept.status)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(concept.title).font(.mCaption).foregroundStyle(Tokens.ink).lineLimit(1)
                            Text("\(concept.courseTitle) · \(concept.evidence.correctCount)/\(concept.evidence.attemptCount) 정답 · \(concept.confidenceLabel)")
                                .font(.mMicro).foregroundStyle(Tokens.text3).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text(concept.mastery.map { "\(Int($0.rounded()))%" } ?? "—")
                            .font(.mCaption.monospacedDigit()).foregroundStyle(statusColor(concept.status))
                    }
                    .padding(.vertical, Tokens.Space.s1)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func summary(_ statistics: ServerAPI.TeacherStudentStatistics) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Text("학부모 공유용 요약").font(.mBodyB)
            ForEach(statistics.summary.bullets) { bullet in
                VStack(alignment: .leading, spacing: 1) {
                    Text(bullet.label).font(.mCaption).foregroundStyle(Tokens.ink)
                    Text(bullet.text).font(.mMicro).foregroundStyle(Tokens.text2)
                }
            }
        }
        .padding(Tokens.Space.s3)
        .background(Tokens.primarySoft,
                    in: RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous))
    }

    @ViewBuilder
    private var feedback: some View {
        if let notice = model.noticeMessage {
            Label(notice, systemImage: "checkmark.circle.fill")
                .font(.mMicro).foregroundStyle(Tokens.successInk)
        }
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.mMicro).foregroundStyle(Tokens.dangerInk)
        }
    }

    private func studentSubtitle(_ membership: ServerAPI.TeacherAcademyMembership) -> String {
        let grade = switch membership.student.schoolGrade {
        case 10: "고1"
        case 11: "고2"
        case 12: "고3"
        case 13: "N수생"
        case 14: "대학생"
        case 15: "직장인"
        default: "학년 미설정"
        }
        return [
            membership.student.school?.name ?? "학교 미설정",
            grade,
            membership.academyClass?.name ?? "미배정",
        ].joined(separator: " · ")
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "MASTERED": Tokens.successInk
        case "DEVELOPING": Tokens.primary
        case "WEAK": Tokens.dangerInk
        default: Tokens.text3
        }
    }

    private func shortPeriod(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else { return "기간" }
        return "\(month)월"
    }
}

private struct TeacherStudentSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Tokens.Space.s3)
            .background(Tokens.paper,
                        in: RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .strokeBorder(Tokens.line, lineWidth: 1)
            }
    }
}

private extension View {
    func teacherStudentSurface() -> some View { modifier(TeacherStudentSurface()) }
}
