# 공식 평가·연습·메모 경계

공식 시작은 인증 후 기존 서버 start API만 사용한다. 로그인 전 요청은 scope/course/unit/subunit intent를 보관하고 로그인 성공 후 한 번 소비한다. 같은 범위의 서버 미제출 회차가 있으면 해당 ID·답안으로 돌아간다. 중복 시작은 진행 중 상태로 차단한다.

서버 회차는 토큰이 사라져도 로컬 채점으로 넘어가지 않는다. submit/expire와 서버 terminal 결과를 사용한다. 기존 로컬 회차는 공식 합격·최고점·미제출 조회에서 제외하며 `legacy-practice-assessments.json`에 보존한 뒤 공식 저장소에서 분리한다. 보존 실패 시 원본은 그대로 두고 공식 조회 필터를 유지한다.

새 오프라인 연습은 `PracticeAssessmentRecord`, `practice-` ID, `practice-assessments-v1.json` 파일을 사용한다. passed/unlock/server ID 필드가 없고 서버 요청·EventLog·공식 오답·진도를 변경하지 않는다. 공개된 과목의 웹 파생 생성기만 사용하고, 허용 후보를 제한된 횟수로 확장한 뒤 계획 문항 수와 정확히 같을 때만 시작한다. 부족하면 실패 상태를 보여준다.

공식 평가의 필기판은 `AssessmentScratchpadModel`이 소유한다. 계정 슬롯 + 평가 ID hash별 파일이며 자동 저장과 명시적 flush, 실행 취소를 제공한다. `DebouncedSnapshotWriter`의 revision·latest-wins·실패 보존·invalidate 계약을 재사용한다. 회전과 패널 전환은 같은 PKDrawing을 이동시킨다. 이 메모는 서버 답안이나 채점 자료로 자동 제출되지 않는다.

넓은 화면에서는 문제지와 메모를 함께 표시하고, 좁은 화면·접근성 큰 글자는 메모 전용 화면을 연다. 나가기·background·계정 전환의 저장 경계와 탈퇴 cancel-and-drain에 연결했다.
