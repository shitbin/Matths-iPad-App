# 커리큘럼 시스템 TTS 실제 재생시간 감사

2026-08-15 현재 220개 published story를 `Yuna` 한국어 여성 시스템 음성으로
실제 합성했다. 앱이 재생하는 것과 동일하게 `CurriculumNarrationChunker`가 만든
문장 chunk를 각각 합성하고 PCM frame 길이를 합산했다. 글자 수를 시간으로
환산한 추정치가 아니다.

- iPad 소스 기준: `fa46a6dd7c441c2ac42a8d5940e20a4a47f902e0` 이후 TTS 속도 보정 작업본
- `systemSpeechRateFactor`: `0.55`
- 측정: 220개
- timeout: 0개
- 최단: 234.900초 (`vocational-math-02-01`)
- 최장: 346.678초 (`math-research-project-03-04`)
- 전체 평균: 274.637초
- 230~360초 범위 밖: 0개

재현 명령:

```sh
bash tests/manual/run-curriculum-narration-duration-audit.sh
```

한 개념만 진단하려면 `MATTHS_TTS_CONCEPT=<conceptId>`를 함께 지정한다.

웹 `SpeechSynthesisUtterance.rate`와 Apple `AVSpeechUtterance.rate`는 같은
스케일이 아니므로 숫자를 공유하지 않는다. 웹은 `0.68`, iPad는 실제 Apple
음성 합성으로 검증한 `0.55`를 사용한다. 브라우저·OS에 설치된 음성에 따라
실제 길이는 달라질 수 있으므로 이 결과는 Yuna ko-KR 기준이다.
