# 설명 영상(explainer-video) 설정 안내

판결·법 개정 하나를 플랫 일러스트와 정보판으로 설명하는 세로 영상(1080×1920, 60~90초)을 만든다.

## 필요한 것

[공통 설정 안내](video-setup.md)의 1~4절(Python, Pillow, ffmpeg, 한글 글꼴)은 필수다. 실제 제작에는 5절의 API 키가 하나 필요하다.

| 단계 | 기본 도구 | 키 없을 때 |
|---|---|---|
| 음성 | Gemini TTS | macOS `say` (시험용) |
| 그림 | Gemini 그림 생성 | 회색 자리표시 그림 |
| 정보판·자막 | Pillow (로컬) | 그대로 |
| 조립 | ffmpeg (로컬) | 그대로 |

## 3분 점검

1. Claude Code에서 플러그인을 최신으로 올린다.
   ```bash
   claude plugin marketplace update jurisupport-plugins
   claude plugin update jurisupport@jurisupport-plugins
   ```
2. "영상 스킬 환경 점검해 줘"라고 말한다. `[없음]` 항목이 있으면 스킬이 [공통 설정 안내](video-setup.md)의 해당 절을 알려 주고, 설치 명령 실행 여부를 묻는다.
3. "예시 컷시트로 시험 영상 만들어 줘"라고 말한다. 무료 경로(say 음성 + 자리표시 그림)로 10초짜리 영상을 만든다.

## 쓰는 법

`promo-content`로 원고·컷시트를 만든 뒤 이어서 말한다.

> promo/<슬러그>/04_컷시트.md로 explainer-video 만들어. 그림 생성 전에 비용 알려 줘.

스킬은 컷시트를 `cuts.json`으로 바꾸고, 음성 → 그림(승인 후) → 정보판 → 조립 순서로 진행한다. 결과는 `promo/<슬러그>/video/out/video.mp4`다.
