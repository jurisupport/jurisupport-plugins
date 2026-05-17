# 강의 사전 안내 — 노트북 사전 준비 (강의 전날까지)

> 강의에서 라이브 설치를 진행합니다. 다음 항목을 **강의 전날까지 미리** 설치해 주세요.
> 사전 설치 안 하시면 강의 40분 중 본인 설치만 하다가 끝날 수 있습니다.

---

## 0. 노트북 — 가능하면 **개인 노트북**

회사 노트북은 다음 이유로 설치 실패율이 높습니다:

- 보안 프로그램(V3·Symantec·Lockheed 등)이 `npm install`을 차단
- 관리자 권한 부족
- 사내 프록시·방화벽

회사 노트북만 있으시면 강의 전 IT팀에 다음 사항 사전 확인 부탁드립니다.

- `npm install -g` 허용 여부
- `brew install` 허용 여부
- `git clone` from GitHub 허용 여부

---

## 1. 클로드 Pro 또는 Max 계정 (월 20달러 이상)

https://claude.ai/upgrade 에서 Pro 이상 가입 + 결제 완료.

**Free 플랜은 작동 안 합니다.**

---

## 2. macOS / Linux 환경

| OS | 추천 |
|---|---|
| macOS Apple Silicon | ✅ 가장 권장 |
| macOS Intel | ✅ |
| Ubuntu 22.04+ | ✅ |
| Windows | ⏳ 본 패키지 미지원 (WSL2 사용 필요) |

Windows만 있으신 분은 강의 전 WSL2(Ubuntu) 설치를 권장하지만, 강의 효율을 위해 가능하면 Mac/Linux 노트북을 빌려서 오시면 좋습니다.

---

## 3. 사전 설치 6가지 (macOS 기준)

### 3-1. Homebrew (있으면 skip)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

설치 후 안내되는 PATH 추가 명령도 실행 (Apple Silicon 머신은 `eval "$(/opt/homebrew/bin/brew shellenv)"` 같은 줄을 `~/.zprofile`에 추가).

### 3-2. jq + git + python (한 줄)

```bash
brew install jq git python@3.11
```

### 3-3. Node.js LTS

```bash
brew install node
node --version    # v22.x 또는 v20.x 확인
```

### 3-4. Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude --version  # 설치 확인
```

### 3-5. Google Chrome (법고을 자동 검색용, 선택)

이미 있으면 skip. 없으면 https://www.google.com/chrome/ 에서 다운로드 설치.

### 3-6. (선택) Google Gemini API 키 발급

https://aistudio.google.com/apikey 에서 무료 키 발급. **무료 한도로 강의·일상 사용에 충분합니다.**

→ 강의에서는 발급만 해 두시면 됩니다. 노트북에 등록은 강의 중에 함께.

---

## 4. 강의 당일 (라이브 단계)

위 사전 준비가 완료되어 있으면 강의에서는 다음만 진행합니다.

| 시간 | 작업 |
|---|---|
| 0–5분 | `claude` 첫 실행 → Pro 계정 OAuth 로그인 |
| 5–10분 | `git clone https://github.com/jurisupport/jurisupport-plugins.git` |
| 10–25분 | `cd jurisupport-plugins && ./install.sh` |
| 25–40분 | 가상사건으로 첫 준비서면 자동 작성 시연 |

---

## 5. 검증 (강의 전날 셀프 점검)

다음 명령을 모두 통과하면 준비 완료:

```bash
brew --version
jq --version
git --version
python3 --version    # 3.9 이상
node --version       # 20 이상
npm --version
claude --version     # Claude Code 설치 확인
```

`Google Chrome.app` 폴더가 `/Applications/` 안에 있는지도 확인.

---

## 6. 막혔을 때

강의 전날 막히신 분은 다음 채널로 연락:

- 이메일: admin@jurisupport.com
- 강의 채팅방: (별도 안내)

당일 아침에 몰아서 해결 어렵습니다. **반드시 전날까지 완료**해 주세요.

---

## 7. 한국어 사용자명 주의

`C:\Users\하희봉\` 같은 한글 경로는 일부 도구에서 깨집니다. 사용자명이 한글이신 분은 강의 전에 미리 알려주시면 별도로 도와드립니다.

(Mac/Linux는 보통 영문 사용자명이라 큰 문제 없음.)
