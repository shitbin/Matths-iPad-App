/* ============================================================
   공통수학1 (2022 개정) — 신규 개념 12종
   다항식 3 · 방정식과 부등식 5(판별식은 concepts.js) · 경우의 수 3 · 행렬 1
   ============================================================ */

/* ---------- C-001 다항식의 연산 (곱셈공식) ---------- */
const cmDaePoly = {
  id: "cm1-poly",
  course: "공통수학1", unit: "다항식",
  badge: "공통수학1 · 다항식",
  title: "다항식의 곱셈 (곱셈공식)",
  tag: "(x+a)(x+b)는 넓이 4조각으로 눈에 보인다",
  oneLiner: "다항식 곱셈은 직사각형 넓이 나누기다. (x+a)(x+b) = x² + (a+b)x + ab.",
  veilText: "🙈 그림 가림 — 넓이 4조각을 머리로 떠올려봐.",
  playgroundGuide: "a, b를 움직여봐. 큰 직사각형이 x², ax, bx, ab 네 조각으로 나뉘는 게 곱셈공식의 정체다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let a = 2, b = 3;
    const render = () => {
      drawAreaModel(svg, { a, b });
      readoutEl.innerHTML =
        `<div class="formula">(x + ${a})(x + ${b}) = x² + ${a + b}x + ${a * b}</div>` +
        `<div class="d-count">가로 (x+${a}) × 세로 (x+${b}) 의 전체 넓이</div>`;
    };
    const sa = buildSlider(controlsEl, { label: "a", min: 1, max: 5, step: 1, value: a, format: fmt });
    const sb = buildSlider(controlsEl, { label: "b", min: 1, max: 5, step: 1, value: b, format: fmt });
    sa.onChange = (v) => { a = v; render(); };
    sb.onChange = (v) => { b = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>(x + 2)(x + 3)</b> 을 전개하면?",
    choices: ["x² + 5x + 6", "x² + 6x + 5", "x² + 5x + 5", "x² + 6x + 6"],
    answer: 0,
    hint: "가운데 항은 a+b(합), 마지막 항은 ab(곱). 2+3과 2×3.",
    wrongNotes: [
      null,
      "합과 곱이 뒤바뀌었다. x항 계수는 2+3=5, 상수항은 2×3=6.",
      "상수항은 두 수의 곱. 2×3=6인데 5로 적었다.",
      "x항 계수는 두 수의 합. 2+3=5인데 6으로 적었다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "가로 x+2, 세로 x+3 인 직사각형을 그린다.", run: () => drawAreaModel(svg, { a: 2, b: 3 }) },
      { caption: "넓이를 4조각으로 나누면 x², 2x, 3x, 6.", run: () => {} },
      { caption: "네 조각을 더하면 x² + 2x + 3x + 6 = x² + 5x + 6.", run: () => {} },
      { caption: "결론: 가운데 항은 합(2+3), 상수항은 곱(2×3). 공식이 아니라 넓이다.", run: () => {} },
    ];
  },
};

/* ---------- C-002 항등식과 나머지정리 ---------- */
const cmDaeRemainder = {
  id: "cm1-remainder",
  course: "공통수학1", unit: "다항식",
  badge: "공통수학1 · 다항식",
  title: "항등식과 나머지정리",
  tag: "(x−a)로 나눈 나머지 = P(a). 나눗셈이 대입 한 번으로 끝난다",
  oneLiner: "P(x)를 (x−a)로 나눈 나머지는 직접 나누지 않아도 P(a)를 계산하면 바로 나온다.",
  veilText: "🙈 그래프 가림 — 나머지정리 공식만으로 답해봐.",
  playgroundGuide: "a를 움직여봐. 그래프 위 x=a 지점의 함숫값 P(a)가 곧 (x−a)로 나눈 나머지다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -5, xMax: 5, yMin: -8, yMax: 12 });
    g.drawBase();
    let a = 2;
    const P = (x) => x * x - 3 * x + 5;
    const render = () => {
      g.curve("curve", P, { color: VIZ_COLORS.primary, width: 4.5 });
      const pa = P(a);
      g.clearLayer("pt");
      if (pa >= g.yMin && pa <= g.yMax) {
        const layer = g.layer("pt");
        layer.appendChild(g.el("line", { x1: g.px(a), y1: g.py(0), x2: g.px(a), y2: g.py(pa), stroke: VIZ_COLORS.lime, "stroke-width": 3.5, "stroke-dasharray": "3 6" }));
        g.point("pt", a, pa, { append: true, color: VIZ_COLORS.point, r: 8 });
        g.point("pt", a, 0, { append: true, color: VIZ_COLORS.lime, r: 6 });
      }
      readoutEl.innerHTML =
        `<div class="formula">P(x) = x² − 3x + 5</div>` +
        `<div class="d-badge pos">(x − ${fmt(a)}) 로 나눈 나머지 = P(${fmt(a)}) = ${fmt(P(a))}</div>` +
        `<div class="d-count">P(x) = (x − ${fmt(a)})·Q(x) + R 에 x = ${fmt(a)} 대입 → R = P(${fmt(a)})</div>`;
    };
    const sa = buildSlider(controlsEl, { label: "a — 나누는 식 (x − a)", min: -3, max: 3, step: 1, value: a, format: fmt });
    sa.onChange = (v) => { a = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "다항식 <b>P(x) = x² − 3x + 5</b> 를 <b>(x − 2)</b> 로 나눈 나머지는?",
    choices: ["3", "5", "−2", "15"],
    answer: 0,
    hint: "나머지정리: 나머지 = P(2). 4 − 6 + 5 를 계산해봐.",
    wrongNotes: [
      null,
      "P(0)을 구했네. 나누는 식이 (x−2)니까 대입할 값은 x=2다.",
      "4 − 6 = −2에서 멈췄다. 마지막 +5까지 더해야 P(2) = 3.",
      "P(−2)를 구했다. (x−2)=0이 되는 값은 x=+2.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -2, xMax: 5, yMin: -2, yMax: 12 });
    g.drawBase();
    const P = (x) => x * x - 3 * x + 5;
    return [
      { caption: "나눗셈의 정체: P(x) = (x−2)·Q(x) + R (R는 상수).", run: () => { g.curve("c", P, { color: VIZ_COLORS.primary, width: 4.5 }); } },
      { caption: "양변에 x = 2 대입 → (x−2)가 0이 되면서 Q(x)가 통째로 사라진다.", run: () => {
        g.text(-1.4, 10.8, "P(2) = 0·Q(2) + R", { layerId: "t1", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "그래서 R = P(2) = 4 − 6 + 5 = 3. 그래프의 x=2 함숫값이 곧 나머지.", run: () => {
        g.point("p", 2, 3, { color: VIZ_COLORS.secondary, r: 9 });
        g.text(2.25, 3.3, "P(2) = 3", { layerId: "t2", size: 19, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "결론: 나머지 = 3. 직접 나눗셈 없이 대입 한 번으로 끝.", run: () => {
        g.text(-1.4, 9.2, "R = 3 ✓", { layerId: "t3", size: 25, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-003 인수분해 ---------- */
const cmDaeFactor = {
  id: "cm1-factor",
  course: "공통수학1", unit: "다항식",
  badge: "공통수학1 · 다항식",
  title: "인수분해",
  tag: "합과 곱을 만족하는 두 수 찾기 — 전개의 되감기",
  oneLiner: "x²+Sx+P 인수분해는 \"합이 S, 곱이 P인 두 수\"를 찾아 직사각형으로 재조립하는 것이다.",
  veilText: "🙈 그림 가림 — 합·곱 조건만으로 두 수를 찾아봐.",
  playgroundGuide: "두 수 m, n을 움직여봐. 목표식 x²+7x+12와 조각이 일치하는 순간이 인수분해 성공이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let m = 2, n = 5;
    const S = 7, P = 12;
    const render = () => {
      drawAreaModel(svg, { a: m, b: n, factorMode: true });
      const ok = m + n === S && m * n === P;
      readoutEl.innerHTML =
        `<div class="formula">목표: x² + ${S}x + ${P}</div>` +
        `<div class="d-badge ${ok ? "pos" : "neg"}">지금: (x+${m})(x+${n}) = x² + ${m + n}x + ${m * n} ${ok ? "— 일치! 🎉" : ""}</div>` +
        `<div class="d-count">합 ${m}+${n}=${m + n} (목표 ${S}) · 곱 ${m}×${n}=${m * n} (목표 ${P})</div>`;
    };
    const sm = buildSlider(controlsEl, { label: "첫째 수 m", min: 1, max: 6, step: 1, value: m, format: fmt });
    const sn = buildSlider(controlsEl, { label: "둘째 수 n", min: 1, max: 6, step: 1, value: n, format: fmt });
    sm.onChange = (v) => { m = v; render(); };
    sn.onChange = (v) => { n = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>x² + 7x + 12</b> 를 인수분해하면?",
    choices: ["(x + 3)(x + 4)", "(x + 2)(x + 5)", "(x + 1)(x + 6)", "(x + 2)(x + 6)"],
    answer: 0,
    hint: "합이 7이면서 곱이 12인 두 수. 후보를 곱으로 먼저 거른다: 12 = 1·12, 2·6, 3·4.",
    wrongNotes: [
      null,
      "합 2+5=7은 맞는데 곱 2×5=10 ≠ 12. 합만 보고 달리면 이렇게 당한다.",
      "합 1+6=7은 맞는데 곱 1×6=6 ≠ 12. 곱 검산은 필수다.",
      "곱 2×6=12는 맞는데 합 2+6=8 ≠ 7. 이번엔 합에서 미끄러졌네.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "x² + 7x + 12: 합이 7, 곱이 12인 두 수를 찾는 게임이다.", run: () => drawAreaModel(svg, { a: 3, b: 4, factorMode: true }) },
      { caption: "곱 12의 후보: (1,12), (2,6), (3,4). 이 중 합이 7인 것은 (3,4)뿐.", run: () => {} },
      { caption: "조각들을 직사각형으로 재조립하면 가로 (x+3), 세로 (x+4).", run: () => {} },
      { caption: "결론: x² + 7x + 12 = (x+3)(x+4). 전개를 거꾸로 감은 것뿐이다.", run: () => {} },
    ];
  },
};

/* ---------- C-004 복소수 ---------- */
const cmDaeComplex = {
  id: "cm1-complex",
  course: "공통수학1", unit: "방정식과 부등식",
  badge: "공통수학1 · 방정식과 부등식",
  title: "복소수와 i의 정체",
  tag: "i를 곱하면 90° 회전 — i²=−1이 눈에 보인다",
  oneLiner: "i는 제곱해서 −1이 되는 수이고, 복소평면에서 i를 곱하는 것은 원점 중심 90° 회전이다.",
  veilText: "🙈 복소평면 가림 — i의 거듭제곱 주기(4)로만 판단해봐.",
  playgroundGuide: "a, b로 점 z = a+bi 를 만들고 [×i] 버튼을 눌러봐. 점이 90°씩 도는 게 보이면 i²=−1은 자동으로 이해된다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -6, xMax: 6, yMin: -6, yMax: 6 });
    g.drawBase();
    let a = 3, b = 1, rot = 0; // rot: ×i 횟수
    const render = () => {
      // 현재 z0 = (a+bi), z = z0 × i^rot
      let re = a, im = b;
      for (let k = 0; k < rot; k++) { const t = re; re = -im; im = t; }
      g.clearLayer("vec");
      const layer = g.layer("vec");
      layer.appendChild(g.el("line", { x1: g.px(0), y1: g.py(0), x2: g.px(a), y2: g.py(b), stroke: VIZ_COLORS.axis, "stroke-width": 2.5, "stroke-dasharray": "5 6" }));
      layer.appendChild(g.el("line", { x1: g.px(0), y1: g.py(0), x2: g.px(re), y2: g.py(im), stroke: VIZ_COLORS.primary, "stroke-width": 4.5, "stroke-linecap": "round" }));
      g.point("vec", a, b, { append: true, color: VIZ_COLORS.axis, r: 6 });
      g.point("vec", re, im, { append: true, color: VIZ_COLORS.point, r: 8 });
      const zStr = (r, i2) => `${fmt(r)}${i2 >= 0 ? " + " + fmt(i2) : " − " + fmt(-i2)}i`;
      readoutEl.innerHTML =
        `<div class="formula">z = ${zStr(a, b)}</div>` +
        `<div class="d-badge ${rot % 4 === 0 ? "pos" : "zero"}">× i를 ${rot}번 → ${zStr(re, im)}</div>` +
        `<div class="d-count">i¹=i, i²=−1, i³=−i, i⁴=1 — 4번 돌면 제자리 (360°)</div>`;
    };
    const sa = buildSlider(controlsEl, { label: "a — 실수부", min: -4, max: 4, step: 1, value: a, format: fmt });
    const sb = buildSlider(controlsEl, { label: "b — 허수부", min: -4, max: 4, step: 1, value: b, format: fmt });
    sa.onChange = (v) => { a = v; rot = 0; render(); };
    sb.onChange = (v) => { b = v; rot = 0; render(); };
    buildButtonRow(controlsEl, [
      { label: "× i (90° 회전)", onClick: () => { rot = (rot + 1) % 8; render(); } },
      { label: "리셋", onClick: () => { rot = 0; render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>i⁴⁷</b> 의 값은?",
    choices: ["−i", "i", "−1", "1"],
    answer: 0,
    hint: "i는 4개마다 한 바퀴. 47 = 4×11 + 3 이니까 i⁴⁷ = i³.",
    wrongNotes: [
      null,
      "i¹과 헷갈렸다. 47을 4로 나눈 나머지는 3. i³ = −i.",
      "i²와 헷갈렸다. 나머지가 2가 아니라 3이다.",
      "i⁴ = 1은 나머지가 0일 때. 47은 4의 배수가 아니다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -3, xMax: 3, yMin: -3, yMax: 3 });
    g.drawBase();
    const arrow = (re, im, color, id) => {
      const layer = g.clearLayer(id);
      layer.appendChild(g.el("line", { x1: g.px(0), y1: g.py(0), x2: g.px(re), y2: g.py(im), stroke: color, "stroke-width": 4.5, "stroke-linecap": "round" }));
      g.point(id, re, im, { append: true, color, r: 8 });
    };
    return [
      { caption: "1에서 출발. i를 곱할 때마다 90° 회전한다: 1 → i → −1 → −i → 1", run: () => {
        arrow(1.8, 0, VIZ_COLORS.axis, "a0");
        g.text(1.9, 0.25, "1", { layerId: "t0", size: 20, weight: 800 });
      } },
      { caption: "네 번 곱하면 제자리(i⁴=1). 그래서 지수는 4로 나눈 나머지만 남는다.", run: () => {
        arrow(0, 1.8, VIZ_COLORS.secondary, "a1"); g.text(0.15, 1.95, "i", { layerId: "t1", size: 20, fill: VIZ_COLORS.secondary, weight: 800 });
        arrow(-1.8, 0, VIZ_COLORS.secondary, "a2"); g.text(-2.45, 0.25, "−1", { layerId: "t2", size: 20, fill: VIZ_COLORS.secondary, weight: 800 });
      } },
      { caption: "47 = 4 × 11 + 3 → i⁴⁷ = (i⁴)¹¹ · i³ = i³", run: () => {
        g.text(-2.8, 2.6, "i⁴⁷ = i³", { layerId: "t3", size: 23, fill: VIZ_COLORS.primary, weight: 800 });
      } },
      { caption: "i³ = −i. 결론: i⁴⁷ = −i. 계산이 아니라 회전 3칸이다.", run: () => {
        arrow(0, -1.8, VIZ_COLORS.primary, "a3");
        g.text(0.15, -2.2, "i³ = −i ✓", { layerId: "t4", size: 22, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-006 근과 계수의 관계 ---------- */
const cmDaeVieta = {
  id: "cm1-vieta",
  course: "공통수학1", unit: "방정식과 부등식",
  badge: "공통수학1 · 방정식과 부등식",
  title: "근과 계수의 관계",
  tag: "두 근만 알면 방정식이 통째로 복원된다",
  oneLiner: "x²+px+q=0에서 두 근의 합은 −p, 곱은 q다. 근이 계수를 만들고 계수가 근을 담고 있다.",
  veilText: "🙈 그래프 가림 — 합·곱 공식만으로 판단해봐.",
  playgroundGuide: "두 근 α, β를 직접 움직여봐. 방정식이 실시간으로 다시 조립되는 걸 보면 공식 부호가 헷갈릴 수 없다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -10, yMax: 10 });
    g.drawBase();
    let al = -1, be = 3;
    const render = () => {
      const s = al + be, p = al * be;
      g.curve("curve", (x) => (x - al) * (x - be), { color: VIZ_COLORS.primary, width: 4.5 });
      g.clearLayer("roots");
      g.point("roots", al, 0, { append: true, color: VIZ_COLORS.secondary, r: 8 });
      g.point("roots", be, 0, { append: true, color: VIZ_COLORS.secondary, r: 8 });
      readoutEl.innerHTML =
        `<div class="formula">x² ${s === 0 ? "" : `${s > 0 ? "− " + fmt(s) : "+ " + fmt(-s)}x `}${p === 0 ? "" : p > 0 ? `+ ${fmt(p)} ` : `− ${fmt(-p)} `}= 0</div>` +
        `<div class="d-badge pos">합 α+β = ${fmt(s)} → x항 계수는 ${fmt(-s)}</div>` +
        `<div class="d-count">곱 αβ = <b>${fmt(p)}</b> → 상수항 그대로</div>`;
    };
    const s1 = buildSlider(controlsEl, { label: "근 α", min: -5, max: 5, step: 1, value: al, format: fmt });
    const s2 = buildSlider(controlsEl, { label: "근 β", min: -5, max: 5, step: 1, value: be, format: fmt });
    s1.onChange = (v) => { al = v; render(); };
    s2.onChange = (v) => { be = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "이차방정식 <b>x² − 5x + 6 = 0</b> 의 두 근의 <b>합</b>과 <b>곱</b>은?",
    choices: ["합 5, 곱 6", "합 −5, 곱 6", "합 5, 곱 −6", "합 6, 곱 5"],
    answer: 0,
    hint: "x²+px+q=0에서 합 = −p, 곱 = q. 여기서 p = −5, q = 6.",
    wrongNotes: [
      null,
      "부호 함정. 합 = −p = −(−5) = +5. 계수 부호를 그대로 읽으면 당한다.",
      "곱은 상수항 그대로 +6. 곱까지 부호를 뒤집을 필요는 없다.",
      "합과 곱이 자리를 바꿨다. 합 = −(x항 계수), 곱 = 상수항.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -1, xMax: 6, yMin: -2, yMax: 8 });
    g.drawBase();
    return [
      { caption: "근이 α, β라면 방정식은 (x−α)(x−β) = 0 으로 쓸 수 있다.", run: () => {
        g.curve("c", (x) => (x - 2) * (x - 3), { color: VIZ_COLORS.primary, width: 4.5 });
        g.point("p1", 2, 0, { color: VIZ_COLORS.secondary, r: 8 });
        g.point("p2", 3, 0, { color: VIZ_COLORS.secondary, r: 8 });
      } },
      { caption: "전개하면 x² − (α+β)x + αβ = 0. 합과 곱이 계수 자리에 박힌다.", run: () => {
        g.text(-0.6, 7.0, "x² − (α+β)x + αβ", { layerId: "t1", size: 22, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "x² − 5x + 6 과 비교: α+β = 5, αβ = 6. (실제 근은 2와 3)", run: () => {
        g.text(-0.6, 5.8, "α+β = 5, αβ = 6", { layerId: "t2", size: 22, fill: VIZ_COLORS.primary, weight: 700 });
      } },
      { caption: "결론: 합 5, 곱 6. 근을 안 구해도 계수가 다 말해준다.", run: () => {
        g.text(-0.6, 4.6, "합 5 · 곱 6 ✓", { layerId: "t3", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-007 이차방정식과 이차함수의 관계 ---------- */
const cmDaeQuadRel = {
  id: "cm1-quadrel",
  course: "공통수학1", unit: "방정식과 부등식",
  badge: "공통수학1 · 방정식과 부등식",
  title: "이차방정식 ↔ 이차함수",
  tag: "방정식의 해 = 그래프가 직선과 만나는 점의 x좌표",
  oneLiner: "이차방정식 f(x)=k의 실근은 y=f(x) 그래프와 직선 y=k의 교점 x좌표와 같다.",
  veilText: "🙈 그래프 가림 — 교점=실근 원리로만 판단해봐.",
  playgroundGuide: "수평선 y=k를 위아래로 움직여봐. 교점의 x좌표가 곧 방정식 x²−2x−3=k의 실근이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -6, xMax: 8, yMin: -8, yMax: 10 });
    g.drawBase();
    let k = 0;
    const f = (x) => x * x - 2 * x - 3;
    const render = () => {
      g.curve("curve", f, { color: VIZ_COLORS.primary, width: 4.5 });
      g.fullLine("k", 0, k, { color: VIZ_COLORS.second, width: 3 });
      // x²-2x-3=k → x²-2x-(3+k)=0 → D/4 = 1+(3+k) = 4+k
      const D = 4 + k;
      g.clearLayer("meet");
      let roots = [];
      if (D > 1e-9) roots = [1 - Math.sqrt(D), 1 + Math.sqrt(D)];
      else if (Math.abs(D) <= 1e-9) roots = [1];
      roots.forEach((r) => g.point("meet", r, k, { append: true, color: VIZ_COLORS.point, r: 8 }));
      readoutEl.innerHTML =
        `<div class="formula">x² − 2x − 3 = ${fmt(k)}</div>` +
        `<div class="d-badge ${roots.length === 2 ? "pos" : roots.length === 1 ? "zero" : "neg"}">교점 ${roots.length}개 = 실근 ${roots.length}개</div>` +
        `<div class="d-count">${roots.length ? "실근: " + roots.map((r) => fmt(r, 2)).join(", ") : "직선이 그래프 아래를 지나면 실근이 없다"}</div>`;
    };
    const sk = buildSlider(controlsEl, { label: "k — 직선 y = k 높이", min: -6, max: 8, step: 0.5, value: k, format: fmt });
    sk.onChange = (v) => { k = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "이차함수 <b>y = x² − 2x − 3</b> 의 그래프가 <b>x축과 만나는 점의 x좌표</b>를 모두 고르면?",
    choices: ["−1 과 3", "1 과 −3", "−1 과 −3", "1 과 3"],
    answer: 0,
    hint: "x축과의 교점 = 방정식 x²−2x−3=0의 해. 인수분해: (x−3)(x+1).",
    wrongNotes: [
      null,
      "(x−3)(x+1)=0 의 해는 x=3, x=−1. 부호를 반대로 읽었다.",
      "곱이 −3인데 (−1)×(−3)=+3. 상수항 부호가 안 맞는다.",
      "합이 −2가 아니라 +2가 돼버린다. 1+3=4도 아니고… 검산 습관!",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -3, xMax: 5, yMin: -6, yMax: 6 });
    g.drawBase();
    const f = (x) => x * x - 2 * x - 3;
    return [
      { caption: "방정식 x²−2x−3=0 을 그래프 문제로 바꾼다: y=x²−2x−3 과 y=0(x축).", run: () => {
        g.curve("c", f, { color: VIZ_COLORS.primary, width: 4.5 });
      } },
      { caption: "인수분해: x²−2x−3 = (x−3)(x+1)", run: () => {
        g.text(-2.5, 5.0, "(x−3)(x+1) = 0", { layerId: "t1", size: 22, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "그래프가 x축을 뚫는 지점이 정확히 x=−1, x=3.", run: () => {
        g.point("p1", -1, 0, { color: VIZ_COLORS.secondary, r: 9 });
        g.point("p2", 3, 0, { color: VIZ_COLORS.secondary, r: 9 });
      } },
      { caption: "결론: 방정식의 해 = 그래프의 교점 x좌표. 대수와 기하는 같은 말이다.", run: () => {
        g.text(-2.5, 3.8, "x = −1, 3 ✓", { layerId: "t2", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-008 여러 가지 방정식 (삼차) ---------- */
const cmDaeCubic = {
  id: "cm1-cubic",
  course: "공통수학1", unit: "방정식과 부등식",
  badge: "공통수학1 · 방정식과 부등식",
  title: "여러 가지 방정식 (삼차방정식)",
  tag: "삼차도 결국 인수분해 — 근 하나 찾으면 나머진 이차",
  oneLiner: "삼차방정식은 인수정리로 근 하나를 찾아 (x−a)를 뽑아내면 이차방정식으로 강등된다.",
  veilText: "🙈 그래프 가림 — 인수분해만으로 근을 찾아봐.",
  playgroundGuide: "세 근 a, b, c를 움직여봐. 삼차 그래프가 x축을 세 번 뚫는 위치가 곧 세 근이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -5, xMax: 5, yMin: -12, yMax: 12 });
    g.drawBase();
    let a = -1, b = 0, c = 2;
    const render = () => {
      g.curve("curve", (x) => (x - a) * (x - b) * (x - c), { color: VIZ_COLORS.primary, width: 4.5 });
      g.clearLayer("roots");
      [a, b, c].forEach((r) => g.point("roots", r, 0, { append: true, color: VIZ_COLORS.secondary, r: 8 }));
      const uniq = [...new Set([a, b, c])];
      readoutEl.innerHTML =
        `<div class="formula">(x ${a >= 0 ? "− " + fmt(a) : "+ " + fmt(-a)})(x ${b >= 0 ? "− " + fmt(b) : "+ " + fmt(-b)})(x ${c >= 0 ? "− " + fmt(c) : "+ " + fmt(-c)}) = 0</div>` +
        `<div class="d-badge pos">서로 다른 실근 ${uniq.length}개</div>` +
        `<div class="d-count">${uniq.length < 3 ? "근이 겹치면 그래프가 x축에 접한다 (중근)" : "삼차 그래프가 x축을 세 번 통과"}</div>`;
    };
    const s1 = buildSlider(controlsEl, { label: "근 a", min: -4, max: 4, step: 1, value: a, format: fmt });
    const s2 = buildSlider(controlsEl, { label: "근 b", min: -4, max: 4, step: 1, value: b, format: fmt });
    const s3 = buildSlider(controlsEl, { label: "근 c", min: -4, max: 4, step: 1, value: c, format: fmt });
    s1.onChange = (v) => { a = v; render(); };
    s2.onChange = (v) => { b = v; render(); };
    s3.onChange = (v) => { c = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "삼차방정식 <b>x³ − x = 0</b> 의 모든 실근은?",
    choices: ["−1, 0, 1", "0, 1 뿐", "−1, 1 뿐", "0 뿐"],
    answer: 0,
    hint: "공통인수 x를 먼저 뽑아라: x(x²−1) = x(x−1)(x+1).",
    wrongNotes: [
      null,
      "x²−1=0 에서 x=−1도 나온다. 음수 근을 버렸네.",
      "공통인수로 뽑은 x 자체도 근이다(x=0). 뽑아놓고 잊어버리기 국룰.",
      "x=0만 보이면 인수분해를 끝까지 안 한 거다. x²−1이 남아 있다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -2.5, xMax: 2.5, yMin: -2.5, yMax: 2.5 });
    g.drawBase();
    return [
      { caption: "x³ − x = 0. 모든 항에 공통인수 x가 숨어 있다.", run: () => {
        g.curve("c", (x) => x * x * x - x, { color: VIZ_COLORS.primary, width: 4.5 });
      } },
      { caption: "x(x² − 1) = 0 → 다시 x²−1 = (x−1)(x+1) 로 쪼갠다.", run: () => {
        g.text(-2.2, 2.1, "x(x−1)(x+1) = 0", { layerId: "t1", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "곱이 0이려면 셋 중 하나가 0: x = 0, 1, −1.", run: () => {
        [-1, 0, 1].forEach((r, i) => g.point("p" + i, r, 0, { color: VIZ_COLORS.secondary, r: 8 }));
      } },
      { caption: "결론: 실근은 −1, 0, 1. 그래프도 정확히 세 번 x축을 통과한다.", run: () => {
        g.text(-2.2, 1.55, "x = −1, 0, 1 ✓", { layerId: "t2", size: 22, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-009 이차부등식 ---------- */
const cmDaeQuadIneq = {
  id: "cm1-quadineq",
  course: "공통수학1", unit: "방정식과 부등식",
  badge: "공통수학1 · 방정식과 부등식",
  title: "이차부등식",
  tag: "부등식의 해 = 그래프가 x축 아래(위)에 있는 구간",
  oneLiner: "이차부등식 f(x)<0의 해는 그래프가 x축 아래로 내려가 있는 x의 구간 그 자체다.",
  veilText: "🙈 그래프 가림 — 근 사이/바깥 규칙만으로 판단해봐.",
  playgroundGuide: "부등호 방향을 바꿔가며 관찰해봐. 아래로 볼록일 때 f<0은 근 사이, f>0은 근 바깥이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -6, xMax: 7, yMin: -9, yMax: 9 });
    g.drawBase();
    let dir = "lt"; // lt: f<0, gt: f>0
    const r1 = -2, r2 = 3;
    const f = (x) => (x - r1) * (x - r2);
    const render = () => {
      g.curve("curve", f, { color: VIZ_COLORS.primary, width: 4.5 });
      g.clearLayer("shade");
      const layer = g.layer("shade");
      // 해 구간 셰이딩
      const shade = (x1, x2) => {
        layer.appendChild(g.el("rect", {
          x: g.px(x1), y: g.py(0) - 5, width: g.px(x2) - g.px(x1), height: 10,
          fill: "rgba(198,242,46,0.9)", rx: 5,
        }));
      };
      if (dir === "lt") shade(r1, r2);
      else { shade(g.xMin, r1); shade(r2, g.xMax); }
      g.point("shade", r1, 0, { append: true, color: VIZ_COLORS.secondary, r: 8 });
      g.point("shade", r2, 0, { append: true, color: VIZ_COLORS.secondary, r: 8 });
      readoutEl.innerHTML =
        `<div class="formula">(x+2)(x−3) ${dir === "lt" ? "<" : ">"} 0</div>` +
        `<div class="d-badge ${dir === "lt" ? "pos" : "zero"}">해: ${dir === "lt" ? "−2 < x < 3 (근 사이)" : "x < −2 또는 x > 3 (근 바깥)"}</div>` +
        `<div class="d-count">${dir === "lt" ? "그래프가 x축 아래로 잠수하는 구간" : "그래프가 x축 위로 떠 있는 구간"}</div>`;
    };
    buildButtonRow(controlsEl, [
      { label: "f(x) < 0 (아래)", cls: "on", onClick: (btn) => { dir = "lt"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "f(x) > 0 (위)", onClick: (btn) => { dir = "gt"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "이차부등식 <b>x² − x − 6 < 0</b> 의 해는?",
    choices: ["−2 < x < 3", "x < −2 또는 x > 3", "−3 < x < 2", "해가 없다"],
    answer: 0,
    hint: "인수분해: (x−3)(x+2) < 0. 아래로 볼록 그래프가 x축 아래인 구간은 두 근 '사이'.",
    wrongNotes: [
      null,
      "그건 f(x) > 0의 해다. 부등호 방향이 반대. < 0 은 근 사이 구간이다.",
      "근을 잘못 구했다. (x−3)(x+2)=0 → x=3, −2. 부호 배치를 다시.",
      "D>0이라 근이 두 개 있고, 그 사이에서 확실히 음수가 된다. 해는 존재한다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -4, xMax: 5, yMin: -8, yMax: 6 });
    g.drawBase();
    const f = (x) => x * x - x - 6;
    return [
      { caption: "y = x² − x − 6 그래프를 그린다. 인수분해하면 (x−3)(x+2).", run: () => {
        g.curve("c", f, { color: VIZ_COLORS.primary, width: 4.5 });
        g.point("p1", -2, 0, { color: VIZ_COLORS.secondary, r: 8 });
        g.point("p2", 3, 0, { color: VIZ_COLORS.secondary, r: 8 });
      } },
      { caption: "부등식 f(x) < 0 은 \"그래프가 x축보다 낮은 곳\"을 찾으라는 뜻.", run: () => {
        g.text(-3.6, 5.0, "f(x) < 0 = x축 아래", { layerId: "t1", size: 20, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "아래로 볼록 포물선은 두 근 사이에서만 잠수한다.", run: () => {
        const layer = g.clearLayer("sh");
        layer.appendChild(g.el("rect", { x: g.px(-2), y: g.py(0) - 5, width: g.px(3) - g.px(-2), height: 10, fill: "rgba(198,242,46,0.9)", rx: 5 }));
      } },
      { caption: "결론: −2 < x < 3. 경계(−2, 3)는 등호가 없으니 제외.", run: () => {
        g.text(-3.6, 3.8, "−2 < x < 3 ✓", { layerId: "t2", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-010 합·곱의 법칙 ---------- */
const cmDaeCount = {
  id: "cm1-count",
  course: "공통수학1", unit: "경우의 수",
  badge: "공통수학1 · 경우의 수",
  title: "합의 법칙 · 곱의 법칙",
  tag: "'또는'이면 더하고, '이어서'면 곱한다",
  oneLiner: "동시에 못 일어나는 선택지는 더하고(합의 법칙), 연달아 하는 선택은 곱한다(곱의 법칙).",
  veilText: "🙈 트리 가림 — '또는'인지 '이어서'인지만 따져봐.",
  playgroundGuide: "상의·하의 개수를 바꿔봐. 가지가 뻗는 모양 자체가 곱셈이 되는 이유다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let m = 3, n = 2;
    const render = () => {
      drawChoiceTree(svg, { m, n });
      readoutEl.innerHTML =
        `<div class="formula">${m} × ${n} = ${m * n}가지</div>` +
        `<div class="d-count">상의 <b>각각</b>에 대해 하의 ${n}가지가 또 갈라진다 → 곱셈</div>` +
        `<div class="tip-line">"버스 2개 또는 지하철 3개"처럼 하나만 고르면? 2+3=5 (합의 법칙)</div>`;
    };
    const sm = buildSlider(controlsEl, { label: "상의 개수", min: 2, max: 4, step: 1, value: m, format: fmt });
    const sn = buildSlider(controlsEl, { label: "하의 개수", min: 2, max: 3, step: 1, value: n, format: fmt });
    sm.onChange = (v) => { m = v; render(); };
    sn.onChange = (v) => { n = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "집에서 학교까지 <b>버스 노선 2개, 지하철 노선 3개</b>가 있다. 버스 <b>또는</b> 지하철로 가는 방법의 수는?",
    choices: ["5가지", "6가지", "8가지", "12가지"],
    answer: 0,
    hint: "'또는'이다. 버스를 타면서 동시에 지하철을 탈 수는 없다 → 더한다.",
    wrongNotes: [
      null,
      "곱해버렸네(2×3). 곱셈은 '버스 타고 나서 이어서 지하철도 탈 때' 얘기다.",
      "2³을 계산했나? 이 문제엔 거듭제곱이 등장할 이유가 없다.",
      "왕복(2×3×2)을 상상했나? 문제는 편도 한 번이다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "핵심 질문: 두 선택이 '동시에/연달아' 인가, '둘 중 하나' 인가.", run: () => drawChoiceTree(svg, { m: 2, n: 3, labelA: "버스", labelB: "지하철" }) },
      { caption: "위 트리는 '버스 타고 이어서 지하철'일 때. 이러면 2×3=6 (곱의 법칙).", run: () => {} },
      { caption: "하지만 문제는 '또는'. 버스길 2개, 지하철길 3개는 겹치지 않는 별개 목록이다.", run: () => {} },
      { caption: "결론: 2 + 3 = 5가지 (합의 법칙). '또는'=덧셈, '이어서'=곱셈.", run: () => {} },
    ];
  },
};

/* ---------- C-011 순열 ---------- */
const cmDaePerm = {
  id: "cm1-perm",
  course: "공통수학1", unit: "경우의 수",
  badge: "공통수학1 · 경우의 수",
  title: "순열 (줄 세우기)",
  tag: "자리마다 선택지가 하나씩 줄어드는 곱셈",
  oneLiner: "n개 중 r개를 순서 있게 뽑는 수 nPr는 n×(n−1)×…로 r개를 곱한 것이다.",
  veilText: "🙈 자리 가림 — 자리별 선택지 곱만으로 계산해봐.",
  playgroundGuide: "n(사람 수)과 r(자리 수)를 바꿔봐. 자리마다 숫자가 1씩 줄어드는 게 순열의 전부다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 5, r = 3;
    const render = () => {
      if (r > n) { r = n; }
      const val = drawPermSlots(svg, { n, r });
      readoutEl.innerHTML =
        `<div class="formula">${n}P${r} = ${val}</div>` +
        `<div class="d-count">첫 자리 ${n}명 → 한 명 앉으면 다음 자리는 ${n - 1}명 → …</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "n — 전체 인원", min: 3, max: 6, step: 1, value: n, format: fmt });
    const sr = buildSlider(controlsEl, { label: "r — 자리 수", min: 2, max: 3, step: 1, value: r, format: fmt });
    sn.onChange = (v) => { n = v; render(); };
    sr.onChange = (v) => { r = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "학생 <b>5명</b> 중 <b>3명</b>을 뽑아 <b>일렬로 세우는</b> 방법의 수는?",
    choices: ["60", "10", "125", "15"],
    answer: 0,
    hint: "자리 3개: 첫 자리 5명, 둘째 4명, 셋째 3명 → 5×4×3.",
    wrongNotes: [
      null,
      "10은 5C3, 순서 없이 '뽑기만' 한 수다. 일렬로 '세우는' 건 순서가 있다.",
      "5³=125는 같은 사람을 또 세울 수 있을 때(중복순열). 한 명이 두 자리에 못 선다.",
      "5+4+3+2+1을 했나? 자리마다 곱해야지 더하면 안 된다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "자리 3개를 왼쪽부터 채운다. 첫 자리에 설 수 있는 사람은 5명.", run: () => drawPermSlots(svg, { n: 5, r: 3 }) },
      { caption: "한 명이 서고 나면 남은 사람은 4명. 둘째 자리는 4가지.", run: () => {} },
      { caption: "셋째 자리는 남은 3명 중 → 3가지. 각 단계가 '이어서'니까 곱한다.", run: () => {} },
      { caption: "결론: 5×4×3 = 60. 순열은 공식이 아니라 자리 채우기 곱셈이다.", run: () => {} },
    ];
  },
};

/* ---------- C-012 조합 ---------- */
const cmDaeComb = {
  id: "cm1-comb",
  course: "공통수학1", unit: "경우의 수",
  badge: "공통수학1 · 경우의 수",
  title: "조합 (뽑기만 하기)",
  tag: "순열에서 순서 중복 r!로 나누면 조합",
  oneLiner: "순서 없이 뽑는 조합 nCr는 줄 세우기 nPr를 같은 팀의 배열 수 r!로 나눈 것이다.",
  veilText: "🙈 그림 가림 — nPr ÷ r! 만으로 계산해봐.",
  playgroundGuide: "n, r를 바꿔봐. '순서만 다른 묶음'이 r!개씩 뭉쳐 하나가 되는 게 나눗셈의 이유다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 4, r = 2;
    const render = () => {
      if (r > n) r = n;
      const { nPr, nCr } = drawCombGroups(svg, { n, r });
      readoutEl.innerHTML =
        `<div class="formula">${n}C${r} = ${n}P${r} / ${r}! = ${nPr} / ${r === 2 ? 2 : 6} = ${nCr}</div>` +
        `<div class="d-count">뽑기만 할 때는 순서가 만든 거품 ${r}!을 걷어낸다</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "n — 전체 인원", min: 3, max: 6, step: 1, value: n, format: fmt });
    const sr = buildSlider(controlsEl, { label: "r — 뽑는 수", min: 2, max: 3, step: 1, value: r, format: fmt });
    sn.onChange = (v) => { n = v; render(); };
    sr.onChange = (v) => { r = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "학생 <b>5명</b> 중 <b>3명</b>을 뽑아 <b>청소 당번</b>을 정하는 방법의 수는? (당번끼리 역할 구분 없음)",
    choices: ["10", "60", "20", "125"],
    answer: 0,
    hint: "역할 구분이 없다 = 순서가 없다 = 조합. 5C3 = 5P3 ÷ 3! = 60 ÷ 6.",
    wrongNotes: [
      null,
      "60은 5P3, 일렬로 세울 때다. 당번은 ABC든 CBA든 같은 팀이다.",
      "3!=6으로 나눠야 하는데 3으로 나눴다. 세 명의 배열은 6가지다.",
      "5³은 중복 허용 얘기. 같은 사람을 세 번 뽑을 수는 없다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "일단 순서 있게 세우면 5P3 = 60가지.", run: () => drawCombGroups(svg, { n: 5, r: 3 }) },
      { caption: "그런데 ABC, ACB, BAC, BCA, CAB, CBA는 전부 같은 당번 팀이다.", run: () => {} },
      { caption: "같은 팀이 3! = 6개씩 중복 → 60을 6으로 나눈다.", run: () => {} },
      { caption: "결론: 5C3 = 60 ÷ 6 = 10. 조합 = 순열 ÷ 순서 거품.", run: () => {} },
    ];
  },
};

/* ---------- C-013 행렬과 그 연산 ---------- */
const cmDaeMatrix = {
  id: "cm1-matrix",
  course: "공통수학1", unit: "행렬",
  badge: "공통수학1 · 행렬 (2022 신설)",
  title: "행렬과 그 연산",
  tag: "곱셈은 '행 × 열' — 라이트가 켜지는 자리를 봐",
  oneLiner: "행렬 곱 AB의 (i,j) 성분은 A의 i행과 B의 j열을 순서대로 곱해 더한 값이다.",
  veilText: "🙈 행렬 가림 — 행×열 규칙만으로 계산해봐.",
  playgroundGuide: "결과 성분 위치를 바꿔봐. A의 어느 행, B의 어느 열에 라이트가 켜지는지가 곱셈 규칙의 전부다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const A = [[1, 2], [3, 4]], B = [[2, 0], [1, 3]];
    let op = "mul", hi = 0;
    const render = () => {
      const C = drawMatrixMul(svg, { A, B, op, hi });
      readoutEl.innerHTML =
        `<div class="formula">${op === "mul" ? "AB" : "A + B"} 계산 중</div>` +
        `<div class="d-count">결과: [[${C[0][0]}, ${C[0][1]}], [${C[1][0]}, ${C[1][1]}]]</div>` +
        (op === "mul" ? `<div class="tip-line">주의: 행렬 곱은 일반적으로 AB ≠ BA. 순서를 바꾸면 결과가 달라질 수 있다!</div>` : "");
    };
    const sh = buildSlider(controlsEl, {
      label: "결과 성분 위치 (1,1 → 1,2 → 2,1 → 2,2)", min: 0, max: 3, step: 1, value: hi,
      format: (v) => `(${Math.floor(v / 2) + 1},${(v % 2) + 1})`,
    });
    sh.onChange = (v) => { hi = v; render(); };
    buildButtonRow(controlsEl, [
      { label: "곱셈 AB", cls: "on", onClick: (btn) => { op = "mul"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "덧셈 A+B", onClick: (btn) => { op = "add"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "A = [[1, 2], [3, 4]], B = [[2, 0], [1, 3]] 일 때, 행렬 곱 <b>AB의 (1,1) 성분</b>은?",
    choices: ["4", "2", "6", "8"],
    answer: 0,
    hint: "A의 1행 (1, 2) 와 B의 1열 (2, 1) 을 짝지어 곱하고 더한다: 1·2 + 2·1.",
    wrongNotes: [
      null,
      "1·2만 하고 멈췄다. 뒤 항 2·1까지 더해야 한다.",
      "B의 1열이 아니라 2열 (0, 3)을 썼다. 1·0 + 2·3 = 6은 AB의 (1,2) 성분이다.",
      "A의 1행을 B의 대각 성분 (2, 3)과 짝지으면 1·2+2·3=8이 나온다. 짝은 B의 같은 '열'에서 위→아래로.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "AB의 (1,1) 성분을 구한다. A의 1행, B의 1열에 라이트가 켜진다.", run: () => drawMatrixMul(svg, { A: [[1, 2], [3, 4]], B: [[2, 0], [1, 3]], op: "mul", hi: 0 }) },
      { caption: "A의 1행 (1, 2)와 B의 1열 (2, 1)을 순서대로 짝짓는다.", run: () => {} },
      { caption: "곱해서 더한다: 1×2 + 2×1 = 2 + 2 = 4.", run: () => {} },
      { caption: "결론: (1,1) 성분은 4. 모든 성분이 이 '행×열' 한 동작의 반복이다.", run: () => {} },
    ];
  },
};

const CM1_CONCEPTS = [
  cmDaePoly, cmDaeRemainder, cmDaeFactor,
  cmDaeComplex, /* 판별식(conceptDisc)은 여기 순서로 삽입됨 */ cmDaeVieta, cmDaeQuadRel, cmDaeCubic, cmDaeQuadIneq,
  cmDaeCount, cmDaePerm, cmDaeComb,
  cmDaeMatrix,
];
