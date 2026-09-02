#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
api="$root/Matths/AdminCommunityAPI.swift"
screen="$root/Matths/AdminCommunityScreen.swift"
demo="$root/Matths/DemoMode.swift"
for file in "$api" "$screen" "$root/Matths/DemoAdminCommunityFixtures.swift"; do test -f "$file" || exit 1; done
for path in '/api/v1/admin/community' '/notices' '/reports/' '/posts/' '/comments/' '/warn' '/status' '/pin'; do
  rg -q -F "$path" "$api" || { echo "missing community API $path" >&2; exit 1; }
done
for behavior in 'ADMIN_COMMUNITY_NATIVE_V1' 'case reports = "신고"' 'case posts = "게시글"' 'case comments = "댓글"' 'case notices = "공지"' 'confirmationDialog("최종 처리할까요?"' 'DB에서 게시글 삭제' '숨김 + 작성자 경고'; do
  rg -q -F "$behavior" "$api" "$screen" || { echo "missing community behavior $behavior" >&2; exit 1; }
done
rg -q -F 'DemoAdminCommunityFixtures.dashboard' "$demo"
if rg -q 'WKWebView|SFSafariViewController|SafariView' "$screen"; then echo "admin community must stay native" >&2; exit 1; fi
echo "native admin community contract passed"
