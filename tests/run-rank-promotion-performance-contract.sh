#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Matths/RankBadge.swift"
APP_SOURCE="$ROOT/Matths/MatthsApp.swift"
VIDEO_SOURCE="$ROOT/Matths/RankPromotionVideo.swift"

grep -Fq 'import ImageIO' "$SOURCE"
grep -Fq 'RankBadgeAssets.prewarmPromotion(tier: requestedTier)' "$SOURCE"
grep -Fq 'RankTier.allCases.enumerated()' "$SOURCE"
grep -Fq 'prewarmPromotionVisuals(tier: tier)' "$SOURCE"
grep -Fq 'PromotionVisualReadiness: @unchecked Sendable' "$SOURCE"
grep -Fq 'promotionVisualReadiness.contains(tier) && preparedPlayers[tier] != nil' "$SOURCE"
grep -Fq 'if RankBadgeAssets.isPromotionPrepared(tier: requestedTier)' "$SOURCE"
grep -Fq 'if isPresented {' "$SOURCE"
grep -Fq '투명한 전체 화면 GeometryReader 자체를 만들지 않는다' "$SOURCE"
if grep -Fq '.accessibilityHidden(!isPresented)' "$SOURCE"; then
  echo "숨은 승급 전체 화면이 일반 화면 접근성을 가로막습니다" >&2
  exit 1
fi
grep -Fq 'guard isPresented else { return }' "$SOURCE"
grep -Fq 'RankPromotionVideoPlayer(' "$SOURCE"
# 2026-08-16: 'Button("건너뛰기")' 리터럴 고정을 그만둔다. 단언의 목적은
# "건너뛰기 버튼이 있는가" 인데, 생성 형태를 고정하면 구현을 고칠 때마다 깨진다.
# 실제로 그 형태는 결함이었다 — 꾸밈이 Button 바깥에 붙어 캡슐은 44pt 로 보이는데
# 눌리는 곳은 글자 높이(약 18pt) 뿐이라, 보이는 대로 눌러도 안 눌렸다.
# 라벨 안으로 옮기고 contentShape 으로 캡슐 전체를 받게 고쳤다.
# 그래서 단언을 약화하지 않고 반대로 강화한다 — 버튼 존재에 더해
# 터치 영역이 실제로 확보돼 있는지까지 못박는다.
grep -Fq 'Text("건너뛰기")' "$SOURCE"
grep -Fq '.accessibilityLabel("승급 모션 건너뛰기")' "$SOURCE"
grep -Fq '.contentShape(Capsule())' "$SOURCE"
grep -Fq '.frame(minHeight: 44)' "$SOURCE"
grep -Fq 'if useVideo { return }' "$SOURCE"
grep -Fq 'playerLayer.videoGravity = .resizeAspect' "$VIDEO_SOURCE"
grep -Fq 'player.isMuted = !motionActive' "$VIDEO_SOURCE"
grep -Fq 'CMTime(seconds: 5.7' "$VIDEO_SOURCE"
grep -Fq '.AVPlayerItemDidPlayToEndTime' "$VIDEO_SOURCE"
grep -Fq '.id("rank-pipeline-prewarm-\(tier.rawValue)")' "$SOURCE"
grep -Fq '.allowsHitTesting(false)' "$SOURCE"
grep -Fq '.accessibilityHidden(true)' "$SOURCE"
grep -Fq 'audioPlaybackSuppressed' "$SOURCE"
grep -Fq 'rank-promotion-pipeline-prewarm.json' "$SOURCE"
grep -Fq 'kCGImageSourceShouldCacheImmediately: true' "$SOURCE"
grep -Fq 'kCGImageSourceThumbnailMaxPixelSize: 1152' "$SOURCE"
grep -Fq '.disabled(!assetsReady)' "$SOURCE"
grep -Fq '.onAppear { prepareTierAndPlay() }' "$SOURCE"
grep -Fq 'tierCode: store.rankPromotionPresentation?.tierCode' "$APP_SOURCE"
grep -Fq 'store.rankPromotionPresentation != nil' "$APP_SOURCE"
grep -Fq '.accessibilityAddTraits(.isModal)' "$SOURCE"
if grep -Fq 'if let presentation = store.rankPromotionPresentation' "$APP_SOURCE"; then
  echo "승급 overlay host가 presentation마다 다시 mount됩니다" >&2
  exit 1
fi

if grep -Fq 'UIImage(contentsOfFile: url.path)' "$SOURCE"; then
  echo "승급 PNG가 첫 프레임에서 지연 디코딩될 수 있습니다" >&2
  exit 1
fi

while read -r expected_hash filename; do
  asset="$ROOT/Matths/RankMotion/$filename"
  test -f "$asset"
  test "$(stat -f %z "$asset")" -gt 900000
  test "$(shasum -a 256 "$asset" | awk '{print $1}')" = "$expected_hash"
done <<'HASHES'
d8910111e26328371b7831c8ce99d70b4091f8d2c2e22e27fccb2dfffdd01a16 bronze-rank-up.v6.mp4
7d25c368ef24294a76caf1bbd5f3f31f519e550e549287c0339ac0583fcdd05e silver-rank-up.v6.mp4
cff67370d3340a6e48328ee6809ac904c1590016ea3d46f436eb46f923926554 gold-rank-up.v6.mp4
99495b7718dc04d6d3c038b4fda2b9e7eb06c39f4a4c33736d8064018acba1c8 platinum-rank-up.v7.mp4
c3216627ca194c21f5f8cb4b54b6e26827a9a7832ed1b11ec660371b503d994a emerald-rank-up.v6.mp4
9ae55c28a784d504ac9382326576e45f8e12aea0f997557e6dee5d76a7bbe55b diamond-rank-up.v6.mp4
a6c2973ed94f207f6304988b97ff72f2c71a77749c117fe64c0923846b3ae059 master-rank-up.v6.mp4
5863f3bb4c783fea7b21a206dbda36acfa3e672095ebfb19c38dfdc6ca6aca3e grandmaster-rank-up.v6.mp4
71d6c90fda117caab4b67bff8e5b339c1b0d3dace8bb6f9fa2ae14c4cea8cd71 challenger-rank-up.v12.mp4
HASHES

echo "승급 모션 자산 사전 디코딩 계약 통과"
