#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d /tmp/matths-model-migration.XXXXXX)
node - "$root" "$scratch" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict');
const [root,out]=process.argv.slice(2);
const engine=fs.readFileSync(root+'/Matths/LocalLLM.swift','utf8');
const pack=fs.readFileSync(root+'/Matths/LocalAIModelPack.swift','utf8');
const tutor=fs.readFileSync(root+'/Matths/AITutor.swift','utf8');
assert(!engine.includes('https://huggingface.co/ggml-org/Qwen2.5-VL-3B'));
assert(!engine.includes('specVision3B'));
assert(engine.includes('hasLargeMemory ? spec9B : specVision2B'));
assert(engine.includes('case "vision2B", "vision3B": return specVision2B'));
assert(engine.includes('f6d5376be1edb4d416d56da11e5397a961aca8ae/Qwen3.5-2B-Q4_K_M.gguf'));
assert(engine.includes('mmproj-Qwen3.5-2B-F16.gguf'));
assert(tutor.includes('!ModelDownloader.isRetiredModel($0.lastPathComponent)'));
assert(engine.includes('guard !ModelDownloader.isRetiredModel((modelPath as NSString).lastPathComponent)'));
assert(pack.includes('1_280_835_840') && pack.includes('668_227_264'));
assert(pack.includes('aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223'));
assert(pack.includes('7035e9cb8d7c6a9681d07eef9a364783e86ea4cd73faab2eabb4f43a101830c7'));
assert(fs.readFileSync(root+'/Matths/Qwen3.5-2B-LICENSE.txt','utf8').includes('Apache License'));
const match=engine.match(/nonisolated static func isRetiredModel\(_ file: String\) -> Bool \{[\s\S]*?\n    \}/);
assert(match);
fs.writeFileSync(out+'/main.swift','import Foundation\nenum Policy {\n'+match[0]+`\n}
precondition(Policy.isRetiredModel("Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf"))
precondition(Policy.isRetiredModel("QWEN2.5-VL-3B-INSTRUCT.gguf"))
precondition(!Policy.isRetiredModel("Qwen3.5-2B-Q4_K_M.gguf"))
precondition(!Policy.isRetiredModel("DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf"))
print("PASS Apache reader replacement: exact artifacts, runtime selection, legacy exclusion without file deletion")
`);
JS
swiftc "$scratch/main.swift" -o "$scratch/cases"
"$scratch/cases"
