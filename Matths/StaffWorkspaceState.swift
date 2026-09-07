import Foundation

/// Workspace destinations are stable even when their presentation moves from a
/// bottom bar to a sidebar. No privileged action is authorized by this router.
enum TeacherWorkspaceArea: String, CaseIterable, Identifiable {
    case overview, classes, students, attendance, more
    var id: String { rawValue }
    var title: String {
        switch self { case .overview: "개요"; case .classes: "반"; case .students: "학생"; case .attendance: "출결"; case .more: "더보기" }
    }
    var symbol: String {
        switch self { case .overview: "rectangle.3.group"; case .classes: "person.3"; case .students: "person.crop.rectangle"; case .attendance: "checklist"; case .more: "ellipsis.circle" }
    }
}

enum AdminWorkspaceArea: String, CaseIterable, Identifiable {
    case operations, academies, users, content, financeSystem
    var id: String { rawValue }
    var title: String {
        switch self { case .operations: "운영"; case .academies: "학원"; case .users: "사용자"; case .content: "콘텐츠"; case .financeSystem: "재무·시스템" }
    }
    var symbol: String {
        switch self { case .operations: "tray.full"; case .academies: "building.2"; case .users: "person.2"; case .content: "square.stack"; case .financeSystem: "wonsign.circle" }
    }
    var defaultTool: AdminWorkspaceTool? {
        switch self { case .operations: .approvals; case .academies: .academies; case .users: .users; case .content, .financeSystem: nil }
    }
}

enum AdminWorkspaceTool: String, CaseIterable, Identifiable {
    case approvals, operations, academies, users, community, weeklyMock, archive, store
    case arena, finance, dataAnalysis, pdfForensics, arenaPolicies, problemBanks, coachSuggestions, operationsGuide
    var id: String { rawValue }
    var area: AdminWorkspaceArea {
        switch self {
        case .approvals, .operations: .operations
        case .academies: .academies
        case .users: .users
        case .community, .weeklyMock, .archive, .store, .problemBanks, .coachSuggestions: .content
        case .arena, .finance, .dataAnalysis, .pdfForensics, .arenaPolicies, .operationsGuide: .financeSystem
        }
    }
    var title: String {
        switch self {
        case .approvals: "학원 등록 승인"
        case .operations: "문의·운영 할 일"
        case .academies: "전체 학원"
        case .users: "사용자·제재 관리"
        case .community: "게시판 신고·제재"
        case .weeklyMock: "주간 모의고사 운영"
        case .archive: "자료실·배포 파일"
        case .store: "수험관·상점 운영"
        case .arena: "GOAT Arena 운영"
        case .finance: "재무·환불·페이백"
        case .dataAnalysis: "월별 운영 지표"
        case .pdfForensics: "PDF·스크린샷 유출 추적"
        case .arenaPolicies: "Arena 정책·가격"
        case .problemBanks: "문제 유형·Arena 데이터"
        case .coachSuggestions: "코치 문구 검수"
        case .operationsGuide: "운영 매뉴얼·DB 스키마"
        }
    }
    var detail: String {
        switch self {
        case .approvals: "신청자·계약을 확인하고 승인 또는 반려"
        case .operations: "답변 대기 문의·공지·오늘의 할 일"
        case .academies: "구성원·반·수업·출결·계약"
        case .users: "계정·보호자·경고·감사 이력"
        case .community: "신고 검토와 게시글·댓글 조치"
        case .weeklyMock: "회차·채점·이의신청·공정성"
        case .archive: "권한·업로드·휴지통·복구"
        case .store: "콘텐츠·상품·카테고리"
        case .arena: "실시간 경기·무결성·랭킹"
        case .finance: "출금 장부와 지급 처리"
        case .dataAnalysis: "결제·학습권·Arena 지표"
        case .pdfForensics: "서명 검증과 OCR 분석"
        case .arenaPolicies: "가격·상점·매치메이킹 정책"
        case .problemBanks: "유형 리비전과 T1–T9 데이터"
        case .coachSuggestions: "학생 제안 승인·반려"
        case .operationsGuide: "권한·자동화·보존·장애 대응"
        }
    }
    var symbol: String {
        switch self {
        case .approvals: "checkmark.shield"
        case .operations: "tray.full"
        case .academies: "building.2"
        case .users: "person.2"
        case .community: "exclamationmark.bubble"
        case .weeklyMock: "doc.text"
        case .archive: "folder"
        case .store: "storefront"
        case .arena: "crown"
        case .finance: "wonsign.circle"
        case .dataAnalysis: "chart.bar.xaxis"
        case .pdfForensics: "viewfinder"
        case .arenaPolicies: "slider.horizontal.3"
        case .problemBanks: "square.stack.3d.up"
        case .coachSuggestions: "text.bubble"
        case .operationsGuide: "book.closed"
        }
    }
    func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return words.allSatisfy { "\(title) \(detail) \(area.title)".localizedCaseInsensitiveContains($0) }
    }
}

struct AdminWorkspaceNavigationState: Equatable {
    private(set) var area: AdminWorkspaceArea = .operations
    private(set) var tool: AdminWorkspaceTool? = .approvals
    private(set) var visitedTools: Set<AdminWorkspaceTool> = [.approvals]
    private var lastTools: [AdminWorkspaceArea: AdminWorkspaceTool] = [.operations: .approvals]

    mutating func select(_ next: AdminWorkspaceArea) {
        area = next
        tool = lastTools[next] ?? next.defaultTool
        if let tool { visitedTools.insert(tool) }
    }

    mutating func open(_ next: AdminWorkspaceTool) {
        area = next.area
        tool = next
        lastTools[area] = next
        visitedTools.insert(next)
    }

    mutating func showDirectory() { tool = nil }
    mutating func reset() { self = Self() }
}

enum StaffWorkspaceMetrics {
    static func usesSidebar(width: Double) -> Bool { width >= 1_040 }
    static func usesListDetail(width: Double) -> Bool { width >= 700 }
    static func listWidth(width: Double) -> Double { min(340, max(240, width * 0.32)) }
}

/// Unsaved rows are retained by server scope (date + class + session), never
/// shared between accounts. Unchanged rows take fresh server values; changed
/// rows retain local input and surface conflicts for an explicit decision.
struct StaffDraftMerge<Key: Hashable, Value: Equatable> {
    let values: [Key: Value]
    let conflicts: Set<Key>
    init(server: [Key: Value], baseline: [Key: Value], edited: [Key: Value]) {
        var result = server
        var collisions = Set<Key>()
        for (key, local) in edited where baseline[key] != local {
            guard let fresh = server[key] else { continue }
            result[key] = local
            if baseline[key] != fresh && fresh != local { collisions.insert(key) }
        }
        values = result
        conflicts = collisions
    }
}
