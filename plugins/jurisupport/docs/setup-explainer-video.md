# 설명 애니메이션(explainer-video) 설정 안내

판결·법 개정 하나를 플랫 일러스트 애니메이션으로 설명하는 세로 영상(1080×1920, 60~90초)을 만든다. 사람 없는 배경과 캐릭터를 따로 그린 뒤, 캐릭터를 머리·몸통 조각으로 오려 브라우저 캔버스에서 움직인다. 팔 동작, 눈 깜빡임, 보드 타이핑, 빨간 X, 날짜 카드, 숫자 카운터, 화면 전환이 내레이션 어절 시각에 맞춰 나온다.

## 필요한 것

[공통 설정 안내](video-setup.md)의 1~4절(Python, Pillow, ffmpeg, 한글 글꼴)과 [7절](video-setup.md#7-cutout)(numpy, Playwright 브라우저)이 필수다. 실제 제작에는 5절의 API 키가 하나 필요하다.

| 단계 | 기본 도구 | 키 없을 때 |
|---|---|---|
| 그림(배경·캐릭터) | OpenAI gpt-image-2 또는 Gemini | 단순 도형 자리표시 그림 |
| 조각 오리기·부위 측정 | numpy·Pillow (로컬) | 그대로 |
| 음성 | Gemini TTS 또는 OpenAI | macOS `say` (시험용) |
| 애니메이션 렌더 | Playwright + Chromium/Chrome (로컬) | 그대로 |
| 효과음·믹스·합치기 | numpy·ffmpeg (로컬) | 그대로 |

## 3분 점검

1. Claude Code에서 플러그인을 최신으로 올린다.
   ```bash
   claude plugin marketplace update jurisupport-plugins
   claude plugin update jurisupport@jurisupport-plugins
   ```
2. "영상 스킬 환경 점검해 줘"라고 말한다. `[없음]` 항목이 있으면 스킬이 [공통 설정 안내](video-setup.md)의 해당 절을 알려 주고, 설치 명령 실행 여부를 묻는다.
3. "예시 장면으로 시험 애니메이션 만들어 줘"라고 말한다. 무료 경로(say 음성 + 자리표시 그림)로 17초짜리 영상을 만든다.

## 쓰는 법

`promo-content`로 쇼츠 원고·사실 대조표를 만든 뒤 이어서 말한다.

> promo/<슬러그>/ 원고로 explainer-video 만들어. 그림 생성 전에 장수와 비용 알려 줘.

스킬은 원고를 장면 정의(`scene.json`)로 바꾸고, 화풍 시험 2장(승인) → 그림 → 조각 → 음성 → 타이밍 → 점검 시트 → 렌더 순서로 진행한다. 결과는 `promo/<슬러그>/video/out/video.mp4`다.

## 비용 감각

배경 8~10장, 캐릭터 5~7장, 음성 20~26문장이 한 편 분량이다. 그림은 장당 요금이 붙고, 렌더·조각·믹스는 로컬에서 무료로 돈다. 다시 만들 때는 그 그림·문장만 다시 만든다.
