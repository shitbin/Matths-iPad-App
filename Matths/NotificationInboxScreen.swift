//  NotificationInboxScreen.swift
//  Matths
//
//  알림함 화면 — 게시판 답글, 전체 공지, 관리자 개별 안내, 경고를 한 목록에 모은다.
//
//  구조 규칙 두 가지.
//  ① **경고를 목록 안에 묻지 않는다.** 안 읽은 긴급 알림(경고·계정·닉네임·무결성)은
//     맨 위에 따로 세운다. 공지 스무 개 사이에 낀 경고는 못 보고 지나간다.
//  ② 상세는 새 화면이 아니라 **그 자리 펼침**이다. 오답노트 카드와 같은 몸짓이라
//     학생이 새로 배울 것이 없고, 뒤로 가기를 눌러 목록 위치를 잃지도 않는다.

import SwiftUI

extension Notification.Name {
    static let matthsRouteRequest = Notification.Name("kr.matths.app.route-request")
}

struct NotificationInboxScreen: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var screenshotGuard: ScreenshotGuard
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var inbox = NotificationInboxStore.shared
    @State private var expandedID: String?

    private var compactHeight: Bool { verticalSizeClass == .compact }
    /// 빈 상태의 설명은 아래 카드 한 곳에서만 한다. 헤더까지 같은 말을 반복하면
    /// 실제 알림이 있을 때의 건수·긴급 요약과 빈 상태 안내의 역할이 섞인다.
    private var showsHeaderSummary: Bool { !inbox.notifications.isEmpty }

    private var urgentUnread: [MatthsNotification] {
        // 펼치는 순간 읽음이 되더라도 열린 카드를 바로 다른 섹션으로 순간이동시키지
        // 않는다. 닫거나 화면을 벗어난 뒤에만 일반 날짜 묶음으로 내려간다.
        inbox.notifications.filter {
            $0.isUrgent && (!$0.isRead || expandedID == $0.id)
        }
    }

    /// 긴급 칸에 올라간 것은 아래 목록에서 뺀다 — 같은 글이 한 화면에 두 번 서면
    /// 학생은 알림이 두 개라고 읽는다.
    private var rest: [MatthsNotification] {
        let lifted = Set(urgentUnread.map(\.id))
        return inbox.notifications.filter { !lifted.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s6) {
            header

            if let notice = availabilityNotice {
                noticeBanner(notice, canRetry: inbox.availability.isFailure)
            }

            if inbox.notifications.isEmpty {
                emptyState
            } else {
                if !urgentUnread.isEmpty {
                    VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s1 : Tokens.Space.s2) {
                        SectionRule(title: "먼저 확인해 주세요")
                        ForEach(urgentUnread) { row($0) }
                    }
                }
                ForEach(groups(rest), id: \.title) { group in
                    VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s1 : Tokens.Space.s2) {
                        SectionRule(title: group.title)
                        ForEach(group.items) { row($0) }
                    }
                }
                if inbox.hasMore {
                    loadMoreButton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { inbox.refresh() }
    }

    // MARK: 머리

    private var loadMoreButton: some View {
        Button {
            inbox.loadMore()
        } label: {
            HStack(spacing: Tokens.Space.s2) {
                if inbox.isLoadingMore {
                    ProgressView().controlSize(.small)
                }
                Text(inbox.isLoadingMore ? "이전 알림 불러오는 중" : "이전 알림 더 보기")
                Image(systemName: "chevron.down")
                    .accessibilityHidden(true)
            }
            .font(.mBodyB)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Tokens.primary)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md)
                .strokeBorder(Tokens.line, lineWidth: 1))
        .disabled(inbox.isLoadingMore)
        .accessibilityHint("서버에 남아 있는 더 오래된 알림을 이어서 불러옵니다")
    }

    private var header: some View {
        SwiftUI.Group {
            if compactHeight && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.s3) {
                    Text("알림함").font(.mTitle).foregroundStyle(Tokens.ink)
                    if showsHeaderSummary {
                        Text(summaryLine)
                            .font(.mCaption).foregroundStyle(Tokens.text2)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: Tokens.Space.s2)
                    markAllReadButton
                }
            } else if compactHeight {
                // 접근성 글자 크기에서 제목·요약·행동을 한 줄에 욱여넣으면 요약이
                // "이 중 확인…"으로 잘려, 긴급 알림이 있다는 핵심 정보가 사라진다.
                // 행동은 제목 옆에 남겨 첫 화면에서 닿게 하고 요약만 온전한 둘째 줄로 둔다.
                VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                    HStack(alignment: .center, spacing: Tokens.Space.s2) {
                        Text("알림함")
                            .font(.mTitle)
                            .foregroundStyle(Tokens.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Spacer(minLength: Tokens.Space.s2)
                        markAllReadButton
                            // 버튼 하나가 목록 높이를 과도하게 잠식하지 않게 하되,
                            // 보이스오버 라벨과 44pt 터치 영역은 그대로 유지한다.
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    }
                    if showsHeaderSummary {
                        Text(summaryLine)
                            .font(.mCaption)
                            .foregroundStyle(Tokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.s3) {
                    Text("알림함").font(.mTitle).foregroundStyle(Tokens.ink)
                    ExamRule()
                    if showsHeaderSummary {
                        HStack(spacing: Tokens.Space.s3) {
                            Text(summaryLine)
                                .font(.mCaption).foregroundStyle(Tokens.text2)
                            Spacer(minLength: Tokens.Space.s2)
                            markAllReadButton
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var markAllReadButton: some View {
        if inbox.unreadCount > 0 {
            Button { inbox.markAllRead() } label: {
                Label("모두 읽음", systemImage: "checkmark.circle")
                    .font(.mCaption).foregroundStyle(Tokens.primary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("안 읽은 알림 \(inbox.unreadCount)건을 모두 읽음으로 표시합니다")
        }
    }

    private var summaryLine: String {
        if inbox.notifications.isEmpty { return "받은 알림이 없습니다" }
        if inbox.unreadCount == 0 { return "전체 \(inbox.totalCount)건 · 모두 읽음" }
        if inbox.urgentUnreadCount > 0 {
            return "안 읽음 \(inbox.unreadCount)건 · 이 중 확인 필요 \(inbox.urgentUnreadCount)건"
        }
        return "안 읽음 \(inbox.unreadCount)건 · 전체 \(inbox.totalCount)건"
    }

    // MARK: 상태 안내
    //
    // 운영 서버에는 알림 JSON 경로가 있지만, 롤백·순차 배포 중 구버전 서버를 만날
    // 수 있다. 그 404/501을 학생 탓인 오류로 그리지 않고 저장된 목록을 유지한다.

    private var availabilityNotice: (icon: String, text: String, tint: Color)? {
        switch inbox.availability {
        case .ready, .unknown:
            return nil
        case .serverRouteMissing:
            return ("clock.badge.checkmark",
                    inbox.notifications.isEmpty
                        ? "서버 알림 연결을 준비하고 있습니다. 연결되면 여기에 쌓입니다."
                        : "서버 알림 연결 준비 중 — 마지막으로 받은 목록을 보여 주고 있습니다.",
                    Tokens.text3)
        case .failed(let message):
            return ("exclamationmark.triangle", message, Tokens.warningInk)
        }
    }

    private func noticeBanner(
        _ notice: (icon: String, text: String, tint: Color),
        canRetry: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.s2) {
            Image(systemName: notice.icon).font(.mCaption).foregroundStyle(notice.tint)
            Text(notice.text)
                .font(.mCaption).foregroundStyle(Tokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if canRetry {
                Button("다시 시도") { inbox.refresh(force: true) }
                    .font(.mCaption)
                    .foregroundStyle(Tokens.primary)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                    .disabled(inbox.isLoading)
                    .accessibilityHint("알림 목록을 서버에서 다시 불러옵니다")
            }
        }
        .padding(Tokens.Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.paper2, in: RoundedRectangle(cornerRadius: Tokens.Radius.md))
        // 실패 상태에는 실제 버튼이 있으므로 하나의 정적 문장으로 합치지 않는다.
        // VoiceOver가 배너 설명 뒤의 재시도 행동까지 별도 컨트롤로 찾아야 한다.
        .accessibilityElement(children: .contain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s2) {
            Image(systemName: "bell.slash")
                .font(.mHeading)
                .foregroundStyle(Tokens.text4)
                // 빈 목록 장식이지 알림 설정이 꺼졌다는 상태값이 아니다.
                .accessibilityHidden(true)
            Text("아직 받은 알림이 없습니다").font(.mBodyB).foregroundStyle(Tokens.text2)
            Text("게시판 답글, 전체 공지, 관리자 안내, 경고가 여기로 옵니다.")
                .font(.mCaption).foregroundStyle(Tokens.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: 목록

    private struct Group {
        let title: String
        let items: [MatthsNotification]
    }

    /// 날짜로 묶는다. "오늘/어제" 는 KST 기준 — 학생이 보는 달력과 같아야 한다.
    private func groups(_ list: [MatthsNotification]) -> [Group] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "M월 d일"

        var order: [String] = []
        var buckets: [String: [MatthsNotification]] = [:]
        for item in list.sorted(by: { $0.createdAt > $1.createdAt }) {
            let title: String
            if calendar.isDateInToday(item.createdAt) { title = "오늘" }
            else if calendar.isDateInYesterday(item.createdAt) { title = "어제" }
            else { title = formatter.string(from: item.createdAt) }
            if buckets[title] == nil { order.append(title) }
            buckets[title, default: []].append(item)
        }
        return order.map { Group(title: $0, items: buckets[$0] ?? []) }
    }

    private func row(_ item: MatthsNotification) -> some View {
        NotificationRow(
            item: item,
            isOpen: expandedID == item.id,
            toggle: {
                // 펼치는 순간이 곧 읽은 순간이다. 목록에서 스치듯 지나간 것을
                // 읽음으로 치면 경고를 안 본 학생이 읽은 것으로 기록된다.
                if expandedID == item.id {
                    expandedID = nil
                } else {
                    expandedID = item.id
                    inbox.markRead(item.id)
                }
            },
            open: { openTarget(item) })
    }

    // MARK: 이동
    //
    // 서버가 준 href 는 **웹 경로**다. 앱에 같은 목적지가 있으면 그 화면으로 보내고,
    // 없으면 홈으로 보낸다. 웹 주소를 그대로 외부 브라우저에 던지지 않는다 —
    // 로그인 세션이 끊긴 창이 열려 학생이 다시 로그인하게 된다.
    private func openTarget(_ item: MatthsNotification) {
        // 이 버튼은 펼친 행 안에만 있으므로, toggle에서 이미 읽음 처리가 끝났다.
        // 여기서 markRead를 한 번 더 호출하면 긴급 행이 섹션 사이를 재배치하는
        // ObservableObject 갱신과 route 교체가 같은 탭에 겹쳐 VoiceOver 포커스와
        // 전환 애니메이션이 흔들린다.
        // 경기 알림은 GOAT Arena 홈으로 뭉개지 않고 서버가 가리킨 우편함·경기·상점
        // 페이지를 그대로 연다. 경기 문항면이면 네이티브 경기와 같은 보호도 넘긴다.
        if let destination = NotificationInboxScreen.arenaDestination(for: item.href) {
            DispatchQueue.main.async {
                ArenaWebPresenter.open(
                    destination,
                    guardModel: destination.isProtectedAssessmentSurface ? screenshotGuard : nil,
                    onCapture: { store.recordStuckPoint($0) })
            }
            return
        }

        // 학습 알림은 커리큘럼 홈이 아니라 서버가 지정한 실제 개념으로 이동한다.
        if let conceptID = NotificationInboxScreen.conceptID(for: item.href) {
            DispatchQueue.main.async { store.openConceptV2(conceptID) }
            return
        }

        // 학원·관리자·자료실 알림은 허브 첫 화면이 아니라 서버가 지정한 실제 행/상세로
        // 이어 연다. 결제 경로는 fromInternalHref에서 거부되어 아래 네이티브 commerce로 간다.
        if let destination = HostedPortalDestination.fromInternalHref(item.href) {
            DispatchQueue.main.async { store.openHostedPortal(destination) }
            return
        }

        let route = NotificationInboxScreen.route(for: item.href)
        // 제거될 ScrollView의 자식 버튼이 자기 부모를 직접 교체하지 않는다.
        // 다음 메인 런루프에서, 계속 살아 있는 RootView가 탭바와 같은 레벨에서
        // 목적지를 적용한다. 큰 글씨의 자동 스크롤/포커스 보정 중에도 안전하다.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .matthsRouteRequest, object: route)
        }
    }

    static func route(for href: String) -> AppStore.Route {
        nativeRoute(for: href) ?? .home
    }

    /// 서버 페이지 중 네이티브 화면이 정본인 경로. nil은 앱이 소유하지 않는 주소다.
    /// `route(for:)`의 홈 fallback과 분리해야 유니버설 링크가 모르는 URL까지 홈으로
    /// 가로채지 않는다.
    static func nativeRoute(for href: String) -> AppStore.Route? {
        let path = normalizedPath(href)
        if path.hasPrefix("/community")   { return .community }
        if ArenaWebDestination.owns(path: path) { return .rank }
        if ServerAPI.isWebPurchasePath(path)
            || path.hasPrefix("/commerce") { return .commerce }
        if path == "/" || path == "/main" || path == "/intro" { return .home }
        if path.hasPrefix("/learn/") || path == "/curriculum"
            || path == "/visual-learning" || path == "/learning-flow" { return .curriculum }
        if path.hasPrefix("/log-curriculum")
            || path.hasPrefix("/my-learning") { return .curriculum }
        if path.hasPrefix("/quick-practice") { return .quickPractice }
        if path.hasPrefix("/wrong-notes") { return .wrongNotes }
        if path.hasPrefix("/assessments") { return .assess }
        if path.hasPrefix("/weekly-mock")
            || path.hasPrefix("/private-mock-exams")
            || path.hasPrefix("/integrity/cases")
            || path.hasPrefix("/account/private-mock-restriction") { return .weeklyMock }
        if path.hasPrefix("/war-of-masters/placement") { return .placement }
        if path.hasPrefix("/war-of-masters") { return .rank }
        if path.hasPrefix("/notifications") { return .notifications }
        if HostedPortalDestination.fromInternalHref(href) != nil { return .services }
        if path.hasPrefix("/profile")
            || path.hasPrefix("/account")
            || path.hasPrefix("/nickname-change") { return .profile }
        return nil
    }

    /// 서버가 보장하는 `/` 시작 내부 href만 URL로 승격한다. 절대 주소나 scheme-relative
    /// 주소는 알림 서비스의 방어가 흔들려도 앱 브리지로 들어오지 못한다.
    static func arenaDestination(for href: String) -> ArenaWebDestination? {
        guard href.hasPrefix("/"), !href.hasPrefix("//"),
              let url = URL(string: href, relativeTo: ServerAPI.baseURL)?.absoluteURL else {
            return nil
        }
        return ArenaWebDeepLink.destination(for: url)
    }

    /// `/learn/<course>/<unit>/<concept>`를 현재 번들 정본과 대조한다. concept ID만 맞고
    /// 과목·단원이 다른 조합도 받지 않아 오래된 알림이 엉뚱한 개념을 열지 않게 한다.
    static func conceptID(for href: String) -> String? {
        let components = normalizedPath(href)
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0).removingPercentEncoding ?? String($0) }
        guard components.count >= 4, components[0] == "learn" else { return nil }
        let courseID = components[1]
        let unitID = components[2]
        let conceptID = components[3]
        guard let (course, unit, _) = CurriculumV2.concept(conceptID),
              course.id == courseID, unit.id == unitID else { return nil }
        return conceptID
    }

    private static func normalizedPath(_ href: String) -> String {
        let withoutQuery = href.split(separator: "?", maxSplits: 1).first.map(String.init) ?? href
        return withoutQuery.split(separator: "#", maxSplits: 1).first.map(String.init) ?? withoutQuery
    }
}

private extension NotificationInboxStore.Availability {
    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

// MARK: - 알림 한 줄

private struct NotificationRow: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let item: MatthsNotification
    let isOpen: Bool
    let toggle: () -> Void
    let open: () -> Void

    private var compactHeight: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: compactHeight ? Tokens.Space.s2 : Tokens.Space.s3) {
            Button(action: toggle) {
                HStack(alignment: .top, spacing: Tokens.Space.s3) {
                    // 안 읽음 표시는 점 **하나만**. 굵은 제목과 배경색까지 함께 바꾸면
                    // 목록 전체가 강조로 뒤덮여 정작 긴급한 것이 안 보인다.
                    Circle()
                        .fill(item.isRead ? Color.clear : item.kind.tint)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: Tokens.Space.s1) {
                        HStack(spacing: Tokens.Space.s2) {
                            Label(item.kind.label, systemImage: item.kind.icon)
                                .font(.mMicro)
                                .foregroundStyle(item.kind.tint)
                            Text(Self.relative(item.createdAt))
                                .font(.mMicro).foregroundStyle(Tokens.text3)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down")
                                .font(.mMicro).foregroundStyle(Tokens.text4)
                                .rotationEffect(.degrees(isOpen ? 180 : 0))
                        }
                        Text(item.title)
                            .font(item.isRead ? .mBody : .mBodyB)
                            .foregroundStyle(Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        if !isOpen {
                            Text(item.message)
                                .font(.mCaption).foregroundStyle(Tokens.text2)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.kind.label). \(item.title). \(item.isRead ? "읽음" : "안 읽음")")
            .accessibilityHint("펼쳐서 전문을 봅니다")

            if isOpen {
                if compactHeight {
                    HStack(alignment: .top, spacing: Tokens.Space.s3) {
                        expandedMessage
                        openButton
                    }
                } else {
                    expandedMessage
                    openButton
                }
            }
        }
        .padding(compactHeight ? Tokens.Space.s3 : Tokens.Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg)
            .strokeBorder(item.isRead || !item.isUrgent
                          ? Tokens.line
                          : item.kind.tint.opacity(0.55),
                          lineWidth: item.isRead || !item.isUrgent ? 1 : 1.5))
    }

    private var expandedMessage: some View {
        Text(item.message)
            .font(.mCallout).foregroundStyle(Tokens.text1)
            .lineSpacing(compactHeight ? 2 : 4)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var openButton: some View {
        Button(action: open) {
            Label("바로가기", systemImage: "arrow.up.right")
                .font(.mCaption).foregroundStyle(Tokens.primary)
                .padding(.horizontal, Tokens.Space.s3).padding(.vertical, 6)
                .overlay(Capsule().strokeBorder(Tokens.primary, lineWidth: 1.2))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityHint("이 알림이 가리키는 화면으로 이동합니다")
    }

    /// "3분 전 · 어제 · 8월 11일". 목록에서 가장 자주 읽히는 정보라 짧게 쓴다.
    static func relative(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "방금" }
        if seconds < 3600 { return "\(Int(seconds / 60))분 전" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))시간 전" }
        if seconds < 172_800 { return "어제" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
    }
}
