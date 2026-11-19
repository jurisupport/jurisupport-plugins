# 영상 스킬 공통 설정 안내

`explainer-video`(애니메이션 설명 영상)와 `narration-shorts`(내레이션 쇼츠)가 함께 쓰는 준비 사항이다. 한 번만 하면 두 스킬 모두 쓸 수 있다.

스킬별 안내: [설명 영상(explainer-video)](setup-explainer-video.md) · [내레이션 쇼츠(narration-shorts)](setup-narration-shorts.md)

## 먼저 점검부터

Claude Code에 "영상 스킬 환경 점검해 줘"라고 말하면 스킬이 아래 명령을 실행한다. 직접 돌려도 된다.

```bash
python3 "<플러그인 폴더>/tools/video/check_env.py"
```

`[없음]`으로 나온 항목만 아래 해당 절을 따라 설치한다. `[선택]` 항목은 없어도 시험 영상은 만들 수 있다.

| 항목 | 필수 | 용도 | 안내 |
|---|---|---|---|
| Python 3.9 이상 | 필수 | 스크립트 실행 | [1절](#1-python) |
| Pillow | 필수 | 자막·정보판 그리기 | [2절](#2-pillow) |
| ffmpeg | 필수 | 영상 조립 | [3절](#3-ffmpeg) |
| 한글 글꼴 | 필수 | 자막 글자 | [4절](#4-font) |
| Gemini 또는 OpenAI API 키 | 선택(실제 제작엔 필요) | 음성·그림 생성 | [5절](#5-api-key) |
| macOS 음성(say) | 선택 | 무료 시험 음성 | [6절](#6-free-voice) |

<a id="1-python"></a>
## 1. Python

- macOS: 터미널에서 `python3 --version`. 없으면 `xcode-select --install` 또는 `brew install python`.
- Windows: `winget install Python.Python.3.12`. 설치 뒤 새 터미널을 연다.
- Linux: `sudo apt install python3 python3-pip`.

<a id="2-pillow"></a>
## 2. Pillow

```bash
python3 -m pip install --user pillow
```

macOS Homebrew Python에서 `externally-managed-environment` 오류가 나면 `python3 -m pip install --user --break-system-packages pillow` 또는 `brew install pillow`를 쓴다.

<a id="3-ffmpeg"></a>
## 3. ffmpeg

- macOS: `brew install ffmpeg` (Homebrew가 없으면 https://brew.sh 에서 먼저 설치)
- Windows: `winget install Gyan.FFmpeg` 후 새 터미널에서 `ffmpeg -version`
- Linux: `sudo apt install ffmpeg`

자막은 Pillow로 그리므로 ffmpeg의 drawtext·libass가 없어도 된다. `zoompan` 필터만 있으면 된다(일반 배포판에는 들어 있다).

<a id="4-font"></a>
## 4. 한글 글꼴

macOS(Apple SD 산돌고딕 Neo)와 Windows(맑은 고딕)는 기본 글꼴을 자동으로 찾는다. Linux는 `sudo apt install fonts-noto-cjk` 또는 `fonts-nanum`을 설치한다.

사무소 글꼴을 쓰려면 환경변수 `JURISUPPORT_FONT`에 글꼴 파일 경로를 넣거나, 스크립트에 `--font 경로`를 준다. 상업용 사용이 허락된 글꼴만 쓴다.

<a id="5-api-key"></a>
## 5. API 키 (음성·그림 생성)

둘 중 하나만 있어도 된다. 둘 다 있으면 Gemini를 먼저 쓴다.

| 서비스 | 쓰는 곳 | 키 발급 |
|---|---|---|
| Google Gemini | 음성(TTS)·그림 | https://aistudio.google.com/apikey |
| OpenAI | 그림·음성 | https://platform.openai.com/api-keys |

키를 넣는 방법은 둘 중 하나다.

```bash
# 방법 1: 파일 (권장, 터미널을 새로 열어도 유지)
mkdir -p ~/.jurisupport && chmod 700 ~/.jurisupport
printf '%s' '여기에_키' > ~/.jurisupport/gemini_api_key   # OpenAI는 openai_api_key
chmod 600 ~/.jurisupport/*_api_key

# 방법 2: 환경변수
export GEMINI_API_KEY='여기에_키'    # OpenAI는 OPENAI_API_KEY
```

주의할 점:

- 키를 Claude 대화창에 붙여 넣지 않는다. 터미널에서 직접 파일로 저장한다.
- 키 파일을 사건 폴더·공유 폴더·Git 저장소에 두지 않는다.
- 두 서비스 모두 사용량만큼 요금이 나온다. 결제 한도(budget)를 먼저 걸어 둔다. 스킬은 그림·음성 생성 전에 컷 수와 생성 횟수를 보여 주고 승인을 받는다.
- 모델 이름은 바뀔 수 있다. 오류가 나면 환경변수 `TTS_MODEL`, `IMAGE_MODEL`로 현재 모델명을 지정한다.

<a id="6-free-voice"></a>
## 6. 무료 시험 경로

API 키 없이도 영상 조립까지 시험할 수 있다.

- 음성: macOS는 내장 `say`(유나 목소리)를 쓴다. Windows·Linux는 무료 음성 경로가 없으므로 API 키가 필요하다.
- 그림: `--provider placeholder`로 회색 자리표시 그림을 만든다.

시험 영상으로 컷 길이·자막·정보판을 먼저 확인하고, 원고가 확정되면 유료 생성으로 바꾼다.

<a id="7-cutout"></a>
## 7. 조각 애니메이션 도구 (explainer-video)

explainer-video는 배경과 캐릭터를 따로 만들어 브라우저 화면에서 움직인 뒤 프레임을 뽑는다. 아래 두 가지가 더 필요하다.

```bash
python3 -m pip install --user numpy playwright
python3 -m playwright install chromium
```

- `playwright install chromium`이 막히는 환경(회사 PC 등)은 Chrome이 설치되어 있으면 그것을 쓴다.
- 렌더 속도: 1분 영상(30fps)은 일반 노트북에서 1~2분 걸린다.

## 공개 전 확인

AI로 만든 음성·그림을 쓴 영상은 플랫폼 규정에 따라 공개 표시를 한다(유튜브 업로드 화면의 "변경되거나 합성된 콘텐츠"). 변호사 광고 점검은 `promo-content`의 광고 점검표를 따른다.
