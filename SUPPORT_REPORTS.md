# Windows 설치 진단 리포트

제3자 Windows 네이티브 설치가 중간에 실패했을 때, 설치 로그와 환경정보를 진단 ZIP으로 묶어 쥬리서포트 지원팀에 전달하는 기능입니다.

## 사용 방법

PowerShell에서 아래처럼 지원 리포트 옵션을 켠 뒤 설치합니다.

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

실패하면 다음을 수행합니다.

1. Desktop에 `jurisupport-install-report-YYYYMMDD-HHMMSS.zip` 생성
2. 기본 업로드 엔드포인트로 ZIP 전송 시도
3. 업로드 실패 시 ZIP 위치를 열고 메일 작성 창 표시

지원 이메일을 바꾸려면:

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
$env:JURISUPPORT_SUPPORT_EMAIL = "support@example.com"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

업로드 엔드포인트를 바꾸려면:

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
$env:JURISUPPORT_SUPPORT_UPLOAD_URL = "https://example.com/support/install-report"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

업로드는 끄고 ZIP/메일 fallback만 쓰려면:

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
$env:JURISUPPORT_SUPPORT_UPLOAD_URL = "off"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

## 포함되는 정보

- PowerShell 버전과 실행 정책
- Windows 버전, 빌드, 아키텍처, 제조사/모델
- 관리자 권한 여부
- 시스템 언어, 코드페이지
- PATH, 단 사용자 로컬 경로는 마스킹
- `winget`, `git`, `bash`, `node`, `npm`, `python`, `jq`, `claude`, `curl.exe` 위치와 버전
- 관련 winget 패키지 설치 상태
- npm global prefix/cache와 Claude Code npm 패키지 상태
- `~/jurisupport-plugins` clone 여부, git HEAD/status
- bootstrap transcript 로그, 토큰·API key·password 형태 문자열은 마스킹

## 포함하지 않는 정보

- 사건자료 파일
- `~/.claude/settings.json`
- `~/.jurisupport/secrets.env`
- 전체 환경변수 덤프
- Claude OAuth 토큰, MCP bearer token 원문

주의: 설치환경 파악을 위해 Windows 사용자 프로필 경로, PATH, 패키지 목록이 일부 포함될 수 있습니다. 사용자 로컬 경로는 `%USERPROFILE%`, `%TEMP%` 등으로 치환하고, 사용자명/프로필 경로에 비ASCII 문자가 있는지만 별도 boolean 값으로 기록합니다.

## 엔드포인트 계약

기본 업로드 URL:

```text
POST https://api.jurisupport.com/support/install-report
Content-Type: multipart/form-data
X-JuriSupport-Report-Version: 1
```

multipart fields:

| 필드 | 설명 |
|---|---|
| `file` | 진단 ZIP 파일 |
| `reason` | `unhandled-error`, `bootstrap-exit` 등 생성 사유 |
| `session_id` | `YYYYMMDD-HHMMSS` 형식의 클라이언트 세션 ID |
| `source` | 현재는 `windows-bootstrap` |

성공 조건:

- HTTP 2xx면 성공으로 간주
- 응답 본문은 사용하지 않음

권장 서버 정책:

- 최대 파일 크기 제한: 10MB
- ZIP만 허용
- 악성 파일 스캔
- 업로드 IP rate limit
- 서버 저장 시 암호화
- 지원 담당자만 접근
- 기본 보관 기간 30일 이하
- 업로드 성공 시 내부 ticket/report ID 발급

엔드포인트가 2xx를 반환하지 않거나 네트워크가 막히면 bootstrap은 ZIP 파일을 보존하고 메일 작성 창을 fallback으로 엽니다.

## JuriSupport 서버 구현 명세

JuriSupport 백엔드에는 공개 인증 없이 받을 수 있는 제한적 ingest endpoint를 하나 둡니다. 설치 실패 시점에는 아직 사용자가 로그인하지 않았을 수 있으므로 계정 인증을 필수로 두지 않습니다. 대신 파일 크기 제한, MIME/ZIP 검증, rate limit, 악성파일 스캔, 짧은 보관 기간으로 방어합니다.

### API

```http
POST /support/install-report
Content-Type: multipart/form-data
X-JuriSupport-Report-Version: 1
```

요청 필드:

| 필드 | 필수 | 검증 |
|---|---:|---|
| `file` | 예 | ZIP, 10MB 이하, 압축 해제 후 30MB 이하, entry 수 50개 이하 |
| `reason` | 예 | `[a-z0-9-]{1,64}` |
| `session_id` | 예 | `YYYYMMDD-HHMMSS` |
| `source` | 예 | 현재는 `windows-bootstrap`만 허용 |

응답:

```json
{
  "ok": true,
  "reportId": "irpt_20260528_abcd1234",
  "message": "received"
}
```

클라이언트는 2xx 여부만 봅니다. 본문은 운영자/수동 확인용입니다.

### 서버 처리 순서

1. `Content-Length`가 10MB를 넘으면 `413` 반환
2. IP 기준 rate limit 적용: 예) 1시간 10건, 1일 30건
3. multipart 필드 검증
4. ZIP 파일 magic byte 확인: `PK\x03\x04`, `PK\x05\x06`, `PK\x07\x08`
5. 임시 디렉토리에 안전하게 저장
6. ZIP slip 방지 검증: entry path에 절대경로, `..`, drive letter 금지
7. 압축 해제 없이 가능하면 ZIP 내부 목록만 검사
8. 허용 파일명만 수락: `environment.txt`, `README.txt`, `bootstrap-transcript.redacted.log`
9. 악성 파일 스캔 가능하면 실행
10. object storage에 저장
11. DB에 metadata 저장
12. 내부 알림 생성: Slack/Discord/email/ticket
13. `201` + `reportId` 반환

### 저장 정책

권장 object key:

```text
support/install-reports/YYYY/MM/DD/{reportId}.zip
```

권장 DB 테이블:

```sql
create table install_reports (
  id text primary key,
  created_at timestamptz not null default now(),
  source text not null,
  reason text not null,
  client_session_id text not null,
  ip_hash text not null,
  user_agent text,
  object_key text not null,
  size_bytes integer not null,
  sha256 text not null,
  status text not null default 'received',
  expires_at timestamptz not null
);
```

`ip_hash`는 원 IP를 그대로 저장하지 말고 서버 비밀 salt로 HMAC 처리합니다. 기본 보관 기간은 30일 이하를 권장합니다.

### 보안 요구사항

- 인증 없는 endpoint이므로 public internet 기준으로 설계
- ZIP 외 파일 거부
- 업로드 파일을 웹에서 직접 다운로드 가능한 public URL로 두지 않음
- 지원 담당자 권한으로만 열람 가능
- 업로드 원본과 해제된 파일 모두 실행 금지
- 로그에 multipart 본문이나 ZIP 내용을 남기지 않음
- `Authorization`, `token`, `api_key`, `password` 패턴이 발견되면 서버에서도 한 번 더 마스킹 또는 quarantine
- WAF/Cloudflare 등을 쓰면 endpoint rate limit을 별도 적용

### 운영자 화면

지원 담당자가 볼 최소 정보:

- report ID
- 생성 시각
- source/reason/session_id
- Windows 버전, PowerShell 버전, winget 상태 요약
- 실패 로그 tail 200줄
- ZIP 다운로드 버튼
- 처리 상태: `received`, `triaged`, `resolved`, `deleted`

ZIP 다운로드는 audit log를 남깁니다.

### 테스트 케이스

- 정상 ZIP 업로드 → `201`
- 10MB 초과 → `413`
- ZIP이 아닌 파일 → `415`
- `../evil.txt` 포함 ZIP → `400`
- `source`가 허용값 아님 → `400`
- 같은 IP 연속 업로드 limit 초과 → `429`
- 악성/의심 패턴 포함 → 저장하되 `status=quarantined` 또는 내부 경고
- object storage 실패 → `503`

### 배포 순서

1. staging endpoint 배포
2. 로컬에서 `JURISUPPORT_SUPPORT_UPLOAD_URL`을 staging으로 바꿔 업로드 테스트
3. 정상/오류 응답과 fallback 동작 확인
4. production endpoint 배포
5. `windows-bootstrap.ps1` 기본 URL이 production으로 동작하는지 확인
6. 보관 기간 cleanup job 활성화
