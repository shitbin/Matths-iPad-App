#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/NotificationInboxScreen.swift"

# 행은 펼치는 순간에만 읽음 처리한다. 바로가기는 네이티브 목적지로 한 번만 publish한다.
grep -Fq 'static let matthsRouteRequest' "$screen"
grep -Fq 'DispatchQueue.main.async' "$screen"
grep -Fq 'NotificationCenter.default.post(name: .matthsRouteRequest, object: route)' "$screen"
grep -Fq 'publisher(for: .matthsRouteRequest)' "$root/Matths/RootView.swift"
grep -Fq 'store.route = route' "$root/Matths/RootView.swift"
if grep -Fq 'store.route == .notifications, route == .community' "$root/Matths/RootView.swift"; then
    echo 'native community route must not detour through home' >&2
    exit 1
fi
grep -Fq '$0.isUrgent && (!$0.isRead || expandedID == $0.id)' "$screen"
grep -Fq 'if compactHeight {' "$screen"
grep -Fq 'compactHeight && !dynamicTypeSize.isAccessibilitySize' "$screen"
grep -Fq '.dynamicTypeSize(...DynamicTypeSize.xxxLarge)' "$screen"
grep -Fq '.fixedSize(horizontal: false, vertical: true)' "$screen"
grep -Fq 'expandedMessage' "$screen"
grep -Fq 'openButton' "$screen"
open_target=$(awk '/private func openTarget/{capture=1} capture{print} capture && /^    }/{exit}' "$screen")
if printf '%s\n' "$open_target" | grep -q 'inbox\.markRead'; then
    echo 'openTarget must not publish a second markRead update' >&2
    exit 1
fi

# 지원하는 서버 href가 앱 안의 안전한 목적지로 계속 닫혀 있어야 한다.
grep -Fq 'if path.hasPrefix("/community")   { return .community }' "$screen"
grep -Fq 'if ArenaWebDestination.owns(path: path) { return .rank }' "$screen"
grep -Fq 'return .home' "$screen"
grep -Fq 'NotificationInboxScreen.arenaDestination(for: item.href)' "$screen"
grep -Fq 'guardModel: destination.isProtectedAssessmentSurface ? screenshotGuard : nil' "$screen"
grep -Fq 'NotificationInboxScreen.conceptID(for: item.href)' "$screen"
grep -Fq 'store.openConceptV2(conceptID)' "$screen"
grep -Fq 'course.id == courseID, unit.id == unitID' "$screen"
grep -Fq 'ServerAPI.isWebPurchasePath(path)' "$screen"
grep -Fq 'if path.hasPrefix("/learn/") || path == "/curriculum"' "$screen"
grep -Fq 'path.hasPrefix("/quick-practice") { return .quickPractice }' "$screen"
grep -Fq 'path.hasPrefix("/private-mock-exams")' "$screen"
grep -Fq 'path.hasPrefix("/notifications") { return .notifications }' "$screen"
grep -Fq 'HostedPortalDestination.fromInternalHref(item.href)' "$screen"
grep -Fq 'store.openHostedPortal(destination)' "$screen"
grep -Fq 'HostedPortalDestination.fromInternalHref(href) != nil { return .services }' "$screen"
grep -Fq 'if inbox.hasMore {' "$screen"
grep -Fq 'inbox.loadMore()' "$screen"
grep -Fq 'Text(inbox.isLoadingMore ? "이전 알림 불러오는 중" : "이전 알림 더 보기")' "$screen"
grep -Fq 'noticeBanner(notice, canRetry: inbox.availability.isFailure)' "$screen"
grep -Fq 'Button("다시 시도") { inbox.refresh(force: true) }' "$screen"
grep -Fq '.accessibilityElement(children: .contain)' "$screen"

store="$root/Matths/NotificationInbox.swift"
grep -Fq '@Published private(set) var pagination = MatthsNotificationInbox.Pagination()' "$store"
grep -Fq 'var hasMore: Bool { pagination.hasNext }' "$store"
grep -Fq 'var totalCount: Int { max(stats.total, notifications.count) }' "$store"
grep -Fq '전체 \(inbox.totalCount)건' "$screen"
grep -Fq 'let nextPage = pagination.page + 1' "$store"
grep -Fq 'let inbox = try await ServerAPI.notificationInbox(' "$store"
grep -Fq 'page: page,' "$store"
grep -Fq 'known.insert($0.id).inserted' "$store"
grep -Fq 'stats.unread = max(0, stats.unread - 1)' "$store"
grep -Fq 'stats.urgentUnread = max(0, stats.urgentUnread - 1)' "$store"
grep -Fq 'stats.unread = 0' "$store"
grep -Fq 'guard changed || hadServerUnread else { return }' "$store"
grep -Fq 'loadTask?.cancel()' "$store"
grep -Fq 'let authorization = ServerAPI.captureAuthorization()' "$store"
grep -Fq 'authorization: ServerAPI.AuthorizationSnapshot' "$store"
grep -Fq 'authorization: authorization' "$store"
grep -Fq 'private var optimisticReadAllAt: Date?' "$store"
grep -Fq 'if let readAt = optimisticReadAllAt' "$store"
grep -Fq 'optimisticReadAllAt = now' "$store"
grep -Fq 'optimisticReadAllAt = nil' "$store"
grep -Fq 'private var loadGeneration = UUID()' "$store"
grep -Fq 'private var loadMoreGeneration = UUID()' "$store"
grep -Fq 'loadGeneration == generation' "$store"
grep -Fq 'loadMoreGeneration == generation' "$store"

demo="$root/Matths/DemoMode.swift"
fixtures="$root/Matths/DemoFixtures/DemoFixturesAccount.swift"
grep -Fq 'query["page"] == "2"' "$demo"
grep -Fq 'DemoAccountFixtures.notificationInboxPage2' "$demo"
grep -Fq 'static let notificationInboxPage2' "$fixtures"
grep -Fq '"stats": { "total": 26, "unread": 4, "urgentUnread": 1, "read": 22 }' "$fixtures"
grep -Fq '"id": "demo-noti-20"' "$fixtures"
grep -Fq '"id": "demo-noti-26"' "$fixtures"
grep -Fq '"page": 1, "totalPages": 2' "$fixtures"
grep -Fq '"page": 2, "totalPages": 2' "$fixtures"

echo 'Notification in-app route handoff contract passed'
