# 사진 판독 모델 교체 — build 22

2026-09-10 사용자 지시에 따라 연구용 Qwen2.5-VL-3B 판독기를
Qwen3.5-2B로 교체합니다. 이 문서는 0908/0909 보고서의 해당 모델에 관한
상업 이용 권한 미확인 상태를 대체합니다. 원 모델의 라이선스를 바꾼 것이 아니라,
원본과 GGUF 배포본 모두 Apache-2.0인 다른 모델을 사용하는 변경입니다.

## 출처와 무결성

- 원본: Qwen/Qwen3.5-2B
- 원본 revision: 15852e8c16360a2fea060d615a32b45270f8a8fc
- 원본 LICENSE: https://huggingface.co/Qwen/Qwen3.5-2B/blob/15852e8c16360a2fea060d615a32b45270f8a8fc/LICENSE
- GGUF: unsloth/Qwen3.5-2B-GGUF
- GGUF revision: f6d5376be1edb4d416d56da11e5397a961aca8ae
- GGUF model card: license=apache-2.0, base_model=Qwen/Qwen3.5-2B.
- 본체: Qwen3.5-2B-Q4_K_M.gguf, 1,280,835,840 bytes,
  SHA-256 aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223
- 프로젝터 원본: mmproj-F16.gguf, 668,227,264 bytes,
  SHA-256 7035e9cb8d7c6a9681d07eef9a364783e86ea4cd73faab2eabb4f43a101830c7
- 로컬 프로젝터 이름: mmproj-Qwen3.5-2B-F16.gguf. 다른 체급의 프로젝터와
  충돌하지 않도록 이름만 구분하며 파일 내용은 변경하지 않습니다.
- 앱에 원본 Apache-2.0 LICENSE 전문과 출처 고지를 포함합니다.

## 변경 범위

- 8GB급 기기의 사진 판독을 specVision2B로 전환합니다.
- 기존 DeepSeek7B 수학 추론 및 고메모리 Qwen3.5-9B 경로는 유지합니다.
- 기존 Qwen2.5-VL-3B 파일은 삭제하지 않지만 자동 탐색과 엔진 로드에서 제외합니다.
- 과거 vision3B 자가진단 인자는 새 vision2B의 호환 별칭입니다. 옛 가중치를 열지 않습니다.
- 시뮬레이터 전체 파이프라인 검증 폴더를 분리해 이전 모델의 체크포인트를 재사용하지 않습니다.

## 현재 확인

- build 22 iOS/iPadOS 개발 빌드 성공 및 지정 iPad14,3 실기에 업데이트 설치·실행 확인.
- 사용자 확인: Google 로그인 정상. 카카오·Apple 로그인 실제 완료는 미확인.
- 모델 변경을 포함한 193개 회귀 검사 통과.
- 실제 가중치 2개 다운로드와 바이트 크기·SHA-256 검증 완료.
- 실제 시뮬레이터 모델 로드와 생성 응답은 확인했지만, 전체 파이프라인은
  손글씨 전사 JSON 형식 검증에서 실패했습니다. 형식 대응이 추가로 필요합니다.
  코드/라이선스 확인을 사진 판독 품질 검증 완료로 표현하지 않습니다.
- 실기 모델 추론·발열·속도 시험은 요청대로 수행하지 않습니다. 실기는 피드백용 앱 설치만 진행합니다.
