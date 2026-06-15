# 부분 설치 가이드

> 전체 설치(`./install.sh`)가 부담스러울 때, 필요한 구성요소만 개별 설치하는 방법.

---

## 최소 설치 (5분)

데이터 보호 Hook + 가이드 스킬 + CSV 템플릿만:

```bash
cd ~/jurisupport-plugins

# 1. Hook
chmod +x hooks/pretool_data_protection.sh
# settings.json에 수동 등록 — hooks/INSTALL.md 참조

# 2. 가이드 스킬
mkdir -p ~/.claude/skills ~/.codex/skills ~/.claude/commands
cp -r skills/lbox-guide ~/.claude/skills/
cp -r skills/beopgoeul-search ~/.claude/skills/
cp -r skills/lbox-guide ~/.codex/skills/
cp -r skills/beopgoeul-search ~/.codex/skills/
cp skills/beopgoeul-search/SKILL.md ~/.claude/commands/beopgoeul-search.md

# 3. CSV 템플릿
mkdir -p ~/사건
cp templates/사건정보_관리표.csv ~/사건/_사건정보관리표.csv
cp templates/사건정보_입력가이드.md ~/사건/_입력가이드.md
```

이 상태로 가능한 것:
- `lbox-guide` / `beopgoeul-search` 스킬로 판례 검색 워크플로우 사용
- CSV 기반 사건 관리
- 데이터 보호 Hook 작동

불가능한 것 (추가 설치 필요):
- JuriSupport 플러그인 사용
- court-forms / legal-books / case-records 검색

---

## JuriSupport 플러그인만

```bash
# 1. plugin source 준비
git clone -c core.autocrlf=false -c core.longpaths=true https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins

# 2. Claude Code에 등록
claude plugin marketplace add "$(pwd)"
claude plugin uninstall songmu-legal 2>/dev/null || true
claude plugin install jurisupport@jurisupport-plugins

# 3. 법령·판결 정식 1차 검증용 korean-law MCP 설치 (법제처 OC 발급 후)
#    OC 발급 전 시연·실습은 JuriSupport 플러그인 내 /jurisupport:offline-law-fallback 사용
#    OC 발급 후:
claude plugin marketplace add chrisryugj/korean-law-mcp
claude plugin install korean-law@korean-law-marketplace
```

사용:
```bash
/jurisupport:cold-start-interview
/jurisupport:brief-protocol
```

---

## legal-books 검색만

```bash
bash toolkit/legal-books/install.sh
```

설치 후:
- 검색 서버 (포트 8766) 자동 시작
- 책 한 권 추가 → `~/legal-books/scripts/add_book.sh ...`
- 가이드: `guides/02_book_scanning.md`

---

## case-records 검색만

```bash
bash toolkit/case-records/install.sh
```

설치 후:
- 검색 서버 (포트 8767)
- 사건 추가 → `~/case-records/scripts/ingest_case.sh ...`
- 일괄 인덱싱 → `~/case-records/scripts/ingest_all.sh --root ~/사건`
- 가이드: `guides/03_case_records.md`

---

## court-forms 법원 양식 DB만

```bash
bash toolkit/court-forms/install.sh
```

설치 후:
- 전자소송포털 공개 양식모음 메타데이터를 `~/court-forms/db/forms.db`에 저장
- 검색 → `~/court-forms/scripts/court_forms.py search "주소보정" --top-k 5`
- 공식 HWP/PDF 다운로드 → `~/court-forms/scripts/court_forms.py download --query "주소보정" --kind hwp --out-dir .`
- 레포 자산화 → `~/court-forms/scripts/court_forms.py export-md --output data/court-forms --copy-files --download-missing`

---

## 제거

```bash
# Hook 제거: ~/.claude/settings.json 편집 (pretool_data_protection.sh 항목 제거)
# 스킬 제거: rm -rf ~/.claude/skills/{lbox-guide,beopgoeul-search,court-forms,legal-books,case-records}
# 명령 제거: rm -f ~/.claude/commands/{beopgoeul-search,court-forms}.md
# 플러그인 제거: claude plugin uninstall jurisupport
# legacy 제거: claude plugin uninstall songmu-legal
# korean-law 제거: claude plugin uninstall korean-law && claude plugin marketplace remove korean-law-marketplace
# toolkit 제거: rm -rf ~/legal-books ~/case-records ~/court-forms
# Secrets: rm -rf ~/.jurisupport (Gemini API 키 등)
```
