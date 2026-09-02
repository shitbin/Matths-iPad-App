#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
screen="$root/Matths/NativeCommunityScreen.swift"
api="$root/Matths/NativeCommunityAPI.swift"
root_view="$root/Matths/RootView.swift"
demo="$root/Matths/DemoMode.swift"
fixtures="$root/Matths/DemoCommunityFixtures.swift"

# 게시판 탭은 WKWebView가 아니라 네이티브 목록을 직접 소유한다.
test "$(grep -Fc 'NativeCommunityScreen()' "$root_view")" -ge 2
if grep -Eq '(^|[^[:alnum:]_])CommunityScreen\(\)' "$root_view"; then
  echo 'RootView 게시판에 레거시 웹뷰가 남아 있습니다.' >&2
  exit 1
fi

# 공개 읽기 + 로그인 후 작성/댓글/추천/신고/차단/삭제 전체 API.
for route in \
  '/api/v1/community"' \
  '/api/v1/community/posts/\(post.id)' \
  '/api/v1/community/notices/\(post.id)' \
  '/api/v1/community/announcements/\(post.id)' \
  '/api/v1/community/posting-access' \
  '/api/v1/community/posts/\(postId)/comments' \
  '/api/v1/community/posts/\(postId)/vote' \
  '/api/v1/community/posts/\(postId)/report' \
  '/api/v1/community/posts/\(postId)/block' \
  '/api/v1/community/blocked-users'; do
  grep -Fq "$route" "$api"
done
grep -Fq 'multipart/form-data; boundary=' "$api"
grep -Fq 'name=\"communityFiles\"' "$api"
grep -Fq 'COMMUNITY_NATIVE_V1' "$api"

# 화면 기능과 앱 가로모드/계정 전환 안전장치.
grep -Fq 'PhotosPicker' "$screen"
grep -Fq '.fileImporter' "$screen"
grep -Fq 'CommunityFilePreview' "$screen"
grep -Fq 'voteCommunityPost' "$screen"
grep -Fq 'reportCommunityPost' "$screen"
grep -Fq 'blockCommunityAuthor' "$screen"
grep -Fq 'deleteCommunityPost' "$screen"
grep -Fq 'communityBlockedUsers' "$screen"
grep -Fq 'DataScope.didSwitchNotification' "$screen"
grep -Fq 'UIImage(data: source)' "$screen"
grep -Fq 'frame(maxWidth: 820)' "$screen"
grep -Fq 'operationsCategories' "$screen"
grep -Fq 'popularStrip' "$screen"
grep -Fq 'switch store.schoolGrade' "$screen"
grep -Fq 'category: category' "$screen"
grep -Fq '.toolbar(verticalSizeClass == .compact ? .hidden : .visible' "$screen"
grep -Fq 'private var compactHeader' "$screen"
grep -Fq '.padding(.top, 44)' "$screen"
grep -Fq 'popularScroller(compact: true)' "$screen"

# 데모에서도 JSON과 multipart/다운로드 전송계층을 모두 실제로 돈다.
grep -Fq 'DemoCommunityFixtures.page' "$demo"
grep -Fq '["api", "v1", "community", "posts"]' "$demo"
grep -Fq '"attachments", "{attachmentId}"' "$demo"
grep -Fq 'COMMUNITY_NATIVE_V1' "$fixtures"

echo 'Native community read, write, moderation, attachment, demo, and account-scope contracts passed.'
