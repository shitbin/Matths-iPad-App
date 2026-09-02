/*
 * 풀이 문장 표시 계약.
 *
 * 풀이 원문에서 수식만 떼어 낸 뒤 남은 조사·연결어를 별도 자막으로 만들면
 * `여기에 입니다.`처럼 문법적으로 성립하지 않는 조각이 생긴다. 이 모듈은
 * solution-player와 범용 solution-scene이 같은 fail-closed 판정을 쓰게 한다.
 */
(function (root) {
  "use strict";

  const FUNCTION_WORDS = new Set([
    // 접속·지시 표현: 다른 절이나 앞 문장이 없으면 독립 설명이 아니다.
    "그리고", "그러나", "그래서", "따라서", "그러므로", "하지만", "또한",
    "또는", "즉", "한편", "먼저", "다음으로", "마지막으로", "여기에", "여기서",
    "이때", "이므로", "그러면", "그런데", "이를", "이것을", "그것을",
    // 조사·서술 보조어만 남은 경우를 막는다.
    "은", "는", "이", "가", "을", "를", "에", "에서", "에게", "께", "와", "과",
    "로", "으로", "도", "만", "부터", "까지", "보다", "처럼", "의", "이며", "이고",
    "이다", "입니다", "이었다", "였습니다", "된다", "됩니다", "되었다", "되었습니다",
  ]);
  const ENGLISH_FUNCTION_WORDS = new Set([
    "and", "or", "but", "therefore", "then", "so", "because", "thus", "hence",
  ]);
  // 종결되지 않은 조건·연결 어미 하나만 남은 조각. 앞에 내용어가 있으면 아래
  // token 검사에서 그 내용어가 통과하므로 정상 문장까지 막지는 않는다.
  const CONNECTIVE_ENDING = /(하면|이라면|이면|라면|이므로|므로|해서|하여|하고|이며|이고|지만|는데|면서|자면|거나|든지)$/u;

  function normalize(value) {
    return String(value == null ? "" : value)
      .replace(/\\\(/g, "$")
      .replace(/\\\)/g, "$")
      .replace(/\$\$([^$]+)\$\$/g, "$$$1$")
      .replace(/\s+/g, " ")
      .trim();
  }

  function segments(value) {
    const source = normalize(value);
    const parts = source.split(/\$([^$]+)\$/);
    const output = [];
    parts.forEach((part, index) => {
      if (index % 2 === 1) {
        const math = part.trim();
        if (math) output.push({ math });
        return;
      }
      const text = part.replace(/\s+/g, " ").trim();
      if (text) output.push({ text });
    });
    return output;
  }

  function proseTokens(value) {
    const prose = segments(value)
      .filter((part) => part.text !== undefined)
      .map((part) => part.text)
      .join(" ")
      .replace(/[“”‘’'"`~!@#%^&*()_+={}\[\]|\\:;,.?<>/·—–-]/g, " ");
    return prose.split(/\s+/).map((token) => token.trim()).filter(Boolean);
  }

  function isContentToken(rawToken) {
    const token = rawToken.replace(/^[①②③④⑤⑥⑦⑧⑨⑩]+|[①②③④⑤⑥⑦⑧⑨⑩]+$/g, "");
    if (!token || FUNCTION_WORDS.has(token)) return false;
    if (CONNECTIVE_ENDING.test(token)) return false;
    if (/^[A-Za-z][A-Za-z0-9]*$/u.test(token)) {
      return !ENGLISH_FUNCTION_WORDS.has(token.toLowerCase());
    }
    if (/[-+]?\d/u.test(token)) return true;
    // 한글 한 글자 조사는 위 집합에서 제거했다. 남은 두 글자 이상 한글은
    // 개념명·동작·수학 명사로 취급한다(상수항, 곱합니다, 확인 등).
    return /[가-힣]{2,}/u.test(token);
  }

  function analyze(value) {
    const normalized = normalize(value);
    const ordered = segments(normalized);
    const maths = ordered
      .filter((part) => part.math !== undefined)
      .map((part) => part.math);
    const tokens = proseTokens(normalized);
    const hasMath = maths.length > 0;
    const hasContent = tokens.some(isContentToken);
    return {
      normalized,
      segments: ordered,
      maths,
      tokens,
      hasMath,
      hasContent,
      standalone: hasMath || hasContent,
    };
  }

  /** 독립 UI 문자열로 내보내도 되는 문장만 돌려준다. */
  function standalone(value) {
    const result = analyze(value);
    return result.standalone ? result.normalized : "";
  }

  const API = { normalize, segments, analyze, standalone, isContentToken };
  root.MatthsSolutionTextContract = API;
  if (typeof module !== "undefined" && module.exports) module.exports = API;
})(typeof window !== "undefined" ? window : globalThis);
