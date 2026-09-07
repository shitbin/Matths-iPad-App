# Legacy native generator: undefined cubic coefficients

The native cubic-extremum question now defines the unknown coefficients in
`f(x) = x³ + px² + qx`. Previously it substituted the already-solved numeric
coefficients into the question while still asking for `p + q`, leaving `p` and
`q` undefined. The first derivative explanation now remains symbolic until the
root/coefficient steps solve the values.

## Reachable paths and reproduction

- The DEBUG launch arguments are `-demo -exam 77` (the flag and seed are separate).
  `AppStore` sends the four legacy types to `startExam(types:count:seed:)`, which
  uses `ExamFactory.make` and then `ProblemType.generate`.
- The same generator is reachable outside the debug shortcut: Pro's weak-type
  practice button calls `startExam(types:count:)`, and the review variation check
  calls it with one matching native type.
- Seed 77 produces extrema at `a = -5`, `b = 5`; the solved coefficients are
  `p = 0`, `q = -75`, so the unchanged answer is `-75`.
- Before the fix, the first question displayed `f(x) = x³ − 75x` but asked for
  the undefined `p + q`. After the fix, it displays `f(x) = x³ + px² + qx` with
  the same extrema and answer.

## Narrow changes

Only three string expressions changed in `Matths/ProblemGenerator.swift`:

1. Define the cubic's unknown coefficients in the question.
2. Keep the derivative `f'(x) = 3x² + 2px + q` symbolic in the first explanation.
3. Group an exponent subtraction explicitly as `a^(m+n − p)` in the exponent-law
   explanation, replacing the ambiguous mixed baseline/superscript subtraction.

No random draws, numerical ranges, answers, durations, visualization parameters,
grading rules, WebGen code, bank data, or server behavior changed. Old persisted
questions are not rewritten by this change; newly generated questions use it.

## Executed checks

The test compiles the actual `MathAnswer.swift` and `ProblemGenerator.swift` with
`tests/LegacyGeneratorSemanticsCases.swift` using the installed Swift compiler.

```sh
sh tests/run-legacy-generator-semantics.sh
sh tests/run-problem-difficulty-contract.sh
```

- Red phase: the cubic coefficient assertion failed against the original code,
  process exit 133. The exponent-grouping assertion separately failed against
  the original exponent-law string, also exit 133.
- Green phase: 17,017 cases passed (all 17 native types, seeds 0 through 999 and
  `UInt64.max`), including the exact seed-77 four-question factory fixture.
- Existing difficulty contract passed: 14 broadened types and the three
  intentionally unchanged types.
- Bounded review covered statements, numerical answers and explanation formulas
  for all 17 types. The new tests verify cubic derivative roots and second-
  derivative signs, logarithm domain, counting factorials, exact linear-integral
  area, periodic sequence sums and uniqueness within the tested range, the
  discriminant's strict integer boundary, Vieta, point-to-circle distance,
  enumeration of all 36 dice outcomes, exponent and polynomial arithmetic,
  complex products, linear expectation/variance, binomial moments computed from
  its probability mass function, normal standardization and sample-mean moments.
- No further statement/answer arithmetic mismatch was found in those generated
  cases. This is bounded evidence, not proof of every possible generated seed.

This check was host-side only; it did not manipulate any simulator or physical
device, submit results, or alter student progress. It does not establish UI
rendering, official web question parity, or performance on a device. The parent
agent owns the subsequent integrated build and screen verification.
