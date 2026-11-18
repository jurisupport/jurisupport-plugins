---
name: explainer-video
description: promo-content의 컷시트로 판결·법 개정 설명 영상(세로 1080×1920, 60~90초, 플랫 일러스트 + 정보판 + 자막 + 내레이션)을 만든다. 시작할 때 환경(Python·Pillow·ffmpeg·한글 글꼴·API 키)을 점검하고, 없으면 설정 안내 페이지와 설치 명령을 안내한다. 그림·음성 생성(유료)은 컷 수와 비용을 보여 주고 승인받은 뒤에 한다. 트리거 — "설명 영상 만들어", "컷시트로 영상", "애니 설명 쇼츠", "explainer-video", "영상 스킬 환경 점검".
license: MIT
metadata:
  category: legal
  locale: ko-KR
---

# 설명 영상 (explainer-video)

먼저 [공통 실행 규칙](../../references/runtime.md)을 읽고 현재 호스트에서 사용 가능한 기능으로 수행한다.

설정 안내: [explainer-video 설정](../../docs/setup-explainer-video.md) · [영상 공통 설정](../../docs/video-setup.md)
(웹: https://github.com/jurisupport/jurisupport-plugins/blob/main/plugins/jurisupport/docs/setup-explainer-video.md)

스크립트는 `<plugin-root>/tools/video/`에 있다. `<plugin-root>`는 이 SKILL.md에서 두 단계 위다. 아래에서 `V="<plugin-root>/tools/video"`로 쓴다. 공백이 있는 경로는 따옴표로 감싼다.

## 0. 원칙

- **원고가 확정된 뒤에 만든다.** 입력은 `promo-content`가 만든 사실 대조표와 컷시트다. 사실 대조표에서 `[미확인]`이 남은 문장은 영상에 넣지 않는다. 컷시트가 없으면 `promo-content`를 먼저 실행하라고 안내한다.
- **돈 드는 단계 전에 묻는다.** 그림·음성 API 호출 전에 컷 수, 호출 횟수, 쓸 서비스를 표로 보여 주고 승인을 받는다. 재생성도 컷 단위(`--only`)로 한다.
- **그림에 글자를 만들지 않는다.** 숫자·금액·날짜·조문은 정보판(boards.py)으로 직접 그린다. 그림 프롬프트에는 글자 금지문이 자동으로 붙는다.
- **실제 사건·실존 인물을 그리지 않는다.** 의뢰인 동의가 없는 사건 정보, 실존 인물 얼굴, 상표·로고는 넣지 않는다.
- **API 키를 대화에 받지 않는다.** 키가 없으면 설정 안내 5절을 보여 주고 사용자가 터미널에서 직접 저장하게 한다.

## 1. 환경 점검 (매번 처음에)

```bash
python3 -I "$V/check_env.py" --mode explainer
```

- 종료 코드 0이면 2단계로 간다.
- `[없음]` 항목이 있으면 그 항목과 안내 링크를 그대로 보여 준다. 그다음 운영체제에 맞는 설치 명령을 제시하고 실행 여부를 묻는다. 승인하면 실행한 뒤 점검을 다시 돌린다.

| 없는 것 | macOS | Windows | Linux |
|---|---|---|---|
| Pillow | `python3 -m pip install --user pillow` | 같음 | 같음 |
| ffmpeg | `brew install ffmpeg` | `winget install Gyan.FFmpeg` | `sudo apt install ffmpeg` |
| 한글 글꼴 | 기본 내장 | 기본 내장 | `sudo apt install fonts-noto-cjk` |

- API 키가 없으면 설치하지 않고 [설정 안내 5절](../../docs/video-setup.md#5-api-key)을 안내한다. 키 없이 시험하려면 무료 경로(say 음성 + 자리표시 그림)를 제안한다.
- 처음 쓰는 사용자에게는 예시로 시험 영상을 먼저 만들자고 제안한다: `$V/example/cuts.json`을 작업 폴더에 복사해 4~6단계를 `--provider say`, `--provider placeholder`로 실행한다.

## 2. cuts.json 만들기

작업 폴더는 `promo/<슬러그>/video/`다. 컷시트(`04_컷시트.md`)의 표를 아래 형식으로 옮긴다.

```json
{
  "title": "상관모욕죄 판결 설명",
  "style": "flat",
  "style_prompt": "Flat vector illustration, simple shapes, muted navy and beige palette, clean background, friendly characters without facial detail.",
  "top_title": "단톡방 욕설, 상관모욕죄일까",
  "voice": "Zephyr",
  "end_card": {"title": "○○ 법률사무소", "lines": ["일반 정보이며 개별 사안은 다를 수 있습니다"]},
  "cuts": [
    {"n": 1, "narration": "읽을 문장", "subtitle": "화면 자막(생략하면 narration)", "image_prompt": "그림 프롬프트(영어 권장, 글자 없음)"},
    {"n": 2, "narration": "읽을 문장", "board": {"title": "정보판 제목", "lines": ["항목 1", "항목 2"]}}
  ]
}
```

- 컷시트의 `정보판 문구`가 있는 컷은 `board`로, 없으면 `image_prompt`로 옮긴다.
- 숫자를 읽는 방식이 어색하면 `"tts": "읽기용 문장"`을 따로 둔다(예: "제3조" → "삼 조").
- `end_card`에는 사무소명과 일반 정보 고지를 넣는다. 광고 규정상 필요한 표시는 `promo-content` 06_광고점검을 따른다.

## 3. 비용 승인

음성 컷 수, 그림 컷 수(board·clip 컷 제외), 서비스 이름을 표로 보여 주고 승인을 받는다. 승인 전에는 4·5단계를 무료 경로로만 돌린다.

## 4. 음성

```bash
python3 -I "$V/tts.py" "promo/<슬러그>/video" [--provider gemini|openai|say] [--voice Zephyr]
```

컷별 길이가 출력된다. 한 컷이 8초를 넘으면 컷을 나누자고 제안한다. 다시 만들 컷은 `audio/NN.wav`를 지우고 `--only N`으로 실행한다.

## 5. 그림과 정보판

```bash
python3 -I "$V/images.py" "promo/<슬러그>/video" [--provider gemini|openai|placeholder]
python3 -I "$V/boards.py" "promo/<슬러그>/video"
```

만든 그림을 열어 본다. 글자·로고·실존 인물로 보이는 얼굴이 있으면 그 컷 그림을 지우고 프롬프트를 고쳐 `--only N`으로 다시 만든다.

## 6. 조립과 확인

```bash
python3 -I "$V/assemble.py" "promo/<슬러그>/video" [--bgm 음악파일]
```

`out/check_NN.jpg`를 모두 열어 자막 잘림, 정보판 숫자, 컷 순서를 확인한다. 결과는 `out/video.mp4`다.

## 7. 보고

사용자에게 다음을 보고한다.

1. 영상 경로와 길이, 컷 수
2. 사용한 서비스와 호출 횟수(재생성 포함)
3. 공개 전 할 일: 유튜브 "변경되거나 합성된 콘텐츠" 표시, `06_광고점검` 항목 재확인, 변호사 최종 시청

게시·업로드는 하지 않는다.
