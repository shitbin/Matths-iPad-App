/* ============================================================
   맵쓰 확률과 통계 전용 엔진
   PMF 막대 · 이항분포+정규근사 · 정규곡선 · 파스칼 삼각형 ·
   중복조합(○|) · 같은것순열 접기 · 상대도수 시뮬 · 표본평균 분포 ·
   분할표 · 확률 나무
   (freeCanvas 는 engines.js 정의를 재사용)
   ============================================================ */

/* ---------- 수학 유틸 ---------- */
function statFact(n) { let r = 1; for (let i = 2; i <= n; i++) r *= i; return r; }
function statC(n, k) {
  if (k < 0 || k > n) return 0;
  k = Math.min(k, n - k);
  let r = 1;
  for (let i = 0; i < k; i++) r = (r * (n - i)) / (i + 1);
  return Math.round(r);
}
/* 기약분수 문자열 */
function statFrac(num, den) {
  const g = (a, b) => (b ? g(b, a % b) : a);
  const d = g(Math.abs(num), Math.abs(den)) || 1;
  num /= d; den /= d;
  if (den === 1) return String(num);
  return `${num}/${den}`;
}
/* 시맨틱 그래프 팔레트 (RG-18) — 주 대상은 파랑, 강조는 마젠타. brand.css 토큰과 같은 값. */
const STAT_HILITE = "#ca44e3", STAT_PRIMARY = "#327ffa", STAT_GREEN = "#178a4c", STAT_LIME = "#9cc70a", STAT_MUTE = "#8b8578";

/* ---------- 이산확률분포 막대 + 기댓값 무게중심 ---------- */
function drawPMF(svg, { values, probs, title = "", showMean = true, unitFrac = null } = {}) {
  const { el, txt } = freeCanvas(svg);
  if (title) txt(280, 56, title, { size: 21, weight: 900 });
  const maxP = Math.max(...probs, 0.01);
  const baseY = 400, plotH = 250;
  const n = values.length;
  const bw = Math.min(84, 380 / n);
  const gap = Math.min(40, 140 / n);
  const total = n * bw + (n - 1) * gap;
  const x0 = (560 - total) / 2;
  el("line", { x1: x0 - 30, y1: baseY, x2: x0 + total + 30, y2: baseY, stroke: "#26221c", "stroke-width": 2.5 });
  let mean = 0;
  values.forEach((v, i) => { mean += v * probs[i]; });
  values.forEach((v, i) => {
    const h = (probs[i] / maxP) * plotH;
    const x = x0 + i * (bw + gap);
    el("rect", { x, y: baseY - h, width: bw, height: h, rx: 8, fill: "rgba(50,127,250,0.18)", stroke: STAT_PRIMARY, "stroke-width": 3 });
    txt(x + bw / 2, baseY + 28, String(v), { size: 20, weight: 800 });
    txt(x + bw / 2, baseY - h - 12, unitFrac ? statFrac(Math.round(probs[i] * unitFrac), unitFrac) : probs[i].toFixed(2), { size: 16, fill: STAT_PRIMARY, weight: 800 });
  });
  if (showMean && n > 1) {
    // 기댓값 위치 = 값 축 위 선형 보간
    const vMin = values[0], vMax = values[n - 1];
    const mx = x0 + bw / 2 + ((mean - vMin) / (vMax - vMin || 1)) * (total - bw);
    el("path", { d: `M ${mx} ${baseY + 44} l -11 18 h 22 z`, fill: STAT_HILITE });
    txt(mx, baseY + 88, `E(X) = ${Math.round(mean * 100) / 100}`, { size: 20, fill: STAT_HILITE, weight: 900 });
    txt(280, 500, "막대를 널빤지 위 무게로 보면, 기댓값은 무게중심(받침점)이다", { size: 15, fill: STAT_MUTE, weight: 700 });
  }
  return mean;
}

/* ---------- 이항분포 막대 (+ 정규근사 곡선) ---------- */
function drawBinomial(svg, { n = 10, p = 0.5, overlay = false, title = "" } = {}) {
  const { el, txt } = freeCanvas(svg);
  txt(280, 52, title || `B(${n}, ${Math.round(p * 100) / 100})`, { size: 22, weight: 900 });
  const probs = [];
  for (let k = 0; k <= n; k++) probs.push(statC(n, k) * Math.pow(p, k) * Math.pow(1 - p, n - k));
  const maxP = Math.max(...probs);
  const baseY = 420, plotH = 280;
  const x0 = 60, plotW = 440;
  const bw = plotW / (n + 1);
  el("line", { x1: x0 - 14, y1: baseY, x2: x0 + plotW + 14, y2: baseY, stroke: "#26221c", "stroke-width": 2.5 });
  probs.forEach((pr, k) => {
    const h = (pr / maxP) * plotH;
    el("rect", {
      x: x0 + k * bw + bw * 0.12, y: baseY - h, width: bw * 0.76, height: h, rx: Math.min(6, bw * 0.2),
      fill: "rgba(50,127,250,0.18)", stroke: STAT_PRIMARY, "stroke-width": n > 25 ? 1.5 : 2.5,
    });
  });
  const mu = n * p, sig = Math.sqrt(n * p * (1 - p));
  // 눈금: 0, μ, n
  [[0, "0"], [mu, `μ=${Math.round(mu * 10) / 10}`], [n, String(n)]].forEach(([v, lab]) => {
    const x = x0 + v * bw + bw / 2;
    txt(x, baseY + 26, lab, { size: 16, fill: v === mu ? STAT_HILITE : STAT_MUTE, weight: 800 });
  });
  if (overlay) {
    // 정규근사 N(μ, σ²)
    let d = "";
    for (let i = 0; i <= 160; i++) {
      const k = (i / 160) * n;
      const y = Math.exp(-((k - mu) ** 2) / (2 * sig * sig)) * maxP; // 최대높이 맞춤
      const px = x0 + k * bw + bw / 2;
      const py = baseY - (y / maxP) * plotH;
      d += `${i === 0 ? "M" : "L"}${px.toFixed(1)},${py.toFixed(1)} `;
    }
    el("path", { d, fill: "none", stroke: STAT_HILITE, "stroke-width": 4, "stroke-linecap": "round" });
    txt(280, 480, `n이 커질수록 막대 윤곽이 정규곡선 N(np, npq)에 붙는다`, { size: 15.5, fill: STAT_HILITE, weight: 800 });
  }
  txt(280, 512, `평균 np = ${Math.round(mu * 100) / 100} · 분산 npq = ${Math.round(n * p * (1 - p) * 100) / 100}`, { size: 16.5, weight: 800, fill: STAT_PRIMARY });
  return { mu, sig };
}

/* ---------- 정규곡선 + 구간 셰이딩 ---------- */
function drawNormal(svg, { mu = 0, sigma = 1, a = null, b = null, title = "", zAxis = false } = {}) {
  const { el, txt } = freeCanvas(svg);
  if (title) txt(280, 52, title, { size: 21, weight: 900 });
  const x0 = 40, plotW = 480, baseY = 400, plotH = 270;
  const lo = mu - 3.6 * sigma, hi = mu + 3.6 * sigma;
  const X = (v) => x0 + ((v - lo) / (hi - lo)) * plotW;
  const pdf = (v) => Math.exp(-((v - mu) ** 2) / (2 * sigma * sigma));
  // 셰이딩
  if (a !== null && b !== null) {
    let d = `M ${X(a)} ${baseY} `;
    for (let i = 0; i <= 90; i++) {
      const v = a + ((b - a) * i) / 90;
      d += `L ${X(v).toFixed(1)} ${(baseY - pdf(v) * plotH).toFixed(1)} `;
    }
    d += `L ${X(b)} ${baseY} Z`;
    el("path", { d, fill: "rgba(198,242,46,0.55)", stroke: "none" });
  }
  // 곡선
  let d = "";
  for (let i = 0; i <= 180; i++) {
    const v = lo + ((hi - lo) * i) / 180;
    d += `${i === 0 ? "M" : "L"}${X(v).toFixed(1)},${(baseY - pdf(v) * plotH).toFixed(1)} `;
  }
  el("path", { d, fill: "none", stroke: STAT_PRIMARY, "stroke-width": 4.5, "stroke-linecap": "round" });
  el("line", { x1: x0 - 10, y1: baseY, x2: x0 + plotW + 10, y2: baseY, stroke: "#26221c", "stroke-width": 2.5 });
  // 평균선
  el("line", { x1: X(mu), y1: baseY, x2: X(mu), y2: baseY - plotH - 8, stroke: STAT_HILITE, "stroke-width": 2.5, "stroke-dasharray": "6 6" });
  const marks = [[mu - 2 * sigma, zAxis ? "-2" : ""], [mu - sigma, zAxis ? "-1" : `${mu - sigma}`], [mu, zAxis ? "0" : `μ=${mu}`], [mu + sigma, zAxis ? "1" : `${mu + sigma}`], [mu + 2 * sigma, zAxis ? "2" : ""]];
  marks.forEach(([v, lab]) => {
    el("line", { x1: X(v), y1: baseY - 5, x2: X(v), y2: baseY + 5, stroke: STAT_MUTE, "stroke-width": 2 });
    if (lab) txt(X(v), baseY + 28, String(lab), { size: 16, fill: v === mu ? STAT_HILITE : STAT_MUTE, weight: 800 });
  });
  return { X, baseY, plotH, el, txt };
}

/* ---------- 파스칼 삼각형 ---------- */
function drawPascal(svg, { rows = 5, hiRow = -1, hiK = -1 } = {}) {
  const { el, txt } = freeCanvas(svg);
  txt(280, 52, "파스칼의 삼각형 = 이항계수 C(n, k)", { size: 20, weight: 900 });
  const cellW = Math.min(72, 480 / rows), cellH = Math.min(64, 400 / rows);
  const topY = 110;
  for (let r = 0; r <= rows; r++) {
    for (let k = 0; k <= r; k++) {
      const x = 280 + (k - r / 2) * cellW;
      const y = topY + r * cellH;
      const on = r === hiRow && (hiK < 0 || k === hiK);
      const rowOn = r === hiRow && hiK < 0;
      el("circle", { cx: x, cy: y, r: Math.min(26, cellW * 0.42), fill: on || rowOn ? "rgba(198,242,46,0.55)" : "#fff", stroke: on ? "#5a7a00" : STAT_PRIMARY, "stroke-width": on ? 3.5 : 2 });
      txt(x, y + 7, String(statC(r, k)), { size: Math.min(20, cellW * 0.3 + 6), weight: 900, fill: on ? "#3c5200" : "#26221c" });
    }
    txt(280 - (r / 2) * cellW - 52, topY + r * cellH + 6, `n=${r}`, { size: 13, fill: STAT_MUTE, weight: 800 });
  }
  txt(280, topY + (rows + 1) * cellH + 16, "위 두 수의 합 = 아래 수 · n행이 (a+b)ⁿ의 계수들", { size: 15, fill: STAT_MUTE, weight: 700 });
}

/* ---------- 중복조합: ○와 칸막이(|) 모델 ---------- */
function drawStarsBars(svg, { kinds = 3, pick = 4, arrangement = null } = {}) {
  const { el, txt } = freeCanvas(svg);
  txt(280, 52, `${kinds}종류에서 중복 허용해 ${pick}개 고르기`, { size: 21, weight: 900 });
  // 예시 배열: ○○|○|○  (kinds-1개의 칸막이, pick개의 ○)
  const items = arrangement || (() => {
    const arr = [];
    let remain = pick;
    for (let i = 0; i < kinds - 1; i++) {
      const take = i === 0 ? Math.ceil(remain / 2) : Math.floor(remain / 2);
      for (let j = 0; j < take; j++) arr.push("o");
      arr.push("|");
      remain -= take;
    }
    for (let j = 0; j < remain; j++) arr.push("o");
    return arr;
  })();
  const total = pick + kinds - 1;
  const s = Math.min(58, 440 / total);
  const x0 = (560 - total * s) / 2 + s / 2;
  const y = 210;
  items.forEach((it, i) => {
    const x = x0 + i * s;
    if (it === "o") {
      el("circle", { cx: x, cy: y, r: s * 0.34, fill: "rgba(202,68,227,0.15)", stroke: STAT_HILITE, "stroke-width": 3 });
    } else {
      el("line", { x1: x, y1: y - s * 0.42, x2: x, y2: y + s * 0.42, stroke: STAT_PRIMARY, "stroke-width": 5, "stroke-linecap": "round" });
    }
  });
  txt(280, 300, `○ ${pick}개 + 칸막이 ${kinds - 1}개 = 자리 ${total}개`, { size: 19, weight: 800 });
  txt(280, 348, `자리 ${total}개 중 ○ 자리 ${pick}개 고르기`, { size: 19, weight: 800, fill: STAT_PRIMARY });
  const H = statC(total, pick);
  txt(280, 420, `${kinds}H${pick} = C(${total}, ${pick}) = ${H}`, { size: 27, weight: 900, fill: STAT_GREEN });
  txt(280, 470, "순서는 없고 중복은 있다 → 개수 배분 문제 = 칸막이 문제", { size: 15, fill: STAT_MUTE, weight: 700 });
  return H;
}

/* ---------- 같은 것이 있는 순열: 접기 ---------- */
function drawMultisetFold(svg, { word = "수학학" } = {}) {
  const { el, txt } = freeCanvas(svg);
  const chars = word.split("");
  const n = chars.length;
  const counts = {};
  chars.forEach((c) => (counts[c] = (counts[c] || 0) + 1));
  const dupFactor = Object.values(counts).reduce((a, c) => a * statFact(c), 1);
  const totalPerm = statFact(n);
  const answer = totalPerm / dupFactor;
  txt(280, 52, `"${word}" 전부 일렬로 세우기`, { size: 22, weight: 900 });
  // 카드
  const s = 64;
  const x0 = (560 - n * (s + 10)) / 2 + s / 2;
  chars.forEach((c, i) => {
    const x = x0 + i * (s + 10);
    el("rect", { x: x - s / 2, y: 100, width: s, height: s, rx: 12, fill: counts[c] > 1 ? "rgba(202,68,227,0.12)" : "#fff", stroke: counts[c] > 1 ? STAT_HILITE : STAT_PRIMARY, "stroke-width": 3 });
    txt(x, 100 + s / 2 + 9, c, { size: 27, weight: 900, fill: counts[c] > 1 ? STAT_HILITE : "#26221c" });
  });
  txt(280, 230, `일단 전부 다르다고 치면 ${n}! = ${totalPerm}`, { size: 20, weight: 800 });
  const dupList = Object.entries(counts).filter(([, c]) => c > 1).map(([ch, c]) => `${ch}×${c} → ${c}!`).join(" · ");
  txt(280, 285, dupList ? `같은 글자끼리 자리 바꿈은 같은 배열: ${dupList}` : "겹치는 글자 없음", { size: 17, weight: 800, fill: STAT_HILITE });
  txt(280, 360, `${n}! / ${dupFactor} = ${answer}`, { size: 30, weight: 900, fill: STAT_GREEN });
  txt(280, 430, "같은 것끼리의 배열 수만큼 접어서(나눠서) 중복을 없앤다", { size: 15.5, fill: STAT_MUTE, weight: 700 });
  return answer;
}

/* ---------- 상대도수 수렴 시뮬레이션 (seed 기반 결정적) ---------- */
function drawRelFreq(svg, { p = 0.5, trials = 200, seed = 7, label = "앞면" } = {}) {
  const { el, txt } = freeCanvas(svg);
  txt(280, 52, `상대도수는 ${label}의 수학적 확률 ${statFrac(Math.round(p * 12), 12)}로 다가간다`, { size: 18.5, weight: 900 });
  // mulberry32
  let t = seed >>> 0;
  const rand = () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
  const x0 = 62, plotW = 450, y0 = 120, plotH = 300;
  const Y = (v) => y0 + plotH - v * plotH; // v∈[0,1]
  // 축
  el("line", { x1: x0, y1: y0 - 6, x2: x0, y2: y0 + plotH, stroke: STAT_MUTE, "stroke-width": 2 });
  el("line", { x1: x0, y1: y0 + plotH, x2: x0 + plotW + 10, y2: y0 + plotH, stroke: "#26221c", "stroke-width": 2.5 });
  // 이론 확률선
  el("line", { x1: x0, y1: Y(p), x2: x0 + plotW + 10, y2: Y(p), stroke: STAT_HILITE, "stroke-width": 3, "stroke-dasharray": "8 7" });
  txt(x0 + plotW - 12, Y(p) - 12, `p = ${Math.round(p * 1000) / 1000}`, { size: 16, fill: STAT_HILITE, weight: 900 });
  let hit = 0, d = "";
  let last = 0;
  for (let i = 1; i <= trials; i++) {
    if (rand() < p) hit++;
    last = hit / i;
    const px = x0 + (i / trials) * plotW;
    d += `${i === 1 ? "M" : "L"}${px.toFixed(1)},${Y(last).toFixed(1)} `;
  }
  el("path", { d, fill: "none", stroke: STAT_PRIMARY, "stroke-width": 3, "stroke-linecap": "round" });
  txt(280, y0 + plotH + 40, `시행 ${trials}번 · 마지막 상대도수 ${last.toFixed(3)}`, { size: 17, weight: 800, fill: STAT_PRIMARY });
  txt(280, y0 + plotH + 78, "처음엔 요동치지만 시행이 쌓일수록 이론값에 달라붙는다", { size: 15, fill: STAT_MUTE, weight: 700 });
  return last;
}

/* ---------- 표본평균의 분포 (σ/√n) ---------- */
function drawSampling(svg, { mu = 60, sigma = 12, n = 4, seed = 11, samples = 260 } = {}) {
  const { el, txt } = freeCanvas(svg);
  const se = sigma / Math.sqrt(n);
  txt(280, 46, `모집단 N(${mu}, ${sigma}²)에서 크기 ${n}짜리 표본을 계속 뽑는다`, { size: 17.5, weight: 900 });
  let t = seed >>> 0;
  const rand = () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
  const gauss = () => {
    const u = Math.max(rand(), 1e-9), v = rand();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  };
  const lo = mu - 3.2 * sigma, hi = mu + 3.2 * sigma;
  const x0 = 50, plotW = 460, baseY = 410, plotH = 240;
  const X = (v) => x0 + ((v - lo) / (hi - lo)) * plotW;
  // 모집단 곡선 (연함)
  let d = "";
  for (let i = 0; i <= 140; i++) {
    const v = lo + ((hi - lo) * i) / 140;
    d += `${i === 0 ? "M" : "L"}${X(v).toFixed(1)},${(baseY - Math.exp(-((v - mu) ** 2) / (2 * sigma * sigma)) * plotH * 0.5).toFixed(1)} `;
  }
  el("path", { d, fill: "none", stroke: STAT_MUTE, "stroke-width": 2.5, "stroke-dasharray": "6 6" });
  // 표본평균 히스토그램
  const bins = 34;
  const counts = new Array(bins).fill(0);
  for (let s = 0; s < samples; s++) {
    let sum = 0;
    for (let i = 0; i < n; i++) sum += mu + sigma * gauss();
    const xb = sum / n;
    const bi = Math.floor(((xb - lo) / (hi - lo)) * bins);
    if (bi >= 0 && bi < bins) counts[bi]++;
  }
  const maxC = Math.max(...counts, 1);
  const bwPx = plotW / bins;
  counts.forEach((c, i) => {
    if (!c) return;
    const h = (c / maxC) * plotH;
    el("rect", { x: x0 + i * bwPx + 1, y: baseY - h, width: bwPx - 2, height: h, rx: 3, fill: "rgba(50,127,250,0.3)", stroke: STAT_PRIMARY, "stroke-width": 1.5 });
  });
  el("line", { x1: x0 - 8, y1: baseY, x2: x0 + plotW + 8, y2: baseY, stroke: "#26221c", "stroke-width": 2.5 });
  el("line", { x1: X(mu), y1: baseY, x2: X(mu), y2: baseY - plotH - 12, stroke: STAT_HILITE, "stroke-width": 2.5, "stroke-dasharray": "6 6" });
  txt(X(mu), baseY + 26, `μ=${mu}`, { size: 16, fill: STAT_HILITE, weight: 900 });
  txt(280, 470, `점선: 모집단 분포 · 막대: 표본평균 X̄의 분포 (표준편차 σ/√n = ${Math.round(se * 100) / 100})`, { size: 15, weight: 800, fill: STAT_PRIMARY });
  txt(280, 505, "n이 커질수록 표본평균 분포가 μ 주위로 뾰족하게 모인다", { size: 14.5, fill: STAT_MUTE, weight: 700 });
  return se;
}

/* ---------- 분할표 (조건부확률) ---------- */
function drawTwoWayTable(svg, { rowLabels, colLabels, data, hiRow = -1, title = "" } = {}) {
  const { el, txt } = freeCanvas(svg);
  if (title) txt(280, 50, title, { size: 20, weight: 900 });
  const cw = 130, ch = 66;
  const x0 = (560 - cw * (colLabels.length + 1)) / 2;
  const y0 = 110;
  const cell = (r, c, text, opts = {}) => {
    const x = x0 + c * cw, y = y0 + r * ch;
    el("rect", {
      x, y, width: cw, height: ch,
      fill: opts.fill || (r === 0 || c === 0 ? "rgba(38,34,28,0.05)" : "#fff"),
      stroke: opts.stroke || "#c9c4b8", "stroke-width": opts.sw || 1.5,
    });
    txt(x + cw / 2, y + ch / 2 + 7, text, { size: opts.size || 19, weight: r === 0 || c === 0 ? 900 : 800, fill: opts.color || "#26221c" });
  };
  cell(0, 0, "");
  colLabels.forEach((cl, c) => cell(0, c + 1, cl));
  const rowSums = data.map((row) => row.reduce((a, b) => a + b, 0));
  rowLabels.forEach((rl, r) => {
    cell(r + 1, 0, rl);
    data[r].forEach((v, c) => {
      const hi = r === hiRow;
      cell(r + 1, c + 1, String(v), hi ? { fill: "rgba(198,242,46,0.45)", stroke: "#5a7a00", sw: 3, color: "#3c5200" } : {});
    });
  });
  // 합계 열
  rowLabels.forEach((rl, r) => {
    txt(x0 + cw * (colLabels.length + 1) + 40, y0 + (r + 1) * ch + ch / 2 + 6, `계 ${rowSums[r]}`, { size: 16, fill: STAT_MUTE, weight: 800 });
  });
  return { rowSums };
}

/* ---------- 확률 나무 (곱셈정리) ----------
   확률 '값'(p1 등)은 가지 배치용, 라벨은 정확한 분수 문자열을 직접 받는다.
   fracs: { b1: [s,s], b2A: [s,s], b2Ac: [s,s], result: s } */
function drawProbTree(svg, { p1, labels1 = ["A", "Aᶜ"], p2GivenA, p2GivenAc, labels2 = ["B", "Bᶜ"], fracs = null, hiPath = 0 } = {}) {
  const { el, txt } = freeCanvas(svg);
  const dec = (v) => String(Math.round(v * 100) / 100);
  const F = fracs || {
    b1: [dec(p1), dec(1 - p1)],
    b2A: [dec(p2GivenA), dec(1 - p2GivenA)],
    b2Ac: [dec(p2GivenAc), dec(1 - p2GivenAc)],
    result: null,
  };
  txt(280, 46, "가지를 지나며 확률을 곱한다", { size: 20, weight: 900 });
  const rootX = 60, rootY = 280;
  el("circle", { cx: rootX, cy: rootY, r: 9, fill: "#26221c" });
  const l1 = [{ p: p1, y: 160, lab: labels1[0] }, { p: 1 - p1, y: 400, lab: labels1[1] }];
  const branch = (x1, y1, x2, y2, plab, on) => {
    el("line", { x1, y1, x2, y2, stroke: on ? STAT_HILITE : STAT_MUTE, "stroke-width": on ? 4.5 : 2.5, "stroke-linecap": "round" });
    txt((x1 + x2) / 2, (y1 + y2) / 2 - 14, plab, { size: 17, fill: on ? STAT_HILITE : STAT_MUTE, weight: 900 });
  };
  const paths = [];
  l1.forEach((b1, i) => {
    const ax = 240;
    branch(rootX + 9, rootY, ax - 30, b1.y, F.b1[i], hiPath >= 0 && Math.floor(hiPath / 2) === i);
    el("circle", { cx: ax, cy: b1.y, r: 27, fill: "rgba(50,127,250,0.08)", stroke: STAT_PRIMARY, "stroke-width": 3 });
    txt(ax, b1.y + 7, b1.lab, { size: 19, fill: STAT_PRIMARY, weight: 900 });
    const conds = i === 0 ? p2GivenA : p2GivenAc;
    const condFr = i === 0 ? F.b2A : F.b2Ac;
    [{ p: conds, dy: -62, lab: labels2[0] }, { p: 1 - conds, dy: 62, lab: labels2[1] }].forEach((b2, j) => {
      const bx = 440, by = b1.y + b2.dy;
      const on = hiPath === i * 2 + j;
      branch(ax + 27, b1.y, bx - 26, by, condFr[j], on);
      el("circle", { cx: bx, cy: by, r: 23, fill: on ? "rgba(202,68,227,0.12)" : "#fff", stroke: on ? STAT_HILITE : STAT_PRIMARY, "stroke-width": on ? 3.5 : 2.5 });
      txt(bx, by + 6, b2.lab, { size: 16, fill: on ? STAT_HILITE : STAT_PRIMARY, weight: 900 });
      paths.push({ p: b1.p * b2.p, on });
    });
  });
  if (paths[hiPath]) {
    const i = Math.floor(hiPath / 2), j = hiPath % 2;
    const leftF = F.b1[i];
    const rightF = (i === 0 ? F.b2A : F.b2Ac)[j];
    const resF = F.result || dec(paths[hiPath].p);
    txt(280, 540, `강조 경로의 확률 = ${leftF} × ${rightF} = ${resF}`, { size: 19, weight: 900, fill: STAT_HILITE });
  }
  return paths.map((x) => x.p);
}
