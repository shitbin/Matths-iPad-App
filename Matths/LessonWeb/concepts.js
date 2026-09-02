/* ============================================================
   맵쓰 개념 모듈 3종 (테스트 개념)
   A. 이차방정식·부등식 — 판별식 ↔ 그래프 교점 개수   (공통수학1)
   B. 함수와 그래프 — 평행이동·대칭이동               (공통수학2)
   C. 도형의 방정식 — 원·직선·자취                    (공통수학2)

   각 개념 = { meta, mountPlayground(), quiz, explainSteps() }
   앱 셸(iPad/PC)은 이 API만 사용한다.
   ============================================================ */

/* ---------- 공용 컨트롤 빌더 ---------- */
function buildSlider(container, { label, min, max, step, value, format }) {
  const wrap = document.createElement("div");
  wrap.className = "ctl";
  const head = document.createElement("div");
  head.className = "ctl-head";
  const lab = document.createElement("span");
  lab.className = "ctl-label";
  lab.innerHTML = label;
  const val = document.createElement("span");
  val.className = "ctl-value";
  head.appendChild(lab);
  head.appendChild(val);
  const input = document.createElement("input");
  input.type = "range";
  input.min = min; input.max = max; input.step = step; input.value = value;
  wrap.appendChild(head);
  wrap.appendChild(input);
  container.appendChild(wrap);
  const fmtFn = format || ((v) => v);
  const api = {
    input,
    get: () => parseFloat(input.value),
    set: (v) => { input.value = v; val.textContent = fmtFn(parseFloat(v)); },
    onChange: null,
  };
  input.addEventListener("input", () => {
    val.textContent = fmtFn(api.get());
    if (api.onChange) api.onChange(api.get());
  });
  val.textContent = fmtFn(value);
  return api;
}

function buildButtonRow(container, buttons) {
  const row = document.createElement("div");
  row.className = "btn-row";
  const apis = buttons.map(({ label, cls, onClick }) => {
    const b = document.createElement("button");
    b.className = "chip-btn " + (cls || "");
    b.innerHTML = label;
    b.addEventListener("click", () => onClick(b));
    row.appendChild(b);
    return b;
  });
  container.appendChild(row);
  return apis;
}

/* ============================================================
   A. 판별식 ↔ 교점 개수
   ============================================================ */
const conceptDisc = {
  id: "disc",
  course: "공통수학1", unit: "방정식과 부등식",
  badge: "공통수학1 · 방정식과 부등식",
  title: "판별식과 그래프의 교점",
  tag: "D = b² − 4ac 의 부호가 교점 개수를 결정한다",
  oneLiner: "이차함수 그래프와 x축이 몇 번 만나는지는 판별식 D의 부호가 전부 알려준다.",
  veilText: "🙈 그래프 가림 — D의 부호만으로 판단해봐. 눈대중 금지.",
  playgroundGuide: "a, b, c를 움직여서 그래프가 x축과 몇 번 만나는지 관찰해봐. D 게이지가 실시간으로 반응한다.",

  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let a = 1, b = -2, c = -3;

    const render = () => {
      const fn = (x) => a * x * x + b * x + c;
      g.curve("curve", fn, { color: VIZ_COLORS.primary, width: 4.5 });
      const D = b * b - 4 * a * c;
      const roots = [];
      if (Math.abs(a) > 1e-9) {
        if (D > 1e-9) {
          roots.push((-b - Math.sqrt(D)) / (2 * a), (-b + Math.sqrt(D)) / (2 * a));
        } else if (Math.abs(D) <= 1e-9) {
          roots.push(-b / (2 * a));
        }
      }
      const layer = g.clearLayer("roots");
      roots.forEach((r) => {
        if (r >= g.xMin && r <= g.xMax) {
          g.point("roots", r, 0, { append: true, color: VIZ_COLORS.secondary, r: 8 });
        }
      });
      void layer;
      const n = roots.length;
      const sign = D > 1e-9 ? "D > 0" : Math.abs(D) <= 1e-9 ? "D = 0" : "D < 0";
      const cls = D > 1e-9 ? "pos" : Math.abs(D) <= 1e-9 ? "zero" : "neg";
      readoutEl.innerHTML =
        `<div class="formula">y = ${sgnTerm(a, "x²", true)}${sgnTerm(b, "x")}${sgnTerm(c, "")}</div>` +
        `<div class="d-badge ${cls}">${sign} &nbsp;(D = ${fmt(b * b - 4 * a * c)})</div>` +
        `<div class="d-count">x축과의 교점 <b>${n}개</b></div>`;
    };

    const sa = buildSlider(controlsEl, { label: "a (이차항)", min: -3, max: 3, step: 0.5, value: a, format: fmt });
    const sb = buildSlider(controlsEl, { label: "b (일차항)", min: -6, max: 6, step: 0.5, value: b, format: fmt });
    const sc = buildSlider(controlsEl, { label: "c (상수항)", min: -6, max: 6, step: 0.5, value: c, format: fmt });
    sa.onChange = (v) => { a = Math.abs(v) < 0.5 ? (v >= 0 ? 0.5 : -0.5) : v; if (a !== v) sa.set(a); render(); };
    sb.onChange = (v) => { b = v; render(); };
    sc.onChange = (v) => { c = v; render(); };
    render();
    return { interact: () => {} };
  },

  quiz: {
    question: "이차함수 <b>y = x² − 4x + 3</b> 의 그래프와 <b>x축의 교점 개수</b>는?",
    choices: ["2개", "1개", "0개"],
    answer: 0,
    hint: "D = b² − 4ac 에 a=1, b=−4, c=3 을 넣어봐. D = 16 − 12 = 4. 부호는?",
    wrongNotes: [
      null,
      "1개는 D = 0일 때야. 지금은 D = 4 > 0 이라 두 점에서 뚫고 지나간다.",
      "0개는 D < 0, 그래프가 x축 위에 떠 있을 때다. D = 4 > 0 이니까 반대 상황.",
    ],
  },

  explainSteps(svg, captionEl) {
    const g = new Graph(svg, { xMin: -2, xMax: 6, yMin: -3, yMax: 9 });
    g.drawBase();
    const fn = (x) => x * x - 4 * x + 3;
    return [
      {
        caption: "문제의 함수 y = x² − 4x + 3 을 그려보자.",
        run: () => { g.curve("c1", fn, { color: VIZ_COLORS.primary, width: 4.5 }); },
      },
      {
        caption: "판별식 D = b² − 4ac = (−4)² − 4·1·3 = 16 − 12 = 4",
        run: () => {
          g.text(0.4, 7.9, "D = (−4)² − 4·1·3", { layerId: "t1", size: 21, fill: VIZ_COLORS.secondary, weight: 700 });
          g.text(0.4, 6.8, "   = 16 − 12 = 4  > 0", { layerId: "t2", size: 21, fill: VIZ_COLORS.primary, weight: 700 });
        },
      },
      {
        caption: "D > 0 이면 서로 다른 두 실근. 인수분해하면 (x−1)(x−3) = 0",
        run: () => {
          g.point("p1", 1, 0, { color: VIZ_COLORS.secondary, r: 9 });
          g.point("p2", 3, 0, { color: VIZ_COLORS.secondary, r: 9 });
          g.text(1, -1.3, "x=1", { layerId: "t3", size: 19, anchor: "middle", fill: VIZ_COLORS.secondary, weight: 700 });
          g.text(3, -1.3, "x=3", { layerId: "t4", size: 19, anchor: "middle", fill: VIZ_COLORS.secondary, weight: 700 });
        },
      },
      {
        caption: "결론: 교점은 2개. D의 부호만 보면 그래프를 안 그려도 안다.",
        run: () => {
          g.text(0.4, 5.6, "교점 2개 ✓", { layerId: "t5", size: 25, fill: "#178a4c", weight: 800 });
        },
      },
    ];
  },
};

/* ============================================================
   B. 평행이동·대칭이동
   ============================================================ */
const conceptTrans = {
  id: "trans",
  course: "공통수학2", unit: "도형의 방정식",
  badge: "공통수학2 · 도형의 방정식",
  title: "그래프의 평행이동·대칭이동",
  tag: "x 방향 +p 이동인데 식에서는 x−p 가 되는 이유를 눈으로",
  oneLiner: "그래프 이동은 꼭짓점(기준점)의 이동이고, 식에서는 x 대신 x−p, y 대신 y−q 를 넣는 것과 같다.",
  veilText: "🙈 그래프 가림 — 이동 방향과 부호 규칙만으로 판단해봐.",
  playgroundGuide: "p, q를 움직여서 y=x² 포물선을 밀어봐. 점선(원본)과 식이 어떻게 변하는지 보라. 대칭 버튼도 눌러봐.",

  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let p = 0, q = 0, flipX = false; // flipX: x축 대칭 (y = -f)

    const render = () => {
      const s = flipX ? -1 : 1;
      // 원본(점선)
      g.curve("orig", (x) => x * x, { color: VIZ_COLORS.axis, width: 2.5, dash: "7 7" });
      // 변환본
      g.curve("moved", (x) => s * ((x - p) * (x - p)) + q, { color: VIZ_COLORS.primary, width: 4.5 });
      // 꼭짓점 & 이동 화살표
      const layer = g.clearLayer("vtx");
      if (p !== 0 || q !== 0) {
        const ar = g.el("line", {
          x1: g.px(0), y1: g.py(0), x2: g.px(p), y2: g.py(q),
          stroke: VIZ_COLORS.lime, "stroke-width": 3.5, "stroke-dasharray": "2 6",
          "stroke-linecap": "round", "marker-end": "url(#arrowhead)",
        });
        layer.appendChild(ar);
      }
      g.point("vtx", p, q, { append: true, color: VIZ_COLORS.point, r: 8 });

      const sStr = flipX ? "−" : "";
      const pStr = p === 0 ? "x²" : p > 0 ? `(x − ${fmt(p)})²` : `(x + ${fmt(-p)})²`;
      const qStr = q === 0 ? "" : q > 0 ? ` + ${fmt(q)}` : ` − ${fmt(-q)}`;
      readoutEl.innerHTML =
        `<div class="formula">y = ${sStr}${pStr}${qStr}</div>` +
        `<div class="d-count">꼭짓점 (0,0) → <b>(${fmt(p)}, ${fmt(q)})</b>${flipX ? " · x축 대칭 상태" : ""}</div>` +
        (p > 0 ? `<div class="tip-line">+${fmt(p)} 이동인데 식은 x−${fmt(p)}. 여기가 최대 함정 구간.</div>` : "");
    };

    // 화살표 마커 정의
    const defs = g.el("defs");
    defs.innerHTML = `<marker id="arrowhead" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="${VIZ_COLORS.lime}"/></marker>`;
    svg.appendChild(defs);

    const sp = buildSlider(controlsEl, { label: "p — x축 방향 이동", min: -5, max: 5, step: 1, value: p, format: fmt });
    const sq = buildSlider(controlsEl, { label: "q — y축 방향 이동", min: -5, max: 5, step: 1, value: q, format: fmt });
    sp.onChange = (v) => { p = v; render(); };
    sq.onChange = (v) => { q = v; render(); };
    buildButtonRow(controlsEl, [
      // x축 대칭: y = f(x) → y = −f(x). 곡선 전체가 뒤집히므로 꼭짓점 (p,q) → (p,−q)
      { label: "x축 대칭 ↕", onClick: (btn) => { flipX = !flipX; q = -q; sq.set(q); btn.classList.toggle("on", flipX); render(); } },
      { label: "y축 대칭 ↔", onClick: () => { p = -p; sp.set(p); render(); } },
      { label: "원위치", onClick: () => { p = 0; q = 0; flipX = false; sp.set(0); sq.set(0); controlsEl.querySelectorAll(".chip-btn.on").forEach((b) => b.classList.remove("on")); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },

  quiz: {
    question: "포물선 <b>y = x²</b> 을 <b>x축 방향으로 +3, y축 방향으로 −2</b> 만큼 평행이동한 그래프의 식은?",
    choices: ["y = (x − 3)² − 2", "y = (x + 3)² − 2", "y = (x − 3)² + 2", "y = (x + 3)² + 2"],
    answer: 0,
    hint: "오른쪽으로 +3 밀면 식에서는 x 대신 (x − 3). 아래로 −2 내리면 끝에 −2. 방금 놀이터에서 봤잖아.",
    wrongNotes: [
      null,
      "부호 함정에 정확히 착지. +3 이동이면 식은 (x − 3)². 반대로 적었다.",
      "x는 맞췄는데 y에서 당했다. 아래로 −2면 식 끝에 −2다.",
      "x, y 둘 다 부호 반대. 이동 방향과 식의 부호는 거꾸로 논다는 게 핵심.",
    ],
  },

  explainSteps(svg, captionEl) {
    const g = new Graph(svg, { xMin: -4, xMax: 8, yMin: -6, yMax: 8 });
    g.drawBase();
    return [
      {
        caption: "원본 y = x². 꼭짓점은 (0, 0)이다.",
        run: () => {
          g.curve("c0", (x) => x * x, { color: VIZ_COLORS.axis, width: 3, dash: "7 7" });
          g.point("v0", 0, 0, { color: VIZ_COLORS.secondary, r: 8 });
        },
      },
      {
        caption: "x축 방향 +3: 꼭짓점이 (3, 0)으로. 식은 x 대신 (x−3)을 넣는다.",
        run: () => {
          g.curve("c1", (x) => (x - 3) * (x - 3), { color: VIZ_COLORS.secondary, width: 3.5, dash: "3 5" });
          g.point("v1", 3, 0, { color: VIZ_COLORS.secondary, r: 8 });
          g.text(3, 0.7, "(3, 0)", { layerId: "t1", size: 18, anchor: "middle", fill: VIZ_COLORS.secondary, weight: 700 });
        },
      },
      {
        caption: "y축 방향 −2: 꼭짓점이 (3, −2)로. 식 끝에 −2를 붙인다.",
        run: () => {
          g.curve("c2", (x) => (x - 3) * (x - 3) - 2, { color: VIZ_COLORS.primary, width: 4.5 });
          g.point("v2", 3, -2, { color: VIZ_COLORS.primary, r: 9 });
          g.text(3.35, -2.8, "(3, −2)", { layerId: "t2", size: 18, fill: VIZ_COLORS.primary, weight: 700 });
        },
      },
      {
        caption: "결론: y = (x − 3)² − 2. 이동 방향(+3)과 식의 부호(−3)는 반대로 논다.",
        run: () => {
          g.text(-3.4, 6.8, "y = (x−3)² − 2 ✓", { layerId: "t3", size: 24, fill: "#178a4c", weight: 800 });
        },
      },
    ];
  },
};

/* ============================================================
   C. 원과 직선의 위치 관계 (+ 자취 보너스)
   ============================================================ */
const conceptCircle = {
  id: "circle",
  course: "공통수학2", unit: "도형의 방정식",
  badge: "공통수학2 · 도형의 방정식",
  title: "원과 직선의 위치 관계",
  tag: "중심까지의 거리 d 와 반지름 r 의 크기 싸움",
  oneLiner: "원과 직선이 만나는 횟수는 중심에서 직선까지 거리 d와 반지름 r를 비교하면 끝난다.",
  veilText: "🙈 그래프 가림 — d와 r의 크기 비교만으로 판단해봐.",
  playgroundGuide: "r, m, k를 움직여봐. 중심에서 직선까지의 거리 d(초록 점선)와 r의 크기 비교가 교점 개수를 결정한다.",

  mountPlayground(controlsEl, svg, readoutEl) {
    const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
    g.drawBase();
    let r = 3, m = 1, k = 3;

    const render = () => {
      g.circle("circ", 0, 0, r, { color: VIZ_COLORS.primary, width: 4.5, fill: VIZ_COLORS.softPrimary });
      g.fullLine("ln", m, k, { color: VIZ_COLORS.secondary, width: 3.5 });
      // 중심→직선 수선의 발: foot = (-mk/(1+m²), k/(1+m²))
      const d = Math.abs(k) / Math.sqrt(m * m + 1);
      const fx = -m * k / (1 + m * m);
      const fy = k / (1 + m * m);
      const layer = g.clearLayer("perp");
      layer.appendChild(g.el("line", {
        x1: g.px(0), y1: g.py(0), x2: g.px(fx), y2: g.py(fy),
        stroke: VIZ_COLORS.lime, "stroke-width": 3.5, "stroke-dasharray": "3 6", "stroke-linecap": "round",
      }));
      g.point("perp", 0, 0, { append: true, color: VIZ_COLORS.primary, r: 6 });
      g.point("perp", fx, fy, { append: true, color: VIZ_COLORS.lime, r: 6 });

      // 교점
      const A = 1 + m * m, B = 2 * m * k, C = k * k - r * r;
      const D = B * B - 4 * A * C;
      g.clearLayer("meet");
      let n = 0;
      if (D > 1e-9) {
        n = 2;
        [(-B - Math.sqrt(D)) / (2 * A), (-B + Math.sqrt(D)) / (2 * A)].forEach((x) => {
          g.point("meet", x, m * x + k, { append: true, color: VIZ_COLORS.point, r: 8 });
        });
      } else if (Math.abs(D) <= 1e-9) {
        n = 1;
        const x = -B / (2 * A);
        g.point("meet", x, m * x + k, { append: true, color: VIZ_COLORS.point, r: 8 });
      }

      const rel = d > r + 1e-9 ? "d > r" : Math.abs(d - r) <= 1e-9 ? "d = r" : "d < r";
      const cls = n === 2 ? "pos" : n === 1 ? "zero" : "neg";
      readoutEl.innerHTML =
        `<div class="formula">x² + y² = ${fmt(r * r, 2)} &nbsp;·&nbsp; y = ${sgnTerm(m, "x", true) || "0"}${sgnTerm(k, "")}</div>` +
        `<div class="d-badge ${cls}">${rel} &nbsp;(d = ${fmt(d, 2)}, r = ${fmt(r)})</div>` +
        `<div class="d-count">교점 <b>${n}개</b>${n === 1 ? " · 접한다!" : ""}</div>`;
    };

    const sr = buildSlider(controlsEl, { label: "r — 반지름", min: 1, max: 6, step: 0.5, value: r, format: fmt });
    const sm = buildSlider(controlsEl, { label: "m — 직선 기울기", min: -3, max: 3, step: 0.5, value: m, format: fmt });
    const sk = buildSlider(controlsEl, { label: "k — 직선 y절편", min: -7, max: 7, step: 0.5, value: k, format: fmt });
    sr.onChange = (v) => { r = v; render(); };
    sm.onChange = (v) => { m = v; render(); };
    sk.onChange = (v) => { k = v; render(); };
    render();
    return { interact: () => {} };
  },

  quiz: {
    question: "원 <b>x² + y² = 4</b> 와 직선 <b>y = x + 3</b> 의 교점 개수는?",
    choices: ["2개", "1개", "0개"],
    answer: 2,
    hint: "중심 (0,0)에서 직선 x − y + 3 = 0 까지의 거리 d = 3/√2 ≈ 2.12. 반지름 r = 2. 누가 더 커?",
    wrongNotes: [
      "그래프 느낌으로 찍었지? d ≈ 2.12 > r = 2 라서 직선이 원을 스치지도 못한다.",
      "아깝다. d = r 이어야 접하는데, 2.12 ≠ 2. 미세하게 밖으로 비껴간다.",
      null,
    ],
  },

  explainSteps(svg, captionEl) {
    const g = new Graph(svg, { xMin: -6, xMax: 6, yMin: -6, yMax: 6 });
    g.drawBase();
    return [
      {
        caption: "원 x² + y² = 4 (반지름 r = 2)와 직선 y = x + 3 을 그린다.",
        run: () => {
          g.circle("c", 0, 0, 2, { color: VIZ_COLORS.primary, width: 4.5, fill: VIZ_COLORS.softPrimary });
          g.fullLine("l", 1, 3, { color: VIZ_COLORS.secondary, width: 3.5 });
        },
      },
      {
        caption: "중심 (0,0)에서 직선까지 수선을 내린다. d = |0−0+3| / √(1²+1²) = 3/√2",
        run: () => {
          const fx = -1.5, fy = 1.5;
          const layer = g.clearLayer("perp");
          layer.appendChild(g.el("line", {
            x1: g.px(0), y1: g.py(0), x2: g.px(fx), y2: g.py(fy),
            stroke: VIZ_COLORS.lime, "stroke-width": 4, "stroke-dasharray": "3 6", "stroke-linecap": "round",
          }));
          g.point("perp", fx, fy, { append: true, color: VIZ_COLORS.lime, r: 7 });
          g.text(-3.6, 0.3, "d = 3/√2 ≈ 2.12", { layerId: "t1", size: 19, fill: "#5a7a00", weight: 700 });
        },
      },
      {
        caption: "크기 비교: d ≈ 2.12 vs r = 2 → d > r",
        run: () => {
          g.text(1.2, -4.0, "d ≈ 2.12  >  r = 2", { layerId: "t2", size: 21, fill: VIZ_COLORS.secondary, weight: 700, anchor: "middle" });
        },
      },
      {
        caption: "결론: 직선이 원 밖으로 비껴간다. 교점 0개. 계산 없이 거리 비교로 끝.",
        run: () => {
          g.text(1.2, -5.2, "교점 0개 ✓", { layerId: "t3", size: 24, fill: "#178a4c", weight: 800, anchor: "middle" });
        },
      },
    ];
  },
};

/* ---------- 자취 보너스 애니메이션 (개념 C 놀이터에서 호출) ---------- */
function runLocusBonus(svg, onCaption, onDone) {
  const g = new Graph(svg, { xMin: -8, xMax: 8, yMin: -8, yMax: 8 });
  g.drawBase();
  const A = [-3, -3], B = [3, 3];
  g.point("pa", A[0], A[1], { color: VIZ_COLORS.primary, r: 8 });
  g.point("pb", B[0], B[1], { color: VIZ_COLORS.primary, r: 8 });
  g.text(A[0] - 0.4, A[1] - 1.0, "A", { layerId: "ta", size: 20, fill: VIZ_COLORS.primary, weight: 800 });
  g.text(B[0] + 0.3, B[1] + 0.4, "B", { layerId: "tb", size: 20, fill: VIZ_COLORS.primary, weight: 800 });
  onCaption("두 점 A, B에서 같은 거리에 있는 점 P를 추적해보자. PA = PB.");

  let t = -7, dots = [];
  const trail = g.layer("trail");
  const timer = setInterval(() => {
    // 수직이등분선: y = -x (A,B 대칭) 위의 점
    const px = t, py = -t;
    g.clearLayer("mv");
    const mv = g.layer("mv");
    mv.appendChild(g.el("line", { x1: g.px(A[0]), y1: g.py(A[1]), x2: g.px(px), y2: g.py(py), stroke: VIZ_COLORS.axis, "stroke-width": 2, "stroke-dasharray": "4 5" }));
    mv.appendChild(g.el("line", { x1: g.px(B[0]), y1: g.py(B[1]), x2: g.px(px), y2: g.py(py), stroke: VIZ_COLORS.axis, "stroke-width": 2, "stroke-dasharray": "4 5" }));
    g.point("mv", px, py, { append: true, color: VIZ_COLORS.point, r: 8 });
    trail.appendChild(g.el("circle", { cx: g.px(px), cy: g.py(py), r: 3, fill: VIZ_COLORS.lime }));
    dots.push(1);
    t += 0.35;
    if (t > 7) {
      clearInterval(timer);
      g.clearLayer("mv");
      g.fullLine("locus", -1, 0, { color: VIZ_COLORS.lime, width: 4 });
      onCaption("자취 완성: AB의 수직이등분선. \"조건을 만족하는 점들의 모임\"이 도형이 된다.");
      if (onDone) onDone();
    }
  }, 85);
  return () => clearInterval(timer);
}

/* 전체 CONCEPTS 배열은 concepts-cm2.js 끝에서 교육과정 순서로 조립된다. */
