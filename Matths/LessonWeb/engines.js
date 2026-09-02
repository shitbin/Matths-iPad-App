/* ============================================================
   맵쓰 확장 엔진 — 좌표평면(Graph) 밖의 시각화 도구 모음
   벤다이어그램 · 경우의수 트리 · 행렬 · 넓이 모델 · AM-GM 반원 · 함수 기계
   모든 함수는 svg 하나를 받아 자유 좌표(viewBox 0 0 560 560)로 그린다.
   ============================================================ */

/** 자유 캔버스 초기화: viewBox 설정 + 유틸 반환 */
function freeCanvas(svg, w = 560, h = 560) {
  while (svg.firstChild) svg.removeChild(svg.firstChild);
  svg.setAttribute("viewBox", `0 0 ${w} ${h}`);
  const el = (name, attrs = {}) => {
    const n = document.createElementNS("http://www.w3.org/2000/svg", name);
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    svg.appendChild(n);
    return n;
  };
  const txt = (x, y, str, opts = {}) => {
    const t = el("text", {
      x, y,
      fill: opts.fill || "#26221c",
      "font-size": opts.size || 20,
      "font-weight": opts.weight || 700,
      "text-anchor": opts.anchor || "middle",
      "font-family": "'Pretendard','Apple SD Gothic Neo',system-ui,sans-serif",
    });
    t.textContent = str;
    return t;
  };
  return { el, txt, w, h };
}

/* ---------- 벤다이어그램 ----------
   mode: "none"|"union"|"inter"|"diff"|"compA"  /  sub: P⊂Q 포함관계 모드 */
function drawVenn(svg, { A = [], B = [], U = [], mode = "none", labels = ["A", "B"], subset = false } = {}) {
  const { el, txt } = freeCanvas(svg);
  const PRIMARY = "#327ffa", SECOND = "#7b4efc", LIME = "rgba(198,242,46,0.55)";
  // 전체집합 사각형
  el("rect", { x: 30, y: 60, width: 500, height: 420, rx: 18, fill: "#fdfcfa", stroke: "#b9b4a8", "stroke-width": 2.5 });
  txt(58, 96, "U", { anchor: "start", size: 24, fill: "#6f6a60" });

  const cxA = subset ? 260 : 215, cxB = subset ? 300 : 345, cy = 270;
  const rA = subset ? 88 : 128, rB = subset ? 168 : 128;

  // 하이라이트 (clip 활용)
  const defs = el("defs");
  defs.innerHTML = `
    <clipPath id="clipA"><circle cx="${cxA}" cy="${cy}" r="${rA}"/></clipPath>
    <clipPath id="clipB"><circle cx="${cxB}" cy="${cy}" r="${rB}"/></clipPath>
    <clipPath id="clipU"><rect x="30" y="60" width="500" height="420" rx="18"/></clipPath>`;

  if (mode === "union") {
    el("circle", { cx: cxA, cy, r: rA, fill: LIME });
    el("circle", { cx: cxB, cy, r: rB, fill: LIME });
  } else if (mode === "inter") {
    el("circle", { cx: cxA, cy, r: rA, fill: LIME, "clip-path": "url(#clipB)" });
  } else if (mode === "diff") {
    const g = el("g", { "clip-path": "url(#clipA)" });
    const full = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    full.setAttribute("cx", cxA); full.setAttribute("cy", cy); full.setAttribute("r", rA); full.setAttribute("fill", LIME);
    g.appendChild(full);
    const hole = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    hole.setAttribute("cx", cxB); hole.setAttribute("cy", cy); hole.setAttribute("r", rB); hole.setAttribute("fill", "#fdfcfa");
    g.appendChild(hole);
  } else if (mode === "compA") {
    const g = el("g", { "clip-path": "url(#clipU)" });
    const bgR = document.createElementNS("http://www.w3.org/2000/svg", "rect");
    bgR.setAttribute("x", 30); bgR.setAttribute("y", 60); bgR.setAttribute("width", 500); bgR.setAttribute("height", 420); bgR.setAttribute("fill", LIME);
    g.appendChild(bgR);
    const hole = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    hole.setAttribute("cx", cxA); hole.setAttribute("cy", cy); hole.setAttribute("r", rA); hole.setAttribute("fill", "#fdfcfa");
    g.appendChild(hole);
  }

  // 원 두 개
  el("circle", { cx: cxA, cy, r: rA, fill: "rgba(50,127,250,0.07)", stroke: PRIMARY, "stroke-width": 3.5 });
  el("circle", { cx: cxB, cy, r: rB, fill: "rgba(123,78,252,0.06)", stroke: SECOND, "stroke-width": 3.5 });
  txt(subset ? cxA : cxA - rA + 34, subset ? cy - rA - 14 : cy - rA - 12, labels[0], { fill: PRIMARY, size: 25, weight: 900 });
  txt(subset ? cxB + rB - 40 : cxB + rB - 34, cy - rB - 12, labels[1], { fill: SECOND, size: 25, weight: 900 });

  // 원소 배치
  if (!subset && (A.length || B.length)) {
    const onlyA = A.filter((x) => !B.includes(x));
    const onlyB = B.filter((x) => !A.includes(x));
    const both = A.filter((x) => B.includes(x));
    const others = U.filter((x) => !A.includes(x) && !B.includes(x));
    const place = (arr, x0, y0, dx = 0, dy = 34) => arr.forEach((v, i) =>
      txt(x0 + (i % 2) * dx, y0 + Math.floor(i / (dx ? 2 : 1)) * dy, String(v), { size: 22, weight: 800 }));
    place(onlyA, cxA - 52, cy - 20, 0, 40);
    place(both, (cxA + cxB) / 2, cy - 20, 0, 40);
    place(onlyB, cxB + 52, cy - 20, 0, 40);
    others.forEach((v, i) => txt(70 + i * 44, 452, String(v), { size: 20, fill: "#6f6a60" }));
  }
  return { cxA, cxB, cy };
}

/* ---------- 경우의 수: 곱의 법칙 트리 ---------- */
function drawChoiceTree(svg, { m = 3, n = 2, labelA = "상의", labelB = "하의" } = {}) {
  const { el, txt } = freeCanvas(svg);
  const PRIMARY = "#327ffa", SECOND = "#7b4efc";
  const rootX = 60, rootY = 280;
  el("circle", { cx: rootX, cy: rootY, r: 10, fill: "#26221c" });
  txt(rootX, rootY - 24, "시작", { size: 17, fill: "#6f6a60" });
  const spanA = 400 / m;
  for (let i = 0; i < m; i++) {
    const ax = 230, ay = 80 + spanA * i + spanA / 2;
    el("line", { x1: rootX + 10, y1: rootY, x2: ax - 34, y2: ay, stroke: PRIMARY, "stroke-width": 3, "stroke-linecap": "round" });
    el("circle", { cx: ax, cy: ay, r: 26, fill: "rgba(50,127,250,0.1)", stroke: PRIMARY, "stroke-width": 3 });
    txt(ax, ay + 7, labelA + (i + 1), { size: 15, fill: PRIMARY, weight: 800 });
    const spanB = Math.min(spanA, 110) / 1;
    for (let j = 0; j < n; j++) {
      const bx = 440, by = ay - ((n - 1) * spanB) / 2 / n * 2 + (j * spanB) / n * 2;
      el("line", { x1: ax + 26, y1: ay, x2: bx - 30, y2: by, stroke: SECOND, "stroke-width": 2.5, "stroke-linecap": "round" });
      el("circle", { cx: bx, cy: by, r: 22, fill: "rgba(123,78,252,0.08)", stroke: SECOND, "stroke-width": 2.5 });
      txt(bx, by + 6, labelB + (j + 1), { size: 13, fill: SECOND, weight: 800 });
    }
  }
  txt(280, 540, `${labelA} ${m}가지 × ${labelB} ${n}가지 = ${m * n}가지`, { size: 26, weight: 900 });
}

/* ---------- 순열: 자리 채우기 ---------- */
function drawPermSlots(svg, { n = 5, r = 3 } = {}) {
  const { el, txt } = freeCanvas(svg);
  const HILITE = "#ca44e3", PRIMARY = "#327ffa";
  txt(280, 70, `${n}명 중에서 ${r}개의 자리에 줄 세우기`, { size: 23, weight: 900 });
  const slotW = 120, gap = 40;
  const total = r * slotW + (r - 1) * gap;
  const x0 = (560 - total) / 2;
  let acc = 1;
  for (let i = 0; i < r; i++) {
    const x = x0 + i * (slotW + gap);
    el("rect", { x, y: 150, width: slotW, height: 130, rx: 16, fill: "#fff", stroke: PRIMARY, "stroke-width": 3 });
    txt(x + slotW / 2, 138, `${i + 1}번째 자리`, { size: 16, fill: "#6f6a60" });
    txt(x + slotW / 2, 226, String(n - i), { size: 46, weight: 900, fill: HILITE });
    txt(x + slotW / 2, 262, "가지 선택 가능", { size: 13, fill: "#6f6a60" });
    if (i < r - 1) txt(x + slotW + gap / 2, 224, "×", { size: 34, fill: PRIMARY, weight: 900 });
    acc *= (n - i);
  }
  const terms = Array.from({ length: r }, (_, i) => n - i).join(" × ");
  txt(280, 380, `${n}P${r} = ${terms} = ${acc}`, { size: 30, weight: 900, fill: PRIMARY });
  txt(280, 430, "한 자리를 채울 때마다 선택지가 1개씩 줄어든다", { size: 17, fill: "#6f6a60" });
  return acc;
}

/* ---------- 조합: 순열 ÷ r! ---------- */
function drawCombGroups(svg, { n = 4, r = 2 } = {}) {
  const { el, txt } = freeCanvas(svg);
  const PRIMARY = "#327ffa", SECOND = "#7b4efc", GREEN = "#178a4c", HILITE = "#ca44e3";
  const fact = (k) => (k <= 1 ? 1 : k * fact(k - 1));
  const nPr = fact(n) / fact(n - r);
  const nCr = nPr / fact(r);
  txt(280, 66, `${n}명 중 ${r}명 "뽑기만" 하면?`, { size: 23, weight: 900 });
  // 예시 묶음: AB / BA 가 같은 팀
  const names = ["A", "B", "C", "D", "E", "F"].slice(0, n);
  const pair = names.slice(0, r);
  const perms = r === 2 ? [`${pair[0]}${pair[1]}`, `${pair[1]}${pair[0]}`]
    : [`${pair.join("")}`, `${pair[1]}${pair[0]}${pair[2] || ""}`, `${(pair[2] || "")}${pair[0]}${pair[1]}`].slice(0, Math.min(6, fact(r)));
  const bw = 92;
  perms.forEach((p, i) => {
    const x = 120 + i * (bw + 26);
    el("rect", { x, y: 120, width: bw, height: 66, rx: 12, fill: "rgba(50,127,250,0.08)", stroke: PRIMARY, "stroke-width": 2.5 });
    txt(x + bw / 2, 162, p, { size: 26, weight: 900, fill: PRIMARY });
  });
  el("rect", { x: 96, y: 104, width: perms.length * (bw + 26) + 22, height: 100, rx: 16, fill: "none", stroke: GREEN, "stroke-width": 3, "stroke-dasharray": "8 7" });
  txt(280, 244, `순서만 다른 ${fact(r)}개(= ${r}!)는 사실 같은 한 팀`, { size: 19, fill: GREEN, weight: 800 });
  txt(280, 330, `${n}P${r} = ${nPr}  (줄 세우기)`, { size: 26, weight: 900, fill: SECOND });
  txt(280, 386, `÷ ${r}! = ${fact(r)}  (중복 제거)`, { size: 26, weight: 900, fill: HILITE });
  el("line", { x1: 150, y1: 412, x2: 410, y2: 412, stroke: "#26221c", "stroke-width": 3 });
  txt(280, 456, `${n}C${r} = ${nCr}`, { size: 34, weight: 900, fill: GREEN });
  return { nPr, nCr };
}

/* ---------- 행렬 곱 시각화 ---------- */
function drawMatrixMul(svg, { A, B, op = "mul", hi = 0 } = {}) {
  const { el, txt } = freeCanvas(svg);
  const PRIMARY = "#327ffa", SECOND = "#7b4efc", GREEN = "#178a4c";
  const cell = 74, gap = 6;
  const drawM = (M, x0, y0, color, hiRow = -1, hiCol = -1) => {
    el("path", { d: `M${x0 - 12},${y0 - 8} h-10 v${cell * 2 + gap + 16} h10`, stroke: "#26221c", "stroke-width": 3.5, fill: "none" });
    el("path", { d: `M${x0 + cell * 2 + gap + 12},${y0 - 8} h10 v${cell * 2 + gap + 16} h-10`, stroke: "#26221c", "stroke-width": 3.5, fill: "none" });
    for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) {
      const on = i === hiRow || j === hiCol;
      el("rect", {
        x: x0 + j * (cell + gap), y: y0 + i * (cell + gap), width: cell, height: cell, rx: 10,
        fill: on ? "rgba(198,242,46,0.5)" : "#fff", stroke: on ? "#5a7a00" : color, "stroke-width": on ? 3.5 : 2.5,
      });
      txt(x0 + j * (cell + gap) + cell / 2, y0 + i * (cell + gap) + cell / 2 + 9, String(M[i][j]), { size: 27, weight: 900 });
    }
  };
  const row = Math.floor(hi / 2), col = hi % 2;
  const mul = (A, B) => [
    [A[0][0] * B[0][0] + A[0][1] * B[1][0], A[0][0] * B[0][1] + A[0][1] * B[1][1]],
    [A[1][0] * B[0][0] + A[1][1] * B[1][0], A[1][0] * B[0][1] + A[1][1] * B[1][1]],
  ];
  const add = (A, B) => [[A[0][0] + B[0][0], A[0][1] + B[0][1]], [A[1][0] + B[1][0], A[1][1] + B[1][1]]];
  const C = op === "mul" ? mul(A, B) : add(A, B);

  txt(280, 60, op === "mul" ? "행렬의 곱셈: 행 × 열" : "행렬의 덧셈: 같은 자리끼리", { size: 22, weight: 900 });
  if (op === "mul") {
    drawM(A, 60, 120, PRIMARY, row, -1);
    txt(230, 205, "×", { size: 30, weight: 900 });
    drawM(B, 262, 120, SECOND, -1, col);
  } else {
    drawM(A, 60, 120, PRIMARY);
    txt(230, 205, "+", { size: 30, weight: 900 });
    drawM(B, 262, 120, SECOND);
  }
  txt(280, 330, "=", { size: 32, weight: 900 });
  drawM(C, 165, 360, GREEN, op === "mul" ? row : -1, op === "mul" ? col : -1);
  if (op === "mul") {
    const a1 = A[row][0], a2 = A[row][1], b1 = B[0][col], b2 = B[1][col];
    txt(280, 540, `(${row + 1}행,${col + 1}열) = ${a1}·${b1} + ${a2}·${b2} = ${a1 * b1 + a2 * b2}`, { size: 23, weight: 900, fill: GREEN });
  }
  return C;
}

/* ---------- 곱셈공식 넓이 모델: (x+a)(x+b) ---------- */
function drawAreaModel(svg, { a = 2, b = 3, factorMode = false } = {}) {
  const { el, txt } = freeCanvas(svg);
  const PRIMARY = "#327ffa", SECOND = "#7b4efc", GREEN = "#178a4c", LIME = "rgba(198,242,46,0.4)", HILITE = "#ca44e3";
  const xLen = 240, unit = 36;
  const aw = a * unit, bw = b * unit;
  const x0 = (560 - (xLen + aw)) / 2, y0 = 120;
  // 구획: x², bx / ax, ab
  el("rect", { x: x0, y: y0, width: xLen, height: xLen, fill: "rgba(50,127,250,0.1)", stroke: PRIMARY, "stroke-width": 3 });
  el("rect", { x: x0 + xLen, y: y0, width: aw, height: xLen, fill: "rgba(123,78,252,0.1)", stroke: SECOND, "stroke-width": 3 });
  el("rect", { x: x0, y: y0 + xLen, width: xLen, height: bw, fill: "rgba(123,78,252,0.1)", stroke: SECOND, "stroke-width": 3 });
  el("rect", { x: x0 + xLen, y: y0 + xLen, width: aw, height: bw, fill: LIME, stroke: "#5a7a00", "stroke-width": 3 });
  txt(x0 + xLen / 2, y0 + xLen / 2 + 10, "x²", { size: 34, weight: 900, fill: PRIMARY });
  txt(x0 + xLen + aw / 2, y0 + xLen / 2 + 8, `${a}x`, { size: 24, weight: 900, fill: SECOND });
  txt(x0 + xLen / 2, y0 + xLen + bw / 2 + 8, `${b}x`, { size: 24, weight: 900, fill: SECOND });
  txt(x0 + xLen + aw / 2, y0 + xLen + bw / 2 + 8, `${a * b}`, { size: 22, weight: 900, fill: "#5a7a00" });
  // 치수
  txt(x0 + xLen / 2, y0 - 16, "x", { size: 22, fill: "#6f6a60" });
  txt(x0 + xLen + aw / 2, y0 - 16, String(a), { size: 22, fill: "#6f6a60" });
  txt(x0 - 22, y0 + xLen / 2 + 8, "x", { size: 22, fill: "#6f6a60" });
  txt(x0 - 22, y0 + xLen + bw / 2 + 8, String(b), { size: 22, fill: "#6f6a60" });
  const S = a + b, P = a * b;
  txt(280, 64, factorMode
    ? `x² + ${S}x + ${P}  →  합 ${S}, 곱 ${P} 인 두 수는?`
    : `(x + ${a})(x + ${b}) 전체 넓이는?`, { size: 22, weight: 900 });
  txt(280, y0 + xLen + bw + 62, `x² + ${a}x + ${b}x + ${a * b} = x² + ${S}x + ${P}`, { size: 24, weight: 900, fill: GREEN });
  if (factorMode) txt(280, y0 + xLen + bw + 100, `조각을 직사각형으로 재조립 → (x + ${a})(x + ${b})`, { size: 19, weight: 800, fill: HILITE });
}

/* ---------- AM-GM 반원 ---------- */
function drawAMGM(svg, { a = 4, b = 1 } = {}) {
  const { el, txt } = freeCanvas(svg);
  const SECOND = "#7b4efc", PRIMARY = "#327ffa", GREEN = "#178a4c", HILITE = "#ca44e3";
  const scale = 300 / Math.max(a + b, 6);
  const cx = 280, baseY = 330;
  const half = ((a + b) / 2) * scale;
  const R = half;
  const leftX = cx - ((a + b) / 2) * scale;
  const joinX = leftX + a * scale;
  // 반원
  el("path", { d: `M ${cx - R} ${baseY} A ${R} ${R} 0 0 1 ${cx + R} ${baseY}`, fill: "rgba(50,127,250,0.06)", stroke: PRIMARY, "stroke-width": 3.5 });
  el("line", { x1: cx - R, y1: baseY, x2: cx + R, y2: baseY, stroke: "#26221c", "stroke-width": 3 });
  // a, b 구간
  el("line", { x1: leftX, y1: baseY + 18, x2: joinX, y2: baseY + 18, stroke: SECOND, "stroke-width": 5, "stroke-linecap": "round" });
  el("line", { x1: joinX, y1: baseY + 18, x2: cx + R, y2: baseY + 18, stroke: "#f5a623", "stroke-width": 5, "stroke-linecap": "round" });
  txt((leftX + joinX) / 2, baseY + 48, `a = ${a}`, { size: 20, fill: SECOND, weight: 900 });
  txt((joinX + cx + R) / 2, baseY + 48, `b = ${b}`, { size: 20, fill: "#b06c00", weight: 900 });
  // 반지름(AM)
  el("line", { x1: cx, y1: baseY, x2: cx, y2: baseY - R, stroke: PRIMARY, "stroke-width": 4, "stroke-dasharray": "7 6" });
  txt(cx + 6, baseY - R - 12, `반지름 = (a+b)/2 = ${(a + b) / 2}`, { size: 19, fill: PRIMARY, weight: 900, anchor: "start" });
  // 수직 현(GM)
  const gm = Math.sqrt(a * b) * scale;
  el("line", { x1: joinX, y1: baseY, x2: joinX, y2: baseY - gm, stroke: GREEN, "stroke-width": 5, "stroke-linecap": "round" });
  el("circle", { cx: joinX, cy: baseY - gm, r: 7, fill: GREEN });
  txt(joinX, baseY - gm - 16, `√(ab) = ${(Math.sqrt(a * b)).toFixed(2)}`, { size: 19, fill: GREEN, weight: 900 });
  // 비교 바
  const eq = Math.abs(a - b) < 1e-9;
  txt(280, 92, "반지름 ≥ 수선의 길이 √(ab) — 항상!", { size: 21, weight: 900 });
  txt(280, 470, eq ? "a = b 일 때 등호 성립! (a+b)/2 = √(ab)" : `(a+b)/2 = ${((a + b) / 2).toFixed(2)}  ≥  √(ab) = ${Math.sqrt(a * b).toFixed(2)}`,
    { size: 23, weight: 900, fill: eq ? HILITE : GREEN });
}

/* ---------- 함수 기계 (합성함수) ---------- */
function drawFuncMachine(svg, { x = 2, fLabel = "f(x) = x + 1", gLabel = "g(x) = 2x", f, g, order = "gf" } = {}) {
  const { el, txt } = freeCanvas(svg);
  const PRIMARY = "#327ffa", SECOND = "#7b4efc", GREEN = "#178a4c";
  const first = order === "gf" ? { fn: f, label: fLabel, color: PRIMARY } : { fn: g, label: gLabel, color: SECOND };
  const second = order === "gf" ? { fn: g, label: gLabel, color: SECOND } : { fn: f, label: fLabel, color: PRIMARY };
  const mid = first.fn(x);
  const out = second.fn(mid);
  const box = (bx, label, color) => {
    el("rect", { x: bx, y: 210, width: 150, height: 120, rx: 18, fill: "#fff", stroke: color, "stroke-width": 4 });
    el("circle", { cx: bx + 22, cy: 232, r: 5, fill: color });
    txt(bx + 75, 280, label, { size: 19, weight: 900, fill: color });
  };
  txt(280, 80, order === "gf" ? "(g ∘ f)(x) = g( f(x) ) — f 먼저!" : "(f ∘ g)(x) = f( g(x) ) — g 먼저!", { size: 22, weight: 900 });
  // 입력
  el("circle", { cx: 50, cy: 270, r: 34, fill: "rgba(38,34,28,0.06)", stroke: "#26221c", "stroke-width": 3 });
  txt(50, 280, String(x), { size: 28, weight: 900 });
  const arrow = (x1, x2, label) => {
    el("line", { x1, y1: 270, x2: x2 - 12, y2: 270, stroke: "#6f6a60", "stroke-width": 3.5, "marker-end": "url(#amk)" });
    if (label !== undefined) txt((x1 + x2) / 2, 250, String(label), { size: 20, weight: 900, fill: "#5a7a00" });
  };
  const defs = el("defs");
  defs.innerHTML = `<marker id="amk" markerWidth="9" markerHeight="9" refX="7" refY="4.5" orient="auto"><path d="M0,0 L9,4.5 L0,9 z" fill="#6f6a60"/></marker>`;
  arrow(86, 140);
  box(140, first.label, first.color);
  arrow(292, 346, mid);
  box(346, second.label, second.color);
  el("line", { x1: 498, y1: 270, x2: 528, y2: 270, stroke: "#6f6a60", "stroke-width": 3.5 });
  el("circle", { cx: 505, cy: 380, r: 0 });
  el("circle", { cx: 280, cy: 430, r: 40, fill: "rgba(23,138,76,0.1)", stroke: GREEN, "stroke-width": 4 });
  txt(280, 441, String(out), { size: 30, weight: 900, fill: GREEN });
  txt(280, 500, `${x} → ${mid} → ${out}`, { size: 22, weight: 900, fill: "#6f6a60" });
  return { mid, out };
}

/* ---------- 명제 카드 (역·이·대우) ---------- */
function drawPropositions(svg, { mode = "orig" } = {}) {
  const { el, txt } = freeCanvas(svg);
  const ERR = "#e8302a", PRIMARY = "#327ffa", GREEN = "#178a4c";
  const P = "x = 2", Q = "x² = 4";
  const NP = "x ≠ 2", NQ = "x² ≠ 4";
  const items = {
    orig: { title: "원래 명제", form: "p → q", sent: `${P}  이면  ${Q}`, truth: true, why: "2² = 4 ✓" },
    conv: { title: "역 (화살표 반대)", form: "q → p", sent: `${Q}  이면  ${P}`, truth: false, why: "반례: x = −2" },
    inv: { title: "이 (둘 다 부정)", form: "~p → ~q", sent: `${NP}  이면  ${NQ}`, truth: false, why: "반례: x = −2" },
    contra: { title: "대우 (반대 + 부정)", form: "~q → ~p", sent: `${NQ}  이면  ${NP}`, truth: true, why: "원래 명제와 참·거짓 운명공동체" },
  };
  const it = items[mode];
  el("rect", { x: 60, y: 130, width: 440, height: 240, rx: 24, fill: "#fff", stroke: it.truth ? GREEN : ERR, "stroke-width": 4 });
  txt(280, 100, it.title, { size: 24, weight: 900 });
  txt(280, 190, it.form, { size: 30, weight: 900, fill: PRIMARY });
  txt(280, 250, it.sent, { size: 25, weight: 900 });
  txt(280, 320, it.truth ? "참 ✓" : "거짓 ✗", { size: 30, weight: 900, fill: it.truth ? GREEN : ERR });
  txt(280, 420, it.why, { size: 21, weight: 800, fill: "#6f6a60" });
  if (mode === "contra") txt(280, 470, "그래서 증명이 어려우면 대우를 증명해도 된다", { size: 18, fill: PRIMARY, weight: 800 });
}
