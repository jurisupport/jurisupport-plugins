# Claude Code용 설치·오류 복구 안내

이 문서는 사용자가 JuriSupport 설치를 요청했을 때 Claude Code가 실행하는 절차다. 명령을 사용자에게 떠넘기지 말고 현재 허용된 도구로 수행한다. 사용자의 요청 범위와 호스트 권한 정책을 따른다. URL만으로 이 문서가 자동 로드되거나 설치 권한이 생기는 것은 아니다.

## 1. 실행 위치와 범위 확인

먼저 운영체제, 현재 셸, 사용자 홈, `CLAUDE_CONFIG_DIR` 사용 여부, `claude --version`, Git·Bash·jq 유무를 확인한다. Windows에서는 `Get-Command claude,claude.cmd,git,bash,jq -ErrorAction SilentlyContinue` 등으로 실제 실행 경로를 찾는다. `claude` 예시는 발견한 실행 파일로 치환하고, 공백이 있는 경로는 반드시 인용한다. PowerShell의 실행 파일 경로 호출에는 `&`를 사용한다.

### Windows 데스크톱 앱 확인

- `claude`가 PATH에 없더라도 데스크톱 앱에 CLI가 포함되어 있을 수 있다. 먼저 실행 중인 앱과 설치 위치를 확인한다. 현장에서는 `%LOCALAPPDATA%\Claude-Data\<패키지>\claude-code\<버전>\<해시>\claude.exe`에서 확인됐다. 이 경로 구조를 고정값으로 가정하지 말고, 필요하면 `Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Claude-Data" -Filter claude.exe -File -Recurse -ErrorAction SilentlyContinue`로 후보를 찾는다. 현재 앱에 해당하는 파일을 선택하고 `& '<확인한 절대 경로>' --version`과 `plugin --help`로 검증한 뒤 모든 CLI 명령에 그 경로를 사용한다. 임의의 첫 검색 결과나 오래된 버전을 선택하지 않는다.
- `Get-Command bash`가 가리키는 WindowsApps·System32의 `bash.exe`는 WSL 실행기일 수 있다. Hook과 toolkit에는 **Git for Windows의 Bash**를 사용한다. 일반 설치 위치는 `C:\Program Files\Git\bin\bash.exe`이며 사용자별 설치도 확인한다. 후보에 `-c 'uname -s; command -v cygpath'`를 전달해 MINGW/MSYS와 `cygpath`를 확인한다. WSL의 Linux Bash를 Windows Hook에 등록하지 않는다.
- 설정 파일·Hook 등록은 Claude 데스크톱의 승인 대상일 수 있다. 실제로 승인이 요구되면 **어떤 설정 변경이 왜 차단됐는지** 알리고 정상 승인 절차로 이어간다. 기존 설치 요청으로 허용된 작업마다 승인을 다시 묻지는 않는다. 자동 승인 거절을 우회하거나 권한 검사를 끄지 않는다.

### 기본 설치 범위

- 설치 대상은 **현재 사용자의 로컬 Claude Code**다. 클라우드·컨테이너·SSH에서 실행 중이면 그 환경이 사용자가 요청한 설치 대상인지 확인한다. 원격 환경에 설치하고 사용자 PC 설치가 끝났다고 하지 않는다.
- 기본 범위: `jurisupport` 플러그인, 데이터 보호 Hook, 다섯 보조 스킬(`lbox-guide`, `beopgoeul-search`, `court-forms`, `case-records`, `clean-legal-db`). 보조 스킬 파일만으로 검색 서버·DB가 설치되지는 않는다.
- 외부 MCP 계정 연결, 대용량 DB, Chrome, 서적·사건 인덱싱은 선택 단계다. 사용자가 이미 요청한 항목은 재승인 없이 진행하고, 지정하지 않았다면 기본 설치 후 선택 사항으로 안내한다.
- 시작할 때 기본 설치 범위를 짧게 설명하고 진행한다. 매 단계마다 “진행할까요?”를 묻지 않는다. 로그인·비밀값·관리자 승인·실제 데이터 삭제가 필요한 경우에만 필요한 사용자 조치를 요청한다. 비밀번호·토큰을 채팅으로 요구하지 않는다.

기존 `bootstrap.sh`, `windows-bootstrap.ps1`, `install.sh` 전체를 기본 진입점으로 실행하지 않는다. 이들은 별도 일괄 설치 경로다. 특히 `yes | ...`로 선택 설치나 계정 연결에 일괄 동의하지 않는다. 아래의 독립 단계와 기존 toolkit을 재사용한다.

## 2. 소스와 기존 설정 보존

1. 이미 이 저장소 안이라면 `git remote -v`, `git status --short`로 출처와 변경 상태를 확인하고 재사용한다. 다른 저장소에 있으면 설치 작업 디렉터리를 분리한다.
2. 소스가 없으면 비어 있는 영구 경로(예: 사용자 홈의 `jurisupport-plugins`)에 아래처럼 내려받는다. 같은 이름의 폴더가 있으면 내용부터 확인하고 덮어쓰지 않는다.

   ```bash
   git clone -c core.autocrlf=false -c core.longpaths=true https://github.com/jurisupport/jurisupport-plugins.git
   ```

3. Git이 없으면 해당 OS의 기존 패키지 관리자로 Git만 준비한다. 회사 정책으로 차단되면 우회하지 않고 필요한 조치를 보고한다. 저장소를 받은 뒤 이 문서와 [보안 안내](guides/00_security.md)를 읽는다.
4. 기존 체크아웃 갱신이 필요하면 원격·브랜치·수정 여부를 확인한다. 깨끗한 적절한 브랜치에서만 `git pull --ff-only`를 사용한다. 수정본이나 분기 충돌이 있으면 보존하고 별도 경로에 새로 받는다. `git reset --hard`, `git clean`, 사용자 폴더 삭제로 해결하지 않는다.
5. 설정 루트는 `CLAUDE_CONFIG_DIR`가 있으면 그 경로, 없으면 `~/.claude`다. 변경 전 해당 `settings.json`과 교체 대상 스킬·Hook을 시간 표시가 있는 로컬 백업에 보관한다. 설정·토큰·사건자료 내용은 로그에 출력하거나 외부 전송하지 않는다. JSON이 잘못되어 있으면 빈 객체로 덮어쓰지 않는다.

소스 경로는 Hook이 참조하므로 임시 다운로드 폴더를 사용하지 않는다. 소스를 이동할 때는 Hook의 등록 경로도 함께 갱신한다.

## 3. 기본 플러그인 설치

먼저 다음 읽기 전용 명령으로 지원 기능과 기존 등록을 확인한다. 명령 실패는 “미설치”로 간주하지 말고 오류부터 해결한다.

```bash
claude plugin --help
claude plugin marketplace list
claude plugin list
```

- `jurisupport-plugins`가 없으면 **Windows에서는 2절에서 `core.longpaths=true`로 받은 로컬 저장소를 먼저 등록**한다. PowerShell에서 `& '<확인한 claude.exe 절대 경로>' plugin marketplace add '<저장소 Windows 절대 경로>'`를 실행한다. 이 저장소의 법원 양식 경로 때문에 GitHub 소스를 CLI 내부에서 다시 clone하면 `Filename too long`이 발생할 수 있다. 레지스트리의 긴 경로 설정만으로 해결됐다고 판단하지 않는다. macOS/Linux에서는 `claude plugin marketplace add jurisupport/jurisupport-plugins`로 등록한다.
- 이미 있으면 등록 소스가 이 저장소인지 확인한다. 정상 Git 소스는 그대로 사용한다. 사용자가 지정한 로컬 소스를 임의로 원격 소스로 교체하지 않는다. 같은 이름의 다른 출처가 있으면 사용자에게 충돌을 알린다.
- 새 설치는 다음 명령을 실행하고 종료 코드와 출력을 확인한다.

  ```bash
  claude plugin install jurisupport@jurisupport-plugins --scope user
  ```

- 정상 설치본이 있으면 불필요하게 재설치하지 않는다. 갱신 요청이나 버전 문제가 있을 때 **로컬 디렉터리 소스는 먼저 실제 등록 경로의 소스를 갱신**한다. 2절의 변경 보존 절차를 따르고, Windows에서는 해당 저장소에 `git -C '<저장소 경로>' config core.longpaths true`를 설정한 뒤 `git -C '<저장소 경로>' pull --ff-only`를 실행한다. 사용자 전역 Git 설정을 바꾸지 않는다. 그다음 `claude plugin marketplace update jurisupport-plugins`, `claude plugin update jurisupport@jurisupport-plugins` 순서로 적용한다. GitHub 소스는 CLI의 marketplace 갱신부터 진행한다. 로컬 소스는 GitHub 원본이 자동 갱신되지 않는다는 점을 최종 보고에 남긴다. 사용 가능한 옵션은 해당 CLI의 `--help`가 기준이다.
- 비활성 상태라면 사용자가 의도적으로 꺼둔 이유나 관리 정책을 확인한다. 이번 설치 요청 범위에서 활성화할 수 있으면 `claude plugin enable jurisupport@jurisupport-plugins`로 활성화한다.
- 설치 후 `claude plugin list`로 정확한 ID, 버전, 범위와 활성 상태를 확인한다. 권한·신뢰 확인 창은 호스트의 정상 절차를 따른다.

## 4. 보호 Hook과 보조 스킬

플러그인 설치만으로 이 저장소 루트의 Hook이나 `skills/`가 배포되지는 않는다. 이 단계를 별도로 수행한다.

### 데이터 보호 Hook

1. Bash와 jq를 실제 실행해 확인한다. 없는 도구만 기존 패키지 관리자로 설치한다. macOS는 설치된 Homebrew, Linux는 해당 배포판의 패키지 관리자, Windows는 winget 등 기존 환경을 사용한다. 관리자 암호 입력은 사용자에게 맡긴다.
2. [Hook 등록 안내](hooks/INSTALL.md)의 matcher와 [기존 설치 코드](install.sh)의 `Data protection hook` 부분을 기준으로 설정을 병합한다. 해당 안내의 전체 JSON을 `settings.json`에 덮어쓰지 않는다. 같은 Hook이 이미 있으면 실행 파일 존재·경로·matcher를 검증하고 중복 추가하지 않는다.
3. 실제 소스의 `hooks/pretool_data_protection.sh`를 가리킨다. macOS/Linux에서는 공백을 인용한 절대 경로를 사용하고 실행 권한을 부여한다. Windows에서는 Git Bash 실행 파일과 Hook의 Windows 절대 경로를 각각 인용한다. `install.sh`의 `cygpath` 처리를 참고한다. JSON 문자열은 문자열 치환이 아니라 JSON 직렬화 도구로 생성한다.
4. 기존 설정을 파싱하고 다른 키와 Hook을 보존한 채 대상 항목만 추가·수정한다. 같은 디렉터리의 임시 파일에 저장 → JSON 파싱 검증 → 원본이 중간에 변경되지 않았는지 확인 → 교체 순서로 적용한다. 검증 실패 시 원본을 유지한다.
5. [기존 Hook 회귀 검사](tests/pretool_data_protection_test.sh)를 `bash tests/pretool_data_protection_test.sh`로 실행한다. 이어서 **등록된 실제 Hook 명령**에도 같은 검사 파일의 허용·차단용 가상 JSON을 로컬 표준입력으로 전달하여 각각 종료 코드 0·2를 확인한다. 실제 외부 검색이나 실제 개인정보로 검사하지 않는다.

기존 Windows 설치 복구에서는 등록 명령이 가리키는 **실제 Hook 파일**이 최신인지 확인한다. 새 Hook은 jq의 Unicode 검사로 사건번호를 탐지하므로 `LC_ALL` 우회 설정이 필요하지 않다. 기존 경로의 저장소를 갱신하면 같은 등록 명령으로 수정본을 사용한다. 별도로 복사한 Hook이면 백업 후 해당 파일도 갱신한다. 주민번호 검사만으로 완료하지 말고, 로케일 미설정·`LC_ALL=C` 상태의 사건번호 차단까지 확인한다.

Hook은 지정된 도구와 패턴에 대한 보조 방어이며 모든 외부 전송을 막는 장치는 아니다. 설치 오류 해결을 위해 Hook·권한 정책을 끄지 않는다. jq 설치나 Hook 검증이 막히면 기본 설치를 “부분 완료”로 보고한다.

### 보조 스킬

저장소의 `skills/<이름>/`을 설정 루트의 `skills/<이름>/`에 복사한다. 대상은 1절의 다섯 스킬이다. [공통 설치 헬퍼](lib/install-host.sh)의 `jurisupport_copy_skill`과 같은 배치를 사용한다. 이 경로에서는 Claude만 대상으로 한다.

파일이 같으면 건너뛰고, 기존 파일이 다르면 백업을 남긴다. 사용자 편집이 있으면 변경을 보존하여 병합하고, 충돌을 임의로 덮어쓰지 않는다. 각 대상에 `SKILL.md`가 있는지와 상대 참조 파일이 함께 복사됐는지 확인한다. 새 설치에서는 같은 스킬을 `commands/`에도 중복 등록할 필요가 없다. 기존 명령은 임의로 삭제하지 않는다.

## 5. 선택 기능은 독립적으로 설치

요청된 기능만 아래 순서와 해당 스킬의 지침으로 처리한다. 모든 명령은 저장소 루트 기준이며 Windows의 `.sh`는 **Git Bash**에서 실행한다. PowerShell에 Bash 문법을 그대로 붙이지 않는다. 대화형 프롬프트는 실제 질문을 읽고 요청 범위에 맞게 응답한다. 터미널 입력을 지원하지 않으면 무작정 재실행하지 말고 해당 구성요소의 수동 절차를 읽어 적용한다.

| 기능 | 실행 | 설치 후 확인 |
|---|---|---|
| 법원 양식 | `bash toolkit/court-forms/install.sh --host claude` | `court_forms.py info`로 목록 개수, `search "주소보정"`으로 결과 확인. 스크립트 위치는 `~/court-forms/scripts/` |
| 과거 사건 검색 | `bash toolkit/case-records/install.sh --host claude` | `http://localhost:8767/health` 확인. 사건 0건이면 인덱싱 전 상태로 보고하고 검색을 시도하지 않음 |
| 법고을 자동 검색 | `bash toolkit/beopgoeul/install.sh --host claude` | 설치된 `beopgoeul-search` 스킬의 실행 경로로 공개 키워드 검색, Chrome 실행과 결과 확인 |
| 오프라인 법률 DB | `bash toolkit/clean-legal-db/install.sh --host claude` | 배포 해시 검증, `python3 ~/clean-legal-db/search.py "임대차" --top 3` 실제 결과 확인 |

- 실행 전 각 설치 코드를 읽고 기존 설치에 미치는 영향을 확인한다. 특히 case-records 설치기는 기존 서버를 멈추고 가상환경을 다시 만든다. 정상 서버에는 재실행하지 말고 상태부터 확인한다. DB·토큰·사건 원본은 보존하며, 실행 중인 작업을 중단해야 하면 사용자와 조율한다.
- Python 버전·실행 경로는 [기존 감지 로직](lib/python-detect.sh)을 참고한다. Windows의 Store 실행 별칭을 정상 Python으로 오인하지 않는다. `python3`라는 이름이 필요한 스크립트는 실제 실행 파일을 확인하고 필요한 범위에서 경로를 맞춘다.
- `korean-law`는 OC가 준비된 경우 `install.sh`의 4단계와 [키 발급 가이드](guides/07_law_openapi_key.md)를 따른다. OC가 없으면 연결 대기로 표시한다. 오프라인 법령은 실습용이며 현행 법령 조회 성공으로 처리하지 않는다.
- JuriSupport MCP는 [연결 가이드](guides/01_jurisupport_alt.md)와 `install.sh`의 12단계를 읽고 사용자 계정·토큰으로 연결한다. 이미 등록된 서버를 임의로 교체하지 않는다. 토큰은 호스트의 설정 절차로 사용자가 입력하고, 등록 후 권한 있는 읽기 전용 조회로 인증을 확인한다.
- legal-books는 별도 저장소의 설치 문서를 먼저 확인한다. 책 0권이면 검색하지 않는다. 사건·서적 인덱싱과 외부 임베딩은 설치와 별개이며 외부 전송 동의 없이 켜지 않는다.

## 6. 실패하면 해당 단계부터 복구

단계마다 명령, 종료 코드, 민감정보를 제거한 오류 요약을 확인한다. “완료”라는 출력이 있어도 실제 검사가 실패하면 미완료다. 실패 원인에 맞는 조치를 한 뒤 **그 단계만** 재시도한다. 같은 원인으로 두 번 실패하면 같은 명령을 반복하지 말고 아래 대안이나 공식 문서를 확인한다. 해결 가능한 다른 독립 단계는 계속 진행한다.

| 증상 | 복구 순서 |
|---|---|
| `command not found`, Windows에서 설치 직후 명령을 못 찾음 | 실제 설치 경로와 PATH 확인 → 절대 경로로 실행 → 필요한 경우 새 터미널 안내. CLI가 보이지 않는다고 앱을 중복 설치하지 않음 |
| PowerShell이 `claude.ps1` 실행을 차단 | 설치된 `claude.exe` 또는 `claude.cmd` 확인 후 사용. 시스템 전체 ExecutionPolicy를 완화하지 않음 |
| Windows marketplace clone의 `Filename too long` | 2절의 긴 경로 옵션으로 받은 영구 로컬 저장소를 등록. 실패한 등록이 남았는지 먼저 확인하고 정상 소스를 보존. 등록되지 않은 불완전 캐시를 정상 설치로 오인하지 않음. 로컬 소스의 이후 갱신은 3절 순서를 따름 |
| GitHub 다운로드·marketplace 등록 실패 | 네트워크·인증·프록시 오류 구분. Git 소스 등록만 실패하고 검증한 로컬 소스가 있으면 `claude plugin marketplace add "<저장소 절대 경로>"` 사용. TLS 검증을 끄지 않음 |
| `plugin` 명령이나 옵션이 없음 | 현재 `--help`와 공식 문서 확인 → 기존 설치 방식으로 Claude Code 업데이트 → 버전 재확인. 문서에 없는 옵션을 추측하지 않음 |
| 설치됐는데 스킬이 안 보임 | 정확한 플러그인 ID·활성 상태·설정 루트·설치 범위 확인 → CLI 출력에 따라 `/reload-plugins` 또는 새 로컬 세션 안내. 플러그인 캐시 전체 삭제나 무조건 제거·재설치를 하지 않음 |
| Hook 실행 실패 | 실제 등록 명령의 인용·Bash·jq·파일 권한 검사. 백업과 비교해 이번에 수정한 항목만 복구. 다른 설정이나 보호 장치를 제거하지 않음 |
| Python·가상환경·포트 충돌 | 실제 Python 버전과 toolkit 로그 확인. 포트 점유 프로세스의 소유·용도를 확인하고 관련 서버만 다룸. 모든 Python 프로세스를 강제 종료하지 않음 |
| 다운로드 해시 불일치 | 실패 파일을 사용하지 않고 공식 배포 파일 재확인. 검증을 생략하거나 예상 해시를 다운로드 파일에 맞춰 바꾸지 않음 |
| 계정·키·관리 권한·조직 정책 필요 | 필요한 사용자 조치와 이어갈 단계를 기록. 연결 대기 또는 차단으로 보고하고 다른 설치를 계속함 |

진단 로그는 로컬에서 확인한다. 지원 리포트 업로드는 이 설치 요청에 포함되지 않으며, 별도 동의 없이 활성화하지 않는다.

## 7. 완료 판정과 인계

최종 보고에는 다음을 짧게 정리한다.

- **검증 완료:** 플러그인 ID·버전·활성 상태, Hook의 등록 명령 검사, 다섯 스킬의 파일 확인과 검사 결과.
- **활성화 확인:** 현재 세션에서 새 플러그인이 로드됐는지 확인한다. 아직이면 CLI 안내에 따라 다시 로드하거나 새 세션에서 `/jurisupport:cold-start-interview`가 보이는지 확인하도록 인계한다. 실행하지 못한 세션 검사는 “미검증”으로 남긴다. 콜드스타트 인터뷰 답을 임의로 채우지 않는다.
- **선택 기능:** 기능별로 동작 확인 / 설치됨·미검증 / 미설치 / 사용자 조치 대기를 구분한다. 서버 등록과 실제 인증·조회 성공을 혼동하지 않는다.
- **복구 이력:** 해결한 오류, 남은 원인, 백업 위치, 사용자가 해야 하는 최소 조치와 재개 단계. 비밀값은 포함하지 않는다.

기본 설치 검사 중 하나라도 실패하면 “기본 설치 부분 완료”로 보고한다. 선택 기능이 없다는 이유로 정상 기본 설치를 실패로 보고하지 않는다. 재실행 요청은 1절에서 현 상태를 다시 읽고 성공한 단계는 건너뛴다.

공식 참고: [플러그인 설치·관리](https://code.claude.com/docs/en/discover-plugins), [Claude 지침 파일](https://code.claude.com/docs/en/memory). 실제 명령·출력이 이 안내와 다르면 설치된 CLI의 도움말과 공식 문서를 먼저 확인한다.
