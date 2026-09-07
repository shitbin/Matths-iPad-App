import Foundation

@main enum LegacyGeneratorSemanticsCases {
    static func main() throws {
        let reproduction = ExamFactory.make(types: [.extremum, .logEq, .counting, .integral], count: 4, seed: 77)
        guard let first = reproduction.first else { fatalError("empty seed-77 exam") }
        print("seed 77: \(first.statement) / answer=\(first.answer)")
        precondition(first.typeKey == ProblemType.extremum.rawValue && first.answer == "-75", "seed-77 numerical fixture must remain stable")
        precondition(first.statement.contains("f(x) = x³ + px² + qx"), "unknown coefficients p and q must be defined in the function, not replaced by their answers")

        var checked = 0
        let seeds = Array(UInt64(0)...UInt64(999)) + [UInt64.max]
        for seed in seeds {
            for type in ProblemType.allCases {
                var rng = SeededRNG(seed: seed)
                let problem = type.generate(rng: &rng, index: 0)
                try check(problem, type: type)
                checked += 1
            }
        }
        print("Legacy generator semantics: \(checked) cases across \(ProblemType.allCases.count) types and \(seeds.count) seeds passed; web generators unchanged")
    }

    private static func check(_ problem: GeneratedProblem, type: ProblemType) throws {
        guard let raw = problem.visualizationJSON?.data(using: .utf8),
              let values = try JSONSerialization.jsonObject(with: raw) as? [String: Any] else { fatalError("missing generator metadata") }
        func i(_ key: String) -> Int { (values[key] as! NSNumber).intValue }
        func flag(_ key: String) -> Bool { (values[key] as! NSNumber).boolValue }
        func has(_ text: String) { precondition(problem.statement.contains(text), "\(type): missing \(text): \(problem.statement)") }
        func expected(_ value: Int) { precondition(problem.answer == String(value), "\(type): \(problem.answer) != \(value)") }
        func power(_ base: Int, _ exponent: Int) -> Int { (0..<exponent).reduce(1) { x, _ in x * base } }
        func factorial(_ number: Int) -> Int { number == 0 ? 1 : (1...number).reduce(1, *) }

        precondition(problem.typeKey == type.rawValue && !problem.steps.isEmpty)
        switch type {
        case .extremum:
            let a = i("a"), b = i("b"), p = i("p"), q = i("q")
            has("f(x) = x³ + px² + qx"); has("x = \(a) 에서 극대"); has("x = \(b) 에서 극소")
            precondition(a < b && (a + b).isMultiple(of: 2))
            precondition(3*a*a + 2*p*a + q == 0 && 3*b*b + 2*p*b + q == 0)
            precondition(6*a + 2*p < 0 && 6*b + 2*p > 0, "stationary points must have the stated maximum/minimum roles")
            precondition(problem.steps.first == "f'(x) = 3x² + 2px + q")
            expected((-3 * (a+b) / 2) + 3*a*b)
        case .logEq:
            let base = i("base"), k = i("k"), c = i("c")
            has("x − \(c)"); has("= \(k)")
            has("log" + [2: "₂", 3: "₃", 5: "₅"][base]!)
            expected(power(base, k) + c)
            precondition(Int(problem.answer)! - c > 0)
        case .counting:
            let n = i("n"), r = i("r"), perm = flag("isPerm")
            has("\(n)명의"); has("\(r)명을")
            precondition(problem.statement.contains("일렬") == perm)
            let permutations = factorial(n) / factorial(n-r)
            expected(perm ? permutations : permutations / factorial(r))
        case .integral:
            let a = i("a"), b = i("b")
            has("∫₀^\(a)"); has("2x + \(b)")
            // Trapezoid rule is exact for this linear integrand.
            expected(((b + 2*a+b) * a) / 2)
        case .seqBlockSum:
            let p = i("p"), q = i("q")
            has("aₙ = \(p)"); has("aₙ = −\(q)")
            precondition(p.isMultiple(of: 2) && q == 2*p - 1)
            var sums = [0]
            for index in 1...900 { sums.append(sums.last! + (index.isMultiple(of: 3) ? -q : p)) }
            let solutions = (1...300).filter { sums[$0] == sums[3*$0] }
            precondition(solutions == [Int(problem.answer)!], "periodic sequence must have one positive solution")
        case .quadDisc:
            let coefficient = i("b"), answer = Int(problem.answer)!
            has("x² + \(coefficient)x + c"); has("서로 다른 두 실근")
            precondition(coefficient*coefficient - 4*answer > 0)
            precondition(coefficient*coefficient - 4*(answer+1) <= 0)
        case .vieta:
            let sum = i("s"), product = i("p")
            has("x² − \(sum)x + \(product)")
            precondition(sum*sum >= 4*product)
            expected(sum*sum - 2*product)
        case .circleDist:
            let x = i("px"), y = i("py"), radius = i("r")
            has("반지름이 \(radius)"); has("P(\(x), \(y))")
            let distance = Int(sqrt(Double(x*x+y*y)))
            precondition(distance*distance == x*x+y*y && distance > radius)
            expected(distance-radius)
        case .diceProb:
            let target = i("target")
            has("합이 \(target)")
            let outcomes = (1...6).flatMap { x in (1...6).map { x + $0 } }.filter { $0 == target }.count
            precondition(problem.answer == "\(outcomes)/36")
        case .expLaw:
            let a = i("a"), m = i("m"), n = i("n"), p = i("p")
            has("(\(a)^\(m) × \(a)^\(n)) ÷ \(a)^\(p)")
            precondition(problem.steps[1].hasSuffix("= \(a)^(\(m+n) − \(p))"), "the entire exponent difference must be grouped")
            expected(power(a,m+n-p))
        case .polyExpand:
            let a = i("a"), b = i("b"), linear = flag("askLinear")
            has("(x + \(a))(x + \(b))")
            precondition(problem.statement.contains("x 의 계수") == linear)
            expected(linear ? a+b : a*b)
        case .complexMul:
            let a = i("a"), coefficient = i("b"), c = i("c"), d = i("d"), real = flag("askReal")
            has("(\(a) + \(coefficient)i)(\(c) + \(d)i)")
            precondition(problem.statement.contains("실수부") == real)
            expected(real ? a*c-coefficient*d : a*d+coefficient*c)
        case .statMean:
            let mean = i("base"), a = i("a"), b = i("b")
            has("E(X) = \(mean)"); has("E(\(a)X + \(b))")
            expected(a*mean+b)
        case .statVar:
            let variance = i("base"), a = i("a"), b = i("b")
            has("V(X) = \(variance)"); has("V(\(a)X + \(b))")
            expected(a*a*variance)
        case .statBinom:
            let n = i("n"), numerator = i("num"), denominator = i("den"), mean = flag("askMean")
            has("B(\(n), \(numerator)/\(denominator))")
            precondition(problem.statement.contains("E(X) 의") == mean)
            let p = Double(numerator)/Double(denominator)
            var probability = pow(1-p, Double(n))
            var mass = 0.0, expectation = 0.0, secondMoment = 0.0
            for k in 0...n {
                mass += probability
                expectation += Double(k)*probability
                secondMoment += Double(k*k)*probability
                if k < n { probability *= Double(n-k)/Double(k+1)*p/(1-p) }
            }
            precondition(abs(mass-1) < 1e-10)
            let result = mean ? expectation : secondMoment-expectation*expectation
            precondition(abs(Double(problem.answer)!-result) < 1e-7)
        case .statNormal:
            let mean = i("mean"), sigma = i("sigma"), x = i("x0")
            has("N(\(mean), \(sigma)²)"); has("X = \(x)")
            precondition(sigma > 0 && (x-mean).isMultiple(of: sigma))
            expected((x-mean)/sigma)
        case .statSample:
            let mean = i("mean"), sigma = i("sigma"), n = i("n"), askMean = flag("askMean")
            has("모평균 \(mean), 모표준편차 \(sigma)"); has("크기 \(n)")
            precondition(problem.statement.contains("평균 E(X̄)") == askMean)
            precondition(n > 0 && (sigma*sigma).isMultiple(of: n))
            expected(askMean ? mean : sigma*sigma/n)
        }
    }
}
