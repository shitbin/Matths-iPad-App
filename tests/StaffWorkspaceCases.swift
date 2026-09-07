import Foundation

@main struct StaffWorkspaceCases {
    static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message); count += 1
        }
        check(TeacherWorkspaceArea.allCases.count == 5, "teacher has exactly five first-level jobs")
        check(AdminWorkspaceArea.allCases.count == 5, "admin has exactly five first-level jobs")
        check(Set(TeacherWorkspaceArea.allCases.map(\.title)).count == 5, "teacher labels unique")
        check(Set(AdminWorkspaceTool.allCases.map(\.id)).count == 16, "all previous tools plus approval inbox reachable")
        var navigation = AdminWorkspaceNavigationState()
        check(navigation.area == .operations && navigation.tool == .approvals, "approval inbox default")
        for tool in AdminWorkspaceTool.allCases {
            navigation.open(tool)
            check(navigation.area == tool.area && navigation.tool == tool, "tool routes to owning job: \(tool)")
            check(navigation.visitedTools.contains(tool), "visited tool retains view identity")
            navigation.showDirectory()
            check(navigation.tool == nil && navigation.area == tool.area, "back returns to same job directory")
            navigation.select(.operations)
            navigation.select(tool.area)
            // Selecting operations remembers the tool only for operations; all
            // other areas must retain their last opened tool.
            if tool.area != .operations { check(navigation.tool == tool, "area restores last tool") }
        }
        navigation.reset()
        check(navigation == AdminWorkspaceNavigationState(), "account switch clears routes and visited state")
        check(AdminWorkspaceTool.finance.matches("환불 페이백"), "multiword Korean search")
        check(AdminWorkspaceTool.arena.matches("goat arena"), "case insensitive search")
        check(!AdminWorkspaceTool.users.matches("환불"), "search cannot invent a result")
        check(AdminWorkspaceTool.allCases.filter { $0.matches("존재하지않는업무") }.isEmpty, "actual empty result")
        for width in [320.0, 375, 430, 600, 699] {
            check(!StaffWorkspaceMetrics.usesListDetail(width: width), "narrow workflow at \(width)")
        }
        for width in [700.0, 744, 834, 1_024, 1_194, 1_366] {
            check(StaffWorkspaceMetrics.usesListDetail(width: width), "wide list detail at \(width)")
            check(StaffWorkspaceMetrics.listWidth(width: width) <= width * 0.5, "detail retains majority width")
        }
        check(!StaffWorkspaceMetrics.usesSidebar(width: 1_039), "no squeezed triple column")
        check(StaffWorkspaceMetrics.usesSidebar(width: 1_040), "sidebar threshold")

        let baseline = ["unchanged": "present", "local": "absent", "both": "absent", "removed": "present"]
        let edited = ["unchanged": "present", "local": "late", "both": "excused", "removed": "late"]
        let server = ["unchanged": "late", "local": "absent", "both": "present", "new": "present"]
        let merge = StaffDraftMerge(server: server, baseline: baseline, edited: edited)
        check(merge.values["unchanged"] == "late", "untouched row adopts fresh server")
        check(merge.values["local"] == "late", "unsaved local edit survives refresh")
        check(merge.values["both"] == "excused", "conflicting local draft survives for review")
        check(merge.conflicts == ["both"], "only both-side conflicts block saving")
        check(merge.values["removed"] == nil, "removed student is not resurrected")
        check(merge.values["new"] == "present", "new roster student included")
        let identical = StaffDraftMerge(server: ["a": "late"], baseline: ["a": "absent"], edited: ["a": "late"])
        check(identical.conflicts.isEmpty, "same server/local change is not a conflict")
        let reset = StaffDraftMerge(server: server, baseline: [String:String](), edited: [String:String]())
        check(reset.values == server && reset.conflicts.isEmpty, "new account has no old drafts")
        print("staff workspace \(count) executable assertions passed")
    }
}
