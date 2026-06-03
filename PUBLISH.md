# GitHub 배포 체크리스트

> 강의 후 본 패키지를 GitHub에 공개 배포할 때의 단계별 작업.

---

## 1. 사전 점검 (push 전 필수)

### 1-1. 개인정보·비밀 누출 검사

```bash
cd ~/jurisupport-plugins
git init 2>/dev/null || true

# 주민번호 패턴 검사
grep -rE '[0-9]{6}-[0-9]{7}' . --include="*.md" --include="*.sh" --include="*.py" --include="*.json" | grep -v node_modules

# 한국 휴대전화 검사
grep -rE '01[0-9]-[0-9]{4}-[0-9]{4}' . --include="*.md" --include="*.sh" --include="*.py" | grep -v "예\|XXXX\|0000"

# API 키 패턴 검사 (Gemini, OpenAI 등)
grep -rE 'AIza[0-9A-Za-z-_]{35}' .
grep -rE 'sk-[0-9A-Za-z]{40,}' .

# 사건번호 패턴 (가상 사건은 OK, 진짜 사건만 검사)
grep -rE '20[0-9]{2}가[가-힣]+[0-9]{4,}' . --include="*.md" | grep -v "가상사건\|예시\|SAMPLE"

# 이메일 (변호사님 본인 이메일이 노출되었는지 확인)
grep -rE "@lawpid\\.kr|본인_이메일@example\\.com" .   # 본인 이메일이 example로 포함되었는지
```

위 검사에서 잡힌 항목은 모두 일반 placeholder로 치환 후 push.

### 1-2. `.gitignore` 작동 확인

```bash
git status --ignored
```

다음 항목들이 `Ignored files:`에 있어야 함:
- `**/secrets.env`
- `**/CLAUDE.md` (CLAUDE.md.example은 제외)
- `**/.env`

---

## 2. GitHub 단일 저장소 Push

본 패키지는 단일 저장소 `jurisupport/jurisupport-plugins`에 모두 통합되어 있습니다.

```bash
# GitHub에서 빈 저장소 생성: jurisupport/jurisupport-plugins
# 설명: 변호사용 클로드코드 통합 패키지 (JuriSupport + 검색·보안·가이드)

cd ~/jurisupport-plugins
git init 2>/dev/null || true
git add .
git commit -m "feat: 변호사용 클로드코드 통합 패키지 (JuriSupport + skills + toolkit + hooks + guides)"
git branch -M main
git remote add origin git@github.com:jurisupport/jurisupport-plugins.git 2>/dev/null || \
  git remote set-url origin git@github.com:jurisupport/jurisupport-plugins.git
git push -u origin main
```

---

## 3. README 배지 / 문서 다듬기

### 3-1. jurisupport-plugins/README.md 상단

```markdown
# jurisupport-plugins

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey)
![Korean](https://img.shields.io/badge/Locale-ko--KR-red)

> 한국 송무 변호사를 위한 클로드코드 통합 패키지
```

### 3-2. 데모 GIF (선택, 강의 후)

5세션 병렬 시연 화면 녹화 → GIF 변환 → README 상단에 첨부.

---

## 4. 공개 안내

### 4-1. 강의 청중에게 메일

```
제목: [클로드코드 강의] 패키지 GitHub 공개

변호사님,

어제 강의 자료 및 통합 패키지를 GitHub에 공개했습니다.

- 통합 패키지: https://github.com/jurisupport/jurisupport-plugins
- 플러그인: https://github.com/jurisupport/jurisupport-plugins

설치는 README의 한 줄 명령으로 가능합니다:
  git clone https://github.com/jurisupport/jurisupport-plugins.git
  cd jurisupport-plugins && ./install.sh

콜드스타트 가이드는 COLD_START.md 참조.

문의: admin@jurisupport.com
```

### 4-2. 변협·법률 커뮤니티 공유 (선택)

- 변협 정보화위원회
- 대한변협신문 또는 법률신문 IT/AI 섹션
- 법률 전문 슬랙·디스코드 커뮤니티

---

## 5. 유지·관리

### Issues 운영

- 라벨: `bug`, `enhancement`, `documentation`, `installation`, `security`
- `security` 라벨 이슈는 우선 처리

### 버전 관리

- Semantic Versioning (v0.1.0 → v0.2.0 → v1.0.0)
- 주요 변경 시 CHANGELOG.md 작성

### 보안 정책

- `SECURITY.md` 작성: 의뢰인 정보·API 키 누출 발견 시 비공개 보고 경로 (이메일)
