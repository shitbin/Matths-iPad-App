# Pro 실제 비전→추론·재개 검증

## 현재 결론

**실제 native 모델 교체, 성공한 JSON 기록 뒤 중단, 프로세스 재실행 뒤 4개
체크포인트 재사용, 엔진 해제와 lease 반납은 확인했습니다. 그러나 합성 1문항의
판독·분석 품질은 통과하지 않았습니다.** 기존 일반 JSON 검사를 통과한 잘못된
단계 구조도 발견하여 보강했습니다. **v12b 재검증에서도 모델은 입력을 오인했지만,
잘못된 구조를 성공 단계로 저장하지 않고 50.65초에 안전하게 실패했습니다.**

현재 결과를 사진 분석 기능 전체, 실제 손글씨 정확도, 실기 성능 또는 상업 배포
승인으로 해석하면 안 됩니다. 20장 반복은 단일 입력의 품질/형식 계약이 안정됐다는
선행 조건을 충족하지 않아 시작하지 않았습니다.

## 환경·입력·안전 한도

- `kr.matths.app.uiqa`, signed Debug v11, iPad Pro 13-inch (M5) Simulator /
  iOS 26.3 runtime 그룹(앱의 UIDevice 실제 응답은 **26.3.1**). 실행 구현 `.debug.dylib` SHA:
  `03bfee8c8e838b375796e083cae36728b86dffe3236bf7a9bcda2a3f1f40d22d`.
- 기반 commit `64d9055`, dirty working tree. 전체 식별은 산출물의 binary manifest와
  provenance를 사용합니다. launcher stub만으로 소스를 식별하지 않았습니다.
- Mac 32GB 메모리 판정, CPU backend, 실제 context 16,384. 기존 저메모리용
  등록 pair를 명시적으로 선택했지만 **8GB 실기 정책/메모리를 모사한 시험은 아닙니다.**
- UIKit으로 만든 1024×800 합성 그림 한 장: `2x + 3 = 7`과 파란색 풀이 3줄.
  사람이 쓴 손글씨가 아니며 외부 입력/학생 데이터는 사용하지 않았습니다.
- 원본 SHA `d4929ee6a944475d6001a2be51049f9d2af9071bc4ff7ff85fd8c1983c6a9817`.
- native load→pipeline→cleanup에 실행당 720초, resident 8GiB 중단 한도,
  100ms 샘플링. SHA 사전 검증 시간은 native 예산 밖이지만 총 실행 시간에 포함됩니다.
  중단은 native callback의 협조적 취소이며 OS jetsam/실제 발열 실험이 아닙니다.
- `SheetGrader.run`, 공유 `AITutor` 엔진, `switchModel`, 실제 성공 JSON journal을
  사용했습니다. 대체 모델 응답을 주입하지 않았습니다. `ProScreen` UI·카메라·자동
  기기 티어 선택을 조작한 E2E는 아닙니다.

## v11 실제 실행

| 관측 | prepare: 실제 추론 후 중단 | verify: 프로세스 종료·재실행 |
|---|---:|---:|
| 전체 시간(SHA 포함) | 196.3초 | 542.5초 |
| 실제 비전 호출 | 3회 | 0회 |
| 비전 호출 시간 | 31.4 / 25.5 / 29.4초 | 이전 성공 기록 재사용 |
| 첫 정답 추론 | 78.6초 | 이전 성공 기록 재사용 |
| 비전→DeepSeek 전환 | 5.73초 | 5.73초 |
| 전환 후 projector/vision | 꺼짐 | 꺼짐 |
| 재사용 checkpoint | 0개 | 4개 |
| resident 관측 최대 | 6,181,027,840B (약 5.76GiB) | 5,448,466,432B (약 5.07GiB) |
| unload 후 resident | 313,589,760B | 282,378,240B |
| engine unloaded / lease returned | true / true | true / true |
| 시간·메모리 한도 발동 | false | false |
| 최종 사용자 결과 | 의도한 중단 | 1문항, `unknown` 보류 |

v11 JSON의 `PASS_PIPELINE_RESUME`는 당시 진단의 **재개 기계 검사**를 의미합니다.
같은 파일의 `syntheticSemanticCheck`는 **false**입니다. 따라서 이를 분석 품질 PASS로
세지 않습니다. 새 진단 V2는 runtime 결과와 semantic 결과를 분리하여 보류를
`SEMANTIC_REVIEW_REQUIRED`로 표시합니다.

## 실제로 발견한 결함

1. 3B 판독기는 파란 풀이를 선지로 오인했고, 재확인에서도 인쇄식 대신 풀이식을
   읽었습니다. 기존 숫자열 대조가 불일치를 감지하여 정오를 단정하지 않았습니다.
   이는 이 합성 입력의 실패이며 실제 손글씨 전체 정확도를 추정할 근거가 아닙니다.
2. DeepSeek 매칭 호출은 요구한 JSON 대신 해설·수식과 다른 언어가 섞인 문장을
   반환했습니다. 일반 교정 뒤 파서가 얻은 `{"1번":{}}`가 성공 checkpoint로 저장됐습니다.
   `assignments`와 `unassigned`가 없는 객체를 다음 단계로 보낸 **앱 검증 결함**입니다.

두 번째 결함을 좁게 수정했습니다:

- `SheetGraderStageSchema`: 8개 단계별 필수 키·자료형·배열/문자열 상한.
- 원래 출력, 교정 출력, 저장 직전, 기존 checkpoint 재사용 시 모두 현재 schema 확인.
- S4는 기존 `isProblemAnalysisObjectAcceptable` 판정 규칙을 재사용.
- 교정 프롬프트는 현재 단계 구조와 원래 값 보존을 요청합니다. 무관한
  `valid/reason` 재채점 객체를 만들거나 빠진 내용을 추측하게 하지 않습니다.
- 손상/잘못된 단계 checkpoint는 재사용하지 않습니다. 원본 사진은 보존하고,
  새 추론/교정도 형식을 지키지 못하면 명시적 실패/기존 보류 정책으로 끝냅니다.
- 모델 선택, 공식 점수·판정, 생성 토큰 상한을 바꾸지 않았습니다.

## v12b 같은 사진 재검증

새 signed binary의 실제 `.debug.dylib` SHA는
`3ea4730f979021810aa31697b31b3f7f10e6b349c04ff8546fb5e8303ef726ca`입니다.
원본 사진 SHA는 v11과 같습니다. source SHA는 v12b manifest에 별도 기록했습니다.

단계 schema 외에 S1에는 **명시된 보기 번호가 있는 항목만 선지로 읽고, 번호 없는
풀이 줄을 선지로 새로 만들지 않도록** 제약을 추가했습니다. 재확인에는 원래 발문의
조건식과 풀이의 계산/마지막 답을 구분하도록 명시했습니다. 합성 문제의 정답이나
특정 수치를 프롬프트에 주입하지 않았습니다.

이 두 프롬프트가 바뀌면 그 checkpoint hash가 달라지는 것이 정상입니다. 원래
`verify`의 사진 추론 0회/재사용 3개 이상 단언을 완화하지 않고, 변경된 단계는 실제
추론하고 유효한 나머지 기록은 재사용하는 별도 `revalidate` 모드로 실행했습니다.

결과:

- 실제 S1 비전 호출 31.37초, 같은 모델의 텍스트 형식 교정 8.56초.
- 모델은 다시 풀이를 선지로 오인했고, `choices`를 문자열 배열 대신
  `[{"text":"…"}]`로 반환했습니다. 교정도 동일한 잘못된 형식을 유지했습니다.
- 새 schema가 이를 거부했습니다. **새 checkpoint 저장 0개, 다음 단계 진행 0회.**
- 총 50.65초, 상태 `FAIL`. native crash나 시간/메모리 상한 발동은 아닙니다.
- resident 관측 최대 6,217,809,920B(약 5.79GiB), unload 후 405,618,688B.
- engine unloaded / lease returned 모두 true.

즉, 잘못된 단계 구조를 받아들이던 앱 검증 결함은 차단됐지만, **프롬프트 제약만으로
판독 품질이 해결되지는 않았습니다.** schema를 완화하거나 답을 주입해 통과로
만들지 않았습니다. DeepSeek은 기존 제품 샘플링(temperature 0.6)을 유지했으므로
한 번의 전후 출력으로 정확도 개선 통계를 주장하지 않습니다.

이 단계에서 20장 스트레스를 진행할 선행 조건은 충족되지 않았습니다. 라이선스와
모델 품질의 별도 방향 없이 같은 실패를 반복하지 않습니다. 현재 증거는 실제
모델 수명주기·중단/재개·실패 후 자원 반환과, 이 합성 입력의 미통과를 보여 줍니다.

실행한 검사:

```sh
sh tests/run-sheet-grader-stage-schema.sh
sh tests/run-sheet-grader-cancellation-contract.sh
sh tests/run-local-model-prompt.sh
sh tests/run-local-ai-analysis-journal.sh
```

새 schema 검사는 실제 v11 잘못된 객체가 기존 일반 검사에서는 통과하고 새 검사에서는
거부됨을 재현합니다. 8개 정상 typed/wire fixture, 필수 키 누락 19개, 다른 단계·자료형·
Boolean/정수 경계, 실제 9개 호출/복구·교정·저장 연결 검사가 통과했습니다.

## 모델 핀과 라이선스

GGUF는 저장소나 ZIP에 넣지 않았습니다. 공개 원본의 앱 registry SHA/크기,
Hugging Face LFS metadata, 다운로드 checksum, 별도 OpenSSL, 앱 내부 SHA가 일치합니다.

- Qwen2.5-VL3B Q4_K_M: 1,929,901,056B,
  `d02fe9b69ad8cadbbd228e387667af66612c44bed29ffc8eb1e7caf9ac486c12`.
- Q8 projector: 844,757,728B,
  `980c9b2f78c04e6cff93d277ada09e768394f112d75db3b4e9dea8a69f9fb904`.
- GGUF revision `5037fcf163dd95d1e41d1974465f0898ed108ca2`.
- DeepSeek7B는 앞서 검증한 pinned cache를 재사용했습니다.

변환 저장소는 Apache-2.0으로 표시하지만, 연결된 원본 3B 모델의 라이선스는
연구·평가 목적과 상업 사용을 구분하며 상업 사용에는 별도 허가를 요청하도록
명시합니다. 이번 실행은 격리 연구/평가 범위로 제한했고, **상업 배포 허용 여부는
제품 소유자의 별도 라이선스 증빙 확인 전까지 보류**했습니다. 법률 판단을 대신하지
않습니다. [원본 3B 라이선스](https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct/blob/37ce9f696340e294a5d3e0e806466addd1b22b3a/LICENSE),
[변환 저장소의 고정 카드](https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/blob/5037fcf163dd95d1e41d1974465f0898ed108ca2/README.md).

별도 읽기 전용 대조에서 기존 고메모리용 Qwen3.5-9B의 원본·변환 카드와 pinned SHA는
Apache-2.0/앱 값으로 일치했습니다. 하지만 6.6GB 본체+projector 조합을 8GB용 대체로
임의 적용하지 않았습니다. 이후 root가 **기존 고메모리 프로파일 자체의 추가 QA**를
승인하여 그 프로파일의 가중치만 별도 캐시에 준비했습니다(다음 절).
[Qwen3.5-9B 원본 라이선스](https://huggingface.co/Qwen/Qwen3.5-9B/blob/ef3d031a90d340a92d71f83ec17d054e100ce713/LICENSE).

## 기존 고메모리 9B 프로파일 추가 QA

상태: **v13c의 실제 native 실행·재개·해제 통과. 이 단순 문항의 최종 답은 맞지만,
추출·유형 분류의 품질 검수는 남습니다.**

- 프로덕션의 고메모리 `analysisVisionSpec`와 `analysisReasoningSpec`는 둘 다
  `Qwen3.5-9B-Q4_K_M.gguf`입니다. 텍스트 단계에서도 같은 본체와 projector가
  유지되므로 중간 모델 switch가 없는 것이 정상입니다.
- 본체 5,680,522,464B / `03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8`,
  revision `99a1b2185534379e6e8b5ec869da25d3e7b3f73c`.
- F16 projector 918,166,080B / `f70dc3509053962b0d0d3ee8a7eacebf5d60aa560cad78254ae8698516ae029f`,
  revision `f0a5ec311e0b365f00a15084f64a43bbd21af890`. 원격 `mmproj-F16.gguf`를
  앱 등록 이름 `mmproj-9B-F16.gguf`로 보관합니다.
- 앱 핀, 공개 LFS metadata, aria2 자체 checksum, 별도 OpenSSL SHA가 일치합니다.
- cache: `Library/Caches/MatthsRuntimeQA/Qwen3.5-9B-highmem-99a1b21-f0a5ec3/`.
  모델 파일은 repo/output ZIP에 넣지 않았습니다.
- QA 인자 `-proNativeRuntimeProfile high-memory-9b`는 사용자 설정이나 저메모리
  기본값을 변경하지 않습니다. 기존 hook에서 이 인자만 명시적으로 읽습니다.
- 같은 사진 SHA를 검증한 뒤 `ProNativeRuntimeQA/high-memory-9b`의 독립 journal에
  복사합니다. 더 쉬운 사진으로 바꾸지 않습니다.
- Mac RAM 32GiB 이상, resident 10GiB/100ms 관찰, native 720초/실행.
  시작 시 host free 40% 이상, 관찰 중 20% 미만이면 해당 UIQA 프로세스만 중단합니다.
  단일 prepare의 해제까지 확인한 뒤 verify 1회까지가 현재 계획입니다.
- 원본 Apache 라이선스 SHA `bbedc3fda3305820b977265f01b8619d87570a6739de3a5582c3464840f1e57a`,
  pinned quantization card SHA `7e03c5ffcdd5df41836ebe31bba8af8e8c5b0544c10a9fa7b13102b5493daa3f`.

3B 상업 허가와 이 9B 프로파일의 QA는 별개입니다. 9B의 실행 성공을 저메모리 기기의
안전성, 3B 상업 허가 또는 전체 앱 출시 승인으로 확장하지 않습니다.

실제 v13c `.debug.dylib` SHA는
`08ed6e082dbdf4a904517834938faa29b7bbf383172e7f83f3f82556e3c28fbe`입니다.

| 관측 | high-memory prepare | high-memory verify |
|---|---:|---:|
| 총 시간(SHA 포함) | 149.47초 | 63.90초 |
| native vision 호출 | 3회 | 0회 |
| native text 호출 | 1회 | 3회 |
| checkpoint 재사용 | 0개 | 4개 |
| 실제 모델 switch | 0회 | 0회 |
| resident 관측 최대 | 9,380,102,144B (약 8.74GiB) | 8,246,378,496B (약 7.68GiB) |
| 해제 후 resident | 329,990,144B | 415,154,176B |
| engine unloaded / lease returned | true / true | true / true |
| 한도 발동 | false | false |

prepare는 세 비전 단계와 실제 정답 추론의 schema-valid JSON을 저장한 뒤 중단했습니다.
verify는 이를 재사용하고 매칭·분석·종합을 각각 한 번의 native 호출로 완료했습니다.
두 단계 모두 `runtimeContractPassed=true`입니다.

최종 S4는 `status=correct`, `student="x = 2"`를 반환했습니다. 원본 식에 대입하면
실제로 맞는 답입니다. 다만 자동 진단은 공식 숫자 답 비교기에서 `"2"`와 `"x = 2"`를
비교하므로 `syntheticSemanticCheck=false`입니다. 원본 진단 결과
`SEMANTIC_REVIEW_REQUIRED`를 바꾸지 않았고, 이 형식 차이를 숨겨 전체 PASS로 만들지
않았습니다. 공식 MathAnswer 규칙도 변경하지 않았습니다.

별도로 실제 품질 문제도 남았습니다. S1은 존재하지 않는 선지 대신 `["unknown"]`을
남겼고, S2는 인쇄문 일부까지 전사했습니다. S4의 답과 판정은 맞지만 `선형방정식`에
`alg-quad-disc`(이차 판별식) 유형을 붙였습니다. 따라서 최종 답 하나가 맞았다는 사실을
추출·분류 전체의 정확도 합격으로 확대하지 않습니다.

### 정답까지 약점으로 추천하던 병합 보강

실제 S4 오분류를 조사하면서 `fromItems = items.compactMap(\.typeKey)`가 정답까지
약점으로 합치고 있음을 확인했습니다. 이 결과는 Pro의 약한 유형 모의고사로 이어집니다.
기존 `SheetAnalysisDemo.weakGeneratorTypes`와 설명 카드의 `hurt` 정책은 이미
계산 실수·개념 오류·전략 막힘만 고르고 있었으므로, 새 `SheetWeakTypePolicy`를 통해
실제 분석 병합도 같은 대상 범위로 맞췄습니다.

- correct, self-corrected, blank, unknown은 약점으로 단정하지 않습니다.
- 오류/막힘 상태라도 원발문, 확실한 판독, 의미 있는 stuckAt/errorWhy가 있어야 합니다.
- S5 요약은 근거 있는 문항 유형의 순서만 조정하며 새로운 약점을 만들지 못합니다.
- 관측된 선형 topic↔이차 판별식 key 모순은 추천에서 제외합니다. 임의 정답 유형을
  대입하지 않으며, 모든 17개 유형의 의미 검증이 완성됐다는 뜻도 아닙니다.
- 약한 유형이 없을 때 모두 해결한 경우와 판독/유형 불확실을 구분해 안내합니다.

`tests/run-sheet-weak-type-policy.sh`는 실제 정답/선형→이차 키 사례, 완료/미착수/보류
제외, 오류 근거, 불확실성, 요약의 근거 제한, 중복/순서, 실제 오류 후보 유지 검사를
통과했습니다. 이 병합 변경은 v13c 이후 소스이므로 v13c 결과에 소급하지 않습니다.
후속 signed 빌드에서 실제 파이프라인의 `weakTypeKeys`를 다시 기록할 수 있게 했습니다.

### v16: 최신 약점 병합으로 기존 7개 checkpoint 재사용

기존 high-memory 프로파일의 `verify`를 최신 signed v16 UIQA 앱에서 **한 번**
실행했습니다. 실제 설치 `.debug.dylib` SHA는
`e01b6c18b3a754e1668b85cb4511b15008d22b783853b49ab72fb0043dd473a6`이며,
위 `SheetWeakTypePolicy` 변경을 포함합니다. 빌드 라벨 v16과 앱 CFBundleVersion 17은
서로 다른 식별값입니다. launcher stub 해시만으로 최신 구현을 판정하지 않았습니다.

- 이전 v13c 보고서, source.jpg, job.json, 성공 checkpoint 7개를 실행 전에 별도 보관.
- 앱이 기존 본체·projector의 크기와 전체 SHA를 다시 확인했으며 다운로드는 하지 않음.
- 기존 checkpoint **7개 재사용**, 새 비전·텍스트 생성 호출 **0회**.
- 복원된 `correct` 1문항에 대해 최종 `weakTypeKeys=[]` 확인.
- `runtimeContractPassed=true`, `engineUnloaded=true`, `leaseReturned=true`.
- SHA 검증 포함 20.924초, resident 최대 7,933,018,112B, 해제 후 391,364,608B.
- 기존 10GiB/720초 중단 한도 유지, `budgetStopped=false`.
- host free는 설치 전 42%, 시작 직전 41%, 실행 중 관측 31%, 종료 후 52%.
- 원본 사진·job.json·checkpoint 7개의 실행 전후 SHA가 모두 동일.

이 결과는 **최신 앱의 checkpoint 복원→약점 병합→native 엔진 해제/실행권 반납**
확인입니다. 모델은 실제로 로드됐지만 이번에는 전부 재사용했으므로 새 생성·OCR·
분류 정확도 시험으로 세지 않습니다. 기존 `SEMANTIC_REVIEW_REQUIRED`와
`syntheticSemanticCheck=false`도 그대로 보관했습니다. 정답을 약점으로 추천하던
앱 병합은 수정됐지만 원본 S4의 선형→이차 유형 오분류 자체를 고쳤다는 뜻은 아닙니다.
입력은 여전히 동일한 인쇄체 합성 사진 한 장이며, 20장·실제 손글씨·실기/발열 시험은
진행하지 않았습니다.

이번 실행의 원본 보고서·로그·이전 상태 백업·binary/source manifest·build provenance:
`outputs/matths-remaining-0907/ai-qa/pro-native-highmem-v16.dCNwSu/`.
GGUF는 이 폴더나 공개 저장소/ZIP에 복사하지 않았습니다.

## 증거 위치

Workspace `outputs/matths-remaining-0907/ai-qa/`:

- `pro-native-v11-binary-manifest.json`, `pro-native-v11-build-provenance.plist`
- `pro-native-research-model-manifest.json`
- `pro-native-prepare-v11.json`, `pro-native-prepare-v11.log`
- `pro-native-verify-v11.json`, `pro-native-verify-v11.log`
- `pro-native-verify-v11-grader-log.json`: 합성 입력의 실제 native 출력만 포함
- `pro-native-synthetic-fixture.jpg`
- `pro-native-v12b-binary-manifest.json`, `pro-native-v12b-build-provenance.plist`
- `pro-native-revalidate-v12b.json`, `pro-native-revalidate-v12b.log`
- `pro-native-revalidate-v12b-grader-log.json`: 실패한 S1/교정 실제 출력
- `pro-native-highmem-model-manifest.json`
- `pro-native-highmem-v13c-binary-manifest.json`, `pro-native-highmem-v13c-build-provenance.plist`
- `pro-native-highmem-prepare-v13c.json`, `.log`, `-grader-log.json`
- `pro-native-highmem-verify-v13c.json`, `.log`, `-grader-log.json`

다음 실행은 새 signed 빌드의 별도 `.debug.dylib` SHA로 기록해야 합니다. v11의
결과에 그 뒤 추가한 schema 수정을 소급하여 포함시키지 않습니다.
