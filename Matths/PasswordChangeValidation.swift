import Foundation

enum PasswordChangeValidation {
    static func isValid(_ password: String, confirmation: String) -> Bool {
        // Web passwordResetService uses JS String.length and ASCII letter/digit checks.
        password.utf16.count >= 8 && password.utf8.count <= 72
            && password.range(of: "[A-Za-z]", options: .regularExpression) != nil
            && password.range(of: "[0-9]", options: .regularExpression) != nil
            && password.utf8.elementsEqual(confirmation.utf8)
    }
}
