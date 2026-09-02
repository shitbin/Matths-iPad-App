# Ling 3.0 tiny — Matths iPad 적용성 검토

검토일: 2026-08-15
현재 판정: **DEBUG 텍스트 추론 후보. 실험 런타임·모델 선택 UI 구현, Release 노출 금지.**

## 결론

Ling 3.0 tiny는 Matths의 사진 판독 모델을 대체할 수 없다. 공개 체크포인트는
`BailingMoeV3ForCausalLM` 텍스트 모델이고 비전 프로젝터가 없다. 대신 현재의
`Qwen2.5-VL 3B 판독 → DeepSeek-R1 7B 추론` 파이프라인에서 두 번째 텍스트 추론
단계를 대체할 후보로는 가치가 높다.

공식 llama.cpp release에는 아직 bailingmoe3가 없다. 이번 DEBUG 빌드는 upstream
PR #26608의 정확한 head `db4480bc802dda303627830833e0e6c2a7c47297`에서
XCFramework를 직접 빌드했다. iOS arm64 바이너리에서 `bailingmoe3`를 확인했지만
PR은 2026-08-15 현재도 미병합이므로 이 런타임을 정식 배포 근거로 쓰지 않는다.

따라서 이번 반영 범위는 다음과 같다.

1. 후보와 가중치 SHA를 고정한다.
2. DEBUG + 검토한 runtime commit + architecture + 기기 RAM + 파일 무결성이 모두
   맞을 때만 벤치마크를 허용한다.
3. DEBUG의 프로필·채점 Pro에서만 Q3_K_M을 선택하고, 사진 판독은 Qwen VL 3B로 고정한다.
4. Release 선택은 계속 막고 M2 8 GB 실기에서 Q3_K_M 로드·추론을 검증한다.

코드 장벽은 `Matths/ExperimentalLocalModelCatalog.swift`, 회귀 검사는
`tests/run-ling3-candidate-contract.sh`에 있다.

## 공식 소스와 라이선스 핀

| 항목 | 확인값 |
|---|---|
| 공식 BF16 저장소 | `inclusionAI/Ling-3.0-tiny` |
| revision | `a2ee06c0f2de5b171701aee7f73f70a1da75483b` |
| 공개/게이트 | public, non-gated |
| HF license 선언 | SPDX `MIT` |
| 아키텍처 | `BailingMoeV3ForCausalLM`, `model_type=bailing_hybrid` |
| 파라미터 | 총 7.9B, 토큰당 활성 1.3B |
| MoE | routed expert 128개, top-8 + shared expert 1개 |
| attention | 24층, KDA 3 : MLA 1 교대 |
| 공식 INT4 저장소 | `inclusionAI/Ling-3.0-tiny-int4` |
| INT4 revision | `d355645f42fa7c08980889e288ed6957bacedde6` |
| INT4 형식 | compressed-tensors safetensors, group size 32 |
| INT4 LFS 총량 | 5,817,910,956 bytes = 약 5.42 GiB |

공식 HF 저장소는 README front matter와 API tag에서 MIT를 선언하고 공개·비게이트다.
상업적 사용·수정·재배포가 가능한 방향이 맞다. 다만 해당 revision의 파일 목록에는
독립 `LICENSE`/`NOTICE`가 없다. 정식 앱에서 가중치를 내려받거나 재배포하기 전에는
MIT 본문과 저작권 고지를 앱 고지에 포함하고 최종 라이선스 검토를 닫아야 한다.

공식 근거:

- 모델 카드: <https://huggingface.co/inclusionAI/Ling-3.0-tiny/blob/a2ee06c0f2de5b171701aee7f73f70a1da75483b/README.md>
- 모델 config: <https://huggingface.co/inclusionAI/Ling-3.0-tiny/blob/a2ee06c0f2de5b171701aee7f73f70a1da75483b/config.json>
- 공식 INT4: <https://huggingface.co/inclusionAI/Ling-3.0-tiny-int4/tree/d355645f42fa7c08980889e288ed6957bacedde6>

## 런타임 호환성

| 경로 | 2026-08-12 상태 | iPad 앱 적용 판단 |
|---|---|---|
| 공식 llama.cpp release | `bailingmoe3` 미포함 | 정식 배포에 사용 불가 |
| llama.cpp PR #26608 | head `db4480bc802dda303627830833e0e6c2a7c47297`, open | DEBUG XCFramework 실험만 가능 |
| 공식 INT4 safetensors | llama.cpp GGUF가 아님 | 현재 bridge로 로드 불가 |
| Ollama PR #17643 MLX | open, 공식 release 아님, macOS용 실험 경로 | iOS 앱 runtime으로 사용 불가 |
| upstream MLX Swift LM | `bailing_moe`는 있으나 `bailing_hybrid`/KDA 경로 없음 | 바로 사용 불가 |

PR head의 공식 Apple 빌드 스크립트로 iOS arm64·simulator를 포함한 XCFramework를
만들고 앱 Debug simulator 링크까지 확인했다. 그러나 PR 자체가 merge 전이므로
공식 release가 나오면 새 commit으로 API·Metal·mtmd 회귀를 다시 확인해야 한다.

- 현재 llama.cpp release: <https://github.com/ggml-org/llama.cpp/releases/tag/b10159>
- BailingMoE3 PR: <https://github.com/ggml-org/llama.cpp/pull/26608>
- Ollama MLX PR: <https://github.com/ollama/ollama/pull/17643>
- MLX Swift LM: <https://github.com/ml-explore/mlx-swift-lm>

## 메모리와 속도 — Mac 수치와 iPad 추정을 분리

| 후보 | 파일/공개 peak | M2 iPad 8 GB 판단 |
|---|---:|---|
| 공식 BF16 | 약 14.71 GiB weights | 불가 |
| 공식 FP8 | 약 7.83 GiB weights, 공식 카드의 M4 Pro 8K peak 약 8.34 GiB | 불가 |
| 공식 INT4 | 약 5.42 GiB weights, Ollama PR의 M4 Pro peak 약 6.1 GiB | jetsam 위험이 너무 큼 |
| community GGUF Q4_K_M | 4.49 GiB | 실험 전에는 8 GB 기기에서 차단 |
| community GGUF Q3_K_M | 3.58 GiB | 가장 현실적인 첫 실기 후보 |
| community GGUF IQ2_M | 2.52 GiB | 메모리는 유리하나 수학 품질 손실 검증 전 채택 금지 |

M4 Pro 48 GB에서 보고된 FP8 86–90 tok/s와 Ollama PR의 INT4 약 115 tok/s는
Mac 수치다. iPad 속도로 환산하면 안 된다. M2 iPad에서는 Metal backend, 낮은 메모리
대역폭, iPadOS jetsam, 앱 자체 메모리까지 함께 작동한다.

현재 앱의 실기 기록상 4.0 GB급 Qwen3.5 9B 3-bit 텍스트 모델은 약 69초에 동작한
적이 있지만 종료 가능성이 있고, 5.7 GB급 9B Q4는 로드 중 종료됐다. Ling은 활성
파라미터가 1.3B라 decode 계산량은 줄 가능성이 크지만 모든 expert weight는 여전히
저장·매핑해야 한다. 그래서 **Q3_K_M은 가능성이 있는 실험 후보이지, 원활한 동작이
확정된 모델이 아니다.**

## 실기 승격 기준

Q3_K_M을 기본 DeepSeek 경로와 같은 데이터로 비교한다.

1. cold load 20회와 연속 30문제에서 jetsam/abort 0회.
2. 모델 SHA, runtime commit, peak resident, minimum available memory, first-token,
   tokens/s, 전체 처리시간을 모두 기록.
3. 손글씨 판독은 동일 Qwen2.5-VL 출력으로 고정하고 텍스트 추론 모델만 바꾼 A/B.
4. 한국 고교 수학 채점·튜터 정확도가 기존 DeepSeek 7B보다 낮아지지 않을 것.
5. 정상 풀이 부정행위 오탐률과 의심 풀이 재현율이 기존 pilot gate를 통과할 것.
6. 발열 상태 15분 연속 실행과 백그라운드 복귀에서 작업 복구가 유지될 것.
7. 위 조건을 Q4_K_M에서도 확인하되 16 GB iPad 전용 결과와 섞지 않을 것.

이 기준을 통과하기 전에는 Ling을 DEBUG 밖이나 Release 빌드에 노출하지 않는다.
