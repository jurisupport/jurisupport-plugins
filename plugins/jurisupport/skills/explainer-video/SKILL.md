---
name: explainer-video
description: promo-content의 쇼츠 원고·사실 대조표로 판결·법 개정 설명 애니메이션(세로 1080×1920, 60~90초)을 만든다. 사람 없는 배경과 크로마 초록 위 캐릭터를 따로 생성해 조각(머리·몸통)으로 오리고, 브라우저 캔버스 엔진으로 팔 동작·눈 깜빡임·말할 때 끄덕임·등장 효과·보드 타이핑·빨간 X·날짜 카드·숫자 카운터·화면 전환을 내레이션 어절 시각에 맞춰 움직인다. 시작할 때 환경(Python·Pillow·numpy·Playwright 브라우저·ffmpeg·한글 글꼴·API 키)을 점검하고, 없으면 설정 안내와 설치 명령을 안내한다. 그림·음성 생성(유료)은 장수와 비용을 보여 주고 승인받은 뒤에 한다. 트리거 — "설명 영상 만들어", "애니메이션 설명 영상", "조각 애니메이션", "플랫 애니 쇼츠", "explainer-video", "영상 스킬 환경 점검".
license: MIT
metadata:
  category: legal
  locale: ko-KR
---

# 설명 애니메이션 (explainer-video)

먼저 [공통 실행 규칙](../../references/runtime.md)을 읽고 현재 호스트에서 사용 가능한 기능으로 수행한다.

설정 안내: [explainer-video 설정](../../docs/setup-explainer-video.md) · [영상 공통 설정](../../docs/video-setup.md)
(웹: https://github.com/jurisupport/jurisupport-plugins/blob/main/plugins/jurisupport/docs/setup-explainer-video.md)

스크립트는 `<plugin-root>/tools/video/cutout/`에 있다. `<plugin-root>`는 이 SKILL.md에서 두 단계 위다. 아래에서 `C="<plugin-root>/tools/video/cutout"`, `V="<plugin-root>/tools/video"`로 쓴다. 공백이 있는 경로는 따옴표로 감싼다.

## 어떤 영상인가

컷마다 그림 한 장을 보여 주는 슬라이드쇼가 아니다. 장면은 배경 그림(플레이트) 위에 캐릭터 조각을 세우고 코드로 움직인다.

| 요소 | 만드는 방법 |
|---|---|
| 배경 | 사람 없는 장소 그림 1장. 보드·간판·화면은 비워 두고 글자는 코드로 타이핑한다 |
| 캐릭터 | 크로마 초록(#00B140) 위 전신 1명. 머리·몸통으로 오리고 눈·목·어깨를 잰다 |
| 팔 | `animate_arms`인 캐릭터는 팔 없이 그리고, 팔은 코드(IK)로 그린다 |
| 움직임 | 말할 때 끄덕임, 숨쉬기, 눈 깜빡임, 뒤돌기, 점프, 자세 바꾸기 |
| 화면 효과 | 보드 타이핑, 빨간 X, 체크, 느낌표, 날짜 카드, 아이콘, 숫자 카운터, ≠, 흰 스플랫 전환 |
| 타이밍 | 모든 장면·효과는 내레이션의 "문장번호 + 어절"에 맞춰 시작한다 |

## 0. 원칙

- **원고가 확정된 뒤에 만든다.** 입력은 `promo-content`의 쇼츠 원고와 사실 대조표다. `[미확인]`이 남은 문장은 넣지 않는다. 원고가 없으면 `promo-content`를 먼저 실행하라고 안내한다.
- **사실은 판결·조문 원문 그대로.** 판결 문언("공시", "연설", "상응하는 방법")을 쉬운 말로 지어 바꾸지 않는다. 보충의견·별개의견을 다수의견처럼 말하지 않는다.
- **돈 드는 단계 전에 묻는다.** 그림(배경 N장 + 캐릭터 M장)과 음성(문장 수)을 표로 보여 주고 승인받는다. 화풍 시험 2장(배경 1·캐릭터 1)을 먼저 만들어 승인받은 뒤 나머지를 만든다.
- **참조 이미지를 넣지 않는다.** 다른 채널 화면·캐릭터를 참조로 넣으면 그대로 베낀다(실제 제작에서 13장 전부 실패). 화풍은 글로만 지시한다. 저작권·부정경쟁 위험도 있다.
- **그림에 글자를 만들지 않는다.** 숫자·금액·날짜·조문은 엔진이 타이핑한다. 프롬프트에 글자 금지문이 자동으로 붙는다.
- **실제 사건·실존 인물을 그리지 않는다.** 의뢰인 동의가 없는 사건 정보, 실존 인물 얼굴, 상표·로고는 넣지 않는다.
- **API 키를 대화에 받지 않는다.** 키가 없으면 [설정 안내 5절](../../docs/video-setup.md#5-api-key)을 보여 주고 사용자가 터미널에서 직접 저장하게 한다.
- 날짜·일수 계산(예: 1999. 11. 12.부터 2026. 7. 22.까지 일수)은 계산 도구로 하고 계산식을 남긴다.

## 1. 환경 점검 (매번 처음에)

```bash
python3 -I "$V/check_env.py" --mode explainer
```

- 종료 코드 0이면 2단계로 간다.
- `[없음]` 항목이 있으면 그 항목과 안내 링크를 보여 주고, 운영체제에 맞는 설치 명령을 제시해 실행 여부를 묻는다. 승인하면 실행한 뒤 다시 점검한다.

| 없는 것 | 설치 명령 |
|---|---|
| Pillow·numpy·Playwright | `python3 -m pip install --user pillow numpy playwright` |
| 렌더용 브라우저 | `python3 -m playwright install chromium` (막히면 Chrome 설치로 대신한다) |
| ffmpeg | macOS `brew install ffmpeg` · Windows `winget install Gyan.FFmpeg` · Linux `sudo apt install ffmpeg` |
| 한글 글꼴(Linux) | `sudo apt install fonts-noto-cjk` |

- 처음 쓰는 사용자에게는 무료 시험을 먼저 제안한다. `$C/example/scene.json`을 빈 작업 폴더에 복사하고 3~8단계를 `--provider placeholder`(단순 도형 그림), `--provider say`(macOS 음성)로 돌린다. 17초짜리 영상이 나온다.

## 2. 장면 설계 → scene.json

작업 폴더는 `promo/<슬러그>/video/`다. 쇼츠 원고 문장을 `sentences`로, 장면을 `shots`로 옮긴다.

### 이야기 구조 (75~85초 기준)

훅(통념 뒤집기, 0~4초) → 위기감 숫자(카운터) → 주제 표지판(조문 번호) → 실제 사건 장소 + 날짜 카드 → 구성요소(아이콘 목록) → "그럼 ○○은 어디에?" 헤드라인 → 작동 원리(날짜 카드·일수 카운터·빨간 X) → 결과 → 반전 헤드라인 → 시청자에게 질문으로 끝(주제어로 끝맺는다). 개인 분쟁 사연은 이 구조에 맞지 않는다. 그런 소재는 `narration-shorts`를 권한다.

### 형식

```json
{
  "title": "상관모욕죄 판결 설명",
  "top_title": "단톡방 욕설, 상관모욕죄일까",
  "voice": "Zephyr", "speed": 1.1,
  "end_card": {"title": "○○ 법률사무소", "lines": ["일반 정보이며 개별 사안은 다를 수 있습니다"]},
  "plates": {
    "강의실": {"prompt": "A military lecture room with a blank teal chalkboard in the upper middle.", "board": [0.17, 0.17, 0.84, 0.44]}
  },
  "characters": {
    "교관": {"prompt": "A Korean army instructor in a beige uniform and glasses.", "animate_arms": true},
    "대법관": {"prompt": "A Korean supreme court justice in a black robe, sitting."}
  },
  "sentences": [
    {"n": 1, "text": "이 해석이 9,749일 이어졌습니다.", "tts": "이 해석이 구천칠백사십구 일 이어졌습니다."}
  ],
  "shots": [
    {"id": "s01", "plate": "강의실", "camera": {"z": 1.06, "fy": 1100},
     "board": {"lines": [{"text": "처벌하는 방법", "at": [1, "이해석이"]}]},
     "chars": [{"name": "교관", "x": 980, "y": 2020, "h": 1080, "talk": true, "pose": "point_up_left"}]}
  ]
}
```

- **좌표**는 배경 그림 좌표(가로 1152 × 세로 2048)다. 캐릭터 `x, y`는 발 가운데, `h`는 키다. 서 있는 캐릭터는 `y` 2000~2040, `h` 900~1150이 기본이다. 두 명이면 `x` 450·900 근처에 둔다. 아래 1/3에 자막이 깔리므로 얼굴을 `y` 1500 아래로 내리지 않는다.
- **앵커** `at: [문장번호, "어절"]`은 그 어절이 발화되는 순간이다. 끝 시각은 `[n, "어절", "end"]`, 같은 어절이 두 번 나오면 `"어절#2"`, 장면 시작부터의 초는 숫자(`0.4`)로 쓴다. 공백·쉼표는 무시하고 찾는다("9,749" = "9749").
- **plates**: `board`는 빈 보드의 대략 위치(0~1 비율, [왼쪽, 위, 오른쪽, 아래])다. cutout.py가 실제 보드 경계를 잰다. 보드가 없으면 생략한다.
- **characters**: `animate_arms: true`면 팔 없이 그리고 팔을 코드로 움직인다(가리키기·손짓·만세가 필요한 캐릭터). 그 밖은 그림 그대로 쓴다(앉은 사람, 단체, 소품 든 사람).
- **sentences**: `text`는 화면 자막, `tts`는 읽기용(숫자를 한글로). 인물 대사는 `"voice": "Fenrir"`처럼 그 인물 목소리를 따로 준다.

### 장면(shot) 키

| 키 | 뜻 |
|---|---|
| `at` | 장면 시작 어절(첫 장면은 생략, 0초) |
| `plate` | 배경 이름. 또는 `headline: {"text", "bg": "#5b3fa6", "deco": "gears"|"blobs"|"none", "at"}`(단색 헤드라인 화면) |
| `camera` | `z` 확대(1.04~1.9), `fx, fy` 초점, `panX, panY` 이동량, `drift` 천천히 확대, `focus: "board"`(보드로 확대) |
| `board` | `{"lines": [{"text", "at", "color": "red", "scale", "cps"}], "color"}` 보드에 줄마다 타이핑. `at`이 없으면 처음부터 보인다 |
| `chars` | 캐릭터 목록(아래 표) |
| `behind` + `cover` | 가림막 뒤 캐릭터(판사석 뒤 대법관). `cover: [y0, y1]` 구간의 배경을 다시 그려 하반신을 가린다 |
| `fx` | 효과 목록(아래 표) |
| `wipe` | `true`면 이 장면이 흰 스플랫 전환으로 시작한다. 막(act)이 바뀔 때 2~3번만 쓴다 |

캐릭터: `name, x, y, h, talk`(말하는 중 끄덕임), `nod`(끄덕임 세기), `seed`(같은 캐릭터 여러 명일 때 서로 다르게), `pose`, `poses: [{"at", "pose"}]`(자세 바꾸기), `flip`(좌우 반전), `flip_at`(그 순간 뒤돌기), `react_at`(움찔), `jump_at`, `enter_at`(튀어나오며 등장), `hold: "phone"|"headset"|"document"…`(손에 든 물건), `bang_at` + `bang`(머리 위 "!"·"?").

자세(`animate_arms` 캐릭터만): `down`, `fists`, `talk`(한 손 손짓), `explain`(두 손 손짓), `shrug`, `point_left`, `point_right`, `point_up_left`, `point_up_right`(보드 가리키기), `raise_left`, `raise_right`, `cheer`(만세), `angry`(두 주먹 흔들기), `hold`(물건 든 손 앞으로).

효과(`fx`): `type`과 위치(`x, y` 또는 `"in": "board", "fx": 0~1, "fy": 0~1`), 시작 `at`.

| type | 추가 키 |
|---|---|
| `x` / `check` | `r` 크기 |
| `date` | `text`("2026. 7. 22.") |
| `count` | `to`, `unit`("일"), `plus`(끝에 +), `until`(다 세는 시각) |
| `text` | `text`, `size`, `color`, `align: "left"` |
| `icon` | `icon`: poster·document·podium·megaphone·phone·bubble·bill·bars·lock·frame·house·coin·gavel·clock·headset, `size` |
| `bang` / `neq` | `text`("?"), `size` |

### 지적받아 고친 연출 규칙

- 내린 팔은 몸 뒤, 손짓·가리키기·든 팔은 몸 앞에 그린다(엔진이 자동으로 한다). 정면 그림 캐릭터는 걷는 장면에서 팔을 흔들지 않는다(옆으로 벌어진다).
- 아이콘은 놓일 보드 색과 대비되는 것을 고른다(청록 칠판 위 청록 아이콘은 안 보인다). 목록 항목마다 아이콘을 붙인다.
- 날짜 카드·라벨은 화면 가장자리에 붙이지 않는다.
- 연출이 법적 의미와 다르면(예: 입건 장면의 오라) 영상 설명문 유의사항에 적는다("입건이 곧 체포나 구속을 뜻하지는 않습니다").
- 관형어를 겹친 번역투("세 명 앞의 한마디는")와 조사 생략("문서 공시")을 쓰지 않는다.

## 3. 비용 승인

배경 장수, 캐릭터 장수, 음성 문장 수, 쓸 서비스를 표로 보여 주고 승인을 받는다. 승인 전에는 `--provider placeholder`/`say`로만 돌린다.

## 4. 그림

```bash
python3 -I "$C/art.py" "promo/<슬러그>/video" --only plate:강의실,char:교관   # 화풍 시험 2장 → 승인
python3 -I "$C/art.py" "promo/<슬러그>/video"                              # 나머지
```

기본은 OpenAI `gpt-image-2`, 없으면 Gemini다(`--provider`로 고른다). 만든 그림을 모두 열어 본다. 배경에 사람·글자가 있거나, `animate_arms` 캐릭터에 팔이 그려졌거나, 캐릭터에 초록색이 쓰였으면 그 그림을 지우고 프롬프트를 고쳐 `--only`로 다시 만든다.

## 5. 조각

```bash
python3 -I "$C/cutout.py" "promo/<슬러그>/video"
```

`out/check_cutout.png`를 연다. 배경의 빨간 사각형이 빈 보드와 맞는지, 캐릭터의 빨간 선(목)이 턱 아래인지, 파란 선(어깨)이 어깨 윗선인지, 분홍 원(눈) 2개가 눈 위에 있는지 본다. 출력에 "힌트값 사용"이 나오면 `board` 힌트를 고쳐 다시 돌린다. 눈을 못 찾으면 깜빡임만 빠지고 나머지는 그대로 된다.

## 6. 음성과 타이밍

```bash
python3 -I "$C/voice.py" "promo/<슬러그>/video" [--provider gemini|openai|say] [--speed 1.1]
python3 -I "$C/timeline.py" "promo/<슬러그>/video"
```

voice.py는 문장별 음성을 만들어 앞뒤 무음을 자르고 이어 붙인다. 어절 시각은 문장 발화 구간을 글자 수로 나눈 추정값이다. 효과가 말보다 늦거나 빠르면 앵커 어절을 앞뒤로 옮긴다. 다시 만들 문장은 `--only 3,5`로 만든다. timeline.py가 0.9초보다 짧은 장면을 알려 주면 앵커를 옮기거나 장면을 합친다.

## 7. 점검 시트

```bash
python3 -I "$C/render.py" "promo/<슬러그>/video" sheet
python3 -I "$C/render.py" "promo/<슬러그>/video" frames 12.4 12.9 31.0   # 특정 시각 확인
```

`out/sheet_N.png`를 모두 연다. 빈 보드, 넘치는 글자, 자막에 가린 얼굴, 화면 가장자리의 검은 띠를 확인한다. 팔이 나오는 장면은 `frames`로 2시점씩 보고, 팔이 어깨에서 시작하는지, 몸통 안에 박히지 않았는지 확인한다. 고치면 timeline.py부터 다시 돌린다.

## 8. 렌더

```bash
python3 -I "$C/render.py" "promo/<슬러그>/video" video [--fps 30] [--sub 2] [--bgm 음악파일]
```

효과음(타이핑·등장·X·체크·전환)은 엔진이 기록한 시각에 맞춰 합성해 넣는다. 배경음은 내레이션보다 약 10dB 낮게, 최종 음량은 -14 LUFS로 맞춘다. 결과는 `out/video.mp4`다. 더 매끄럽게 하려면 `--fps 60 --sub 4`(시간이 4배 걸린다).

## 9. 보고

사용자에게 다음을 보고한다.

1. 영상 경로와 길이, 장면 수
2. 사용한 서비스와 호출 횟수(재생성 포함)
3. 공개 전 할 일: 유튜브 "변경되거나 합성된 콘텐츠" 표시 여부 판단(애니메이션은 대개 불요, 실사풍 장면은 필요), `06_광고점검` 항목 재확인, 변호사 최종 시청

게시·업로드는 하지 않는다.
