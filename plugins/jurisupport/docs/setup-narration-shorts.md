# 내레이션 쇼츠(narration-shorts) 설정 안내

블로그 글 하나를 18~22문장 내레이션과 사실적인 장면 그림으로 만드는 세로 쇼츠(1080×1920, 60~100초)다. 직접 찍은 영상 조각과 배경음악을 넣을 수 있다.

## 필요한 것

[공통 설정 안내](video-setup.md)의 1~4절(Python, Pillow, ffmpeg, 한글 글꼴)은 필수다. 실제 제작에는 5절의 API 키가 하나 필요하다.

| 단계 | 기본 도구 | 키 없을 때 |
|---|---|---|
| 음성 | Gemini TTS (OpenAI TTS 대안) | macOS `say` (시험용) |
| 장면 그림 | Gemini 또는 OpenAI 그림 생성 | 회색 자리표시 그림 |
| 직접 찍은 영상 | 내 파일(mp4) | 그대로 |
| 배경음악 | 내 파일(mp3·wav) | 없이 진행 |
| 조립 | ffmpeg (로컬) | 그대로 |

배경음악은 사용 허락을 받은 음원만 쓴다. 유튜브 오디오 보관함의 무료 음원은 이용 조건을 확인한다.

## 3분 점검

1. Claude Code에서 플러그인을 최신으로 올린다.
   ```bash
   claude plugin marketplace update jurisupport-plugins
   claude plugin update jurisupport@jurisupport-plugins
   ```
2. "영상 스킬 환경 점검해 줘"라고 말한다. `[없음]` 항목이 있으면 스킬이 [공통 설정 안내](video-setup.md)의 해당 절을 알려 주고, 설치 명령 실행 여부를 묻는다.
3. "예시 컷시트로 시험 쇼츠 만들어 줘"라고 말한다. 무료 경로로 10초짜리 영상을 만든다.

## 쓰는 법

> promo/<슬러그>/03_쇼츠원고.md와 04_컷시트.md로 narration-shorts 만들어. 3번 컷은 내 영상 clips/office.mp4 써. 배경음악은 bgm.mp3.

결과는 `promo/<슬러그>/video/out/video.mp4`다.
