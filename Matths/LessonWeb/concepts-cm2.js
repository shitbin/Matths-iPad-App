/* ============================================================
   공통수학2 (2022 개정) — 신규 개념 12종
   도형의 방정식 4(원·직선, 평행이동은 concepts.js) · 집합과 명제 4 · 함수와 그래프 4
   ============================================================ */

/* ---------- C-020 두 점 사이의 거리 · 내분점 ---------- */
const cm2Dist = {
  id: "cm2-dist",
  course: "공통수학2", unit: "도형의 방정식",
  badge: "공통수학2 · 도형의 방정식",
  title: "두 점 사이의 거리 · 내분점",
  tag: "거리는 피타고라스, 내분점은 가중 평균",
  oneLiner: "두 점 사이 거리는 가로·세로 차이로 만든 직각삼각형의 빗변이다.",
  veilText: "🙈 좌표평면 가림 — 거리 공식만으로 계산해봐.",
  playgroundGuide: "B점과 내분 비율 t를 움직여봐. 거리 직각삼각형과 내분점이 실시간으로 따라온다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    const A = [-4, -3];
    let bx = 4, by = 3, t = 0.5;
    const render = () => {
      const layer = g.clearLayer("main");
      // 직각삼각형 (dx, dy)
      layer.appendChild(g.el("line", { x1: g.px(A[0]), y1: g.py(A[1]), x2: g.px(bx), y2: g.py(A[1]), stroke: VIZ_COLORS.second, "stroke-width": 2.5, "stroke-dasharray": "5 5" }));
      layer.appendChild(g.el("line", { x1: g.px(bx), y1: g.py(A[1]), x2: g.px(bx), y2: g.py(by), stroke: VIZ_COLORS.second, "stroke-width": 2.5, "stroke-dasharray": "5 5" }));
      layer.appendChild(g.el("line", { x1: g.px(A[0]), y1: g.py(A[1]), x2: g.px(bx), y2: g.py(by), stroke: VIZ_COLORS.primary, "stroke-width": 4, "stroke-linecap": "round" }));
      g.point("main", A[0], A[1], { append: true, color: VIZ_COLORS.secondary, r: 8 });
      g.point("main", bx, by, { append: true, color: VIZ_COLORS.point, r: 8 });
      // 내분점 P = A + t(B-A)  (AP:PB = t : 1-t)
      const px = A[0] + t * (bx - A[0]), py = A[1] + t * (by - A[1]);
      g.point("main", px, py, { append: true, color: VIZ_COLORS.lime, r: 8 });
      const dx = bx - A[0], dy = by - A[1];
      const d = Math.sqrt(dx * dx + dy * dy);
      const m = Math.round(t * 10), n = 10 - m;
      const sq = (v) => (v < 0 ? `(${fmt(v)})` : fmt(v)); // 음수는 괄호로 감싸 −2² 오독 방지
      readoutEl.innerHTML =
        `<div class="formula">AB = √(${sq(dx)}² + ${sq(dy)}²) = ${fmt(d, 2)}</div>` +
        `<div class="d-badge pos">내분점 (${m}:${n}) = (${fmt(px, 1)}, ${fmt(py, 1)})</div>` +
        `<div class="d-count">가로 차 ${fmt(dx)}, 세로 차 ${fmt(dy)} → 빗변이 거리</div>`;
    };
    const sx = buildSlider(controlsEl, { label: "B의 x좌표", min: -6, max: 7, step: 1, value: bx, format: fmt });
    const sy = buildSlider(controlsEl, { label: "B의 y좌표", min: -6, max: 7, step: 1, value: by, format: fmt });
    const st = buildSlider(controlsEl, { label: "내분 비율 t (AP:PB = t:1−t)", min: 0.1, max: 0.9, step: 0.1, value: t, format: (v) => `${Math.round(v * 10)}:${10 - Math.round(v * 10)}` });
    sx.onChange = (v) => { bx = v; render(); };
    sy.onChange = (v) => { by = v; render(); };
    st.onChange = (v) => { t = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "두 점 <b>A(−1, 2)</b>, <b>B(3, −1)</b> 사이의 거리는?",
    choices: ["5", "√7", "7", "25"],
    answer: 0,
    hint: "가로 차 3−(−1)=4, 세로 차 −1−2=−3. √(4²+3²)은?",
    wrongNotes: [
      null,
      "차를 제곱하지 않고 더했나? (4)²+(−3)² = 25, 루트 씌우면 5.",
      "4+3을 했네. 거리 공식은 각각 '제곱해서' 더한 뒤 루트다.",
      "루트를 빼먹었다. 4²+3²=25는 거리의 제곱이고, 거리는 √25=5.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -3, xMax: 5, yMin: -3, yMax: 4 });
    g.drawBase();
    return [
      { caption: "A(−1,2), B(3,−1)을 찍고 잇는다. 이 길이가 궁금하다.", run: () => {
        g.point("a", -1, 2, { color: VIZ_COLORS.secondary, r: 8 });
        g.point("b", 3, -1, { color: VIZ_COLORS.secondary, r: 8 });
        g.line("ab", -1, 2, 3, -1, { color: VIZ_COLORS.primary, width: 4 });
      } },
      { caption: "가로 차 4, 세로 차 3으로 직각삼각형을 만든다.", run: () => {
        g.line("h", -1, 2, 3, 2, { color: VIZ_COLORS.second, width: 2.5, dash: "5 5" });
        g.line("v", 3, 2, 3, -1, { color: VIZ_COLORS.second, width: 2.5, dash: "5 5" });
        g.text(1, 2.35, "4", { layerId: "t1", size: 20, fill: VIZ_COLORS.second, weight: 800, anchor: "middle" });
        g.text(3.2, 0.5, "3", { layerId: "t2", size: 20, fill: VIZ_COLORS.second, weight: 800 });
      } },
      { caption: "피타고라스: AB² = 4² + 3² = 25", run: () => {
        g.text(-2.6, 3.4, "AB² = 16 + 9 = 25", { layerId: "t3", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "결론: AB = 5. 거리 공식은 피타고라스의 다른 이름일 뿐이다.", run: () => {
        g.text(-2.6, 2.6, "AB = 5 ✓", { layerId: "t4", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-021 직선의 방정식 ---------- */
const cm2Line = {
  id: "cm2-line",
  course: "공통수학2", unit: "도형의 방정식",
  badge: "공통수학2 · 도형의 방정식",
  title: "직선의 방정식",
  tag: "기울기 = 오른쪽 1칸당 올라가는 높이",
  oneLiner: "직선은 기울기 m(가로 1칸당 세로 변화)과 한 점만 알면 완전히 결정된다.",
  veilText: "🙈 그래프 가림 — 기울기 공식 (y변화/x변화)만으로 계산해봐.",
  playgroundGuide: "m, b를 움직여봐. 기울기 삼각형(가로 1, 세로 m)이 직선의 정체다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let m = 1.5, b = -1;
    const render = () => {
      g.fullLine("ln", m, b, { color: VIZ_COLORS.primary, width: 4 });
      // 기울기 삼각형 at x=1
      const layer = g.clearLayer("tri");
      const x0 = 1, y0 = m * x0 + b;
      layer.appendChild(g.el("line", { x1: g.px(x0), y1: g.py(y0), x2: g.px(x0 + 1), y2: g.py(y0), stroke: VIZ_COLORS.lime, "stroke-width": 4, "stroke-linecap": "round" }));
      layer.appendChild(g.el("line", { x1: g.px(x0 + 1), y1: g.py(y0), x2: g.px(x0 + 1), y2: g.py(y0 + m), stroke: VIZ_COLORS.lime, "stroke-width": 4, "stroke-linecap": "round" }));
      g.point("tri", 0, b, { append: true, color: VIZ_COLORS.point, r: 8 });
      readoutEl.innerHTML =
        `<div class="formula">y = ${sgnTerm(m, "x", true) || "0"}${sgnTerm(b, "")}</div>` +
        `<div class="d-badge pos">기울기 m = ${fmt(m)} — 가로 1칸에 세로 ${fmt(m)}칸</div>` +
        `<div class="d-count">y절편 b = ${fmt(b)} — x=0에서 직선이 y축을 지나는 높이</div>`;
    };
    const sm = buildSlider(controlsEl, { label: "m — 기울기", min: -3, max: 3, step: 0.5, value: m, format: fmt });
    const sb = buildSlider(controlsEl, { label: "b — y절편", min: -5, max: 5, step: 1, value: b, format: fmt });
    sm.onChange = (v) => { m = v; render(); };
    sb.onChange = (v) => { b = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "두 점 <b>(1, 2)</b>와 <b>(3, 8)</b>을 지나는 직선의 <b>기울기</b>는?",
    choices: ["3", "1/3", "6", "2"],
    answer: 0,
    hint: "기울기 = (y 변화) ÷ (x 변화) = (8−2) / (3−1).",
    wrongNotes: [
      null,
      "분자·분모가 뒤집혔다. 기울기는 y변화/x변화 = 6/2.",
      "y 변화 6만 보고 x 변화 2로 나누는 걸 잊었다.",
      "x 변화 2만 봤다. 세로 변화 6을 가로 변화 2로 나눠야 한다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -1, xMax: 5, yMin: -1, yMax: 10 });
    g.drawBase();
    return [
      { caption: "(1,2)와 (3,8)을 찍는다. 이 둘을 잇는 직선의 기울기를 구하자.", run: () => {
        g.point("a", 1, 2, { color: VIZ_COLORS.secondary, r: 8 });
        g.point("b", 3, 8, { color: VIZ_COLORS.secondary, r: 8 });
      } },
      { caption: "가로로 2칸 갈 때 세로로 6칸 올라간다.", run: () => {
        g.line("h", 1, 2, 3, 2, { color: VIZ_COLORS.lime, width: 4 });
        g.line("v", 3, 2, 3, 8, { color: VIZ_COLORS.lime, width: 4 });
        g.text(2, 1.2, "+2", { layerId: "t1", size: 20, fill: "#5a7a00", weight: 800, anchor: "middle" });
        g.text(3.25, 5, "+6", { layerId: "t2", size: 20, fill: "#5a7a00", weight: 800 });
      } },
      { caption: "기울기 m = 6 ÷ 2 = 3. '1칸당 3칸' 비율이다.", run: () => {
        g.fullLine("ln", 3, -1, { color: VIZ_COLORS.primary, width: 4 });
        g.text(-0.6, 9.0, "m = 6/2 = 3", { layerId: "t3", size: 22, fill: VIZ_COLORS.primary, weight: 800 });
      } },
      { caption: "결론: 기울기 3. 어느 두 점을 잡아도 이 비율은 같다 — 그게 직선이다.", run: () => {
        g.text(-0.6, 7.6, "m = 3 ✓", { layerId: "t4", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-022 두 직선의 평행과 수직 ---------- */
const cm2Perp = {
  id: "cm2-perp",
  course: "공통수학2", unit: "도형의 방정식",
  badge: "공통수학2 · 도형의 방정식",
  title: "두 직선의 평행과 수직",
  tag: "평행: 기울기 같음 · 수직: 기울기 곱 = −1",
  oneLiner: "두 직선은 기울기가 같으면 평행, 기울기의 곱이 −1이면 수직이다.",
  veilText: "🙈 그래프 가림 — 기울기 조건만으로 판단해봐.",
  playgroundGuide: "두 직선의 기울기를 움직여봐. m₁·m₂ = −1이 되는 순간 직각 마크가 켜진다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let m1 = 2, m2 = -0.5, b2 = 2;
    const render = () => {
      g.fullLine("l1", m1, 0, { color: VIZ_COLORS.primary, width: 4 });
      g.fullLine("l2", m2, b2, { color: VIZ_COLORS.secondary, width: 4 });
      const prod = m1 * m2;
      const isPerp = Math.abs(prod + 1) < 1e-9;
      const sameSlope = Math.abs(m1 - m2) < 1e-9;
      const isSame = sameSlope && Math.abs(b2) < 1e-9; // 빨간 직선 절편은 0 고정 → 일치
      const isPara = sameSlope && !isSame;
      // 직각 마크: 교점에
      g.clearLayer("mark");
      if (isPerp) {
        const ix = b2 / (m1 - m2), iy = m1 * ix;
        const layer = g.layer("mark");
        const s = 0.55;
        const d1 = Math.atan(m1), d2 = Math.atan(m2);
        const p1 = [ix + s * Math.cos(d1), iy + s * Math.sin(d1)];
        const p2 = [ix + s * Math.cos(d2), iy + s * Math.sin(d2)];
        const pm = [p1[0] + s * Math.cos(d2), p1[1] + s * Math.sin(d2)];
        layer.appendChild(g.el("path", {
          d: `M ${g.px(p1[0])} ${g.py(p1[1])} L ${g.px(pm[0])} ${g.py(pm[1])} L ${g.px(p2[0])} ${g.py(p2[1])}`,
          stroke: "#5a7a00", "stroke-width": 3.5, fill: "none",
        }));
      }
      readoutEl.innerHTML =
        `<div class="formula">m₁ = ${fmt(m1)} · m₂ = ${fmt(m2)}</div>` +
        `<div class="d-badge ${isPerp ? "pos" : isPara || isSame ? "zero" : "neg"}">m₁ × m₂ = ${fmt(prod, 2)} ${isPerp ? "= −1 → 수직! ⊥" : isSame ? "(기울기·절편 모두 같음 → 일치)" : isPara ? "(기울기 같고 절편 다름 → 평행 ∥)" : ""}</div>` +
        `<div class="d-count">수직이려면 한쪽이 다른 쪽의 음수 역수여야 한다</div>`;
    };
    const s1 = buildSlider(controlsEl, { label: "m₁ — 빨간 직선 기울기", min: -3, max: 3, step: 0.5, value: m1, format: fmt });
    const s2 = buildSlider(controlsEl, { label: "m₂ — 파란 직선 기울기", min: -3, max: 3, step: 0.25, value: m2, format: fmt });
    const s3 = buildSlider(controlsEl, { label: "파란 직선 y절편", min: -4, max: 4, step: 1, value: b2, format: fmt });
    s1.onChange = (v) => { m1 = v; render(); };
    s2.onChange = (v) => { m2 = v; render(); };
    s3.onChange = (v) => { b2 = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "직선 <b>y = 2x + 1</b> 에 <b>수직</b>인 직선의 기울기는?",
    choices: ["−1/2", "1/2", "−2", "2"],
    answer: 0,
    hint: "수직 조건: 2 × m = −1. m을 풀면?",
    wrongNotes: [
      null,
      "역수만 취하고 부호를 안 뒤집었다. 2×(1/2)=1이지 −1이 아니다.",
      "부호만 뒤집고 역수를 안 취했다. 2×(−2)=−4 ≠ −1.",
      "그건 평행 조건이다. 기울기가 같고 y절편이 다르면 만나지 않는다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -4, xMax: 4, yMin: -4, yMax: 4 });
    g.drawBase();
    return [
      { caption: "y = 2x + 1: 가로 1칸에 세로 2칸 올라가는 직선.", run: () => {
        g.fullLine("l1", 2, 1, { color: VIZ_COLORS.primary, width: 4 });
      } },
      { caption: "90° 돌리면 '가로 2칸에 세로 −1칸'이 된다. 비율이 뒤집히고 부호가 바뀐다.", run: () => {
        g.fullLine("l2", -0.5, 1, { color: VIZ_COLORS.secondary, width: 4 });
      } },
      { caption: "그래서 수직 기울기 = −1/2. 검산: 2 × (−1/2) = −1 ✓", run: () => {
        g.text(-3.6, 3.4, "2 × (−1/2) = −1", { layerId: "t1", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "결론: 수직 조건은 기울기 곱 = −1. '음수 역수'로 기억해라.", run: () => {
        g.text(-3.6, 2.6, "m = −1/2 ✓", { layerId: "t2", size: 23, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-023 원의 방정식 ---------- */
const cm2Circle = {
  id: "cm2-circleeq",
  course: "공통수학2", unit: "도형의 방정식",
  badge: "공통수학2 · 도형의 방정식",
  title: "원의 방정식",
  tag: "(x−a)² + (y−b)² = r² — 중심에서 거리 r인 점들의 모임",
  oneLiner: "원의 방정식은 \"중심 (a,b)에서 거리가 r로 같은 점들\"이라는 조건을 식으로 쓴 것이다.",
  veilText: "🙈 그래프 가림 — 중심·반지름 대입만으로 판단해봐.",
  playgroundGuide: "중심 (a,b)와 반지름 r를 움직여봐. 식의 부호가 중심과 반대로 노는 것에 주목.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let a = 2, b = -1, r = 3;
    const render = () => {
      g.circle("c", a, b, r, { color: VIZ_COLORS.primary, width: 4.5, fill: VIZ_COLORS.softPrimary });
      const layer = g.clearLayer("rad");
      const ex = a + r * Math.cos(Math.PI / 4), ey = b + r * Math.sin(Math.PI / 4);
      layer.appendChild(g.el("line", { x1: g.px(a), y1: g.py(b), x2: g.px(ex), y2: g.py(ey), stroke: VIZ_COLORS.lime, "stroke-width": 3.5, "stroke-dasharray": "3 6" }));
      g.point("rad", a, b, { append: true, color: VIZ_COLORS.point, r: 7 });
      readoutEl.innerHTML =
        `<div class="formula">(x ${a >= 0 ? "− " + fmt(a) : "+ " + fmt(-a)})² + (y ${b >= 0 ? "− " + fmt(b) : "+ " + fmt(-b)})² = ${fmt(r * r, 2)}</div>` +
        `<div class="d-badge pos">중심 (${fmt(a)}, ${fmt(b)}) · 반지름 ${fmt(r)}</div>` +
        `<div class="d-count">우변은 r이 아니라 <b>r² = ${fmt(r * r, 2)}</b> — 최다 실수 포인트</div>`;
    };
    const sa = buildSlider(controlsEl, { label: "a — 중심 x", min: -5, max: 5, step: 1, value: a, format: fmt });
    const sb = buildSlider(controlsEl, { label: "b — 중심 y", min: -5, max: 5, step: 1, value: b, format: fmt });
    const sr = buildSlider(controlsEl, { label: "r — 반지름", min: 1, max: 5, step: 0.5, value: r, format: fmt });
    sa.onChange = (v) => { a = v; render(); };
    sb.onChange = (v) => { b = v; render(); };
    sr.onChange = (v) => { r = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "중심이 <b>(2, −1)</b> 이고 반지름이 <b>3</b> 인 원의 방정식은?",
    choices: [
      "(x−2)² + (y+1)² = 9",
      "(x+2)² + (y−1)² = 9",
      "(x−2)² + (y+1)² = 3",
      "(x−2)² + (y−1)² = 9",
    ],
    answer: 0,
    hint: "중심 (a,b)면 식은 (x−a)²+(y−b)². b = −1 이면 y−(−1) = y+1. 우변은 r².",
    wrongNotes: [
      null,
      "중심 부호가 통째로 반대. (x−a)²에서 a=2니까 (x−2)². 식과 중심은 부호가 거꾸로 논다.",
      "우변에 r을 그대로 썼다. r=3이면 r²=9.",
      "y 부호 함정. 중심 y가 −1이면 y−(−1) = y+1 이다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -3, xMax: 7, yMin: -6, yMax: 4 });
    g.drawBase();
    return [
      { caption: "원의 정의: 중심 (2,−1)에서 거리가 3으로 같은 점 (x,y)들의 모임.", run: () => {
        g.point("c", 2, -1, { color: VIZ_COLORS.primary, r: 8 });
      } },
      { caption: "거리 공식으로 조건을 쓴다: √((x−2)² + (y+1)²) = 3", run: () => {
        g.circle("circ", 2, -1, 3, { color: VIZ_COLORS.primary, width: 4.5, fill: VIZ_COLORS.softPrimary });
      } },
      { caption: "양변 제곱: (x−2)² + (y+1)² = 9. 루트를 없애느라 우변이 r²이 된다.", run: () => {
        g.text(-2.4, 3.2, "(x−2)²+(y+1)² = 9", { layerId: "t1", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "결론: 원의 방정식은 거리 공식의 제곱형이다. 부호 반대·우변 r² 두 함정만 조심.", run: () => {
        g.text(-2.4, 2.2, "정답 ✓", { layerId: "t2", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-026 집합의 연산 ---------- */
const cm2Set = {
  id: "cm2-set",
  course: "공통수학2", unit: "집합과 명제",
  badge: "공통수학2 · 집합과 명제",
  title: "집합의 연산",
  tag: "∪ ∩ − ᶜ — 벤다이어그램 영역에 불이 들어온다",
  oneLiner: "합집합·교집합·차집합·여집합은 벤다이어그램에서 어느 영역에 불을 켜느냐의 문제다.",
  veilText: "🙈 벤다이어그램 가림 — 원소를 직접 나열해서 판단해봐.",
  playgroundGuide: "연산 버튼을 눌러봐. 불이 켜지는 영역과 원소 목록이 함께 바뀐다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const U = [1, 2, 3, 4, 5, 6, 7, 8];
    const A = [1, 2, 3, 4], B = [3, 4, 5, 6];
    let mode = "union";
    const calc = {
      union: { label: "A ∪ B", els: [...new Set([...A, ...B])].sort() },
      inter: { label: "A ∩ B", els: A.filter((x) => B.includes(x)) },
      diff: { label: "A − B", els: A.filter((x) => !B.includes(x)) },
      compA: { label: "Aᶜ", els: U.filter((x) => !A.includes(x)) },
    };
    const render = () => {
      drawVenn(svg, { A, B, U, mode });
      const c = calc[mode];
      readoutEl.innerHTML =
        `<div class="formula">${c.label} = {${c.els.join(", ")}}</div>` +
        `<div class="d-count">A = {1,2,3,4} · B = {3,4,5,6} · U = {1~8}</div>`;
    };
    buildButtonRow(controlsEl, [
      { label: "A ∪ B 합집합", cls: "on", onClick: (btn) => { mode = "union"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "A ∩ B 교집합", onClick: (btn) => { mode = "inter"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "A − B 차집합", onClick: (btn) => { mode = "diff"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "Aᶜ 여집합", onClick: (btn) => { mode = "compA"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>A = {1, 2, 3, 4}</b>, <b>B = {3, 4, 5}</b> 일 때 <b>A ∩ B</b> 는?",
    choices: ["{3, 4}", "{1, 2, 3, 4, 5}", "{1, 2}", "{5}"],
    answer: 0,
    hint: "∩(교집합)는 '양쪽 모두'에 있는 원소만. 겹치는 걸 찾아라.",
    wrongNotes: [
      null,
      "그건 A ∪ B(합집합)다. ∩는 겹치는 부분만 남긴다.",
      "그건 A − B(차집합)다. A에만 있는 원소를 골랐네.",
      "그건 B − A. 문제는 교집합이다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "A = {1,2,3,4}, B = {3,4,5} 를 벤다이어그램에 배치한다.", run: () => drawVenn(svg, { A: [1, 2, 3, 4], B: [3, 4, 5], U: [1, 2, 3, 4, 5, 6], mode: "none" }) },
      { caption: "∩(교집합)는 두 원이 겹치는 가운데 영역이다.", run: () => drawVenn(svg, { A: [1, 2, 3, 4], B: [3, 4, 5], U: [1, 2, 3, 4, 5, 6], mode: "inter" }) },
      { caption: "겹친 영역에 들어 있는 원소는 3과 4뿐.", run: () => {} },
      { caption: "결론: A ∩ B = {3, 4}. 기호가 헷갈리면 영역으로 그려서 확인해라.", run: () => {} },
    ];
  },
};

/* ---------- C-027 명제와 조건 (역·이·대우) ---------- */
const cm2Prop = {
  id: "cm2-prop",
  course: "공통수학2", unit: "집합과 명제",
  badge: "공통수학2 · 집합과 명제",
  title: "명제의 역·이·대우",
  tag: "대우만이 원래 명제와 운명을 같이한다",
  oneLiner: "명제 p→q에서 역은 화살표 반대, 이는 둘 다 부정, 대우는 반대+부정이며 대우만 참·거짓이 같다.",
  veilText: "🙈 카드 가림 — 변환 규칙만으로 판단해봐.",
  playgroundGuide: "버튼으로 역·이·대우를 오가며 참·거짓이 어떻게 变하는지 봐라. 대우만 원래 명제와 같다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let mode = "orig";
    const render = () => {
      drawPropositions(svg, { mode });
      const info = {
        orig: "원래 명제: x=2 → x²=4 (참)",
        conv: "역: 참이라는 보장이 없다 (반례 x=−2)",
        inv: "이: 역과 대우 관계라 역과 운명이 같다",
        contra: "대우: 원래 명제와 참·거짓이 항상 일치!",
      };
      readoutEl.innerHTML =
        `<div class="d-badge ${mode === "orig" || mode === "contra" ? "pos" : "neg"}">${info[mode]}</div>` +
        `<div class="d-count">증명이 막히면 대우를 증명해도 같은 효과다</div>`;
    };
    buildButtonRow(controlsEl, [
      { label: "원래 명제", cls: "on", onClick: (btn) => { mode = "orig"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "역", onClick: (btn) => { mode = "conv"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "이", onClick: (btn) => { mode = "inv"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "대우", onClick: (btn) => { mode = "contra"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "명제 <b>\"x = 2 이면 x² = 4 이다\"</b> 의 <b>대우</b>는?",
    choices: [
      "x² ≠ 4 이면 x ≠ 2 이다",
      "x² = 4 이면 x = 2 이다",
      "x ≠ 2 이면 x² ≠ 4 이다",
      "x = 2 이면 x² ≠ 4 이다",
    ],
    answer: 0,
    hint: "대우 = 화살표 뒤집기 + 양쪽 부정. ~q → ~p.",
    wrongNotes: [
      null,
      "그건 역(화살표만 반대)이다. 부정까지 해야 대우.",
      "그건 이(부정만 하고 방향 유지)다. 방향도 뒤집어야 대우.",
      "결론만 부정하면 명제 자체가 부서진다. 대우는 규칙이 있다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "원래 명제 p→q: \"x=2 이면 x²=4\" — 참이다.", run: () => drawPropositions(svg, { mode: "orig" }) },
      { caption: "역(q→p): \"x²=4 이면 x=2\" — x=−2라는 반례가 있어 거짓.", run: () => drawPropositions(svg, { mode: "conv" }) },
      { caption: "대우(~q→~p): \"x²≠4 이면 x≠2\" — 화살표 반대 + 양쪽 부정.", run: () => drawPropositions(svg, { mode: "contra" }) },
      { caption: "결론: 대우는 원래 명제와 참·거짓이 항상 같다. 그래서 대우 증명이 통한다.", run: () => {} },
    ];
  },
};

/* ---------- C-028 충분조건과 필요조건 ---------- */
const cm2Cond = {
  id: "cm2-cond",
  course: "공통수학2", unit: "집합과 명제",
  badge: "공통수학2 · 집합과 명제",
  title: "충분조건과 필요조건",
  tag: "작은 집합이 충분, 큰 집합이 필요 — 포함관계로 끝",
  oneLiner: "진리집합이 P⊂Q이면 p는 충분조건, q는 필요조건이다. 작은 쪽이 충분하다.",
  veilText: "🙈 벤다이어그램 가림 — 포함관계만 따져서 판단해봐.",
  playgroundGuide: "포함관계를 바꿔가며 봐라. 안에 들어간(작은) 집합 쪽이 항상 충분조건이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let rel = "PinQ";
    const render = () => {
      if (rel === "PinQ") {
        drawVenn(svg, { subset: true, labels: ["P", "Q"] });
        readoutEl.innerHTML =
          `<div class="formula">P ⊂ Q</div>` +
          `<div class="d-badge pos">p는 q이기 위한 <b>충분</b>조건 · q는 p이기 위한 <b>필요</b>조건</div>` +
          `<div class="d-count">P 안에만 있으면 자동으로 Q 안 → p만 만족하면 '충분'하다</div>`;
      } else {
        drawVenn(svg, { subset: true, labels: ["Q", "P"] });
        readoutEl.innerHTML =
          `<div class="formula">Q ⊂ P</div>` +
          `<div class="d-badge zero">이번엔 반대: q가 충분조건, p가 필요조건</div>` +
          `<div class="d-count">누가 충분인지 헷갈리면 '작은 집합이 충분'만 기억</div>`;
      }
    };
    buildButtonRow(controlsEl, [
      { label: "P ⊂ Q", cls: "on", onClick: (btn) => { rel = "PinQ"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "Q ⊂ P", onClick: (btn) => { rel = "QinP"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>x > 2</b> 는 <b>x > 0</b> 이기 위한 무슨 조건인가?",
    choices: ["충분조건", "필요조건", "필요충분조건", "아무 조건도 아니다"],
    answer: 0,
    hint: "진리집합: {x>2} ⊂ {x>0}. 작은 쪽이 어느 것인가?",
    wrongNotes: [
      null,
      "반대다. x>0이 x>2이기 위한 필요조건. 큰 집합이 필요조건이다.",
      "필요충분은 두 집합이 같을 때(P=Q). x>2와 x>0은 분명 다르다.",
      "x>2이면 반드시 x>0이니 관계가 확실히 있다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "진리집합으로 바꾼다: P = {x | x>2}, Q = {x | x>0}.", run: () => drawVenn(svg, { subset: true, labels: ["P", "Q"] }) },
      { caption: "x>2인 수는 전부 x>0이다 → P ⊂ Q (P가 Q 안에 쏙).", run: () => {} },
      { caption: "P 안에 들어가기만 하면 Q 확정 — p는 q를 보장하는 '충분'조건.", run: () => {} },
      { caption: "결론: 충분조건. 화살표는 작은 집합 → 큰 집합으로만 성립한다.", run: () => {} },
    ];
  },
};

/* ---------- C-029 절대부등식 (산술·기하평균) ---------- */
const cm2AMGM = {
  id: "cm2-amgm",
  course: "공통수학2", unit: "집합과 명제",
  badge: "공통수학2 · 집합과 명제",
  title: "절대부등식 (산술·기하평균)",
  tag: "반지름 ≥ 현의 절반 — AM ≥ GM이 그림 한 장",
  oneLiner: "양수 a,b에 대해 (a+b)/2 ≥ √(ab)이며, 등호는 a=b일 때만 성립한다.",
  veilText: "🙈 반원 가림 — AM≥GM 공식만으로 계산해봐.",
  playgroundGuide: "a, b를 움직여봐. 반지름(산술평균)이 초록 수선(기하평균)보다 항상 길고, a=b일 때 딱 겹친다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let a = 4, b = 1;
    const render = () => {
      drawAMGM(svg, { a, b });
      const am = (a + b) / 2, gm = Math.sqrt(a * b);
      const eq = Math.abs(a - b) < 1e-9;
      readoutEl.innerHTML =
        `<div class="formula">(${fmt(a)}+${fmt(b)})/2 = ${fmt(am, 2)} &nbsp;≥&nbsp; √(${fmt(a)}·${fmt(b)}) = ${fmt(gm, 2)}</div>` +
        `<div class="d-badge ${eq ? "zero" : "pos"}">${eq ? "a = b → 등호 성립!" : "차이 " + fmt(am - gm, 2)}</div>` +
        `<div class="d-count">최솟값 문제에서 "합의 최소 = 곱이 고정일 때 a=b" 로 쓰인다</div>`;
    };
    const sa = buildSlider(controlsEl, { label: "a", min: 1, max: 8, step: 0.5, value: a, format: fmt });
    const sb = buildSlider(controlsEl, { label: "b", min: 1, max: 8, step: 0.5, value: b, format: fmt });
    sa.onChange = (v) => { a = v; render(); };
    sb.onChange = (v) => { b = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>a > 0</b> 일 때 <b>a + 4/a</b> 의 최솟값은?",
    choices: ["4", "2", "8", "2√2"],
    answer: 0,
    hint: "AM-GM: a + 4/a ≥ 2√(a · 4/a) = 2√4. 등호는 a = 4/a, 즉 a=2일 때.",
    wrongNotes: [
      null,
      "2√(ab)에서 √4=2를 곱하는 걸 잊었다. 2×2=4.",
      "2√4 = 2×2 = 4다. √4를 4로 계산했나?",
      "√(a·4/a) = √4 = 2. 근호 안이 4라서 딱 떨어진다. 2√2가 아니다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "AM-GM: 두 양수의 합은 2√(곱) 이상이다.", run: () => drawAMGM(svg, { a: 4, b: 1 }) },
      { caption: "a + 4/a 에 적용: 곱 a × 4/a = 4 로 항상 고정!", run: () => {} },
      { caption: "따라서 a + 4/a ≥ 2√4 = 4.", run: () => drawAMGM(svg, { a: 2, b: 2 }) },
      { caption: "등호는 a = 4/a → a = 2일 때. 결론: 최솟값 4.", run: () => {} },
    ];
  },
};

/* ---------- C-030 함수와 합성함수 ---------- */
const cm2Compose = {
  id: "cm2-compose",
  course: "공통수학2", unit: "함수와 그래프",
  badge: "공통수학2 · 함수와 그래프",
  title: "함수와 합성함수",
  tag: "g∘f 는 f 먼저! — 기계 두 대를 순서대로 통과",
  oneLiner: "합성함수 (g∘f)(x)는 x를 f에 먼저 넣고 그 결과를 g에 넣는 것이며, 일반적으로 순서를 바꾸면 결과가 달라진다.",
  veilText: "🙈 기계 가림 — 안쪽 함수부터 계산해봐.",
  playgroundGuide: "x를 움직이고 순서를 바꿔봐. g∘f와 f∘g의 출력이 다른 게 이 개념의 핵심 함정이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const f = (x) => x + 1, g = (x) => 2 * x;
    let x = 2, order = "gf";
    const render = () => {
      const { mid, out } = drawFuncMachine(svg, { x, f, g, order, fLabel: "f(x) = x + 1", gLabel: "g(x) = 2x" });
      const other = order === "gf" ? g(x) * 1 + 1 : 2 * (x + 1); // 반대 순서 결과
      const otherOut = order === "gf" ? f(g(x)) : g(f(x));
      readoutEl.innerHTML =
        `<div class="formula">${order === "gf" ? "(g∘f)" : "(f∘g)"}(${fmt(x)}) = ${fmt(out)}</div>` +
        `<div class="d-badge ${out !== otherOut ? "neg" : "pos"}">반대 순서 ${order === "gf" ? "(f∘g)" : "(g∘f)"}(${fmt(x)}) = ${fmt(otherOut)} ${out !== otherOut ? "— 다르다!" : ""}</div>` +
        `<div class="d-count">중간값: ${fmt(x)} → ${fmt(mid)} → ${fmt(out)}</div>`;
      void other;
    };
    const sx = buildSlider(controlsEl, { label: "입력 x", min: -3, max: 5, step: 1, value: x, format: fmt });
    sx.onChange = (v) => { x = v; render(); };
    buildButtonRow(controlsEl, [
      { label: "g∘f (f 먼저)", cls: "on", onClick: (btn) => { order = "gf"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "f∘g (g 먼저)", onClick: (btn) => { order = "fg"; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>f(x) = x + 1</b>, <b>g(x) = 2x</b> 일 때 <b>(g∘f)(2)</b> 의 값은?",
    choices: ["6", "5", "3", "4"],
    answer: 0,
    hint: "g∘f는 f 먼저. f(2)=3을 구한 다음 g(3)을 계산해라.",
    wrongNotes: [
      null,
      "f(g(2)) = f(4) = 5를 구했네. 기호 g∘f는 오른쪽(f)이 먼저다.",
      "f(2)=3에서 멈췄다. 그 3을 g에 넣는 것까지가 합성이다.",
      "g(2)=4에서 멈췄거나 순서가 꼬였다. f 먼저, 그다음 g.",
    ],
  },
  explainSteps(svg) {
    const f = (x) => x + 1, g = (x) => 2 * x;
    return [
      { caption: "(g∘f)(2): 기호는 왼쪽부터 읽지만 실행은 오른쪽 f부터다.", run: () => drawFuncMachine(svg, { x: 2, f, g, order: "gf", fLabel: "f(x) = x + 1", gLabel: "g(x) = 2x" }) },
      { caption: "1단계: f(2) = 2 + 1 = 3.", run: () => {} },
      { caption: "2단계: 그 결과 3을 g에 투입 → g(3) = 6.", run: () => {} },
      { caption: "결론: (g∘f)(2) = 6. 참고로 (f∘g)(2) = 5 — 순서가 바뀌면 값도 바뀐다.", run: () => {} },
    ];
  },
};

/* ---------- C-031 역함수 ---------- */
const cm2Inverse = {
  id: "cm2-inverse",
  course: "공통수학2", unit: "함수와 그래프",
  badge: "공통수학2 · 함수와 그래프",
  title: "역함수",
  tag: "입력과 출력을 맞바꾸면 그래프는 y=x 대칭",
  oneLiner: "역함수는 x와 y의 역할을 맞바꾼 함수이고, 그래프는 y=x에 대해 대칭이다.",
  veilText: "🙈 그래프 가림 — x↔y 교환 규칙만으로 계산해봐.",
  playgroundGuide: "점 a를 움직여봐. (a, f(a))와 (f(a), a)가 y=x 거울에 비친 쌍둥이처럼 움직인다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let a = 3;
    const f = (x) => 2 * x - 4;
    const finv = (x) => (x + 4) / 2;
    const render = () => {
      g.fullLine("id", 1, 0, { color: VIZ_COLORS.axis, width: 2, dash: "6 6" });
      g.curve("f", f, { color: VIZ_COLORS.primary, width: 4 });
      g.curve("finv", finv, { color: VIZ_COLORS.second, width: 4 });
      const fa = f(a);
      g.clearLayer("pts");
      const layer = g.layer("pts");
      layer.appendChild(g.el("line", { x1: g.px(a), y1: g.py(fa), x2: g.px(fa), y2: g.py(a), stroke: VIZ_COLORS.lime, "stroke-width": 2.5, "stroke-dasharray": "4 6" }));
      g.point("pts", a, fa, { append: true, color: VIZ_COLORS.primary, r: 8 });
      g.point("pts", fa, a, { append: true, color: VIZ_COLORS.second, r: 8 });
      readoutEl.innerHTML =
        `<div class="formula">f(x) = 2x − 4 &nbsp;·&nbsp; f⁻¹(x) = (x + 4)/2</div>` +
        `<div class="d-badge pos">(${fmt(a)}, ${fmt(fa)}) ↔ (${fmt(fa)}, ${fmt(a)})</div>` +
        `<div class="d-count">y = x 점선이 거울이다</div>`;
    };
    const sa = buildSlider(controlsEl, { label: "a — 입력값", min: -2, max: 6, step: 0.5, value: a, format: fmt });
    sa.onChange = (v) => { a = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>f(x) = 2x − 4</b> 의 역함수는?",
    choices: [
      "f⁻¹(x) = (x + 4)/2",
      "f⁻¹(x) = (x − 4)/2",
      "f⁻¹(x) = 1/(2x − 4)",
      "f⁻¹(x) = −2x + 4",
    ],
    answer: 0,
    hint: "y = 2x−4에서 x와 y를 바꾼다: x = 2y−4. 이제 y에 대해 풀어라.",
    wrongNotes: [
      null,
      "x = 2y − 4 → 2y = x + 4. −4를 넘길 때 +4가 된다. 이항 부호 실수.",
      "그건 역수(1/f)다. 역함수는 분수로 뒤집는 게 아니라 x↔y를 바꾸는 것.",
      "부호를 뒤집는 것도 역함수가 아니다. x와 y의 역할 교환이 전부다.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -6, xMax: 6, yMin: -6, yMax: 6 });
    g.drawBase();
    return [
      { caption: "y = 2x − 4 그래프. 역함수는 입력·출력의 역할 교환이다.", run: () => {
        g.curve("f", (x) => 2 * x - 4, { color: VIZ_COLORS.primary, width: 4 });
      } },
      { caption: "x와 y를 맞바꾼다: x = 2y − 4.", run: () => {
        g.text(-5.4, 5.0, "x = 2y − 4", { layerId: "t1", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "y에 대해 정리: 2y = x + 4 → y = (x+4)/2.", run: () => {
        g.curve("finv", (x) => (x + 4) / 2, { color: VIZ_COLORS.second, width: 4 });
        g.text(-5.4, 3.9, "y = (x+4)/2", { layerId: "t2", size: 21, fill: VIZ_COLORS.second, weight: 700 });
      } },
      { caption: "결론: f⁻¹(x) = (x+4)/2. 두 그래프는 y=x 거울 대칭이다.", run: () => {
        g.fullLine("id", 1, 0, { color: VIZ_COLORS.axis, width: 2, dash: "6 6" });
        g.text(-5.4, 2.8, "✓ y=x 대칭", { layerId: "t3", size: 22, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-032 유리함수 ---------- */
const cm2Rational = {
  id: "cm2-rational",
  course: "공통수학2", unit: "함수와 그래프",
  badge: "공통수학2 · 함수와 그래프",
  title: "유리함수의 그래프",
  tag: "y = k/(x−p) + q — 점근선 (p, q)가 그래프의 뼈대",
  oneLiner: "유리함수 y=k/(x−p)+q는 점근선 x=p, y=q를 뼈대로 한 쌍곡선이다.",
  veilText: "🙈 그래프 가림 — 점근선 위치만으로 판단해봐.",
  playgroundGuide: "k, p, q를 움직여봐. 곡선은 절대 점근선을 넘지 못한다. 점근선이 먼저, 곡선은 나중이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let k = 2, p = 1, q = 3;
    const render = () => {
      const layer = g.clearLayer("asym");
      layer.appendChild(g.el("line", { x1: g.px(p), y1: g.py(g.yMin), x2: g.px(p), y2: g.py(g.yMax), stroke: VIZ_COLORS.lime, "stroke-width": 3, "stroke-dasharray": "7 6" }));
      layer.appendChild(g.el("line", { x1: g.px(g.xMin), y1: g.py(q), x2: g.px(g.xMax), y2: g.py(q), stroke: VIZ_COLORS.lime, "stroke-width": 3, "stroke-dasharray": "7 6" }));
      g.curve("curve", (x) => (Math.abs(x - p) < 0.04 ? NaN : k / (x - p) + q), { color: VIZ_COLORS.primary, width: 4 });
      readoutEl.innerHTML =
        `<div class="formula">y = ${fmt(k)}/(x ${p >= 0 ? "− " + fmt(p) : "+ " + fmt(-p)}) ${q >= 0 ? "+ " + fmt(q) : "− " + fmt(-q)}</div>` +
        `<div class="d-badge pos">점근선: x = ${fmt(p)}, y = ${fmt(q)}</div>` +
        `<div class="d-count">${k > 0 ? "k > 0 → 1·3사분면형" : "k < 0 → 2·4사분면형"} (점근선 기준)</div>`;
    };
    const sk = buildSlider(controlsEl, { label: "k", min: -4, max: 4, step: 1, value: k, format: fmt });
    const sp = buildSlider(controlsEl, { label: "p — 세로 점근선", min: -4, max: 4, step: 1, value: p, format: fmt });
    const sq = buildSlider(controlsEl, { label: "q — 가로 점근선", min: -4, max: 4, step: 1, value: q, format: fmt });
    sk.onChange = (v) => { k = Math.abs(v) < 1 ? (v >= 0 ? 1 : -1) : v; if (k !== v) sk.set(k); render(); };
    sp.onChange = (v) => { p = v; render(); };
    sq.onChange = (v) => { q = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "유리함수 <b>y = 2/(x − 1) + 3</b> 의 <b>점근선</b>은?",
    choices: ["x = 1, y = 3", "x = −1, y = 3", "x = 1, y = 2", "x = 3, y = 1"],
    answer: 0,
    hint: "분모가 0이 되는 x(= 세로 점근선)와, x가 무한히 커질 때 다가가는 y값.",
    wrongNotes: [
      null,
      "분모 x−1=0 → x=+1. 괄호 부호 반대로 읽기, 평행이동과 같은 함정이다.",
      "y 점근선은 뒤에 붙은 +3이다. k=2는 곡선의 휨 정도를 정할 뿐.",
      "x와 y가 뒤바뀌었다. 세로 점근선이 x=1, 가로가 y=3.",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -5, xMax: 7, yMin: -3, yMax: 9 });
    g.drawBase();
    return [
      { caption: "기본형 y = 2/x 를 떠올린다. 점근선은 x=0, y=0.", run: () => {
        g.curve("c0", (x) => (Math.abs(x) < 0.04 ? NaN : 2 / x), { color: VIZ_COLORS.axis, width: 2.5, dash: "6 6" });
      } },
      { caption: "x−1: 오른쪽으로 1 이동 → 세로 점근선도 x=1로 따라간다.", run: () => {
        const layer = g.clearLayer("a1");
        layer.appendChild(g.el("line", { x1: g.px(1), y1: g.py(g.yMin), x2: g.px(1), y2: g.py(g.yMax), stroke: VIZ_COLORS.lime, "stroke-width": 3, "stroke-dasharray": "7 6" }));
      } },
      { caption: "+3: 위로 3 이동 → 가로 점근선도 y=3으로 이동.", run: () => {
        const layer = g.clearLayer("a2");
        layer.appendChild(g.el("line", { x1: g.px(g.xMin), y1: g.py(3), x2: g.px(g.xMax), y2: g.py(3), stroke: VIZ_COLORS.lime, "stroke-width": 3, "stroke-dasharray": "7 6" }));
        g.curve("c1", (x) => (Math.abs(x - 1) < 0.04 ? NaN : 2 / (x - 1) + 3), { color: VIZ_COLORS.primary, width: 4 });
      } },
      { caption: "결론: 점근선 x=1, y=3. 유리함수는 '이동한 반비례 그래프'다.", run: () => {
        g.text(-4.4, 8.2, "x=1, y=3 ✓", { layerId: "t", size: 23, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ---------- C-033 무리함수 ---------- */
const cm2Irrational = {
  id: "cm2-irrational",
  course: "공통수학2", unit: "함수와 그래프",
  badge: "공통수학2 · 함수와 그래프",
  title: "무리함수의 그래프",
  tag: "y = √(x−p) + q — 시작점 (p, q)에서 한쪽으로만 자란다",
  oneLiner: "무리함수 y=√(x−p)+q의 그래프는 시작점 (p,q)에서 출발해 한 방향으로만 뻗는 반쪽 곡선이다.",
  veilText: "🙈 그래프 가림 — 근호 안 ≥ 0 조건만으로 판단해봐.",
  playgroundGuide: "p, q, 부호 a를 바꿔봐. 시작점과 자라는 방향, 그리고 정의역이 한 몸으로 움직인다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let p = 2, q = 1, a = 1;
    const render = () => {
      g.curve("curve", (x) => (x < p ? NaN : a * Math.sqrt(x - p) + q), { color: VIZ_COLORS.primary, width: 4.5 });
      g.point("start", p, q, { color: VIZ_COLORS.secondary, r: 9 });
      readoutEl.innerHTML =
        `<div class="formula">y = ${a === 1 ? "" : "−"}√(x ${p >= 0 ? "− " + fmt(p) : "+ " + fmt(-p)}) ${q >= 0 ? "+ " + fmt(q) : "− " + fmt(-q)}</div>` +
        `<div class="d-badge pos">시작점 (${fmt(p)}, ${fmt(q)}) · 정의역 x ≥ ${fmt(p)}</div>` +
        `<div class="d-count">근호 안 x − ${fmt(p)} ≥ 0 이어야 실수 → 정의역이 잘린다</div>`;
    };
    const sp = buildSlider(controlsEl, { label: "p — 시작점 x", min: -5, max: 5, step: 1, value: p, format: fmt });
    const sq = buildSlider(controlsEl, { label: "q — 시작점 y", min: -5, max: 5, step: 1, value: q, format: fmt });
    sp.onChange = (v) => { p = v; render(); };
    sq.onChange = (v) => { q = v; render(); };
    buildButtonRow(controlsEl, [
      { label: "위로 자람 (+√)", cls: "on", onClick: (btn) => { a = 1; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
      { label: "아래로 자람 (−√)", onClick: (btn) => { a = -1; btn.parentElement.querySelectorAll(".chip-btn").forEach((b) => b.classList.remove("on")); btn.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "무리함수 <b>y = √(x − 2) + 1</b> 의 <b>정의역</b>은?",
    choices: ["x ≥ 2", "x ≥ 1", "x ≥ −2", "모든 실수"],
    answer: 0,
    hint: "근호 안이 음수면 실수가 아니다. x − 2 ≥ 0 을 풀어라.",
    wrongNotes: [
      null,
      "+1은 그래프를 위로 올릴 뿐, 정의역과 무관하다. 근호 '안'만 봐라.",
      "부호 함정. x−2 ≥ 0 → x ≥ +2. 괄호 안 부호는 반대로 논다.",
      "루트 안이 음수가 되는 순간 그래프가 사라진다. x=0을 넣어봐: √(−2)?",
    ],
  },
  explainSteps(svg) {
    const g = new Graph(svg, { xMin: -2, xMax: 9, yMin: -2, yMax: 6 });
    g.drawBase();
    return [
      { caption: "√ 안은 음수가 될 수 없다. x − 2 ≥ 0 이 필수 조건.", run: () => {
        g.text(-1.4, 5.2, "x − 2 ≥ 0", { layerId: "t1", size: 22, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "따라서 x ≥ 2. 그래프는 x=2부터만 존재한다.", run: () => {
        g.curve("c", (x) => (x < 2 ? NaN : Math.sqrt(x - 2) + 1), { color: VIZ_COLORS.primary, width: 4.5 });
        g.point("s", 2, 1, { color: VIZ_COLORS.secondary, r: 9 });
      } },
      { caption: "시작점은 (2, 1). +1은 높이만 정하고 정의역엔 손대지 않는다.", run: () => {
        g.text(2.3, 0.3, "(2, 1) 시작", { layerId: "t2", size: 19, fill: VIZ_COLORS.secondary, weight: 700 });
      } },
      { caption: "결론: 정의역 x ≥ 2. 무리함수는 시작점에서 한쪽으로만 자라는 반쪽 곡선이다.", run: () => {
        g.text(-1.4, 4.2, "x ≥ 2 ✓", { layerId: "t3", size: 24, fill: "#178a4c", weight: 800 });
      } },
    ];
  },
};

/* ============================================================
   전체 개념 배열 조립 (교육과정 순서)
   conceptDisc / conceptCircle / conceptTrans 는 concepts.js 정의
   ============================================================ */
const CONCEPTS = [
  // ── 공통수학1
  cmDaePoly, cmDaeRemainder, cmDaeFactor,                     // 다항식
  cmDaeComplex, conceptDisc, cmDaeVieta, cmDaeQuadRel,        // 방정식과 부등식
  cmDaeCubic, cmDaeQuadIneq,
  cmDaeCount, cmDaePerm, cmDaeComb,                           // 경우의 수
  cmDaeMatrix,                                                // 행렬
  // ── 공통수학2
  cm2Dist, cm2Line, cm2Perp, cm2Circle, conceptCircle, conceptTrans, // 도형의 방정식
  cm2Set, cm2Prop, cm2Cond, cm2AMGM,                          // 집합과 명제
  cm2Compose, cm2Inverse, cm2Rational, cm2Irrational,         // 함수와 그래프
];
