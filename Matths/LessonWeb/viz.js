/* ============================================================
   맵쓰 그래프 렌더러 — 의존성 없는 SVG 좌표평면
   모든 개념 놀이터가 공유한다.
   ============================================================ */

/* 시맨틱 그래프 팔레트 (RG-18) — brand.css 그래프 토큰과 같은 값.
   SVG 프레젠테이션 속성에는 var() 를 못 쓰므로 hex 로 박는다.
   주 대상은 파랑 하나 — 상단 시각 강의와 하단 놀이터가 같은 함수를
   같은 색으로 그린다. 빨강은 오류·경고 의미로만 쓴다. */
const VIZ_COLORS = {
  primary: "#327FFA",    // 기본 곡선·주 대상
  secondary: "#7B4EFC",  // 보조 곡선·변환·짝 대상
  second: "#7B4EFC",     // secondary 의 옛 이름 — 기존 호출부 호환
  highlight: "#CA44E3",  // 순간 강조
  point: "#0CDCF1",      // 인터랙티브 점·핸들
  error: "#E8302A",      // 오류·경고 전용
  lime: "#9CC70A",
  grid: "#E3E0D8",
  axis: "#B9B4A8",
  text: "#3A3630",
  softPrimary: "rgba(50,127,250,0.12)",
  softSecondary: "rgba(123,78,252,0.10)",
};

class Graph {
  /**
   * @param {SVGElement} svg  대상 svg (viewBox 자동 설정)
   * @param {object} opt  {xMin,xMax,yMin,yMax,w,h}
   */
  constructor(svg, opt = {}) {
    this.svg = svg;
    this.xMin = opt.xMin ?? -8;
    this.xMax = opt.xMax ?? 8;
    this.yMin = opt.yMin ?? -8;
    this.yMax = opt.yMax ?? 8;
    this.w = opt.w ?? 560;
    this.h = opt.h ?? 560;
    this.pad = opt.pad ?? 8;
    svg.setAttribute("viewBox", `0 0 ${this.w} ${this.h}`);
    this.layers = {};
  }

  px(x) {
    return this.pad + ((x - this.xMin) / (this.xMax - this.xMin)) * (this.w - 2 * this.pad);
  }
  py(y) {
    return this.h - this.pad - ((y - this.yMin) / (this.yMax - this.yMin)) * (this.h - 2 * this.pad);
  }

  el(name, attrs = {}) {
    const n = document.createElementNS("http://www.w3.org/2000/svg", name);
    for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
    return n;
  }

  layer(id) {
    if (!this.layers[id]) {
      this.layers[id] = this.el("g", { "data-layer": id });
      this.svg.appendChild(this.layers[id]);
    }
    return this.layers[id];
  }

  clearLayer(id) {
    const g = this.layer(id);
    while (g.firstChild) g.removeChild(g.firstChild);
    return g;
  }

  /* 격자 + 축 (한 번만 호출) */
  drawBase() {
    const g = this.clearLayer("base");
    for (let x = Math.ceil(this.xMin); x <= this.xMax; x++) {
      g.appendChild(this.el("line", {
        x1: this.px(x), y1: this.py(this.yMin), x2: this.px(x), y2: this.py(this.yMax),
        stroke: x === 0 ? VIZ_COLORS.axis : VIZ_COLORS.grid, "stroke-width": x === 0 ? 2 : 1,
      }));
    }
    for (let y = Math.ceil(this.yMin); y <= this.yMax; y++) {
      g.appendChild(this.el("line", {
        x1: this.px(this.xMin), y1: this.py(y), x2: this.px(this.xMax), y2: this.py(y),
        stroke: y === 0 ? VIZ_COLORS.axis : VIZ_COLORS.grid, "stroke-width": y === 0 ? 2 : 1,
      }));
    }
    // 눈금 숫자 (2 간격)
    for (let x = Math.ceil(this.xMin / 2) * 2; x <= this.xMax; x += 2) {
      if (x === 0) continue;
      g.appendChild(this.text(x, -0.45, String(x), { size: 15, fill: VIZ_COLORS.axis, anchor: "middle" }));
    }
    for (let y = Math.ceil(this.yMin / 2) * 2; y <= this.yMax; y += 2) {
      if (y === 0) continue;
      g.appendChild(this.text(-0.35, y - 0.12, String(y), { size: 15, fill: VIZ_COLORS.axis, anchor: "end" }));
    }
  }

  /* 함수 곡선 path 생성 */
  fnPath(fn, samples = 220) {
    let d = "", pen = false;
    for (let i = 0; i <= samples; i++) {
      const x = this.xMin + ((this.xMax - this.xMin) * i) / samples;
      const y = fn(x);
      if (!Number.isFinite(y) || y < this.yMin - 20 || y > this.yMax + 20) { pen = false; continue; }
      const cmd = pen ? "L" : "M";
      d += `${cmd}${this.px(x).toFixed(1)},${this.py(y).toFixed(1)} `;
      pen = true;
    }
    return d;
  }

  curve(layerId, fn, opts = {}) {
    const g = this.clearLayer(layerId);
    const p = this.el("path", {
      d: this.fnPath(fn),
      fill: "none",
      stroke: opts.color || VIZ_COLORS.primary,
      "stroke-width": opts.width || 4,
      "stroke-linecap": "round",
      ...(opts.dash ? { "stroke-dasharray": opts.dash } : {}),
    });
    g.appendChild(p);
    return p;
  }

  line(layerId, x1, y1, x2, y2, opts = {}) {
    const g = opts.append ? this.layer(layerId) : this.clearLayer(layerId);
    const l = this.el("line", {
      x1: this.px(x1), y1: this.py(y1), x2: this.px(x2), y2: this.py(y2),
      stroke: opts.color || VIZ_COLORS.secondary, "stroke-width": opts.width || 3,
      "stroke-linecap": "round",
      ...(opts.dash ? { "stroke-dasharray": opts.dash } : {}),
    });
    g.appendChild(l);
    return l;
  }

  /* 무한 직선 y=mx+k 를 화면 가장자리까지 */
  fullLine(layerId, m, k, opts = {}) {
    const y1 = m * this.xMin + k, y2 = m * this.xMax + k;
    return this.line(layerId, this.xMin, y1, this.xMax, y2, opts);
  }

  circle(layerId, cx, cy, r, opts = {}) {
    const g = opts.append ? this.layer(layerId) : this.clearLayer(layerId);
    // 반지름을 px로 환산(x축 스케일 기준; 정사각 좌표계 전제)
    const rpx = Math.abs(this.px(cx + r) - this.px(cx));
    const c = this.el("circle", {
      cx: this.px(cx), cy: this.py(cy), r: rpx,
      fill: opts.fill || "none",
      stroke: opts.color || VIZ_COLORS.primary,
      "stroke-width": opts.width || 4,
      ...(opts.dash ? { "stroke-dasharray": opts.dash } : {}),
    });
    g.appendChild(c);
    return c;
  }

  point(layerId, x, y, opts = {}) {
    const g = opts.append ? this.layer(layerId) : this.clearLayer(layerId);
    const c = this.el("circle", {
      cx: this.px(x), cy: this.py(y), r: opts.r || 7,
      fill: opts.color || VIZ_COLORS.point,
      stroke: "#fff", "stroke-width": 2.5,
    });
    g.appendChild(c);
    return c;
  }

  text(x, y, str, opts = {}) {
    const t = this.el("text", {
      x: this.px(x), y: this.py(y),
      fill: opts.fill || VIZ_COLORS.text,
      "font-size": opts.size || 17,
      "font-weight": opts.weight || 600,
      "text-anchor": opts.anchor || "start",
      "font-family": "'Pretendard','Apple SD Gothic Neo',system-ui,sans-serif",
    });
    t.textContent = str;
    if (opts.layerId) (opts.append ? this.layer(opts.layerId) : this.clearLayer(opts.layerId)).appendChild(t);
    return t;
  }
}

/* 숫자 포맷: 1.0 → 1, -0 → 0, 소수 1자리 */
function fmt(n, digits = 1) {
  const v = Math.round(n * 10 ** digits) / 10 ** digits;
  return String(v === 0 ? 0 : v);
}

/* 계수 부호 붙여 수식 문자열 조립: sgnTerm(-3,"x") → " - 3x" */
function sgnTerm(coef, sym, first = false) {
  if (Math.abs(coef) < 1e-9) return "";
  const sign = coef > 0 ? (first ? "" : " + ") : (first ? "-" : " − ");
  const a = Math.abs(coef);
  const num = sym ? (Math.abs(a - 1) < 1e-9 ? "" : fmt(a)) : fmt(a);
  return sign + num + sym;
}
