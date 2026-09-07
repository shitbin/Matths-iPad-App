# 로컬 AI 수명주기·복구 보강 — 2026-09-07

이 문서는 AI-001/ARC-004 중 이번에 수정한 범위와 실제 증거를 구분합니다. **실제 GGUF 추론 품질, 최소 지원 기기 메모리/발열, 20장 사진 분석, 실제 다운로드 네트워크 장애 전수검사가 끝났다는 문서가 아닙니다.** 모델 파일을 새로 다운로드하거나 개인 시험지·사진을 외부로 보내지 않았습니다.

## 확인된 결함과 수정

| 문제 | 수정 | 확인 범위 |
|---|---|---|
| 튜터와 분석 모델팩이 같은 다운로드 continuation을 덮어씀 | broker가 구독자별 continuation을 보관하고 task 생성도 한 번만 수행 | Swift 단일 실행 경계 테스트, 실제 broker 디바이스 재개 검사는 별도 |
| 네트워크 작업만 공유하면 두 소비자가 같은 완료 파일을 각각 이동·설치 | 검증→다운로드→SHA→원자 설치 전체를 `LocalAIArtifactFlight` 하나로 묶음 | 동일 키 20개 요청에서 작업 시작 1회, 공유 실패·재시도·취소·재진입 |
| 취소된 화면이 수 GB 준비 작업의 완료를 계속 기다림 | 화면의 waiter는 즉시 취소하고 이미 요청한 공용 다운로드는 다른 소비자/백그라운드 복구를 위해 한 번만 지속 | 취소 후 다시 붙어도 설치 작업 수가 늘지 않는 단위 테스트 |
| SHA+바이트 수 영수증이 같은 크기 파일 교체/수정을 구분하지 못함 | 영수증 v2가 inode·생성/수정 시각·바이트 수에 결합, 예전 영수증은 백그라운드 재해시 | 동일 크기 원자 교체/수정, 해시 도중 교체, 예전 영수증, 심볼릭 링크 거부 |
| 잘린 HTTP 응답·206 suffix를 완료 파일로 간주할 여지 | 200 Content-Length, 206 Content-Range 전체 길이와 suffix 길이를 구분하여 확인 | 1–99% 잘린 파일 거부, 206 조립 결과·미조립 suffix·잘못된 범위/상태 코드 검사 |
| 오래된 task callback 및 progress가 최신 완료 상태를 덮을 수 있음 | 정확한 URLSession task ID와 다운로드 attempt ID 확인, retired task 무시, 완료 파일 경로를 전용 폴더로 제한 | 코드 계약 및 컴파일; 실제 중복 background callback 주입은 별도 |
| 비전 projector 뒤 context 생성 실패에서 projector 해제 누락 | mtmd→모델→backend 순으로 해제, 처리된 실패의 crash 표식 해제 | 코드 경로 확인; 실제 malloc/Metal 실패 주입은 별도 |
| 취소를 첫 출력 토큰에서만 관찰 | 작업 소유자의 `shouldCancel`을 native abort callback과 prefill/decode 경계에 연결 | 튜터·Pro·무결성 검토 호출 계약, 실제 native 취소 지연은 측정 필요 |
| decode 실패/취소 뒤 KV prefix 장부가 이전 성공 값을 유지 | 비정상 종료 시 KV 및 `lastTokens`를 함께 초기화 | 코드 경로 확인, 실제 GGUF 후속 대화 검사는 별도 |
| UI에서 엔진 속성을 읽을 때 native queue에 막히거나 pointer를 경합해서 읽음 | native pointer 대신 NSLock으로 보호한 짧은 값 snapshot 읽기 | 컴파일·호출 구조 확인; UI hitch 측정은 별도 |
| BG 만료·메모리 경고·높은 발열에도 다음 무거운 단계 시작 | 작업별 중단 callback, native 본체/projector 로더의 progress 중단, thermal/BG admission 검사, 활성 lease 반납 뒤 최우선 자원 회수 | DEBUG 합성 자원 중단 자가진단 제공, 실제 시스템 압박/발열은 별도 |
| 재실행 복구가 항상 처음부터 재추론 | 원본 SHA·모델·프롬프트·출력 정책·이미지 crop에 묶인 성공 JSON checkpoint | 20단계마다 새 journal 인스턴스 재시작, 1개 손상 시 나머지 19개 유지 |
| checkpoint가 이전 계정·다른 사진/모델을 재사용하거나 늦은 결과가 삭제 자료 복원 가능 | 계정 폴더 분리, 원본 identity 확인, 명시 삭제 뒤 쓰기 거부, 128개×128KB 상한 | 계정/원본/모델/프롬프트/crop 변경과 늦은 쓰기 테스트 |
| 실제 분석 순서와 화면 단계 순서 불일치, 시작 전 모든 단계가 완료 표시 | 인쇄 판독→전사→정답 추론 순서를 맞추고 미시작은 빈 원 표시 | 코드 계약; Pro 시뮬레이터 화면 확인은 통합 QA에 포함 |
| 채팅 body/복구 화면이 큰 UIImage를 동기 디코드 | 파일 기반 ImageIO 축소 미리보기를 background에서 생성, 원본 파일은 변경하지 않음 | 코드·컴파일; 최소 기기 20장 메모리 곡선은 별도 |
| 사진 공급자 진단 로그에 사진 ID/내부 경로가 Release에서도 저장 | 원문 로그는 DEBUG 한정, 128KB 상한·파일 보호·백업 제외 | 컴파일 분기/코드 확인 |

## 의도적으로 유지한 기존 안전장치

- 단일 엔진 lease와 우선순위 큐는 전면 재작성하지 않았습니다. 취소/grant 경합의 lease 반환과, 압박 시 다음 무거운 작업보다 자원 회수를 우선하는 경계를 보강했습니다.
- 기기별 검증된 모델 크기·CPU/Metal 배치·컨텍스트 한도는 근거 없이 늘리지 않았습니다.
- 공식 GGUF URL의 pinned revision 및 SHA-256, GGUF magic, 원자 파일 교체를 유지했습니다.
- 사진 분석/무결성 검토는 공식 점수·Arena 제재·정산을 자동 변경하지 않습니다.
- checkpoint는 검증을 통과한 JSON 객체만 기록합니다. 부분 토큰·raw draft·native KV cache는 복구 자료로 저장하지 않습니다. 읽은 JSON에도 현재 출력 정책을 다시 적용합니다.
- 24시간짜리 원본 보존 정책을 유지하고, 정해진 `source.jpg` 외 메타데이터 경로·심볼릭 링크·빈/50MB 초과 파일을 복원하지 않습니다.

## 실행한 집중 검사

다음은 실제 실행한 검사입니다. 원격 모델 자체나 운영 계정 데이터를 사용한 E2E 검사가 아닙니다.

```sh
sh tests/run-local-ai-artifact-safety.sh
sh tests/run-local-ai-analysis-journal.sh
sh tests/run-local-ai-work-coordinator.sh
sh tests/run-local-ai-job-recovery.sh
sh tests/run-model-download-resume-contract.sh
sh tests/run-local-model-prompt.sh
sh tests/run-local-ai-evaluation.sh
sh tests/run-debug-model-selector-contract.sh
sh tests/run-local-ai-pilot-gate.sh
sh tests/run-solution-analysis-floating-contract.sh
```

- Artifact/journal는 실제 제품의 Foundation 코드로 컴파일·실행합니다.
- Coordinator는 20개 요청·10개 취소, grant/취소 경합 100회를 추가했습니다.
- 라벨 평가 및 pilot gate는 평가 도구의 계약 검사입니다. 모델 정확도 증거가 아닙니다.
- HTTP 1% 검사는 검증기에 넣는 길이/범위 fixture입니다. 실제 네트워크를 1%마다 끊은 시험이 아닙니다.

통합 2차 실행에서 single-flight fixture가 한 번 실패해 분리 재현했습니다. 실제 값은 중복 2회가 아닌 `starts=0`이었으며, waiter 20개 등록 완료와 operation Task 시작이 별도 actor 사건인 점을 fixture가 누락한 문제였습니다. 시작 사건을 기다린 뒤 기존 `starts == 1` 단언을 그대로 적용하도록 수정했습니다. 수정 후 100회 반복 PASS, 별도 임시 복사본의 `starts += 2` 음성대조는 `starts=2`로 FAIL했습니다. 제품 single-flight 구현을 바꾸거나 단언을 완화하지 않았습니다.

## 통합 앱에서 실행할 수 있는 진단

- `-modelDownloadSelfTest`: 256KB급 GGUF 모양 fixture로 실제 설치·SHA·교체·디스크 부족 경계를 확인하고 `Documents/model-download-device-qa.json`을 생성합니다.
- `-localAIResourceSelfTest`: 20개 가짜 작업에 메모리/발열/만료 중단을 주입하고 활성 lease를 반납하기 전 unload가 대기하는지 확인합니다. `Documents/local-ai-resource-qa.json`에 합성 주입임을 명시합니다. 실제 압박/온도 측정은 아닙니다.
- 기존 `-localAIRecoverySelfTest prepare`/`verify`는 별도 앱 실행 사이 원본 복구를 확인합니다.
- 모델 load/unload, text/vision inference, 첫 토큰에 `local-ai` OS signpost가 추가됐습니다. load/unload의 resident MB는 샘플값이며 peak 측정이 아닙니다. 프롬프트·사진·계정 ID는 signpost에 포함하지 않습니다.

## 남은 실측

실제 다운로드 중 kill(1/25/50/99%), HTTP Range 미지원/ETag 교체·망 전환, actual GGUF hash, 비전→텍스트 교체의 Metal 해제/메모리 peak, 실제 첫 토큰 전 취소 응답 시간, 최소 지원 기기·최신 기기의 열/에너지·20장 분석 후 회수는 아직 합격 근거가 없습니다. 정적/합성 검사 결과를 대신 제시하지 않습니다.

## 통합 시뮬레이터 실행 증거

2026-09-07 09:27–09:28 KST, iPhone 17 / iOS 26.3 시뮬레이터에서 검증 전용 `kr.matths.app.uiqa`를 실행했습니다. 실제 설치 앱 `kr.matths.app`은 실행·변경하지 않았습니다.

- `model-download-device-qa.json`: PASS. 원자 교체, v2 receipt, 손상 header, 잘못된 SHA 거부, 실패 시 기존 destination 보존, 공간 부족 경계 모두 true. Resume URL은 주지 않았으므로 **실제 URLSession 재개는 이 결과에 포함되지 않습니다.**
- `local-ai-resource-qa.json`: PASS. memoryPressure/thermalPressure/backgroundExpired 합성 주입 각각 20개 callback, 활성 lease 반납 후 unload, 작업 정리 확인. 실제 압박/발열 측정 및 모델 추론 실행은 false로 기록했습니다.
- `local-ai-recovery-device-qa.json`: PASS. prepare 뒤 앱 프로세스를 종료·재실행해 원본 SHA `ec587510610bb144b56d0f2980f9499fb2b53efe094d1c2b3f207aefd790048a`와 마지막 단계를 복원하고 복구 fixture를 정리했습니다.
- 원본 결과 복사 위치: workspace `outputs/matths-remaining-0907/ai-qa/`.

## 후속 실제 GGUF 실행

이 문서의 초기 미검증 범위 중 **등록된 DeepSeek-R1-Distill-Qwen-7B-Q3_K_M 한 모델의 실제 텍스트 생성·취소·재생성·엔진 해제**는 이후 iPhone 17 시뮬레이터에서 확인했습니다. 3.8GB 공개 pinned artifact를 코드/게시자/다운로드/앱 내부 SHA로 교차 확인했고 합성 프롬프트만 사용했습니다. 상세 수치·코드 hash·한계는 `NATIVE_LLM_SIMULATOR_SMOKE_0907.md`를 참조합니다. 이 결과는 다른 모델, vision→text 교체, 20장 실제 시험지, 물리 기기·thermal·모델 정확도 검증을 대체하지 않습니다.
