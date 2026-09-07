import Foundation

@main enum WorkspaceEntryCases {
    static func main() {
        precondition(AppWorkspace.initial(role: "teacher", savedValue: nil) == .teacher)
        precondition(AppWorkspace.initial(role: "admin", savedValue: nil) == .administrator)
        precondition(AppWorkspace.initial(role: "student", savedValue: nil) == .student)
        precondition(AppWorkspace.initial(role: "TEACHER", savedValue: "student") == .student)
        precondition(AppWorkspace.initial(role: "admin", savedValue: "student") == .student)
        precondition(AppWorkspace.initial(role: "student", savedValue: "administrator") == .student)
        precondition(AppWorkspace.initial(role: "teacher", savedValue: "administrator") == .teacher)
        precondition(AppWorkspace.initial(role: "unknown", savedValue: "teacher") == .student)
        precondition(AppWorkspace.initial(role: "admin", savedValue: "broken") == .administrator)
        print("Workspace entry: role defaults, explicit personal-study preference and revoked-role boundary passed")
    }
}
