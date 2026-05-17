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
mkdir -p ~/.claude/skills
cp -r skills/lbox-guide skills/beopgoeul-guide ~/.claude/skills/

# 3. CSV 템플릿
mkdir -p ~/사건
cp templates/사건정보_관리표.csv ~/사건/_사건정보관리표.csv
cp templates/사건정보_입력가이드.md ~/사건/_입력가이드.md
```

이 상태로 가능한 것:
- `lbox-guide` / `beopgoeul-guide` 스킬로 판례 검색 워크플로우 사용
- CSV 기반 사건 관리
- 데이터 보호 Hook 작동

불가능한 것 (추가 설치 필요):
- songmu-legal 플러그인 사용
- legal-books / case-records 검색

---

## songmu-legal 플러그인만

```bash
# 1. plugin source 준비 (이미 plugins/songmu-legal 안에 있으면 skip)
git clone https://github.com/.../jurisupport-plugins.git plugins/

# 2. Claude Code에 등록
mkdir -p ~/.claude/plugins/cache/jurisupport-plugins
ln -s "$(pwd)/plugins/songmu-legal" ~/.claude/plugins/cache/jurisupport-plugins/songmu-legal
```

사용:
```bash
/songmu-legal:cold-start-interview
/songmu-legal:brief-protocol
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

## 제거

```bash
# Hook 제거: ~/.claude/settings.json 편집 (pretool_data_protection.sh 항목 제거)
# 스킬 제거: rm -rf ~/.claude/skills/{lbox-guide,beopgoeul-guide,legal-books,case-records}
# 플러그인 제거: rm ~/.claude/plugins/cache/jurisupport-plugins/songmu-legal
# 서버 제거: rm -rf ~/legal-books ~/case-records
# Secrets: rm -rf ~/.jurisupport (Gemini API 키 등)
```
