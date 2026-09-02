#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rank="$root/Matths/RankArenaScreen.swift"
arena="$root/Matths/GoatArenaScreen.swift"
evidence="$root/Matths/GoatArenaEvidencePanel.swift"
shop="$root/Matths/ArenaShopScreen.swift"
placement="$root/Matths/PlacementExamScreen.swift"
match_play="$root/Matths/GoatArenaMatchPlayScreen.swift"
main_match="$root/Matths/GoatArenaMainMatchSheet.swift"

grep -Fq '웹 GOAT Arena에서 확인' "$rank"
# 웹 GOAT Arena fallback은 Safari로 계정을 갈라 놓지 않고 로그인 핸드오프 브리지를 쓴다.
for source in "$rank" "$main_match" "$match_play"; do
  if grep -Fq 'appendingPathComponent("goat-arena")' "$source"; then
    echo "GOAT Arena fallback이 Safari 직행 주소를 사용합니다: $source" >&2
    exit 1
  fi
done
grep -Fq 'ArenaWebPresenter.open(.home)' "$rank"
grep -Fq 'ArenaWebPresenter.open(.rankedBattle)' "$main_match"
grep -Fq '.match(matchId: matchId)' "$match_play"
grep -Fq 'guardModel: screenshotGuard' "$match_play"
grep -Fq 'onCapture: { store.recordStuckPoint($0) }' "$match_play"
grep -Fq 'static func owns(path: String) -> Bool' "$root/Matths/ArenaWeb/ArenaWebDestination.swift"
grep -Fq 'path == "/goat-arena" || path.hasPrefix("/goat-arena/")' \
  "$root/Matths/ArenaWeb/ArenaWebDestination.swift"
grep -Fq 'ArenaWebDestination.owns(path: url.path)' \
  "$root/Matths/ArenaWeb/ArenaWebPresenter.swift"

# 로그인 뒤 주문 상태는 앱의 Bearer 세션과 웹 쿠키를 안전하게 잇는 commerce handoff
# 화면으로 들어가야 한다.
grep -Fq 'store.route = .commerce' "$arena"
grep -Fq 'heroButton("이용권과 상점 보기")' "$arena"

# 로그인 뒤 첫 핵심 정보는 서버 snapshot의 tier/MMR/Arena Position이어야 한다.
# 사이클이 없을 때는 같은 설명 섹션을 다시 만들지 않고 hero 안의 상태 1문장과
# commerce 행동 1개만 노출한다. 서버 값이나 상태 판정 자체는 이 계약의 대상이 아니다.
python3 - "$arena" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")

def section(start: str, end: str) -> str:
    try:
        begin = source.index(start)
        finish = source.index(end, begin)
    except ValueError as exc:
        raise SystemExit(f"GOAT Arena hierarchy marker missing: {exc}")
    return source[begin:finish]

body = section("    private var arenaBody", "    // MARK: Header")
ranking_call = body.index("rankingSection(snapshot)")
# hero 는 AnyView 로 감싸져 있다 — 아이패드에서 아레나 진입 즉시 죽던 뷰 제네릭
# 타입 깊이 폭발을 끊기 위해서다(크래시로그 Matths-2026-08-18-204228.ips).
# 이 계약이 지키려는 것은 **순서**이지 그 줄의 생김새가 아니므로, 감싸든 안 감싸든
# 잡히도록 본다. 감싸는 방식이 또 바뀌어도 순서 검사는 살아 있어야 한다.
def hero_position(text: str, after: int) -> int:
    # 가장 **먼저 나오는** 것을 잡는다. 후보를 차례로 시도하면 넓은 폭 본문의
    # AnyView(hero) 를 건너뛰고 좁은 폭 본문의 hero 를 잡아 순서 검사가 헛돈다.
    found = [
        position
        for position in (text.find(candidate, after)
                         for candidate in ("\n                hero\n", "AnyView(hero"))
        if position >= 0
    ]
    if not found:
        raise SystemExit("loaded GOAT Arena must still render the hero section")
    return min(found)

first_hero = hero_position(body, ranking_call)
cycle_sections = body.index("if snapshot.cycle != nil", first_hero)
if not ranking_call < first_hero < cycle_sections:
    raise SystemExit("loaded GOAT Arena must render ranking before cycle hero/sections")

ranking = section("    private func rankingSection", "    private var rankBadgeSize")
tier = ranking.index("tierHero(snapshot.ranking.skill)")
ranking_children = ranking.split(
    "VStack(alignment: .leading, spacing: Tokens.Space.s5) {", 1
)[1]
first_content = next(
    line.strip()
    for line in ranking_children.splitlines()
    if line.strip() and not line.lstrip().startswith("//")
)
if first_content != "tierHero(snapshot.ranking.skill)":
    raise SystemExit(f"server tier must be the first visual ranking child, got {first_content}")
for marker in (
    'Text("두 가지 기준")',
    "statusDecisionRow(rankingLifecyclePresentation(snapshot))",
    "store.route = .placement",
    "mmrPanel(",
    "seatPanel(",
):
    if not tier < ranking.index(marker):
        raise SystemExit(f"server tier must be the first ranking content before {marker}")
if not ranking.index("mmrPanel(") < ranking.index("seatPanel("):
    raise SystemExit("MMR must remain before Arena Position after the tier hero")

if "noCycleGuide" in source:
    raise SystemExit("inactive-cycle copy must not be duplicated in a separate guide section")

inactive = section("    private func noCycleHero", "    private func heroIdentity")
if inactive.count('Text("현재 활성 30일 사이클이 없습니다")') != 1:
    raise SystemExit("inactive cycle must expose exactly one status sentence")
if inactive.count('heroButton("이용권과 상점 보기")') != 1:
    raise SystemExit("inactive cycle must expose exactly one required action")
if inactive.count("store.route = .commerce") != 1:
    raise SystemExit("inactive-cycle action must keep the existing commerce route")
for duplicate in ("MMR은 안전하게 보존됩니다", "패키지 결제가 승인되면", "사이클 시작 안내"):
    if duplicate in source:
        raise SystemExit(f"duplicate inactive-cycle explanation remains: {duplicate}")
PY

if grep -Eiq 'war of goat|war-of-masters|warOfGoatLink' "$rank" "$arena"; then
  echo "iPad 사용자 Arena 화면에 폐기된 이름이나 구형 웹 경로가 남아 있습니다." >&2
  exit 1
fi

if grep -Eq 'TWO AXES|SKILL MMR|ARENA POSITION|SERVER DEADLINES|SOLUTION EVIDENCE|SEALED MATCH REVIEW|GOAT ARENA ENTRY|SKILL CHECK' \
  "$arena" "$evidence" "$shop" "$placement"; then
  echo "iPad 사용자 Arena 화면에 뜻이 불분명한 장식용 영문 라벨이 남아 있습니다." >&2
  exit 1
fi

if grep -Fq 'Text(attempt?.phase == "verification" ? "SKILL CHECK" : "PLACEMENT")' "$placement"; then
  echo "배치고사 상단에 폐기한 영문 상태 라벨이 남아 있습니다." >&2
  exit 1
fi

# 서버 라우트 유무는 구현 상세다. 웹 브리지로 이어지는 Release 안내는 사용자가
# 실제로 할 동작과 로그인 유지 여부만 설명해야 한다.
if grep -Fq '앱 API에 없어' "$arena" \
  || grep -Fq '이 서버는 앱 안에서' "$arena" "$evidence" "$match_play" "$main_match"; then
  echo "GOAT Arena 사용자 문구에 내부 API/서버 구현 설명이 남아 있습니다." >&2
  exit 1
fi
grep -Fq '일부 기능은 앱 안의 웹 GOAT Arena 화면에서 이어집니다.' "$arena"
grep -Fq '현재 경기의 풀이 사진은 아래 버튼을 눌러 앱 안의 웹 경기 화면에서 제출해 주세요.' "$evidence"

echo "iPad GOAT Arena public route contract passed"
