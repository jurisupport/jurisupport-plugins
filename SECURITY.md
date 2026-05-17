# Security Policy

## 📛 절대 커밋 금지

이 저장소는 법률 실무 자동화 플러그인을 담는다. **개인정보·비밀정보·인증 자료가 절대 git 히스토리에 들어가서는 안 된다.**

### 자동 차단되는 파일 (`.gitignore`)

| 패턴 | 사유 |
|---|---|
| `**/CLAUDE.md` | 사무소 플레이북. 변호사명·이메일·전자소송 ID·인증서명·로컬 경로 등 포함 |
| `.env`, `.env.*` | 환경변수, API 키 |
| `*.key`, `*.pem`, `*.p12`, `*.pfx`, `*.cer`, `*.crt` | 인증서·개인키 |
| `credentials.json`, `secrets.*`, `service-account*.json` | OAuth·서비스 계정 |
| `auth.json`, `token.json`, `.netrc` | 인증 토큰 |
| `*.local`, `*.local.*` | 사용자 로컬 설정 변종 |

### 허용되는 예외 (negation)
- `**/CLAUDE.md.example` — 공개 배포용 placeholder 템플릿
- `.env.example`, `.env.template` — 환경변수 명세 (값 비어있음)

## 🚨 사고 발생 시

실수로 개인정보가 포함된 커밋을 푸시했다면:

1. **즉시 해당 정보 무효화** (전자소송 비밀번호 변경, API 키 회전, 인증서 폐기 등)
2. `git filter-repo` 또는 BFG Repo-Cleaner로 히스토리에서 제거
3. `git push --force` (사전 협의 필수)
4. github 저장소가 fork/clone된 경우 모든 사본 확인

> ⚠️ git에 한 번 커밋되어 푸시되면 사실상 영구 노출로 간주. 정보 무효화가 1순위, 히스토리 제거는 2순위.

## 🔍 커밋 전 자가점검

```bash
# 1. 의도하지 않은 추적 파일 확인
git status

# 2. 스테이지된 변경에 개인정보 키워드 검색
git diff --cached | grep -iE '/Users/|/home/|@.*\.(com|kr)|password|secret|token|key.*=|cert'

# 3. CLAUDE.md가 실수로 추적되고 있는지 확인
git ls-files | grep -E 'CLAUDE\.md$'   # 결과가 비어있어야 함 (.example만 허용)
```

## 📨 취약점 신고

- 이 플러그인의 보안 이슈는 admin@jurisupport.com 으로 신고
- 공개 issue로 올리지 말 것

## 🛡 권장 운영 규칙

1. **`CLAUDE.md`는 절대 직접 만들지 말 것.** 항상 `cp CLAUDE.md.example CLAUDE.md` → 콜드스타트로 채움
2. PR/커밋 메시지에 사건번호·당사자명·의뢰인 이름 기재 금지
3. 사용자 로컬 확장(`brief-draft` 같은 개인 계정·DB 의존 스킬, 사용자 보유 법률서적 PDF 본체, 사건기록 본체)은 본 저장소의 `templates/`·`skills/`·`toolkit/`에 **재사용 가능한 설치·가이드 코드만** 포함하고, **실제 데이터(책 PDF, 사건 PDF, DB 파일)는 절대 커밋하지 말 것**. 데이터는 사용자 로컬 `~/legal-books/`·`~/case-records/`·`~/사건/`에만 존재
4. 개발 환경 변경 시 `.gitignore` 패턴이 여전히 유효한지 점검 (특히 IDE/OS 업그레이드 후)
