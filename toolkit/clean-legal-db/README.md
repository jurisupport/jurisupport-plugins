# clean-legal-db toolkit

저작권 청정 법률 DB(법령·판례·재결·결정 **18,150여 건**)를 오프라인 SQLite로 키워드 검색하는 도구. **API 키·인터넷 불필요.**

## 구성

| 파일 | 설명 | git 포함 |
|---|---|---|
| `search.py` | 검색기 (Python 표준 라이브러리만, 의존성 0) | ✅ |
| `install.sh` | `~/clean-legal-db/` 세팅 + DB 다운로드·검증 | ✅ |
| `COPYRIGHT.md` | 자료 출처·저작권 근거 | ✅ |
| `clean_legal.db` | DB 본체 (약 235MB) | ❌ GitHub Release 자산으로 별도 배포 |

> DB 본체(246MB)는 GitHub 일반 git의 100MB/파일 제한을 넘어 레포에 직접 커밋하지 않는다.
> legal-books·case-records와 동일하게 **데이터는 git 밖, 설치 시 사용자 머신에 취득**하는 방식.

## 설치

```bash
bash ~/jurisupport-plugins/toolkit/clean-legal-db/install.sh
```

수행 내용:
1. `~/clean-legal-db/` 생성, `search.py`·`COPYRIGHT.md` 복사
2. GitHub Release 자산에서 `clean_legal.db` 다운로드(`curl -C -` 이어받기 지원)
3. sha256 무결성 검증
4. SKILL.md를 `~/.claude/skills/clean-legal-db/`에 설치

환경변수로 다운로드 URL 교체 가능:
```bash
CLEAN_LEGAL_DB_URL="https://.../clean_legal.db" bash install.sh
```

## DB 배포(메인테이너용)

새 DB를 빌드한 뒤 Release 자산으로 올린다:

```bash
# 태그 clean-legal-db-v1 에 DB 자산 업로드
gh release create clean-legal-db-v1 \
  /path/to/clean_legal.db \
  --repo jurisupport/jurisupport-plugins \
  --title "clean-legal-db data v1" \
  --notes "법률 DB 18,150여 건 (sha256: 597b81f8…b4577)"

# 이미 릴리스가 있으면 자산만 추가
gh release upload clean-legal-db-v1 /path/to/clean_legal.db \
  --repo jurisupport/jurisupport-plugins --clobber
```

DB를 갱신해 sha256이 바뀌면 `install.sh`의 `EXPECTED_SHA256`도 함께 갱신할 것.

## 직접 검색

```bash
python3 ~/clean-legal-db/search.py "위법수집증거 증거능력"
python3 ~/clean-legal-db/search.py "유류분" --type 판례 --top 5
python3 ~/clean-legal-db/search.py "배임"          # 2글자도 가능
```
