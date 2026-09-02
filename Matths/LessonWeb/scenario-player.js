/* ============================================================
   맵쓰 3b1b 시나리오 플레이어
   hs-math-concepts v2 엔진(beat 기반 선언적 애니메이션)의 vanilla JS 포트.
   - 시나리오 JSON을 그대로 소비 (SCENARIOS 전역, scenarios-data.js)
   - 자동 진행(연속 타임라인) · 일시정지 · 진행바 시킹 · 배속
   - KaTeX 수식 조판 (렌더 결과 캐시)
   - 색상은 맵쓰 팔레트로 리매핑
   ============================================================ */

const SP_FPS = 30;
const SP_W = 1920, SP_H = 1080;

/* 원본 팔레트 → 시맨틱 그래프 팔레트 리매핑 (RG-17·18)
   주 대상은 파랑, 보조 대상은 바이올렛, 강조는 마젠타 — brand.css 토큰과 같은 값.
   구 CI 색(네이비·레드)이 구워진 데이터(scenarios-data.js 는 자동 생성이라
   손대지 않는다)도 여기서 렌더 시점에 같이 살린다. 빨강은 오류 의미로만 남긴다. */
const SP_COLOR_MAP = {
  "#3D6BE5": "#327FFA", // 3b1b blue(주 대상) → graph-primary
  "#F2703A": "#7B4EFC", // 3b1b coral(보조 대상) → graph-secondary
  "#2FA36B": "#178A4C", // 3b1b green → 맵쓰 그린 (state-correct)
  "#D95454": "#CA44E3", // 3b1b red(강조) → graph-highlight
  "#1E2A44": "#26221C", // ink → 맵쓰 잉크
  "#8B93A5": "#8B8578", // muted → 웜 뮤트
  "#1E3799": "#327FFA", // 구 네이비(주 대상) → graph-primary
  "#E8302A": "#7B4EFC", // 구 레드(보조·대비 대상) → graph-secondary
  "#C81F1A": "#CA44E3", // 구 딥레드(강조) → graph-highlight
};
const SP = {
  bg: "#FDFCFA",
  ink: "#26221C",
  muted: "#8B8578",
  grid: "rgba(38,34,28,0.07)",
  axis: "rgba(38,34,28,0.45)",
  accent: "#327FFA",
};
const spColor = (c, fallback) => {
  if (!c) return fallback;
  const up = c.toUpperCase();
  return SP_COLOR_MAP[up] || c;
};

/* ---------- KaTeX 헬퍼 (캐시) ---------- */
const _texCache = new Map();
function spTex(tex, displayMode = false) {
  const key = (displayMode ? "D:" : "I:") + tex;
  if (_texCache.has(key)) return _texCache.get(key);
  let html;
  try {
    html = katex.renderToString(tex, { throwOnError: false, displayMode });
  } catch (e) {
    html = tex;
  }
  _texCache.set(key, html);
  return html;
}
/* "$...$" 혼합 텍스트 → HTML */
function spMixed(text) {
  return String(text)
    .split(/(\$[^$]+\$)/)
    .map((seg) =>
      seg.startsWith("$") && seg.endsWith("$")
        ? `<span class="sp-tex">${spTex(seg.slice(1, -1))}</span>`
        : `<span>${seg.replace(/</g, "&lt;")}</span>`
    )
    .join("");
}

/* ---------- svgeom 포트 ---------- */
function spPlaneMapper(pl) {
  const sx = pl.rect.w / (pl.xRange[1] - pl.xRange[0]);
  const sy = pl.rect.h / (pl.yRange[1] - pl.yRange[0]);
  return (p) => [
    pl.rect.x + (p[0] - pl.xRange[0]) * sx,
    pl.rect.y + pl.rect.h - (p[1] - pl.yRange[0]) * sy,
  ];
}
const spIdentity = (p) => p;
function spPolyLen(pts) {
  let len = 0;
  for (let i = 1; i < pts.length; i++) len += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
  return len;
}
function spPath(pts, closed = false) {
  if (!pts.length) return "";
  const d = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p[0].toFixed(2)},${p[1].toFixed(2)}`).join(" ");
  return closed ? d + " Z" : d;
}
function spBrace(a, b, flip = false) {
  const dx = b[0] - a[0], dy = b[1] - a[1];
  const len = Math.hypot(dx, dy) || 1;
  const nx = (-dy / len) * (flip ? -1 : 1);
  const ny = (dx / len) * (flip ? -1 : 1);
  const off = 16, cap = 10;
  const ax = a[0] + nx * off, ay = a[1] + ny * off;
  const bx = b[0] + nx * off, by = b[1] + ny * off;
  const mx = (ax + bx) / 2 + nx * cap, my = (ay + by) / 2 + ny * cap;
  const d = [
    `M${a[0]},${a[1]} L${ax},${ay}`,
    `L${(ax + bx) / 2},${(ay + by) / 2}`,
    `M${mx},${my} L${(ax + bx) / 2},${(ay + by) / 2}`,
    `M${(ax + bx) / 2},${(ay + by) / 2} L${bx},${by}`,
    `L${b[0]},${b[1]}`,
  ].join(" ");
  return { d, labelAt: [(ax + bx) / 2 + nx * 34, (ay + by) / 2 + ny * 34] };
}

/* ---------- interpret 포트 ---------- */
const spSec = (s) => Math.round(s * SP_FPS);
const spLerp = (a, b, t) => a + (b - a) * t;
const spLerpVec = (a, b, t) => [spLerp(a[0], b[0], t), spLerp(a[1], b[1], t)];
const spLerpPts = (a, b, t) => (a.length !== b.length ? b : b.map((p, i) => spLerpVec(a[i], p, t)));
const spEase = (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);
const spClamp01 = (v) => Math.min(1, Math.max(0, v));

function spMorph(prev, next, t) {
  if (t >= 1) return next;
  const out = { ...next };
  for (const k of Object.keys(next)) {
    const pv = prev[k], nv = next[k];
    if (typeof pv === "number" && typeof nv === "number") out[k] = spLerp(pv, nv, t);
    else if (Array.isArray(pv) && Array.isArray(nv) && pv.length === 2 && typeof pv[0] === "number" && typeof nv[0] === "number" && nv.length === 2)
      out[k] = spLerpVec(pv, nv, t);
    else if (Array.isArray(pv) && Array.isArray(nv) && Array.isArray(pv[0]) && Array.isArray(nv[0]))
      out[k] = spLerpPts(pv, nv, t);
  }
  return out;
}

/* 시나리오가 실제로 사용하는 스테이지 영역(bbox) 계산 —
   1920×1080 영상 레이아웃을 앱 컨테이너에 맞게 잘라 확대하기 위함 */
function spContentBounds(sc) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  const grow = (x, y, px = 0, py = 0) => {
    x0 = Math.min(x0, x - px); y0 = Math.min(y0, y - py);
    x1 = Math.max(x1, x + px); y1 = Math.max(y1, y + py);
  };
  for (const b of sc.beats) {
    for (const a of b.actions) {
      switch (a.type) {
        case "plane":
          grow(a.rect.x, a.rect.y, 46, 40); // 눈금 숫자 여유
          grow(a.rect.x + a.rect.w, a.rect.y + a.rect.h, 60, 44);
          break;
        case "blocks":
          grow(a.rect.x, a.rect.y); grow(a.rect.x + a.rect.w + 110, a.rect.y + a.rect.h);
          break;
        default: {
          if (a.plane) break; // plane 좌표계 요소는 plane rect가 커버
          const pts = [];
          if (a.at) pts.push(a.at);
          if (a.from) pts.push(a.from);
          if (a.to) pts.push(a.to);
          if (a.center) pts.push(a.center);
          if (Array.isArray(a.points) && Array.isArray(a.points[0])) pts.push(...a.points);
          // glabel 은 점을 중심으로 좌우로 뻗는다(.sp-glabel: translate -50%, max-width 560).
          // 예전엔 여백을 size*3.2(최대 110px)로 잡았는데, 실제 라벨은 한쪽으로만
          // 280px 까지 자란다 — 그래서 무대 가장자리 캡션이 카메라 밖으로 나가 잘렸다
          // ("극한은 그 점의 값과 무관…" 이 끝에서 싹둑, 2026-07-29 시뮬 확인).
          // 글자 수로 실제 폭을 어림해 그만큼 확보한다.
          const pad = a.type === "glabel" ? spLabelHalf(a) : 50;
          const padY = a.type === "glabel" ? spLabelHalfHeight(a) : 34;
          for (const p of pts) grow(p[0], p[1], pad, padY);
        }
      }
    }
  }
  if (!Number.isFinite(x0)) { x0 = 0; y0 = 0; x1 = SP_W; y1 = SP_H; }
  const PAD = 26;
  x0 = Math.max(0, x0 - PAD); y0 = Math.max(0, y0 - PAD);
  x1 = Math.min(SP_W, x1 + PAD); y1 = Math.min(SP_H, y1 + PAD);
  return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

// glabel 의 반폭·반높이 어림. 실측은 DOM 이 붙어야 가능한데 바운즈는 컴파일 때
// 필요하므로 글자 수로 센다. CJK 는 한 글자 ≈ 1em, 그 외 ≈ 0.55em.
// $...$ 수식은 조판 후 조금 넓어지므로 1.15배 본다.
const SP_LABEL_MAX_W = 560;   // brand.css .sp-glabel max-width 와 같은 값
function spLabelText(a) {
  return a.tex ? String(a.tex) : String(a.text || "");
}
function spLabelWidth(a) {
  const t = spLabelText(a);
  if (!t) return 0;
  const size = a.size || 30;
  let em = 0;
  for (const ch of t) em += /[\u3000-\u9fff\uac00-\ud7af\uff00-\uffef]/.test(ch) ? 1 : 0.55;
  return Math.min(SP_LABEL_MAX_W, em * size * (a.tex ? 1.15 : 1));
}
function spLabelHalf(a) {
  return Math.max(110, spLabelWidth(a) / 2);
}
function spLabelHalfHeight(a) {
  const size = a.size || 30;
  // max-width 를 넘으면 줄바꿈된다(white-space: normal) — 줄 수만큼 높이가 는다
  const lines = Math.max(1, Math.ceil(spLabelWidth(a) / SP_LABEL_MAX_W));
  return size * 1.2 * lines;
}

function spCompile(sc) {
  const beatStarts = [];
  let acc = 0;
  for (const b of sc.beats) { beatStarts.push(acc); acc += spSec(b.dur); }
  const totalFrames = acc;
  const bounds = spContentBounds(sc);

  const history = new Map();
  const clears = [], formulaEvents = [], cameraEvents = [];
  sc.beats.forEach((b, bi) => {
    const at = beatStarts[bi];
    for (const a of b.actions) {
      if (a.type === "clear") clears.push({ ids: a.ids, at });
      else if (a.type === "formula") formulaEvents.push({ spec: a, at });
      else if (a.type === "camera") cameraEvents.push({ spec: a, at });
      else {
        const list = history.get(a.id) || [];
        list.push({ spec: a, start: at });
        history.set(a.id, list);
      }
    }
  });

  const EXIT = 0.6, MORPH_DEFAULT = 1.6;

  const stateAt = (frame) => {
    const elements = [];
    for (const [id, list] of history) {
      const visible = list.filter((i) => i.start <= frame);
      if (!visible.length) continue;
      const cur = visible[visible.length - 1];
      const prev = visible.length > 1 ? visible[visible.length - 2] : null;
      let opacity = 1, removed = false;
      for (const c of clears) {
        if (c.ids.includes(id) && frame >= c.at) {
          const t = spClamp01((frame - c.at) / spSec(EXIT));
          opacity = 1 - t;
          if (t >= 1) removed = true;
        }
      }
      if (removed) continue;
      const drawSec = cur.spec.type === "mover" ? cur.spec.travelSec : (cur.spec.drawSec || 0.9);
      const enter = prev ? 1 : spEase(spClamp01((frame - cur.start) / spSec(drawSec)));
      let current = cur.spec;
      if (prev) {
        const morphSec = cur.spec.morphSec || MORPH_DEFAULT;
        current = spMorph(prev.spec, cur.spec, spEase(spClamp01((frame - cur.start) / spSec(morphSec))));
      }
      elements.push({ id, spec: cur.spec, current, enter, opacity });
    }

    const seen = new Map();
    let order = 0;
    for (const f of formulaEvents) {
      if (f.at > frame) continue;
      const ex = seen.get(f.spec.id);
      if (ex) { ex.tex = f.spec.tex; ex.changedAt = f.at; }
      else seen.set(f.spec.id, { id: f.spec.id, tex: f.spec.tex, changedAt: f.at, order: order++ });
    }

    let camera = { scale: 1, cx: 960, cy: 540 };
    const past = cameraEvents.filter((c) => c.at <= frame);
    if (past.length) {
      const last = past[past.length - 1];
      const prevCam = past.length > 1 ? past[past.length - 2].spec : { scale: 1, cx: 960, cy: 540 };
      const t = spEase(spClamp01((frame - last.at) / spSec(1.2)));
      camera = {
        scale: spLerp(prevCam.scale, last.spec.scale, t),
        cx: spLerp(prevCam.cx, last.spec.cx, t),
        cy: spLerp(prevCam.cy, last.spec.cy, t),
      };
    }

    let beatIndex = 0;
    for (let i = 0; i < beatStarts.length; i++) if (frame >= beatStarts[i]) beatIndex = i;
    return {
      elements,
      formulas: [...seen.values()].sort((a, b) => a.order - b.order),
      camera,
      beatIndex,
      subtitle: sc.beats[beatIndex].subtitle,
      subtitleStart: beatStarts[beatIndex],
    };
  };

  return { beats: sc.beats, beatStarts, totalFrames, stateAt, bounds };
}

/* ---------- 렌더러 ---------- */
function spRender(st, svgEl, htmlEl, frame) {
  const planes = new Map();
  for (const el of st.elements) if (el.current.type === "plane") planes.set(el.id, el.current);
  const mapperFor = (pid) => (pid && planes.has(pid) ? spPlaneMapper(planes.get(pid)) : spIdentity);

  let svg = "";
  let html = "";

  const strokePath = (pts, enter, opacity, color, width, dashed, closed, fill, fillOpacity) => {
    const extra = closed && pts.length ? Math.hypot(pts[0][0] - pts[pts.length - 1][0], pts[0][1] - pts[pts.length - 1][1]) : 0;
    const len = spPolyLen(pts) + extra;
    const d = spPath(pts, closed);
    let out = "";
    if (fill && enter >= 1) out += `<path d="${d}" fill="${fill}" opacity="${(fillOpacity ?? 0.25) * opacity}" stroke="none"/>`;
    out += `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" opacity="${opacity}" stroke-dasharray="${dashed ? "10 10" : len}" stroke-dashoffset="${dashed ? 0 : (1 - enter) * len}"/>`;
    return out;
  };
  const label = (x, y, txt, size, color, opacity, center = false, weight = 500) =>
    `<div class="sp-label" style="left:${x}px;top:${y}px;${center ? "translate:-50% -50%;text-align:center;" : ""}font-size:${size}px;color:${color};opacity:${opacity};font-weight:${weight};">${spMixed(txt)}</div>`;

  for (const el of st.elements) {
    const c = el.current;
    const op = el.opacity, en = el.enter;
    switch (c.type) {
      case "plane": {
        const m = spPlaneMapper(c);
        const [x0, x1] = c.xRange, [y0, y1] = c.yRange;
        const ox = Math.min(Math.max(0, x0), x1), oy = Math.min(Math.max(0, y0), y1);
        const xa = m([x0, oy]), xb = m([x1, oy]), ya = m([ox, y0]), yb = m([ox, y1]);
        let g = `<g opacity="${en * op}">`;
        if (c.showGrid) {
          for (const t of c.xTicks || []) { const a = m([t, y0]), b = m([t, y1]); g += `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${SP.grid}" stroke-width="1"/>`; }
          for (const t of c.yTicks || []) { const a = m([x0, t]), b = m([x1, t]); g += `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${SP.grid}" stroke-width="1"/>`; }
        }
        g += `<line x1="${xa[0]}" y1="${xa[1]}" x2="${xb[0]}" y2="${xb[1]}" stroke="${SP.axis}" stroke-width="2.5"/>`;
        g += `<line x1="${ya[0]}" y1="${ya[1]}" x2="${yb[0]}" y2="${yb[1]}" stroke="${SP.axis}" stroke-width="2.5"/>`;
        for (const t of c.xTicks || []) { const p = m([t, oy]); g += `<line x1="${p[0]}" y1="${p[1] - 5}" x2="${p[0]}" y2="${p[1] + 5}" stroke="${SP.axis}" stroke-width="2"/>`; }
        for (const t of c.yTicks || []) { const p = m([ox, t]); g += `<line x1="${p[0] - 5}" y1="${p[1]}" x2="${p[0] + 5}" y2="${p[1]}" stroke="${SP.axis}" stroke-width="2"/>`; }
        if (c.xLabel) g += `<text x="${xb[0] + 16}" y="${xb[1] + 8}" fill="${SP.axis}" font-size="26" font-style="italic">${c.xLabel}</text>`;
        if (c.yLabel) g += `<text x="${yb[0]}" y="${yb[1] - 14}" fill="${SP.axis}" font-size="26" font-style="italic" text-anchor="middle">${c.yLabel}</text>`;
        g += "</g>";
        svg += g;
        for (const t of c.xTicks || []) { const p = m([t, oy]); html += `<div class="sp-tick" style="left:${p[0]}px;top:${p[1] + 12}px;translate:-50% 0;opacity:${en * op};">${t}</div>`; }
        for (const t of c.yTicks || []) { const p = m([ox, t]); html += `<div class="sp-tick" style="left:${p[0] - 12}px;top:${p[1]}px;translate:-100% -50%;opacity:${en * op};">${t}</div>`; }
        break;
      }
      case "plot": {
        const m = mapperFor(c.plane);
        svg += strokePath(c.points.map(m), en, op, spColor(c.color, SP.accent), c.width ?? 5, c.dashed);
        break;
      }
      case "fill": {
        const m = mapperFor(c.plane);
        const pts = c.points.map(m);
        const xs = pts.map((p) => p[0]);
        const minX = Math.min(...xs), maxX = Math.max(...xs);
        const cid = `spclip-${el.id}`;
        svg += `<g opacity="${op}"><clipPath id="${cid}"><rect x="${minX}" y="0" width="${(maxX - minX) * en}" height="${SP_H}"/></clipPath><path d="${spPath(pts, true)}" fill="${spColor(c.color, SP.accent)}" opacity="${c.opacity ?? 0.3}" clip-path="url(#${cid})"/></g>`;
        break;
      }
      case "point": {
        const p = mapperFor(c.plane)(c.at);
        svg += `<circle cx="${p[0]}" cy="${p[1]}" r="${(c.r ?? 8) * en}" fill="${spColor(c.color, SP.ink)}" opacity="${op}"/>`;
        if (c.label) html += label(p[0] + (c.labelDx ?? 14), p[1] + (c.labelDy ?? -34), c.label, 26, spColor(c.color, SP.ink), en * op);
        break;
      }
      case "vline": {
        const m = mapperFor(c.plane);
        const pl = planes.get(c.plane);
        const yy0 = c.from ?? (pl ? pl.yRange[0] : 0);
        const yy1 = c.to ?? (pl ? pl.yRange[1] : 0);
        const a = m([c.x, yy0]), b = m([c.x, yy1]);
        svg += strokePath([a, b], en, op, spColor(c.color, SP.muted), 2.5, c.dashed ?? true);
        if (c.label) html += label(b[0] - 12, b[1] - 40, c.label, 26, spColor(c.color, SP.ink), en * op);
        break;
      }
      case "seg": {
        const m = mapperFor(c.plane);
        const a = m(c.from), b = m(c.to);
        svg += strokePath([a, b], en, op, spColor(c.color, SP.ink), c.width ?? 4, c.dashed);
        if (c.label) html += label((a[0] + b[0]) / 2 + 12, (a[1] + b[1]) / 2 - 38, c.label, 26, spColor(c.color, SP.ink), en * op);
        break;
      }
      case "polygon": {
        const m = mapperFor(c.plane);
        svg += strokePath(c.points.map(m), en, op, spColor(c.stroke, SP.accent), c.width ?? 4.5, false, c.closed ?? true, spColor(c.fill, null), c.fillOpacity);
        break;
      }
      case "circle": {
        const m = mapperFor(c.plane);
        const ctr = m(c.center);
        const edge = m([c.center[0] + c.r, c.center[1]]);
        const rr = Math.hypot(edge[0] - ctr[0], edge[1] - ctr[1]);
        const rim = [];
        for (let i = 0; i <= 96; i++) {
          const a = (i / 96) * Math.PI * 2 - Math.PI / 2;
          rim.push([ctr[0] + rr * Math.cos(a), ctr[1] + rr * Math.sin(a)]);
        }
        svg += strokePath(rim, en, op, spColor(c.stroke, SP.accent), 4.5, false, true, spColor(c.fill, null), c.fillOpacity);
        break;
      }
      case "brace": {
        const m = mapperFor(c.plane);
        const { d, labelAt } = spBrace(m(c.from), m(c.to), c.flip);
        svg += `<path d="${d}" fill="none" stroke="${spColor(c.color, SP.ink)}" stroke-width="2.5" opacity="${en * op}"/>`;
        html += label(labelAt[0], labelAt[1], c.label, 30, spColor(c.color, SP.ink), en * op, true);
        break;
      }
      case "glabel": {
        const p = mapperFor(c.plane)(c.at);
        const content = c.tex ? `$${c.tex}$` : (c.text || "");
        html += `<div class="sp-label sp-glabel" style="left:${p[0]}px;top:${p[1]}px;font-size:${c.size ?? 30}px;color:${spColor(c.color, SP.ink)};opacity:${en * op};">${spMixed(content)}</div>`;
        break;
      }
      case "mover": {
        const m = mapperFor(c.plane);
        const pts = c.points.map(m);
        if (pts.length < 2) break;
        const t = en * (pts.length - 1);
        const i0 = Math.min(Math.floor(t), pts.length - 2);
        const ft = t - i0;
        const pos = [pts[i0][0] + (pts[i0 + 1][0] - pts[i0][0]) * ft, pts[i0][1] + (pts[i0 + 1][1] - pts[i0][1]) * ft];
        if (c.trail) svg += `<path d="${spPath([...pts.slice(0, i0 + 1), pos])}" fill="none" stroke="${spColor(c.color, SP.accent)}" stroke-width="3" opacity="${0.35 * op}" stroke-linecap="round"/>`;
        svg += `<circle cx="${pos[0]}" cy="${pos[1]}" r="${c.r ?? 11}" fill="${spColor(c.color, SP.accent)}" opacity="${op}"/>`;
        if (c.label) html += label(pos[0] + 16, pos[1] - 44, c.label, 28, spColor(c.color, SP.ink), op, false, 700);
        break;
      }
      case "blocks": {
        const total = c.rows * c.cols;
        const shown = Math.round(c.count * en);
        const gap = c.gap ?? 6;
        const cw = (c.rect.w - gap * (c.cols - 1)) / c.cols;
        const ch = (c.rect.h - gap * (c.rows - 1)) / c.rows;
        const col0 = spColor(c.color, SP.accent);
        let cells = "";
        for (let i = 0; i < Math.min(shown, total); i++) {
          const r = Math.floor(i / c.cols), cc = i % c.cols;
          cells += `<div style="position:absolute;left:${c.rect.x + cc * (cw + gap)}px;top:${c.rect.y + (c.rows - 1 - r) * (ch + gap)}px;width:${cw}px;height:${ch}px;background:${col0}33;border:2.5px solid ${col0};border-radius:6px;"></div>`;
        }
        html += `<div style="opacity:${op}">${cells}</div>`;
        if (c.countLabel && shown > 0) html += `<div class="sp-label" style="left:${c.rect.x + c.rect.w + 30}px;top:${c.rect.y + c.rect.h / 2 - 30}px;font-size:54px;font-weight:900;color:${col0};opacity:${op};">${shown}</div>`;
        break;
      }
    }
  }

  // 수식은 스테이지 밖 앱 UI(formula bar)에서 렌더한다 — 여기서는 제외
  svgEl.innerHTML = svg;
  htmlEl.innerHTML = html;
}

/* ---------- 자막 (단어 단위 등장) ---------- */
function spSubtitle(el, st, frame) {
  const key = st.beatIndex;
  if (el._beat !== key) {
    el._beat = key;
    // 단어 분해: $...$는 한 단어 취급
    const segs = String(st.subtitle).split(/(\$[^$]+\$)/).filter(Boolean);
    const words = [];
    let cur = [];
    const flush = () => { if (cur.length) { words.push(cur.join("")); cur = []; } };
    for (const seg of segs) {
      if (seg.startsWith("$")) { cur.push(seg); continue; }
      for (const p of seg.split(/(\s+)/)) {
        if (!p) continue;
        if (/^\s+$/.test(p)) flush();
        else cur.push(p);
      }
    }
    flush();
    el.innerHTML = words.map((w, i) => `<span class="sp-word" data-i="${i}">${spMixed(w)}</span>`).join(" ");
  }
  const dt = frame - st.subtitleStart;
  el.querySelectorAll(".sp-word").forEach((w) => {
    const i = +w.dataset.i;
    const t = spClamp01((dt - i * 3) / 10);
    w.style.opacity = t;
    w.style.transform = `translateY(${(1 - t) * 10}px)`;
  });
}

/* ---------- 플레이어 ---------- */
class ScenarioPlayer {
  /**
   * @param {HTMLElement} container 플레이어를 채울 요소
   * @param {object} scenario ConceptScenario JSON
   * @param {object} opts { title, onEnd }
   */
  constructor(container, scenario, opts = {}) {
    this.container = container;
    this.sc = scenario;
    this.opts = opts;
    this.compiled = spCompile(scenario);
    this.playing = false;
    this.speed = 1;
    this.frame = 0;
    this._raf = null;
    this._last = 0;
    this._accessibilityHandler = () => {
      if (window.MATTHS_MOTION === false) this.pause();
    };
    window.addEventListener("matthsAccessibilityChanged", this._accessibilityHandler);
    this._build();
    // 자동재생은 모션 스위치를 따른다. 꺼져 있으면 첫 프레임을 그려 두고 멈춘다 —
    // 큰 재생 버튼이 남아 있으므로 보고 싶으면 직접 누르면 된다.
    // (Motion.swift 규칙 2: 시스템 '동작 줄이기' 는 앱 설정보다 항상 우선)
    if (typeof window !== "undefined" && window.MATTHS_MOTION === false) {
      this.seek(0);
    } else {
      this.play();
    }
  }

  _build() {
    this.container.classList.add("sp-container");
    this.container.innerHTML = `
      <div class="sp-formula-bar"></div>
      <div class="sp-viewport">
        <div class="sp-stage">
          <svg class="sp-svg" viewBox="0 0 ${SP_W} ${SP_H}" width="${SP_W}" height="${SP_H}"></svg>
          <div class="sp-html"></div>
        </div>
        <div class="sp-summary hidden"></div>
        <button class="sp-bigplay hidden">▶</button>
      </div>
      <div class="sp-caption"></div>
      <div class="sp-controls">
        <button class="sp-btn sp-play" title="재생/일시정지">⏸</button>
        <button class="sp-btn sp-restart" title="처음부터">↺</button>
        <div class="sp-progress"><div class="sp-progress-fill"></div></div>
        <span class="sp-time">0:00</span>
        <button class="sp-btn sp-speed" title="배속">1x</button>
      </div>`;
    this.viewport = this.container.querySelector(".sp-viewport");
    this.stage = this.container.querySelector(".sp-stage");
    this.svgEl = this.container.querySelector(".sp-svg");
    this.htmlEl = this.container.querySelector(".sp-html");
    this.formulaBar = this.container.querySelector(".sp-formula-bar");
    this.captionEl = this.container.querySelector(".sp-caption");
    this.summaryEl = this.container.querySelector(".sp-summary");
    this.bigPlay = this.container.querySelector(".sp-bigplay");
    this.playBtn = this.container.querySelector(".sp-play");
    this.progressEl = this.container.querySelector(".sp-progress");
    this.fillEl = this.container.querySelector(".sp-progress-fill");
    this.timeEl = this.container.querySelector(".sp-time");
    this.speedBtn = this.container.querySelector(".sp-speed");

    this.playBtn.addEventListener("click", () => (this.playing ? this.pause() : this.play()));
    this.bigPlay.addEventListener("click", () => this.play());
    this.container.querySelector(".sp-restart").addEventListener("click", () => { this.seek(0); this.play(); });
    this.speedBtn.addEventListener("click", () => {
      this.speed = this.speed === 1 ? 1.5 : this.speed === 1.5 ? 2 : 1;
      this.speedBtn.textContent = this.speed + "x";
    });
    this.progressEl.addEventListener("pointerdown", (e) => {
      const rect = this.progressEl.getBoundingClientRect();
      const t = spClamp01((e.clientX - rect.left) / rect.width);
      this.seek(t * this.compiled.totalFrames);
    });

    /* 콘텐츠 bbox 크롭 핏: 영상용 1920×1080 여백을 잘라내고
       그래프가 컨테이너를 꽉 채우도록 스케일·오프셋 계산 */
    this._resize = () => {
      const b = this.compiled.bounds;
      const w = this.viewport.clientWidth || this.container.clientWidth || 600;
      // 셸이 스테이지 상한을 내려줄 수 있다(lesson.html 의 MATTHS_STAGE_MAX).
      // 없으면 데모 원판의 760 그대로다.
      const cap = window.MATTHS_STAGE_MAX || 760;
      const maxH = Math.max(300, Math.min(window.innerHeight * 0.74, cap));
      const s = Math.min(w / b.w, maxH / b.h);
      this._fit = { s, ox: (w - b.w * s) / 2, b };
      this.viewport.style.height = Math.round(b.h * s) + "px";
      if (this._lastState) this._applyCamera(this._lastState.camera);
    };
    window.addEventListener("resize", this._resize);
    this._resize();
    this._renderFrame();
  }

  _applyCamera(cam) {
    const { s, ox, b } = this._fit;
    const k = cam.scale;
    const tx = (960 - cam.cx) * k, ty = (540 - cam.cy) * k;
    this.stage.style.transformOrigin = "0 0";
    this.stage.style.transform =
      `translate(${ox}px, 0px) scale(${s}) translate(${tx - b.x}px, ${ty - b.y}px) scale(${k})`;
  }

  _renderFrame() {
    const st = this.compiled.stateAt(this.frame);
    this._lastState = st;
    this._applyCamera(st.camera);
    spRender(st, this.svgEl, this.htmlEl, this.frame);
    spSubtitle(this.captionEl, st, this.frame);
    // 수식 바 (앱 UI 크기, 등장 펄스)
    let fhtml = "";
    for (const f of st.formulas) {
      const dt = this.frame - f.changedAt;
      const appear = spClamp01(dt / 10);
      const pulse = dt < 12 ? 1 + 0.05 * (dt / 12) : dt < 26 ? 1.05 - 0.05 * ((dt - 12) / 14) : 1;
      fhtml += `<div class="sp-formula" style="opacity:${appear};transform:scale(${Math.max(pulse, 0.95)});">${spTex(f.tex)}</div>`;
    }
    this.formulaBar.innerHTML = fhtml;
    this.formulaBar.classList.toggle("empty", !st.formulas.length);
    const total = this.compiled.totalFrames;
    this.fillEl.style.width = (100 * this.frame / total) + "%";
    const sec = Math.floor(this.frame / SP_FPS);
    this.timeEl.textContent = `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
  }

  /* setInterval 기반 타임라인 (rAF는 백그라운드 탭에서 정지되므로 인터벌로 구동,
     시간 계산은 performance.now() 기준이라 프레임 드랍에도 정확) */
  _tick = () => {
    if (!this.playing) return;
    const now = performance.now();
    if (!this._last) this._last = now;
    const dt = (now - this._last) / 1000;
    this._last = now;
    this.frame += dt * SP_FPS * this.speed;
    if (this.frame >= this.compiled.totalFrames - 1) {
      this.frame = this.compiled.totalFrames - 1;
      this._renderFrame();
      this._finish();
      return;
    }
    this._renderFrame();
  };

  play() {
    if (this.playing) return;
    // 끝에서 재생 누르면 처음부터
    if (this.frame >= this.compiled.totalFrames - 2) this.frame = 0;
    this.summaryEl.classList.add("hidden");
    this.bigPlay.classList.add("hidden");
    this.playing = true;
    this._last = 0;
    this.playBtn.textContent = "⏸";
    this._raf = setInterval(this._tick, 1000 / SP_FPS);
  }

  pause() {
    this.playing = false;
    if (this._raf) clearInterval(this._raf);
    this.playBtn.textContent = "▶";
    this.bigPlay.classList.remove("hidden");
  }

  seek(frame) {
    this.frame = spClamp01(frame / this.compiled.totalFrames) * this.compiled.totalFrames;
    this.summaryEl.classList.add("hidden");
    this._renderFrame();
  }

  _finish() {
    this.playing = false;
    this.playBtn.textContent = "▶";
    // 요약 카드
    const lines = this.sc.summaryLines || [];
    if (lines.length) {
      this.summaryEl.innerHTML =
        `<div class="sp-summary-card"><div class="sp-summary-title">핵심 정리</div>` +
        lines.map((l) => `<div class="sp-summary-line">${spMixed(l)}</div>`).join("") +
        `<button class="sp-btn sp-replay">↺ 다시 보기</button></div>`;
      this.summaryEl.classList.remove("hidden");
      this.summaryEl.querySelector(".sp-replay").addEventListener("click", () => { this.seek(0); this.play(); });
    } else {
      this.bigPlay.classList.remove("hidden");
    }
    if (this.opts.onEnd) this.opts.onEnd();
  }

  destroy() {
    this.pause();
    window.removeEventListener("resize", this._resize);
    window.removeEventListener("matthsAccessibilityChanged", this._accessibilityHandler);
    this.container.classList.remove("sp-container");
    this.container.innerHTML = "";
  }
}

/* ---------- 27개념 ↔ 시나리오 매핑 ---------- */
const SCENARIO_MAP = {
  "cm1-poly": "polynomial-arithmetic",
  "cm1-remainder": "identity-remainder-theorem",
  "cm1-factor": "polynomial-factorization",
  "cm1-complex": "complex-numbers",
  "disc": "quadratic-discriminant",
  "cm1-vieta": "quadratic-roots-and-coefficients",
  "cm1-quadrel": "quadratic-equation-and-function",
  "cm1-cubic": "cubic-and-quartic-equations",
  "cm1-quadineq": "quadratic-inequalities",
  "cm1-count": "addition-and-multiplication-principles",
  "cm1-perm": "permutations",
  "cm1-comb": "combinations",
  "cm1-matrix": "matrix-operations",
  "cm2-dist": "distance-and-internal-division",
  // "cm2-line": 전용 시나리오 없음 → 레거시 해설 자동 재생
  "cm2-perp": "parallel-and-perpendicular-lines",
  "cm2-circleeq": "circle-equation",
  "circle": "circle-line-position",
  "trans": "geometric-translation",
  "cm2-set": "set-operations",
  "cm2-prop": "converse-and-contrapositive",
  "cm2-cond": "sufficient-and-necessary-conditions",
  "cm2-amgm": "absolute-inequality",
  "cm2-compose": "composite-function",
  "cm2-inverse": "inverse-function",
  "cm2-rational": "rational-function",
  "cm2-irrational": "irrational-function",
};
