#!/bin/sh
# 아카이브에 **실제로 서명된** entitlement 가 소스 선언과 같은지 본다.
#
# 막으려는 사고 (2026-08-21, 첫 TestFlight 아카이브에서 실제로 발생):
#   Matths/MatthsApp.entitlements 는 세 가지를 선언한다.
#       com.apple.security.application-groups
#       com.apple.developer.automatic-assessment-configuration   ← 시험 중 화면 차단
#       com.apple.developer.applesignin                          ← Apple 로그인
#   그런데 서명된 바이너리에는 앞의 하나뿐이었다. 자동 서명이 만든 프로비저닝
#   프로파일에 나머지 두 capability 가 없어서 **조용히 떨어져 나간 것이다.**
#
#   결과: Apple 로그인은 런타임에 실패하고(심사지침 4.8 위반으로 이어진다),
#   AAC 는 소프트웨어 덮개로만 내려앉는다. 둘 다 크래시가 아니라 **조용한 실패**라
#   빌드도 통과하고 소스 grep 계약 테스트도 전부 통과한다.
#
#   tests/*.sh 는 소스 문자열을 본다. 소스에 설정이 있다는 것과 아카이브가 그걸
#   쓴다는 것은 다른 말이다. 그 틈을 이 스크립트가 닫는다.
#
# 쓰는 법:
#   sh scripts/verify-archive-entitlements.sh /path/to/Matths.xcarchive
#
# 업로드 전에 반드시 한 번 돌리십시오.
set -eu

archive="${1:-}"
[ -n "$archive" ] || { echo "사용법: $0 <경로>/Matths.xcarchive" >&2; exit 2; }
[ -d "$archive" ] || { echo "아카이브를 찾을 수 없습니다: $archive" >&2; exit 2; }

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app="$archive/Products/Applications/Matths.app"
[ -d "$app" ] || { echo "Matths.app 이 없습니다: $app" >&2; exit 2; }

src="$root/Matths/MatthsApp.entitlements"
bad=0

# **XML 주석 안의 <key> 를 세면 안 된다.** 이 저장소는 제한 권한(AAC·applesignin)을
# 승인 전까지 주석으로 막아 두는 방식을 쓴다. 주석까지 세면 "선언했는데 서명에
# 빠졌다"는 거짓 경보가 난다 — 이 스크립트를 처음 쓸 때 실제로 그렇게 잘못 읽었다.
# plutil 로 파싱해 **실제 최상위 키만** 가져온다.
keys_of_plist() {
  plutil -convert json -o - "$1" 2>/dev/null \
    | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin).keys()))' 2>/dev/null
}

signed=$(codesign -d --entitlements :- "$app" 2>/dev/null \
         | grep -oE "<key>[^<]+</key>" | sed 's/<[^>]*>//g')

echo "── 소스 선언 대비 서명 결과 ──"
for k in $(keys_of_plist "$src"); do
  if printf '%s\n' "$signed" | grep -Fxq "$k"; then
    echo "  OK    $k"
  else
    echo "  빠짐  $k" >&2
    bad=1
  fi
done

# get-task-allow 는 디버거 부착 허용 여부다. **키의 존재가 아니라 값을 봐야 한다.**
# 배포 서명에도 이 키는 남고 값만 <false/> 로 바뀐다. 키 이름만 grep 하면
# 정상인 IPA 를 "업로드 거부된다" 고 잘못 읽는다 — 실제로 그렇게 오경보를 냈다.
gta=$(codesign -d --entitlements :- "$app" 2>/dev/null \
      | plutil -convert json -o - - 2>/dev/null \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("get-task-allow"))' 2>/dev/null)
case "$gta" in
  True)  echo; echo "  참고: get-task-allow=true — 개발 서명입니다."
         echo "        아카이브 단계에서는 정상이고, exportArchive 로 배포 재서명하면 false 가 됩니다." ;;
  False) echo; echo "  OK    get-task-allow=false — 배포 서명입니다." ;;
esac

echo
echo "── 프로비저닝 프로파일이 그 capability 를 갖고 있는가 ──"
prov="$app/embedded.mobileprovision"
if [ -f "$prov" ]; then
  tmp=$(mktemp -t matths-prov)
  security cms -D -i "$prov" > "$tmp" 2>/dev/null || true
  echo "  프로파일: $(/usr/libexec/PlistBuddy -c 'Print :Name' "$tmp" 2>/dev/null)"
  for k in com.apple.developer.automatic-assessment-configuration \
           com.apple.developer.applesignin; do
    if grep -Fq "$k" "$tmp"; then echo "  OK    $k"; else echo "  없음  $k" >&2; bad=1; fi
  done
  rm -f "$tmp"
else
  echo "  embedded.mobileprovision 이 없습니다." >&2
  bad=1
fi

echo
if [ "$bad" -ne 0 ]; then
  cat >&2 <<'EOF'
FAIL: 선언한 entitlement 가 서명에 실리지 않았습니다.

거의 항상 원인은 하나입니다 — **App ID 에 capability 가 안 켜져 있습니다.**
자동 서명은 App ID 에 켜진 것만으로 프로파일을 만들기 때문에, 소스에 아무리
적어 두어도 조용히 떨어집니다.

  developer.apple.com → Certificates, Identifiers & Profiles
    → Identifiers → kr.matths.app
      · Sign in with Apple                        켜기
      · Automatic Assessment Configuration        켜기 (Apple 승인 필요 항목)
    저장 후 Xcode 에서 자동 서명이 프로파일을 다시 받게 하고 재아카이브.

AAC 는 Apple 승인을 받아야 목록에 나타납니다. 승인 전이라면 그 항목은
승인 뒤로 미루고, Apple 로그인만 먼저 닫으십시오 — 그쪽은 심사지침 4.8 과
직결됩니다(소셜 로그인을 제공하면 동등한 대안이 있어야 합니다).
EOF
  exit 1
fi

echo "PASS: 선언한 entitlement 가 모두 서명에 실렸습니다."
