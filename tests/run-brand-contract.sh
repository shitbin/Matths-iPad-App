#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
expected_hash="f46fd23006c2a529f94f85a25ef34c3e577d072a9e925e4d6afe9f997d9a59d4"
asset="$root/Matths/Assets.xcassets/MatthsPrimaryIdentity.imageset/MatthsPrimaryIdentity.svg"

actual_hash=$(shasum -a 256 "$asset" | awk '{print $1}')
if [ "$actual_hash" != "$expected_hash" ]; then
  echo "FAIL: Primary Identity SVG가 승인된 CI 원본과 다릅니다." >&2
  exit 1
fi

if grep -R -n --include='*.swift' --exclude='DesignTokens.swift' -E '판돈|Sub Division|Main Division' "$root/Matths"; then
  echo "FAIL: 학생 화면에 금지된 도박 용어가 남아 있습니다." >&2
  exit 1
fi

if grep -R -n --include='*.swift' -E '서버가 아직 지원하지 않아|현재 서버는 .*아직 지원하지|서버 업데이트 필요|주소가 바뀌었거나 서버가 내려간|개발 서버 미리보기 코드' "$root/Matths" \
  | grep -v 'AuthScreen.swift'; then
  echo "FAIL: 학생 화면에 개발·인프라 현황 문구가 남아 있습니다." >&2
  exit 1
fi

grep -q 'enum ArenaDisplayTerms' "$root/Matths/DesignTokens.swift"
grep -q 'ArenaDisplayTerms.apply(policy.displayName)' "$root/Matths/ArenaShopScreen.swift"
grep -q 'ArenaDisplayTerms.apply(section.title)' "$root/Matths/GoatArenaRulebookScreen.swift"
grep -q 'ArenaDisplayTerms.tier(target.tier)' "$root/Matths/GoatArenaMainMatchSheet.swift"
grep -q 'ArenaDisplayTerms.purchaseStatus(purchase.status)' "$root/Matths/ArenaShopScreen.swift"
if rg -n 'Text\(target\.tier\)|\\\(purchase\.status\)|\\\(invitation\.targetTier\)' \
    "$root/Matths/ArenaShopScreen.swift" "$root/Matths/GoatArenaMainMatchSheet.swift"; then
  echo "FAIL: Arena 내부 상태·티어 코드가 사용자 Text에 직접 노출됩니다." >&2
  exit 1
fi

# Swift의 \b는 영문 뒤 한글 조사에서 경계를 만들지 않는다. 실제 매퍼에 적힌
# 정규식을 읽어 "Division별" 같은 결합형까지 결과 문자열로 검증한다.
python3 - "$root/Matths/DesignTokens.swift" "$root/Matths" <<'PY'
import pathlib, re, sys

token_source = pathlib.Path(sys.argv[1]).read_text()
replacements = re.findall(r'\(#"(.*?)"#,\s*"(.*?)"\)', token_source)
if not replacements:
    raise SystemExit("FAIL: ArenaDisplayTerms replacement를 읽지 못했습니다.")

def apply(value):
    for pattern, replacement in replacements:
        value = re.sub(pattern, replacement, value, flags=re.IGNORECASE)
    return value

cases = {
    "Division별 순위": "경쟁 구분별 순위",
    "Main Division별 정책": "Ranked별 정책",
    "Sub Ranking에서는": "Unranked에서는",
    "Main전 참가": "Ranked전 참가",
    "판돈 2일": "경기 예치 2일",
    "Subdivision": "Subdivision",
}
for source, expected in cases.items():
    actual = apply(source)
    if actual != expected:
        raise SystemExit(f"FAIL: ArenaDisplayTerms {source!r} -> {actual!r}, expected {expected!r}")

string_literal = re.compile(r'"(?:\\.|[^"\\])*"')
for path in pathlib.Path(sys.argv[2]).rglob("*.swift"):
    if path.name == "DesignTokens.swift":
        continue
    for match in string_literal.finditer(path.read_text()):
        literal = match.group(0)
        if re.search(r'(?<![A-Za-z])Division(?![A-Za-z])', literal, re.IGNORECASE):
            raise SystemExit(f"FAIL: {path} 사용자 문자열에 Division이 남아 있습니다: {literal}")
PY

# WHY: 예전에는 프로젝트 전체의 'TARGETED_DEVICE_FAMILY = "1,2";' 개수를 2로 셌다.
# 위젯 확장(kr.matths.app.widget)이 생기면서 같은 줄이 4개가 되어 앱 타깃은 멀쩡한데
# 검사만 실패했다. run-universal-device-contract.sh 와 같은 방식으로, 앱 타깃
# (kr.matths.app)의 빌드 설정 블록 안에서만 센다 — 확장이 더 붙어도 계약의 뜻
# (앱이 Debug·Release 모두 유니버설)은 그대로고, 앱이 iPad 를 잃으면 여전히 잡힌다.
device_family_count=$(awk '
  /^\t\t[0-9A-Za-z]+ \/\* .* \*\/ = \{$/ { inblock = 1; block = "" }
  inblock { block = block $0 "\n" }
  /^\t\t\};$/ {
    if (inblock && block ~ /isa = XCBuildConfiguration;/ \
        && block ~ /PRODUCT_BUNDLE_IDENTIFIER = kr\.matths\.app;/ \
        && block ~ /TARGETED_DEVICE_FAMILY = "1,2";/) n++
    inblock = 0
  }
  END { print n + 0 }
' "$root/Matths.xcodeproj/project.pbxproj")
if [ "$device_family_count" -ne 2 ]; then
  echo "FAIL: Matths는 iPhone·iPad 유니버설 target이어야 합니다." >&2
  exit 1
fi

grep -q 'PrimaryBrandIdentity()' "$root/Matths/AuthScreen.swift"
if grep -q 'Text("Matths")' "$root/Matths/AuthScreen.swift"; then
  echo "FAIL: 인증 화면에서 워드마크를 Text로 재조립하면 안 됩니다." >&2
  exit 1
fi

grep -q 'PrimaryBrandIdentity()' "$root/Matths/RootView.swift"
if grep -q 'Text("Matths")' "$root/Matths/RootView.swift"; then
  echo "FAIL: 밝은 앱 상단바에서 워드마크를 Text로 재조립하면 안 됩니다." >&2
  exit 1
fi

grep -q 'BrandMark()' "$root/Matths/SplashView.swift"
if grep -q 'Text("Matths")' "$root/Matths/SplashView.swift"; then
  echo "FAIL: 스플래시에서 공식 브랜드 마크 옆 워드마크를 Text로 재조립하면 안 됩니다." >&2
  exit 1
fi

echo "Universal iOS brand and Arena language contracts passed"
