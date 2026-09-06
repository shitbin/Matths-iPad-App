import Foundation
import SwiftSyntax
import SwiftParser

final class CopyVisitor: SyntaxVisitor {
    var violations: [String] = []
    private let names: Set<String> = ["Text", "Label", "Button", "Link", "Toggle", "TextField", "SecureField",
                                      "accessibilityLabel", "accessibilityHint", "navigationTitle", "alert", "confirmationDialog"]
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text
            ?? node.calledExpression.as(MemberAccessExprSyntax.self)?.declName.baseName.text ?? ""
        guard names.contains(name), let first = node.arguments.first,
              let literal = first.expression.as(StringLiteralExprSyntax.self) else { return .visitChildren }
        let text = literal.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
        if text.range(of: "(?<![A-Za-z])Division(?![A-Za-z])", options: [.regularExpression, .caseInsensitive]) != nil {
            violations.append(text)
        }
        return .visitChildren
    }
}

func check(_ source: String) -> [String] {
    let visitor = CopyVisitor(viewMode: .sourceAccurate)
    visitor.walk(Parser.parse(source: source))
    return visitor.violations
}
if CommandLine.arguments.contains("--self-test") {
    precondition(check("let path = \"/api/v1/admin/arena-policies/\\(division)/activate\"").isEmpty)
    precondition(!check("Text(\"Main Division별 순위\")").isEmpty)
    precondition(!check("Label(\"Division\", systemImage: \"circle\")").isEmpty)
    precondition(check("// Text(\"Division\")\nText(\"경쟁 구분\")").isEmpty)
    print("User-facing copy AST mutation cases PASS")
} else {
    let root = URL(fileURLWithPath: CommandLine.arguments[1])
    var failed = false
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
    for case let url as URL in files where url.pathExtension == "swift" && url.lastPathComponent != "DesignTokens.swift" {
        for issue in check(try String(contentsOf: url, encoding: .utf8)) {
            print("FAIL: \(url.lastPathComponent) user-facing copy: \(issue)"); failed = true
        }
    }
    if failed { exit(1) }
    print("User-facing copy AST PASS")
}
