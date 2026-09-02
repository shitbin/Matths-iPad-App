/* ============================================================
   유형별 풀이 안무 (solution scenes)

   같은 유형이면 값이 바뀌어도 풀이의 뼈대는 같다 — 그래서 안무를 유형 단위로
   한 번만 짜 두고, 그 회차의 수치를 꽂아 재생한다. 시드가 달라지면 곡선이
   휘는 정도와 눈금 숫자만 달라지고 연출은 같다.

   입력: 생성기가 문항과 함께 내보내는 visualization 파라미터
     { kind: "polynomial", focusX: 2, coefficients: {...} }
   출력: scenario-player.js 가 그대로 먹는 시나리오 {id, beats}

   등록되지 않은 유형은 buildGeneric 이 풀이 단계 텍스트만으로 식 변형 안무를
   만든다 — 어떤 문제도 "재생할 게 없음" 으로 끝나지 않는다.
   ============================================================ */

(function (root) {
  "use strict";

  const TextContract = root.MatthsSolutionTextContract
    || (typeof require === "function" ? require("./solution-text-contract.js") : null);

  /* 잉크색만 셸에서 읽어 온다.
     고정값(#26221C)이면 다크 모드 무대(#141a2e)에서 잉크 도형이 배경에 잠긴다 —
     실제로 넓이 모델의 바깥 사각형 테두리가 거의 안 보였다.
     var(--sol-ink) 를 그대로 흘려보내지 않는 이유: SVG 프레젠테이션 속성
     (stroke="…")에서의 var() 지원이 WebKit 버전에 따라 흔들려, 실패하면 선이
     통째로 사라진다. 그래서 로드 시점에 실제 색으로 한 번 해석해 둔다.
     (스타일 블록이 이 스크립트보다 앞에 있으므로 이 시점에 이미 적용돼 있다) */
  const INK = (() => {
    try {
      const v = getComputedStyle(document.documentElement).getPropertyValue("--sol-ink").trim();
      if (v) return v;
    } catch (e) { /* 셸 밖(노드 테스트)에서는 무시 */ }
    try {
      if (root.matchMedia && root.matchMedia("(prefers-color-scheme: dark)").matches) return "#EEF1FA";
    } catch (e) { /* 무시 */ }
    return "#26221C";
  })();

  /* ---------- 팔레트 (시맨틱 그래프 토큰과 같은 값, RG-18) ----------
     주역은 그래프 주 파랑, 강조·소거는 마젠타 — 빨강은 오류 의미로만 남긴다. */
  const C = {
    main: "#327FFA",   // 주역 (graph-primary)
    hot: "#CA44E3",    // 강조·소거 (graph-highlight)
    ok: "#178A4C",     // 성립·정답 (state-correct)
    mute: "#8B8578",   // 보조
    ink: INK,          // 테마에 따라 위에서 해석된다 (라벨뿐 아니라 SVG 선까지)
  };

  /* ---------- 수치 서식 ---------- */
  const nf = (x) => {
    if (!isFinite(x)) return "";
    const r = Math.round(x * 1000) / 1000;
    return Number.isInteger(r) ? String(r) : String(r);
  };
  /** 부호 붙은 항: 3 → "+3", -3 → "-3" */
  const sg = (x) => (x >= 0 ? "+" + nf(x) : "-" + nf(-x));
  /** 계수 항: 1x → x, -1x → -x, 0x → "" */
  const term = (c, sym) => {
    if (c === 0) return "";
    if (sym === "") return sg(c);
    if (c === 1) return "+" + sym;
    if (c === -1) return "-" + sym;
    return sg(c) + sym;
  };
  /** 맨 앞 항의 + 를 떼고 정리 */
  const head = (s) => s.replace(/^\+/, "").replace(/^$/, "0");

  /* ---------- 무대 기하 ---------- */
  const STAGE = { w: 1920, h: 1080 };
  /** 왼쪽 큰 좌표평면 (오른쪽은 수식·설명 자리) */
  const PLANE_RECT = { x: 220, y: 150, w: 880, h: 780 };

  /**
   * 표준 좌표평면 액션. 범위를 주면 눈금을 알아서 고른다.
   */
  function plane(id, xRange, yRange, opts) {
    opts = opts || {};
    const ticks = (lo, hi) => {
      const span = hi - lo;
      const raw = span / 5;
      const mag = Math.pow(10, Math.floor(Math.log10(raw)));
      const step = [1, 2, 2.5, 5, 10].map((m) => m * mag)
        .find((s) => span / s <= 6.5) || mag * 10;
      const out = [];
      for (let t = Math.ceil(lo / step) * step; t <= hi + 1e-9; t += step) {
        const v = Math.round(t * 1000) / 1000;
        if (Math.abs(v) > 1e-9 || opts.keepZero) out.push(v);
      }
      return out.slice(0, 7);
    };
    return {
      type: "plane", id,
      rect: opts.rect || PLANE_RECT,
      xRange, yRange,
      xTicks: opts.xTicks || ticks(xRange[0], xRange[1]),
      yTicks: opts.yTicks || ticks(yRange[0], yRange[1]),
      showGrid: opts.showGrid !== false,
      xLabel: opts.xLabel || "x",
      yLabel: opts.yLabel || "y",
      drawSec: opts.drawSec || 1.0,
    };
  }

  /** 함수를 점렬로 — 발산 구간은 잘라낸다 */
  function sample(fn, x0, x1, opts) {
    opts = opts || {};
    const n = opts.n || 90;
    const yMin = opts.yMin, yMax = opts.yMax;
    const pts = [];
    for (let i = 0; i <= n; i++) {
      const x = x0 + ((x1 - x0) * i) / n;
      const y = fn(x);
      if (!isFinite(y)) continue;
      if (yMin !== undefined && y < yMin) continue;
      if (yMax !== undefined && y > yMax) continue;
      pts.push([x, Math.round(y * 10000) / 10000]);
    }
    return pts;
  }

  /** 오른쪽 설명 열의 라벨 (화면 좌표) */
  function note(id, line, tex, opts) {
    opts = opts || {};
    return {
      type: "glabel", id,
      at: [opts.x || 1200, 250 + line * 110],
      tex: tex,
      size: opts.size || 40,
      color: opts.color || C.ink,
    };
  }
  function noteText(id, line, text, opts) {
    const a = note(id, line, "", opts);
    delete a.tex;
    a.text = text;
    return a;
  }

  const beat = (dur, subtitle, actions) => ({ dur, subtitle, actions });

  /* ============================================================
     등록부 — kind → (viz, ctx) => scenario
     ctx = { steps, statement, answer, typeName }
     ============================================================ */
  const BUILDERS = {};
  const register = (kind, fn) => { BUILDERS[kind] = fn; };

  /* ---------- 다항함수의 극한: 대입하면 끝난다 ---------- */
  register("polynomial", (v, ctx) => {
    const co = v.coefficients || {};
    const a = co.quadratic || 0, b = co.linear || 0, c = co.constant || 0;
    const f = (x) => a * x * x + b * x + c;
    const x0 = v.focusX || 0;
    const y0 = f(x0);
    const xr = [x0 - 3.2, x0 + 3.2];
    const ys = sample(f, xr[0], xr[1]).map((p) => p[1]);
    const pad = Math.max(1, (Math.max(...ys) - Math.min(...ys)) * 0.15);
    const yr = [Math.min(...ys, 0) - pad, Math.max(...ys, 0) + pad];
    const tex = head(term(a, "x^2") + term(b, "x") + term(c, ""));

    return {
      id: "sol-polynomial",
      beats: [
        beat(6, `다항함수 $f(x)=${tex}$ 의 그래프입니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0], xr[1]), color: C.main, width: 5, drawSec: 1.4 },
          note("n1", 0, `f(x)=${tex}`, { color: C.main }),
        ]),
        beat(7, `$x$ 를 $${nf(x0)}$ 로 보내면 그래프 위의 점도 함께 따라갑니다.`, [
          { type: "mover", id: "m", plane: "pl", points: sample(f, x0 - 2.6, x0), travelSec: 3.0, trail: true, color: C.hot },
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: y0, dashed: true, color: C.mute, label: `$x=${nf(x0)}$` },
        ]),
        beat(7, "다항함수는 끊긴 곳이 없어서 극한값이 곧 함숫값입니다.", [
          { type: "point", id: "P", plane: "pl", at: [x0, y0], r: 11, color: C.hot, label: `$(${nf(x0)},\\ ${nf(y0)})$` },
          note("n2", 1, `\\lim_{x\\to ${nf(x0)}}f(x)=f(${nf(x0)})`, { color: C.ink }),
        ]),
        beat(8, `직접 대입해 계산하면 값이 $${nf(y0)}$ 입니다.`, [
          note("n3", 2, `f(${nf(x0)})=${nf(y0)}`, { color: C.ok, size: 46 }),
          { type: "seg", id: "sy", plane: "pl", from: [x0, y0], to: [0, y0], dashed: true, color: C.ok, width: 3 },
        ]),
      ],
    };
  });

  /* ---------- 유리식의 극한: 구멍 뚫린 직선 ---------- */
  register("hole-linear", (v) => {
    const m = v.slope || 1, k = v.intercept || 0, x0 = v.focusX || 0;
    const g = (x) => m * x + k;
    const y0 = g(x0);
    const xr = [x0 - 3.5, x0 + 3.5];
    const yr = [y0 - Math.abs(m) * 3.5 - 1, y0 + Math.abs(m) * 3.5 + 1];
    const tex = head(term(m, "x") + term(k, ""));

    return {
      id: "sol-hole-linear",
      beats: [
        beat(7, `약분하면 $y=${tex}$ 인 직선입니다. 단 한 점만 빠져 있습니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(g, xr[0], xr[1]), color: C.main, width: 5, drawSec: 1.4 },
          note("n1", 0, `y=${tex}\\quad(x\\ne ${nf(x0)})`, { color: C.main }),
        ]),
        beat(7, `$x=${nf(x0)}$ 에서는 분모가 0 이라 그 점이 뚫려 있습니다.`, [
          { type: "point", id: "hole", plane: "pl", at: [x0, y0], r: 13, color: C.hot, label: "구멍" },
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: y0, dashed: true, color: C.mute },
        ]),
        beat(8, "극한은 그 점에 도달하지 않고 다가가기만 하므로 구멍과 무관합니다.", [
          { type: "mover", id: "ml", plane: "pl", points: sample(g, x0 - 2.4, x0 - 0.05, { n: 40 }), travelSec: 2.4, trail: true, color: C.ok },
          { type: "mover", id: "mr", plane: "pl", points: sample(g, x0 + 2.4, x0 + 0.05, { n: 40 }), travelSec: 2.4, trail: true, color: C.ok },
        ]),
        beat(7, `양쪽에서 같은 높이 $${nf(y0)}$ 로 모입니다.`, [
          note("n2", 1, `\\lim_{x\\to ${nf(x0)}}f(x)=${nf(y0)}`, { color: C.ok, size: 46 }),
          { type: "seg", id: "sy", plane: "pl", from: [x0, y0], to: [xr[0], y0], dashed: true, color: C.ok, width: 3 },
        ]),
      ],
    };
  });

  /* ---------- 좌우 극한이 다른 조각함수 ---------- */
  register("piecewise-linear", (v) => {
    const x0 = v.focusX || 0;
    const L = v.left || { slope: 1, constant: 0 };
    const R = v.right || { slope: 1, constant: 0 };
    const fl = (x) => L.slope * x + L.constant;
    const fr = (x) => R.slope * x + R.constant;
    const yl = fl(x0), yr0 = fr(x0);
    const xr = [x0 - 3.2, x0 + 3.2];
    const all = [yl, yr0, fl(xr[0]), fr(xr[1])];
    const yr = [Math.min(...all) - 1.2, Math.max(...all) + 1.2];
    const same = Math.abs(yl - yr0) < 1e-9;

    return {
      id: "sol-piecewise-linear",
      beats: [
        beat(7, `경계 $x=${nf(x0)}$ 를 사이에 두고 식이 둘로 나뉩니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "fl", plane: "pl", points: sample(fl, xr[0], x0), color: C.main, width: 5, drawSec: 1.2 },
          { type: "plot", id: "fr", plane: "pl", points: sample(fr, x0, xr[1]), color: C.ok, width: 5, drawSec: 1.2 },
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: yr[1], dashed: true, color: C.mute, label: `$x=${nf(x0)}$` },
        ]),
        beat(7, "왼쪽에서 다가가면 왼쪽 식의 값에 닿습니다.", [
          { type: "mover", id: "ml", plane: "pl", points: sample(fl, x0 - 2.6, x0, { n: 40 }), travelSec: 2.6, trail: true, color: C.main },
          note("n1", 0, `\\lim_{x\\to ${nf(x0)}^-}f(x)=${nf(yl)}`, { color: C.main }),
        ]),
        beat(7, "오른쪽에서 다가가면 오른쪽 식의 값에 닿습니다.", [
          { type: "mover", id: "mr", plane: "pl", points: sample(fr, x0 + 2.6, x0, { n: 40 }), travelSec: 2.6, trail: true, color: C.ok },
          note("n2", 1, `\\lim_{x\\to ${nf(x0)}^+}f(x)=${nf(yr0)}`, { color: C.ok }),
        ]),
        beat(8,
          same ? "좌극한과 우극한이 같으므로 극한값이 존재합니다."
               : "좌극한과 우극한이 다르므로 극한값은 존재하지 않습니다.", [
          { type: "point", id: "pl2", plane: "pl", at: [x0, yl], r: 11, color: C.main },
          { type: "point", id: "pr2", plane: "pl", at: [x0, yr0], r: 11, color: C.ok },
          note("n3", 2, same ? `\\lim_{x\\to ${nf(x0)}}f(x)=${nf(yl)}` : `${nf(yl)}\\ne ${nf(yr0)}`,
               { color: same ? C.ok : C.hot, size: 46 }),
        ]),
      ],
    };
  });

  /* ---------- 좌우 극한 값이 직접 주어진 경우 ---------- */
  register("one-sided-limits", (v) => {
    const x0 = v.focusX || 0;
    const l = v.leftLimit ?? 0, r = v.rightLimit ?? 0;
    const same = Math.abs(l - r) < 1e-9;
    const xr = [x0 - 3, x0 + 3];
    const yr = [Math.min(l, r) - 2, Math.max(l, r) + 2];
    const curveL = sample((x) => l + (x - x0) * 0.35, xr[0], x0 - 0.02, { n: 40 });
    const curveR = sample((x) => r + (x - x0) * 0.35, x0 + 0.02, xr[1], { n: 40 });

    return {
      id: "sol-one-sided",
      beats: [
        beat(7, `$x=${nf(x0)}$ 근처만 확대해서 보겠습니다.`, [
          plane("pl", xr, yr),
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: yr[1], dashed: true, color: C.mute, label: `$x=${nf(x0)}$` },
        ]),
        beat(7, `왼쪽 가지는 높이 $${nf(l)}$ 를 향합니다.`, [
          { type: "plot", id: "cl", plane: "pl", points: curveL, color: C.main, width: 5, drawSec: 1.2 },
          { type: "point", id: "pl2", plane: "pl", at: [x0, l], r: 11, color: C.main, label: `$${nf(l)}$` },
          note("n1", 0, `\\lim_{x\\to ${nf(x0)}^-}f(x)=${nf(l)}`, { color: C.main }),
        ]),
        beat(7, `오른쪽 가지는 높이 $${nf(r)}$ 를 향합니다.`, [
          { type: "plot", id: "cr", plane: "pl", points: curveR, color: C.ok, width: 5, drawSec: 1.2 },
          { type: "point", id: "pr2", plane: "pl", at: [x0, r], r: 11, color: C.ok, label: `$${nf(r)}$` },
          note("n2", 1, `\\lim_{x\\to ${nf(x0)}^+}f(x)=${nf(r)}`, { color: C.ok }),
        ]),
        beat(8, same ? "두 값이 같으니 극한값이 존재합니다." : "두 값이 다르니 극한값은 없습니다.", [
          note("n3", 2, same ? `\\lim_{x\\to ${nf(x0)}}f(x)=${nf(l)}` : `\\lim_{x\\to ${nf(x0)}}f(x)\\ \\text{없음}`,
               { color: same ? C.ok : C.hot, size: 44 }),
        ]),
      ],
    };
  });

  /* ---------- 극한의 성질로 결합 ---------- */
  register("limit-law-combination", (v) => {
    const x0 = v.focusX || 0;
    const fl = v.fLimit ?? 0, gl = v.gLimit ?? 0, res = v.resultLimit ?? 0;
    const xr = [x0 - 3, x0 + 3];
    const yr = [Math.min(fl, gl, res, 0) - 2, Math.max(fl, gl, res, 0) + 2];
    return {
      id: "sol-limit-law",
      beats: [
        beat(7, "두 함수가 각각 어느 높이로 향하는지부터 봅니다.", [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample((x) => fl + (x - x0) * 0.4, xr[0], xr[1]), color: C.main, width: 5 },
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: yr[1], dashed: true, color: C.mute },
        ]),
        beat(7, `$f(x)$ 는 $${nf(fl)}$ 로 갑니다.`, [
          { type: "point", id: "pf", plane: "pl", at: [x0, fl], r: 11, color: C.main, label: `$${nf(fl)}$` },
          note("n1", 0, `\\lim f(x)=${nf(fl)}`, { color: C.main }),
        ]),
        beat(7, `$g(x)$ 는 $${nf(gl)}$ 로 갑니다.`, [
          { type: "plot", id: "g", plane: "pl", points: sample((x) => gl - (x - x0) * 0.4, xr[0], xr[1]), color: C.ok, width: 5 },
          { type: "point", id: "pg", plane: "pl", at: [x0, gl], r: 11, color: C.ok, label: `$${nf(gl)}$` },
          note("n2", 1, `\\lim g(x)=${nf(gl)}`, { color: C.ok }),
        ]),
        beat(8, "극한은 각각 구해서 결합해도 됩니다 — 그게 극한의 성질입니다.", [
          note("n3", 2, `\\Rightarrow\\ ${nf(res)}`, { color: C.hot, size: 48 }),
          { type: "point", id: "pr", plane: "pl", at: [x0, res], r: 13, color: C.hot, label: `$${nf(res)}$` },
        ]),
      ],
    };
  });

  /* ---------- 표로 극한 관찰 ---------- */
  register("table-points", (v) => {
    const x0 = v.focusX || 0, t = v.target ?? 0;
    const xs = v.xValues || [], ys = v.yValues || [];
    const pts = xs.map((x, i) => [x, ys[i]]);
    const xr = [Math.min(x0, ...xs) - 0.3, Math.max(x0, ...xs) + 0.3];
    const yr = [Math.min(t, ...ys) - 0.4, Math.max(t, ...ys) + 0.4];
    const dots = (from, to, color) => pts.slice(from, to).map((p, i) => ({
      type: "point", id: `t${from}${i}`, plane: "pl", at: p, r: 10, color, label: `$${nf(p[1])}$`,
    }));
    return {
      id: "sol-table-points",
      beats: [
        beat(6, `$x$ 를 $${nf(x0)}$ 에 가깝게 넣어 보며 $y$ 값을 관찰합니다.`, [
          plane("pl", xr, yr),
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: yr[1], dashed: true, color: C.mute, label: `$x=${nf(x0)}$` },
        ]),
        beat(7, "왼쪽에서 다가갈 때의 값들입니다.", dots(0, Math.ceil(pts.length / 2), C.main)),
        beat(7, "오른쪽에서 다가갈 때의 값들입니다.", dots(Math.ceil(pts.length / 2), pts.length, C.ok)),
        beat(8, `양쪽 모두 $${nf(t)}$ 로 좁혀집니다.`, [
          { type: "seg", id: "sy", plane: "pl", from: [xr[0], t], to: [xr[1], t], dashed: true, color: C.hot, width: 3 },
          note("n1", 0, `\\lim_{x\\to ${nf(x0)}}f(x)=${nf(t)}`, { color: C.hot, size: 46 }),
        ]),
      ],
    };
  });

  /* ---------- 유리함수의 불연속점 ---------- */
  register("rational-continuity", (v) => {
    const pole = v.pole ?? 0;
    const num = v.numeratorConstant ?? 1;
    const f = (x) => num / (x - pole);
    const xr = [pole - 4, pole + 4];
    const yr = [-6, 6];
    return {
      id: "sol-rational-continuity",
      beats: [
        beat(7, `분모가 $0$ 이 되는 곳은 $x=${nf(pole)}$ 하나뿐입니다.`, [
          plane("pl", xr, yr),
          { type: "vline", id: "vx", plane: "pl", x: pole, from: yr[0], to: yr[1], dashed: true, color: C.hot, label: `$x=${nf(pole)}$` },
          note("n1", 0, `x-(${nf(pole)})=0`, { color: C.hot }),
        ]),
        beat(8, "그 점을 기준으로 그래프가 두 조각으로 끊깁니다.", [
          { type: "plot", id: "fl", plane: "pl", points: sample(f, xr[0], pole - 0.12, { n: 70, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.3 },
          { type: "plot", id: "fr", plane: "pl", points: sample(f, pole + 0.12, xr[1], { n: 70, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.3 },
        ]),
        beat(7, "이 점을 포함하지 않는 구간에서는 함수가 이어져 있습니다.", [
          { type: "fill", id: "safe", plane: "pl", points: [[pole + 0.6, yr[0]], [xr[1], yr[0]], [xr[1], yr[1]], [pole + 0.6, yr[1]]], color: C.ok, opacity: 0.16 },
        ]),
        beat(7, v.note || "분모를 0 으로 만드는 값을 피한 구간을 고르면 됩니다.", [
          note("n2", 1, `x\\ne ${nf(pole)}\\ \\Rightarrow\\ \\text{연속}`, { color: C.ok, size: 44 }),
        ]),
      ],
    };
  });

  /* ---------- 닫힌구간에서의 연속 ---------- */
  register("continuous-interval", (v) => {
    const a = v.left ?? -1, b = v.right ?? 1;
    const ya = v.leftValue ?? 0, ym = v.midpointValue ?? 0, yb = v.rightValue ?? 0;
    const mid = v.midpoint ?? (a + b) / 2;
    // 세 점을 지나는 부드러운 곡선 (라그랑주 보간)
    const f = (x) =>
      ya * ((x - mid) * (x - b)) / ((a - mid) * (a - b)) +
      ym * ((x - a) * (x - b)) / ((mid - a) * (mid - b)) +
      yb * ((x - a) * (x - mid)) / ((b - a) * (b - mid));
    const xr = [a - 1, b + 1];
    const ys = sample(f, a, b).map((p) => p[1]);
    const yr = [Math.min(...ys) - 1.5, Math.max(...ys) + 1.5];
    return {
      id: "sol-continuous-interval",
      beats: [
        beat(7, `구간 $[${nf(a)},\\,${nf(b)}]$ 안에서 그래프가 끊기지 않습니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f, a, b), color: C.main, width: 5, drawSec: 1.5 },
        ]),
        beat(7, "왼쪽 끝에서는 오른쪽에서 다가간 값이 함숫값과 같습니다.", [
          { type: "point", id: "pa", plane: "pl", at: [a, ya], r: 12, color: C.ok, label: `$f(${nf(a)})$` },
          note("n1", 0, `\\lim_{x\\to ${nf(a)}^+}f(x)=f(${nf(a)})`, { color: C.ok }),
        ]),
        beat(7, "오른쪽 끝에서는 왼쪽에서 다가간 값이 함숫값과 같습니다.", [
          { type: "point", id: "pb", plane: "pl", at: [b, yb], r: 12, color: C.ok, label: `$f(${nf(b)})$` },
          note("n2", 1, `\\lim_{x\\to ${nf(b)}^-}f(x)=f(${nf(b)})`, { color: C.ok }),
        ]),
        beat(8, v.note || "두 끝점까지 이어지므로 닫힌구간 전체에서 연속입니다.", [
          { type: "fill", id: "band", plane: "pl", points: [[a, yr[0]], [b, yr[0]], [b, yr[1]], [a, yr[1]]], color: C.ok, opacity: 0.12 },
          note("n3", 2, `[${nf(a)},\\,${nf(b)}]\\ \\text{에서 연속}`, { color: C.ok, size: 44 }),
        ]),
      ],
    };
  });

  /* ---------- 무리식 유리화 ---------- */
  register("rationalized-root", (v) => {
    const x0 = v.focusX ?? 0, r = v.root ?? Math.sqrt(Math.max(x0, 0));
    const f = (x) => (Math.sqrt(Math.max(x, 0)) - r) / (x - x0 || 1e-9);
    const lim = 1 / (2 * r || 1);
    const xr = [Math.max(0, x0 - 12), x0 + 12];
    const yr = [lim - 0.12, lim + 0.12];
    return {
      id: "sol-rationalized-root",
      beats: [
        beat(7, "그대로 대입하면 분모와 분자가 모두 $0$ 이 됩니다.", [
          plane("pl", xr, yr),
          note("n1", 0, `\\frac{0}{0}\\ \\text{꼴}`, { color: C.hot }),
        ]),
        beat(8, "분자를 유리화하면 약분할 인수가 드러납니다.", [
          note("n2", 1, `\\frac{\\sqrt{x}-${nf(r)}}{x-${nf(x0)}}\\cdot\\frac{\\sqrt{x}+${nf(r)}}{\\sqrt{x}+${nf(r)}}`, { color: C.main, size: 36 }),
        ]),
        beat(8, `약분하고 나면 $\\dfrac{1}{\\sqrt{x}+${nf(r)}}$ 만 남습니다.`, [
          { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0] + 0.2, xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.4 },
          note("n3", 2, `=\\frac{1}{\\sqrt{x}+${nf(r)}}`, { color: C.main }),
        ]),
        beat(7, `이제 대입할 수 있습니다 — 값은 $${nf(Math.round(lim * 10000) / 10000)}$ 입니다.`, [
          { type: "point", id: "P", plane: "pl", at: [x0, lim], r: 12, color: C.ok, label: `$${nf(Math.round(lim * 10000) / 10000)}$` },
        ]),
      ],
    };
  });

  /* ---------- 극한값과 함숫값이 다른 예 ---------- */
  register("limit-point-example", (v) => {
    const x0 = v.focusX ?? 0, L = v.limitValue ?? 0, P = v.pointValue ?? 0;
    const xr = [x0 - 3, x0 + 3];
    const yr = [Math.min(L, P) - 1.5, Math.max(L, P) + 1.5];
    return {
      id: "sol-limit-point",
      beats: [
        beat(7, `$x=${nf(x0)}$ 를 뺀 곳에서는 그래프가 매끈합니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "fl", plane: "pl", points: sample((x) => L, xr[0], x0 - 0.05, { n: 30 }), color: C.main, width: 5 },
          { type: "plot", id: "fr", plane: "pl", points: sample((x) => L, x0 + 0.05, xr[1], { n: 30 }), color: C.main, width: 5 },
        ]),
        beat(7, `양쪽에서 다가가면 높이 $${nf(L)}$ 로 모입니다 — 이게 극한값입니다.`, [
          { type: "point", id: "hole", plane: "pl", at: [x0, L], r: 12, color: C.mute, label: "극한" },
          note("n1", 0, `\\lim_{x\\to ${nf(x0)}}f(x)=${nf(L)}`, { color: C.main }),
        ]),
        beat(7, `그런데 그 점의 함숫값은 따로 $${nf(P)}$ 로 정해져 있습니다.`, [
          { type: "point", id: "pv", plane: "pl", at: [x0, P], r: 13, color: C.hot, label: `$f(${nf(x0)})=${nf(P)}$` },
          note("n2", 1, `f(${nf(x0)})=${nf(P)}`, { color: C.hot }),
        ]),
        beat(8, "극한값과 함숫값은 다를 수 있습니다 — 극한은 그 점을 보지 않습니다.", [
          note("n3", 2, Math.abs(L - P) < 1e-9 ? `\\text{두 값이 같다}` : `${nf(L)}\\ne ${nf(P)}`,
               { color: C.hot, size: 46 }),
        ]),
      ],
    };
  });

  /* ---------- 역제곱형 발산 ---------- */
  register("inverse-square", (v) => {
    const x0 = v.focusX ?? 0, k = v.coefficient ?? 1;
    const f = (x) => k / ((x - x0) * (x - x0));
    const xr = [x0 - 4, x0 + 4];
    const yr = [-1, 12];
    return {
      id: "sol-inverse-square",
      beats: [
        beat(7, `$x=${nf(x0)}$ 에 가까울수록 분모가 작아집니다.`, [
          plane("pl", xr, yr),
          { type: "vline", id: "vx", plane: "pl", x: x0, from: yr[0], to: yr[1], dashed: true, color: C.hot, label: `$x=${nf(x0)}$` },
        ]),
        beat(8, "작은 수로 나누면 값은 한없이 커집니다.", [
          { type: "plot", id: "fl", plane: "pl", points: sample(f, xr[0], x0 - 0.28, { n: 70, yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.4 },
          { type: "plot", id: "fr", plane: "pl", points: sample(f, x0 + 0.28, xr[1], { n: 70, yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.4 },
        ]),
        beat(7, "제곱이라 좌우 모두 양수 쪽으로 치솟습니다.", [
          { type: "mover", id: "m", plane: "pl", points: sample(f, x0 - 2.2, x0 - 0.3, { n: 40, yMax: yr[1] }), travelSec: 2.6, trail: true, color: C.ok },
        ]),
        beat(7, "정해진 값으로 모이지 않으므로 극한은 $\\infty$ 로 발산합니다.", [
          note("n1", 0, `\\lim_{x\\to ${nf(x0)}}\\frac{${nf(k)}}{(x-${nf(x0)})^2}=\\infty`, { color: C.hot, size: 40 }),
        ]),
      ],
    };
  });

  /* ---------- 지수·로그함수 ---------- */
  register("algebra-exp-log", (v) => {
    const base = v.base || 2;
    const isLog = (v.functionType || v.focusFunction) === "log";
    const sx = v.shiftX || 0, sy = v.shiftY || 0;
    const f = isLog
      ? (x) => Math.log(x - sx) / Math.log(base) + sy
      : (x) => Math.pow(base, x - sx) + sy;
    const xr = isLog ? [sx - 0.5, sx + Math.pow(base, 2.4) + 1] : [-3 + sx, 3 + sx];
    const yr = isLog ? [-3 + sy, 3 + sy] : [sy - 1, sy + Math.pow(base, 3) * 0.9];
    const fx = v.focusX;
    const acts = [
      plane("pl", xr, yr),
      { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0] + 0.02, xr[1], { n: 110, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.5 },
    ];
    const asym = isLog
      ? { type: "vline", id: "as", plane: "pl", x: sx, from: yr[0], to: yr[1], dashed: true, color: C.mute, label: `$x=${nf(sx)}$` }
      : { type: "seg", id: "as", plane: "pl", from: [xr[0], sy], to: [xr[1], sy], dashed: true, color: C.mute, width: 3, label: `$y=${nf(sy)}$` };

    const beats = [
      beat(7, isLog ? `밑이 $${nf(base)}$ 인 로그함수의 그래프입니다.` : `밑이 $${nf(base)}$ 인 지수함수의 그래프입니다.`, acts),
      beat(7, isLog ? "진수가 0 에 가까워지면 그래프가 수직 점근선에 붙습니다."
                    : "값이 아무리 작아져도 점근선 아래로는 내려가지 않습니다.", [asym]),
    ];
    if (fx !== undefined && fx !== null && isFinite(f(fx))) {
      beats.push(beat(8, `$x=${nf(fx)}$ 을 넣으면 높이가 정해집니다.`, [
        { type: "vline", id: "vf", plane: "pl", x: fx, from: yr[0], to: f(fx), dashed: true, color: C.hot },
        { type: "point", id: "P", plane: "pl", at: [fx, f(fx)], r: 12, color: C.hot, label: `$${nf(Math.round(f(fx) * 100) / 100)}$` },
      ]));
    }
    beats.push(beat(7, v.note || "그래프 위의 점 하나가 곧 식의 값입니다.", [
      note("n1", 0, isLog ? `y=\\log_{${nf(base)}}(x${sx ? sg(-sx) : ""})${sy ? sg(sy) : ""}`
                          : `y=${nf(base)}^{x${sx ? sg(-sx) : ""}}${sy ? sg(sy) : ""}`,
           { color: C.main, size: 38 }),
    ]));
    return { id: "sol-algebra-exp-log", beats };
  });

  /* ---------- 삼각함수 ---------- */
  register("algebra-trig", (v) => {
    const A = v.amplitude || 1, w = v.frequency || 1, k = v.verticalShift || 0;
    const name = v.functionName || "sin";
    const base = name === "cos" ? Math.cos : name === "tan" ? Math.tan : Math.sin;
    const f = (deg) => A * base((w * deg * Math.PI) / 180) + k;
    const xr = [0, 360];
    const yr = [k - Math.abs(A) - 1, k + Math.abs(A) + 1];
    const deg = v.focusDegree;
    const beats = [
      beat(7, `$y=${A === 1 ? "" : nf(A)}\\${name}${w === 1 ? "" : nf(w)}x${k ? sg(k) : ""}$ 의 그래프입니다.`, [
        plane("pl", xr, yr, { xTicks: [90, 180, 270, 360] }),
        { type: "plot", id: "f", plane: "pl", points: sample(f, 0, 360, { n: 140, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.6 },
      ]),
      beat(7, `진폭이 $${nf(Math.abs(A))}$ 이므로 위아래로 그만큼 흔들립니다.`, [
        { type: "seg", id: "top", plane: "pl", from: [0, k + Math.abs(A)], to: [360, k + Math.abs(A)], dashed: true, color: C.mute, width: 3 },
        { type: "seg", id: "bot", plane: "pl", from: [0, k - Math.abs(A)], to: [360, k - Math.abs(A)], dashed: true, color: C.mute, width: 3 },
      ]),
    ];
    if (deg !== undefined && deg !== null && isFinite(f(deg))) {
      beats.push(beat(8, `$x=${nf(deg)}^\\circ$ 에서의 높이가 함숫값입니다.`, [
        { type: "vline", id: "vf", plane: "pl", x: deg, from: k, to: f(deg), dashed: true, color: C.hot },
        { type: "point", id: "P", plane: "pl", at: [deg, f(deg)], r: 12, color: C.hot, label: `$${nf(Math.round(f(deg) * 100) / 100)}$` },
      ]));
    }
    beats.push(beat(7, v.note || "각을 정하면 그래프의 높이가 곧 삼각함수 값입니다.", [
      note("n1", 0, `${name === "sin" ? "\\sin" : name === "cos" ? "\\cos" : "\\tan"}\\ \\text{값} = \\text{그래프의 높이}`, { color: C.ok, size: 38 }),
    ]));
    return { id: "sol-algebra-trig", beats };
  });

  /* ---------- 수열 ---------- */
  register("algebra-sequence", (v) => {
    const vals = (v.values && v.values.length ? v.values : [1, 2, 3, 4, 5]).slice(0, 8);
    const fi = v.focusIndex ?? 0;
    const xr = [0, vals.length + 1];
    const yr = [Math.min(0, ...vals) - 1, Math.max(...vals) + 2];
    const dots = vals.map((y, i) => ({
      type: "point", id: `a${i}`, plane: "pl", at: [i + 1, y], r: 10,
      color: i === fi ? C.hot : C.main, label: `$${nf(y)}$`,
    }));
    const d = vals.length > 1 ? vals[1] - vals[0] : 0;
    const arith = vals.every((y, i) => i === 0 || Math.abs(y - vals[i - 1] - d) < 1e-9);
    return {
      id: "sol-algebra-sequence",
      beats: [
        beat(7, "수열은 자연수 자리마다 찍힌 점들의 모임입니다.", [
          plane("pl", xr, yr, { xTicks: vals.map((_, i) => i + 1), xLabel: "n", yLabel: "a_n" }),
          ...dots.slice(0, 3),
        ]),
        beat(7, "이어지는 항들을 마저 찍어 봅니다.", dots.slice(3)),
        beat(8, arith ? `이웃한 항의 차이가 항상 $${nf(d)}$ 로 같습니다 — 등차수열입니다.`
                      : "이웃한 항의 관계에서 규칙을 읽습니다.",
          vals.slice(1).map((y, i) => ({
            type: "seg", id: `d${i}`, plane: "pl", from: [i + 1, vals[i]], to: [i + 2, y],
            color: C.ok, width: 3, dashed: true,
          }))),
        beat(7, v.note || "규칙을 식으로 쓰면 임의의 항을 바로 구할 수 있습니다.", [
          { type: "point", id: `a${fi}`, plane: "pl", at: [fi + 1, vals[fi]], r: 15, color: C.hot, label: `$a_{${fi + 1}}=${nf(vals[fi])}$` },
          note("n1", 0, arith ? `a_n=a_1${d >= 0 ? "+" : "-"}(n-1)\\cdot ${nf(Math.abs(d))}` : `a_n\\ \\text{의 규칙}`,
               { color: C.ok, size: 40 }),
        ]),
      ],
    };
  });

  /* ---------- 계산형 대수 유형 — 개념 계열로 그림을 고른다 ----------
     지수·로그·삼각·수열은 파라미터가 따로 오지 않지만, 어느 계열인지는 안다.
     계열마다 "그 단원의 그림" 을 한 장 세워 두고 풀이 단계를 그 위에 얹는다. */
  register("algebra-concept", (v, ctx) => {
    const cid = String(v.conceptId || "");
    const unit = cid.slice(0, 10);          // algebra-01 / algebra-02 / algebra-03
    const idx = Number(cid.slice(11, 13)) || 1;
    const steps = (ctx && ctx.steps) || [];
    const tail = () => beat(7, steps.length ? String(steps[steps.length - 1]).replace(/\$/g, "").slice(0, 60)
                                            : "정리하면 답이 나옵니다.", [
      noteText("ans", 2, ctx && ctx.answer ? `답  ${String(ctx.answer).replace(/\$/g, "").slice(0, 24)}` : "정리",
               { x: 1180, size: 52, color: C.ok }),
    ]);

    // 지수와 로그 (algebra-01)
    if (unit === "algebra-01") {
      const isLog = idx >= 4;
      const b = 2;
      const f = isLog ? (x) => Math.log(x) / Math.log(b) : (x) => Math.pow(b, x);
      const xr = isLog ? [0.05, 9] : [-3, 3.2];
      const yr = isLog ? [-3.2, 3.2] : [-0.6, 9];
      return {
        id: "sol-algebra-01",
        beats: [
          beat(7, isLog ? "로그는 '밑을 몇 번 곱해야 그 수가 되는가' 입니다."
                        : "거듭제곱은 밑을 반복해서 곱한 결과입니다.", [
            plane("pl", xr, yr),
            { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0], xr[1], { n: 110, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.5 },
          ]),
          beat(7, isLog ? "밑이 같으면 로그끼리 더하고 빼서 합칠 수 있습니다."
                        : "밑이 같으면 지수끼리 더하고 빼서 합칠 수 있습니다.", [
            note("n1", 0, isLog ? "\\log_a M+\\log_a N=\\log_a MN" : "a^m\\cdot a^n=a^{m+n}", { color: C.main, size: 38 }),
          ]),
          beat(7, steps[0] ? String(steps[0]).replace(/\$/g, "").slice(0, 60) : "식을 하나로 모읍니다.", [
            note("n2", 1, isLog ? "\\log_a M^k=k\\log_a M" : "(a^m)^n=a^{mn}", { color: C.ok, size: 38 }),
            { type: "point", id: "P", plane: "pl", at: isLog ? [4, 2] : [2, 4], r: 12, color: C.hot },
          ]),
          tail(),
        ],
      };
    }

    // 삼각함수 (algebra-02) — 단위원과 각
    if (unit === "algebra-02") {
      const rad = Math.PI / 3;
      const arc = [];
      for (let i = 0; i <= 40; i++) {
        const t = (rad * i) / 40;
        arc.push([Math.cos(t), Math.sin(t)]);
      }
      const circle = [];
      for (let i = 0; i <= 96; i++) {
        const t = (i / 96) * Math.PI * 2;
        circle.push([Math.cos(t), Math.sin(t)]);
      }
      return {
        id: "sol-algebra-02",
        beats: [
          beat(7, "반지름 $1$ 인 원 위에서 각을 재면 삼각함수가 보입니다.", [
            plane("pl", [-1.4, 1.4], [-1.4, 1.4], { xTicks: [-1, 1], yTicks: [-1, 1] }),
            { type: "plot", id: "c", plane: "pl", points: circle, color: C.mute, width: 4, drawSec: 1.4 },
          ]),
          beat(7, "각이 커지면 원 위의 점이 그만큼 돌아갑니다.", [
            { type: "plot", id: "arc", plane: "pl", points: arc, color: C.hot, width: 7, drawSec: 1.2 },
            { type: "mover", id: "m", plane: "pl", points: arc, travelSec: 2.4, trail: true, color: C.hot },
          ]),
          beat(8, "그 점의 $x$ 좌표가 코사인, $y$ 좌표가 사인입니다.", [
            { type: "seg", id: "sx", plane: "pl", from: [0, 0], to: [Math.cos(rad), Math.sin(rad)], color: C.main, width: 4 },
            { type: "seg", id: "sy", plane: "pl", from: [Math.cos(rad), 0], to: [Math.cos(rad), Math.sin(rad)], dashed: true, color: C.ok, width: 3 },
            note("n1", 0, "(\\cos\\theta,\\ \\sin\\theta)", { color: C.main, size: 40 }),
          ]),
          tail(),
        ],
      };
    }

    // 수열 (algebra-03) — 항을 블록으로 쌓는다
    const vals = [3, 5, 7, 9, 11];
    return {
      id: "sol-algebra-03",
      beats: [
        beat(7, "수열의 항을 하나씩 늘어놓고 규칙을 찾습니다.", [
          plane("pl", [0, 6], [0, 13], { xTicks: [1, 2, 3, 4, 5], xLabel: "n", yLabel: "a_n" }),
          ...vals.map((y, i) => ({ type: "point", id: `a${i}`, plane: "pl", at: [i + 1, y], r: 10, color: C.main, label: `$${y}$` })),
        ]),
        beat(7, "이웃한 항의 차이가 일정하면 등차수열입니다.", [
          ...vals.slice(1).map((y, i) => ({
            type: "seg", id: `d${i}`, plane: "pl", from: [i + 1, vals[i]], to: [i + 2, y], color: C.ok, width: 3, dashed: true,
          })),
          note("n1", 0, "a_{n+1}-a_n=\\text{일정}", { color: C.ok, size: 38 }),
        ]),
        beat(8, "합은 항을 블록으로 쌓아 세는 것과 같습니다.", [
          { type: "blocks", id: "bk", rect: { x: 1180, y: 480, w: 520, h: 300 }, rows: 5, cols: 7, count: 25, gap: 7, color: C.main, countLabel: true },
        ]),
        tail(),
      ],
    };
  });

  /* ============================================================
     네이티브 생성기(ProblemGenerator.swift) 17유형
     각 유형의 수치가 그대로 넘어오므로, 같은 안무에 값만 갈아 끼운다.
     ============================================================ */

  /* 삼차함수의 극값 — f(x)=x³+px²+qx 의 봉우리와 골짜기 */
  register("swift-cubic-extremum", (v) => {
    const p = v.p || 0, q = v.q || 0, a = v.a || -1, b = v.b || 1;
    const f = (x) => x * x * x + p * x * x + q * x;
    const df = (x) => 3 * x * x + 2 * p * x + q;
    const xr = [a - 1.6, b + 1.6];
    const ys = sample(f, xr[0], xr[1]).map((t) => t[1]);
    const yr = [Math.min(...ys) - 2, Math.max(...ys) + 2];
    return {
      id: "sol-cubic-extremum",
      beats: [
        beat(7, `삼차함수 $f(x)=x^3${term(p, "x^2")}${term(q, "x")}$ 의 그래프입니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0], xr[1]), color: C.main, width: 5, drawSec: 1.6 },
        ]),
        beat(7, "극값은 봉우리와 골짜기 — 그 자리에서 접선이 눕습니다.", [
          { type: "point", id: "PA", plane: "pl", at: [a, f(a)], r: 12, color: C.hot, label: `극대 $x=${nf(a)}$` },
          { type: "point", id: "PB", plane: "pl", at: [b, f(b)], r: 12, color: C.ok, label: `극소 $x=${nf(b)}$` },
        ]),
        beat(8, `접선의 기울기가 $0$ 인 곳이니 $f'(x)=3x^2${term(2 * p, "x")}${term(q, "")}$ 의 근입니다.`, [
          { type: "plot", id: "df", plane: "pl", points: sample(df, xr[0], xr[1], { yMin: yr[0], yMax: yr[1] }), color: C.mute, width: 4, dashed: true },
          note("n1", 0, `f'(x)=3x^2${term(2 * p, "x")}${term(q, "")}`, { color: C.mute, size: 36 }),
        ]),
        beat(8, "두 근이 곧 극점의 $x$ 좌표이므로 근과 계수의 관계로 상수를 찾습니다.", [
          note("n2", 1, `${nf(a)}+${nf(b)}=-\\frac{2p}{3}\\ \\Rightarrow\\ p=${nf(p)}`, { color: C.main, size: 34 }),
          note("n3", 2, `${nf(a)}\\cdot${nf(b)}=\\frac{q}{3}\\ \\Rightarrow\\ q=${nf(q)}`, { color: C.ok, size: 34 }),
        ]),
      ],
    };
  });

  /* 로그방정식 — 지수와 로그가 서로 되돌리는 관계 */
  register("swift-log-equation", (v) => {
    const base = v.base || 2, k = v.k || 1, c = v.c || 0, x = v.x || 0;
    const f = (t) => Math.log(t - c) / Math.log(base);
    const xr = [c - 0.5, x + Math.max(2, (x - c) * 0.35)];
    const yr = [-2, k + 2];
    return {
      id: "sol-log-equation",
      beats: [
        beat(7, `$y=\\log_{${nf(base)}}(x-${nf(c)})$ 의 그래프에서 높이가 $${nf(k)}$ 인 곳을 찾습니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f, c + 0.02, xr[1], { n: 110, yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.6 },
          { type: "vline", id: "as", plane: "pl", x: c, from: yr[0], to: yr[1], dashed: true, color: C.mute, label: `$x=${nf(c)}$` },
        ]),
        beat(7, "로그의 정의를 그대로 쓰면 지수식으로 바뀝니다.", [
          { type: "seg", id: "hk", plane: "pl", from: [xr[0], k], to: [xr[1], k], dashed: true, color: C.ok, width: 3, label: `$y=${nf(k)}$` },
          note("n1", 0, `\\log_{${nf(base)}}A=${nf(k)}\\iff A=${nf(base)}^{${nf(k)}}`, { color: C.ok, size: 34 }),
        ]),
        beat(8, `진수를 통째로 두면 $x-${nf(c)}=${nf(base)}^{${nf(k)}}$ 입니다.`, [
          note("n2", 1, `x-${nf(c)}=${nf(Math.pow(base, k))}`, { color: C.main, size: 38 }),
          { type: "point", id: "P", plane: "pl", at: [x, k], r: 12, color: C.hot, label: `$x=${nf(x)}$` },
        ]),
        beat(7, "진수가 양수인지 확인하면 풀이가 끝납니다.", [
          note("n3", 2, `x=${nf(x)}\\quad(${nf(Math.pow(base, k))}>0)`, { color: C.ok, size: 42 }),
        ]),
      ],
    };
  });

  /* 순열·조합 — 자리를 채우는 블록 */
  register("swift-counting", (v) => {
    const n = v.n || 5, r = v.r || 2, perm = !!v.isPerm, ans = v.answer ?? 0;
    return {
      id: "sol-counting",
      beats: [
        beat(7, `서로 다른 $${nf(n)}$ 명이 있습니다.`, [
          { type: "blocks", id: "all", rect: { x: 260, y: 300, w: 700, h: 320 }, rows: 2, cols: Math.ceil(n / 2), count: n, gap: 10, color: C.main, countLabel: true },
        ]),
        beat(7, perm ? "'일렬로 세운다' — 뽑은 뒤 순서까지 정합니다."
                     : "'뽑는다' 만 있습니다 — 순서는 따지지 않습니다.", [
          { type: "blocks", id: "pick", rect: { x: 260, y: 700, w: 420, h: 150 }, rows: 1, cols: r, count: r, gap: 10, color: C.hot, countLabel: true },
          note("n1", 0, perm ? "\\text{순서 있음}" : "\\text{순서 없음}", { color: C.hot }),
        ]),
        beat(8, perm ? `자리마다 후보가 하나씩 줄어듭니다.`
                     : `순서만큼 중복해서 셌으니 $${nf(r)}!$ 로 나눕니다.`, [
          note("n2", 1, perm ? `{}_{${nf(n)}}P_{${nf(r)}}` : `{}_{${nf(n)}}C_{${nf(r)}}=\\frac{{}_{${nf(n)}}P_{${nf(r)}}}{${nf(r)}!}`,
               { color: C.main, size: 40 }),
        ]),
        beat(7, `계산하면 $${nf(ans)}$ 가지입니다.`, [
          note("n3", 2, `=${nf(ans)}`, { color: C.ok, size: 52 }),
        ]),
      ],
    };
  });

  /* 정적분 — 넓이로 보는 적분 */
  register("swift-definite-integral", (v) => {
    const a = v.a || 1, b = v.b || 1, ans = v.answer ?? 0;
    const f = (x) => 2 * x + b;
    const xr = [-0.6, a + 1];
    const yr = [-0.6, f(a) + 1.5];
    const region = [[0, 0], ...sample(f, 0, a, { n: 40 }), [a, 0]];
    return {
      id: "sol-definite-integral",
      beats: [
        beat(7, `적분할 함수 $y=2x+${nf(b)}$ 를 그립니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0], xr[1]), color: C.main, width: 5, drawSec: 1.3 },
        ]),
        beat(8, `$0$ 부터 $${nf(a)}$ 까지의 정적분은 이 사다리꼴의 넓이입니다.`, [
          { type: "fill", id: "area", plane: "pl", points: region, color: C.ok, opacity: 0.3 },
          { type: "vline", id: "vb", plane: "pl", x: a, from: 0, to: f(a), dashed: true, color: C.mute, label: `$x=${nf(a)}$` },
        ]),
        beat(8, "항별로 적분하면 부정적분이 나옵니다.", [
          note("n1", 0, `\\int(2x+${nf(b)})dx=x^2+${nf(b)}x+C`, { color: C.main, size: 34 }),
        ]),
        beat(7, `위끝에서 아래끝을 빼면 $${nf(ans)}$ 입니다.`, [
          note("n2", 1, `\\left[x^2+${nf(b)}x\\right]_0^{${nf(a)}}=${nf(ans)}`, { color: C.ok, size: 40 }),
        ]),
      ],
    };
  });

  /* 주기 수열의 합 — 세 항씩 묶기 */
  register("swift-block-sum", (v) => {
    const p = v.p || 2, q = v.q || 1, ans = v.answer ?? 0;
    const vals = [p, p, -q, p, p, -q, p, p, -q];
    const xr = [0, vals.length + 1];
    const yr = [Math.min(-q, 0) - 2, p + 2];
    return {
      id: "sol-block-sum",
      beats: [
        beat(7, `항이 $${nf(p)},\\ ${nf(p)},\\ -${nf(q)}$ 로 계속 반복됩니다.`, [
          plane("pl", xr, yr, { xTicks: [3, 6, 9], xLabel: "n", yLabel: "a_n" }),
          ...vals.map((y, i) => ({
            type: "point", id: `a${i}`, plane: "pl", at: [i + 1, y], r: 9,
            color: y < 0 ? C.hot : C.main,
          })),
        ]),
        beat(8, "세 항씩 묶으면 한 덩어리의 합이 일정합니다.", [
          ...[0, 1, 2].map((k) => ({
            type: "brace", id: `br${k}`, plane: "pl", from: [3 * k + 1, yr[0] + 0.5], to: [3 * k + 3, yr[0] + 0.5],
            label: `$${nf(2 * p - q)}$`, color: C.ok,
          })),
          note("n1", 0, `${nf(p)}+${nf(p)}-${nf(q)}=${nf(2 * p - q)}`, { color: C.ok, size: 36 }),
        ]),
        beat(8, "그래서 $3n$ 개까지의 합은 덩어리 개수만큼입니다.", [
          note("n2", 1, `S_{3n}=n`, { color: C.main, size: 42 }),
        ]),
        beat(7, `두 합이 같아지는 자연수를 풀면 $${nf(ans)}$ 입니다.`, [
          note("n3", 2, `n=${nf(ans)}`, { color: C.ok, size: 52 }),
        ]),
      ],
    };
  });

  /* 판별식 — 축을 몇 번 만나는가 */
  register("swift-quad-disc", (v) => {
    const b = v.b || 2, bound = v.bound ?? (b * b) / 4, ans = v.answer ?? 0;
    const f = (c) => (x) => x * x + b * x + c;
    const xr = [-b / 2 - 4, -b / 2 + 4];
    const yr = [-6, 10];
    return {
      id: "sol-quad-disc",
      beats: [
        beat(7, `$y=x^2+${nf(b)}x+c$ 에서 $c$ 를 키우면 포물선이 위로 올라갑니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f(bound - 4), xr[0], xr[1], { yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.4 },
        ]),
        beat(8, "서로 다른 두 실근이란 $x$ 축을 두 점에서 자른다는 뜻입니다.", [
          { type: "plot", id: "f", plane: "pl", points: sample(f(ans), xr[0], xr[1], { yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, morphSec: 2.0 },
          note("n1", 0, `D=${nf(b)}^2-4c>0`, { color: C.main, size: 40 }),
        ]),
        beat(8, `더 올리면 접했다가 떨어집니다 — 경계는 $c=${nf(bound)}$ 입니다.`, [
          { type: "plot", id: "f", plane: "pl", points: sample(f(bound), xr[0], xr[1], { yMin: yr[0], yMax: yr[1] }), color: C.hot, width: 5, morphSec: 2.0 },
          note("n2", 1, `c<\\frac{${nf(b)}^2}{4}=${nf(bound)}`, { color: C.hot, size: 38 }),
        ]),
        beat(7, `$c$ 는 정수이므로 최댓값은 $${nf(ans)}$ 입니다.`, [
          note("n3", 2, `c_{\\max}=${nf(ans)}`, { color: C.ok, size: 50 }),
        ]),
      ],
    };
  });

  /* 근과 계수의 관계 */
  register("swift-vieta", (v) => {
    const s = v.s || 0, p = v.p || 0, ans = v.answer ?? 0;
    const disc = s * s - 4 * p;
    const r1 = (s - Math.sqrt(Math.max(disc, 0))) / 2;
    const r2 = (s + Math.sqrt(Math.max(disc, 0))) / 2;
    const f = (x) => x * x - s * x + p;
    const xr = [Math.min(r1, 0) - 1.5, Math.max(r2, 0) + 1.5];
    const yr = [Math.min(f(s / 2), 0) - 1.5, Math.max(f(xr[0]), f(xr[1])) + 1];
    return {
      id: "sol-vieta",
      beats: [
        beat(7, `$x^2-${nf(s)}x+${nf(p)}=0$ 의 두 근이 곧 축과 만나는 자리입니다.`, [
          plane("pl", xr, yr),
          { type: "plot", id: "f", plane: "pl", points: sample(f, xr[0], xr[1], { yMin: yr[0], yMax: yr[1] }), color: C.main, width: 5, drawSec: 1.5 },
          { type: "point", id: "r1", plane: "pl", at: [r1, 0], r: 11, color: C.hot, label: "$\\alpha$" },
          { type: "point", id: "r2", plane: "pl", at: [r2, 0], r: 11, color: C.hot, label: "$\\beta$" },
        ]),
        beat(7, "근을 직접 구하지 않아도 합과 곱은 계수에서 바로 읽힙니다.", [
          note("n1", 0, `\\alpha+\\beta=${nf(s)},\\quad \\alpha\\beta=${nf(p)}`, { color: C.main, size: 36 }),
          { type: "brace", id: "br", plane: "pl", from: [r1, -0.6], to: [r2, -0.6], label: "$\\alpha+\\beta$", color: C.mute },
        ]),
        beat(8, "구하려는 식을 합과 곱만으로 바꿔 씁니다.", [
          note("n2", 1, `\\alpha^2+\\beta^2=(\\alpha+\\beta)^2-2\\alpha\\beta`, { color: C.ok, size: 34 }),
        ]),
        beat(7, `대입하면 $${nf(s)}^2-2\\cdot${nf(p)}=${nf(ans)}$ 입니다.`, [
          note("n3", 2, `=${nf(ans)}`, { color: C.ok, size: 50 }),
        ]),
      ],
    };
  });

  /* 원과 점의 거리 */
  register("swift-circle-dist", (v) => {
    const px = v.px || 3, py = v.py || 4, r = v.r || 1, dist = v.dist || 5, ans = v.answer ?? 0;
    const lim = Math.max(Math.abs(px), Math.abs(py), r) + 1.5;
    const ux = px / dist, uy = py / dist;
    return {
      id: "sol-circle-dist",
      beats: [
        beat(7, `원점이 중심이고 반지름이 $${nf(r)}$ 인 원과 점 $P(${nf(px)},${nf(py)})$ 입니다.`, [
          plane("pl", [-lim, lim], [-lim, lim]),
          { type: "circle", id: "c", plane: "pl", center: [0, 0], r: r, stroke: C.main, fill: C.main, fillOpacity: 0.1 },
          { type: "point", id: "P", plane: "pl", at: [px, py], r: 12, color: C.hot, label: "$P$" },
        ]),
        beat(8, `중심에서 $P$ 까지 거리는 피타고라스로 $${nf(dist)}$ 입니다.`, [
          { type: "seg", id: "op", plane: "pl", from: [0, 0], to: [px, py], color: C.mute, width: 4, label: `$${nf(dist)}$` },
          note("n1", 0, `\\sqrt{${nf(px)}^2+${nf(py)}^2}=${nf(dist)}`, { color: C.mute, size: 34 }),
        ]),
        beat(8, "최단거리는 중심·원 위의 점·$P$ 가 한 직선에 놓일 때입니다.", [
          { type: "point", id: "Q", plane: "pl", at: [ux * r, uy * r], r: 11, color: C.ok, label: "$Q$" },
          { type: "seg", id: "qp", plane: "pl", from: [ux * r, uy * r], to: [px, py], color: C.ok, width: 5 },
        ]),
        beat(7, `그래서 거리에서 반지름을 뺀 $${nf(ans)}$ 가 최솟값입니다.`, [
          note("n2", 1, `${nf(dist)}-${nf(r)}=${nf(ans)}`, { color: C.ok, size: 48 }),
        ]),
      ],
    };
  });

  /* 주사위 두 개의 합 — 6×6 격자 */
  register("swift-dice", (v) => {
    const target = v.target || 7, count = v.count || 1;
    const cells = [];
    for (let a = 1; a <= 6; a++) {
      for (let b = 1; b <= 6; b++) {
        if (a + b === target) cells.push([a, b]);
      }
    }
    return {
      id: "sol-dice",
      beats: [
        beat(7, "두 주사위의 눈을 격자로 늘어놓으면 전부 $36$ 가지입니다.", [
          plane("pl", [0, 7], [0, 7], { xTicks: [1, 2, 3, 4, 5, 6], yTicks: [1, 2, 3, 4, 5, 6], xLabel: "a", yLabel: "b" }),
          { type: "blocks", id: "all", rect: { x: 1200, y: 380, w: 380, h: 380 }, rows: 6, cols: 6, count: 36, gap: 6, color: C.mute, countLabel: true },
        ]),
        beat(8, `합이 $${nf(target)}$ 인 칸만 골라 표시합니다.`,
          cells.map((c, i) => ({
            type: "point", id: `h${i}`, plane: "pl", at: c, r: 13, color: C.hot,
          }))),
        beat(7, `대각선 위의 $${nf(count)}$ 칸이 조건을 만족합니다.`, [
          { type: "blocks", id: "hit", rect: { x: 1200, y: 800, w: 380, h: 90 }, rows: 1, cols: 6, count: count, gap: 6, color: C.hot, countLabel: true },
        ]),
        beat(7, `확률은 $\\dfrac{${nf(count)}}{36}$ 입니다.`, [
          note("n1", 0, `P=\\frac{${nf(count)}}{36}`, { color: C.ok, size: 50 }),
        ]),
      ],
    };
  });

  /* 지수법칙 */
  register("swift-exp-law", (v) => {
    const a = v.a || 2, m = v.m || 1, n = v.n || 1, p = v.p || 1, e = v.e ?? (m + n - p), ans = v.answer ?? 0;
    return {
      id: "sol-exp-law",
      beats: [
        beat(7, `밑이 $${nf(a)}$ 로 모두 같으니 지수만 따라가면 됩니다.`, [
          { type: "blocks", id: "bm", rect: { x: 300, y: 300, w: 380, h: 120 }, rows: 1, cols: Math.max(m, 1), count: m, gap: 10, color: C.main, countLabel: true },
          note("n1", 0, `${nf(a)}^{${nf(m)}}\\cdot ${nf(a)}^{${nf(n)}}\\div ${nf(a)}^{${nf(p)}}`, { color: C.ink, size: 38 }),
        ]),
        beat(7, `곱하면 지수는 더해집니다 — $${nf(m)}+${nf(n)}=${nf(m + n)}$.`, [
          { type: "blocks", id: "bn", rect: { x: 300, y: 460, w: 380, h: 120 }, rows: 1, cols: Math.max(n, 1), count: n, gap: 10, color: C.ok, countLabel: true },
          note("n2", 1, `${nf(a)}^{${nf(m)}+${nf(n)}}=${nf(a)}^{${nf(m + n)}}`, { color: C.main, size: 36 }),
        ]),
        beat(8, `나누면 지수는 빠집니다 — $${nf(m + n)}-${nf(p)}=${nf(e)}$.`, [
          { type: "blocks", id: "bp", rect: { x: 300, y: 620, w: 380, h: 120 }, rows: 1, cols: Math.max(p, 1), count: p, gap: 10, color: C.hot, countLabel: true },
          note("n3", 2, `${nf(a)}^{${nf(e)}}`, { color: C.hot, size: 42 }),
        ]),
        beat(7, `계산하면 $${nf(ans)}$ 입니다.`, [
          noteText("ans", 3, `= ${nf(ans)}`, { size: 54, color: C.ok }),
        ]),
      ],
    };
  });

  /* 다항식의 전개 — 넓이 모델 */
  register("swift-poly-expand", (v) => {
    const a = v.a || 1, b = v.b || 1, askLinear = !!v.askLinear, ans = v.answer ?? 0;
    const X = 4;  // x 를 길이 4 로 그린다
    const W2 = X + a, H2 = X + b;
    return {
      id: "sol-poly-expand",
      beats: [
        beat(7, `가로 $x+${nf(a)}$, 세로 $x+${nf(b)}$ 인 직사각형의 넓이입니다.`, [
          plane("pl", [-0.5, W2 + 1], [-0.5, H2 + 1], { showGrid: false, xTicks: [], yTicks: [] }),
          { type: "polygon", id: "R", plane: "pl", points: [[0, 0], [W2, 0], [W2, H2], [0, H2]], stroke: C.ink, fill: C.main, fillOpacity: 0.08 },
          { type: "brace", id: "bw", plane: "pl", from: [0, -0.35], to: [W2, -0.35], label: `$x+${nf(a)}$`, color: C.mute },
        ]),
        beat(8, "가로와 세로를 각각 잘라 네 조각으로 나눕니다.", [
          { type: "seg", id: "cx", plane: "pl", from: [X, 0], to: [X, H2], color: C.hot, width: 3, dashed: true },
          { type: "seg", id: "cy", plane: "pl", from: [0, X], to: [W2, X], color: C.hot, width: 3, dashed: true },
          { type: "glabel", id: "q1", plane: "pl", at: [X / 2 - 0.4, X / 2], tex: "x^2", size: 34, color: C.main },
        ]),
        beat(8, `옆의 두 조각이 $${nf(a)}x$ 와 $${nf(b)}x$ 이고, 모서리가 $${nf(a * b)}$ 입니다.`, [
          { type: "glabel", id: "q2", plane: "pl", at: [X + a / 2 - 0.3, X / 2], tex: `${nf(a)}x`, size: 30, color: C.ok },
          { type: "glabel", id: "q3", plane: "pl", at: [X / 2 - 0.3, X + b / 2], tex: `${nf(b)}x`, size: 30, color: C.ok },
          { type: "glabel", id: "q4", plane: "pl", at: [X + a / 2 - 0.3, X + b / 2], tex: nf(a * b), size: 28, color: C.hot },
        ]),
        beat(7, askLinear ? `$x$ 의 계수는 두 수의 합 $${nf(a + b)}$ 입니다.`
                          : `상수항은 두 수의 곱 $${nf(a * b)}$ 입니다.`, [
          note("n1", 0, `x^2+(${nf(a)}+${nf(b)})x+${nf(a * b)}`, { color: C.ink, size: 36 }),
          noteText("ans", 1, `답  ${nf(ans)}`, { size: 52, color: C.ok }),
        ]),
      ],
    };
  });

  /* 복소수의 곱 — 복소평면 */
  register("swift-complex-mul", (v) => {
    const a = v.a || 1, b = v.b || 1, c = v.c || 1, d = v.d || 1;
    const re = v.re ?? (a * c - b * d), im = v.im ?? (a * d + b * c);
    const askReal = !!v.askReal;
    const lim = Math.max(Math.abs(re), Math.abs(im), a, b, c, d) + 2;
    return {
      id: "sol-complex-mul",
      beats: [
        beat(7, `두 복소수를 복소평면 위의 점으로 봅니다.`, [
          plane("pl", [-lim, lim], [-lim, lim], { xLabel: "실수", yLabel: "허수" }),
          { type: "point", id: "z1", plane: "pl", at: [a, b], r: 12, color: C.main, label: `$${nf(a)}+${nf(b)}i$` },
          { type: "point", id: "z2", plane: "pl", at: [c, d], r: 12, color: C.ok, label: `$${nf(c)}+${nf(d)}i$` },
        ]),
        beat(8, "분배법칙으로 네 항을 만들고 $i^2=-1$ 을 씁니다.", [
          note("n1", 0, `${nf(a * c)}+${nf(a * d)}i+${nf(b * c)}i+${nf(b * d)}i^2`, { color: C.ink, size: 34 }),
          note("n2", 1, `i^2=-1`, { color: C.hot, size: 36 }),
        ]),
        beat(8, `실수부는 $${nf(a * c)}-${nf(b * d)}=${nf(re)}$ 입니다.`, [
          { type: "point", id: "zp", plane: "pl", at: [re, im], r: 14, color: C.hot, label: `$${nf(re)}${sg(im)}i$` },
          { type: "seg", id: "oz", plane: "pl", from: [0, 0], to: [re, im], color: C.hot, width: 4 },
        ]),
        beat(7, askReal ? `묻는 것은 실수부이므로 $${nf(re)}$ 입니다.`
                        : `묻는 것은 허수부이므로 $${nf(im)}$ 입니다.`, [
          noteText("ans", 2, `답  ${askReal ? nf(re) : nf(im)}`, { size: 52, color: C.ok }),
        ]),
      ],
    };
  });

  /* 기댓값·분산의 선형성 — 이 앱의 급소 유형 */
  register("swift-stat-linear", (v) => {
    const isVar = v.mode === "variance";
    const base = v.base || 1, a = v.a || 1, b = v.b || 0, ans = v.answer ?? 0;
    const xs = [-2, -1, 0, 1, 2];
    const bell = (m, s) => (x) => Math.exp(-((x - m) * (x - m)) / (2 * s * s)) / s;
    const s0 = isVar ? Math.sqrt(base) : 1;
    const s1 = isVar ? Math.sqrt(base) * a : 1;
    const xr = [-Math.max(s1 * 3, 6), Math.max(s1 * 3, 6) + b];
    return {
      id: "sol-stat-linear",
      beats: [
        beat(7, isVar ? `분산 $V(X)=${nf(base)}$ 인 분포입니다. 흩어진 정도를 봅니다.`
                      : `평균 $E(X)=${nf(base)}$ 인 분포입니다.`, [
          plane("pl", xr, [0, 1.15], { yTicks: [] }),
          { type: "plot", id: "d", plane: "pl", points: sample(bell(0, s0), xr[0], xr[1], { n: 120 }), color: C.main, width: 5, drawSec: 1.5 },
        ]),
        beat(8, `$${nf(a)}$ 배 하면 분포가 옆으로 ${isVar ? "그만큼 넓어집니다" : "늘어납니다"}.`, [
          { type: "plot", id: "d", plane: "pl", points: sample(bell(0, s1), xr[0], xr[1], { n: 120 }), color: C.main, width: 5, morphSec: 2.0 },
          note("n1", 0, isVar ? `V(aX)=a^2V(X)` : `E(aX)=aE(X)`, { color: C.main, size: 38 }),
        ]),
        beat(8, isVar ? `$+${nf(b)}$ 는 통째로 옮길 뿐 — 흩어짐은 그대로입니다.`
                      : `$+${nf(b)}$ 만큼 통째로 옮겨지므로 평균도 그만큼 커집니다.`, [
          { type: "plot", id: "d", plane: "pl", points: sample(bell(b, s1), xr[0], xr[1], { n: 120 }), color: isVar ? C.mute : C.ok, width: 5, morphSec: 2.0 },
          note("n2", 1, isVar ? `V(aX+b)=a^2V(X)` : `E(aX+b)=aE(X)+b`, { color: isVar ? C.hot : C.ok, size: 36 }),
        ]),
        beat(7, isVar ? `그래서 $${nf(a)}^2\\cdot${nf(base)}=${nf(ans)}$ 입니다.`
                      : `그래서 $${nf(a)}\\cdot${nf(base)}+${nf(b)}=${nf(ans)}$ 입니다.`, [
          noteText("ans", 2, `답  ${nf(ans)}`, { size: 54, color: C.ok }),
        ]),
      ],
    };
  });

  /* 이항분포 */
  register("swift-binomial", (v) => {
    const n = v.n || 4, num = v.num || 1, den = v.den || 2;
    const mean = v.mean ?? (n * num) / den, variance = v.variance ?? 0;
    const askMean = !!v.askMean;
    const p = num / den;
    const logC = (nn, k) => {
      let s = 0;
      for (let i = 1; i <= k; i++) s += Math.log(nn - k + i) - Math.log(i);
      return s;
    };
    const bars = [];
    for (let k = 0; k <= n; k++) {
      const pr = Math.exp(logC(n, k) + k * Math.log(p) + (n - k) * Math.log(1 - p));
      bars.push({ k, pr });
    }
    const top = Math.max(...bars.map((b) => b.pr));
    return {
      id: "sol-binomial",
      beats: [
        beat(7, `성공확률 $${nf(num)}/${nf(den)}$ 인 시행을 $${nf(n)}$ 번 합니다.`, [
          plane("pl", [-0.6, n + 0.6], [0, top * 1.25], { xTicks: bars.map((b) => b.k).slice(0, 7), yTicks: [], xLabel: "k", yLabel: "P" }),
          ...bars.map((b) => ({
            type: "seg", id: `b${b.k}`, plane: "pl", from: [b.k, 0], to: [b.k, b.pr],
            color: C.main, width: 14,
          })),
        ]),
        beat(7, "성공 횟수의 분포가 이렇게 생겼습니다 — 가운데가 가장 두껍습니다.", [
          { type: "vline", id: "vm", plane: "pl", x: mean, from: 0, to: top * 1.1, dashed: true, color: C.hot, label: `$np$` },
        ]),
        beat(8, `평균은 $np=${nf(n)}\\cdot\\dfrac{${nf(num)}}{${nf(den)}}=${nf(mean)}$ 입니다.`, [
          note("n1", 0, `E(X)=np=${nf(mean)}`, { color: C.main, size: 38 }),
        ]),
        beat(7, askMean ? `묻는 것은 평균이므로 답은 $${nf(mean)}$ 입니다.`
                        : `분산은 $np(1-p)=${nf(variance)}$ 입니다.`, [
          note("n2", 1, `V(X)=np(1-p)=${nf(variance)}`, { color: C.ok, size: 36 }),
          noteText("ans", 2, `답  ${nf(askMean ? mean : variance)}`, { size: 50, color: C.ok }),
        ]),
      ],
    };
  });

  /* 정규분포의 표준화 */
  register("swift-normal", (v) => {
    const m = v.mean || 0, s = v.sigma || 1, x0 = v.x0 ?? m, z = v.z ?? 0;
    const bell = (mu, sd) => (x) => Math.exp(-((x - mu) * (x - mu)) / (2 * sd * sd));
    const xr = [m - 4 * s, m + 4 * s];
    return {
      id: "sol-normal",
      beats: [
        beat(7, `평균 $${nf(m)}$, 표준편차 $${nf(s)}$ 인 정규분포입니다.`, [
          plane("pl", xr, [0, 1.2], { yTicks: [] }),
          { type: "plot", id: "d", plane: "pl", points: sample(bell(m, s), xr[0], xr[1], { n: 130 }), color: C.main, width: 5, drawSec: 1.6 },
          { type: "vline", id: "vm", plane: "pl", x: m, from: 0, to: 1.05, dashed: true, color: C.mute, label: `$m=${nf(m)}$` },
        ]),
        beat(8, `$X=${nf(x0)}$ 은 평균에서 얼마나 떨어져 있는지가 관건입니다.`, [
          { type: "vline", id: "vx", plane: "pl", x: x0, from: 0, to: bell(m, s)(x0), color: C.hot, dashed: false, label: `$${nf(x0)}$` },
          { type: "brace", id: "br", plane: "pl", from: [Math.min(m, x0), 1.1], to: [Math.max(m, x0), 1.1], label: `$${nf(Math.abs(x0 - m))}$`, color: C.hot },
        ]),
        beat(8, `그 거리를 표준편차 $${nf(s)}$ 로 재면 몇 칸인지가 나옵니다.`, [
          note("n1", 0, `Z=\\frac{X-m}{\\sigma}=\\frac{${nf(x0)}-${nf(m)}}{${nf(s)}}`, { color: C.main, size: 34 }),
        ]),
        beat(7, `표준편차 $${nf(Math.abs(z))}$ 개만큼 ${z >= 0 ? "위" : "아래"}이므로 $Z=${nf(z)}$ 입니다.`, [
          noteText("ans", 1, `Z = ${nf(z)}`, { size: 54, color: C.ok }),
        ]),
      ],
    };
  });

  /* 표본평균의 분포 */
  register("swift-sample-mean", (v) => {
    const m = v.mean || 0, s = v.sigma || 1, n = v.n || 1;
    const variance = v.variance ?? (s * s) / n;
    const askMean = !!v.askMean;
    const se = Math.sqrt(variance);
    const bell = (sd) => (x) => Math.exp(-((x - m) * (x - m)) / (2 * sd * sd));
    const xr = [m - 3.5 * s, m + 3.5 * s];
    return {
      id: "sol-sample-mean",
      beats: [
        beat(7, `모집단은 평균 $${nf(m)}$, 표준편차 $${nf(s)}$ 로 퍼져 있습니다.`, [
          plane("pl", xr, [0, 1.2], { yTicks: [] }),
          { type: "plot", id: "d", plane: "pl", points: sample(bell(s), xr[0], xr[1], { n: 130 }), color: C.mute, width: 5, drawSec: 1.5 },
        ]),
        beat(8, `크기 $${nf(n)}$ 인 표본의 평균을 모으면 훨씬 좁게 모입니다.`, [
          { type: "plot", id: "d2", plane: "pl", points: sample(bell(se), xr[0], xr[1], { n: 130 }), color: C.main, width: 5, drawSec: 1.5 },
          { type: "vline", id: "vm", plane: "pl", x: m, from: 0, to: 1.1, dashed: true, color: C.hot, label: `$${nf(m)}$` },
        ]),
        beat(8, "중심은 그대로이고 흩어짐만 표본 크기만큼 줄어듭니다.", [
          note("n1", 0, `E(\\bar X)=m=${nf(m)}`, { color: C.main, size: 36 }),
          note("n2", 1, `V(\\bar X)=\\frac{\\sigma^2}{n}=\\frac{${nf(s * s)}}{${nf(n)}}=${nf(variance)}`, { color: C.ok, size: 34 }),
        ]),
        beat(7, askMean ? `묻는 것은 평균이므로 $${nf(m)}$ 입니다.` : `묻는 것은 분산이므로 $${nf(variance)}$ 입니다.`, [
          noteText("ans", 2, `답  ${nf(askMean ? m : variance)}`, { size: 54, color: C.ok }),
        ]),
      ],
    };
  });

  /* ============================================================
     추가 유형 안무 (2026-08) — 생성기가 내보내지만 대응 빌더가 없던 kind 들.

     여기 있는 빌더는 모두 같은 모양이다:
       도입 안무(그 문항의 수치로 그린 진짜 그림) + 그 문항의 단계 카드
     마지막을 buildGeneric 에 넘기는 이유 — 학생이 볼 것은 개념 그림만이 아니라
     '내 문제의 풀이' 다. 그림은 왼쪽(ART), 단계는 오른쪽 카드로 나뉜다.

     주의: 이 유형들은 상당수가 객관식 개념 문항이라 viz 파라미터가 듬성듬성 온다
     ({kind:"calculus-area", belowAxis:true} 처럼). 그래서 모든 빌더는 값이 없을 때의
     대표값을 갖고, 있으면 그 값으로 그린다. 없는 값을 지어내 라벨로 박지는 않는다.
     ============================================================ */

  /* ---------- 개념 그림 영역 helper (ART 안에서만 논다) ----------
     note() 를 쓰지 않는 이유: note 는 x=1200 고정이라 오른쪽 단계 카드와 겹친다. */
  const gpl = (xr, yr, opts) => artPlane(xr, yr, opts);
  const gcrv = (id, pts, color, o) =>
    Object.assign({ type: "plot", id, plane: "gpl", points: pts, color, width: 5, drawSec: 1.2 }, o || {});
  const gseg = (id, from, to, color, o) =>
    Object.assign({ type: "seg", id, plane: "gpl", from, to, color, width: 4 }, o || {});
  const gpt = (id, at, color, o) =>
    Object.assign({ type: "point", id, plane: "gpl", at, r: 12, color }, o || {});
  const gfill = (id, pts, color, opacity) =>
    ({ type: "fill", id, plane: "gpl", points: pts, color, opacity: opacity ?? 0.28 });
  const gpoly = (id, pts, color, o) =>
    Object.assign({ type: "polygon", id, plane: "gpl", points: pts, stroke: color, width: 3.5 }, o || {});
  const gtex = (id, at, tex, color, size) =>
    ({ type: "glabel", id, plane: "gpl", at, tex, size: size || 32, color: color || C.ink });
  /* 그림 아래 '설명 띠'. 좌표평면은 ART(y 165~855)를 꽉 채우므로, 식을 평면 안
     화면좌표에 두면 눈금·축·곡선과 겹친다(실제로 x축 위에 식이 걸쳤다).
     그래서 설명은 평면 **아래** 정해진 두 줄에만 놓는다. 오른쪽 단계 카드는
     x≥1000 이라 이 띠와도 겹치지 않는다. */
  // ART 는 아래쪽에서 const 로 선언된다 — 모듈 로드 시점에 읽으면 TDZ 로 죽는다.
  // 빌더는 build() 때 돌므로 그때 값을 읽도록 함수로 둔다.
  const capX = () => ART.x + ART.w / 2;
  const capY = (line) => 902 + line * 80;
  const cap = (id, line, tex, color, size) =>
    ({ type: "glabel", id, at: [capX(), capY(line)], tex, size: size || 36, color: color || C.ink });
  const capText = (id, line, text, color, size) =>
    ({ type: "glabel", id, at: [capX(), capY(line)], text, size: size || 32, color: color || C.mute });

  /** 오름차순 계수 배열 → 함수/도함수. webgen 의 coefficients 는 [상수, x, x², …] 순이다. */
  const polyOf = (cs) => (x) => (cs || []).reduce((s, c, i) => s + c * Math.pow(x, i), 0);
  const dpolyOf = (cs) => (x) => (cs || []).reduce((s, c, i) => (i ? s + i * c * Math.pow(x, i - 1) : s), 0);
  /** 구간에서 실제 y 폭을 재서 여백을 붙인 세로 범위 (곡선이 화면 밖으로 안 나가게) */
  const yFit = (f, xr, opts) => {
    opts = opts || {};
    const ys = sample(f, xr[0], xr[1], { n: 70 }).map((p) => p[1]);
    if (!ys.length) return [-1, 1];
    let lo = Math.min(...ys), hi = Math.max(...ys);
    if (opts.keepZero !== false) { lo = Math.min(lo, 0); hi = Math.max(hi, 0); }
    const m = Math.max(0.8, (hi - lo) * (opts.pad ?? 0.16));
    return [lo - m, hi + m];
  };
  /** 점 (x0,f(x0)) 에서 기울기 m 인 직선의 양 끝 — 접선·할선 공용 */
  const lineAt = (x0, y0, m, half) => [[x0 - half, y0 - m * half], [x0 + half, y0 + m * half]];

  /** 도입 안무 + 그 문항의 단계 카드. 단계가 없으면 그림만이라도 남긴다. */
  function withSteps(id, introBeats, ctx) {
    const sc = buildGeneric(ctx || {}, { introBeats });
    return { id, beats: sc ? sc.beats : introBeats };
  }

  /* ---------- 미분: 접선·평균변화율 계열 ----------
     q,l,c 는 f(x)=qx²+lx+c 규약이다 (실제 발문으로 확인: "곡선 y=2x²+2x+2"). */
  function quadBeats(v, opts) {
    opts = opts || {};
    const q = v.q ?? 1, l = v.l ?? 0, c = v.c ?? 0;
    const f = (x) => q * x * x + l * x + c;
    const df = (x) => 2 * q * x + l;
    const tex = head(term(q, "x^2") + term(l, "x") + term(c, "")) || "0";
    return { f, df, tex, deg: q === 0 ? 1 : 2 };
  }

  /* 접선의 기울기 = 미분계수 */
  register("calculus-tangent", (v, ctx) => {
    const { f, df, tex } = quadBeats(v);
    const x0 = v.point ?? 0;
    const y0 = v.y ?? f(x0);
    const m = v.slope ?? df(x0);
    const xr = [x0 - 3.4, x0 + 3.4];
    const yr = yFit(f, xr);
    const half = Math.min(2.6, (xr[1] - xr[0]) / 2.4);
    return withSteps("sol-calc-tangent", [
      beat(6, `먼저 곡선 $y=${tex}$ 를 그립니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        cap("ft", 0, `y=${tex}`, C.main, 34),
      ]),
      beat(6, `기울기를 물어본 자리는 $x=${nf(x0)}$ 한 점입니다.`, [
        { type: "vline", id: "vx", plane: "gpl", x: x0, from: yr[0], to: y0, dashed: true, color: C.mute },
        gpt("p", [x0, y0], C.hot, { label: `$(${nf(x0)},\\,${nf(y0)})$` }),
      ]),
      beat(8, `그 점에 접선을 대면 기울기가 $${nf(m)}$ 입니다 — 이게 미분계수입니다.`, [
        gseg("tan", ...lineAt(x0, y0, m, half), C.hot, { width: 5 }),
        // 기울기 삼각형 — '얼마나 가파른가' 를 숫자가 아니라 모양으로 보여 준다
        gseg("dx", [x0, y0], [x0 + 1, y0], C.ok, { width: 3, dashed: true }),
        gseg("dy", [x0 + 1, y0], [x0 + 1, y0 + m], C.ok, { width: 3, dashed: true }),
        gtex("ml", [x0 + 1.25, y0 + m / 2], `${nf(m)}`, C.ok, 30),
      ]),
    ], ctx);
  });

  /* 평균변화율 = 할선의 기울기 */
  register("calculus-secant", (v, ctx) => {
    const { f, tex } = quadBeats(v);
    const a = v.a ?? -1, b = v.b ?? 1;
    const lo = Math.min(a, b), hi = Math.max(a, b);
    const span = Math.max(1, hi - lo);
    const xr = [lo - span * 0.6, hi + span * 0.6];
    const yr = yFit(f, xr);
    const avg = (f(hi) - f(lo)) / (hi - lo || 1);
    return withSteps("sol-calc-secant", [
      beat(6, `곡선 $y=${tex}$ 위에서 구간 $[${nf(lo)},\\,${nf(hi)}]$ 를 봅니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, "구간의 두 끝점을 찍습니다.", [
        gpt("pa", [lo, f(lo)], C.hot),
        gpt("pb", [hi, f(hi)], C.hot),
        { type: "vline", id: "va", plane: "gpl", x: lo, from: yr[0], to: f(lo), dashed: true, color: C.mute },
        { type: "vline", id: "vb", plane: "gpl", x: hi, from: yr[0], to: f(hi), dashed: true, color: C.mute },
      ]),
      beat(8, `두 점을 이은 직선의 기울기가 평균변화율 $${nf(avg)}$ 입니다.`, [
        gseg("sec", [lo, f(lo)], [hi, f(hi)], C.hot, { width: 5 }),
        // 세로 변화량 ÷ 가로 변화량 을 직각삼각형으로 — 분수의 뜻이 그림에 있다
        gseg("dx", [lo, f(lo)], [hi, f(lo)], C.ok, { width: 3.5, dashed: true }),
        gseg("dy", [hi, f(lo)], [hi, f(hi)], C.ok, { width: 3.5, dashed: true }),
        gtex("dxl", [(lo + hi) / 2, f(lo) - (yr[1] - yr[0]) * 0.07], `\\Delta x=${nf(hi - lo)}`, C.ok, 28),
        gtex("dyl", [hi + (xr[1] - xr[0]) * 0.09, (f(lo) + f(hi)) / 2], `\\Delta y=${nf(f(hi) - f(lo))}`, C.ok, 28),
      ]),
    ], ctx);
  });

  /* 평균값 정리 — 할선과 평행한 접선이 구간 안에 반드시 있다 */
  register("calculus-mvt", (v, ctx) => {
    const { f, df, tex } = quadBeats(v);
    const a = v.a ?? -1, b = v.b ?? 2;
    const lo = Math.min(a, b), hi = Math.max(a, b);
    const avg = v.average ?? (f(hi) - f(lo)) / (hi - lo || 1);
    // meanPoint 가 오면 그 값을, 없으면 이차함수의 성질상 중점이 답이다
    const cx = v.meanPoint ?? (lo + hi) / 2;
    const xr = [lo - 0.9, hi + 0.9];
    const yr = yFit(f, xr);
    return withSteps("sol-calc-mvt", [
      beat(6, `곡선 $y=${tex}$ 와 구간 $[${nf(lo)},\\,${nf(hi)}]$ 입니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        gpt("pa", [lo, f(lo)], C.mute, { r: 11 }),
        gpt("pb", [hi, f(hi)], C.mute, { r: 11 }),
      ]),
      beat(7, `양 끝을 이은 할선의 기울기는 $${nf(avg)}$ 입니다.`, [
        gseg("sec", [lo, f(lo)], [hi, f(hi)], C.main, { width: 5, dashed: true }),
      ]),
      beat(8, `구간 안 어딘가($x=${nf(cx)}$)에 이 할선과 나란한 접선이 반드시 있습니다.`, [
        gseg("tan", ...lineAt(cx, f(cx), df(cx), Math.min(1.8, (hi - lo) / 1.6)), C.hot, { width: 5 }),
        gpt("pc", [cx, f(cx)], C.hot),
        { type: "vline", id: "vc", plane: "gpl", x: cx, from: yr[0], to: f(cx), dashed: true, color: C.hot },
        gtex("cl", [cx, yr[0] + (yr[1] - yr[0]) * 0.07], `c=${nf(cx)}`, C.hot, 30),
      ]),
    ], ctx);
  });

  /* 다항함수의 도함수 */
  register("calculus-polynomial", (v, ctx) => {
    const cs = (v.coefficients && v.coefficients.length) ? v.coefficients : [0, 0, 1];
    const f = polyOf(cs), df = dpolyOf(cs);
    const x0 = v.point ?? 0;
    const m = v.slope ?? df(x0);
    const xr = [x0 - 2.8, x0 + 2.8];
    const yr = yFit(f, xr);
    const tex = head(cs.map((c, i) => term(c, i === 0 ? "" : i === 1 ? "x" : `x^${i}`)).reverse().join("")) || "0";
    return withSteps("sol-calc-poly", [
      beat(6, `주어진 다항함수 $y=${tex}$ 입니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, "도함수는 각 항의 차수를 하나씩 내리면서 계수에 곱해 만듭니다.", [
        gcrv("df", sample(df, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.ok, { dashed: true, width: 4 }),
        gtex("dfl", [xr[0] + (xr[1] - xr[0]) * 0.2, yr[0] + (yr[1] - yr[0]) * 0.12], "y=f'(x)", C.ok, 30),
      ]),
      beat(7, `$x=${nf(x0)}$ 에서 도함수의 값이 곧 그 점 접선의 기울기 $${nf(m)}$ 입니다.`, [
        gpt("p", [x0, f(x0)], C.hot),
        gseg("tan", ...lineAt(x0, f(x0), m, 1.5), C.hot, { width: 5 }),
        gpt("pd", [x0, m], C.ok, { r: 11, label: `$f'(${nf(x0)})=${nf(m)}$` }),
      ]),
    ], ctx);
  });

  /* 거듭제곱의 미분 */
  register("calculus-power", (v, ctx) => {
    const k = v.coefficient ?? 1, n = v.n ?? 2;
    const f = (x) => k * Math.pow(x, n);
    const df = (x) => k * n * Math.pow(x, n - 1);
    const x0 = v.point ?? 1;
    const xr = [-Math.max(2, Math.abs(x0) + 1.4), Math.max(2, Math.abs(x0) + 1.4)];
    const yr = yFit(f, xr, { pad: 0.2 });
    // -1x^2 / 1x^2 처럼 읽히지 않게 계수를 정리하고, 지수 0 은 아예 떼어 낸다
    const powTex = (c, e) => `${c === 1 ? "" : c === -1 ? "-" : nf(c)}${e === 0 ? (c === 1 || c === -1 ? "1" : "") : e === 1 ? "x" : `x^{${nf(e)}}`}`;
    return withSteps("sol-calc-power", [
      beat(6, `$y=${powTex(k, n)}$ 의 그래프입니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 100, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(8, `미분하면 지수가 하나 내려오고 지수는 $1$ 줄어듭니다.`, [
        cap("rule", 0, `(${powTex(k, n)})'=${powTex(k * n, n - 1)}`, C.ok, 40),
      ]),
      beat(7, `$x=${nf(x0)}$ 에서 접선의 기울기는 $${nf(df(x0))}$ 입니다.`, [
        gpt("p", [x0, f(x0)], C.hot),
        gseg("tan", ...lineAt(x0, f(x0), df(x0), Math.max(0.9, (xr[1] - xr[0]) / 5)), C.hot, { width: 5 }),
      ]),
    ], ctx);
  });

  /* 미분계수의 정의 — 할선이 접선으로 수렴한다 */
  register("calculus-definition", (v, ctx) => {
    const x0 = v.point ?? 0, m = v.slope ?? 1;
    // 그 점에서 기울기가 m 인 매끈한 곡선 하나를 세운다 (수치는 viz 가 준 것만 쓴다)
    const f = (x) => m * (x - x0) + 0.55 * (x - x0) * (x - x0);
    const xr = [x0 - 3, x0 + 3];
    const yr = yFit(f, xr, { pad: 0.2 });
    const hs = [2.0, 1.2, 0.6];
    return withSteps("sol-calc-definition", [
      beat(6, `$x=${nf(x0)}$ 근처의 곡선을 봅니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        gpt("p0", [x0, f(x0)], C.hot),
      ]),
      beat(8, "조금 떨어진 점과 이으면 할선이 생깁니다 — 기울기는 차분몫입니다.", [
        ...hs.map((h, i) => gseg(`s${i}`, [x0, f(x0)], [x0 + h, f(x0 + h)], C.mute,
          { width: 3, dashed: true })),
        ...hs.map((h, i) => gpt(`q${i}`, [x0 + h, f(x0 + h)], C.mute, { r: 9 })),
        cap("q", 0, "\\frac{f(x_0+h)-f(x_0)}{h}", C.mute, 36),
      ]),
      beat(8, `$h$ 를 $0$ 으로 줄이면 할선이 접선으로 붙고, 그 기울기가 $${nf(m)}$ 입니다.`, [
        gseg("tan", ...lineAt(x0, f(x0), m, 2.4), C.hot, { width: 5 }),
        cap("d", 0, `f'(${nf(x0)})=${nf(m)}`, C.ok, 44),
      ]),
    ], ctx);
  });

  /* 접선의 방정식 */
  register("calculus-line", (v, ctx) => {
    const x0 = v.point ?? 0, y0 = v.y ?? 0, m = v.slope ?? 1;
    const f = (x) => y0 + m * (x - x0) + 0.5 * (x - x0) * (x - x0);
    const xr = [x0 - 3, x0 + 3];
    const yr = yFit(f, xr, { pad: 0.2 });
    return withSteps("sol-calc-line", [
      beat(6, `접점 $(${nf(x0)},\\,${nf(y0)})$ 을 지나는 곡선입니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        gpt("p", [x0, y0], C.hot),
      ]),
      beat(7, `그 점에서의 기울기는 $${nf(m)}$ 입니다.`, [
        gseg("tan", ...lineAt(x0, y0, m, 2.6), C.hot, { width: 5 }),
      ]),
      beat(8, "접점과 기울기를 알면 직선의 방정식이 바로 나옵니다.", [
        // y - y0 = m(x - x0) 를 부호까지 정리해 쓴다 (y0·x0 이 음수면 +로 뒤집힌다)
        cap("eq", 0, `y${y0 >= 0 ? "-" : "+"}${nf(Math.abs(y0))}`
          + `=${nf(m)}(x${x0 >= 0 ? "-" : "+"}${nf(Math.abs(x0))})`, C.ok, 40),
      ]),
    ], ctx);
  });

  /* ---------- 미분가능성 계열 ---------- */
  /** 꺾인 그래프 한 벌 — 왼쪽 기울기 / 오른쪽 기울기 */
  function kinkBeats(x0, ml, mr, y0, story) {
    const span = 2.6;
    const fl = (x) => y0 + ml * (x - x0);
    const fr = (x) => y0 + mr * (x - x0);
    const xr = [x0 - span, x0 + span];
    const ys = [fl(xr[0]), fr(xr[1]), y0];
    const pad = Math.max(1.2, (Math.max(...ys) - Math.min(...ys)) * 0.25);
    const yr = [Math.min(...ys) - pad, Math.max(...ys) + pad];
    return [
      beat(6, story.a, [
        gpl(xr, yr),
        gcrv("L", sample(fl, xr[0], x0, { n: 30 }), C.main),
        gcrv("R", sample(fr, x0, xr[1], { n: 30 }), C.ok),
        gpt("p", [x0, y0], C.hot),
      ]),
      beat(7, story.b, [
        gseg("tl", [x0 - 1.5, fl(x0 - 1.5)], [x0, y0], C.main, { width: 7 }),
        gseg("tr", [x0, y0], [x0 + 1.5, fr(x0 + 1.5)], C.ok, { width: 7 }),
        gtex("ll", [x0 - 1.7, fl(x0 - 1.7)], `${nf(ml)}`, C.main, 30),
        gtex("rl", [x0 + 1.7, fr(x0 + 1.7)], `${nf(mr)}`, C.ok, 30),
      ]),
      beat(8, story.c, [
        { type: "vline", id: "vx", plane: "gpl", x: x0, from: yr[0], to: yr[1], dashed: true, color: C.hot },
        cap("verdict", 0, story.tex, story.ok ? C.ok : C.hot, 38),
      ]),
    ];
  }

  /* 좌우 기울기가 다르다 — 뾰족점 */
  register("calculus-cusp", (v, ctx) => {
    const x0 = v.point ?? 0;
    return withSteps("sol-calc-cusp", kinkBeats(x0, -1, 1, 0, {
      a: `$y=|x${x0 >= 0 ? "-" : "+"}${nf(Math.abs(x0))}|$ 처럼 $x=${nf(x0)}$ 에서 꺾이는 그래프입니다.`,
      b: "왼쪽에서 온 기울기와 오른쪽에서 온 기울기가 다릅니다.",
      c: "끊기지는 않았지만(연속) 접선이 하나로 정해지지 않습니다 — 미분불가능입니다.",
      tex: "f'(" + nf(x0) + ")\\ \\text{없음}", ok: false,
    }), ctx);
  });

  /* 좌우 기울기가 같다 — 매끄럽게 이어진다 */
  register("calculus-smooth", (v, ctx) => {
    const m = v.slope ?? 1, y0 = v.value ?? 0;
    return withSteps("sol-calc-smooth", kinkBeats(0, m, m, y0, {
      a: "두 조각이 한 점에서 만나는 함수입니다.",
      b: `왼쪽 기울기도 $${nf(m)}$, 오른쪽 기울기도 $${nf(m)}$ 입니다.`,
      c: "값도 이어지고 기울기도 같으므로 그 점에서 미분가능합니다.",
      tex: `f'(0)=${nf(m)}`, ok: true,
    }), ctx);
  });

  /* 좌우 미분계수가 다르면 미분계수가 없다 */
  register("calculus-piecewise-slope", (v, ctx) => {
    const x0 = v.point ?? 0;
    const ml = v.leftSlope ?? 1;
    const mr = v.rightSlope ?? (v.leftSlope ?? 1);
    const same = Math.abs(ml - mr) < 1e-9;
    return withSteps("sol-calc-pw-slope", kinkBeats(x0, ml, mr, v.value ?? 0, {
      a: `$x=${nf(x0)}$ 을 경계로 두 식이 갈리는 함수입니다.`,
      b: `왼쪽 기울기 $${nf(ml)}$, 오른쪽 기울기 $${nf(mr)}$ 입니다.`,
      c: same ? "두 기울기가 같으므로 그 점에서도 미분가능합니다."
              : "두 기울기가 다르므로 미분계수가 하나로 정해지지 않습니다.",
      tex: same ? `f'(${nf(x0)})=${nf(ml)}` : `${nf(ml)}\\ne${nf(mr)}`, ok: same,
    }), ctx);
  });

  /* 이어 붙는 값 — 연속이 먼저다 */
  register("calculus-piecewise-value", (v, ctx) => {
    const x0 = v.point ?? 0, ml = v.leftSlope ?? 1;
    return withSteps("sol-calc-pw-value", kinkBeats(x0, ml, ml, 0, {
      a: `$x=${nf(x0)}$ 에서 두 조각이 만나야 합니다.`,
      b: "왼쪽에서 다가간 값과 오른쪽에서 다가간 값이 같아야 끊기지 않습니다.",
      c: "먼저 값을 맞춰 연속으로 만든 뒤에야 기울기를 따질 수 있습니다.",
      tex: `\\lim_{x\\to ${nf(x0)}^-}f=\\lim_{x\\to ${nf(x0)}^+}f`, ok: true,
    }), ctx);
  });

  /* 미분가능하면 연속이다 */
  register("calculus-differentiability", (v, ctx) => {
    const x0 = v.point ?? 0, m = v.slope ?? 1;
    const f = (x) => m * (x - x0) + 0.4 * (x - x0) * (x - x0);
    const xr = [x0 - 2.8, x0 + 2.8];
    const yr = yFit(f, xr, { pad: 0.25 });
    return withSteps("sol-calc-diffable", [
      beat(6, `$x=${nf(x0)}$ 에서 미분가능한 함수를 그려 봅니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, "접선이 하나로 정해진다는 것은 그 점이 끊기지 않았다는 뜻입니다.", [
        gpt("p", [x0, f(x0)], C.hot),
        gseg("tan", ...lineAt(x0, f(x0), m, 2.2), C.hot, { width: 5 }),
      ]),
      beat(8, "그래서 미분가능하면 반드시 연속입니다 (거꾸로는 성립하지 않습니다).", [
        ...arrow("impl", [430, 902], [690, 902], C.ok, { width: 5, head: 26 }),
        { type: "glabel", id: "l1", at: [270, 902], text: "미분가능", size: 34, color: C.ok },
        { type: "glabel", id: "l2", at: [800, 902], text: "연속", size: 34, color: C.ok },
        // 역은 성립하지 않는다 — 되돌아오는 화살표에 ✕ 를 얹어 한눈에 보인다
        ...arrow("nimpl", [690, 982], [430, 982], C.mute, { width: 4, head: 22 }),
        { type: "glabel", id: "xm", at: [capX(), 982], text: "✕", size: 40, color: C.hot },
      ]),
    ], ctx);
  });

  /* 불연속이면 미분불가능 */
  register("calculus-discontinuity", (v, ctx) => {
    const x0 = v.point ?? 0;
    const jump = 2.2;
    const fl = (x) => 0.6 * (x - x0);
    const fr = (x) => 0.6 * (x - x0) + jump;
    const xr = [x0 - 2.8, x0 + 2.8];
    const yr = [-3.4, 4.4];
    return withSteps("sol-calc-discont", [
      beat(6, `$x=${nf(x0)}$ 에서 그래프가 끊어져 있습니다.`, [
        gpl(xr, yr),
        gcrv("L", sample(fl, xr[0], x0 - 0.02, { n: 30 }), C.main),
        gcrv("R", sample(fr, x0 + 0.02, xr[1], { n: 30 }), C.main),
        // 빈 동그라미 = 그 값을 갖지 않는다 (배경색 채움이 아니라 테두리만)
        gpoly("hole", ovalPts(x0, fl(x0), 0.13, 0.19, 20), C.hot, { width: 4 }),
        gpt("dot", [x0, fr(x0)], C.hot, { r: 11 }),
      ]),
      beat(7, "왼쪽에서 다가간 값과 오른쪽에서 다가간 값이 다릅니다.", [
        { type: "brace", id: "jp", plane: "gpl", from: [x0 + 0.35, fl(x0)], to: [x0 + 0.35, fr(x0)],
          label: `$${nf(jump)}$ 만큼 뜀`, color: C.hot },
      ]),
      beat(8, "끊긴 자리에는 접선을 댈 수 없습니다 — 불연속이면 미분불가능입니다.", [
        cap("v", 0, "\\text{불연속}\\Rightarrow\\text{미분불가능}", C.hot, 36),
      ]),
    ], ctx);
  });

  /* ---------- 증감·극값 계열 ---------- */
  /* 부호표 — 도함수의 부호가 바뀌는 자리 */
  register("calculus-sign-chart", (v, ctx) => {
    const r = v.r ?? (v.roots && v.roots.length ? Math.abs(v.roots[1]) : 2);
    const s = v.scale ?? 1;
    const f = (x) => s * ((x * x * x) / 3 - r * r * x);
    const df = (x) => s * (x * x - r * r);
    const xr = [-r - 1.6, r + 1.6];
    const yr = yFit(f, xr, { pad: 0.2 });
    return withSteps("sol-calc-signchart", [
      beat(6, "도함수가 $0$ 이 되는 자리를 먼저 찾습니다.", [
        gpl(xr, yr),
        gcrv("df", sample(df, xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.ok, { dashed: true, width: 4 }),
        gpt("r1", [-r, 0], C.hot, { r: 13 }),
        gpt("r2", [r, 0], C.hot, { r: 13 }),
        gtex("dl", [xr[0] + 0.7, yr[0] + (yr[1] - yr[0]) * 0.12], "y=f'(x)", C.ok, 28),
      ]),
      beat(8, "그 자리를 경계로 도함수의 부호가 갈립니다 — 양수면 증가, 음수면 감소입니다.", [
        gfill("z1", [[xr[0], yr[0]], [-r, yr[0]], [-r, yr[1]], [xr[0], yr[1]]], C.ok, 0.12),
        gfill("z2", [[-r, yr[0]], [r, yr[0]], [r, yr[1]], [-r, yr[1]]], C.hot, 0.12),
        gfill("z3", [[r, yr[0]], [xr[1], yr[0]], [xr[1], yr[1]], [r, yr[1]]], C.ok, 0.12),
        { type: "glabel", id: "s1", plane: "gpl", at: [(xr[0] - r) / 2, yr[1] - (yr[1] - yr[0]) * 0.09], text: "＋", size: 50, color: C.ok },
        { type: "glabel", id: "s2", plane: "gpl", at: [0, yr[1] - (yr[1] - yr[0]) * 0.09], text: "－", size: 50, color: C.hot },
        { type: "glabel", id: "s3", plane: "gpl", at: [(xr[1] + r) / 2, yr[1] - (yr[1] - yr[0]) * 0.09], text: "＋", size: 50, color: C.ok },
      ]),
      beat(8, "원래 함수는 그 부호를 따라 올라갔다 내려갔다 합니다.", [
        gcrv("f", sample(f, xr[0], xr[1], { n: 100, yMin: yr[0], yMax: yr[1] }), C.main),
        gpt("mx", [-r, f(-r)], C.ok, { r: 13, label: "극대" }),
        gpt("mn", [r, f(r)], C.hot, { r: 13, label: "극소" }),
      ]),
    ], ctx);
  });

  /* 극값 */
  register("calculus-extrema", (v, ctx) => {
    // 두 형태가 온다: 삼차(r, scale) 또는 꼭짓점형 이차(vertexX, constant, scale)
    if (v.vertexX !== undefined) {
      const s = v.scale ?? 1, vx = v.vertexX, k = v.constant ?? 0;
      const f = (x) => s * (x - vx) * (x - vx) + k;
      const xr = [vx - 3.2, vx + 3.2];
      const yr = yFit(f, xr, { pad: 0.2 });
      return withSteps("sol-calc-extrema", [
        beat(6, `꼭짓점형 $y=${nf(s)}(x${vx >= 0 ? "-" : "+"}${nf(Math.abs(vx))})^2${sg(k)}$ 입니다.`, [
          gpl(xr, yr),
          gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        ]),
        beat(7, `제곱항은 $x=${nf(vx)}$ 일 때 $0$ 으로 가장 작아집니다.`, [
          { type: "vline", id: "vx", plane: "gpl", x: vx, from: yr[0], to: yr[1], dashed: true, color: C.mute },
          gpt("p", [vx, k], C.hot, { r: 14 }),
        ]),
        beat(7, `그때 남는 상수항 $${nf(k)}$ 이 ${s >= 0 ? "극솟값" : "극댓값"}입니다.`, [
          gseg("h", [xr[0], k], [xr[1], k], C.ok, { width: 3.5, dashed: true }),
          gtex("kl", [xr[0] + 0.6, k + (yr[1] - yr[0]) * 0.07], `${nf(k)}`, C.ok, 34),
        ]),
      ], ctx);
    }
    const r = v.r ?? 1, s = v.scale ?? 1;
    const f = (x) => s * x * x * x - 3 * s * r * r * x;
    const xr = [-r - 1.7, r + 1.7];
    const yr = yFit(f, xr, { pad: 0.2 });
    return withSteps("sol-calc-extrema", [
      beat(6, `삼차함수 $y=${nf(s)}x^3${sg(-3 * s * r * r)}x$ 를 그립니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 100, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, `도함수가 $0$ 이 되는 $x=\\pm${nf(r)}$ 에서 방향이 바뀝니다.`, [
        gpt("m1", [-r, f(-r)], C.ok, { r: 14 }),
        gpt("m2", [r, f(r)], C.hot, { r: 14 }),
        { type: "vline", id: "v1", plane: "gpl", x: -r, from: yr[0], to: f(-r), dashed: true, color: C.mute },
        { type: "vline", id: "v2", plane: "gpl", x: r, from: yr[0], to: f(r), dashed: true, color: C.mute },
      ]),
      beat(7, `그 자리의 함숫값이 극댓값 $${nf(f(-r))}$, 극솟값 $${nf(f(r))}$ 입니다.`, [
        gseg("h1", [xr[0], f(-r)], [-r, f(-r)], C.ok, { width: 3, dashed: true }),
        gseg("h2", [r, f(r)], [xr[1], f(r)], C.hot, { width: 3, dashed: true }),
        gtex("t1", [xr[0] + 0.55, f(-r) + (yr[1] - yr[0]) * 0.07], `${nf(f(-r))}`, C.ok, 32),
        gtex("t2", [xr[1] - 0.55, f(r) - (yr[1] - yr[0]) * 0.07], `${nf(f(r))}`, C.hot, 32),
      ]),
    ], ctx);
  });

  /* 그래프의 모양 — 도함수의 부호가 꼭짓점의 종류를 정한다 */
  register("calculus-graph-shape", (v, ctx) => {
    const s = v.scale ?? 1, sh = v.shift ?? 0;
    const up = v.derivativePositive !== false;
    const f = (x) => (up ? 1 : -1) * s * (x - sh) * (x - sh) * 0.5 + (v.vertexY ?? 0);
    const df = (x) => (up ? 1 : -1) * s * (x - sh);
    const xr = [sh - 3.2, sh + 3.2];
    const yr = yFit(f, xr, { pad: 0.2 });
    return withSteps("sol-calc-shape", [
      beat(6, `도함수가 $0$ 이 되는 자리는 $x=${nf(sh)}$ 입니다.`, [
        gpl(xr, yr),
        gcrv("df", sample(df, xr[0], xr[1], { n: 70, yMin: yr[0], yMax: yr[1] }), C.ok, { dashed: true, width: 4 }),
        gpt("r", [sh, 0], C.hot, { r: 13 }),
        gtex("dl", [xr[0] + 0.7, yr[0] + (yr[1] - yr[0]) * 0.12], "y=f'(x)", C.ok, 28),
      ]),
      beat(8, up ? "그 왼쪽은 음수, 오른쪽은 양수 — 감소하다 증가로 바뀝니다."
                 : "그 왼쪽은 양수, 오른쪽은 음수 — 증가하다 감소로 바뀝니다.", [
        gfill("zl", [[xr[0], yr[0]], [sh, yr[0]], [sh, yr[1]], [xr[0], yr[1]]], up ? C.hot : C.ok, 0.12),
        gfill("zr", [[sh, yr[0]], [xr[1], yr[0]], [xr[1], yr[1]], [sh, yr[1]]], up ? C.ok : C.hot, 0.12),
      ]),
      beat(7, up ? `그래서 $x=${nf(sh)}$ 에서 극소입니다.` : `그래서 $x=${nf(sh)}$ 에서 극대입니다.`, [
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        gpt("p", [sh, f(sh)], C.hot, { r: 14, label: up ? "극소" : "극대" }),
      ]),
    ], ctx);
  });

  /* 방정식의 실근 개수 = 수평선과의 교점 */
  register("calculus-equation", (v, ctx) => {
    const sh = v.shift ?? 0;
    const mn = v.minimum ?? -1, mx = v.maximum ?? 1;
    const k = v.k ?? 0;
    // 극솟값 mn, 극댓값 mx 를 갖는 삼차 모양
    const amp = Math.max(0.6, (mx - mn) / 4);
    const f = (x) => ((mx + mn) / 2) - amp * ((x - sh) * (x - sh) * (x - sh) / 3 - (x - sh));
    const xr = [sh - 3, sh + 3];
    const yr = yFit(f, xr, { pad: 0.25 });
    const cross = k > Math.min(mn, mx) && k < Math.max(mn, mx) ? 3 : 1;
    return withSteps("sol-calc-equation", [
      beat(6, `곡선의 극댓값은 $${nf(mx)}$, 극솟값은 $${nf(mn)}$ 입니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 100, yMin: yr[0], yMax: yr[1] }), C.main),
        gseg("hmx", [xr[0], mx], [xr[1], mx], C.mute, { width: 2.5, dashed: true }),
        gseg("hmn", [xr[0], mn], [xr[1], mn], C.mute, { width: 2.5, dashed: true }),
      ]),
      beat(8, `방정식의 실근은 곡선과 가로선 $y=${nf(k)}$ 이 만나는 자리입니다.`, [
        gseg("hk", [xr[0], k], [xr[1], k], C.hot, { width: 5 }),
        gtex("kl", [xr[1] - 0.5, k + (yr[1] - yr[0]) * 0.07], `y=${nf(k)}`, C.hot, 30),
      ]),
      beat(8, cross === 3 ? "가로선이 두 극값 사이를 지나면 만나는 점이 셋입니다."
                          : "가로선이 두 극값 밖에 있으면 만나는 점이 하나입니다.", [
        gfill("band", [[xr[0], mn], [xr[1], mn], [xr[1], mx], [xr[0], mx]], C.ok, 0.14),
        cap("cnt", 0, `\\text{실근 }${cross}\\text{개}`, C.ok, 40),
      ]),
    ], ctx);
  });

  /* 부등식이 항상 성립할 조건 — 최솟값이 기준선 위에 있으면 된다 */
  register("calculus-inequality", (v, ctx) => {
    const sh = v.shift ?? 0, r = v.r ?? 1;
    const f = (x) => (x - sh) * (x - sh) + r;
    const xr = [sh - 3.2, sh + 3.2];
    const yr = yFit(f, xr, { pad: 0.2 });
    return withSteps("sol-calc-inequality", [
      beat(6, "먼저 함수의 그래프를 그립니다.", [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, `가장 낮은 자리는 $x=${nf(sh)}$, 그때 값은 $${nf(r)}$ 입니다.`, [
        gpt("mn", [sh, r], C.hot, { r: 14 }),
        { type: "vline", id: "vx", plane: "gpl", x: sh, from: yr[0], to: r, dashed: true, color: C.mute },
      ]),
      beat(8, r >= 0 ? "그 최솟값이 $0$ 이상이므로 부등식이 항상 성립합니다."
                     : "그 최솟값이 $0$ 보다 작으므로 성립하지 않는 구간이 생깁니다.", [
        gseg("axis", [xr[0], 0], [xr[1], 0], C.ok, { width: 4 }),
        gfill("ok", [[xr[0], 0], [xr[1], 0], [xr[1], yr[1]], [xr[0], yr[1]]], C.ok, 0.1),
        cap("v", 0, `\\min f=${nf(r)}`, r >= 0 ? C.ok : C.hot, 40),
      ]),
    ], ctx);
  });

  /* ---------- 적분 계열 ---------- */
  /* 부정적분 — +C 는 위아래로 평행이동한 곡선족 */
  register("calculus-antiderivative", (v, ctx) => {
    const cs = (v.coefficients && v.coefficients.length) ? v.coefficients : null;
    const k = v.coefficient ?? 1, n = v.n ?? 1;
    const f = cs ? polyOf(cs) : (x) => k * Math.pow(x, n);
    // 원시함수 하나 (수치적분 대신 다항 규칙 그대로)
    const F = cs
      ? polyOf([0, ...cs.map((c, i) => c / (i + 1))])
      : (x) => (k / (n + 1)) * Math.pow(x, n + 1);
    const xr = [-2.6, 2.6];
    const yr = yFit((x) => F(x), xr, { pad: 0.45 });
    const Cs = [-(yr[1] - yr[0]) * 0.18, 0, (yr[1] - yr[0]) * 0.18];
    return withSteps("sol-calc-antideriv", [
      beat(6, "적분할 함수를 먼저 봅니다.", [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.mute, { dashed: true, width: 4 }),
        gtex("fl", [xr[0] + 0.7, yr[0] + (yr[1] - yr[0]) * 0.1], "y=f(x)", C.mute, 28),
      ]),
      beat(8, "미분해서 이 함수가 되는 곡선을 찾습니다 — 차수를 하나 올리고 그 수로 나눕니다.", [
        gcrv("F", sample(F, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        gtex("Fl", [xr[1] - 0.9, F(xr[1] * 0.8)], "y=F(x)", C.main, 28),
      ]),
      beat(8, "상수는 미분하면 사라지므로, 위아래로 옮긴 곡선도 모두 답입니다 — 그래서 $+C$ 입니다.", [
        ...Cs.map((dc, i) => gcrv(`Fc${i}`, sample((x) => F(x) + dc, xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }),
          i === 1 ? C.main : C.hot, { width: 4, dashed: i !== 1 })),
        ...arrow("up", [880, 400], [880, 300], C.hot, { width: 4, head: 20 }),
        ...arrow("dn", [880, 640], [880, 740], C.hot, { width: 4, head: 20 }),
        cap("C", 0, "\\int f(x)\\,dx=F(x)+C", C.ok, 38),
      ]),
    ], ctx);
  });

  /* 정적분의 부호 있는 넓이 */
  register("calculus-area", (v, ctx) => {
    const a = v.left ?? 0, b = v.right ?? (v.width ? a + v.width : 3);
    const h = v.height ?? 2;
    const below = !!v.belowAxis, crossing = !!v.crossing;
    const f = crossing
      ? (x) => h * Math.sin(((x - a) / Math.max(0.6, b - a)) * Math.PI * 2)
      : (x) => (below ? -Math.abs(h) : Math.abs(h)) * (0.55 + 0.35 * Math.sin(((x - a) / Math.max(0.6, b - a)) * Math.PI));
    const xr = [a - 0.8, b + 0.8];
    const yr = yFit(f, xr, { pad: 0.3 });
    const mid = (a + b) / 2;
    const region = (x0, x1) => [[x0, 0], ...sample(f, x0, x1, { n: 40 }), [x1, 0]];
    return withSteps("sol-calc-area", [
      beat(6, `구간 $[${nf(a)},\\,${nf(b)}]$ 에서 곡선을 그립니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        { type: "vline", id: "va", plane: "gpl", x: a, from: yr[0], to: yr[1], dashed: true, color: C.mute },
        { type: "vline", id: "vb", plane: "gpl", x: b, from: yr[0], to: yr[1], dashed: true, color: C.mute },
      ]),
      crossing
        ? beat(8, "곡선이 축을 가로지르면 위쪽 조각과 아래쪽 조각이 갈립니다.", [
            gfill("r1", region(a, mid), C.ok, 0.32),
            gfill("r2", region(mid, b), C.hot, 0.32),
            { type: "glabel", id: "p1", plane: "gpl", at: [(a + mid) / 2, yr[1] * 0.35], text: "＋", size: 52, color: C.ok },
            { type: "glabel", id: "p2", plane: "gpl", at: [(mid + b) / 2, yr[0] * 0.35], text: "－", size: 52, color: C.hot },
          ])
        : beat(8, below ? "곡선이 축 아래에 있습니다." : "곡선이 축 위에 있습니다.", [
            gfill("r1", region(a, b), below ? C.hot : C.ok, 0.32),
          ]),
      beat(8, "정적분은 축 위를 $+$, 축 아래를 $-$ 로 세어 더한 값입니다.", [
        cap("v", 0, `\\int_{${nf(a)}}^{${nf(b)}}f(x)\\,dx`, C.ink, 40),
        capText("note", 1, below ? "축 아래 → 음수" : crossing ? "위 − 아래" : "축 위 → 양수",
          below || crossing ? C.hot : C.ok, 32),
      ]),
    ], ctx);
  });

  /* 정적분의 성질 (구간·상수배·합) */
  register("calculus-definite", (v, ctx) => {
    const a = v.a ?? 0, b = v.b ?? 3;
    const lo = Math.min(a, b), hi = Math.max(a, b);
    const h = v.height ?? 2;
    const f = (x) => h * (0.55 + 0.4 * Math.sin(((x - lo) / Math.max(0.6, hi - lo)) * Math.PI));
    const xr = [lo - 0.9, hi + 0.9];
    const yr = yFit(f, xr, { pad: 0.3 });
    const region = [[lo, 0], ...sample(f, lo, hi, { n: 44 }), [hi, 0]];
    return withSteps("sol-calc-definite", [
      beat(6, `아래끝 $${nf(lo)}$, 위끝 $${nf(hi)}$ 사이를 봅니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 90, yMin: yr[0], yMax: yr[1] }), C.main),
        { type: "vline", id: "va", plane: "gpl", x: lo, from: 0, to: f(lo), color: C.mute, dashed: true },
        { type: "vline", id: "vb", plane: "gpl", x: hi, from: 0, to: f(hi), color: C.mute, dashed: true },
      ]),
      beat(7, v.value !== undefined
        ? `이 넓이가 $${nf(v.value)}$ 입니다.`
        : "이 구간의 정적분이 곧 이 넓이입니다.", [
        gfill("r", region, C.ok, 0.32),
        { type: "brace", id: "br", plane: "gpl", from: [lo, -0.001], to: [hi, -0.001],
          label: v.value !== undefined ? `$${nf(v.value)}$` : "", color: C.ok },
      ]),
      beat(8, "상수배는 밖으로 나오고, 합의 적분은 적분의 합입니다 — 넓이를 배로 늘리거나 포개는 일과 같습니다.", [
        cap("p1", 0, "\\int k f=k\\int f", C.main, 36),
        cap("p2", 1, "\\int (f+g)=\\int f+\\int g", C.ok, 36),
      ]),
    ], ctx);
  });

  /* 미적분의 기본정리 — F(b)-F(a) */
  register("calculus-fundamental", (v, ctx) => {
    const a = v.a ?? 0, b = v.b ?? 2;
    const lo = Math.min(a, b), hi = Math.max(a, b);
    const k = v.coefficient ?? 1;
    const f = (x) => 2 * k * x;                 // 발문 규약: 원시함수가 k x²
    const F = (x) => k * x * x + (v.constant ?? 0);
    const xr = [Math.min(lo, 0) - 0.8, hi + 0.8];
    const yr = yFit(f, xr, { pad: 0.25 });
    return withSteps("sol-calc-fundamental", [
      beat(6, `적분할 함수와 구간 $[${nf(lo)},\\,${nf(hi)}]$ 입니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, "이 넓이를 직접 세지 않고 원시함수를 씁니다.", [
        gfill("r", [[lo, 0], ...sample(f, lo, hi, { n: 40 }), [hi, 0]], C.ok, 0.3),
        { type: "vline", id: "va", plane: "gpl", x: lo, from: 0, to: f(lo), color: C.mute, dashed: true },
        { type: "vline", id: "vb", plane: "gpl", x: hi, from: 0, to: f(hi), color: C.mute, dashed: true },
      ]),
      beat(8, `위끝의 원시함수값에서 아래끝의 원시함수값을 뺍니다 — 답은 $${nf(F(hi) - F(lo))}$ 입니다.`, [
        cap("ftc", 0, `\\int_{${nf(lo)}}^{${nf(hi)}}f=F(${nf(hi)})-F(${nf(lo)})`, C.main, 34),
        cap("val", 1, `=${nf(F(hi))}-${nf(F(lo))}=${nf(F(hi) - F(lo))}`, C.ok, 38),
      ]),
    ], ctx);
  });

  /* 리만합 — 직사각형을 촘촘히 */
  register("calculus-riemann", (v, ctx) => {
    const a = v.a ?? 0, b = v.b ?? 3;
    const lo = Math.min(a, b), hi = Math.max(a, b);
    const f = (x) => 0.28 * (x - lo) * (x - lo) + 1.1;
    const xr = [lo - 0.7, hi + 0.7];
    const yr = yFit(f, xr, { pad: 0.25 });
    // 굵은 분할 → 촘촘한 분할. 직사각형은 polygon 으로 그린다.
    const bars = (n, id, color) => {
      const w = (hi - lo) / n, out = [];
      for (let i = 0; i < n; i++) {
        const x0 = lo + i * w, y = f(x0 + w / 2);
        out.push(gpoly(`${id}${i}`, [[x0, 0], [x0 + w, 0], [x0 + w, y], [x0, y]], color,
          { fill: color, fillOpacity: 0.22, width: 2.5 }));
      }
      return out;
    };
    return withSteps("sol-calc-riemann", [
      beat(6, `구간 $[${nf(lo)},\\,${nf(hi)}]$ 의 곡선 아래 넓이를 재려 합니다.`, [
        gpl(xr, yr),
        gcrv("f", sample(f, xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(7, "먼저 굵은 직사각형 몇 개로 어림합니다 — 삐져나오고 모자란 데가 생깁니다.", bars(4, "b4", C.hot)),
      beat(8, "폭을 잘게 쪼갤수록 어림값이 참값에 붙습니다. 그 극한이 정적분입니다.", [
        ...bars(16, "b16", C.ok),
        cap("lim", 0, "\\lim_{n\\to\\infty}\\sum f(x_k)\\Delta x=\\int_{a}^{b} f", C.ok, 32),
      ]),
    ], ctx);
  });

  /* 위치·속도·가속도 */
  register("calculus-motion", (v, ctx) => {
    const a = v.a ?? 1, b = v.b ?? 0, c = v.c ?? 0;
    const s = (t) => a * t * t + b * t + c;
    const vel = (t) => 2 * a * t + b;
    const acc = () => 2 * a;
    const t0 = v.time ?? 1;
    const xr = [0, Math.max(3, t0 + 1.6)];
    const yr = yFit(s, xr, { pad: 0.2 });
    return withSteps("sol-calc-motion", [
      beat(6, `위치가 $s(t)=${head(term(a, "t^2") + term(b, "t") + term(c, ""))}$ 로 변합니다.`, [
        gpl(xr, yr, { xLabel: "t", yLabel: "s" }),
        gcrv("s", sample(s, xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.main),
      ]),
      beat(8, `한 번 미분하면 속도입니다 — $t=${nf(t0)}$ 에서 접선의 기울기가 곧 속도 $${nf(vel(t0))}$ 입니다.`, [
        gpt("p", [t0, s(t0)], C.hot),
        gseg("tan", ...lineAt(t0, s(t0), vel(t0), Math.min(1.3, xr[1] / 3)), C.hot, { width: 5 }),
        cap("v", 0, `v(${nf(t0)})=s'(${nf(t0)})=${nf(vel(t0))}`, C.hot, 34),
      ]),
      beat(8, `한 번 더 미분하면 가속도 $${nf(acc())}$ 입니다.`, [
        cap("a", 0, `a=v'=${nf(acc())}`, C.ok, 38),
        ...arrow("c1", [320, 982], [500, 982], C.mute, { width: 4, head: 20 }),
        ...arrow("c2", [620, 982], [800, 982], C.mute, { width: 4, head: 20 }),
        { type: "glabel", id: "l1", at: [255, 982], text: "위치", size: 32, color: C.main },
        { type: "glabel", id: "l2", at: [560, 982], text: "속도", size: 32, color: C.hot },
        { type: "glabel", id: "l3", at: [858, 982], text: "가속도", size: 32, color: C.ok },
      ]),
    ], ctx);
  });

  /* 속도 그래프의 넓이 = 변위 / 이동거리 */
  register("calculus-velocity-area", (v, ctx) => {
    const z = v.zero ?? 2, k = v.scale ?? 1, end = v.end ?? 5;
    const vel = (t) => k * (t - z);
    const xr = [0, end + 0.5];
    const yr = yFit(vel, xr, { pad: 0.25 });
    const neg = [[0, 0], ...sample(vel, 0, Math.min(z, end), { n: 24 }), [Math.min(z, end), 0]];
    const pos = z < end ? [[z, 0], ...sample(vel, z, end, { n: 24 }), [end, 0]] : null;
    const abs = !!v.absolute;
    return withSteps("sol-calc-velarea", [
      beat(6, `속도 그래프입니다 — $t=${nf(z)}$ 에서 부호가 바뀝니다.`, [
        gpl(xr, yr, { xLabel: "t", yLabel: "v" }),
        gcrv("v", sample(vel, xr[0], xr[1], { n: 60 }), C.main),
        gpt("z", [z, 0], C.hot, { r: 12 }),
      ]),
      beat(8, "속도가 음수인 동안은 뒤로, 양수인 동안은 앞으로 갑니다.", [
        gfill("n", neg, C.hot, 0.3),
        ...(pos ? [gfill("p", pos, C.ok, 0.3)] : []),
        { type: "glabel", id: "sn", plane: "gpl", at: [Math.min(z, end) / 2, yr[0] * 0.4], text: "－", size: 52, color: C.hot },
        ...(pos ? [{ type: "glabel", id: "sp", plane: "gpl", at: [(z + end) / 2, yr[1] * 0.4], text: "＋", size: 52, color: C.ok }] : []),
      ]),
      beat(8, abs
        ? "이동거리는 방향을 무시하므로 두 넓이의 크기를 그냥 더합니다."
        : "변위는 부호를 살려 더하므로 두 넓이가 서로 상쇄됩니다.", [
        cap("f", 0, abs
          ? `\\int_0^{${nf(end)}}|v|\\,dt`
          : `\\int_0^{${nf(end)}}v\\,dt`, abs ? C.hot : C.ok, 40),
        capText("n2", 1, abs ? "이동거리 = |음| + |양|" : "변위 = (양) − (음)", C.mute, 30),
      ]),
    ], ctx);
  });

  /* ---------- 확률·통계 계열 ----------
     이 유형들은 값이 개수(24, 16)로 올 때도 있고 확률(0.4)로 올 때도 있다.
     그래서 숫자를 해석해 이름 붙이지 않고 온 그대로 보여 준다 — 지어내면 거짓이 된다. */

  /** 두 원이 겹친 렌즈(교집합) 둘레. 색칠은 fill 이 닫힌 경로를 채우므로 순서가 중요하다. */
  function lensPts(x1, x2, cy, r) {
    const d = Math.abs(x2 - x1) / 2;
    if (d >= r) return [];
    const half = Math.acos(d / r);
    const out = [];
    for (let i = 0; i <= 26; i++) {          // 왼쪽 원의 오른쪽 호 (위 교점 → 아래 교점)
      const t = -half + (2 * half * i) / 26;
      out.push([x1 + r * Math.cos(t), cy + r * Math.sin(t)]);
    }
    for (let i = 0; i <= 26; i++) {          // 오른쪽 원의 왼쪽 호 (아래 교점 → 위 교점)
      const t = Math.PI - half + (2 * half * i) / 26;
      out.push([x2 + r * Math.cos(t), cy + r * Math.sin(t)]);
    }
    return out;
  }

  /* 집합·확률의 벤 다이어그램 */
  register("probability-venn", (v, ctx) => {
    const cx = ART.x + ART.w / 2, cy = ART.y + ART.h / 2 - 20, R = 158, off = 92;
    const ax = cx - off, bx = cx + off;
    const has = (x) => x !== undefined && x !== null;
    const box = roundRectPts(ART.x + 34, ART.y + 46, ART.w - 68, ART.h - 150, 26);
    const beats = [
      beat(6, has(v.total) ? `전체 ${nf(v.total)} 개를 상자로 두고 시작합니다.`
                           : "전체집합을 상자로 두고 시작합니다.", [
        { type: "polygon", id: "U", points: box, stroke: C.mute, width: 3 },
        { type: "glabel", id: "Ul", at: [ART.x + 78, ART.y + 88], text: "U", size: 34, color: C.mute },
        ...(has(v.total) ? [{ type: "glabel", id: "Ut", at: [ART.x + ART.w - 110, ART.y + 88],
                              text: `${nf(v.total)}`, size: 34, color: C.mute }] : []),
      ]),
      beat(7, "조건마다 원 하나씩 — 겹친 자리가 '둘 다' 입니다.", [
        { type: "polygon", id: "A", points: ovalPts(ax, cy, R, R), stroke: C.main, fill: C.main, fillOpacity: 0.2, width: 4 },
        { type: "polygon", id: "B", points: ovalPts(bx, cy, R, R), stroke: C.ok, fill: C.ok, fillOpacity: 0.2, width: 4 },
        { type: "glabel", id: "Al", at: [ax - R - 34, cy - R * 0.65], text: "A", size: 40, color: C.main },
        { type: "glabel", id: "Bl", at: [bx + R + 34, cy - R * 0.65], text: "B", size: 40, color: C.ok },
        ...(has(v.a) ? [{ type: "glabel", id: "av", at: [ax - 72, cy], text: `${nf(v.a)}`, size: 38, color: C.main }] : []),
        ...(has(v.b) ? [{ type: "glabel", id: "bv", at: [bx + 72, cy], text: `${nf(v.b)}`, size: 38, color: C.ok }] : []),
      ]),
      beat(8, has(v.intersection)
        ? `두 원이 겹친 부분이 ${nf(v.intersection)} 입니다 — 여기가 두 번 세어진 자리입니다.`
        : "두 원이 겹친 부분은 양쪽에서 한 번씩, 두 번 세어집니다.", [
        { type: "polygon", id: "AB", points: lensPts(ax, bx, cy, R), stroke: C.hot, fill: C.hot, fillOpacity: 0.45, width: 4 },
        ...(has(v.intersection) ? [{ type: "glabel", id: "iv", at: [cx, cy], text: `${nf(v.intersection)}`, size: 40, color: C.hot }] : []),
      ]),
      beat(7, v.conditional
        ? `조건부확률은 조건이 된 쪽(${v.conditional})만 새 전체로 봅니다.`
        : "그래서 합집합은 더한 뒤 겹친 만큼 한 번 빼 줍니다.", [
        v.conditional
          ? { type: "polygon", id: "cond", points: ovalPts(v.conditional === "A" ? ax : bx, cy, R + 12, R + 12),
              stroke: C.hot, width: 6 }
          : cap("uni", 0, "n(A\\cup B)=n(A)+n(B)-n(A\\cap B)", C.ok, 34),
      ]),
    ];
    if (v.complement) {
      beats.push(beat(7, "여집합은 상자 안에서 그 원을 뺀 나머지입니다.", [
        { type: "polygon", id: "Uc", points: box, stroke: C.hot, fill: C.hot, fillOpacity: 0.16, width: 4 },
        { type: "polygon", id: "A2", points: ovalPts(ax, cy, R, R), stroke: C.main, fill: "#FFFFFF", fillOpacity: 1, width: 4 },
      ]));
    }
    return withSteps("sol-prob-venn", beats, ctx);
  });

  /* 경우의 수 — mode 마다 다른 그림 */
  register("probability-counting", (v, ctx) => {
    const cx = ART.x + ART.w / 2, cy = ART.y + ART.h / 2;
    const mode = v.mode || (v.groups ? "multiset" : "repeated");

    if (mode === "circle") {
      const n = v.items || 5, R = 200;
      const seat = (i) => [cx + R * Math.cos((i / n) * Math.PI * 2 - Math.PI / 2),
                           cy + R * Math.sin((i / n) * Math.PI * 2 - Math.PI / 2)];
      return withSteps("sol-prob-counting", [
        beat(6, `${nf(n)} 명을 원탁에 앉힙니다.`, [
          { type: "polygon", id: "tbl", points: ovalPts(cx, cy, R, R), stroke: C.mute, width: 3 },
          ...Array.from({ length: n }, (_, i) => ({ type: "point", id: `s${i}`, at: seat(i), r: 20, color: C.main })),
        ]),
        beat(8, "원탁은 돌리면 같은 배열이라, 한 사람을 기준으로 고정합니다.", [
          { type: "point", id: "s0", at: seat(0), r: 26, color: C.hot },
          ...arrow("fix", [cx, cy - R - 96], seat(0).map((t, i) => (i === 1 ? t - 30 : t)), C.hot, { width: 4, head: 22 }),
        ]),
        beat(7, "나머지 자리만 일렬로 세우면 됩니다.", [
          ...Array.from({ length: Math.max(0, n - 1) }, (_, i) =>
            ({ type: "point", id: `s${i + 1}`, at: seat(i + 1), r: 20, color: C.ok })),
          cap("f", 0, `(${nf(n)}-1)!`, C.ok, 46),
        ]),
      ], ctx);
    }

    if (mode === "pascal") {
      const rows = Math.min(v.row || 5, 7);
      const tri = [[1]];
      for (let i = 1; i <= rows; i++) {
        const prev = tri[i - 1], cur = [1];
        for (let j = 1; j < prev.length; j++) cur.push(prev[j - 1] + prev[j]);
        cur.push(1);
        tri.push(cur);
      }
      const dx = 96, dy = Math.min(96, (ART.h - 200) / rows);
      const at = (i, j) => [cx - (i * dx) / 2 + j * dx, ART.y + 120 + i * dy];
      // 숫자만 늘어놓으면 '글자 나열' 이 된다 — 각 수를 원 안에 넣어 삼각형 모양이
      // 도형으로 읽히게 한다(어느 두 수가 어느 수로 내려오는지가 보여야 한다).
      const R = Math.min(34, dx / 2.6);
      const cells = [];
      tri.forEach((row, i) => row.forEach((val, j) => {
        const c = i === rows ? C.main : C.mute;
        cells.push({ type: "polygon", id: `pc${i}_${j}`, points: ovalPts(at(i, j)[0], at(i, j)[1], R, R, 24),
                     stroke: c, fill: c, fillOpacity: 0.12, width: 3 });
        cells.push({ type: "glabel", id: `p${i}_${j}`, at: at(i, j), text: String(val),
                     size: Math.min(30, R * 0.9), color: c });
      }));
      return withSteps("sol-prob-counting", [
        beat(6, "파스칼의 삼각형을 한 줄씩 쌓습니다.", cells),
        beat(8, "바로 위 두 수를 더하면 아래 수가 됩니다.", [
          ...(tri[rows].length > 2 ? [
            ...arrow("a1", at(rows - 1, 0), at(rows, 1), C.hot, { width: 3.5, head: 18 }),
            ...arrow("a2", at(rows - 1, 1), at(rows, 1), C.hot, { width: 3.5, head: 18 }),
            { type: "point", id: "hi", at: at(rows, 1), r: 26, color: C.hot },
            { type: "glabel", id: `p${rows}_1`, at: at(rows, 1), text: String(tri[rows][1]), size: 32, color: "#FFFFFF" },
          ] : []),
        ]),
        beat(7, `그래서 ${nf(rows)} 번째 줄이 조합의 수와 같습니다.`, [
          cap("f", 0, `{}_{${nf(rows)}}C_{r}`, C.ok, 44),
        ]),
      ], ctx);
    }

    if (mode === "stars-bars") {
      const items = v.items || 6, slots = v.slots || 3;
      const bars = Math.max(0, slots - 1);
      const gap = 70, x0 = cx - ((items + bars - 1) * gap) / 2;
      const marks = [];
      // 별(나눠 줄 것) 과 막대(칸막이) 를 한 줄에 늘어놓는다 — 이게 이 공식의 그림이다
      for (let i = 0; i < items; i++) marks.push({ type: "point", id: `st${i}`, at: [x0 + i * gap, cy], r: 22, color: C.main });
      for (let i = 0; i < bars; i++)
        marks.push({ type: "seg", id: `br${i}`, from: [x0 + (items + i) * gap, cy - 40],
                     to: [x0 + (items + i) * gap, cy + 40], color: C.hot, width: 8 });
      return withSteps("sol-prob-counting", [
        beat(6, `똑같은 것 ${nf(items)} 개를 나눠 줍니다.`,
          marks.filter((m) => m.type === "point")),
        beat(8, `칸막이 ${nf(bars)} 개를 끼우면 ${nf(slots)} 묶음으로 갈립니다.`, marks),
        beat(7, "결국 자리 중 어디에 칸막이를 둘지 고르는 문제입니다.", [
          cap("f", 0, `{}_{${nf(items + bars)}}C_{${nf(bars)}}`, C.ok, 46),
        ]),
      ], ctx);
    }

    if (mode === "multiset" && v.groups) {
      const groups = v.groups.slice(0, 4);
      const cols = [C.main, C.ok, C.hot, C.mute];
      const total = groups.reduce((s, g) => s + g, 0);
      const rowH = Math.min(120, (ART.h - 220) / groups.length);
      return withSteps("sol-prob-counting", [
        beat(6, `같은 것끼리 묶으면 ${groups.map(nf).join(", ")} 개씩입니다.`,
          groups.map((g, i) => ({ type: "blocks", id: `g${i}`,
            rect: { x: ART.x + 70, y: ART.y + 110 + i * rowH, w: Math.min(520, g * 84), h: rowH - 26 },
            rows: 1, cols: g, count: g, gap: 8, color: cols[i % 4] }))),
        beat(8, `전부 다르다면 ${nf(total)}! 가지지만, 같은 것끼리는 순서를 바꿔도 구별이 안 됩니다.`, [
          ...groups.map((g, i) => ({ type: "brace", id: `bb${i}`,
            from: [ART.x + 70, ART.y + 110 + i * rowH + rowH - 22],
            to: [ART.x + 70 + Math.min(520, g * 84), ART.y + 110 + i * rowH + rowH - 22],
            label: `${nf(g)}!`, color: cols[i % 4] })),
        ]),
        beat(7, "그래서 같은 것들의 순서 수만큼 나눕니다.", [
          cap("f", 0, `\\dfrac{${nf(total)}!}{${groups.map((g) => `${nf(g)}!`).join("\\,")}}`, C.ok, 42),
        ]),
      ], ctx);
    }

    // repeated (중복순열) — 자리마다 후보가 그대로 다시 열린다
    const slots = Math.min(v.slots || 3, 5), choices = v.choices || 4;
    const sx = cx - ((slots - 1) * 190) / 2;
    const boxes = Array.from({ length: slots }, (_, i) => ({
      type: "polygon", id: `bx${i}`, points: roundRectPts(sx + i * 190 - 66, cy - 60, 132, 120, 18),
      stroke: C.main, fill: C.main, fillOpacity: 0.1, width: 4,
    }));
    return withSteps("sol-prob-counting", [
      beat(6, `채워야 할 자리가 ${nf(slots)} 칸입니다.`, boxes),
      beat(8, `자리마다 후보는 늘 ${nf(choices)} 가지 — 뽑아도 줄지 않습니다.`, [
        ...Array.from({ length: slots }, (_, i) => ({ type: "blocks", id: `c${i}`,
          rect: { x: sx + i * 190 - 60, y: cy + 110, w: 120, h: Math.min(210, choices * 34) },
          rows: choices, cols: 1, count: choices, gap: 6, color: C.hot })),
        ...Array.from({ length: slots }, (_, i) =>
          arrow(`ar${i}`, [sx + i * 190, cy + 100], [sx + i * 190, cy + 68], C.hot, { width: 3.5, head: 18 })).flat(),
      ]),
      beat(7, "그래서 칸 수만큼 곱합니다.", [
        cap("f", 0, `${nf(choices)}^{${nf(slots)}}`, C.ok, 50),
      ]),
    ], ctx);
  });

  /* 확률의 나뭇가지 그림 */
  register("probability-tree", (v, ctx) => {
    const levels = Math.min(v.levels ?? (v.path ? v.path.length : 2), 3) || 2;
    const path = v.path || (v.paths && v.paths[0]) || null;
    const p1 = path ? path[0] : (v.first ?? v.probability ?? 0.5);
    const x0 = ART.x + 90, cy = ART.y + ART.h / 2;
    const spanY = 210, dx = Math.min(250, (ART.w - 200) / levels);
    // 단계별 확률 — viz 가 준 것만 쓴다. path 가 없으면 첫 갈래(first/probability)와
    // 둘째 갈래(conditional) 까지만 알 수 있고, 나머지는 라벨 없이 모양만 그린다.
    const probs = [];
    for (let d = 0; d < levels; d++) {
      if (path && path[d] !== undefined) probs.push(path[d]);
      else if (d === 0 && (v.first ?? v.probability) !== undefined) probs.push(v.first ?? v.probability);
      else if (d === 1 && v.conditional !== undefined) probs.push(v.conditional);
      else probs.push(null);
    }
    const nodes = [];
    const edges = [];
    const mainIds = [];   // 뿌리에서 늘 위쪽 갈래를 따라간 '한 경로' — 이것만 강조한다
    const build = (depth, x, y, spread, id, onMain) => {
      if (depth >= levels) return;
      const pr = probs[depth];
      [0, 1].forEach((k) => {
        const dir = k === 0 ? -1 : 1;
        const prob = pr === null ? null : (k === 0 ? pr : Math.round((1 - pr) * 1000) / 1000);
        const ny = y + dir * spread, nx = x + dx;
        const eid = `e${id}${k}`;
        const main = onMain && k === 0;
        if (main) mainIds.push(eid);
        edges.push({ type: "seg", id: eid, from: [x, y], to: [nx, ny],
          color: main ? C.main : C.mute, width: main ? 5 : 3.5,
          label: prob !== null ? `$${nf(prob)}$` : undefined });
        nodes.push({ type: "point", id: `n${id}${k}`, at: [nx, ny], r: 13, color: main ? C.main : C.mute });
        build(depth + 1, nx, ny, spread / 2, `${id}${k}`, main);
      });
    };
    build(0, x0, cy, spanY, "r", true);
    const root = { type: "point", id: "root", at: [x0, cy], r: 16, color: C.hot };
    const byId = new Map(edges.map((e) => [e.id, e]));
    return withSteps("sol-prob-tree", [
      beat(6, "일어날 수 있는 길을 갈래로 펼칩니다.", [root, ...edges, ...nodes]),
      beat(8, `한 갈래로 갈 확률은 ${nf(p1)} 입니다 — 가지마다 확률이 붙습니다.`,
        mainIds.map((id) => Object.assign({}, byId.get(id), { color: C.hot, width: 8 }))),
      beat(8, v.withoutReplacement
        ? "꺼낸 것을 되돌리지 않으면 다음 갈래의 확률이 달라집니다 — 분모가 줄어듭니다."
        : "한 경로의 확률은 그 길에 붙은 확률을 모두 곱한 값입니다.", [
        cap("f", 0, path && path.length
          ? path.map((x) => nf(x)).join("\\times") + "=" + nf(path.reduce((s, x) => s * x, 1))
          : "P=p_1\\times p_2\\times\\cdots", C.ok, 38),
      ]),
    ], ctx);
  });

  /* 확률분포 — 막대와 평균 */
  register("probability-distribution", (v, ctx) => {
    const pr = (v.probabilities && v.probabilities.length) ? v.probabilities
      : (v.values && v.values.length ? v.values.map((x) => x / v.values.reduce((s, y) => s + y, 0)) : [0.2, 0.3, 0.3, 0.2]);
    const n = pr.length;
    const top = Math.max(...pr);
    const from = v.focusFrom ?? v.focus ?? null, to = v.focusTo ?? null;
    const inFocus = (i) => (from === null ? false : to === null ? i === from : i >= from && i <= to);
    const xr = [-0.8, n - 0.2];
    const yr = [0, top * 1.3];
    return withSteps("sol-prob-dist", [
      beat(6, "값마다 확률이 얼마인지 막대로 세웁니다.", [
        gpl(xr, yr, { xTicks: pr.map((_, i) => i).slice(0, 7), yTicks: [], xLabel: "X", yLabel: "P" }),
        ...pr.map((p, i) => gseg(`b${i}`, [i, 0], [i, p], C.main, { width: Math.max(14, 150 / n) })),
      ]),
      beat(8, "확률을 모두 더하면 반드시 $1$ 입니다.", [
        { type: "brace", id: "sum", plane: "gpl", from: [0, top * 1.16], to: [n - 1, top * 1.16],
          label: "$\\text{합}=1$", color: C.mute },
      ]),
      from !== null
        ? beat(8, "묻는 범위의 막대만 골라 더합니다.", [
            ...pr.map((p, i) => inFocus(i)
              ? gseg(`b${i}`, [i, 0], [i, p], C.hot, { width: Math.max(14, 150 / n) })
              : gseg(`b${i}`, [i, 0], [i, p], C.mute, { width: Math.max(14, 150 / n) })),
            cap("f", 0, `P=${nf(pr.filter((_, i) => inFocus(i)).reduce((s, x) => s + x, 0))}`, C.hot, 40),
          ])
        : beat(8, v.mean !== undefined
            ? `기댓값은 값에 확률을 곱해 더한 무게중심 $${nf(v.mean)}$ 입니다.`
            : "기댓값은 값에 확률을 곱해 더한 무게중심입니다.", [
            ...(v.mean !== undefined && v.mean >= xr[0] && v.mean <= xr[1]
              ? [{ type: "vline", id: "vm", plane: "gpl", x: v.mean, from: 0, to: top * 1.2,
                   dashed: true, color: C.hot, label: `$${nf(v.mean)}$` }] : []),
            cap("f", 0, "E(X)=\\sum x_i p_i", C.ok, 38),
          ]),
    ], ctx);
  });

  /* 이항분포 */
  register("probability-binomial", (v, ctx) => {
    const n = Math.min(v.n || 8, 24), p = v.p ?? 0.5;
    const logC = (nn, k) => { let s = 0; for (let i = 1; i <= k; i++) s += Math.log(nn - k + i) - Math.log(i); return s; };
    const bars = [];
    for (let k = 0; k <= n; k++) bars.push(Math.exp(logC(n, k) + k * Math.log(p) + (n - k) * Math.log(1 - p)));
    const top = Math.max(...bars);
    const mean = v.mean ?? n * p;
    const fv = v.focusValues || (v.focus !== undefined ? [v.focus] : null);
    const xr = [-0.8, n + 0.8], yr = [0, top * 1.3];
    return withSteps("sol-prob-binomial", [
      beat(6, `성공확률 $${nf(p)}$ 인 시행을 $${nf(n)}$ 번 반복합니다.`, [
        gpl(xr, yr, { xTicks: bars.map((_, k) => k).filter((k) => k % Math.ceil((n + 1) / 7) === 0), yTicks: [], xLabel: "k", yLabel: "P" }),
        ...bars.map((pr, k) => gseg(`b${k}`, [k, 0], [k, pr], C.main, { width: Math.max(8, 240 / (n + 1)) })),
      ]),
      beat(7, "성공 횟수의 분포는 가운데가 가장 두껍습니다.", [
        { type: "vline", id: "vm", plane: "gpl", x: mean, from: 0, to: top * 1.22, dashed: true, color: C.hot,
          label: `$np=${nf(mean)}$` },
      ]),
      fv
        ? beat(8, "묻는 값의 막대만 골라 더합니다.", [
            ...fv.filter((k) => k >= 0 && k <= n).map((k) =>
              gseg(`b${k}`, [k, 0], [k, bars[k]], C.hot, { width: Math.max(8, 240 / (n + 1)) })),
            cap("f", 0, `P=\\sum {}_{${nf(n)}}C_k\\,p^k(1-p)^{${nf(n)}-k}`, C.hot, 32),
          ])
        : beat(8, `평균은 $np=${nf(mean)}$, 분산은 $np(1-p)=${nf(n * p * (1 - p))}$ 입니다.`, [
            cap("f", 0, `E(X)=np=${nf(mean)}`, C.main, 36),
            cap("f2", 1, `V(X)=np(1-p)=${nf(Math.round(n * p * (1 - p) * 1000) / 1000)}`, C.ok, 34),
          ]),
    ], ctx);
  });

  /* 정규분포 — 평균에서 몇 표준편차 */
  register("probability-normal", (v, ctx) => {
    const m = v.mean ?? 0, s = v.sd || 1;
    const bell = (x) => Math.exp(-((x - m) * (x - m)) / (2 * s * s));
    const xr = [m - 3.8 * s, m + 3.8 * s];
    const lo = v.shadeFrom ?? null, hi = v.shadeTo ?? null;
    const cl = (x) => Math.min(Math.max(x, xr[0]), xr[1]);
    return withSteps("sol-prob-normal", [
      beat(6, `평균 $${nf(m)}$, 표준편차 $${nf(s)}$ 인 정규분포입니다.`, [
        gpl(xr, [0, 1.25], { yTicks: [] }),
        gcrv("d", sample(bell, xr[0], xr[1], { n: 140 }), C.main, { drawSec: 1.5 }),
        { type: "vline", id: "vm", plane: "gpl", x: m, from: 0, to: 1.08, dashed: true, color: C.mute, label: `$m=${nf(m)}$` },
      ]),
      beat(8, "확률은 곡선 아래의 넓이입니다 — 묻는 구간만큼 칠합니다.", [
        ...(lo !== null || hi !== null ? [gfill("sh",
          [[cl(lo ?? xr[0]), 0], ...sample(bell, cl(lo ?? xr[0]), cl(hi ?? xr[1]), { n: 60 }), [cl(hi ?? xr[1]), 0]],
          C.hot, 0.34)] : []),
        ...(lo !== null ? [{ type: "vline", id: "vl", plane: "gpl", x: cl(lo), from: 0, to: bell(cl(lo)), color: C.hot, dashed: false, label: `$${nf(lo)}$` }] : []),
        ...(hi !== null ? [{ type: "vline", id: "vh", plane: "gpl", x: cl(hi), from: 0, to: bell(cl(hi)), color: C.hot, dashed: false, label: `$${nf(hi)}$` }] : []),
      ]),
      beat(8, "평균에서 몇 표준편차 떨어졌는지로 바꾸면 표준정규분포표를 쓸 수 있습니다.", [
        { type: "brace", id: "br", plane: "gpl", from: [m, 1.14], to: [m + s, 1.14], label: `$\\sigma=${nf(s)}$`, color: C.ok },
        cap("z", 0, "Z=\\dfrac{X-m}{\\sigma}", C.ok, 40),
      ]),
    ], ctx);
  });

  /* 표본조사·표본평균 */
  register("probability-sampling", (v, ctx) => {
    const cx = ART.x + ART.w / 2;
    // 모표준편차·표본크기가 오면 '표본평균의 분포' 그림이 정확하다
    if (v.populationSd !== undefined && v.sampleSize) {
      const s = v.populationSd, n = v.sampleSize, m = v.populationMean ?? 0;
      const se = v.standardError ?? s / Math.sqrt(n);
      const bell = (sd) => (x) => Math.exp(-((x - m) * (x - m)) / (2 * sd * sd));
      const xr = [m - 3.4 * s, m + 3.4 * s];
      return withSteps("sol-prob-sampling", [
        beat(6, `모집단은 평균 $${nf(m)}$, 표준편차 $${nf(s)}$ 로 넓게 퍼져 있습니다.`, [
          gpl(xr, [0, 1.25], { yTicks: [] }),
          gcrv("pop", sample(bell(s), xr[0], xr[1], { n: 140 }), C.mute, { drawSec: 1.4 }),
        ]),
        beat(8, `크기 $${nf(n)}$ 인 표본의 평균을 모으면 훨씬 좁게 뭉칩니다.`, [
          gcrv("smp", sample(bell(se), xr[0], xr[1], { n: 140 }), C.main, { drawSec: 1.4 }),
          { type: "vline", id: "vm", plane: "gpl", x: m, from: 0, to: 1.1, dashed: true, color: C.hot, label: `$${nf(m)}$` },
        ]),
        beat(8, "중심은 그대로, 흩어짐만 표본 크기의 제곱근만큼 줄어듭니다.", [
          { type: "brace", id: "br", plane: "gpl", from: [m, 1.16], to: [m + se, 1.16], label: `$${nf(se)}$`, color: C.ok },
          cap("f", 0, `\\sigma_{\\bar X}=\\dfrac{\\sigma}{\\sqrt{n}}=\\dfrac{${nf(s)}}{\\sqrt{${nf(n)}}}=${nf(se)}`, C.ok, 34),
        ]),
      ], ctx);
    }
    // 층화·군집·단순임의 — 모집단 칸에서 무엇을 고르는지가 그림이다
    const strata = v.strata || null, clusters = v.clusters || null;
    const pop = v.population || 60, smp = v.sample || 12;
    if (strata) {
      const cols = [C.main, C.ok, C.hot, C.mute];
      const rowH = Math.min(130, (ART.h - 220) / strata.length);
      // 층 격자와 표본 격자의 rect·cols 를 맞춘다(칸 크기가 달라지면 강조가 어긋난다).
      const rowRect = (i) => ({ x: ART.x + 80, y: ART.y + 110 + i * rowH, w: 520, h: rowH - 30 });
      const cellsOf = (g) => Math.min(g, 12);
      return withSteps("sol-prob-sampling", [
        beat(6, "모집단이 성질에 따라 층으로 나뉘어 있습니다.",
          strata.map((g, i) => ({ type: "blocks", id: `s${i}`, rect: rowRect(i),
            rows: 1, cols: cellsOf(g), count: cellsOf(g), gap: 6, color: cols[i % 4] }))),
        beat(8, "층마다 크기에 비례해 뽑아야 전체를 닮은 표본이 됩니다.",
          strata.map((g, i) => ({ type: "blocks", id: `p${i}`, rect: rowRect(i),
            rows: 1, cols: cellsOf(g),
            count: Math.max(1, Math.round(cellsOf(g) * 0.35)), gap: 6, color: C.hot }))),
        beat(7, "이렇게 하면 어느 층도 빠지지 않습니다 — 층화표집입니다.", [
          capText("t", 0, "층마다 비례 배분", C.ok, 34),
        ]),
      ], ctx);
    }
    if (clusters) {
      const k = Math.min(clusters, 8), sel = Math.min(v.selectedClusters || 2, k);
      const w = 150, gap = 26, perRow = 4;
      const boxAt = (i) => [ART.x + 90 + (i % perRow) * (w + gap), ART.y + 150 + Math.floor(i / perRow) * (w + gap)];
      return withSteps("sol-prob-sampling", [
        beat(6, `모집단이 ${nf(k)} 개의 무리로 나뉘어 있습니다.`,
          Array.from({ length: k }, (_, i) => ({ type: "polygon", id: `c${i}`,
            points: roundRectPts(boxAt(i)[0], boxAt(i)[1], w, w, 18), stroke: C.mute, width: 3 }))),
        beat(8, `무리 중 ${nf(sel)} 개를 통째로 고릅니다.`,
          Array.from({ length: sel }, (_, i) => ({ type: "polygon", id: `c${i}`,
            points: roundRectPts(boxAt(i)[0], boxAt(i)[1], w, w, 18),
            stroke: C.hot, fill: C.hot, fillOpacity: 0.28, width: 5 }))),
        beat(7, "고른 무리 안은 전부 조사합니다 — 군집표집입니다.", [
          capText("t", 0, "무리 단위로 통째 조사", C.ok, 34),
        ]),
      ], ctx);
    }
    const shown = Math.min(pop, 40), pick = Math.max(1, Math.min(smp, shown));
    // 표본 격자는 모집단 격자와 **같은 rect·rows·cols** 여야 한다. 예전엔 폭과 열 수를
    // 따로 잡아서 칸 크기가 달라졌고, 강조 칸이 모집단 칸과 어긋나 겹쳐 보였다.
    // count 만 줄이면 앞에서부터 그만큼만 칠해져 '전체 중 이만큼' 이 그대로 읽힌다.
    const grid = { x: ART.x + 80, y: ART.y + 160, w: 600, h: 380 };
    return withSteps("sol-prob-sampling", [
      beat(6, `모집단 ${nf(pop)} 개 전체를 다 조사하기는 어렵습니다.`, [
        { type: "blocks", id: "pop", rect: grid, rows: 5, cols: 8, count: shown, gap: 10, color: C.mute },
      ]),
      beat(8, `그래서 ${nf(smp)} 개를 골라 표본으로 삼습니다.`, [
        { type: "blocks", id: "smp", rect: grid, rows: 5, cols: 8, count: pick, gap: 10,
          color: C.hot, countLabel: true },
      ]),
      beat(7, v.biased
        ? "고르는 방법이 한쪽으로 치우치면 표본이 모집단을 대표하지 못합니다."
        : "모두가 뽑힐 가능성이 같아야 표본이 모집단을 닮습니다.", [
        capText("t", 0, v.biased ? "치우친 표본 — 대표성 없음" : "임의추출 — 대표성 확보", v.biased ? C.hot : C.ok, 34),
      ]),
    ], ctx);
  });

  /* 신뢰구간 */
  register("probability-confidence", (v, ctx) => {
    const c = v.center ?? 0, mg = v.margin ?? 1;
    const list = v.intervals && v.intervals.length ? v.intervals : [[c, mg]];
    const widest = Math.max(...list.map((it) => it[1]));
    const xr = [c - widest * 2.4, c + widest * 2.4];
    const yr = [-1.2, 1.2];
    const rowY = (i) => (list.length === 1 ? 0 : 0.6 - i * 1.1);
    return withSteps("sol-prob-confidence", [
      beat(6, `표본에서 얻은 값 $${nf(c)}$ 이 추정의 중심입니다.`, [
        gpl(xr, yr, { yTicks: [], showGrid: false, yLabel: "" }),
        gpt("c", [c, 0], C.hot, { r: 14 }),
        { type: "vline", id: "vc", plane: "gpl", x: c, from: -1, to: 1, dashed: true, color: C.mute },
      ]),
      beat(8, `한 점으로 딱 찍지 않고 오차 $${nf(mg)}$ 만큼 양옆으로 폭을 줍니다.`,
        list.map((it, i) => gseg(`iv${i}`, [it[0] - it[1], rowY(i)], [it[0] + it[1], rowY(i)],
          i === 0 ? C.main : C.ok, { width: 16 }))
        .concat(list.map((it, i) => gpt(`ic${i}`, [it[0], rowY(i)], C.hot, { r: 11 })))),
      beat(8, list.length > 1
        ? "표본이 클수록, 신뢰도가 낮을수록 구간이 좁아집니다."
        : "이 폭이 신뢰구간입니다 — 넓을수록 확신은 크지만 정보는 흐려집니다.", [
        { type: "brace", id: "br", plane: "gpl", from: [list[0][0] - list[0][1], rowY(0) - 0.35],
          to: [list[0][0] + list[0][1], rowY(0) - 0.35], label: `$${nf(2 * list[0][1])}$`, color: C.ok },
        cap("f", 0, `${nf(c)}\\pm${nf(mg)}`, C.ok, 44),
      ]),
    ], ctx);
  });

  /* ---------- 공통수학 개념 문항 (common-math-concept) ----------
     생성기가 실어 오는 것은 conceptId 와 focus 뿐이다(수치는 없다). 그래서 그림은
     '그 단원의 한 장' 이되, 대표 배경을 한 컷 세우고 마는 대신 **단계별로 쌓아 올린다**.
     배경 그림(BACKDROPS)은 정지화면 한 장이라 "이게 최선이냐" 는 지적을 받았다 —
     여기서는 같은 소재를 3박으로 조립하면서 무엇이 무엇인지 짚는다.

     이 유형만 전체 표본의 4할이 넘으므로(실측 4,680/11,160) 여기 품질이 곧 전체 품질이다. */
  const CONCEPT_ART = {
    /* 곱셈·인수분해 — 넓이 모델을 조각내며 만든다 */
    areaModel() {
      const x0 = ART.x + 110, y0 = ART.y + 150, W = 560, H = 470;
      const mx = x0 + W * 0.62, my = y0 + H * 0.6;
      const cell = (n, ax, ay, bx, by, color, tex) => ([
        { type: "polygon", id: `c${n}`, points: [[ax, ay], [bx, ay], [bx, by], [ax, by]],
          stroke: color, fill: color, fillOpacity: 0.18, width: 3 },
        { type: "glabel", id: `cl${n}`, at: [(ax + bx) / 2, (ay + by) / 2], tex, size: 34, color },
      ]);
      return [
        beat(6, "두 식의 곱은 가로·세로가 그 식인 직사각형의 넓이입니다.", [
          { type: "polygon", id: "box", points: [[x0, y0], [x0 + W, y0], [x0 + W, y0 + H], [x0, y0 + H]],
            stroke: C.mute, width: 4 },
          { type: "glabel", id: "wl", at: [x0 + W / 2, y0 - 58], tex: "x+a", size: 34, color: C.mute },
          { type: "glabel", id: "hl", at: [x0 - 92, y0 + H / 2], tex: "x+b", size: 34, color: C.mute },
        ]),
        beat(8, "가로와 세로를 항끼리 끊으면 직사각형이 네 조각으로 갈립니다.", [
          { type: "seg", id: "sv", from: [mx, y0], to: [mx, y0 + H], color: C.mute, width: 3, dashed: true },
          { type: "seg", id: "sh", from: [x0, my], to: [x0 + W, my], color: C.mute, width: 3, dashed: true },
          ...cell(1, x0, y0, mx, my, C.main, "x^2"),
          ...cell(2, mx, y0, x0 + W, my, C.ok, "ax"),
          ...cell(3, x0, my, mx, y0 + H, C.ok, "bx"),
          ...cell(4, mx, my, x0 + W, y0 + H, C.hot, "ab"),
        ]),
        beat(8, "조각의 넓이를 모두 더한 것이 전개식입니다 — 거꾸로 읽으면 인수분해입니다.", [
          cap("f", 0, "(x+a)(x+b)=x^2+(a+b)x+ab", C.ok, 36),
        ]),
      ];
    },
    /* 이차식 — 판별식의 세 경우 */
    parabola() {
      const mk = (k) => (x) => x * x - 2 * x + k;
      const xr = [-2.2, 4.2], yr = [-4.6, 5.4];
      return [
        beat(6, "이차식의 그래프는 포물선입니다 — 축과 만나는 자리가 근입니다.", [
          gpl(xr, yr),
          gcrv("p0", sample(mk(-3), xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.main),
          gpt("r1", [-1, 0], C.hot, { r: 13 }),
          gpt("r2", [3, 0], C.hot, { r: 13 }),
        ]),
        beat(8, "상수항을 올리면 포물선이 떠오르면서 만나는 점의 수가 줄어듭니다.", [
          gcrv("p1", sample(mk(1), xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.ok),
          gpt("t", [1, 0], C.ok, { r: 13 }),
          gcrv("p2", sample(mk(3), xr[0], xr[1], { n: 80, yMin: yr[0], yMax: yr[1] }), C.mute, { dashed: true }),
        ]),
        beat(8, "두 점에서 만나면 $D>0$, 접하면 $D=0$, 안 만나면 $D<0$ 입니다.", [
          cap("f", 0, "D=b^2-4ac", C.ink, 40),
          capText("t2", 1, "두 점 → D>0 · 접함 → D=0 · 안 만남 → D<0", C.mute, 30),
        ]),
      ];
    },
    /* 부등식 — 수직선 위의 구간 */
    numberLine() {
      const xr = [-5.4, 5.4], yr = [-1.3, 1.3];
      return [
        beat(6, "부등식의 해는 수직선 위의 '구간' 입니다.", [
          gpl(xr, yr, { yTicks: [], showGrid: false, yLabel: "" }),
        ]),
        beat(7, "경계가 되는 수를 먼저 찍고, 조건을 만족하는 쪽만 굵게 남깁니다.", [
          gseg("r1", [1, 0.34], [5.4, 0.34], C.main, { width: 16 }),
          gpt("b1", [1, 0.34], C.main, { r: 15 }),
          gseg("r2", [-5.4, -0.34], [3, -0.34], C.ok, { width: 16 }),
          gpt("b2", [3, -0.34], C.ok, { r: 15 }),
        ]),
        beat(8, "두 조건을 함께 만족하려면 겹치는 구간만 답이 됩니다.", [
          gseg("both", [1, 0], [3, 0], C.hot, { width: 22 }),
          { type: "brace", id: "br", plane: "gpl", from: [1, -0.75], to: [3, -0.75], label: "공통 부분", color: C.hot },
        ]),
      ];
    },
    /* 집합·명제 — 벤 다이어그램을 쌓는다 */
    venn() {
      const cx = ART.x + ART.w / 2, cy = ART.y + ART.h / 2 - 10, R = 152, off = 88;
      const ax = cx - off, bx = cx + off;
      const box = roundRectPts(ART.x + 34, ART.y + 46, ART.w - 68, ART.h - 150, 26);
      return [
        beat(6, "먼저 전체집합을 상자로 두고 그 안에서 생각합니다.", [
          { type: "polygon", id: "U", points: box, stroke: C.mute, width: 3 },
          { type: "glabel", id: "Ul", at: [ART.x + 78, ART.y + 88], text: "U", size: 34, color: C.mute },
        ]),
        beat(7, "조건마다 원을 하나씩 그립니다.", [
          { type: "polygon", id: "A", points: ovalPts(ax, cy, R, R), stroke: C.main, fill: C.main, fillOpacity: 0.2, width: 4 },
          { type: "polygon", id: "B", points: ovalPts(bx, cy, R, R), stroke: C.ok, fill: C.ok, fillOpacity: 0.2, width: 4 },
          { type: "glabel", id: "Al", at: [ax - R - 30, cy - R * 0.7], text: "A", size: 38, color: C.main },
          { type: "glabel", id: "Bl", at: [bx + R + 30, cy - R * 0.7], text: "B", size: 38, color: C.ok },
        ]),
        beat(8, "겹친 곳이 '둘 다', 합친 곳이 '적어도 하나', 바깥이 '아니다' 입니다.", [
          { type: "polygon", id: "AB", points: lensPts(ax, bx, cy, R), stroke: C.hot, fill: C.hot, fillOpacity: 0.5, width: 4 },
          { type: "glabel", id: "il", at: [cx, cy], tex: "A\\cap B", size: 30, color: C.hot },
          capText("t", 0, "A⊂B 이면 'A이면 B' 가 참", C.mute, 30),
        ]),
      ];
    },
    /* 경우의 수 — 갈래를 단계로 편다 */
    tree() {
      const x0 = ART.x + 100, cy = ART.y + ART.h / 2;
      const lvl1 = [-170, 0, 170];
      const lvl2 = [-70, 70];
      const n1 = lvl1.map((dy, i) => ({ type: "point", id: `a${i}`, at: [x0 + 250, cy + dy], r: 15, color: C.main }));
      const e1 = lvl1.map((dy, i) => ({ type: "seg", id: `ea${i}`, from: [x0, cy], to: [x0 + 250, cy + dy], color: C.main, width: 4 }));
      const e2 = [], n2 = [];
      lvl1.forEach((dy, i) => lvl2.forEach((d2, j) => {
        e2.push({ type: "seg", id: `eb${i}${j}`, from: [x0 + 250, cy + dy], to: [x0 + 540, cy + dy + d2], color: C.ok, width: 3.5 });
        n2.push({ type: "point", id: `b${i}${j}`, at: [x0 + 540, cy + dy + d2], r: 12, color: C.ok });
      }));
      return [
        beat(6, "첫 번째로 고를 것부터 갈래를 폅니다.", [
          { type: "point", id: "root", at: [x0, cy], r: 17, color: C.hot }, ...e1, ...n1,
          { type: "brace", id: "br1", from: [x0 + 300, cy - 210], to: [x0 + 300, cy + 210], label: "3", color: C.main },
        ]),
        beat(8, "그 각각마다 다음 선택이 또 갈라집니다.", [...e2, ...n2,
          { type: "brace", id: "br2", from: [x0 + 590, cy - 240], to: [x0 + 590, cy + 240], label: "×2", color: C.ok }]),
        beat(8, "끝에 달린 잎의 수가 곧 경우의 수입니다 — 단계마다 곱합니다.", [
          ...n2.map((p) => Object.assign({}, p, { r: 16, color: C.hot })),
          cap("f", 0, "3\\times2=6", C.hot, 46),
        ]),
      ];
    },
    /* 행렬 — 행과 열 */
    grid() {
      const x0 = ART.x + 150, y0 = ART.y + 190, cw = 130, ch = 110, rows = 3, cols = 3;
      const cells = [];
      for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
        cells.push({ type: "polygon", id: `g${r}${c}`,
          points: roundRectPts(x0 + c * cw, y0 + r * ch, cw - 12, ch - 12, 12),
          stroke: C.mute, width: 3 });
      }
      return [
        beat(6, "행렬은 수를 칸에 가지런히 늘어놓은 것입니다.", cells),
        beat(7, "가로 줄이 행, 세로 줄이 열입니다.", [
          ...[0, 1, 2].map((r) => ({ type: "polygon", id: `g${r}0`,
            points: roundRectPts(x0, y0 + r * ch, cw - 12, ch - 12, 12),
            stroke: r === 1 ? C.main : C.mute, fill: r === 1 ? C.main : undefined,
            fillOpacity: r === 1 ? 0.2 : 0, width: r === 1 ? 4 : 3 })),
          ...[0, 1, 2].map((r) => ({ type: "polygon", id: `g${r}1`,
            points: roundRectPts(x0 + cw, y0 + r * ch, cw - 12, ch - 12, 12),
            stroke: C.ok, fill: C.ok, fillOpacity: 0.2, width: 4 })),
          { type: "glabel", id: "rl", at: [x0 - 78, y0 + ch + ch / 2 - 6], text: "행", size: 32, color: C.main },
          { type: "glabel", id: "cl", at: [x0 + cw + cw / 2 - 6, y0 - 56], text: "열", size: 32, color: C.ok },
        ]),
        beat(8, "몇 번째 행, 몇 번째 열인지로 자리를 부릅니다.", [
          { type: "polygon", id: "g11", points: roundRectPts(x0 + cw, y0 + ch, cw - 12, ch - 12, 12),
            stroke: C.hot, fill: C.hot, fillOpacity: 0.45, width: 5 },
          { type: "glabel", id: "a22", at: [x0 + cw + (cw - 12) / 2, y0 + ch + (ch - 12) / 2], tex: "a_{22}", size: 32, color: C.hot },
        ]),
      ];
    },
    /* 좌표평면의 두 점 */
    linePlane() {
      const A = [-2, -1], B = [3, 3];
      const xr = [-4, 4.6], yr = [-3, 4.6];
      return [
        beat(6, "좌표평면에 두 점을 찍습니다.", [
          gpl(xr, yr),
          gpt("A", A, C.main, { label: "$A$" }),
          gpt("B", B, C.ok, { label: "$B$" }),
        ]),
        beat(8, "가로 차와 세로 차로 직각삼각형을 만들면 거리가 나옵니다.", [
          gseg("AB", A, B, C.hot, { width: 5 }),
          gseg("dx", A, [B[0], A[1]], C.mute, { width: 3.5, dashed: true }),
          gseg("dy", [B[0], A[1]], B, C.mute, { width: 3.5, dashed: true }),
          gtex("dxl", [(A[0] + B[0]) / 2, A[1] - 0.5], "\\Delta x", C.mute, 30),
          gtex("dyl", [B[0] + 0.55, (A[1] + B[1]) / 2], "\\Delta y", C.mute, 30),
        ]),
        beat(8, "선분을 정해진 비로 나눈 자리가 내분점입니다.", [
          gpt("P", [A[0] + (B[0] - A[0]) * 0.4, A[1] + (B[1] - A[1]) * 0.4], C.hot, { r: 14, label: "$P$" }),
          cap("f", 0, "\\sqrt{(\\Delta x)^2+(\\Delta y)^2}", C.ok, 38),
        ]),
      ];
    },
    /* 원과 직선의 위치 관계 */
    circleLine() {
      const xr = [-4.4, 4.4], yr = [-4.4, 4.4], R = 2;
      const rim = ovalPts(0, 0, R, R, 80);
      const line = (k) => (x) => -0.5 * x + k;
      return [
        beat(6, "중심과 반지름이 정해지면 원이 하나 정해집니다.", [
          gpl(xr, yr),
          gcrv("cir", rim, C.main),
          gpt("O", [0, 0], C.mute, { r: 10 }),
          gseg("r", [0, 0], [R * 0.71, R * 0.71], C.mute, { width: 3.5, dashed: true, label: "$r$" }),
        ]),
        beat(8, "직선을 밀어 보면 두 점에서 만나거나, 접하거나, 안 만납니다.", [
          gcrv("l1", sample(line(1), xr[0], xr[1], { n: 24, yMin: yr[0], yMax: yr[1] }), C.ok, { width: 4 }),
          gcrv("l2", sample(line(2.236), xr[0], xr[1], { n: 24, yMin: yr[0], yMax: yr[1] }), C.hot, { width: 4 }),
          gcrv("l3", sample(line(3.6), xr[0], xr[1], { n: 24, yMin: yr[0], yMax: yr[1] }), C.mute, { width: 4, dashed: true }),
        ]),
        beat(8, "중심에서 직선까지의 거리 $d$ 를 반지름 $r$ 과 견주면 바로 판정됩니다.", [
          gseg("d", [0, 0], [1, 1.736], C.hot, { width: 5 }),
          capText("t", 0, "d<r 두 점 · d=r 접함 · d>r 안 만남", C.mute, 32),
        ]),
      ];
    },
    /* 도형의 이동 */
    transform() {
      const t1 = [[-3, 0.6], [-1, 0.6], [-2, 2.8]];
      const t2 = t1.map((p) => [p[0] + 3.4, p[1]]);
      const t3 = t1.map((p) => [p[0], -p[1]]);
      const xr = [-4.4, 4.4], yr = [-3.6, 4];
      return [
        beat(6, "옮기기 전의 도형을 먼저 둡니다.", [
          gpl(xr, yr),
          gpoly("t1", t1, C.main, { fill: C.main, fillOpacity: 0.2, width: 4 }),
        ]),
        beat(8, "평행이동은 모든 점이 같은 만큼 미끄러지는 것입니다.", [
          gpoly("t2", t2, C.ok, { fill: C.ok, fillOpacity: 0.2, width: 4 }),
          ...t1.map((p, i) => gseg(`m${i}`, p, t2[i], C.mute, { width: 3, dashed: true })),
        ]),
        beat(8, "대칭이동은 축 너머로 뒤집는 것 — 좌표의 부호가 바뀝니다.", [
          gpoly("t3", t3, C.hot, { fill: C.hot, fillOpacity: 0.2, width: 4 }),
          ...t1.map((p, i) => gseg(`f${i}`, p, t3[i], C.hot, { width: 2.5, dashed: true })),
        ]),
      ];
    },
    /* 함수의 대응 */
    mapping() {
      const lx = ART.x + 210, rx = ART.x + 560, cy = ART.y + ART.h / 2;
      const ys = [-130, 0, 130];
      return [
        beat(6, "정의역과 공역을 두 덩어리로 그립니다.", [
          { type: "polygon", id: "X", points: ovalPts(lx, cy, 110, 210), stroke: C.main, fill: C.main, fillOpacity: 0.1, width: 4 },
          { type: "polygon", id: "Y", points: ovalPts(rx, cy, 110, 210), stroke: C.ok, fill: C.ok, fillOpacity: 0.1, width: 4 },
          { type: "glabel", id: "Xl", at: [lx, cy - 254], text: "X", size: 36, color: C.main },
          { type: "glabel", id: "Yl", at: [rx, cy - 254], text: "Y", size: 36, color: C.ok },
        ]),
        beat(8, "정의역의 원소마다 도착지가 딱 하나씩 정해져야 함수입니다.", [
          ...ys.map((d, i) => ({ type: "point", id: `x${i}`, at: [lx, cy + d], r: 12, color: C.main })),
          ...ys.map((d, i) => ({ type: "point", id: `y${i}`, at: [rx, cy + d * 0.65], r: 12, color: C.ok })),
          ...ys.map((d, i) => arrow(`ar${i}`, [lx + 34, cy + d], [rx - 34, cy + d * 0.65], C.hot, { width: 3.5, head: 20 })).flat(),
        ]),
        beat(8, "화살표를 이어 붙이면 합성함수, 거꾸로 돌리면 역함수입니다.", [
          ...ys.map((d, i) => arrow(`bk${i}`, [rx - 34, cy + d * 0.65 + 26], [lx + 34, cy + d + 26], C.mute, { width: 3, head: 18 })).flat(),
          capText("t", 0, "거꾸로 되돌리려면 일대일대응이어야 한다", C.mute, 30),
        ]),
      ];
    },
    /* 유리·무리함수 — 점근선 */
    rationalCurve() {
      const f = (x) => 1 / (x - 1) + 1;
      const xr = [-2.6, 4.6], yr = [-3.4, 5.4];
      return [
        beat(6, "먼저 다가가되 닿지 못하는 선 — 점근선을 긋습니다.", [
          gpl(xr, yr),
          { type: "vline", id: "va", plane: "gpl", x: 1, from: yr[0], to: yr[1], dashed: true, color: C.hot },
          gseg("ha", [xr[0], 1], [xr[1], 1], C.hot, { width: 3, dashed: true }),
        ]),
        beat(7, "곡선은 그 선을 넘지 않고 양쪽으로 갈라집니다.", [
          gcrv("l", sample(f, xr[0], 0.72, { n: 60, yMin: yr[0], yMax: yr[1] }), C.main),
          gcrv("r", sample(f, 1.28, xr[1], { n: 60, yMin: yr[0], yMax: yr[1] }), C.main),
        ]),
        beat(8, "분모를 $0$ 으로 만드는 값은 정의역에서 빠집니다.", [
          gpt("hole", [1, 1], C.hot, { r: 13 }),
          cap("f", 0, "x\\ne1", C.hot, 42),
        ]),
      ];
    },
    /* 복소평면 */
    complexPlane() {
      const xr = [-4, 4], yr = [-4, 4];
      return [
        beat(6, "복소수는 실수부와 허수부를 좌표로 갖는 평면 위의 점입니다.", [
          gpl(xr, yr, { xLabel: "실수", yLabel: "허수" }),
          gpt("z", [3, 2], C.hot, { r: 14, label: "$z$" }),
        ]),
        beat(8, "가로가 실수부, 세로가 허수부입니다.", [
          gseg("re", [0, 0], [3, 0], C.main, { width: 5 }),
          gseg("im", [3, 0], [3, 2], C.ok, { width: 5 }),
          gseg("oz", [0, 0], [3, 2], C.mute, { width: 3.5, dashed: true }),
          gtex("rl", [1.5, -0.55], "a", C.main, 32),
          gtex("il", [3.5, 1], "b", C.ok, 32),
        ]),
        beat(8, "켤레복소수는 실수축을 거울로 뒤집은 점입니다.", [
          gpt("zc", [3, -2], C.main, { r: 14, label: "$\\bar z$" }),
          gseg("mir", [3, 2], [3, -2], C.hot, { width: 3, dashed: true }),
        ]),
      ];
    },
  };

  register("common-math-concept", (v, ctx) => {
    // conceptId 표가 단원을 정확히 말해 준다. 표에 없으면 문장으로 유추하고,
    // 그것도 실패하면 기존 폴백(대표 배경 + 단계 카드)에 그대로 맡긴다.
    const topic = CONCEPT_TOPIC[String(v.conceptId || "")] || inferTopic(ctx);
    const art = topic && CONCEPT_ART[topic];
    if (!art) return buildGeneric(ctx || {});
    return withSteps(`sol-cm-${topic}`, art(v, ctx), ctx);
  });

  /* ============================================================
     그림 조립 키트 — 폴백이 "그림"을 그리기 위해 쓰는 원시 도형 헬퍼.

     scenario-player 가 아는 액션(plane/plot/point/seg/vline/fill/polygon/
     circle/brace/glabel/mover/blocks)만 조합한다. 플레이어는 남의 파일이라
     새 액션 타입을 만들 수 없다 — 있는 것으로 그린다.
     ============================================================ */

  /** 원·타원 둘레 점렬.
      circle 액션을 안 쓰는 이유: 무대 bbox(spContentBounds)가 center 만 보고
      반지름을 안 세서, plane 밖(화면 좌표)에 큰 원을 두면 가장자리가 잘린다.
      polygon 은 points 를 전부 세므로 안전하다. */
  function ovalPts(cx, cy, rx, ry, n) {
    const out = [];
    const k = n || 48;
    for (let i = 0; i < k; i++) {
      const t = (i / k) * Math.PI * 2;
      out.push([cx + rx * Math.cos(t), cy + ry * Math.sin(t)]);
    }
    return out;
  }

  /** 모서리 둥근 사각형 점렬 (화면 좌표) — 단계 카드의 몸통 */
  function roundRectPts(x, y, w, h, r) {
    const k = Math.max(2, Math.min(r, w / 2, h / 2));
    const corner = (cx, cy, a0, a1) => {
      const out = [];
      for (let i = 0; i <= 4; i++) {
        const a = a0 + ((a1 - a0) * i) / 4;
        out.push([cx + k * Math.cos(a), cy + k * Math.sin(a)]);
      }
      return out;
    };
    return [
      ...corner(x + w - k, y + k, -Math.PI / 2, 0),
      ...corner(x + w - k, y + h - k, 0, Math.PI / 2),
      ...corner(x + k, y + h - k, Math.PI / 2, Math.PI),
      ...corner(x + k, y + k, Math.PI, Math.PI * 1.5),
    ];
  }

  /** 화살표 = 몸통 seg + 삼각 머리 polygon. seg 만으로는 방향이 안 보인다. */
  function arrow(id, from, to, color, opts) {
    opts = opts || {};
    const dx = to[0] - from[0], dy = to[1] - from[1];
    const len = Math.hypot(dx, dy) || 1;
    const ux = dx / len, uy = dy / len;
    const head = Math.min(opts.head || 22, len * 0.5);
    const base = [to[0] - ux * head, to[1] - uy * head];
    const wing = head * 0.55;
    return [
      { type: "seg", id: `${id}s`, from, to: base, color, width: opts.width || 4 },
      {
        type: "polygon", id: `${id}h`, width: 2, stroke: color, fill: color, fillOpacity: 1,
        points: [to, [base[0] - uy * wing, base[1] + ux * wing], [base[0] + uy * wing, base[1] - ux * wing]],
      },
    ];
  }

  /* ---------- 단계 아이콘 — 그 단계가 '무슨 짓을 하는지' 를 도형으로 ----------
     사용자 요구: "텍스트 이쁘게 쓰지 말고 아이콘으로 대체". 산문 단계는 글자를
     지우고 이 아이콘만 남긴다(문장 전문은 자막이 한 번 읽어 준다). */
  function icon(id, op, cx, cy, s, color) {
    const seg = (n, a, b, o) => Object.assign({ type: "seg", id: `${id}${n}`, from: a, to: b, color, width: 3.5 }, o || {});
    const poly = (n, pts, o) => Object.assign({ type: "polygon", id: `${id}${n}`, points: pts, stroke: color, width: 3.5 }, o || {});
    const dot = (n, at, r) => ({ type: "point", id: `${id}${n}`, at, r: r || 6, color });
    const box = [[cx - s, cy - s], [cx + s, cy - s], [cx + s, cy + s], [cx - s, cy + s]];
    switch (op) {
      // 곱·전개 — 넓이 4조각 (이 앱이 강의에서 쓰는 바로 그 그림)
      case "mul": return [
        poly("b", box, { fill: color, fillOpacity: 0.12 }),
        seg("v", [cx - s * 0.2, cy - s], [cx - s * 0.2, cy + s], { width: 3 }),
        seg("h", [cx - s, cy - s * 0.2], [cx + s, cy - s * 0.2], { width: 3 }),
      ];
      // 약분·인수분해 — 분수를 사선으로 지운다
      case "split": return [
        seg("b", [cx - s, cy], [cx + s, cy], { width: 4 }),
        dot("u", [cx, cy - s * 0.55], 7),
        dot("d", [cx, cy + s * 0.55], 7),
        seg("x", [cx - s * 0.8, cy + s * 0.9], [cx + s * 0.8, cy - s * 0.9], { width: 3 }),
      ];
      // 대입 — 화살표가 상자 안으로 들어간다
      case "subst": return [
        poly("b", [[cx - s * 0.1, cy - s], [cx + s, cy - s], [cx + s, cy + s], [cx - s * 0.1, cy + s]]),
        ...arrow(`${id}a`, [cx - s * 1.5, cy], [cx + s * 0.35, cy], color, { head: s * 0.7, width: 3.5 }),
      ];
      // 이항·정리 — 좌우로 옮긴다
      case "move": return [
        ...arrow(`${id}r`, [cx - s, cy - s * 0.5], [cx + s, cy - s * 0.5], color, { head: s * 0.6, width: 3.5 }),
        ...arrow(`${id}l`, [cx + s, cy + s * 0.5], [cx - s, cy + s * 0.5], color, { head: s * 0.6, width: 3.5 }),
      ];
      // 부등식·범위 — 수직선 위 한쪽만 남는다
      case "compare": return [
        seg("l", [cx - s, cy], [cx + s, cy], { width: 3, color: C.mute }),
        seg("r", [cx - s * 0.1, cy], [cx + s, cy], { width: 9 }),
        dot("p", [cx - s * 0.1, cy], 8),
      ];
      // 미분 — 곡선 위 한 점의 접선
      case "diff": return [
        { type: "plot", id: `${id}c`, color, width: 3.5,
          points: sample((t) => cy + (t - cx) * (t - cx) * (0.9 / s) - s * 0.5, cx - s, cx + s, { n: 24 }) },
        seg("t", [cx - s * 0.2, cy - s * 0.5 + s * 0.6], [cx + s, cy - s * 0.5 - s * 0.55], { width: 3.5, color: C.hot }),
        dot("p", [cx + s * 0.35, cy - s * 0.5 + 0.03], 7),
      ];
      // 적분 — 곡선 아래를 채운다
      case "integ": return [
        { type: "plot", id: `${id}c`, color, width: 3.5,
          points: sample((t) => cy + s * 0.6 - (t - cx + s) * (0.9), cx - s, cx + s, { n: 12 }) },
        poly("f", [[cx - s, cy + s], [cx + s, cy + s], [cx + s, cy + s * 0.6 - 2 * s * 0.9], [cx - s, cy + s * 0.6]],
             { fill: color, fillOpacity: 0.3, width: 0.1 }),
      ];
      // 경우의 수·확률 — 칸을 센다
      case "count": return [
        { type: "blocks", id: `${id}b`, rect: { x: cx - s, y: cy - s, w: s * 2, h: s * 2 },
          rows: 2, cols: 3, count: 6, gap: 5, color },
      ];
      // 제곱근·유리화 — 기호 그 자체가 아이콘이다
      case "root": return [
        { type: "glabel", id: `${id}g`, at: [cx, cy], tex: "\\sqrt{\\phantom{x}}", size: s * 2.1, color },
      ];
      // 결론 — 과녁
      case "goal": return [
        poly("o", ovalPts(cx, cy, s, s, 32), { width: 4 }),
        poly("i", ovalPts(cx, cy, s * 0.55, s * 0.55, 24), { width: 3.5 }),
        dot("c", [cx, cy], s * 0.24),
      ];
      default: return [
        poly("d", [[cx, cy - s], [cx + s, cy], [cx, cy + s], [cx - s, cy]], { fill: color, fillOpacity: 0.14 }),
        dot("c", [cx, cy], s * 0.26),
      ];
    }
  }

  /* ---------- 단계 문장 → 아이콘 종류 ----------
     확실한 동사·명사만 본다. 애매하면 기본 마름모로 떨어뜨린다. */
  const OP_RULES = [
    [/따라서|그러므로|결국|답은|최종|구하는 값/, "goal"],
    [/미분|도함수|접선|기울기|변화율|극대|극소/, "diff"],
    [/적분|넓이|면적/, "integ"],
    [/경우의? ?수|가짓수|가지|확률|순열|조합|뽑|고르/, "count"],
    [/근호|제곱근|루트|유리화|\\sqrt/, "root"],
    [/부등식|이상|이하|미만|초과|범위|비교/, "compare"],
    [/인수분해|약분|나누|나눗|묶으|묶어/, "split"],
    [/대입|넣으|넣어/, "subst"],
    [/이항|정리하면|정리합니다|모으|더하|빼/, "move"],
    [/곱하|곱합|곱의|전개|분배/, "mul"],
  ];
  function opOf(text, isLast) {
    if (isLast) return "goal";
    const t = String(text || "");
    // 마지막이 아닌 단계에는 과녁을 주지 않는다. 중간에 "따라서" 가 섞여 있어도
    // 과녁이 두 번 뜨면 어디가 도착점인지 흐려진다 — 그 다음으로 맞는 연산을 쓴다.
    for (const [re, op] of OP_RULES) if (op !== "goal" && re.test(t)) return op;
    return "dot";
  }

  /* ============================================================
     개념 배경 그림 — "그 단원의 한 장" 을 폴백 무대 왼쪽에 세운다.

     전용 안무가 없는 유형이라도 이 그림 위에서 단계를 밟으면 화면이
     그림으로 읽힌다. 값은 그 회차 수치가 아니라 개념의 대표값이다
     (파라미터가 안 오는 유형이라 수치를 지어내면 오히려 거짓이 된다 —
     실제 수치는 오른쪽 단계 카드가 원문 그대로 보여 준다).
     ============================================================ */
  const ART = { x: 150, y: 165, w: 760, h: 690 };
  const artPlane = (xr, yr, opts) => plane("gpl", xr, yr, Object.assign({ rect: ART }, opts || {}));

  const BACKDROPS = {
    /* 다항식의 곱·전개 — 넓이 모델 */
    areaModel: {
      caption: "곱을 전개하는 일은 직사각형을 조각내어 넓이를 더하는 일과 같습니다.",
      build() {
        const x0 = ART.x + 70, y0 = ART.y + 110, W = 600, H = 500;
        const mx = x0 + W * 0.62, my = y0 + H * 0.6;
        const cell = (n, ax, ay, bx, by, color, tex) => ([
          { type: "polygon", id: `bd${n}`, points: [[ax, ay], [bx, ay], [bx, by], [ax, by]],
            stroke: color, fill: color, fillOpacity: 0.16, width: 3 },
          { type: "glabel", id: `bdl${n}`, at: [(ax + bx) / 2, (ay + by) / 2], tex, size: 34, color },
        ]);
        return [
          ...cell(1, x0, y0, mx, my, C.main, "x^2"),
          ...cell(2, mx, y0, x0 + W, my, C.ok, "a\\,x"),
          ...cell(3, x0, my, mx, y0 + H, C.ok, "b\\,x"),
          ...cell(4, mx, my, x0 + W, y0 + H, C.hot, "a\\,b"),
          // flip — spBrace 는 진행방향의 왼쪽 법선으로 부풀린다. 화면 좌표는 y 가
          // 아래로 자라므로 flip 을 안 주면 두 중괄호가 사각형 **안쪽**으로 접혀
          // 칸 글자를 덮는다.
          // label: "" 는 생략하면 안 된다 — 플레이어가 brace 라벨을 무조건 그리므로
          // 값이 없으면 화면에 문자열 "undefined" 가 찍힌다.
          { type: "brace", id: "bdw", from: [x0, y0 - 24], to: [x0 + W, y0 - 24], label: "", color: C.mute, flip: true },
          { type: "brace", id: "bdh", from: [x0 - 24, y0 + H], to: [x0 - 24, y0], label: "", color: C.mute, flip: true },
          // 변 이름은 brace 의 label 이 아니라 glabel 로 단다. brace label 은 무대
          // bbox 계산에서 글자 폭을 안 세기 때문에, 왼쪽 세로 중괄호의 라벨이
          // 카메라 왼쪽 밖으로 나가 잘렸다(glabel 은 폭을 세어 여백을 잡는다).
          { type: "glabel", id: "bdwl", at: [x0 + W / 2, y0 - 74], tex: "x+a", size: 32, color: C.mute },
          { type: "glabel", id: "bdhl", at: [x0 - 100, y0 + H / 2], tex: "x+b", size: 32, color: C.mute },
        ];
      },
    },
    /* 이차식 — 포물선과 근 */
    parabola: {
      caption: "이차식은 포물선입니다 — 축과 만나는 자리가 근입니다.",
      build() {
        const f = (x) => x * x - 2 * x - 3;
        return [
          artPlane([-3.2, 5.2], [-5.2, 5.4]),
          { type: "plot", id: "bdc", plane: "gpl", color: C.main, width: 5, drawSec: 1.4,
            points: sample(f, -3.2, 5.2, { n: 90, yMin: -5.2, yMax: 5.4 }) },
          { type: "point", id: "bdr1", plane: "gpl", at: [-1, 0], r: 12, color: C.hot },
          { type: "point", id: "bdr2", plane: "gpl", at: [3, 0], r: 12, color: C.hot },
          { type: "point", id: "bdv", plane: "gpl", at: [1, -4], r: 11, color: C.ok },
        ];
      },
    },
    /* 점과 직선 */
    linePlane: {
      caption: "좌표평면에 점과 직선을 놓고 거리를 잽니다.",
      build() {
        const g = (x) => 0.6 * x + 1;
        return [
          artPlane([-4, 4], [-3, 5]),
          { type: "plot", id: "bdc", plane: "gpl", points: sample(g, -4, 4, { n: 20 }), color: C.main, width: 5, drawSec: 1.1 },
          { type: "point", id: "bdp", plane: "gpl", at: [2, 4], r: 12, color: C.hot },
          { type: "seg", id: "bdd", plane: "gpl", from: [2, 4], to: [2.794, 2.676], color: C.ok, width: 4, dashed: true },
        ];
      },
    },
    /* 원과 직선 */
    circleLine: {
      caption: "중심에서 직선까지의 거리와 반지름을 견주면 위치가 정해집니다.",
      build() {
        const g = (x) => -0.5 * x + 3;
        const rim = [];
        for (let i = 0; i <= 72; i++) {
          const t = (i / 72) * Math.PI * 2;
          rim.push([2 * Math.cos(t), 2 * Math.sin(t)]);
        }
        return [
          artPlane([-4, 4], [-4, 4]),
          { type: "plot", id: "bdc", plane: "gpl", points: rim, color: C.main, width: 5, drawSec: 1.4 },
          { type: "plot", id: "bdl", plane: "gpl", points: sample(g, -4, 4, { n: 24, yMin: -4, yMax: 4 }), color: C.ok, width: 5, drawSec: 1.0 },
          { type: "point", id: "bdo", plane: "gpl", at: [0, 0], r: 10, color: C.mute },
          { type: "seg", id: "bdd", plane: "gpl", from: [0, 0], to: [1.2, 2.4], color: C.hot, width: 4, dashed: true },
        ];
      },
    },
    /* 접선 — 미분 */
    curveTangent: {
      caption: "곡선 위 한 점에서의 기울기 — 그 자리에서는 접선이 곡선을 대신합니다.",
      build() {
        const f = (x) => 0.35 * x * x * x - 1.4 * x;
        const df = (x) => 1.05 * x * x - 1.4;
        const a = 1.4, d = 1.1;
        return [
          artPlane([-2.6, 2.6], [-4.2, 4.2]),
          { type: "plot", id: "bdc", plane: "gpl", points: sample(f, -2.6, 2.6, { n: 90 }), color: C.main, width: 5, drawSec: 1.3 },
          { type: "seg", id: "bdt", plane: "gpl", color: C.hot, width: 4,
            from: [a - d, f(a) - df(a) * d], to: [a + d, f(a) + df(a) * d] },
          { type: "point", id: "bdp", plane: "gpl", at: [a, f(a)], r: 12, color: C.hot },
        ];
      },
    },
    /* 할선 — 평균변화율 */
    curveSecant: {
      caption: "두 점을 잇는 직선의 기울기가 평균변화율입니다.",
      build() {
        const f = (x) => 0.4 * x * x;
        const a = -1.6, b = 2.2;
        return [
          artPlane([-2.6, 2.8], [-0.8, 3.4]),
          { type: "plot", id: "bdc", plane: "gpl", points: sample(f, -2.6, 2.8, { n: 80 }), color: C.main, width: 5, drawSec: 1.3 },
          { type: "seg", id: "bds", plane: "gpl", from: [a, f(a)], to: [b, f(b)], color: C.hot, width: 4 },
          { type: "point", id: "bdp1", plane: "gpl", at: [a, f(a)], r: 11, color: C.hot },
          { type: "point", id: "bdp2", plane: "gpl", at: [b, f(b)], r: 11, color: C.hot },
          { type: "seg", id: "bddx", plane: "gpl", from: [a, f(a)], to: [b, f(a)], color: C.mute, width: 3, dashed: true },
          { type: "seg", id: "bddy", plane: "gpl", from: [b, f(a)], to: [b, f(b)], color: C.ok, width: 3, dashed: true },
        ];
      },
    },
    /* 넓이 — 정적분 */
    curveArea: {
      caption: "정적분은 곡선 아래의 넓이입니다.",
      build() {
        const f = (x) => 0.35 * x * x + 0.6;
        return [
          artPlane([-0.5, 3.5], [-0.4, 4.6]),
          { type: "plot", id: "bdc", plane: "gpl", points: sample(f, -0.5, 3.5, { n: 80 }), color: C.main, width: 5, drawSec: 1.3 },
          { type: "fill", id: "bdf", plane: "gpl", color: C.ok, opacity: 0.32,
            points: [[0.4, 0], ...sample(f, 0.4, 2.8, { n: 40 }), [2.8, 0]] },
          { type: "vline", id: "bdv1", plane: "gpl", x: 0.4, from: 0, to: f(0.4), color: C.mute, dashed: true },
          { type: "vline", id: "bdv2", plane: "gpl", x: 2.8, from: 0, to: f(2.8), color: C.mute, dashed: true },
        ];
      },
    },
    /* 증감 — 부호가 바뀌는 자리 */
    signChart: {
      caption: "도함수의 부호가 바뀌는 곳에서 곡선의 방향이 꺾입니다.",
      build() {
        const f = (x) => (x * x * x) / 3 - x;
        return [
          artPlane([-2.6, 2.6], [-2.4, 2.4]),
          { type: "fill", id: "bdf1", plane: "gpl", color: C.ok, opacity: 0.12,
            points: [[-2.6, -2.4], [-1, -2.4], [-1, 2.4], [-2.6, 2.4]] },
          { type: "fill", id: "bdf2", plane: "gpl", color: C.hot, opacity: 0.12,
            points: [[-1, -2.4], [1, -2.4], [1, 2.4], [-1, 2.4]] },
          { type: "plot", id: "bdc", plane: "gpl", color: C.main, width: 5, drawSec: 1.4,
            points: sample(f, -2.6, 2.6, { n: 90, yMin: -2.4, yMax: 2.4 }) },
          { type: "point", id: "bdp1", plane: "gpl", at: [-1, f(-1)], r: 12, color: C.ok },
          { type: "point", id: "bdp2", plane: "gpl", at: [1, f(1)], r: 12, color: C.hot },
        ];
      },
    },
    /* 부등식 — 수직선 위의 구간 */
    numberLine: {
      caption: "수직선 위에서 조건을 만족하는 구간만 남깁니다.",
      build() {
        return [
          artPlane([-5, 5], [-1.2, 1.2], { yTicks: [], showGrid: false, yLabel: "" }),
          { type: "seg", id: "bdr", plane: "gpl", from: [1, 0], to: [5, 0], color: C.hot, width: 16 },
          { type: "point", id: "bdp", plane: "gpl", at: [1, 0], r: 15, color: C.hot },
          { type: "brace", id: "bdb", plane: "gpl", from: [1, -0.4], to: [5, -0.4], label: "조건을 만족", color: C.ok },
        ];
      },
    },
    /* 집합·명제 — 벤 다이어그램 */
    venn: {
      caption: "두 조건을 원으로 그리면 겹친 곳이 곧 '둘 다' 입니다.",
      build() {
        const cx = ART.x + ART.w / 2, cy = ART.y + ART.h / 2, r = 160;
        return [
          { type: "polygon", id: "bdu", points: roundRectPts(ART.x + 40, ART.y + 60, ART.w - 80, ART.h - 120, 26),
            stroke: C.mute, width: 3 },
          { type: "glabel", id: "bdul", at: [ART.x + 86, ART.y + 104], text: "U", size: 34, color: C.mute },
          { type: "polygon", id: "bda", points: ovalPts(cx - 95, cy, r, r), stroke: C.main, fill: C.main, fillOpacity: 0.22, width: 4 },
          { type: "polygon", id: "bdb", points: ovalPts(cx + 95, cy, r, r), stroke: C.ok, fill: C.ok, fillOpacity: 0.22, width: 4 },
          { type: "glabel", id: "bdal", at: [cx - 200, cy], text: "A", size: 40, color: C.main },
          { type: "glabel", id: "bdbl", at: [cx + 200, cy], text: "B", size: 40, color: C.ok },
        ];
      },
    },
    /* 경우의 수 — 나뭇가지 */
    tree: {
      caption: "고를 수 있는 길을 갈래로 펼치면 경우의 수가 눈에 보입니다.",
      build() {
        const x0 = ART.x + 90, cy = ART.y + ART.h / 2;
        const acts = [{ type: "point", id: "bdr", at: [x0, cy], r: 14, color: C.main }];
        [-150, 150].forEach((y1, i) => {
          acts.push({ type: "seg", id: `bde1${i}`, from: [x0, cy], to: [x0 + 250, cy + y1], color: C.main, width: 4 });
          acts.push({ type: "point", id: `bdn1${i}`, at: [x0 + 250, cy + y1], r: 12, color: C.main });
          [-80, 80].forEach((d, j) => {
            acts.push({ type: "seg", id: `bde2${i}${j}`, from: [x0 + 250, cy + y1], to: [x0 + 550, cy + y1 + d], color: C.ok, width: 3.5 });
            acts.push({ type: "point", id: `bdn2${i}${j}`, at: [x0 + 550, cy + y1 + d], r: 11, color: C.ok });
          });
        });
        return acts;
      },
    },
    /* 표·행렬·거듭제곱 — 칸으로 센다 */
    grid: {
      caption: "칸을 채워 세면 수가 아니라 모양으로 보입니다.",
      build() {
        return [{ type: "blocks", id: "bdg", rect: { x: ART.x + 80, y: ART.y + 150, w: 500, h: 380 },
                  rows: 3, cols: 4, count: 12, gap: 12, color: C.main, countLabel: true }];
      },
    },
    /* 정규분포 */
    bell: {
      caption: "평균을 가운데 두고 좌우로 퍼진 분포로 보면 자리가 보입니다.",
      build() {
        const g = (x) => Math.exp(-(x * x) / 2);
        return [
          artPlane([-3.4, 3.4], [0, 1.2], { yTicks: [] }),
          { type: "plot", id: "bdc", plane: "gpl", points: sample(g, -3.4, 3.4, { n: 120 }), color: C.main, width: 5, drawSec: 1.4 },
          { type: "fill", id: "bdf", plane: "gpl", color: C.hot, opacity: 0.28,
            points: [[1, 0], ...sample(g, 1, 3.4, { n: 40 }), [3.4, 0]] },
          { type: "vline", id: "bdm", plane: "gpl", x: 0, from: 0, to: 1.05, dashed: true, color: C.mute, label: "$m$" },
        ];
      },
    },
    /* 이산분포 — 막대 */
    bars: {
      caption: "값마다 확률이 얼마인지 막대로 세워 봅니다.",
      build() {
        const pr = [0.06, 0.16, 0.28, 0.28, 0.16, 0.06];
        return [
          artPlane([-0.7, 5.7], [0, 0.36], { xTicks: [0, 1, 2, 3, 4, 5], yTicks: [], xLabel: "k", yLabel: "P" }),
          ...pr.map((p, i) => ({ type: "seg", id: `bdb${i}`, plane: "gpl", from: [i, 0], to: [i, p],
                                 color: i === 2 || i === 3 ? C.hot : C.main, width: 26 })),
        ];
      },
    },
    /* 함수의 대응 */
    mapping: {
      caption: "정의역의 원소가 어디로 가는지 화살표로 잇습니다.",
      build() {
        const lx = ART.x + 190, rx = ART.x + 570, cy = ART.y + ART.h / 2;
        const acts = [
          { type: "polygon", id: "bdA", points: ovalPts(lx, cy, 110, 215), stroke: C.main, fill: C.main, fillOpacity: 0.1, width: 4 },
          { type: "polygon", id: "bdB", points: ovalPts(rx, cy, 110, 215), stroke: C.ok, fill: C.ok, fillOpacity: 0.1, width: 4 },
          { type: "glabel", id: "bdAl", at: [lx, cy - 258], text: "X", size: 36, color: C.main },
          { type: "glabel", id: "bdBl", at: [rx, cy - 258], text: "Y", size: 36, color: C.ok },
        ];
        [-120, 0, 120].forEach((d, i) => {
          acts.push({ type: "point", id: `bdax${i}`, at: [lx, cy + d], r: 10, color: C.main });
          acts.push({ type: "point", id: `bdby${i}`, at: [rx, cy + d * 0.6], r: 10, color: C.ok });
          acts.push(...arrow(`bdar${i}`, [lx + 32, cy + d], [rx - 32, cy + d * 0.6], C.hot, { width: 3.5, head: 20 }));
        });
        return acts;
      },
    },
    /* 삼각함수 — 단위원 */
    unitCircle: {
      caption: "각을 단위원 위의 점으로 보면 삼각함수 값이 곧 좌표입니다.",
      build() {
        const th = Math.PI / 3, rim = [], arc = [];
        for (let i = 0; i <= 72; i++) {
          const t = (i / 72) * Math.PI * 2;
          rim.push([Math.cos(t), Math.sin(t)]);
        }
        for (let i = 0; i <= 32; i++) {
          const t = (th * i) / 32;
          arc.push([0.42 * Math.cos(t), 0.42 * Math.sin(t)]);
        }
        return [
          artPlane([-1.4, 1.4], [-1.4, 1.4], { xTicks: [-1, 1], yTicks: [-1, 1] }),
          { type: "plot", id: "bdc", plane: "gpl", points: rim, color: C.mute, width: 4, drawSec: 1.3 },
          { type: "plot", id: "bda", plane: "gpl", points: arc, color: C.hot, width: 6, drawSec: 0.9 },
          { type: "seg", id: "bdr", plane: "gpl", from: [0, 0], to: [Math.cos(th), Math.sin(th)], color: C.main, width: 4 },
          { type: "seg", id: "bdy", plane: "gpl", from: [Math.cos(th), 0], to: [Math.cos(th), Math.sin(th)], color: C.ok, width: 3.5, dashed: true },
          { type: "point", id: "bdp", plane: "gpl", at: [Math.cos(th), Math.sin(th)], r: 12, color: C.hot },
        ];
      },
    },
    /* 수열 */
    sequenceDots: {
      caption: "항을 자리마다 찍어 보면 규칙이 모양으로 드러납니다.",
      build() {
        const vals = [2, 5, 8, 11, 14, 17];
        return [
          artPlane([0, 7], [0, 20], { xTicks: [1, 2, 3, 4, 5, 6], xLabel: "n", yLabel: "a_n" }),
          ...vals.map((y, i) => ({ type: "point", id: `bdp${i}`, plane: "gpl", at: [i + 1, y], r: 11, color: C.main })),
          ...vals.slice(1).map((y, i) => ({ type: "seg", id: `bds${i}`, plane: "gpl",
            from: [i + 1, vals[i]], to: [i + 2, y], color: C.ok, width: 3, dashed: true })),
        ];
      },
    },
    /* 유리·무리함수 — 점근선 */
    rationalCurve: {
      caption: "점근선에 다가가되 닿지 않는 곡선입니다.",
      build() {
        const f = (x) => 1 / (x - 1) + 1;
        return [
          artPlane([-2.6, 4.6], [-3.4, 5.4]),
          { type: "plot", id: "bdl", plane: "gpl", color: C.main, width: 5, drawSec: 1.2,
            points: sample(f, -2.6, 0.72, { n: 60, yMin: -3.4, yMax: 5.4 }) },
          { type: "plot", id: "bdr", plane: "gpl", color: C.main, width: 5, drawSec: 1.2,
            points: sample(f, 1.28, 4.6, { n: 60, yMin: -3.4, yMax: 5.4 }) },
          { type: "vline", id: "bdv", plane: "gpl", x: 1, from: -3.4, to: 5.4, dashed: true, color: C.hot },
          { type: "seg", id: "bdh", plane: "gpl", from: [-2.6, 1], to: [4.6, 1], dashed: true, color: C.hot, width: 3 },
        ];
      },
    },
    /* 복소평면 */
    complexPlane: {
      caption: "복소수는 평면 위의 점 — 실수부와 허수부가 좌표입니다.",
      build() {
        return [
          artPlane([-4, 4], [-4, 4], { xLabel: "실수", yLabel: "허수" }),
          { type: "seg", id: "bdo", plane: "gpl", from: [0, 0], to: [3, 2], color: C.main, width: 4 },
          { type: "seg", id: "bdx", plane: "gpl", from: [3, 0], to: [3, 2], color: C.ok, width: 3, dashed: true },
          { type: "seg", id: "bdy", plane: "gpl", from: [0, 2], to: [3, 2], color: C.ok, width: 3, dashed: true },
          { type: "point", id: "bdz", plane: "gpl", at: [3, 2], r: 13, color: C.hot },
        ];
      },
    },
    /* 지수·로그 — 서로 거울상인 두 곡선.
       심화 문항 실측에서 지수·로그 단원이 그림 없이 떨어지고 있었다(치환·상용로그 등). */
    expLog: {
      caption: "지수와 로그는 $y=x$ 를 거울로 뒤집은 한 쌍입니다.",
      build() {
        const e = (x) => Math.pow(2, x);
        const l = (x) => Math.log(x) / Math.log(2);
        return [
          artPlane([-3.4, 5.4], [-3.4, 5.4]),
          { type: "plot", id: "bde", plane: "gpl", color: C.main, width: 5, drawSec: 1.2,
            points: sample(e, -3.4, 2.5, { n: 70, yMin: -3.4, yMax: 5.4 }) },
          { type: "plot", id: "bdl", plane: "gpl", color: C.ok, width: 5, drawSec: 1.2,
            points: sample(l, 0.09, 5.4, { n: 70, yMin: -3.4, yMax: 5.4 }) },
          { type: "seg", id: "bdm", plane: "gpl", from: [-3.4, -3.4], to: [5.4, 5.4],
            color: C.mute, width: 3, dashed: true },
          { type: "point", id: "bdp1", plane: "gpl", at: [0, 1], r: 11, color: C.main },
          { type: "point", id: "bdp2", plane: "gpl", at: [1, 0], r: 11, color: C.ok },
        ];
      },
    },
    /* 삼각형의 변·각·높이 — 사인·코사인법칙 단원 */
    triangle: {
      caption: "변과 각, 그리고 내린 높이를 한 그림에 두고 봅니다.",
      build() {
        // 좌표평면을 쓰지 않는다 — 플레이어가 축을 무조건 그리는데, 순수 도형 그림에
        // x·y 축이 가로질러 나오면 삼각형이 좌표 문제처럼 잘못 읽힌다.
        const A = [530, 250], B = [230, 700], Cc = [830, 700], F = [530, 700];
        const rightAngle = [[F[0], F[1] - 34], [F[0] + 34, F[1] - 34], [F[0] + 34, F[1]]];
        return [
          { type: "polygon", id: "bdt", points: [A, B, Cc], stroke: C.main, fill: C.main, fillOpacity: 0.14, width: 4 },
          { type: "seg", id: "bdh", from: A, to: F, color: C.hot, width: 4, dashed: true },
          { type: "polygon", id: "bdra", points: rightAngle, stroke: C.hot, width: 2.5, closed: false },
          { type: "point", id: "bdf", at: F, r: 9, color: C.hot },
          { type: "glabel", id: "bdA", at: [A[0], A[1] - 52], text: "A", size: 34, color: C.ink },
          { type: "glabel", id: "bdB", at: [B[0] - 44, B[1] + 26], text: "B", size: 34, color: C.ink },
          { type: "glabel", id: "bdC", at: [Cc[0] + 44, Cc[1] + 26], text: "C", size: 34, color: C.ink },
          { type: "glabel", id: "bdhl", at: [A[0] - 46, (A[1] + F[1]) / 2], tex: "h", size: 32, color: C.hot },
          { type: "glabel", id: "bda", at: [(B[0] + Cc[0]) / 2, Cc[1] + 52], tex: "a", size: 32, color: C.ok },
          { type: "glabel", id: "bdc", at: [(A[0] + B[0]) / 2 - 44, (A[1] + B[1]) / 2], tex: "c", size: 32, color: C.ok },
          { type: "glabel", id: "bdb", at: [(A[0] + Cc[0]) / 2 + 44, (A[1] + Cc[1]) / 2], tex: "b", size: 32, color: C.ok },
        ];
      },
    },
    /* 연속·불연속 — 이어지는가, 끊기는가 */
    continuity: {
      caption: "이어져 있으면 연속, 한 자리라도 끊기면 그 점에서 불연속입니다.",
      build() {
        const f = (x) => 0.5 * x + 1;
        const g = (x) => 0.5 * x - 1.4;
        return [
          artPlane([-4, 4], [-3.4, 3.4]),
          { type: "plot", id: "bdl", plane: "gpl", color: C.main, width: 5, drawSec: 1.1,
            points: sample(f, -4, 0.98, { n: 40, yMin: -3.4, yMax: 3.4 }) },
          { type: "plot", id: "bdr", plane: "gpl", color: C.main, width: 5, drawSec: 1.1,
            points: sample(g, 1.02, 4, { n: 40, yMin: -3.4, yMax: 3.4 }) },
          // 빈 동그라미 = 그 값을 갖지 않는다
          { type: "polygon", id: "bdo", plane: "gpl", points: ovalPts(1, f(1), 0.14, 0.2, 20), stroke: C.hot, width: 4 },
          { type: "point", id: "bdd", plane: "gpl", at: [1, g(1)], r: 11, color: C.hot },
          { type: "brace", id: "bdj", plane: "gpl", from: [1.34, g(1)], to: [1.34, f(1)], label: "뜀", color: C.hot },
        ];
      },
    },
    /* 도형의 이동 */
    transform: {
      caption: "도형을 통째로 옮기면 좌표가 같은 만큼 움직입니다.",
      build() {
        const t1 = [[-2.8, 0.4], [-0.8, 0.4], [-1.8, 2.4]];
        const t2 = t1.map((p) => [p[0] + 3.2, p[1] - 2]);
        return [
          artPlane([-4, 4], [-3, 4]),
          { type: "polygon", id: "bdt1", plane: "gpl", points: t1, stroke: C.main, fill: C.main, fillOpacity: 0.16, width: 4 },
          { type: "polygon", id: "bdt2", plane: "gpl", points: t2, stroke: C.hot, fill: C.hot, fillOpacity: 0.16, width: 4 },
          ...t1.map((p, i) => ({ type: "seg", id: `bdm${i}`, plane: "gpl", from: p, to: t2[i],
                                 color: C.mute, width: 3, dashed: true })),
        ];
      },
    },
  };

  /* ---------- kind → 배경 그림 ----------
     webgen-bundle 이 내보내지만 전용 안무가 없는 유형들. 이름이 곧 단원이라
     그림은 확실히 정할 수 있다(수치는 안 오므로 대표 그림만 세운다). */
  const KIND_TOPIC = {
    "calculus-definition": "curveSecant", "calculus-secant": "curveSecant", "calculus-mvt": "curveSecant",
    "calculus-tangent": "curveTangent", "calculus-line": "linePlane", "calculus-smooth": "curveTangent",
    "calculus-cusp": "curveTangent", "calculus-differentiability": "curveTangent",
    "calculus-piecewise-slope": "curveTangent", "calculus-piecewise-value": "curveTangent",
    "calculus-discontinuity": "curveTangent", "calculus-power": "curveTangent",
    "calculus-polynomial": "curveTangent", "calculus-motion": "curveTangent",
    "calculus-extrema": "signChart", "calculus-sign-chart": "signChart", "calculus-graph-shape": "signChart",
    "calculus-equation": "parabola", "calculus-inequality": "signChart",
    "calculus-antiderivative": "curveArea", "calculus-definite": "curveArea", "calculus-area": "curveArea",
    "calculus-riemann": "curveArea", "calculus-fundamental": "curveArea", "calculus-velocity-area": "curveArea",
    "probability-counting": "tree", "probability-tree": "tree", "probability-venn": "venn",
    "probability-concept": "venn", "probability-distribution": "bars", "probability-binomial": "bars",
    "probability-normal": "bell", "probability-sampling": "bell", "probability-confidence": "bell",
  };

  /* common-math-concept 는 conceptId 가 단원을 말해 준다 */
  const CONCEPT_TOPIC = {
    "polynomial-arithmetic": "areaModel", "identity-remainder-theorem": "areaModel",
    "polynomial-factorization": "areaModel",
    "complex-numbers": "complexPlane",
    "quadratic-discriminant": "parabola", "quadratic-roots-and-coefficients": "parabola",
    "quadratic-equation-and-function": "parabola", "parabola-and-line": "parabola",
    "quadratic-max-min-restricted": "parabola", "cubic-and-quartic-equations": "parabola",
    "simultaneous-quadratic-equations": "parabola",
    "quadratic-inequalities": "numberLine", "simultaneous-linear-inequalities": "numberLine",
    "absolute-linear-inequalities": "numberLine", "absolute-inequality": "numberLine",
    "addition-and-multiplication-principles": "tree", "permutations": "tree", "combinations": "tree",
    "matrix-concept": "grid", "matrix-operations": "grid",
    "distance-and-internal-division": "linePlane", "parallel-and-perpendicular-lines": "linePlane",
    "point-line-distance": "linePlane",
    "circle-equation": "circleLine", "circle-line-position": "circleLine",
    "geometric-translation": "transform", "geometric-reflection": "transform",
    "set-concept-and-representation": "venn", "set-inclusion": "venn", "set-operations": "venn",
    "proposition-and-condition": "venn", "converse-and-contrapositive": "venn",
    "sufficient-and-necessary-conditions": "venn", "proof-by-contrapositive-and-contradiction": "venn",
    "function-concept-and-graph": "mapping", "composite-function": "mapping", "inverse-function": "mapping",
    "rational-function": "rationalCurve", "irrational-function": "rationalCurve",
  };

  /* 발문·풀이 문장으로 단원을 읽는다. **확실한 신호만** 쓴다 —
     애매하면 배경 없이 단계 흐름만 그린다(잘못된 그림보다 낫다). */
  const TEXT_TOPIC = [
    [/전개했을 때|전개하면|전개한|곱을 전개|분배법칙|인수분해/, "areaModel"],
    [/판별식|포물선|이차함수의 그래프|이차방정식|근과 계수/, "parabola"],
    [/접선|미분계수|도함수|순간변화율|극댓값|극솟값|증가.*감소|증감표/, "curveTangent"],
    [/평균변화율|할선/, "curveSecant"],
    [/정적분|부정적분|적분|곡선.*넓이/, "curveArea"],
    [/부등식|해의 범위|이상이고|이하이고|수직선/, "numberLine"],
    [/집합|명제|충분조건|필요조건|부분집합|여집합|대우/, "venn"],
    [/경우의 수|가짓수|순열|조합|뽑는|나열하는/, "tree"],
    [/정규분포|표준편차|표본평균|신뢰구간|표준화/, "bell"],
    [/이항분포|확률변수|확률분포|기댓값/, "bars"],
    [/수열|등차|등비|일반항|제\s*n\s*항/, "sequenceDots"],
    [/삼각함수|사인|코사인|탄젠트|\\sin|\\cos|\\tan|호도법|단위원/, "unitCircle"],
    [/원의 방정식|중심.*반지름|원과 직선/, "circleLine"],
    [/합성함수|역함수|정의역|치역|일대일대응/, "mapping"],
    [/유리함수|무리함수|점근선/, "rationalCurve"],
    [/복소수|허수|켤레/, "complexPlane"],
    [/평행이동|대칭이동/, "transform"],
    [/행렬/, "grid"],
    /* 2단계 — 위에서 하나도 안 걸렸을 때만 보는 단원 이름들.
       앞줄보다 넓은 말이라 순서를 뒤에 둔다(접선 문제가 "다항식" 때문에
       넓이 모델로 끌려가면 안 된다). 커버리지 실측에서 그림 없이 떨어지던
       8개 개념을 이 줄들이 덮는다. */
    [/항등식|나머지정리|인수정리|다항식|동류항|내림차순/, "areaModel"],
    [/극한|\\lim|수렴하|발산하|좌극한|우극한/, "rationalCurve"],
    [/최댓값|최솟값|꼭짓점|삼차방정식|사차방정식|고차방정식/, "parabola"],
    [/합의 법칙|곱의 법칙|방법의 수|가지 수|배열하|짝지/, "tree"],
    [/내분점|외분점|두 점 사이의 거리|중점|평행한 직선|수직인 직선|직선의 방정식|점과 직선 사이의 거리/, "linePlane"],
    [/대응|일대일|함숫값|합성|역함수/, "mapping"],
    /* 3단계 — 심화 문항 실측(2026-08)에서 그림 없이 떨어지던 40개 템플릿을 덮는다.
       여기까지 왔다는 것은 위의 좁은 규칙이 전부 안 걸렸다는 뜻이라, 넓은 말을 써도
       엉뚱한 그림으로 끌려갈 위험이 낮다. */
    [/조건부확률|사후확률|베이즈|독립시행|적어도 한 번|주머니|주사위|동전|복원추출|비복원/, "tree"],
    [/사인법칙|코사인법칙|외접원|내접원|이등변삼각형|삼각형.*넓이|밑변|빗변|피타고라스/, "triangle"],
    [/상용로그|밑을 바꾸|로그의 성질|지수법칙|\\log|로그|지수/, "expLog"],
    [/연속|불연속|사잇값|중간값 정리|이어져/, "continuity"],
    [/극대|극소|증가하다|감소하다|도함수의 부호/, "signChart"],
    [/최단경로|격자점|행렬/, "grid"],
    [/이항전개|이항정리|계수합/, "areaModel"],
    [/평균|분산|가중평균|중앙값|자료/, "bars"],
    [/자리 자연수|배열하|숫자를 골라|양끝|한 줄로/, "tree"],
    [/확률을 구하시오|확률은|경우를 모두|사건/, "tree"],
    [/접점|접하는 직선/, "curveTangent"],
    // 한국어 단어 없이 식만 오는 경우 — 지수 자리에 x 가 있으면 지수·로그 단원이다
    // ($3^{2x}$, $3^{x}$ 는 걸리고 $x^{2}$ 는 안 걸린다).
    [/\^\{?[0-9]*x/, "expLog"],
  ];

  /** payload → 배경 그림 이름 (없으면 null).
      1) viz.kind 표 → 2) viz.conceptId 표 → 3) 발문·단계 문장 */
  function inferTopic(ctx) {
    const viz = (ctx && ctx.viz) || {};
    const kind = viz.kind || (ctx && ctx.kind) || "";
    if (KIND_TOPIC[kind]) return KIND_TOPIC[kind];
    const cid = String(viz.conceptId || "");
    if (CONCEPT_TOPIC[cid]) return CONCEPT_TOPIC[cid];
    const text = [ctx && ctx.statement, ...((ctx && ctx.steps) || [])].filter(Boolean).join(" ");
    for (const [re, topic] of TEXT_TOPIC) if (re.test(text)) return topic;
    return null;
  }

  /* ============================================================
     범용 폴백 — 어떤 유형이든 마지막에 여기로 떨어진다. 그래서 이 화면의
     바닥 품질이 곧 폴백의 품질이다.

     예전에는 "세로 회색 직선 + 단계 문자열 나열" 이었다. '그림으로' 모드인데
     그림이 없었다. 지금은
       · 왼쪽: 그 단원의 대표 그림 (inferTopic)
       · 오른쪽: 단계마다 카드 + 무슨 연산인지 말하는 아이콘 + 그 단계의 식
       · 마지막: 과녁과 함께 도착점으로서의 답
     글자는 보조다 — 산문뿐인 단계는 아이콘만 남기고 문장은 자막이 읽는다.
     ============================================================ */
  function buildGeneric(ctx, opts) {
    opts = opts || {};
    // opts.introBeats — 유형 전용 빌더가 그 문항의 수치로 그린 도입 안무.
    // 있으면 대표 배경 그림 대신 그것을 왼쪽에 세우고, 단계 카드는 그대로 오른쪽에 둔다.
    // (전용 그림 + 내 문제의 풀이 단계, 둘 다 필요하다)
    const intro = (opts.introBeats && opts.introBeats.length) ? opts.introBeats : null;
    const steps = (ctx.steps || []).filter((s) => String(s || "").trim()).slice(0, 6);
    if (!steps.length) return intro ? { id: "sol-generic", beats: intro } : null;
    // 수식 구분자를 보존해야 spMixed 가 KaTeX 로 조판한다. 달러를 벗기면
    // x^{2} 같은 소스가 그대로 보인다. 구 MathJax 구분자만 앱의 $ 규약으로 맞춘다.
    const mixed = (s) => TextContract
      ? TextContract.normalize(s)
      : String(s).replace(/\\\(/g, "$").replace(/\\\)/g, "$").trim();
    const normalized = steps.map(mixed);
    const n = normalized.length;

    /* 단계 하나에서 "무대에 그릴 식" 만 뽑는다. 식이 없으면 아무 글자도 두지
       않는다 — 아이콘이 그 자리를 대신하고, 문장 전문은 자막이 읽는다.
       (예전에는 산문을 30자로 잘라 무대에 얹어서, 그림이어야 할 화면이
        글자 나열이 됐다.)
       수식이 여럿이면 **가장 긴 것**을 고른다. 예전처럼 마지막 것을 고르면
       "…남학생 중 $5$명" 같은 문장에서 부속 숫자가 대표식으로 올라온다. */
    const stageMath = (text) => {
      const parts = text.split("$");
      let best = "";
      for (let i = 1; i < parts.length; i += 2) {
        const m = (parts[i] || "").trim();
        if (m && m.length >= best.length) best = m;
      }
      return best;
    };

    // 배경 그림 — 있으면 왼쪽에 세우고, 없으면 단계 흐름만 넓게 쓴다.
    // 전용 도입 안무가 이미 왼쪽을 쓰고 있으면 대표 그림은 세우지 않는다(겹친다).
    const topicName = intro ? null : inferTopic(ctx);
    const backdrop = topicName ? BACKDROPS[topicName] : null;
    const hasArt = !!intro || !!backdrop;
    // 어느 단계에도 식이 없으면 카드는 아이콘만 담는다 — 그때까지 넓은 카드를
    // 유지하면 빈 상자만 늘어서므로 폭을 줄여 아이콘 흐름으로 읽히게 한다.
    const anyMath = normalized.some((t) => stageMath(t));
    const wide = anyMath ? 830 : 400;
    const col = hasArt ? { x: 1000, w: wide } : { x: 240, w: anyMath ? 1050 : 460 };

    const TOP = 155, BOTTOM = 895;
    const slot = Math.min(178, (BOTTOM - TOP) / n);
    const cardH = Math.max(70, slot - 38);
    const y0 = TOP + ((BOTTOM - TOP) - slot * n) / 2;
    const cy = (i) => y0 + slot * (i + 0.5);
    const iconX = col.x + 142, badgeX = col.x + 52;
    const chipX = col.x + 216 + (col.w - 216) / 2;
    const iconS = Math.min(34, cardH / 2 - 12);
    const chipSize = Math.max(26, Math.min(44, cardH * 0.42));

    const beats = [];
    if (intro) beats.push(...intro);
    else if (backdrop) beats.push(beat(6, backdrop.caption, backdrop.build()));

    normalized.forEach((text, i) => {
      const last = i === n - 1;
      const color = last ? C.ok : C.main;
      const y = cy(i);
      const acts = [
        // 카드 — 단계가 하나의 덩어리로 보이게
        { type: "polygon", id: `gc${i}`, width: 3, stroke: color, fill: color, fillOpacity: 0.09,
          points: roundRectPts(col.x, y - cardH / 2, col.w, cardH, 26), drawSec: 0.8 },
        // 단계 번호 배지 (동그라미 + 숫자)
        { type: "point", id: `gb${i}`, at: [badgeX, y], r: Math.min(22, cardH / 2 - 8), color },
        { type: "glabel", id: `gbn${i}`, at: [badgeX, y], text: String(i + 1),
          size: Math.min(28, cardH * 0.3), color: "#FFFFFF" },
        // 이 단계가 하는 일 — 아이콘.
        // 단계가 하나뿐이면 '도착' 을 따로 표시할 필요가 없으므로 그 단계
        // 본연의 연산 아이콘을 쓴다(과녁이 두 줄 연달아 나오면 뜻이 흐려진다).
        ...icon(`gi${i}`, opOf(text, last && n > 1), iconX, y, iconS, last ? C.ok : C.hot),
      ];
      const math = stageMath(text);
      if (math) {
        acts.push({ type: "glabel", id: `gm${i}`, at: [chipX, y], tex: math, size: chipSize, color: C.ink });
      }
      // 앞 단계에서 이 단계로 내려오는 화살표 — 흐름이 눈에 보이게
      if (i > 0) {
        acts.push(...arrow(`ga${i}`, [iconX, cy(i - 1) + cardH / 2 + 5], [iconX, y - cardH / 2 - 5],
                           C.mute, { width: 3.5, head: Math.min(18, slot - cardH - 8) }));
      }
      const safeSubtitle = TextContract ? TextContract.standalone(text) : "";
      beats.push(beat(Math.max(5, Math.min(11, 4 + Math.ceil(text.length / 14))),
                      safeSubtitle || `${i + 1}단계를 확인합니다.`, acts));
    });

    if (ctx.answer) {
      const answer = mixed(ctx.answer);
      const answerMath = answer.includes("$") ? answer : `$${answer}$`;
      const ansY = Math.min(1010, y0 + slot * n + 66);
      beats.push(beat(6, "여기까지 오면 답에 닿습니다.", [
        // 도착점 — 과녁이 달린 띠
        { type: "polygon", id: "gans", width: 4, stroke: C.ok, fill: C.ok, fillOpacity: 0.16,
          points: roundRectPts(col.x, ansY - 56, col.w, 112, 26), drawSec: 0.7 },
        ...icon("gag", "goal", iconX, ansY, 32, C.ok),
        { type: "glabel", id: "gansv", at: [chipX, ansY], text: `답  ${answerMath}`, size: 50, color: C.ok },
        // 마지막 단계 카드를 초록으로 바꿔 '도착' 을 잇는다
        { type: "polygon", id: `gc${n - 1}`, width: 4, stroke: C.ok, fill: C.ok, fillOpacity: 0.16,
          points: roundRectPts(col.x, cy(n - 1) - cardH / 2, col.w, cardH, 26) },
      ]));
    }
    return { id: "sol-generic", beats };
  }

  /* ============================================================
     공개 API
     ============================================================ */
  const API = {
    /** 이 유형에 전용 안무가 있는가 */
    has(kind) { return !!(kind && BUILDERS[kind]); },
    kinds() { return Object.keys(BUILDERS); },
    /**
     * payload = { kind, viz, steps, statement, answer, typeName }
     * 전용 안무 → 실패하면 범용 폴백 → 그것도 없으면 null
     */
    build(payload) {
      payload = payload || {};
      const viz = payload.viz || (payload.kind ? { kind: payload.kind } : null);
      const kind = (viz && viz.kind) || payload.kind;
      if (kind && BUILDERS[kind]) {
        try {
          const sc = BUILDERS[kind](viz || {}, payload);
          if (sc && sc.beats && sc.beats.length) return sc;
        } catch (e) {
          if (typeof console !== "undefined") console.log("solution scene 실패", kind, e && e.message);
        }
      }
      return buildGeneric(payload);
    },
    register,
    _helpers: { plane, sample, note, noteText, beat, nf, sg, term, head, C, buildGeneric },
  };

  root.MatthsSolutionScenes = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
