---
name: narration-shorts
description: promo-content의 쇼츠 원고(18~22문장)와 컷시트로 내레이션형 세로 쇼츠(1080×1920, 60~100초, 사실적 장면 그림 + 직접 찍은 영상 조각 + 자막 + 배경음악)를 만든다. 시작할 때 환경(Python·Pillow·ffmpeg·한글 글꼴·API 키)을 점검하고, 없으면 설정 안내 페이지와 설치 명령을 안내한다. 그림·음성 생성(유료)은 승인받은 뒤에 한다. 트리거 — "쇼츠 만들어", "블로그 글로 쇼츠", "내레이션 영상", "narration-shorts", "릴스 영상 만들어".
license: MIT
metadata:
  category: legal
  locale: ko-KR
---

# 내레이션 쇼츠 (narration-shorts)

먼저 [공통 실행 규칙](../../references/runtime.md)을 읽고 현재 호스트에서 사용 가능한 기능으로 수행한다.

설정 안내: [narration-shorts 설정](../../docs/setup-narration-shorts.md) · [영상 공통 설정](../../docs/video-setup.md)
(웹: https://github.com/jurisupport/jurisupport-plugins/blob/main/plugins/jurisupport/docs/setup-narration-shorts.md)

스크립트는 `explainer-video`와 같은 `<plugin-root>/tools/video/`를 쓴다. `<plugin-root>`는 이 SKILL.md에서 두 단계 위다. 아래에서 `V="<plugin-root>/tools/video"`로 쓴다.

## 0. 원칙

- **원고 한 문장 = 컷 하나.** `promo-content`의 `03_쇼츠원고`(18~22문장)와 사실 대조표가 입력이다. 사실 대조표에서 `[미확인]`이 남은 문장은 넣지 않는다. 원고가 없으면 `promo-content`를 먼저 실행하라고 안내한다.
- **돈 드는 단계 전에 묻는다.** 그림·음성 API 호출 전에 컷 수, 호출 횟수, 서비스를 표로 보여 주고 승인을 받는다.
- **그림에 글자를 만들지 않는다.** 숫자·금액·날짜·조문은 정보판(boards.py)으로 그린다.
- **실제 사건·실존 인물을 그리지 않는다.** 사실적 그림일수록 실존 인물·실제 장소로 오해받지 않게 한다. 의뢰인 얼굴·사무실 외 실제 장소·상표는 넣지 않는다.
- **직접 찍은 영상과 음악은 사용자 것만 쓴다.** 초상권 동의가 없는 사람이 나오는 영상, 사용 허락 없는 음원은 쓰지 않는다.
- **API 키를 대화에 받지 않는다.** 키가 없으면 설정 안내 5절을 보여 준다.

## 1. 환경 점검 (매번 처음에)

```bash
python3 -I "$V/check_env.py" --mode narration
```

처리 방법은 `explainer-video` 1단계와 같다. `[없음]` 항목과 안내 링크를 보여 주고, 운영체제에 맞는 설치 명령을 제시해 실행 여부를 묻는다.

| 없는 것 | macOS | Windows | Linux |
|---|---|---|---|
| Pillow | `python3 -m pip install --user pillow` | 같음 | 같음 |
| ffmpeg | `brew install ffmpeg` | `winget install Gyan.FFmpeg` | `sudo apt install ffmpeg` |
| 한글 글꼴 | 기본 내장 | 기본 내장 | `sudo apt install fonts-noto-cjk` |

API 키가 없으면 [설정 안내 5절](../../docs/video-setup.md#5-api-key)을 안내하고, 무료 경로(say + placeholder)로 시험 영상부터 만들자고 제안한다.

## 2. cuts.json 만들기

작업 폴더는 `promo/<슬러그>/video/`다. 쇼츠 원고 문장마다 컷 하나를 만든다.

```json
{
  "title": "전세보증금 반환",
  "style": "real",
  "style_prompt": "Photorealistic illustration, natural window light, Korean apartment interior, calm documentary mood, shallow depth of field.",
  "top_title": "이사 가도 보증금 지키는 법",
  "voice": "Zephyr",
  "bgm": "bgm.mp3",
  "bgm_volume": 0.12,
  "end_card": {"title": "○○ 법률사무소", "lines": ["일반 정보이며 개별 사안은 다를 수 있습니다"]},
  "cuts": [
    {"n": 1, "narration": "원고 1번 문장", "subtitle": "줄인 자막", "image_prompt": "장면 묘사(글자 없음)"},
    {"n": 2, "narration": "원고 2번 문장", "clip": "clips/office.mp4"},
    {"n": 3, "narration": "원고 3번 문장", "board": {"title": "임차권등기명령", "lines": ["계약 끝난 뒤 신청", "등기 확인 후 이사"]}}
  ]
}
```

- `clip`은 작업 폴더 기준 경로다. 영상이 컷보다 짧으면 반복, 길면 잘린다. 원래 소리는 쓰지 않는다.
- 자막은 한 컷 2줄 이내가 되게 `subtitle`을 줄인다.
- 장면이 비슷하게 반복되지 않도록 인물·장소·거리(가까이/멀리)를 컷마다 바꾼다.

## 3. 비용 승인

음성 컷 수, 그림 컷 수(board·clip 컷 제외), 서비스 이름을 표로 보여 주고 승인을 받는다.

## 4. 음성 → 5. 그림·정보판 → 6. 조립

```bash
python3 -I "$V/tts.py"      "promo/<슬러그>/video" [--provider gemini|openai|say] [--voice Zephyr]
python3 -I "$V/images.py"   "promo/<슬러그>/video" [--provider gemini|openai|placeholder]
python3 -I "$V/boards.py"   "promo/<슬러그>/video"
python3 -I "$V/assemble.py" "promo/<슬러그>/video"
```

- 음성 전체 길이가 100초를 넘으면 원고를 줄이자고 제안한다.
- 그림을 열어 글자·로고·실존 인물로 보이는 얼굴이 있으면 그 컷만 지우고 `--only N`으로 다시 만든다.
- `out/check_NN.jpg`를 모두 열어 자막 잘림, 정보판 숫자, 영상 조각 위치를 확인한다.

## 7. 보고

1. 영상 경로(`out/video.mp4`)와 길이, 컷 수
2. 사용한 서비스와 호출 횟수(재생성 포함), 사용한 직접 영상·음원 목록
3. 공개 전 할 일: 유튜브 "변경되거나 합성된 콘텐츠" 표시, `06_광고점검` 재확인, 변호사 최종 시청

게시·업로드는 하지 않는다.
