# 로컬 AI 정확도 평가

이 폴더는 실제 학생 풀이를 사람이 먼저 라벨한 뒤, Matths 로컬 비전 모델·부정행위 보조 판정·채점기·튜터의 결과를 같은 기준으로 비교하기 위한 도구다.

`fixtures/demo-labeled.jsonl`은 계산식 검증용 가상 데이터다. 제품 정확도 증거로 쓰면 안 된다.

## 개인정보 규칙

1. 학생 이름, 학교, 계정 ID, 촬영 위치와 EXIF를 제거한다.
2. `sampleId`는 무작위 내부 ID만 쓴다.
3. 원본 사진은 별도의 암호화된 검수 폴더에 두고 JSONL에는 상대 참조만 기록한다.
4. 한 명이 만든 라벨은 다른 한 명이 재검토한다. 의견이 갈리면 `inconclusive`로 둔다.
5. 부정행위 결과는 자동 제재나 환불·랭크 정산에 직접 연결하지 않는다.

## JSONL 계약

한 줄에 JSON 객체 하나를 적는다. `kind`는 아래 셋 중 하나다. 실제 파일럿 표본은 모든 줄에
원본 바이트의 `sourceSha256`과 독립된 두 검토자의 가명 식별자·합의 여부를 넣어야 한다.
불일치는 `adjudication`에 최종 검토 기록을 남긴다. 이름·이메일 같은 개인정보는 검토자
식별자로 쓰지 않는다.

```json
{"sampleId":"H-001","sourceSha256":"64자리 sha256","review":{"primaryLabeler":"reviewer-a","secondaryLabeler":"reviewer-b","agreed":false,"adjudication":"third-review-2026-08"}}
```

### 손글씨 판독

```json
{"kind":"handwriting","sampleId":"H-001","imageRef":"images/H-001.jpg","expected":{"problems":[{"problemId":"1","finalAnswer":"12","acceptedAnswers":["12.0"],"requiredSteps":["미분","임계점 비교"]}]},"observed":{"unreadable":false,"problems":[{"problemId":"1","finalAnswer":"12","recognizedSteps":["미분","임계점 비교"]}]}}
```

문항 매칭 재현율, 최종 답 정확도, 필수 풀이 단계 포착률, 판독 불가율을 계산한다. 표현이 여러 개인 답은 `acceptedAnswers`에 명시한다.

### 부정행위 보조 판정

```json
{"kind":"cheating","sampleId":"C-001","expected":{"verdict":"normal"},"observed":{"verdict":"inconclusive"}}
```

`normal`, `suspicious`, `inconclusive`만 허용한다. 의심 precision/recall/F1, 정상 풀이 오탐률, 보류율과 혼동행렬을 계산한다.

### 채점·튜터

```json
{"kind":"grading-tutor","sampleId":"G-001","expected":{"verdict":"incorrect","finalAnswer":"3","acceptedAnswers":[],"requiredConcepts":["인수분해"],"forbiddenClaims":["실근이 없다"]},"observed":{"verdict":"incorrect","finalAnswer":"3","mentionedConcepts":["인수분해"],"tutorAnswer":"인수분해 뒤 두 근을 확인하세요.","unsafeClaim":false}}
```

정오 판정, 최종 답, 필수 개념 포함률, 금지된 허위 주장과 위험 답변을 계산한다. `forbiddenClaims`는 해당 문항에서 나오면 안 되는 구체적 주장만 적는다.

## 실행

```sh
node tests/evaluation/evaluate-local-ai.mjs labels.jsonl \
  --json reports/local-ai-eval.json \
  --markdown reports/local-ai-eval.md
```

실측 보고서에는 기기 모델, iPadOS, 모델 파일 SHA-256, 양자화, 표본 수와 구성을 함께 적어야
한다. `datasetSourceSha256`은 평가기가 출력한 `dataset.sourceSha256`과 같아야 한다. 이중 라벨
일치율은 메타데이터의 자기보고값이 아니라 각 표본의 `review`에서 다시 계산된다. 중복 ID,
원본 해시 누락, 독립 검토 누락, 미조정 불일치, `fixtures/` 또는 `DEMO-*` 표본은 모두 게이트를
실패시킨다. 표본 수가 0인 항목은 `해당 없음`이며 통과로 해석하지 않는다.

## 내부 파일럿 통과 게이트

계산된 수치가 있다는 사실과 서비스에 써도 된다는 판정은 다르다. 익명 실측 보고서와 이중
라벨 메타데이터가 준비되면 아래 게이트를 통과해야 한다.

```sh
node tests/evaluation/gate-local-ai.mjs reports/local-ai-eval.json reports/metadata.json \
  --dataset labels.jsonl \
  --output reports/pilot-gate.json
```

현재 `production-thresholds.json`은 내부 파일럿 최소선이다. 손글씨 100장, 부정행위 200건,
채점·튜터 100건과 이중 라벨 일치율 90% 이상을 요구한다. 정상 풀이를 부정행위로 보는 비율은
2% 이하, 허위·위험 주장은 0건이어야 한다. 임계값을 낮추려면 파일 변경과 별도 검토 기록이
필요하며, 데모 fixture는 표본 수와 정확도 모두 부족해 반드시 실패한다.
