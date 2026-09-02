#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
app=${1:-}
if [ -z "$app" ]; then
  echo '커리큘럼 번들 검증 실패: .app 경로가 필요합니다.' >&2
  exit 2
fi

node_bin=${NODE_BINARY:-}
if [ -z "$node_bin" ] || [ ! -x "$node_bin" ]; then
  node_bin=$(command -v node 2>/dev/null || true)
fi
if [ -z "$node_bin" ] || [ ! -x "$node_bin" ]; then
  for candidate in /opt/homebrew/bin/node /usr/local/bin/node; do
    if [ -x "$candidate" ]; then
      node_bin=$candidate
      break
    fi
  done
fi
if [ -z "$node_bin" ] || [ ! -x "$node_bin" ]; then
  echo '커리큘럼 번들 검증 실패: Release 검증에 Node.js가 필요합니다.' >&2
  exit 3
fi

exec "$node_bin" "$script_dir/verifyCurriculumStoryBundle.js" "$app"
