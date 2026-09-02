#!/bin/bash
# 앱이 바라보는 서버 주소를 바꾼다 (백로그 L-3 의 앱 쪽 절반).
#
#   ./set-server-url.sh https://www.matths.kr
#
# 왜 스크립트인가: 이 값을 바꾸는 일은 "Swift 파일을 열어 한 줄 고치기" 였는데,
# 그 한 줄을 잘못 고치면(끝에 / 를 붙이거나 http 로 적거나) 앱 전체가 서버에
# 못 붙고 원인은 런타임에야 드러난다. 형식을 먼저 검사하고, 바꾼 뒤
# 릴리즈 검사까지 자동으로 돌린다.
set -euo pipefail
cd "$(dirname "$0")"

FILE="Matths/ServerAPI.swift"
NEW="${1:-}"

if [ -z "$NEW" ]; then
  CUR=$(grep -o 'static let defaultURL = "[^"]*"' "$FILE" | sed 's/.*"\(.*\)"/\1/')
  echo "지금 주소: $CUR"
  echo "사용법: $0 https://www.matths.kr"
  exit 0
fi

# ── 형식 검사 ────────────────────────────────────────────────────────────
if [[ "$NEW" != https://* ]]; then
  echo "✗ https:// 로 시작해야 한다 (http 는 ATS 예외가 필요해 출시가 막힌다): $NEW" >&2
  exit 1
fi
if [[ "$NEW" != "https://www.matths.kr" && "$NEW" != "https://www.matths.kr/" ]]; then
  echo "✗ 운영 정본은 https://www.matths.kr 하나다: $NEW" >&2
  exit 1
fi
if [[ "$NEW" == */ ]]; then
  # 경로를 이어 붙일 때 //api/v1 이 되어 404 가 난다. 조용히 고쳐 준다.
  NEW="${NEW%/}"
  echo "· 끝의 / 를 떼었다 → $NEW"
fi
if [[ "$NEW" == *"/api"* ]]; then
  echo "✗ /api 경로까지 넣지 마라. 도메인만 적는다 (코드가 /api/v1 을 붙인다): $NEW" >&2
  exit 1
fi
case "$NEW" in
  *trycloudflare*|*ngrok*|*localhost*|*127.0.0.1*|*192.168.*)
    echo "✗ 임시/로컬 주소다 — 이걸로 출시하면 앱이 며칠 뒤 죽는다: $NEW" >&2
    exit 1;;
esac

# ── 교체 ─────────────────────────────────────────────────────────────────
python3 - "$FILE" "$NEW" <<'PY'
import re, sys
path, new = sys.argv[1], sys.argv[2]
s = open(path, encoding="utf-8").read()
pat = r'(static let defaultURL = ")[^"]*(")'
if not re.search(pat, s):
    print("✗ defaultURL 을 못 찾았다 — ServerAPI.swift 구조가 바뀌었다", file=sys.stderr)
    sys.exit(1)
open(path, "w", encoding="utf-8").write(re.sub(pat, lambda m: m.group(1) + new + m.group(2), s, count=1))
print(f"· {path} 갱신 → {new}")
PY

# 살아 있는 주소인지 확인한다 — 오타를 여기서 잡는다.
echo "· /api/v1/health 확인 중…"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$NEW/api/v1/health" || echo "000")
if [ "$CODE" = "200" ]; then
  echo "  ✓ 서버 응답 200"
else
  echo "  ⚠ 응답 $CODE — 아직 배포 전이거나 주소가 틀렸다. 코드는 바꿔 뒀으니 배포 후 다시 확인할 것."
fi

echo
./verify-release.sh
