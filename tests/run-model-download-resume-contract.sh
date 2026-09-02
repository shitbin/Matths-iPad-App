#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
broker="$ROOT/Matths/ResumableModelDownload.swift"
pack="$ROOT/Matths/LocalAIModelPack.swift"
legacy="$ROOT/Matths/LocalLLM.swift"
app="$ROOT/Matths/MatthsApp.swift"
selftest="$ROOT/Matths/ModelDownloadSelfTest.swift"
tutor="$ROOT/Matths/AITutor.swift"
chat="$ROOT/Matths/ChatScreen.swift"

grep -Fq 'URLSessionConfiguration.background(withIdentifier:' "$broker"
grep -Fq 'sessionSendsLaunchEvents = true' "$broker"
grep -Fq 'downloadTask(withResumeData:' "$broker"
grep -Fq 'NSURLSessionDownloadTaskResumeData' "$broker"
grep -Fq 'getAllTasks' "$broker"
grep -Fq 'didFinishDownloadingTo location:' "$broker"
grep -Fq 'installValidatedGGUF' "$pack"
grep -Fq 'expectedSHA256' "$pack"
grep -Fq 'verifyExistingArtifact' "$pack"
grep -Fq 'integrityReceiptMatches' "$pack"
grep -Fq 'writeIntegrityReceipt' "$pack"
grep -Fq 'await LocalAIModelPack.verifyExistingArtifact(spec.file)' "$legacy"
grep -Fq 'return 5_680_522_464' "$pack"
grep -Fq 'return 3_190_613_216' "$pack"
grep -Fq 'return 918_166_080' "$pack"
grep -Fq '0931f946c6f439a3b5cc0226f39dce14c092c2ee4386be98f12ca6305cef7ec7' "$pack"
grep -Fq '03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8' "$pack"
grep -Fq '570ce2bbc92545cffbcb01df43cba59d86093dadc34c25da9f554d256bc70b91' "$pack"
grep -Fq 'f70dc3509053962b0d0d3ee8a7eacebf5d60aa560cad78254ae8698516ae029f' "$pack"
grep -Fq '/resolve/99a1b21/Qwen3.5-9B-Q4_K_M.gguf' "$legacy"
grep -Fq '/resolve/f584643/Qwen3.5-9B-UD-IQ2_XXS.gguf' "$legacy"
grep -Fq '/resolve/a5f384a/DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf' "$legacy"
grep -Fq 'mmprojURL: nil' "$legacy"
if grep -Fq 'DeepSeek-R1-Distill-Qwen-7B-GGUF")!' "$legacy"; then
  echo "텍스트 전용 DeepSeek 모델에 가짜 사진 모듈 URL이 남아 있습니다" >&2
  exit 1
fi
grep -Fq '/resolve/5037fcf/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf' "$legacy"
if grep -Eq 'Qwen3\.5-9B-GGUF/resolve/main|Qwen2\.5-VL-3B-Instruct-GGUF/resolve/main' "$legacy"; then
  echo "운영 로컬 AI 모델 URL이 변경 가능한 main revision을 사용합니다" >&2
  exit 1
fi
python3 - "$legacy" <<'PY'
from pathlib import Path
import sys

lines = Path(sys.argv[1]).read_text().splitlines()
debug_depth = 0
for number, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith("#if DEBUG"):
        debug_depth += 1
    elif stripped.startswith("#endif") and debug_depth:
        debug_depth -= 1
    elif "/resolve/main/" in line and debug_depth == 0:
        raise SystemExit(
            f"운영 로컬 AI 모델 URL이 변경 가능한 main revision을 사용합니다: {number}"
        )
PY
grep -Fq 'else if modelFile.contains("4B") { base = "mmproj-4B-F16.gguf" }' "$legacy"
grep -Fq 'volumeAvailableCapacityForImportantUsageKey' "$pack"
grep -Fq 'ResumableModelDownload.shared.download' "$pack"
grep -Fq 'ResumableModelDownload.shared.download' "$legacy"
grep -Fq 'handleEventsForBackgroundURLSession identifier:' "$app"
grep -Fq 'ModelDownloadSelfTest.runIfRequested()' "$app"
grep -Fq 'MATTHS_MODEL_DOWNLOAD_DEVICE_QA_V1' "$selftest"
grep -Fq 'installValidatedGGUF' "$selftest"
grep -Fq 'requireStorage(' "$selftest"
grep -Fq 'destinationPreservedAfterFailures' "$selftest"
grep -Fq 'cancelForSelfTest' "$broker"
grep -Fq 'resumeDataPersisted' "$selftest"
grep -Fq 'resumedFromPersistedData' "$selftest"
grep -Fq 'resumedDownloadCompleted' "$selftest"
grep -Fq 'static func userFacingDownloadFailure(_ error: Error)' "$legacy"
grep -Fq 'self.state = .failed(Self.userFacingDownloadFailure(error))' "$legacy"
grep -Fq 'state = .failed(ModelDownloader.userFacingDownloadFailure(error))' "$pack"
if grep -Fq 'state = .failed(error.localizedDescription)' "$legacy" ||
   grep -Fq 'state = .failed(error.localizedDescription)' "$pack"; then
  echo "모델 다운로드 오류 원문이 학생 화면 상태에 남아 있습니다" >&2
  exit 1
fi
grep -Fq 'Text(modelFailureCopy(why))' "$chat"
grep -Fq 'AI 모델을 열지 못했습니다. 앱을 다시 시작하거나 모델을 다시 받아 주세요.' "$tutor"
if grep -Fq 'modelState = .failed("\(loadError)")' "$tutor" ||
   grep -Fq 'modelState = .failed("\(error)")' "$tutor"; then
  echo "모델 로드 오류 원문이 AI 튜터 화면 상태에 남아 있습니다" >&2
  exit 1
fi
grep -Fq 'var generationFailed = false' "$tutor"
grep -Fq 'let finalGenerationFailed = generationFailed' "$tutor"
if grep -Fq 'generationError = error.localizedDescription' "$tutor" ||
   grep -Fq 'generationError = e.errorDescription' "$tutor" ||
   grep -Fq 'generationError = "\(error)"' "$tutor"; then
  echo "튜터 생성 오류 원문이 답변 상태에 남아 있습니다" >&2
  exit 1
fi

# 주소 검증·기존 파일 검사·저장 공간 확인을 포함한 준비 단계의 모든 실패는
# UI를 checking에 남겨 두지 않고 failed로 전환해야 다시 시도할 수 있다.
PACK_SOURCE="$(sed -n '/private func performPreparation()/,/^    }/p' "$pack")"
if ! grep -Fq 'state = .checking' <<<"$PACK_SOURCE" ||
   ! grep -Fq 'do {' <<<"$PACK_SOURCE" ||
   ! grep -Fq 'try Self.requireStorage' <<<"$PACK_SOURCE" ||
   ! grep -Fq 'state = .failed(ModelDownloader.userFacingDownloadFailure(error))' <<<"$PACK_SOURCE"; then
  echo "모델팩 준비 실패가 checking 상태를 빠져나오는 계약이 깨졌습니다" >&2
  exit 1
fi

if grep -Fq 'URLSession.shared.download(from: artifact.url)' "$pack"; then
  echo "모델팩이 재개 불가능한 shared download 경로를 사용합니다" >&2
  exit 1
fi

echo "모델 다운로드 재개·검증 계약 통과"
