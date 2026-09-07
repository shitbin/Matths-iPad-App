# 실제 등록 GGUF의 native simulator smoke — 2026-09-07

**한 가지 승인된 텍스트 모델로 실제 생성·취소·재생성·엔진 해제와 lease 반납을 확인했습니다.** 실기, Metal/발열, 최저 지원 기기, 사진 판독, 학생 답변의 정확도 검증은 아닙니다. 입력은 합성 짧은 산술/숫자 세기 프롬프트뿐이며 학생 이미지나 대화를 사용하지 않았습니다.

## 모델과 출처

- 기존 production 기본 텍스트 전용 사양: `DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf`.
- 3,808,390,880 bytes, SHA-256 `0931f946c6f439a3b5cc0226f39dce14c092c2ee4386be98f12ca6305cef7ec7`.
- 고정 revision `a5f384a99071aea7fbd64b1f4b162bd9318a9862`: [등록된 공개 GGUF 파일](https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/blob/a5f384a/DeepSeek-R1-Distill-Qwen-7B-Q3_K_M.gguf).
- 코드의 기존 SHA/크기, 게시자 API LFS metadata, HTTP linked SHA/size, 다운로드 자체 checksum, 별도 OpenSSL SHA 및 **앱 안에서 다시 계산한 SHA**가 일치합니다.
- [DeepSeek upstream MIT](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-7B/blob/008b8c2/LICENSE)와 [게시자 model card의 MIT/원본 Qwen Apache-2.0 설명](https://huggingface.co/unsloth/DeepSeek-R1-Distill-Qwen-7B-GGUF/blob/main/README.md)을 기록했습니다. gated/유료 로그인이 필요하지 않았습니다.
- 현행 텍스트 전용 옵션 중 DeepSeek 3.808GB가 Qwen 텍스트 전용 4.016GB보다 작습니다. 3.19GB Qwen legacy 멀티모달 사양이나 미등록 작은 모델을 새로 선택하지 않았습니다.
- 저장소 밖 cache: `/Users/soobin/Library/Caches/MatthsRuntimeQA/DeepSeek-R1-7B-a5f384a/`. GGUF는 repo/output ZIP에 넣지 않았습니다.

## 실제 실행 조건

- `kr.matths.app.uiqa`, iPhone 17 / iOS 26.3 Simulator, 32GB Mac.
- Shared `AITutor`의 실제 `LlamaEngine` 하나와 `LocalAIWorkCoordinator` lease를 사용했습니다. 엔진 복제·운영 모델 선택 변경·임의 projector 사용은 없습니다.
- Product simulator settings, 실제 context 16,384, vision=false. 로그에서 CPU mapped weights와 CPU compute buffer 318MiB를 확인했습니다.
- 각 생성은 maxTokens=48입니다. 아래 callback 수는 완성된 UTF-8 조각 수이며 **정확한 tokenizer token 수나 정확도 점수가 아닙니다.**
- 앱 프로세스 resident를 100ms마다 샘플링하고 8GiB/90초 안전 한도를 두었습니다. 한도는 발동하지 않았습니다.

## 결과

| 항목 | 관측값 |
|---|---:|
| 실제 모델 load | 18,430ms |
| 첫 짧은 생성 | 47 UTF-8 callbacks / 157 bytes / 22,089ms |
| 첫 완성 UTF-8 조각까지 | 14,923ms |
| 취소 | 4번째 조각에서 shouldCancel=true, CancellationError 확인 |
| 취소 신호부터 반환 | 180.7ms |
| 취소 뒤 새 생성 | 37 callbacks / 105 bytes / 19,060ms |
| engine unloaded | true |
| lease returned | true |
| run 직전 process resident | 2,195,488,768 bytes |
| sampled process resident peak | 4,597,907,456 bytes (약 4.28GiB) |
| unload 직후 process resident | 217,546,752 bytes |

이 시간/메모리는 개발 Mac의 simulator 프로세스 관측입니다. 통제된 성능 baseline이나 실기 성능 예측으로 쓰지 않습니다. run 직전 값은 파일 검증을 거친 뒤의 값이지 cold-launch idle 기준선이 아닙니다. GPU peak·thermal 측정도 아닙니다.

## 증거와 코드 식별

Workspace `outputs/matths-remaining-0907/ai-qa/`:

- `native-llm-runtime-qa.json`: 앱이 기록한 결과.
- `native-llama-runtime.log`: 합성 실행의 native log.
- `native-llm-binary-manifest.json`, `native-llm-build-provenance.plist`.
- `approved-model-cache-manifest.json`: 공개 원본·라이선스·cache·checksum 기록.

실제 구현 `Matths.debug.dylib` SHA-256은 `b7d7dffb799a2ce53392974495b6152e67a649ed69ffe0ea4fca6a44299d202e`입니다. launcher stub만으로 최신 코드를 식별하지 않았습니다. 이 v8 바이너리에서 PASS를 확인했으며, 이후 source 변경이 자동으로 이 결과에 포함된다고 주장하지 않습니다.
