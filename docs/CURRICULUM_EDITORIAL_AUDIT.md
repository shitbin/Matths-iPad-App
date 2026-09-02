# 13과목·220개념 편집 품질 감사

데이터 정본: `Matths/curriculum-v2.json` (SHA-256 `e598f2503e21236eb48b65c796a18bd47bf9bd98e4f50dcca9f1d66e16a263ae`)

판정: **통과** · 오류 0건 · 맥락 확인 16건

## 전체 집계

- 과목 13개
- 단원 46개
- 개념 220개
- 강의 본문 220개
- 총 권장 학습 시간 3105분
- 검사 범위: ID·순서·필수 본문·성취기준·주제 중복·예상 시간·선수 과목 DAG·학습 트랙·임시 문구·본문 완전 중복

## 과목별 집계

| 과목 | 단원 | 개념 | 권장 시간 | 선수 과목 |
|---|---:|---:|---:|---|
| 공통수학1 | 4 | 19 | 260분 | 없음 |
| 공통수학2 | 3 | 20 | 256분 | 없음 |
| 대수 | 3 | 18 | 221분 | 공통수학1 · 공통수학2 |
| 미적분Ⅰ | 3 | 20 | 396분 | 공통수학1 · 공통수학2 |
| 확률과 통계 | 3 | 16 | 258분 | 공통수학1 · 공통수학2 |
| 미적분Ⅱ | 3 | 23 | 324분 | 대수 · 미적분Ⅰ |
| 기하 | 3 | 14 | 200분 | 공통수학1 · 공통수학2 |
| 경제 수학 | 4 | 18 | 248분 | 공통수학1 · 공통수학2 |
| 인공지능 수학 | 5 | 15 | 201분 | 공통수학1 · 공통수학2 |
| 직무 수학 | 4 | 18 | 205분 | 없음 |
| 실용 통계 | 4 | 13 | 162분 | 공통수학1 · 공통수학2 |
| 수학과 문화 | 4 | 16 | 254분 | 없음 |
| 수학과제 탐구 | 3 | 10 | 120분 | 없음 |

## 맥락 확인 항목

자동 실패로 단정할 수 없는 선택 필드와 교과 간 반복 제목도 숨기지 않고 확인 대상으로 남긴다.

| 개념명 | 위치 | 판정 근거 |
|---|---|---|
| 범위 메모 없음 | common-math-1/equations-and-inequalities/quadratic-equation-and-function | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-1/equations-and-inequalities/parabola-and-line | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-1/equations-and-inequalities/simultaneous-linear-inequalities | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-1/equations-and-inequalities/absolute-linear-inequalities | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-1/equations-and-inequalities/quadratic-inequalities | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-1/matrices/matrix-concept | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/coordinate-geometry/parallel-and-perpendicular-lines | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/coordinate-geometry/point-line-distance | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/coordinate-geometry/circle-equation | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/coordinate-geometry/circle-line-position | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/coordinate-geometry/geometric-reflection | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/functions-and-graphs/composite-function | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 범위 메모 없음 | common-math-2/functions-and-graphs/inverse-function | 성취기준과 학습 주제는 존재하며 별도 범위 제한이 없는 항목 |
| 미분과 방정식·부등식 | 미적분Ⅰ / 미분<br>미적분Ⅱ / 미분법 | 과목명이 함께 표시되는 교과 간 심화 반복 |
| 정적분과 넓이 | 미적분Ⅰ / 적분<br>미적분Ⅱ / 적분법 | 과목명이 함께 표시되는 교과 간 심화 반복 |
| 적분과 속도·거리 | 미적분Ⅰ / 적분<br>미적분Ⅱ / 적분법 | 과목명이 함께 표시되는 교과 간 심화 반복 |

## 오류

없음

## 별도 검증 경계

이 보고서는 데이터 편집 계약을 검사한다. 실제 수학적 참·거짓, 학생 난이도, 화면에서의 긴 제목 줄바꿈은 자동 통과로 간주하지 않는다. 연습 출제 경로는 `run-curriculum-practice-coverage.sh`, 실제 폭·접근성은 iPad 실기 캡처로 별도 검증한다.

