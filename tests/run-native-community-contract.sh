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
grep -Fq 'name=\"communityFiles\"' "$root/Matths/CommunityMultipartBody.swift"
grep -Fq 'upload(for: request, fromFile: prepared.fileURL)' "$api"
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
# The behavior is image decoding/re-encoding, not the old full-resolution UIImage
# constructor. The shared ImageIO implementation is exercised with EXIF fixtures
# in run-native-service-recovery.sh.
grep -Fq 'NativeServicePhotoPreparation.prepareJPEG(source)' "$screen"
grep -Fq 'CGImageSourceCreateThumbnailAtIndex' "$root/Matths/NativeServicePhotoPreparation.swift"
grep -Fq 'CGImageDestinationFinalize' "$root/Matths/NativeServicePhotoPreparation.swift"
grep -Fq 'frame(maxWidth: 820)' "$screen"
grep -Fq 'operationsCategories' "$screen"
grep -Fq 'popularStrip' "$screen"
grep -Fq 'switch store.schoolGrade' "$screen"
grep -Fq 'category: category' "$screen"
grep -Fq '.toolbar(verticalSizeClass == .compact ? .hidden : .visible' "$screen"
grep -Fq 'private var compactHeader' "$screen"
grep -Fq '.padding(.top, 44)' "$screen"
grep -Fq 'popularScroller(compact: true)' "$screen"

# 앱의 자체 상단바 아래에서 시스템 toolbar가 사라져도 글쓰기 행동이 남아야 한다.
# compact/regular 헤더가 같은 네이티브 버튼을 공유하고, 실제 탭·자동화가 식별할 수 있다.
grep -Fq 'composeButton(compact: true)' "$screen"
grep -Fq 'composeButton(compact: false)' "$screen"
grep -Fq 'accessibilityIdentifier("community-compose-button")' "$screen"
grep -Fq '.toolbar(verticalSizeClass == .compact ? .hidden : .visible' "$screen"
grep -Fq 'private var narrowRegularHeader' "$screen"
grep -Fq 'private var wideRegularHeader' "$screen"
grep -Fq 'horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize' "$screen"
grep -Fq 'boardMenu.fixedSize(horizontal: true, vertical: false)' "$screen"
grep -Fq 'sortPicker.frame(maxWidth: .infinity)' "$screen"

# 등록 성공은 상세 시트를 덧띄우지 않고 작성한 게시판의 최신 목록으로 돌아온다.
grep -Fq 'NativeCommunityComposerSheet(initialBoard: board) { _, createdBoard in' "$screen"
grep -Fq 'board = createdBoard' "$screen"
grep -Fq 'sort = "latest"' "$screen"
grep -Fq 'await load(reset: true)' "$screen"
grep -Fq 'accessibilityIdentifier("community-post-created-banner")' "$screen"
grep -Fq 'let submittedBoard = board' "$screen"
grep -Fq 'createCommunityPost(board: submittedBoard' "$screen"
grep -Fq 'AcknowledgedSubmission(post: post, board: submittedBoard' "$screen"
grep -Fq 'onCreated(acknowledged.post, acknowledged.board)' "$screen"
if sed -n '/NativeCommunityComposerSheet(initialBoard: board)/,/^            }/p' "$screen" | grep -Fq 'selectedPost = post'; then
  echo '게시글 등록 뒤 상세 시트를 자동으로 다시 열면 목록 복귀 계약을 어깁니다.' >&2
  exit 1
fi

# 작성 권한과 폼의 핵심 행동은 눈에 보이는 설명과 안정적인 식별자를 가진다.
grep -Fq '오늘 작성 한도를 모두 사용했습니다.' "$screen"
for identifier in community-compose-board community-compose-title community-compose-content community-compose-submit; do
  grep -Fq "accessibilityIdentifier(\"$identifier\")" "$screen"
done
grep -Fq '.safeAreaInset(edge: .bottom, spacing: 0)' "$screen"
grep -Fq 'private var submitButton' "$screen"

# 데모에서도 JSON과 multipart/다운로드 전송계층을 모두 실제로 돈다.
grep -Fq 'DemoCommunityFixtures.page' "$demo"
grep -Fq '["api", "v1", "community", "posts"]' "$demo"
grep -Fq '"attachments", "{attachmentId}"' "$demo"
grep -Fq 'COMMUNITY_NATIVE_V1' "$fixtures"

echo 'Native community read, write, moderation, attachment, demo, and account-scope contracts passed.'
