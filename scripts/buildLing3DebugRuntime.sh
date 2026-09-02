#!/bin/zsh
set -euo pipefail

RUNTIME_COMMIT="db4480bc802dda303627830833e0e6c2a7c47297"
OUTPUT="${1:-/private/tmp/matths-ling3-llama-${RUNTIME_COMMIT[1,7]}.xcframework}"

if [[ -e "$OUTPUT" ]]; then
  print -u2 "출력 경로가 이미 있습니다. 기존 프레임워크를 덮어쓰지 않습니다: $OUTPUT"
  exit 2
fi
if ! command -v cmake >/dev/null 2>&1; then
  print -u2 "cmake가 필요합니다. 신뢰하는 패키지 관리자로 먼저 설치하세요."
  exit 2
fi

WORK="$(mktemp -d /private/tmp/matths-ling3-runtime.XXXXXX)"
git clone --filter=blob:none https://github.com/ggml-org/llama.cpp.git "$WORK/llama.cpp"
git -C "$WORK/llama.cpp" fetch origin "$RUNTIME_COMMIT"
git -C "$WORK/llama.cpp" checkout --detach "$RUNTIME_COMMIT"
[[ "$(git -C "$WORK/llama.cpp" rev-parse HEAD)" == "$RUNTIME_COMMIT" ]]

(
  cd "$WORK/llama.cpp"
  ./build-xcframework.sh
)

FRAMEWORK="$WORK/llama.cpp/build-apple/llama.xcframework"
BIN="$FRAMEWORK/ios-arm64/llama.framework/llama"
strings "$BIN" | grep -Fq "bailingmoe3"
strings "$BIN" | grep -Fq "db4480b"
mv "$FRAMEWORK" "$OUTPUT"

print "Ling DEBUG llama XCFramework 생성 완료:"
print "$OUTPUT"
print "검증: iOS arm64 · bailingmoe3 · runtime $RUNTIME_COMMIT"
print "기존 Frameworks/llama.xcframework는 별도 보존한 뒤 수동 교체하세요."
