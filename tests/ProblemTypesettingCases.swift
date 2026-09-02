import Foundation

@main
struct ProblemTypesettingCases {
    private static func problem(
        statement: String,
        choices: [String]? = nil,
        isTex: Bool = false,
        steps: [String] = []
    ) -> GeneratedProblem {
        GeneratedProblem(
            id: "typesetting-case",
            typeKey: "typesetting",
            typeName: "수식 조판",
            unit: "공통수학",
            statement: statement,
            answer: "1",
            steps: steps,
            minutes: 1,
            choices: choices,
            isTex: isTex
        )
    }

    static func main() {
        precondition(!problem(statement: "두 수의 합을 구하세요.").needsMathTypesetting)
        precondition(problem(statement: #"\(\displaystyle\frac{1}{2}\)의 값은?"#)
            .needsMathTypesetting)
        precondition(problem(statement: #"\[x^2=1\]"#).needsMathTypesetting)
        precondition(problem(statement: "$x+1$의 값은?").needsMathTypesetting)
        precondition(problem(statement: "알맞은 답을 고르세요.", choices: ["1", "2"])
            .needsMathTypesetting)
        precondition(problem(statement: "일반 발문", isTex: true).needsMathTypesetting)
        precondition(problem(statement: "일반 발문", steps: [#"\(x=1\)"#])
            .needsMathTypesetting)
        print("problem typesetting inference passed")
    }
}
