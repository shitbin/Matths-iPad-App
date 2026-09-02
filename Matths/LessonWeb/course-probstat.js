/* ============================================================
   확률과 통계 (2022 개정 · 교육부 고시 제2022-33호) — 16개념
   kr-2022-probability-statistics.yaml 구조를 그대로 따른다.
   단원: 경우의 수(3) · 확률(6) · 통계(7)
   ============================================================ */

/* ---------- 1단원 · 경우의 수 ---------- */

/* 12확통01-01 중복순열과 같은 것이 있는 순열 */
const ps0101 = {
  id: "ps-0101",
  course: "확률과 통계", unit: "경우의 수",
  badge: "확통 · 경우의 수 · 12확통01-01",
  std: "12확통01-01",
  title: "중복순열과 같은 것이 있는 순열",
  tag: "다시 뽑을 수 있으면 nʳ, 같은 게 섞여 있으면 접어서 나눈다",
  oneLiner: "중복 허용 줄 세우기는 자리마다 n가지라 nʳ, 같은 것이 섞이면 같은 것끼리의 배열 수로 나눈다.",
  veilText: "🙈 그림 가림 — nʳ과 n!/p! 규칙만으로 판단해봐.",
  playgroundGuide: "두 모드를 오가며 봐라. 중복순열은 선택지가 줄지 않고, 같은 것 순열은 겹친 배열을 접는다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let mode = "rep", n = 3, r = 2, wordIdx = 0;
    const words = ["수학학", "1123", "aabb"];
    const render = () => {
      if (mode === "rep") {
        const { el, txt } = freeCanvas(svg);
        txt(280, 52, `${n}가지 중 중복 허용해서 ${r}자리 만들기`, { size: 21, weight: 900 });
        const slotW = 120, gap = 40;
        const total = r * slotW + (r - 1) * gap;
        const x0 = (560 - total) / 2;
        for (let i = 0; i < r; i++) {
          const x = x0 + i * (slotW + gap);
          el("rect", { x, y: 150, width: slotW, height: 130, rx: 16, fill: "#fff", stroke: "#327ffa", "stroke-width": 3 });
          txt(x + slotW / 2, 138, `${i + 1}번째 자리`, { size: 16, fill: "#8b8578" });
          txt(x + slotW / 2, 226, String(n), { size: 46, weight: 900, fill: "#ca44e3" });
          txt(x + slotW / 2, 262, "가지 (안 줄어듦!)", { size: 13, fill: "#8b8578" });
          if (i < r - 1) txt(x + slotW + gap / 2, 224, "×", { size: 34, fill: "#327ffa", weight: 900 });
        }
        txt(280, 380, `${n}Π${r} = ${n}ʳ 꼴 = ${Math.pow(n, r)}`, { size: 30, weight: 900, fill: "#178a4c" });
        txt(280, 430, "뽑은 걸 되돌려 놓으니 선택지가 매번 그대로다", { size: 16, fill: "#8b8578", weight: 700 });
        readoutEl.innerHTML =
          `<div class="formula">${n}Π${r} = ${n}^${r} = ${Math.pow(n, r)}</div>` +
          `<div class="d-count">순열 ${n}P${r} = ${Array.from({ length: r }, (_, i) => n - i).reduce((a, b) => a * b, 1)}과 비교해봐 — 중복 허용이 더 많다</div>`;
      } else {
        const w = words[wordIdx];
        const ans = drawMultisetFold(svg, { word: w });
        readoutEl.innerHTML =
          `<div class="formula">"${w}" 배열의 수 = ${ans}</div>` +
          `<div class="d-count">같은 글자끼리 자리를 바꿔도 같은 배열 → 그만큼 나눈다</div>`;
      }
    };
    const sn = buildSlider(controlsEl, { label: "n — 종류 수 (중복순열)", min: 2, max: 4, step: 1, value: n, format: fmt });
    const sr = buildSlider(controlsEl, { label: "r — 자리 수 (중복순열)", min: 2, max: 4, step: 1, value: r, format: fmt });
    sn.onChange = (v) => { n = v; mode = "rep"; render(); };
    sr.onChange = (v) => { r = v; mode = "rep"; render(); };
    buildButtonRow(controlsEl, [
      { label: "중복순열 모드", cls: "on", onClick: (b) => { mode = "rep"; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "같은 것 순열 (예시 순환)", onClick: (b) => { if (mode === "same") wordIdx = (wordIdx + 1) % words.length; mode = "same"; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "숫자 <b>1, 1, 2, 3</b> 을 모두 사용하여 만들 수 있는 <b>네 자리 자연수</b>의 개수는?",
    choices: ["12", "24", "6", "4"],
    answer: 0,
    hint: "전부 다르면 4! = 24. 그런데 1이 두 개라 겹치는 배열이 생긴다. 2!로 나눠라.",
    wrongNotes: [
      null,
      "4!=24는 네 숫자가 전부 다를 때다. 1끼리 바꿔치기한 배열은 같은 수다.",
      "3!=6? 자리는 네 개다. 접는 건 같은 숫자(1,1)의 2!뿐.",
      "너무 많이 접었다. 나누는 건 같은 것의 배열 수 2!=2 한 번뿐이다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "1,1,2,3 — 일단 네 숫자가 전부 다르다고 치면 4! = 24가지.", run: () => drawMultisetFold(svg, { word: "1123" }) },
      { caption: "그런데 두 개의 1은 서로 바꿔 앉아도 같은 수다. 배열들이 2!개씩 겹친다.", run: () => {} },
      { caption: "겹친 만큼 접는다: 24 ÷ 2! = 12.", run: () => {} },
      { caption: "결론: 12개. '전부 다르게 센 다음, 같은 것의 배열 수로 나눈다'가 공식의 전부다.", run: () => {} },
    ];
  },
};

/* 12확통01-02 중복조합 */
const ps0102 = {
  id: "ps-0102",
  course: "확률과 통계", unit: "경우의 수",
  badge: "확통 · 경우의 수 · 12확통01-02",
  std: "12확통01-02",
  title: "중복조합",
  tag: "○와 칸막이 — 배분 문제는 nHr = C(n+r−1, r)",
  oneLiner: "종류별 개수만 정하는 중복조합은 ○ r개와 칸막이 n−1개를 일렬로 세우는 문제와 같다.",
  veilText: "🙈 그림 가림 — nHr = C(n+r−1, r) 공식만으로 계산해봐.",
  playgroundGuide: "종류 수와 뽑는 개수를 바꿔봐. ○와 칸막이의 자리 수가 어떻게 정해지는지가 핵심이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let kinds = 3, pick = 4;
    const render = () => {
      const H = drawStarsBars(svg, { kinds, pick });
      readoutEl.innerHTML =
        `<div class="formula">${kinds}H${pick} = C(${kinds + pick - 1}, ${pick}) = ${H}</div>` +
        `<div class="d-count">중복순열 ${kinds}^${pick} = ${Math.pow(kinds, pick)}과 비교 — 순서를 지우면 이만큼 줄어든다</div>`;
    };
    const sk = buildSlider(controlsEl, { label: "n — 종류 수", min: 2, max: 4, step: 1, value: kinds, format: fmt });
    const sp = buildSlider(controlsEl, { label: "r — 뽑는 개수", min: 2, max: 6, step: 1, value: pick, format: fmt });
    sk.onChange = (v) => { kinds = v; render(); };
    sp.onChange = (v) => { pick = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>3종류</b>의 음료 중에서 <b>중복을 허용하여 4잔</b>을 고르는 방법의 수는? (순서 무관)",
    choices: ["15", "81", "12", "35"],
    answer: 0,
    hint: "3H4 = C(3+4−1, 4) = C(6, 4). ○ 4개 + 칸막이 2개 = 자리 6개.",
    wrongNotes: [
      null,
      "3⁴=81은 '순서 있는' 중복순열이다. 잔을 받는 순서는 상관없다.",
      "3×4=12는 아무 공식도 아니다. 칸막이 모델로 돌아가라.",
      "C(7,4)=35 — n+r−1이지 n+r이 아니다. 칸막이는 n−1개.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "콜라·사이다·주스 3종류에서 4잔. 각 종류를 몇 잔씩 받을지가 전부다.", run: () => drawStarsBars(svg, { kinds: 3, pick: 4 }) },
      { caption: "잔 4개를 ○로, 종류 경계를 칸막이 | 2개로 표현하면 자리 6개의 배열이 된다.", run: () => {} },
      { caption: "자리 6개 중 ○가 들어갈 4자리를 고르면 끝: C(6,4) = 15.", run: () => {} },
      { caption: "결론: 3H4 = C(6,4) = 15. '나눠주기·배분' 문제가 보이면 칸막이부터 세워라.", run: () => {} },
    ];
  },
};

/* 12확통01-03 이항정리 */
const ps0103 = {
  id: "ps-0103",
  course: "확률과 통계", unit: "경우의 수",
  badge: "확통 · 경우의 수 · 12확통01-03",
  std: "12확통01-03",
  title: "이항정리",
  tag: "(a+b)ⁿ의 계수는 조합이 만든다 — 일반항 C(n,r)aⁿ⁻ʳbʳ",
  oneLiner: "(a+b)ⁿ 전개의 각 항 계수는 n개의 괄호에서 b를 몇 번 뽑을지 고르는 조합의 수다.",
  veilText: "🙈 삼각형 가림 — 일반항 C(n,r)aⁿ⁻ʳbʳ만으로 계산해봐.",
  playgroundGuide: "n을 키우며 파스칼 삼각형이 자라는 걸 봐라. k를 움직이면 해당 항의 계수가 켜진다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 4, k = 2;
    const render = () => {
      if (k > n) k = n;
      drawPascal(svg, { rows: Math.max(n, 4), hiRow: n, hiK: k });
      const terms = [];
      for (let r = 0; r <= n; r++) terms.push(`${statC(n, r) === 1 ? "" : statC(n, r)}x${n - r === 0 ? "" : n - r === 1 ? "" : "^" + (n - r)}${n - r === 0 ? "" : ""}`);
      readoutEl.innerHTML =
        `<div class="formula">(x+1)^${n} 의 x^${n - k} 항 계수 = C(${n}, ${k}) = ${statC(n, k)}</div>` +
        `<div class="d-count">일반항: C(n, r) · aⁿ⁻ʳ · bʳ — r는 b를 뽑은 횟수</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "n — 거듭제곱", min: 2, max: 7, step: 1, value: n, format: fmt });
    const sk = buildSlider(controlsEl, { label: "r — b를 뽑는 횟수", min: 0, max: 7, step: 1, value: k, format: fmt });
    // r > n 이면 C(n,r)=0 오독을 막기 위해 슬라이더 표시값까지 n으로 동기화
    sn.onChange = (v) => { n = v; if (k > n) { k = n; sk.set(k); } render(); };
    sk.onChange = (v) => { k = Math.min(v, n); if (k !== v) sk.set(k); render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>(x + 2)⁴</b> 의 전개식에서 <b>x² 항의 계수</b>는?",
    choices: ["24", "6", "12", "96"],
    answer: 0,
    hint: "일반항 C(4, r)·x⁴⁻ʳ·2ʳ 에서 x²가 되려면 r=2. C(4,2)·2² 을 계산해라.",
    wrongNotes: [
      null,
      "C(4,2)=6까지만 하고 2²=4를 곱하는 걸 잊었다. b가 2라서 2ʳ이 붙는다.",
      "2²이 아니라 2를 한 번만 곱했다. r=2면 2가 두 번 뽑힌 것.",
      "2⁴=16을 곱했나? r=2일 때 2는 정확히 2번만 등장한다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "(x+2)⁴ = (x+2)(x+2)(x+2)(x+2). 괄호 4개에서 각각 x나 2를 하나씩 고른다.", run: () => drawPascal(svg, { rows: 4, hiRow: 4, hiK: 2 }) },
      { caption: "x²항 = 괄호 2개에서 x, 나머지 2개에서 2를 고른 경우. 고르는 방법이 C(4,2)=6가지.", run: () => {} },
      { caption: "각 경우의 값은 x²·2² = 4x². 따라서 계수는 6 × 4 = 24.", run: () => {} },
      { caption: "결론: 24. 이항계수는 '몇 번째 항'이 아니라 'b를 몇 번 뽑았나'를 센다.", run: () => {} },
    ];
  },
};

/* ---------- 2단원 · 확률 ---------- */

/* 12확통02-01 확률의 개념과 기본 성질 */
const ps0201 = {
  id: "ps-0201",
  course: "확률과 통계", unit: "확률",
  badge: "확통 · 확률 · 12확통02-01",
  std: "12확통02-01",
  title: "확률의 개념과 기본 성질",
  tag: "상대도수가 다가가는 그 값 — 0 ≤ P ≤ 1",
  oneLiner: "확률은 시행을 무한히 반복할 때 상대도수가 다가가는 값이며, 같은 가능성이면 (경우의 수)/(전체)로 계산한다.",
  veilText: "🙈 시뮬레이션 가림 — (사건의 경우)/(전체 경우)로만 계산해봐.",
  playgroundGuide: "실험을 바꾸고 [다시 시뮬]을 눌러봐. 곡선이 요동쳐도 결국 이론 확률선에 달라붙는다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let exp = 0, trials = 300, seed = 7;
    const exps = [
      { p: 1 / 2, label: "동전 앞면", desc: "P = 1/2" },
      { p: 1 / 3, label: "주사위 3의 배수", desc: "3, 6 두 가지 / 여섯 가지 = 1/3" },
      { p: 1 / 6, label: "주사위 6", desc: "P = 1/6" },
    ];
    const render = () => {
      const e = exps[exp];
      const last = drawRelFreq(svg, { p: e.p, trials, seed, label: e.label });
      readoutEl.innerHTML =
        `<div class="formula">P(${e.label}) = ${statFrac(Math.round(e.p * 6), 6)}</div>` +
        `<div class="d-badge ${Math.abs(last - e.p) < 0.04 ? "pos" : "zero"}">시뮬 상대도수 ${last.toFixed(3)} — 이론값과 차이 ${Math.abs(last - e.p).toFixed(3)}</div>` +
        `<div class="d-count">${e.desc} · 항상 0 ≤ P ≤ 1, 전체의 확률 = 1</div>`;
    };
    const st = buildSlider(controlsEl, { label: "시행 횟수", min: 50, max: 1000, step: 50, value: trials, format: fmt });
    st.onChange = (v) => { trials = v; render(); };
    buildButtonRow(controlsEl, [
      { label: "동전", cls: "on", onClick: (b) => { exp = 0; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "주사위 3의 배수", onClick: (b) => { exp = 1; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "🎲 다시 시뮬", cls: "lime", onClick: () => { seed = (seed * 1103515245 + 12345) % 2147483647; render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "주사위를 한 번 던질 때, <b>3의 배수의 눈</b>이 나올 확률은?",
    choices: ["1/3", "1/6", "1/2", "2/3"],
    answer: 0,
    hint: "3의 배수는 3과 6, 두 가지. 전체는 여섯 가지.",
    wrongNotes: [
      null,
      "3의 배수는 3 하나가 아니다. 6도 3의 배수다 → 2가지.",
      "짝수(2,4,6)와 헷갈렸다. 3의 배수는 3, 6 두 개뿐.",
      "2/3는 '3의 배수가 아닐' 확률(4/6)이다. 값은 맞지만 질문이 묻는 사건의 반대편.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "주사위의 근원사건은 1~6, 여섯 가지. 전부 같은 가능성이다.", run: () => drawRelFreq(svg, { p: 1 / 3, trials: 400, seed: 21, label: "3의 배수" }) },
      { caption: "사건 '3의 배수' = {3, 6}. 경우의 수 2개.", run: () => {} },
      { caption: "P = (사건의 경우) / (전체 경우) = 2/6 = 1/3.", run: () => {} },
      { caption: "시뮬레이션 곡선도 결국 1/3에 붙는다 — 이것이 통계적 확률과 수학적 확률의 만남이다.", run: () => {} },
    ];
  },
};

/* 12확통02-02 확률의 덧셈정리 */
const ps0202 = {
  id: "ps-0202",
  course: "확률과 통계", unit: "확률",
  badge: "확통 · 확률 · 12확통02-02",
  std: "12확통02-02",
  title: "확률의 덧셈정리",
  tag: "P(A∪B) = P(A) + P(B) − P(A∩B) — 겹침은 한 번만",
  oneLiner: "합사건의 확률은 두 확률을 더한 뒤, 두 번 세어진 교집합을 한 번 빼서 구한다.",
  veilText: "🙈 벤다이어그램 가림 — 덧셈정리 공식만으로 계산해봐.",
  playgroundGuide: "P(A), P(B), 겹침을 바꿔봐. 겹침을 안 빼면 확률이 1을 넘어버리는 순간도 만들어봐라.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let a = 4, b = 6, c = 2; // 12분모
    let sa, sb, sc;
    const render = () => {
      // P(A∩B) ≤ min(P(A), P(B)) — 클램프하면 슬라이더 표시도 동기화
      const cl = Math.min(c, a, b);
      if (cl !== c) { c = cl; if (sc) sc.set(c); }
      drawVenn(svg, { mode: "union", labels: [`A`, `B`] });
      const u = a + b - c;
      const impossible = u > 12; // P(A∪B) > 1 — 존재할 수 없는 확률 배정
      readoutEl.innerHTML =
        `<div class="formula">P(A∪B) = ${statFrac(a, 12)} + ${statFrac(b, 12)} − ${statFrac(c, 12)} = ${statFrac(u, 12)}</div>` +
        `<div class="d-badge ${impossible ? "neg" : "pos"}">${impossible
          ? `불가능한 조합! P(A∪B)는 1을 넘을 수 없다 — 이 P(A), P(B)라면 겹침이 최소 ${statFrac(a + b - 12, 12)}는 되어야 한다`
          : "겹침(A∩B)을 한 번 빼서 이중 계산 제거"}</div>` +
        `<div class="d-count">P(A∩B) = 0 이면(배반) 그냥 더하면 된다</div>`;
    };
    sa = buildSlider(controlsEl, { label: "P(A) (12분의)", min: 1, max: 10, step: 1, value: a, format: (v) => statFrac(v, 12) });
    sb = buildSlider(controlsEl, { label: "P(B) (12분의)", min: 1, max: 10, step: 1, value: b, format: (v) => statFrac(v, 12) });
    sc = buildSlider(controlsEl, { label: "P(A∩B) (12분의)", min: 0, max: 6, step: 1, value: c, format: (v) => statFrac(v, 12) });
    sa.onChange = (v) => { a = v; render(); };
    sb.onChange = (v) => { b = v; render(); };
    sc.onChange = (v) => { c = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>P(A) = 1/3, P(B) = 1/2, P(A∩B) = 1/6</b> 일 때 <b>P(A∪B)</b> 는?",
    choices: ["2/3", "5/6", "1/2", "1"],
    answer: 0,
    hint: "통분: 2/6 + 3/6 − 1/6.",
    wrongNotes: [
      null,
      "그냥 더했다(5/6). 교집합이 두 번 세어졌으니 1/6을 빼야 한다.",
      "P(B)만 남았네. 덧셈정리 세 항을 다 써라.",
      "합이 1이 되려면 두 사건이 전체를 덮어야 한다. 여기선 아니다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "P(A)와 P(B)를 그냥 더하면 겹치는 부분이 두 번 들어간다.", run: () => drawVenn(svg, { mode: "union", labels: ["A", "B"] }) },
      { caption: "2/6 + 3/6 = 5/6 — 여기엔 A∩B(1/6)가 이중으로 포함돼 있다.", run: () => drawVenn(svg, { mode: "inter", labels: ["A", "B"] }) },
      { caption: "한 번 빼준다: 5/6 − 1/6 = 4/6 = 2/3.", run: () => {} },
      { caption: "결론: P(A∪B) = 2/3. 벤다이어그램의 넓이 감각으로 기억해라 — 겹침은 한 번만.", run: () => {} },
    ];
  },
};

/* 12확통02-03 여사건의 확률 */
const ps0203 = {
  id: "ps-0203",
  course: "확률과 통계", unit: "확률",
  badge: "확통 · 확률 · 12확통02-03",
  std: "12확통02-03",
  title: "여사건의 확률",
  tag: "'적어도'가 보이면 반대편(전부 아님)을 계산해 1에서 뺀다",
  oneLiner: "사건 A가 일어나지 않을 확률은 1−P(A)이며, '적어도 하나'는 여사건으로 계산하는 게 훨씬 빠르다.",
  veilText: "🙈 그림 가림 — 1 − P(여사건)으로만 계산해봐.",
  playgroundGuide: "동전 개수를 바꿔봐. '적어도 한 번 앞면'을 정공법으로 세면 지옥, 여사건으로 하면 한 줄이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 3;
    const render = () => {
      const { el, txt } = freeCanvas(svg);
      const total = Math.pow(2, n);
      txt(280, 52, `동전 ${n}번 — 적어도 한 번은 앞면일 확률`, { size: 21, weight: 900 });
      // 전체 사각형 + '모두 뒷면' 한 조각
      el("rect", { x: 60, y: 110, width: 440, height: 260, rx: 16, fill: "rgba(198,242,46,0.4)", stroke: "#5a7a00", "stroke-width": 3 });
      const sliceW = 440 / total;
      el("rect", { x: 60 + 440 - sliceW, y: 110, width: sliceW, height: 260, rx: 4, fill: "rgba(202,68,227,0.25)", stroke: "#ca44e3", "stroke-width": 3 });
      txt(60 + 220, 250, `적어도 한 번 앞면\n${total - 1}가지`, { size: 20, weight: 900, fill: "#3c5200" });
      txt(60 + 440 - sliceW / 2, 100, `모두 뒷면 1가지`, { size: 14, fill: "#ca44e3", weight: 900 });
      txt(280, 420, `P = 1 − (1/2)^${n} = 1 − ${statFrac(1, total)} = ${statFrac(total - 1, total)}`, { size: 25, weight: 900, fill: "#178a4c" });
      txt(280, 470, `정공법이면 경우 ${total - 1}가지를 일일이 세야 한다`, { size: 15, fill: "#8b8578", weight: 700 });
      readoutEl.innerHTML =
        `<div class="formula">P(적어도 1번 앞면) = 1 − P(모두 뒷면) = ${statFrac(total - 1, total)}</div>` +
        `<div class="d-count">여사건: 단 한 조각(모두 뒷면)만 계산하면 끝</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "동전 던지는 횟수", min: 2, max: 5, step: 1, value: n, format: fmt });
    sn.onChange = (v) => { n = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "동전을 <b>3번</b> 던질 때, <b>적어도 한 번 앞면</b>이 나올 확률은?",
    choices: ["7/8", "1/8", "3/8", "1/2"],
    answer: 0,
    hint: "여사건 = '모두 뒷면' 딱 하나. 1 − (1/2)³.",
    wrongNotes: [
      null,
      "1/8은 '모두 뒷면'의 확률, 즉 여사건이다. 1에서 빼는 걸 잊었다.",
      "'정확히 한 번'(3/8)과 헷갈렸다. '적어도'는 1번, 2번, 3번 전부 포함.",
      "감으로 반반? '적어도'는 생각보다 크다. 세 판 중 한 번은 나오기 마련.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "'적어도 한 번 앞면'의 반대는 단 하나 — '세 번 모두 뒷면'.", run: () => {
        const { el, txt } = freeCanvas(svg);
        el("rect", { x: 60, y: 120, width: 440, height: 260, rx: 16, fill: "rgba(198,242,46,0.4)", stroke: "#5a7a00", "stroke-width": 3 });
        el("rect", { x: 445, y: 120, width: 55, height: 260, rx: 4, fill: "rgba(202,68,227,0.25)", stroke: "#ca44e3", "stroke-width": 3 });
        txt(250, 260, "적어도 한 번 앞면 (7가지)", { size: 20, weight: 900, fill: "#3c5200" });
        txt(472, 110, "모두 뒷면", { size: 14, fill: "#ca44e3", weight: 900 });
        txt(280, 440, "전체 = 1", { size: 20, weight: 800 });
      } },
      { caption: "P(모두 뒷면) = (1/2)×(1/2)×(1/2) = 1/8.", run: () => {} },
      { caption: "전체에서 뺀다: 1 − 1/8 = 7/8.", run: () => {} },
      { caption: "결론: 7/8. '적어도'라는 단어가 보이면 반사적으로 여사건을 떠올려라.", run: () => {} },
    ];
  },
};

/* 12확통02-04 조건부확률 */
const ps0204 = {
  id: "ps-0204",
  course: "확률과 통계", unit: "확률",
  badge: "확통 · 확률 · 12확통02-04",
  std: "12확통02-04",
  title: "조건부확률",
  tag: "조건이 붙으면 분모가 바뀐다 — 표본공간의 축소",
  oneLiner: "P(B|A)는 A가 일어났다는 정보로 표본공간을 A로 줄인 뒤, 그 안에서 B의 비율을 재는 것이다.",
  veilText: "🙈 표 가림 — P(B|A) = P(A∩B)/P(A)로만 계산해봐.",
  playgroundGuide: "조건 버튼을 눌러봐. 표에서 초록으로 켜지는 행이 새 분모(축소된 표본공간)다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    // 학년 × 동아리 분할표 (전체 40명)
    const data = [[12, 8], [6, 14]];
    const rowLabels = ["1학년", "2학년"], colLabels = ["밴드부", "코딩부"];
    let cond = 0; // 0: 1학년 중, 1: 2학년 중, -1: 전체
    const render = () => {
      drawTwoWayTable(svg, { rowLabels, colLabels, data, hiRow: cond, title: "학생 40명 — 학년 × 동아리" });
      if (cond >= 0) {
        const rowSum = data[cond][0] + data[cond][1];
        readoutEl.innerHTML =
          `<div class="formula">P(밴드부 | ${rowLabels[cond]}) = ${data[cond][0]}/${rowSum} = ${statFrac(data[cond][0], rowSum)}</div>` +
          `<div class="d-badge pos">분모가 40이 아니라 ${rowSum} — 조건이 표본공간을 줄였다</div>` +
          `<div class="d-count">전체 기준 P(${rowLabels[cond]}∩밴드) = ${statFrac(data[cond][0], 40)}과 헷갈리지 마라</div>`;
      } else {
        readoutEl.innerHTML =
          `<div class="formula">P(밴드부) = ${data[0][0] + data[1][0]}/40 = ${statFrac(data[0][0] + data[1][0], 40)}</div>` +
          `<div class="d-count">조건이 없으면 분모는 전체 40</div>`;
      }
    };
    buildButtonRow(controlsEl, [
      { label: "조건 없음 (전체)", onClick: (b) => { cond = -1; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "1학년 중에서", cls: "on", onClick: (b) => { cond = 0; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "2학년 중에서", onClick: (b) => { cond = 1; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "학생 40명 중 1학년은 <b>밴드부 12명, 코딩부 8명</b>이다. <b>1학년 중에서</b> 한 명을 뽑을 때 <b>밴드부</b>일 확률은?",
    choices: ["3/5", "3/10", "2/3", "1/2"],
    answer: 0,
    hint: "조건 '1학년 중에서' → 분모는 40이 아니라 1학년 20명.",
    wrongNotes: [
      null,
      "12/40 = 3/10은 '전체에서 1학년 밴드부'일 확률. 분모가 축소되지 않았다.",
      "12/18은 P(1학년|밴드부) — 조건과 사건을 뒤집었다. 조건부확률의 대표 함정.",
      "감이 아니라 표를 봐라. 1학년 20명 중 밴드부 12명이다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "조건 '1학년 중에서'가 붙는 순간, 2학년 행은 세상에서 사라진다.", run: () => drawTwoWayTable(svg, { rowLabels: ["1학년", "2학년"], colLabels: ["밴드부", "코딩부"], data: [[12, 8], [6, 14]], hiRow: 0, title: "표본공간이 1학년 20명으로 축소" }) },
      { caption: "새 표본공간 = 1학년 20명. 그 안에서 밴드부는 12명.", run: () => {} },
      { caption: "P(밴드|1학년) = 12/20 = 3/5. 공식으로는 P(A∩B)/P(A) = (12/40)/(20/40).", run: () => {} },
      { caption: "결론: 3/5. 조건부확률은 '시간 순서'가 아니라 '분모 교체'다.", run: () => {} },
    ];
  },
};

/* 12확통02-05 사건의 독립과 종속 */
const ps0205 = {
  id: "ps-0205",
  course: "확률과 통계", unit: "확률",
  badge: "확통 · 확률 · 12확통02-05",
  std: "12확통02-05",
  title: "사건의 독립과 종속",
  tag: "P(A∩B) = P(A)P(B)가 성립하면 독립 — 정보가 확률을 안 바꾼다",
  oneLiner: "두 사건이 독립이면 한 사건의 발생 정보가 다른 사건의 확률을 바꾸지 못한다.",
  veilText: "🙈 판정기 가림 — P(A∩B) = P(A)P(B) 검산만으로 판단해봐.",
  playgroundGuide: "세 확률을 움직여 독립 조건이 맞아떨어지는 순간을 찾아봐. 배지가 초록으로 켜진다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let a = 3, b = 2, c = 6; // P(A)=a/6, P(B)=b/6, P(A∩B)=c/36
    let sa2, sb2, sc2;
    const render = () => {
      // 확률 공리 제약: max(0, P(A)+P(B)−1) ≤ P(A∩B) ≤ min(P(A), P(B))
      const lo = Math.max(0, 6 * (a + b) - 36), hi = 6 * Math.min(a, b);
      const cl = Math.min(Math.max(c, lo), hi);
      if (cl !== c) { c = cl; if (sc2) sc2.set(c); }
      const { el, txt } = freeCanvas(svg);
      const pa = a / 6, pb = b / 6, pab = c / 36;
      const prod = a * b; // /36
      const indep = c === prod;
      txt(280, 60, "독립 판정기", { size: 22, weight: 900 });
      txt(280, 130, `P(A) × P(B) = ${statFrac(a, 6)} × ${statFrac(b, 6)} = ${statFrac(prod, 36)}`, { size: 22, weight: 800 });
      txt(280, 190, `P(A∩B) = ${statFrac(c, 36)}`, { size: 22, weight: 800, fill: "#327ffa" });
      el("rect", { x: 130, y: 240, width: 300, height: 86, rx: 18, fill: indep ? "rgba(23,138,76,0.12)" : "rgba(202,68,227,0.1)", stroke: indep ? "#178a4c" : "#ca44e3", "stroke-width": 3.5 });
      txt(280, 292, indep ? "독립! 정보가 확률을 안 바꾼다" : "종속 — 정보가 확률을 바꾼다", { size: 21, weight: 900, fill: indep ? "#178a4c" : "#ca44e3" });
      const pbGivenA = a === 0 ? 0 : c / (6 * a);
      txt(280, 380, `P(B|A) = ${a ? statFrac(c, 6 * a) : "-"} vs P(B) = ${statFrac(b, 6)}`, { size: 19, weight: 800 });
      txt(280, 425, indep ? "조건이 붙어도 B의 확률이 그대로다" : "조건이 붙으니 B의 확률이 달라졌다", { size: 15, fill: "#8b8578", weight: 700 });
      void pab; void pbGivenA;
      readoutEl.innerHTML =
        `<div class="formula">P(A∩B) ${indep ? "=" : "≠"} P(A)·P(B)</div>` +
        `<div class="d-badge ${indep ? "pos" : "neg"}">${indep ? "독립" : "종속"}</div>` +
        `<div class="d-count">독립 판정은 느낌이 아니라 곱셈 검산이다</div>`;
    };
    sa2 = buildSlider(controlsEl, { label: "P(A) (6분의)", min: 1, max: 5, step: 1, value: a, format: (v) => statFrac(v, 6) });
    sb2 = buildSlider(controlsEl, { label: "P(B) (6분의)", min: 1, max: 5, step: 1, value: b, format: (v) => statFrac(v, 6) });
    sc2 = buildSlider(controlsEl, { label: "P(A∩B) (36분의)", min: 0, max: 25, step: 1, value: c, format: (v) => statFrac(v, 36) });
    sa2.onChange = (v) => { a = v; render(); };
    sb2.onChange = (v) => { b = v; render(); };
    sc2.onChange = (v) => { c = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "<b>P(A) = 1/2, P(B) = 1/3, P(A∩B) = 1/6</b> 일 때 두 사건 A, B는?",
    choices: ["독립이다", "종속이다", "배반이다", "판단할 수 없다"],
    answer: 0,
    hint: "P(A)·P(B) = 1/2 × 1/3 을 계산해서 P(A∩B)와 비교해라.",
    wrongNotes: [
      null,
      "1/2 × 1/3 = 1/6 = P(A∩B). 곱이 정확히 일치하니 독립이다.",
      "배반은 P(A∩B)=0일 때다. 여긴 1/6로 함께 일어난다.",
      "판단 재료는 다 있다. 독립 판정식에 넣기만 하면 된다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "독립의 정의: P(A∩B) = P(A)·P(B). 느낌이 아니라 등식이다.", run: () => {
        const { el, txt } = freeCanvas(svg);
        txt(280, 120, "P(A∩B) =? P(A) × P(B)", { size: 26, weight: 900, fill: "#327ffa" });
        el("rect", { x: 100, y: 180, width: 360, height: 4, rx: 2, fill: "#e7e3da" });
      } },
      { caption: "우변: 1/2 × 1/3 = 1/6.", run: () => {} },
      { caption: "좌변 P(A∩B) = 1/6. 정확히 일치.", run: () => {} },
      { caption: "결론: 독립. A가 일어났다는 소식이 B의 확률을 1/3에서 한 치도 못 움직인다.", run: () => {} },
    ];
  },
};

/* 12확통02-06 확률의 곱셈정리 */
const ps0206 = {
  id: "ps-0206",
  course: "확률과 통계", unit: "확률",
  badge: "확통 · 확률 · 12확통02-06",
  std: "12확통02-06",
  title: "확률의 곱셈정리",
  tag: "P(A∩B) = P(A)·P(B|A) — 가지를 타고 곱해라",
  oneLiner: "연달아 일어나는 사건의 확률은 첫 확률에 '앞이 일어난 뒤의' 조건부확률을 곱한다.",
  veilText: "🙈 나무 가림 — P(A)·P(B|A) 곱셈만으로 계산해봐.",
  playgroundGuide: "공 개수를 바꾸고 경로를 골라봐. 비복원이면 둘째 가지의 분모·분자가 줄어드는 게 핵심이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let r = 3, b = 7, path = 0;
    const render = () => {
      const total = r + b;
      const desc = ["빨강→빨강", "빨강→파랑", "파랑→빨강", "파랑→파랑"][path];
      const nums = [
        [r, total, r - 1, total - 1],
        [r, total, b, total - 1],
        [b, total, r, total - 1],
        [b, total, b - 1, total - 1],
      ][path];
      drawProbTree(svg, {
        p1: r / total,
        labels1: ["빨강", "파랑"],
        p2GivenA: (r - 1) / (total - 1),
        p2GivenAc: r / (total - 1),
        labels2: ["빨강", "파랑"],
        fracs: {
          // 가지 라벨은 약분 없이 — 분모가 total−1로 줄어드는 게 보여야 한다
          b1: [`${r}/${total}`, `${b}/${total}`],
          b2A: [`${r - 1}/${total - 1}`, `${b}/${total - 1}`],
          b2Ac: [`${r}/${total - 1}`, `${b - 1}/${total - 1}`],
          result: statFrac(nums[0] * nums[2], nums[1] * nums[3]),
        },
        hiPath: path,
      });
      readoutEl.innerHTML =
        // 분모가 total → total−1로 '줄어드는 것'이 보이도록 약분하지 않고 표기
        `<div class="formula">P(${desc}) = ${nums[0]}/${nums[1]} × ${nums[2]}/${nums[3]} = ${statFrac(nums[0] * nums[2], nums[1] * nums[3])}</div>` +
        `<div class="d-badge pos">비복원: 둘째 가지는 분모가 ${total - 1}로 줄어든 조건부확률</div>` +
        `<div class="d-count">빨강 ${r} · 파랑 ${b} 주머니에서 연달아 2개</div>`;
    };
    const sr = buildSlider(controlsEl, { label: "빨간 공", min: 2, max: 5, step: 1, value: r, format: fmt });
    const sb = buildSlider(controlsEl, { label: "파란 공", min: 2, max: 7, step: 1, value: b, format: fmt });
    const sp = buildSlider(controlsEl, { label: "경로 선택", min: 0, max: 3, step: 1, value: path, format: (v) => ["빨→빨", "빨→파", "파→빨", "파→파"][v] });
    sr.onChange = (v) => { r = v; render(); };
    sb.onChange = (v) => { b = v; render(); };
    sp.onChange = (v) => { path = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "빨간 공 <b>3개</b>, 파란 공 <b>7개</b> 주머니에서 <b>꺼낸 공을 되돌리지 않고</b> 2개를 뽑을 때, <b>둘 다 빨간 공</b>일 확률은?",
    choices: ["1/15", "9/100", "3/10", "2/9"],
    answer: 0,
    hint: "첫 번째 3/10, 두 번째는 빨강이 하나 줄어든 2/9. 곱해라.",
    wrongNotes: [
      null,
      "(3/10)² = 9/100은 '복원'일 때다. 공을 되돌리지 않으면 둘째 확률이 변한다.",
      "첫 번째 확률에서 멈췄다. 두 번째 가지까지 곱해야 한다.",
      "그건 둘째 가지 P(빨강|빨강)뿐이다. 첫 가지 3/10을 곱해라.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "첫 뽑기: 빨강 확률 3/10.", run: () => drawProbTree(svg, { p1: 0.3, labels1: ["빨강", "파랑"], p2GivenA: 2 / 9, p2GivenAc: 3 / 9, labels2: ["빨강", "파랑"], fracs: { b1: ["3/10", "7/10"], b2A: ["2/9", "7/9"], b2Ac: ["3/9", "6/9"], result: "1/15" }, hiPath: 0 }) },
      { caption: "빨강을 이미 꺼냈다면? 남은 건 빨강 2, 파랑 7 — 9개. 둘째 빨강은 2/9.", run: () => {} },
      { caption: "곱셈정리: P = 3/10 × 2/9 = 6/90 = 1/15.", run: () => {} },
      { caption: "결론: 1/15. 비복원 = 세상이 바뀐 뒤의 조건부확률을 곱하는 것.", run: () => {} },
    ];
  },
};

/* ---------- 3단원 · 통계 ---------- */

/* 12확통03-01 확률변수와 확률분포 */
const ps0301 = {
  id: "ps-0301",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-01",
  std: "12확통03-01",
  title: "확률변수와 확률분포",
  tag: "결과에 숫자를 붙이면 X, 숫자마다 확률을 붙이면 분포",
  oneLiner: "확률변수는 시행 결과를 숫자로 바꾼 것이고, 그 숫자들이 각각 어떤 확률을 갖는지가 확률분포다.",
  veilText: "🙈 분포표 가림 — 확률의 합 = 1 조건만으로 계산해봐.",
  playgroundGuide: "실험을 바꿔봐. 어떤 실험이든 분포표의 확률을 다 더하면 정확히 1이 된다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let exp = 0;
    const exps = [
      { title: "동전 2개 — X = 앞면의 수", values: [0, 1, 2], probs: [0.25, 0.5, 0.25], den: 4 },
      { title: "주사위 1개 — X = 나온 눈", values: [1, 2, 3, 4, 5, 6], probs: Array(6).fill(1 / 6), den: 6 },
      { title: "동전 3개 — X = 앞면의 수", values: [0, 1, 2, 3], probs: [1 / 8, 3 / 8, 3 / 8, 1 / 8], den: 8 },
    ];
    const render = () => {
      const e = exps[exp];
      drawPMF(svg, { values: e.values, probs: e.probs, title: e.title, showMean: false, unitFrac: e.den });
      readoutEl.innerHTML =
        `<div class="formula">P(X=x) 분포표 — 합 = ${e.probs.map((p) => statFrac(Math.round(p * e.den), e.den)).join(" + ")} = 1</div>` +
        `<div class="d-badge pos">모든 확률분포의 철칙: 각 확률 ≥ 0, 총합 = 1</div>` +
        `<div class="d-count">X는 결과가 아니라 결과에 붙인 '숫자'다</div>`;
    };
    buildButtonRow(controlsEl, [
      { label: "동전 2개", cls: "on", onClick: (b) => { exp = 0; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "주사위", onClick: (b) => { exp = 1; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
      { label: "동전 3개", onClick: (b) => { exp = 2; b.parentElement.querySelectorAll(".chip-btn").forEach((x) => x.classList.remove("on")); b.classList.add("on"); render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "확률변수 X의 분포가 <b>P(X=0)=1/4, P(X=1)=a, P(X=2)=1/4</b> 일 때, <b>a</b> 의 값은?",
    choices: ["1/2", "1/4", "3/4", "1"],
    answer: 0,
    hint: "확률의 총합은 반드시 1. 1/4 + a + 1/4 = 1.",
    wrongNotes: [
      null,
      "1/4이면 합이 3/4밖에 안 된다. 남은 확률이 어디로 갔나?",
      "3/4이면 합이 1을 넘는다(5/4). 확률 총합은 정확히 1.",
      "a=1이면 합이 3/2. 확률 하나가 1이면 나머지는 0이어야 한다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "분포표의 확률을 모두 더하면 반드시 1 — 어떤 경우든 예외 없다.", run: () => drawPMF(svg, { values: [0, 1, 2], probs: [0.25, 0.5, 0.25], title: "P(X=1)이 비어 있는 분포표", showMean: false, unitFrac: 4 }) },
      { caption: "1/4 + a + 1/4 = 1 로 식을 세운다.", run: () => {} },
      { caption: "a = 1 − 2/4 = 1/2.", run: () => {} },
      { caption: "결론: a = 1/2. '합=1'은 분포표 문제의 만능 열쇠다.", run: () => {} },
    ];
  },
};

/* 12확통03-02 이산확률변수의 기댓값과 표준편차 */
const ps0302 = {
  id: "ps-0302",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-02",
  std: "12확통03-02",
  title: "기댓값과 표준편차",
  tag: "기댓값은 분포의 무게중심, 표준편차는 퍼짐의 크기",
  oneLiner: "E(X)는 값×확률의 합으로 분포의 무게중심이고, V(X)=E(X²)−{E(X)}²는 그 주위의 퍼짐이다.",
  veilText: "🙈 분포 가림 — E(X)=Σx·p 공식만으로 계산해봐.",
  playgroundGuide: "확률을 옮겨봐. 무게가 쏠리는 쪽으로 받침점(기댓값)이 미끄러진다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let p0 = 2, p2 = 4, p4 = 2; // 8분모
    const render = () => {
      const den = p0 + p2 + p4;
      const probs = [p0 / den, p2 / den, p4 / den];
      const values = [0, 2, 4];
      const mean = drawPMF(svg, { values, probs, title: "X = 0, 2, 4 — 무게중심 찾기", showMean: true, unitFrac: den });
      const ex2 = values.reduce((a, v, i) => a + v * v * probs[i], 0);
      const varr = ex2 - mean * mean;
      readoutEl.innerHTML =
        `<div class="formula">E(X) = ${values.map((v, i) => `${v}·${statFrac([p0, p2, p4][i], den)}`).join(" + ")} = ${Math.round(mean * 100) / 100}</div>` +
        `<div class="d-badge pos">V(X) = E(X²) − {E(X)}² = ${Math.round(ex2 * 100) / 100} − ${Math.round(mean * mean * 100) / 100} = ${Math.round(varr * 100) / 100}</div>` +
        `<div class="d-count">σ = √V(X) = ${Math.round(Math.sqrt(varr) * 100) / 100}</div>`;
    };
    const s0 = buildSlider(controlsEl, { label: "X=0의 비중", min: 1, max: 6, step: 1, value: p0, format: fmt });
    const s2 = buildSlider(controlsEl, { label: "X=2의 비중", min: 1, max: 6, step: 1, value: p2, format: fmt });
    const s4 = buildSlider(controlsEl, { label: "X=4의 비중", min: 1, max: 6, step: 1, value: p4, format: fmt });
    s0.onChange = (v) => { p0 = v; render(); };
    s2.onChange = (v) => { p2 = v; render(); };
    s4.onChange = (v) => { p4 = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "확률변수 X가 <b>0, 2, 4</b> 값을 각각 확률 <b>1/4, 1/2, 1/4</b> 로 가질 때 <b>E(X)</b> 는?",
    choices: ["2", "1", "3/2", "5/2"],
    answer: 0,
    hint: "E(X) = 0·(1/4) + 2·(1/2) + 4·(1/4).",
    wrongNotes: [
      null,
      "2·(1/2)=1에서 멈췄다. 4·(1/4)=1도 더해야 한다.",
      "계산이 꼬였다. E(X) = Σ(값×확률)을 처음부터: 0·(1/4)+2·(1/2)+4·(1/4).",
      "어디선가 확률을 잘못 곱했다. 세 항을 다시 써서 더해봐라 — 0 + 1 + 1.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "각 값에 확률만큼의 무게를 얹는다: 0에 1/4, 2에 1/2, 4에 1/4.", run: () => drawPMF(svg, { values: [0, 2, 4], probs: [0.25, 0.5, 0.25], title: "무게중심 = 기댓값", showMean: true, unitFrac: 4 }) },
      { caption: "E(X) = 0·(1/4) + 2·(1/2) + 4·(1/4) = 0 + 1 + 1 = 2.", run: () => {} },
      { caption: "받침점을 2에 두면 널빤지가 수평 — 그래서 '무게중심'이다.", run: () => {} },
      { caption: "결론: E(X) = 2. 참고로 V(X) = E(X²)−4 = (0+2+4)−4 = 2.", run: () => {} },
    ];
  },
};

/* 12확통03-03 이항분포 */
const ps0303 = {
  id: "ps-0303",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-03",
  std: "12확통03-03",
  title: "이항분포",
  tag: "성공 확률 p로 n번 — B(n,p)의 평균은 np, 분산은 npq",
  oneLiner: "독립시행을 n번 반복할 때 성공 횟수 X는 이항분포 B(n,p)를 따르고 E(X)=np, V(X)=npq다.",
  veilText: "🙈 분포 가림 — np, npq 공식만으로 계산해봐.",
  playgroundGuide: "n과 p를 움직여봐. 산의 꼭대기가 항상 np 근처에 서는 게 보이면 성공이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 10, p = 0.5;
    const render = () => {
      const { mu } = drawBinomial(svg, { n, p });
      readoutEl.innerHTML =
        `<div class="formula">B(${n}, ${Math.round(p * 100) / 100}) — P(X=k) = C(${n},k) p^k q^${n}⁻^k</div>` +
        `<div class="d-badge pos">E(X) = np = ${Math.round(mu * 100) / 100} · V(X) = npq = ${Math.round(n * p * (1 - p) * 100) / 100}</div>` +
        `<div class="d-count">q = 1 − p. 봉우리가 np 근처에 서 있다</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "n — 시행 횟수", min: 4, max: 40, step: 2, value: n, format: fmt });
    const sp = buildSlider(controlsEl, { label: "p — 성공 확률", min: 0.1, max: 0.9, step: 0.1, value: p, format: (v) => fmt(v, 1) });
    sn.onChange = (v) => { n = v; render(); };
    sp.onChange = (v) => { p = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "확률변수 X가 이항분포 <b>B(100, 1/5)</b> 를 따를 때, X의 <b>표준편차</b>는?",
    choices: ["4", "16", "20", "2"],
    answer: 0,
    hint: "V(X) = npq = 100 · (1/5) · (4/5). 표준편차는 그 제곱근.",
    wrongNotes: [
      null,
      "16은 분산 V(X)다. 표준편차는 √16 = 4.",
      "20은 평균 np다. 평균과 표준편차를 헷갈렸다.",
      "√V를 너무 많이 씌웠나? V=16이니 σ=4다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "B(100, 1/5): 성공 확률 1/5짜리 시행을 100번.", run: () => drawBinomial(svg, { n: 20, p: 0.2, title: "B(n, 1/5)의 모양 (축소판 n=20)" }) },
      { caption: "평균 E(X) = np = 100 × 1/5 = 20.", run: () => {} },
      { caption: "분산 V(X) = npq = 100 × 1/5 × 4/5 = 16.", run: () => {} },
      { caption: "표준편차 σ = √16 = 4. 결론: 4. (평균 20과 헷갈리면 앙망이다)", run: () => {} },
    ];
  },
};

/* 12확통03-04 정규분포와 이항분포의 관계 */
const ps0304 = {
  id: "ps-0304",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-04",
  std: "12확통03-04",
  title: "정규분포와 이항분포의 관계",
  tag: "n이 커지면 이항분포는 종 모양 N(np, npq)에 안긴다",
  oneLiner: "정규분포는 종 모양의 연속확률분포이고, n이 큰 이항분포는 N(np, npq)로 근사된다.",
  veilText: "🙈 곡선 가림 — 68·95 규칙만으로 판단해봐.",
  playgroundGuide: "n을 끝까지 밀어봐. 삐죽삐죽한 막대들이 매끈한 정규곡선에 정확히 안기는 순간이 온다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 8, p = 0.5;
    const render = () => {
      drawBinomial(svg, { n, p, overlay: true, title: `B(${n}, ${p}) vs 정규곡선` });
      readoutEl.innerHTML =
        `<div class="formula">B(${n}, ${p}) ≈ N(${Math.round(n * p * 10) / 10}, ${Math.round(n * p * (1 - p) * 10) / 10})</div>` +
        `<div class="d-badge ${n >= 30 ? "pos" : "zero"}">${n >= 30 ? "n이 충분히 커서 근사가 딱 맞는다" : "n을 더 키워봐 — 아직 근사가 어설프다"}</div>` +
        `<div class="d-count">정규분포 안에서는 μ±σ에 약 68%, μ±2σ에 약 95%</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "n — 시행 횟수", min: 4, max: 60, step: 4, value: n, format: fmt });
    const sp = buildSlider(controlsEl, { label: "p — 성공 확률", min: 0.2, max: 0.8, step: 0.1, value: p, format: (v) => fmt(v, 1) });
    sn.onChange = (v) => { n = v; render(); };
    sp.onChange = (v) => { p = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "확률변수 X가 정규분포 <b>N(70, 10²)</b> 을 따를 때, <b>P(60 ≤ X ≤ 80)</b> 의 값에 가장 가까운 것은? (P(|Z|≤1) ≈ 0.68)",
    choices: ["약 0.68", "약 0.95", "약 0.50", "약 0.34"],
    answer: 0,
    hint: "60과 80은 평균 70에서 ±10, 즉 ±1σ 구간이다.",
    wrongNotes: [
      null,
      "0.95는 ±2σ(50~90) 구간이다. 여긴 ±1σ.",
      "0.50은 평균 한쪽 전체. 구간을 표준화해서 다시 봐라.",
      "0.34는 한쪽 절반(0~1σ)만이다. 양쪽을 더해야 0.68.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "N(70, 10²): 평균 70, 표준편차 10인 종 모양.", run: () => drawNormal(svg, { mu: 70, sigma: 10, a: 60, b: 80, title: "P(60 ≤ X ≤ 80)" }) },
      { caption: "표준화: Z = (X−70)/10 → 60은 Z=−1, 80은 Z=+1.", run: () => {} },
      { caption: "±1σ 구간의 확률은 어느 정규분포든 약 0.68로 똑같다.", run: () => {} },
      { caption: "결론: 약 0.68. 표준화는 '모든 정규분포를 하나의 표로 통일'하는 기술이다.", run: () => {} },
    ];
  },
};

/* 12확통03-05 모집단과 표본추출 */
const ps0305 = {
  id: "ps-0305",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-05",
  std: "12확통03-05",
  title: "모집단과 표본추출",
  tag: "전수조사가 불가능할 때 — 공정하게 뽑아야 대표한다",
  oneLiner: "알고 싶은 전체가 모집단, 실제로 조사하는 일부가 표본이며 표본은 임의추출로 공정하게 뽑아야 한다.",
  veilText: "🙈 그림 가림 — 임의추출의 정의만으로 판단해봐.",
  playgroundGuide: "[다시 뽑기]를 눌러봐. 매번 다른 표본이 뽑히지만 어떤 점도 특별 대우받지 않는다 — 그게 임의추출이다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let size = 10, seed = 3;
    const render = () => {
      const { el, txt } = freeCanvas(svg);
      txt(280, 46, `모집단 240명 중 ${size}명 임의추출`, { size: 21, weight: 900 });
      let t = seed >>> 0;
      const rand = () => {
        t += 0x6d2b79f5;
        let r = Math.imul(t ^ (t >>> 15), 1 | t);
        r = (r + Math.imul(r ^ (r >>> 7), 61 | r)) ^ r;
        return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
      };
      const cols = 20, rows = 12;
      const chosen = new Set();
      while (chosen.size < size) chosen.add(Math.floor(rand() * cols * rows));
      for (let i = 0; i < cols * rows; i++) {
        const cx = 60 + (i % cols) * 23, cy = 100 + Math.floor(i / cols) * 26;
        const on = chosen.has(i);
        el("circle", { cx, cy, r: on ? 9 : 5, fill: on ? "#ca44e3" : "rgba(38,34,28,0.18)", stroke: on ? "#a236b6" : "none", "stroke-width": 2 });
      }
      txt(280, 460, "모든 점이 뽑힐 확률이 똑같다 — 임의추출(랜덤 샘플링)", { size: 17, weight: 800, fill: "#327ffa" });
      txt(280, 500, "친한 사람만, 앞줄만 뽑으면 표본이 모집단을 대표하지 못한다", { size: 14.5, fill: "#8b8578", weight: 700 });
      readoutEl.innerHTML =
        `<div class="formula">모집단 240 → 표본 ${size}</div>` +
        `<div class="d-count">표본조사의 생명 = 공정한 추출. 크기보다 '어떻게 뽑았나'가 먼저다</div>`;
    };
    const ss = buildSlider(controlsEl, { label: "표본 크기", min: 5, max: 40, step: 5, value: size, format: fmt });
    ss.onChange = (v) => { size = v; render(); };
    buildButtonRow(controlsEl, [
      { label: "🎲 다시 뽑기", cls: "lime", onClick: () => { seed = (seed * 1103515245 + 12345) % 2147483647; render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "전국 고등학생의 평균 수면 시간을 조사하려 한다. 표본을 뽑는 방법으로 가장 적절한 것은?",
    choices: [
      "전국 학생 명단에서 무작위로 추첨한다",
      "우리 반 친구들에게 물어본다",
      "아침 1교시에 졸고 있는 학생만 조사한다",
      "설문에 자원한 학생만 조사한다",
    ],
    answer: 0,
    hint: "모집단의 누구든 같은 확률로 뽑혀야 표본이 전체를 대표한다.",
    wrongNotes: [
      null,
      "우리 반은 전국을 대표하지 못한다. 지역·학교 특성이 통째로 편향된다.",
      "졸고 있는 학생만 고르면 수면 시간이 적은 쪽으로 왕창 치우친다 — 표적 편향.",
      "자원자는 관심 있는 사람만 모여서 편향된다. 유명한 '자기선택 편향'.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "알고 싶은 대상 전체 = 모집단. 전국 고등학생 전부다.", run: () => {
        const { el, txt } = freeCanvas(svg);
        for (let i = 0; i < 240; i++) {
          el("circle", { cx: 60 + (i % 20) * 23, cy: 110 + Math.floor(i / 20) * 26, r: 5, fill: "rgba(38,34,28,0.18)" });
        }
        txt(280, 60, "모집단: 전부 조사(전수조사)는 현실적으로 불가능", { size: 17, weight: 900 });
      } },
      { caption: "그래서 일부(표본)만 조사해 전체를 추측한다 — 표본조사.", run: () => {} },
      { caption: "핵심 조건: 누구든 같은 확률로 뽑히게(임의추출). 편한 대상만 고르면 편향.", run: () => {} },
      { caption: "결론: 무작위 추첨. 통계의 신뢰는 표본의 '공정함'에서 시작된다.", run: () => {} },
    ];
  },
};

/* 12확통03-06 표본통계량과 모수의 관계 */
const ps0306 = {
  id: "ps-0306",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-06",
  std: "12확통03-06",
  title: "표본평균과 모평균의 관계",
  tag: "X̄의 평균은 μ 그대로, 표준편차는 σ/√n으로 줄어든다",
  oneLiner: "표본평균 X̄는 그 자체가 확률변수이며 E(X̄)=μ, σ(X̄)=σ/√n — 표본이 클수록 μ에 다닥 붙는다.",
  veilText: "🙈 분포 가림 — σ/√n 공식만으로 계산해봐.",
  playgroundGuide: "표본 크기 n을 키워봐. 표본평균의 히스토그램이 μ 주위로 빨려 들어가듯 좁아진다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let n = 4, seed = 11;
    const render = () => {
      const se = drawSampling(svg, { mu: 60, sigma: 12, n, seed });
      readoutEl.innerHTML =
        `<div class="formula">E(X̄) = μ = 60 · σ(X̄) = σ/√n = 12/√${n} = ${Math.round(se * 100) / 100}</div>` +
        `<div class="d-badge pos">n=${n} → 표본평균의 퍼짐이 ${Math.round(se * 100) / 100}로 축소</div>` +
        `<div class="d-count">평균은 그대로, 퍼짐만 √n배 줄어든다 — 크게 뽑을수록 정확해지는 이유</div>`;
    };
    const sn = buildSlider(controlsEl, { label: "n — 표본 크기", min: 1, max: 36, step: 1, value: n, format: fmt });
    sn.onChange = (v) => { n = v; render(); };
    buildButtonRow(controlsEl, [
      { label: "🎲 다시 시뮬", cls: "lime", onClick: () => { seed = (seed * 1103515245 + 12345) % 2147483647; render(); } },
    ]);
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "모평균 60, 모표준편차 <b>12</b>인 모집단에서 크기 <b>9</b>인 표본을 뽑을 때, 표본평균 X̄의 <b>표준편차</b>는?",
    choices: ["4", "12", "4/3", "3"],
    answer: 0,
    hint: "σ(X̄) = σ/√n = 12/√9.",
    wrongNotes: [
      null,
      "12는 모집단의 표준편차 그대로다. 표본평균은 √n배 덜 퍼진다.",
      "12/9로 나눴다. 나누는 건 n이 아니라 √n = 3.",
      "3은 √9다. 그걸로 12를 나눠야 답이 된다.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "표본평균 X̄도 뽑을 때마다 달라지는 확률변수다 — 자기만의 분포를 가진다.", run: () => drawSampling(svg, { mu: 60, sigma: 12, n: 9, seed: 23 }) },
      { caption: "그 분포의 중심은 모평균 그대로: E(X̄) = 60.", run: () => {} },
      { caption: "퍼짐은 σ/√n = 12/√9 = 12/3 = 4.", run: () => {} },
      { caption: "결론: 4. 표본을 9배 키우면 오차는 3배(√9배) 줄어든다 — 통계의 핵심 거래.", run: () => {} },
    ];
  },
};

/* 12확통03-07 모평균과 모비율의 추정 */
const ps0307 = {
  id: "ps-0307",
  course: "확률과 통계", unit: "통계",
  badge: "확통 · 통계 · 12확통03-07",
  std: "12확통03-07",
  title: "모평균의 추정 (신뢰구간)",
  tag: "x̄ ± 1.96·σ/√n — '95% 신뢰'는 방법에 대한 신뢰다",
  oneLiner: "표본평균으로 모평균을 포함할 법한 구간을 만들며, 95% 신뢰구간은 x̄±1.96σ/√n이다.",
  veilText: "🙈 구간 가림 — x̄±1.96σ/√n 공식만으로 계산해봐.",
  playgroundGuide: "n을 키워봐. 구간이 좁아진다 — 더 많이 조사할수록 더 정밀하게 말할 수 있다.",
  mountPlayground(controlsEl, svg, readoutEl) {
    let xbar = 50, sigma = 10, n = 25;
    const render = () => {
      const { el, txt } = freeCanvas(svg);
      const half = 1.96 * sigma / Math.sqrt(n);
      const lo = xbar - half, hi = xbar + half;
      txt(280, 52, "95% 신뢰구간", { size: 22, weight: 900 });
      const X = (v) => 60 + ((v - 30) / 40) * 440; // 30~70 스케일
      el("line", { x1: 50, y1: 260, x2: 510, y2: 260, stroke: "#26221c", "stroke-width": 2.5 });
      [30, 40, 50, 60, 70].forEach((v) => {
        el("line", { x1: X(v), y1: 254, x2: X(v), y2: 266, stroke: "#8b8578", "stroke-width": 2 });
        txt(X(v), 292, String(v), { size: 15, fill: "#8b8578", weight: 800 });
      });
      el("rect", { x: X(lo), y: 236, width: X(hi) - X(lo), height: 48, rx: 12, fill: "rgba(198,242,46,0.5)", stroke: "#5a7a00", "stroke-width": 3 });
      el("circle", { cx: X(xbar), cy: 260, r: 9, fill: "#ca44e3" });
      txt(X(xbar), 210, `x̄ = ${xbar}`, { size: 17, fill: "#ca44e3", weight: 900 });
      txt(280, 360, `${Math.round(lo * 100) / 100} ≤ m ≤ ${Math.round(hi * 100) / 100}`, { size: 26, weight: 900, fill: "#178a4c" });
      txt(280, 415, `반폭 = 1.96 × ${sigma}/√${n} = ${Math.round(half * 100) / 100}`, { size: 18, weight: 800, fill: "#327ffa" });
      txt(280, 470, "같은 방법으로 100번 구간을 만들면 약 95번은 진짜 모평균을 품는다", { size: 14.5, fill: "#8b8578", weight: 700 });
      readoutEl.innerHTML =
        `<div class="formula">m ∈ [${Math.round(lo * 100) / 100}, ${Math.round(hi * 100) / 100}]</div>` +
        `<div class="d-count">n이 4배가 되면 구간 폭은 절반 — 정밀도의 값은 √n</div>`;
    };
    const sx = buildSlider(controlsEl, { label: "x̄ — 표본평균", min: 40, max: 60, step: 1, value: xbar, format: fmt });
    const ss = buildSlider(controlsEl, { label: "σ — 모표준편차", min: 5, max: 15, step: 1, value: sigma, format: fmt });
    const sn = buildSlider(controlsEl, { label: "n — 표본 크기", min: 4, max: 100, step: 4, value: n, format: fmt });
    sx.onChange = (v) => { xbar = v; render(); };
    ss.onChange = (v) => { sigma = v; render(); };
    sn.onChange = (v) => { n = v; render(); };
    render();
    return { interact: () => {} };
  },
  quiz: {
    question: "표본평균 <b>x̄ = 50</b>, 모표준편차 <b>σ = 10</b>, 표본 크기 <b>n = 25</b> 일 때 모평균 m의 <b>95% 신뢰구간</b>은? (P(|Z|≤1.96)=0.95)",
    choices: [
      "46.08 ≤ m ≤ 53.92",
      "48.04 ≤ m ≤ 51.96",
      "40 ≤ m ≤ 60",
      "49.22 ≤ m ≤ 50.78",
    ],
    answer: 0,
    hint: "반폭 = 1.96 × 10/√25 = 1.96 × 2 = 3.92.",
    wrongNotes: [
      null,
      "z값 1.96만 반폭으로 썼다. 1.96에 σ/√n = 2를 곱해야 반폭 3.92가 된다.",
      "±σ를 그대로 썼다. σ가 아니라 σ/√n에 1.96을 곱한다.",
      "√n 대신 n=25로 나눴다. 10/25=0.4 → 틀린 반폭.",
    ],
  },
  explainSteps(svg) {
    return [
      { caption: "X̄의 표준편차부터: σ/√n = 10/√25 = 2.", run: () => {
        const { el, txt } = freeCanvas(svg);
        txt(280, 100, "σ(X̄) = 10/√25 = 2", { size: 24, weight: 900, fill: "#327ffa" });
        el("rect", { x: 100, y: 140, width: 360, height: 4, rx: 2, fill: "#e7e3da" });
      } },
      { caption: "95%는 Z가 ±1.96 안에 있을 확률 → 반폭 = 1.96 × 2 = 3.92.", run: () => {} },
      { caption: "구간 = 50 ± 3.92 → [46.08, 53.92].", run: () => {} },
      { caption: "결론: 46.08 ≤ m ≤ 53.92. '95%'는 이 구간이 아니라 이 '방법'의 적중률이다.", run: () => {} },
    ];
  },
};

/* ============================================================
   전체 개념 배열 (교육과정 순서)
   ============================================================ */
const PS_CONCEPTS = [
  ps0101, ps0102, ps0103,                              // 경우의 수
  ps0201, ps0202, ps0203, ps0204, ps0205, ps0206,      // 확률
  ps0301, ps0302, ps0303, ps0304, ps0305, ps0306, ps0307, // 통계
];
