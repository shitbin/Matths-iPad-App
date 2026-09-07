# 일반 풀이 작업대의 로컬 입력 복원

## 범위

`PracticeWorkspaceDraft*`는 같은 문제를 다시 열었을 때 답 입력·선택한 보기·PencilKit 필기·확대 배율을 복원합니다. 문제/시험 전체를 자동 재개하거나 공식 점수·합격·해금·서버 진도를 변경하지 않습니다. 공식 평가의 `paper-scratchpad-*` 저장소도 사용하지 않습니다.

## 연결 계약

- namespace / DataScope.managedFiles: `practice-workspace-drafts-v1`.
- fingerprint: `PracticeWorkspaceDraft.questionFingerprint(id:typeKey:statement:choices:revisionHint:)`. 문제 ID가 같아도 발문·보기·정답/시각화 revision이 달라지면 다른 기록입니다. revisionHint에는 정답/시각화의 변경 식별자를 넣을 수 있으나 원본 정답은 draft에 저장하지 않습니다.
- View는 `PracticeWorkspaceDraftModel`의 `answer`, `pickedKey`, `drawing`, `zoom`에 바인딩합니다.
- `.task(id: slot + fingerprint)`에서 `open(fingerprint:allowedChoiceKeys:store:)`를 호출합니다.
- `isLoading || !isWritable`이면 입력을 잠그고 `error` 및 재시도/안전 초기화/나가기 경로를 제공합니다.
- 기존 examIndex 변경 handler가 답/필기를 별도로 지우면 안 됩니다. `open`이 이전 snapshot 보존과 새 문제 복원을 소유합니다.
- View 이탈 전 `flush()` 결과를 확인합니다. 시스템 background/계정 전환은 `PracticeWorkspaceDraftRepository.flush(slot:)`를 기존 내구 저장 장벽에 포함합니다.
- 계정 삭제 전 `invalidate(slot:)`를 await합니다. 정상적인 새 계정 세션 활성화 시 `activate(slot:)`로 새로운 epoch를 발급합니다. 옛 handle은 활성화 이후에도 무효입니다.

## 저장과 실패

UI 변경 callback은 값 snapshot만 저장합니다. `PKDrawing.dataRepresentation`, SHA, JSON 인코딩, 파일 교체는 debounce/flush의 직렬 writer에서 수행합니다. lifecycle flush는 아직 actor에 도착하지 않은 변경도 높은 revision으로 확정하며, 저장 중 새 입력이 생기면 마지막 입력까지 반복 확인합니다.

한 draft는 원본 drawing 4MiB, 인코딩 파일 6MiB, 답 UTF-8 8,192바이트 이내입니다. zoom은 유한한 0.25–8 값입니다. PencilKit 복원은 파일 길이/SHA 검증 후 백그라운드에서 수행하고 10,000 stroke·200,000 point·유한 좌표/100,000pt 경계를 추가 확인합니다. 한도를 넘으면 화면 입력을 지우지 않으며 자동으로 예전 저장본을 덮지 않습니다.

읽기 권한 실패를 ‘파일 없음’으로 취급하지 않습니다. 손상/다른 fingerprint/잘못된 보기/깨진 PKDrawing이면 원본을 보존하고 쓰기를 막습니다. 사용자가 **원본 보관 후 새로 쓰기**를 선택하면 `resetPreservingOriginal()`이 다음 순서를 같은 직렬 writer에서 수행합니다.

1. 기존 지연 쓰기 취소·drain.
2. `preserved-originals/`에 복사.
3. 원본·복사본 SHA와 원본 identity 검증.
4. 검증 성공 후에만 새 빈 draft를 원자 저장.

복사·해시·저장 실패 시 원본은 그대로 남습니다. 계정 invalidate가 중간에 끼어도 writer drain 뒤에만 삭제가 진행되므로 지워진 계정 폴더를 늦은 callback이 되살리지 않습니다. 원본 백업은 같은 계정 namespace 안에 있고 계정 삭제 시 함께 정리됩니다.

## 검증

`tests/run-practice-workspace-draft.sh`는 실제 임시 디렉터리를 사용한 순수 Swift 테스트입니다. 답/보기/bytes/zoom 왕복, 20개 최신 변경 flush, 계정/문제 구분, 손상 JSON/SHA/크기/zoom 거절, 삭제 뒤 늦은 쓰기 차단, 새 epoch 활성화, 원본 보존 초기화와 백업 실패를 검증합니다. 이 검사에서 drawing bytes는 불투명 fixture이며 실제 PencilKit 디코드 검사가 아닙니다.

DEBUG `PracticeWorkspaceDraftSelfTest.runIfRequested(store:)`는 앱 안의 실제 모델/PencilKit을 사용합니다. `-demo -preserveDemoState -practiceWorkspaceDraftSelfTest prepare` 실행 후 앱을 종료하고 `verify`로 재실행하면 실제 합성 PKStroke·답·보기·zoom 복원 및 손상 PKDrawing 보존/백업 초기화를 검사합니다. 결과는 `Documents/practice-workspace-device-qa.json`입니다. **합성 stroke는 사용자의 실제 Pencil/손가락 입력 성공 증거가 아닙니다.** 실기 사용은 현재 사용자 요청에 따라 수행하지 않습니다.

2026-09-07 10:05–10:06 KST에 iPhone 17 / iOS 26.3 시뮬레이터의 격리된 `kr.matths.app.uiqa`로 이 절차를 실행해 PASS를 확인했습니다. 구현 코드 `Matths.debug.dylib`의 SHA-256은 `e73a916b198245cef072758f0460a85e006feac24a4515cd89fb9e4ee3896c82`입니다. `Matths` 파일은 Debug launcher stub이므로 그것의 해시만 구현 증거로 사용하지 않습니다. 결과·구현 해시·빌드 provenance는 workspace `outputs/matths-remaining-0907/ai-qa/practice-workspace-*`에 보관했습니다. 이 빌드는 최종 Web handoff 수정 전 UIQA v5입니다.
